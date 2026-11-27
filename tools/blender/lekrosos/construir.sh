#!/usr/bin/env bash
# Refaz os lekrosos e leva pro jogo.
#
#     tools/blender/lekrosos/construir.sh                    # todos os lekroso_*.glb
#     tools/blender/lekrosos/construir.sh lekroso_4          # so' um
#     tools/blender/lekrosos/construir.sh lekroso_4 animar   # so' os clipes dele
#     tools/blender/lekrosos/construir.sh todos animar       # so' os clipes de todos
#
# LEKROSO NOVO: ponha o scan em red-valve/assets/3d_model/enemies/lekrosos/
# como lekroso_N.glb (+ as texturas dele) e rode com o nome. Sai tudo:
#
# 1. montar_lekroso.py  scan -> malha decimada + esqueleto + pesos
#                       (pontos do esqueleto medidos na malha: pontos_auto.py)
#                       (Red-Valve-Blender/lekrosos/lekroso_N.blend)
# 2. cortar.py          pecas, crateras, cotos, ossos-sombra e as pecas soltas
#                       (lekroso_N_cortado.blend + scripts/enemies/lekrosos/lekroso_N_dados.gd)
# 3. animar.py          clipes + export do .glb + a PASSADA no _dados.gd
#                       (assets/3d_model/enemies/lekrosos/lekroso_N/lekroso_N_rig.glb)
# 4. gerar_cena.py      scenes/enemies/lekrosos/lekroso_N.tscn, SO' se ainda
#                       nao existe (a cena e' do jogo: mexeu nela, ela fica)
# 5. Godot --import     o reimport pelo editor nao reescreve o .scn
#
# O comportamento e' um so' (scripts/enemies/lekrosos/lekroso.gd): a cena de
# cada um so' troca o modelo e os dados. A sala de teste ja' acha o novo
# sozinha (entra no sorteio do "Lekroso").
set -e
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BLENDS="$(dirname "$RAIZ")/Red-Valve-Blender/lekrosos"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
AQUI="$RAIZ/tools/blender/lekrosos"
SCANS="$RAIZ/red-valve/assets/3d_model/enemies/lekrosos"
FILTRO="^  |PASSADA|CLIPE|==|Error|Traceback|line [0-9]|!!"

QUEM="${1:-todos}"
if [ "$QUEM" = "todos" ]; then
	NOMES=$(cd "$SCANS" && ls lekroso_*.glb | sed 's/\.glb$//' | sort -V)
else
	NOMES="$QUEM"
fi

cd "$RAIZ"
for NOME in $NOMES; do
	echo "==== $NOME"
	if [ "${2:-}" != "animar" ]; then
		echo "== montar"
		blender -b --factory-startup -P "$AQUI/montar_lekroso.py" -- "$NOME" 2>&1 | grep -E "$FILTRO" || true
		echo "== cortar"
		blender -b "$BLENDS/$NOME.blend" -P "$AQUI/cortar.py" -- "$NOME" 2>&1 | grep -E "$FILTRO" || true
	fi
	echo "== animar"
	blender -b "$BLENDS/${NOME}_cortado.blend" -P "$AQUI/animar.py" -- "$NOME" 2>&1 | grep -E "$FILTRO" || true
	python3 "$AQUI/gerar_cena.py" "$NOME"
done

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3
echo "== pronto"
