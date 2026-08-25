@tool
extends Node3D
class_name CityGenerator

@export var generate_layout: bool = false:
	set(value):
		if value:
			_generate_city()
			generate_layout = false # Desmarca o botão automaticamente

var house_mat: StandardMaterial3D
var landmark_mat: StandardMaterial3D
var road_mat: StandardMaterial3D
var forest_mat: StandardMaterial3D

func _generate_city() -> void:
	# Limpar a cena atual
	for child in get_children():
		child.queue_free()
		
	_setup_materials()
	
	# Chão da cidade
	_create_box("Chao_Cidade", Vector3(250, 1, 200), Vector3(0, -0.5, -10), road_mat)
	
	# 1. Floresta ao Fundo (Topo da imagem)
	_create_box("Floresta_Base", Vector3(250, 2, 50), Vector3(0, 1, -90), forest_mat)
	
	# 2. Igreja e Campanário (Centro Fundo)
	var igreja_base = _create_box("Igreja_Base", Vector3(25, 18, 40), Vector3(10, 9, -50), landmark_mat)
	_create_box("Igreja_Torre", Vector3(8, 35, 8), Vector3(10, 17.5, -60), landmark_mat) # Torre alta
	
	# 3. Mansão com Jardim (Esquerda)
	var mansao_chao = _create_box("Mansao_Jardim", Vector3(45, 1, 45), Vector3(-70, 0.1, -25), forest_mat)
	_create_box("Mansao_Predio", Vector3(25, 15, 20), Vector3(-70, 7.5, -30), landmark_mat)
	_create_box("Mansao_Muro", Vector3(45, 4, 2), Vector3(-70, 2, -2.5), landmark_mat)
	
	# 4. Praça Circular e Monumento (Direita Fundo)
	var praca = CSGCylinder3D.new()
	praca.name = "Praca_Circular"
	praca.radius = 18
	praca.height = 1.2
	praca.position = Vector3(70, 0, -40)
	praca.material = road_mat
	add_child(praca)
	praca.owner = get_tree().edited_scene_root
	
	_create_box("Monumento_Base", Vector3(6, 3, 6), Vector3(70, 1.5, -40), landmark_mat)
	_create_box("Monumento_Obelisco", Vector3(2, 18, 2), Vector3(70, 10, -40), landmark_mat)
	
	# 5. Tratamento de Esgoto (Frente Esquerda/Centro)
	_create_box("Tratamento_Esgoto_Base", Vector3(35, 10, 25), Vector3(-35, 5, 50), landmark_mat)
	
	var tanque1 = CSGCylinder3D.new()
	tanque1.name = "Tanque_1"
	tanque1.radius = 7; tanque1.height = 5; tanque1.position = Vector3(-43, 12, 50); tanque1.material = landmark_mat
	add_child(tanque1); tanque1.owner = get_tree().edited_scene_root
	
	var tanque2 = CSGCylinder3D.new()
	tanque2.name = "Tanque_2"
	tanque2.radius = 7; tanque2.height = 5; tanque2.position = Vector3(-27, 12, 50); tanque2.material = landmark_mat
	add_child(tanque2); tanque2.owner = get_tree().edited_scene_root
	
	var chamine = CSGCylinder3D.new()
	chamine.name = "Chamine_Vermelha"
	chamine.radius = 1.5; chamine.height = 25; chamine.position = Vector3(-45, 15, 38)
	var mat_vermelho = StandardMaterial3D.new(); mat_vermelho.albedo_color = Color(0.7, 0.2, 0.2)
	chamine.material = mat_vermelho
	add_child(chamine); chamine.owner = get_tree().edited_scene_root
	
	# 6. Casa do Jimmy (Frente Direita)
	_create_box("Casa_do_Jimmy", Vector3(18, 12, 15), Vector3(50, 6, 50), landmark_mat)
	
	# 7. Quarteirões Densos (O preenchimento da cidade em torno das ruas)
	# Quarteirões perto da Igreja
	_generate_block("Bloco_Centro_Norte", Vector3(-15, 0, -15), Vector2(40, 20))
	_generate_block("Bloco_Direita_Norte", Vector3(35, 0, -15), Vector2(25, 25))
	
	# Rua Margarida Maria Alves passa horizontalmente por volta do Z = 0
	# Quarteirões do meio
	_generate_block("Bloco_Oeste_Meio", Vector3(-35, 0, 15), Vector2(35, 25))
	_generate_block("Bloco_Centro_Meio", Vector3(10, 0, 15), Vector2(45, 25))
	_generate_block("Bloco_Leste_Meio", Vector3(65, 0, 10), Vector2(30, 20))
	
	# Rua Eustráquia Portela (Rua Diagonal)
	_generate_block("Bloco_Diagonal", Vector3(45, 0, 0), Vector2(15, 25), 0.6) # Rotacionado para criar a rua diagonal
	
	# Av Padre Gabriel de Melo passa por volta do Z = 35
	_generate_block("Bloco_Centro_Sul", Vector3(10, 0, 50), Vector2(25, 20))
	_generate_block("Bloco_Direita_Sul", Vector3(85, 0, 50), Vector2(20, 20))

	print("Layout exato baseado na imagem de referência gerado!")

func _setup_materials():
	house_mat = StandardMaterial3D.new()
	house_mat.albedo_color = Color(0.65, 0.55, 0.45) # Tons de telhado/colonial
	
	landmark_mat = StandardMaterial3D.new()
	landmark_mat.albedo_color = Color(0.7, 0.7, 0.7) # Prédios de pedra/concreto
	
	road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.25, 0.25, 0.25) # Paralelepípedo escuro
	
	forest_mat = StandardMaterial3D.new()
	forest_mat.albedo_color = Color(0.15, 0.3, 0.15) # Verde musgo

func _create_box(node_name: String, size: Vector3, pos: Vector3, mat: Material) -> CSGBox3D:
	var b = CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = pos
	b.material = mat
	add_child(b)
	b.owner = get_tree().edited_scene_root
	return b

func _generate_block(block_name: String, center: Vector3, size: Vector2, rot_y: float = 0.0):
	var b_node = Node3D.new()
	b_node.name = block_name
	b_node.position = center
	b_node.rotation.y = rot_y
	add_child(b_node)
	b_node.owner = get_tree().edited_scene_root
	
	var house_size = 7.0 # Casas apertadas umas nas outras
	var cols = int(size.x / house_size)
	var rows = int(size.y / house_size)
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for x in range(cols):
		for z in range(rows):
			# Casas geminadas formando o anel do quarteirão
			if x == 0 or x == cols - 1 or z == 0 or z == rows - 1:
				var h = rng.randf_range(6.0, 12.0)
				var px = (x * house_size) - (size.x/2.0) + (house_size/2.0)
				var pz = (z * house_size) - (size.y/2.0) + (house_size/2.0)
				
				var house = CSGBox3D.new()
				house.name = "Casa_Generica"
				house.size = Vector3(house_size * 0.95, h, house_size * 0.95)
				house.position = Vector3(px, h/2.0, pz)
				house.material = house_mat
				b_node.add_child(house)
				house.owner = get_tree().edited_scene_root
