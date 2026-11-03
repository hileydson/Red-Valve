#!/usr/bin/env bash
# Refaz os clipes do Capitulo 5 (o resgate do Jimmy e o fim) e leva pro jogo.
#
#     tools/blender/capitulo_5/construir.sh             # os tres
#     tools/blender/capitulo_5/construir.sh jimmy       # so' um
#     tools/blender/capitulo_5/construir.sh rig         # refaz o rig do Jimmy antes
#
# 1. (rig) Blender: montar_jimmy.py -> Red-Valve-Blender/jimmy/jimmy.blend
# 2. Blender: grava os clipes e exporta (ver animar_capitulo_5.py):
#      jimmy    -> npc/capitulo_5/jimmy.glb                    (malha + rig)
#      jonny    -> npc/capitulo_5/jonny_clipes.glb             (so' esqueleto)
#      parasita -> npc/capitulo_5/maycow_parasita_clipes.glb   (so' esqueleto)
# 3. Godot --import (o reimport pelo editor nao reescreve o .scn)
#
# Pra so' olhar as poses, sem exportar:
#     blender -b Red-Valve-Blender/jimmy/jimmy.blend \
#         -P tools/blender/capitulo_5/animar_capitulo_5.py -- jimmy --previa /tmp/previa
set -e
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BLENDS="$(dirname "$RAIZ")/Red-Valve-Blender"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
AQUI="$RAIZ/tools/blender/capitulo_5"

NOMES="${1:-jimmy jonny parasita}"
cd "$RAIZ"
if [ "$NOMES" = "rig" ]; then
	echo "== rig do Jimmy"
	blender -b --factory-startup -P "$AQUI/montar_jimmy.py" 2>&1 \
		| grep -E "proxy|scan|salvo|decimada|Error|Traceback|line [0-9]" || true
	NOMES="jimmy jonny parasita"
fi
for n in $NOMES; do
	echo "== $n"
	case "$n" in
		jimmy) blender -b "$BLENDS/jimmy/jimmy.blend" -P "$AQUI/animar_capitulo_5.py" -- jimmy 2>&1 \
			| grep -E "CLIPES|exportado|Error|Traceback|line [0-9]" || true ;;
		jonny) blender -b "$BLENDS/jonny/jonny.blend" -P "$AQUI/animar_capitulo_5.py" -- jonny 2>&1 \
			| grep -E "CLIPES|exportado|Error|Traceback|line [0-9]" || true ;;
		parasita) blender -b --factory-startup -P "$AQUI/animar_capitulo_5.py" -- parasita 2>&1 \
			| grep -E "CLIPES|exportado|Error|Traceback|line [0-9]" || true ;;
	esac
done

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3
echo "== pronto"
