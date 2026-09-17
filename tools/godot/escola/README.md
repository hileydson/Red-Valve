# A escola (e o porão)

Um andar, com um **pátio descoberto** no meio — a "área de lazer" do desenho —
e um **túnel de barro** cavado por baixo. Tudo (geometria, luz, móvel, pichação,
colisão e navmesh) é **gerado por script** a partir da planta. Mexer pelo editor
do Godot se perde na próxima geração, igual ao hospital e à arena 2.

São **três cenas** saindo dos mesmos módulos:

| Cena | O que é |
| :--- | :--- |
| `escola.tscn` | o prédio inteiro + o pátio, onde se joga |
| `porao.tscn` | o túnel de barro debaixo dele |
| `escola_exterior.tscn` | a casca vista da rua, instanciada na `stage_1` |

O exterior é oco de propósito: entrar é trocar de cena, então ninguém atravessa
a casca. Por isso toda janela leva um painel preto atrás do vidro e o portão da
rua é de **chapa cega**. A exceção é o pátio, que fica **descoberto na casca
também**, com o piso e a mancha da quadra desenhados nele — a cidade tem morro,
e de cima de qualquer coisa dá para olhar por cima de um muro de 4,80 m.

## Rodar

```bash
tools/godot/escola/construir.sh
```

Gera **e importa**. Nunca rode só o Python: o Godot continua carregando o `.scn`
velho de `.godot/imported/` sem erro nem aviso.

Para nascer em outro ponto enquanto testa (economiza muita caminhada):

```bash
ESCOLA_SPAWN="63,1.05,54.5,90" tools/godot/escola/construir.sh
PORAO_SPAWN="73,1.05,73,270"   tools/godot/escola/construir.sh
```

`x,y,z,giro em graus`. Sem as variáveis, o jogador nasce no pátio (escola) e na
boca de cima (porão).

## O caminho que esta fase desenha

É o desenho do caderno, e ele manda em tudo o que está na planta:

1. o jogador chega da cidade pelo **portão da rua** e cai no **PÁTIO**;
2. do pátio ele entra no prédio pela **porta principal** (corredor norte);
3. anda o corredor norte → corredor leste → corredor sul e tromba na **GRADE**,
   soldada de parede a parede no meio do corredor. Ela não abre nunca;
4. do lado de cá da grade fica o **DEPÓSITO**, e no fundo dele o **BURACO**;
5. o buraco leva ao **porão** (outra cena) e o devolve no **ALMOXARIFADO**, do
   outro lado da grade;
6. dali ele alcança o resto do prédio e o **PORTÃO DO PÁTIO**, que só destranca
   por dentro — é o atalho de volta para a área de lazer.

**O anel de corredores NÃO fecha, e isso é regra de jogo, não acaso.** Duas
paredes seguram o desenho inteiro, e as duas estão comentadas na `planta.py`:

- o corredor norte morre na fachada oeste (não dá a volta pelo lado de fora);
- **a biblioteca não tem porta para o refeitório.** Ela abre só no corredor sul,
  do lado de lá da grade. Uma porta ali ligaria "lado de cá" a "lado de lá" por
  dentro e o jogador contornaria a grade sem nunca entrar no porão.

Quem confere isso é `navmesh.py`, e ele confere **contando**:

```bash
python3 tools/godot/escola/navmesh.py
```

A última seção do relatório (`a grade separa os dois lados?`) simula a grade e o
portão fechados e diz quantas células do mapa sobram inalcançáveis. Hoje são
**826 de 4.117** — se esse número cair para perto de zero, alguém abriu um
caminho por dentro e o porão virou enfeite.

## O pátio

É o único espaço **descoberto** da cena, e é isso que o separa de tudo o que já
existe no projeto:

- não leva laje de forro — leva céu, e por isso esta cena tem uma
  **DirectionalLight** (a lua) e **chuva**, que um interior fechado não teria;
- as paredes que dão para ele sobem além do pé-direito (`PATIO_MURO_ALTO`),
  senão o céu apareceria por baixo do prédio;
- a chuva é emitida só sobre ele, com vida curta o bastante para a gota morrer
  perto do chão. Chuva atravessando a laje do corredor vizinho denunciaria na
  hora que o prédio não tem telhado de verdade.

Dentro dele vai exatamente o que foi pedido e nada mais: uma **quadra
esportiva** (26 x 16 m, traves nas duas pontas) e **bancos**, todos encostados
nos muros. O centro fica vazio. A quadra é **pintura**, não construção: uma laje
rasa de asfalto com as linhas 1 cm acima, sem colisão nenhuma.

A lua saiu de 0,55 para **1,50** depois de medir no jogo: com 0,55 o pátio
ficava mais escuro que o corredor coberto, o que inverte a leitura do mapa
inteiro. O piso de cimento tem albedo 0,40 e come quase tudo o que recebe.

