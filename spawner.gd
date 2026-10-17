extends Node3D


@export var player : CharacterBody3D
@export var enemy_scene : PackedScene 


var min_radius : float = 15.0
var max_radius : float = 30.0


var minutes : int = 0
var seconds : int = 0

var time_counter : float = 0.0
var spawn_cooldown : float = 1.0 
var spawn_counter : float = 0.0

func _ready() -> void:
	
	if player == null:
		player = get_tree().current_scene.find_child("Player2", true, false) as CharacterBody3D

func _process(delta: float) -> void:
	
	if not is_inside_tree():
		return


	time_counter += delta
	if time_counter >= 1.0:
		time_counter -= 1.0
		seconds += 1
		if seconds >= 60:
			seconds = 0
			minutes += 1
		
		var time_string = "%02d:%02d" % [minutes, seconds]
		print(time_string)

	
	if player == null:
		return
		
	spawn_counter += delta
	if spawn_counter >= spawn_cooldown:
		spawn_counter = 0.0
		spawn_enemy_in_radius()

func spawn_enemy_in_radius() -> void:
	if not is_inside_tree() or player == null or not player.is_inside_tree() or enemy_scene == null:
		return


	var angle = randf_range(0.0, 2 * PI)
	var dist = randf_range(min_radius, max_radius)
	
	var offset_x = cos(angle) * dist
	var offset_z = sin(angle) * dist
	var spawn_offset = Vector3(offset_x, 0.0, offset_z)
	

	var target_position = player.global_position + spawn_offset
	target_position.y = player.global_position.y 

	
	var enemy_instance = enemy_scene.instantiate()
	

	get_tree().current_scene.add_child(enemy_instance)
	
	
	enemy_instance.global_position = target_position
	
	
	if "player" in enemy_instance:
		enemy_instance.player = player
