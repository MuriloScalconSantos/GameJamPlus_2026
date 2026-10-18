extends Area3D

## Fator de desaceleração (0.5 = reduz para a metade / 50%)
@export_range(0.1, 1.0, 0.05) var fator_desaceleracao: float = 0.5
@export var fov_agua: float = 50.0

var corpos_na_agua: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	for body in corpos_na_agua.keys():
		var dados = corpos_na_agua[body]
		if dados["tipo"] == "player" and is_instance_valid(dados.get("camera")):
			var cam: Camera3D = dados["camera"]
			cam.fov = lerp(cam.fov, fov_agua, 15.0 * delta)

func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D) or corpos_na_agua.has(body):
		return
		
	var dados := {}

	# Se for o Jogador
	if "velocidade_movimento" in EstadoJogo or "velocidade_andar" in body:
		dados["tipo"] = "player"
		var cam: Camera3D = _find_camera(body)
		if cam:
			dados["camera"] = cam
			dados["fov_original"] = cam.fov
			
		# Aplica o multiplicador de água no player (se ele tiver essa variável)
		if "multiplicador_agua" in body:
			body.multiplicador_agua = fator_desaceleracao
		elif "walk_speed" in body:
			dados["speed_original"] = body.walk_speed
			body.walk_speed *= fator_desaceleracao
			
		# Corta a inércia imediatamente dividindo a velocidade atual
		body.velocity.x *= fator_desaceleracao
		body.velocity.z *= fator_desaceleracao

	# Se for Inimigo (Slime / Aranha / etc)
	elif "speed" in body:
		dados["tipo"] = "enemy"
		dados["speed_original"] = body.speed
		body.speed *= fator_desaceleracao
		body.velocity.x *= fator_desaceleracao
		body.velocity.z *= fator_desaceleracao

	if not dados.is_empty():
		corpos_na_agua[body] = dados

func _on_body_exited(body: Node3D) -> void:
	if not corpos_na_agua.has(body):
		return
		
	var dados = corpos_na_agua[body]
	
	if dados["tipo"] == "player":
		if "multiplicador_agua" in body:
			body.multiplicador_agua = 1.0
		elif "walk_speed" in body and "speed_original" in dados:
			body.walk_speed = dados["speed_original"]

		if is_instance_valid(dados.get("camera")):
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
