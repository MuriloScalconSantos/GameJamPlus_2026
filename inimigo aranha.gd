extends CharacterBody3D
## Aranha: persegue o jogador mais rápido, morre com um hit e dropa joias de XP.

signal cabecada_iniciada
signal cabecada_terminada(acertou: bool)

const CENA_JOIA_XP: PackedScene = preload("res://progressao/xp_joia.tscn")

@export_group("Movimento")
@export var speed: float = 5.0 # Mais rápida para o estilo swarm
@export var max_health: float = 1.0 # Morre com um hit

@export_group("Cabeçada")
@export var attack_range: float = 1.45
@export var hit_range: float = 1.75
@export var attack_damage: float = 5.0
@export var attack_duration: float = 1.0
@export var attack_cooldown: float = 1.1
@export var lunge_speed: float = 1.8

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

@onready var sprite: AnimatedSprite3D = $Sprite3D


func _ready() -> void:
	if EstadoJogo and "VIDA_ARANHA" in EstadoJogo:
		max_health = EstadoJogo.VIDA_ARANHA
	health = max_health
	
	add_to_group("enemy")
	add_to_group("inimigos")
	
	if player == null and get_parent():
		player = get_parent().get_node_or_null("Player") as CharacterBody3D
		
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"walk"):
		sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if _morto or not is_inside_tree():
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
			_walk_time += delta * 1.2
			var pulse: float = sin(_walk_time * TAU)
			if sprite:
				sprite.scale = Vector3(1.0 - pulse * 0.05, 1.0 + pulse * 0.08, 1.0)
		else:
			_stop_horizontal()
			_set_animation(&"idle")

	move_and_slide()


func _begin_attack(to_player: Vector3) -> void:
	if _morto or not sprite or not sprite.sprite_frames:
		return
	_attacking = true
	_attack_time = 0.0
	_hit_done = false
	_attack_direction = to_player.normalized()
	_stop_horizontal()
	sprite.scale = Vector3.ONE
	
	if sprite.sprite_frames.has_animation(&"attack"):
		var anim_speed: float = sprite.sprite_frames.get_animation_speed(&"attack")
		if anim_speed > 0.0:
			sprite.speed_scale = 2.0 / maxf(attack_duration, 0.01) / anim_speed
		else:
			sprite.speed_scale = 1.0
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
		if sprite:
			sprite.speed_scale = 1.0
		_set_animation(&"idle")


func _hit_player() -> bool:
	if _morto or not is_instance_valid(player) or get_world_3d() == null:
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
		sprite.flip_h = camera.global_basis.x.dot(to_player) < 0.0


func _set_animation(anim_name: StringName) -> void:
	if _morto or not sprite or not sprite.sprite_frames:
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.scale = Vector3.ONE
			sprite.play(anim_name)


func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func receber_dano(amount: float, _origin: Vector3, autor: Node = null) -> void:
	if _morto or amount <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		_morto = true
		_soltar_xp(autor)
		
		var spawner = get_tree().get_first_node_in_group("spawner_ritmo")
		if spawner and spawner.has_method("add_kill"):
			spawner.call("add_kill")
			
		queue_free()


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
