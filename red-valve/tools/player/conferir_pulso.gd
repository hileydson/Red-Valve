extends Node

const CENA := "res://scenes/stages/hospital/hospital.tscn"
const PASTA := "/tmp/claude-1000/-home-dev-Documents-Development-Game-Development-Red-Valve-Red-Valve/50b164e1-5634-4c7f-bf78-f036c200a4a4/scratchpad/"
const PONTO := Vector3(6.0, 0.3, 34.0)

var _player: CharacterBody3D
var _mod: Node


func _ready() -> void:
	SaveManager.current_slot = 9
	GlobalEvents.is_maycow_normal = true
	SaveManager.prolog_finished = true
	add_child(load(CENA).instantiate())
	for i in 300:
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player != null and i > 180:
			break
	SaveManager.add_item("pistol", 1)
	SaveManager.add_item("pistol_ammo", 25)
	SaveManager.equip_item("pistol")
	_player.update_equipment_visuals()
	_player.global_position = PONTO
	_player.rotation.y = 0.0
	for filho in _player.find_children("*", "SkeletonModifier3D", true, false):
		if filho.has_method("direcao_do_cano"):
			_mod = filho

	Input.action_press("ui_hold_first_person_view")
	for i in 180:
		await get_tree().physics_frame
	_player.set_physics_process(false)
	_player._cutscene_camera_disabled = true

	var malha: MeshInstance3D = _player.find_child("char1", true, false)
	var arma: Node3D = malha.find_child("PistolaNaMao", true, false)
	var cam := Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.make_current()
	await RenderingServer.frame_post_draw

	var pulso := arma.global_position + Vector3(-0.05, -0.02, 0.13)
	for caso in [["sem", 0.0], ["com", 0.5]]:
		_mod._torcao = caso[1]
		for k in 5:
			await get_tree().process_frame
		for a in [["lado", Vector3(-0.45, 0.16, -0.22)], ["cima", Vector3(-0.22, 0.48, 0.02)]]:
			cam.global_position = pulso + (a[1] as Vector3)
			cam.look_at(pulso, Vector3.UP)
			for k in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				PASTA + "pulso_" + String(caso[0]) + "_" + String(a[0]) + ".png")
		print("fotografado torcao=", caso[1])
	get_tree().quit()
