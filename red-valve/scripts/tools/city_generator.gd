@tool
extends Node3D
class_name CityGenerator

@export var generate_layout: bool = false:
	set(value):
		if value:
			_generate_city()
			generate_layout = false

var house_mat: StandardMaterial3D
var house_roof_mat: StandardMaterial3D
var landmark_mat: StandardMaterial3D
var road_mat: StandardMaterial3D
var dirt_mat: StandardMaterial3D
var forest_mat: StandardMaterial3D
var tree_mat: StandardMaterial3D
var red_grate_mat: StandardMaterial3D
var metal_mat: StandardMaterial3D
var green_mat: StandardMaterial3D
var rng: RandomNumberGenerator

func _generate_city() -> void:
	for child in get_children():
		child.queue_free()
	rng = RandomNumberGenerator.new()
	rng.seed = 42
	_setup_materials()
	_add_lighting()
	_add_ground()
	_add_roads()
	_add_church()
	_add_mansion()
	_add_treatment_plant()
	_add_plaza()
	_add_jimmy_house()
	_add_housing_blocks()
	_add_forest()
	_add_labels()
	_add_grates()
	_add_compass()
	_add_legenda()
	print("Cidade gerada com sucesso!")

func _setup_materials():
	house_mat = StandardMaterial3D.new()
	house_mat.albedo_color = Color(0.72, 0.65, 0.55)

	house_roof_mat = StandardMaterial3D.new()
	house_roof_mat.albedo_color = Color(0.58, 0.22, 0.12)

	landmark_mat = StandardMaterial3D.new()
	landmark_mat.albedo_color = Color(0.78, 0.76, 0.72)

	road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.22, 0.20, 0.18)

	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.38, 0.28, 0.18)

	forest_mat = StandardMaterial3D.new()
	forest_mat.albedo_color = Color(0.1, 0.20, 0.08)

	tree_mat = StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.12, 0.28, 0.10)

	red_grate_mat = StandardMaterial3D.new()
	red_grate_mat.albedo_color = Color(0.75, 0.08, 0.08)

	metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.32, 0.32, 0.34)
	metal_mat.metallic = 0.85
	metal_mat.roughness = 0.3

	green_mat = StandardMaterial3D.new()
	green_mat.albedo_color = Color(0.18, 0.35, 0.12)

func _add_lighting():
	var light = DirectionalLight3D.new()
	light.name = "GoldenHourLight"
	light.light_color = Color(1.0, 0.82, 0.48)
	light.light_energy = 3.0
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-22, 40, 0)
	_add(light)

	var ambient = WorldEnvironment.new()
	ambient.name = "WorldEnv"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.75, 0.55)
	env.ambient_light_energy = 0.6
	ambient.environment = env
	_add(ambient)

func _add_ground():
	_box("Chao_Principal", Vector3(240, 0.4, 240), Vector3(0, -0.2, 0), road_mat)

func _add_roads():
	# Avenida Padre Gabriel (primeiro plano - Z positivo)
	_box("Rua_Padre1", Vector3(220, 0.5, 8), Vector3(0, 0.05, 78), road_mat)
	_box("Rua_Padre2", Vector3(220, 0.5, 6), Vector3(0, 0.05, 66), road_mat)
	# Rua Antonia Fortes (horizontal centro-esquerda)
	_box("Rua_Antonia", Vector3(100, 0.5, 6), Vector3(-60, 0.05, -8), road_mat)
	# Rua Estrela Guia (horizontal centro-direita)
	_box("Rua_Estrela", Vector3(80, 0.5, 6), Vector3(60, 0.05, -8), road_mat)
	# Rua Margarida Alves (diagonal - aproximada em zigzag)
	_box("Rua_Marg1", Vector3(6, 0.5, 60), Vector3(-30, 0.05, 15), road_mat)
	_box("Rua_Marg2", Vector3(60, 0.5, 6), Vector3(-5, 0.05, -15), road_mat)
	# Ruas internas dos quarteiroes
	_box("Rua_Interna1", Vector3(6, 0.5, 80), Vector3(15, 0.05, 20), road_mat)
	_box("Rua_Interna2", Vector3(6, 0.5, 80), Vector3(-15, 0.05, 20), road_mat)
	_box("Rua_Interna3", Vector3(80, 0.5, 6), Vector3(0, 0.05, 30), road_mat)
	_box("Rua_Interna4", Vector3(80, 0.5, 6), Vector3(0, 0.05, 10), road_mat)

