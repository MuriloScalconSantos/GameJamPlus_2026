extends AudioStreamPlayer2D
## Mantém as duas faixas tocando e cruza para a música frenética após 80 abates.

const ABATES_PARA_MUSICA_FRENÉTICA: int = 80
const VOLUME_MUSICA_INICIAL: float = 0.0
const VOLUME_MUSICA_FRENÉTICA: float = -10.0
const VOLUME_MUDO: float = -80.0
const DURACAO_TRANSICAO: float = 2.0

var _musica_inicial: AudioStreamPlayer2D
var _transicao: Tween
var _musica_frenetica_ativa: bool = false


func _ready() -> void:
	_musica_inicial = get_parent().get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	volume_db = VOLUME_MUDO
	if not is_playing():
		play()
	if _musica_inicial != null and not _musica_inicial.is_playing():
		_musica_inicial.play()
	if EstadoJogo.abates_alterados.is_connected(_ao_alterar_abates) == false:
		EstadoJogo.abates_alterados.connect(_ao_alterar_abates)
	_ao_alterar_abates(EstadoJogo.abates_total)


func _ao_alterar_abates(total: int) -> void:
	var ativar_frenetica: bool = total >= ABATES_PARA_MUSICA_FRENÉTICA
	if ativar_frenetica == _musica_frenetica_ativa:
		return
	_musica_frenetica_ativa = ativar_frenetica
	if _transicao != null and _transicao.is_running():
		_transicao.kill()
	_transicao = create_tween()
	if _musica_inicial != null:
		_transicao.parallel().tween_property(
			_musica_inicial,
			"volume_db",
			VOLUME_MUDO if ativar_frenetica else VOLUME_MUSICA_INICIAL,
			DURACAO_TRANSICAO
		)
	_transicao.parallel().tween_property(
		self,
		"volume_db",
		VOLUME_MUSICA_FRENÉTICA if ativar_frenetica else VOLUME_MUDO,
		DURACAO_TRANSICAO
	)
