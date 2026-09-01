# Plano — Reconstrução 3D da Cidade (Blender via MCP → Godot)

> Projeto: **Red Valve** · Alvo: Godot 4.6, renderer **mobile** · Autoria: Blender 4.x via MCP
> Documento de referência. Cada Etapa é um pedido fechado que você me manda; eu executo e devolvo render de conferência.

---

## 0. Sumário executivo

### 0.1 Blender autora, Godot monta

A cidade é construída nos **dois** programas. A divisão não é preferência — é o que cada ferramenta
consegue fazer:

| Trabalho | Onde | Por quê |
|---|---|---|
| Geometria, UV, vertex color | **Blender** | O Godot não desdobra UV nem tem operações de modelagem (bevel, boolean, solidify). CSG é protótipo e não gera UV; `ArrayMesh` por script gera malha, mas sem nenhuma dessas operações |
| Textura: assar, atlas, *trim sheet*, ORM | **Blender** | O Godot não assa textura nenhuma |
| Terreno, posicionamento, espalhamento | **Godot** | Terrain3D e Proton Scatter vivem lá; a colocação acontece contra o terreno real |
| Iluminação, névoa, LUT, atmosfera | **Godot** | O render do Blender não é o seu renderer. Look calibrado fora do `mobile` @ 0.8 não bate |
| Conferência visual | **Godot** | `editor_screenshot` pelo MCP fecha o loop na hora, dentro do jogo |

**Consequência prática, e é a mais importante deste plano:** cada etapa termina com o resultado
**dentro do jogo**, não com um render do Blender. O critério de aceite é sempre um screenshot no
Godot, sob o Sky3D às 18:08. Nada é avaliado num ambiente que não é o de destino.

A importação não é trabalho manual seu: eu exporto do Blender e monto no Godot no mesmo fluxo,
pelos dois MCPs. O caminho já está provado no seu projeto — `auto_pecas_jimmy.glb` e
`casa_inteira_por_fora.glb` entram exatamente assim.

### 0.2 As ruas geram o terreno

Inversão em relação à primeira versão deste plano. O terreno **não** vem primeiro com as ruas se
adaptando a ele. Eu construo a malha viária no Blender e **derivo o heightmap dela**, que vai para o
Terrain3D. Não existe "terreno do Blender" e "terreno do Godot" para manter em sincronia — existe um
só, e as ruas assentam nele por construção. É assim que loteamento real funciona.

### 0.3 A cidade mora em `city.tscn`, instanciada no `stage_1`

Não construo dentro do `stage_1.tscn`. Construo em **`city.tscn`** e instancio como **um nó** dentro
do `stage_1`. Você tem o que queria — está no `stage_1`, você move, esconde e liga com um clique —
sem transformar um arquivo de 14 MB num de 100 MB, e sem eu precisar mexer na cena que já funciona
enquanto itero. Se der errado, você deleta um nó.

### 0.4 Tudo é gerado por script, não modelado à mão

Os scripts Python moram no disco e leem um `layout.json`. Três motivos:

1. **Limite de payload do MCP.** Mandar milhares de linhas de `bpy` por chamada é frágil. O Blender
   executa só um *bootstrap* de 5 linhas.
2. **Iterabilidade.** Você vai querer mudar largura de rua, densidade de postes, curvatura do eixo.
   Com dado separado de código, é editar um número e re-rodar — não remodelar.
3. **Reaproveitamento no Godot.** O mesmo `layout.json` posiciona colisões, âncoras de gameplay,
   navmesh e *spawns*.

**Idempotência**: toda função apaga a própria coleção antes de reconstruir. Rodar duas vezes nunca
duplica geometria.

### 0.5 Escopo

Regra que você definiu: **casas, igrejas e cemitério são _proxies_ descartáveis** (volume, telhado e
material certo, nada mais). **Ruas, meio-fio, calçada, postes, fiação, iluminação, praça, atmosfera,
texturas e paleta são acabamento final.**

---

## 1. Leitura detalhada da imagem

### 1.1 Câmera e luz da referência

| Aspecto | Leitura |
|---|---|
| Enquadramento | Aéreo oblíquo, *pitch* ~45–50°, lente média-longa (perspectiva contida) |
| Direção do sol | Alto-esquerda, **elevação ~22°**, azimute lançando sombras longas para a direita/baixo |
| Hora | *Golden hour* tardia, luz rasante e quente |
| Névoa | Perspectiva aérea forte: mata do fundo e telhados distantes lavados por véu quente |
| Saturação | **Baixa**. Dominância de meios-tons. Sombras fechadas mas não pretas, *rolloff* suave nos altos |
| Contraste térmico | Faces iluminadas em ocre/dourado × sombras em cinza-marrom **dessaturado** (não azuladas) |

