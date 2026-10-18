extends Node
## Vida independente da movimentação e da câmera do jogador.

signal health_changed(current: float, maximum: float)
signal died

# A vida inicial e as melhorias ficam em EstadoJogo.
const INVULNERABILIDADE: float = 1.0
const TEMPO_FLASH: float = 0.25
var max_health: float
var health: float
var morto: bool = false
var _invulneravel_restante: float = 0.0

@onready var sprite: SpriteBase3D = get_parent().get_node_or_null("Sprite3D") as SpriteBase3D
@onready var dano_visual: Sprite3D = get_parent().get_node("DanoVisual") as Sprite3D


func _ready() -> void:
	_sincronizar_vida()
	EstadoJogo.status_alterado.connect(_sincronizar_vida)
	process_physics_priority = 100
	_mostrar_vermelho(false)


func _sincronizar_vida() -> void:
	if morto:
		return
	max_health = EstadoJogo.vida_maxima
	health = EstadoJogo.vida_atual
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if morto:
		return
	_invulneravel_restante = maxf(0.0, _invulneravel_restante - delta)
	_copiar_visual()
	if _invulneravel_restante > 0.0:
		var tempo: float = INVULNERABILIDADE - _invulneravel_restante
		var etapa: int = int(tempo / TEMPO_FLASH)
		_mostrar_vermelho(etapa % 2 == 0)
	else:
		_mostrar_vermelho(false)


func receber_dano(amount: float, _origin: Vector3) -> float:
	if morto or health <= 0.0 or amount <= 0.0 or _invulneravel_restante > 0.0 or get_tree().paused:
		return 0.0
	var aplicado: float = minf(amount, health)
	health -= aplicado
	_invulneravel_restante = INVULNERABILIDADE
	EstadoJogo.atualizar_vida(health)
	_copiar_visual()
	_mostrar_vermelho(true)
	if health <= 0.0:
		_morrer()
	return aplicado


func _copiar_visual() -> void:
	if sprite != null:
		dano_visual.transform = sprite.transform
		dano_visual.flip_h = sprite.flip_h


func _mostrar_vermelho(vermelho: bool) -> void:
	if sprite != null:
		sprite.visible = not vermelho
	dano_visual.visible = vermelho


func _morrer() -> void:
	# A morte tem prioridade sobre a piscada e sobre as animações normais.
	morto = true
	_invulneravel_restante = 0.0
	_mostrar_vermelho(true)
	set_physics_process(false)
	var corpo: CharacterBody3D = get_parent() as CharacterBody3D
	corpo.velocity = Vector3.ZERO
	corpo.set_physics_process(false)
	if sprite is AnimatedSprite3D:
		(sprite as AnimatedSprite3D).pause()
	var combate: Node = corpo.get_node("Combat")
	combate.habilitado = false
	combate.clique_pendente = false
	combate.set_physics_process(false)
	combate.set_process_unhandled_input(false)
	EstadoJogo.encerrar_partida()
	died.emit()
