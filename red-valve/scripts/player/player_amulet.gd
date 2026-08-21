extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func _process_amulet_magic(delta: float) -> void:
	if not player.is_first_person or player.is_reloading or player.is_using_ultimate:
		_hide_amulet_magic()
		return
		
	if Input.is_action_pressed("ui_magic") and SaveManager.is_equipped("amulet") and SaveManager.current_mp > 0:
		if not player.amulet_magic_active:
			player.amulet_magic_active = true
			if player.amulet_crosshair:
				player.amulet_crosshair.visible = true
			if player.amulet_counter_label:
				player.amulet_counter_label.visible = true
				player.amulet_counter_label.text = "0 / 3"
			player.hand_with_pistol.visible = false
			if player.hand_with_magic:
				player.hand_with_magic.visible = false
			
			if player.amuleto_node:
				player.amuleto_node.visible = true
				if player.amuleto_anim:
					player.amuleto_anim.play("idle")
				if player.amuleto_particles:
					player.amuleto_particles.emitting = true
			
			player.control_weapons.visible = false
			player.control_magic.visible = false
			
		_process_amulet_targeting()
	else:
		if player.amulet_magic_active:
			if Input.is_action_just_released("ui_magic") and player.amulet_selected_enemies.size() > 0:
				_on_amulet_magic_released()
			else:
				_hide_amulet_magic()

func _hide_amulet_magic() -> void:
	player.amulet_magic_active = false
	if player.amulet_crosshair:
		player.amulet_crosshair.visible = false
	if player.amulet_counter_label:
		player.amulet_counter_label.visible = false
	
	if player.is_first_person and not player.is_reloading:
		if SaveManager.is_equipped("pistol"):
			player.hand_with_pistol.visible = true
		if player.hand_with_magic:
			player.hand_with_magic.visible = true
		player.control_weapons.visible = true
		player.control_magic.visible = true
		
	if player.amuleto_node:
		player.amuleto_node.visible = false
		if player.amuleto_particles:
			player.amuleto_particles.emitting = false
			
	_clear_amulet_hover()
	
	for enemy in player.amulet_selected_enemies:
		if is_instance_valid(enemy):
			_remove_silhouette(enemy)
	player.amulet_selected_enemies.clear()

func _process_amulet_targeting() -> void:
	var space_state = player.get_world_3d().direct_space_state
	var center = player.get_viewport().size / 2
	var from = player.camera.project_ray_origin(center)
	var to = from + player.camera.project_ray_normal(center) * 30.0 
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	var target = null
	if result and result.collider:
		if result.collider.is_in_group("enemies") or (result.collider.get_parent() and result.collider.get_parent().is_in_group("enemies")):
			target = result.collider
			if not target.is_in_group("enemies"):
				target = target.get_parent()
				
	if target != player.amulet_hovered_enemy:
		_clear_amulet_hover()
		if target and not player.amulet_selected_enemies.has(target):
			player.amulet_hovered_enemy = target
			_apply_silhouette(target, Color(1.0, 1.0, 1.0, 0.5)) # Branco fraco (Hover)
	
	if Input.is_action_just_pressed("ui_shoot") and player.amulet_hovered_enemy:
		if player.amulet_selected_enemies.size() < player.max_amulet_targets:
			var enemy = player.amulet_hovered_enemy
			player.amulet_selected_enemies.append(enemy)
			player.amulet_hovered_enemy = null
			_apply_silhouette(enemy, Color(1.0, 0.0, 0.0, 0.8)) # Vermelho forte (Selecionado)
			
			if player.amulet_counter_label:
				player.amulet_counter_label.text = str(player.amulet_selected_enemies.size()) + " / 3"
				
			if player.amuleto_anim:
				player.amuleto_anim.play("cast")
				player.amuleto_anim.queue("idle")

func _clear_amulet_hover() -> void:
	if player.amulet_hovered_enemy and is_instance_valid(player.amulet_hovered_enemy):
		if not player.amulet_selected_enemies.has(player.amulet_hovered_enemy):
			_remove_silhouette(player.amulet_hovered_enemy)
	player.amulet_hovered_enemy = null

func _apply_silhouette(enemy: Node, cor: Color) -> void:
	if not enemy.has_meta("original_materials"):
		var meshes = _get_all_meshes(enemy)
		var mat_dict = {}
		for m in meshes:
			mat_dict[m] = m.material_override
		enemy.set_meta("original_materials", mat_dict)
		
	var meshes = _get_all_meshes(enemy)
	var sil_mat = StandardMaterial3D.new()
	sil_mat.albedo_color = cor
	sil_mat.emission_enabled = true
	sil_mat.emission = cor
	sil_mat.emission_energy_multiplier = 2.0
	sil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	for m in meshes:
		m.material_override = sil_mat

func _remove_silhouette(enemy: Node) -> void:
	if enemy.has_meta("original_materials"):
		var mat_dict = enemy.get_meta("original_materials")
		for m in mat_dict.keys():
			if is_instance_valid(m):
				m.material_override = mat_dict[m]
		enemy.remove_meta("original_materials")

func _get_all_meshes(node: Node) -> Array:
	var result = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_meshes(child))
	return result

func _on_amulet_magic_released() -> void:
	player.is_using_ultimate = true # Trava outras ações
	_hide_amulet_magic()
	
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 2.0)
	
	# Efeito de Flash na tela inteiro Roxo/Branco
	var flash = ColorRect.new()
	flash.color = Color(0.8, 0.2, 1.0, 1.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if player.hud_layer: player.hud_layer.add_child(flash)
	
	# Aguardar flash tapar a tela
	var tw = create_tween()
	tw.tween_property(flash, "color:a", 1.0, 0.1)
	await get_tree().create_timer(0.2).timeout
	
	# Transportar Maycow e inimigos para a Arena
	# O ArenaManager deve ouvir esse evento globalmente ou podemos chamar ele se existir
	var arena = get_tree().get_first_node_in_group("magic_arena")
	if arena and arena.has_method("start_arena_event"):
		# Teleporta o player
		player.global_transform.origin = arena.get_player_spawn_point()
		
		# Teleporta e prepara os inimigos
		var valid_enemies = []
		for e in player.amulet_selected_enemies:
			if is_instance_valid(e): valid_enemies.append(e)
		
		arena.start_arena_event(player, valid_enemies)
	
	# Desvanecer o flash
	var tw2 = create_tween()
	tw2.tween_property(flash, "color:a", 0.0, 1.0)
	tw2.tween_callback(flash.queue_free)
	
	player.amulet_selected_enemies.clear()
	player.is_using_ultimate = false

func play_return_from_arena_effect() -> void:
	var flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 1.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if player.hud_layer: player.hud_layer.add_child(flash)
	
	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 1.5)
	tw.tween_callback(flash.queue_free)
	
	GlobalUtils.vibrate_controller(null, 0.8, 0.8, 1.0)