### 1.2 Terreno

Bacia rasa. O terreno **cai da mata (fundo/norte) em direção ao primeiro plano (sul/sudeste)**.
Relevo total estimado em **12–18 m** ao longo de ~450 m — declive suave, perceptível pelos degraus e
arrimos entre lotes, nunca por rampas dramáticas. Duas inflexões: um patamar mais alto onde está a igreja
matriz e o complexo do cemitério (oeste), e uma cota baixa onde fica a estação de tratamento de esgoto.

### 1.3 Distritos identificados

Convenção: **topo da imagem = Norte**, origem do mundo `(0,0)` no centro da praça do obelisco.

| # | Distrito | Posição aprox. (m) | Caráter |
|---|---|---|---|
| A | **Mata fechada** | envolve tudo além de `y>+110`, `x<-330`, `x>+270` | Dossel denso, misto, 14–22 m, verde escuro frio, entra em névoa |
| B | **Complexo do Cemitério** | centro `(-230, -25)`, recinto ~150×130 | Duas construções em pedra clara ornamentada (capela com campanário + mausoléu com frontão/cúpula), muro de pedra, ciprestes colunares, caminhos de saibro |
| C | **Igreja Matriz** | `(-72, +34)` | Nave única, alvenaria rebocada creme, **telhado de ardósia cinza-azulado íngreme**, torre quadrada com coruchéu octogonal, janelas em ogiva, adro elevado com degraus |
| D | **Praça do Obelisco** | `(0, 0)`, rotatória Ø ~38 m | Rotatória em paralelepípedo, ilha ajardinada (grama seca, arbustos baixos), **obelisco sobre base escalonada**, 4–5 braços radiais |
| E | **Núcleo residencial denso** | miolo entre C, D e F | Malha orgânica de casas 1–2 pav., telha colonial desbotada + muita telha metálica enferrujada, quintais estreitos com entulho |
| F | **Eixo comercial** | diagonal `(30,-40)` → `(150,-175)` | Sobrados com loja no térreo: letreiros pintados desbotados, **toldos**, portas de enrolar, fachadas em vermelho-terra; uma ruína com caibros expostos |
| G | **Estação de Tratamento de Esgoto** | `(-150, -230)`, recinto ~70×55 | Dois **tanques circulares de concreto** (um com ponte de clarificador), bacias retangulares, deck de madeira, tubulação aparente, cerca |
| H | **Periferia baixa** | borda sul/sudoeste | Construção improvisada, predominância de telha metálica, lotes irregulares |

### 1.4 Sistema viário — o coração do trabalho

**Pavimento.** Paralelepípedo granítico irregular, cinza-areia, assentado em **arcos/leque**, com juntas
escuras de terra. Há **trilhas de roda desgastadas** ao centro da faixa (pedra polida, mais clara e lisa) e
**remendos de asfalto** escuros sobre a pedra em trechos. Vias secundárias degradam: paralelepípedo falhado
virando terra batida compactada, com buracos e manchas escuras de poça seca.

**Seção transversal padrão** (o detalhe que vende o realismo):

```
 muro/fachada │ calçada │meio-fio│        pista (abaulada 2%)        │meio-fio│ calçada │ muro
              │  1,4 m  │ 0,15 m │              8,0 m               │        │  1,4 m  │
                          ▲ sarjeta: linha escura de detrito e escorrimento
```

- **Meio-fio**: bloco granítico, 0,15 m de altura visível × 0,20 m de largura, com quebras e trechos faltando.
- **Calçada**: placas de concreto moldado, trincadas, desniveladas, com mato nas juntas. **Em vários trechos
  a calçada simplesmente não existe** — a parede da casa encosta na pista. Essa irregularidade é essencial.
- **Sarjeta**: canaleta com faixa escura de sujeira e detrito acumulado junto ao meio-fio.
- **Abaulamento (camber)**: 2%, do eixo para as sarjetas. Sem isso a rua fica "de papelão".
- As ruas **não são retas**: elas curvam, mudam de largura, e os cruzamentos deixam sobras triangulares.

**Hierarquia:**

| Classe | Largura da pista | Pavimento | Calçada |
|---|---|---|---|
| Avenida (Av. Padre Gabriel de Melo) | 10,0 m | Paralelepípedo bom + remendo asfáltico | 1,8 m ambos os lados |
| Via principal | 8,0–8,5 m | Paralelepípedo desgastado | 1,4 m, com falhas |
| Via secundária | 5,5 m | Paralelepípedo falhado | 1,0 m ou ausente |
| Beco / travessa | 2,5–3,5 m | Terra batida com pedra residual | Ausente |

### 1.5 Postes, luminárias e fiação

O elemento mais característico da estética, e o que mais barato entrega "cidade viva":

