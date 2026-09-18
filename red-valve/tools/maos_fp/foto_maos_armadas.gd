extends Node3D

## Retrata as MAOS COM ARMA da primeira pessoa, com a camera do jogo.
##
##     Godot_v4.6.1 --path red-valve res://tools/maos_fp/foto_maos_armadas.tscn
##
## (SEM --headless: sem renderizador nao ha' foto.)
##
## Irmao do `tools/shotgun/foto_pose.gd`. O `conferir_maos_armadas` diz se a
## arma esta' NA MAO; este diz se ela esta' BONITA, que e' outra pergunta e so'
## o olho responde.
##
## A previa do Blender (`tools/blender/maos_fp/previa_armas.py`) mostra a mesma
## pose muito mais rapido, e e' la' que se afina pegada. Aqui e' o unico lugar
## que mostra a coisa como o jogador ve': com a pele, com a luz da mao, com o
## material da arma e com o campo de visao de verdade.

const CENA_PLAYER := "res://scenes/player/player.tscn"
const PASTA := "user://fotos_maos_fp"

## (nome do arquivo, item equipado, clipe, em que fracao do clipe clicar).
## Fracao e nao segundo: assim mudar a duracao de um clipe nao desalinha as
## fotos dele.
const RETRATOS := [
	["pistola_parada", "pistol", "pistola_idle", 0.0],
	["pistola_tiro", "pistol", "pistola_tiro", 0.2],
	["shotgun_parada", "shotgun", "shotgun_idle", 0.0],
	["shotgun_tiro", "shotgun", "shotgun_tiro", 0.18],
	["shotgun_recarga_abre", "shotgun", "shotgun_recarga", 0.20],
	["shotgun_recarga_ejeta", "shotgun", "shotgun_recarga", 0.31],
	["shotgun_recarga_cinto", "shotgun", "shotgun_recarga", 0.48],
	["shotgun_recarga_bala1", "shotgun", "shotgun_recarga", 0.60],
	["shotgun_recarga_bala2", "shotgun", "shotgun_recarga", 0.84],
	["shotgun_recarga_fecha", "shotgun", "shotgun_recarga", 0.93],
	# 0,45 e nao 0,75: la' no fim do gesto a arma ja' saiu de quadro (e' pra
	# isso que ele existe — a troca do modelo acontece com a tela limpa), e a
	# foto sairia vazia.
	["troca_guardando", "shotgun", "shotgun_guardar", 0.45],
	["troca_sacando", "pistol", "pistola_sacar", 0.35],
]

var _player: Node3D = null
var _rig: Node = null
var _animador: AnimationPlayer = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	_montar_cenario()

	GlobalEvents.is_maycow_normal = false
	SaveManager.add_item("pistol", 1)
	SaveManager.add_item("pistol_ammo", 12)
	SaveManager.add_item("shotgun", 1)
	SaveManager.add_item("shotgun_ammo", 8)

	_player = load(CENA_PLAYER).instantiate()
	add_child(_player)
	for i in 10:
		await get_tree().process_frame
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(0.0, 1.0, 0.0)

	_rig = _player.get_node_or_null("Camera3D/hand_with_pistol/rig")
	if _rig == null:
		push_error("foto_maos_armadas: nao achei o rig de primeira pessoa")
		get_tree().quit(1)
		return
	_animador = _rig.get_node("AnimationPlayer")
	var camera: Camera3D = _player.get_node("Camera3D")
	camera.make_current()

	for retrato in RETRATOS:
		await _retratar(retrato[0], retrato[1], retrato[2], float(retrato[3]))

	print("== %d fotos em %s ==" % [RETRATOS.size(),
		ProjectSettings.globalize_path(PASTA)])
	get_tree().quit()


## Um retrato.
##
## O clipe e' posto NA MAO (play + seek) em vez de esperar o estado do
## componente chegar la' sozinho: esperar a troca de arma, a recarga e o
## cooldown de tiro acontecerem em ordem levaria meio minuto por foto, e o que
## interessa aqui e' o QUADRO, nao o caminho ate' ele.
func _retratar(nome: String, item: String, clipe: String, fracao: float) -> void:
	SaveManager.equip_item(item)
	# A troca de arma tem GESTO (guarda uma, saca a outra, ~1 s). Esperar so'
	# alguns quadros fotografava a arma anterior: a primeira rodada saiu com a
	# pistola na foto chamada "shotgun_parada".
	_player.hand_with_pistol.visible = true
	for i in 600:
		if _rig.arma_na_mao() == item and not _rig.em_troca():
			break
		await get_tree().process_frame
	# A dobra da cacadeira e' do componente, e ela so' abre durante a recarga
	# de verdade — entao a recarga e' pedida a ele, e nao so' o clipe.
	if clipe.ends_with("_recarga"):
		_rig.recarregar(3.6)
	# A visibilidade das maos e' decidida pelo `_physics_process` do jogador,
	# que esta' congelado aqui. Sem isto a foto sai so' com o HUD.
	_player.hand_with_pistol.visible = true
	_player.hand_with_magic.visible = (item == "pistol")
	_animador.play(clipe)
	_animador.seek(_animador.current_animation_length * fracao, true)
	await RenderingServer.frame_post_draw
	_animador.seek(_animador.current_animation_length * fracao, true)
	await RenderingServer.frame_post_draw

	var caminho := "%s/%s.png" % [PASTA, nome]
	get_viewport().get_texture().get_image().save_png(caminho)
	print("  %s" % ProjectSettings.globalize_path(caminho))


## Um fundo escuro e uma luz — a arena e' corredor de hospital, nao campo
## aberto, e mao de primeira pessoa contra fundo claro nao se le'.
func _montar_cenario() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-42.0, 150.0, 0.0)
	sol.light_energy = 1.1
	add_child(sol)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.35, 0.40)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	ambiente.environment = env
	add_child(ambiente)
