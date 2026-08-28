extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()
	_setup_iron_rusks_hud()
	_setup_health_hud()

func _setup_health_hud() -> void:
	player.current_health = player.max_health
	
	player.hud_layer = CanvasLayer.new()
	player.hud_layer.layer = 100
	player.hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var sc = GDScript.new()
	sc.source_code = "extends CanvasLayer\nfunc _process(delta):\n\tif get_parent()._cutscene_hud_hidden:\n\t\tvisible = false\n\telse:\n\t\tvisible = not GlobalEvents.in_cutscene"
	sc.reload()
	player.hud_layer.set_script(sc)
	player.add_child(player.hud_layer)
	
	player.heartbeat_hud = ColorRect.new()
	player.heartbeat_hud.anchor_left = 0.0
	player.heartbeat_hud.anchor_top = 1.0
	player.heartbeat_hud.anchor_right = 0.0
	player.heartbeat_hud.anchor_bottom = 1.0
	player.heartbeat_hud.offset_left = 30
	player.heartbeat_hud.offset_top = -110
	player.heartbeat_hud.offset_right = 230
	player.heartbeat_hud.offset_bottom = -30
	player.heartbeat_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float speed = 1.0;
uniform float line_thickness = 0.02;

float ekg(float x) {
	x = fract(x); 
	float y = 0.5;
	y += 0.08 * exp(-pow((x - 0.2) * 50.0, 2.0));
	y -= 0.15 * exp(-pow((x - 0.3) * 100.0, 2.0));
	y += 0.45 * exp(-pow((x - 0.35) * 150.0, 2.0));
	y -= 0.20 * exp(-pow((x - 0.4) * 100.0, 2.0));
	y += 0.10 * exp(-pow((x - 0.6) * 30.0, 2.0));
	return y;
}

void fragment() {
	// 2 batimentos por tela, movendo para a esquerda
	float x = UV.x * 2.0 + TIME * speed;
	float target_y = ekg(x);
	
	float dist = abs(UV.y - target_y);
	float glow = line_thickness / (dist + 0.005);
	
	// Fundo totalmente transparente
	vec4 bg = vec4(0.0, 0.0, 0.0, 0.0);
	
	COLOR = mix(bg, vec4(line_color.rgb, 1.0), clamp(glow, 0.0, 1.0) * line_color.a);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	player.heartbeat_hud.material = mat
	
	player.hud_layer.add_child(player.heartbeat_hud)
	
	if !GlobalEvents.is_maycow_normal:
		player.cogblade_hud = TextureProgressBar.new()
		var cog_tex = load("res://assets/images/menu/itens/red_valve/cogblade.png")
		player.cogblade_hud.texture_under = cog_tex
		player.cogblade_hud.texture_progress = cog_tex
		player.cogblade_hud.tint_under = Color(1, 1, 1, 0.25) # Marca d'água permanente na tela
		player.cogblade_hud.tint_progress = Color(1, 1, 1, 1.0) # Cor de preenchimento
		player.cogblade_hud.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		player.cogblade_hud.min_value = 0
		player.cogblade_hud.max_value = 100
		player.cogblade_hud.value = 0
		player.cogblade_hud.anchor_left = 0.0
		player.cogblade_hud.anchor_top = 0.0
		player.cogblade_hud.anchor_right = 0.0
		player.cogblade_hud.anchor_bottom = 0.0
		player.cogblade_hud.offset_left = 20
		player.cogblade_hud.offset_top = 20
		player.cogblade_hud.scale = Vector2(0.4, 0.4)
		player.hud_layer.add_child(player.cogblade_hud)
		
		player.cogblade_hud_label = Label.new()
		player.cogblade_hud_label.text = "PODER DA COGBLADE"
		player.cogblade_hud_label.add_theme_font_size_override("font_size", 64)
		player.cogblade_hud_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
		player.cogblade_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		player.cogblade_hud_label.visible = false
		player.hud_layer.add_child(player.cogblade_hud_label)

	# Adicionando BackBufferCopy para garantir captura da tela
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	player.hud_layer.add_child(back_buffer)

	var blur_overlay = ColorRect.new()
	blur_overlay.name = "MotionBlurOverlay"
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_overlay.visible = false
	var blur_shader = Shader.new()
	blur_shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	uniform float blur_strength = 0.0;
	
	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		vec2 uv = SCREEN_UV;
		vec2 dir = center - uv;
		vec4 c = texture(screen_texture, uv);
		c += texture(screen_texture, uv + dir * blur_strength * 0.05);
		c += texture(screen_texture, uv + dir * blur_strength * 0.10);
		c += texture(screen_texture, uv + dir * blur_strength * 0.15);
		c += texture(screen_texture, uv + dir * blur_strength * 0.20);
		c += texture(screen_texture, uv + dir * blur_strength * 0.25);
		c += texture(screen_texture, uv + dir * blur_strength * 0.30);
		c += texture(screen_texture, uv + dir * blur_strength * 0.35);
		COLOR = c / 8.0;
	}
	"""
	var blur_mat = ShaderMaterial.new()
	blur_mat.shader = blur_shader
	blur_overlay.material = blur_mat
	player.hud_layer.add_child(blur_overlay)

	
	player.blood_overlay = ColorRect.new()
	player.blood_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.blood_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blood_shader = Shader.new()
	blood_shader.code = """
