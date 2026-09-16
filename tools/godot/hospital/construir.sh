#!/usr/bin/env bash
# Gera o hospital e IMPORTA. Rode sempre este, nunca so' o gerador.
#
#     tools/godot/hospital/construir.sh
#
# Por que existe: o gerador cospe .gltf, e o Godot so' enxerga .gltf depois de
# importar. Rodando so' o Python, o arquivo novo fica no disco e o jogo
# continua carregando o .scn VELHO de `.godot/imported/` — sem erro nenhum, sem
# aviso nenhum. Perdi meia hora afinando iluminacao contra uma geometria que
# nao estava mais em lugar nenhum.
#
# O reimport pelo editor (o botao, ou o MCP) nao resolve: ele responde
# "reimportado" e nao reescreve o .scn. Quem reimporta de verdade e' o binario
# em --headless --import.
set -e

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"

# O binario TEM de ser o 4.6: abrir o projeto com o 4.5 do snap rebaixa o
# project.godot e tira parametros dos .import.
if [ ! -x "$GODOT" ]; then
	echo "Godot 4.6 nao encontrado em $GODOT — defina GODOT=<caminho>" >&2
	exit 1
fi

echo "== gerando o interior =="
python3 "$RAIZ/tools/godot/hospital/gerar_cena_hospital.py"

echo "== gerando o exterior =="
python3 "$RAIZ/tools/godot/hospital/gerar_cena_exterior.py"

# As duas plantas do interior (uma por andar), para o minimapa e a aba MAPA.
# Saem da mesma planta.py que gera a geometria, entao mexer numa parede aqui
# muda o mapa junto.
echo "== desenhando as plantas do interior =="
python3 "$RAIZ/tools/godot/hospital/make_mapa_hospital.py"

# O mapa da cidade desenha a silhueta do hospital, e tira a posicao dela da
# instancia na stage_1. Entao TODA mexida no predio — regerar aqui ou so'
# arrastar/girar ele no editor — deixa o mapa do menu mentindo ate' isto rodar.
echo "== redesenhando o mapa da cidade =="
python3 "$RAIZ/tools/blender/citygen/textures/make_minimap.py"

echo "== importando =="
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked at exit|ObjectDB instances|only available when using|RID allocation" \
	| tail -5

echo "== pronto =="