## O porão

`porao.py` descreve o traçado (uma polilinha com raio variável, uma câmara
grande e três becos sem saída) e **rasteriza tudo numa grade de 1 m**. Daqui
saem quatro coisas, todas da mesma grade: chão, teto, parede e navmesh.

**Por que grade e não caixa girada ao longo da linha:** caixa girada quebra na
curva — na parte de fora de todo cotovelo sobra uma cunha sem parede e o jogador
vê o vazio por ela. Rasterizando, a parede nasce na *fronteira* entre célula
aberta e célula fechada: não existe canto sem tratamento porque não existe
canto, existe célula. O túnel sai estanque por construção.

O que tira a cara de gaveta que uma grade de 1 m tem: **torrões** (caixas
pequenas e giradas saindo da parede), **raízes** descendo do teto (são elas que
dão escala — sem nada pendurado, uma galeria de 2,60 m e uma de 5 m parecem a
mesma coisa) e **escoras** de tábua a cada 9 m, que dão ritmo ao caminho.

**A luz do porão é o assunto dele.** A `ambient_light_energy` é **0,42** contra
1,75 da escola, e as lâmpadas são poucas, fracas e a maioria morta: elas
*marcam* o caminho, não o iluminam. Foi o pedido — aqui a lanterna deixa de ser
conforto e vira ferramenta, e por isso `porao.gd` avisa quem chegou sem ela.

Abaixo de ~0,3 de ambiente o jogador para de enxergar a parede e passa a bater
nela, o que não dá medo, dá raiva. 0,42 mostra a silhueta e esconde o resto.

**O túnel é de mão dupla.** Dá para descer pelo depósito e voltar pelo mesmo
buraco. Mão única viraria armadilha: quem descesse sem lanterna ficaria preso no
escuro sem poder voltar.

## Onde a escola fica na cidade

A instância mora na `stage_1`, em `locais_importantes/escola_exterior`, em cima
do `Marker3D` chamado `escola_local`. **Arrastar e girar pelo editor é seguro** —
a posição mora na `stage_1`, não no gerador.

O `(0,0,0)` da cena de fora é a **calçada diante do portão**, e não o canto do
terreno. Logo, girar a instância gira o prédio *em torno da entrada*.

Duas coisas viajam junto com a instância, e é por isso que o `stage_1.gd` não
tem nenhuma coordenada da escola escrita no código:

| Nó | Para quê |
| :--- | :--- |
| `area_entrada` | acende o "Entrar na escola?" |
| `ponto_de_saida` | onde o jogador reaparece ao sair |

**Hoje ela está em (889,94, 8,08, −398,49), sem giro**, na ponta sudeste — o
último quarteirão da cidade de um lado, a mata do outro, com o portão dando na
via que fecha a malha a leste. Das quatro orientações possíveis nesse ponto, a
sem giro é a única cujo portão encara uma rua (o asfalto começa 12 m adiante
dele); nenhuma das quatro engole casa nenhuma do gerador da cidade.

**O Y é o ajuste que costuma sobrar**, igual ao hospital, e ele vale a mesma
regra de sempre: é a cota do chão **no portão**, porque é ali que o jogador
pisa. Enterrar é de graça — a casca de fora é fechada, ninguém enxerga por
dentro dela — mas **flutuar não é**, dá para ver por baixo da parede.

Aqui o terreno cai 2,2 m de uma ponta do lote à outra, três vezes o que a
calçada de 0,70 m tapava. Por isso o embasamento e a calçada ganharam a
`SAIA = 3.00` do `exterior.py`: as duas descem 3 m abaixo do chão de
referência. Do lado alto some no barro; do lado baixo vira um embasamento de
concreto, que é como um prédio de verdade se apoia em ladeira.

### A mata não pode nascer dentro dela

Esse canto do mapa é o anel de floresta, e o espalhamento da cidade não sabia
da escola: 25 árvores e 5 arbustos nasciam **dentro** do lote, atravessando o
telhado e o pátio. Quem segura isso é a lista `CLAREIRAS`, em
`tools/blender/citygen/lib/vegetation.py` — retângulos onde não se planta, no
mesmo espírito das vagas reservadas de `houses.py`.

O corte é feito no **fim** de `scatter()`, e não dentro do laço, de propósito:
o sorteio continua consumindo o `rng` na mesma ordem, então abrir uma clareira
não move uma árvore que seja no resto do mapa.

Mexeu na lista? São dois comandos, os dois sem Blender:

```
python3 tools/blender/citygen/refazer_scatter.py     # reescreve o scatter.json
python3 tools/blender/citygen/podar_multimesh.py     # poda as MultiMesh assadas
```

