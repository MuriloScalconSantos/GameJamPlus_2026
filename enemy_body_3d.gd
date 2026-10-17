extends CharacterBody3D

@export var speed: float = 6.0
@export var player_path: NodePath = "../Player" 

# --- Novas configurações para desviar de paredes ---
@export var avoid_distance: float = 2.0  # Distância que ele começa a desviar da parede

var player: Node3D = null

func _ready() -> void:
	if has_node(player_path):
		player = get_node(player_path) as Node3D

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if player != null:
		# 1. Direção base até o jogador
		var direction = player.global_position - global_position
		direction.y = 0 
		direction = direction.normalized()
		
		# 2. Aplica o desvio de obstáculos usando Raycasts por código
		direction = avoid_obstacles(direction)
		
		# Movimentação básica
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		if direction != Vector3.ZERO:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

# Função que usa Raycasts por código para calcular uma nova direção livre de paredes
func avoid_obstacles(current_dir: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	
	# Criamos 3 direções de sensores (Frente, Diagonal Esquerda, Diagonal Direita)
	var left_dir = current_dir.rotated(Vector3.UP, deg_to_rad(45))
	var right_dir = current_dir.rotated(Vector3.UP, deg_to_rad(-45))
	
	var ray_dirs = [current_dir, left_dir, right_dir]
	var avoidance_force = Vector3.ZERO
	
	for dir in ray_dirs:
		var target_pos = global_position + dir * avoid_distance
		
		# Configura o raio físico
		var query = PhysicsRayQueryParameters3D.create(global_position, target_pos, collision_mask)
		query.exclude = [get_rid()] # Impede o raio de colidir com o próprio inimigo
		
		var result = space_state.intersect_ray(query)
		
		# Se o raio atingir uma parede, empurra o inimigo para o lado oposto
		if result:
			# Calcula a força de desvio baseada na normal da parede e na proximidade
			var distance_to_wall = global_position.distance_to(result.position)
			var force_multiplier = 1.0 - (distance_to_wall / avoid_distance)
			avoidance_force += result.normal * force_multiplier * 2.0
	
	# Retorna a direção final (original + força de desvio) corrigida na horizontal
	var final_dir = current_dir + avoidance_force
	final_dir.y = 0
	return final_dir.normalized()
