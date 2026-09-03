# Cidade procedural — referência v2

Como a cidade é gerada, onde mexer em cada coisa, e as armadilhas que já
custaram caro. Atualizado em 03/09/2026.

---

## 1. Como funciona, em uma frase

A geometria é gerada por script Python no **Blender headless**, exportada em
**glTF** para `red-valve/assets/3d_model/city/`, e o que é repetitivo demais
para virar malha (14 mil plantas, 296 luzes) é montado no **Godot** por
scripts `@tool` que leem **JSON** produzido pelo mesmo build do Blender.

```
tools/blender/citygen/          gerador (Python)
  ├── lib/*.py                  cada etapa: roads, houses, props, vegetation…
  ├── city_data/                dados de entrada (signs.json, layout)
  └── out/                      saída: houses.json, poles.json, scatter.json
              │
              ├── glTF ──────►  red-valve/assets/3d_model/city/*.gltf
              └── JSON ──────►  red-valve/assets/3d_model/city/*.json
                                        │
red-valve/tools/godot/citybuild/*.gd  ──┘  scripts @tool que leem o JSON
              │
              └──────────────►  red-valve/scenes/stages/city/city.tscn
```

---

## 2. Rebuild completo

Nunca rode o gerador pela MCP do Blender: numa etapa longa a conexão pendura e
não volta. **Sempre headless:**

```bash
/snap/blender/7740/blender --background --factory-startup --python /caminho/rebuild.py
```

O `rebuild.py` (script driver, fica no scratchpad) faz, nesta ordem:

1. `run._build(fases=("roads","walls","houses","vegetation","props"))`
2. checagem `verts_no_asfalto` — nenhum vértice de concreto/granito pode
   estar dentro da pista; tem que sair `{}`
3. merge por material + export de cada coleção:

| coleção Blender | arquivo | colisão |
|---|---|---|
| `02_ROADS` | `city_roads.gltf` | não |
| `04_PROXY_BUILD` | `city_houses.gltf` | sim (tudo) |
| `06_STREET_FURN` | `city_props.gltf` | `curb_granite`, `wall_render_raw` |
| `07_VEGETATION` | `city_vegkit.gltf` | não (é só o kit de malhas) |

4. copia `houses.json`, `poles.json`, `scatter.json` para os assets

Depois, no Godot: **`scan()` completo** (ver §5), abrir `city.tscn` com
`force_reload`, e acionar os botões dos nós `@tool` (§4).

Tempo: ~5 min. A exportação das casas é a parte lenta.

---

## 3. Estado atual (números)

| | |
|---|---:|
| ruas | 30 objetos, 2 malhas, 54.936 tris |
| casas | 573, 271 tris cada, 155.160 tris |
| mobiliário | 296 postes, 804 cabos, 13 placas, 71 detritos |
| vegetação | 14.058 plantas em 339 MultiMesh |
| luzes | 296 SpotLight + 296 lentes + 296 poças |
| oclusores | 573 casas, 6.876 tris |

Vagas reservadas para prédios de roteiro: `oficina_jimmy` (3),
`casa_nice` (1), `casa_maycow` (1).

---

## 4. Onde mexer em cada coisa

Todos os nós `@tool` estão sob `City` em `city.tscn`. Cada um tem um bool
`construir` (ou `aplicar`) que dispara ao ser marcado, e um `last_result`
com o relatório da última execução.

### `City` → `city_colisao.gd`
Põe **toda** a colisão da cidade na camada 2. O importador de glTF sempre cria
os `StaticBody3D` dos nós `-col` na camada 1, e o mundo sólido deste projeto
está na 2 — sem isso o player atravessa as casas. Roda sozinho no `_ready`,
e tem o botão `aplicar` para o editor.

### `Vegetation` → `city_vegetation.gd`
| propriedade | valor | o que faz |
|---|---:|---|
| `bloco` | 128 | tamanho do bloco espacial, em metros |
| `dist_lod` | 340 | distância em que troca para a silhueta |
| `margem_lod` | 30 | largura do crossfade |

