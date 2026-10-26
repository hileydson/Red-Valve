extends SceneTree

## Recria somente a biblioteca de animacoes editavel da cogblade em primeira pessoa.
## Godot --headless --path red-valve --script res://tools/maos_fp/gerar_cogblade_clipes.gd
const SAIDA := "res://assets/3d_model/player/hands/maos_fp/cogblade_fp_clipes.tres"
const APOIO_ESQUERDO := Vector3(0.035, 0.12, 0.0381699)

var biblioteca := AnimationLibrary.new()
var base_pos := Vector3(-0.30, -0.37, -0.74)
var base_rot := Vector3(-28, 42, -48)
var base: Basis

func _initialize() -> void:
	call_deferred("_gerar")

func _pose(posicao: Vector3, rotacao_graus: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(rotacao_graus * PI / 180.0), posicao)

func _gerar() -> void:
	base = _pose(base_pos, base_rot).basis
	_clipe("idle", 2.8, [0.0, 1.4, 2.8], [
		_pose(base_pos, base_rot),
		_pose(base_pos + Vector3(0, 0.003, 0), base_rot + Vector3(0.2, 0, 0.2)),
		_pose(base_pos, base_rot),
	], true)
	_clipe("sacar", 0.52, [0.0, 0.36, 0.52], [
		_pose(Vector3(-0.38, -0.76, -0.53), Vector3(-48, 38, -78)),
		_pose(base_pos + Vector3(0, 0.01, -0.01), base_rot + Vector3(1, 0, 1)),
		_pose(base_pos, base_rot),
	])
	_clipe("guardar", 0.38, [0.0, 0.38], [
		_pose(base_pos, base_rot),
		_pose(Vector3(-0.38, -0.76, -0.53), Vector3(-48, 38, -78)),
	])
	var guarda := _pose(Vector3(-0.34, -0.12, -0.68), Vector3(-15, 48, -88))
	_clipe("defesa", 0.30, [0.0, 0.30], [_pose(base_pos, base_rot), guarda])
	_clipe("impacto_defesa", 0.32, [0.0, 0.07, 0.32], [
		guarda,
		_pose(Vector3(-0.31, -0.16, -0.61), Vector3(-21, 52, -94)),
		guarda,
	])

	# Os golpes sao CORTES de um lado pro outro, sorteados entre quatro: o
	# horizontal da direita pra esquerda, o de volta (esquerda pra direita), e
	# as duas diagonais descendo. Os antigos tinham pose escrita a mao e dois
	# deles vinham DE TRAS PRA FRENTE: a lamina subia colada na camera e
	# descia em cima do alvo, ou subia de baixo pro rosto.
	_cogblade_no_rig = _transform_da_cogblade()
	_corte("ataque_1", -8.0, true)
	_corte("ataque_2", 8.0, false)
	_corte("ataque_3", 35.0, true)
	_corte("ataque_4", -35.0, false)
	print("CLIPES_COGBLADE ", ResourceSaver.save(biblioteca, SAIDA))
	quit()

func _clipe(nome: String, duracao: float, tempos: Array, poses: Array, loop := false) -> Animation:
	var animacao := Animation.new()
	animacao.resource_name = "cogblade_" + nome
	animacao.length = duracao
	if loop:
		animacao.loop_mode = Animation.LOOP_LINEAR
	var posicao := animacao.add_track(Animation.TYPE_POSITION_3D)
	var rotacao := animacao.add_track(Animation.TYPE_ROTATION_3D)
	for trilha in [posicao, rotacao]:
		animacao.track_set_path(trilha, NodePath("Armas/Cogblade/Movimento"))
		animacao.track_set_interpolation_type(trilha, Animation.INTERPOLATION_CUBIC)
	for indice in tempos.size():
		var quadro: Transform3D = poses[indice]
		animacao.track_insert_key(posicao, tempos[indice], base.inverse() * (quadro.origin - base_pos))
		animacao.track_insert_key(rotacao, tempos[indice], (base.inverse() * quadro.basis).get_rotation_quaternion())
	if not nome.begins_with("ataque_"):
		var apoio := animacao.add_track(Animation.TYPE_POSITION_3D)
		animacao.track_set_path(apoio, NodePath("Armas/Cogblade/Movimento/Articulacao/ApoioEsquerdo"))
		for tempo in [0.0, duracao]:
			animacao.track_insert_key(apoio, tempo, APOIO_ESQUERDO)
	biblioteca.add_animation("cogblade_" + nome, animacao)
	return animacao

# ------------------------------------------------------------------ cortes
## Onde o `Movimento` da cogblade fica em repouso, no espaco do rig (camera):
## a transformacao do no' `Cogblade` da mao_armada. Os cortes sao escritos no
## espaco da CAMERA e convertidos pra este no' na hora de virar chave.
var _cogblade_no_rig := Transform3D.IDENTITY

