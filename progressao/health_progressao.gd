extends "res://player/health.gd"
## Liga a vida do jogador (player/health.gd) ao Autoload EstadoJogo.
## Sincroniza vida atual/máxima e avisa o EstadoJogo quando há dano.

func _ready() -> void:
	# Ao reabrir a cena depois de morrer, inicia uma nova partida.
	if EstadoJogo.vida_atual <= 0.0:
		EstadoJogo.nova_partida()
	max_health = EstadoJogo.vida_maxima
	super._ready()
	health = EstadoJogo.vida_atual
	EstadoJogo.status_alterado.connect(_sincronizar_vida)

func receber_dano(amount: float, origin: Vector3) -> void:
	super.receber_dano(amount, origin)
	EstadoJogo.atualizar_vida(health)

func _sincronizar_vida() -> void:
	max_health = EstadoJogo.vida_maxima
	health = EstadoJogo.vida_atual
