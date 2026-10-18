extends "res://inimigo.gd"
## Mantém o comportamento original do slime (perseguir, pulsar, cabeçada) de inimigo.gd.
## Só aplica a vida/dano do EstadoJogo e dá XP ao jogador quando o inimigo morre.
@export_enum("generico", "aranha", "slime") var tipo_inimigo: String = "slime"

func _ready() -> void:
	# Precisa vir antes do super: inimigo.gd faz health = max_health no _ready.
	if tipo_inimigo == "aranha":
		max_health = EstadoJogo.VIDA_ARANHA
	elif tipo_inimigo == "slime":
		max_health = EstadoJogo.VIDA_SLIME
		attack_damage = EstadoJogo.DANO_SLIME
	super._ready()

func receber_dano(amount: float, origin: Vector3) -> void:
	var estava_vivo: bool = health > 0.0
	super.receber_dano(amount, origin)
	# Só o jogador causa dano aos inimigos; estava_vivo evita XP duplicado no mesmo frame.
	if estava_vivo and health <= 0.0:
		_recompensar_morte()

func _recompensar_morte() -> void:
	if tipo_inimigo == "aranha":
		EstadoJogo.adicionar_xp(EstadoJogo.XP_ARANHA)
	elif tipo_inimigo == "slime":
		EstadoJogo.adicionar_xp(EstadoJogo.XP_SLIME)
