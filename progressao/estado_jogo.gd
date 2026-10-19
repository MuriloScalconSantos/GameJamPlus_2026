extends Node
## Autoload EstadoJogo: dados da partida, disponíveis em qualquer script.

const VELOCIDADE_INICIAL: float = 100.0
const ATTACK_SPEED_INICIAL: float = 1.0

const VIDA_INICIAL: float = 6.0
const DANO_INICIAL: float = 2.0
const VIDA_ARANHA: float = 1.0
const VIDA_SLIME: float = 4.0
const DANO_SLIME: float = 2.0
const XP_ARANHA: int = 1
const XP_SLIME: int = 2

# XP base inicial e o acréscimo progressivo por nível
const XP_BASE_INICIAL: int = 10
const XP_INCREMENTO_POR_NIVEL: int = 10

const INTERVALO_MACHADO_INICIAL: float = 8.0
const VELOCIDADE_MACHADO_INICIAL: float = 12.0
const INTERVALO_MACHADO_MINIMO: float = 2.0

# Pré-carrega as cartas uma única vez para otimizar desempenho e memória
const TODAS_AS_CARTAS: Array[Dictionary] = [
	{"id": &"forca", "titulo": "FORÇA", "texto": "+1 de dano\npara todos os seus ataques.", "imagem": preload("res://progressao/imagens/forca.svg")},
	{"id": &"vitalidade", "titulo": "VITALIDADE", "texto": "+2 de vida máxima\ne recupera 2 de vida.", "imagem": preload("res://progressao/imagens/vitalidade.svg")},
	{"id": &"cura", "titulo": "RECUPERAÇÃO", "texto": "Recupera toda\na sua vida atual.", "imagem": preload("res://progressao/imagens/cura.svg")},
	{"id": &"acelerar", "titulo": "ACELERAR", "texto": "Aumenta a velocidade\nde movimento em 10%.", "imagem": preload("res://progressao/imagens/acelerar.png")},
	{"id": &"destreza", "titulo": "DESTREZA", "texto": "Aumenta a velocidade\nde ataque em 20%.", "imagem": preload("res://progressao/imagens/destreza.png")},
	{"id": &"machado_dano", "titulo": "LÂMINA FORTE", "texto": "+1 de dano\npara o machado.", "imagem": preload("res://progressao/imagens/machado_animacao/machado_1.png")},
	{"id": &"machado_velocidade", "titulo": "LÂMINA VELOZ", "texto": "Machado voa 20%\nmais rápido.", "imagem": preload("res://progressao/imagens/machado_animacao/machado_2.png")},
	{"id": &"machado_intervalo", "titulo": "ARREMESSO RÁPIDO", "texto": "Machado sai 2 s\nmais cedo (mín. 2 s).", "imagem": preload("res://progressao/imagens/machado_animacao/machado_3.png")}
]

var velocidade_movimento: float = VELOCIDADE_INICIAL
var velocidade_ataque: float = ATTACK_SPEED_INICIAL
var cartas_disponiveis_atuais: Array[Dictionary] = []

signal status_alterado
signal escolha_solicitada
signal carta_escolhida(id: StringName)
signal abates_alterados(total: int)

var vida_maxima: float = VIDA_INICIAL
var vida_atual: float = VIDA_INICIAL
var dano_jogador: float = DANO_INICIAL
var dano_extra_machado: float = 0.0
var velocidade_machado: float = VELOCIDADE_MACHADO_INICIAL
var intervalo_machado: float = INTERVALO_MACHADO_INICIAL
var xp_total: int = 0
var xp_atual: int = 0
var cartas_pendentes: int = 0
var escolhendo_carta: bool = false
var cartas_selecionadas: Array[StringName] = []
var abates_total: int = 0

# Retorna quanto de XP é necessário para o nível atual com base nas cartas já pegas
func xp_necessario_para_proximo_nivel() -> int:
	return XP_BASE_INICIAL + (cartas_selecionadas.size() * XP_INCREMENTO_POR_NIVEL)

func registrar_abate() -> void:
	abates_total += 1
	abates_alterados.emit(abates_total)

func atualizar_vida(valor: float) -> void:
	vida_atual = clampf(valor, 0.0, vida_maxima)
	status_alterado.emit()

func dano_machado_atual() -> float:
	return dano_jogador + dano_extra_machado

func adicionar_xp(quantidade: int) -> void:
	if quantidade <= 0 or vida_atual <= 0.0:
		return
	xp_total += quantidade
	xp_atual += quantidade
	
	# Loop para lidar caso ganhe XP suficiente para subir múltiplos níveis de uma vez
	while xp_atual >= xp_necessario_para_proximo_nivel():
		xp_atual -= xp_necessario_para_proximo_nivel()
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
			velocidade_movimento += 0.2
		&"destreza":
			velocidade_ataque += 0.2
		&"machado_dano":
			dano_extra_machado += 1.0
		&"machado_velocidade":
			velocidade_machado *= 1.2
		&"machado_intervalo":
			intervalo_machado = maxf(INTERVALO_MACHADO_MINIMO, intervalo_machado - 2.0)
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
	dano_extra_machado = 0.0
	velocidade_machado = VELOCIDADE_MACHADO_INICIAL
	intervalo_machado = INTERVALO_MACHADO_INICIAL
	velocidade_movimento = VELOCIDADE_INICIAL
	velocidade_ataque = ATTACK_SPEED_INICIAL
	xp_total = 0
	xp_atual = 0
	cartas_pendentes = 0
	escolhendo_carta = false
	cartas_selecionadas.clear()
	abates_total = 0
	abates_alterados.emit(abates_total)
	status_alterado.emit()