O segundo existe porque o jogo **não lê o `scatter.json`**: lê as MultiMesh de
`assets/3d_model/city/multimesh/`, assadas uma vez pelo nó `City/Vegetation`. O
caminho oficial é apertar `construir` naquele nó — só que isso reassa a
floresta inteira por causa de 30 plantas, e `ResourceSaver` dentro de um @tool
já derrubou o editor neste projeto.

**O retângulo é um número escrito à mão**, então arrastar a escola no editor o
deixa para trás e as árvores voltam — sem erro nenhum, só aparece andando por
lá. Por isso o `construir.sh` roda `conferir_clareira.py`, que compara os dois
e escreve a linha certa para colar quando eles discordam.

### E o mapa do menu

A escola também é desenhada no mapa da cidade — a mancha verde com o pátio
escuro no meio. Isso **não** é automático em tempo de jogo: a figura está assada
no `T_citymap.png`, gerado por
`tools/blender/citygen/textures/make_minimap.py`.

Ele monta a silhueta de duas fontes, de propósito:

| O quê | De onde | Quem escreve |
| :--- | :--- | :--- |
| a **forma** (lote, pátio, corpo) | `assets/3d_model/stages/escola/escola_mapa.json` | `gerar_cena_exterior.py` |
| a **posição e o giro** | o nó `escola_exterior` dentro do `stage_1.tscn` | o editor, quando você arrasta |

Por isso **arrastar ou girar o prédio no editor exige rodar o `construir.sh` de
novo** (ou só o `make_minimap.py`). O losango fica na PORTA, e não no meio do
prédio: com a planta inteira desenhada, o que falta dizer ao jogador não é onde
ele fica, é por onde se entra.

O recorte quadrado da imagem também deixou de ser só os limites da cidade: como
parte do lote da escola caiu **fora** deles, `_recorte()` passou a incluir os
dois prédios soltos, senão a escola saía cortada na borda. Ela cresceu de 680
para 740 m, e a cidade inteira perdeu 8 % de resolução no mapa — foi o preço de
a escola caber.

O nome sai do CSV, chave `MAP_POI_ESCOLA`. O desenho sai 15 % menor que o prédio
real (`ESCALA_ESCOLA`), encolhendo em torno do portão — mesma conta do hospital.
A escola tem paleta **própria** no mapa da cidade (verde) e não o ouro do
hospital: são os dois únicos prédios grandes, e no mesmo tom viravam duas
manchas iguais.

## Os mapas de dentro

`make_mapa_escola.py` desenha **duas pranchas**, a partir dos mesmos módulos que
geram a geometria:

| Saída | O que é |
| :--- | :--- |
| `textures/T_escolamap.png` + `escolamap.json` | a planta da escola |
| `textures/T_poraomap.png` + `poraomap.json` | o traçado do túnel |

**Não há troca automática entre elas**, e não precisa haver: escola e porão são
duas CENAS, cada uma instancia o seu perfil de minimapa
(`scenes/ui/minimap_escola.tscn` e `minimap_porao.tscn`), e trocar de cena já
troca o nó que declara o mapa. É o contrário do hospital, que tem dois andares
no mesmo prédio e precisa do `minimap.gd` decidindo pela altura do jogador.

A planta da escola é desenhada **pelo avesso** (preenche o prédio de massa de
parede e escava o vão de cada sala; o que sobra são as paredes). Por cima vão os
vãos de `planta.muros()` — porta em laranja, janela em azul. Três coisas só
existem neste mapa, e as três são a regra de jogo:

- o **pátio** sai numa cor própria (esverdeada): é o único espaço descoberto e é
  onde o jogador nasce;
- a **quadra** aparece desenhada dentro dele, que é o que faz o pátio ser
  reconhecível como pátio e não como mais um salão;
- a **grade** é uma barra **vermelha** atravessando o corredor sul. Sem ela o
  mapa mostraria um corredor contínuo que não existe, e o jogador ficaria dando
  voltas atrás de um caminho que o mapa promete e o jogo não tem.

Os dois **buracos** aparecem saindo do prédio, com o nicho de terra atrás — é o
que diz, sem texto, que aquilo não é uma porta para a rua.

O mapa do porão sai direto da grade de células. O único enfeite é o **fio do
caminho principal**: num túnel de terra sem rótulo nenhum, o que falta saber é
qual das ramificações leva a algum lugar. Os becos sem saída ficam de fora do
fio de propósito. Ele leva três pontos e nem um a mais (entrada, câmara, saída);
no minimapa eles ficam **ligados**, ao contrário da escola — no escuro, ver para
que lado fica a saída é a única orientação que o jogador tem.

Os rótulos da escola saem da própria `planta.py` (`ESC_SALA_*`, as mesmas chaves
que o prompt da porta usa) — renomear a sala no CSV renomeia no mapa.

## Pichação

Reaproveita o atlas da cidade (`assets/images/textures/pichacao/`, gerado por
`tools/texturas/gerar_pichacao.py`). É o mesmo mundo e a mesma gente: as facções
que pixam o muro da rua são as que pixam a escola.

