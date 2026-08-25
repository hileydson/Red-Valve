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
var water_mat: StandardMaterial3D
var ivy_mat: StandardMaterial3D
var red_grate_mat: StandardMaterial3D
var metal_mat: StandardMaterial3D

func _generate_city() -> void:
	for child in get_children():
		child.queue_free()
		
	_setup_materials()
	
	# Iluminação - Golden Hour suave e quente
	var light = DirectionalLight3D.new()
	light.name = "GoldenHourLight"
	light.light_color = Color(1.0, 0.85, 0.5) 
	light.light_energy = 2.5
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-20, 35, 0) # Sombras longas
	add_child(light)
	light.owner = get_tree().edited_scene_root
	
	# Base da Cidade (Asfalto/Pedra)
	_create_box("Chao_Asfalto", Vector3(200, 0.5, 200), Vector3(0, -0.25, 0), road_mat)
	
	# Floresta Densa (Fundo e bordas)
	_create_box("Floresta_Fundo", Vector3(250, 2, 80), Vector3(0, 1, -120), forest_mat)
	_create_box("Floresta_Esq", Vector3(40, 2, 200), Vector3(-120, 1, 0), forest_mat)
	_create_box("Floresta_Dir", Vector3(40, 2, 200), Vector3(120, 1, 0), forest_mat)
	
	_populate_trees("Arvores_Fundo", Vector3(0, 2, -120), Vector2(240, 70), 100)
	
	# 1. Igreja Central (Bloco proeminente e aberto)
	var igreja_z = -30
	var igreja_x = 0
	_create_box("Igreja_Grama", Vector3(40, 0.6, 40), Vector3(igreja_x, 0.3, igreja_z), forest_mat)
	_create_box("Igreja_Corpo", Vector3(20, 15, 30), Vector3(igreja_x, 7.5, igreja_z), landmark_mat)
	_create_box("Igreja_Contraforte1", Vector3(24, 10, 5), Vector3(igreja_x, 5, igreja_z - 5), landmark_mat)
	_create_box("Igreja_Contraforte2", Vector3(24, 10, 5), Vector3(igreja_x, 5, igreja_z + 5), landmark_mat)
	_create_box("Igreja_Torre", Vector3(8, 25, 8), Vector3(igreja_x, 12.5, igreja_z - 15), landmark_mat)
	# Sino e Agulha
	_create_box("Igreja_Sino", Vector3(4, 4, 4), Vector3(igreja_x, 27, igreja_z - 15), metal_mat)
	var agulha = CSGCylinder3D.new(); agulha.name = "Igreja_Agulha"; agulha.cone = true
	agulha.radius = 5; agulha.height = 15; agulha.position = Vector3(igreja_x, 36.5, igreja_z - 15); agulha.material = landmark_mat
	add_child(agulha); agulha.owner = get_tree().edited_scene_root
	# Cerca
	_create_box("Igreja_Cerca_Frente", Vector3(40, 2, 1), Vector3(igreja_x, 1, igreja_z + 20), metal_mat)
	
	# 2. Solar / Mansão (Canto Superior Esquerdo)
	var mansao_x = -70; var mansao_z = -60
	_create_box("Mansao_Terreno", Vector3(50, 0.6, 50), Vector3(mansao_x, 0.3, mansao_z), dirt_mat)
	_create_box("Mansao_Muro_Sul", Vector3(50, 4, 2), Vector3(mansao_x, 2, mansao_z + 25), landmark_mat)
	_create_box("Mansao_Muro_Leste", Vector3(2, 4, 50), Vector3(mansao_x + 25, 2, mansao_z), landmark_mat)
	_create_box("Mansao_Predio_Principal", Vector3(30, 18, 15), Vector3(mansao_x - 5, 9, mansao_z - 10), landmark_mat)
	_create_box("Mansao_Ala_Lateral", Vector3(10, 12, 20), Vector3(mansao_x - 15, 6, mansao_z + 7.5), landmark_mat)
	_create_box("Mansao_Jardim_Formal", Vector3(20, 0.8, 20), Vector3(mansao_x + 10, 0.4, mansao_z + 10), forest_mat) # Pátio interno
	
	# 3. Praça Circular (Canto Superior Direito)
	var praca_x = 70; var praca_z = -50
	var praca = CSGCylinder3D.new()
	praca.name = "Praca_Circular"
	praca.radius = 22; praca.height = 0.8; praca.position = Vector3(praca_x, 0.4, praca_z); praca.material = dirt_mat
	add_child(praca); praca.owner = get_tree().edited_scene_root
	var praca_calcada = CSGCylinder3D.new()
	praca_calcada.name = "Praca_Calcada"
	praca_calcada.radius = 24; praca_calcada.height = 0.6; praca_calcada.position = Vector3(praca_x, 0.3, praca_z); praca_calcada.material = landmark_mat
	add_child(praca_calcada); praca_calcada.owner = get_tree().edited_scene_root
	
	_create_box("Monumento_Base", Vector3(6, 2, 6), Vector3(praca_x, 1.4, praca_z), landmark_mat)
	var monumento_coluna = CSGCylinder3D.new()
	monumento_coluna.name = "Monumento_Coluna"
	monumento_coluna.radius = 1.5; monumento_coluna.height = 20; monumento_coluna.position = Vector3(praca_x, 12, praca_z); monumento_coluna.material = landmark_mat
	add_child(monumento_coluna); monumento_coluna.owner = get_tree().edited_scene_root
	
	# 4. Fábrica / Estação de Tratamento (Frente Esquerda)
	var trat_x = -65; var trat_z = 60
	_create_box("Tratamento_Base", Vector3(45, 1, 40), Vector3(trat_x, 0.5, trat_z), dirt_mat)
	_create_box("Tratamento_Predio", Vector3(20, 12, 15), Vector3(trat_x - 10, 6, trat_z + 10), landmark_mat)
	
	var t1 = CSGCylinder3D.new(); t1.name = "Tanque_Grande"; t1.radius = 8; t1.height = 6; t1.position = Vector3(trat_x + 10, 3, trat_z - 5); t1.material = landmark_mat
	add_child(t1); t1.owner = get_tree().edited_scene_root
	var t2 = CSGCylinder3D.new(); t2.name = "Tanque_Menor"; t2.radius = 5; t2.height = 8; t2.position = Vector3(trat_x + 12, 4, trat_z + 10); t2.material = landmark_mat
	add_child(t2); t2.owner = get_tree().edited_scene_root
	
	# Tubos expostos
	var tubo1 = CSGCylinder3D.new(); tubo1.name = "Tubo_Exposto"; tubo1.radius = 0.8; tubo1.height = 20; tubo1.position = Vector3(trat_x, 3, trat_z); tubo1.rotation_degrees.z = 90; tubo1.material = metal_mat
	add_child(tubo1); tubo1.owner = get_tree().edited_scene_root
	
	# 5. Casa do Jimmy (Frente Direita)
	var jimmy_x = 65; var jimmy_z = 50
	_create_box("Casa_do_Jimmy", Vector3(15, 10, 12), Vector3(jimmy_x, 5, jimmy_z), house_mat)
	var jimmy_telhado = CSGCylinder3D.new(); jimmy_telhado.name = "Jimmy_Telhado"; jimmy_telhado.radius = 10; jimmy_telhado.height = 15; jimmy_telhado.position = Vector3(jimmy_x, 13, jimmy_z); jimmy_telhado.rotation_degrees.z = 90; jimmy_telhado.rotation_degrees.y = 90; jimmy_telhado.material = house_roof_mat
	add_child(jimmy_telhado); jimmy_telhado.owner = get_tree().edited_scene_root

	# 6. Ruas e Textos (Asfalto/Pedra com Inscrições)
	# R. Padre Gabriel de Melo (Primeiro plano inferior)
	_create_text_label("R. Padre Gabriel de Melo", Vector3(-20, 0.6, 85), Vector3(-90, 0, 0))
	_create_text_label("Av. Padre Gabriel de Melo", Vector3(20, 0.6, 70), Vector3(-90, 0, 0))
	
	# Rua Margarida Maria Alves (Diagonal do esq-inferior pro centro-superior)
	_create_text_label("Rua Margarida Maria Alves", Vector3(-30, 0.6, 10), Vector3(-90, -45, 0))
	
	# Rua Antónia Fortes (Esquerda pro centro)
	_create_text_label("Rua Antónia Fortes", Vector3(-70, 0.6, -10), Vector3(-90, 0, 0))
	
	# Rua Estrela Guia de Laga (Direita pro centro)
	_create_text_label("Rua Estrela Guia de Laga", Vector3(60, 0.6, -10), Vector3(-90, 0, 0))
	
	_create_text_label("TRATAMENTO ESGOTO", Vector3(trat_x, 0.6, trat_z + 25), Vector3(-90, 0, 0), 100)
	_create_text_label("CASA DO JIMMY", Vector3(jimmy_x, 0.6, jimmy_z + 15), Vector3(-90, 0, 0), 100)

	# 7. Compass Rose (Rosa dos Ventos no asfalto - Canto Inferior Direito)
	var compass_x = 85; var compass_z = 85
	_create_text_label("N", Vector3(compass_x, 0.6, compass_z - 6), Vector3(-90, 0, 0), 120)
	_create_text_label("S", Vector3(compass_x, 0.6, compass_z + 6), Vector3(-90, 0, 0), 120)
	_create_text_label("E", Vector3(compass_x + 6, 0.6, compass_z), Vector3(-90, 0, 0), 120)
	_create_text_label("O", Vector3(compass_x - 6, 0.6, compass_z), Vector3(-90, 0, 0), 120)
	_create_box("Compass_NS", Vector3(0.5, 0.6, 10), Vector3(compass_x, 0.3, compass_z), landmark_mat)
	_create_box("Compass_EO", Vector3(10, 0.6, 0.5), Vector3(compass_x, 0.3, compass_z), landmark_mat)

	# 8. Quarteirões Densos (Grade de labirinto preenchendo o vazio)
	# Centro-Oeste (Entre Antónia Fortes e Diagonal)
	_generate_block("Bloco_Oeste1", Vector3(-35, 0, -30), Vector2(25, 30))
	_generate_block("Bloco_Oeste2", Vector3(-30, 0, 30), Vector2(25, 20))
	
	# Centro (Abaixo da Igreja)
	_generate_block("Bloco_Centro1", Vector3(0, 0, 10), Vector2(25, 25))
	_generate_block("Bloco_Centro2", Vector3(0, 0, 40), Vector2(30, 20))
	
	# Centro-Leste (Entre Igreja e Praça, e abaixo de Estrela Guia)
	_generate_block("Bloco_Leste1", Vector3(35, 0, -40), Vector2(20, 25))
	_generate_block("Bloco_Leste2", Vector3(35, 0, -5), Vector2(25, 30))
	_generate_block("Bloco_Leste3", Vector3(35, 0, 30), Vector2(25, 25))
	
	# Blocos ao redor da diagonal
	_generate_block("Bloco_Diag1", Vector3(-15, 0, -10), Vector2(15, 20), -0.7)
	_generate_block("Bloco_Diag2", Vector3(-50, 0, 5), Vector2(20, 15), -0.7)

	# 9. Grelhas Vermelhas de Chão (Red floor grates no asfalto)
	_create_box("Grelha_1", Vector3(2.5, 0.7, 2.5), Vector3(-20, 0.35, 20), red_grate_mat)
	_create_box("Grelha_2", Vector3(2.5, 0.7, 2.5), Vector3(25, 0.35, -20), red_grate_mat)
	_create_box("Grelha_3", Vector3(2.5, 0.7, 2.5), Vector3(-50, 0.35, -15), red_grate_mat)
	_create_box("Grelha_4", Vector3(2.5, 0.7, 2.5), Vector3(15, 0.35, 60), red_grate_mat)

	print("Layout isométrico completo baseado na descrição maquete gerado!")

