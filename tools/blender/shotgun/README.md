# A caçadeira que dobra

A *The Negotiator Mk. III* é a **V3** cortada em duas peças para poder abrir na
recarga. O corte é feito por script, a partir do `.glb` que já existia:

```bash
blender -b -P tools/blender/shotgun/gerar_shotgun.py
/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64 --headless --path red-valve --import
```

O import é obrigatório e é o de sempre: reimportar pelo editor (o botão, ou o
MCP) responde "reimportado" e **não reescreve o `.scn`** — o jogo continua
carregando a geometria velha, sem erro nem aviso.

## Por que cortar, e não riggar

`the_negotiator_V3.glb` é uma casca **única** de 4.497 triângulos, sem osso, sem
`.blend` fonte, com a textura assada num atlas só. Cano e coronha são a mesma
superfície contínua: não existe dobradiça para pesar vértice nenhum. Uma
break-action precisa abrir de verdade, então a dobra é **corte**.

### Onde a malha quebra

Não foi escolhido no olho. Perfilando a malha ao longo do X (o comprimento da
arma), a báscula aparece sozinha:

| Faixa em X | O que é | Como se sabe |
| :--- | :--- | :--- |
| −0,957 … −0,030 | canos + fore-end | seção constante: 0,226 de largura, base sempre acima de +0,057 |
| −0,030 … +0,24 | báscula | em X = 0 a largura estreita para 0,188 e o fundo despenca para −0,035 (o guarda-mato) |
| +0,24 … +0,956 | coronha | Y desce até −0,315 no rabo |

O corte fica em **X = −0,030**, e ali a contagem de vértices tem um pico: é o
anel gravado que o desenho já tem. A emenda se esconde numa quina que existia.

O pino da charneira é o canto inferior dianteiro da báscula, **(−0,030, +0,057,
0)**, e o eixo é o **Z** do modelo.

### O que se modela a mais

Cortar uma casca fechada abre buraco dos dois lados, e com a arma aberta esse
buraco fica **de frente para a câmera** — é o quadro principal da recarga. Numa
break-action ele não é tampa cega: é a culatra. Então o corte vem com

- as **duas câmaras**, furadas da culatra para dentro do cano. O centro delas
  sai dos bores de verdade — os vértices da boca se agrupam em Z = ±0,060, e o
  eixo do furo sobe 0,152 por unidade de X ao longo da arma;
- os **dois extratores**, pinos na face da báscula apontando para o cano.

Tudo isso em material próprio (`negotiator_interior`, aço escuro fosco): o atlas
assado não tem "interior", e face nova com UV daqui puxaria pixel de um lugar
aleatório da textura.

## Três armadilhas que custaram tempo

**1. O `.glb` entra no Blender com 2.819 arestas de borda.** A casca é fechada
(2 bordas, medido no arquivo), mas o glTF guarda um vértice **por canto de
face** nas costuras de UV e de normal: os 2.245 vértices chegam como 3.841, e
quase toda aresta vira borda. Cortar uma malha assim não abre um buraco, abre 68
pedaços soltos, e `holes_fill` não tem o que tapar. Por isso `soldar()` roda
antes de tudo. As UVs não se perdem — no Blender elas moram no canto da face.

**2. `bmesh.ops.holes_fill` tem `sides=4` por padrão.** É "quantos lados o
buraco pode ter para ser tapado". A culatra tem 68. Sem `sides=0` a tampa
simplesmente não nasce, e sem tampa a peça fica aberta e os booleanos exatos
seguintes não colam nada — o sintoma é a câmara não aparecer.

**3. As normais customizadas mandam mais que o flag de suave/chato.** A solda
transforma as normais do glTF em *custom split normals*, e a tampa — face nova,
sem normal própria — sai ondulada, com a sombra escorrendo de um lado ao outro
da chapa. `refazer_sombreamento()` apaga e remonta por ângulo (35°): quina onde
há quina, liso onde é liso, nas faces velhas e nas novas.

## O que sai

| Arquivo | O que é |
| :--- | :--- |
| `the_negotiator_V3_dobravel.glb` | a arma em duas peças, para a **mão** do Maycow |
| `cartridge/the_negotiator_V3_bullet_x2.glb` | dois cartuchos lado a lado, no tamanho real, para o **balcão** |

A hierarquia do primeiro é o contrato com o jogo:

```
the_negotiator_V3_dobravel
├── corpo        báscula + coronha, com os dois extratores
└── charneira    vazio no pino
    └── canos    canos + fore-end, com as duas câmaras
```

