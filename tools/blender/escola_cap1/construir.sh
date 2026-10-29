#!/usr/bin/env bash
# Refaz os clipes do Capitulo 1 (escola) e leva pro jogo.
#
#     tools/blender/escola_cap1/construir.sh              # todos
#     tools/blender/escola_cap1/construir.sh grizzolito   # so' um
#
# 1. Blender: abre o .blend de cada personagem, grava os clipes e exporta o
#    .glb (ver animar.py). Os rigs do Grizzolito (malha + esqueleto + pesos)
#    NAO sao refeitos aqui: isso e' o montar_grizzolito.py, uma vez so'.
# 2. Godot --import (o reimport pelo editor nao reescreve o .scn — ver
#    tools/godot/escola/construir.sh)
set -e
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BLENDS="$(dirname "$RAIZ")/Red-Valve-Blender"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
AQUI="$RAIZ/tools/blender/escola_cap1"

declare -A BLEND=(
	[grizzolito]="grizzolito/grizzolito.blend"
	[grizzolito_monstro_1]="grizzolito/grizzolito_monstro_1.blend"
	[grizzolito_monstro_2]="grizzolito/grizzolito_monstro_2.blend"
	[dona_nice_escola]="dona_nice/dona_nice_cena.blend"
	[jonny_escola]="jonny/jonny.blend"
)
NOMES="${1:-grizzolito grizzolito_monstro_1 grizzolito_monstro_2 dona_nice_escola jonny_escola}"

cd "$RAIZ"
for n in $NOMES; do
	echo "== $n"
	blender -b "$BLENDS/${BLEND[$n]}" -P "$AQUI/animar.py" -- "$n" 2>&1 \
		| grep -E "CLIPES|exportado|Error|Traceback|line [0-9]" || true
done

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3
echo "== pronto"
