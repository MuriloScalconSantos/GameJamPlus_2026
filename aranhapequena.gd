extends CharacterBody3D
## Aranha: persegue o jogador mais rápido, morre com um hit e dropa joias de XP.

signal cabecada_iniciada
signal cabecada_terminada(acertou: bool)

const CENA_JOIA_XP: PackedScene = preload("res://progressao/xp_joia.tscn")

@export_group("Movimento")
@export var speed: float = 8.0 # Velocidade ajustada anteriormente para 8.0
@export var max_health: float = 1.0 # Morre com um hit

@export_group("Aparência")
@export var escala_aranha: Vector3 = Vector3(0.45, 0.45, 0.45) # Reduzida de 0.7 para 0.45 (bem menor)
@export var cor_aranha: Color = Color(1.8, 0.2, 0.2, 1.0) # Vermelho intenso/vibrante

@export_group("Cabeçada (Super Rápida)")
@export var attack_range: float = 1.45
@export var hit_range: float = 1.75
@export var attack_damage: float = 5.0
@export var attack_duration: float = 0.3 # Bem mais rápido para concluir o bote num instante
@export var attack_cooldown: float = 0.15 # Praticamente sem pausa entre um ataque e outro
@export var lunge_speed: float = 1.5

@export_group("Recuo ao receber dano")
@export var textura_recuo: Texture2D = preload(
	"res://Sprites/Knockback/aranha_knockback.png"
)
@export_range(0.1, 20.0, 0.1) var forca_recuo: float = 8.0
@export_range(0.05, 1.0, 0.01) var duracao_recuo: float = 0.22

var player: CharacterBody3D
var health: float
var _attacking := false
var _attack_time := 0.0
var _cooldown_left := 0.0
var _hit_done := false
var _attack_direction := Vector3.ZERO
var _walk_time := 0.0
var _morto: bool = false
var _xp_dropado: bool = false
var _recuo_restante: float = 0.0
var _sprite_recuo: Sprite3D
var _tween_recuo: Tween

@onready var sprite: AnimatedSprite3D = $Sprite3D


func _ready() -> void:
	if EstadoJogo and "VIDA_ARANHA" in EstadoJogo:
		max_health = EstadoJogo.VIDA_ARANHA
	health = max_health

	add_to_group("enemy")
	add_to_group("inimigos")

	if player == null and get_parent():
		player = get_parent().get_node_or_null("Player") as CharacterBody3D

	# --- APLICA TAMANHO REDUZIDO E TOM AVERMELHADO ---
	if sprite:
		sprite.scale = escala_aranha
		sprite.modulate = cor_aranha

	_preparar_sprite_recuo()
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"walk"):
		sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if _morto:
		if not is_on_floor():
			velocity += get_gravity() * delta
		_atualizar_recuo(delta)
		move_and_slide()
		return
	if EstadoJogo.vida_atual <= 0.0:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _atualizar_recuo(delta):
		move_and_slide()
		return

	if not is_instance_valid(player):
		_stop_horizontal()
		_set_animation(&"idle")
	elif _attacking:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null and sprite:
			sprite.flip_h = camera.global_basis.x.dot(_attack_direction) > 0.0
		_update_attack(delta)
	else:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		var distance: float = to_player.length()
		_face_player(to_player)
		if distance <= attack_range:
			_stop_horizontal()
			if _cooldown_left <= 0.0:
				_begin_attack(to_player)
			else:
				_set_animation(&"idle")
		elif distance > 0.01:
			var direction: Vector3 = to_player / distance
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			_set_animation(&"walk")
			_walk_time += delta * 1.2
			var pulse: float = sin(_walk_time * TAU)
			if sprite:
				sprite.scale = Vector3(escala_aranha.x - pulse * 0.03, escala_aranha.y + pulse * 0.05, escala_aranha.z)
		else:
			_stop_horizontal()
			_set_animation(&"idle")

	move_and_slide()


func _begin_attack(to_player: Vector3) -> void:
	if _morto:
		return
	_attacking = true
	_attack_time = 0.0
	_hit_done = false
	_attack_direction = to_player.normalized()
	_stop_horizontal()
	if sprite:
		sprite.scale = escala_aranha
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"attack"):
			sprite.speed_scale = 2.0 / maxf(attack_duration, 0.01) / sprite.sprite_frames.get_animation_speed(&"attack")
			sprite.play(&"attack")
	cabecada_iniciada.emit()


func _update_attack(delta: float) -> void:
	_attack_time += delta
	var strike_start: float = attack_duration * 0.3
	var strike_end: float = attack_duration * 0.8
	if _attack_time >= strike_start and _attack_time < strike_end:
		velocity.x = _attack_direction.x * lunge_speed
		velocity.z = _attack_direction.z * lunge_speed
	else:
		_stop_horizontal()
	if not _hit_done and _attack_time >= attack_duration * 0.5:
		_hit_done = true
		cabecada_terminada.emit(_hit_player())
	if _attack_time >= attack_duration:
		_attacking = false
		_cooldown_left = attack_cooldown
		_stop_horizontal()
		if sprite:
			sprite.speed_scale = 1.0
		_set_animation(&"idle")