shader_type canvas_item;
uniform vec4 color : source_color = vec4(0.8, 0.0, 0.0, 1.0);
uniform float multiplier = 0.0;
uniform float softness = 0.8;

void fragment() {
	float value = distance(UV, vec2(0.5));
	value = smoothstep(0.5 - softness, 0.5, value);
	COLOR = vec4(color.rgb, value * multiplier);
}
"""
	var blood_mat = ShaderMaterial.new()
	blood_mat.shader = blood_shader
	player.blood_overlay.material = blood_mat
	#player.hud_layer.add_child(player.blood_overlay) # Removido a marca de sangue conforme pedido

	# Blur Setup
	
	player.ammo_label = Label.new()
	player.ammo_label.anchor_left = 1.0
	player.ammo_label.anchor_top = 1.0
	player.ammo_label.anchor_right = 1.0
	player.ammo_label.anchor_bottom = 1.0
	player.ammo_label.offset_left = -300
	player.ammo_label.offset_top = -100
	player.ammo_label.offset_right = -80
	player.ammo_label.offset_bottom = -30
	player.ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player.ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	player.ammo_label.add_theme_font_size_override("font_size", 48)
	player.ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	player.ammo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	player.ammo_label.add_theme_constant_override("outline_size", 6)
	player.hud_layer.add_child(player.ammo_label)
	
	player.ammo_icon = TextureRect.new()
	player.ammo_icon.texture = load("res://assets/images/menu/itens/mostragem_bullets/mostragem_bullets.png")
	player.ammo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player.ammo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player.ammo_icon.anchor_left = 1.0
	player.ammo_icon.anchor_top = 1.0
	player.ammo_icon.anchor_right = 1.0
	player.ammo_icon.anchor_bottom = 1.0
	player.ammo_icon.offset_left = -70
	player.ammo_icon.offset_top = -85
	player.ammo_icon.offset_right = -30
	player.ammo_icon.offset_bottom = -45
	player.hud_layer.add_child(player.ammo_icon)
	
	update_ammo_ui()

	# MP Bar
	player.mp_bar = ProgressBar.new()
	player.mp_bar.anchor_left = 0.5
	player.mp_bar.anchor_top = 1.0
	player.mp_bar.anchor_right = 0.5
	player.mp_bar.anchor_bottom = 1.0
	player.mp_bar.offset_left = -100
	player.mp_bar.offset_top = -35
	player.mp_bar.offset_right = 100
	player.mp_bar.offset_bottom = -25
	player.mp_bar.show_percentage = false
	var mp_sb = StyleBoxFlat.new()
	mp_sb.bg_color = Color(0.2, 0.4, 0.9, 0.8)
	mp_sb.corner_radius_top_left = 4
	mp_sb.corner_radius_top_right = 4
	mp_sb.corner_radius_bottom_left = 4
	mp_sb.corner_radius_bottom_right = 4
	player.mp_bar.add_theme_stylebox_override("fill", mp_sb)
	var mp_bg = StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	mp_bg.corner_radius_top_left = 4
	mp_bg.corner_radius_top_right = 4
	mp_bg.corner_radius_bottom_left = 4
	mp_bg.corner_radius_bottom_right = 4
	player.mp_bar.add_theme_stylebox_override("background", mp_bg)
	player.hud_layer.add_child(player.mp_bar)

	# Stamina Bar
	player.stamina_bar = ProgressBar.new()
	player.stamina_bar.anchor_left = 0.5
	player.stamina_bar.anchor_top = 1.0
	player.stamina_bar.anchor_right = 0.5
	player.stamina_bar.anchor_bottom = 1.0
	player.stamina_bar.offset_left = -150
	player.stamina_bar.offset_top = -50
	player.stamina_bar.offset_right = 150
	player.stamina_bar.offset_bottom = -40
	player.stamina_bar.show_percentage = false
	var st_sb = StyleBoxFlat.new()
	st_sb.bg_color = Color(0.9, 0.9, 0.9, 0.7)
	st_sb.corner_radius_top_left = 2
	st_sb.corner_radius_top_right = 2
	st_sb.corner_radius_bottom_left = 2
	st_sb.corner_radius_bottom_right = 2
	player.stamina_bar.add_theme_stylebox_override("fill", st_sb)
	var st_bg = StyleBoxFlat.new()
	st_bg.bg_color = Color(0.1, 0.1, 0.1, 0.3)
	st_bg.corner_radius_top_left = 2
	st_bg.corner_radius_top_right = 2
	st_bg.corner_radius_bottom_left = 2
	st_bg.corner_radius_bottom_right = 2
	player.stamina_bar.add_theme_stylebox_override("background", st_bg)
	player.hud_layer.add_child(player.stamina_bar)
	
	# Mira do Amuleto (Círculo Estilo DOOM)
	player.amulet_crosshair = Panel.new()
	player.amulet_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	player.amulet_crosshair.custom_minimum_size = Vector2(32, 32)
	player.amulet_crosshair.offset_left = -16
	player.amulet_crosshair.offset_top = -16
	player.amulet_crosshair.offset_right = 16
	player.amulet_crosshair.offset_bottom = 16
	player.amulet_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0) # Transparente no meio
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.9, 0.2, 1.0, 0.8) # Roxo/Magia
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.anti_aliasing = true
	player.amulet_crosshair.add_theme_stylebox_override("panel", style)
	player.amulet_crosshair.visible = false
	player.hud_layer.add_child(player.amulet_crosshair)
	
	# Amulet Counter Label
	player.amulet_counter_label = Label.new()
	player.amulet_counter_label.add_theme_font_size_override("font_size", 54)
	player.amulet_counter_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	player.amulet_counter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	player.amulet_counter_label.add_theme_constant_override("outline_size", 10)
	player.amulet_counter_label.anchor_left = 1.0
	player.amulet_counter_label.anchor_right = 1.0
	player.amulet_counter_label.offset_left = -250
	player.amulet_counter_label.offset_top = 130
	player.amulet_counter_label.offset_right = -40
	player.amulet_counter_label.offset_bottom = 240
	player.amulet_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player.amulet_counter_label.visible = false
	player.hud_layer.add_child(player.amulet_counter_label)
	
	# Piscar em tons de vermelho
	var counter_tween = create_tween().set_loops()
	counter_tween.tween_property(player.amulet_counter_label, "theme_override_colors/font_color", Color(1.0, 0.2, 0.2, 1.0), 0.4)
	counter_tween.tween_property(player.amulet_counter_label, "theme_override_colors/font_color", Color(0.5, 0.0, 0.0, 1.0), 0.4)
	
	_start_heartbeat_pulse()

func _setup_iron_rusks_hud() -> void:
	var iron_rusks_layer = CanvasLayer.new()
	iron_rusks_layer.layer = 120 # Acima do HUD normal (100), mas por baixo do overlay do menu (129)
	iron_rusks_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var value_label = Label.new()
	value_label.name = "IronRusksValue"
	value_label.add_theme_font_size_override("font_size", 32)
	value_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4, 1.0))
	value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	value_label.add_theme_constant_override("outline_size", 6)
	value_label.anchor_left = 1.0
	value_label.anchor_right = 1.0
	value_label.offset_left = -220
	value_label.offset_top = 15
	value_label.offset_right = -20
	value_label.offset_bottom = 55
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.pivot_offset = Vector2(100, 20)
	value_label.text = str(SaveManager.iron_rusks_display)
	iron_rusks_layer.add_child(value_label)

	var caption_label = Label.new()
	caption_label.add_theme_font_size_override("font_size", 14)
	caption_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4, 0.85))
	caption_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	caption_label.add_theme_constant_override("outline_size", 5)
	caption_label.anchor_left = 1.0
	caption_label.anchor_right = 1.0
	caption_label.offset_left = -220
	caption_label.offset_top = 55
	caption_label.offset_right = -20
	caption_label.offset_bottom = 75
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.text = "Iron Rusks"
	caption_label.visible = false
	iron_rusks_layer.add_child(caption_label)

	var sc = GDScript.new()
	sc.source_code = "extends CanvasLayer\nvar value_label: Label\nvar caption_label: Label\nfunc _process(_delta):\n\tvalue_label.text = str(SaveManager.iron_rusks_display)\n\tcaption_label.visible = get_tree().paused"
	sc.reload()
	# O script precisa ser anexado ANTES do nó entrar na árvore, senão o Godot
	# não habilita o _process automaticamente (mesmo padrão usado no hud_layer acima).
	iron_rusks_layer.set_script(sc)
	iron_rusks_layer.value_label = value_label
	iron_rusks_layer.caption_label = caption_label

	player.add_child(iron_rusks_layer)
	player.iron_rusks_value_label = value_label

func update_ammo_ui() -> void:
	if not is_instance_valid(player.ammo_label): return
	
	var is_pistol_equipped = SaveManager.is_equipped("pistol")
	
	if GlobalEvents.is_maycow_normal or not is_pistol_equipped:
		player.ammo_label.visible = false
		if is_instance_valid(player.ammo_icon): player.ammo_icon.visible = false
	else:
		player.ammo_label.visible = true
		if is_instance_valid(player.ammo_icon): player.ammo_icon.visible = true
		var total = SaveManager.get_item_amount("pistol_ammo")
		player.ammo_label.text = str(player.clip_pistol_ammo) + " / " + str(total)

func _start_heartbeat_pulse() -> void:
	if player.current_health <= 0:
		player.heartbeat_hud.visible = false
		return
		
	if player.heartbeat_tween:
		player.heartbeat_tween.kill()
		
	player.heartbeat_tween = create_tween().set_parallel(true)
	
	var target_speed = 1.0
	var target_color = Color(0, 1, 0, 1.0) # Verde
	
	if player.current_health < 30:
		target_color = Color(1, 0, 0, 1.0) # Vermelho
		target_speed = 2.8
	elif player.current_health < 70:
		target_color = Color(1, 1, 0, 1.0) # Amarelo
		target_speed = 2.0
		
	var mat = player.heartbeat_hud.material as ShaderMaterial
	if not mat: return
	
	var current_color = mat.get_shader_parameter("line_color")
	if current_color == null: current_color = Color(0, 1, 0, 1.0)
	
	var current_speed = mat.get_shader_parameter("speed")
	if current_speed == null: current_speed = 1.0
	
	# Transição suave de cor e velocidade do ECG
	player.heartbeat_tween.tween_method(func(val): mat.set_shader_parameter("line_color", val), current_color, target_color, 0.5)
	player.heartbeat_tween.tween_method(func(val): mat.set_shader_parameter("speed", val), current_speed, target_speed, 0.5) 
