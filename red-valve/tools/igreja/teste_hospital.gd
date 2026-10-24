extends Node

## O Maycow com o Jonny no colo dentro do hospital: anda, larga (ui_largar) e
## tenta sair pela porta da rua. Fotografa de fora (camera propria, de lado).
##
##     IGREJA_FOTOS=/tmp/x Godot_v4.6.1 --path red-valve --resolution 1280x720 \
##         res://tools/igreja/teste_hospital.tscn

var pasta := "/tmp/hospital_jonny"
var n := 0
var cam: Camera3D


func _ready() -> void:
	SaveManager.current_slot = 9
	SaveManager.evento_dona_nice = 4
	if not OS.get_environment("IGREJA_FOTOS").is_empty():
		pasta = OS.get_environment("IGREJA_FOTOS")
	DirAccess.make_dir_recursive_absolute(pasta)
	var raiz := get_tree().root
	get_parent().remove_child.call_deferred(self)
	raiz.add_child.call_deferred(self)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/stages/hospital/hospital.tscn")
	await get_tree().create_timer(4.0).timeout
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	print("carregando=", p.carregando_jonny)
	await _foto("jogo")
	Input.action_press("ui_up")
	await get_tree().create_timer(1.6).timeout
	await _de_lado(p, "andando")
	Input.action_release("ui_up")
	await get_tree().create_timer(0.6).timeout
	await _de_lado(p, "parado")
	var ev := InputEventAction.new()
	ev.action = "ui_largar"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.1).timeout
	ev = InputEventAction.new()
	ev.action = "ui_largar"
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().create_timer(1.4).timeout
	await _de_lado(p, "largando")
	await get_tree().create_timer(2.4).timeout
	await _de_lado(p, "largou")
	print("estado=", SaveManager.evento_dona_nice, " carregando=", p.carregando_jonny,
		" jonny=", SaveManager.jonny_no_hospital)
	get_tree().current_scene.sair_do_hospital()
	await get_tree().create_timer(0.5).timeout
	print("cena depois de tentar sair: ", get_tree().current_scene.scene_file_path)
	await _foto("porta_trancada")
	get_tree().quit()


func _de_lado(p: Node3D, rotulo: String) -> void:
	if cam == null:
		cam = Camera3D.new()
		get_tree().current_scene.add_child(cam)
	p._cutscene_camera_disabled = true
	var frente := -p.global_basis.z
	var lado := frente.cross(Vector3.UP)
	cam.global_position = p.global_position + lado * 2.6 + frente * 1.0 + Vector3(0, 0.3, 0)
	cam.look_at(p.global_position + Vector3(0, -0.1, 0))
	cam.make_current()
	await _foto(rotulo)
	p._cutscene_camera_disabled = false


func _foto(rotulo: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [pasta, n, rotulo])
	n += 1
