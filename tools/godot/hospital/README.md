# O hospital

Dois andares, ligados só pelo elevador. Tudo — geometria, luz, móvel, colisão e
navmesh — é **gerado por script** a partir da planta. Mexer pelo editor do Godot
se perde na próxima geração, igual à arena 2.

São **duas cenas** saindo da mesma planta:

| Cena | O que é |
| :--- | :--- |
| `hospital.tscn` | o interior inteiro, onde se joga |
| `hospital_exterior.tscn` | a casca vista da rua, instanciada na `stage_1` |

O exterior é oco de propósito: entrar é trocar de cena, então ninguém atravessa
a casca e ninguém vê que ela é oca. Por isso toda janela leva um painel preto
atrás do vidro, e a porta da entrada é de vidro **opaco**.

## Rodar

```bash
tools/godot/hospital/construir.sh
```

Gera **e importa**. Nunca rode só o Python: o Godot continua carregando o
`.scn` velho de `.godot/imported/` sem erro nem aviso, e você acaba afinando
material contra uma geometria que não existe mais.

Para nascer em outro ponto enquanto testa (economiza muita caminhada):

```bash
HOSPITAL_SPAWN="53.4,1.05,31.6,-90" tools/godot/hospital/construir.sh
```

`x,y,z,giro em graus`. Sem a variável, o jogador nasce no hall.

## Onde o prédio fica na cidade

A instância mora na `stage_1`, em `locais_importantes/hospital_exterior`, em
cima do `Marker3D` chamado `hospital_local`. **Arrastar e girar pelo editor é
seguro** — a posição mora na `stage_1`, não no gerador.

O `(0,0,0)` da cena de fora é o **pé da escada da entrada**, e não o canto do
terreno. Logo, girar a instância gira o prédio *em torno da porta*: a entrada
fica onde está e o volume é que roda atrás dela.

Duas coisas viajam junto com a instância, e é por isso que o `stage_1.gd` não
tem nenhuma coordenada do hospital escrita no código:

| Nó | Para quê |
| :--- | :--- |
| `area_entrada` | acende o "Entrar no hospital?" |
| `ponto_de_saida` | onde o jogador reaparece ao sair |

A altura (Y) é o único ajuste que costuma sobrar: o terreno da cidade é o
Terrain3D e o pátio de concreto é plano. Suba ou desça a instância até a calçada
encostar no chão.

### E o mapa do menu

O prédio também é desenhado no mapa da cidade — a mancha dourada com o losango
"Hospital" na porta. Isso **não** é automático em tempo de jogo: a figura está
assada no `T_citymap.png`, que é gerado por
`tools/blender/citygen/textures/make_minimap.py`.

Ele monta a silhueta de duas fontes, de propósito:

| O quê | De onde | Quem escreve |
| :--- | :--- | :--- |
| a **forma** (retângulos do corpo, torre e tablado) | `assets/3d_model/stages/hospital/hospital_mapa.json` | `gerar_cena_exterior.py` |
| a **posição e o giro** | o nó `hospital_exterior` dentro do `stage_1.tscn` | o editor, quando você arrasta |

Por isso **arrastar ou girar o prédio no editor exige rodar o
`construir.sh` de novo** (ou só o `make_minimap.py`): senão o mapa continua
mostrando o hospital no lugar antigo. O losango fica na porta, e não no meio do
prédio como os outros pontos — com a planta inteira desenhada, o que falta
dizer ao jogador não é onde ele fica, é por onde se entra.

O nome sai do CSV, chave `MAP_POI_HOSPITAL`. O desenho sai 15 % menor que o
prédio de verdade (`ESCALA_HOSPITAL` no `make_minimap.py`): em tamanho real
ele ficava maior que a pracinha e a igreja juntas e dominava o mapa. A escala
encolhe em torno da porta, então o losango continua em cima da entrada.

## O mapa de dentro

`make_mapa_hospital.py` desenha **uma prancha por andar** a partir da mesma
`planta.py` — mexeu numa parede, o mapa mexe junto:

| Saída | O que é |
| :--- | :--- |
| `textures/T_hospitalmap_1.png` + `hospitalmap_1.json` | térreo |
| `textures/T_hospitalmap_2.png` + `hospitalmap_2.json` | segundo andar |

Duas pranchas e não uma com hachura (o truque das galerias da igreja) porque
aqui são dois andares INTEIROS, 56 x 68 m um em cima do outro, com plantas
diferentes — sobrepostos viram rabisco.

