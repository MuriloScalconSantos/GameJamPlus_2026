# Correção da água

Principal: GameJamPlus_2026(2).zip enviado nesta solicitação.
Causa: a cena Scenes/mundo_teste.tscn não possuía o nó Ambiente/Agua, embora fluid_agua.gd e fluid_water.tscn estivessem no projeto.

Único arquivo existente alterado: Scenes/mundo_teste.tscn.
Linhas na versão entregue:
- 7–8: referências ao script original fluid_agua.gd e à textura icon.svg.
- 14–21: forma de colisão, material e malha da água.
- 57–73: nó Ambiente/Agua e seus filhos, copiados da cena do Lucca, com a posição, escala, velocidade_agua=2.0 e aparência de teste originais.

Todos os demais arquivos do principal foram preservados byte a byte, inclusive câmera, combate, XP, menu, movimentação e script da água. Não foi feito merge completo do projeto Lucca.
A aparência continua sendo a textura de teste icon.svg usada no projeto Lucca; não foi criado um novo shader de água.

Para conferir: abra Scenes/mundo_teste.tscn, selecione Ambiente/Agua e pressione F no editor 3D para enquadrar. Ela está em X=5.9413595, Y=0, Z=0. Rode o jogo e caminhe para o lado positivo de X. Entrar aplica lentidão; sair restaura a velocidade.

Validação: importação sem erros de scripts e cinco verificações automáticas aprovadas na Godot 4.5.1 headless (instância/malha visível, superfície acima do piso, script conectado, entrada e saída física com mudança/restauração de velocidade). Não houve verificação visual renderizada nem execução na Godot 4.7.
CORRECAO_AGUA.patch contém o diff exato.
