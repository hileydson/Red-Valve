extends Node

## TIRA OS CLIPES DOS PERSONAGENS DA IGREJA DE DENTRO DOS .glb E POE EM
## BIBLIOTECAS QUE O EDITOR DEIXA EDITAR.
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/igreja/extrair_clipes.tscn
##
## Mesmo motivo das maos de primeira pessoa: animacao que vem de .glb e'
## IMPORTADA — o editor mostra, mas nao grava. Aqui cada clipe e' copiado pra
## `assets/3d_model/npc/igreja/<personagem>_clipes.tres`, que e' o que as cenas
## dos personagens carregam no AnimationPlayer.
##
## DEPOIS DE RODAR ISTO, A FONTE DA ANIMACAO PASSA A SER O .tres. Os .glb saem
## de `tools/blender/igreja_dona_nice/animar.py`; rodar o Blender de novo troca
## o .glb e NAO o .tres. Rodar ISTO de novo refaz o .tres — e apaga o que tiver
## sido mexido a mao no editor. Pra refazer so' um personagem:
##
##     IGREJA_SO=jonny Godot_v4.6.1 --headless --path red-valve res://tools/igreja/extrair_clipes.tscn

const PASTA := "res://assets/3d_model/npc/igreja/"

## personagem -> clipes que tocam em laco. Clipe fora daqui toca uma vez.
const LACOS := {
	"dona_nice": ["ajoelhada_sussurro", "olhando_parada"],
	"dona_nice_monster": ["parado", "andar", "mordendo", "morta"],
	"dona_nice_monster_fase_2": ["flutuar"],
	"jonny": ["caido_agonia", "no_colo", "deitado"],
	"maycow": ["andar_lento", "mao_esticada", "mirando", "parado_carregando",
		"andar_carregando", "correr_carregando"],
}

## Clipes que existem no .glb mas nao sao desta cena (os de rosto do rig
## original da Dona Nice, em pose T).
const IGNORAR := ["idle_breathing", "talk_loop", "talk"]


func _ready() -> void:
	var so := OS.get_environment("IGREJA_SO")
	for nome in LACOS.keys():
		if not so.is_empty() and so != nome:
			continue
		_extrair(nome)
	get_tree().quit()


func _extrair(nome: String) -> void:
	var cena: PackedScene = load(PASTA + nome + ".glb")
	if cena == null:
		push_error("extrair_clipes: nao achei %s.glb" % nome)
		return
	var raiz: Node = cena.instantiate()
	var animador := raiz.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animador == null:
		push_error("extrair_clipes: %s.glb nao tem AnimationPlayer" % nome)
		raiz.free()
		return
	print("== %s  (AnimationPlayer em %s)" % [nome, raiz.get_path_to(animador)])
	var lib := AnimationLibrary.new()
	var nomes := animador.get_animation_list()
	nomes.sort()
	for clipe in nomes:
		if clipe in IGNORAR:
			continue
		var anim: Animation = animador.get_animation(clipe).duplicate(true)
		anim.resource_local_to_scene = false
		anim.loop_mode = Animation.LOOP_LINEAR if clipe in LACOS[nome] \
			else Animation.LOOP_NONE
		for t in anim.get_track_count():
			anim.track_set_imported(t, false)
		lib.add_animation(clipe, anim)
		print("  %-20s %5.2f s  %3d trilhas  ex: %s" % [clipe, anim.length,
			anim.get_track_count(),
			anim.track_get_path(0) if anim.get_track_count() > 0 else "-"])
	var saida := PASTA + nome + "_clipes.tres"
	var erro := ResourceSaver.save(lib, saida)
	if erro != OK:
		push_error("extrair_clipes: nao gravei %s (erro %d)" % [saida, erro])
	raiz.free()
