extends CharacterBody3D
## Movimentação com momentum estilo Mario (eixos do mundo, sem rotação do personagem).
## Requer a ação "run" no Input Map (opcional: sem ela, o personagem só anda).

# ---------------------------------------------------------------------------
# SINAIS (use para partículas, sons, câmera shake etc.)
# ---------------------------------------------------------------------------
signal landed(impact_speed: float)
signal skid_started
signal run_started

# ---------------------------------------------------------------------------
# MOVIMENTAÇÃO
# ---------------------------------------------------------------------------
@export_group("Velocidade")
@export var walk_speed: float = 5.0
@export var run_speed: float = 9.0

@export_group("Aceleração e arraste")
## Quão rápido atinge a velocidade alvo ao andar (unidades/s²).
@export var walk_acceleration: float = 28.0
## Aceleração ao correr (menor = mais "peso" para engatar a corrida).
@export var run_acceleration: float = 18.0
## Fricção quando solta o direcional no chão.
@export var ground_friction: float = 22.0
## Frenagem forte ao inverter a direção em velocidade alta (derrapagem).
@export var skid_deceleration: float = 75.0
## Velocidade mínima para considerar derrapagem.
@export var skid_min_speed: float = 3.5
## Quanto menor o dot (direção vs velocidade), mais oposta precisa ser (-1 = totalmente oposta).
@export_range(-1.0, 0.0) var skid_dot_threshold: float = -0.5
## Multiplicador de aceleração/fricção no ar (0 a 1).
@export_range(0.0, 1.0) var air_control: float = 0.45
## Arraste leve no ar para não manter momentum infinito ao cair.
@export var air_drag: float = 1.5

# ---------------------------------------------------------------------------
# JUICINESS (visual)
# ---------------------------------------------------------------------------
@export_group("Juice")
## Nó visual (mesh/modelo) que recebe squash & stretch e bobbing.
## Dica: deixe o pivô do nó nos pés para a escala não "afundar" no chão.
@export var visual: Node3D
@export var squash_stiffness: float = 220.0
@export var squash_damping: float = 14.0
## Intensidade do squash no pouso (por unidade de velocidade de queda).
@export var landing_squash_amount: float = 0.03
@export var landing_squash_max: float = 0.4
@export var run_start_squash: float = 0.12
@export var skid_squash: float = 0.18
## Altura do quique ao andar.
@export var bob_height: float = 0.06
## Frequência do quique (relativa à velocidade).
@export var bob_frequency: float = 1.6

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------
var _is_running: bool = false
var _is_skidding: bool = false

# Mola do squash: positivo = achatado, negativo = esticado.
var _squash: float = 0.0
var _squash_velocity: float = 0.0

var _bob_time: float = 0.0
var _visual_base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	if visual:
		_visual_base_position = visual.position


func _physics_process(delta: float) -> void:
	var was_on_floor: bool = is_on_floor()

	# --- Gravidade -----------------------------------------------------------
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- Input (eixos do mundo, não depende de rotação nem câmera) -----------
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)

	var wants_run: bool = InputMap.has_action(&"run") and Input.is_action_pressed(&"run")
	var has_input: bool = direction.length_squared() > 0.0001

	# Detecta início da corrida (só conta se estiver se movendo)
	var now_running: bool = wants_run and has_input
	if now_running and not _is_running and is_on_floor():
		run_started.emit()
		_squash_velocity += run_start_squash * 12.0
	_is_running = now_running

	# --- Movimento horizontal com momentum ------------------------------------
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var on_floor: bool = is_on_floor()
	var control: float = 1.0 if on_floor else air_control

	var max_speed: float = run_speed if _is_running else walk_speed
	var accel: float = (run_acceleration if _is_running else walk_acceleration) * control

	if has_input:
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
			var target: Vector3 = direction * max_speed
			horizontal = horizontal.move_toward(target, accel * delta)

		_is_skidding = skidding_now
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


func _update_juice(delta: float) -> void:
	if not visual:
		return

	# Mola amortecida do squash & stretch
	var spring_force: float = -_squash * squash_stiffness - _squash_velocity * squash_damping
	_squash_velocity += spring_force * delta
	_squash += _squash_velocity * delta

	# Achata no Y e expande em X/Z (preserva volume aproximado)
	visual.scale = Vector3(
		1.0 + _squash * 0.5,
		1.0 - _squash,
		1.0 + _squash * 0.5
	)

	# Bobbing proporcional à velocidade, só no chão
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clampf(horizontal_speed / run_speed, 0.0, 1.0)

	var bob: float = 0.0
	if is_on_floor() and speed_ratio > 0.05:
		_bob_time += delta * horizontal_speed * bob_frequency
		bob = absf(sin(_bob_time)) * bob_height * speed_ratio

	visual.position = _visual_base_position + Vector3(0.0, bob, 0.0)
