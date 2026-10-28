@tool
extends Node3D

func _ready() -> void:
	# Procura todas as malhas dentro da casa e ajusta o material automaticamente
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		var mat = mesh_node.get_active_material(0)
		if mat and mat is StandardMaterial3D:
			# Se o material estiver embutido, precisamos criar uma cópia local para modificar
			var new_mat = mat.duplicate()
			
			# Garante que o material receba luz e sombra
			new_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			
			# Desliga a emissão de luz (que cega a luz externa)
			new_mat.emission_enabled = false
			
			# Zera o aspecto de "espelho" para a luz difusa funcionar melhor
			new_mat.metallic = 0.0
			new_mat.roughness = 1.0
			
			# Aplica o material corrigido de volta na malha
			mesh_node.set_surface_override_material(0, new_mat)
