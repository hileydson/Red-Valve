extends CanvasLayer

## Aba DEBUG: só pra este momento de testes do prólogo/arena — vida infinita
## fixa via export quebra a luta perdida obrigatória, então isto liga/desliga
## em tempo real por Player.set_infinite_health_debug. Remover quando os
## testes acabarem.
const PlayerScript := preload("res://scripts/player/player.gd")

var bg: ColorRect
var title_label: Label
var tab_container: TabContainer
var back_btn: Button

# Fica true enquanto a lista suspensa de algum OptionButton está aberta. Sem
# isso, o mesmo evento do controle (D-pad, LB/RB, cancelar) era processado ao
# mesmo tempo pela lista e pelo menu por trás dela - trocava de aba ou movia o
# foco enquanto o jogador só queria escolher uma opção.
var _popup_open: bool = false

# Gameplay Tab
var tab_gameplay: MarginContainer
var lang_label: Label
var lang_option: OptionButton
var run_label: Label
var run_option: OptionButton
var aim_assist_label: Label
var aim_assist_check: CheckButton
var aim_strength_label: Label
var aim_strength_slider: HSlider

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
## Dispositivo com que a lista de comandos foi escrita.
var _controls_text_controle := false

# Video Tab
var tab_video: MarginContainer
var display_label: Label
var display_option: OptionButton
var res_label: Label
var resolution_option: OptionButton
var brightness_label: Label
var brightness_slider: HSlider
var cel_label: Label
var cel_check: CheckButton
var cel_intensity_label: Label
var cel_intensity_slider: HSlider

# Debug Tab (só visível após sequência)
var tab_debug: MarginContainer
var debug_infinite_hp_label: Label
var debug_infinite_hp_check: CheckButton
var debug_infinite_stamina_label: Label
var debug_infinite_stamina_check: CheckButton
var debug_events_scroll: ScrollContainer
var debug_event_checks: Dictionary = {}
var debug_rusks_spin: SpinBox
var debug_max_mp_spin: SpinBox
var debug_curr_mp_spin: SpinBox
var debug_ammo_pistol_spin: SpinBox
var debug_ammo_shotgun_spin: SpinBox
var debug_ammo_mk3_spin: SpinBox
var debug_ammo_granola_spin: SpinBox
var debug_save_btn: Button

# Debug Travel Tab (só visível após sequência)
var tab_debug_travel: MarginContainer
var debug_travel_first_btn: Button

# Controle de alteração de valores numéricos via analógico direito
var _stick_val_hold_time: float = 0.0
var _stick_val_repeat_timer: float = 0.0
var _stick_val_last_dir: int = 0
var _stick_sound_timer: float = 0.0



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
	
	# Ordem das Abas: Gameplay, Controles, Vídeo, e Debugs se destravados
	_build_gameplay_tab()
	_build_controls_tab()
	_build_video_tab()
	if GlobalEvents.debug_mode_unlocked:
		# Sempre carregar os dados em memória como estão gravados no Slot 1 (sem troca de cena)
		SaveManager.load_slot_data_only(1)
		_build_debug_tab()
		_build_debug_travel_tab()
	
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
	elif tab_container.current_tab == 3 and is_instance_valid(debug_infinite_hp_check):
		debug_infinite_hp_check.grab_focus()
	elif tab_container.current_tab == 4 and is_instance_valid(debug_travel_first_btn):
		debug_travel_first_btn.grab_focus()




func _wire_option_popup(option: OptionButton) -> void:
	# Enquanto a lista está aberta ela é a única a receber navegação: soltamos o
	# foco do menu de trás e devolvemos pro próprio OptionButton ao fechar.
	var popup := option.get_popup()
	popup.about_to_popup.connect(func():
		_popup_open = true
		if get_viewport(): get_viewport().gui_release_focus()
	)
	popup.popup_hide.connect(func():
		_popup_open = false
		if is_instance_valid(option): option.grab_focus()
	)

func _input(event: InputEvent) -> void:
	var is_back = event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed)
	
	if _popup_open:
		if is_back:
			for tab in tab_container.get_children():
				for option in tab.find_children("*", "OptionButton", true, false):
					if option.get_popup().visible:
						option.get_popup().hide()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			tab_container.current_tab = max(0, tab_container.current_tab - 1)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			tab_container.current_tab = min(tab_container.get_tab_count() - 1, tab_container.current_tab + 1)
			get_viewport().set_input_as_handled()
			
	if is_back:
		back_btn.pressed.emit()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# trocou de dispositivo com o menu aberto: a lista de comandos acompanha
	if is_instance_valid(controls_text) and GlobalEvents.usando_controle != _controls_text_controle:
		_update_controls_text()
	if _popup_open: return
	
	var active_target := _get_active_spin_or_slider()
	if not active_target.is_empty():
		_process_stick_value_change(active_target, delta)
	else:
		if tab_container.current_tab == 1 and is_instance_valid(controls_scroll):
			var joy_y = Input.get_axis("ui_look_up", "ui_look_down")
			if abs(joy_y) > 0.1:
				controls_scroll.scroll_vertical += int(joy_y * 600 * delta)
		elif tab_container.current_tab == 3 and is_instance_valid(debug_events_scroll):
			var joy_y = Input.get_axis("ui_look_up", "ui_look_down")
			if abs(joy_y) > 0.1:
				debug_events_scroll.scroll_vertical += int(joy_y * 600 * delta)

