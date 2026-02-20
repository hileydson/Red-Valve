@tool
extends EditorScenePostImport

func _post_import(scene):
	# Chamamos a função recursiva para varrer toda a cena importada
	iterate(scene)
	return scene # Retorna a cena modificada

func iterate(node):
	if node == null:
		return
	
	# Verifica se o nó atual é uma malha (MeshInstance3D)
	if node is MeshInstance3D:
		# Cria a colisão Trimesh (Complexa/Estática)
		# Se preferir a Convex (mais leve), use node.create_convex_collision()
		node.create_trimesh_collision()
		print("Colisão gerada para: ", node.name)
	
	# Continua a busca nos filhos deste nó
	for child in node.get_children():
		iterate(child)