func _add_church():
	var cx = 0.0; var cz = -35.0
	# Patio verde
	_box("Igreja_Patio", Vector3(44, 0.6, 44), Vector3(cx, 0.3, cz), green_mat)
	# Cerca do patio (4 lados)
	_box("Igreja_Cerca_N", Vector3(44, 2, 1), Vector3(cx, 1, cz - 22), metal_mat)
	_box("Igreja_Cerca_S", Vector3(44, 2, 1), Vector3(cx, 1, cz + 22), metal_mat)
	_box("Igreja_Cerca_L", Vector3(1, 2, 44), Vector3(cx + 22, 1, cz), metal_mat)
	_box("Igreja_Cerca_O", Vector3(1, 2, 44), Vector3(cx - 22, 1, cz), metal_mat)
	# Nave central
	_box("Igreja_Nave", Vector3(18, 14, 28), Vector3(cx, 7, cz + 2), landmark_mat)
	# Absida (traseira)
	_box("Igreja_Absida", Vector3(10, 12, 8), Vector3(cx, 6, cz - 14), landmark_mat)
	# Contrafortes laterais
	_box("Igreja_CF1", Vector3(3, 10, 6), Vector3(cx - 10, 5, cz - 5), landmark_mat)
	_box("Igreja_CF2", Vector3(3, 10, 6), Vector3(cx + 10, 5, cz - 5), landmark_mat)
	_box("Igreja_CF3", Vector3(3, 10, 6), Vector3(cx - 10, 5, cz + 5), landmark_mat)
	_box("Igreja_CF4", Vector3(3, 10, 6), Vector3(cx + 10, 5, cz + 5), landmark_mat)
	# Torre sineira
	_box("Igreja_Torre", Vector3(8, 28, 8), Vector3(cx, 14, cz - 12), landmark_mat)
	# Sino (caixinha na torre)
	_box("Igreja_Sino", Vector3(5, 3, 5), Vector3(cx, 29, cz - 12), metal_mat)
	# Agulha (cone)
	var agulha = CSGCylinder3D.new()
	agulha.name = "Igreja_Agulha"
	agulha.cone = true; agulha.radius = 4; agulha.height = 18; agulha.sides = 4
	agulha.position = Vector3(cx, 40, cz - 12)
	agulha.rotation_degrees.y = 45
	agulha.material = house_roof_mat
	_add(agulha)
	# Telhado da nave
	var tnave = CSGCylinder3D.new()
	tnave.name = "Igreja_TelhadoNave"
	tnave.cone = true; tnave.radius = 12; tnave.height = 6; tnave.sides = 4
	tnave.position = Vector3(cx, 16, cz + 2)
	tnave.rotation_degrees.y = 45
	tnave.material = house_roof_mat
	_add(tnave)

func _add_mansion():
	var mx = -75.0; var mz = -60.0
	# Terreno
	_box("Mansao_Terreno", Vector3(55, 0.7, 52), Vector3(mx, 0.35, mz), dirt_mat)
	# Jardim formal interno
	_box("Mansao_Jardim", Vector3(22, 0.8, 18), Vector3(mx + 8, 0.4, mz + 5), green_mat)
	# Muro (4 lados)
	_box("Mansao_Muro_N", Vector3(55, 4, 2), Vector3(mx, 2, mz - 26), landmark_mat)
	_box("Mansao_Muro_S", Vector3(55, 4, 2), Vector3(mx, 2, mz + 26), landmark_mat)
	_box("Mansao_Muro_L", Vector3(2, 4, 52), Vector3(mx + 27, 2, mz), landmark_mat)
	_box("Mansao_Muro_O", Vector3(2, 4, 52), Vector3(mx - 27, 2, mz), landmark_mat)
	# Portao de entrada
	_box("Mansao_Portao", Vector3(6, 6, 2), Vector3(mx, 3, mz + 26), metal_mat)
	# Predio principal
	_box("Mansao_Principal", Vector3(30, 20, 18), Vector3(mx - 4, 10, mz - 8), landmark_mat)
	# Ala lateral esquerda
	_box("Mansao_Ala_O", Vector3(10, 14, 28), Vector3(mx - 20, 7, mz + 4), landmark_mat)
	# Ala lateral direita
	_box("Mansao_Ala_L", Vector3(10, 14, 20), Vector3(mx + 14, 7, mz - 4), landmark_mat)
	# Telhados
	var tm = CSGCylinder3D.new()
	tm.name = "Mansao_Telhado"; tm.cone = true; tm.radius = 18; tm.height = 6; tm.sides = 4
	tm.position = Vector3(mx - 4, 22, mz - 8); tm.rotation_degrees.y = 45; tm.material = house_roof_mat
	_add(tm)

