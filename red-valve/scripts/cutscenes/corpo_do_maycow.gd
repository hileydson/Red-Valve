extends RefCounted

## O CORPO DO MAYCOW NORMAL NUMA CUTSCENE — clipes que a AnimationTree dele
## não toca (andar de costas, olhar em volta, ajoelhar).
##
## Mesmo arranjo do colo do Jonny (`player_carregar_jonny.gd`): a AnimationTree
## desliga e um AnimationPlayer próprio, pendurado no modelo, toca no
## esqueleto dele. Duas bibliotecas:
##   ""        os clipes da cena da igreja (`maycow_clipes.tres`: pegar_jonny,
##             esticar_mao...)
##   "normal"  os do próprio .glb dele (Walk_Backward_inplace,
##             Long_Breathe_and_Look_Around, Talk_with_Right_Hand_Open...)
## As armas na mão (os "holds") ficam suspensas enquanto isto vale.
##
##     var corpo = CorpoDoMaycow.assumir(player)
##     corpo.tocar(&"normal/Walk_Backward_inplace")
##     corpo.soltar()       # devolve à AnimationTree

const ESTE := "res://scripts/cutscenes/corpo_do_maycow.gd"
const CLIPES_IGREJA := "res://assets/3d_model/npc/igreja/maycow_clipes.tres"
const MODELO := "maycow_lopes_normal"
const ESQUELETO := "maycow_lopes_normal/Armature/Skeleton3D"
const HOLDS := ["PlayerGunHold", "PlayerMk3Hold", "PlayerShotgunHold", "PlayerGranolaHold"]
const LACOS := [&"normal/Walk_Backward_inplace", &"normal/Walking", &"normal/Long_Breathe_and_Look_Around",
	&"normal/Talk_with_Right_Hand_Open"]

var player: Node
var ap: AnimationPlayer
var _arvore: AnimationTree


static func assumir(jogador: Node) -> RefCounted:
	var c = (load(ESTE) as GDScript).new()
	c._montar(jogador)
	return c


func _montar(jogador: Node) -> void:
	player = jogador
	var modelo := player.get_node_or_null(MODELO) as Node3D
	if modelo == null:
		return
	_arvore = modelo.get_node_or_null("AnimationTree") as AnimationTree
	ap = AnimationPlayer.new()
	ap.name = "AnimCutscene"
	modelo.add_child(ap)
	ap.add_animation_library("", load(CLIPES_IGREJA))
	var proprio := modelo.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if proprio and proprio.has_animation_library(""):
		var lib := (proprio.get_animation_library("") as AnimationLibrary).duplicate() as AnimationLibrary
		# os de andar repetem; a cópia é daqui (a AnimationTree usa os originais)
		for clipe in LACOS:
			var nome := String(clipe).trim_prefix("normal/")
			if lib.has_animation(nome) and lib.get_animation(nome).loop_mode == Animation.LOOP_NONE:
				var laco := lib.get_animation(nome).duplicate() as Animation
				laco.loop_mode = Animation.LOOP_LINEAR
				lib.remove_animation(nome)
				lib.add_animation(nome, laco)
		ap.add_animation_library("normal", lib)
	if _arvore:
		_arvore.active = false
	_suspender(true)


func tocar(clipe: StringName, mistura: float = 0.3, velocidade: float = 1.0) -> void:
	if ap == null or not ap.has_animation(clipe):
		push_warning("corpo do Maycow: sem o clipe %s" % clipe)
		return
	ap.play(clipe, mistura, velocidade)


## Pára o clipe no instante `t` (segundos), misturando até ele em `mistura`.
func congelar(clipe: StringName, t: float, mistura: float = 0.3) -> void:
	if ap == null or not ap.has_animation(clipe):
		return
	ap.play(clipe, mistura)
	ap.seek(t, true)
	ap.pause()


## Devolve o corpo à AnimationTree e as armas à mão.
func soltar() -> void:
	if is_instance_valid(ap):
		ap.stop()
		ap.queue_free()
	if is_instance_valid(_arvore):
		_arvore.active = true
	_suspender(false)


func _suspender(sim: bool) -> void:
	if not is_instance_valid(player):
		return
	for caminho in HOLDS:
		var h := player.get_node_or_null(ESQUELETO + "/" + caminho)
		if h and "suspensa" in h:
			h.suspensa = sim
