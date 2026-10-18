extends "res://spawner.gd"
## Progressão por tempo dedicada exclusivamente ao Swarm de Aranhas.

@export_group("Ritmo da partida")
@export var atraso_inicial: float = 15.0 # Começa a spawnar após um tempo de respiro na partida
@export var inicio_etapas: Array[float] = [0.0, 30.0, 60.0, 120.0, 180.0]
@export var intervalos: Array[float] = [2.0, 1.5, 1.0, 0.6, 0.4] # Intervalos menores para gerar mais volume (swarm)
@export var limites: Array[int] = [10, 20, 35, 50, 70] # Limite de aranhas maior em campo
@export_range(1, 200) var maximo_absoluto: int = 70

@export_group("Inimigo")
@export var aranha_scene: PackedScene

var tempo_partida: float = 0.0
var etapa: int = 0
var limite_atual: int = 10
var _ate_spawn: float = 15.0

func _ready() -> void:
	super._ready()
	# Não adicionamos ao grupo "spawner_ritmo" principal se o HUD usa apenas um contador,
	# ou mantemos se quiser que o total de vivos englobe as aranhas.
	_ate_spawn = maxf(0.0, atraso_inicial)
	_atualizar_etapa()

func _process(delta: float) -> void:
	var cena_alvo = aranha_scene if aranha_scene != null else enemy_scene
	if not is_instance_valid(player) or cena_alvo == null or EstadoJogo.vida_atual <= 0.0:
		return

	tempo_partida += delta
	_atualizar_etapa()
	_ate_spawn -= delta
	if _ate_spawn <= 0.0:
		_ate_spawn = spawn_cooldown
		spawn_enemy_in_radius()

func _atualizar_etapa() -> void:
	var quantidade: int = mini(inicio_etapas.size(), mini(intervalos.size(), limites.size()))
	if quantidade == 0:
		spawn_cooldown = 2.0
		limite_atual = mini(10, maximo_absoluto)
		return
	var anterior: int = etapa
	etapa = 0
	for i in range(quantidade):
		if tempo_partida >= inicio_etapas[i]:
			etapa = i
	spawn_cooldown = maxf(0.1, intervalos[etapa])
	limite_atual = clampi(limites[etapa], 1, maximo_absoluto)
	if etapa != anterior:
		_ate_spawn = minf(_ate_spawn, spawn_cooldown)

func inimigos_vivos() -> int:
	var total: int = 0
	for inimigo: Node in get_tree().get_nodes_in_group("inimigos"):
		if not is_instance_valid(inimigo) or inimigo.is_queued_for_deletion():
			continue
		var vida: Variant = inimigo.get("health")
		if vida == null or float(vida) > 0.0:
			total += 1
	return total

func spawn_enemy_in_radius() -> CharacterBody3D:
	var cena_alvo = aranha_scene if aranha_scene != null else enemy_scene
	if EstadoJogo.vida_atual <= 0.0 or inimigos_vivos() >= limite_atual or cena_alvo == null:
		return null

	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(min_radius, max_radius)
	var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	var spawn_position: Vector3 = player.global_position + offset

	var enemy: CharacterBody3D = cena_alvo.instantiate() as CharacterBody3D
	if enemy == null:
		return null

	if "player" in enemy:
		enemy.set("player", player)

	get_parent().add_child(enemy)
	enemy.global_position = spawn_position
	return enemy
