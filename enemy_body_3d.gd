extends Area3D

@export var velocidade_agua: float = 3.0
@export var fov_agua: float = 50.0

var corpos_na_agua: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	for body in corpos_na_agua.keys():
		var dados = corpos_na_agua[body]
		if dados["tipo"] == "player" and "camera" in dados and is_instance_valid(dados["camera"]):
			var cam: Camera3D = dados["camera"]
			cam.fov = lerp(cam.fov, fov_agua, 15.0 * delta)

func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D) or corpos_na_agua.has(body):
		return

	var dados = {}

	if "walk_speed" in body:
		dados["tipo"] = "player"
		dados["speed_original"] = body.walk_speed

		var cam: Camera3D = _find_camera(body)
		if cam:
			dados["camera"] = cam
			dados["fov_original"] = cam.fov

		body.walk_speed = velocidade_agua

	elif "speed" in body:
		dados["tipo"] = "enemy"
		dados["speed_original"] = body.speed
		body.speed = velocidade_agua

	if not dados.is_empty():
		corpos_na_agua[body] = dados

func _on_body_exited(body: Node3D) -> void:
	if not corpos_na_agua.has(body):
		return

	var dados = corpos_na_agua[body]

	if dados["tipo"] == "player":
		if "walk_speed" in body and "speed_original" in dados:
			body.walk_speed = dados["speed_original"]

			var horizontal = Vector3(body.velocity.x, 0.0, body.velocity.z)
			if horizontal.length_squared() > 0.0:
				horizontal = horizontal.normalized() * dados["speed_original"]
				body.velocity.x = horizontal.x
				body.velocity.z = horizontal.z

		if "camera" in dados and is_instance_valid(dados["camera"]):
			dados["camera"].fov = dados["fov_original"]

	elif dados["tipo"] == "enemy" and "speed" in body:
		body.speed = dados["speed_original"]

	corpos_na_agua.erase(body)

func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node as Camera3D
	for child in node.get_children():
		var res = _find_camera(child)
		if res:
			return res
	return null
