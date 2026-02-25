extends Node3D

@onready var terrain: Terrain3D = $"../NavigationRegion3D/Terrain3D"
@export var quantidade: int = 50
@export var raio_espalhamento: float = 800.0
@export var semente: int = 12345 # Use qualquer número para travar as posições
@onready var arvores_inicio_mesh: MultiMeshInstance3D = $arvores_inicio

func _ready():
	# 1. Trava a aleatoriedade para ser sempre igual
	seed(semente)
	
	await get_tree().process_frame
	
	if not arvores_inicio_mesh or not arvores_inicio_mesh.multimesh:
		return

	var mm = arvores_inicio_mesh.multimesh
	mm.instance_count = quantidade
	
	# Criamos uma caixa (AABB) gigante para o Godot nunca "esconder" as árvores
	var area_total = AABB(Vector3(-raio_espalhamento, -100, -raio_espalhamento), 
						  Vector3(raio_espalhamento * 2, 500, raio_espalhamento * 2))
	arvores_inicio_mesh.custom_aabb = area_total

	for i in range(quantidade):
		var x = randf_range(-raio_espalhamento, raio_espalhamento)
		var z = randf_range(-raio_espalhamento, raio_espalhamento)
		
		var y = 0.0
		if terrain and terrain.data:
			y = terrain.data.get_height(Vector3(x, 0, z))
			if is_nan(y): y = 0.0
		
		var pos = Vector3(x, y, z)
		var basis = Basis().rotated(Vector3.UP, randf_range(0, TAU))
		var escala_aleatoria = randf_range(0.7, 1.3)
		basis = basis.scaled(Vector3.ONE * escala_aleatoria)
		
		var t = Transform3D(basis, pos)
		mm.set_instance_transform(i, t)
