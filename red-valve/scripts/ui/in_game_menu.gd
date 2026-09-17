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

# ==============================================================================
# ATALHOS DO DIRECIONAL
# ==============================================================================
# Só um item equipável fica equipado por vez (SaveManager.EQUIPAMENTO_EXCLUSIVO),
# então trocar de item é uma coisa que o jogo vai pedir no meio da ação. A ação
# "Atalho" amarra o item a uma direção do D-pad; fora do menu, quem lê é o
# `player_atalhos.gd`.
#
# O submenu é uma lista de 5: as quatro direções mais "remover". Cada direção
# mostra o que já está amarrada nela, porque escolher às cegas e descobrir
# depois que se sobrescreveu o outro item é o erro óbvio aqui.
const DIRECOES_ATALHO := ["esquerda", "cima", "direita", "baixo"]
const SETAS := {"esquerda": "←", "cima": "↑", "direita": "→", "baixo": "↓"}
const ROTULOS_ATALHO := {
	"esquerda": "SHORTCUT_LEFT",
	"cima": "SHORTCUT_UP",
	"direita": "SHORTCUT_RIGHT",
	"baixo": "SHORTCUT_DOWN",
}

var atalho_panel: PanelContainer
var atalho_vbox: VBoxContainer
var atalho_options = []
var atalho_open = false
var atalho_index = 0

# Aba MAPA (índice 1 em `tabs`). O painel se vira sozinho: lê o citymap.json,
# acha o player pelo grupo e decide se há mapa nesta fase.
const TAB_MAPA := 1
const MAPA_PAINEL := preload("res://scenes/ui/mapa_painel.tscn")
var mapa_painel: Control

# Aba ARQUIVOS (índice 2 em `tabs`). Mesmo acordo da aba do mapa: o painel se
# monta sozinho e só recebe `ativar()`/`desativar()` quando entra e sai de foco.
const TAB_ARQUIVOS := 2
var arquivos_painel: ArquivosPainel

func _ready() -> void:
	self.layer = 150 # Acima das mensagens do jogo e no mesmo nível do Pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/entrar_menu.mp3")

	# reabre na aba em que o jogador estava. O menu é destruído ao fechar, por
	# isso a lembrança mora em GlobalEvents e não aqui.
	current_tab = clampi(GlobalEvents.menu_ultima_aba, 0, tabs.size() - 1)
	
	# Fundo
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if action_menu_open:
				close_action_menu()
	)
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
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		var tab_idx = i
		lbl.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if current_tab != tab_idx:
					GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/sair_menu.mp3")
					current_tab = tab_idx
					if action_menu_open:
						close_action_menu()
					update_ui()
		)
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
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		
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
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		qtd.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		equip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(equip)

		# Indicador de atalho: a seta do direcional em que o item está amarrado.
		# Fica no canto de CIMA, longe do "E" de equipado e da quantidade — são
		# três informações diferentes no mesmo quadradinho de 100 px.
		var atalho = Label.new()
		atalho.name = "Atalho"
		atalho.set_anchors_preset(Control.PRESET_TOP_LEFT)
		atalho.offset_left = 6
		atalho.offset_top = 2
		atalho.add_theme_font_size_override("font_size", 20)
		atalho.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		atalho.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		atalho.add_theme_constant_override("outline_size", 4)
		atalho.visible = false
		atalho.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(atalho)
		
		var slot_idx = i
		slot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if current_slot == slot_idx:
					if current_item_selected != null and not action_menu_open:
						open_action_menu()
					elif action_menu_open:
						close_action_menu()
				else:
					GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
					current_slot = slot_idx
					if action_menu_open:
						close_action_menu()
					update_ui()
		)
		
		grid_container.add_child(slot)
		slot_panels.append(slot)
		
	# Painel do mapa: ocupa a área central, abaixo do carrossel de abas
	mapa_painel = MAPA_PAINEL.instantiate()
	mapa_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	mapa_painel.offset_left = 150
	mapa_painel.offset_top = 200
	mapa_painel.offset_right = -150
	mapa_painel.offset_bottom = -70
	mapa_painel.visible = false
	add_child(mapa_painel)

	# Painel dos arquivos: mesma área central do mapa
	arquivos_painel = ArquivosPainel.new()
	arquivos_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	arquivos_painel.offset_left = 150
	arquivos_painel.offset_top = 200
	arquivos_painel.offset_right = -150
	arquivos_painel.offset_bottom = -70
	arquivos_painel.visible = false
	add_child(arquivos_painel)

	_create_action_menu()
	_create_atalho_menu()
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
	action_menu_panel.z_index = 20
	
	action_menu_vbox = VBoxContainer.new()
	action_menu_panel.add_child(action_menu_vbox)
	add_child(action_menu_panel)
	
	var options = [tr("ACTION_USE"), tr("ACTION_EQUIP"), tr("ACTION_INSPECT"), tr("ACTION_SHORTCUT")]
	for i in range(options.size()):
		var opt_idx = i
		var btn = Button.new()
		btn.text = options[i]
		btn.flat = true
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 22)
		btn.set_custom_minimum_size(Vector2(160, 36))
		
		btn.mouse_entered.connect(func():
			if action_menu_index != opt_idx:
				GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			action_menu_index = opt_idx
			_render_action_menu()
		)
		btn.pressed.connect(func():
			action_menu_index = opt_idx
			execute_action()
		)
		
		action_menu_vbox.add_child(btn)
		action_options.append(btn)

