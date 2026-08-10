extends CanvasLayer

var tabs = ["MENU_TAB_INVENTORY", "MENU_TAB_MAP", "MENU_TAB_FILES"]
var current_tab = 0
var current_slot = 0 # 0 a 15 (grid 4x4)
var grid_cols = 4
var grid_rows = 4

# Referências
var bg: ColorRect
var tab_label: Label
var item_name_label: Label
var item_desc_label: Label
var item_icon_preview: TextureRect
var grid_container: GridContainer
var slot_panels = []

func _ready() -> void:
	self.layer = 127 # Abaixo do Game Over (128)
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# Fundo
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	add_child(bg)
	
	# Header Tabs
	tab_label = Label.new()
	tab_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tab_label.offset_top = 20
	tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_label.add_theme_font_size_override("font_size", 40)
	add_child(tab_label)
	
	# Painel Esquerdo (Info do Item)
	var left_vbox = VBoxContainer.new()
	left_vbox.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_vbox.offset_left = 150
	left_vbox.offset_top = 250
	left_vbox.offset_right = 750
	left_vbox.offset_bottom = -100
	add_child(left_vbox)
	
	item_icon_preview = TextureRect.new()
	item_icon_preview.custom_minimum_size = Vector2(300, 300)
	item_icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_vbox.add_child(item_icon_preview)
	
	item_name_label = Label.new()
	item_name_label.add_theme_font_size_override("font_size", 32)
	left_vbox.add_child(item_name_label)
	
	item_desc_label = Label.new()
	item_desc_label.add_theme_font_size_override("font_size", 20)
	item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	left_vbox.add_child(item_desc_label)
	
	# Painel Direito (Grid de Itens)
	grid_container = GridContainer.new()
	grid_container.columns = grid_cols
	grid_container.add_theme_constant_override("h_separation", 15)
	grid_container.add_theme_constant_override("v_separation", 15)
	grid_container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	grid_container.offset_left = -700
	grid_container.offset_top = 250
	grid_container.offset_right = -150
	grid_container.offset_bottom = -100
	add_child(grid_container)
	
	for i in range(grid_cols * grid_rows):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(100, 100)
		
		# Estilo do painel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color(0.3, 0.3, 0.3, 1)
		slot.add_theme_stylebox_override("panel", style)
		
		# Icone
		var tex = TextureRect.new()
		tex.name = "Icon"
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.add_child(tex)
		
		# Quantidade
		var qtd = Label.new()
		qtd.name = "Qtd"
		qtd.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		qtd.add_theme_font_size_override("font_size", 18)
		slot.add_child(qtd)
		
		grid_container.add_child(slot)
		slot_panels.append(slot)
		
	update_ui()

func update_ui() -> void:
	tab_label.text = "< L1 " + tr(tabs[current_tab]) + " R1 >"
	
	if current_tab == 0:
		grid_container.visible = true
		_render_inventory()
	else:
		grid_container.visible = false
		item_name_label.text = ""
		item_desc_label.text = ""
		item_icon_preview.texture = null

func _render_inventory() -> void:
	# Limpa slots
	for i in range(slot_panels.size()):
		var slot = slot_panels[i]
		slot.get_node("Icon").texture = null
		slot.get_node("Qtd").text = ""
		var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
		if i == current_slot:
			style.border_color = Color(1.0, 1.0, 1.0, 1.0)
			style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
		else:
			style.border_color = Color(0.3, 0.3, 0.3, 1.0)
			style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
			
	# Preenche itens
	var inv = SaveManager.inventory
	var item_to_show = null
	
	for i in range(inv.size()):
		if i >= slot_panels.size(): break
		var item_data = inv[i]
		var db_info = SaveManager.item_db.get(item_data["id"])
		if db_info:
			var slot = slot_panels[i]
			var tex = load(db_info["icon_path"]) if db_info.has("icon_path") else null
			slot.get_node("Icon").texture = tex
			
			if db_info["stackable"] and item_data["amount"] > 1:
				slot.get_node("Qtd").text = str(item_data["amount"])
				
			if i == current_slot:
				item_to_show = db_info
				item_icon_preview.texture = tex
				
	if item_to_show:
		item_name_label.text = tr(item_to_show["name_key"])
		item_desc_label.text = tr(item_to_show["desc_key"])
	else:
		item_name_label.text = ""
		item_desc_label.text = ""
		item_icon_preview.texture = null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu_game") or event.is_action_pressed("ui_cancel"):
		close_menu()
		
	elif event.is_action_pressed("ui_r1"):
		current_tab = (current_tab + 1) % tabs.size()
		update_ui()
	elif event.is_action_pressed("ui_l1"):
		current_tab = (current_tab - 1 + tabs.size()) % tabs.size()
		update_ui()
		
	elif current_tab == 0:
		var moved = false
		if event.is_action_pressed("ui_right"):
			if current_slot % grid_cols < grid_cols - 1:
				current_slot += 1
				moved = true
		elif event.is_action_pressed("ui_left"):
			if current_slot % grid_cols > 0:
				current_slot -= 1
				moved = true
		elif event.is_action_pressed("ui_down"):
			if current_slot + grid_cols < grid_cols * grid_rows:
				current_slot += grid_cols
				moved = true
		elif event.is_action_pressed("ui_up"):
			if current_slot - grid_cols >= 0:
				current_slot -= grid_cols
				moved = true
				
		if moved:
			update_ui()

func close_menu() -> void:
	get_tree().paused = false
	queue_free()
