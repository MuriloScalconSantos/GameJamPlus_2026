extends CharacterBody3D
class_name enemy_body_3d 

@export var speed: float = 3.0


var player: CharacterBody3D = null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	
	if player != null:
		var direction = player.global_position - global_position
		direction.y = 0
		direction = direction.normalized()
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		if direction != Vector3.ZERO:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