func _get_active_spin_or_slider() -> Dictionary:
	var focus_owner = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if not is_instance_valid(focus_owner):
		return {}
	if focus_owner is SpinBox:
		return {"spin": focus_owner}
	elif focus_owner.get_parent() is SpinBox:
		return {"spin": focus_owner.get_parent() as SpinBox}
	elif focus_owner is HSlider:
		return {"slider": focus_owner}
	return {}

func _process_stick_value_change(target: Dictionary, delta: float) -> void:
	var joy_x = Input.get_axis("ui_look_left", "ui_look_right")
	var joy_y = Input.get_axis("ui_look_down", "ui_look_up") # Cima = positivo (+1.0)
	
	var input_dir := 0
	if abs(joy_x) >= abs(joy_y):
		if abs(joy_x) > 0.25:
			input_dir = 1 if joy_x > 0 else -1
	else:
		if abs(joy_y) > 0.25:
			input_dir = 1 if joy_y > 0 else -1
			
	if input_dir == 0:
		_stick_val_last_dir = 0
		_stick_val_hold_time = 0.0
		_stick_val_repeat_timer = 0.0
		_stick_sound_timer = 0.0
		return
		
	if _stick_val_last_dir != input_dir:
		_stick_val_last_dir = input_dir
		_stick_val_hold_time = 0.0
		_stick_val_repeat_timer = 0.30 # Delay inicial antes da aceleração
		_stick_sound_timer = 0.0
		_apply_value_step(target, input_dir, 1.0, true)
	else:
		_stick_val_hold_time += delta
		_stick_val_repeat_timer -= delta
		_stick_sound_timer -= delta
		if _stick_val_repeat_timer <= 0.0:
			var mult := 1.0
			if _stick_val_hold_time > 3.5:
				mult = 100.0
			elif _stick_val_hold_time > 2.0:
				mult = 20.0
			elif _stick_val_hold_time > 1.0:
				mult = 5.0
			else:
				mult = 1.0
			
			_stick_val_repeat_timer = 0.05
			var play_sound := false
			if _stick_sound_timer <= 0.0:
				play_sound = true
				_stick_sound_timer = 0.12
			_apply_value_step(target, input_dir, mult, play_sound)

func _apply_value_step(target: Dictionary, dir: int, mult: float, play_sound: bool) -> void:
	if target.has("spin"):
		var spin: SpinBox = target["spin"]
		if is_instance_valid(spin):
			var step: float = maxf(float(spin.step), 1.0)
			if spin.max_value >= 10000:
				step = step * mult
			elif spin.max_value >= 500:
				step = step * minf(mult, 25.0)
			elif spin.max_value >= 100:
				step = step * minf(mult, 5.0)
			
			var new_val: float = clampf(float(spin.value) + (float(dir) * step), float(spin.min_value), float(spin.max_value))
			if new_val != spin.value:
				spin.value = new_val
				if is_instance_valid(spin.get_line_edit()):
					spin.get_line_edit().text = str(int(new_val) if spin.step >= 1.0 else new_val)
				if play_sound:
					GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
	elif target.has("slider"):
		var slider: HSlider = target["slider"]
		if is_instance_valid(slider):
			var step: float = maxf(float(slider.step), 1.0)
			var new_val: float = clampf(float(slider.value) + (float(dir) * step), float(slider.min_value), float(slider.max_value))
			if new_val != slider.value:
				slider.value = new_val
				if play_sound:
					GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")

func _update_tab_titles():
	if tab_container.get_tab_count() > 0: tab_container.set_tab_title(0, tr("CONFIG_TAB_GAMEPLAY"))
	if tab_container.get_tab_count() > 1: tab_container.set_tab_title(1, tr("CONFIG_TAB_CONTROLS"))
	if tab_container.get_tab_count() > 2: tab_container.set_tab_title(2, tr("CONFIG_TAB_VIDEO"))
	if tab_container.get_tab_count() > 3: tab_container.set_tab_title(3, tr("CONFIG_TAB_DEBUG"))
	if tab_container.get_tab_count() > 4: tab_container.set_tab_title(4, tr("CONFIG_TAB_DEBUG_TRAVEL"))


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
	_wire_option_popup(lang_option)
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
	_wire_option_popup(run_option)
	run_option.item_selected.connect(_on_run_selected)
	vbox.add_child(run_option)

	# Assistente de mira
	aim_assist_label = Label.new()
	aim_assist_label.text = tr("CONFIG_AIM_ASSIST")
	aim_assist_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(aim_assist_label)

	aim_assist_check = CheckButton.new()
	aim_assist_check.add_theme_font_size_override("font_size", 20)
	aim_assist_check.button_pressed = SaveManager.config.get("aim_assist", true)
	aim_assist_check.toggled.connect(_on_aim_assist_toggled)
	vbox.add_child(aim_assist_check)

	# Intensidade da assistência (só faz efeito com ela ligada)
	aim_strength_label = Label.new()
	aim_strength_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(aim_strength_label)

	aim_strength_slider = HSlider.new()
	aim_strength_slider.min_value = 50
	aim_strength_slider.max_value = 200
	aim_strength_slider.step = 5
	aim_strength_slider.value = round(SaveManager.config.get("aim_assist_strength", 1.0) * 100.0)
	aim_strength_slider.value_changed.connect(_on_aim_strength_changed)
	vbox.add_child(aim_strength_slider)

	_update_aim_assist_ui()

	tab_container.add_child(tab_gameplay)

