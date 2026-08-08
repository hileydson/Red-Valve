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
		node.create_trimesh_collision()
		
		# Pega o corpo gerado (o último filho adicionado)
		if node.get_child_count() > 0:
			var static_body = node.get_child(node.get_child_count() - 1)
			if static_body is StaticBody3D:
				# O Player do jogo Red Valve colide com a máscara 2, então o cenário precisa estar no layer 2
				static_body.collision_layer = 3 # (Layers 1 e 2)
				static_body.collision_mask = 3
				
				# Se o modelo for oco (como uma casa vista por dentro), as normais podem estar invertidas para quem está dentro.
				# Ativar "backface_collision" faz o chão e as paredes colidirem por ambos os lados (frente e verso).
				for shape_child in static_body.get_children():
					if shape_child is CollisionShape3D and shape_child.shape is ConcavePolygonShape3D:
						shape_child.shape.backface_collision = true
		
		print("Colisão dupla-face e Layers configurados para: ", node.name)
	
	# Continua a busca nos filhos deste nó
	for child in node.get_children(true):
		iterate(child)
