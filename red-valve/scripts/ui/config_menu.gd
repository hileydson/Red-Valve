extends CanvasLayer

var bg: ColorRect
var title_label: Label
var vbox: VBoxContainer

var lang_option: OptionButton
var aim_option: OptionButton
var back_btn: Button

func _ready() -> void:
	self.layer = 130 # Fica acima de tudo
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Fundo
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	add_child(bg)
	
	# Título
	title_label = Label.new()
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 40
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.text = tr("MENU_CONFIG")
	add_child(title_label)
	
	# Container Central
	vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.add_theme_constant_override("separation", 30)
	
	# O VBoxContainer precisa ser ajustado após criar para centralizar
	# Mas o PRESET_CENTER com anchors cuida disso automaticamente no Godot
	add_child(vbox)
	
	# ==========================================
	# IDIOMA
	# ==========================================
	var lang_label = Label.new()
	lang_label.text = tr("CONFIG_LANGUAGE")
	lang_label.add_theme_font_size_override("font_size", 24)
	lang_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lang_label)
	
	lang_option = OptionButton.new()
	lang_option.add_theme_font_size_override("font_size", 24)
	lang_option.add_item(tr("CONFIG_LANG_EN"), 0)
	lang_option.add_item(tr("CONFIG_LANG_PT"), 1)
	
	# Sincroniza com a config
	if SaveManager.config["language"] == "en":
		lang_option.select(0)
	else:
		lang_option.select(1)
		
	lang_option.item_selected.connect(_on_lang_selected)
	vbox.add_child(lang_option)
	
	# ==========================================
	# MIRA
	# ==========================================
	var aim_label = Label.new()
	aim_label.text = tr("CONFIG_AIM_MODE")
	aim_label.add_theme_font_size_override("font_size", 24)
	aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(aim_label)
	
	aim_option = OptionButton.new()
	aim_option.add_theme_font_size_override("font_size", 24)
	aim_option.add_item(tr("CONFIG_AIM_HOLD"), 0)
	aim_option.add_item(tr("CONFIG_AIM_TOGGLE"), 1)
	
	# Sincroniza com a config
	if SaveManager.config["aim_mode"] == "hold":
		aim_option.select(0)
	else:
		aim_option.select(1)
		
	aim_option.item_selected.connect(_on_aim_selected)
	vbox.add_child(aim_option)
	
	# ==========================================
	# BOTÃO VOLTAR
	# ==========================================
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer)
	
	back_btn = Button.new()
	back_btn.text = tr("BTN_BACK")
	back_btn.add_theme_font_size_override("font_size", 32)
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)
	
	# Corrige posição inicial
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Garante que o menu receba o foco para navegação por teclado/controle
	lang_option.grab_focus()
	
func _on_lang_selected(index: int) -> void:
	if index == 0:
		SaveManager.config["language"] = "en"
	else:
		SaveManager.config["language"] = "pt"
		
	# Aplica idioma imediatamente e atualiza os textos desta tela!
	TranslationServer.set_locale(SaveManager.config["language"])
	title_label.text = tr("MENU_CONFIG")
	vbox.get_child(0).text = tr("CONFIG_LANGUAGE")
	lang_option.set_item_text(0, tr("CONFIG_LANG_EN"))
	lang_option.set_item_text(1, tr("CONFIG_LANG_PT"))
	vbox.get_child(2).text = tr("CONFIG_AIM_MODE")
	aim_option.set_item_text(0, tr("CONFIG_AIM_HOLD"))
	aim_option.set_item_text(1, tr("CONFIG_AIM_TOGGLE"))
	back_btn.text = tr("BTN_BACK")

func _on_aim_selected(index: int) -> void:
	if index == 0:
		SaveManager.config["aim_mode"] = "hold"
	else:
		SaveManager.config["aim_mode"] = "toggle"

func _on_back_pressed() -> void:
	# Salva imediatamente no JSON as alterações feitas
	SaveManager.save_game()
	
	# Reabre a tela de pause original
	var pause_node = get_parent().get_node("Pause")
	if pause_node:
		pause_node.visible = true
		# Devolve o foco para o botão de Configuração no Pause Menu
		var config_btn = pause_node.get_node_or_null("Control/VSplitContainer/config")
		if config_btn: config_btn.grab_focus()
	queue_free()