Aqui são ~140 rabiscos dentro de um prédio, então cada um é um `MeshInstance3D`
com `QuadMesh` e um `StandardMaterial3D` apontando para o atlas com `uv1_offset`
e `uv1_scale` — a mesma conta do shader da cidade, feita pelo material padrão.
O material é por **arte**, não por rabisco: 140 quads dividem ~50 materiais.

Duas armadilhas já pagas na cidade e que valem aqui do mesmo jeito estão
comentadas em `pichacao.py`: `cull_mode` tem de ser **2** (o `QuadMesh` com
`orientation = FACE_Z` não encara o +Z local e o quad some sem erro nenhum em
log), e o decalque usa **mistura**, nunca alpha scissor.

O porão não leva pichação nenhuma — quem pixa quer plateia, e o túnel foi cavado
às escondidas. Lá só vão manchas de umidade.

## Entrar e sair

- **Entrar (da cidade):** a `area_entrada` acende o prompt e o `ui_accept`
  carrega `escola.tscn`. Mesmo caminho da igreja, da casa do Jimmy e do
  hospital.
- **Sair:** o portão da rua tem `metadata/saida = true`. Acionar chama
  `escola.gd.sair_da_escola()`, que liga `GlobalEvents.voltando_da_escola` antes
  de trocar de cena. O `stage_1` consome a flag no spawn.
- **Escola ↔ porão:** os buracos e as bocas usam o **mesmo** script
  (`buraco.gd`) nas duas cenas. Ele só acende o prompt e chama
  `usar_buraco(papel)` no dono — quem sabe o que "trocar de lugar" significa é a
  cena, não o buraco. Os pontos de chegada são `Marker3D` da cena gerada, nunca
  coordenada escrita no `.gd`.

## Onde mexer em cada coisa

| Arquivo | Assunto |
| :--- | :--- |
| `planta.py` | salas, muros, portas, janelas, a grade, os dois buracos |
| `porao.py` | o traçado do túnel, a câmara, os becos |
| `luzes.py` | luz da escola E do porão (os dois no mesmo arquivo, de propósito) |
| `materiais.py` | textura e cor: interior, porão e fachada |
| `mobilia.py` | o que vai em cada sala, a quadra e os bancos, o entulho do porão |
| `pichacao.py` | onde nasce cada rabisco |
| `navmesh.py` | malha de navegação + conferidor da planta + o teste da grade |
| `comum.py` | setor de malha, Transform3D, juntador de peças, escritor de .tscn |
| `gerar_cena_escola.py` | monta o `.tscn` do interior |
| `gerar_cena_porao.py` | monta o `.tscn` do túnel |
| `exterior.py` | medidas da fachada, estado das janelas, o letreiro |
| `gerar_cena_exterior.py` | monta a casca + `escola_mapa.json` |
| `make_mapa_escola.py` | as duas plantas do menu |

O escritor de glTF é **importado do hospital** (`tools/godot/hospital/gltf.py`),
e não copiado: ele transforma caixa em arquivo e não sabe nada de hospital. O
resto **não** pode ser importado de lá — `gerar_cena_hospital.py` faz
`import planta as P` no topo, e com a pasta da escola na frente do `sys.path`
ele acordaria com a planta errada na mão.

Comportamento (porta, grade, buraco, piscar de lâmpada) fica em
`red-valve/scripts/stages/escola/`.

## Conferir depois de mexer

```bash
# sobreposição de sala, vão fora de parede, vão encavalado, sala sem porta,
# buraco fora do cômodo, ilha solta no navmesh, e o teste da grade
python3 tools/godot/escola/navmesh.py

# tunel em uma peça só, navmesh do porão inteiro, bocas dentro do túnel
python3 tools/godot/escola/porao.py
```

O próprio `construir.sh` roda os dois antes de gerar, e os geradores imprimem o
tamanho de setor que escolheram e quantas luzes a pior malha enxerga — se
aparecer mais de 8, o renderer mobile vai descartar lâmpada em silêncio.

## O que ainda não está feito

- **O porão não tem inimigo.** O pedido chamou a câmara grande de "arena"; ela
  está construída e com navmesh, mas não há spawner nenhum ligado nela.
- Não tem som próprio de porta, de grade nem de terra; só a ambiência geral.
- O estado do portão do pátio (`GlobalEvents.escola_portao_destrancado`) é de
  **sessão**, não vai para o save. Carregar um save volta com ele trancado — e
  ele se destranca de novo por dentro, em dois passos. Levar isso para o
  `SaveManager` mexeria na serialização do save, que é assunto de outra tarefa.
- A grade e o portão não têm animação de cadeado/corrente: a grade nunca abre e
  o portão simplesmente gira quando destranca.
