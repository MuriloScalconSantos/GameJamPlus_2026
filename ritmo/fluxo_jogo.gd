extends Node
## Autoload: transições, pausa por Esc e HUD do tempo de jogo.
const MENU: String = "res://Scenes/Menu/CRTShaderMenuTest.tscn"
const MUNDO: String = "res://Scenes/mundo_teste.tscn"
var pausa_aberta: bool = false
var em_transicao: bool = false
var _painel: ColorRect
var _titulo: Label
var _retomar: Button
var _tempo: Label
var _camada: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_interface()

func em_partida() -> bool:
	var cena: Node = get_tree().current_scene
	return is_instance_valid(cena) and cena.scene_file_path == MUNDO

func _input(event: InputEvent) -> void:
	if em_transicao or not em_partida():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if pausa_aberta:
			retomar()
		else:
			abrir_pausa()

func _process(_delta: float) -> void:
	_tempo.visible = em_partida() and not em_transicao
	if not em_partida() or em_transicao:
		return
	if EstadoJogo.vida_atual <= 0.0 and not pausa_aberta:
		abrir_pausa()
	var spawner: Node = get_tree().get_first_node_in_group("spawner_ritmo")
	if spawner != null:
		var segundos: int = int(spawner.tempo_partida)
		_tempo.text = "%02d:%02d  |  ETAPA %d\nINIMIGOS %d/%d  |  ESC: PAUSA" % [
			segundos / 60, segundos % 60, spawner.etapa + 1,
			spawner.inimigos_vivos(), spawner.limite_atual]

func abrir_pausa() -> void:
	if not em_partida() or em_transicao:
		return
	pausa_aberta = true
	get_tree().paused = true
	_titulo.text = "FIM DA PARTIDA" if EstadoJogo.vida_atual <= 0.0 else "JOGO PAUSADO"
	_retomar.disabled = EstadoJogo.vida_atual <= 0.0
	_painel.show()
	if not _retomar.disabled:
		_retomar.grab_focus()

func retomar() -> void:
	if not pausa_aberta or EstadoJogo.vida_atual <= 0.0 or em_transicao:
		return
	pausa_aberta = false
	_painel.hide()
	# Se as cartas estavam abertas, elas continuam pausando o mundo.
	get_tree().paused = EstadoJogo.escolhendo_carta or EstadoJogo.cartas_pendentes > 0
	if EstadoJogo.escolhendo_carta:
		EstadoJogo.escolha_solicitada.emit()

func iniciar_partida() -> void:
	if em_transicao:
		return
	_trocar_cena.call_deferred(MUNDO)
	em_transicao = true

func retornar_menu() -> void:
	if em_transicao:
		return
	_trocar_cena.call_deferred(MENU)
	em_transicao = true

func _trocar_cena(destino: String) -> void:
	var pausado_antes: bool = get_tree().paused
	get_tree().paused = true
	# Reinício precisa ocorrer antes de criar os componentes do novo jogador.
	if destino == MUNDO:
		EstadoJogo.nova_partida()
	var erro: Error = get_tree().change_scene_to_file(destino)
	if erro != OK:
		em_transicao = false
		get_tree().paused = pausado_antes
		push_error("Não foi possível abrir a cena: " + destino)
		return
	await get_tree().scene_changed
	# A interface antiga das cartas já foi removida antes de liberar a pausa.
	if destino == MENU:
		EstadoJogo.nova_partida()
	pausa_aberta = false
	em_transicao = false
	_painel.hide()
	get_tree().paused = false

func _construir_interface() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 50
	add_child(_camada)
	_tempo = Label.new()
	_camada.add_child(_tempo)
	_tempo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tempo.offset_left = -360
	_tempo.offset_right = -20
	_tempo.offset_top = 20
	_tempo.offset_bottom = 85
	_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tempo.add_theme_font_size_override("font_size", 20)
	_tempo.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tempo.add_theme_constant_override("shadow_offset_x", 2)
	_tempo.add_theme_constant_override("shadow_offset_y", 2)
	_tempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tempo.hide()
	_painel = ColorRect.new()
	_painel.color = Color(0.025, 0.035, 0.065, 0.94)
	_camada.add_child(_painel)
	_painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_painel.hide()
	var centro := CenterContainer.new()
	_painel.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size.x = 340
	caixa.add_theme_constant_override("separation", 18)
	centro.add_child(caixa)
	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 30)
	caixa.add_child(_titulo)
	_retomar = _botao(caixa, "CONTINUAR", retomar)
	_botao(caixa, "REINICIAR PARTIDA", iniciar_partida)
	_botao(caixa, "RETORNAR AO MENU", retornar_menu)
	var aviso := Label.new()
	aviso.text = "Ao reiniciar ou voltar ao menu, a partida atual termina."
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 14)
	caixa.add_child(aviso)

func _botao(caixa: VBoxContainer, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size.y = 50
	botao.pressed.connect(acao)
	caixa.add_child(botao)
	return botao
