extends Node3D

@export var player: CharacterBody3D
@export var enemy_scene: PackedScene
@export var tipos_inimigos: Array[PackedScene] = []

# Ritmo inicial lento (1 a cada 3.5 segundos) e limite para estabilizar em 3.0 segundos
@export_range(0.1, 60.0, 0.1) var spawn_cooldown: float = 3.5
@export var target_spawn_cooldown: float = 3.0
@export var kills_for_max_tempo: int = 20 # Quantas interações/abates necessários para atingir o ritmo de 3.0s

@export var min_radius: float = 15.0
@export var max_radius: float = 30.0

var _spawn_counter: float = 0.0
var progresso_kills: int = 0


func _ready() -> void:
	if player == null:
		player = get_tree().current_scene.find_child("Player2", true, false) as CharacterBody3D
	if player == null:
		player = get_parent().get_node_or_null("Player") as CharacterBody3D
		
	if player == null:
		push_warning("Spawner: configure o Player.")
		return
		
	if enemy_scene == null and tipos_inimigos.is_empty():
		push_warning("Spawner: configure a cena do inimigo.")

	# Conecta-se automaticamente ao sistema de combate do player para contar o progresso
	var combate = player.find_child("Combate", true, false) # Ajuste o nome do nó de combate se necessário
	if not combate:
		# Procura por qualquer nó que tenha o sinal alvo_atingido
		for child in player.get_children():
			if child.has_signal("alvo_atingido"):
				combate = child
				break
				
	if combate and combate.has_signal("alvo_atingido"):
		combate.alvo_atingido.connect(_on_alvo_atingido)


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


# Chamado automaticamente quando o player atinge um inimigo (ou você pode adaptar para quando o inimigo morrer)
# Substitua a função _on_alvo_atingido no seu spawner por esta:
func _on_alvo_atingido(_alvo: Node3D, _quantidade: float) -> void:
	progresso_kills += 1
	
	var fator = clampf(float(progresso_kills) / float(kills_for_max_tempo), 0.0, 1.0)
	spawn_cooldown = lerp(3.5, target_spawn_cooldown, fator)
