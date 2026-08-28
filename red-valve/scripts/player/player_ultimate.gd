extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func _activate_cogblade_ultimate() -> void:
	player.is_using_ultimate = true
	player.cogblade_power_value = 0.0
	player.cogblade_pulsing = false
	if player.cogblade_hud: player.cogblade_hud.value = 0
	if player.cogblade_pulse_tween: player.cogblade_pulse_tween.kill()
	if player.cogblade_hud: player.cogblade_hud.tint_progress = Color(1, 1, 1, 1)
	if player.cogblade_particles: player.cogblade_particles.emitting = false
	
	player.magic_hand_attack()

	# Parar jogador e deixar invulnerável durante a animação
	
	var _old_pos = player.hand_magic_3d.position
	var tween_prep = create_tween().set_parallel(true)
	
	# Aproxima muito a câmera e a arma para dar sensação de foco
	tween_prep.tween_property(player.camera, "fov", 40.0, 1.5).set_trans(Tween.TRANS_SINE)
	tween_prep.tween_property(player.hand_magic_3d, "position", player.hand_magic_3d_pos_original + Vector3(0.0, 0.2, 0.4), 1.5).set_trans(Tween.TRANS_SINE)
	
	# Tela escurece gradualmente e slow motion no mundo
	GlobalUtils.ativar_camera_lenta(0.1, 99.0, false) # O tempo pára quase totalmente
	
	if player.hud_layer: player.hud_layer.visible = false
	player.hand_with_pistol.visible = false
	
	# Pisca a cogblade de forma intensa
	var flash_tween = create_tween().set_loops(5)
	var mesh_node = player.crescent_cogblade.get_node_or_null("Area3D/mesh")
	if not mesh_node:
		mesh_node = player.crescent_cogblade.get_node_or_null("mesh") # Fallback
	if mesh_node:
		var mat = mesh_node.get_surface_override_material(0)
		if mat and mat is StandardMaterial3D:
			flash_tween.tween_property(mat, "emission_energy_multiplier", 10.0, 0.1)
			flash_tween.tween_property(mat, "emission_energy_multiplier", 1.0, 0.1)
	
	await get_tree().create_timer(1.0).timeout
	
	player.slay_it.play()
	player.blade_out.play()
	
	if player.hand_magic_tree:
		var pb = player.hand_magic_tree["parameters/playback"]
		if pb: pb.travel("attack")
		
	# Jogar cogblade pro alto
	player.crescent_cogblade.show()
	player.crescent_cogblade.top_level = true
	var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas") 
	if faiscas: faiscas.emitting = true
	
	player.crescent_cogblade.global_rotation_degrees = Vector3(player.cogblade_tilt_x, player.camera.global_rotation_degrees.y + player.cogblade_tilt_y, player.cogblade_tilt_z)
	
	var tween_magic = create_tween()
	var pos_final_global = player.crescent_cogblade.global_transform.origin + Vector3(0, 15.0, 0) # Joga alto no céu
	
	tween_magic.tween_property(player.crescent_cogblade, "global_transform:origin", pos_final_global, 0.8)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)
		
	# Fazer a câmera olhar para a cogblade no ar
	var _tween_cam = create_tween()
	# Precisamos calcular a rotação necessária pra olhar pra cima
	var _target_look = player.crescent_cogblade.global_transform.origin
	# Não podemos usar look_at direto na câmera durante o processo de física de forma limpa, vamos interpolar a rotação
	
	await tween_magic.finished
	
	# Ponto de parada no ar
	await get_tree().create_timer(0.4).timeout
	
	# Cair como um meteoro
	var ground_pos = player.global_transform.origin + (-player.camera.global_transform.basis.z * 6.0) # Cai um pouco a frente do player
	ground_pos.y = player.global_transform.origin.y # Chão
	
	var tween_fall = create_tween()
	tween_fall.tween_property(player.crescent_cogblade, "global_transform:origin", ground_pos, 0.2)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)
		
	await tween_fall.finished
	
	# IMPACTO!
	GlobalUtils.shake_camera(0.5, 1.0)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 1.0) # Tremor forte no controle
	GlobalUtils.remover_camera_lenta()
	
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 1)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if player.hud_layer: player.hud_layer.add_child(flash)
	
	var f_tween = create_tween()
	f_tween.tween_property(flash, "color:a", 0.0, 0.5)
	f_tween.tween_callback(flash.queue_free)
	
	# Criar esfera de energia / explosão visual
	_spawn_explosion_vfx(ground_pos)
	
	# Dano em área
	var hit_count = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.global_transform.origin.distance_to(ground_pos) < 12.0: # Raio de 12 metros
			if enemy.has_method("take_damage"):
				enemy.take_damage(player.damage_crescent_cogblade * 5.0) # 5x mais dano
				player.spawn_blood_effect(enemy)
				hit_count += 1
				
	# Recuperar vida baseado nos inimigos atingidos (vampirismo)
	if hit_count > 0:
		player.current_health = clamp(player.current_health + (hit_count * 15.0), 0.0, player.max_health)
	
	# Aplicar dano continuo e lentidão
	_apply_aoe_damage_slowly(ground_pos)
	
	# Retornar tudo ao normal
	var tween_restore = create_tween().set_parallel(true)
	tween_restore.tween_property(player.camera, "fov", 75.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(1.0).timeout
	
	player.is_blade_returning = true
	
	if player.hud_layer: player.hud_layer.visible = true
	if SaveManager.is_equipped("pistol"): player.hand_with_pistol.visible = true
	
	player.is_using_ultimate = false
	
func _apply_aoe_damage_slowly(pos: Vector3):
	var inimigos = player.get_tree().get_nodes_in_group("enemies")
	var afetados = []
	for inimigo in inimigos:
		if is_instance_valid(inimigo) and inimigo.has_method("take_damage"):
			if inimigo.global_position.distance_to(pos) <= 15.0:
				afetados.append(inimigo)
				
	# Aplica o dano em sequência para dar peso
	for alvo in afetados:
		if is_instance_valid(alvo) and alvo.has_method("take_damage"):
			# Atraso bem curtinho entre os hits
			await player.get_tree().create_timer(0.05).timeout
			if is_instance_valid(alvo):
				alvo.take_damage(player.damage_crescent_cogblade)
				if player.has_method("spawn_blood_effect"):
					player.spawn_blood_effect(alvo)

func _spawn_explosion_vfx(pos: Vector3):
	# Criar uma malha esférica que cresce e some
	var sphere = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	sphere.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material_override = mat
	
	get_tree().root.add_child(sphere)
	sphere.global_position = pos
	sphere.scale = Vector3(0.1, 0.1, 0.1)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sphere, "scale", Vector3(24.0, 24.0, 24.0), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 1.0)
	
	tween.chain().tween_callback(sphere.queue_free)