- **Postes** de concreto/madeira, **8,5 m**, espaçados **~32 m**, **sempre de um lado só** da via, com
  **inclinação leve e aleatória** (±3°). Base com colarinho de concreto e mato.
- **Luminária de braço curvo**: braço de aço ~1,6 m projetando 15° para cima, terminando em **luminária tipo
  "cobra" ou globo/tigela** — enferrujada, vidro amarelado/sujo.
- **Fiação**: no mínimo **3 catenárias** por vão — o cabo de força (triplex, mais espesso e mais tenso) e um
  **feixe bagunçado de telecom** (mais fino, mais barrigudo, com sobras enroladas). Ponto baixo do cabo a
  **~6,0 m** do chão. A **barriga da catenária é obrigatória** — fio reto mata a imagem.
- **Transformador** cilíndrico em ~1 a cada 6 postes, com isoladores e para-raios.
- **Estais (guy wires)** ancorados no chão nos postes de esquina e de fim de linha.

### 1.6 Mobiliário urbano e detritos

Muros baixos de alvenaria com topo quebrado e caco de vidro · cercas de madeira e arame · portões de chapa ·
**caixas d'água** (plástico azul/preto e fibrocimento) nos telhados · antenas de TV · varais com roupa ·
caixotes, tambores, pneus, pilhas de entulho · veículos velhos estacionados (um sedã, uma caminhonete) ·
bueiros e grelhas · **degraus e pequenos arrimos** vencendo o desnível entre lotes · **placas de nome de rua**
esmaltadas em pequenas chapas metálicas (parede de esquina ou poste).

### 1.7 Vegetação

| Camada | Descrição | Altura |
|---|---|---|
| Mata (anel) | Dossel denso misto, verde escuro frio, silhueta irregular com emergentes | 14–22 m |
| Árvore urbana | Copa arredondada larga (mangueira/ficus), verde oliva empoeirado | 7–12 m |
| Cipreste do cemitério | Colunar, verde muito escuro | 6–9 m |
| Arbusto / mato de terreno baldio | Massas soltas, palha-oliva seca | 0,4–1,5 m |
| Grama | Irregular, **seca, amarelo-oliva**, falhada — nunca verde vivo | — |
| Trepadeira / musgo | Manchas em muros de pedra ao norte/sombra | — |

---

## 2. Paleta de cores oficial

Todos os valores em **sRGB hex**. Serão convertidos para linear no Blender e gravados em `palette.json`.
A regra da paleta: **nada acima de ~45% de saturação**, e o dourado da luz faz o resto.

### Superfícies

| Nome | Hex | Uso |
|---|---|---|
| `roof_tile_warm` | `#A8613F` | Telha colonial ainda com cor |
| `roof_tile_faded` | `#8C5138` | Telha colonial média (dominante) |
| `roof_tile_bleached` | `#9A7A66` | Telha muito desbotada / com limo |
| `roof_metal_rust` | `#7A5442` | Telha metálica enferrujada |
| `roof_metal_zinc` | `#8A8378` | Telha metálica cinza / fibrocimento |
| `roof_slate_blue` | `#5A6472` | Ardósia da torre da igreja |
| `wall_whitewash` | `#C9BCA6` | Caiação suja |
| `wall_whitewash_hi` | `#D6CBB4` | Caiação recém-lavada (raro, para variedade) |
| `wall_render_raw` | `#A89880` | Reboco cru sem pintura |
| `wall_brick` | `#8A5B45` | Tijolo aparente |
| `wall_stone_church` | `#C4B79C` | Pedra creme da matriz |
| `wall_stone_cemetery` | `#9B978C` | Pedra cinza do cemitério |
| `paint_shop_red` | `#7E3A32` | Fachada comercial vermelha desbotada |
| `paint_shop_ochre` | `#9C7A45` | Fachada comercial ocre |
| `wood_aged` | `#6B5844` | Madeira envelhecida |
| `wood_dark` | `#56463A` | Madeira em sombra / caibro |
| `metal_rust_dark` | `#5C3E30` | Ferro corroído, portões |

### Chão e via

| Nome | Hex | Uso |
|---|---|---|
| `cobble_base` | `#948B7C` | Paralelepípedo (pedra) |
| `cobble_joint` | `#6C6458` | Junta de terra entre pedras |
| `cobble_polish` | `#A69C8B` | Trilha de roda polida |
| `asphalt_patch` | `#5E564B` | Remendo asfáltico |
| `dirt_road` | `#7A6A55` | Terra batida |
| `sidewalk_concrete` | `#B2A894` | Placa de calçada |
| `curb_granite` | `#8E877A` | Meio-fio de granito |
| `gutter_grime` | `#4E463A` | Sujeira da sarjeta |

### Vegetação e atmosfera

