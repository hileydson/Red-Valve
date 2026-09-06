extends Node3D

@onready var new_game: Button = $UI/Control/VBoxContainer/new_game
@onready var load_btn: Button = $UI/Control/VBoxContainer/load
@onready var ashen: AudioStreamPlayer = $AshenSerenity

var input_locked: bool = true

var old_film_layer: CanvasLayer = null
var amulet_node: Node3D = null
var amulet_spin_velocity: float = 0.3

func _process(delta: float) -> void:
	if amulet_node:
		amulet_node.rotation.y += amulet_spin_velocity * delta
		# Desacelera suavemente de volta para a velocidade base (0.3)
		amulet_spin_velocity = lerp(amulet_spin_velocity, 0.3, delta * 4.0)

func _setup_old_film_filter() -> void:
	old_film_layer = CanvasLayer.new()
	old_film_layer.layer = 0
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
	
	# 1. Primeiro move para a esquerda e dá um pequeno zoom.
	var move_duration = 6.0
	var maycow_target_pos = maycow.position + Vector3(0.85, -0.65, 0)
	
	var intro_tween = create_tween()
	intro_tween.tween_property(maycow, "position", maycow_target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Zoom - camera olha para +Z (Z=-1.3 para Z=-0.9)
	var cam_target_pos = cam.position + Vector3(0, 0, 0.45)
	intro_tween.parallel().tween_property(cam, "position", cam_target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Move o titulo
	var title = get_node_or_null("UI/TitleLabel")
	if title:
		# Valores aumentados para ir mais para a direita (260) e mais para cima (-100)
		var title_target_pos = title.position + Vector2(260, -100)
		intro_tween.parallel().tween_property(title, "position", title_target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await intro_tween.finished
	
	# 2. Depois de ir para a esquerda, começa o loop de girar a camera em volta do modelo.
	var pivot = Node3D.new()
	add_child(pivot)
	pivot.global_position = maycow.global_position
	
	var cam_global = cam.global_transform
	cam.get_parent().remove_child(cam)
	pivot.add_child(cam)
	cam.global_transform = cam_global
	
	var duration_loop = 16.0
	var pause_duration = 3.0
	
	var pivot_orig_rot = pivot.rotation
	# Gira levemente para revelar o perfil
	var pivot_target_rot = pivot_orig_rot + Vector3(0, 0.3, 0)
	
	var loop_tween = create_tween().set_loops()
	
	# Vai devagar em volta do modelo 3d
	loop_tween.tween_property(pivot, "rotation", pivot_target_rot, duration_loop).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop_tween.tween_interval(pause_duration)
	
	# Volta
	loop_tween.tween_property(pivot, "rotation", pivot_orig_rot, duration_loop).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop_tween.tween_interval(pause_duration)
	
	# === Efeito do Amuleto Fantasma ===
	var amulet_scene = load("res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb")
	if amulet_scene:
		var amulet = amulet_scene.instantiate()
		cam.add_child(amulet)
		# Posiciona na frente da câmera
		amulet.position = Vector3(0, 0, -1.5)
		amulet.scale = Vector3(1.0, 1.0, 1.0)
		
		# Volta o material fantasma cinza e transparente
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.3, 0.3, 0.3, 0.0) # Começa totalmente invisível (0.0)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.1, 0.1) # Brilho cinza
		
		# Aplica o material em todos os meshes do amuleto
		for child in amulet.find_children("*", "MeshInstance3D"):
			child.material_override = mat
			
		# Fade-in um pouco mais rápido (5 segundos) até 35% de opacidade
		var fade_duration = 5.0
		var fade_tween = create_tween()
		fade_tween.tween_property(mat, "albedo_color:a", 0.35, fade_duration).set_trans(Tween.TRANS_SINE)
			
		amulet_node = amulet

func _on_button_focus(btn: Button) -> void:
	if input_locked: return
	
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
	
	# Dá um impulso no giro do amuleto (agora menos rápido e mais curto)
	amulet_spin_velocity = 2.0
	
	# Efeito de "pulo" no botão
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween()
	btn.scale = Vector2(1.15, 1.15)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	get_tree().paused = false
	# Rede de segurança: qualquer caminho que traga o jogador de volta ao menu
	# não pode deixar cena/HUD/sangue do jogo pendurados na árvore.
	GlobalUtils.cleanup_gameplay_leftovers()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	load_btn.grab_focus()
	
	# Verifica se há saves para o botão de load e configura
	var slots = SaveManager.get_slots_info()
	var has_any_save = false
	var has_empty_slot = false
	for slot in slots:
		if not slot["empty"]:
			has_any_save = true
		else:
			has_empty_slot = true
			
	if not has_any_save:
		load_btn.disabled = true
		new_game.grab_focus()
	if not has_empty_slot:
		new_game.disabled = true
	
	var ashen_target = ashen.volume_db
	ashen.volume_db = -80.0
	var audio_in_tween = create_tween()
	audio_in_tween.tween_property(ashen, "volume_db", ashen_target, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Tocar talk_passionately
	var maycow = get_node_or_null("maycow_lopes")
	if maycow and maycow.has_node("AnimationPlayer"):
		var ap = maycow.get_node("AnimationPlayer")
		for anim in ap.get_animation_list():
			if "talk_passionately" in anim.to_lower():
				ap.get_animation(anim).loop_mode = 1 # Animation.LOOP_LINEAR
				ap.play(anim)
				break
				
	# === Estilizar as Opções do Menu ===
	var vbox = $UI/Control/VBoxContainer
	if vbox:
		for btn in vbox.get_children():
			if btn is Button:
				# Criar os estilos customizados em vermelho
				var style_normal = StyleBoxEmpty.new()
				
				var style_focus = StyleBoxFlat.new()
				style_focus.bg_color = Color(0.6, 0.0, 0.0, 0.4) # Vermelho translúcido
				style_focus.border_color = Color(1.0, 0.1, 0.1, 0.8) # Borda vermelha brilhante
				style_focus.set_border_width_all(0)
				style_focus.border_width_left = 6
				style_focus.corner_radius_top_right = 5
				style_focus.corner_radius_bottom_right = 5
				
				var style_hover = style_focus.duplicate()
				style_hover.bg_color = Color(0.8, 0.0, 0.0, 0.2)
				
				var style_pressed = style_focus.duplicate()
				style_pressed.bg_color = Color(1.0, 0.0, 0.0, 0.6)
				
				# Aplicar os estilos
				btn.add_theme_stylebox_override("normal", style_normal)
				btn.add_theme_stylebox_override("focus", style_focus)
				btn.add_theme_stylebox_override("hover", style_hover)
				btn.add_theme_stylebox_override("pressed", style_pressed)
				
				# Mudar cor e tamanho da fonte para destacar
				btn.add_theme_color_override("font_focus_color", Color(1.0, 0.8, 0.8))
				btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.8))
				btn.add_theme_font_size_override("font_size", 22)
				
				# Conectar sinais para efeito de foco
				btn.focus_entered.connect(func(): _on_button_focus(btn))
				btn.mouse_entered.connect(func(): btn.grab_focus())
				
				btn.gui_input.connect(func(event: InputEvent):
					if input_locked: return
					if (event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)):
						if btn.disabled:
							GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/negacao.mp3")
				)

	_setup_old_film_filter()
	_start_menu_loop()
	
	await get_tree().create_timer(2.0).timeout
	input_locked = false