func _add_treatment_plant():
	var tx = -65.0; var tz = 58.0
	# Base industrial
	_box("Trat_Base", Vector3(48, 1, 44), Vector3(tx, 0.5, tz), dirt_mat)
	# Predio principal
	_box("Trat_Predio", Vector3(20, 14, 16), Vector3(tx - 10, 7, tz + 8), landmark_mat)
	# Telhado shed industrial
	_box("Trat_TelhadoA", Vector3(21, 2, 8), Vector3(tx - 10, 15, tz + 4), metal_mat)
	_box("Trat_TelhadoB", Vector3(21, 1, 8), Vector3(tx - 10, 14.5, tz + 12), metal_mat)
	# Tanque grande
	var t1 = CSGCylinder3D.new()
	t1.name = "Trat_Tanque1"; t1.radius = 9; t1.height = 7; t1.sides = 24
	t1.position = Vector3(tx + 12, 4.5, tz - 5); t1.material = metal_mat
	_add(t1)
	# Tanque menor
	var t2 = CSGCylinder3D.new()
	t2.name = "Trat_Tanque2"; t2.radius = 5.5; t2.height = 9; t2.sides = 24
	t2.position = Vector3(tx + 14, 5, tz + 12); t2.material = metal_mat
	_add(t2)
	# Chamine
	var chamine = CSGCylinder3D.new()
	chamine.name = "Trat_Chamine"; chamine.radius = 2; chamine.height = 22; chamine.sides = 12
	chamine.position = Vector3(tx - 22, 11, tz + 14); chamine.material = metal_mat
	_add(chamine)
	# Tubo horizontal
	var tubo = CSGCylinder3D.new()
	tubo.name = "Trat_Tubo"; tubo.radius = 1.0; tubo.height = 30; tubo.sides = 8
	tubo.position = Vector3(tx, 2, tz); tubo.rotation_degrees.z = 90; tubo.material = metal_mat
	_add(tubo)
	var tubo2 = CSGCylinder3D.new()
	tubo2.name = "Trat_Tubo2"; tubo2.radius = 0.7; tubo2.height = 22; tubo2.sides = 8
	tubo2.position = Vector3(tx + 5, 3, tz + 2); tubo2.rotation_degrees.x = 90; tubo2.material = metal_mat
	_add(tubo2)

func _add_plaza():
	var px = 72.0; var pz = -52.0
	var calcada = CSGCylinder3D.new()
	calcada.name = "Praca_Calcada"; calcada.radius = 26; calcada.height = 0.7; calcada.sides = 32
	calcada.position = Vector3(px, 0.35, pz); calcada.material = landmark_mat
	_add(calcada)
	var base = CSGCylinder3D.new()
	base.name = "Praca_Jardim"; base.radius = 22; base.height = 0.8; base.sides = 32
	base.position = Vector3(px, 0.4, pz); base.material = green_mat
	_add(base)
	# Monumento: base + coluna + esfera
	_box("Monumento_Base", Vector3(7, 3, 7), Vector3(px, 1.5, pz), landmark_mat)
	var coluna = CSGCylinder3D.new()
	coluna.name = "Monumento_Coluna"; coluna.radius = 1.5; coluna.height = 22; coluna.sides = 8
	coluna.position = Vector3(px, 14, pz); coluna.material = landmark_mat
	_add(coluna)
	var topo = CSGCylinder3D.new()
	topo.name = "Monumento_Topo"; topo.cone = true; topo.radius = 3; topo.height = 4; topo.sides = 8
	topo.position = Vector3(px, 27, pz); topo.material = landmark_mat
	_add(topo)
	# Bancos ao redor
	for i in range(4):
		var ang = i * 90.0
		var bx = px + cos(deg_to_rad(ang)) * 14
		var bz = pz + sin(deg_to_rad(ang)) * 14
		_box("Banco_%d" % i, Vector3(3, 0.8, 1.2), Vector3(bx, 0.4, bz), landmark_mat)

