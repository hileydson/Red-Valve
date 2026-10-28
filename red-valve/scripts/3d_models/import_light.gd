@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	_process_node(scene)
	return scene

func _process_node(node: Node):
	# 1. Se for um MeshInstance, limpamos o peso gráfico
	if node is MeshInstance3D:
		# Desativa sombras (muito mais leve para paisagem)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Desativa iluminação global
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	
	# 2. Se o importador criou nós de colisão/física, nós os removemos
	if node is StaticBody3D or node is CollisionShape3D:
		node.free() # Deleta o nó de física completamente
		return # Para o processo neste nó já que ele foi deletado

	# 3. Remove AnimationPlayer (se existir e você não for usar)
	if node is AnimationPlayer:
		node.free()
		return

	# Continua para os filhos
	for child in node.get_children():
		if is_instance_valid(child):
			_process_node(child)
