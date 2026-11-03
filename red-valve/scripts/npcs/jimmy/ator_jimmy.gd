extends Node3D

## O JIMMY numa cena: o rig dele (`tools/blender/capitulo_5/`) de pé na origem
## deste nó e olhando pro +Z dele (a frente do glTF).
##
##     var j = AtorJimmy.criar(pai, Transform3D(...))
##     j.tocar(&"jaula_sacudir")
##     j.olhar_para(ponto)
##
## O .glb já sai em metro (1,80 m, a sola em y = 0). Os clipes estão no topo
## de `tools/blender/capitulo_5/anim_capitulo_5.py`. Quem segue o Maycow pela
## cidade e pelo hospital é o `jimmy_segue.gd`, que herda daqui.
##
## Sem `class_name` (ver [[project-class-name-travado]]): preload deste script.

const ESTE := "res://scripts/npcs/jimmy/ator_jimmy.gd"
const MODELO := "res://assets/3d_model/npc/capitulo_5/jimmy.glb"
## Os clipes que repetem (o `jaula_bater` e o `mao_na_cabeca` são de uma vez).
const LACOS := [&"parado", &"andar", &"andar_devagar", &"correr", &"jaula_sacudir",
	&"jaula_gritar", &"abraco", &"ouvindo", &"falando", &"abraco_jonny"]

var modelo: Node3D
var anim: AnimationPlayer


static func criar(pai: Node, onde: Transform3D) -> Node3D:
	var a: Node3D = (load(ESTE) as GDScript).new()
	a.name = "jimmy"
	pai.add_child(a)
	a.global_transform = onde
	return a


func _ready() -> void:
	var cena := load(MODELO) as PackedScene
	if cena == null:
		push_warning("jimmy: sem o modelo %s" % MODELO)
		return
	modelo = cena.instantiate() as Node3D
	add_child(modelo)
	anim = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for clipe in LACOS:
			if anim.has_animation(clipe):
				anim.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR
	# a pele anda longe da caixa de repouso (braço pra fora da grade, abraço)
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).extra_cull_margin = 1.0


func tocar(clipe: StringName, mistura: float = 0.3, velocidade: float = 1.0) -> void:
	if anim == null or not anim.has_animation(clipe):
		push_warning("jimmy: sem o clipe %s" % clipe)
		return
	if anim.current_animation == String(clipe):
		anim.speed_scale = velocidade
		return
	anim.speed_scale = velocidade
	anim.play(clipe, mistura)


func clipe_atual() -> StringName:
	return StringName(anim.current_animation) if anim else &""


## Gira em Y pra olhar o ponto (a frente é +Z).
func olhar_para(ponto: Vector3) -> void:
	var d := ponto - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		global_rotation.y = atan2(d.x, d.z)


func giro_para(ponto: Vector3) -> float:
	var d := ponto - global_position
	return atan2(d.x, d.z)


func esqueleto() -> Skeleton3D:
	return find_child("Skeleton3D", true, false) as Skeleton3D


func posicao_do_osso(osso: String) -> Vector3:
	var sk := esqueleto()
	if sk == null:
		return global_position
	var i := sk.find_bone(osso)
	if i < 0:
		return global_position
	return sk.global_transform * sk.get_bone_global_pose(i).origin


## A cabeça (pra câmera mirar).
func cabeca() -> Vector3:
	return posicao_do_osso("head") + Vector3.UP * 0.1
