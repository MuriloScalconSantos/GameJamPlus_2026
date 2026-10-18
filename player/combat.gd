extends Node3D
## Ataques da branch murilo/movimentacao-combate, separados da movimentação.
## Este nó deve ser filho direto do CharacterBody3D do jogador.

# ---------------------------------------------------------------------------
# SINAIS DE COMBATE
# ---------------------------------------------------------------------------
signal ataque_realizado(direcao: Vector3)
signal alvo_atingido(alvo: Node3D, quantidade: float)
signal especial_realizado(direcao: Vector3)


# ---------------------------------------------------------------------------
# ATAQUE BÁSICO — CLIQUE ESQUERDO
# ---------------------------------------------------------------------------
@export_group("Ataque")
@export var dano: float = 10.0

@export_range(0.1, 20.0, 0.1)
var alcance: float = 7.0

@export_range(1.0, 90.0, 1.0)
var abertura_graus: float = 45.0

@export_range(0.05, 5.0, 0.05)
var intervalo: float = 1.6

@export var habilitado: bool = true

@export_flags_3d_physics
var mascara_paredes: int = 1


# ---------------------------------------------------------------------------
# ESPECIAL AZUL — AUTOMÁTICO
# ---------------------------------------------------------------------------
@export_group("Especial")

@export_range(0.05, 10.0, 0.05)
var intervalo_especial: float = 3.0

@export var dano_especial: float = 10.0

@export var textura_especial: Texture2D = preload(
	"res://Sprites/fogo_azul.png"
)


# ---------------------------------------------------------------------------
# VISUAL DO COMBATE
# ---------------------------------------------------------------------------
@export_group("Visual")

@export var textura_fogo: Texture2D = preload(
	"res://Sprites/fogo.png"
)

@export var altura_ataque: float = 0.65
## Altura do guia de mira (setor laranja) acima do centro do personagem.
## Aumente para subir a mira, diminua para descer. O guia fica sempre paralelo ao chão.
@export var altura_guia: float = 0.35
@export var duracao_efeito: float = 0.18
@export var mostrar_alcance: bool = true


# ---------------------------------------------------------------------------
# ESTADO INTERNO DO COMBATE
# ---------------------------------------------------------------------------
var direcao: Vector3 = Vector3.FORWARD

var recarga: float = 0.0
var recarga_especial: float = 0.0

# Usado somente pelo ataque básico.
var clique_pendente: bool = false

var guia: MeshInstance3D
var linhas := ImmediateMesh.new()

@onready var portador: CharacterBody3D = get_parent() as CharacterBody3D

func _ready() -> void:
	if portador == null:
		push_error("Combate: o nó precisa ser filho de um CharacterBody3D.")
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	_inicializar_combate()


func _physics_process(delta: float) -> void:
	_processar_combate(delta)


# ---------------------------------------------------------------------------
# PREPARAÇÃO DO COMBATE
# ---------------------------------------------------------------------------
func _inicializar_combate() -> void:
	# Básico disponível imediatamente para clicar.
	recarga = 0.0

	# Primeiro especial automático após 3 segundos.
	recarga_especial = intervalo_especial

	clique_pendente = false

	guia = MeshInstance3D.new()
	guia.mesh = linhas

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.65, 0.12)

	guia.material_override = material
	guia.top_level = true
	add_child(guia)


# ---------------------------------------------------------------------------
# ENTRADA — APENAS O BÁSICO USA CLIQUE
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("atacar"):
		clique_pendente = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clique_pendente = false


# ---------------------------------------------------------------------------
# BÁSICO MANUAL E ESPECIAL AUTOMÁTICO
# ---------------------------------------------------------------------------
func _processar_combate(delta: float) -> void:
	_atualizar_mira()
	_atualizar_guia()

	var solicitar_basico := clique_pendente
	clique_pendente = false

	if not habilitado:
		return

	# Recarga do básico: termina e espera um novo clique.
	recarga = maxf(0.0, recarga - delta)

	# Recarga do especial: termina e dispara automaticamente.
	recarga_especial -= delta

	if solicitar_basico and recarga <= 0.0:
		executar_ataque()

	if recarga_especial <= 0.0:
		executar_especial()


