extends CharacterBody3D

@export var speed: float = 6.0
@export var detection_distance: float = 1.2
@export_flags_3d_physics var obstacle_collision_mask: int = 1

# Limite de distância ajustado para 30 metros
@export var max_despawn_distance: float = 30.0

# Sistema de Vida do Inimigo
@export var vida_maxima: float = 4.0
var vida_atual: float = 4.0

var player: Node3D = null
var is_initialized: bool = false
var spawn_safe_timer: float = 0.5

var is_avoiding: bool = false
var evasion_direction: Vector3 = Vector3.ZERO
var wall_following_side: int = 0 
var individual_speed: float = 6.0

@onready var push_area: Area3D = get_node_or_null("PushArea")

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("inimigos") # Compatível com o sistema de mira do player
	collision_layer = 0
	collision_mask = 0
	
	vida_atual = vida_maxima
	
	# Variação sutil na velocidade para evitar simetria e travamentos mecânicos
	individual_speed = speed * randf_range(0.9, 1.1)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node3D

func _physics_process(delta: float) -> void:
	if not is_initialized:
		spawn_safe_timer -= delta
		if spawn_safe_timer <= 0:
			collision_layer = 2 
			collision_mask = 1 | 2 | 4
			is_initialized = true
		return

	# --- LIMPEZA AUTOMÁTICA POR DISTÂNCIA (30m) ---
	if player != null:
		var current_distance = global_position.distance_to(player.global_position)
		if current_distance > max_despawn_distance:
			queue_free()
			return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if player != null:
		var space_state = get_world_3d().direct_space_state
		var ray_origin = global_position + Vector3(0, 0.5, 0)
		
		var to_player = player.global_position - global_position
		to_player.y = 0
		var direct_to_player = to_player.normalized()
		
		var move_dir = direct_to_player
		
		if space_state:
			var is_blocked_ahead = is_path_blocked(space_state, ray_origin, direct_to_player, detection_distance)
			
			if is_blocked_ahead or is_avoiding:
				if not is_avoiding:
					is_avoiding = true
					
					var left_dir = direct_to_player.rotated(Vector3.UP, deg_to_rad(80))
					var right_dir = direct_to_player.rotated(Vector3.UP, deg_to_rad(-80))
					
					var left_space = get_free_space_distance(space_state, ray_origin, left_dir, 3.0)
					var right_space = get_free_space_distance(space_state, ray_origin, right_dir, 3.0)
					
					if left_space >= right_space:
						wall_following_side = 1 
					else:
						wall_following_side = -1 
				
				var tangent_angle = 90.0 if wall_following_side == 1 else -90.0
				var tangent_dir = direct_to_player.rotated(Vector3.UP, deg_to_rad(tangent_angle))
				
				if is_path_blocked(space_state, ray_origin, tangent_dir, 1.0):
					wall_following_side *= -1
					tangent_dir = direct_to_player.rotated(Vector3.UP, deg_to_rad(90.0 if wall_following_side == 1 else -90.0))
				
				evasion_direction = tangent_dir
				
				if not is_path_blocked(space_state, ray_origin, direct_to_player, detection_distance + 0.5):
					is_avoiding = false
					move_dir = direct_to_player
				else:
					move_dir = evasion_direction
			else:
				is_avoiding = false
				move_dir = direct_to_player
		
		# Força de repulsão entre os mobs (efeito íman deslizante a menos de 1 metro)
		var push_force = Vector3.ZERO
		if push_area:
			for body in push_area.get_overlapping_bodies():
				if body != self and body.is_in_group("enemy"):
					var away = global_position - body.global_position
					away.y = 0
					var dist = away.length()
					if dist > 0 and dist < 1.0:
						var strength = (1.0 - (dist / 1.0))
						push_force += away.normalized() * strength
		
		# Mescla a direção de movimento com a força de empurrão dos outros mobs
		var final_move_dir = (move_dir + (push_force * 0.8)).normalized()
		
		velocity.x = final_move_dir.x * individual_speed
		velocity.z = final_move_dir.z * individual_speed
		
		# Rotação suave na direção do movimento
		if final_move_dir.length_squared() > 0.0001:
			var target_rotation = atan2(-final_move_dir.x, -final_move_dir.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, individual_speed)
		velocity.z = move_toward(velocity.z, 0, individual_speed)

	move_and_slide()

# --- SISTEMA DE DANO E MORTE ---
func receber_dano(quantidade: float, _origem: Vector3, _atacante: Node3D) -> void:
	vida_atual -= quantidade
	
	if vida_atual <= 0.0:
		morrer()

func morrer() -> void:
	var spawner = get_tree().current_scene.find_child("Spawner", true, false)
	if spawner and spawner.has_method("add_kill"):
		spawner.call("add_kill")
		
	queue_free()

# --- FUNÇÕES DE RADAR E DETECÇÃO ---
func is_path_blocked(space_state: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, dist: float) -> bool:
	var target_pos = origin + (direction * dist)
	
	var query = PhysicsRayQueryParameters3D.create(origin, target_pos, obstacle_collision_mask)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider.is_in_group("enemy"):
			return false
		if player and result.collider == player:
			return false
		return true
		
	return false

func get_free_space_distance(space_state: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, max_dist: float) -> float:
	var target_pos = origin + (direction * max_dist)
	
	var query = PhysicsRayQueryParameters3D.create(origin, target_pos, obstacle_collision_mask)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider.is_in_group("enemy") or (player and result.collider == player):
			return max_dist
		return origin.distance_to(result.position)
		
	return max_dist
