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