# ---------------------------------------------------------------------------
# MIRA PELO MOUSE EM OITO DIREÇÕES
# ---------------------------------------------------------------------------
func _atualizar_mira() -> void:
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	var origem := portador.global_position + Vector3.UP * altura_ataque
	var centro := camera.unproject_position(origem)

	var diferenca := (
		get_viewport().get_mouse_position() - centro
	)

	# Evita mudar a direção com o mouse sobre o personagem.
	if diferenca.length() < 8.0:
		return

	var angulo := snappedf(
		diferenca.angle(),
		PI / 4.0
	)

	var pixel := (
		centro + Vector2.from_angle(angulo) * 100.0
	)

	var plano := Plane(Vector3.UP, origem.y)

	var ponto: Variant = plano.intersects_ray(
		camera.project_ray_origin(pixel),
		camera.project_ray_normal(pixel)
	)

	# Alternativa para câmeras paralelas ao plano do chão.
	if ponto == null:
		var tela := Vector2.from_angle(angulo)

		var direita := camera.global_basis.x
		var tras := camera.global_basis.z

		direita.y = 0.0
		tras.y = 0.0

		var alternativa := (
			direita.normalized() * tela.x
			+ tras.normalized() * tela.y
		)

		if alternativa.length_squared() > 0.0001:
			direcao = alternativa.normalized()

		return

	var vetor: Vector3 = ponto - origem
	vetor.y = 0.0

	if vetor.length_squared() > 0.0001:
		direcao = vetor.normalized()


# ---------------------------------------------------------------------------
# ATAQUE BÁSICO — MANUAL
# ---------------------------------------------------------------------------
func executar_ataque() -> void:
	if not habilitado or recarga > 0.0:
		return

	recarga = intervalo
	_aplicar_golpe(dano, textura_fogo)


# ---------------------------------------------------------------------------
# ESPECIAL AZUL — AUTOMÁTICO
# ---------------------------------------------------------------------------
func executar_especial() -> void:
	if not habilitado or recarga_especial > 0.0:
		return

	# Preserva a fração do passo de física para evitar acumular atraso.
	recarga_especial = maxf(
		0.0,
		recarga_especial + intervalo_especial
	)

	_aplicar_golpe(dano_especial, textura_especial)
	especial_realizado.emit(direcao)


# ---------------------------------------------------------------------------
# DANO COMPARTILHADO PELOS DOIS ATAQUES
# ---------------------------------------------------------------------------
func _aplicar_golpe(
	dano_golpe: float,
	textura_golpe: Texture2D
) -> void:
	var origem := portador.global_position + Vector3.UP * altura_ataque
	var espaco := get_world_3d().direct_space_state

	for candidato in get_tree().get_nodes_in_group("inimigos"):
		if not candidato is Node3D:
			continue

		if not candidato.has_method("receber_dano"):
			continue

		var inimigo := candidato as Node3D

		var ponto_dano := inimigo.get_node_or_null(
			"PontoDano"
		) as Node3D

		var destino: Vector3

		if ponto_dano != null:
			destino = ponto_dano.global_position
		else:
			destino = (
				inimigo.global_position
				+ Vector3.UP * altura_ataque
			)

		var deslocamento := destino - origem

		# Limita a diferença vertical.
		if absf(deslocamento.y) > 1.0:
			continue

		deslocamento.y = 0.0

		# Verifica alcance horizontal.
		if deslocamento.length() > alcance:
			continue

		# Verifica se o alvo está dentro da abertura do ataque.
		if deslocamento.length_squared() > 0.0001:
			var alinhamento := direcao.dot(
				deslocamento.normalized()
			)

			var limite_angular := cos(
				deg_to_rad(abertura_graus * 0.5)
			)

			if alinhamento < limite_angular:
				continue

		# Verifica obstáculos entre jogador e alvo.
		var raio := PhysicsRayQueryParameters3D.create(
			origem,
			destino,
			mascara_paredes
		)

		var ignorados: Array[RID] = [
			portador.get_rid()
		]

		if inimigo is CollisionObject3D:
			ignorados.append(
				(inimigo as CollisionObject3D).get_rid()
			)

		raio.exclude = ignorados

		if not espaco.intersect_ray(raio).is_empty():
			continue

		inimigo.call(
			"receber_dano",
			dano_golpe,
			origem
		)

		alvo_atingido.emit(inimigo, dano_golpe)

	_exibir_fogo(origem, textura_golpe)
	ataque_realizado.emit(direcao)


