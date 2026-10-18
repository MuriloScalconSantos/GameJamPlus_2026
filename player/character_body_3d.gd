extends CharacterBody3D
## Movimentação com momentum estilo Mario (eixos do mundo, sem rotação do personagem).
## Usa animações por direção quando o sprite tem SpriteFrames configurado.
## Sprites sem animações direcionais continuam sendo espelhados na horizontal.
## Input e sprite são detectados automaticamente (veja o Output ao iniciar o jogo).

# ===========================================================================
# VARIÁVEIS AJUSTÁVEIS (também aparecem no Inspector)
# ===========================================================================

# --- INPUT ------------------------------------------------------------------
@export_group("Input")
## Procura no Input Map as ações ligadas a A/D/W/S (ignora as ui_* padrão).
@export var auto_detect_actions: bool = true
## Se não achar ação, lê as teclas WASD diretamente.
@export var fallback_to_wasd_keys: bool = true
## Opcional: força o nome de uma ação do Input Map. Vazio = detecção automática.
@export var input_left: StringName = &""
@export var input_right: StringName = &""
@export var input_up: StringName = &""
@export var input_down: StringName = &""

# --- VELOCIDADE -------------------------------------------------------------
@export_group("Velocidade")
@export var walk_speed: float = 5.0

# --- ACELERAÇÃO E ARRASTE ---------------------------------------------------
@export_group("Aceleração e arraste")
## Quão rápido atinge a velocidade alvo (unidades/s²).
@export var walk_acceleration: float = 28.0
## Fricção quando solta o direcional no chão.
@export var ground_friction: float = 22.0
## Frenagem forte ao inverter a direção em velocidade alta (derrapagem).
@export var skid_deceleration: float = 55.0
## Velocidade mínima para considerar derrapagem.
@export var skid_min_speed: float = 3.5
## Quanto menor o dot (direção vs velocidade), mais oposta precisa ser (-1 = totalmente oposta).
@export_range(-1.0, 0.0) var skid_dot_threshold: float = -0.5
## Multiplicador de aceleração/fricção no ar (0 a 1).
@export_range(0.0, 1.0) var air_control: float = 0.45
## Arraste leve no ar para não manter momentum infinito ao cair.
@export var air_drag: float = 1.5

# --- SPRITE / DIREÇÃO -------------------------------------------------------
@export_group("Sprite")
## Opcional: Sprite3D ou AnimatedSprite3D. Vazio = procura nos filhos.
@export var sprite: SpriteBase3D
## Durante a derrapada o sprite continua olhando para onde está deslizando,
## e só vira quando a derrapada termina.
@export var hold_facing_while_skidding: bool = true
## Zona morta do direcional para trocar de lado.
@export_range(0.0, 1.0) var facing_deadzone: float = 0.1
## Tempo em que o quadro de dano aparece antes de voltar à animação normal.
@export var hit_visual_duration: float = 0.25

@export_group("Reação ao dano")
## Recuo curto para longe da origem do golpe; não altera walk_speed.
@export var hit_knockback_speed: float = 2.5
@export var hit_knockback_duration: float = 0.12
## Pequeno afundamento visual ao receber um golpe vindo de cima.
@export var hit_up_recoil: float = 0.05

# --- JUICINESS --------------------------------------------------------------
@export_group("Juice")
## Opcional: nó que recebe squash & stretch e bobbing. Vazio = usa o sprite.
## Dica: deixe o pivô do nó nos pés para a escala não "afundar" no chão.
@export var visual: Node3D
@export var squash_stiffness: float = 220.0
@export var squash_damping: float = 14.0
## Intensidade do squash no pouso (por unidade de velocidade de queda).
@export var landing_squash_amount: float = 0.03
@export var landing_squash_max: float = 0.4
@export var skid_squash: float = 0.18
## Altura do quique ao andar.
@export var bob_height: float = 0.06
## Frequência do quique (relativa à velocidade).
@export var bob_frequency: float = 1.6

# ===========================================================================
# SINAIS (use para partículas, sons, câmera etc.)
# ===========================================================================
signal landed(impact_speed: float)
signal skid_started
signal facing_changed(facing_right: bool)

