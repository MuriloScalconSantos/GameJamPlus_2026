extends CanvasLayer
## Seleção de cartas. O HUD de vida e XP vive em Scenes/hud.tscn.

var _overlay: ColorRect
var _botoes: Array[Button] = []
var _linha_cartas: HBoxContainer # Referência para atualizar as cartas dinamicamente
var _pausa_anterior: bool = false
var _aberto: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_construir_interface()
	EstadoJogo.escolha_solicitada.connect(_abrir_cartas)
	EstadoJogo.carta_escolhida.connect(_apos_escolha)
	EstadoJogo.solicitar_carta.call_deferred()

func _construir_interface() -> void:
	# Overlay de seleção de cartas, acima do HUD (layer 20).
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

	_linha_cartas = HBoxContainer.new()
	_linha_cartas.add_theme_constant_override("separation", 20)
	coluna.add_child(_linha_cartas)

# --- FUNÇÃO PARA GERAR AS CARTAS DINAMICAMENTE (SORTEADAS) ---

func _atualizar_cartas_visuais() -> void:
	# Limpa as cartas antigas da tela
	for child in _linha_cartas.get_children():
		child.queue_free()
	_botoes.clear()

	# Cria os painéis com base nas cartas sorteadas pelo EstadoJogo
	for carta: Dictionary in EstadoJogo.cartas_disponiveis_atuais:
		var painel := PanelContainer.new()
		painel.custom_minimum_size = Vector2(260, 380)
		painel.add_theme_stylebox_override("panel", _estilo(Color("202d43"), Color("3b4e6d"), 2))
		_linha_cartas.add_child(painel)

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

func _abrir_cartas() -> void:
	if not _aberto:
		_pausa_anterior = get_tree().paused
		_aberto = true
	
	_atualizar_cartas_visuais() # Gera as cartas sorteadas no EstadoJogo
	
	get_tree().paused = true
	_overlay.show()
	for botao: Button in _botoes:
		botao.disabled = false
	if _botoes.size() > 0:
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