A planta é desenhada **pelo avesso**: preenche o andar todo de massa de parede
e escava o vão interno de cada sala e de cada área. O que sobra sem escavar são
exatamente as paredes. Por cima vão os vãos de `planta.muros()` — porta em
laranja, janela em azul —, que é o que faz a planta virar caminho em vez de um
monte de caixa fechada. Circulação sai um tom mais clara que sala.

**Quem troca de andar é o `minimap.gd`**, pela ALTURA do jogador (acima de
2,10 m é o andar de cima), e não por sinal do elevador: assim vale para
qualquer forma de subir que venha a existir, e um save carregado em cima já
abre com o mapa certo. Ao trocar, ele reescreve os próprios `dados_json` e
`textura_mapa` — é por esses dois que a aba MAPA do menu pergunta qual mapa
mostrar (`MapaDados.caminho_da_cena`), então eles têm de apontar para o andar
atual. O painel do menu não precisou saber de andar nenhum.

O perfil da cena é `scenes/ui/minimap_hospital.tscn`, instanciado dentro do
`hospital.tscn` **pelo gerador**. Sem ele o menu diria "nenhum mapa disponível"
lá dentro.

Os rótulos são uma sala por ponto, e a chave de tradução sai da própria
`planta.py` (`HOSP_SALA_*`, as mesmas que o prompt da porta usa) — renomear a
sala no CSV renomeia no mapa. Mais o elevador e, no térreo, a saída para a rua.
No minimapa eles ficam **desligados** (`pontos_no_minimapa = false`): trinta
losangos em 190 px tapariam a planta que eles deviam explicar.

## Entrar e sair

- **Entrar:** a área acende o prompt, e o `ui_accept` carrega `hospital.tscn`.
  Mesmo caminho da igreja e da casa do Jimmy.
- **Sair:** a porta da rua (`entrada_principal`) tem `metadata/saida = true`.
  Ela não gira: acionar chama `hospital.gd.sair_do_hospital()`, que liga
  `GlobalEvents.voltando_do_hospital` antes de trocar de cena. O `stage_1`
  consome a flag no spawn e devolve o jogador ao tablado, de costas para a
  porta.

## Onde mexer em cada coisa

| Arquivo | Assunto |
| :--- | :--- |
| `planta.py` | salas, muros, portas, janelas, o poço do elevador |
| `luzes.py` | onde tem lâmpada, qual está queimada, cor e alcance |
| `materiais.py` | textura e cor de piso, parede, teto, móvel |
| `mobilia.py` | o que vai dentro de cada tipo de sala |
| `navmesh.py` | malha de navegação + conferidor da planta |
| `gltf.py` | escritor de glTF (funde caixas numa malha só) |
| `gerar_cena_hospital.py` | monta o `.tscn` do interior |
| `exterior.py` | medidas da fachada, estado das janelas, o letreiro |
| `gerar_cena_exterior.py` | monta o `.tscn` da casca de fora |
| `gerar_cena_exterior.py` → `hospital_mapa.json` | a silhueta que vai pro mapa da cidade |
| `make_mapa_hospital.py` | as duas plantas do interior (minimapa e aba MAPA) |

Comportamento (porta, elevador, lâmpada piscando) fica em
`red-valve/scripts/stages/hospital/`.

## Conferir depois de mexer

```bash
# sobreposição de sala, vão fora de parede, sala sem porta, ilha solta no navmesh
python3 tools/godot/hospital/navmesh.py

# pergunta ao NavigationServer se dá pra andar de um canto ao outro (12 trajetos)
/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64 --headless \
    --path red-valve res://tools/hospital/testar_navmesh.tscn
```

O próprio `construir.sh` já imprime o tamanho de setor que escolheu e quantas
luzes a pior malha enxerga — se aparecer mais de 8, o renderer mobile vai
descartar lâmpada em silêncio.

## O que ainda não está feito

- Não tem escada: o mapa desenhado não mostra nenhuma, e o elevador é o caminho.
- O exterior não tem inimigo, navmesh nem interior visível pelas janelas: ele é
  cenário de rua, e o jogo acontece do outro lado da porta.
- Não tem som próprio de porta nem de elevador (o projeto não tem esses
  arquivos); só a ambiência geral.
- O lote onde ele está hoje **não está vazio**: 8 casas do gerador da cidade e
  5 postes caem dentro dos 56 x 68 m do corpo. O prédio passa por cima delas.
  É para resolver quando a posição final for escolhida — o mapa já mostra o
  estrago, porque desenha as casas e o hospital da mesma origem.
