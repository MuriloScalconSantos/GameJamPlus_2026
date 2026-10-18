extends Area3D

## Velocidade fixa aplicada a qualquer corpo dentro da água
@export var velocidade_agua: float = 2.0
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
	if "velocidade_movimento" in EstadoJogo or "velocidade_andar" in body or "multiplicador_agua" in body:
		dados["tipo"] = "player"
		var cam: Camera3D = _find_camera(body)
		if cam:
			dados["camera"] = cam
			dados["fov_original"] = cam.fov
			
		# Salva e força a velocidade de movimento do player para 2.0
		if "multiplicador_agua" in body:
			# Se você usa multiplicador, guardamos o valor atual para restaurar depois
			dados["multiplicador_original"] = body.multiplicador_agua
			body.multiplicador_agua = 0.0 # Zera o multiplicador se ele somar/multiplicar a base, ou ajuste conforme sua engine
		
		if "walk_speed" in body:
			dados["speed_original"] = body.walk_speed
			body.walk_speed = velocidade_agua
		elif "speed" in body:
			dados["speed_original"] = body.speed
			body.speed = velocidade_agua
			
		# Corta a inércia imediatamente para o player não deslizar com velocidade antiga
		body.velocity.x = 0.0
		body.velocity.z = 0.0

	# Se for Inimigo (Slime / Aranha / etc)
	elif "speed" in body:
		dados["tipo"] = "enemy"
		dados["speed_original"] = body.speed
		body.speed = velocidade_agua
		body.velocity.x = 0.0
		body.velocity.z = 0.0

	if not dados.is_empty():
		corpos_na_agua[body] = dados

func _on_body_exited(body: Node3D) -> void:
	if not corpos_na_agua.has(body):
		return
		
	var dados = corpos_na_agua[body]
	
	if dados["tipo"] == "player":
		if "multiplicador_original" in dados and "multiplicador_agua" in body:
			body.multiplicador_agua = dados["multiplicador_original"]
			
		if "walk_speed" in body and "speed_original" in dados:
			body.walk_speed = dados["speed_original"]
		elif "speed" in body and "speed_original" in dados:
			body.speed = dados["speed_original"]

		if is_instance_valid(dados.get("camera")):
			dados["camera"].fov = dados["fov_original"]

	elif dados["tipo"] == "enemy" and "speed" in body:
		if "speed_original" in dados:
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
