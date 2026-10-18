extends CanvasLayer
## HUD em estilo RPG com Barras de Status e Seleção de Cartas.

var _barra_vida: ProgressBar
var _label_vida: Label
var _barra_xp: ProgressBar
var _label_xp: Label
var _label_dano: Label

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
	# --- PAINEL PRINCIPAL DO HUD (ESTILO RPG) ---
	var hud_painel := PanelContainer.new()
	hud_painel.position = Vector2(20, 20)
	hud_painel.custom_minimum_size = Vector2(340, 110)
	hud_painel.add_theme_stylebox_override("panel", _estilo(Color("0d131d"), Color("2e3b52"), 3))
	add_child(hud_painel)

	var hud_caixa := VBoxContainer.new()
	hud_caixa.add_theme_constant_override("separation", 8)
	hud_painel.add_child(hud_caixa)

	# 1. BARRA DE VIDA (HP)
	var caixa_vida := VBoxContainer.new()
	caixa_vida.add_theme_constant_override("separation", 2)
	hud_caixa.add_child(caixa_vida)

	_label_vida = Label.new()
	_label_vida.text = "HP: 20/20"
	_label_vida.add_theme_font_size_override("font_size", 13)
	_label_vida.add_theme_color_override("font_color", Color("ff6b6b"))
	caixa_vida.add_child(_label_vida)

	_barra_vida = ProgressBar.new()
	_barra_vida.show_percentage = false
	_barra_vida.custom_minimum_size = Vector2(300, 16)
	_estilizar_barra(_barra_vida, Color("b82525"), Color("1a0505"))
	caixa_vida.add_child(_barra_vida)

	# 2. BARRA DE XP
	var caixa_xp := VBoxContainer.new()
	caixa_xp.add_theme_constant_override("separation", 2)
	hud_caixa.add_child(caixa_xp)

	_label_xp = Label.new()
	_label_xp.text = "XP: 0/15"
	_label_xp.add_theme_font_size_override("font_size", 13)
	_label_xp.add_theme_color_override("font_color", Color("4cd137"))
	caixa_xp.add_child(_label_xp)

	_barra_xp = ProgressBar.new()
	_barra_xp.show_percentage = false
	_barra_xp.custom_minimum_size = Vector2(300, 12)
	_barra_xp.max_value = EstadoJogo.XP_POR_CARTA
	_estilizar_barra(_barra_xp, Color("2ed573"), Color("051a0b"))
	caixa_xp.add_child(_barra_xp)

	# 3. INDICADOR DE DANO / STATUS
	_label_dano = Label.new()
	_label_dano.text = "⚔️ Dano: 2"
	_label_dano.add_theme_font_size_override("font_size", 12)
	_label_dano.add_theme_color_override("font_color", Color("f1c40f"))
	hud_caixa.add_child(_label_dano)

	# --- OVERLAY DE SELEÇÃO DE CARTAS ---
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
	dica.text = "XP Máximo Conquistado • Escolha uma melhoria para continuar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(dica)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	coluna.add_child(linha)

	for carta: Dictionary in CARTAS:
		var painel := PanelContainer.new()
		painel.custom_minimum_size = Vector2(260, 380)
		painel.add_theme_stylebox_override("panel", _estilo(Color("202d43"), Color("3b4e6d"), 2))
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

# --- FUNÇÕES DE ESTILIZAÇÃO VIA CÓDIGO ---

func _estilo(cor_fundo: Color, cor_borda: Color = Color.TRANSPARENT, largura_borda: int = 0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor_fundo
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	if largura_borda > 0:
		estilo.draw_center = true
		estilo.border_color = cor_borda
		estilo.set_border_width_all(largura_borda)
	return estilo

func _estilizar_barra(barra: ProgressBar, cor_preenchimento: Color, cor_fundo: Color) -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = cor_fundo
	bg_style.set_corner_radius_all(4)

	var fg_style := StyleBoxFlat.new()
	fg_style.bg_color = cor_preenchimento
	fg_style.set_corner_radius_all(4)

	barra.add_theme_stylebox_override("background", bg_style)
	barra.add_theme_stylebox_override("fill", fg_style)

# --- LÓGICA E ATUALIZAÇÕES ---

func _atualizar_hud() -> void:
	# Atualiza a Barra de Vida
	_barra_vida.max_value = EstadoJogo.vida_maxima
	_barra_vida.value = EstadoJogo.vida_atual
	_label_vida.text = "HP: %.0f / %.0f" % [EstadoJogo.vida_atual, EstadoJogo.vida_maxima]

	# Atualiza a Barra de XP
	_barra_xp.max_value = EstadoJogo.XP_POR_CARTA
	_barra_xp.value = EstadoJogo.xp_atual
	_label_xp.text = "XP: %d / %d  (Total: %d)" % [EstadoJogo.xp_atual, EstadoJogo.XP_POR_CARTA, EstadoJogo.xp_total]

	# Atualiza Status
	_label_dano.text = "⚔️ Dano: %.0f" % EstadoJogo.dano_jogador

func _abrir_cartas() -> void:
	if not _aberto:
		_pausa_anterior = get_tree().paused
		_aberto = true
	get_tree().paused = true
	_overlay.show()
	for botao: Button in _botoes:
		botao.disabled = false
	_botoes[0].grab_focus()

func _selecionar(id: StringName) -> void:
	if not _aberto or not EstadoJogo.escolhendo_carta:
		return
	for botao: Button in _botoes:
		botao.disabled = true
	EstadoJogo.selecionar_carta(id)

func _apos_escolha(_id: StringName) -> void:
	if EstadoJogo.cartas_pendentes > 0:
		return
	_overlay.hide()
	_aberto = false
	get_tree().paused = _pausa_anterior

func _exit_tree() -> void:
	if _aberto:
		get_tree().paused = _pausa_anterior
		EstadoJogo.escolhendo_carta = false
