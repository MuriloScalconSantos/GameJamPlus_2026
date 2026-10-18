extends CharacterBody3D
## Movimento e colisão do jogador. Controles e aparência ficam nos nós filhos.

@export_group("Movimento")
@export var velocidade_andar: float = 5.0
@export var aceleracao: float = 28.0
@export var atrito_chao: float = 22.0
@export_range(0.0, 1.0) var controle_no_ar: float = 0.45
@export var arrasto_no_ar: float = 1.5

@export_group("Derrapagem")
@export var freio_derrapagem: float = 55.0
@export var velocidade_minima_derrapagem: float = 3.5
@export_range(-1.0, 0.0) var limite_oposicao: float = -0.5
@export var manter_lado_na_derrapagem: bool = true
@export_range(0.0, 1.0) var zona_morta_lado: float = 0.1

@export_group("Recuo")
@export var velocidade_recuo: float = 2.5
@export var duracao_recuo: float = 0.12

# Multiplicador temporário (modificado pela água/lama/etc.)
var multiplicador_agua: float = 1.0

signal pousou(velocidade_impacto: float)
signal derrapou
signal lado_alterado(olhando_direita: bool)

@onready var controles: ControlesJogador = $Controles
@onready var visual_jogador: VisualJogador = $Sprite3D

var _derrapando: bool = false
var _olhando_direita: bool = true
var _tempo_recuo: float = 0.0


func _ready() -> void:
	$Health.connect(&"dano_recebido", _ao_receber_dano)


func _physics_process(delta: float) -> void:
	var estava_no_chao: bool = is_on_floor()
	if not estava_no_chao:
		velocity += get_gravity() * delta

	var entrada: Vector2 = controles.ler_direcao()
	var direcao: Vector3 = Vector3(entrada.x, 0.0, entrada.y)
	var tem_entrada: bool = direcao.length_squared() > 0.0001
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var no_chao: bool = is_on_floor()

	# Pega a velocidade base do EstadoJogo (com bônus de cartas) ou a local
	var vel_base: float = EstadoJogo.velocidade_movimento if "velocidade_movimento" in EstadoJogo else velocidade_andar
	var vel_atual: float = vel_base * multiplicador_agua

	if _tempo_recuo > 0.0:
		var freio_recuo: float = velocidade_recuo / maxf(duracao_recuo, 0.001)
		horizontal = horizontal.move_toward(Vector3.ZERO, freio_recuo * delta)
		_tempo_recuo = maxf(_tempo_recuo - delta, 0.0)
		_derrapando = false
	elif tem_entrada:
		var derrapando_agora: bool = false
		if no_chao and horizontal.length() > velocidade_minima_derrapagem:
			var alinhamento: float = horizontal.normalized().dot(direcao.normalized())
			derrapando_agora = alinhamento < limite_oposicao

		if derrapando_agora:
			horizontal = horizontal.move_toward(Vector3.ZERO, freio_derrapagem * delta)
			if not _derrapando:
				derrapou.emit()
				visual_jogador.reagir_derrapagem()
		else:
			var controle: float = 1.0 if no_chao else controle_no_ar
			var velocidade_desejada: Vector3 = direcao * vel_atual
			horizontal = horizontal.move_toward(velocidade_desejada, aceleracao * controle * delta)

		_derrapando = derrapando_agora
		if not (derrapando_agora and manter_lado_na_derrapagem) and absf(entrada.x) > zona_morta_lado:
			_definir_lado(entrada.x > 0.0)
	else:
		_derrapando = false
		var atrito: float = atrito_chao if no_chao else arrasto_no_ar
		horizontal = horizontal.move_toward(Vector3.ZERO, atrito * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var velocidade_queda: float = maxf(-velocity.y, 0.0)
	move_and_slide()

	if is_on_floor() and not estava_no_chao:
		pousou.emit(velocidade_queda)
		visual_jogador.reagir_pouso(velocidade_queda)

	var usar_velocidade: bool = _derrapando and manter_lado_na_derrapagem
	visual_jogador.atualizar(delta, entrada, usar_velocidade, vel_atual)


func _definir_lado(olhando_direita: bool) -> void:
	if olhando_direita == _olhando_direita:
		return
	_olhando_direita = olhando_direita
	lado_alterado.emit(olhando_direita)


func _ao_receber_dano(origem: Vector3) -> void:
	var afastamento: Vector3 = global_position - origem
	afastamento.y = 0.0
	_tempo_recuo = 0.0
	if afastamento.length_squared() <= 0.0001 or velocidade_recuo <= 0.0 or duracao_recuo <= 0.0:
		return
	var direcao_recuo: Vector3 = afastamento.normalized()
	velocity.x = direcao_recuo.x * velocidade_recuo
	velocity.z = direcao_recuo.z * velocidade_recuo
	_tempo_recuo = duracao_recuo