func _on_aim_assist_toggled(pressed: bool) -> void:
	SaveManager.config["aim_assist"] = pressed
	_update_aim_assist_ui()

func _on_aim_strength_changed(value: float) -> void:
	# O slider trabalha em 50-200% pra ficar legível; o componente usa 0.5-2.0.
	SaveManager.config["aim_assist_strength"] = value / 100.0
	_update_aim_assist_ui()

func _update_aim_assist_ui() -> void:
	if not is_instance_valid(aim_strength_slider): return
	var on: bool = SaveManager.config.get("aim_assist", true)
	aim_strength_slider.editable = on
	aim_strength_slider.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	aim_strength_slider.modulate.a = 1.0 if on else 0.4
	if is_instance_valid(aim_strength_label):
		aim_strength_label.modulate.a = 1.0 if on else 0.4
		aim_strength_label.text = "%s: %d%%" % [tr("CONFIG_AIM_ASSIST_STRENGTH"), int(aim_strength_slider.value)]

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
	# só o dispositivo em uso: quem está no controle não lê tecla nenhuma
	_controls_text_controle = GlobalEvents.usando_controle
	var pad = _controls_text_controle
	var txt = ""
	if is_pt:
		txt += "[b]Maycow Normal[/b]\n"
		txt += "- Movimento: " + ("Analógico Esquerdo" if pad else "WASD") + "\n"
		txt += "- Câmera: " + ("Analógico Direito" if pad else "Mouse") + "\n"
		txt += "- Correr: " + ("RB" if pad else "Shift") + "\n"
		txt += "- Pular, Interagir e Confirmar: " + ("A" if pad else "Espaço") + "\n"
		txt += "- Esquiva (Dash): " + ("B" if pad else "Botão do Meio do Mouse") + "\n"
		txt += "- Lanterna: " + ("LS (clique do analógico esquerdo)" if pad else "tecla Y") + "\n"
		txt += "- Visão do Amuleto (só na cidade): " + ("SEGURE LB" if pad else "SEGURE a tecla V") + "\n"
		txt += "- Menu do Jogo (itens, arquivos, mapa): " + ("Back" if pad else "tecla T") + "\n"
		txt += "- Trocar de aba no Menu: " + ("LB e RB" if pad else "teclas 2 e 1") + "\n"
		txt += "- Voltar / Fechar: " + ("B" if pad else "Esc") + "\n"
		txt += "- Pausar: " + ("Start" if pad else "Esc") + "\n"
		txt += "\n[b]Maycow Combate (Adicionais)[/b]\n"
		txt += "- Mirar: " + ("LT" if pad else "Botão Direito do Mouse") + "\n"
		txt += "- Atirar: " + ("RT" if pad else "Botão Esquerdo do Mouse") + "\n"
		txt += "- Recarregar: " + ("X" if pad else "tecla R") + "\n"
		txt += "- Golpe da Cogblade: " + ("aperte LB" if pad else "tecla C") + "\n"
		txt += "- Poderes da Cogblade: " + ("SEGURE LB e escolha com o Analógico Esquerdo" if pad else "SEGURE a tecla C e escolha com o Mouse") + "\n"
	else:
		txt += "[b]Normal Maycow[/b]\n"
		txt += "- Movement: " + ("Left Stick" if pad else "WASD") + "\n"
		txt += "- Camera: " + ("Right Stick" if pad else "Mouse") + "\n"
		txt += "- Run: " + ("RB" if pad else "Shift") + "\n"
		txt += "- Jump, Interact and Confirm: " + ("A" if pad else "Space") + "\n"
		txt += "- Dodge (Dash): " + ("B" if pad else "Middle Mouse Button") + "\n"
		txt += "- Flashlight: " + ("LS (left stick click)" if pad else "Y key") + "\n"
		txt += "- Amulet Vision (city only): " + ("HOLD LB" if pad else "HOLD the V key") + "\n"
		txt += "- Game Menu (items, files, map): " + ("Back" if pad else "T key") + "\n"
		txt += "- Switch Menu Tab: " + ("LB and RB" if pad else "keys 2 and 1") + "\n"
		txt += "- Back / Close: " + ("B" if pad else "Esc") + "\n"
		txt += "- Pause: " + ("Start" if pad else "Esc") + "\n"
		txt += "\n[b]Combat Maycow (Additional)[/b]\n"
		txt += "- Aim: " + ("LT" if pad else "Right Mouse Button") + "\n"
		txt += "- Shoot: " + ("RT" if pad else "Left Mouse Button") + "\n"
		txt += "- Reload: " + ("X" if pad else "R key") + "\n"
		txt += "- Cogblade Slash: " + ("tap LB" if pad else "C key") + "\n"
		txt += "- Cogblade Powers: " + ("HOLD LB and pick with the Left Stick" if pad else "HOLD the C key and pick with the Mouse") + "\n"
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
		
	_wire_option_popup(display_option)
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
	
	_wire_option_popup(resolution_option)
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

	# Cel Shading (filtro cartoon por cima do 3D)
	cel_label = Label.new()
	cel_label.text = tr("CONFIG_CEL_SHADING")
	cel_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(cel_label)

	cel_check = CheckButton.new()
	cel_check.add_theme_font_size_override("font_size", 20)
	cel_check.button_pressed = SaveManager.config.get("cel_shading", false)
	cel_check.toggled.connect(_on_cel_shading_toggled)
	vbox.add_child(cel_check)

	# Intensidade: só faz sentido dentro da faixa em que o efeito fica bom.
	cel_intensity_label = Label.new()
	cel_intensity_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(cel_intensity_label)

	cel_intensity_slider = HSlider.new()
	cel_intensity_slider.min_value = 55
	cel_intensity_slider.max_value = 85
	cel_intensity_slider.step = 1
	cel_intensity_slider.value = round(SaveManager.config.get("cel_shading_intensity", 0.65) * 100.0)
	cel_intensity_slider.value_changed.connect(_on_cel_intensity_changed)
	vbox.add_child(cel_intensity_slider)

	_update_cel_shading_ui()

	tab_container.add_child(tab_video)

