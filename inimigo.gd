extends CharacterBody3D
## Slime: persegue o jogador, pulsa ao andar e dá uma cabeçada telegrafada.

signal cabecada_iniciada
signal cabecada_terminada(acertou: bool)

@export_group("Movimento")
@export var speed: float = 2.0
@export var max_health: float = 10.0

@export_group("Cabeçada")
@export var attack_range: float = 1.45
@export var hit_range: float = 1.75
@export var attack_damage: float = 10.0
@export var attack_duration: float = 1.2
@export var attack_cooldown: float = 1.3
@export var lunge_speed: float = 1.5

@export_group("Recuo ao receber dano")
@export var textura_recuo: Texture2D = preload(
	"res://Sprites/Knockback/slime_knockback.png"
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
var _recuo_restante := 0.0
var _morto := false
var _sprite_recuo: Sprite3D
var _tween_recuo: Tween

@onready var sprite: AnimatedSprite3D = $Sprite3D


func _ready() -> void:
	health = max_health
	if player == null:
		player = get_parent().get_node_or_null("Player") as CharacterBody3D
	_preparar_sprite_recuo()
	sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	var em_recuo := _atualizar_recuo(delta)
	if _morto or em_recuo:
		move_and_slide()
		return

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
	if not is_instance_valid(player):
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
	if camera != null and to_player.length_squared() > 0.001:
		sprite.flip_h = camera.global_basis.x.dot(to_player) < 0.0


func _set_animation(name: StringName) -> void:
	if sprite.animation != name or not sprite.is_playing():
		sprite.scale = Vector3.ONE
		sprite.play(name)


func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func receber_dano(amount: float, origem: Vector3) -> void:
	if _morto or amount <= 0.0:
		return
	health -= amount
	_iniciar_recuo(origem)
	if health <= 0.0:
		_morto = true
		get_tree().create_timer(duracao_recuo + 0.04).timeout.connect(queue_free)


func _preparar_sprite_recuo() -> void:
	if textura_recuo == null:
		return
	_sprite_recuo = Sprite3D.new()
	_sprite_recuo.name = "SpriteRecuo"
	_sprite_recuo.texture = textura_recuo
	_sprite_recuo.position = sprite.position
	_sprite_recuo.pixel_size = sprite.pixel_size
	_sprite_recuo.billboard = sprite.billboard
	_sprite_recuo.no_depth_test = sprite.no_depth_test
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
	_sprite_recuo.scale = sprite.scale * Vector3(1.12, 0.9, 1.0)
	sprite.visible = false
	_sprite_recuo.visible = true
	if _tween_recuo and _tween_recuo.is_running():
		_tween_recuo.kill()
	_tween_recuo = create_tween()
	_tween_recuo.tween_property(
		_sprite_recuo,
		"scale",
		sprite.scale,
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
			sprite.scale = Vector3.ONE
	return true
