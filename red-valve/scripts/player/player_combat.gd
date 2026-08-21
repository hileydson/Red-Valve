extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func process_combat(delta: float) -> void:
	# GIRO DA COGBLADE
	if is_instance_valid(player.crescent_cogblade) and player.crescent_cogblade.top_level:
		player.crescent_cogblade.global_rotate(Vector3.UP, -15.0 * delta)

	# LÓGICA DO BUMERANGUE (COGBLADE RETORNANDO)
	if player.is_blade_returning and is_instance_valid(player.crescent_cogblade):
		var target_pos = player.camera.global_transform.origin + player.camera.global_transform.basis * player.magic_blade_pos_original
		player.crescent_cogblade.global_transform.origin = player.crescent_cogblade.global_transform.origin.move_toward(target_pos, delta * player.blade_return_speed)
		
		if player.crescent_cogblade.global_transform.origin.distance_to(target_pos) < 0.8:
			player.is_blade_returning = false
			player.crescent_cogblade.top_level = false
			player.crescent_cogblade.position = player.magic_blade_pos_original
			player.crescent_cogblade.rotation = Vector3.ZERO
			player.crescent_cogblade.hide()
			
			var bb = player.crescent_cogblade.get_node_or_null("blade_back")
			if bb: bb.play()
			
			var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas")
			if faiscas: faiscas.emitting = false
			
			player.is_magic_attacking = false
			if player.hand_magic_tree:
				var pb = player.hand_magic_tree["parameters/playback"]
				if pb: pb.travel("idle")
				
			var tween_hand = create_tween()
			tween_hand.tween_interval(0.2)
			tween_hand.tween_property(player.hand_magic_3d, "position", player.hand_magic_3d_pos_hidden, 1.5).set_trans(Tween.TRANS_SINE)

func reload() -> void:
	if player.is_first_person and not player.is_reloading and not player.is_magic_attacking:
		var total = SaveManager.get_item_amount("pistol_ammo")
		if total <= 0 or player.clip_pistol_ammo >= player.max_clip_pistol:
			return
			
		player.is_reloading = true
		
		var needed = player.max_clip_pistol - player.clip_pistol_ammo
		var taken = mini(needed, total)
		SaveManager.remove_item_amount("pistol_ammo", taken)
		player.clip_pistol_ammo += taken
		player.update_ammo_ui()
		
		if not is_instance_valid(player.current_weapon): 
			player.is_reloading = false
			return

		player.gun_load.play()
		
		if is_instance_valid(player.hand_magic_3d): 
			player.hand_magic_3d.position = player.hand_magic_3d_pos_original
			player.hand_magic_3d.visible = true
			
		if player.hand_magic_tree:
			var pb = player.hand_magic_tree["parameters/playback"]
			if pb: pb.travel("magic_reload")
		
		if player.hand_animations:
			player.hand_animations.play("reload")
			await player.hand_animations.animation_finished
		else:
			await get_tree().create_timer(1.0).timeout
			
		await get_tree().create_timer(0.2).timeout
			
		if is_instance_valid(player.hand_magic_3d): 
			var tween_retorno = create_tween()
			tween_retorno.tween_property(player.hand_magic_3d, "position", player.hand_magic_3d_pos_hidden, 0.6).set_trans(Tween.TRANS_SINE)
			
		player.is_reloading = false

