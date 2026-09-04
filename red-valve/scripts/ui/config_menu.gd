extends CanvasLayer

var bg: ColorRect
var title_label: Label
var tab_container: TabContainer
var back_btn: Button

# Gameplay Tab
var tab_gameplay: MarginContainer
var lang_label: Label
var lang_option: OptionButton
var run_label: Label
var run_option: OptionButton

# Controls Tab
var tab_controls: MarginContainer
var deadzone_label: Label
var deadzone_slider: HSlider
var sens_look_label: Label
var sens_look_slider: HSlider
var sens_aim_label: Label
var sens_aim_slider: HSlider
var commands_label: Label
var controls_text: RichTextLabel
var controls_scroll: ScrollContainer

# Video Tab
var tab_video: MarginContainer
var display_label: Label
var display_option: OptionButton
var res_label: Label
var resolution_option: OptionButton
var brightness_label: Label
var brightness_slider: HSlider

func _ready() -> void:
	self.layer = 130 # Fica acima de tudo
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Fundo
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# Container Principal Centralizado na tela toda
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# Título
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.text = tr("MENU_CONFIG")
	main_vbox.add_child(title_label)
	
	# TabContainer Central
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_container.custom_minimum_size = Vector2(850, 520)
	main_vbox.add_child(tab_container)
	
	# Ordem das Abas: Gameplay, Controles, Vídeo
	_build_gameplay_tab()
	_build_controls_tab()
	_build_video_tab()
	
	_update_tab_titles()
	
	# BOTÃO VOLTAR
	back_btn = Button.new()
	back_btn.text = tr("BTN_BACK")
	back_btn.add_theme_font_size_override("font_size", 28)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.custom_minimum_size = Vector2(250, 50)
	back_btn.pressed.connect(_on_back_pressed)
	main_vbox.add_child(back_btn)
	
	tab_container.tab_changed.connect(func(_idx): _focus_first_item())
	_focus_first_item()

func _focus_first_item() -> void:
	await get_tree().process_frame # Espera um frame para garantir que os nós estão prontos
	if tab_container.current_tab == 0 and is_instance_valid(lang_option):
		lang_option.grab_focus()
	elif tab_container.current_tab == 1 and is_instance_valid(deadzone_slider):
		deadzone_slider.grab_focus()
	elif tab_container.current_tab == 2 and is_instance_valid(display_option):
		display_option.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			tab_container.current_tab = max(0, tab_container.current_tab - 1)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			tab_container.current_tab = min(tab_container.get_tab_count() - 1, tab_container.current_tab + 1)
			get_viewport().set_input_as_handled()
			
	if event.is_action_pressed("ui_cancel"):
		back_btn.pressed.emit()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if tab_container.current_tab == 1 and is_instance_valid(controls_scroll):
		var joy_y = Input.get_axis("ui_look_up", "ui_look_down")
		if abs(joy_y) > 0.1:
			controls_scroll.scroll_vertical += int(joy_y * 600 * delta)

func _update_tab_titles():
	tab_container.set_tab_title(0, tr("CONFIG_TAB_GAMEPLAY"))
	tab_container.set_tab_title(1, tr("CONFIG_TAB_CONTROLS"))
	tab_container.set_tab_title(2, tr("CONFIG_TAB_VIDEO"))

func _build_gameplay_tab():
	tab_gameplay = MarginContainer.new()
	tab_gameplay.name = "Gameplay"
	tab_gameplay.add_theme_constant_override("margin_left", 40)
	tab_gameplay.add_theme_constant_override("margin_right", 40)
	tab_gameplay.add_theme_constant_override("margin_top", 30)
	tab_gameplay.add_theme_constant_override("margin_bottom", 30)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	tab_gameplay.add_child(vbox)
	
	# Idioma
	lang_label = Label.new()
	lang_label.text = tr("CONFIG_LANGUAGE")
	lang_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(lang_label)
	
	lang_option = OptionButton.new()
	lang_option.add_theme_font_size_override("font_size", 20)
	lang_option.add_item(tr("CONFIG_LANG_EN"), 0)
	lang_option.add_item(tr("CONFIG_LANG_PT"), 1)
	if SaveManager.config["language"] == "en": lang_option.select(0)
	else: lang_option.select(1)
	lang_option.item_selected.connect(_on_lang_selected)
	vbox.add_child(lang_option)
	
	# Modo de Corrida
	run_label = Label.new()
	run_label.text = tr("CONFIG_RUN_MODE")
	run_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(run_label)
	
	run_option = OptionButton.new()
	run_option.add_theme_font_size_override("font_size", 20)
	run_option.add_item(tr("CONFIG_RUN_HOLD"), 0)
	run_option.add_item(tr("CONFIG_RUN_TOGGLE"), 1)
	if SaveManager.config["run_mode"] == "hold": run_option.select(0)
	else: run_option.select(1)
	run_option.item_selected.connect(_on_run_selected)
	vbox.add_child(run_option)
	
	tab_container.add_child(tab_gameplay)

