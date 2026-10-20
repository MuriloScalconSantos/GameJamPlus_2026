extends "res://inimigo.gd"
## Mantém o comportamento original do slime (perseguir, pulsar, cabeçada) de inimigo.gd.
## Só aplica a vida/dano do EstadoJogo e deixa joias de XP quando o inimigo morre.
const CENA_JOIA_XP: PackedScene = preload("res://progressao/xp_joia.tscn")

@export_enum("generico", "aranha", "slime") var tipo_inimigo: String = "slime"

func _ready() -> void:
	# Precisa vir antes do super: inimigo.gd faz health = max_health no _ready.
	if tipo_inimigo == "aranha":
		max_health = EstadoJogo.VIDA_ARANHA
	elif tipo_inimigo == "slime":
		max_health = EstadoJogo.VIDA_SLIME
		attack_damage = EstadoJogo.DANO_SLIME
	super._ready()

func receber_dano(amount: float, origin: Vector3, autor: Node = null) -> void:
	var estava_vivo: bool = health > 0.0
	super.receber_dano(amount, origin, autor)
	# Só o jogador causa dano aos inimigos; estava_vivo evita XP duplicado no mesmo frame.
	if estava_vivo and health <= 0.0:
		_recompensar_morte(autor)

func _recompensar_morte(_autor: Node = null) -> void:
	# Mantém a recompensa existente, mas entrega XP somente ao coletar as joias.
	var quantidade: int = 0
	if tipo_inimigo == "aranha":
		quantidade = EstadoJogo.XP_ARANHA
	elif tipo_inimigo == "slime":
		quantidade = EstadoJogo.XP_SLIME
	if quantidade <= 0 or EstadoJogo.vida_atual <= 0.0:
		return

	var angulo_inicial: float = randf_range(0.0, TAU)
	for numero in range(quantidade):
		var joia = CENA_JOIA_XP.instantiate()
		var angulo: float = angulo_inicial + TAU * numero / quantidade
		var deslocamento := Vector3(cos(angulo), 0.0, sin(angulo)) * 0.35
		# Filha do mundo: não desaparece junto com o inimigo.
		get_parent().add_child(joia)
		joia.global_position = global_position + Vector3.UP * 0.28
		joia.preparar(player, deslocamento)
