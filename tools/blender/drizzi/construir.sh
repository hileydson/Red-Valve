#!/usr/bin/env bash
# Refaz a Drizzi Wisny (rig + clipe) e leva pro jogo.
#
#     tools/blender/drizzi/construir.sh           # so' o clipe (usa o .blend)
#     tools/blender/drizzi/construir.sh rig       # refaz o rig antes (sobrescreve o .blend)
#
# 1. (rig) Blender: montar_drizzi.py -> Red-Valve-Blender/drizzi/drizzi.blend
# 2. Blender: animar_drizzi.py grava o clipe e exporta
#    red-valve/assets/3d_model/npc/drizzi/drizzi.glb
# 3. Godot --import (o reimport pelo editor nao reescreve o .scn)
set -e
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BLENDS="$(dirname "$RAIZ")/Red-Valve-Blender"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
AQUI="$RAIZ/tools/blender/drizzi"

cd "$RAIZ"
if [ "${1:-}" = "rig" ]; then
	echo "== rig"
	blender -b --factory-startup -P "$AQUI/montar_drizzi.py" 2>&1 \
		| grep -E "proxy|scan|salvo|Error|Traceback|line [0-9]" || true
fi
echo "== clipe"
blender -b "$BLENDS/drizzi/drizzi.blend" -P "$AQUI/animar_drizzi.py" 2>&1 \
	| grep -E "CLIPES|exportado|Error|Traceback|line [0-9]" || true

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3
echo "== pronto"
