extends Node3D
## Machado que segue uma direção fixa, atravessa inimigos e acerta cada um uma vez.

@export var forca_recuo: float = 8.0
@export_range(0.0, 2.0, 0.05) var desvio_lateral: float = 0.7

var direcao: Vector3 = Vector3.ZERO
var dano: float = 0.0
var velocidade: float = 12.0
var distancia_maxima: float = 12.0
var distancia_percorrida: float = 0.0
var iniciado: bool = false
var alvos_atingidos: Dictionary = {}

@onready var hitbox: Area3D = $Hitbox
@onready var sprite: AnimatedSprite3D = $Sprite3D

func _ready() -> void:
	hitbox.body_entered.connect(_ao_entrar_corpo)
	sprite.play(&"girar")

func iniciar(direcao_inicial: Vector3, dano_inicial: float, velocidade_inicial: float, alcance: float) -> void:
	direcao = direcao_inicial
	direcao.y = 0.0
	direcao = direcao.normalized()
	dano = dano_inicial
	velocidade = maxf(0.1, velocidade_inicial)
	distancia_maxima = maxf(1.0, alcance)
	iniciado = direcao.length_squared() > 0.0

func _physics_process(delta: float) -> void:
	if not iniciado:
		return
	if EstadoJogo.vida_atual <= 0.0:
		queue_free()
		return
	var passo: float = velocidade * delta
	global_position += direcao * passo
	distancia_percorrida += passo
	if distancia_percorrida >= distancia_maxima:
		queue_free()

func _ao_entrar_corpo(corpo: Node3D) -> void:
	if not iniciado or not is_instance_valid(corpo) or not corpo is CharacterBody3D:
		return
	if not corpo.is_in_group("inimigos") or corpo.is_queued_for_deletion() or not corpo.has_method("receber_dano"):
		return
	var vida_antes: Variant = corpo.get("health")
	if vida_antes == null or float(vida_antes) <= 0.0:
		return
	var id: int = corpo.get_instance_id()
	if alvos_atingidos.has(id):
		return
	alvos_atingidos[id] = true
	corpo.call("receber_dano", dano, global_position)
	if not is_instance_valid(corpo) or corpo.is_queued_for_deletion():
		return
	var vida_depois: Variant = corpo.get("health")
	if vida_depois == null or float(vida_depois) <= 0.0:
		return
	# O dano já iniciou o recuo normal. Redireciona-o para tirar o inimigo
	# da frente do machado sem tocar na lógica de morte e XP.
	var inimigo := corpo as CharacterBody3D
	var lateral := Vector3(-direcao.z, 0.0, direcao.x)
	var lado: float = 1.0 if lateral.dot(inimigo.global_position - global_position) >= 0.0 else -1.0
	var impulso: Vector3 = (direcao + lateral * lado * desvio_lateral).normalized() * forca_recuo
	inimigo.velocity.x = impulso.x
	inimigo.velocity.z = impulso.z
