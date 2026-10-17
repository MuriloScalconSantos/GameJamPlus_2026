extends Node
## Vida independente da movimentação e da câmera do jogador.

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
var health: float
var _flash_tween: Tween

@onready var sprite: SpriteBase3D = get_parent().get_node_or_null("Sprite3D") as SpriteBase3D


func _ready() -> void:
	health = max_health


func receber_dano(amount: float, _origin: Vector3) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if sprite != null:
		if _flash_tween != null and _flash_tween.is_running():
			_flash_tween.kill()
		sprite.modulate = Color(1.0, 0.4, 0.4)
		_flash_tween = create_tween()
		_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if health <= 0.0:
		died.emit()
