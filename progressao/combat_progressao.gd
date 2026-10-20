extends "res://player/combat.gd"
## Mantém a mira, o alcance, a recarga e os efeitos originais de player/combat.gd.
## Sincroniza a força do ataque básico com o EstadoJogo (cartas de força)
## e a velocidade de ataque com as cartas de Destreza.

func _ready() -> void:
	super._ready()
	_sincronizar_dano()
	EstadoJogo.status_alterado.connect(_sincronizar_dano)

func _sincronizar_dano() -> void:
	dano = EstadoJogo.dano_jogador

## Destreza acelera o ataque: o intervalo real é o export dividido pela
## velocidade de ataque. velocidade_ataque começa em 1.0 e cada carta de
## Destreza soma 0.2, ou seja, +20% de velocidade por carta.
func intervalo_efetivo() -> float:
	var vel_ataque: float = maxf(EstadoJogo.velocidade_ataque, 0.1)
	return intervalo / vel_ataque
