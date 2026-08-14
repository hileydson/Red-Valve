extends CanvasLayer

var bg: ColorRect
var title_label: Label
var tab_container: TabContainer
var back_btn: Button

# Controls Tab
var deadzone_slider: HSlider
var sens_look_slider: HSlider
var sens_aim_slider: HSlider
var controls_text: RichTextLabel

# Video Tab
var resolution_option: OptionButton
var brightness_slider: HSlider

# Gameplay Tab
var lang_option: OptionButton
var run_option: OptionButton

func _ready() -> void:
	self.layer = 130 # Fica acima de tudo
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Fundo
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.95)
	add_child(bg)
	
	# Título
	title_label = Label.new()
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 30
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.text = tr("MENU_CONFIG")
	add_child(title_label)
	
	# TabContainer Central
	tab_container = TabContainer.new()
	tab_container.set_anchors_preset(Control.PRESET_CENTER)
	tab_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tab_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	tab_container.custom_minimum_size = Vector2(800, 500)
	# Deslocar para cima do botão Voltar
	tab_container.position -= Vector2(400, 250) + Vector2(0, 30)
	add_child(tab_container)
	
	_build_controls_tab()
	_build_video_tab()
	_build_gameplay_tab()
	
	# BOTÃO VOLTAR
	back_btn = Button.new()
	back_btn.text = tr("BTN_BACK")
	back_btn.add_theme_font_size_override("font_size", 32)
	back_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	back_btn.grow_vertical = Control.GROW_DIRECTION_END
	back_btn.position = Vector2(-100, -80)
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	
	tab_container.grab_focus()

func _build_controls_tab():
	var tab = ScrollContainer.new()
	tab.name = "Controles"
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vbox.custom_minimum_size = Vector2(760, 0)
	vbox.add_theme_constant_override("separation", 20)
	tab.add_child(vbox)
	
	# Espaçador
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sp1)
	
	# Deadzone
	var d_lbl = Label.new()
	d_lbl.text = "Deadzone (Analógico)"
	vbox.add_child(d_lbl)
	deadzone_slider = HSlider.new()
	deadzone_slider.min_value = 0.0
	deadzone_slider.max_value = 0.5
	deadzone_slider.step = 0.05
	deadzone_slider.value = SaveManager.config["deadzone"]
	deadzone_slider.value_changed.connect(func(v): SaveManager.config["deadzone"] = v; SaveManager.apply_configs())
	vbox.add_child(deadzone_slider)
	
	# Sensibilidade Normal
	var sl_lbl = Label.new()
	sl_lbl.text = "Sensibilidade (Olhar/Movimentação)"
	vbox.add_child(sl_lbl)
	sens_look_slider = HSlider.new()
	sens_look_slider.min_value = 0.1
	sens_look_slider.max_value = 3.0
	sens_look_slider.step = 0.1
	sens_look_slider.value = SaveManager.config["sensitivity_look"]
	sens_look_slider.value_changed.connect(func(v): SaveManager.config["sensitivity_look"] = v)
	vbox.add_child(sens_look_slider)
	
	# Sensibilidade Mira
	var sa_lbl = Label.new()
	sa_lbl.text = "Sensibilidade (Mira/Zoom)"
	vbox.add_child(sa_lbl)
	sens_aim_slider = HSlider.new()
	sens_aim_slider.min_value = 0.1
	sens_aim_slider.max_value = 3.0
	sens_aim_slider.step = 0.1
	sens_aim_slider.value = SaveManager.config["sensitivity_aim"]
	sens_aim_slider.value_changed.connect(func(v): SaveManager.config["sensitivity_aim"] = v)
	vbox.add_child(sens_aim_slider)
	
	# Comandos
	var c_lbl = Label.new()
	c_lbl.text = "\nComandos Mapeados:"
	c_lbl.add_theme_color_override("font_color", Color(1,1,0))
	vbox.add_child(c_lbl)
	
	controls_text = RichTextLabel.new()
	controls_text.custom_minimum_size = Vector2(0, 300)
	controls_text.bbcode_enabled = true
	var txt = ""
	txt += "[b]Maycow Normal[/b]\n"
	txt += "- Movimento: Analógico Esquerdo / WASD\n"
	txt += "- Câmera: Analógico Direito / Mouse\n"
	txt += "- Correr: L3 / Shift\n"
	txt += "- Menu/Inventário: Start / Tab\n"
	txt += "- Pegar Item: Quadrado / F\n"
	txt += "\n[b]Maycow Combate (Adicionais)[/b]\n"
	txt += "- Mirar: L2 / Botão Direito Mouse\n"
	txt += "- Atirar: R2 / Botão Esquerdo Mouse\n"
	txt += "- Ultimate (Cogblade): Triângulo / Q\n"
	txt += "- Trocar Câmera: R3 / C\n"
	controls_text.text = txt
	vbox.add_child(controls_text)
	
	tab_container.add_child(tab)

