extends "res://player/character_body_3d.gd"
## Aplica ao jogador o multiplicador de velocidade das cartas de Acelerar.
##
## A base (player/character_body_3d.gd) expoe o hook `velocidade_efetiva()`.
## Aqui ele devolve a velocidade de caminhada multiplicada pelo valor
## acumulado em EstadoJogo.velocidade_movimento (1.0 = sem cartas, +0.1 por
## carta), respeitando o multiplicador da agua quando o jogador esta dentro
## de uma area com agua.

@export var multiplicador_agua: float = 1.0


## Multiplicador acumulado das cartas de Acelerar (1.0 = nenhuma carta).
func _multiplicador_cartas() -> float:
	return maxf(EstadoJogo.velocidade_movimento, 0.1)


func velocidade_efetiva() -> float:
	return super.velocidade_efetiva() * _multiplicador_cartas() * multiplicador_agua
