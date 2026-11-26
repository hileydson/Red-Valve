#!/usr/bin/env bash
# Refaz o Lekroso 1 inteiro e leva pro jogo.
#
#     tools/blender/lekrosos/construir.sh            # tudo
#     tools/blender/lekrosos/construir.sh animar     # so' os clipes (rig e cortes ficam)
#
# 1. montar_lekroso.py  scan -> malha decimada + esqueleto + pesos
#                       (Red-Valve-Blender/lekrosos/lekroso_1.blend)
# 2. cortar.py          pecas, crateras, cotos, ossos-sombra e as pecas soltas
#                       (lekroso_1_cortado.blend + scripts/enemies/lekrosos/lekroso_1_dados.gd)
# 3. animar.py          clipes + export do .glb
#                       (assets/3d_model/enemies/lekrosos/lekroso_1/lekroso_1_rig.glb)
# 4. Godot --import     o reimport pelo editor nao reescreve o .scn
set -e
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BLENDS="$(dirname "$RAIZ")/Red-Valve-Blender/lekrosos"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
AQUI="$RAIZ/tools/blender/lekrosos"
NOME=lekroso_1
FILTRO="^  |PASSADA|CLIPE|==|Error|Traceback|line [0-9]|!!"

cd "$RAIZ"
if [ "${1:-}" != "animar" ]; then
	echo "== montar"
	blender -b --factory-startup -P "$AQUI/montar_lekroso.py" -- "$NOME" 2>&1 | grep -E "$FILTRO" || true
	echo "== cortar"
	blender -b "$BLENDS/$NOME.blend" -P "$AQUI/cortar.py" -- "$NOME" 2>&1 | grep -E "$FILTRO" || true
fi
echo "== animar"
blender -b "$BLENDS/${NOME}_cortado.blend" -P "$AQUI/animar.py" -- "$NOME" 2>&1 | grep -E "$FILTRO" || true

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3
echo "== pronto"
