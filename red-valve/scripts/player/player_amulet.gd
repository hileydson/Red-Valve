extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func _process_amulet_magic(delta: float) -> void:
	if not GlobalEvents.is_maycow_normal or not SaveManager.prolog_finished or player.is_reloading or player.is_using_ultimate:
		_hide_amulet_magic()
		return

	if SaveManager.current_mp > 0:
		if not player.amulet_magic_active:
			player.amulet_magic_active = true
			if player.amulet_crosshair:
				player.amulet_crosshair.visible = true
			if player.amulet_counter_label:
				player.amulet_counter_label.visible = true
				player.amulet_counter_label.text = "0"
			player.hand_with_pistol.visible = false
			player.control_weapons.visible = false
			player.control_magic.visible = false

		# Transição de câmera do poder do amuleto: espera o zoom da 3ª pessoa
		# (feito pelo lerp de FOV normal em player.gd) avançar o bastante antes
		# de trocar para a câmera em 1ª pessoa - dá a sensação de "zoom pra dentro".
		if not player.is_first_person:
			if is_instance_valid(player.camera_third_person) and player.camera_third_person.fov <= 55.0:
				player.is_first_person = true
				if is_instance_valid(player.camera) and not player.camera.current:
					player.camera.fov = 75.0
					player.camera.make_current()
					if player.camera_third_person:
						player.camera_third_person.current = false

				if player.hand_with_magic: player.hand_with_magic.visible = true

				_ensure_amuleto_visual()
				if player.amuleto_node:
					player.amuleto_node.visible = true
					if player.amuleto_particles:
						player.amuleto_particles.emitting = true

		if is_instance_valid(player.amuleto_node):
			player.amuleto_node.rotate_y(delta * 8.0) # Amuleto girando rapidamente

		_process_amulet_targeting()
	else:
		if player.amulet_magic_active:
			_hide_amulet_magic()

