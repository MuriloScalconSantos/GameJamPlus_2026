extends Node
## Autoload EstadoJogo: dados da partida, disponíveis em qualquer script.
signal status_alterado
signal escolha_solicitada
signal carta_escolhida(id: StringName)

const VIDA_INICIAL: float = 20.0
const DANO_INICIAL: float = 2.0
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
var partida_encerrada: bool = false
# Espera os dois frames de todos os inimigos que estão morrendo antes de pausar.
var mortes_em_andamento: int = 0

func atualizar_vida(valor: float) -> void:
	vida_atual = clampf(valor, 0.0, vida_maxima)
	status_alterado.emit()

func adicionar_xp(quantidade: int) -> void:
	if quantidade <= 0 or partida_encerrada or vida_atual <= 0.0:
		return
	xp_total += quantidade
	xp_atual += quantidade
	while xp_atual >= XP_POR_CARTA:
		xp_atual -= XP_POR_CARTA
		cartas_pendentes += 1
	print("[XP] +%d | Total: %d | Próxima carta: %d/%d" % [quantidade, xp_total, xp_atual, XP_POR_CARTA])
	status_alterado.emit()
	# Abre a interface após terminar a resolução do golpe e da morte.
	solicitar_carta.call_deferred()

func solicitar_carta() -> void:
	if cartas_pendentes > 0 and not escolhendo_carta and vida_atual > 0.0 and not partida_encerrada and mortes_em_andamento == 0:
		escolhendo_carta = true
		escolha_solicitada.emit()

func selecionar_carta(id: StringName) -> void:
	if not escolhendo_carta or cartas_pendentes <= 0 or partida_encerrada:
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
	print("[CARTA] %s selecionada | Vida %.0f/%.0f | Dano %.0f" % [id, vida_atual, vida_maxima, dano_jogador])
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
	partida_encerrada = false
	mortes_em_andamento = 0
	cartas_selecionadas.clear()
	status_alterado.emit()

func iniciar_morte_inimigo() -> void:
	mortes_em_andamento += 1

func terminar_morte_inimigo() -> void:
	mortes_em_andamento = maxi(0, mortes_em_andamento - 1)
	solicitar_carta.call_deferred()

func encerrar_partida() -> void:
	partida_encerrada = true
	vida_atual = 0.0
	escolhendo_carta = false
	status_alterado.emit()
	get_tree().paused = true