func _setup_materials():
	house_mat = StandardMaterial3D.new()
	house_mat.albedo_color = Color(0.7, 0.65, 0.6) # Pedra/Estuque
	
	house_roof_mat = StandardMaterial3D.new()
	house_roof_mat.albedo_color = Color(0.6, 0.25, 0.15) # Telha terracota
	
	landmark_mat = StandardMaterial3D.new()
	landmark_mat.albedo_color = Color(0.65, 0.65, 0.7) # Pedra nobre
	
	road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.25, 0.25, 0.25) # Paralelepípedo escuro
	
	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.35, 0.25, 0.2)
	
	forest_mat = StandardMaterial3D.new()
	forest_mat.albedo_color = Color(0.1, 0.22, 0.1)
	
	tree_mat = StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.15, 0.3, 0.15)
	
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.1, 0.4, 0.6)
	
	ivy_mat = StandardMaterial3D.new()
	ivy_mat.albedo_color = Color(0.2, 0.35, 0.15)
	
	red_grate_mat = StandardMaterial3D.new()
	red_grate_mat.albedo_color = Color(0.7, 0.1, 0.1)
	
	metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.3, 0.3, 0.3)
	metal_mat.metallic = 0.8

func _create_box(node_name: String, size: Vector3, pos: Vector3, mat: Material) -> CSGBox3D:
	var b = CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = pos
	b.material = mat
	add_child(b)
	b.owner = get_tree().edited_scene_root
	return b

