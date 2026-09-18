# As mãos de primeira pessoa

`gerar_maos_fp.py` anima a mão de `Red-Valve-Blender/maos_e_armas/mao_rig_new.blend`
e exporta `red-valve/assets/3d_model/player/hands/maos_fp/maos_fp.glb` — as duas
mãos, um esqueleto cada, 23 clipes num arquivo só.

```bash
blender --background <mao_rig_new.blend> --python tools/blender/maos_fp/gerar_maos_fp.py
```

Quem consome o .glb:

| cena | o quê |
| :--- | :--- |
| `scenes/player/cutscene_fp/player_cutscene_fp.tscn` | as duas mãos vazias das cutscenes e do agarrão |
| `scenes/player/first_person_view/mao_armada.tscn` | a cópia ARMADA (`hand_with_pistol` no player.tscn) |
| `scenes/player/first_person_view/mao_magica.tscn` | a mão esquerda sozinha (`hand_with_magic`) |

## Quem manda na animação agora é o Godot

**O `.glb` deixou de ser a fonte da animação.** Os 23 clipes foram copiados
para uma biblioteca de verdade,

```
red-valve/assets/3d_model/player/hands/maos_fp/maos_fp_clipes.tres
```

e é ela que as duas cenas carregam no `AnimationPlayer`. Animação que vem de
`.glb` é *importada*: o editor mostra, mas não grava — qualquer tecla que se
mexa volta atrás no próximo reimport. Num `.tres` dá para abrir o
AnimationPlayer e mexer.

Consequência: **rodar o gerador troca o `.glb` e não troca o que o jogo
toca.** Para voltar a mandar do Blender:

```bash
Godot_v4.6.1 --headless --path red-valve res://tools/maos_fp/extrair_clipes.tscn
```

que refaz o `.tres` a partir do `.glb` — e apaga as chaves mexidas à mão.

O que o gerador continua mandando sozinho: a MALHA, o ESQUELETO e o osso
`arma`. Esses não dá para editar no Godot, e mexer neles pede o Blender.

## O enquadramento se acerta em jogo

Onde a arma cai na tela não é pose: é enquadramento, e mora no `AJUSTE` do
`scripts/player/maos_fp_armas.gd` — centímetros e graus, por arma. Com o jogo
rodando, **F9** liga o modo de ajuste, **G** troca entre conjunto / arma / mão
esquerda, as teclas `IKUOJL` + `RFVBNM` mexem e **P** imprime o bloco pronto
para colar.

Isso é de propósito: pose custa quatro minutos de gerador mais o reimport;
enquadramento tem de custar um toque de tecla. Os `CABO_*` / `FRENTE_*` /
`ROLAGEM_*` daqui continuam sendo onde a arma está EM RELAÇÃO ÀS MÃOS — mexer
neles muda a pegada; mexer no `AJUSTE` muda só onde tudo isso aparece.

O `conferir_maos_armadas` mexe no ajuste de verdade e mede na tela se cada
tecla anda para o lado que a ajuda promete.

Duas coisas que o ajuste **não** resolve e moram noutro lugar: a mão esquerda
com a PISTOLA é a outra cópia do rig (`hand_with_magic`), que tem dono
próprio; e com a CAÇADEIRA essa cópia é escondida pelo `maos_fp_armas.gd`
todo quadro, porque quem a liga (saída de cutscene, amuleto, ultimate) não
sabe que existe uma caçadeira.

## Ver antes de gerar

O gerador leva uns quatro minutos e o Godot leva mais. Pose de mão se acerta no
olho, então há uma prévia que renderiza direto do Blender, em segundos, com a
câmera do jogo (75° na vertical, olho na origem):

```bash
blender --background <mao_rig_new.blend> --python tools/blender/maos_fp/previa_armas.py \
    -- shotgun_idle:1 shotgun_recarga:22 pistola_tiro:3
```

Sai em `/tmp/previa_armas/`. Sem argumento, retrata uma lista de quadros-chave.

Do lado do Godot há os dois de sempre:

- `res://tools/maos_fp/conferir_maos_armadas.tscn` — headless, diz se a arma
  está **na mão**;
- `res://tools/maos_fp/foto_maos_armadas.tscn` — com tela, diz se ela está
  **bonita**. Doze retratos em `user://fotos_maos_fp`.