func _on_cel_shading_toggled(pressed: bool) -> void:
	SaveManager.config["cel_shading"] = pressed
	_update_cel_shading_ui()
	SaveManager.apply_configs()

func _on_cel_intensity_changed(value: float) -> void:
	# O slider trabalha em 55-85 pra ficar legível; o shader usa 0.55-0.85.
	SaveManager.config["cel_shading_intensity"] = value / 100.0
	_update_cel_shading_ui()
	SaveManager.apply_configs()

func _update_cel_shading_ui() -> void:
	if not is_instance_valid(cel_intensity_slider): return
	var on: bool = SaveManager.config.get("cel_shading", false)
	# Sem cel shading ligado, o controle de intensidade fica inerte e apagado
	cel_intensity_slider.editable = on
	cel_intensity_slider.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	cel_intensity_slider.modulate.a = 1.0 if on else 0.4
	if is_instance_valid(cel_intensity_label):
		cel_intensity_label.modulate.a = 1.0 if on else 0.4
		cel_intensity_label.text = "%s: %d%%" % [tr("CONFIG_CEL_SHADING_INTENSITY"), int(cel_intensity_slider.value)]

func _build_debug_tab():
	tab_debug = MarginContainer.new()
	tab_debug.name = "Debug"
	tab_debug.add_theme_constant_override("margin_left", 30)
	tab_debug.add_theme_constant_override("margin_right", 30)
	tab_debug.add_theme_constant_override("margin_top", 20)
	tab_debug.add_theme_constant_override("margin_bottom", 20)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	debug_events_scroll = scroll
	tab_debug.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# --- Batalha / Testes ---
	var section_combat = Label.new()
	section_combat.text = "--- " + tr("CONFIG_TAB_GAMEPLAY") + " / Status ---"
	section_combat.add_theme_font_size_override("font_size", 22)
	section_combat.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(section_combat)

	debug_infinite_hp_check = CheckButton.new()
	debug_infinite_hp_check.text = tr("CONFIG_DEBUG_INFINITE_HP")
	debug_infinite_hp_check.add_theme_font_size_override("font_size", 18)
	debug_infinite_hp_check.button_pressed = PlayerScript.is_infinite_health_debug()
	debug_infinite_hp_check.toggled.connect(func(pressed): PlayerScript.set_infinite_health_debug(pressed))
	vbox.add_child(debug_infinite_hp_check)

	debug_infinite_stamina_check = CheckButton.new()
	debug_infinite_stamina_check.text = tr("CONFIG_DEBUG_INFINITE_STAMINA")
	debug_infinite_stamina_check.add_theme_font_size_override("font_size", 18)
	debug_infinite_stamina_check.button_pressed = PlayerScript.is_infinite_stamina_debug()
	debug_infinite_stamina_check.toggled.connect(func(pressed): PlayerScript.set_infinite_stamina_debug(pressed))
	vbox.add_child(debug_infinite_stamina_check)

	# --- Eventos do Jogo e Save do Player (Slot 1) ---
	var section_events = Label.new()
	section_events.text = "--- " + tr("MENU_TAB_FILES") + " / Eventos do Save (Slot 1) ---"
	section_events.add_theme_font_size_override("font_size", 22)
	section_events.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(section_events)

	# Eventos de História e Progressão
	_add_event_checkbox(vbox, "prolog_finished", tr("DEBUG_EVENT_PROLOG_FINISHED"), SaveManager.prolog_finished, func(val):
		SaveManager.prolog_finished = val
		_auto_save_debug()
	)
	_add_event_checkbox(vbox, "phone_answered", tr("DEBUG_EVENT_PHONE_ANSWERED"), SaveManager.tem_arquivo("telefonema_dona_nice"), func(val):
		if val:
			if not SaveManager.arquivos_desbloqueados.has("telefonema_dona_nice"):
				SaveManager.arquivos_desbloqueados.append("telefonema_dona_nice")
		else:
			SaveManager.arquivos_desbloqueados.erase("telefonema_dona_nice")
		if debug_event_checks.has("file_telefone"):
			debug_event_checks["file_telefone"].set_pressed_no_signal(val)
		_auto_save_debug()
	)
	_add_event_checkbox(vbox, "stage_1_intro_played", tr("DEBUG_EVENT_STAGE1_INTRO"), SaveManager.stage_1_intro_played, func(val):
		SaveManager.stage_1_intro_played = val
		_auto_save_debug()
	)
	_add_event_checkbox(vbox, "battlefield_1_intro_played", tr("DEBUG_EVENT_BATTLEFIELD1_INTRO"), SaveManager.battlefield_1_intro_played, func(val):
		SaveManager.battlefield_1_intro_played = val
		_auto_save_debug()
	)
	_add_event_checkbox(vbox, "tutorial_amuleto_visto", tr("DEBUG_EVENT_AMULETO_TUTORIAL"), SaveManager.tutorial_amuleto_visto, func(val):
		SaveManager.tutorial_amuleto_visto = val
		_auto_save_debug()
	)
	_add_event_checkbox(vbox, "escola_portao_destrancado", tr("DEBUG_EVENT_ESCOLA_PORTAO"), GlobalEvents.escola_portao_destrancado, func(val):
		GlobalEvents.escola_portao_destrancado = val
		_auto_save_debug()
	)
	# O evento da Dona Nice (igreja), por etapa: 0 nada, 1 luta fase 1, 2 luta
	# fase 2, 3 o Jonny no chao da igreja, 4 no colo (hospital), 5 deixado la'.
	var linha_dona_nice = HBoxContainer.new()
	var rotulo_dona_nice = Label.new()
	rotulo_dona_nice.text = tr("DEBUG_EVENT_DONA_NICE")
	rotulo_dona_nice.add_theme_font_size_override("font_size", 18)
	linha_dona_nice.add_child(rotulo_dona_nice)
	var spin_dona_nice = SpinBox.new()
	_setup_debug_spinbox(spin_dona_nice, 0, 5, SaveManager.evento_dona_nice)
	spin_dona_nice.value_changed.connect(func(v):
		SaveManager.evento_dona_nice = int(v)
		_auto_save_debug()
	)
	linha_dona_nice.add_child(spin_dona_nice)
	vbox.add_child(linha_dona_nice)

	# --- Armas e Itens Possuídos (Inventário) ---
	var section_items = Label.new()
	section_items.text = "--- Armas e Itens no Inventário ---"
	section_items.add_theme_font_size_override("font_size", 20)
	section_items.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(section_items)

	_add_event_checkbox(vbox, "item_watch", tr("DEBUG_ITEM_WATCH"), SaveManager.tem_item("maycow_watch"), func(val):
		_debug_set_item("maycow_watch", val, 1)
	)
	_add_event_checkbox(vbox, "item_amuleto", tr("DEBUG_ITEM_AMULETO"), SaveManager.tem_item("amuleto"), func(val):
		_debug_set_item("amuleto", val, 1)
	)
	_add_event_checkbox(vbox, "item_lanterna", tr("DEBUG_ITEM_LANTERNA"), SaveManager.tem_item("lanterna"), func(val):
		_debug_set_item("lanterna", val, 1)
	)
	_add_event_checkbox(vbox, "item_pistol", tr("DEBUG_ITEM_PISTOL"), SaveManager.tem_item("pistol"), func(val):
		_debug_set_item("pistol", val, 1)
	)
	_add_event_checkbox(vbox, "item_shotgun", tr("DEBUG_ITEM_SHOTGUN"), SaveManager.tem_item("shotgun"), func(val):
		_debug_set_item("shotgun", val, 1)
	)
	_add_event_checkbox(vbox, "item_mk3", tr("DEBUG_ITEM_MK3"), SaveManager.tem_item("mk3"), func(val):
		_debug_set_item("mk3", val, 1)
	)
	_add_event_checkbox(vbox, "item_granola", tr("DEBUG_ITEM_GRANOLA"), SaveManager.tem_item("granola"), func(val):
		_debug_set_item("granola", val, 1)
	)
	_add_event_checkbox(vbox, "item_cogblade", tr("DEBUG_ITEM_COGBLADE"), SaveManager.tem_item("cogblade"), func(val):
		_debug_set_item("cogblade", val, 1)
	)

	# Arquivos desbloqueados
	var section_files = Label.new()
	section_files.text = "--- Arquivos Desbloqueados ---"
	section_files.add_theme_font_size_override("font_size", 18)
	section_files.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(section_files)

	_add_event_checkbox(vbox, "file_apos_trabalho", tr("DEBUG_EVENT_FILE_APOS_TRABALHO"), SaveManager.arquivos_desbloqueados.has("apos_um_dia_de_trabalho"), func(val):
		_debug_set_array_entry(SaveManager.arquivos_desbloqueados, "apos_um_dia_de_trabalho", val)
	)
	_add_event_checkbox(vbox, "file_telefone", tr("DEBUG_EVENT_FILE_TELEFONE"), SaveManager.arquivos_desbloqueados.has("telefonema_dona_nice"), func(val):
		_debug_set_array_entry(SaveManager.arquivos_desbloqueados, "telefonema_dona_nice", val)
		if debug_event_checks.has("phone_answered"):
			debug_event_checks["phone_answered"].set_pressed_no_signal(val)
	)
	_add_event_checkbox(vbox, "file_caderno", tr("DEBUG_EVENT_FILE_CADERNO"), SaveManager.arquivos_desbloqueados.has("caderno_do_jimmy"), func(val):
		_debug_set_array_entry(SaveManager.arquivos_desbloqueados, "caderno_do_jimmy", val)
	)

	# Pickups do cenário
	var section_pickups = Label.new()
	section_pickups.text = "--- Pickups do Cenário Recolhidos ---"
	section_pickups.add_theme_font_size_override("font_size", 18)
	section_pickups.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(section_pickups)

	_add_event_checkbox(vbox, "pickup_pistol", tr("DEBUG_EVENT_PICKUP_PISTOL"), SaveManager.pickups_pegos.has("hospital_pistola_no_balcao"), func(val):
		_debug_set_array_entry(SaveManager.pickups_pegos, "hospital_pistola_no_balcao", val)
	)
	_add_event_checkbox(vbox, "pickup_ammo1", tr("DEBUG_EVENT_PICKUP_AMMO1"), SaveManager.pickups_pegos.has("hospital_municao_no_balcao"), func(val):
		_debug_set_array_entry(SaveManager.pickups_pegos, "hospital_municao_no_balcao", val)
	)
	_add_event_checkbox(vbox, "pickup_ammo2", tr("DEBUG_EVENT_PICKUP_AMMO2"), SaveManager.pickups_pegos.has("hospital_municao_no_balcao_2"), func(val):
		_debug_set_array_entry(SaveManager.pickups_pegos, "hospital_municao_no_balcao_2", val)
	)
	_add_event_checkbox(vbox, "pickup_shotgun", tr("DEBUG_EVENT_PICKUP_SHOTGUN"), SaveManager.pickups_pegos.has("hospital_shotgun_no_balcao"), func(val):
		_debug_set_array_entry(SaveManager.pickups_pegos, "hospital_shotgun_no_balcao", val)
	)
	_add_event_checkbox(vbox, "pickup_shotgun_ammo1", tr("DEBUG_EVENT_PICKUP_SHOTGUN_AMMO1"), SaveManager.pickups_pegos.has("hospital_shotgun_municao_no_balcao"), func(val):
		_debug_set_array_entry(SaveManager.pickups_pegos, "hospital_shotgun_municao_no_balcao", val)
	)
	_add_event_checkbox(vbox, "pickup_shotgun_ammo2", tr("DEBUG_EVENT_PICKUP_SHOTGUN_AMMO2"), SaveManager.pickups_pegos.has("hospital_shotgun_municao_no_balcao_2"), func(val):
		_debug_set_array_entry(SaveManager.pickups_pegos, "hospital_shotgun_municao_no_balcao_2", val)
	)
	# A MK3 e a Granola no balcao, e as balas da casa da Dona Nice.
	for pickup in [["pickup_mk3", "DEBUG_EVENT_PICKUP_MK3", "hospital_mk3_no_balcao"],
			["pickup_mk3_ammo1", "DEBUG_EVENT_PICKUP_MK3_AMMO1", "hospital_mk3_municao_no_balcao"],
			["pickup_mk3_ammo2", "DEBUG_EVENT_PICKUP_MK3_AMMO2", "hospital_mk3_municao_no_balcao_2"],
			["pickup_granola", "DEBUG_EVENT_PICKUP_GRANOLA", "hospital_granola_no_balcao"],
			["pickup_granola_ammo1", "DEBUG_EVENT_PICKUP_GRANOLA_AMMO1", "hospital_granola_foguete_no_balcao"],
			["pickup_granola_ammo2", "DEBUG_EVENT_PICKUP_GRANOLA_AMMO2", "hospital_granola_foguete_no_balcao_2"],
			["pickup_nice_ammo1", "DEBUG_EVENT_PICKUP_NICE_AMMO1", "casa_nice_municao_cozinha"],
			["pickup_nice_ammo2", "DEBUG_EVENT_PICKUP_NICE_AMMO2", "casa_nice_municao_quarto"]]:
		var id_pickup: String = pickup[2]
		_add_event_checkbox(vbox, pickup[0], tr(pickup[1]), SaveManager.pickups_pegos.has(id_pickup), func(val):
			_debug_set_array_entry(SaveManager.pickups_pegos, id_pickup, val)
		)

	# Recursos Numéricos e Munições
	var section_numeric = Label.new()
	section_numeric.text = "--- Recursos e Munições ---"
	section_numeric.add_theme_font_size_override("font_size", 18)
	section_numeric.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(section_numeric)

	# Iron Rusks
	var hbox_rusks = HBoxContainer.new()
	hbox_rusks.add_theme_constant_override("separation", 20)
	var lbl_rusks = Label.new()
	lbl_rusks.text = tr("DEBUG_EVENT_IRON_RUSKS")
	lbl_rusks.add_theme_font_size_override("font_size", 18)
	hbox_rusks.add_child(lbl_rusks)
	debug_rusks_spin = SpinBox.new()
	_setup_debug_spinbox(debug_rusks_spin, 0, 99999, SaveManager.iron_rusks)
	debug_rusks_spin.value_changed.connect(func(v):
		SaveManager.iron_rusks = int(v)
		SaveManager.iron_rusks_display = SaveManager.iron_rusks
		_auto_save_debug()
	)
	hbox_rusks.add_child(debug_rusks_spin)
	vbox.add_child(hbox_rusks)

	# Max MP
	var hbox_max_mp = HBoxContainer.new()
	hbox_max_mp.add_theme_constant_override("separation", 20)
	var lbl_max_mp = Label.new()
	lbl_max_mp.text = tr("DEBUG_EVENT_MAX_MP")
	lbl_max_mp.add_theme_font_size_override("font_size", 18)
	hbox_max_mp.add_child(lbl_max_mp)
	debug_max_mp_spin = SpinBox.new()
	_setup_debug_spinbox(debug_max_mp_spin, 1, 100, SaveManager.max_mp)
	debug_max_mp_spin.value_changed.connect(func(v):
		SaveManager.max_mp = float(v)
		_auto_save_debug()
	)
	hbox_max_mp.add_child(debug_max_mp_spin)
	vbox.add_child(hbox_max_mp)

	# Current MP
	var hbox_curr_mp = HBoxContainer.new()
	hbox_curr_mp.add_theme_constant_override("separation", 20)
	var lbl_curr_mp = Label.new()
	lbl_curr_mp.text = tr("DEBUG_EVENT_CURRENT_MP")
	lbl_curr_mp.add_theme_font_size_override("font_size", 18)
	hbox_curr_mp.add_child(lbl_curr_mp)
	debug_curr_mp_spin = SpinBox.new()
	_setup_debug_spinbox(debug_curr_mp_spin, 0, 100, SaveManager.current_mp)
	debug_curr_mp_spin.value_changed.connect(func(v):
		SaveManager.current_mp = float(v)
		_auto_save_debug()
	)
	hbox_curr_mp.add_child(debug_curr_mp_spin)
	vbox.add_child(hbox_curr_mp)

	# Munição Pistola
	var hbox_ammo_p = HBoxContainer.new()
	hbox_ammo_p.add_theme_constant_override("separation", 20)
	var lbl_ammo_p = Label.new()
	lbl_ammo_p.text = tr("DEBUG_ITEM_PISTOL_AMMO")
	lbl_ammo_p.add_theme_font_size_override("font_size", 18)
	hbox_ammo_p.add_child(lbl_ammo_p)
	debug_ammo_pistol_spin = SpinBox.new()
	_setup_debug_spinbox(debug_ammo_pistol_spin, 0, 999, _debug_get_item_amount("pistol_ammo"))
	debug_ammo_pistol_spin.value_changed.connect(func(v):
		_debug_set_item_amount("pistol_ammo", int(v))
	)
	hbox_ammo_p.add_child(debug_ammo_pistol_spin)
	vbox.add_child(hbox_ammo_p)

	# Munição Espingarda
	var hbox_ammo_s = HBoxContainer.new()
	hbox_ammo_s.add_theme_constant_override("separation", 20)
	var lbl_ammo_s = Label.new()
	lbl_ammo_s.text = tr("DEBUG_ITEM_SHOTGUN_AMMO")
	lbl_ammo_s.add_theme_font_size_override("font_size", 18)
	hbox_ammo_s.add_child(lbl_ammo_s)
	debug_ammo_shotgun_spin = SpinBox.new()
	_setup_debug_spinbox(debug_ammo_shotgun_spin, 0, 999, _debug_get_item_amount("shotgun_ammo"))
	debug_ammo_shotgun_spin.value_changed.connect(func(v):
		_debug_set_item_amount("shotgun_ammo", int(v))
	)
	hbox_ammo_s.add_child(debug_ammo_shotgun_spin)
	vbox.add_child(hbox_ammo_s)

	# Munição da MK3 e foguetes da Granola
	debug_ammo_mk3_spin = _debug_spin_de_municao(vbox, "DEBUG_ITEM_MK3_AMMO", "mk3_ammo")
	debug_ammo_granola_spin = _debug_spin_de_municao(vbox, "DEBUG_ITEM_GRANOLA_AMMO", "granola_ammo")


	tab_container.add_child(tab_debug)