# ===========================================================================
# ESTADO INTERNO (não mexer)
# ===========================================================================
var _act_left: StringName = &""
var _act_right: StringName = &""
var _act_up: StringName = &""
var _act_down: StringName = &""

var _is_skidding: bool = false
var _facing_right: bool = true
var _use_scale_flip: bool = false
var _directional_sprite: AnimatedSprite3D
var _last_animation_direction: String = "down"
var _run_visual_active: bool = false
var _hit_visual_time: float = 0.0
var _hit_animation_direction: String = "down"
var _knockback_time: float = 0.0

# Mola do squash: positivo = achatado, negativo = esticado.
var _squash: float = 0.0
var _squash_velocity: float = 0.0

var _bob_time: float = 0.0
var _visual_base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_resolve_visuals()
	_resolve_inputs()
	var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
	if camera and camera.has_signal(&"pull_out_changed"):
		camera.connect(&"pull_out_changed", _on_pull_out_changed)
	var health_node: Node = get_node_or_null("Health")
	if health_node and health_node.has_signal(&"hit_received"):
		health_node.connect(&"hit_received", _on_hit_received)


func _on_pull_out_changed(active: bool) -> void:
	_run_visual_active = active


func _on_hit_received(origin: Vector3) -> void:
	var from_hit: Vector3 = origin - global_position
	from_hit.y = 0.0
	if Vector2(from_hit.x, from_hit.z).length_squared() > 0.0001:
		if absf(from_hit.x) >= absf(from_hit.z):
			_hit_animation_direction = "right" if from_hit.x > 0.0 else "left"
		else:
			_hit_animation_direction = "down" if from_hit.z > 0.0 else "up"
	else:
		_hit_animation_direction = _last_animation_direction
	_hit_visual_time = maxf(hit_visual_duration, 0.0)
	_knockback_time = 0.0
	if (
		from_hit.length_squared() > 0.0001
		and hit_knockback_speed > 0.0
		and hit_knockback_duration > 0.0
	):
		var away: Vector3 = -from_hit.normalized()
		velocity.x = away.x * hit_knockback_speed
		velocity.z = away.z * hit_knockback_speed
		_knockback_time = maxf(hit_knockback_duration, 0.0)


# ---------------------------------------------------------------------------
# SETUP: sprite / visual
# ---------------------------------------------------------------------------
func _resolve_visuals() -> void:
	if sprite == null and visual is SpriteBase3D:
		sprite = visual as SpriteBase3D
	if sprite == null:
		var found: Array[Node] = find_children("*", "SpriteBase3D", true, false)
		if not found.is_empty():
			sprite = found[0] as SpriteBase3D
	if visual == null:
		visual = sprite

	if visual:
		_visual_base_position = visual.position

	# Sem sprite: espelha invertendo a escala X do visual.
	_use_scale_flip = sprite == null
	if sprite is AnimatedSprite3D:
		var candidate: AnimatedSprite3D = sprite as AnimatedSprite3D
		var frames: SpriteFrames = candidate.sprite_frames
		if frames:
			var all_directions: bool = true
			for direction_name: String in ["down", "up", "left", "right"]:
				if not frames.has_animation("walk_" + direction_name) or not frames.has_animation("idle_" + direction_name):
						all_directions = false
						break
			if all_directions:
				_directional_sprite = candidate

	if sprite:
		if _directional_sprite:
			_directional_sprite.flip_h = false
			_directional_sprite.play(&"idle_down")
			print("[Player] animações direcionais: ", sprite.name)
		else:
			sprite.flip_h = not _facing_right
			print("[Player] sprite espelhado: ", sprite.name)
	elif visual:
		print("[Player] nenhum Sprite3D encontrado; espelhando pela escala de: ", visual.name)
	else:
		push_warning("Player: nenhum nó visual/sprite encontrado. Atribua 'visual' no Inspector.")