## Três coisas que custaram caro

### 1. A arma vem primeiro; a mão é derivada dela

É o contrário da terceira pessoa (`player_shotgun_hold.gd`), e de propósito. Lá o
que o jogador vê é o corpo, e arma fora da mão denuncia na hora. Aqui não há
corpo: o que se vê é a ARMA, e o enquadramento dela na tela é o assunto.

Então `CABO_*` / `FRENTE_*` / `ROLAGEM_*` dizem onde a arma está e para onde
aponta, e as duas mãos caem nela por `pose_de_arma()`. Não existe uma única pose
de mão escrita à mão nas animações de arma — se a arma se mexe, as mãos vão
junto, e não há como uma descolar da outra.

**Quem mexe no enquadramento mexe nesses três números, e em mais nada.**

### 2. Escala de osso não sobrevive ao glTF

O antebraço do rig é um toco de 15 cm: com ele o cotovelo fica sempre dentro do
quadro. A primeira versão esticava por **escala de osso** (`pb.scale.y = 2.05`),
com `mao.inherit_scale = 'NONE'` para a mão não inflar junto. No Blender isso
funciona. No glTF, não:

> o exportador amostra a matriz de mundo, calcula a local como
> `pai⁻¹ @ filho` — que fica **cisalhada**, porque a escala do pai está num eixo
> e o filho está girado em relação a ele — e decompõe isso em
> posição/rotação/escala, jogando o cisalhamento fora.

Medido, com o mesmo clipe nos dois:

| | Blender | Godot |
| :--- | ---: | ---: |
| `mao → indicador_3` | 0,130 m | 0,229 m |
| `mao → medio_1` | 0,097 m | 0,192 m |
| `antebraco → mao` | 0,465 m | 0,465 m |

**A mão inteira chegava ~1,8× maior no jogo**, com escala diferente a cada pose.
O antebraço chegava exato, que é justamente o que fazia o erro passar: quem olha
o braço não vê nada errado.

`assar_estica_no_descanso()` grava o esticão no OSSO e na CARNE (deslocamento ao
longo do eixo, zero na cauda, **pesado pelo peso do vértice** — sem isso a malha
rasga no pulso). Depois disso não há escala em osso nenhum, a pose só gira e
translada, e o Godot recebe a mão do tamanho em que foi desenhada.

Isso corrigiu também as mãos das cutscenes, que vinham grandes desde sempre.

### 3. A arma pendura num osso só dela

Pela mesma razão do item 2, `BoneAttachment3D` no osso `mao` **não serve**: a
pose global dele chegava com escala (1,30 / 1,93 / 1,37) e mudando a cada pose,
então a arma escorregava da mão — no meio da troca de arma o cabo ficou a 21 cm
do punho.

`criar_osso_da_arma()` põe no rig um osso **sem pai** chamado `arma`, cuja pose
É o quadro da arma em cada chave. Osso de raiz não tem de quem herdar escala:
chega no Godot rígido. Do lado de lá sobra uma conta só, exata — levar o modelo
das unidades dele para as do rig — mais a troca de eixos, porque o osso foi
escrito no Blender (topo no +Z) e o mesmo .glb importado tem o topo no +Y.

Essa troca de eixos é fácil de não notar: sem ela a arma fica girada 90° em
volta do próprio cano, e na caçadeira quase não aparece (o cabo dela está
praticamente no eixo do cano). Foi a pistola que denunciou.

## A recarga da caçadeira

`shotgun_recarga` tem 108 quadros = 3,60 s, que é o `TEMPO_RECARGA_SHOTGUN` do
`player_combat.gd`. Os `R_*` daqui são cópia dos `M_*` do
`player_shotgun_hold.gd` e dos `MOMENTO_*` do `player_combat.gd` — **o gesto é o
mesmo da terceira pessoa e os sons são os mesmos, então os três arquivos têm de
concordar.** O `conferir_maos_armadas` checa a duração.

A dobra da arma **não vai no .glb** (ela é um nó da arma, e a arma não é do rig):
quem abre é o `maos_fp_armas.gd`, com a mesma conta que `abertura_da_recarga()`
usa para a prévia.