## Uma linha "nome da munição + quantidade", igual às da pistola e da espingarda.
func _debug_spin_de_municao(vbox: Node, chave: String, item: String) -> SpinBox:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	var lbl = Label.new()
	lbl.text = tr(chave)
	lbl.add_theme_font_size_override("font_size", 18)
	hbox.add_child(lbl)
	var spin = SpinBox.new()
	_setup_debug_spinbox(spin, 0, 999, _debug_get_item_amount(item))
	spin.value_changed.connect(func(v):
		_debug_set_item_amount(item, int(v))
	)
	hbox.add_child(spin)
	vbox.add_child(hbox)
	return spin


func _add_event_checkbox(parent: Node, id: String, title: String, current_state: bool, on_toggled: Callable) -> void:
	var check = CheckButton.new()
	check.text = title
	check.add_theme_font_size_override("font_size", 18)
	check.button_pressed = current_state
	check.toggled.connect(on_toggled)
	parent.add_child(check)
	debug_event_checks[id] = check

func _setup_debug_spinbox(spin: SpinBox, min_v: float, max_v: float, cur_v: float) -> void:
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.value = cur_v
	spin.custom_minimum_size = Vector2(140, 36)
	spin.focus_mode = Control.FOCUS_ALL
	var le = spin.get_line_edit()
	if is_instance_valid(le):
		le.add_theme_font_size_override("font_size", 18)
		le.focus_mode = Control.FOCUS_ALL
		spin.mouse_entered.connect(func(): if is_instance_valid(le): le.grab_focus())

