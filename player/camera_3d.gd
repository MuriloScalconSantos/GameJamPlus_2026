extends Camera3D
## Câmera com seguimento por mola (delay + momentum).
## Espelha o offset X (ex.: 1.30 -> -1.30) quando o jogador vira para a esquerda.
## Mantenha a Camera3D como filha do jogador: o script a desacopla sozinho.
## A posição/ângulo que você deixar no editor define o offset e a rotação fixa
## (o offset do editor corresponde ao jogador olhando para a DIREITA).

# ---------------------------------------------------------------------------
# ALVO
# ---------------------------------------------------------------------------
@export_group("Alvo")
## Se vazio, usa o nó pai (o jogador).
@export var target: Node3D

# ---------------------------------------------------------------------------
# MOLA
# ---------------------------------------------------------------------------
@export_group("Mola")
## Menor = mais delay e mais "preguiçosa". Maior = mais colada no jogador.
@export var follow_frequency: float = 5.0
## Frequência do eixo vertical (maior evita lag exagerado em rampas e quedas).
@export var vertical_frequency: float = 8.0
## 1.0 = sem oscilação. Abaixo de 1.0 a câmera "passa do ponto" e volta (efeito mola).
@export_range(0.1, 2.0) var damping_ratio: float = 0.75

# ---------------------------------------------------------------------------
# ESPELHAMENTO HORIZONTAL
# ---------------------------------------------------------------------------
@export_group("Espelhamento")
## Espelha o offset X do editor ao virar para a esquerda (1.30 -> -1.30).
@export var mirror_offset: bool = true
## Velocidade da troca de lado. Menor = troca mais lenta e suave.
@export var flip_smoothing: float = 6.0
## Deslocamento extra em X na direção em que o jogador olha (0 = só espelha o offset).
@export var facing_offset: float = 0.0

# ---------------------------------------------------------------------------
# ANTECIPAÇÃO
# ---------------------------------------------------------------------------
@export_group("Antecipação")
## A câmera mira à frente na direção do movimento (0 desliga).
@export var look_ahead: float = 0.15
## Distância máxima da antecipação.
@export var look_ahead_max: float = 1.0

# ---------------------------------------------------------------------------
# FOV
# ---------------------------------------------------------------------------
@export_group("FOV")
## Quanto o FOV aumenta na velocidade máxima (0 desliga).
@export var fov_boost: float = 6.0
## Velocidade que corresponde ao FOV máximo (use o run_speed do jogador).
@export var speed_reference: float = 9.0
@export var fov_smoothing: float = 4.0

# ---------------------------------------------------------------------------
# IMPACTO
# ---------------------------------------------------------------------------
@export_group("Impacto")
## Quanto a câmera afunda ao pousar (0 desliga). Precisa do sinal "landed" no jogador.
@export var landing_kick: float = 0.6
@export var landing_kick_max: float = 6.0

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------
var _offset: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _base_fov: float = 75.0
var _facing_sign: float = 1.0     # alvo: 1 = direita, -1 = esquerda
var _facing_current: float = 1.0  # valor suavizado entre 1 e -1


func _ready() -> void:
	if target == null:
		target = get_parent() as Node3D
	if target == null:
		push_warning("CameraFollow: nenhum alvo encontrado.")
		set_process(false)
		return

	# Guarda a posição/ângulo definidos no editor antes de desacoplar do pai.
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
		push_warning("CameraFollow: o alvo não tem o sinal 'facing_changed'; o espelhamento não vai funcionar.")


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # evita instabilidade da mola em travadas

	var target_velocity: Vector3 = Vector3.ZERO
	if target is CharacterBody3D:
		target_velocity = (target as CharacterBody3D).velocity
	var horizontal_velocity: Vector3 = Vector3(target_velocity.x, 0.0, target_velocity.z)

	# Suaviza a troca de lado (1 -> -1) e monta o offset espelhado
	_facing_current = lerpf(_facing_current, _facing_sign, 1.0 - exp(-flip_smoothing * delta))
	var current_offset: Vector3 = _get_mirrored_offset(_facing_current)

	# Posição desejada: alvo + offset espelhado + antecipação na direção do movimento
	var lead: Vector3 = (horizontal_velocity * look_ahead).limit_length(look_ahead_max)
	var desired: Vector3 = target.global_position + current_offset + lead

	# Mola amortecida: aceleração = -k * deslocamento - c * velocidade
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

	# FOV aumenta com a velocidade
	var speed_ratio: float = clampf(horizontal_velocity.length() / speed_reference, 0.0, 1.0)
	var target_fov: float = _base_fov + fov_boost * speed_ratio
	fov = lerpf(fov, target_fov, 1.0 - exp(-fov_smoothing * delta))


## Offset do editor com o X espelhado conforme o lado (1 = direita, -1 = esquerda).
func _get_mirrored_offset(side: float) -> Vector3:
	var x: float = _offset.x * (side if mirror_offset else 1.0)
	x += facing_offset * side
	return Vector3(x, _offset.y, _offset.z)


func _on_target_landed(impact_speed: float) -> void:
	_velocity.y -= clampf(impact_speed * landing_kick, 0.0, landing_kick_max)


func _on_target_facing_changed(facing_right: bool) -> void:
	_facing_sign = 1.0 if facing_right else -1.0


## Teleporta a câmera para a posição ideal sem mola (use ao dar respawn).
func snap_to_target() -> void:
	_velocity = Vector3.ZERO
	_facing_current = _facing_sign
	global_position = target.global_position + _get_mirrored_offset(_facing_current)
