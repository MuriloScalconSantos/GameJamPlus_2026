extends "res://player/combat.gd"
## Mantém a mira, o alcance, a recarga e os efeitos originais de player/combat.gd.
## Só sincroniza a força dos ataques (básico e especial) com o EstadoJogo (cartas de força).

func _ready() -> void:
	super._ready()
	_sincronizar_dano()
	EstadoJogo.status_alterado.connect(_sincronizar_dano)

func _sincronizar_dano() -> void:
	dano = EstadoJogo.dano_jogador
	dano_especial = EstadoJogo.dano_jogador
