extends Node
## Autoload EstadoJogo: dados da partida, disponíveis em qualquer script.

const VELOCIDADE_INICIAL: float = 100.0
const ATTACK_SPEED_INICIAL: float = 1.0

const VIDA_INICIAL: float = 20.0
const DANO_INICIAL: float = 2.0
const VIDA_ARANHA: float = 1.0
const VIDA_SLIME: float = 4.0
const DANO_SLIME: float = 2.0
const XP_ARANHA: int = 1
const XP_SLIME: int = 2
const XP_POR_CARTA: int = 15

# Pré-carrega as cartas uma única vez para otimizar desempenho e memória
const TODAS_AS_CARTAS: Array[Dictionary] = [
	{"id": &"forca", "titulo": "FORÇA", "texto": "+1 de dano\npara todos os seus ataques.", "imagem": preload("res://progressao/imagens/forca.svg")},
	{"id": &"vitalidade", "titulo": "VITALIDADE", "texto": "+2 de vida máxima\ne recupera 2 de vida.", "imagem": preload("res://progressao/imagens/vitalidade.svg")},
	{"id": &"cura", "titulo": "RECUPERAÇÃO", "texto": "Recupera toda\na sua vida atual.", "imagem": preload("res://progressao/imagens/cura.svg")},
	{"id": &"acelerar", "titulo": "ACELERAR", "texto": "Aumenta a velocidade\nde movimento em 10%.", "imagem": preload("res://progressao/imagens/acelerar.png")},
	{"id": &"destreza", "titulo": "DESTREZA", "texto": "Aumenta a velocidade\nde ataque em 20%.", "imagem": preload("res://progressao/imagens/destreza.png")}
]

var velocidade_movimento: float = VELOCIDADE_INICIAL
var velocidade_ataque: float = ATTACK_SPEED_INICIAL
var cartas_disponiveis_atuais: Array[Dictionary] = [] # Corrigido aqui com o "="

signal status_alterado
signal escolha_solicitada
signal carta_escolhida(id: StringName)

var vida_maxima: float = VIDA_INICIAL
var vida_atual: float = VIDA_INICIAL
var dano_jogador: float = DANO_INICIAL
var xp_total: int = 0
var xp_atual: int = 0
var cartas_pendentes: int = 0
var escolhendo_carta: bool = false
var cartas_selecionadas: Array[StringName] = []

func atualizar_vida(valor: float) -> void:
	vida_atual = clampf(valor, 0.0, vida_maxima)
	status_alterado.emit()

func adicionar_xp(quantidade: int) -> void:
	if quantidade <= 0 or vida_atual <= 0.0:
		return
	xp_total += quantidade
	xp_atual += quantidade
	while xp_atual >= XP_POR_CARTA:
		xp_atual -= XP_POR_CARTA
		cartas_pendentes += 1
	status_alterado.emit()
	solicitar_carta.call_deferred()

func solicitar_carta() -> void:
	if cartas_pendentes > 0 and not escolhendo_carta and vida_atual > 0.0:
		escolhendo_carta = true
		sortear_cartas_aleatorias()
		escolha_solicitada.emit()

func sortear_cartas_aleatorias() -> void:
	var copia_cartas := TODAS_AS_CARTAS.duplicate()
	copia_cartas.shuffle()
	cartas_disponiveis_atuais = copia_cartas.slice(0, 3)

func selecionar_carta(id: StringName) -> void:
	if not escolhendo_carta or cartas_pendentes <= 0:
		return
	match id:
		&"forca":
			dano_jogador += 1.0
		&"vitalidade":
			vida_maxima += 2.0
			vida_atual = minf(vida_maxima, vida_atual + 2.0)
		&"cura":
			vida_atual = vida_maxima
		&"acelerar":
			velocidade_movimento += 0.1
		&"destreza":
			velocidade_ataque += 0.2
		_:
			return
	cartas_selecionadas.append(id)
	cartas_pendentes -= 1
	escolhendo_carta = false
	status_alterado.emit()
	carta_escolhida.emit(id)
	solicitar_carta.call_deferred()

func nova_partida() -> void:
	vida_maxima = VIDA_INICIAL
	vida_atual = VIDA_INICIAL
	dano_jogador = DANO_INICIAL
	velocidade_movimento = VELOCIDADE_INICIAL
	velocidade_ataque = ATTACK_SPEED_INICIAL
	xp_total = 0
	xp_atual = 0
	cartas_pendentes = 0
	escolhendo_carta = false
	cartas_selecionadas.clear()
	status_alterado.emit()
