extends Node3D

## Fotografa o TIRO da cacadeira: clarao, faiscas e fumaca.
##
##     Godot_v4.6.1 --path red-valve res://tools/shotgun/foto_tiro.tscn
##
## (SEM --headless: particula sem renderizador nao existe.)
##
## O efeito e' curto — o clarao dura 9 centesimos — e cada tentativa no jogo
## custa chegar ao hospital, equipar, mirar e atirar. Aqui o Maycow ja' nasce de
## arma na mao e o tiro sai no primeiro segundo; o que sobra e' escolher em que
## instantes clicar.
##
## A camera fica de LADO e perto da boca do cano: de frente o clarao cobre a
## tela inteira e de longe a fumaca vira um borrao de tres pixels.

const CENA_PLAYER := "res://scenes/player/player.tscn"
const PASTA := "user://fotos_shotgun"

## Em que QUADRO clicar depois do disparo — quadro, e nao segundo. O relogio
## nao serve aqui: o primeiro quadro depois do tiro leva 0,16 s enquanto o
## shader da particula compila, e os dois primeiros cliques caiam ambos DEPOIS
## do clarao, que dura 0,09. Por isso tambem o aquecimento la' embaixo.
const QUADROS := [1, 3, 8, 20, 50, 100]

## De onde olhar, em relacao a' BOCA DO CANO (e nao ao peito): o assunto aqui e'
## a ponta da arma.
const CAMERA_DE := Vector3(0.95, 0.22, 0.55)

var _player: Node3D = null
var _hold: Node = null
var _camera: Camera3D = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	_montar_luz()

	GlobalEvents.is_maycow_normal = true
	SaveManager.add_item("shotgun", 1)
	SaveManager.add_item("shotgun_ammo", 4)
	SaveManager.equip_item("shotgun")

	_player = load(CENA_PLAYER).instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3.ZERO

	_hold = _player.get_node_or_null(
		"maycow_lopes_normal/Armature/Skeleton3D/PlayerShotgunHold")
	if _hold == null:
		push_error("foto_tiro: nao achei o PlayerShotgunHold")
		get_tree().quit(1)
		return

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()

	# AQUECIMENTO: um efeito descartavel longe da camera, so' pra o shader das
	# particulas compilar antes do tiro que interessa. Sem isto o primeiro
	# quadro depois do disparo demora 0,16 s e o clarao passa entre um clique e
	# outro.
	var aquece = load("res://scenes/effects/fogo_shotgun.tscn").instantiate()
	add_child(aquece)
	aquece.global_position = Vector3(0, -50, 0)
	for i in 20:
		await get_tree().process_frame
	aquece.queue_free()

	# Mirando: com a arma no porte o cano aponta pro chao e a fumaca sai pros
	# pes dele, que nao mostra nada.
	var alvo: Vector3 = _player.global_position + Vector3(0, 1.4, -40.0)
	for i in 40:
		_hold.mirar(true, alvo)
		_enquadrar()
		await get_tree().process_frame

	_player.atirar_shotgun()

	var quadro := 0
	var passado := 0.0
	for parada in QUADROS:
		while quadro < int(parada):
			_hold.mirar(true, alvo)
			_enquadrar()
			await RenderingServer.frame_post_draw
			passado += get_process_delta_time()
			quadro += 1
		var caminho := "%s/tiro_q%03d.png" % [PASTA, quadro]
		get_viewport().get_texture().get_image().save_png(caminho)
		print("  %s   (quadro %d, %.2f s depois do tiro)"
			% [ProjectSettings.globalize_path(caminho), quadro, passado])

	print("== %d fotos do tiro ==" % QUADROS.size())
	get_tree().quit()


func _montar_luz() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, 145.0, 0.0)
	sol.light_energy = 0.9
	add_child(sol)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Fundo escuro de proposito: clarao e fumaca so' se leem contra o escuro, e
	# a cacadeira e' arma de corredor de hospital, nao de campo aberto.
	env.background_color = Color(0.10, 0.10, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.31, 0.35)
	env.ambient_light_energy = 1.0
	ambiente.environment = env
	add_child(ambiente)


func _enquadrar() -> void:
	var boca: Vector3 = _hold.boca_do_cano()
	_camera.make_current()
	_camera.global_position = boca + CAMERA_DE
	_camera.look_at(boca, Vector3.UP)
