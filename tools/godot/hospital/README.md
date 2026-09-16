# O hospital

Dois andares, ligados só pelo elevador. Tudo — geometria, luz, móvel, colisão e
navmesh — é **gerado por script** a partir da planta. Mexer pelo editor do Godot
se perde na próxima geração, igual à arena 2.

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

## Onde mexer em cada coisa

| Arquivo | Assunto |
| :--- | :--- |
| `planta.py` | salas, muros, portas, janelas, o poço do elevador |
| `luzes.py` | onde tem lâmpada, qual está queimada, cor e alcance |
| `materiais.py` | textura e cor de piso, parede, teto, móvel |
| `mobilia.py` | o que vai dentro de cada tipo de sala |
| `navmesh.py` | malha de navegação + conferidor da planta |
| `gltf.py` | escritor de glTF (funde caixas numa malha só) |
| `gerar_cena_hospital.py` | monta o `.tscn` |

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

- O hospital **não está ligado ao mapa da cidade**. A porta da rua é trancada
  de propósito; ligar exige um portal no `stage_1` e uma flag de volta em
  `GlobalEvents`, como a igreja e a casa do Jimmy têm.
- Não tem escada: o mapa desenhado não mostra nenhuma, e o elevador é o caminho.
- Não tem som próprio de porta nem de elevador (o projeto não tem esses
  arquivos); só a ambiência geral.