func _create_text_label(text: String, pos: Vector3, rot: Vector3 = Vector3.ZERO, font_size: int = 150, color: Color = Color.WHITE):
	var lbl = Label3D.new()
	lbl.name = "Text_" + text.replace(" ", "_").replace(".", "")
	lbl.text = text
	lbl.position = pos
	lbl.rotation_degrees = rot
	lbl.font_size = font_size
	lbl.modulate = color
	lbl.outline_size = 24
	lbl.outline_modulate = Color.BLACK
	add_child(lbl)
	lbl.owner = get_tree().edited_scene_root

func _populate_trees(group_name: String, center: Vector3, area: Vector2, count: int):
	var group = Node3D.new()
	group.name = group_name
	group.position = center
	add_child(group)
	group.owner = get_tree().edited_scene_root
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(count):
		var rx = rng.randf_range(-area.x/2, area.x/2)
		var rz = rng.randf_range(-area.y/2, area.y/2)
		var h = rng.randf_range(6.0, 15.0)
		
		var tree = CSGCylinder3D.new()
		tree.name = "Arvore"
		tree.radius = rng.randf_range(1.5, 3.0)
		tree.height = h
		tree.position = Vector3(rx, h/2.0, rz)
		tree.material = tree_mat
		group.add_child(tree)
		tree.owner = get_tree().edited_scene_root