## O submenu do atalho: título, as quatro direções e "remover".
##
## Nasce escondido e vive por cima do menu de ação (z_index maior), no mesmo
## canto do slot — assim o jogador não perde de vista de que item se trata.
func _create_atalho_menu() -> void:
	atalho_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.97)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(1.0, 0.85, 0.3, 1)
	atalho_panel.add_theme_stylebox_override("panel", style)
	atalho_panel.visible = false
	atalho_panel.z_index = 30

	atalho_vbox = VBoxContainer.new()
	atalho_panel.add_child(atalho_vbox)
	add_child(atalho_panel)

	var titulo = Label.new()
	titulo.name = "Titulo"
	titulo.text = tr("SHORTCUT_TITLE")
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	atalho_vbox.add_child(titulo)

	var dica = Label.new()
	dica.text = tr("SHORTCUT_HINT")
	dica.add_theme_font_size_override("font_size", 13)
	dica.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	atalho_vbox.add_child(dica)

	for i in range(DIRECOES_ATALHO.size() + 1):
		var opt_idx = i
		var btn = Button.new()
		btn.flat = true
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 20)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.set_custom_minimum_size(Vector2(260, 34))
		btn.mouse_entered.connect(func():
			if atalho_index != opt_idx:
				GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			atalho_index = opt_idx
			_render_atalho_menu()
		)
		btn.pressed.connect(func():
			atalho_index = opt_idx
			_executar_atalho()
		)
		atalho_vbox.add_child(btn)
		atalho_options.append(btn)


func update_ui() -> void:
	GlobalEvents.menu_ultima_aba = current_tab
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

	if mapa_painel:
		var no_mapa: bool = current_tab == TAB_MAPA
		mapa_painel.visible = no_mapa
		if no_mapa:
			mapa_painel.ativar()
		else:
			mapa_painel.desativar()

	if arquivos_painel:
		var nos_arquivos: bool = current_tab == TAB_ARQUIVOS
		arquivos_painel.visible = nos_arquivos
		if nos_arquivos:
			arquivos_painel.ativar()
		else:
			arquivos_painel.desativar()
		
	if action_menu_open:
		_render_action_menu()
	if atalho_open:
		_render_atalho_menu()

func _render_inventory() -> void:
	# Limpa slots
	for i in range(slot_panels.size()):
		var slot = slot_panels[i]
		slot.get_node("Icon").texture = null
		slot.get_node("Qtd").text = ""
		slot.get_node("Equip").visible = false
		slot.get_node("Atalho").visible = false
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

			var direcao_atalho: String = SaveManager.atalho_do_item(item_data["id"])
			if direcao_atalho != "":
				var rotulo_atalho = slot.get_node("Atalho") as Label
				rotulo_atalho.text = String(SETAS.get(direcao_atalho, ""))
				rotulo_atalho.visible = true

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
	action_menu_panel.move_to_front()
	var slot = slot_panels[current_slot]
	action_menu_panel.global_position = slot.global_position + Vector2(slot.size.x / 2, slot.size.y / 2)
	
	# Usar [0], Equipar [1], Inspecionar [2], Atalho [3]
	var type = db_info.get("type", "")
	var item_id = current_item_selected["id"]
	var equipavel: bool = SaveManager.pode_equipar(item_id)

	var opts = [tr("ACTION_USE"), tr("ACTION_EQUIP"), tr("ACTION_INSPECT"), tr("ACTION_SHORTCUT")]
	if SaveManager.is_equipped(item_id):
		opts[1] = tr("ACTION_UNEQUIP")
	# O atalho já amarrado aparece no próprio nome da opção: sem isso o jogador
	# tinha de entrar no submenu só para descobrir onde tinha posto o item.
	var atalho_atual: String = SaveManager.atalho_do_item(item_id)
	if atalho_atual != "":
		opts[3] = "%s  %s" % [tr("ACTION_SHORTCUT"), SETAS.get(atalho_atual, "")]
	for i in range(action_options.size()):
		var btn = action_options[i] as Button
		var enabled = false

		if i == 0 and type == "usable": enabled = true
		if i == 1 and equipavel: enabled = true
		if i == 2 and type == "inspectable": enabled = true
		# Atalho só faz sentido para o que se equipa: ele existe para TROCAR o
		# item equipado sem abrir o menu.
		if i == 3 and equipavel: enabled = true

		if i == 1 and item_id == "cogblade": enabled = false # Cogblade nao desequipa

		btn.disabled = not enabled
		
		var style = StyleBoxFlat.new()
		
		if i == action_menu_index:
			btn.text = "> " + opts[i]
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0) if enabled else Color(0.7, 0.7, 0.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0) if enabled else Color(0.7, 0.7, 0.0))
			btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0) if enabled else Color(0.7, 0.7, 0.0))
			style.bg_color = Color(1, 1, 1, 0.2)
		else:
			btn.text = "  " + opts[i]
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8) if enabled else Color(0.4, 0.4, 0.4))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8) if enabled else Color(0.4, 0.4, 0.4))
			btn.add_theme_color_override("font_focus_color", Color(0.8, 0.8, 0.8) if enabled else Color(0.4, 0.4, 0.4))
			style.bg_color = Color(0, 0, 0, 0)
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_stylebox_override("disabled", style)


