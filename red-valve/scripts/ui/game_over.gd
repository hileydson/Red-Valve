extends CanvasLayer

var shake_intensity: float = 0.0
var noise = FastNoiseLite.new()
var noise_time: float = 0.0

func _process(delta: float) -> void:
	if shake_intensity > 0:
		noise_time += delta * 30.0 # Velocidade do tremor
		offset = Vector2(
			noise.get_noise_2d(noise_time, 0.0) * shake_intensity,
			noise.get_noise_2d(0.0, noise_time) * shake_intensity
		)
	else:
		offset = Vector2.ZERO

func _ready() -> void:
	#sempre sera o maycow da mundo paralelo e nao do mundo real
	GlobalEvents.is_maycow_normal = false
	
	self.layer = 128
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.1
	
	# 1. Congela o jogo
	get_tree().paused = true
	
	# 2. Tela de fundo com shader de derretimento
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float melt_amount : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Ruído simples para colunas escorrendo
	float col_id = floor(uv.x * 80.0) / 80.0;
	float noise = fract(sin(dot(vec2(col_id, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	
	float melt = melt_amount * (0.1 + noise * 0.9);
	
	vec2 distorted_uv = vec2(uv.x, uv.y - melt);
	
	if (distorted_uv.y < 0.0) {
		COLOR = vec4(0.2, 0.0, 0.0, 1.0); // Sangue escuro no topo que derreteu
	} else {
		COLOR = texture(screen_texture, distorted_uv);
		COLOR.rgb = mix(COLOR.rgb, vec3(0.5, 0.0, 0.0), melt_amount * 0.7); // Escurece e avermelha
	}
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	bg.material = mat
	
	# 3. Label de Game Over
	var label = Label.new()
	var txt = tr("GAME_OVER_TEXT")
	label.text = txt if txt != "GAME_OVER_TEXT" else "GAME OVER"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 140)
	
	var custom_font = load("res://assets/fonts/Nosifer-Regular.ttf")
	if custom_font:
		label.add_theme_font_override("font", custom_font)
		
	label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0)) # Preta
	label.add_theme_color_override("font_outline_color", Color(0.5, 0.0, 0.0, 1.0)) # Contorno vermelho escuro
	label.add_theme_constant_override("outline_size", 15)
	label.modulate.a = 0.0
	add_child(label)
	
	# 4. Partículas (Gotas de Sangue caindo do texto)
	var particles = CPUParticles2D.new()
	var vp_size = get_viewport().get_visible_rect().size
	particles.position = Vector2(vp_size.x / 2.0, vp_size.y / 2.0 + 30) # Um pouco pra baixo pra encaixar nas letras
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(420, 20)
	particles.direction = Vector2(0, 1)
	particles.spread = 15.0
	particles.gravity = Vector2(0, 600)
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 80.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 12.0
	particles.color = Color(0.6, 0.0, 0.0, 1.0)
	particles.amount = 120
	particles.lifetime = 4.0
	particles.modulate.a = 0.0 # Começa invisível
	add_child(particles)
	
	# 5. Animações (Tween)
	var tween = create_tween().set_parallel(true)
	
	# TREMOR DE TELA (Começa forte em 40.0 e vai parando suavemente em 3 segundos)
	shake_intensity = 40.0
	tween.tween_property(self, "shake_intensity", 0.0, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_method(func(val): mat.set_shader_parameter("melt_amount", val), 0.0, 1.2, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 1.0, 3.0).set_delay(1.5)
	tween.tween_property(particles, "modulate:a", 1.0, 3.0).set_delay(1.5)
	
	# 6. Esperar a animação principal terminar (6 segundos)
	await tween.finished
	print("Animação de Game Over finalizada.")
	
	var fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	add_child(fade)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(fade, "color:a", 1.0, 1.5)
	
	await fade_tween.finished
	print("Fade out completo. Retornando ao menu...")
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/configs/main_menu.tscn")
	queue_free()
