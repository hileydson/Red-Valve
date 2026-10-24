extends Node

## Fotografa a escola de pontos fixos, para comparar antes/depois sem jogar.
##
##     Godot_v4.6.1 --path red-valve --resolution 1280x720 res://tools/escola/fotos.tscn
##
## Sem `--headless`: o que se quer é o render. As fotos vão para a pasta em
## ESCOLA_FOTOS (ou /tmp/escola_fotos), com o prefixo ESCOLA_FOTOS_PREFIXO.
## ESCOLA_FOTOS_SO="3,5" fotografa só esses índices.

const CENA := "res://scenes/stages/escola/escola.tscn"
const CENA_PORAO := "res://scenes/stages/escola/porao.tscn"

## ESCOLA_CENA=porao troca a cena e os pontos.
const PONTOS_PORAO := [
	["p0_entrada", Vector3(17.4, 1.5, 9.5), Vector3(25.9, 1.2, 13.0)],
	["p1_tunel", Vector3(44.7, 1.5, 23.4), Vector3(53.4, 1.2, 20.3)],
	["p2_curva", Vector3(75.1, 1.5, 20.8), Vector3(76.7, 1.2, 28.7)],
	["p3_camara", Vector3(26.0, 1.7, 38.0), Vector3(44.0, 1.0, 50.0)],
	["p4_tunel", Vector3(23.9, 1.5, 54.1), Vector3(16.2, 1.2, 58.4)],
	["p5_saida", Vector3(45.8, 1.5, 70.3), Vector3(54.7, 1.2, 67.8)],
]

## (nome, posição da câmera, para onde ela olha)
const PONTOS := [
	["00_patio_portao", Vector3(3.6, 1.7, 30.5), Vector3(24.0, 1.3, 33.0)],
	["01_corredor_norte", Vector3(3.0, 1.7, 12.85), Vector3(40.0, 1.5, 12.85)],
	["02_sala_102", Vector3(28.6, 1.75, 8.6), Vector3(16.0, 1.2, 4.0)],
	["03_corredor_leste", Vector3(73.1, 1.7, 13.0), Vector3(73.1, 1.5, 50.0)],
	["04_refeitorio", Vector3(48.0, 1.75, 17.5), Vector3(66.0, 0.9, 29.0)],
	["05_biblioteca", Vector3(52.0, 1.75, 50.4), Vector3(52.0, 1.2, 34.0)],
	["06_laboratorio", Vector3(60.0, 1.75, 50.0), Vector3(68.5, 1.0, 35.0)],
	["07_corredor_sul_grade", Vector3(68.5, 1.7, 54.5), Vector3(50.0, 1.4, 54.5)],
	["08_deposito", Vector3(60.0, 1.75, 59.2), Vector3(70.0, 0.9, 66.5)],
	["09_secretaria", Vector3(61.5, 1.75, 8.8), Vector3(74.0, 1.0, 2.0)],
	["10_sala_106", Vector3(40.6, 1.75, 59.0), Vector3(28.5, 1.0, 65.0)],
	["11_almoxarifado", Vector3(10.5, 1.75, 58.5), Vector3(1.5, 0.9, 64.0)],
	["12_patio_quadra", Vector3(40.0, 2.2, 48.0), Vector3(14.0, 0.8, 24.0)],
	["13_sala_101_porta", Vector3(7.0, 1.7, 13.8), Vector3(7.0, 1.4, 3.0)],
	# de perto: o que se le' e o que se ve' pregado
	["14_lousa_104", Vector3(50.0, 1.6, 5.2), Vector3(45.4, 1.5, 5.2)],
	["15_mural_norte", Vector3(8.2, 1.6, 12.2), Vector3(8.2, 1.6, 15.4)],
	["16_buraco_deposito", Vector3(65.5, 1.6, 61.5), Vector3(67.0, 0.7, 67.6)],
	["17_biblioteca_silencio", Vector3(52.2, 1.7, 39.0), Vector3(52.2, 2.0, 32.4)],
	["18_saida_principal", Vector3(20.0, 1.6, 11.6), Vector3(20.0, 2.4, 15.4)],
	["19_desenhos_101", Vector3(9.5, 1.6, 4.0), Vector3(15.0, 1.5, 4.5)],
	["20_bandeirinhas", Vector3(22.0, 1.7, 44.0), Vector3(22.0, 4.0, 29.0)],
	["21_bandeira_caida", Vector3(33.0, 1.7, 38.0), Vector3(38.0, 1.0, 44.0)],
]