Cada bloco vira um par de `MultiMeshInstance3D` (detalhado + LOD) posicionado
no **centróide do bloco**, com as transformações das instâncias relativas a
ele. Isso é essencial: `visibility_range_begin/end` mede a partir da origem do
nó, e com tudo em (0,0,0) o LOD trocaria no mapa inteiro de uma vez.

### `PoleLights` → `city_lights.gd`
| propriedade | valor |
|---|---:|
| `energia` | 1.6 |
| `alcance` | 15 m |
| `angulo` | 38° (cone de 76°) |
| `inclinacao_graus` | 10° |
| `lente_tamanho` | (0.66, 0.24) |
| `lente_brilho` | 8.0 |
| `poca_forca` | 0.75 |
| `fade` | 55–80 m |

Três coisas por poste:
- **SpotLight3D** — a luz de verdade, com `distance_fade` (é o que torna 296
  luzes viáveis).
- **Lente** — caixa emissiva na boca da luminária, num único MultiMesh.
  Sem ela a luz aparece no chão mas a luminária fica apagada.
- **Poça** — quad aceso no chão, em blend aditivo. **Não é luz.** O Forward
  Mobile atribui no máximo ~8 fontes por *objeto*, e a pista é um único mesh
  de 596 × 420 m — por isso só um punhado de postes a iluminava. Geometria
  acesa não tem esse teto.

`inclinacao_graus` **tem que ser igual** a `POCA_INCLINACAO` em `props.py`,
senão o cone da luz e a mancha pintada apontam para lugares diferentes.

### `Neblina` → `city_neblina.gd`
Interpola a névoa do Environment conforme o player entra na mata.
Deliberadamente **não** é `@tool` (rodava no editor e bagunçava o preview).

| | cidade | mata |
|---|---:|---:|
| densidade | 0.0012 | 0.048 |
| energia | 1.0 | 0.45 |
| aérea | 0.35 | 0.0 |
| céu | 0.4 | 1.0 |
| cor | (0.578, 0.392, 0.162) | (0.055, 0.060, 0.062) |

Caixa da cidade: `(294, -436.5)` a `(916, 4)`, transição de 50 m.

O Forward Mobile **não tem névoa volumétrica nem `FogVolume`** — só a névoa
de profundidade do Environment. E ela é **aditiva**: pinta a própria cor por
cima do que está atrás, então densidade alta com cor clara *clareia* a cena
em vez de escurecer. `fog_aerial_perspective` puxa a cor do **céu** para
dentro da névoa — com céu nublado, isso clareia tudo. É por isso que
`aerea_mata` é 0.

---

## 5. Armadilhas (leia antes de debugar)

### `reimport` mente
`filesystem_manage(op="reimport")` responde `reimported: [...]` e não
reimporta nada. Já aconteceu com `.gltf` e com `.png`.

**Só um `scan()` completo reimporta de fato** — e às vezes nem ele, se o
`.md5` ainda casa. Receita que funciona sempre:

```bash
rm -f .godot/imported/<arquivo>-*.md5
touch <caminho/do/arquivo>
# depois: filesystem_manage(op="scan")
```

**Sempre confira o carimbo** antes de acreditar que a cena está atualizada:

```bash
stat -c '%y %n' assets/.../city_props.gltf .godot/imported/city_props.gltf-*.scn
```

Se o `.scn` for mais velho que a fonte, a cena está mostrando o build antigo —
e você vai debugar um problema que já foi corrigido.

### `hash()` de string é aleatorizado por processo
Foi o bug mais caro desta série. O lado da rua onde a fileira de postes é
plantada vinha de `hash(road["id"]) & 1`. A geometria dos postes sai no
`city_props.gltf` e a posição das luzes sai no `poles.json`; gerados em
execuções diferentes do Blender, o sorteio mudava e **185 dos 296 postes**
ficavam de um lado da pista com a lâmpada acesa do outro, a até 9,75 m.

Corrigido com `zlib.crc32(road["id"].encode("utf-8")) & 1`.

> **Regra:** nada que atravesse a fronteira Blender→Godot pode depender de
> `hash()` de string. Se o dado vai para JSON e o Godot reconstrói a partir
> dele, tem de ser reproduzível fora do processo que o gerou.

