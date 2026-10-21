extends "res://spawner.gd"
## Progressão em ondas de Swarm (Estilo Vampire Survivors) para Aranhas.

@export_group("Ritmo do Swarm")
## Piso de tempo antes da primeira onda. A onda real cai entre
## `atraso_inicial` e `atraso_inicial + aleatoriedade_primeira_onda`.
@export var atraso_inicial: float = 30.0
## Janela de aleatoriedade da primeira onda. Com 30.0 a 1a onda cai entre
## 30s e 60s de partida.
@export var aleatoriedade_primeira_onda: float = 30.0
@export var intervalo_ondas: float = 10.0 # Depois repete a cada 10 segundos
## A onda cresce com a progressao do jogador: base + 4 por cartela pego,
## ate o teto. Sem isso a 1a onda (12 aranhas) ja mataria o jogador nos
## primeiros minutos, quando ele ainda nao tem nenhuma cartela.
@export var tamanho_onda_base: int = 12
@export var tamanho_onda_por_carta: int = 4
@export var tamanho_onda_maximo: int = 30
@export var maximo_absoluto: int = 200 # Limite máximo global em campo

@export_group("Atributos do Swarm")
@export var velocidade_mobs: float = 8.0 # Velocidade ajustada para 8.0
## Dano por toque da aranha. Precisa casar com `attack_damage` da
## aranhapequena.gd (5.0): o valor antigo 10.0 era uma export morta (a
## aranha nao tem atributo `dano`/`dano_toque`), e se alguem "consertasse" o
## nome do atributo viraria 10 de dano por toque.
@export var dano_toque: float = 5.0

@export_group("Inimigo")
@export var aranha_scene: PackedScene
## Grupo usado para contar os inimigos deste spawner. Contar so os inimigos do
## proprio tipo evita que um spawner consuma o budget do outro (a aranha parava
## de spawnar assim que os slimes passavam do limite deles).
@export var grupo_contagem: StringName = &"aranhas_pequenas"

var tempo_partida: float = 0.0
var _ate_proximo_swarm: float = 0.0

func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = aranha_scene
	super._ready()
	# A primeira onda cai em um momento aleatorio dentro da janela, para que
	# o jogador nao previsivelmente apanhe no mesmo instante toda partida.
	var janela: float = maxf(0.0, aleatoriedade_primeira_onda)
	_ate_proximo_swarm = maxf(0.0, atraso_inicial) + randf_range(0.0, janela)

func _process(delta: float) -> void:
	var cena_alvo = aranha_scene if aranha_scene != null else enemy_scene
	if not is_instance_valid(player) or cena_alvo == null or EstadoJogo.vida_atual <= 0.0:
		return

	# Avança o tempo de jogo local do spawner
	tempo_partida += delta
	_ate_proximo_swarm -= delta

	# Dispara a primeira onda no instante sorteado em _ready(), e as
	# seguintes a cada intervalo_ondas
	if _ate_proximo_swarm <= 0.0:
		_disparar_swarm_de_aranhas(cena_alvo)
		_ate_proximo_swarm = intervalo_ondas

func _disparar_swarm_de_aranhas(cena_alvo: PackedScene) -> void:
	if EstadoJogo.vida_atual <= 0.0:
		return

	# Ponto central aleatório ao redor do jogador onde o enxame vai se originar
	var angulo_base: float = randf_range(0.0, TAU)
	var raio_base: float = randf_range(min_radius, max_radius)
	var centro_swarm := Vector3(cos(angulo_base) * raio_base, 0.0, sin(angulo_base) * raio_base)
	var posicao_central: Vector3 = player.global_position + centro_swarm

	# Instancia as aranhas da onda, com o tamanho definido pela progressao
	for i in range(tamanho_onda_atual()):
		if inimigos_vivos() >= maximo_absoluto:
			break

		var enemy: CharacterBody3D = cena_alvo.instantiate() as CharacterBody3D
		if enemy == null:
			continue

		if "player" in enemy:
			enemy.set("player", player)

		# Aplica velocidade e dano de toque no mob instanciado
		_aplicar_atributo(enemy, ["speed", "move_speed", "velocidade"], velocidade_mobs)
		_aplicar_atributo(enemy, ["attack_damage", "damage", "dano", "touch_damage", "dano_toque"], dano_toque)

		get_parent().add_child(enemy)

		# Espalha levemente as aranhas ao redor do centro do enxame
		var dispersao := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		enemy.global_position = posicao_central + dispersao

func _aplicar_atributo(enemy: Node, nomes_possiveis: Array[String], valor: float) -> void:
	for nome_var in nomes_possiveis:
		if nome_var in enemy:
			enemy.set(nome_var, valor)
			break

## Tamanho da onda corrente: base + 4 por cartela pego, ate o teto.
## Como `cartas_selecionadas` so cresce, a pressao acompanha o poder do
## jogador: quem esta atrasado sofre ondas menores, quem esta forte sofre
## ondas maiores.
func tamanho_onda_atual() -> int:
	var cartelas: int = EstadoJogo.cartas_selecionadas.size()
	var tamanho: int = tamanho_onda_base + (cartelas * tamanho_onda_por_carta)
	return clampi(tamanho, tamanho_onda_base, tamanho_onda_maximo)

func inimigos_vivos() -> int:
	var total: int = 0
	for inimigo: Node in get_tree().get_nodes_in_group(grupo_contagem):
		if not is_instance_valid(inimigo) or inimigo.is_queued_for_deletion():
			continue
		var vida: Variant = inimigo.get("health")
		if vida == null or float(vida) > 0.0:
			total += 1
	return total