| Nome | Hex | Uso |
|---|---|---|
| `canopy_forest` | `#3E4A2E` | Dossel da mata |
| `canopy_forest_dark` | `#2A3322` | Sombra do dossel |
| `canopy_urban` | `#55603A` | Árvore urbana empoeirada |
| `cypress_dark` | `#2E3A2B` | Cipreste |
| `grass_dry` | `#7E7A52` | Grama seca |
| `sun_light` | `#FFD9A0` | Cor da luz solar |
| `shadow_ambient` | `#4A4438` | Ambiente/preenchimento nas sombras |
| `haze_warm` | `#C8A870` | Névoa / *fog* distante |
| `sky_horizon` | `#D8B98A` | Horizonte |
| `sky_zenith` | `#7E90A0` | Zênite |

---

## 3. Convenções técnicas

### 3.1 Mundo e escala

| Item | Valor |
|---|---|
| Unidade | **1 unidade Blender = 1 metro**, `Scene.unit_settings.length_unit = 'METERS'` |
| Eixo vertical | **+Z** no Blender (o exportador glTF converte para +Y do Godot automaticamente) |
| Origem do mundo | Centro da **Praça do Obelisco** |
| Núcleo da cidade | **600 m (L–O) × 420 m (N–S)** → `x ∈ [-340, +260]`, `y ∈ [-280, +140]` |
| Anel de mata | até raio **900 m** a partir da origem |
| Chunk de streaming | grade de **120 × 120 m** → 5 × 4 = **20 chunks** |
| Referência humana | objeto `REF_Human` (cápsula 1,75 m) permanente na cena, nunca exportado |

### 3.2 Tabela mestra de dimensões

| Elemento | Dimensão |
|---|---|
| Pé-direito térreo / superior | 2,80 m / 2,60 m |
| Altura da casa térrea (beiral / cumeeira) | 3,40 m / 5,10 m |
| Inclinação telha colonial | 30% (~17°) · **beiral 0,60 m** |
| Inclinação telha metálica | 15% (~9°) · beiral 0,35 m |
| Muro de divisa | 1,80–2,20 m |
| Testada do lote (frente) | 6–10 m · profundidade 14–22 m |
| Quadra | 55–75 m de face |
| Poste | 8,50 m · vão 32 m · inclinação ±3° |
| Braço da luminária | 1,60 m · elevação 15° · luminária 0,70 × 0,25 m |
| Flecha do cabo (ponto baixo) | 6,00 m do solo |
| Torre da igreja | 31 m (corpo 22 m + coruchéu 9 m) |
| Nave da igreja | 13 × 32 m · cumeeira 16 m · adro elevado 0,9 m (3 degraus) |
| Obelisco | fuste 9,5 m + base escalonada 2,4 m |
| Rotatória da praça | Ø 38 m · ilha central Ø 22 m |
| Tanque da ETE | Ø 14 m · altura 3,5 m (0,8 m acima do solo) |

### 3.3 Nomenclatura (obrigatória — o script depende dela)

```
SM_<categoria>_<nome>_<variante>     malha estática      SM_road_main_A
SM_prox_<nome>_<var>                 PROXY descartável   SM_prox_house_B3
MI_<superficie>                      material            MI_cobble_main
COL_<alvo>                           colisão simplificada COL_house_B3
OCC_<chunk>                          oclusor             OCC_chunk_2_1
EMP_<gameplay>                       empty de âncora     EMP_valve_door_01
```

Coleções (o exportador varre por elas):

```
CITY/
  00_REF/            blueprint, imagem de referência, REF_Human
  01_TERRAIN/        malha derivada das ruas → fonte do heightmap R16
  02_ROADS/          pista, meio-fio, calçada, sarjeta, remendos
  03_BLOCKS/         quadras, muros, cercas, portões, arrimos, degraus
  04_PROXY_BUILD/    ← DESCARTÁVEL: casas, sobrados
  05_LANDMARKS/      igreja, cemitério, obelisco, ETE  (proxy médio)
  06_STREET_FURN/    postes, luminárias, fios, placas, bueiros, lixo
  07_VEGETATION/     árvores urbanas, mata, arbustos
  08_LOOKDEV/        sol e céu só para conferir material — o look real é no Godot
  09_EXPORT/         cópias unidas por chunk → .glb
```

### 3.4 Estrutura de arquivos

**Lado Blender** — a fábrica:

