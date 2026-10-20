extends Area3D

## Velocidade fixa aplicada a qualquer corpo dentro da água
@export var velocidade_agua: float = 2.0
@export var fov_agua: float = 50.0

## Corpos dentro DESTA area. Cada instância do script tem o seu próprio.
var corpos_desta_area: Dictionary = {}

## Estado compartilhado entre todas as instancias deste script.
## As areas de agua do mundo se sobrepoem, entao um mesmo corpo pode estar
## dentro de varias areas ao mesmo tempo. Como cada area salva e restaura a
## velocidade original por conta propria, o resultado seria um valor corrompido
## (a segunda area salva a velocidade ja modificada, e a primeira restaura a
## velocidade normal enquanto o corpo ainda esta na agua).
## Com a contagem em `areas`, a velocidade so volta ao normal quando o corpo
## sai da ULTIMA area que o continha.
static var corpos_na_agua: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# Remove corpos que foram destruidos sem sair da area (ex: inimigo morto).
	for body in corpos_desta_area.keys():
		if not is_instance_valid(body):
			corpos_desta_area.erase(body)
			corpos_na_agua.erase(body)

	for body in corpos_desta_area.keys():
		var dados = corpos_na_agua.get(body, {})
		if dados.get("tipo") == "player" and is_instance_valid(dados.get("camera")):
			var cam: Camera3D = dados["camera"]
			cam.fov = lerp(cam.fov, fov_agua, 15.0 * delta)

func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return

	var dados = corpos_na_agua.get(body)
	if dados == null:
		# Primeira area que contem este corpo: guarda os valores originais.
		dados = _guardar_original(body)
		corpos_na_agua[body] = dados
		_aplicar_agua(body, dados)

		# Corta a inercia imediatamente para o player não deslizar com velocidade antiga
		body.velocity.x = 0.0
		body.velocity.z = 0.0

	dados["areas"] += 1
	corpos_desta_area[body] = true

func _on_body_exited(body: Node3D) -> void:
	corpos_desta_area.erase(body)

	var dados = corpos_na_agua.get(body)
	if dados == null:
		return

	dados["areas"] -= 1
	if dados["areas"] > 0:
		# Ainda esta dentro de outra area de agua: mantem a velocidade da agua.
		return

	# Saiu de todas as areas: restaura os valores originais.
	if dados["tipo"] == "player":
		if "multiplicador_original" in dados and "multiplicador_agua" in body:
			body.multiplicador_agua = dados["multiplicador_original"]
		if is_instance_valid(dados.get("camera")):
			dados["camera"].fov = dados["fov_original"]
	elif dados["tipo"] == "enemy" and "speed" in body:
		if "speed_original" in dados:
			body.speed = dados["speed_original"]

	corpos_na_agua.erase(body)

## Guarda os valores originais do corpo e classifica ele como player ou inimigo.
func _guardar_original(body: Node3D) -> Dictionary:
	var dados := {"areas": 0, "tipo": "enemy"}

	# Se for o Jogador
	if "velocidade_andar" in body or "multiplicador_agua" in body:
		dados["tipo"] = "player"
		var cam: Camera3D = _find_camera(body)
		if cam:
			dados["camera"] = cam
			dados["fov_original"] = cam.fov

		if "multiplicador_agua" in body:
			dados["multiplicador_original"] = body.multiplicador_agua
	# Se for Inimigo (Slime / Aranha / etc)
	elif "speed" in body:
		dados["speed_original"] = body.speed

	return dados

## Aplica a lentidao da agua no corpo.
func _aplicar_agua(body: Node3D, dados: Dictionary) -> void:
	if dados["tipo"] == "player":
		if "multiplicador_agua" in body:
			# A velocidade na agua e absoluta (velocidade_agua). Convertemos para
			# multiplicador sobre a velocidade base do player.
			var base: float = body.velocidade_andar if "velocidade_andar" in body else 1.0
			body.multiplicador_agua = clampf(velocidade_agua / maxf(base, 0.001), 0.0, 1.0)
	elif "speed" in body:
		body.speed = velocidade_agua

func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node as Camera3D
	for child in node.get_children():
		var res = _find_camera(child)
		if res:
			return res
	return null
