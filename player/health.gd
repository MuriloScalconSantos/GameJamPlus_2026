extends Node
## Vida independente da movimentação e da câmera do jogador.

signal health_changed(current: float, maximum: float)
signal dano_recebido(origem: Vector3)
signal died

@export var max_health: float = 100.0
var health: float
func _ready() -> void:
	health = max_health


func receber_dano(amount: float, origin: Vector3) -> void:
	if health <= 0.0:
		return
	var previous_health: float = health
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health < previous_health:
		dano_recebido.emit(origin)
	if health <= 0.0:
		died.emit()
