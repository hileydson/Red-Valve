extends Node

## O Maycow sai da igreja com o Jonny no colo e vai a pe' pela cidade: confere
## o adro, o objetivo, andar e correr no colo, o prompt da igreja calado,
## largar e pegar de volta na rua (save com a cena e a posicao) e a entrada no
## hospital com ele no colo.
##
##     IGREJA_FOTOS=/tmp/x Godot_v4.6.1 --path red-valve --resolution 1280x720 \
##         res://tools/igreja/teste_cidade.tscn

var pasta := "/tmp/cidade_jonny"
var n := 0
var cam: Camera3D
var luz: OmniLight3D


func _ready() -> void:
	SaveManager.current_slot = 9
	SaveManager.prolog_finished = true
	SaveManager.evento_dona_nice = 4
	SaveManager.stage_1_saved_position = {}
	GlobalEvents.voltando_da_igreja = true
	if not OS.get_environment("IGREJA_FOTOS").is_empty():
		pasta = OS.get_environment("IGREJA_FOTOS")
	DirAccess.make_dir_recursive_absolute(pasta)
	var raiz := get_tree().root
	get_parent().remove_child.call_deferred(self)
	raiz.add_child.call_deferred(self)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1.tscn")
	await get_tree().create_timer(7.0).timeout
	var cena := get_tree().current_scene
	var p := cena.get_node("Player") as CharacterBody3D
	print("adro: pos=", p.global_position, " carregando=", p.carregando_jonny,
		" prompt=", cena.prompt_label.visible, " na_igreja=", cena.player_na_igreja)
	await _foto("adro")
	await _de_lado(p, "adro_colo")

	Input.action_press("ui_mover_cima")
	await get_tree().create_timer(1.6).timeout
	print("andando=", _rapidez(p), " clipe=", _clipe(p), " fov=", get_viewport().get_camera_3d().fov)
	Input.action_press("ui_run")
	await get_tree().create_timer(2.0).timeout
	print("correndo=", _rapidez(p), " clipe=", _clipe(p), " x", _passada(p),
		" fov=", get_viewport().get_camera_3d().fov)
	await _de_lado(p, "correndo")
	Input.action_release("ui_run")
	Input.action_release("ui_mover_cima")
	await get_tree().create_timer(1.0).timeout

	# a porta da igreja nao chama com ele no colo
	p.global_position = cena.IGREJA_PORTA + Vector3(-12, 1, 0)
	await get_tree().create_timer(1.0).timeout
	p.global_position = cena.IGREJA_PORTA + Vector3(0, 0.5, 0)
	await get_tree().create_timer(1.0).timeout
	print("voltou ao adro: na_igreja=", cena.player_na_igreja, " prompt=", cena.prompt_label.visible)
	p.global_position = cena.IGREJA_PORTA + Vector3(-12, 1, 0)
	await get_tree().create_timer(1.5).timeout

	await _apertar("ui_largar")
	await get_tree().create_timer(3.7).timeout
	await _de_lado(p, "largou")
	print("largou: estado=", SaveManager.evento_dona_nice, " cena=", SaveManager.jonny_deixado_em,
		" jonny=", SaveManager.jonny_no_hospital, " pos_salva=", SaveManager.stage_1_saved_position,
		" pontos_vivos=", MapaDados.pontos_vivos(get_tree(), MapaDados.caminho_da_cena(get_tree())).size())
	var jo := get_tree().current_scene.find_child("jonny", true, false) as Node3D
	if jo:
		print("jonny deitado: giro=", jo.global_rotation_degrees, " pos=", jo.global_position)
	await _foto("mapa_com_jonny")
	await _apertar("ui_accept")
	await get_tree().create_timer(4.0).timeout
	print("pegou: estado=", SaveManager.evento_dona_nice, " carregando=", p.carregando_jonny)

	var area := cena._no_do_hospital().get_node("area_entrada") as Node3D
	p.global_position = area.global_position + Vector3(0, 1.0, 0)
	await get_tree().create_timer(1.5).timeout
	print("hospital: na_area=", cena.player_no_hospital, " prompt=", cena.prompt_label.visible,
		" texto=", cena.prompt_label.text)
	await _foto("porta_hospital")
	await _apertar("ui_accept")
	await get_tree().create_timer(9.0).timeout
	var h := get_tree().current_scene
	var ph := get_tree().get_first_node_in_group("player")
	print("FIM cena=", h.scene_file_path, " carregando=", ph.carregando_jonny if ph else null,
		" estado=", SaveManager.evento_dona_nice)
	await _foto("dentro_hospital")
	get_tree().quit()


func _rapidez(p: CharacterBody3D) -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _passada(p: Node) -> float:
	var ap := p.find_child("AnimColo", true, false) as AnimationPlayer
	return ap.speed_scale if ap else 0.0


func _clipe(p: Node) -> String:
	var ap := p.find_child("AnimColo", true, false) as AnimationPlayer
	return ap.current_animation if ap else "?"


func _apertar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.1).timeout
	ev = InputEventAction.new()
	ev.action = acao
	ev.pressed = false
	Input.parse_input_event(ev)


func _de_lado(p: Node3D, rotulo: String) -> void:
	if cam == null:
		cam = Camera3D.new()
		get_tree().current_scene.add_child(cam)
	p._cutscene_camera_disabled = true
	if luz == null:
		luz = OmniLight3D.new()
		luz.omni_range = 6.0
		luz.light_energy = 2.0
		get_tree().current_scene.add_child(luz)
	var frente := -p.global_basis.z
	var lado := frente.cross(Vector3.UP)
	var corpo := (p.get_node("maycow_lopes_normal") as Node3D).global_position
	cam.global_position = corpo + frente * 1.8 + lado * 0.9 + Vector3(0, 0.3, 0)
	cam.look_at(corpo + Vector3(0, 0.05, 0))
	luz.global_position = cam.global_position + Vector3(0, 0.6, 0)
	cam.make_current()
	await _foto(rotulo)
	p._cutscene_camera_disabled = false


func _foto(rotulo: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [pasta, n, rotulo])
	n += 1