func _render_atalho_menu() -> void:
	if not current_item_selected:
		close_atalho_menu()
		return

	var item_id = current_item_selected["id"]
	atalho_panel.visible = true
	atalho_panel.move_to_front()
	# O menu de ação sai da frente: os dois nascem no mesmo canto do slot, e um
	# por cima do outro vira uma sopa de palavras meio transparentes.
	action_menu_panel.visible = false
	var slot = slot_panels[current_slot]
	atalho_panel.global_position = slot.global_position + Vector2(slot.size.x / 2, slot.size.y / 2)

	for i in range(atalho_options.size()):
		var btn = atalho_options[i] as Button
		var texto := ""
		if i < DIRECOES_ATALHO.size():
			var direcao: String = DIRECOES_ATALHO[i]
			texto = "%s  %s" % [SETAS[direcao], tr(ROTULOS_ATALHO[direcao])]
			# Quem já mora nesta direção aparece ao lado: escolher às cegas e só
			# depois descobrir que sobrescreveu o outro item é o erro fácil aqui.
			var ocupante: String = SaveManager.item_do_atalho(direcao)
			if ocupante != "":
				var nome_chave: String = SaveManager.item_db.get(ocupante, {}).get("name_key", "")
				texto += "   [%s]" % tr(nome_chave)
		else:
			texto = tr("SHORTCUT_CLEAR")
			btn.disabled = SaveManager.atalho_do_item(item_id) == ""

		var style = StyleBoxFlat.new()
		if i == atalho_index:
			btn.text = "> " + texto
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.3))
			style.bg_color = Color(1, 1, 1, 0.15)
		else:
			btn.text = "  " + texto
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.85))
			style.bg_color = Color(0, 0, 0, 0)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_stylebox_override("disabled", style)


func open_atalho_menu() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	atalho_open = true
	# Abre já em cima da direção em que o item está, se estiver em alguma.
	var atual: String = SaveManager.atalho_do_item(current_item_selected["id"])
	atalho_index = DIRECOES_ATALHO.find(atual) if atual != "" else 0
	if atalho_index < 0:
		atalho_index = 0
	_render_atalho_menu()


func close_atalho_menu() -> void:
	if not atalho_open:
		return
	atalho_open = false
	if is_instance_valid(atalho_panel):
		atalho_panel.visible = false
	# Devolve o menu de ação, se ele ainda for pra estar aberto (quem fechou os
	# dois de uma vez já apagou `action_menu_open` antes de chegar aqui).
	if action_menu_open and is_instance_valid(action_menu_panel):
		action_menu_panel.visible = true


