class_name ControlesJogador
extends Node
## Lê as ações configuradas no Input Map do projeto.

@export var esquerda: StringName = &"mover_esquerda"
@export var direita: StringName = &"mover_direita"
@export var cima: StringName = &"mover_frente"
@export var baixo: StringName = &"mover_tras"


func ler_direcao() -> Vector2:
	return Input.get_vector(esquerda, direita, cima, baixo)



##  H A D E S MS
