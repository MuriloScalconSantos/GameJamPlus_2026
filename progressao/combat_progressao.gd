extends "res://player/combat.gd"
## Mantém a mira, o alcance, a recarga e os efeitos originais de player/combat.gd.
## Sincroniza a força do ataque básico com o EstadoJogo (cartas de força).

func _ready() -> void:
	super._ready()
	_sincronizar_dano()
	EstadoJogo.status_alterado.connect(_sincronizar_dano)

func _sincronizar_dano() -> void:
	dano = EstadoJogo.dano_jogador
