extends Camera3D
## Seguimento por mola, mantendo espelhamento, antecipacao, FOV e impacto.
## Alvo automatico: procura o CharacterBody3D acima da camera.
## A rotacao e a distancia de profundidade continuam definidas no editor.

@export_group("Alvo")
@export var target: Node3D

@export_group("Mola")
@export var follow_frequency: float = 8.0
@export var vertical_frequency: float = 8.0
@export_range(0.1, 2.0) var damping_ratio: float = 1.0
## Limite horizontal do atraso em relacao a posicao desejada da camera.
@export_range(0.1, 5.0, 0.05) var max_follow_lag: float = 0.9

@export_group("Espelhamento")
@export var mirror_offset: bool = true
@export var flip_smoothing: float = 6.0
@export var facing_offset: float = 0.0
## Limita o deslocamento lateral total para nao afastar demais o jogador.
@export_range(0.0, 5.0, 0.05) var max_side_offset: float = 0.4

@export_group("Antecipação")
@export var look_ahead: float = 0.15
@export var look_ahead_max: float = 0.75

@export_group("FOV")
@export var fov_boost: float = 6.0
@export var speed_reference: float = 9.0
@export var fov_smoothing: float = 4.0

@export_group("Impacto")
@export var landing_kick: float = 0.6
@export var landing_kick_max: float = 6.0

var _offset: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _base_fov: float = 75.0
var _facing_sign: float = 1.0
var _facing_current: float = 1.0


func _ready() -> void:
	# A camera pode estar dentro do Sprite3D ou de outro no visual.
	# Nesse caso, seguir o pai imediato inclui bobbing e perde os sinais do corpo.
	if target == null:
		var ancestor: Node = get_parent()
		while ancestor != null:
			if ancestor is CharacterBody3D:
				target = ancestor as Node3D
				break
			ancestor = ancestor.get_parent()
		if target == null:
			target = get_parent() as Node3D
	if target == null:
		push_warning("CameraFollow: nenhum alvo encontrado.")
		set_process(false)
		return

	var start_transform: Transform3D = global_transform
	_offset = global_position - target.global_position
	top_level = true
	global_transform = start_transform
	_base_fov = fov

	if target.has_signal(&"landed"):
		target.connect(&"landed", _on_target_landed)
	if target.has_signal(&"facing_changed"):
		target.connect(&"facing_changed", _on_target_facing_changed)
	else:
		push_warning("CameraFollow: o alvo nao tem o sinal facing_changed.")
	# Aplica o limite lateral ja na entrada da cena, sem arrasto inicial.
	snap_to_target()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	delta = minf(delta, 0.05)

	var target_velocity: Vector3 = Vector3.ZERO
	if target is CharacterBody3D:
		target_velocity = (target as CharacterBody3D).velocity
	var horizontal_velocity: Vector3 = Vector3(target_velocity.x, 0.0, target_velocity.z)

	_facing_current = lerpf(_facing_current, _facing_sign, 1.0 - exp(-flip_smoothing * delta))
	var current_offset: Vector3 = _get_mirrored_offset(_facing_current)
	var lead: Vector3 = (horizontal_velocity * look_ahead).limit_length(look_ahead_max)
	var desired: Vector3 = target.global_position + current_offset + lead

	var k_h: float = follow_frequency * follow_frequency
	var c_h: float = 2.0 * damping_ratio * follow_frequency
	var k_v: float = vertical_frequency * vertical_frequency
	var c_v: float = 2.0 * damping_ratio * vertical_frequency

	var displacement: Vector3 = global_position - desired
	var acceleration: Vector3 = Vector3(
		-k_h * displacement.x - c_h * _velocity.x,
		-k_v * displacement.y - c_v * _velocity.y,
		-k_h * displacement.z - c_h * _velocity.z
	)
	_velocity += acceleration * delta
	global_position += _velocity * delta

	# A mola continua ativa, mas o atraso horizontal nao cresce sem limite.
	var lag: Vector3 = global_position - desired
	lag.y = 0.0
	if lag.length_squared() > max_follow_lag * max_follow_lag:
		var limited: Vector3 = lag.limit_length(max_follow_lag)
		global_position = Vector3(desired.x + limited.x, global_position.y, desired.z + limited.z)
		# Remove somente velocidade que empurra ainda mais para fora do limite.
		var outward: Vector3 = lag.normalized()
		var outward_speed: float = _velocity.dot(outward)
		if outward_speed > 0.0:
			_velocity -= outward * outward_speed

	var speed_ratio: float = clampf(horizontal_velocity.length() / maxf(speed_reference, 0.001), 0.0, 1.0)
	var target_fov: float = _base_fov + fov_boost * speed_ratio
	fov = lerpf(fov, target_fov, 1.0 - exp(-fov_smoothing * delta))


func _get_mirrored_offset(side: float) -> Vector3:
	var x: float = _offset.x * (side if mirror_offset else 1.0)
	x += facing_offset * side
	x = clampf(x, -max_side_offset, max_side_offset)
	return Vector3(x, _offset.y, _offset.z)


func _on_target_landed(impact_speed: float) -> void:
	_velocity.y -= clampf(impact_speed * landing_kick, 0.0, landing_kick_max)


func _on_target_facing_changed(facing_right: bool) -> void:
	_facing_sign = 1.0 if facing_right else -1.0


func snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	_velocity = Vector3.ZERO
	_facing_current = _facing_sign
	global_position = target.global_position + _get_mirrored_offset(_facing_current)
