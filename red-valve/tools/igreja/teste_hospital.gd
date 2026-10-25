extends Node

## O Maycow com o Jonny no colo dentro do hospital: anda, larga (ui_largar),
## confere o ponto no mapa, pega de volta (ui_accept), anda de novo e tenta
## sair pela porta da rua. Fotografa de fora (camera e luz proprias, de lado).
##
##     IGREJA_FOTOS=/tmp/x Godot_v4.6.1 --path red-valve --resolution 1280x720 \
##         res://tools/igreja/teste_hospital.tscn

var pasta := "/tmp/hospital_jonny"
var n := 0
var cam: Camera3D
var luz: OmniLight3D


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
	Input.action_press("ui_mover_cima")
	await get_tree().create_timer(1.6).timeout
	print("velocidade no colo=", Vector2(p.velocity.x, p.velocity.z).length())
	await _de_lado(p, "andando")
	await get_tree().create_timer(0.27).timeout
	await _de_lado(p, "andando_b")
	Input.action_release("ui_mover_cima")
	await get_tree().create_timer(0.8).timeout
	await _de_lado(p, "parado")
	await _apertar("ui_largar")
	await get_tree().create_timer(1.4).timeout
	await _de_lado(p, "largando")
	await get_tree().create_timer(2.4).timeout
	await _de_lado(p, "largou")
	print("estado=", SaveManager.evento_dona_nice, " carregando=", p.carregando_jonny,
		" jonny=", SaveManager.jonny_no_hospital,
		" pontos_vivos=", MapaDados.pontos_vivos(get_tree(), MapaDados.caminho_da_cena(get_tree())))
	# afasta, volta, e pega de novo
	Input.action_press("ui_mover_baixo")
	await get_tree().create_timer(1.2).timeout
	Input.action_release("ui_mover_baixo")
	await get_tree().create_timer(0.5).timeout
	await _foto("mapa_com_jonny")
	Input.action_press("ui_mover_cima")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("ui_mover_cima")
	await get_tree().create_timer(0.4).timeout
	await _foto("prompt_pegar")
	await _apertar("ui_accept")
	await get_tree().create_timer(1.2).timeout
	await _de_lado(p, "pegando_a")
	await get_tree().create_timer(1.2).timeout
	await _de_lado(p, "pegando_b")
	await get_tree().create_timer(1.6).timeout
	await _de_lado(p, "pegou")
	print("depois de pegar: estado=", SaveManager.evento_dona_nice, " carregando=", p.carregando_jonny,
		" pontos_vivos=", MapaDados.pontos_vivos(get_tree(), MapaDados.caminho_da_cena(get_tree())).size())
	Input.action_press("ui_mover_cima")
	await get_tree().create_timer(1.2).timeout
	await _de_lado(p, "andando_de_novo")
	Input.action_release("ui_mover_cima")
	get_tree().current_scene.sair_do_hospital()
	await get_tree().create_timer(0.5).timeout
	print("cena depois de tentar sair: ", get_tree().current_scene.scene_file_path)
	await _foto("porta_trancada")
	get_tree().quit()


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
	# o corpo que se ve' fica ~40 cm atras da origem do player
	var corpo := (p.get_node("maycow_lopes_normal") as Node3D).global_position
	cam.global_position = corpo + lado * 1.7 + frente * 0.5 + Vector3(0, 0.2, 0)
	cam.look_at(corpo + Vector3(0, 0.05, 0))
	luz.global_position = cam.global_position + Vector3(0, 0.6, 0)
	cam.make_current()
	await _foto(rotulo)
	cam.global_position = corpo + frente * 1.8 + lado * 0.7 + Vector3(0, 0.3, 0)
	cam.look_at(corpo + Vector3(0, 0.05, 0))
	luz.global_position = cam.global_position + Vector3(0, 0.6, 0)
	await _foto(rotulo + "_frente")
	p._cutscene_camera_disabled = false


func _foto(rotulo: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [pasta, n, rotulo])
	n += 1
