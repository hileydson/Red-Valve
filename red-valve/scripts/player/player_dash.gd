extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func dash() -> void:
	var _tween = create_tween()
	if player.trail_particles:
		player.trail_particles.emitting = true
		
	if !player.is_first_person:
		player.smoke_effect.process_mode = Node.PROCESS_MODE_ALWAYS
		player.smoke_effect.speed_scale = 1.0 / 0.2
		player.smoke_effect.play("smoke")
		player.smoke_effect_back.process_mode = Node.PROCESS_MODE_ALWAYS
		player.smoke_effect_back.speed_scale = 1.0 / 0.2
		player.smoke_effect_back.play("smoke")	
		
	player.dash_effect.process_mode = Node.PROCESS_MODE_ALWAYS
	player.dash_effect.pitch_scale = 0.4
	player.dash_effect.play()
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var target_bus = sfx_bus if sfx_bus != -1 else 0
	
	var has_pitch = false
	var effect_idx = -1
	for i in range(AudioServer.get_bus_effect_count(target_bus)):
		if AudioServer.get_bus_effect(target_bus, i) is AudioEffectPitchShift:
			has_pitch = true
			effect_idx = i
			break
			
	if not has_pitch:
		var pitch_effect = AudioEffectPitchShift.new()
		AudioServer.add_bus_effect(target_bus, pitch_effect)
		effect_idx = AudioServer.get_bus_effect_count(target_bus) - 1
		
	var effect = AudioServer.get_bus_effect(target_bus, effect_idx) as AudioEffectPitchShift
	
	var audio_tween = create_tween().set_parallel(true)
	audio_tween.tween_property(effect, "pitch_scale", 0.4, 0.1)
	audio_tween.chain().tween_property(effect, "pitch_scale", 1.0, player.DASH_DURATION)
	
	player.dash_effect_particles.emitting = true

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction == Vector3.ZERO:
		direction = -player.transform.basis.z
	
	player.dash_direction = direction

	var motion_blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
	if motion_blur:
		motion_blur.visible = true
		motion_blur.material.set_shader_parameter("blur_strength", 1.0)
		var tween_blur = create_tween().set_parallel(true)
		tween_blur.tween_property(motion_blur.material, "shader_parameter/blur_strength", 0.0, player.DASH_DURATION)
		tween_blur.chain().tween_callback(func(): motion_blur.visible = false)
		
		var camera = player.get_viewport().get_camera_3d()
		if camera:
			var base_fov = camera.fov
			var fov_boost = 6.0 if player.is_first_person else 12.0
			tween_blur.tween_property(camera, "fov", base_fov + fov_boost, player.DASH_DURATION * 0.3).set_trans(Tween.TRANS_SINE)
			tween_blur.tween_property(camera, "fov", base_fov, player.DASH_DURATION * 0.7).set_delay(player.DASH_DURATION * 0.3).set_trans(Tween.TRANS_SINE)
		
	player.is_dashing = true
	player.dash_timer = player.DASH_DURATION
	player.dash_cooldown_timer = player.DASH_COOLDOWN

	if player.modelo_visual:
		var tween_scale = create_tween()
		tween_scale.set_speed_scale(1.0 / 0.2) 
		
		var shrink = tween_scale.tween_property(player.modelo_visual, "scale", Vector3(0, 0, 0), 0.17)
		if shrink: shrink.set_trans(Tween.TRANS_SINE)
		
		tween_scale.tween_interval(player.DASH_DURATION)
		
		var grow = tween_scale.tween_property(player.modelo_visual, "scale", Vector3(1, 1, 1), 0.17)
		if grow: grow.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if player.trail_particles:
		player.trail_particles.emitting = true

	GlobalUtils.vibrate_controller(Input, 0.5, 0.2, 0.1)
	GlobalUtils.ativar_camera_lenta_com_fim(0.2, 1.0, false)