func magic_hand_attack() -> void:
	SaveManager.current_mp -= 10.0
	if SaveManager.current_mp < 0: SaveManager.current_mp = 0
	if player.is_reloading: return
	
	player.is_magic_attacking = true
	player.slay_it.play()
	player.blade_out.play()
	
	if player.hand_magic_tree:
		var pb = player.hand_magic_tree["parameters/playback"]
		if pb: pb.travel("attack")
		
	var tween_magic = create_tween().set_parallel(true)
	
	var pos_alvo = player.hand_magic_3d_pos_original + Vector3(0, 0, 0.1)
	player.hand_magic_3d.visible = true
	tween_magic.tween_property(player.hand_magic_3d, "position", pos_alvo, 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	player.crescent_cogblade.show()
	player.crescent_cogblade.top_level = true
	
	var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas") 
	if faiscas: faiscas.emitting = true
	
	player.crescent_cogblade.global_rotation_degrees = Vector3(player.cogblade_tilt_x, player.camera.global_rotation_degrees.y + player.cogblade_tilt_y, player.cogblade_tilt_z)
	
	var dir = -player.camera.global_transform.basis.z
	var pos_final_global = player.crescent_cogblade.global_transform.origin + (dir * 11.0)
	
	tween_magic.tween_property(player.crescent_cogblade, "global_transform:origin", pos_final_global, 1.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	await tween_magic.finished
	
	player.is_blade_returning = true
	
	var tween_hand = create_tween()
	var pos_recuo = player.hand_magic_3d_pos_original + Vector3(0.0, -0.4, 0.6)
	tween_hand.tween_property(player.hand_magic_3d, "position", pos_recuo, 0.5)\
		.set_trans(Tween.TRANS_QUAD)

func cast_spell() -> void:
	player.magic_hand_particles.emitting = true
	player.blade_light.visible = true
	
	var tween = create_tween()
	player.magic_hand_particles.amount = 50
	
	tween.tween_property(player.magic_hand_particles.process_material, "scale_min", 2.0, 0.5)
	await get_tree().create_timer(3.0).timeout
	player.magic_hand_particles.emitting = false
	player.blade_light.visible = false

func shoot(input: Variant) -> void:
	if not SaveManager.is_equipped("pistol"): return
	if player.is_reloading: return
	
	if player.can_shoot_again and player.camera.current:
		if player.clip_pistol_ammo <= 0:
			return
			
		player.clip_pistol_ammo -= 1
		player.update_ammo_ui()
		
		if not is_instance_valid(player.current_weapon): return

		player.current_weapon = player.hand_with_pistol
		var rotation_default = player.current_weapon.rotation

		var tween = create_tween()
		player.fire.play("shoot")
		GlobalUtils.shake_camera(0.03, 0.05)
		GlobalUtils.vibrate_controller(input, 0.5, 0.0, 0.1)
		player.faisca.restart()
		player.faisca.emitting = true
		player.gun_shot.play()
		player.can_shoot_again = false
		
		if player.capsula_scene:
			var capsula = player.capsula_scene.instantiate()
			get_tree().current_scene.add_child(capsula)
			capsula.add_collision_exception_with(player)
			var spawn_pos = player.camera.global_position + player.camera.global_transform.basis * Vector3(0.4, -0.1, -0.75)
			capsula.global_position = spawn_pos
			capsula.global_rotation = player.camera.global_rotation
			
			var eject_dir = player.camera.global_transform.basis * Vector3(1.0, 1.0, 0.0) 
			capsula.apply_central_impulse(eject_dir * randf_range(1.5, 2.0))
			capsula.apply_torque(Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))
		
		var flash_tween = create_tween()
		player.flash_tela.color.a = 0.1 
		flash_tween.tween_property(player.flash_tela, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		
		tween.parallel().tween_property(player.current_weapon, "position:x", player.current_weapon.position.x + 0.01, 0.05).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(player.current_weapon, "position:y", player.current_weapon.position.y - 0.01, 0.05).set_trans(Tween.TRANS_SINE)

		tween.tween_interval(0.1)

		player.current_weapon.rotation = rotation_default
		tween.parallel().tween_property(player.current_weapon, "position:x", player.current_weapon.position.x, 0.1).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(player.current_weapon, "position:y", player.current_weapon.position.y, 0.1).set_trans(Tween.TRANS_BACK)
		
		raycast_process_shoot()		
				
		await get_tree().create_timer(0.56).timeout
		player.can_shoot_again = true

func raycast_process_shoot() -> void:
	if player.ray_cast_3d.is_colliding():
		var target = player.ray_cast_3d.get_collider()
		
		if target and target.has_method("take_damage"):
			target.take_damage(player.damage_pistol)
			
			if target.is_in_group("enemies"):
				spawn_blood_raycast(player.ray_cast_3d.get_collision_point(), player.ray_cast_3d.get_collision_normal())
				add_cogblade_power(10.0)
		
			var ponto_colisao = player.ray_cast_3d.get_collision_point()
			var distancia = player.ray_cast_3d.global_position.distance_to(ponto_colisao)
			
			if target.name == "heart" and distancia > 7:
				player.bullet.visible = true
				target.take_damage(player.damage_pistol+player.damage_headshoot)
					
				var offset_altura = Vector3(0.25, -0.3, 0) 
				var alvo_ajustado = target.global_position + offset_altura

				var tween_bullet = create_tween()
				var voltas = deg_to_rad(1800) 
				tween_bullet.tween_property(player.bullet, "rotation:z", player.bullet.rotation.z + voltas, 2.5)\
					.set_trans(Tween.TRANS_LINEAR)
					
				player.control_weapons.visible = false
				player.hand_with_pistol.visible = false
				if player.hand_with_magic: player.hand_with_magic.visible = false
				player.control_magic.visible = false
				player.bullet_light.visible = true
				player.bullet.visible = true
				player.camera_bullet_time_ON = true
				GlobalUtils.ativar_camera_lenta(0.1, 60.0, true)
				
				var tween_cam = create_tween()
				
				player.camera_3d_bullet_time.global_position = player.camera.global_position
				player.camera_3d_bullet_time.make_current()
				
				tween_cam.tween_property(player.camera_3d_bullet_time, "global_position", alvo_ajustado + (player.ray_cast_3d.global_transform.basis.z * 2.0), 0.9)\
					.set_trans(Tween.TRANS_QUINT)\
					.set_ease(Tween.EASE_OUT)

				tween_cam.parallel().tween_method(
				func(pos): player.camera_3d_bullet_time.look_at(alvo_ajustado),
					0.0, 1.0, 0.9
				)

				tween_cam.tween_interval(0.05)

				tween_cam.tween_property(player.camera_3d_bullet_time, "global_position", player.camera.global_position, 0.4)\
					.set_trans(Tween.TRANS_SINE)
				
				await get_tree().create_timer(0.65).timeout
				if player.camera_bullet_time_ON: bullet_time_back()

func bullet_time_back() -> void:	
	player.camera_bullet_time_ON = false
	player.bullet.visible = false
	GlobalUtils.remover_camera_lenta()
	
	if player.is_first_person:
		player.camera.make_current()
		player.control_weapons.visible = true
		player.hand_with_pistol.visible = SaveManager.is_equipped("pistol")
		if player.hand_with_magic: player.hand_with_magic.visible = true
		player.control_magic.visible = true
	else:
		player.camera_third_person.make_current()
	
	await get_tree().create_timer(0.16).timeout
	player.bullet_light.visible = false

func spawn_blood_raycast(pos: Vector3, normal: Vector3) -> void:
	var blood = player.blood_effect.instantiate()
	get_tree().root.add_child(blood)
	blood.global_position = pos
	
	if normal != Vector3.ZERO:
		blood.look_at(pos + normal, Vector3.UP)
		
func spawn_blood_effect(body: Node3D) -> void:
	var blood = player.blood_effect.instantiate()
	get_tree().root.add_child(blood)
	blood.global_position = body.global_position
	blood.global_position.y += 2
		
func add_cogblade_power(amount: float) -> void:
	if GlobalEvents.is_maycow_normal or not player.cogblade_hud or player.is_using_ultimate: return
	player.cogblade_power_value = clamp(player.cogblade_power_value + amount, 0.0, 100.0)
	if player.cogblade_hud: player.cogblade_hud.value = player.cogblade_power_value
	
	if player.cogblade_power_value >= 100.0 and not player.cogblade_pulsing:
		player.cogblade_pulsing = true
		_start_cogblade_pulse()

func _start_cogblade_pulse() -> void:
	if not player.cogblade_hud: return
	
	if player.cogblade_pulse_tween: player.cogblade_pulse_tween.kill()
	player.cogblade_pulse_tween = create_tween().set_loops()
	
	player.cogblade_pulse_tween.tween_property(player.cogblade_hud, "tint_progress", Color(1.0, 0.2, 0.2, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	player.cogblade_pulse_tween.tween_property(player.cogblade_hud, "tint_progress", Color(1.0, 1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	if not player.cogblade_particles:
		player.cogblade_particles = CPUParticles2D.new()
		player.cogblade_particles.emitting = true
		player.cogblade_particles.amount = 50
		player.cogblade_particles.lifetime = 1.0
		player.cogblade_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		
		var w = player.cogblade_hud.texture_progress.get_width()
		var h = player.cogblade_hud.texture_progress.get_height()
		player.cogblade_particles.emission_rect_extents = Vector2(w / 2.0, h / 2.0)
		
		player.cogblade_particles.gravity = Vector2(0, 300)
		player.cogblade_particles.color = Color(0.8, 0.0, 0.0, 0.8)
		player.cogblade_particles.scale_amount_min = 3.0
		player.cogblade_particles.scale_amount_max = 6.0
		
		player.cogblade_hud.add_child(player.cogblade_particles)
		player.cogblade_particles.position = Vector2(w / 2.0, h / 2.0)
	else:
		player.cogblade_particles.emitting = true

func update_equipment_visuals() -> void:
	if player.is_first_person and not player.is_reloading and player.control_weapons.visible:
		player.hand_with_pistol.visible = SaveManager.is_equipped("pistol")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if player.is_magic_attacking:
		player.blade_in.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true)
		if body.has_method("take_damage"): body.take_damage(player.damage_crescent_cogblade)
	
func _on_area_3d_body_exited(body: Node3D) -> void:
	if player.is_magic_attacking:
		player.blade_back.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true)
		if body.has_method("take_damage"): body.take_damage(player.damage_crescent_cogblade)

func _on_bullet_touch_body_entered(body: Node3D) -> void:
	player.bullet.visible = false
	spawn_blood_effect(body)
