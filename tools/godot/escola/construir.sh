#!/usr/bin/env bash
# Gera a escola, o porao e a fachada — e IMPORTA. Rode sempre este, nunca so'
# um dos geradores.
#
#     tools/godot/escola/construir.sh
#
# Por que existe: os geradores cospem .gltf, e o Godot so' enxerga .gltf depois
# de importar. Rodando so' o Python, o arquivo novo fica no disco e o jogo
# continua carregando o .scn VELHO de `.godot/imported/` — sem erro nenhum, sem
# aviso nenhum.
#
# O reimport pelo editor (o botao, ou o MCP) nao resolve: ele responde
# "reimportado" e nao reescreve o .scn. Quem reimporta de verdade e' o binario
# em --headless --import.
set -e

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
ESC="$RAIZ/tools/godot/escola"

# O binario TEM de ser o 4.6: abrir o projeto com o 4.5 do snap rebaixa o
# project.godot e tira parametros dos .import.
if [ ! -x "$GODOT" ]; then
	echo "Godot 4.6 nao encontrado em $GODOT — defina GODOT=<caminho>" >&2
	exit 1
fi

echo "== conferindo a planta e o tracado =="
python3 "$ESC/navmesh.py"
python3 "$ESC/porao.py"

# A escola esta' na mata, e a clareira que segura as arvores fora do lote e' um
# retangulo escrito a mao em citygen/lib/vegetation.py. Arrastar a escola no
# editor deixa esse retangulo pra tras. Aviso, e nao erro: quem so' mexeu numa
# parede nao tem nada a fazer aqui.
python3 "$ESC/conferir_clareira.py" || true

echo "== gerando o interior da escola =="
python3 "$ESC/gerar_cena_escola.py"

echo "== gerando o porao =="
python3 "$ESC/gerar_cena_porao.py"

echo "== gerando a fachada =="
python3 "$ESC/gerar_cena_exterior.py"

# As duas plantas do menu (escola e porao). Saem da mesma planta.py e do mesmo
# porao.py que geram a geometria, entao mexer numa parede aqui muda o mapa.
echo "== desenhando as plantas do menu =="
python3 "$ESC/make_mapa_escola.py"

# O mapa da cidade desenha a silhueta da escola, e tira a posicao dela da
# instancia na stage_1. Entao TODA mexida no predio — regerar aqui ou so'
# arrastar/girar ele no editor — deixa o mapa do menu mentindo ate' isto rodar.
echo "== redesenhando o mapa da cidade =="
python3 "$RAIZ/tools/blender/citygen/textures/make_minimap.py"

echo "== importando =="
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked at exit|ObjectDB instances|only available when using|RID allocation" \
	| tail -5

echo "== pronto =="
