extends CharacterBody3D
## Slime e aranha usam a mesma perseguição, com animações próprias.

signal cabecada_iniciada
signal cabecada_terminada(acertou: bool)

const CENA_JOIA_XP: PackedScene = preload("res://progressao/xp_joia.tscn")

@export_enum("slime", "aranha") var tipo_inimigo: String = "slime"

@export_group("Movimento")
@export var speed: float = 3.0
@export var max_health: float = 4.0

@export_group("Cabeçada")
@export var attack_range: float = 1.45
@export var hit_range: float = 1.75
@export var attack_damage: float = 2.0
@export var attack_duration: float = 1.2
@export var attack_cooldown: float = 1.3
@export var lunge_speed: float = 1.5

var player: CharacterBody3D
var health: float
var morto: bool = false
var _morte_contada: bool = false
var _xp_dropado: bool = false
var _morto_pelo_jogador: bool = false
var _pixel_size_normal: float
var _attacking := false
var _attack_time := 0.0
var _cooldown_left := 0.0
var _hit_done := false
var _attack_direction := Vector3.ZERO
var _walk_time := 0.0

@onready var sprite: AnimatedSprite3D = $Sprite3D


func _ready() -> void:
	health = max_health
	_pixel_size_normal = sprite.pixel_size
	sprite.animation_finished.connect(_ao_terminar_animacao)
	if player == null:
		player = get_parent().get_node_or_null("Player") as CharacterBody3D
	sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if morto or EstadoJogo.partida_encerrada:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	_cooldown_left = maxf(0.0, _cooldown_left - delta)

	if not is_instance_valid(player):
		_stop_horizontal()
		_set_animation(&"idle")
	elif _attacking:
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
			_walk_time += delta * 0.9
			var pulse: float = sin(_walk_time * TAU)
			sprite.scale = Vector3(1.0 - pulse * 0.04, 1.0 + pulse * 0.07, 1.0)
		else:
			_stop_horizontal()
			_set_animation(&"idle")

	move_and_slide()


func _begin_attack(to_player: Vector3) -> void:
	if morto:
		return
	_attacking = true
	_attack_time = 0.0
	_hit_done = false
	_attack_direction = to_player.normalized()
	_stop_horizontal()
	sprite.scale = Vector3.ONE
	sprite.speed_scale = 2.0 / maxf(attack_duration, 0.01) / sprite.sprite_frames.get_animation_speed(&"attack")
	sprite.play(&"attack")
	cabecada_iniciada.emit()


func _update_attack(delta: float) -> void:
	_attack_time += delta
	var strike_start: float = attack_duration * 0.5
	var strike_end: float = attack_duration * 0.8
	if _attack_time >= strike_start and _attack_time < strike_end:
		velocity.x = _attack_direction.x * lunge_speed
		velocity.z = _attack_direction.z * lunge_speed
	else:
		_stop_horizontal()
	if not _hit_done and _attack_time >= attack_duration * 0.62:
		_hit_done = true
		cabecada_terminada.emit(_hit_player())
	if _attack_time >= attack_duration:
		_attacking = false
		_cooldown_left = attack_cooldown
		_stop_horizontal()
		sprite.speed_scale = 1.0
		_set_animation(&"idle")


func _hit_player() -> bool:
	if morto or EstadoJogo.partida_encerrada or get_tree().paused or not is_instance_valid(player):
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
	var aplicado: float = health_node.call("receber_dano", attack_damage, global_position)
	return aplicado > 0.0


func _face_player(to_player: Vector3) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and to_player.length_squared() > 0.001:
		sprite.flip_h = camera.global_basis.x.dot(to_player) < 0.0


func _set_animation(anim_name: StringName) -> void:
	if morto:
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.scale = Vector3.ONE
		sprite.play(anim_name)


func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func receber_dano(amount: float, _origin: Vector3, autor: Node = null) -> float:
	if morto or amount <= 0.0 or EstadoJogo.partida_encerrada or get_tree().paused:
		return 0.0
	var aplicado: float = minf(amount, health)
	health -= aplicado
	if health <= 0.0:
		# Guarda quem deu o golpe final; só a morte causada pelo jogador dá XP.
		_morto_pelo_jogador = is_instance_valid(autor) and autor == player
		_morrer()
	return aplicado


func _morrer() -> void:
	# Entrou aqui uma vez, não pode mais andar, atacar ou receber outro golpe.
	morto = true
	_attacking = false
	_hit_done = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	remove_from_group("inimigos")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	$CollisionShape3D.set_deferred("disabled", true)
	_morte_contada = true
	EstadoJogo.iniciar_morte_inimigo()
	_soltar_xp()

	# Os arquivos têm telas diferentes. Compensa só o enquadramento da arte.
	var normal: Texture2D = sprite.sprite_frames.get_frame_texture(&"walk", 0)
	var morte: Texture2D = sprite.sprite_frames.get_frame_texture(&"death", 0)
	sprite.pixel_size = _pixel_size_normal * normal.get_height() / float(morte.get_height())
	sprite.scale = Vector3.ONE
	sprite.speed_scale = 1.0
	sprite.play(&"death")


func _soltar_xp() -> void:
	if _xp_dropado or not _morto_pelo_jogador:
		return
	_xp_dropado = true
	var quantidade: int = EstadoJogo.XP_SLIME
	if tipo_inimigo == "aranha":
		quantidade = EstadoJogo.XP_ARANHA

	# Uma joia por ponto de XP. As duas do Slime caem um pouco separadas.
	var angulo_inicial: float = randf_range(0.0, TAU)
	for numero in range(quantidade):
		var joia = CENA_JOIA_XP.instantiate()
		var angulo: float = angulo_inicial + TAU * numero / quantidade
		var deslocamento := Vector3(cos(angulo), 0.0, sin(angulo)) * 0.35
		# Filha do mundo: continua existindo depois que o inimigo desaparece.
		get_parent().add_child(joia)
		joia.global_position = global_position + Vector3.UP * 0.28
		joia.preparar(player, deslocamento)


func _ao_terminar_animacao() -> void:
	if not morto or sprite.animation != &"death" or is_queued_for_deletion():
		return
	# O XP agora pertence às joias. Aqui só termina a morte do inimigo.
	_liberar_morte()
	queue_free()


func _liberar_morte() -> void:
	if _morte_contada:
		_morte_contada = false
		EstadoJogo.terminar_morte_inimigo()


func _exit_tree() -> void:
	# Se a cena for fechada durante a animação, não deixa uma morte pendente.
	_liberar_morte()
