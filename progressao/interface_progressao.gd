extends CanvasLayer
## HUD e seleção de cartas. Continua recebendo cliques com o mundo pausado.
var _hud: Label
var _barra: ProgressBar
var _overlay: ColorRect
var _botoes: Array[Button] = []
var _pausa_anterior: bool = false
var _aberto: bool = false

const CARTAS: Array[Dictionary] = [
	{"id": &"forca", "titulo": "FORÇA", "texto": "+1 de dano\npara todos os seus ataques.", "imagem": preload("res://progressao/imagens/forca.svg")},
	{"id": &"vitalidade", "titulo": "VITALIDADE", "texto": "+2 de vida máxima\ne recupera 2 de vida.", "imagem": preload("res://progressao/imagens/vitalidade.svg")},
	{"id": &"cura", "titulo": "RECUPERAÇÃO", "texto": "Recupera toda\na sua vida atual.", "imagem": preload("res://progressao/imagens/cura.svg")}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_construir_interface()
	EstadoJogo.status_alterado.connect(_atualizar_hud)
	EstadoJogo.escolha_solicitada.connect(_abrir_cartas)
	EstadoJogo.carta_escolhida.connect(_apos_escolha)
	_atualizar_hud()
	EstadoJogo.solicitar_carta.call_deferred()

func _construir_interface() -> void:
	var hud_painel := PanelContainer.new()
	hud_painel.position = Vector2(20, 20)
	hud_painel.custom_minimum_size = Vector2(330, 80)
	hud_painel.add_theme_stylebox_override("panel", _estilo(Color("172334")))
	add_child(hud_painel)
	var hud_caixa := VBoxContainer.new()
	hud_painel.add_child(hud_caixa)
	_hud = Label.new()
	_hud.add_theme_color_override("font_color", Color.WHITE)
	hud_caixa.add_child(_hud)
	_barra = ProgressBar.new()
	_barra.max_value = EstadoJogo.XP_POR_CARTA
	_barra.show_percentage = false
	_barra.custom_minimum_size.y = 12
	hud_caixa.add_child(_barra)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.025, 0.035, 0.065, 0.94)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.hide()
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(centro)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 20)
	centro.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "ESCOLHA UMA CARTA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 32)
	titulo.add_theme_color_override("font_color", Color("ffe3a0"))
	coluna.add_child(titulo)
	var dica := Label.new()
	dica.text = "15 XP conquistados • Escolha uma melhoria para continuar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(dica)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	coluna.add_child(linha)
	for carta: Dictionary in CARTAS:
		var painel := PanelContainer.new()
		painel.custom_minimum_size = Vector2(260, 380)
		painel.add_theme_stylebox_override("panel", _estilo(Color("202d43")))
		linha.add_child(painel)
		var conteudo := VBoxContainer.new()
		conteudo.add_theme_constant_override("separation", 16)
		painel.add_child(conteudo)
		var imagem := TextureRect.new()
		imagem.texture = carta["imagem"]
		imagem.custom_minimum_size = Vector2(200, 160)
		imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		conteudo.add_child(imagem)
		var nome := Label.new()
		nome.text = carta["titulo"]
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_font_size_override("font_size", 23)
		conteudo.add_child(nome)
		var descricao := Label.new()
		descricao.text = carta["texto"]
		descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		descricao.size_flags_vertical = Control.SIZE_EXPAND_FILL
		conteudo.add_child(descricao)
		var botao := Button.new()
		botao.text = "SELECIONAR"
		botao.custom_minimum_size.y = 48
		botao.add_theme_font_size_override("font_size", 18)
		botao.pressed.connect(_selecionar.bind(carta["id"]))
		conteudo.add_child(botao)
		_botoes.append(botao)

func _estilo(cor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 18
	estilo.content_margin_bottom = 18
	return estilo

func _atualizar_hud() -> void:
	_hud.text = "VIDA %.0f/%.0f  |  DANO BÁSICO/ESPECIAL %.0f\nXP %d/%d  |  TOTAL %d" % [
		EstadoJogo.vida_atual, EstadoJogo.vida_maxima, EstadoJogo.dano_jogador,
		EstadoJogo.xp_atual, EstadoJogo.XP_POR_CARTA, EstadoJogo.xp_total]
	_barra.value = EstadoJogo.xp_atual
	if EstadoJogo.partida_encerrada:
		_overlay.hide()
		_aberto = false

func _abrir_cartas() -> void:
	if EstadoJogo.partida_encerrada:
		return
	if not _aberto:
		_pausa_anterior = get_tree().paused
		_aberto = true
	get_tree().paused = true
	_overlay.show()
	for botao: Button in _botoes:
		botao.disabled = false
	_botoes[0].grab_focus()

func _selecionar(id: StringName) -> void:
	if not _aberto or not EstadoJogo.escolhendo_carta or EstadoJogo.partida_encerrada:
		return
	for botao: Button in _botoes:
		botao.disabled = true
	EstadoJogo.selecionar_carta(id)

func _apos_escolha(_id: StringName) -> void:
	if EstadoJogo.partida_encerrada:
		return
	if EstadoJogo.cartas_pendentes > 0:
		return # Continua pausado para a próxima escolha pendente.
	_overlay.hide()
	_aberto = false
	get_tree().paused = _pausa_anterior

func _exit_tree() -> void:
	if _aberto and not EstadoJogo.partida_encerrada:
		get_tree().paused = _pausa_anterior
		EstadoJogo.escolhendo_carta = false
