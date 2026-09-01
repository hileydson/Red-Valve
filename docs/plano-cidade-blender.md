# Plano — Reconstrução 3D da Cidade (Blender via MCP → Godot)

> Projeto: **Red Valve** · Alvo: Godot 4.6, renderer **mobile** · Autoria: Blender 4.x via MCP
> Documento de referência. Cada Etapa é um pedido fechado que você me manda; eu executo e devolvo render de conferência.

---

## 0. Sumário executivo

A cidade **não será modelada à mão**. Ela será **gerada por scripts Python versionados**, alimentados por um
arquivo `layout.json` que descreve eixos de rua, quadras, lotes e props. Isso é obrigatório por três motivos:

1. **Limite de payload do MCP.** Mandar milhares de linhas de `bpy` por chamada é frágil. Os scripts moram no
   disco; o Blender só executa um *bootstrap* de 5 linhas.
2. **Iterabilidade.** Você vai querer mudar largura de rua, densidade de postes, curvatura do eixo. Com dado
   separado de código, é editar um número e re-rodar — não remodelar.
3. **Reaproveitamento no Godot.** O mesmo `layout.json` pode depois posicionar colisões, waypoints de IA,
   navmesh e os *spawns* de gameplay.

Regra de ouro do escopo que você definiu: **casas, igrejas e o cemitério são _proxies_ descartáveis**
(volume + telhado + material certo, nada mais). **Ruas, meio-fio, calçada, postes, fiação, iluminação,
praça, atmosfera, texturas e paleta são acabamento final.**

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
  01_TERRAIN/        malha do terreno (fonte do heightmap)
  02_ROADS/          pista, meio-fio, calçada, sarjeta, remendos
  03_BLOCKS/         quadras, muros, cercas, portões, arrimos, degraus
  04_PROXY_BUILD/    ← DESCARTÁVEL: casas, sobrados
  05_LANDMARKS/      igreja, cemitério, obelisco, ETE  (proxy médio)
  06_STREET_FURN/    postes, luminárias, fios, placas, bueiros, lixo
  07_VEGETATION/     árvores urbanas, mata, arbustos
  08_LIGHTING/       sol, céu, sondas (só look-dev, não exporta)
  09_EXPORT/         cópias unidas por chunk + oclusores
