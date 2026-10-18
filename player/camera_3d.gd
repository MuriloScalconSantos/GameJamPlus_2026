extends Camera3D
signal pull_out_changed(active: bool)
## Câmera com seguimento por mola (delay + momentum).
## Espelha o offset X quando o jogador vira para a esquerda.
## Se afasta do jogador depois de andar por um tempo contínuo.
## Mantenha a Camera3D como filha do jogador: o script a desacopla sozinho.
## A posição/ângulo definidos no editor determinam o offset e a rotação fixa.
## O offset do editor corresponde ao jogador olhando para a DIREITA.

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
## Menor = mais delay. Maior = acompanha mais rapidamente.
@export var follow_frequency: float = 5.0
## Frequência do eixo vertical.
@export var vertical_frequency: float = 8.0
## 1.0 = sem oscilação. Abaixo de 1.0 permite efeito de mola.
@export_range(0.1, 2.0) var damping_ratio: float = 0.75

# ---------------------------------------------------------------------------
# ESPELHAMENTO HORIZONTAL
# ---------------------------------------------------------------------------
@export_group("Espelhamento")
## Espelha o offset X do editor ao virar para a esquerda.
@export var mirror_offset: bool = true
## Velocidade da troca de lado.
@export var flip_smoothing: float = 6.0
## Deslocamento extra em X na direção em que o jogador olha.
@export var facing_offset: float = 0.0

# ---------------------------------------------------------------------------
# ANTECIPAÇÃO
# ---------------------------------------------------------------------------
@export_group("Antecipação")
## A câmera se adianta na direção do movimento. Zero desliga.
@export var look_ahead: float = 0.15
## Distância máxima da antecipação.
@export var look_ahead_max: float = 1.0

# ---------------------------------------------------------------------------
# AFASTAMENTO
# ---------------------------------------------------------------------------
@export_group("Afastamento")
## Segundos andando sem parar antes da câmera começar a se afastar.
@export var pull_delay: float = 1.0
## Quanto a câmera se afasta (distância extra para trás).
@export var pull_distance: float = 3.0
## Velocidade horizontal mínima para contar como "andando".
@export var move_speed_threshold: float = 0.5
## Velocidade do afastamento (maior = mais rápido).
@export var pull_out_smoothing: float = 2.0
## Velocidade da volta ao normal ao parar.
@export var pull_in_smoothing: float = 4.0

# ---------------------------------------------------------------------------
# FOV
# ---------------------------------------------------------------------------
@export_group("FOV")
## Quanto o FOV aumenta na velocidade de referência. Zero desliga.
## Só age depois do afastamento (após pull_delay andando).
@export var fov_boost: float = 40.0
## Use a velocidade de corrida do jogador.
@export var speed_reference: float = 20.0
@export var fov_smoothing: float = 4.0

# ---------------------------------------------------------------------------
# IMPACTO
# ---------------------------------------------------------------------------
@export_group("Impacto")
## Quanto a câmera afunda ao pousar. Precisa do sinal "landed".
@export var landing_kick: float = 0.6
@export var landing_kick_max: float = 6.0

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------
var _offset: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _base_fov: float = 75.0
var _facing_sign: float = 1.0
var _facing_current: float = 1.0
var _move_time: float = 0.0
var _pull_amount: float = 0.0
var _pull_out_active: bool = false
var _back_direction: Vector3 = Vector3.BACK


func _ready() -> void:
	if target == null:
		target = get_parent() as Node3D

	if target == null:
		push_warning("CameraFollow: nenhum alvo encontrado.")
		set_process(false)
		return

	# Guarda a posição e o ângulo antes de desacoplar do pai.
	var start_transform: Transform3D = global_transform
	_offset = global_position - target.global_position

	# Direção "para trás" da câmera (usada no afastamento).
	_back_direction = start_transform.basis.z.normalized()

	top_level = true
	global_transform = start_transform

	_base_fov = fov

	if target.has_signal(&"landed"):
		target.connect(&"landed", _on_target_landed)

	if target.has_signal(&"facing_changed"):
		target.connect(&"facing_changed", _on_target_facing_changed)
	else:
		push_warning(
			"CameraFollow: o alvo não tem o sinal 'facing_changed'; "
			+ "o espelhamento não vai funcionar."
		)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)

	var target_velocity: Vector3 = Vector3.ZERO

	if target is CharacterBody3D:
		target_velocity = (target as CharacterBody3D).velocity

	var horizontal_velocity: Vector3 = Vector3(
		target_velocity.x,
		0.0,
		target_velocity.z
	)

	# Cronômetro de movimento contínuo: zera ao parar.
	if horizontal_velocity.length() > move_speed_threshold:
		_move_time += delta
	else:
		_move_time = 0.0

	# Só se afasta depois de pull_delay segundos andando.
	var pull_target: float = 1.0 if _move_time >= pull_delay else 0.0
	var pull_out_active: bool = pull_target > 0.0
	if pull_out_active != _pull_out_active:
		_pull_out_active = pull_out_active
		pull_out_changed.emit(_pull_out_active)
	var pull_smoothing: float = (
		pull_out_smoothing if pull_target > _pull_amount
		else pull_in_smoothing
	)

	_pull_amount = lerpf(
		_pull_amount,
		pull_target,
		1.0 - exp(-pull_smoothing * delta)
	)

	# Suaviza a troca de lado.
	_facing_current = lerpf(
		_facing_current,
		_facing_sign,
		1.0 - exp(-flip_smoothing * delta)
	)

	var current_offset: Vector3 = _get_mirrored_offset(
		_facing_current
	)

	# Antecipa a câmera na direção do movimento.
	var lead: Vector3 = (
		horizontal_velocity * look_ahead
	).limit_length(look_ahead_max)

	# Afastamento extra, aplicado só depois do atraso.
	var pull: Vector3 = _back_direction * pull_distance * _pull_amount

	var desired: Vector3 = (
		target.global_position + current_offset + lead + pull
	)

	# Mola amortecida: controla o acompanhamento da câmera.
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

	# FOV aumenta com a velocidade, mas só após o afastamento.
	var speed_ratio: float = clampf(
		horizontal_velocity.length() / speed_reference,
		0.0,
		5.0
	)

	var target_fov: float = (
		_base_fov + fov_boost * speed_ratio * _pull_amount
	)

	fov = lerpf(
		fov,
		target_fov,
		1.0 - exp(-fov_smoothing * delta)
	)


## Offset do editor com X espelhado conforme o lado.
func _get_mirrored_offset(side: float) -> Vector3:
	var x: float = _offset.x * (
		side if mirror_offset else 1.0
	)

	x += facing_offset * side

	return Vector3(x, _offset.y, _offset.z)


func _on_target_landed(impact_speed: float) -> void:
	_velocity.y -= clampf(
		impact_speed * landing_kick,
		0.0,
		landing_kick_max
	)


func _on_target_facing_changed(facing_right: bool) -> void:
	_facing_sign = 1.0 if facing_right else -1.0


## Teleporta a câmera para a posição ideal sem mola.
func snap_to_target() -> void:
	_velocity = Vector3.ZERO
	_facing_current = _facing_sign
	_move_time = 0.0
	_pull_amount = 0.0
	if _pull_out_active:
		_pull_out_active = false
		pull_out_changed.emit(false)

	global_position = (
		target.global_position
		+ _get_mirrored_offset(_facing_current)
	)
