extends CanvasLayer

var tabs = ["MENU_TAB_INVENTORY", "MENU_TAB_MAP", "MENU_TAB_FILES"]
var current_tab = 0
var current_slot = 0 # 0 a 15 (grid 4x4)
var grid_cols = 4
var grid_rows = 4

# Referências
var bg: ColorRect
var tab_label: Label
var carousel_container: Control
var carousel_labels = []
var carousel_tween: Tween
var item_name_label: Label
var item_desc_label: Label
var item_icon_preview: TextureRect
var grid_container: GridContainer
var slot_panels = []

# Action Menu
var action_menu_panel: PanelContainer
var action_menu_vbox: VBoxContainer
var action_options = []
var action_menu_open = false
var action_menu_index = 0
var current_item_selected = null

func _ready() -> void:
	self.layer = 129 # Acima das mensagens do jogo (128) e no mesmo nível do Pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# Fundo
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	add_child(bg)
	
	# Header Tabs Carousel
	tab_label = Label.new() # Mantem a var pro resto nao quebrar caso algo acesse, mas deixamos invisivel
	tab_label.visible = false
	add_child(tab_label)
	
	carousel_container = Control.new()
	carousel_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	carousel_container.offset_top = 40
	add_child(carousel_container)
	
	for i in range(tabs.size()):
		var lbl = Label.new()
		lbl.text = tr(tabs[i])
		lbl.add_theme_font_size_override("font_size", 40)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		carousel_container.add_child(lbl)
		carousel_labels.append(lbl)
	
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
		qtd.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		qtd.grow_vertical = Control.GROW_DIRECTION_BEGIN
		qtd.offset_right = -5
		qtd.offset_bottom = -5
		qtd.add_theme_font_size_override("font_size", 18)
		slot.add_child(qtd)
		
		# Indicador Equipado
		var equip = Label.new()
		equip.name = "Equip"
		equip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		equip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		equip.grow_vertical = Control.GROW_DIRECTION_BEGIN
		equip.offset_right = -5
		equip.offset_bottom = -25
		equip.add_theme_font_size_override("font_size", 18)
		equip.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		equip.text = "E"
		equip.visible = false
		slot.add_child(equip)
		
		grid_container.add_child(slot)
		slot_panels.append(slot)
		
	_create_action_menu()
	update_ui()

func _create_action_menu() -> void:
	action_menu_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.8, 0.8, 0.8, 1)
	action_menu_panel.add_theme_stylebox_override("panel", style)
	action_menu_panel.visible = false
	
	action_menu_vbox = VBoxContainer.new()
	action_menu_panel.add_child(action_menu_vbox)
	add_child(action_menu_panel)
	
	var options = ["Usar", "Equipar", "Inspecionar"]
	for opt in options:
		var lbl = Label.new()
		lbl.text = opt
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.set_custom_minimum_size(Vector2(150, 30))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_menu_vbox.add_child(lbl)
		action_options.append(lbl)

func update_ui() -> void:
	# Animação do Carrossel
	if carousel_tween: carousel_tween.kill()
	carousel_tween = create_tween().set_parallel(true)
	var center_x = get_viewport().get_visible_rect().size.x / 2.0
	
	for i in range(carousel_labels.size()):
		var lbl = carousel_labels[i]
		var dist = i - current_tab
		
		# Ajusta pra fazer a roda girar infinito se quiser (opcional)
		if dist > tabs.size() / 2: dist -= tabs.size()
		elif dist < -tabs.size() / 2: dist += tabs.size()
		
		var target_x = center_x - (lbl.size.x / 2.0) + (dist * 300.0)
		var target_scale = Vector2(1.0, 1.0) if dist == 0 else Vector2(0.6, 0.6)
		var target_alpha = 1.0 if dist == 0 else 0.3
		var target_color = Color(1, 1, 0) if dist == 0 else Color(1, 1, 1)
		
		carousel_tween.tween_property(lbl, "position:x", target_x, 0.2).set_trans(Tween.TRANS_CUBIC)
		carousel_tween.tween_property(lbl, "scale", target_scale, 0.2).set_trans(Tween.TRANS_CUBIC)
		carousel_tween.tween_property(lbl, "modulate:a", target_alpha, 0.2)
		lbl.add_theme_color_override("font_color", target_color)
		
	if current_tab == 0:
		grid_container.visible = true
		_render_inventory()
	else:
		grid_container.visible = false
		item_name_label.text = ""
		item_desc_label.text = ""
		item_icon_preview.texture = null
		
	if action_menu_open:
		_render_action_menu()

