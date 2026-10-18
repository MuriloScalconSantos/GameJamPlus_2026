# Quadrado de seleção de cartas

Base: GameJamPlus_2026(2).zip enviado nesta solicitação.

## Arquivos existentes alterados

| Arquivo | Linhas na versão entregue | Alteração |
|---|---|---|
| Scenes/mundo_teste.tscn | 10–11 | Referência ao novo script, com linha de separação. |
| Scenes/mundo_teste.tscn | 129–131 | Novo nó CartasDoMapa na raiz do mundo, com o script conectado. |
| ritmo/fluxo_jogo.gd | 22–24 | Quando a seleção do quadrado está aberta, o Esc fica a cargo dela, sem abrir a pausa ao mesmo tempo. |

## Arquivos novos
interacoes/quadrado_cartas.gd — 141 linhas, todas novas:
- 1–14: configuração e variáveis. Linhas 3–4: distância mínima 5 e máxima 8 unidades. Linha 5: atraso inicial 1 segundo; também aguarda o personagem pousar. Linha 6: máscara de chão.
- 16–20: encontra Player, registra o grupo e constrói a interface.
- 22–29: aguarda chão/tempo; pausa impede geração. Repete a tentativa caso não haja posição válida.
- 31–63: sorteia uma posição no anel de 5 a 8 unidades, verifica piso estático, inclinação e diferença de altura, e verifica linha livre entre jogador e ponto. Cria cubo amarelo de 1,2 unidade sem colisão de bloqueio. Uma unidade por partida.
- 65–81: trata clique esquerdo no volume do quadrado e Esc. Consome o clique para não acionar o ataque básico via _unhandled_input.
- 83–121: cria tela com três retângulos em branco, três botões SELECIONAR e botão VOLTAR (ESC).
- 123–130: abre a tela e pausa, impedindo sobreposição com cartas de XP.
- 132–137: fecha a tela e restaura a pausa respeitando outros estados. Não aplica habilidades e não modifica o EstadoJogo.
- 139–141: restaura pausa quando a cena é removida com a seleção aberta.
interacoes/quadrado_cartas.gd.uid — identificador do novo script (1 linha).

## Decisões e uso
Foi criada uma interface separada porque a existente aplica melhorias de XP. Nenhum arquivo do sistema de XP foi alterado.
O quadrado aparece uma vez por partida e pode ser clicado novamente depois de fechar a seleção. Não desaparece nem concede recompensas; não existe spawn periódico nesta versão.
Para conferir, inicie pelo menu, aguarde o jogador pousar e procure o cubo amarelo próximo dele. Clique com o botão esquerdo. Selecione qualquer carta ou aperte Esc para voltar.
No editor: Scenes/mundo_teste.tscn > CartasDoMapa. Ajuste Distancia Minima, Distancia Maxima e Atraso Inicial no Inspetor, ou os valores das linhas 3–5 do script novo.

## Validação
11 verificações automáticas aprovadas na Godot 4.5.1 headless: spawn sobre o mapa real; distância 5–8; três opções; clique projetado e pausa; fechamento; nenhuma mudança de status; Esc; abertura por XP; bloqueio de sobreposição; efeito da carta de XP original; saída para menu limpando os nós e pausa.
Não foi feita inspeção visual renderizada nem execução na Godot 4.7.
O projeto emitiu aviso de UID antigo em progressao/xp_joia.tscn (usando corretamente o caminho alternativo) e aviso de recurso ainda em uso ao encerrar o menu, já observado em versões anteriores. Esses arquivos não foram alterados.
Todas as outras entradas do ZIP original foram preservadas byte a byte. Camera, ataques e cenas de inimigos não foram modificados.
ALTERACOES_QUADRADO.patch contém o diff dos dois arquivos existentes.