func _ensure_amuleto_visual() -> void:
	if is_instance_valid(player.amuleto_node): return
	if not player.camera: return

	var amuleto_scene = load("res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb")
	if not amuleto_scene: return

	var amuleto = amuleto_scene.instantiate()
	# Preso na câmera (não na mão) para garantir posição e escala previsíveis na tela
	player.camera.add_child(amuleto)
	amuleto.scale = Vector3(0.24, 0.24, 0.24)
	amuleto.visible = true

	# Posição e giro vêm do Marker3D "amuleto_position" (filho da câmera),
	# ajustável direto na cena sem precisar mexer no código.
	var amuleto_marker = player.camera.get_node_or_null("amuleto_position")
	if amuleto_marker:
		amuleto.position = amuleto_marker.position
		amuleto.rotation = amuleto_marker.rotation
	else:
		amuleto.position = Vector3(0.05, -0.22, -0.55)
		amuleto.rotation.z = deg_to_rad(90)

	# Sem material override: mantém a cor/textura originais do modelo.
	for mesh in amuleto.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = true

	# Desliga colisão de qualquer corpo físico vindo do .glb: o amuleto fica
	# bem na frente da câmera e não pode bloquear o raycast de mira/seleção de inimigos.
	for col in amuleto.find_children("*", "CollisionObject3D", true, false):
		col.collision_layer = 0
		col.collision_mask = 0

	var particles = CPUParticles3D.new()
	particles.amount = 120
	particles.lifetime = 1.0
	particles.local_coords = false # Partículas se espalham no ar independente do giro do amuleto
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3(0, 0.5, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 2.0

	# Variação de tons: roxos, brancos e vermelhos
	var initial_grad = Gradient.new()
	initial_grad.offsets = [0.0, 0.25, 0.5, 0.75, 1.0]
	initial_grad.colors = [
		Color(0.5, 0.0, 1.0, 1.0), # Roxo puro brilhante
		Color(1.0, 1.0, 1.0, 1.0), # Branco mágico
		Color(0.8, 0.2, 1.0, 1.0), # Lilás/Rosa
		Color(1.0, 0.0, 0.0, 1.0), # Vermelho sangue
		Color(0.3, 0.0, 0.6, 1.0)  # Roxo escuro
	]
	particles.color_initial_ramp = initial_grad

	# Fade in e fade out no ciclo de vida
	var alpha_grad = Gradient.new()
	alpha_grad.offsets = [0.0, 0.2, 0.8, 1.0]
	alpha_grad.colors = [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	particles.color_ramp = alpha_grad

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve

	var pmat = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.vertex_color_use_as_albedo = true # OBRIGATÓRIO para a cor do Gradient funcionar!
	var pmesh = SphereMesh.new()
	pmesh.radius = 0.04
	pmesh.height = 0.08
	pmesh.material = pmat
	particles.mesh = pmesh

	amuleto.add_child(particles)

	player.amuleto_node = amuleto
	player.amuleto_particles = particles

func _hide_amulet_magic() -> void:
	player.amulet_magic_active = false
	if player.amulet_crosshair:
		player.amulet_crosshair.visible = false
	if player.amulet_counter_label:
		player.amulet_counter_label.visible = false
	
	if GlobalEvents.is_maycow_normal:
		# Volta da 1ª pessoa (amuleto) pra 3ª pessoa com zoom-out gradual:
		# começa o FOV da 3ª pessoa já "fechado" e deixa o lerp normal abrir até 75.
		if player.is_first_person:
			player.is_first_person = false
			if is_instance_valid(player.camera_third_person):
				player.camera_third_person.fov = 40.0
				player.camera_third_person.make_current()
			if player.hand_with_magic:
				player.hand_with_magic.visible = false
			player.control_weapons.visible = false
			player.control_magic.visible = false
	elif player.is_first_person and not player.is_reloading:
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
	if not GlobalEvents.is_maycow_normal:
		_clear_amulet_hover()
		return

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
		if target:
			player.amulet_hovered_enemy = target
			if player.amulet_selected_enemies.has(target):
				_apply_silhouette(target, Color(1.0, 0.0, 0.0, 0.8)) # Já selecionado (vermelho forte)
			else:
				_apply_silhouette(target, Color(1.0, 1.0, 1.0, 0.5)) # Branco fraco (Hover)

	if Input.is_action_just_pressed("ui_shoot") and player.amulet_hovered_enemy:
		var enemy = player.amulet_hovered_enemy
		if player.amulet_selected_enemies.has(enemy):
			# Já estava selecionado: remove a seleção
			player.amulet_selected_enemies.erase(enemy)
			_apply_silhouette(enemy, Color(1.0, 1.0, 1.0, 0.5)) # Volta para hover fraco
		elif player.amulet_selected_enemies.size() < player.max_amulet_targets:
			player.amulet_selected_enemies.append(enemy)
			_apply_silhouette(enemy, Color(1.0, 0.0, 0.0, 0.8)) # Vermelho forte (Selecionado)

		if player.amulet_counter_label:
			player.amulet_counter_label.text = str(player.amulet_selected_enemies.size())

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
		
	var all_meshes = _get_all_meshes(enemy)
	var sil_mat = StandardMaterial3D.new()
	sil_mat.albedo_color = cor
	sil_mat.emission_enabled = true
	sil_mat.emission = cor
	sil_mat.emission_energy_multiplier = 2.0
	sil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	for m in all_meshes:
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
	if player.amulet_selected_enemies.size() == 0:
		return

	# Guardamos os inimigos para transferir
	GlobalEvents.amulet_captured_enemies.clear()
	for e in player.amulet_selected_enemies:
		if is_instance_valid(e):
			_remove_silhouette(e)
			GlobalEvents.amulet_captured_enemies.append(e)

	player.amulet_selected_enemies.clear()
	_clear_amulet_hover()

	# Limpa os estados do Player para quando voltar da Arena
	player.is_aiming = false
	player.is_first_person = false
	if is_instance_valid(player.camera_third_person):
		player.camera_third_person.make_current()
		player.camera_third_person.fov = 75.0
	if is_instance_valid(player.hand_with_magic):
		player.hand_with_magic.visible = false
	if is_instance_valid(player.amulet_crosshair): player.amulet_crosshair.visible = false
	if player.point: player.point.visible = false
	if is_instance_valid(player.amulet_counter_label): player.amulet_counter_label.visible = false

	# Desativa o Motion Blur ao sair
	if is_instance_valid(player.hud_layer):
		var motion_blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
		if motion_blur:
			motion_blur.material.set_shader_parameter("blur_strength", 0.0)
			motion_blur.visible = false

	_hide_amulet_magic()

	GlobalEvents.previous_is_maycow_normal = GlobalEvents.is_maycow_normal

	player.is_teleporting_enemies = true

	SaveManager.current_mp = SaveManager.max_mp

	var tree = get_tree()
	var root = tree.root
	var current = tree.current_scene

	# ---- TRANSIÇÃO CINEMÁTICA DIMENSIONAL ----
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 0.2 # Slow motion global

	var cine_cam = Camera3D.new()
	var cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 1.0
	cam_attr.dof_blur_far_transition = 10.0 # Motion blur pesado artificial
	cine_cam.attributes = cam_attr
	cine_cam.fov = 95.0

	var center_pos = Vector3.ZERO
	for e in GlobalEvents.amulet_captured_enemies:
		center_pos += e.global_position
	center_pos /= GlobalEvents.amulet_captured_enemies.size()

	cine_cam.global_position = center_pos + Vector3(0, 1.5, 4.5)
	current.add_child(cine_cam)
	cine_cam.look_at(center_pos + Vector3(0, 1.0, 0), Vector3.UP)
	cine_cam.make_current()

	var tween = tree.create_tween().set_parallel(true).set_ignore_time_scale(true)
	var anim_time = 1.2
	for e in GlobalEvents.amulet_captured_enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED
			var target_y = e.global_position.y + 35.0
			tween.tween_property(e, "global_position:y", target_y, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tween.tween_property(e, "rotation:y", e.rotation.y + deg_to_rad(1080), anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tween.tween_property(e, "scale", Vector3(0.05, 5.0, 0.05), anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	tween.tween_property(cine_cam, "global_position:y", cine_cam.global_position.y + 35.0, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(cine_cam, "fov", 130.0, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	await tween.finished

	for e in GlobalEvents.amulet_captured_enemies:
		if is_instance_valid(e):
			e.scale = Vector3.ONE
			e.rotation.x = 0
			e.rotation.z = 0

	if is_instance_valid(cine_cam):
		cine_cam.queue_free()

	player.process_mode = Node.PROCESS_MODE_INHERIT
	Engine.time_scale = 1.0 # Retorna ao normal
	AudioServer.playback_speed_scale = 1.0 # Garante que o áudio não fique em câmera lenta

	player.is_teleporting_enemies = false

	# Instancia o campo de batalha antes de removermos a nós mesmos da árvore
	var battlefield_scene = load("res://scenes/stages/battlefield/battlefield_1.tscn").instantiate()

	# Pausa a cena atual tirando ela da árvore
	root.remove_child(current)
	GlobalEvents.paused_scene_for_amulet = current

	root.add_child(battlefield_scene)
	tree.current_scene = battlefield_scene

func play_return_from_arena_effect() -> void:
	player.is_playing_return_effect = true
	GlobalUtils.vibrate_controller(null, 0.8, 0.8, 1.0)
	GlobalUtils.shake_camera(0.6, 1.0)

	# Câmera lenta momentânea ao voltar da arena
	Engine.time_scale = 0.3
	var time_tween = create_tween().set_ignore_time_scale(true)
	time_tween.tween_interval(0.5)
	time_tween.tween_callback(func(): Engine.time_scale = 1.0)

	# Flash branco de transição
	var flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 1.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if player.hud_layer: player.hud_layer.add_child(flash)

	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 1.5)
	tw.tween_callback(flash.queue_free)

	# Motion blur momentâneo
	if is_instance_valid(player.hud_layer):
		player.hud_layer.visible = true
		var motion_blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
		if motion_blur:
			motion_blur.visible = true
			motion_blur.material.set_shader_parameter("blur_strength", 1.8)
			var blur_tween = create_tween()
			blur_tween.tween_property(motion_blur.material, "shader_parameter/blur_strength", 0.0, 2.5).set_trans(Tween.TRANS_SINE)
			blur_tween.finished.connect(func():
				motion_blur.visible = false
				player.is_playing_return_effect = false
			)
		else:
			player.is_playing_return_effect = false
	else:
		player.is_playing_return_effect = false

	_play_iron_rusks_tally()

	SaveManager.save_game()

func _play_iron_rusks_tally() -> void:
	var earned = SaveManager.iron_rusks_pending
	if earned <= 0: return
	if not is_instance_valid(player.iron_rusks_value_label): return

	var target_layer = player.iron_rusks_value_label.get_parent()
	if not target_layer: return

	var tally_label = Label.new()
	tally_label.add_theme_font_size_override("font_size", 80)
	tally_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	tally_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	tally_label.add_theme_constant_override("outline_size", 10)
	tally_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally_label.pivot_offset = Vector2(60, 40)
	tally_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally_label.text = "+0"
	target_layer.add_child(tally_label)

	var count_tween = create_tween().set_ignore_time_scale(true)
	count_tween.tween_method(func(v): tally_label.text = "+" + str(int(v)), 0.0, float(earned), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await count_tween.finished

	# Voa até o contador do canto e soma
	var start_pos = tally_label.global_position
	var end_pos = player.iron_rusks_value_label.global_position + Vector2(20, 15)

	var fly_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	fly_tween.tween_property(tally_label, "global_position", end_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(tally_label, "scale", Vector2(0.3, 0.3), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(tally_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await fly_tween.finished

	tally_label.queue_free()

	SaveManager.iron_rusks_display += earned
	SaveManager.iron_rusks_pending -= earned

	# Efeito de "pop" no número do canto ao receber a soma
	var pop_tween = create_tween().set_ignore_time_scale(true)
	pop_tween.tween_property(player.iron_rusks_value_label, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(player.iron_rusks_value_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