func _show_slots_menu(is_new_game: bool) -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	$UI/Control.visible = false
	
	var slots_panel = Control.new()
	slots_panel.name = "SlotsPanel"
	slots_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(slots_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vbox.offset_right = -150
	vbox.offset_bottom = -50
	vbox.add_theme_constant_override("separation", 20)
	slots_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = tr("UI_SELECT_SAVE_SLOT") if is_new_game else tr("BTN_LOAD_GAME")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	vbox.add_child(title)
	
	var slots_info = SaveManager.get_slots_info()
	var first_focusable = null
	
	for slot_info in slots_info:
		var btn = Button.new()
		var slot_idx = slot_info["slot"]
		var is_empty = slot_info["empty"]
		
		btn.custom_minimum_size = Vector2(400, 80)
		
		if is_empty:
			btn.text = tr("UI_SLOT") + " " + str(slot_idx) + " - [ " + tr("UI_EMPTY") + " ]"
		else:
			btn.text = tr("UI_SLOT") + " " + str(slot_idx) + " - " + tr(slot_info["chapter"])
			
		var style_normal = StyleBoxEmpty.new()
		var style_focus = StyleBoxFlat.new()
		style_focus.bg_color = Color(0.6, 0.0, 0.0, 0.4)
		style_focus.border_color = Color(1.0, 0.1, 0.1, 0.8)
		style_focus.border_width_left = 6
		var style_hover = style_focus.duplicate()
		style_hover.bg_color = Color(0.8, 0.0, 0.0, 0.2)
		var style_pressed = style_focus.duplicate()
		style_pressed.bg_color = Color(1.0, 0.0, 0.0, 0.6)
		var style_disabled = StyleBoxFlat.new()
		style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.4)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("focus", style_focus)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		
		btn.add_theme_font_size_override("font_size", 22)
		
		if is_new_game and not is_empty:
			btn.disabled = true
		elif not is_new_game and is_empty:
			btn.disabled = true
		else:
			if not first_focusable:
				first_focusable = btn
				
		btn.focus_entered.connect(func():
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			btn.pivot_offset = btn.size / 2.0
			var tween = create_tween()
			btn.scale = Vector2(1.15, 1.15)
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		)
		btn.mouse_entered.connect(func(): if not btn.disabled: btn.grab_focus())
		
		btn.pressed.connect(func():
			_on_slot_selected(slot_idx, is_new_game)
		)
		
		vbox.add_child(btn)
		
	var back_btn = Button.new()
	back_btn.text = "BTN_BACK"
	back_btn.custom_minimum_size = Vector2(400, 60)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0.5)
	back_btn.add_theme_stylebox_override("normal", btn_style)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(func():
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
		slots_panel.queue_free()
		$UI/Control.visible = true
		if is_new_game:
			new_game.grab_focus()
		else:
			load_btn.grab_focus()
	)
	vbox.add_child(back_btn)
	
	if first_focusable:
		first_focusable.grab_focus()
	else:
		back_btn.grab_focus()

