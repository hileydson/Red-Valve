extends Node

## Fotografa a cutscene da Dona Nice em instantes escolhidos, dentro da igreja.
##
##     IGREJA_TEMPOS="0.5,7,12" IGREJA_ANIM=chegada IGREJA_FOTOS=/tmp/x \
##         Godot_v4.6.1 --path red-valve --resolution 1280x720 res://tools/igreja/fotos_cena.tscn
##
## Sem --headless (o que se quer e' o render). Cada foto sai como t_<tempo>.png.

func _ready() -> void:
	SaveManager.current_slot = 9
	var igreja: Node = load("res://scenes/stages/igreja/igreja_interior.tscn").instantiate()
	igreja.set_meta("sem_evento", true)
	add_child(igreja)
	var cena: Node = load("res://scenes/stages/igreja/cena_dona_nice.tscn").instantiate()
	igreja.add_child(cena)
	await get_tree().create_timer(2.5).timeout
	var pl := igreja.get_node_or_null("Player")
	if pl:
		pl._cutscene_camera_disabled = true
		pl.cutscene_set_hud_enabled(false)
		pl.global_position = Vector3(0, -50, 0)
		pl.set_physics_process(false)
	var pasta := OS.get_environment("IGREJA_FOTOS")
	if pasta.is_empty():
		pasta = "/tmp/igreja_fotos"
	DirAccess.make_dir_recursive_absolute(pasta)
	var anim := OS.get_environment("IGREJA_ANIM")
	if anim.is_empty():
		anim = "chegada"
	# as cenas depois da chegada acontecem com os bancos ja' nas naves laterais
	# (e sem a Dona Nice de gente, que a chegada transformou)
	if anim != "chegada":
		cena.bancos_no_canto()
		cena.get_node("atores/DonaNice").visible = false
	cena.tocar(anim)
	var diretor: AnimationPlayer = cena.get_node("diretor")
	for s in OS.get_environment("IGREJA_TEMPOS").split(",", false):
		var t := float(s)
		# deixa a cena RODAR ate' o instante (particulas, tweens e o laco dos
		# clipes so' ficam certos assim); seek direto so' quando e' pra tras
		var falta := t - diretor.current_animation_position
		if falta < 0.0:
			diretor.seek(t, true)
		else:
			await get_tree().create_timer(falta).timeout
		await get_tree().process_frame
		var cam_extra := OS.get_environment("IGREJA_CAM")    # "x,y,z>x,y,z"
		if not cam_extra.is_empty():
			var par := cam_extra.split(">")
			var de := par[0].split(",")
			var para := par[1].split(",")
			var c := Camera3D.new()
			c.fov = 40.0
			add_child(c)
			c.global_position = Vector3(float(de[0]), float(de[1]), float(de[2]))
			c.look_at(Vector3(float(para[0]), float(para[1]), float(para[2])))
			c.make_current()
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(pasta + "/t_%s.png" % s)
		print("foto ", s, " plano=", cena.plano)
	get_tree().quit()
