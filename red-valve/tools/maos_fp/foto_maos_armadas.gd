extends Node3D

## Retrata a propria mao_armada, sem carregar player, inventario ou fase.
## Godot --path red-valve res://tools/maos_fp/foto_maos_armadas.tscn
## As fotos ficam em user://fotos_maos_fp. A cena de autoria e a usada no jogo.
const CENA := "res://scenes/player/first_person_view/mao_armada.tscn"
const PASTA := "user://fotos_maos_fp"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	ambiente.environment = env
	add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -35, 0)
	sol.light_energy = 1.8
	add_child(sol)
	var cena: Node3D = load(CENA).instantiate()
	add_child(cena)
	cena.set_process(false)
	var rig := cena.get_node("rig")
	rig.set_process(false)
	var ap: AnimationPlayer = rig.get_node("AnimationPlayer")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var camera: Camera3D = cena.get_node("PreviaDaTela")
	camera.make_current()
	for item in ["pistol", "shotgun"]:
		var prefixo := "pistola" if item == "pistol" else "shotgun"
		for acao in ["idle", "tiro", "recarga"]:
			var clipe: String = prefixo + "_" + acao
			var instantes := [0.0] if acao == "idle" else [0.04, 0.16]
			if acao == "recarga":
				instantes = [0.35, 0.72, 1.46, 1.90, 2.04, 2.16, 2.55, 3.024, 3.30] if item == "shotgun" else [0.35, 0.55, 1.12, 1.80, 2.04, 2.55, 2.85]
			for instante in instantes:
				rig._na_mao = item
				rig._mostrar_arma(item)
				ap.play(clipe)
				ap.seek(instante, true)
				for arma in rig.get_node("Armas").get_children(): arma._process(0.0)
				rig._atualizar_pose()
				await get_tree().process_frame
				ap.seek(instante, true)
				rig._atualizar_pose()
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s-%.3f.png" % [PASTA, clipe, instante])
	print("Fotos FP: ", ProjectSettings.globalize_path(PASTA))
	get_tree().quit()