func _render_inventory() -> void:
	# Limpa slots
	for i in range(slot_panels.size()):
		var slot = slot_panels[i]
		slot.get_node("Icon").texture = null
		slot.get_node("Qtd").text = ""
		slot.get_node("Equip").visible = false
		var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
		if i == current_slot and not action_menu_open:
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
				slot.get_node("Qtd").text = str(int(item_data["amount"]))
				
			if SaveManager.is_equipped(item_data["id"]):
				slot.get_node("Equip").visible = true
				
			if i == current_slot:
				item_to_show = db_info
				current_item_selected = item_data
				item_icon_preview.texture = tex
				
	if item_to_show:
		item_name_label.text = tr(item_to_show["name_key"])
		item_desc_label.text = tr(item_to_show["desc_key"])
	else:
		item_name_label.text = ""
		item_desc_label.text = ""
		item_icon_preview.texture = null
		current_item_selected = null

func _render_action_menu() -> void:
	if not current_item_selected:
		close_action_menu()
		return
		
	var db_info = SaveManager.item_db.get(current_item_selected["id"])
	if not db_info: return
	
	action_menu_panel.visible = true
	var slot = slot_panels[current_slot]
	action_menu_panel.global_position = slot.global_position + Vector2(slot.size.x / 2, slot.size.y / 2)
	
	# Usar [0], Equipar [1], Inspecionar [2]
	var type = db_info.get("type", "")
	
	var opts = ["Usar", "Equipar", "Inspecionar"]
	if SaveManager.is_equipped(current_item_selected["id"]):
		opts[1] = "Remover"
	for i in range(3):
		var lbl = action_options[i]
		var enabled = false
		
		if i == 0 and type == "usable": enabled = true
		if i == 1 and type == "equippable": enabled = true
		if i == 2 and type == "inspectable": enabled = true
		
		if i == 1 and current_item_selected["id"] == "cogblade": enabled = false # Cogblade nao desequipa
		
		if i == action_menu_index:
			lbl.text = opts[i]
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0) if enabled else Color(0.7, 0.7, 0.0))
		else:
			lbl.text = opts[i]
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8) if enabled else Color(0.4, 0.4, 0.4))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu_game") or event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled()
		close_menu()
		return
		
	if action_menu_open:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_dash"):
			close_action_menu()
		elif event.is_action_pressed("ui_down"):
			action_menu_index = (action_menu_index + 1) % 3
			update_ui()
		elif event.is_action_pressed("ui_up"):
			action_menu_index = (action_menu_index - 1 + 3) % 3
			update_ui()
		elif event.is_action_pressed("ui_accept"):
			execute_action()
		return
		
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_dash"):
		get_viewport().set_input_as_handled()
		close_menu()
		return

	if event.is_action_pressed("ui_r1"):
		current_tab = (current_tab - 1 + tabs.size()) % tabs.size()
		update_ui()
	elif event.is_action_pressed("ui_l1"):
		current_tab = (current_tab + 1) % tabs.size()
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
		elif event.is_action_pressed("ui_accept"):
			if current_item_selected != null:
				open_action_menu()
				
		if moved:
			update_ui()

func open_action_menu() -> void:
	action_menu_open = true
	action_menu_index = 0
	update_ui()

func close_action_menu() -> void:
	action_menu_open = false
	action_menu_panel.visible = false
	update_ui()

func execute_action() -> void:
	if not current_item_selected: return
	
	var item_id = current_item_selected["id"]
	var db_info = SaveManager.item_db.get(item_id)
	var type = db_info.get("type", "")
	
	# Usar [0]
	if action_menu_index == 0 and type == "usable":
		SaveManager.remove_item_amount(item_id, 1)
		close_action_menu()
		
	# Equipar [1]
	elif action_menu_index == 1 and type == "equippable":
		if item_id == "cogblade":
			pass # Não pode desequipar
		else:
			if SaveManager.is_equipped(item_id):
				SaveManager.unequip_item(item_id)
			else:
				SaveManager.equip_item(item_id)
			# Atualiza o UI do player imediatamente
			get_tree().call_group("player", "update_ammo_ui")
		close_action_menu()
		
	# Inspecionar [2]
	elif action_menu_index == 2 and type == "inspectable":
		# No futuro abriremos o objeto 3D aqui
		close_action_menu()

func close_menu() -> void:
	await get_tree().process_frame
	get_tree().paused = false
	get_tree().call_group("player", "prevent_dash_leak")
	get_tree().call_group("player", "update_equipment_visuals")
	queue_free()
