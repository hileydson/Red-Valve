extends Node

## ASSA A POSE QUE ESTA' NA CENA DENTRO DO CLIPE `shotgun_idle`.
##
## POR QUE ISTO EXISTE
##
## A pose de uma mao de primeira pessoa e' decisao de olho, e olho se resolve
## no editor, mexendo osso a osso e olhando. So' que mexer osso no inspetor
## grava OVERRIDE DE NO' na cena, e override de no' nao e' animacao: no
## instante em que o AnimationPlayer toca `shotgun_idle` — que tem trilha pros
## 17 ossos das duas maos — tudo o que foi posado ali e' sobrescrito.
##
## Entao este script le' a pose como ela esta' na cena e ESCREVE nas trilhas
## do clipe, uma chave em t=0. Depois disso a pose e' a animacao: da' pra
## abrir o AnimationPlayer e mexer nela como em qualquer outro clipe, sem
## precisar de codigo.
##
## A ARMA
##
## A cacadeira que se ve' no editor pendura num `PreviaNoEditor`. Se ela
## estiver TIRADA do Skeleton3D (foi assim que ela pode ser posada a mao), a
## transformacao dela e' onde a arma deve ficar — e em jogo quem carrega a
## arma e' o osso `arma`. Como o Skeleton3D nao tem transformacao propria
## dentro do Armature, a conta e' direta: a pose do osso E' a transformacao da
## previa. E' isso que o script assa na trilha do osso.
##
## O SEGUNDO PASSO: DOBRAR O QUE FOI POSADO NO NO'
##
## Girar o `Armature` ou o `Skeleton3D` no editor e' tentador — mexe o braco
## inteiro de uma vez. So' que esses nos nao sao animados: a rotacao deles
## vale pros 23 clipes, e endireitar a cacadeira desendireita a pistola. Foi o
## que aconteceu (o cano da pistola passou a apontar pro olho).
##
## Entao o script tira essa rotacao dos nos e poe dentro do clipe: como os
## ossos de raiz (`antebraco` e `arma`) ficam logo abaixo do Skeleton3D, basta
## multiplicar a pose deles pela diferenca entre o que o .glb traz e o que a
## cena tem. O mundo nao muda de lugar; muda so' QUEM carrega o giro. Depois
## disso as linhas `transform` desses nos podem sair da cena — o script diz
## quais.
##
## Rodar:
##     Godot_v4.6.1 --headless --path red-valve \
##         res://tools/maos_fp/assar_idle_da_shotgun.tscn

const CENA := "res://scenes/player/first_person_view/mao_armada.tscn"
const BIBLIOTECA := "res://assets/3d_model/player/hands/maos_fp/maos_fp_clipes.tres"
const CLIPE := "shotgun_idle"
const OSSO_ARMA := "arma"

