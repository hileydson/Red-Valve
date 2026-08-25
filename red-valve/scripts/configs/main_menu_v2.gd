extends Node3D

@onready var start: Button = $UI/Control/VBoxContainer/start
@onready var load_btn: Button = $UI/Control/VBoxContainer/load
@onready var ashen: AudioStreamPlayer = $AshenSerenity

var input_locked: bool = true


var old_film_layer: CanvasLayer = null

func _setup_old_film_filter() -> void:
	old_film_layer = CanvasLayer.new()
	old_film_layer.layer = 110
	add_child(old_film_layer)
	
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	old_film_layer.add_child(back_buffer)
	
	var film_rect = ColorRect.new()
	film_rect.name = "OldFilmOverlay"
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader_code: String = """
	shader_type canvas_item;

	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	uniform float sepia_amount : hint_range(0.0, 1.0) = 0.35;
	uniform float grain_amount : hint_range(0.0, 1.0) = 0.18;
	uniform float scratch_amount : hint_range(0.0, 1.0) = 0.35;
	uniform float vignette_amount : hint_range(0.0, 1.0) = 0.65;
	uniform float flicker_amount : hint_range(0.0, 1.0) = 0.08;

	float rand(vec2 co) {
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}

	void fragment() {
		vec2 uv = SCREEN_UV;
		vec4 color = texture(screen_texture, uv);
		
		vec3 sepia = vec3(
			dot(color.rgb, vec3(0.393, 0.769, 0.189)),
			dot(color.rgb, vec3(0.349, 0.686, 0.168)),
			dot(color.rgb, vec3(0.272, 0.534, 0.131))
		);
		color.rgb = mix(color.rgb, sepia, sepia_amount);
		
		float noise = rand(uv + vec2(TIME * 18.0, TIME * 33.0));
		color.rgb += (noise - 0.5) * grain_amount;
		
		float scratch_rand = rand(vec2(floor(uv.x * 250.0), floor(TIME * 12.0)));
		if (scratch_rand > (1.0 - scratch_amount * 0.04)) {
			float scratch_int = rand(vec2(uv.x, TIME * 5.0));
			color.rgb -= vec3(scratch_int * 0.35);
		}
		
		float dist = distance(uv, vec2(0.5, 0.5));
		float vignette = smoothstep(0.85, 0.25, dist * vignette_amount);
		color.rgb *= mix(1.0, vignette, vignette_amount);
		
		float flicker = sin(TIME * 35.0) * 0.5 + 0.5;
		color.rgb *= (1.0 - flicker * flicker_amount);
		
		COLOR = color;
	}
	"""
	var shader = Shader.new()
	shader.code = shader_code
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	film_rect.material = mat
	old_film_layer.add_child(film_rect)

func _start_menu_loop() -> void:
	var maycow = get_node_or_null("maycow_lopes")
	var cam = $Camera3D
	
	if not maycow or not cam:
		return
	
	# Cria um pivot no centro (mesma posicao inicial do maycow)
	var pivot = Node3D.new()
	add_child(pivot)
	pivot.global_position = Vector3(0, 0, 0)
	
	# Reparenta a camera para o pivot para fazer orbita facilmente
	cam.get_parent().remove_child(cam)
	pivot.add_child(cam)
	
	var duration = 14.0
	var pause_duration = 4.0
	
	var maycow_orig_pos = maycow.position
	# Move para a esquerda na visão da camera (a camera olha para +Z, logo a esquerda dela é +X)
	var maycow_target_pos = maycow_orig_pos + Vector3(0.5, 0, 0)
	
	var pivot_orig_rot = pivot.rotation
	# Gira a camera para a direita (negativo no eixo Y)
	var pivot_target_rot = pivot_orig_rot + Vector3(0, -0.4, 0)
	
	var loop_tween = create_tween().set_loops()
	
	# Vai devagar e gradual
	loop_tween.tween_property(maycow, "position", maycow_target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop_tween.parallel().tween_property(pivot, "rotation", pivot_target_rot, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Espera
	loop_tween.tween_interval(pause_duration)
	
	# Volta
	loop_tween.tween_property(maycow, "position", maycow_orig_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop_tween.parallel().tween_property(pivot, "rotation", pivot_orig_rot, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Espera
	loop_tween.tween_interval(pause_duration)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	start.grab_focus()
	
	if not FileAccess.file_exists("user://save_game.json"):
		load_btn.disabled = true
	
	var ashen_target = ashen.volume_db
	ashen.volume_db = -80.0
	var audio_in_tween = create_tween()
	audio_in_tween.tween_property(ashen, "volume_db", ashen_target, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Tocar idle
	var maycow = get_node_or_null("maycow_lopes")
	if maycow and maycow.has_node("AnimationPlayer"):
		var ap = maycow.get_node("AnimationPlayer")
		if ap.has_animation("idle"):
			ap.play("idle")
	
	await get_tree().create_timer(2.0).timeout
	input_locked = false

	_setup_old_film_filter()
	_start_menu_loop()


func _on_load_pressed() -> void:
	if input_locked: return
	$UI/Control.visible = false
	var audio_out_tween = create_tween()
	audio_out_tween.tween_property(ashen, "volume_db", -80.0, 2.0)
	$UI/fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	SaveManager.load_game()

func _on_start_pressed() -> void:
	if input_locked: return
	$UI/Control.visible = false
	var audio_out_tween = create_tween()
	audio_out_tween.tween_property(ashen, "volume_db", -80.0, 2.0)
	$UI/fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1_cutscene_prologo.tscn")

func _on_config_pressed() -> void:
	if input_locked: return
	var config_script = load("res://scripts/ui/config_menu.gd")
	if config_script:
		var config_menu = config_script.new()
		add_child(config_menu)
		$UI/Control.visible = false
		config_menu.back_btn.pressed.disconnect(config_menu._on_back_pressed)
		config_menu.back_btn.pressed.connect(func():
			SaveManager.save_game()
			$UI/Control.visible = true
			$UI/Control/VBoxContainer/config.grab_focus()
			config_menu.queue_free()
		)

func _on_exit_pressed() -> void:
	if input_locked: return
	get_tree().quit()