# ---------------------------------------------------------------------------
# SETUP: input
# ---------------------------------------------------------------------------
func _resolve_inputs() -> void:
	_act_left = _resolve_action(input_left, KEY_A, PackedStringArray(["left", "esq"]))
	_act_right = _resolve_action(input_right, KEY_D, PackedStringArray(["right", "direita"]))
	_act_up = _resolve_action(input_up, KEY_W, PackedStringArray(["up", "forward", "front", "frente", "cima"]))
	_act_down = _resolve_action(input_down, KEY_S, PackedStringArray(["down", "back", "tras", "baixo"]))

	print("[Player] input -> esquerda: %s | direita: %s | cima: %s | baixo: %s" % [
		_describe(_act_left, "A"),
		_describe(_act_right, "D"),
		_describe(_act_up, "W"),
		_describe(_act_down, "S"),
	])


func _resolve_action(manual: StringName, key: Key, hints: PackedStringArray) -> StringName:
	if manual != &"":
		if InputMap.has_action(manual):
			return manual
		push_warning("Player: a ação '%s' não existe no Input Map." % manual)
	if auto_detect_actions:
		return _find_action_for_key(key, hints)
	return &""


## Procura uma ação do projeto (ignora ui_*) que tenha a tecla indicada.
## Se várias ações usarem a mesma tecla, prefere a que tiver uma dica no nome.
func _find_action_for_key(key: Key, hints: PackedStringArray) -> StringName:
	var fallback: StringName = &""
	for action: StringName in InputMap.get_actions():
		var action_name: String = String(action)
		if action_name.begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event: InputEventKey = event as InputEventKey
				if key_event.physical_keycode == key or key_event.keycode == key:
					var lower: String = action_name.to_lower()
					for hint: String in hints:
						if lower.contains(hint):
							return action
					if fallback == &"":
						fallback = action
	return fallback


func _describe(action: StringName, key_name: String) -> String:
	if action != &"":
		return "ação '%s'" % action
	if fallback_to_wasd_keys:
		return "tecla %s (direta)" % key_name
	return "(nenhuma)"


# ---------------------------------------------------------------------------
# LEITURA DE INPUT
# ---------------------------------------------------------------------------
func _axis(action: StringName, key: Key) -> float:
	if action != &"":
		return Input.get_action_strength(action)
	if fallback_to_wasd_keys and Input.is_physical_key_pressed(key):
		return 1.0
	return 0.0


func _read_move_input() -> Vector2:
	var result: Vector2 = Vector2(
		_axis(_act_right, KEY_D) - _axis(_act_left, KEY_A),
		_axis(_act_down, KEY_S) - _axis(_act_up, KEY_W)
	)
	return result.limit_length(1.0)


# ---------------------------------------------------------------------------
# FÍSICA
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var was_on_floor: bool = is_on_floor()

	# --- Gravidade -----------------------------------------------------------
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- Input (eixos do mundo, não depende de rotação nem câmera) -----------
	var input_dir: Vector2 = _read_move_input()
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	var has_input: bool = direction.length_squared() > 0.0001

	# --- Movimento horizontal com momentum ------------------------------------
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var on_floor: bool = is_on_floor()
	var control: float = 1.0 if on_floor else air_control
	var accel: float = walk_acceleration * control

	if _knockback_time > 0.0:
		var recoil_deceleration: float = hit_knockback_speed / maxf(hit_knockback_duration, 0.001)
		horizontal = horizontal.move_toward(Vector3.ZERO, recoil_deceleration * delta)
		_knockback_time = maxf(_knockback_time - delta, 0.0)
		_is_skidding = false
	elif has_input:
		var speed: float = horizontal.length()
		var skidding_now: bool = false

		if on_floor and speed > skid_min_speed:
			var dot: float = horizontal.normalized().dot(direction.normalized())
			skidding_now = dot < skid_dot_threshold

		if skidding_now:
			horizontal = horizontal.move_toward(Vector3.ZERO, skid_deceleration * delta)
			if not _is_skidding:
				skid_started.emit()
				_squash_velocity += skid_squash * 12.0
		else:
			var target: Vector3 = direction * walk_speed
			horizontal = horizontal.move_toward(target, accel * delta)

		_is_skidding = skidding_now

		# --- Direção do sprite ---------------------------------------------------
		var keep_facing: bool = skidding_now and hold_facing_while_skidding
		if not keep_facing and absf(input_dir.x) > facing_deadzone:
			_set_facing(input_dir.x > 0.0)
	else:
		_is_skidding = false
		var friction: float = ground_friction if on_floor else air_drag
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# --- Move -----------------------------------------------------------------
	var fall_speed: float = -velocity.y  # guardado antes do move_and_slide zerar
	move_and_slide()

	# --- Pouso ----------------------------------------------------------------
	if is_on_floor() and not was_on_floor:
		var impact: float = maxf(fall_speed, 0.0)
		landed.emit(impact)
		var amount: float = clampf(impact * landing_squash_amount, 0.0, landing_squash_max)
		_squash = maxf(_squash, amount)
		_squash_velocity = 0.0

	_update_juice(delta)
	_hit_visual_time = maxf(_hit_visual_time - delta, 0.0)
	_update_directional_animation(input_dir, has_input)


