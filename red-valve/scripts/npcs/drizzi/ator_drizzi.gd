extends Node3D

## A DRIZZI WISNY numa cena: o rig dela (`tools/blender/drizzi/`) na altura
## certa, de pé na origem deste nó e olhando pro +Z dele (a frente do glTF).
##
##     var d = AtorDrizzi.criar(pai, Transform3D(...), false)   # humana
##     d.tocar(&"andar")
##     d.olhar_para(ponto)
##     await d.desfazer(2.0)    # some no ar (o dissolver da Dona Nice)
##
## `monstro = true` é a Drizzi tomada pelo parasita (só pra cena: a da luta é
## `drizzi_monstro.gd`). Os clipes de cada uma estão no topo de
## `anim_drizzi.py` e `anim_drizzi_monstro.py`.

const ESTE := "res://scripts/npcs/drizzi/ator_drizzi.gd"
const MODELO_HUMANA := "res://assets/3d_model/npc/drizzi/drizzi.glb"
const MODELO_MONSTRO := "res://assets/3d_model/npc/drizzi/drizzi_monstro.glb"
const DissolverCorpo := preload("res://scripts/effects/dissolver_corpo.gd")
const Teleporte := preload("res://scripts/effects/teleporte_dona_nice.gd")
## Do alto da cabeça à sola; o monstro, da cabeça à ponta das tripas.
const ALTURA_HUMANA := 1.68
const ALTURA_MONSTRO := 2.7
## Os clipes que repetem.
const LACOS := [&"conversando", &"parada", &"andar", &"acusando", &"comendo_terra",
	&"gritando", &"caida", &"flutuar", &"cavar"]

var monstro := false
var modelo: Node3D
var anim: AnimationPlayer
var _corpo: RefCounted


static func criar(pai: Node, onde: Transform3D, de_monstro: bool = false) -> Node3D:
	var a: Node3D = load(ESTE).new()
	a.name = "drizzi_monstro_cena" if de_monstro else "drizzi_cena"
	a.monstro = de_monstro
	pai.add_child(a)
	a.global_transform = onde
	return a


func _ready() -> void:
	var cena := load(MODELO_MONSTRO if monstro else MODELO_HUMANA) as PackedScene
	if cena == null:
		return
	modelo = cena.instantiate() as Node3D
	add_child(modelo)
	var caixa := _caixa(modelo)
	if caixa.size.y > 0.0:
		var s := (ALTURA_MONSTRO if monstro else ALTURA_HUMANA) / caixa.size.y
		modelo.scale = Vector3.ONE * s
		caixa = _caixa(modelo)
		# a humana pisa na origem; o monstro fica com a ponta das tripas nela
		modelo.position -= Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	anim = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for clipe in LACOS:
			if anim.has_animation(clipe):
				anim.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).extra_cull_margin = 1.0


func tocar(clipe: StringName, mistura: float = 0.3, velocidade: float = 1.0) -> void:
	if anim == null or not anim.has_animation(clipe):
		push_warning("drizzi: sem o clipe %s" % clipe)
		return
	anim.play(clipe, mistura, velocidade)


## Pára o clipe no instante `t` (segundos).
func congelar(clipe: StringName, t: float) -> void:
	if anim == null or not anim.has_animation(clipe):
		return
	anim.play(clipe, 0.0)
	anim.seek(t, true)
	anim.pause()


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
	return posicao_do_osso("head") + Vector3.UP * 0.08


## Some no ar: o corpo queima de baixo pra cima (o dissolver da Dona Nice) com
## o rastro do teleporte, e o nó se apaga no fim.
func desfazer(duracao: float, apagar: bool = true) -> void:
	_corpo = DissolverCorpo.vestir(modelo)
	_corpo.parametro("cor_borda", Color(0.75, 0.55, 1.0))
	Teleporte.criar(get_parent(), Vector3(global_position.x, global_position.y, global_position.z),
		1.0 if not monstro else 1.6, false)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: _corpo.parametro("dissolver", v), 0.0, 1.0, duracao) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false
	if apagar:
		queue_free()


## Surge do nada (o mesmo efeito ao contrário).
func surgir(duracao: float) -> void:
	_corpo = DissolverCorpo.vestir(modelo)
	_corpo.parametro("dissolver", 1.0)
	visible = true
	var t := create_tween()
	t.tween_method(func(v: float) -> void: _corpo.parametro("dissolver", v), 1.0, 0.0, duracao) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	_corpo.restaurar()


static func _caixa(no: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := mi.transform
		var pai := mi.get_parent()
		while pai != null and pai != no:
			if pai is Node3D:
				t = (pai as Node3D).transform * t
			pai = pai.get_parent()
		var c: AABB = (no.transform * t) * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return caixa
