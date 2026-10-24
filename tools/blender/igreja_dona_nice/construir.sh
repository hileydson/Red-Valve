#!/usr/bin/env bash
# Refaz os clipes dos personagens da cena da igreja e leva pro jogo.
#
#     tools/blender/igreja_dona_nice/construir.sh            # todos
#     tools/blender/igreja_dona_nice/construir.sh jonny      # so' um
#
# 1. Blender: abre o .blend de cada personagem (Red-Valve-Blender/), regrava
#    as acoes e exporta red-valve/assets/3d_model/npc/igreja/<nome>.glb
# 2. Godot --import (o reimport pelo editor nao reescreve o .scn — ver
#    tools/godot/escola/construir.sh)
# 3. extrai os clipes pras bibliotecas <nome>_clipes.tres
#
# ATENCAO: o passo 3 APAGA o que tiver sido mexido a mao nos .tres pelo
# editor. Se voce ajustou um clipe no AnimationPlayer, nao rode isto pra
# esse personagem (ou refaca o ajuste depois).
#
# Os rigs (malha + esqueleto + pesos) NAO sao refeitos aqui: isso e' o
# montar_personagem.py / montar_dona_nice.py / montar_maycow.py, uma vez so'.
set -e
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BLENDS="$(dirname "$RAIZ")/Red-Valve-Blender"
GODOT="${GODOT:-/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64}"
AQUI="$RAIZ/tools/blender/igreja_dona_nice"

declare -A BLEND=(
	[dona_nice]="dona_nice/dona_nice_cena.blend"
	[dona_nice_monster]="dona_nice_monster/dona_nice_monster.blend"
	[dona_nice_monster_fase_2]="dona_nice_monster_fase_2/dona_nice_monster_fase_2.blend"
	[jonny]="jonny/jonny.blend"
	[maycow]="maycow_cenas/maycow_cenas.blend"
)
NOMES="${1:-dona_nice dona_nice_monster dona_nice_monster_fase_2 jonny maycow}"

cd "$RAIZ"
for n in $NOMES; do
	echo "== $n"
	blender -b "$BLENDS/${BLEND[$n]}" -P "$AQUI/animar.py" -- "$n" 2>&1 \
		| grep -E "CLIPES|exportado|Error|Traceback" || true
done

echo "== importando"
"$GODOT" --headless --path "$RAIZ/red-valve" --import 2>&1 \
	| grep -viE "leaked|ObjectDB|RID alloc|only available" | tail -3

echo "== extraindo clipes"
for n in $NOMES; do
	IGREJA_SO="$n" "$GODOT" --headless --path "$RAIZ/red-valve" \
		res://tools/igreja/extrair_clipes.tscn 2>&1 | grep -E "^==|ERROR" || true
done
echo "== pronto"