func _generate_block(block_name: String, center: Vector3, size: Vector2, rot_y: float = 0.0):
	var b_node = Node3D.new()
	b_node.name = block_name
	b_node.position = center
	b_node.rotation.y = rot_y
	add_child(b_node)
	b_node.owner = get_tree().edited_scene_root
	
	var house_size = 6.0 # Casas densamente alinhadas
	var cols = int(size.x / house_size)
	var rows = int(size.y / house_size)
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for x in range(cols):
		for z in range(rows):
			if x == 0 or x == cols - 1 or z == 0 or z == rows - 1:
				var h = rng.randf_range(6.0, 10.0) # 2 a 3 andares
				var px = (x * house_size) - (size.x/2.0) + (house_size/2.0)
				var pz = (z * house_size) - (size.y/2.0) + (house_size/2.0)
				
				# Corpo da Casa (Pedra/Estuque/Tijolo)
				var house = CSGBox3D.new()
				house.name = "Casa_Colonial"
				house.size = Vector3(house_size * 0.95, h, house_size * 0.95)
				house.position = Vector3(px, h/2.0, pz)
				house.material = house_mat
				b_node.add_child(house)
				house.owner = get_tree().edited_scene_root
				
				# Telhado Texturizado (Terracota)
				var roof = CSGCylinder3D.new()
				roof.name = "Telhado"
				roof.cone = true
				roof.sides = 4 # Formato de pirâmide/telhado simples
				roof.radius = house_size * 0.7
				roof.height = 3.0
				roof.position = Vector3(0, (h/2.0) + 1.5, 0)
				roof.rotation_degrees.y = 45
				roof.material = house_roof_mat
				house.add_child(roof)
				roof.owner = get_tree().edited_scene_root
				
				# Pequenas árvores nas ruas/pátios
				if rng.randf() > 0.85:
					var street_tree = CSGCylinder3D.new()
					street_tree.name = "Arvore_Rua"
					street_tree.radius = 1.0; street_tree.height = 4.0; street_tree.material = tree_mat
					street_tree.position = Vector3(0, -h/2.0 + 2.0, house_size * 0.8)
					house.add_child(street_tree)
					street_tree.owner = get_tree().edited_scene_root