func _build_video_tab():
	var tab = VBoxContainer.new()
	tab.name = "Vídeo"
	tab.add_theme_constant_override("separation", 25)
	
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 10)
	tab.add_child(sp1)
	
	# Resolution
	var r_lbl = Label.new()
	r_lbl.text = "Resolução"
	tab.add_child(r_lbl)
	resolution_option = OptionButton.new()
	resolution_option.add_item("720p", 0)
	resolution_option.add_item("1080p", 1)
	resolution_option.add_item("1440p", 2)
	
	var r_val = SaveManager.config["resolution"]
	if r_val == "720p": resolution_option.select(0)
	elif r_val == "1080p": resolution_option.select(1)
	else: resolution_option.select(2)
	
	resolution_option.item_selected.connect(_on_resolution_selected)
	tab.add_child(resolution_option)
	
	# Brightness
	var b_lbl = Label.new()
	b_lbl.text = "Brilho Global"
	tab.add_child(b_lbl)
	brightness_slider = HSlider.new()
	brightness_slider.min_value = 0.1
	brightness_slider.max_value = 2.0
	brightness_slider.step = 0.1
	brightness_slider.value = SaveManager.config["brightness"]
	brightness_slider.value_changed.connect(func(v): SaveManager.config["brightness"] = v; SaveManager.apply_configs())
	tab.add_child(brightness_slider)
	
	tab_container.add_child(tab)

func _on_resolution_selected(index: int):
	if index == 0: SaveManager.config["resolution"] = "720p"
	elif index == 1: SaveManager.config["resolution"] = "1080p"
	else: SaveManager.config["resolution"] = "1440p"
	SaveManager.apply_configs()

func _build_gameplay_tab():
	var tab = VBoxContainer.new()
	tab.name = "Gameplay"
	tab.add_theme_constant_override("separation", 25)
	
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 10)
	tab.add_child(sp1)
	
	# Idioma
	var l_lbl = Label.new()
	l_lbl.text = tr("CONFIG_LANGUAGE")
	tab.add_child(l_lbl)
	lang_option = OptionButton.new()
	lang_option.add_item(tr("CONFIG_LANG_EN"), 0)
	lang_option.add_item(tr("CONFIG_LANG_PT"), 1)
	if SaveManager.config["language"] == "en": lang_option.select(0)
	else: lang_option.select(1)
	lang_option.item_selected.connect(_on_lang_selected)
	tab.add_child(lang_option)
	
	# Modo de Corrida
	var run_lbl = Label.new()
	run_lbl.text = "Modo de Corrida"
	tab.add_child(run_lbl)
	run_option = OptionButton.new()
	run_option.add_item("Segurar para Correr (Hold)", 0)
	run_option.add_item("Apertar para Correr (Toggle)", 1)
	if SaveManager.config["run_mode"] == "hold": run_option.select(0)
	else: run_option.select(1)
	run_option.item_selected.connect(_on_run_selected)
	tab.add_child(run_option)
	
	tab_container.add_child(tab)

func _on_lang_selected(index: int) -> void:
	if index == 0: SaveManager.config["language"] = "en"
	else: SaveManager.config["language"] = "pt"
	SaveManager.apply_configs()
	
	title_label.text = tr("MENU_CONFIG")
	tab_container.get_child(2).get_child(1).text = tr("CONFIG_LANGUAGE") # Atualiza o label do idioma na aba
	lang_option.set_item_text(0, tr("CONFIG_LANG_EN"))
	lang_option.set_item_text(1, tr("CONFIG_LANG_PT"))
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
