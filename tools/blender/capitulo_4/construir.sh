#!/usr/bin/env bash
# Refaz os clipes do fim do Capitulo 4 / comeco do 5 e leva pro jogo.
#
#     tools/blender/capitulo_4/construir.sh             # os dois
#     tools/blender/capitulo_4/construir.sh parasita    # so' um
#
# 1. Blender: grava os clipes e exporta o .glb so' de esqueleto (ver
#    animar_capitulo_4.py):
#      normal   -> npc/capitulo_4/maycow_normal_clipes.glb   (rig do
#                  maycow_cenas.blend, que NAO e' salvo)
#      parasita -> npc/capitulo_4/maycow_parasita_clipes.glb (rig do proprio
#                  maycow_lopes.glb, num Blender vazio)
# 2. Godot --import (o reimport pelo editor nao reescreve o .scn — ver
#    tools/godot/escola/construir.sh)
#
# Pra so' olhar as poses, sem exportar:
#     blender -b --factory-startup -P tools/blender/capitulo_4/animar_capitulo_4.py \
#         -- parasita --previa /tmp/previa [--quadros agonia_fogo:0,18]
set -e
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BLENDS="$(dirname "$RAIZ")/Red-Valve-Blender"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
AQUI="$RAIZ/tools/blender/capitulo_4"

NOMES="${1:-normal parasita}"

cd "$RAIZ"
for n in $NOMES; do
	echo "== $n"
	if [ "$n" = "normal" ]; then
		blender -b "$BLENDS/maycow_cenas/maycow_cenas.blend" -P "$AQUI/animar_capitulo_4.py" -- "$n" 2>&1 \
			| grep -E "CLIPES|INFO|exportado|Error|Traceback|line [0-9]" || true
	else
		blender -b --factory-startup -P "$AQUI/animar_capitulo_4.py" -- "$n" 2>&1 \
			| grep -E "CLIPES|INFO|exportado|Error|Traceback|line [0-9]" || true
	fi
done

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3
echo "== pronto"
