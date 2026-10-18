extends Node3D
const SKILL_CHOICE_SCENE = preload("res://Scenes/Menu/skill/SkillChoice.tscn")
## Um altar por partida; abre a interface de escolha de skills e fecha ao clicar em uma opção.

@export var distancia_minima: float = 50.0
@export var distancia_maxima: float = 100.0
@export var atraso_inicial: float = 1.0
@export_flags_3d_physics var mascara_chao: int = 1
var aberto: bool = false
var _criado: bool = false
var _tempo: float = 0.0
var _jogador: CharacterBody3D

var _quadrado: Sprite3D
var _tela: Control
var _interface_skill: Control
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
		var raio := randf_range(distancia_minima, maxf(distancia_minima, distancia_maxima))
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
		
		# Cria o Sprite3D usando a imagem do altar
		_quadrado = Sprite3D.new()
		_quadrado.name = "AltarClicavel"
		var textura := load("res://Scenes/Menu/skill/altar.png") as Texture2D
		if textura:
			_quadrado.texture = textura
		
		# Ajuste o pixel_size se quiser a imagem maior ou menor no mundo 3D
		_quadrado.pixel_size = 0.003
		_quadrado.shaded = false # Mantém as cores vivas sem sofrer sombra escura do ambiente
		
		add_child(_quadrado)
		_quadrado.global_position = centro
		_criado = true
		return

func _input(event: InputEvent) -> void:
	if aberto:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
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
			_abrir()

func _construir_tela() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 60
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)

	_tela = Control.new()
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_tela)
	_tela.hide()

	_interface_skill = SKILL_CHOICE_SCENE.instantiate() as Control

	if _interface_skill == null:
		push_error("A raiz de SkillChoice.tscn precisa ser um Control.")
		return

	_interface_skill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.add_child(_interface_skill)

	# Conecta automaticamente os botões dos troncos para fechar a interface ao clicar
	var btn_fogo = _interface_skill.get_node_or_null("Tronco 1/Button")
	if btn_fogo:
		btn_fogo.pressed.connect(_fechar)

	var btn_espada = _interface_skill.get_node_or_null("Tronco 2/Button")
	if btn_espada:
		btn_espada.pressed.connect(_fechar)

	var btn_machado = _interface_skill.get_node_or_null("Tronco 3/Button")
	if btn_machado:
		btn_machado.pressed.connect(_fechar)

func _abrir() -> void:
	if aberto or EstadoJogo.escolhendo_carta or FluxoJogo.em_transicao:
		return

	_pausa_anterior = get_tree().paused
	aberto = true

	get_tree().paused = true
	_tela.show()

	if is_instance_valid(_interface_skill):
		_interface_skill.show()

	# Remove o altar 3D do mundo após o clique
	if is_instance_valid(_quadrado):
		_quadrado.queue_free()

func _fechar() -> void:
	if not aberto:
		return

	aberto = false
	_tela.hide()

	get_tree().paused = (
		_pausa_anterior
		or FluxoJogo.pausa_aberta
		or FluxoJogo.em_transicao
		or EstadoJogo.escolhendo_carta
	)

func _exit_tree() -> void:
	if aberto:
		get_tree().paused = _pausa_anterior or FluxoJogo.em_transicao