```
tools/blender/citygen/
├── run.py                  bootstrap chamado pelo MCP
├── lib/
│   ├── util.py             coleção, nome, limpeza idempotente
│   ├── palette.py          paleta → cores lineares
│   ├── materials.py        construção dos materiais
│   ├── roads.py            Etapa 02 — malha viária (gera o terreno)
│   ├── terrain.py          Etapa 01 — heightmap derivado das ruas
│   ├── blocks.py           Etapa 03
│   ├── buildings.py        Etapa 04 (proxies)
│   ├── landmarks.py        Etapa 05
│   ├── props.py            Etapa 06
│   ├── vegetation.py       Etapa 07 — kit + pontos
│   ├── bake.py             assar textura + empacotar ORM
│   └── export.py           .glb por chunk, heightmap R16, splatmap
├── city_data/
│   ├── layout.json         eixos, quadras, lotes, praça
│   ├── props.json          postes, placas, mobiliário, âncoras
│   └── palette.json        a paleta da seção 2
└── out/                    .glb, heightmap, splatmap, texturas assadas
```

**Lado Godot** — a obra:

```
red-valve/
├── scenes/stages/city/
│   ├── city.tscn                    ← instanciada dentro do stage_1
│   ├── chunks/city_chunk_XX_YY.tscn  20 sub-cenas
│   └── city_env.tres                 Environment calibrado
├── assets/3d_model/city/
│   ├── chunks/*.glb                  geometria unida por chunk
│   ├── kit/*.glb                     postes, muros, árvores, props
│   └── textures/*.png                albedo + ORM + normal (1024²)
└── tools/godot/citybuild/
    └── assemble.gd                   script de montagem chamado pelo MCP
```

**Bootstrap MCP no Blender** (a única coisa que trafega por chamada):

```python
import sys, importlib
P = r"/home/dev/Documents/Development/Game Development/Red Valve/Red-Valve/tools/blender/citygen"
if P not in sys.path: sys.path.insert(0, P)
import run; importlib.reload(run)
run.phase(2)
```

---

## 4. Pipeline de textura e material

### 4.1 Restrições reais, verificadas no projeto

| Achado | Consequência para o plano |
|---|---|
| `rendering_method="mobile"` | **Sem** VoxelGI, SDFGI, névoa volumétrica, SSAO/SSIL/SSR. GI tem que ser **assada** (LightmapGI) |
| `scaling_3d/scale=0.8` | Render a 80% com *upscale*. **Detalhe de 10–50 cm ganha de micro-detalhe** — invista em manchas e desgaste, não em poro de 2 mm |
| `occlusion_culling=true` | Preciso **gerar `OccluderInstance3D`** por chunk, ou a cidade densa não renderiza bem |
| Addon `terrain_3d` (dados já existem) | O chão sai como **heightmap R16 + splatmap**, derivado das ruas (§0.2) |
| Addon `proton_scatter` | Vegetação e entulho são espalhados **no Godot**. Blender entrega só o *kit* |
| Addons `sky_3d`, `SunshineClouds2` | Céu e nuvens são do Godot |
| `RealisticTexturePack` em 1024² | Mantenho 1024² como padrão — coerência visual com o `stage_1` |
| `stage_1.tscn` = **14 MB** monolítico | A cidade vai em `city.tscn` instanciada, com `.glb` externos por chunk |

**Achados específicos do `stage_1`** (medidos na cena):

| Achado | Consequência |
|---|---|
| **Dois `WorldEnvironment` aninhados** — `Sky3D` é filho de `WorldEnvironment`, ambos com Environment atribuído | Só um vale, e é o do `Sky3D`. O `fog_enabled` e o `glow_enabled` do pai **não estão sendo aplicados** — hoje não há névoa de profundidade rodando. **Corrigir na Etapa 00** |
| `TimeOfDay` congelado em **18:08**, `editor_time_enabled` e `game_time_enabled` ambos `false` | Notícia boa: já é golden hour, a hora da referência. A base atmosférica está certa — é a âncora do look-dev |
| GLB de cenário com **20–34 MB cada** (um armário tem 29 MB) | Peso que não vira imagem no mobile @ 0.8. A cidade inteira, 20 chunks, deve ficar **menor que um** desses arquivos. É o principal motivo de ativos avulsos não assentarem juntos |
| Conteúdo espalhado por **1450 × 1037 m**, player em `(486, 448)` | Cabe uma cidade de 600 × 420 m com folga, numa região livre do Terrain3D. Narrativamente a trilha da mata desemboca nela |
| `volumetric_fog` e `VoxelGI` configurados | **Ignorados em runtime pelo renderer mobile.** Se a névoa do jogo não bate com a do editor, é essa a causa |

### 4.2 Estratégia de textura

**Reaproveitar primeiro.** O `RealisticTexturePack` já tem `bricks`, `wall`, `wall2/3`, `rustywall`,
`rustymetal`, `metal`, `woodplanks`, `ground`, `drygrass`, `rockwall`. Isso cobre ~60% da cidade e garante
que ela pareça do mesmo jogo que o `stage_1`. O que falta eu autoro no Blender e **asso para textura**:

