extends Node

## Pausa e despausa na igreja e confere se o jogo volta a andar.
##     IGREJA_ESTADO=5 Godot_v4.6.1 --path red-valve res://tools/igreja/teste_pausa.tscn

var pasta := "/tmp/igreja_pausa"
var n_foto := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.current_slot = 9
	SaveManager.evento_dona_nice = int(OS.get_environment("IGREJA_ESTADO"))
	DirAccess.make_dir_recursive_absolute(pasta)
	var raiz := get_tree().root
	get_parent().remove_child.call_deferred(self)
	raiz.add_child.call_deferred(self)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/stages/igreja/igreja_interior.tscn")
	await _esperar(float(OS.get_environment("IGREJA_ESPERA")) if OS.get_environment("IGREJA_ESPERA") != "" else 4.0)
	await _estado("antes")
	await _andar("antes")
	await _apertar("ui_pause")
	await _esperar(float(OS.get_environment("IGREJA_PAUSA_SEG")) if OS.get_environment("IGREJA_PAUSA_SEG") != "" else 0.6)
	await _estado("pausado")
	if OS.get_environment("IGREJA_CONFIG") == "1":
		get_tree().current_scene.get_node("Pause")._on_config_pressed()
		await _esperar(1.0)
		await _estado("config")
		await _apertar("ui_cancel")
		await _esperar(0.6)
		await _estado("voltou_da_config")
	await _apertar(OS.get_environment("IGREJA_SAIDA") if OS.get_environment("IGREJA_SAIDA") != "" else "ui_pause")
	await _esperar(0.6)
	await _estado("despausado")
	await _andar("depois")
	await _esperar(2.0)
	await _estado("fim")
	get_tree().quit()


func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _apertar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	ev = InputEventAction.new()
	ev.action = acao
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _andar(rotulo: String) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var p0 := p.global_position
	Input.action_press("ui_mover_cima")
	await _esperar(1.0)
	Input.action_release("ui_mover_cima")
	print("ANDAR ", rotulo, ": ", p0.distance_to(p.global_position), " m")


func _estado(rotulo: String) -> void:
	var p := get_tree().get_first_node_in_group("player")
	var pausa := get_tree().current_scene.get_node_or_null("Pause")
	print("ESTADO ", rotulo, ": paused=", get_tree().paused, " pause.visible=",
		pausa.visible if pausa else null, " in_cutscene=", GlobalEvents.in_cutscene,
		" cin=", GlobalUtils.in_cinematic_cutscene, " travado=", p._cutscene_inputs_disabled,
		" time_scale=", Engine.time_scale, " phys=", p.is_physics_processing(),
		" proc_mode=", p.process_mode, " can_process=", p.can_process())
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [pasta, n_foto, rotulo])
	n_foto += 1
