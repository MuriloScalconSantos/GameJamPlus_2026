extends CharacterBody3D

@export var speed: float = 6.0


@export var player_path: NodePath = "../Player" 
var player: Node3D = null

func _ready() -> void:
	# Busca o jogador na cena ao iniciar
	if has_node(player_path):
		player = get_node(player_path) as Node3D

func _physics_process(delta: float) -> void:
	# Aplica a gravidade padrão do projeto caso o inimigo esteja no ar
	if not is_on_floor():
		velocity += get_gravity() * delta

	if player != null:
		
		var direction = player.global_position - global_position
		direction.y = 0 
		direction = direction.normalized()
		
		# 2. Define a velocidade horizontal
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		
		if direction != Vector3.ZERO:
			
			look_at(global_position + direction, Vector3.UP)
	else:
		
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	
	move_and_slide()
