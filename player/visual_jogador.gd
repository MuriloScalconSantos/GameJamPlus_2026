class_name VisualJogador
extends AnimatedSprite3D
## Animações e efeitos visuais. Não altera a velocidade física do jogador.

@export_group("Dano")
@export var duracao_dano: float = 0.25
@export var afundamento_dano_cima: float = 0.05

@export_group("Aparência")
@export var forca_mola: float = 220.0
@export var amortecimento_mola: float = 14.0
@export var achatamento_pouso: float = 0.03
@export var achatamento_maximo: float = 0.4
@export var achatamento_derrapagem: float = 0.18
@export var altura_quique: float = 0.06
@export var frequencia_quique: float = 1.6

var _jogador: CharacterBody3D
var _posicao_inicial: Vector3 = Vector3.ZERO
var _direcao_animacao: String = "down"
var _direcao_dano: String = "down"
var _camera_afastada: bool = false
var _tempo_dano: float = 0.0
var _achatamento: float = 0.0
var _velocidade_mola: float = 0.0
var _tempo_quique: float = 0.0


func _ready() -> void:
	_jogador = get_parent() as CharacterBody3D
	_posicao_inicial = position
	flip_h = false
	play(&"idle_down")
	var camera: Node = _jogador.get_node_or_null("Camera3D")
	if camera and camera.has_signal(&"afastamento_alterado"):
		camera.connect(&"afastamento_alterado", _ao_afastar_camera)
	var vida: Node = _jogador.get_node_or_null("Health")
	if vida and vida.has_signal(&"dano_recebido"):
		vida.connect(&"dano_recebido", _ao_receber_dano)


func _ao_afastar_camera(afastada: bool) -> void:
	_camera_afastada = afastada


func _ao_receber_dano(origem: Vector3) -> void:
	var lado_golpe: Vector3 = origem - _jogador.global_position
	if Vector2(lado_golpe.x, lado_golpe.z).length_squared() > 0.0001:
		if absf(lado_golpe.x) >= absf(lado_golpe.z):
			_direcao_dano = "right" if lado_golpe.x > 0.0 else "left"
		else:
			_direcao_dano = "down" if lado_golpe.z > 0.0 else "up"
	else:
		_direcao_dano = _direcao_animacao
	_tempo_dano = maxf(duracao_dano, 0.0)


func reagir_pouso(velocidade_impacto: float) -> void:
	var forca: float = clampf(velocidade_impacto * achatamento_pouso, 0.0, achatamento_maximo)
	_achatamento = maxf(_achatamento, forca)
	_velocidade_mola = 0.0


func reagir_derrapagem() -> void:
	_velocidade_mola += achatamento_derrapagem * 12.0


func atualizar(delta: float, entrada: Vector2, usar_velocidade: bool, velocidade_andar: float) -> void:
	_atualizar_forma(delta, velocidade_andar)
	_tempo_dano = maxf(_tempo_dano - delta, 0.0)
	_atualizar_animacao(entrada, usar_velocidade)


func _atualizar_animacao(entrada: Vector2, usar_velocidade: bool) -> void:
	if _tempo_dano > 0.0:
		var nome_dano: StringName = StringName("hit_" + _direcao_dano)
		if sprite_frames.has_animation(nome_dano):
			flip_h = nome_dano == &"hit_right"
			if animation != nome_dano:
				play(nome_dano)
			return

	var movimento: Vector2 = Vector2(_jogador.velocity.x, _jogador.velocity.z)
	var andando: bool = entrada.length_squared() > 0.0001 or movimento.length_squared() > 0.04
	if andando:
		var direcao: Vector2 = movimento if entrada.length_squared() <= 0.0001 or usar_velocidade else entrada
		if direcao.length_squared() > 0.0001:
			if absf(direcao.x) >= absf(direcao.y):
				_direcao_animacao = "right" if direcao.x > 0.0 else "left"
			else:
				_direcao_animacao = "down" if direcao.y > 0.0 else "up"

	var tipo: String = "idle_"
	if andando:
		tipo = "run_" if _camera_afastada else "walk_"
	var nome: StringName = StringName(tipo + _direcao_animacao)
	if not sprite_frames.has_animation(nome):
		nome = StringName("walk_" + _direcao_animacao)
	flip_h = nome == &"run_left"
	if animation != nome or not is_playing():
		play(nome)


func _atualizar_forma(delta: float, velocidade_andar: float) -> void:
	var forca: float = -_achatamento * forca_mola - _velocidade_mola * amortecimento_mola
	_velocidade_mola += forca * delta
	_achatamento += _velocidade_mola * delta
	scale = Vector3(1.0 + _achatamento * 0.5, 1.0 - _achatamento, 1.0 + _achatamento * 0.5)

	var velocidade: float = Vector2(_jogador.velocity.x, _jogador.velocity.z).length()
	var proporcao: float = clampf(velocidade / maxf(velocidade_andar, 0.001), 0.0, 1.0)
	var quique: float = 0.0
	if _jogador.is_on_floor() and proporcao > 0.05:
		_tempo_quique += delta * velocidade * frequencia_quique
		quique = absf(sin(_tempo_quique)) * altura_quique * proporcao

	var recuo_visual: float = 0.0
	if _tempo_dano > 0.0 and _direcao_dano == "up":
		var progresso: float = 1.0 - _tempo_dano / maxf(duracao_dano, 0.001)
		recuo_visual = -afundamento_dano_cima * sin(progresso * PI)
	position = _posicao_inicial + Vector3(0.0, quique + recuo_visual, 0.0)


##  H A D E S MS