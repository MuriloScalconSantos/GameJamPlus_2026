extends "res://progressao/interface_progressao.gd"
## A pausa de Esc e a pausa das cartas podem coexistir.
func _apos_escolha(id: StringName) -> void:
	super._apos_escolha(id)
	if EstadoJogo.cartas_pendentes == 0:
		get_tree().paused = FluxoJogo.pausa_aberta or FluxoJogo.em_transicao
