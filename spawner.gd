extends Node3D
## Instancia inimigos ao redor do jogador em intervalos regulares.

@export var player: CharacterBody3D
@export var enemy_scene: PackedScene
## Vazio mantém apenas enemy_scene. Preencha para sortear os tipos, como na referência.
@export var tipos_inimigos: Array[PackedScene] = []
@export_range(0.1, 60.0, 0.1) var spawn_cooldown: float = 1.0
@export var min_radius: float = 15.0
@export var max_radius: float = 30.0

var _spawn_counter: float = 0.0


func _ready() -> void:
	if player == null:
		player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if player == null or (enemy_scene == null and tipos_inimigos.is_empty()):
		push_warning("Spawner: configure o Player e a cena do inimigo.")


func _process(delta: float) -> void:
	if not is_instance_valid(player) or (enemy_scene == null and tipos_inimigos.is_empty()):
		return
	_spawn_counter += delta
	if _spawn_counter >= spawn_cooldown:
		_spawn_counter -= spawn_cooldown
		spawn_enemy_in_radius()


func spawn_enemy_in_radius() -> CharacterBody3D:
	if not is_inside_tree() or not is_instance_valid(player) or (enemy_scene == null and tipos_inimigos.is_empty()):
		return null

	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(min_radius, max_radius)
	var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	var spawn_position: Vector3 = player.global_position + offset

	var cena: PackedScene = enemy_scene
	if not tipos_inimigos.is_empty():
		cena = tipos_inimigos.pick_random()
	if cena == null:
		return null
	var enemy: CharacterBody3D = cena.instantiate() as CharacterBody3D
	if enemy == null:
		push_error("Spawner: a cena do inimigo precisa ter CharacterBody3D na raiz.")
		return null

	if "player" in enemy:
		enemy.set("player", player)
	get_parent().add_child(enemy)
	enemy.global_position = spawn_position
	return enemy