```

### 3.4 Estrutura de arquivos no repositório

```
tools/blender/citygen/
├── run.py                  bootstrap chamado pelo MCP
├── lib/
│   ├── util.py             helpers de coleção, nome, limpeza idempotente
│   ├── palette.py          paleta → cores lineares
│   ├── materials.py        construção de todos os materiais
│   ├── terrain.py          Etapa 1
│   ├── roads.py            Etapa 2
│   ├── blocks.py           Etapa 3
│   ├── buildings.py        Etapa 4 (proxies)
│   ├── landmarks.py        Etapa 5
│   ├── props.py            Etapa 6 (postes/fios/placas)
│   ├── vegetation.py       Etapa 7
│   ├── lookdev.py          Etapa 8
│   └── exporter.py         Etapa 9
├── city_data/
│   ├── layout.json         eixos de rua, quadras, lotes, praça
│   ├── props.json          postes, placas, mobiliário, âncoras
│   └── palette.json        a paleta da seção 2
└── out/                    GLBs, heightmap, splatmap, renders
```

**Bootstrap MCP** (a única coisa que trafega pelo MCP a cada chamada):

```python
import sys, importlib
P = r"/home/dev/Documents/Development/Game Development/Red Valve/Red-Valve/tools/blender/citygen"
if P not in sys.path: sys.path.insert(0, P)
import run; importlib.reload(run)
run.phase(2)          # roda a Etapa 2 de forma idempotente
```

**Idempotência**: toda função apaga sua própria coleção antes de reconstruir. Rodar duas vezes nunca duplica
geometria. Isso é o que torna a iteração viável.

---

## 4. Pipeline de textura e material

### 4.1 Restrições reais do seu projeto (verificadas no `project.godot`)

| Achado | Consequência para o plano |
|---|---|
| `renderer/rendering_method="mobile"` | **Sem** VoxelGI, SDFGI, névoa volumétrica, SSAO/SSIL/SSR. GI tem que ser **assada** (LightmapGI) ou pintada no material |
| `scaling_3d/scale=0.8` | Render a 80% e *upscale*. **Detalhe de média frequência ganha de micro-detalhe** — invista em manchas/desgaste de 10–50 cm, não em poro de 2 mm |
| `occlusion_culling=true` | Preciso **gerar `OccluderInstance3D`** a partir do volume dos prédios, ou a cidade densa não vai render bem |
| Addon `terrain_3d` (+ dados `.res` já existentes) | O chão **não sai como malha do Blender** — sai como **heightmap R16 + splatmap** para o Terrain3D |
| Addon `proton_scatter` | Vegetação e entulho **são espalhados no Godot**, não assados no Blender. Blender entrega só o *kit* de árvores/arbustos |
| Addons `sky_3d`, `SunshineClouds2` | Céu e nuvens são do Godot. A luz do Blender é **só para look-dev/conferência** |
| Texturas do `RealisticTexturePack` são **1024²** | Mantenho 1024² como padrão para coerência com o `stage_1` |
| `stage_1.tscn` = **14 MB monolítico** | A cidade **não pode** repetir isso. Vai em `.glb` externos + cenas por chunk |

> ⚠️ Observação: o `stage_1` tem `volumetric_fog_enabled` e `VoxelGI` configurados, mas **o renderer mobile
> ignora os dois em runtime**. Se a névoa que você vê no jogo hoje não bate com a do editor, é essa a causa.
> A atmosfera da cidade vai ser construída com **fog de profundidade + céu + partículas de poeira**, que
> funcionam no mobile.

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

Cada etapa é **um pedido fechado**. Ao fim de cada uma eu entrego: os scripts commitáveis, um **render de
viewport de conferência**, e o critério de aceite verificado. Só avanço com seu OK.

---

### Etapa 0 — Fundação e look-dev (1 sessão)

**Faço:** estrutura de pastas e coleções · `palette.json` com a seção 2 · `materials.py` com todos os
materiais já nas cores certas · `REF_Human` · imagem de referência como *background* alinhada ·
sol a 22° + céu de look-dev · uma **"placa de teste"** com todos os materiais lado a lado.

**Aceite:** o render da placa de teste bate com a paleta da referência quando comparado lado a lado.

> Esta etapa vale ouro. Acertar a cor **antes** de modelar evita refazer tudo depois.

---

### Etapa 1 — Terreno e `layout.json` (1 sessão)

**Faço:** malha de terreno 600×420 m com a bacia rasa (queda de ~15 m para SE, patamar da igreja, cota baixa
da ETE) · escrevo o **`layout.json` completo**: todos os eixos de rua como polilinhas com largura e classe,
polígonos de quadra, subdivisão em lotes, footprints dos *landmarks*, limite da mata · marcações visuais
das quadras sobre o terreno para você conferir a planta de cima.

**Aceite:** vista de topo do *blockout* comparável à referência; você aprova a planta antes de eu gastar
esforço em acabamento.

**Este é o ponto de decisão mais importante do projeto.** Se a planta estiver certa, o resto flui.

---

### Etapa 2 — Sistema viário completo ⭐ *(prioridade máxima sua)*

**Faço:** geração da malha viária a partir das polilinhas — pista com **abaulamento de 2%** projetada no
terreno · **meio-fio** com quebras e trechos faltando · **calçada** com placas trincadas e trechos ausentes ·
**sarjeta** com vertex color de sujeira · **cruzamentos** resolvidos com sobras triangulares · **remendos de
asfalto** como geometria decalcada · **trilhas de roda** pintadas em vertex color · bueiros e grelhas ·
degraus e arrimos onde a rua vence desnível · transição paralelepípedo → terra batida nos becos.

**Aceite:** perfil transversal correto em corte; a rua lê como rua a 1,70 m de altura (vista do jogador),
não só de cima.

*Provável 2 sessões — é a etapa mais pesada e a que você mais quer bem feita.*

---

### Etapa 3 — Quadras, muros e divisas (1 sessão)

**Faço:** muros de divisa modulares (1,8–2,2 m) com topo quebrado · cercas de madeira e arame · portões de
chapa · arrimos e escadas entre lotes · calçamento de quintal · terrenos baldios com massa de mato ·
tudo em **MultiMesh** a partir de ~10 módulos.

**Aceite:** a silhueta em nível de rua já parece uma cidade mesmo sem casas.

---

### Etapa 4 — Casas proxy (1 sessão) — *descartável*

**Faço:** ~12 variantes paramétricas (térrea telha colonial, térrea metálica, sobrado, sobrado comercial com
toldo e letreiro, ruína) · instanciadas nos lotes com rotação/escala/paleta variadas · caixa d'água, antena,
varal como props opcionais por casa · **cada casa com um `EMP_` de âncora** para você trocar depois.

**Aceite:** massa e ritmo dos telhados batendo com a referência. **Sem investir em detalhe** — é proxy.

---

### Etapa 5 — *Landmarks* (1 sessão) — *igreja/cemitério em proxy, ETE em acabamento*

**Faço:** **Igreja Matriz** proxy (nave + torre + coruchéu + adro com degraus, telhado ardósia) ·
**Complexo do Cemitério** proxy (capela, mausoléu, muro de pedra, caminhos de saibro, ciprestes) ·
**Praça do Obelisco** em acabamento (rotatória, ilha ajardinada, obelisco com base escalonada, bancos,
canteiro) · **ETE em acabamento** (tanques circulares, ponte de clarificador, bacias, deck, tubulação, cerca).

**Aceite:** silhuetas corretas na vista aérea; praça e ETE prontas para o jogo.

---

### Etapa 6 — Postes, fiação e mobiliário ⭐ *(prioridade máxima sua)*

**Faço:** poste + braço + luminária no *trim sheet* · distribuição a cada ~32 m com inclinação aleatória ·
**catenárias reais** (3 cabos por vão, flecha calculada, feixe de telecom bagunçado) · transformadores ·
estais · **placas de nome de rua** com o atlas de texto · bueiros, lixeiras, tambores, pneus, caixotes,
pilhas de entulho, veículos abandonados · tudo em MultiMesh.

**Aceite:** a fiação cruzando o céu na vista aérea é a assinatura visual da referência — tem que estar lá.

---

### Etapa 7 — Vegetação e anel de mata (1 sessão)

**Faço:** kit de árvores (dossel de mata, copa urbana larga, cipreste, arbusto, moita de mato) reaproveitando
`BIRCH`/`SPRUCE` que você já tem quando couber · **anel de mata** com silhueta irregular e emergentes ·
árvores urbanas nas praças e quintais · mato em terreno baldio, junta de calçada e pé de muro ·
**exporto os pontos de espalhamento para o Proton Scatter** em vez de assar tudo no Blender.

**Aceite:** a linha do horizonte de mata fecha a cidade por todos os lados, como na referência.

---

### Etapa 8 — Look-dev final e atmosfera (1 sessão)

**Faço:** ajuste fino de toda a paleta em conjunto · máscaras de sujeira/desgaste por vertex color em tudo ·
sol/céu/névoa calibrados · **3 renders de conferência** (o ângulo aéreo da referência, uma vista de rua a
1,70 m, e um contra-luz) · **LUT sépia** exportada para o Godot · **preset de `Environment`** pronto para colar.

**Aceite:** o render aéreo lado a lado com a referência — é aqui que a gente fecha a estética.

---

### Etapa 9 — Export e integração no Godot (1–2 sessões)

**Faço:** bake de todos os materiais procedurais para textura (ORM empacotado) · **heightmap R16 + splatmap**
para o Terrain3D · união estática por chunk → **20 `.glb`** em `assets/3d_model/city/` · **colisões
simplificadas** (`COL_`) e trimesh só onde precisa · **`OccluderInstance3D`** por chunk · LOD0/LOD1 ·
cena `city_root.tscn` com sub-cenas por chunk (**sem repetir o monolito de 14 MB do `stage_1`**) ·
`Environment` + `LightmapGI` + `DirectionalLight3D` configurados · `props.json` com as âncoras de gameplay.

**Aceite:** roda no editor dentro do orçamento da seção 5, com o *profiler* aberto.

---

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

Formato do pedido (curto é suficiente — o contexto está neste documento):

```
Executa a Etapa 2 do plano da cidade.
```

Se quiser ajustar algo antes:

```
Executa a Etapa 2, mas com calçada de 1,8 m nas principais
e sem remendo de asfalto na Margarida Maria Alves.
```

Para revisar sem reconstruir:

```
Me mostra um render da Etapa 2 do ângulo da referência.
```

**Ordem recomendada:** `0 → 1 → 2 → 6 → 3 → 4 → 5 → 7 → 8 → 9`.

A troca (6 antes de 3/4) é proposital: **postes e fiação junto com a rua já entregam a estética da referência**
em nível de rua. Você consegue avaliar se a direção está certa antes de gastar sessões em massa construída.