Efeito colateral bom: agora dá para regerar **só o `poles.json`** num processo
à parte, sem reexportar geometria — segundos em vez de 5 minutos.

### `ResourceSaver.save()` + `load()` devolve o cache
`load()` logo depois de salvar devolve o `.tres` **da construção anterior**.
Isso já dobrou o tamanho da mata (transformações absolutas velhas somadas ao
novo `position` do bloco). Use **`take_over_path()`**, nunca `load()`.

### `ResourceSaver.save()` gira o loop principal
E o plugin MCP aproveita para processar a próxima mensagem da fila. Dois
`construir` entrelaçados derrubaram o editor com SIGSEGV dentro do MultiMesh.
Todos os scripts `@tool` daqui têm uma trava `_ocupado`.

### MultiMesh embutido na cena trava o editor
`"Instance count must be 0 to change the transform format"` → SIGSEGV na
releitura. Sempre `.tres` externo.

### Malha do kit duplicada em cada bloco
Cada `.tres` de bloco embutia uma cópia inteira da malha da árvore (20 cópias
da folhosa). `_persistir_malhas()` grava `mesh_<especie>.tres` uma vez só e os
blocos referenciam.

### Script `@tool` editado não recarrega
Precisa de um `scan()` antes do código novo rodar. Sem isso você testa a
versão antiga e conclui que a correção não funcionou.

### Verificar pelo arquivo não é verificar
Já afirmei que as casas tinham portas porque `vao_escuro` aparecia no glTF
exportado. Aparecia — mas o painel estava centrado 6 cm **dentro** do volume
sólido da casa e era engolido por completo. Nenhuma casa tinha porta.
**Para geometria, renderize.** Um `--background` com Workbench resolve.

### Screenshot do viewport não serve para conferir luz
296 ícones de gizmo de SpotLight tapam a cena. Use
`editor_screenshot source: "cinematic"`, que renderiza por um `Camera3D` sem
gizmos. Basta criar um `Camera3D` temporário, posicionar, capturar e apagar.

---

## 6. Decisões que já foram tomadas (não refazer)

- **Sem calçada e sem meio-fio.** Removidos a pedido, em duas rodadas. A borda
  da pista fica marcada só pela **sarjeta**, que é vertex color na própria
  malha da via — não é geometria solta na grama.
- **Sem `WEED`.** Eram 438 cones de 5 lados com 60 cm espalhados pela cidade;
  de perto liam como triângulos de plástico espetados na grama. A grama já
  está na textura do terreno.
- **Nomes de rua nunca escritos no chão.** Placas nos postes, sim.
- **Postes não se afastam da pista de outra via em cruzamento.** Já tentei:
  empurrar o poste 4 m leva junto a luminária e a poça, que saem da rua.
  Melhor um canto de base sobre o asfalto.

---

## 6b. Minimapa (stage_1)

Círculo giratório no canto superior esquerdo, só no `stage_1` e só no
gameplay com o Maycow normal.

**É 2D, não 3D.** Uma textura assada do mapa mais um shader que a amostra
girada. Custa um `ColorRect`: nada de segunda câmera, segundo viewport ou
re-render da cidade a cada quadro.

### Arquivos

| arquivo | papel |
|---|---|
| `tools/blender/citygen/textures/make_minimap.py` | gera a textura (PIL puro, não precisa de Blender) |
| `assets/3d_model/city/textures/T_citymap.png` | 2048², 3,01 px/m |
| `assets/3d_model/city/citymap.json` | recorte do mundo que a textura cobre |
| `shaders/ui/minimapa.gdshader` | recorte circular + giro na amostragem |
| `scripts/ui/minimap.gd` | posição, giro e regra de visibilidade |
| `scenes/ui/minimap.tscn` | a cena, instanciada em `stage_1.tscn` |

O mapa é desenhado a partir dos **dados** (`layout.json` + `houses.json`), não
renderizado da cena: fica legível a 190 px, não depende da hora do dia nem da
iluminação, e regerar custa dois segundos.

```bash
python3 tools/blender/citygen/textures/make_minimap.py
```