func _build_controls_tab():
	tab_controls = MarginContainer.new()
	tab_controls.name = "Controles"
	tab_controls.add_theme_constant_override("margin_left", 40)
	tab_controls.add_theme_constant_override("margin_right", 40)
	tab_controls.add_theme_constant_override("margin_top", 20)
	tab_controls.add_theme_constant_override("margin_bottom", 20)
	
	controls_scroll = ScrollContainer.new()
	controls_scroll.custom_minimum_size = Vector2(770, 440)
	controls_scroll.follow_focus = true
	tab_controls.add_child(controls_scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 15)
	controls_scroll.add_child(vbox)
	
	# Deadzone
	deadzone_label = Label.new()
	deadzone_label.text = tr("CONFIG_DEADZONE")
	deadzone_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(deadzone_label)
	
	deadzone_slider = HSlider.new()
	deadzone_slider.min_value = 0.0
	deadzone_slider.max_value = 0.5
	deadzone_slider.step = 0.05
	deadzone_slider.value = SaveManager.config["deadzone"]
	deadzone_slider.value_changed.connect(func(v): SaveManager.config["deadzone"] = v; SaveManager.apply_configs())
	vbox.add_child(deadzone_slider)
	
	# Sensibilidade Normal
	sens_look_label = Label.new()
	sens_look_label.text = tr("CONFIG_SENS_LOOK")
	sens_look_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(sens_look_label)
	
	sens_look_slider = HSlider.new()
	sens_look_slider.min_value = 0.1
	sens_look_slider.max_value = 3.0
	sens_look_slider.step = 0.1
	sens_look_slider.value = SaveManager.config["sensitivity_look"]
	sens_look_slider.value_changed.connect(func(v): SaveManager.config["sensitivity_look"] = v)
	vbox.add_child(sens_look_slider)
	
	# Sensibilidade Mira
	sens_aim_label = Label.new()
	sens_aim_label.text = tr("CONFIG_SENS_AIM")
	sens_aim_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(sens_aim_label)
	
	sens_aim_slider = HSlider.new()
	sens_aim_slider.min_value = 0.1
	sens_aim_slider.max_value = 3.0
	sens_aim_slider.step = 0.1
	sens_aim_slider.value = SaveManager.config["sensitivity_aim"]
	sens_aim_slider.value_changed.connect(func(v): SaveManager.config["sensitivity_aim"] = v)
	vbox.add_child(sens_aim_slider)
	
	# Comandos
	commands_label = Label.new()
	commands_label.text = tr("CONFIG_MAPPED_CONTROLS")
	commands_label.add_theme_font_size_override("font_size", 18)
	commands_label.add_theme_color_override("font_color", Color(1, 1, 0))
	vbox.add_child(commands_label)
	
	controls_text = RichTextLabel.new()
	controls_text.custom_minimum_size = Vector2(0, 260)
	controls_text.bbcode_enabled = true
	controls_text.fit_content = true
	_update_controls_text()
	vbox.add_child(controls_text)
	
	tab_container.add_child(tab_controls)

func _update_controls_text():
	var is_pt = (SaveManager.config["language"] == "pt")
	var txt = ""
	if is_pt:
		txt += "[b]Maycow Normal[/b]\n"
		txt += "- Movimento: Analógico Esquerdo / WASD\n"
		txt += "- Câmera: Analógico Direito / Mouse\n"
		txt += "- Correr: L3 / Shift\n"
		txt += "- Menu/Inventário: Start / Tab\n"
		txt += "- Pegar Item: Quadrado / F\n"
		txt += "\n[b]Maycow Combate (Adicionais)[/b]\n"
		txt += "- Mirar: L2 / Botão Direito Mouse\n"
		txt += "- Atirar: R2 / Botão Esquerdo Mouse\n"
		txt += "- Golpe da Cogblade: aperte L1 / C\n"
		txt += "- Poderes da Cogblade: SEGURE L1 / C e escolha com o Analógico Esquerdo / Mouse\n"
		txt += "- Trocar Câmera: R3 / C\n"
	else:
		txt += "[b]Normal Maycow[/b]\n"
		txt += "- Movement: Left Stick / WASD\n"
		txt += "- Camera: Right Stick / Mouse\n"
		txt += "- Run: L3 / Shift\n"
		txt += "- Menu/Inventory: Start / Tab\n"
		txt += "- Pick Item: Square / F\n"
		txt += "\n[b]Combat Maycow (Additional)[/b]\n"
		txt += "- Aim: L2 / Right Mouse Button\n"
		txt += "- Shoot: R2 / Left Mouse Button\n"
		txt += "- Cogblade Slash: tap L1 / C\n"
		txt += "- Cogblade Powers: HOLD L1 / C and pick with the Left Stick / Mouse\n"
		txt += "- Switch Camera: R3 / C\n"
	controls_text.text = txt