func _set_facing(facing_right: bool) -> void:
	if facing_right == _facing_right:
		return
	_facing_right = facing_right
	if sprite and not _directional_sprite:
		sprite.flip_h = not facing_right
	facing_changed.emit(facing_right)


func _update_directional_animation(input_dir: Vector2, has_input: bool) -> void:
	if not _directional_sprite:
		return
	if _hit_visual_time > 0.0:
		var hit_name: StringName = StringName("hit_" + _hit_animation_direction)
		if _directional_sprite.sprite_frames.has_animation(hit_name):
			_directional_sprite.flip_h = hit_name == &"hit_right"
			if _directional_sprite.animation != hit_name:
				_directional_sprite.play(hit_name)
			return

	var movement: Vector2 = Vector2(velocity.x, velocity.z)
	var moving: bool = has_input or movement.length_squared() > 0.04
	if moving:
		var facing_input: Vector2 = input_dir
		if not has_input or (_is_skidding and hold_facing_while_skidding):
			facing_input = movement
		if facing_input.length_squared() > 0.0001:
			if absf(facing_input.x) >= absf(facing_input.y):
				_last_animation_direction = "right" if facing_input.x > 0.0 else "left"
			else:
				_last_animation_direction = "down" if facing_input.y > 0.0 else "up"

	var animation_prefix: String = "idle_"
	if moving:
		animation_prefix = "run_" if _run_visual_active else "walk_"
	var animation_name: StringName = StringName(animation_prefix + _last_animation_direction)
	if not _directional_sprite.sprite_frames.has_animation(animation_name):
		animation_name = StringName("walk_" + _last_animation_direction)
	_directional_sprite.flip_h = animation_name == &"run_left"
	if _directional_sprite.animation != animation_name or not _directional_sprite.is_playing():
		_directional_sprite.play(animation_name)


func _update_juice(delta: float) -> void:
	if not visual:
		return

	# Mola amortecida do squash & stretch
	var spring_force: float = -_squash * squash_stiffness - _squash_velocity * squash_damping
	_squash_velocity += spring_force * delta
	_squash += _squash_velocity * delta

	# Achata no Y e expande em X/Z (preserva volume aproximado).
	# Se não há sprite, o espelhamento é feito invertendo o X da escala.
	var flip: float = -1.0 if (_use_scale_flip and not _facing_right) else 1.0
	visual.scale = Vector3(
		(1.0 + _squash * 0.5) * flip,
		1.0 - _squash,
		1.0 + _squash * 0.5
	)

	# Bobbing proporcional à velocidade, só no chão
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clampf(horizontal_speed / walk_speed, 0.0, 1.0)

	var bob: float = 0.0
	if is_on_floor() and speed_ratio > 0.05:
		_bob_time += delta * horizontal_speed * bob_frequency
		bob = absf(sin(_bob_time)) * bob_height * speed_ratio

	var hit_offset: float = 0.0
	if _hit_visual_time > 0.0 and _hit_animation_direction == "up":
		var hit_progress: float = 1.0 - _hit_visual_time / maxf(hit_visual_duration, 0.001)
		hit_offset = -hit_up_recoil * sin(hit_progress * PI)
	visual.position = _visual_base_position + Vector3(0.0, bob + hit_offset, 0.0)
