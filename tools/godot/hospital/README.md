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

### O mapa começa apagado

A prancha nasce toda escura e vai acendendo conforme o jogador anda. Quem
guarda o que já foi descoberto é `scripts/ui/mapa_nevoa.gd` (uma máscara de
256 x 256, uns 30 cm por pixel), quem a alimenta é o minimapa do HUD — ele já
tem a posição do jogador a cada quadro — e quem a guarda entre uma visita e
outra é o `SaveManager`, comprimida dentro do save.

O que acende de uma vez e o que acende aos poucos sai da lista `zonas` que este
script escreve no JSON, e a divisão já existe na `planta.py`:

| na planta | zona | o que faz |
| :--- | :--- | :--- |
| `_sala(...)` | `"sala"` | entrou, acende **inteira** |
| `_area(...)` | `"gradual"` | acende um disco em volta do jogador, **recortado na própria zona** |

O recorte é o que segura a coisa de pé: sem ele um disco de 12 m no corredor
acenderia meia sala dos dois lados através da parede. É por isso que o raio nos
corredores pode ser generoso e o raio de quem está **fora** de qualquer zona
(porta, soleira) é pequeno — ali não há parede que recorte nada.

Zona em que o jogador nunca pisa leva um `gatilho`: um retângulo onde ele pisa
e que acende a zona. É o mesmo mecanismo do altar da igreja.

Os pontos do mapa (os losangos com o nome da sala) só aparecem depois que o
lugar deles foi descoberto — nome de sala em cima de planta apagada entregaria
justo o que a névoa existe para esconder.

Sala nova na planta já nasce com zona. **O que não é automático são os raios**:
eles moram no topo do script (`NEVOA_*`).

**Cada andar tem a sua máscara**, porque são dois JSON: descobrir o térreo não
acende o segundo andar. O poço do elevador fica de fora das zonas de propósito
— é o único lugar a que o jogador chega sem ter andado até lá, e na cabine vale
a névoa solta, que acende a cabine e um naco do corredor em que ela abre.

## Entrar e sair

- **Entrar:** a área acende o prompt, e o `ui_accept` carrega `hospital.tscn`.
  Mesmo caminho da igreja e da casa do Jimmy.
- **Sair:** a porta da rua (`entrada_principal`) tem `metadata/saida = true`.
  Ela não gira: acionar chama `hospital.gd.sair_do_hospital()`, que liga
  `GlobalEvents.voltando_do_hospital` antes de trocar de cena. O `stage_1`
  consome a flag no spawn e devolve o jogador ao tablado, de costas para a
  porta.

## O que está em cima do balcão

O balcão redondo da recepção (o círculo do mapa, no meio do hall) carrega os
dois itens que o jogador **pega aqui e em nenhum outro lugar**:

| Onde | Item | Prompt |
| :--- | :--- | :--- |
| face **oeste** (a que encara a porta da rua) | a pistola *The Negotiator* | `PROMPT_TAKE_PISTOL` |
| face **leste** (do outro lado) | uma caixa de 25 balas | `PROMPT_TAKE_AMMO` |
| face **norte** | outra caixa de 25 balas | `PROMPT_TAKE_AMMO` |

Estão em lados diferentes de propósito: quem entra vê a arma de cara e precisa
contornar o balcão para achar a munição. E são **duas** caixas de bala porque uma
só não deixa o jogador perceber que a quantidade soma — com duas ele pega 25,
olha o menu, pega mais 25 e vê 50.

Os dois nascem em `gerar_cena_hospital.py` → `ITENS_BALCAO`, e o comportamento
(prompt, `ui_accept`, tela de item obtido) é de `item_de_balcao.gd`, um script de
nó — igual ao da porta e ao do elevador. Mexer no raio ou na altura do balcão
não os deixa flutuando: as duas medidas moram em `mobilia.RECEPCAO_*` e são as
mesmas que o móvel usa.

A colisão do balcão é uma caixa de 7,4 x 7,4 m, maior que o círculo: o jogador
para a pouco mais de um metro do tampo e pega o item **por cima** do balcão —
que é como se pega algo num balcão.

Cada objeto tem `id` próprio e o `SaveManager` guarda quais já foram recolhidos
(`pickups_pegos`) — "já tenho bala" não responde se a **segunda** caixa ainda
está lá. A checagem por inventário vale só para item único: é ela que faz um save
antigo, que já tenha a arma, chegar aqui com aquele canto do balcão vazio.

A tela de item obtido (modelo 3D girando, jogo parado) só aparece na **primeira**
vez que aquele item entra no inventário. Da segunda em diante é um aviso curto no
meio da tela (`PICKUP_AMMO_AGAIN`): parar o jogo para apresentar a mesma caixa de
bala pela quinta vez seria castigo.

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
| `gerar_cena_hospital.py` → `ITENS_BALCAO` | a pistola e a munição em cima da recepção |
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
