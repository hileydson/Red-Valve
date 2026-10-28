extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

# ==============================================================================
# CUTSCENE HELPER METHODS
# ==============================================================================

func cutscene_set_hud_enabled(enabled: bool) -> void:
	player._cutscene_hud_hidden = not enabled
	if is_instance_valid(player.hud_layer):
		player.hud_layer.visible = enabled
	if "point" in player and is_instance_valid(player.point):
		player.point.visible = enabled
	if "control_weapons" in player and is_instance_valid(player.control_weapons):
		player.control_weapons.visible = enabled
	if "stamina_bar" in player and is_instance_valid(player.stamina_bar):
		player.stamina_bar.visible = enabled

func cutscene_set_player_control(enabled: bool) -> void:
	player._cutscene_inputs_disabled = not enabled

func cutscene_set_auto_walk(enabled: bool) -> void:
	player._cutscene_auto_walk = enabled

func cutscene_set_auto_run(enabled: bool) -> void:
	player._cutscene_auto_run = enabled

func cutscene_set_motion_blur(intensity_percent: int) -> void:
	var strength = clamp(intensity_percent / 100.0, 0.0, 1.0)
	if is_instance_valid(player.hud_layer):
		var blur_overlay = player.hud_layer.get_node_or_null("MotionBlurOverlay")
		if blur_overlay and blur_overlay.material:
			blur_overlay.material.set_shader_parameter("blur_strength", strength * 1.5) # Aumentando o multiplicador pra notar mais o efeito
			blur_overlay.visible = (strength > 0.0)

func cutscene_set_slow_motion(intensity_percent: int) -> void:
	if intensity_percent <= 0:
		Engine.time_scale = 1.0
		AudioServer.set_playback_speed_scale(1.0)
	else:
		var scale = 1.0 - clamp(intensity_percent / 100.0, 0.0, 0.99)
		Engine.time_scale = scale
		AudioServer.set_playback_speed_scale(scale)

func cutscene_set_slow_motion_no_audio(intensity_percent: int) -> void:
	if intensity_percent <= 0:
		Engine.time_scale = 1.0
	else:
		var scale = 1.0 - clamp(intensity_percent / 100.0, 0.0, 0.99)
		Engine.time_scale = scale

func cutscene_set_camera_shake(intensity_percent: int) -> void:
	player._cutscene_camera_shake_intensity = clamp(intensity_percent / 100.0, 0.0, 1.0)

func cutscene_set_camera_current(is_current: bool) -> void:
	player._cutscene_camera_disabled = not is_current
	if is_current:
		if is_instance_valid(player.camera_third_person):
			player.camera_third_person.make_current()
	else:
		if is_instance_valid(player.camera_third_person):
			player.camera_third_person.current = false
		if is_instance_valid(player.camera):
			player.camera.current = false
