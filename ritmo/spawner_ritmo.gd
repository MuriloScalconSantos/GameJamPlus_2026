extends "res://spawner.gd"
## Progressão por tempo. Reutiliza a cena, o raio e a posição do spawner original (spawner.gd).
@export_group("Ritmo da partida")
@export var atraso_inicial: float = 3.0
@export var inicio_etapas: Array[float] = [0.0, 30.0, 60.0, 120.0, 180.0]
@export var intervalos: Array[float] = [3.0, 2.0, 1.5, 1.0, 0.75]
@export var limites: Array[int] = [8, 12, 18, 24, 30]
@export_range(1, 200) var maximo_absoluto: int = 30

var tempo_partida: float = 0.0
var etapa: int = 0
var limite_atual: int = 8
var _ate_spawn: float = 3.0

func _ready() -> void:
	super._ready()
	add_to_group("spawner_ritmo")
	_ate_spawn = maxf(0.0, atraso_inicial)
	_atualizar_etapa()

func _process(delta: float) -> void:
	if not is_instance_valid(player) or enemy_scene == null or EstadoJogo.vida_atual <= 0.0:
		return
	tempo_partida += delta
	_atualizar_etapa()
	_ate_spawn -= delta
	if _ate_spawn <= 0.0:
		# Nunca acumula uma fila de spawns ao atingir o limite ou após uma travada.
		_ate_spawn = spawn_cooldown
		spawn_enemy_in_radius()

func _atualizar_etapa() -> void:
	var quantidade: int = mini(inicio_etapas.size(), mini(intervalos.size(), limites.size()))
	if quantidade == 0:
		spawn_cooldown = 3.0
		limite_atual = mini(8, maximo_absoluto)
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
		print("[RITMO] Etapa %d | Intervalo %.2f s | Limite %d" % [etapa + 1, spawn_cooldown, limite_atual])

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
	if EstadoJogo.vida_atual <= 0.0 or inimigos_vivos() >= limite_atual:
		return null
	return super.spawn_enemy_in_radius()
