extends Node3D


@export var enemy_scene: PackedScene 


var player: Node3D = null


@export var min_radius: float = 15.0
@export var max_radius: float = 22.0

func _ready() -> void:
	
	player = get_tree().current_scene.find_child("Player2", true, false)
	
	if player == null:
		
		player = get_tree().current_scene.find_child("Player", true, false)
		
	if player == null:
		push_warning("Aviso: O Spawner não conseguiu encontrar o jogador na cena!")

func _on_spawn_timer_timeout() -> void:
	if player == null:
		return
		
	
	var random_angle = randf_range(0.0, 2 * PI)
	var random_distance = randf_range(min_radius, max_radius)
	
	var offset_x = cos(random_angle) * random_distance
	var offset_z = sin(random_angle) * random_distance
	var spawn_offset = Vector3(offset_x, 0.0, offset_z)
	
	
	var spawn_position = player.global_position + spawn_offset
	
	
	spawn_position.y = player.global_position.y 
	
	# 3. Instancia o inimigo caso a cena tenha sido colocada no Inspetor
	if enemy_scene:
		var enemy_instance = enemy_scene.instantiate()
		enemy_instance.global_position = spawn_position
		
		# Adiciona o inimigo direto na cena principal (mundo_teste)
		get_tree().current_scene.add_child(enemy_instance)