| Novo mapa | Resolução | Método |
|---|---|---|
| `T_cobble` (paralelepípedo) | 1024², *tileable* 4 m | Geometry Nodes → pedras em leque → bake de Albedo/Normal/AO/Rough |
| `T_cobble_worn` (trilha de roda) | 1024² | Variante polida, mesclada por **vertex color** na pista |
| `T_roof_tile` (telha colonial) | 1024², *tileable* 2 m | Perfil senoidal → bake |
| `T_roof_corrugated` | 1024², *tileable* 1 m | Trapezoidal → bake |
| `T_sidewalk` (placa de concreto) | 1024², *tileable* 3 m | Grid trincado → bake |
| `T_trim_props` (*trim sheet*) | 1024² | Faixas para poste, braço, luminária, placa, grade, tubo |
| `T_signplates` (atlas de placas) | 1024² | Atlas com os nomes de rua renderizados como texto |

**Empacotamento ORM** (Godot 4 `StandardMaterial3D`): `R=Occlusion, G=Roughness, B=Metallic` num único PNG.
Corta o número de samplers pela metade — decisivo no mobile.

**Máscaras de sujeira sem custo de textura**: desgaste, escorrimento e musgo entram como **vertex color**
(canal R = sujeira acumulada, G = desgaste de tráfego, B = umidade/musgo). Zero custo de memória, e o
shader do Godot mistura duas texturas por vertex color. É assim que a rua ganha manchas sem atlas gigante.

**Decals** (suportados no mobile): poças secas, rachaduras, manchas de óleo, pichação, remendos de asfalto.
~15 decals reaproveitados cobrem a cidade inteira.

### 4.3 Iluminação no Godot (mobile-safe)

1. **`DirectionalLight3D`** — elevação 22°, cor `#FFD9A0`, energia ~1,6, sombra `PSSM 4 Splits`, `blend_splits` on.
2. **`LightmapGI`** assada para toda a geometria estática (única GI disponível no mobile). Rebote quente das
   paredes ocre é o que dá a "sopa dourada" da referência.
3. **Postes**: **não** colocar 60 `OmniLight3D`. A luz do poste vai **assada no lightmap** + material
   `emission` na luminária. Só **2–4 luzes dinâmicas** perto do jogador, ativadas por `VisibleOnScreenNotifier3D`.
4. **`Environment`**: `fog_enabled` (de profundidade), `fog_light_color = #C8A870`, `fog_sun_scatter` alto,
   `fog_density` baixa (~0.008), `fog_aerial_perspective` ~0.6. Tonemap **Filmic** ou **AgX**, `white ≈ 4.5`.
5. **Grade sépia**: `adjustment_enabled` + **LUT** (`color_correction`) — é o passo que fecha a cor da
   referência de uma vez, e é praticamente de graça.
6. **Poeira**: um `GPUParticles3D` de ~200 partículas em *billboard* seguindo a câmera. Vende a atmosfera.

---

## 5. Orçamento técnico (renderer mobile @ 0.8 scale)

| Métrica | Meta | Como se atinge |
|---|---|---|
| Triângulos visíveis | **< 600 k** (teto 900 k) | Proxies baixos, occlusion culling, LOD por chunk |
| *Draw calls* | **< 300** | MultiMesh para todo prop repetido; união estática por chunk |
| Materiais únicos | **< 25** | Atlas + ORM + vertex color no lugar de variantes |
| Casa proxy | 250–500 tris | Caixa + telhado + platibanda, sem detalhe |
| Poste completo | ~420 tris | *Trim sheet*, MultiMesh |
| Catenária | 96 tris | 8 segmentos × cilindro de 6 lados; a barriga é geométrica |
| Igreja (proxy médio) | ~8 k tris | Você troca depois |
| Cemitério / ETE | ~12 k / ~6 k tris | ETE é acabamento (é POI de gameplay) |
| Textura total em VRAM | < 180 MB | 1024² + ORM + compressão VRAM do Godot |

**MultiMesh obrigatório para**: postes, luminárias, placas, muros modulares, telhas de caixa d'água,
tambores, pneus, caixotes, bueiros, degraus, árvores.

---

## 6. Ruas e placas de nome

As placas são **chapas metálicas esmaltadas** (0,42 × 0,14 m), montadas em **parede de esquina a 2,3 m** ou
em **braço curto no poste**. O texto entra como **atlas de textura assado** (`T_signplates`), nunca como
geometria de texto, e **nunca escrito no chão** — o texto na imagem de referência era só legenda.

