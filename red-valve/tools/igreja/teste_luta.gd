extends Node

## Joga a luta da Dona Nice sozinho, de ponta a ponta, e fotografa.
##
##     IGREJA_ESTADO=1 IGREJA_FOTOS=/tmp/x Godot_v4.6.1 --path red-valve \
##         --resolution 1280x720 res://tools/igreja/teste_luta.tscn
##
## IGREJA_ESTADO = o `evento_dona_nice` de partida (0 roda a chegada inteira).
## Usa o slot 9. O driver vai pra raiz da arvore antes de trocar de cena, por
## isso sobrevive a ela.

var pasta := "/tmp/igreja_luta"
var n_foto := 0


func _ready() -> void:
	SaveManager.current_slot = 9
	SaveManager.evento_dona_nice = int(OS.get_environment("IGREJA_ESTADO"))
	if not OS.get_environment("IGREJA_FOTOS").is_empty():
		pasta = OS.get_environment("IGREJA_FOTOS")
	DirAccess.make_dir_recursive_absolute(pasta)
	var raiz := get_tree().root
	get_parent().remove_child.call_deferred(self)
	raiz.add_child.call_deferred(self)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/stages/igreja/igreja_interior.tscn")
	await _esperar(3.0)
	await _roteiro()
	get_tree().quit()


func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _foto(rotulo: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [pasta, n_foto, rotulo])
	print("FOTO ", n_foto, " ", rotulo, " estado=", SaveManager.evento_dona_nice,
		" vida=", _jogador().current_health if _jogador() else -1)
	n_foto += 1


func _jogador() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _evento() -> Node:
	return get_tree().current_scene.get_node_or_null("evento_dona_nice")


func _boss() -> Node:
	var e := _evento()
	return e.boss if e and is_instance_valid(e.boss) else null


func _roteiro() -> void:
	var e := _evento()
	if e == null:
		print("ERRO sem evento")
		return
	if SaveManager.evento_dona_nice == 0:
		await _foto("chegada")
		await _esperar(20.0)
		await _foto("chegada_20s")
		await _esperar(38.0)
		var j := _jogador()
		print("CHEGADA acabou: estado=", SaveManager.evento_dona_nice, " in_cutscene=",
			GlobalEvents.in_cutscene, " controle_travado=", j._cutscene_inputs_disabled,
			" pistola=", SaveManager.is_equipped("pistol"), " boss=", _boss() != null)
		await _foto("luta_comeca")
		if OS.get_environment("IGREJA_SO_CHEGADA") == "1":
			return
	await _esperar(3.5)
	if SaveManager.evento_dona_nice == 1:
		await _fase_1()
	if SaveManager.evento_dona_nice == 2:
		await _fase_2()
	if SaveManager.evento_dona_nice == 3:
		await _jonny()


func _fase_1() -> void:
	await _foto("fase1_inicio")
	var b := _boss()
	var p0: Vector3 = b.global_position
	await _esperar(4.0)
	print("boss andou ", p0.distance_to(b.global_position), " m")
	await _foto("fase1_andando")
	# chega perto: ela agarra
	var j := _jogador()
	j.global_position = b.global_position + b.global_basis.z * 1.3 + Vector3(0, 1.0, 0)
	await _esperar(1.6)
	await _foto("fase1_agarrao")
	await _esperar(4.0)
	await _foto("fase1_solta")
	# 29 tiros, e o trigesimo
	var dano: int = int(j.damage_pistol) if "damage_pistol" in j else 10
	for i in 29:
		b.take_damage(dano)
		await _esperar(0.05)
	print("vida boss ", b.current_health, "/", b.max_health)
	j.global_position = Vector3(0, 1.05, 6.0)
	b.take_damage(dano)
	await _esperar(3.5)
	await _foto("vira_fase2_a")
	await _esperar(4.0)
	await _foto("vira_fase2_b")
	await _esperar(4.5)


func _fase_2() -> void:
	await _foto("fase2_inicio")
	await _esperar(5.0)
	await _foto("fase2_flutuando")
	var b := _boss()
	b._prox_tapa = b._tempo
	await _esperar(1.3)
	await _foto("fase2_investida")
	await _esperar(1.1)
	await _foto("fase2_tapa")
	await _esperar(4.0)
	await _foto("fase2_gosma")
	var j := _jogador()
	var dano: int = int(j.damage_pistol) if "damage_pistol" in j else 10
	for i in 30:
		if is_instance_valid(b):
			b.take_damage(dano)
		await _esperar(0.05)
	await _esperar(5.0)
	await _foto("morte_final")
	await _esperar(8.0)


func _jonny() -> void:
	var j := _jogador()
	var jonny := get_tree().current_scene.find_child("Jonny", true, false) as Node3D
	j.global_position = jonny.global_position + Vector3(0, 1.05, -1.4)
	await _esperar(1.0)
	await _foto("jonny_prompt")
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _esperar(0.1)
	ev = InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = false
	Input.parse_input_event(ev)
	await _esperar(3.0)
	await _foto("pega_jonny")
	await _esperar(6.0)
	await _foto("saindo")
	print("cena atual ", get_tree().current_scene.scene_file_path, " igreja=", GlobalEvents.voltando_da_igreja)
	# a corrida pela cidade e a chegada no hospital
	for i in 14:
		await _esperar(2.5)
		var cena := get_tree().current_scene
		await _foto("depois_%02d_%s" % [i, cena.name if cena else "?"])
	print("FIM cena=", get_tree().current_scene.scene_file_path, " estado=", SaveManager.evento_dona_nice)