Abrir a arma é **um número**: `charneira.rotation.z`, positivo desce a boca.

O `.glb` inteiro **não** é o que o menu mostra. Lá vai a V3 original: a peça
cortada só existe na mão, onde a recarga precisa dela.

## Quem consome isto

`red-valve/scripts/player/player_shotgun_hold.gd` — e ele repete as medidas do
corte (`CORTE_X`, `CHARNEIRA_NO_MODELO`, `CAMARA_*`, `BOCA_NO_MODELO`) nas
constantes dele. **Mexeu aqui, muda lá**: são os mesmos números vistos dos dois
lados, e não há como um descobrir o outro.

## Conferir depois de mexer

```bash
# a hierarquia, as peças, o item no balcão, os textos, e o ciclo tiro/recarga
/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64 --headless \
    --path red-valve res://tools/shotgun/conferir_shotgun.tscn
```

E três harnesses de foto, que precisam de tela (**sem** `--headless`):

| Cena | O que responde |
| :--- | :--- |
| `tools/shotgun/foto_pose.tscn` | a pose parado: porte, mira e a recarga em 6 quadros |
| `tools/shotgun/foto_costas.tscn` | o Maycow **andando e correndo**, visto de trás |
| `tools/shotgun/foto_tiro.tscn` | o clarão, as fagulhas e a fumaça, quadro a quadro |

O primeiro imprime `aberta 0%` / `100%` em cada quadro da recarga: 16° de dobra
numa arma vista meio de lado são dois pixels, e olhar a foto não distingue
"abriu pouco" de "não abriu".

### Por que existe um harness só pras costas

O `foto_pose` fotografa o Maycow **parado**, e há um defeito que só aparece em
movimento: a omoplata esquerda deforma enquanto ele anda ou corre. O
`foto_costas` mede, por junta, o quanto cada osso está fora do descanso.

| | direção do braço E, fora do descanso |
| :--- | :--- |
| sem arma, correndo | 24° |
| com arma, **parado** (a pose aprovada) | 55° |
| com arma, **correndo** | **111°** |

Cem graus entre dois ossos é mais do que skinning linear aguenta.

**Quatro tentativas de conserto, todas revertidas.** Vale registrar para ninguém
repetir:

| tentativa | mediu | resultado |
| :--- | :--- | :--- |
| clavícula toma parte do giro | 111° → 86° | deformou igual |
| tirar o amortecimento do tronco | 49,2 cm de estica com e sem | nada |
| trazer a mão esquerda pra trás no cano | parado 49,4 → 45,4; correndo igual | nada na corrida |
| a arma acompanhar o giro do peito no porte | 111° → 54° | **funcionou, e moveu a pose** |

A última resolvia de verdade, mas mexia na posição da arma e da mão direita —
que estavam afinadas à mão pelo jogador, no F9 — e por isso foi revertida junto
com as outras.

**Por que qualquer mexida no ombro move a arma:** o braço esquerdo está
*travado no limite de alcance* (49,2 cm num braço de 49,0; ver o `braço
esticado` no relatório). Com o IK no limite ele não resolve mais, só aponta o
braço reto — e aí mudar a posição do ombro muda **onde a mão para**, o que
reposiciona tudo. Enquanto esse número encostar no alcance, não existe conserto
de ombro que seja neutro.

**O que ficou no lugar:** não deixar a câmera ver a omoplata. Com a caçadeira
equipada, o tronco não faz mais a inclinação de strafe pra ESQUERDA (o `alvo_y`
positivo, na seção 8 do `player.gd`) — é esse giro que trazia o lado esquerdo
das costas pra frente da câmera. A inclinação pra direita continua, e o pivô do
corpo parado também: aquele não é o modelo girando, é o modelo ficando plantado
enquanto a câmera orbita.

Duas outras tentativas de enquadramento entraram e saíram: um zoom extra na
corrida e um deslocamento do corpo pra esquerda (`shotgun_offset_x`). As duas
mexiam demais em como o jogo já estava.

### Ler ângulo de osso depois de um SkeletonModifier3D

Não dá de fora: o `Skeleton3D` guarda as poses antes de rodar a pilha e as
devolve depois de desenhar, então `get_bone_pose()` chamado de outro nó entrega
a pose crua da AnimationTree — o mesmo número com arma e sem arma. O
`foto_costas` pendura um `SkeletonModifier3D` espião no fim da pilha.

E ao decompor o giro em direção/rolagem, o eixo tem de estar no quadro do
**pai** (girado pelo descanso). No quadro errado a conta acusou 72° de rolagem
onde havia 10.