| Via | Classe | Traçado aproximado |
|---|---|---|
| **Av. Padre Gabriel de Melo** | Avenida 10 m | `(-260,-245) → (210,-215)`, eixo sul |
| **R. Padre Gabriel de Melo** | Principal 8,5 m | `(110,-235) → (250,-160)`, continuação sudeste |
| **R. Margarida Maria Alves** | Principal 8,0 m | `(-320,+25) → (+10,-110)`, eixo NO–SE do miolo |
| **R. Eustáquia Portela** | Principal 8,5 m | `(+60,+75) → (+185,-175)`, eixo NNE–SSE |
| **R. Terra Velha** | Secundária 6,0 m | `(-330,+90) → (-300,-140)`, borda oeste / cemitério |
| **Largo da Matriz** | Adro / largo | Forecourt em `(-72,+8)` |
| **R. do Pobre** | Secundária 4,5 m | `(+20,-190) → (+55,-250)` |
| **Tv. da Bica** | Travessa 3,5 m | Conector do miolo |
| **Beco do Esgoto** | Beco 2,8 m | Acesso à ETE |
| **R. do Obelisco** | Radial 7,0 m | Braço norte da praça |

Mais **~14 secundárias** e **~20 becos** sem placa, gerados proceduralmente a partir das quadras.

---

## 7. As Etapas

Cada etapa tem **metade Blender e metade Godot**, e termina com o resultado **dentro do jogo**.
O critério de aceite é sempre um screenshot no Godot, sob o Sky3D às 18:08 — nunca um render do
Blender. Ao fim de cada etapa entrego os scripts commitáveis dos dois lados. Só avanço com seu OK.

---

### Etapa 00 — Fundação e look base

**Blender:** estrutura de coleções · `palette.json` com a seção 2 · `materials.py` com todos os
materiais nas cores certas · `REF_Human` · imagem de referência alinhada · **placa de teste** com
todos os materiais lado a lado.

**Godot:** cria `scenes/stages/city/city.tscn` e instancia no `stage_1` · **corrige o conflito dos
dois `WorldEnvironment`** · cria `city_env.tres` com fog de profundidade de fato ativo · confirma o
`TimeOfDay` travado em 18:08 · importa a placa de teste para dentro da cena.

**Aceite:** screenshot da placa de teste **no Godot**, sob o Sky3D, comparada lado a lado com a
referência. Acertar a cor no ambiente de destino antes de modelar evita refazer tudo depois.

---

### Etapa 01 — Traçado e terreno derivado ⭐ *decisão*

**Blender:** `layout.json` completo — eixos de rua como polilinhas com largura e classe, polígonos
de quadra, subdivisão em lotes, *footprints* dos landmarks, limite da mata · malha viária esquemática
· **deriva o heightmap R16 e o splatmap a partir das ruas** (§0.2).

**Godot:** escolhe a região livre do Terrain3D (longe da trilha e da oficina do Jimmy) · aplica
heightmap e splatmap · screenshot de topo.

**Aceite:** vista de topo no Godot comparável à planta da seção 6. **Ponto de decisão mais importante
do projeto** — aprovada a planta, o resto flui.

---

### Etapa 02 — Sistema viário ⭐ *prioridade máxima sua*

**Blender:** pista com abaulamento de 2% · meio-fio com quebras e trechos faltando · calçada trincada
e **ausente em trechos** · sarjeta em vertex color · cruzamentos com sobras triangulares · remendos
de asfalto · trilhas de roda · bueiros e grelhas · degraus e arrimos vencendo desnível · transição
paralelepípedo → terra batida nos becos · **UV ao longo do caminho** · texturas assadas (`T_cobble`,
`T_cobble_worn`, `T_sidewalk`, `T_dirt`) com ORM empacotado.

**Godot:** importa os `.glb` por chunk · aplica `StandardMaterial3D` com ORM · colisão · screenshots
**a 1,70 m de altura** e do ângulo aéreo da referência.

**Aceite:** a rua lê como rua na altura do jogador, dentro do jogo — não só de cima.
*Provável 2 sessões: é a etapa mais pesada e a que você mais quer bem feita.*

---

### Etapa 03 — Quadras, muros e divisas

**Blender:** kit de ~10 módulos — muro de 1,8–2,2 m com topo quebrado, cerca de madeira, cerca de
arame, portão de chapa, arrimo, escada, mureta.

**Godot:** MultiMesh ao longo das divisas do `layout.json` · terrenos baldios · screenshot em nível
de rua.

**Aceite:** a silhueta em nível de rua já parece uma cidade mesmo sem casas.

---

### Etapa 04 — Casas proxy — *descartável*

**Blender:** ~12 variantes paramétricas (térrea colonial, térrea metálica, sobrado, sobrado comercial
com toldo e letreiro, ruína), 250–500 tris cada.

**Godot:** instanciadas nos lotes com rotação, escala e paleta variadas · caixa d'água, antena e varal
como props opcionais · **um `EMP_` de âncora por casa** para você trocar depois.

**Aceite:** massa e ritmo dos telhados batendo com a referência. **Sem investir em detalhe** — é proxy.