**Se a cidade mudar de forma, rode isso de novo** — o mapa não se atualiza
sozinho. O `citymap.json` sai junto e carrega o recorte do mundo, então o
script do Godot não repete nenhum número: se o mapa crescer, os dois andam
juntos.

### Ajustes

Todos exportados no nó `Minimap` de `stage_1`:

| | padrão | |
|---|---:|---|
| `alcance_m` | 130 | diâmetro do mundo que cabe no círculo |
| `tamanho_px` | 190 | lado do widget |
| `margem_px` | (26, 26) | distância até o canto |
| `suavidade` | 12 | 0 = giro instantâneo |

### Por que o giro é `-rotation.y`

Um nó com `rotation.y = θ` olha para `(-sen θ, 0, -cos θ)`. O shader amostra
`uv = centro + R(giro)·p·raio`, com `p` indo de −1 a 1 e `p.y` para baixo.
Para o topo da tela (`p = (0,−1)`) cair à frente do player:

```
R(a)·(0,−1) = (sen a, −cos a)  ≡  (−sen θ, −cos θ)   ⇒   a = −θ
```

Verificado também na prática: com o player a (815,97, −70,94) e `yaw` 0,5487,
o ponto 26 m à frente é exatamente o pixel 40% acima da seta.

O mapa em si não é espelhado: em UV, `u` cresce com X e `v` cresce com Z, o
que é a projeção de cima olhando para −Y com −Z para cima — base destra, sem
reflexão. Conferido no jogo: casa à direita do player aparece à direita da
seta.

### Regra de visibilidade

`GlobalEvents.is_maycow_normal` **e** não `in_cutscene` **e** não pausado.

O nó é `PROCESS_MODE_ALWAYS` de propósito: sem isso o `_process` para junto
com a árvore quando o jogo pausa, e o minimapa ficaria congelado por cima do
menu em vez de sumir. O `CanvasLayer` está na camada 100; o menu de pausa
está na 150, então fica por cima de qualquer jeito.

---

## 6c. Mapa grande (aba MAPA do menu do jogo)

O mesmo mapa em tamanho grande vive na **aba MAPA** do menu do jogo — aquele
que abre com `ui_menu_game`, montado em código por `scripts/ui/in_game_menu.gd`
(abas: INVENTORY, **MAP**, FILES). Não é o menu de pausa.

| arquivo | papel |
|---|---|
| `scenes/ui/mapa_painel.tscn` | a cena do painel |
| `scripts/ui/mapa_painel.gd` | zoom, arrasto, marcadores, seta |
| `scripts/ui/mapa_dados.gd` | `class_name MapaDados` — lê o `citymap.json` |
| `shaders/ui/mapa_grande.gdshader` | recorte com zoom, sem girar |

O menu instancia o painel uma vez no `_ready` e o mostra quando
`current_tab == TAB_MAPA` (1), chamando `ativar()` / `desativar()`. Se não
houver mapa nesta fase, ou o Maycow não for o normal, a aba mostra
`MAP_UNAVAILABLE` em vez do mapa.

`MapaDados.disponivel()` é a regra única, usada pelo minimapa e pela aba:
Maycow normal **e** fora de cutscene **e** existe nó no grupo `mapa_cidade`.

### Controles

| | |
|---|---|
| analógico esquerdo (e WASD/setas) | mover |
| analógico direito | zoom |
| roda do mouse | zoom no ponto sob o cursor |
| arrastar | mover |
| **R** | centralizar no player |

Os analógicos são lidos por *polling* em `_process` (`Input.get_vector`), não
por evento: assim o movimento é proporcional à inclinação do manche. Esquerdo
usa `ui_left/right/up/down` (que no projeto é o stick esquerdo, e de brinde
traz WASD e setas); direito usa `ui_look_*`.

### Este NÃO gira

O minimapa gira com o player; o mapa grande é norte-para-cima e quem gira é a
seta. Com rótulo escrito na tela, girar o mapa deixaria os nomes de cabeça
para baixo. A dedução do ângulo da seta é a mesma do minimapa: `-rotation.y`.

### Limites do zoom

