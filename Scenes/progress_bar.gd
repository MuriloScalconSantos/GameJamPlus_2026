extends ProgressBar
## Barra de vida do HUD. EstadoJogo continua sendo a fonte dos valores.

@onready var numero: Label = $Valor
@onready var dano: Label = $"../Dano"
var animacao: Tween

func _ready() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("201113")
	fundo.set_corner_radius_all(3)
	add_theme_stylebox_override("background", fundo)
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = Color("d3444f")
	preenchimento.set_corner_radius_all(3)
	add_theme_stylebox_override("fill", preenchimento)
	EstadoJogo.status_alterado.connect(atualizar)
	atualizar(false)

func atualizar(animar: bool = true) -> void:
	if animacao and animacao.is_running():
		animacao.kill()
	var novo_maximo: float = maxf(1.0, EstadoJogo.vida_maxima)
	var novo_valor: float = clampf(EstadoJogo.vida_atual, 0.0, novo_maximo)
	if not animar or max_value != novo_maximo:
		max_value = novo_maximo
		value = novo_valor
	else:
		animacao = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		animacao.tween_property(self, "value", novo_valor, 0.2).set_trans(Tween.TRANS_SINE)
	numero.text = "%.0f / %.0f" % [EstadoJogo.vida_atual, EstadoJogo.vida_maxima]
	dano.text = "DANO  %.0f" % EstadoJogo.dano_jogador