---

### Etapa 05 — Landmarks

**Blender:** igreja matriz e complexo do cemitério em **proxy** · praça do obelisco e ETE em
**acabamento**.

**Godot:** posicionados · praça com pavimento radial e ilha ajardinada · ETE com tanques, ponte de
clarificador, bacias, deck, tubulação e cerca.

**Aceite:** silhuetas corretas na vista aérea; praça e ETE já prontas para o jogo.

---

### Etapa 06 — Postes, fiação e mobiliário ⭐ *prioridade máxima sua*

**Blender:** poste, braço e luminária no *trim sheet* · **catenárias com flecha calculada** e feixe
de telecom bagunçado · transformador · estais · placas de rua com atlas de texto assado · bueiros,
lixeiras, tambores, pneus, caixotes, entulho, veículos abandonados.

**Godot:** MultiMesh a cada ~32 m com inclinação aleatória de ±3° · luminárias com material
`emission` · **a luz dos postes vai assada no LightmapGI, não em 60 `OmniLight3D`** — só 2–4 luzes
dinâmicas perto do jogador, ativadas por `VisibleOnScreenNotifier3D`.

**Aceite:** a fiação cruzando o céu na vista aérea. É a assinatura visual da referência.

---

### Etapa 07 — Vegetação e anel de mata

**Blender:** kit de árvores — dossel de mata, copa urbana larga, cipreste, arbusto, moita —
reaproveitando `BIRCH` e `SPRUCE` que você já tem onde couber.

**Godot:** **Proton Scatter** para o anel de mata com silhueta irregular, árvores urbanas em praças e
quintais, mato em terreno baldio, junta de calçada e pé de muro.

**Aceite:** a linha de horizonte de mata fecha a cidade por todos os lados, como na referência.

---

### Etapa 08 — Atmosfera e look final

**Blender:** ajuste fino da paleta em conjunto · máscaras de sujeira e desgaste em vertex color ·
rebake do que precisar.

**Godot — aqui é o grosso do trabalho:** calibra o fog de profundidade (`fog_light_color` = `#C8A870`,
`fog_aerial_perspective` alto, densidade baixa) · tonemap Filmic ou AgX · **LUT sépia** em
`adjustment_enabled` · partículas de poeira · **LightmapGI assado** · afinação do Sky3D às 18:08.

**Aceite:** screenshot aéreo **no jogo** lado a lado com a referência. É aqui que a estética fecha.

---

### Etapa 09 — Otimização e fechamento

A integração já aconteceu ao longo de todas as etapas anteriores — esta é só o fechamento técnico.

**Godot:** `OccluderInstance3D` por chunk · LOD0/LOD1 · colisões simplificadas e trimesh só onde
precisa · união estática por chunk · navmesh · `props.json` com as âncoras de gameplay · passagem com
o *profiler*.

**Aceite:** roda dentro do orçamento da seção 5, com o *profiler* aberto.

## 8. Âncoras de gameplay (opcional, mas barato agora)

Você mandou ignorar as legendas — mas três delas são âncoras que o `layout.json` pode reservar **de graça**
agora e que custariam retrabalho depois. Se não quiser, é só dizer e eu removo:

- `EMP_valve_door_*` — pontos das **portas de válvula vermelha** (4 marcações na referência: duas perto da
  ETE, uma no eixo comercial, uma no sudeste).
- `EMP_jimmy_house` — a **Casa do Jimmy** em `(+48,-196)`. Vale porque você **já tem**
  [oficina_jimmy.tscn](red-valve/scenes/stages/prolog/oficina_jimmy.tscn) e
  [cutscene_sub_scene_portal_jimmy.tscn](red-valve/scenes/stages/prolog/cutscene_sub_scene_portal_jimmy.tscn) —
  a fachada na cidade pode casar com o interior que já existe.
- `EMP_ete_entrance` — entrada da estação de tratamento.

---

## 9. Como me pedir cada etapa

Pedido curto basta — o contexto está neste documento.

```
Executa a Etapa 02 do plano da cidade.
```

Com ajuste antes de executar:

```
Executa a Etapa 02, mas com calçada de 1,8 m nas principais
e sem remendo de asfalto na Margarida Maria Alves.
```

Para rever sem reconstruir (screenshot no Godot, não render do Blender):

```
Me mostra a Etapa 02 do ângulo da referência e a 1,70 m.
```

**Ordem recomendada:** `00 → 01 → 02 → 06 → 03 → 04 → 05 → 07 → 08 → 09`.

A troca (06 antes de 03 e 04) é proposital: **rua e fiação juntas já entregam a estética da
referência em nível de rua**. Você julga se a direção está certa dentro do jogo, antes de gastar
sessões inteiras em massa construída.
