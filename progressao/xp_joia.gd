extends Node3D
## Cada joia vale 1 XP: salta, espera o jogador e voa até ele para ser coletada.

@export var raio_de_atracao: float = 6.0
@export var velocidade_inicial: float = 4.0
@export var aceleracao: float = 24.0
@export var velocidade_maxima: float = 18.0

const TEMPO_DO_SALTO: float = 0.3
const ALTURA_DO_SALTO: float = 0.45
const TEMPO_DO_BRILHO: float = 0.28
const ENERGIA_DO_BRILHO: float = 2.4
const ALCANCE_DO_BRILHO: float = 2.0
const TEXTURA_DROP: Texture2D = preload("res://Sprites/XP/XPDrop.tres")
const TEXTURA_VOO: Texture2D = preload("res://Sprites/XP/XPVoo.tres")

var jogador: Node3D
var preparada: bool = false
var voando: bool = false
var coletada: bool = false
var tempo: float = 0.0
var tempo_da_coleta: float = 0.0
var velocidade: float = 0.0
var posicao_inicial: Vector3
var posicao_no_chao: Vector3

@onready var sprite: Sprite3D = $Sprite3D
@onready var brilho: OmniLight3D = $Brilho


func preparar(jogador_alvo: Node3D, deslocamento: Vector3) -> void:
	jogador = jogador_alvo
	posicao_inicial = global_position
	posicao_no_chao = posicao_inicial + deslocamento
	velocidade = velocidade_inicial
	preparada = true
	sprite.scale = Vector3.ONE * 0.6


func _physics_process(delta: float) -> void:
	if not preparada or EstadoJogo.vida_atual <= 0.0 or get_tree().paused:
		return

	if coletada:
		_animar_coleta(delta)
		return

	tempo += delta
	if tempo < TEMPO_DO_SALTO:
		_animar_salto()
		return

	if not voando:
		_esperar_jogador()
	else:
		_voar_ate_jogador(delta)


func _animar_salto() -> void:
	# Sai do inimigo em um arco e cresce um pouco ao aparecer.
	var progresso: float = tempo / TEMPO_DO_SALTO
	global_position = posicao_inicial.lerp(posicao_no_chao, progresso)
	global_position.y += sin(progresso * PI) * ALTURA_DO_SALTO
	var tamanho: float = lerpf(0.6, 1.0, progresso) + sin(progresso * PI) * 0.25
	sprite.scale = Vector3.ONE * tamanho


func _esperar_jogador() -> void:
	# A joia fica aqui sem desaparecer, com uma flutuação leve.
	var tempo_no_chao: float = tempo - TEMPO_DO_SALTO
	global_position = posicao_no_chao
	global_position.y += sin(tempo_no_chao * 4.0) * 0.05
	sprite.scale = Vector3.ONE * (1.0 + sin(tempo_no_chao * 4.0) * 0.06)
	if not is_instance_valid(jogador):
		return

	var direcao: Vector3 = jogador.global_position - global_position
	direcao.y = 0.0
	if direcao.length() <= raio_de_atracao:
		voando = true
		sprite.texture = TEXTURA_VOO


func _voar_ate_jogador(delta: float) -> void:
	if not is_instance_valid(jogador):
		return

	# Depois de atraída, continua seguindo mesmo se o jogador se afastar.
	var destino: Vector3 = jogador.global_position + Vector3.UP * 0.6
	var direcao: Vector3 = destino - global_position
	var distancia: float = direcao.length()
	velocidade = minf(velocidade + aceleracao * delta, velocidade_maxima)
	var passo: float = velocidade * delta
	if distancia <= passo:
		global_position = destino
		_coletar()
		return

	# Aqui movemos a posição de um Node3D, então precisamos usar delta.
	global_position += direcao.normalized() * passo
	var tamanho: float = clampf(distancia / 0.8, 0.35, 1.0)
	sprite.scale = Vector3(0.85, 1.15, 1.0) * tamanho


func _coletar() -> void:
	if coletada or EstadoJogo.vida_atual <= 0.0 or get_tree().paused:
		return
	# Marca antes de somar, para a mesma joia nunca entregar XP duas vezes.
	coletada = true
	remove_from_group("joias_xp")
	sprite.texture = TEXTURA_DROP
	sprite.scale = Vector3.ONE * 1.2
	sprite.modulate = Color(1.55, 1.3, 1.8, 1.0)
	brilho.visible = true
	brilho.light_energy = ENERGIA_DO_BRILHO
	brilho.omni_range = ALCANCE_DO_BRILHO
	EstadoJogo.adicionar_xp(1)


func _animar_coleta(delta: float) -> void:
	# Um brilho curto no jogador encerra a coleta.
	tempo_da_coleta += delta
	var progresso: float = minf(tempo_da_coleta / TEMPO_DO_BRILHO, 1.0)
	var restante: float = 1.0 - progresso
	if is_instance_valid(jogador):
		global_position = jogador.global_position + Vector3.UP * 0.6
	var estouro: float = sin(progresso * PI) * 0.3
	var tamanho: float = lerpf(1.2, 1.7, progresso) + estouro
	sprite.scale = Vector3.ONE * tamanho
	sprite.modulate = Color(1.55, 1.3, 1.8, restante)
	brilho.light_energy = ENERGIA_DO_BRILHO * restante
	brilho.omni_range = lerpf(ALCANCE_DO_BRILHO, 3.2, progresso)
	if progresso >= 1.0:
		queue_free()