func _add_jimmy_house():
	var jx = 65.0; var jz = 50.0
	_box("Jimmy_Casa", Vector3(14, 10, 12), Vector3(jx, 5, jz), house_mat)
	var jroof = CSGCylinder3D.new()
	jroof.name = "Jimmy_Telhado"; jroof.cone = true; jroof.radius = 9; jroof.height = 5; jroof.sides = 4
	jroof.position = Vector3(jx, 12, jz); jroof.rotation_degrees.y = 45; jroof.material = house_roof_mat
	_add(jroof)
	# Muro externo simples
	_box("Jimmy_Muro_F", Vector3(18, 2, 1), Vector3(jx, 1, jz + 8), landmark_mat)

func _add_housing_blocks():
	# Layout organico - cidade colonial brasileira que cresceu sem planejamento rigido
	# Definimos os quarteiroes manualmente com tamanhos, posicoes e rotacoes variadas
	# para simular o crescimento organico da cidade da imagem de referencia

	var blocks = [
		# [centro_x, centro_z, largura, profundidade, rotacao_graus]
		# --- Zona Norte (acima da Igreja) ---
		[-45, -72, 28, 16, -3.0],
		[-16, -68, 20, 14, 2.5],
		[20, -70, 24, 15, -1.5],
		[44, -75, 20, 14, 4.0],

		# --- Zona Noroeste (entre Mansao e Igreja) ---
		[-42, -52, 22, 18, -5.0],
		[-42, -28, 24, 16, 3.5],
		[-18, -55, 18, 20, 2.0],

		# --- Zona Nordeste (entre Igreja e Praca) ---
		[26, -55, 20, 18, -2.0],
		[26, -30, 22, 16, 5.0],
		[50, -30, 18, 20, -3.5],

		# --- Centro-Oeste ---
		[-42, -8, 20, 18, 4.0],
		[-18, -10, 22, 16, -2.5],
		[-42, 15, 22, 16, -4.5],
		[-18, 18, 18, 18, 3.0],

		# --- Centro ---
		[8, -12, 20, 18, 2.0],
		[8, 12, 18, 16, -3.0],
		[32, -10, 20, 16, 4.5],
		[32, 16, 18, 18, -2.0],

		# --- Centro-Leste ---
		[56, -10, 18, 16, 3.0],
		[56, 15, 20, 16, -4.0],

		# --- Zona Sul-Oeste (perto da Fabrica) ---
		[-38, 35, 20, 16, -5.5],
		[-15, 35, 18, 16, 3.0],
		[-38, 55, 20, 14, 2.5],

		# --- Zona Sul-Centro ---
		[8, 35, 22, 16, -2.0],
		[32, 35, 18, 16, 4.0],
		[8, 52, 20, 14, 3.5],

		# --- Zona Sul-Leste (perto de Jimmy) ---
		[36, 52, 18, 14, -3.0],
		[56, 35, 16, 16, 2.0],

		# --- Bordas extremas (cidade se espalhando) ---
		[-70, -30, 16, 20, 6.0],
		[-70, -5, 14, 18, -5.0],
		[78, -28, 16, 18, -4.0],
		[78, 0, 14, 18, 3.5],
		[-55, -72, 18, 14, 5.0],
	]

	for i in range(blocks.size()):
		var bd = blocks[i]
		var bx = bd[0]; var bz = bd[1]
		var bw = bd[2]; var bd2 = bd[3]; var brot = bd[4]

		if _is_landmark_zone(bx, bz):
			continue

		# Pequeno offset organico adicional
		var ox = rng.randf_range(-2.5, 2.5)
		var oz = rng.randf_range(-2.5, 2.5)

		_gen_block("HB_%d" % i, Vector3(bx + ox, 0, bz + oz), Vector2(bw, bd2), brot)

