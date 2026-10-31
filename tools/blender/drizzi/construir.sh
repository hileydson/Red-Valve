#!/usr/bin/env bash
# Refaz a Drizzi Wisny (rig + clipes) e leva pro jogo.
#
#     tools/blender/drizzi/construir.sh           # so' os clipes da humana (usa o .blend)
#     tools/blender/drizzi/construir.sh rig       # refaz o rig da humana antes (sobrescreve o .blend)
#     tools/blender/drizzi/construir.sh monstro   # os clipes do monstro (drizzi_monstro.blend)
#
# 1. (rig) Blender: montar_drizzi.py -> Red-Valve-Blender/drizzi/drizzi.blend
# 2. Blender: animar_drizzi.py grava os clipes e exporta
#    red-valve/assets/3d_model/npc/drizzi/drizzi.glb (ou drizzi_monstro.glb)
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
if [ "${1:-}" = "monstro" ]; then
	echo "== clipes do monstro"
	blender -b "$BLENDS/drizzi/drizzi_monstro.blend" -P "$AQUI/animar_drizzi.py" -- monstro 2>&1 \
		| grep -E "CLIPES|decimando|exportado|Error|Traceback|line [0-9]" || true
else
	echo "== clipes"
	blender -b "$BLENDS/drizzi/drizzi.blend" -P "$AQUI/animar_drizzi.py" 2>&1 \
		| grep -E "CLIPES|exportado|Error|Traceback|line [0-9]" || true
fi

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3
echo "== pronto"