## No modelo, o cabo vai pro +Y (a lamina na ponta, ate' 1,16) e a largura da
## lamina e' o Z: o plano da lamina e' o YZ. No corte esse plano contem o
## movimento — o fio vai na frente, e nao a face chapada.
const LADO_DO_FIO := -1.0
## O meio do corte (onde as maos passam), quanto elas correm pro lado e quanto
## avancam no meio, em metros no espaco da camera.
const CORTE_CENTRO := Vector3(-0.05, -0.30, -0.60)
const CORTE_LADO := 0.32
const CORTE_AVANCO := 0.08
## O plano do corte sobe da frente pra cima nesta proporcao (1 = 45 graus):
## a lamina cruza a tela por cima das maos, grande, de um lado pro outro.
const CORTE_ERGUE := 0.9
## O arco do corte (graus a partir da frente) e o recuo antes dele.
const CORTE_ARCO := 75.0
const CORTE_ARMAR := 18.0

func _transform_da_cogblade() -> Transform3D:
	var cena: Node = load("res://scenes/player/first_person_view/mao_armada.tscn").instantiate()
	var t := (cena.get_node("rig/Armas/Cogblade") as Node3D).transform
	cena.free()
	return t

## Um corte num plano de frente pra camera, inclinado `inclinacao` graus
## (positivo: o lado direito mais alto). `pra_esquerda`: da direita pra
## esquerda; senao o contrario.
func _corte(nome: String, inclinacao: float, pra_esquerda: bool) -> void:
	var frente := Vector3(0, 0, -1)
	var fi := deg_to_rad(inclinacao)
	var lado := Vector3(cos(fi), sin(fi), 0.0)
	var cima := lado.cross(frente).normalized()
	# No meio do corte a lamina aponta pra frente E pra cima: so' pra frente
	# ela some no fundo da tela (parece estocada); so' pra cima, nao alcanca.
	var meio := (frente + cima * CORTE_ERGUE).normalized()
	var sentido := -1.0 if pra_esquerda else 1.0
	var a0 := -sentido * CORTE_ARCO
	# armar (alem do comeco), o corte em cinco quadros, o fim e o assentar
	var angulos := [a0 - sentido * CORTE_ARMAR, a0, a0 + sentido * CORTE_ARCO * 0.5, 0.0,
		-a0 * 0.5, -a0, -a0 - sentido * 12.0]
	var tempos := [0.0, 0.20, 0.34, 0.41, 0.48, 0.56, 0.64, 0.80, 1.05]
	var poses: Array[Transform3D] = [_cogblade_no_rig]
	for k in angulos.size():
		var a := deg_to_rad(float(angulos[k]))
		var dir := (meio * cos(a) + lado * sin(a)).normalized()
		# pra onde a lamina anda (a derivada do arco), que o fio acompanha
		var anda := (-meio * sin(a) + lado * cos(a)) * sentido
		var fio := (anda * LADO_DO_FIO - dir * dir.dot(anda * LADO_DO_FIO)).normalized()
		var x := dir.cross(fio).normalized()
		var mao := CORTE_CENTRO + lado * (CORTE_LADO * sin(a)) + frente * (CORTE_AVANCO * cos(a))
		# armando, as maos recuam e sobem um pouco
		if k == 0:
			mao += -frente * 0.06 + cima * 0.04
		poses.append(Transform3D(Basis(x, dir, fio), mao))
	poses.append(_cogblade_no_rig)

	var animacao := Animation.new()
	animacao.resource_name = "cogblade_" + nome
	animacao.length = 1.05
	var posicao := animacao.add_track(Animation.TYPE_POSITION_3D)
	var rotacao := animacao.add_track(Animation.TYPE_ROTATION_3D)
	for trilha in [posicao, rotacao]:
		animacao.track_set_path(trilha, NodePath("Armas/Cogblade/Movimento"))
		animacao.track_set_interpolation_type(trilha, Animation.INTERPOLATION_CUBIC)
	var no_movimento := _cogblade_no_rig.affine_inverse()
	for indice in tempos.size():
		var local: Transform3D = no_movimento * poses[indice]
		animacao.track_insert_key(posicao, tempos[indice], local.origin)
		animacao.track_insert_key(rotacao, tempos[indice], local.basis.orthonormalized().get_rotation_quaternion())
	biblioteca.add_animation("cogblade_" + nome, animacao)
	var apoio := animacao.add_track(Animation.TYPE_POSITION_3D)
	animacao.track_set_path(apoio, NodePath("Armas/Cogblade/Movimento/Articulacao/ApoioEsquerdo"))
	animacao.track_set_interpolation_type(apoio, Animation.INTERPOLATION_CUBIC)
	for indice in tempos.size():
		var y := 0.16 if indice == 1 else 0.12
		animacao.track_insert_key(apoio, tempos[indice], Vector3(APOIO_ESQUERDO.x, y, APOIO_ESQUERDO.z))
	var eventos := animacao.add_track(Animation.TYPE_METHOD)
	animacao.track_set_path(eventos, NodePath("."))
	for evento in [[0.35, "rastro_inicio"], [0.48, "impacto"], [0.66, "rastro_fim"], [1.05, "fim"]]:
		animacao.track_insert_key(eventos, evento[0], {"method": &"evento_golpe_cogblade", "args": [evento[1]]})
