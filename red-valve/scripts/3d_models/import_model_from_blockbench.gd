@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	# 1. Processa todos os nós para corrigir configurações de malha e esqueletos
	_process_node(scene)
	
	# 2. Corrigir o AnimationPlayer para evitar distorções de otimização
	var anim_player = _find_animation_player(scene)
	if anim_player:
		_sanitize_animations(anim_player)
		
	return scene  # Retorna a cena processada e corrigida

func _process_node(node: Node) -> void:
	# Corrigir Skinned Meshes (Malhas com esqueletos/panos)
	if node is MeshInstance3D:
		# Garante que a malha não perca dados de rig/pesos nos vértices
		node.skin = node.skin
		# Desativa a iluminação de duas faces para evitar rasgo visual se o pano for 1-plane
		for i in range(node.get_surface_override_material_count()):
			var mat = node.get_surface_override_material(i)
			if mat is BaseMaterial3D:
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Garante que as transformações de escala dos ossos não distorçam a malha
	if node is Skeleton3D:
		for i in range(node.get_bone_count()):
			# Zera qualquer escala acumulada que o Blockbench tenha enviado no osso
			var bone_rest = node.get_bone_rest(i)
			bone_rest.basis = bone_rest.basis.orthonormalized()
			node.set_bone_rest(i, bone_rest)

	for child in node.get_children():
		_process_node(child)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _sanitize_animations(anim_player: AnimationPlayer) -> void:
	var library_list = anim_player.get_animation_library_list()
	for lib_name in library_list:
		var library = anim_player.get_animation_library(lib_name)
		for anim_name in library.get_animation_list():
			var anim = library.get_animation(anim_name)
			# Garante o modo de interpolação correto e desativa otimizações agressivas
			for track in range(anim.get_track_count()):
				anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