func _auto_save_debug() -> void:
	SaveManager.current_slot = 1
	SaveManager.save_game()

func _debug_set_array_entry(target_array: Array, entry_id: String, active: bool) -> void:
	if active:
		if not target_array.has(entry_id):
			target_array.append(entry_id)
	else:
		target_array.erase(entry_id)
	_auto_save_debug()

func _debug_set_item(item_id: String, active: bool, amount: int = 1) -> void:
	if active:
		if not SaveManager.tem_item(item_id):
			SaveManager.add_item(item_id, amount)
	else:
		for lista in [SaveManager.inventory_normal, SaveManager.inventory_combat]:
			for i in range(lista.size() - 1, -1, -1):
				if lista[i].get("id") == item_id:
					lista.remove_at(i)
		if item_id in SaveManager.equipped_items:
			SaveManager.equipped_items.erase(item_id)
		if SaveManager.ultima_arma_equipada == item_id:
			SaveManager.ultima_arma_equipada = ""
		if SaveManager.equipado_na_cidade == item_id:
			SaveManager.equipado_na_cidade = ""
		SaveManager.garantir_equipamento_do_normal()
	_auto_save_debug()

func _debug_get_item_amount(item_id: String) -> int:
	for item in SaveManager.inventory_normal:
		if item.get("id") == item_id:
			return int(item.get("amount", 0))
	for item in SaveManager.inventory_combat:
		if item.get("id") == item_id:
			return int(item.get("amount", 0))
	return 0