func _on_slot_selected(slot_id: int, is_new_game: bool) -> void:
	if input_locked: return
	input_locked = true
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/entrar_super.mp3")
	
	var audio_out_tween = create_tween()
	audio_out_tween.tween_property(ashen, "volume_db", -80.0, 2.0)
	$UI/fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	
	if is_new_game:
		SaveManager.reset_progress()
		SaveManager.current_slot = slot_id
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1_cutscene_prologo.tscn")
	else:
		SaveManager.load_game(slot_id)

func _on_load_pressed() -> void:
	_show_slots_menu(false)

func _on_start_pressed() -> void:
	_show_slots_menu(true)

func _on_config_pressed() -> void:
	if input_locked: return
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	var config_script = load("res://scripts/ui/config_menu.gd")
	if config_script:
		var config_menu = config_script.new()
		add_child(config_menu)
		$UI/Control.visible = false
		config_menu.back_btn.pressed.disconnect(config_menu._on_back_pressed)
		config_menu.back_btn.pressed.connect(func():
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
			SaveManager.save_config()
			$UI/Control.visible = true
			$UI/Control/VBoxContainer/config.grab_focus()
			config_menu.queue_free()
		)

func _on_exit_pressed() -> void:
	if input_locked: return
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if input_locked: return
	var is_back = event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed)
	if is_back:
		var slots_panel = $UI.get_node_or_null("SlotsPanel")
		if slots_panel and slots_panel.visible:
			var vbox = slots_panel.get_child(0)
			if vbox:
				for child in vbox.get_children():
					if child is Button and child.text == "BTN_BACK":
						child.pressed.emit()
						get_viewport().set_input_as_handled()
						return