func _hit_player() -> bool:
	if _morto or not is_instance_valid(player):
		return false
	var separation: Vector3 = player.global_position - global_position
	separation.y = 0.0
	if separation.length() > hit_range:
		return false
	var health_node: Node = player.get_node_or_null("Health")
	if health_node == null or not health_node.has_method("receber_dano"):
		return false
	var start: Vector3 = global_position + Vector3.UP * 0.6
	var finish: Vector3 = player.global_position + Vector3.UP * 0.6
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1)
	ray.exclude = [get_rid(), player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	health_node.call("receber_dano", attack_damage, global_position)
	return true


func _face_player(to_player: Vector3) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and to_player.length_squared() > 0.001 and sprite:
		sprite.flip_h = camera.global_basis.x.dot(to_player) > 0.0


func _set_animation(anim_name: StringName) -> void:
	if _morto or not sprite or not sprite.sprite_frames:
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.scale = escala_aranha
			sprite.play(anim_name)


func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func receber_dano(amount: float, _origin: Vector3, autor: Node = null) -> void:
	if _morto or amount <= 0.0:
		return
	health -= amount
	_iniciar_recuo(_origin)
	if health <= 0.0:
		_morto = true
		_soltar_xp(autor)

		var spawner = get_tree().get_first_node_in_group("spawner_ritmo")
		if spawner and spawner.has_method("add_kill"):
			spawner.call("add_kill")

		get_tree().create_timer(duracao_recuo + 0.04).timeout.connect(queue_free)


func _preparar_sprite_recuo() -> void:
	if textura_recuo == null or sprite == null:
		return
	_sprite_recuo = Sprite3D.new()
	_sprite_recuo.name = "SpriteRecuo"
	_sprite_recuo.texture = textura_recuo
	_sprite_recuo.position = sprite.position
	_sprite_recuo.pixel_size = sprite.pixel_size
	_sprite_recuo.billboard = sprite.billboard
	_sprite_recuo.no_depth_test = sprite.no_depth_test
	_sprite_recuo.modulate = cor_aranha
	_sprite_recuo.visible = false
	add_child(_sprite_recuo)


func _iniciar_recuo(origem: Vector3) -> void:
	_attacking = false
	_attack_time = 0.0
	_cooldown_left = maxf(_cooldown_left, 0.18)
	var direcao := global_position - origem
	direcao.y = 0.0
	if direcao.length_squared() < 0.0001 and is_instance_valid(player):
		direcao = global_position - player.global_position
		direcao.y = 0.0
	if direcao.length_squared() < 0.0001:
		direcao = Vector3.BACK
	direcao = direcao.normalized()
	velocity.x = direcao.x * forca_recuo
	velocity.z = direcao.z * forca_recuo
	_recuo_restante = duracao_recuo
	if _sprite_recuo == null:
		return
	_sprite_recuo.flip_h = sprite.flip_h
	_sprite_recuo.scale = escala_aranha * Vector3(1.12, 0.9, 1.0)
	sprite.visible = false
	_sprite_recuo.visible = true
	if _tween_recuo and _tween_recuo.is_running():
		_tween_recuo.kill()
	_tween_recuo = create_tween()
	_tween_recuo.tween_property(
		_sprite_recuo,
		"scale",
		escala_aranha,
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _atualizar_recuo(delta: float) -> bool:
	if _recuo_restante <= 0.0:
		return false
	_recuo_restante = maxf(0.0, _recuo_restante - delta)
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
		Vector2.ZERO,
		forca_recuo / maxf(duracao_recuo, 0.01) * delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if _recuo_restante <= 0.0 and not _morto:
		sprite.visible = true
		if _sprite_recuo:
			_sprite_recuo.visible = false
		sprite.scale = escala_aranha
	return true


func _soltar_xp(_autor: Node = null) -> void:
	if _xp_dropado or CENA_JOIA_XP == null:
		return
	_xp_dropado = true
	var quantidade: int = EstadoJogo.XP_ARANHA if EstadoJogo and "XP_ARANHA" in EstadoJogo else 1

	var angulo_inicial: float = randf_range(0.0, TAU)
	for numero in range(quantidade):
		var joia = CENA_JOIA_XP.instantiate()
		var angulo: float = angulo_inicial + TAU * numero / quantidade
		var deslocamento := Vector3(cos(angulo), 0.0, sin(angulo)) * 0.35
		get_parent().add_child(joia)
		joia.global_position = global_position + Vector3.UP * 0.28
		joia.preparar(player, deslocamento)