- `zoom_min_m = 80`, não 40: a textura tem 3,01 px/m e a 40 m de altura o
  painel a amplia 4,5 vezes — vira borrão. A 80 m são 2,2x, que ainda lê bem.
- `zoom_max_m = 560`, não 680 (o lado da textura): o papel tem 680 m mas a
  cidade só ocupa 600 × 420 no meio dele.

O centro é preso de forma **sensível ao zoom** (`_limitar_centro`): enquanto a
janela é menor que o mapa ela anda até encostar na borda; quando fica maior
que o mapa, o mapa é centralizado. Sem isso, no zoom máximo a cidade ficava
largada num canto do painel.

---

## 6d. Pontos de interesse

Marcados nos dois mapas (com rótulo só no grande). Saem no `citymap.json`,
calculados pelo `make_minimap.py` a partir dos mesmos dados que desenham o
mapa — se a cidade for regerada e uma casa mudar de lugar, o ponto acompanha.

| ponto | chave | origem do dado | cor |
|---|---|---|---|
| Pracinha | `MAP_POI_PRACINHA` | `landmarks.praca_obelisco` | verde-água |
| Igreja Matriz | `MAP_POI_IGREJA` | `landmarks.igreja_matriz` | verde-água |
| Oficina do Jimmy | `MAP_POI_OFICINA_JIMMY` | `vagas_reservadas.oficina_jimmy` | laranja |
| Casa do Jimmy | `MAP_POI_CASA_JIMMY` | âncora → casa mais próxima | azul |
| Casa da Dona Nice | `MAP_POI_CASA_NICE` | `vagas_reservadas.casa_nice` | azul |
| Casa do Maycow | `MAP_POI_CASA_MAYCOW` | `vagas_reservadas.casa_maycow` | azul |

O JSON guarda a **chave**, não o texto — quem escreve na tela é o Godot com
`tr()`.

### Por que a casa do Jimmy não virou vaga reservada

Entrar em `RESERVADOS` (em `houses.py`) faria a passada 2 **pular** aquele
lote: vaga reservada existe para receber asset feito à mão, e o gerador deixa
o terreno vazio de propósito. Sem um modelo para pôr ali, isso abriria um
buraco na cidade.

Em vez disso a `ANCORA_CASA_JIMMY` em `make_minimap.py` se cola na casa
procedural **mais próxima** — que já está construída, tem 8,6 × 12,3 m e fica
a um quarteirão da oficina. Se um dia houver um asset da casa do Jimmy, aí sim
vale promover a ponto reservado.

---

## 6e. Regra: todo texto vai para o CSV

Nada de string escrita no código. Os textos do jogo ficam em
`assets/textos/red_valve_textos_gerais.csv` (colunas `keys,en,pt`) e o Godot
usa `tr("CHAVE")`. Traduzir para inglês é obrigatório na mesma linha.

**Nome de pessoa não se traduz.** Jimmy, Maycow e Nice ficam iguais nas duas
colunas; só a parte comum muda — `"Jimmy's House"` / `"Casa do Jimmy"`.

Chaves do mapa: `MAP_POI_*`, `MAP_RECENTER`, `MAP_SCALE`, `MAP_HELP_PAD`,
`MAP_HELP_MOUSE`, `MAP_UNAVAILABLE`. `MAP_SCALE` usa `{h}` e `{z}` com
`String.format`, para a ordem das palavras poder mudar por idioma.

Ao editar o CSV, confira que os `.translation` foram regerados — é a mesma
armadilha de reimportação do §5.

---

## 7. Dívidas em aberto

- LightmapGI não assado
- LOD de malha para casas e props (só a vegetação tem)
- Navmesh da área urbana
- Splatmap do Terrain3D
- ~60 `mm_*.tres` órfãos de grades antigas em
  `assets/3d_model/city/multimesh/` (~3 MB), de layouts que não existem mais

---

## 8. Histórico detalhado

O passo a passo com o raciocínio de cada etapa está em
`docs/plano-cidade-blender.md`, na raiz do repositório. As seções §10.7 a
§10.13 cobrem exatamente os ajustes resumidos aqui.