func _build_video_tab():
	tab_video = MarginContainer.new()
	tab_video.name = "Vídeo"
	tab_video.add_theme_constant_override("margin_left", 40)
	tab_video.add_theme_constant_override("margin_right", 40)
	tab_video.add_theme_constant_override("margin_top", 30)
	tab_video.add_theme_constant_override("margin_bottom", 30)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	tab_video.add_child(vbox)
	
	# Display Mode
	display_label = Label.new()
	display_label.text = tr("CONFIG_DISPLAY_MODE")
	display_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(display_label)
	
	display_option = OptionButton.new()
	display_option.add_theme_font_size_override("font_size", 20)
	display_option.add_item(tr("CONFIG_DISPLAY_FULLSCREEN"), 0)
	display_option.add_item(tr("CONFIG_DISPLAY_WINDOWED"), 1)
	
	var cur_mode = SaveManager.config.get("display_mode", "windowed")
	if cur_mode == "fullscreen":
		display_option.select(0)
	else:
		display_option.select(1)
		
	display_option.item_selected.connect(_on_display_mode_selected)
	vbox.add_child(display_option)
	
	# Resolution
	res_label = Label.new()
	res_label.text = tr("CONFIG_RESOLUTION")
	res_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(res_label)
	
	resolution_option = OptionButton.new()
	resolution_option.add_theme_font_size_override("font_size", 20)
	resolution_option.add_item("720p", 0)
	resolution_option.add_item("1080p", 1)
	resolution_option.add_item("1440p", 2)
	
	var r_val = SaveManager.config["resolution"]
	if r_val == "720p": resolution_option.select(0)
	elif r_val == "1080p": resolution_option.select(1)
	else: resolution_option.select(2)
	
	resolution_option.item_selected.connect(_on_resolution_selected)
	vbox.add_child(resolution_option)
	
	# Brightness
	brightness_label = Label.new()
	brightness_label.text = tr("CONFIG_BRIGHTNESS")
	brightness_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(brightness_label)
	
	brightness_slider = HSlider.new()
	brightness_slider.min_value = 0.1
	brightness_slider.max_value = 2.0
	brightness_slider.step = 0.1
	brightness_slider.value = SaveManager.config["brightness"]
	brightness_slider.value_changed.connect(func(v): SaveManager.config["brightness"] = v; SaveManager.apply_configs())
	vbox.add_child(brightness_slider)
	
	tab_container.add_child(tab_video)

func _on_display_mode_selected(index: int):
	if index == 0:
		SaveManager.config["display_mode"] = "fullscreen"
	else:
		SaveManager.config["display_mode"] = "windowed"
	SaveManager.apply_configs()

func _on_resolution_selected(index: int):
	if index == 0: SaveManager.config["resolution"] = "720p"
	elif index == 1: SaveManager.config["resolution"] = "1080p"
	else: SaveManager.config["resolution"] = "1440p"
	SaveManager.apply_configs()

func _on_lang_selected(index: int) -> void:
	if index == 0: SaveManager.config["language"] = "en"
	else: SaveManager.config["language"] = "pt"
	SaveManager.apply_configs()
	
	title_label.text = tr("MENU_CONFIG")
	_update_tab_titles()
	
	if is_instance_valid(lang_label): lang_label.text = tr("CONFIG_LANGUAGE")
	lang_option.set_item_text(0, tr("CONFIG_LANG_EN"))
	lang_option.set_item_text(1, tr("CONFIG_LANG_PT"))
	
	if is_instance_valid(run_label): run_label.text = tr("CONFIG_RUN_MODE")
	run_option.set_item_text(0, tr("CONFIG_RUN_HOLD"))
	run_option.set_item_text(1, tr("CONFIG_RUN_TOGGLE"))
	
	if is_instance_valid(deadzone_label): deadzone_label.text = tr("CONFIG_DEADZONE")
	if is_instance_valid(sens_look_label): sens_look_label.text = tr("CONFIG_SENS_LOOK")
	if is_instance_valid(sens_aim_label): sens_aim_label.text = tr("CONFIG_SENS_AIM")
	if is_instance_valid(commands_label): commands_label.text = tr("CONFIG_MAPPED_CONTROLS")
	if is_instance_valid(controls_text): _update_controls_text()
	
	if is_instance_valid(display_label): display_label.text = tr("CONFIG_DISPLAY_MODE")
	if is_instance_valid(display_option):
		display_option.set_item_text(0, tr("CONFIG_DISPLAY_FULLSCREEN"))
		display_option.set_item_text(1, tr("CONFIG_DISPLAY_WINDOWED"))
	
	if is_instance_valid(res_label): res_label.text = tr("CONFIG_RESOLUTION")
	if is_instance_valid(brightness_label): brightness_label.text = tr("CONFIG_BRIGHTNESS")
	
	back_btn.text = tr("BTN_BACK")

func _on_run_selected(index: int) -> void:
	if index == 0: SaveManager.config["run_mode"] = "hold"
	else: SaveManager.config["run_mode"] = "toggle"

func _on_back_pressed() -> void:
	SaveManager.save_game()
	
	var pause_node = get_parent().get_node_or_null("Pause")
	if pause_node:
		pause_node.visible = true
		var config_btn = pause_node.get_node_or_null("Control/VSplitContainer/config")
		if config_btn: config_btn.grab_focus()
	queue_free()
