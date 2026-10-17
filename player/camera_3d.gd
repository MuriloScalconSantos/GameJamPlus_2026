extends Camera3D
## Câmera com seguimento por mola (delay + momentum).
## Mantenha a Camera3D como filha do jogador: o script a desacopla sozinho.
## A posição/ângulo que você deixar no editor define o offset e a rotação fixa.

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
# ANTECIPAÇÃO
# ---------------------------------------------------------------------------
@export_group("Antecipação")
## A câmera mira à frente na direção do movimento (0 desliga).
@export var look_ahead: float = 0.3
## Distância máxima da antecipação.
@export var look_ahead_max: float = 3.0

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


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # evita instabilidade da mola em travadas

	var target_velocity: Vector3 = Vector3.ZERO
	if target is CharacterBody3D:
		target_velocity = (target as CharacterBody3D).velocity
	var horizontal_velocity: Vector3 = Vector3(target_velocity.x, 0.0, target_velocity.z)

	# Posição desejada: alvo + offset + antecipação na direção do movimento
	var lead: Vector3 = (horizontal_velocity * look_ahead).limit_length(look_ahead_max)
	var desired: Vector3 = target.global_position + _offset + lead

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


func _on_target_landed(impact_speed: float) -> void:
	_velocity.y -= clampf(impact_speed * landing_kick, 0.0, landing_kick_max)


## Teleporta a câmera para a posição ideal sem mola (use ao dar respawn).
func snap_to_target() -> void:
	_velocity = Vector3.ZERO
	global_position = target.global_position + _offset
