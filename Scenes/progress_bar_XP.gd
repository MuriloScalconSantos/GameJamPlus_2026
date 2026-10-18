extends ProgressBar
## Progresso até a próxima carta, atualizado quando uma joia concede XP.

@onready var numero: Label = $Valor
var animacao: Tween

func _ready() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("0c1b19")
	fundo.set_corner_radius_all(3)
	add_theme_stylebox_override("background", fundo)
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = Color("36cba5")
	preenchimento.set_corner_radius_all(3)
	add_theme_stylebox_override("fill", preenchimento)
	EstadoJogo.status_alterado.connect(atualizar)
	atualizar(false)

func atualizar(animar: bool = true) -> void:
	if animacao and animacao.is_running():
		animacao.kill()
	
	# Pega o custo dinâmico atualizado do EstadoJogo
	var maximo_atual = EstadoJogo.xp_necessario_para_proximo_nivel()
	var novo_maximo: float = maxf(1.0, float(maximo_atual))
	var novo_valor: float = clampf(float(EstadoJogo.xp_atual), 0.0, novo_maximo)
	
	if not animar or novo_valor < value:
		max_value = novo_maximo
		value = novo_valor
	else:
		max_value = novo_maximo
		animacao = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		animacao.tween_property(self, "value", novo_valor, 0.2).set_trans(Tween.TRANS_SINE)
		
	numero.text = "%d / %d" % [EstadoJogo.xp_atual, maximo_atual]
