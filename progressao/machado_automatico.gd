extends Node3D
## Dispara um machado periodicamente na direção do inimigo vivo mais próximo.

const CENA_MACHADO: PackedScene = preload("res://progressao/machado_projetil.tscn")

@export var altura_lancamento: float = 0.65
@export var deslocamento_frente: float = 0.5
@export var alcance_apos_alvo: float = 12.0
@export var forca_recuo: float = 8.0
@export_range(0.0, 2.0, 0.05) var desvio_lateral: float = 0.7

@onready var jogador: CharacterBody3D = get_parent() as CharacterBody3D
@onready var temporizador: Timer = $Temporizador

var intervalo_atual: float = 8.0

func _ready() -> void:
	if jogador == null:
		push_error("MachadoAutomatico precisa ser filho do jogador.")
		return
	temporizador.one_shot = true
	temporizador.timeout.connect(_lancar)
	intervalo_atual = EstadoJogo.intervalo_machado
	EstadoJogo.status_alterado.connect(_atualizar_intervalo)
	# O machado é uma skill comprada: ate a carta ser escolhida, ele nao
	# lanca nada e o temporizador fica parado.
	if EstadoJogo.machado_desbloqueado:
		temporizador.start(intervalo_atual)

func _atualizar_intervalo() -> void:
	if not EstadoJogo.machado_desbloqueado:
		temporizador.stop()
		return
	var novo_intervalo: float = EstadoJogo.intervalo_machado
	if is_equal_approx(intervalo_atual, novo_intervalo):
		# Skill acabou de ser comprada: comeca a contar o tempo ate o 1o lancamento.
		if temporizador.is_stopped():
			temporizador.start(intervalo_atual)
		return
	var fracao_restante: float = temporizador.time_left / intervalo_atual if not temporizador.is_stopped() else 1.0
	intervalo_atual = novo_intervalo
	temporizador.start(maxf(0.01, intervalo_atual * fracao_restante))

func _lancar() -> void:
	if not is_instance_valid(jogador) or EstadoJogo.vida_atual <= 0.0:
		return
	if not EstadoJogo.machado_desbloqueado:
		return
	var alvos: Array[Node3D] = _alvos_proximos(EstadoJogo.quantidade_machados)
	if alvos.is_empty():
		temporizador.start(intervalo_atual)
		return
	var mundo: Node = get_tree().current_scene if get_tree().current_scene != null else jogador.get_parent()
	for alvo: Node3D in alvos:
		var origem: Vector3 = jogador.global_position + Vector3.UP * altura_lancamento
		var vetor: Vector3 = alvo.global_position - origem
		vetor.y = 0.0
		var direcao: Vector3 = vetor.normalized() if vetor.length_squared() > 0.0001 else Vector3.FORWARD
		var posicao_inicial: Vector3 = origem + direcao * deslocamento_frente
		var distancia_alvo: float = maxf(0.0, vetor.length() - deslocamento_frente)
		var projetil: Node3D = CENA_MACHADO.instantiate() as Node3D
		mundo.add_child(projetil)
		projetil.global_position = posicao_inicial
		projetil.set("forca_recuo", forca_recuo)
		projetil.set("desvio_lateral", desvio_lateral)
		projetil.call("iniciar", direcao, EstadoJogo.dano_machado_atual(), EstadoJogo.velocidade_machado, distancia_alvo + alcance_apos_alvo, jogador)
	temporizador.start(intervalo_atual)

## Devolve ate `quantidade` inimigos vivos distintos, do mais proximo para o
## mais distante. Cada machado vai para um alvo diferente: assim a cartela de
## quantidade cobre mais inimigos da multidao em vez de empilhar dano no mesmo.
func _alvos_proximos(quantidade: int) -> Array[Node3D]:
	var candidatos: Array[Node3D] = []
	for candidato: Node in get_tree().get_nodes_in_group("inimigos"):
		if not candidato is Node3D or candidato.is_queued_for_deletion() or not candidato.has_method("receber_dano"):
			continue
		var vida: Variant = candidato.get("health")
		if vida == null or float(vida) <= 0.0:
			continue
		candidatos.append(candidato as Node3D)
	candidatos.sort_custom(_ordenar_por_distancia)
	return candidatos.slice(0, maxi(0, quantidade))

func _ordenar_por_distancia(a: Node3D, b: Node3D) -> bool:
	return _distancia_ao_jogador(a) < _distancia_ao_jogador(b)

func _distancia_ao_jogador(alvo: Node3D) -> float:
	var deslocamento: Vector3 = alvo.global_position - jogador.global_position
	deslocamento.y = 0.0
	return deslocamento.length_squared()
