extends Node3D

@export var distancia_minima: float = 5.0
@export var distancia_maxima: float = 8.0
@export var atraso_inicial: float = 1.0
@export_flags_3d_physics var mascara_chao: int = 1

var aberto: bool = false
var _criado: bool = false
var _tempo: float = 0.0
var _jogador: CharacterBody3D
var _quadrado: MeshInstance3D
var _tela: ColorRect
var _botoes: Array[Button] = []
var _pausa_anterior: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("selecao_cartas_mapa")
	_jogador = get_parent().get_node_or_null("Player") as CharacterBody3D
	_construir_tela()

func _physics_process(delta: float) -> void:
	if get_tree().paused or _criado or not is_instance_valid(_jogador):
		return
		
	_tempo += delta
	
	if _tempo < atraso_inicial or not _jogador.is_on_floor():
		return
		
	_tempo = 0.0
	_sortear_quadrado()

func _sortear_quadrado() -> void:
	var espaco := get_world_3d().direct_space_state
	
	for tentativa in range(40):
		var angulo := randf_range(0.0, TAU)
		
		var raio := randf_range(
			distancia_minima, maxf(distancia_minima, distancia_maxima))
		
		var candidato := _jogador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * raio
		var consulta := PhysicsRayQueryParameters3D.create(candidato + Vector3.UP * 2.0, candidato + Vector3.DOWN * 12.0, mascara_chao)
		consulta.exclude = [_jogador.get_rid()]
		var resultado := espaco.intersect_ray(consulta)
		if resultado.is_empty() or not resultado["collider"] is StaticBody3D:
			continue
		var ponto: Vector3 = resultado["position"]
		var normal: Vector3 = resultado["normal"]
		if normal.y < 0.9 or absf(ponto.y - _jogador.global_position.y) > 2.0:
			continue
		var centro := ponto + Vector3.UP * 0.65
		var visao := PhysicsRayQueryParameters3D.create(_jogador.global_position + Vector3.UP * 0.65, centro, mascara_chao)
		visao.exclude = [_jogador.get_rid()]
		if not espaco.intersect_ray(visao).is_empty():
			continue
		_quadrado = MeshInstance3D.new()
		_quadrado.name = "QuadradoClicavel"
		var malha := BoxMesh.new()
		malha.size = Vector3(1.2, 1.2, 1.2)
		_quadrado.mesh = malha
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("f2c94c")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_quadrado.material_override = material
		add_child(_quadrado)
		_quadrado.global_position = centro
		_criado = true
		print("[QUADRADO] Nasceu na posição: ", _quadrado.global_position)
		return

func _input(event: InputEvent) -> void:
	if aberto:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			print("[CARTAS DO MAPA] Saiu pela tecla ESC.")
			_fechar()
		return
	if get_tree().paused or not is_instance_valid(_quadrado) or EstadoJogo.vida_atual <= 0.0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera := get_viewport().get_camera_3d()
		if camera == null or camera.is_position_behind(_quadrado.global_position):
			return
		var origem := _quadrado.to_local(camera.project_ray_origin(event.position))
		var direcao := _quadrado.global_basis.inverse() * camera.project_ray_normal(event.position)
		if _quadrado.get_aabb().intersects_ray(origem, direcao) != null:
			get_viewport().set_input_as_handled()
			print("[QUADRADO] Clicado pelo jogador.")
			_abrir()

func _construir_tela() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 60
	add_child(camada)
	_tela = ColorRect.new()
	_tela.color = Color(0.02, 0.03, 0.06, 0.94)
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_tela)
	_tela.hide()
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.add_child(centro)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 20)
	centro.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "ESCOLHA UMA CARTA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	coluna.add_child(linha)
	for indice in range(3):
		var conteudo := VBoxContainer.new()
		linha.add_child(conteudo)
		var carta := ColorRect.new()
		carta.color = Color("e8e4dc")
		carta.custom_minimum_size = Vector2(180, 240)
		conteudo.add_child(carta)
		var botao := Button.new()
		botao.text = "SELECIONAR"
		botao.custom_minimum_size.y = 48
		botao.pressed.connect(_selecionar_carta.bind(indice + 1))
		conteudo.add_child(botao)
		_botoes.append(botao)
	var fechar := Button.new()
	fechar.text = "VOLTAR (ESC)"
	fechar.pressed.connect(func(): print("[CARTAS DO MAPA] Saiu pelo botão VOLTAR."))
	fechar.pressed.connect(_fechar)
	coluna.add_child(fechar)

func _abrir() -> void:
	if aberto or EstadoJogo.escolhendo_carta or FluxoJogo.em_transicao:
		return
	_pausa_anterior = get_tree().paused
	aberto = true
	get_tree().paused = true
	_tela.show()
	_botoes[0].grab_focus()
	print("[CARTAS DO MAPA] Tela aberta. Escolha a carta 1, 2 ou 3.")
	
func _selecionar_carta(numero: int) -> void:
	if not aberto:
		return

	print("[CARTAS DO MAPA] Carta %d selecionada. Nenhum efeito aplicado." % numero)
	_fechar()
	
func _fechar() -> void:
	if not aberto:
		return
	aberto = false
	_tela.hide()
	get_tree().paused = _pausa_anterior or FluxoJogo.pausa_aberta or FluxoJogo.em_transicao or EstadoJogo.escolhendo_carta
	
func _exit_tree() -> void:
	if aberto:
		get_tree().paused = _pausa_anterior or FluxoJogo.em_transicao
