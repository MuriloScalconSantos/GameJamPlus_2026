extends Node
## Autoload EstadoJogo: dados da partida, disponíveis em qualquer script.
signal status_alterado
signal escolha_solicitada
signal carta_escolhida(id: StringName)

const VIDA_INICIAL: float = 20.0
const DANO_INICIAL: float = 2.0
const VIDA_ARANHA: float = 1.0
const VIDA_SLIME: float = 4.0
const DANO_SLIME: float = 2.0
const XP_ARANHA: int = 1
const XP_SLIME: int = 2
const XP_POR_CARTA: int = 15

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
	# Abre a interface após terminar a resolução do golpe e da morte.
	solicitar_carta.call_deferred()

func solicitar_carta() -> void:
	if cartas_pendentes > 0 and not escolhendo_carta and vida_atual > 0.0:
		escolhendo_carta = true
		escolha_solicitada.emit()

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
	xp_total = 0
	xp_atual = 0
	cartas_pendentes = 0
	escolhendo_carta = false
	cartas_selecionadas.clear()
	status_alterado.emit()