func _executar_atalho() -> void:
	if not current_item_selected:
		close_atalho_menu()
		return

	var item_id = current_item_selected["id"]
	if atalho_index >= DIRECOES_ATALHO.size():
		if SaveManager.atalho_do_item(item_id) == "":
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/negacao.mp3")
			return
		SaveManager.limpar_atalho(SaveManager.atalho_do_item(item_id))
	else:
		SaveManager.definir_atalho(DIRECOES_ATALHO[atalho_index], item_id)

	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	close_atalho_menu()
	close_action_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu_game") or event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled()
		close_menu()
		return
		
	# O submenu do atalho vem ANTES do menu de ação: ele abre por cima dele, e
	# quem está por cima é quem lê a entrada.
	if atalho_open:
		var total_atalho: int = atalho_options.size()
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_dash"):
			get_viewport().set_input_as_handled()
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
			close_atalho_menu()
			return
		elif event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			atalho_index = (atalho_index + 1) % total_atalho
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			_render_atalho_menu()
			return
		elif event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			atalho_index = (atalho_index - 1 + total_atalho) % total_atalho
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			_render_atalho_menu()
			return
		elif event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_executar_atalho()
			return
		return

	if action_menu_open:
		var total_acoes: int = action_options.size()
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_dash"):
			get_viewport().set_input_as_handled()
			close_action_menu()
			return
		elif event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			action_menu_index = (action_menu_index + 1) % total_acoes
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			update_ui()
			return
		elif event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			action_menu_index = (action_menu_index - 1 + total_acoes) % total_acoes
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			update_ui()
			return
		elif event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			execute_action()
			return
		return
		
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_dash"):
		get_viewport().set_input_as_handled()
		close_menu()
		return

	if event.is_action_pressed("ui_r1"):
		current_tab = (current_tab - 1 + tabs.size()) % tabs.size()
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/sair_menu.mp3")
		update_ui()
	elif event.is_action_pressed("ui_l1"):
		current_tab = (current_tab + 1) % tabs.size()
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/sair_menu.mp3")
		update_ui()
		
	elif current_tab == 0:
		var moved = false
		if event.is_action_pressed("ui_right") and not event is InputEventJoypadMotion:
			if current_slot % grid_cols < grid_cols - 1:
				current_slot += 1
				moved = true
		elif event.is_action_pressed("ui_left") and not event is InputEventJoypadMotion:
			if current_slot % grid_cols > 0:
				current_slot -= 1
				moved = true
		elif event.is_action_pressed("ui_down") and not event is InputEventJoypadMotion:
			if current_slot + grid_cols < grid_cols * grid_rows:
				current_slot += grid_cols
				moved = true
		elif event.is_action_pressed("ui_up") and not event is InputEventJoypadMotion:
			if current_slot - grid_cols >= 0:
				current_slot -= grid_cols
				moved = true
		elif event.is_action_pressed("ui_accept"):
			if current_item_selected != null:
				open_action_menu()
			else:
				GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/negacao.mp3")
				
		if moved:
			GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
			update_ui()

func open_action_menu() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	action_menu_open = true
	action_menu_index = 0
	action_menu_panel.move_to_front()
	update_ui()

func close_action_menu() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
	# O submenu do atalho vive por cima deste: fechar o de baixo e deixar o de
	# cima aberto deixaria uma lista flutuando sozinha na tela.
	close_atalho_menu()
	action_menu_open = false
	action_menu_panel.visible = false
	update_ui()

func execute_action() -> void:
	if not current_item_selected: return
	
	var item_id = current_item_selected["id"]
	var db_info = SaveManager.item_db.get(item_id)
	var type = db_info.get("type", "")
	
	var btn_is_disabled = action_options[action_menu_index].disabled
	if btn_is_disabled:
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/negacao.mp3")
		return

	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	
	# Usar [0]
	if action_menu_index == 0 and type == "usable":
		SaveManager.remove_item_amount(item_id, 1)
		close_action_menu()
		
	# Equipar [1]
	elif action_menu_index == 1 and SaveManager.pode_equipar(item_id):
		if item_id == "cogblade":
			pass # Não pode desequipar
		else:
			if SaveManager.is_equipped(item_id):
				SaveManager.unequip_item(item_id)
			else:
				# `equip_item` desequipa sozinho o outro item do grupo exclusivo
				# (amuleto x pistola): os dois disputam o botão de mira.
				SaveManager.equip_item(item_id)
			# Equipar é progresso: quem equipa a arma e fecha o jogo tem de
			# reencontrá-la na mão.
			SaveManager.save_game()
			# Atualiza o UI do player imediatamente
			get_tree().call_group("player", "update_ammo_ui")
		close_action_menu()
		
	# Inspecionar [2]
	elif action_menu_index == 2 and type == "inspectable":
		var model_path = db_info.get("model_path", "")
		if model_path != "":
			var inspector_scene = load("res://scenes/ui/item_inspector.tscn")
			if inspector_scene:
				var inspector = inspector_scene.instantiate()
				inspector.model_path = model_path
				# Esconde o inventário enquanto inspeciona
				visible = false
				get_tree().root.add_child(inspector)
				inspector.inspector_closed.connect(func():
					visible = true
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				)

		close_action_menu()

	# Atalho [3] — abre o submenu das direções por cima deste menu
	elif action_menu_index == 3 and SaveManager.pode_equipar(item_id):
		open_atalho_menu()

func close_menu() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/sair_menu.mp3")
	await get_tree().process_frame
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Antes aqui havia um `call_group("player", "prevent_dash_leak")` — método
	# que NÃO existe em lugar nenhum, e `call_group` para método inexistente é
	# silencioso: a proteção nunca chegou a valer. O B que fecha este menu é o
	# mesmo botão do dash, daí a disparada ao sair.
	GlobalEvents.bloquear_dash_por()
	get_tree().call_group("player", "update_equipment_visuals")
	queue_free()
