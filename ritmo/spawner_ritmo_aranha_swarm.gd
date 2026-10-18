extends "res://spawner.gd"
## Progressão em ondas de Swarm (Estilo Vampire Survivors) para Aranhas.

@export_group("Ritmo do Swarm")
@export var atraso_inicial: float = 30.0 # Primeira wave bate aos 30 segundos
@export var intervalo_ondas: float = 10.0 # Depois repete a cada 10 segundos
@export var tamanho_onda: int = 30 # 30 aranhas por onda
@export var maximo_absoluto: int = 200 # Limite máximo global em campo

@export_group("Atributos do Swarm")
@export var velocidade_mobs: float = 8.0 # Velocidade ajustada para 8.0
@export var dano_toque: float = 10.0 # Dano que a aranha causa ao tocar no jogador

@export_group("Inimigo")
@export var aranha_scene: PackedScene

var tempo_partida: float = 0.0
var _ate_proximo_swarm: float = 0.0
var _primeira_onda_disparada: bool = false

func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = aranha_scene
	super._ready()
	_ate_proximo_swarm = maxf(0.0, atraso_inicial)

func _process(delta: float) -> void:
	var cena_alvo = aranha_scene if aranha_scene != null else enemy_scene
	if not is_instance_valid(player) or cena_alvo == null or EstadoJogo.vida_atual <= 0.0:
		return

	# Avança o tempo de jogo local do spawner
	tempo_partida += delta
	_ate_proximo_swarm -= delta

	# Dispara a primeira onda exatos 30s e as próximas a cada 10s
	if _ate_proximo_swarm <= 0.0:
		_disparar_swarm_de_aranhas(cena_alvo)
		
		# Se foi a primeira, muda o intervalo para o padrão menor de 10 segundos
		if not _primeira_onda_disparada:
			_primeira_onda_disparada = true
			_ate_proximo_swarm = intervalo_ondas # 10 segundos agora
		else:
			_ate_proximo_swarm = intervalo_ondas

func _disparar_swarm_de_aranhas(cena_alvo: PackedScene) -> void:
	if EstadoJogo.vida_atual <= 0.0:
		return

	# Ponto central aleatório ao redor do jogador onde o enxame vai se originar
	var angulo_base: float = randf_range(0.0, TAU)
	var raio_base: float = randf_range(min_radius, max_radius)
	var centro_swarm := Vector3(cos(angulo_base) * raio_base, 0.0, sin(angulo_base) * raio_base)
	var posicao_central: Vector3 = player.global_position + centro_swarm

	# Instancia as 30 aranhas da onda
	for i in range(tamanho_onda):
		if inimigos_vivos() >= maximo_absoluto:
			break

		var enemy: CharacterBody3D = cena_alvo.instantiate() as CharacterBody3D
		if enemy == null:
			continue

		if "player" in enemy:
			enemy.set("player", player)

		# Aplica velocidade e dano de toque no mob instanciado
		_aplicar_atributo(enemy, ["speed", "move_speed", "velocidade"], velocidade_mobs)
		_aplicar_atributo(enemy, ["damage", "dano", "touch_damage", "dano_toque"], dano_toque)

		get_parent().add_child(enemy)

		# Espalha levemente as aranhas ao redor do centro do enxame
		var dispersao := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		enemy.global_position = posicao_central + dispersao

func _aplicar_atributo(enemy: Node, nomes_possiveis: Array[String], valor: float) -> void:
	for nome_var in nomes_possiveis:
		if nome_var in enemy:
			enemy.set(nome_var, valor)
			break

func inimigos_vivos() -> int:
	var total: int = 0
	for inimigo: Node in get_tree().get_nodes_in_group("inimigos"):
		if not is_instance_valid(inimigo) or inimigo.is_queued_for_deletion():
			continue
		var vida: Variant = inimigo.get("health")
		if vida == null or float(vida) > 0.0:
			total += 1
	return total