func _is_landmark_zone(bx: float, bz: float) -> bool:
	if abs(bx - 0) < 26 and abs(bz - (-35)) < 26:
		return true
	if abs(bx - (-75)) < 32 and abs(bz - (-60)) < 30:
		return true
	if abs(bx - 72) < 30 and abs(bz - (-52)) < 30:
		return true
	if abs(bx - (-65)) < 28 and abs(bz - 58) < 26:
		return true
	if abs(bx - 65) < 16 and abs(bz - 50) < 16:
		return true
	return false

func _gen_block(bname: String, center: Vector3, size: Vector2, rotation_deg: float = 0.0):
	var b_node = Node3D.new()
	b_node.name = bname
	b_node.position = center
	b_node.rotation_degrees.y = rotation_deg
	_add(b_node)

	var step = rng.randf_range(5.5, 7.0) # passo variavel por bloco = mais organico
	var cols = int(size.x / step)
	var rows = int(size.y / step)
	if cols < 1: cols = 1
	if rows < 1: rows = 1

	for x in range(cols):
		for z in range(rows):
			var h = rng.randf_range(5.5, 11.0)
			var w = rng.randf_range(4.8, 6.8)
			var d = rng.randf_range(4.5, 7.5) # profundidade diferente da largura
			var px = (x * step) - (size.x / 2.0) + step * 0.5 + rng.randf_range(-0.8, 0.8)
			var pz = (z * step) - (size.y / 2.0) + step * 0.5 + rng.randf_range(-0.8, 0.8)

			var house = CSGBox3D.new()
			house.name = "Casa"
			house.size = Vector3(w, h, d)
			house.position = Vector3(px, h * 0.5, pz)
			# Leve rotacao individual por casa (rua nao totalmente alinhada)
			house.rotation_degrees.y = rng.randf_range(-4.0, 4.0)
			var hmat = house_mat if rng.randf() > 0.45 else landmark_mat
			house.material = hmat
			b_node.add_child(house)
			house.owner = get_tree().edited_scene_root

			var roof = CSGCylinder3D.new()
			roof.name = "Telhado"
			roof.cone = true; roof.sides = 4
			roof.radius = w * 0.65; roof.height = rng.randf_range(2.5, 4.0)
			roof.position = Vector3(px, h + roof.height * 0.5, pz)
			roof.rotation_degrees.y = 45
			roof.material = house_roof_mat
			b_node.add_child(roof)
			roof.owner = get_tree().edited_scene_root

			# Arvore de rua ocasional
			if rng.randf() > 0.88:
				var st = CSGCylinder3D.new()
				st.name = "ArvoreRua"
				st.radius = 0.8; st.height = rng.randf_range(3.0, 6.0); st.sides = 6
				st.position = Vector3(px + step * 0.5, st.height * 0.5, pz + step * 0.5)
				st.material = tree_mat
				b_node.add_child(st)
				st.owner = get_tree().edited_scene_root

func _add_forest():
	# Floresta ao norte (fundo)
	_box("Floresta_N", Vector3(260, 3, 60), Vector3(0, 1.5, -125), forest_mat)
	_populate_trees("Arvores_N", Vector3(0, 3, -110), Vector2(230, 50), 120)
	# Floresta leste
	_box("Floresta_L", Vector3(50, 3, 260), Vector3(128, 1.5, 0), forest_mat)
	_populate_trees("Arvores_L", Vector3(115, 3, 0), Vector2(40, 200), 50)
	# Floresta oeste
	_box("Floresta_O", Vector3(50, 3, 260), Vector3(-128, 1.5, 0), forest_mat)
	_populate_trees("Arvores_O", Vector3(-115, 3, 0), Vector2(40, 200), 50)

func _populate_trees(gname: String, center: Vector3, area: Vector2, count: int):
	var g = Node3D.new()
	g.name = gname
	g.position = center
	_add(g)
	for i in range(count):
		var rx = rng.randf_range(-area.x * 0.5, area.x * 0.5)
		var rz = rng.randf_range(-area.y * 0.5, area.y * 0.5)
		var h = rng.randf_range(7.0, 18.0)
		var t = CSGCylinder3D.new()
		t.name = "Arv"
		t.radius = rng.randf_range(1.5, 3.5); t.height = h; t.sides = 6
		t.position = Vector3(rx, h * 0.5, rz)
		t.material = tree_mat if rng.randf() > 0.3 else forest_mat
		g.add_child(t)
		t.owner = get_tree().edited_scene_root

