extends Node

## TIRA OS CLIPES DE DENTRO DO .glb E POE NUM ARQUIVO QUE O EDITOR DEIXA EDITAR.
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/maos_fp/extrair_clipes.tscn
##
## Animacao que vem de .glb e' IMPORTADA: o editor mostra, mas nao deixa gravar
## — qualquer tecla que se mexa volta atras no proximo reimport. Isto copia
## todos os clipes pra uma AnimationLibrary em `.tres`, que e' arquivo de
## verdade e abre no AnimationPlayer como qualquer outro.
##
## DEPOIS DE RODAR ISTO, A FONTE DA ANIMACAO PASSA A SER O .tres. Rodar o
## `gerar_maos_fp.py` de novo troca o .glb e NAO troca o .tres — se a intencao
## for voltar a mandar do Blender, apague o .tres (as cenas voltam sozinhas pro
## que vem do .glb) ou rode isto outra vez, ciente de que as chaves mexidas a
## mao se perdem.

const GLB := "res://assets/3d_model/player/hands/maos_fp/maos_fp.glb"
const SAIDA := "res://assets/3d_model/player/hands/maos_fp/maos_fp_clipes.tres"

## Os que tocam em laco. A mesma lista do `maos_fp_armas.gd` — o laco e'
## propriedade do clipe, entao fica gravado aqui e o codigo nao precisa mais
## corrigir a mao.
const EM_LACO := ["idle", "pistola_idle", "shotgun_idle", "defesa", "agarrado",
	"queda", "magic_holding_gun"]


func _ready() -> void:
	var cena: PackedScene = load(GLB)
	if cena == null:
		push_error("extrair_clipes: nao achei %s" % GLB)
		get_tree().quit(1)
		return
	var raiz: Node = cena.instantiate()
	var animador: AnimationPlayer = raiz.get_node_or_null("AnimationPlayer")
	if animador == null:
		push_error("extrair_clipes: o .glb nao tem AnimationPlayer")
		get_tree().quit(1)
		return

	print("estrutura do .glb:")
	_arvore(raiz, 1)

	var lib := AnimationLibrary.new()
	var nomes := animador.get_animation_list()
	nomes.sort()
	for nome in nomes:
		var anim: Animation = animador.get_animation(nome).duplicate(true)
		anim.resource_local_to_scene = false
		anim.loop_mode = Animation.LOOP_LINEAR if nome in EM_LACO \
			else Animation.LOOP_NONE
		# Trilha marcada como "importada" o editor mostra em cinza e avisa que
		# nao vai salvar. Aqui ela ja' nao e' importada: e' um arquivo.
		for t in anim.get_track_count():
			anim.track_set_imported(t, false)
		lib.add_animation(nome, anim)
		print("  %-22s %5.2f s  %d trilhas" % [nome, anim.length,
			anim.get_track_count()])

	var erro := ResourceSaver.save(lib, SAIDA)
	if erro != OK:
		push_error("extrair_clipes: nao consegui gravar %s (erro %d)" % [SAIDA, erro])
		get_tree().quit(1)
		return
	print("== %d clipes em %s ==" % [nomes.size(), SAIDA])
	get_tree().quit()


func _arvore(no: Node, nivel: int) -> void:
	var i := 0
	for filho in no.get_children():
		print("  %s[%d] %s (%s)" % ["  ".repeat(nivel - 1), i, filho.name,
			filho.get_class()])
		_arvore(filho, nivel + 1)
		i += 1
