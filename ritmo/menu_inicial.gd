extends Control
## Mantém os botões e a arte do menu existente.
func _ready() -> void:
	$VBoxContainer/Start.grab_focus()

func _exit_tree() -> void:
	$Menu.stop()

func _on_start_pressed() -> void:
	FluxoJogo.iniciar_partida()

func _on_exit_game_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	_abrir_pagina("res://Scenes/Options/Options.tscn", "As opções ainda não estão disponíveis neste projeto.")

func _on_creditos_pressed() -> void:
	_abrir_pagina("res://Scenes/Credits/Credits.tscn", "A tela de créditos ainda não está disponível neste projeto.")

func _abrir_pagina(caminho: String, mensagem: String) -> void:
	if ResourceLoader.exists(caminho):
		get_tree().change_scene_to_file(caminho)
		return
	var aviso := AcceptDialog.new()
	aviso.title = "Em desenvolvimento"
	aviso.dialog_text = mensagem
	add_child(aviso)
	aviso.confirmed.connect(aviso.queue_free)
	aviso.canceled.connect(aviso.queue_free)
	aviso.popup_centered()
