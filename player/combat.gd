extends Node3D
## Ataques da branch murilo/movimentacao-combate, separados da movimentação.
## Este nó deve ser filho direto do CharacterBody3D do jogador.

# ---------------------------------------------------------------------------
# SINAIS DE COMBATE
# ---------------------------------------------------------------------------
signal ataque_realizado(direcao: Vector3)
signal alvo_atingido(alvo: Node3D, quantidade: float)

# ------# ---------------------------------------------------------------------------
# ATAQUE BÁSICO — CLIQUE ESQUERDO
# ---------------------------------------------------------------------------
@export_group("Ataque")
@export var dano: float = 10.0
@export_range(0.1, 20.0, 0.1) var alcance: float = 7.0
@export_range(1.0, 90.0, 1.0) var abertura_graus: float = 45.0
@export_range(0.05, 5.0, 0.05) var intervalo: float = 1.6 # <--- Mantém o nome original 'intervalo'
@export var habilitado: bool = true
@export_flags_3d_physics var mascara_paredes: int = 1

var _tempo_recarga: float = 0.0

func _process(delta: float) -> void:
	# Atualiza o tempo de recarga do ataque básico diminuindo com o delta
	if _tempo_recarga > 0.0:
		_tempo_recarga -= delta

# Função que executa o ataque ao receber o clique/input
func tentar_atacar(direcao: Vector3) -> void:
	if not habilitado:
		return
	
	# Calcula o intervalo real baseado na velocidade de ataque do EstadoJogo (Destreza)
	var vel_ataque = max(EstadoJogo.velocidade_ataque, 0.1)
	var intervalo_real = intervalo / vel_ataque
	
	if _tempo_recarga <= 0.0:
		_tempo_recarga = intervalo_real
		
		ataque_realizado.emit(direcao)
		# Insira aqui a sua lógica existente de deteção de alvos com o 'dano_total' e 'alcance'


# ---------------------------------------------------------------------------
# VISUAL DO COMBATE
# ---------------------------------------------------------------------------
@export_group("Visual")

@export var textura_fogo: Texture2D = preload(
	"res://Sprites/ataque_basico.png"
)

@export var altura_ataque: float = 0.65
## Altura do guia de mira (setor laranja) acima do centro do personagem.
## Aumente para subir a mira, diminua para descer. O guia fica sempre paralelo ao chão.
@export var altura_guia: float = 0.35
@export var duracao_efeito: float = 0.18
@export var mostrar_alcance: bool = true
@export var tamanho_imagem: float = 20.0


# ---------------------------------------------------------------------------
# ESTADO INTERNO DO COMBATE
# ---------------------------------------------------------------------------
var direcao: Vector3 = Vector3.FORWARD

var recarga: float = 0.0

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
# BÁSICO MANUAL
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

	if solicitar_basico and recarga <= 0.0:
		executar_ataque()


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
	# O cone laranja é a hitbox do golpe corpo a corpo: atinge todos os
	# inimigos dentro do setor, mesmo que exista um obstáculo entre eles.
	_aplicar_golpe(dano, textura_fogo, true)


# ---------------------------------------------------------------------------
# DANO DO ATAQUE BÁSICO
# ---------------------------------------------------------------------------
func _aplicar_golpe(
	dano_golpe: float,
	textura_golpe: Texture2D,
	golpe_corpo_a_corpo: bool = false
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
		var distancia_alvo := deslocamento.length()
		var raio_alvo := (
			_raio_horizontal_colisor(inimigo)
			if golpe_corpo_a_corpo
			else 0.0
		)

		# A hitbox encosta no alcance conforme o volume do collider, não apenas
		# quando o ponto central do inimigo já cruzou o arco.
		if distancia_alvo > alcance + raio_alvo:
			continue

		# Testa a abertura do cone. No melee, amplia o ângulo pelo raio do
		# collider para atingir inimigos que encostam na borda visível.
		if distancia_alvo > raio_alvo and distancia_alvo > 0.0001:
			var alinhamento := direcao.dot(
				deslocamento.normalized()
			)

			var meia_abertura := deg_to_rad(abertura_graus * 0.5)
			if golpe_corpo_a_corpo:
				meia_abertura += asin(
					clampf(raio_alvo / distancia_alvo, 0.0, 1.0)
				)

			var limite_angular := cos(meia_abertura)

			if alinhamento < limite_angular:
				continue

		# O golpe corpo a corpo usa o setor laranja como área de acerto.
		if not golpe_corpo_a_corpo:
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


func _raio_horizontal_colisor(alvo: Node3D) -> float:
	var raio: float = 0.0
	var colisores := alvo.find_children(
		"*",
		"CollisionShape3D",
		true,
		false
	)
	for no_colisor in colisores:
		var colisor := no_colisor as CollisionShape3D
		if colisor.disabled or colisor.shape == null:
			continue

		var malha: Mesh = colisor.shape.get_debug_mesh()
		if malha == null:
			continue
		var limites: AABB = malha.get_aabb()
		for x in [limites.position.x, limites.end.x]:
			for y in [limites.position.y, limites.end.y]:
				for z in [limites.position.z, limites.end.z]:
					var canto_local := Vector3(x, y, z)
					var canto_global := colisor.global_transform * canto_local
					var deslocamento_horizontal := canto_global - alvo.global_position
					deslocamento_horizontal.y = 0.0
					raio = maxf(raio, deslocamento_horizontal.length())
	return raio


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
	fogo.pixel_size = 0.0055
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
			-vetor_tela.angle() - PI / 0.5
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