func _ready() -> void:
	# save_game() roda no _ready da escola: sem isto o teste grava por cima do
	# save do jogador.
	SaveManager.current_slot = 9
	var pasta := OS.get_environment("ESCOLA_FOTOS")
	if pasta.is_empty():
		pasta = "/tmp/escola_fotos"
	DirAccess.make_dir_recursive_absolute(pasta)
	var prefixo := OS.get_environment("ESCOLA_FOTOS_PREFIXO")
	var so := OS.get_environment("ESCOLA_FOTOS_SO")
	var escolhidos: Array = []
	for s in so.split(",", false):
		escolhidos.append(int(s))

	var porao := OS.get_environment("ESCOLA_CENA") == "porao"
	var pontos: Array = PONTOS_PORAO if porao else PONTOS
	if not OS.get_environment("ESCOLA_IDIOMA").is_empty():
		TranslationServer.set_locale(OS.get_environment("ESCOLA_IDIOMA"))
	var cena: Node = load(CENA_PORAO if porao else CENA).instantiate()
	add_child(cena)
	await get_tree().create_timer(3.0).timeout

	# Ajuste fino sem regerar a cena:
	#   ESCOLA_ENV="ambient_light_energy=2.5;tonemap_exposure=1.3"
	#   ESCOLA_LENTE="exposicao=1.2;grao=0.0"   (ou "off")
	var we := cena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	for par in OS.get_environment("ESCOLA_ENV").split(";", false):
		var kv := par.split("=")
		we.environment.set(kv[0], str_to_var(kv[1]))
	var lente := cena.get_node_or_null("lente/tela") as ColorRect
	var cfg_lente := OS.get_environment("ESCOLA_LENTE")
	if lente and cfg_lente == "off":
		lente.visible = false
	elif lente:
		for par in cfg_lente.split(";", false):
			var kv := par.split("=")
			(lente.material as ShaderMaterial).set_shader_parameter(kv[0], str_to_var(kv[1]))

	# ESCOLA_ESCONDER="detalhes,lente" — some com esses nós (mede o custo deles)
	for nome in OS.get_environment("ESCOLA_ESCONDER").split(",", false):
		var no := cena.get_node_or_null(nome)
		if no:
			no.queue_free()
	# ESCOLA_SEM_SOMBRA_LUAR=1 — tira a sombra dos luares de sala
	if OS.get_environment("ESCOLA_SEM_SOMBRA_LUAR") == "1":
		for luz in cena.find_children("luar_*", "SpotLight3D", true, false):
			(luz as Light3D).shadow_enabled = false

	var jogador := cena.get_node_or_null("Player")
	# ESCOLA_JOGADOR=1 — foto pela camera do PROPRIO jogador, no spawn
	if OS.get_environment("ESCOLA_JOGADOR") == "1":
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%sjogador.png" % [pasta, prefixo])
		get_tree().quit()
		return
	if jogador:
		jogador.set("_cutscene_camera_disabled", true)
		jogador.set_physics_process(false)
		jogador.global_position = Vector3(-30.0, 1.0, -30.0)
		jogador.visible = false
	GlobalUtils.esconder_objetivo()

	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 300.0
	cena.add_child(cam)
	cam.make_current()
	# ESCOLA_LANTERNA=1 — a lanterna do jogador, copiada pra camera de teste
	if OS.get_environment("ESCOLA_LANTERNA") == "1" and jogador:
		var original := jogador.get_node_or_null("Camera3D/lanterna") as SpotLight3D
		if original:
			var lanterna := original.duplicate() as SpotLight3D
			lanterna.transform = Transform3D(Basis(), Vector3(0.25, -0.25, 0.0))
			lanterna.visible = true
			cam.add_child(lanterna)

	for i in pontos.size():
		if not escolhidos.is_empty() and not escolhidos.has(i):
			continue
		var p: Array = pontos[i]
		cam.global_position = p[1]
		cam.look_at(p[2], Vector3.UP)
		cam.make_current()
		# Partículas, sombra e auto-exposição precisam de alguns quadros para
		# assentar depois do salto de câmera.
		await get_tree().create_timer(0.9).timeout
		# FPS medio de 2 s, contado em quadros: o `get_frames_per_second` e'
		# uma amostra so' e oscilava de 40 a 60 na mesma vista.
		var q0 := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_usec()
		await get_tree().create_timer(2.0).timeout
		var fps_medio := (Engine.get_frames_drawn() - q0) / ((Time.get_ticks_usec() - t0) / 1000000.0)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s%s.png" % [pasta, prefixo, p[0]])
		print("foto: %s  fps %.1f  draw %d  objetos %d  prim %d" % [p[0],
			fps_medio,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