# ---------------------------------------------------------------------------
# EFEITO VISUAL DO FOGO
# ---------------------------------------------------------------------------
func _exibir_fogo(
	origem: Vector3,
	textura: Texture2D
) -> void:
	var fim := origem + direcao * alcance

	var raio := PhysicsRayQueryParameters3D.create(
		origem,
		fim,
		mascara_paredes
	)

	raio.exclude = [portador.get_rid()]

	var bloqueio := (
		get_world_3d().direct_space_state.intersect_ray(raio)
	)

	if not bloqueio.is_empty():
		fim = bloqueio["position"]

	var fogo := Sprite3D.new()
	fogo.texture = textura
	fogo.pixel_size = 0.0018
	fogo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fogo.no_depth_test = false

	add_child(fogo)

	# O fogo continua sua trajetória independentemente do jogador.
	fogo.top_level = true
	fogo.global_position = origem

	var camera := get_viewport().get_camera_3d()

	if camera != null:
		var vetor_tela := (
			camera.unproject_position(fim)
			- camera.unproject_position(origem)
		)

		fogo.axis = Vector3.AXIS_Z
		fogo.billboard = BaseMaterial3D.BILLBOARD_DISABLED

		fogo.global_basis = camera.global_basis * Basis(
			Vector3.BACK,
			-vetor_tela.angle() - PI / 2.0
		)

	var tween := create_tween().set_parallel(true)

	tween.tween_property(
		fogo,
		"global_position",
		fim,
		duracao_efeito
	)

	tween.tween_property(
		fogo,
		"modulate:a",
		0.0,
		duracao_efeito
	)

	tween.chain().tween_callback(fogo.queue_free)


# ---------------------------------------------------------------------------
# GUIA VISUAL DO ALCANCE
# ---------------------------------------------------------------------------
func _atualizar_guia() -> void:
	guia.visible = mostrar_alcance and habilitado
	linhas.clear_surfaces()

	if not guia.visible:
		return

	# O guia ignora a rotação do jogador/câmera: fica sempre paralelo ao chão.
	guia.global_transform = Transform3D(Basis.IDENTITY, portador.global_position)

	var centro := Vector3(0.0, altura_guia, 0.0)
	var metade := deg_to_rad(abertura_graus * 0.5)

	linhas.surface_begin(Mesh.PRIMITIVE_LINES)

	# Arco externo do setor.
	for i in range(16):
		var angulo_a := lerpf(
			-metade,
			metade,
			float(i) / 16.0
		)

		var angulo_b := lerpf(
			-metade,
			metade,
			float(i + 1) / 16.0
		)

		var a := (
			direcao.rotated(Vector3.UP, angulo_a)
			* alcance
			+ centro
		)

		var b := (
			direcao.rotated(Vector3.UP, angulo_b)
			* alcance
			+ centro
		)

		linhas.surface_add_vertex(a)
		linhas.surface_add_vertex(b)

	# Laterais do setor.
	for angulo in [-metade, metade]:
		linhas.surface_add_vertex(centro)

		linhas.surface_add_vertex(
			centro
			+ direcao.rotated(Vector3.UP, angulo) * alcance
		)

	linhas.surface_end()