func _ready() -> void:
	var cena: Node3D = load(CENA).instantiate()
	add_child(cena)
	await get_tree().process_frame

	var rig: Node3D = cena.get_node("rig")
	var esqueletos := {
		"Armature/Skeleton3D": rig.get_node("Armature/Skeleton3D") as Skeleton3D,
		"Armature_dir/Skeleton3D": rig.get_node("Armature_dir/Skeleton3D") as Skeleton3D,
	}

	# Onde a arma foi posada a mao, se foi.
	var previa := rig.get_node_or_null("Armature_dir/PreviaNoEditor") as Node3D
	var pose_da_arma := Transform3D.IDENTITY
	var tem_arma_posada := previa != null
	if tem_arma_posada:
		var esq_dir: Node3D = rig.get_node("Armature_dir/Skeleton3D")
		var pai: Node3D = previa.get_parent()
		pose_da_arma = esq_dir.global_transform.affine_inverse() \
			* (pai.global_transform * previa.transform)
		print("a arma foi posada a mao; pose do osso = ", pose_da_arma.origin,
			" escala ", pose_da_arma.basis.get_scale())

	var lib: AnimationLibrary = load(BIBLIOTECA)
	var anim: Animation = lib.get_animation(CLIPE)
	if anim == null:
		push_error("nao achei o clipe %s" % CLIPE)
		get_tree().quit(1)
		return

	var mexidas := 0
	for t in anim.get_track_count():
		var caminho := anim.track_get_path(t)
		var no := String(caminho.get_concatenated_names())
		var osso := String(caminho.get_concatenated_subnames())
		var sk: Skeleton3D = esqueletos.get(no)
		if sk == null:
			continue
		var i := sk.find_bone(osso)
		if i < 0:
			continue

		var pos := sk.get_bone_pose_position(i)
		var giro := sk.get_bone_pose_rotation(i)
		var tam := sk.get_bone_pose_scale(i)
		if tem_arma_posada and no == "Armature_dir/Skeleton3D" and osso == OSSO_ARMA:
			pos = pose_da_arma.origin
			giro = pose_da_arma.basis.get_rotation_quaternion()
			tam = pose_da_arma.basis.get_scale()

		while anim.track_get_key_count(t) > 0:
			anim.track_remove_key(t, 0)
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				anim.position_track_insert_key(t, 0.0, pos)
			Animation.TYPE_ROTATION_3D:
				anim.rotation_track_insert_key(t, 0.0, giro)
			Animation.TYPE_SCALE_3D:
				anim.scale_track_insert_key(t, 0.0, tam)
			_:
				continue
		mexidas += 1

	# Passo 2: o giro que estiver nos nos `Armature`/`Skeleton3D` desce pros
	# ossos de raiz do clipe.
	var glb: Node3D = load(ExtResource_glb()).instantiate()
	for bra in ["Armature", "Armature_dir"]:
		var a0: Transform3D = (glb.get_node(bra) as Node3D).transform \
			* (glb.get_node(bra + "/Skeleton3D") as Node3D).transform
		var ah: Transform3D = (rig.get_node(bra) as Node3D).transform \
			* (rig.get_node(bra + "/Skeleton3D") as Node3D).transform
		var f := a0.affine_inverse() * ah
		if f.is_equal_approx(Transform3D.IDENTITY):
			continue
		var sk: Skeleton3D = esqueletos[bra + "/Skeleton3D"]
		for i in sk.get_bone_count():
			if sk.get_bone_parent(i) >= 0:
				continue
			_dobrar(anim, bra + "/Skeleton3D", sk.get_bone_name(i), f, sk, i)
		print("dobrado o giro de %s pra dentro do clipe — tire a linha "
			% bra + "`transform` de %s e de %s/Skeleton3D na cena" % [bra, bra])
	glb.queue_free()

	var erro := ResourceSaver.save(lib, BIBLIOTECA)
	if erro != OK:
		push_error("nao consegui salvar a biblioteca (erro %d)" % erro)
		get_tree().quit(1)
		return
	print("assado: %d trilhas de '%s' agora sao a pose da cena" % [mexidas, CLIPE])
	get_tree().quit()


## O caminho do rig, so' pra nao repetir a string.
func ExtResource_glb() -> String:
	return "res://assets/3d_model/player/hands/maos_fp/maos_fp.glb"


## Multiplica a pose de um osso de raiz por `f`, criando as trilhas que
## faltarem (sem trilha de posicao o osso usaria a de repouso, e a conta sairia
## pela metade).
func _dobrar(anim: Animation, no: String, osso: String, f: Transform3D,
		sk: Skeleton3D, i: int) -> void:
	var t_pos := anim.find_track(NodePath(no + ":" + osso), Animation.TYPE_POSITION_3D)
	var t_rot := anim.find_track(NodePath(no + ":" + osso), Animation.TYPE_ROTATION_3D)
	var pos: Vector3 = anim.position_track_interpolate(t_pos, 0.0) if t_pos >= 0 \
		else sk.get_bone_rest(i).origin
	var rot: Quaternion = anim.rotation_track_interpolate(t_rot, 0.0) if t_rot >= 0 \
		else sk.get_bone_rest(i).basis.get_rotation_quaternion()
	var novo := f * Transform3D(Basis(rot), pos)
	if t_pos < 0:
		t_pos = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(t_pos, NodePath(no + ":" + osso))
	while anim.track_get_key_count(t_pos) > 0:
		anim.track_remove_key(t_pos, 0)
	anim.position_track_insert_key(t_pos, 0.0, novo.origin)
	if t_rot < 0:
		t_rot = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t_rot, NodePath(no + ":" + osso))
	while anim.track_get_key_count(t_rot) > 0:
		anim.track_remove_key(t_rot, 0)
	anim.rotation_track_insert_key(t_rot, 0.0, novo.basis.get_rotation_quaternion())