func _debug_set_item_amount(item_id: String, new_amount: int) -> void:
	if new_amount <= 0:
		for lista in [SaveManager.inventory_normal, SaveManager.inventory_combat]:
			for i in range(lista.size() - 1, -1, -1):
				if lista[i].get("id") == item_id:
					lista.remove_at(i)
	else:
		var current_amt = _debug_get_item_amount(item_id)
		if current_amt == 0:
			SaveManager.add_item(item_id, new_amount)
		else:
			for lista in [SaveManager.inventory_normal, SaveManager.inventory_combat]:
				for item in lista:
					if item.get("id") == item_id:
						item["amount"] = new_amount
	_auto_save_debug()

func _build_debug_travel_tab() -> void:
	tab_debug_travel = MarginContainer.new()
	tab_debug_travel.name = "Debug Travel"
	tab_debug_travel.add_theme_constant_override("margin_left", 40)
	tab_debug_travel.add_theme_constant_override("margin_right", 40)
	tab_debug_travel.add_theme_constant_override("margin_top", 30)
	tab_debug_travel.add_theme_constant_override("margin_bottom", 30)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	tab_debug_travel.add_child(vbox)

	var title = Label.new()
	title.text = "Fast Travel (Debug):"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(title)

	var destinations = [
		{"name": tr("DEBUG_TRAVEL_MAYCOW_HOUSE"), "scene": "res://scenes/stages/prolog/the_house.tscn", "flag": "entrando_na_casa_maycow"},
		{"name": tr("DEBUG_TRAVEL_CHURCH"), "scene": "res://scenes/stages/igreja/igreja_interior.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_JIMMY_HOUSE"), "scene": "res://scenes/stages/jimmy_house/casa_jimmy_interior.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_NICE_HOUSE"), "scene": "res://scenes/stages/nice_house/casa_nice_interior.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_HOSPITAL"), "scene": "res://scenes/stages/hospital/hospital.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_SCHOOL"), "scene": "res://scenes/stages/escola/escola.tscn", "flag": ""}
	]

	debug_travel_first_btn = null
	for dest in destinations:
		var btn = Button.new()
		btn.text = dest["name"]
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(350, 45)
		btn.pressed.connect(func(): _fast_travel_to(dest["scene"], dest["flag"]))
		vbox.add_child(btn)
		if debug_travel_first_btn == null:
			debug_travel_first_btn = btn

	tab_container.add_child(tab_debug_travel)

func _fast_travel_to(scene_path: String, flag: String) -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	if flag == "entrando_na_casa_maycow":
		GlobalEvents.entrando_na_casa_maycow = true
	
	# Despausa e limpa resíduos de combate se houver
	get_tree().paused = false
	GlobalUtils.cleanup_gameplay_leftovers()
	
	LoadingScreen.load_scene(scene_path)
	queue_free()



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
	
	if is_instance_valid(aim_assist_label): aim_assist_label.text = tr("CONFIG_AIM_ASSIST")
	_update_aim_assist_ui()
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
	if is_instance_valid(cel_label): cel_label.text = tr("CONFIG_CEL_SHADING")
	_update_cel_shading_ui()
	if is_instance_valid(debug_infinite_hp_label): debug_infinite_hp_label.text = tr("CONFIG_DEBUG_INFINITE_HP")
	if is_instance_valid(debug_infinite_stamina_label): debug_infinite_stamina_label.text = tr("CONFIG_DEBUG_INFINITE_STAMINA")
	
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
