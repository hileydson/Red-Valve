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

	var tempos := [0.0, 0.22, 0.34, 0.48, 0.64, 0.80, 1.05]
	_golpe("ataque_1", tempos, [
		_pose(base_pos, base_rot),
		_pose(Vector3(0.08, -0.60, -0.54), Vector3(-4, 24, -18)),
		_pose(Vector3(0.03, -0.53, -0.62), Vector3(-14, 26, -28)),
		_pose(Vector3(-0.28, -0.36, -0.84), Vector3(-72, 24, -55)),
		_pose(Vector3(-0.52, -0.51, -0.66), Vector3(-108, 16, -70)),
		_pose(Vector3(-0.41, -0.48, -0.72), Vector3(-70, 28, -64)),
		_pose(base_pos, base_rot),
	])
	_golpe("ataque_2", tempos, [
		_pose(base_pos, base_rot),
		_pose(Vector3(0.38, -0.45, -0.56), Vector3(-16, 55, -88)),
		_pose(Vector3(0.22, -0.39, -0.66), Vector3(-21, 46, -76)),
		_pose(Vector3(-0.34, -0.34, -0.84), Vector3(-34, 22, -49)),
		_pose(Vector3(-1.12, -0.49, -0.58), Vector3(-49, -8, -20)),
		_pose(Vector3(-0.70, -0.47, -0.68), Vector3(-38, 12, -36)),
		_pose(base_pos, base_rot),
	])
	_golpe("ataque_3", tempos, [
		_pose(base_pos, base_rot),
		_pose(Vector3(-1.02, -0.49, -0.57), Vector3(-18, -12, -18)),
		_pose(Vector3(-0.78, -0.42, -0.67), Vector3(-24, 0, -30)),
		_pose(Vector3(-0.31, -0.34, -0.84), Vector3(-35, 22, -50)),
		_pose(Vector3(0.52, -0.42, -0.58), Vector3(-49, 58, -98)),
		_pose(Vector3(0.14, -0.43, -0.68), Vector3(-39, 44, -80)),
		_pose(base_pos, base_rot),
	])
	_golpe("ataque_4", tempos, [
		_pose(base_pos, base_rot),
		_pose(Vector3(-0.67, -0.82, -0.50), Vector3(-106, 0, -42)),
		_pose(Vector3(-0.54, -0.68, -0.62), Vector3(-82, 8, -48)),
		_pose(Vector3(-0.24, -0.35, -0.84), Vector3(-39, 28, -56)),
		_pose(Vector3(0.34, -0.14, -0.57), Vector3(16, 48, -78)),
		_pose(Vector3(0.03, -0.24, -0.70), Vector3(-10, 40, -70)),
		_pose(base_pos, base_rot),
	])
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

func _golpe(nome: String, tempos: Array, poses: Array) -> void:
	# Mantem arcos maiores que os anteriores sem deixar a arma tempo demais fora da tela.
	var poses_moderadas: Array[Transform3D] = []
	var rotacao_base := base.get_rotation_quaternion()
	for quadro: Transform3D in poses:
		var posicao := base_pos.lerp(quadro.origin, 0.75)
		var rotacao := rotacao_base.slerp(quadro.basis.get_rotation_quaternion(), 0.78)
		poses_moderadas.append(Transform3D(Basis(rotacao), posicao))
	var animacao := _clipe(nome, 1.05, tempos, poses_moderadas)
	var apoio := animacao.add_track(Animation.TYPE_POSITION_3D)
	animacao.track_set_path(apoio, NodePath("Armas/Cogblade/Movimento/Articulacao/ApoioEsquerdo"))
	animacao.track_set_interpolation_type(apoio, Animation.INTERPOLATION_CUBIC)
	for indice in tempos.size():
		var y := 0.16 if indice == 1 else (0.14 if indice == 2 else 0.12)
		animacao.track_insert_key(apoio, tempos[indice], Vector3(APOIO_ESQUERDO.x, y, APOIO_ESQUERDO.z))
	var eventos := animacao.add_track(Animation.TYPE_METHOD)
	animacao.track_set_path(eventos, NodePath("."))
	for evento in [[0.35, "rastro_inicio"], [0.48, "impacto"], [0.66, "rastro_fim"], [1.05, "fim"]]:
		animacao.track_insert_key(eventos, evento[0], {"method": &"evento_golpe_cogblade", "args": [evento[1]]})