func _add_labels():
	_label("Av. Padre Gabriel de Melo", Vector3(-10, 0.6, 78), Vector3(-90, 0, 0))
	_label("R. Padre Gabriel de Melo", Vector3(-10, 0.6, 66), Vector3(-90, 0, 0))
	_label("Rua Margarida Maria Alves", Vector3(-22, 0.6, 5), Vector3(-90, -45, 0))
	_label("Rua Antónia Fortes", Vector3(-72, 0.6, -8), Vector3(-90, 0, 0))
	_label("Rua Estrela Guia de Laga", Vector3(52, 0.6, -8), Vector3(-90, 0, 0))
	_label("TRATAMENTO ESGOTO", Vector3(-65, 0.6, 75), Vector3(-90, 0, 0), 120)
	_label("CASA DO JIMMY", Vector3(65, 0.6, 62), Vector3(-90, 0, 0), 120)

func _add_grates():
	var positions = [
		Vector3(-22, 0.5, 18), Vector3(24, 0.5, -22), Vector3(-48, 0.5, -18),
		Vector3(15, 0.5, 58), Vector3(-5, 0.5, 38), Vector3(30, 0.5, 5),
		Vector3(-18, 0.5, -42), Vector3(48, 0.5, 32), Vector3(0, 0.5, -18)
	]
	for i in range(positions.size()):
		_box("Grelha_%d" % i, Vector3(2.5, 0.4, 2.5), positions[i], red_grate_mat)

func _add_compass():
	var cx = 88.0; var cz = 88.0
	_box("Compass_NS", Vector3(0.5, 0.5, 14), Vector3(cx, 0.35, cz), landmark_mat)
	_box("Compass_EO", Vector3(14, 0.5, 0.5), Vector3(cx, 0.35, cz), landmark_mat)
	_label("N", Vector3(cx, 0.6, cz - 9), Vector3(-90, 0, 0), 140)
	_label("S", Vector3(cx, 0.6, cz + 9), Vector3(-90, 0, 0), 140)
	_label("L", Vector3(cx + 9, 0.6, cz), Vector3(-90, 0, 0), 140)
	_label("O", Vector3(cx - 9, 0.6, cz), Vector3(-90, 0, 0), 140)

func _add_legenda():
	var lx = -90.0; var lz = 80.0
	_box("Legenda_Fundo", Vector3(38, 0.5, 18), Vector3(lx, 0.25, lz), road_mat)
	_box("Legenda_Borda", Vector3(40, 0.5, 20), Vector3(lx, 0.15, lz), landmark_mat)
	_label("LEGENDA", Vector3(lx, 0.7, lz - 5), Vector3(-90, 0, 0), 110)
	_label("• Ponto de Válvula Vermelha", Vector3(lx - 4, 0.7, lz + 2), Vector3(-90, 0, 0), 70, Color(1, 0.2, 0.2))
	# Icone vermelho da legenda
	_box("Legenda_Icon", Vector3(2, 0.6, 2), Vector3(lx - 16, 0.5, lz + 2), red_grate_mat)

func _add(node: Node):
	add_child(node)
	node.owner = get_tree().edited_scene_root

func _box(bname: String, size: Vector3, pos: Vector3, mat: Material) -> CSGBox3D:
	var b = CSGBox3D.new()
	b.name = bname
	b.size = size
	b.position = pos
	b.material = mat
	_add(b)
	return b

func _label(text: String, pos: Vector3, rot: Vector3 = Vector3.ZERO, fsize: int = 150, color: Color = Color.WHITE):
	var lbl = Label3D.new()
	lbl.name = "Txt_" + text.left(20).replace(" ", "_")
	lbl.text = text
	lbl.position = pos
	lbl.rotation_degrees = rot
	lbl.font_size = fsize
	lbl.modulate = color
	lbl.outline_size = 20
	lbl.outline_modulate = Color.BLACK
	_add(lbl)
