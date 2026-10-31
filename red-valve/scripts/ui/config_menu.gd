extends CanvasLayer

## Aba DEBUG: só pra este momento de testes do prólogo/arena — vida infinita
## fixa via export quebra a luta perdida obrigatória, então isto liga/desliga
## em tempo real por Player.set_infinite_health_debug. Remover quando os
## testes acabarem.
const PlayerScript := preload("res://scripts/player/player.gd")
const DebugQuantidade := preload("res://scripts/ui/debug_quantidade.gd")

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

# Debug Eventos (só visível após sequência)
var tab_debug: MarginContainer
var debug_infinite_hp_label: Label
var debug_infinite_hp_check: CheckButton
var debug_infinite_stamina_label: Label
var debug_infinite_stamina_check: CheckButton
var debug_corrida_dobrada_check: CheckButton
var debug_events_scroll: ScrollContainer
var debug_event_checks: Dictionary = {}

# Debug Itens (só visível após sequência)
var tab_debug_itens: MarginContainer
var debug_itens_scroll: ScrollContainer
var debug_itens_first: Control
var debug_rusks_spin: Button
var debug_max_mp_spin: Button
var debug_curr_mp_spin: Button

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
		# Os dados em memória são os do jogo em andamento (ou, no menu principal,
		# os do último slot lido); o que mudar aqui vai pro slot escolhido.
		_build_debug_tab()
		_build_debug_itens_tab()
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
	elif tab_container.current_tab == 4 and is_instance_valid(debug_itens_first):
		debug_itens_first.grab_focus()
	elif tab_container.current_tab == 5 and is_instance_valid(debug_travel_first_btn):
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
		elif tab_container.current_tab == 4 and is_instance_valid(debug_itens_scroll):
			var joy_y = Input.get_axis("ui_look_up", "ui_look_down")
			if abs(joy_y) > 0.1:
				debug_itens_scroll.scroll_vertical += int(joy_y * 600 * delta)

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
	if tab_container.get_tab_count() > 4: tab_container.set_tab_title(4, tr("CONFIG_TAB_DEBUG_ITENS"))
	if tab_container.get_tab_count() > 5: tab_container.set_tab_title(5, tr("CONFIG_TAB_DEBUG_TRAVEL"))


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
		txt += "- Menu do Jogo (itens, arquivos, mapa): " + ("Y" if pad else "tecla T") + "\n"
		txt += "- Mapa: " + ("Back (Select)" if pad else "tecla M") + "\n"
		txt += "- Trocar de aba no Menu: " + ("LB e RB" if pad else "teclas 2 e 1") + "\n"
		txt += "- Voltar / Fechar: " + ("B" if pad else "Esc") + "\n"
		txt += "- Pausar: " + ("Start" if pad else "Esc") + "\n"
		txt += "\n[b]Maycow Combate (Adicionais)[/b]\n"
		txt += "- Mirar: " + ("LT" if pad else "Botão Direito do Mouse") + "\n"
		txt += "- Atirar: " + ("RT" if pad else "Botão Esquerdo do Mouse") + "\n"
		txt += "- Recarregar: " + ("X" if pad else "tecla R") + "\n"
		txt += "- Empunhar a Cogblade: " + ("aperte LB" if pad else "tecla C") + "\n"
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
		txt += "- Game Menu (items, files, map): " + ("Y" if pad else "T key") + "\n"
		txt += "- Map: " + ("Back (Select)" if pad else "M key") + "\n"
		txt += "- Switch Menu Tab: " + ("LB and RB" if pad else "keys 2 and 1") + "\n"
		txt += "- Back / Close: " + ("B" if pad else "Esc") + "\n"
		txt += "- Pause: " + ("Start" if pad else "Esc") + "\n"
		txt += "\n[b]Combat Maycow (Additional)[/b]\n"
		txt += "- Aim: " + ("LT" if pad else "Right Mouse Button") + "\n"
		txt += "- Shoot: " + ("RT" if pad else "Left Mouse Button") + "\n"
		txt += "- Reload: " + ("X" if pad else "R key") + "\n"
		txt += "- Wield the Cogblade: " + ("tap LB" if pad else "C key") + "\n"
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
	_margem_debug(tab_debug)
	var vbox := _rolagem_debug(tab_debug)
	debug_events_scroll = vbox.get_parent() as ScrollContainer

	# --- Status do jogador (vale na hora, nao vai pro save) ---
	_secao_debug(vbox, tr("DEBUG_SECAO_STATUS"))

	debug_infinite_hp_check = CheckButton.new()
	debug_infinite_hp_check.text = tr("CONFIG_DEBUG_INFINITE_HP")
	debug_infinite_hp_check.add_theme_font_size_override("font_size", 18)
	debug_infinite_hp_check.button_pressed = PlayerScript.is_infinite_health_debug()
	debug_infinite_hp_check.toggled.connect(func(pressed): PlayerScript.set_infinite_health_debug(pressed))
	_foco_debug(debug_infinite_hp_check)
	vbox.add_child(debug_infinite_hp_check)

	debug_infinite_stamina_check = CheckButton.new()
	debug_infinite_stamina_check.text = tr("CONFIG_DEBUG_INFINITE_STAMINA")
	debug_infinite_stamina_check.add_theme_font_size_override("font_size", 18)
	debug_infinite_stamina_check.button_pressed = PlayerScript.is_infinite_stamina_debug()
	debug_infinite_stamina_check.toggled.connect(func(pressed): PlayerScript.set_infinite_stamina_debug(pressed))
	_foco_debug(debug_infinite_stamina_check)
	vbox.add_child(debug_infinite_stamina_check)

	debug_corrida_dobrada_check = CheckButton.new()
	debug_corrida_dobrada_check.text = tr("CONFIG_DEBUG_CORRIDA_DOBRADA")
	debug_corrida_dobrada_check.add_theme_font_size_override("font_size", 18)
	debug_corrida_dobrada_check.button_pressed = PlayerScript.is_corrida_dobrada_debug()
	debug_corrida_dobrada_check.toggled.connect(func(pressed): PlayerScript.set_corrida_dobrada_debug(pressed))
	_foco_debug(debug_corrida_dobrada_check)
	vbox.add_child(debug_corrida_dobrada_check)

	# --- Eventos da historia, por capitulo (do slot em jogo) ---
	# Ligar um evento liga tudo o que ele exige; desligar desliga tudo o que
	# depende dele (ver scripts/systems/eventos_historia.gd).
	var dica := Label.new()
	dica.text = tr("DEBUG_DICA_DEPENDENCIA")
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.add_theme_font_size_override("font_size", 15)
	dica.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(dica)

	for cap in [Eventos.PROLOGO, Eventos.CAPITULO_1, Eventos.CAPITULO_2, Eventos.CAPITULO_3]:
		_secao_debug(vbox, tr(Eventos.TITULOS_CAPITULO[cap]))
		for id in Eventos.do_capitulo(cap):
			var id_evento: String = id
			_add_event_checkbox(vbox, "evt_" + id_evento, tr(Eventos.rotulo(id_evento)),
				Eventos.feito(id_evento), func(val):
					SaveManager.alterar_pelo_menu("evt_" + id_evento, Eventos.forcar.bind(id_evento, val))
					_atualizar_checks_de_eventos()
			)
		if cap == Eventos.CAPITULO_2:
			# O evento da Dona Nice (igreja), por etapa: 0 nada, 1 luta fase 1,
			# 2 luta fase 2, 3 o Jonny no chao da igreja, 4 no colo, 5 deixado,
			# 6 na maca do hospital.
			var etapa := _linha_quantidade(vbox, tr("DEBUG_EVENT_DONA_NICE"), 0, 6,
				SaveManager.evento_dona_nice)
			etapa.value_changed.connect(func(v):
				SaveManager.alterar_pelo_menu("evento_dona_nice",
					SaveManager.set.bind("evento_dona_nice", int(v)))
			)

	# --- Poderes da cogblade: o jogo comeca sem nenhum; o evento da aura do
	# amuleto (Capitulo 1) liga o primeiro, e cada um liga e desliga aqui ---
	_secao_debug(vbox, tr("DEBUG_SECAO_PODERES_COGBLADE"))
	for p in Eventos.PODERES_COGBLADE:
		var id_poder: String = p["id"]
		_add_event_checkbox(vbox, "poder_" + id_poder, tr(String(p["rotulo"])),
			Eventos.poder_liberado(id_poder), func(val):
				SaveManager.alterar_pelo_menu("poder_" + id_poder, Eventos.forcar_poder.bind(id_poder, val))
		)

	tab_container.add_child(tab_debug)


## Depois de um `Eventos.forcar` outros eventos podem ter mudado junto
## (dependencias e dependentes): todas as caixinhas releem o estado.
func _atualizar_checks_de_eventos() -> void:
	for e in Eventos.CATALOGO:
		var chave := "evt_" + String(e["id"])
		if debug_event_checks.has(chave):
			debug_event_checks[chave].set_pressed_no_signal(Eventos.feito(String(e["id"])))
	# o evento da aura leva o poder junto
	for p in Eventos.PODERES_COGBLADE:
		var chave_poder := "poder_" + String(p["id"])
		if debug_event_checks.has(chave_poder):
			debug_event_checks[chave_poder].set_pressed_no_signal(Eventos.poder_liberado(String(p["id"])))
	# o telefonema tambem e' um arquivo: a aba de itens acompanha
	if debug_event_checks.has("file_telefone"):
		debug_event_checks["file_telefone"].set_pressed_no_signal(SaveManager.tem_arquivo("telefonema_dona_nice"))


## Itens, pickups, arquivos e quantidades — o que fica no menu do jogador —,
## separados pelo capitulo em que aparecem.
const DEBUG_ITENS_POR_CAPITULO := {
	0: [["maycow_watch", "DEBUG_ITEM_WATCH"], ["cogblade", "DEBUG_ITEM_COGBLADE"]],
	1: [["amuleto", "DEBUG_ITEM_AMULETO"], ["lanterna", "DEBUG_ITEM_LANTERNA"],
		["pistol", "DEBUG_ITEM_PISTOL"]],
	2: [["chave_igreja", "DEBUG_ITEM_CHAVE_IGREJA"],
		["shotgun", "DEBUG_ITEM_SHOTGUN"], ["mk3", "DEBUG_ITEM_MK3"],
		["granola", "DEBUG_ITEM_GRANOLA"]],
}
const DEBUG_ARQUIVOS_POR_CAPITULO := {
	0: [["file_apos_trabalho", "DEBUG_EVENT_FILE_APOS_TRABALHO", "apos_um_dia_de_trabalho"],
		["file_telefone", "DEBUG_EVENT_FILE_TELEFONE", "telefonema_dona_nice"]],
	1: [["file_caderno", "DEBUG_EVENT_FILE_CADERNO", "caderno_do_jimmy"],
		["file_diario", "DEBUG_EVENT_FILE_DIARIO", "diario_do_jimmy"]],
	2: [["file_carta_nice", "DEBUG_EVENT_FILE_CARTA_NICE", "carta_da_dona_nice"]],
}
## [chave do checkbox, rotulo, id do pickup no save, (sala, se o rotulo for
## o generico "Municao (%s)")]
const DEBUG_PICKUPS_POR_CAPITULO := {
	1: [["pickup_pistol", "DEBUG_EVENT_PICKUP_PISTOL", "casa_jimmy_pistola_gaveta"],
		["pickup_jimmy_ammo", "DEBUG_EVENT_PICKUP_JIMMY_AMMO", "casa_jimmy_municao_gaveta"],
		["pickup_jimmy_ammo_2", "DEBUG_PICKUP_MUNICAO_EM", "casa_jimmy_municao_aparador", "DEBUG_LOCAL_JIMMY_SALA"],
		["pickup_jimmy_ammo_3", "DEBUG_PICKUP_MUNICAO_EM", "casa_jimmy_municao_q2", "DEBUG_LOCAL_JIMMY_Q2"],
		["pickup_esc_101", "DEBUG_PICKUP_MUNICAO_EM", "escola_municao_101", "ESC_SALA_101"],
		["pickup_esc_secretaria", "DEBUG_PICKUP_MUNICAO_EM", "escola_municao_secretaria", "ESC_SALA_SECRETARIA"],
		["pickup_esc_biblioteca", "DEBUG_PICKUP_MUNICAO_EM", "escola_municao_biblioteca", "ESC_SALA_BIBLIOTECA"],
		["pickup_esc_106", "DEBUG_PICKUP_MUNICAO_EM", "escola_municao_106", "ESC_SALA_106"],
		["pickup_por_1", "DEBUG_PICKUP_MUNICAO_EM", "porao_municao_1", "DEBUG_LOCAL_PORAO_BECO_1"],
		["pickup_por_2", "DEBUG_PICKUP_MUNICAO_EM", "porao_municao_2", "MAP_POI_POR_CAMARA"],
		["pickup_por_3", "DEBUG_PICKUP_MUNICAO_EM", "porao_municao_3", "DEBUG_LOCAL_PORAO_BECO_2"]],
	2: [["pickup_nice_gaveta", "DEBUG_EVENT_PICKUP_NICE_GAVETA", "casa_nice_gaveta_aberta"],
		["pickup_nice_chave", "DEBUG_EVENT_PICKUP_NICE_CHAVE", "casa_nice_chave_igreja"],
		["pickup_nice_shotgun", "DEBUG_EVENT_PICKUP_NICE_SHOTGUN", "casa_nice_shotgun_laje"],
		["pickup_nice_shells", "DEBUG_EVENT_PICKUP_NICE_SHELLS", "casa_nice_shotgun_municao_laje"],
		["pickup_nice_ammo1", "DEBUG_EVENT_PICKUP_NICE_AMMO1", "casa_nice_municao_cozinha"],
		["pickup_nice_ammo2", "DEBUG_EVENT_PICKUP_NICE_AMMO2", "casa_nice_municao_quarto"],
		["pickup_seringa_igreja", "DEBUG_EVENT_PICKUP_SERINGA_IGREJA", "igreja_seringa_galeria"],
		["pickup_ammo1", "DEBUG_EVENT_PICKUP_AMMO1", "hospital_municao_no_balcao"],
		["pickup_ammo2", "DEBUG_EVENT_PICKUP_AMMO2", "hospital_municao_no_balcao_2"],
		["pickup_shotgun", "DEBUG_EVENT_PICKUP_SHOTGUN", "hospital_shotgun_no_balcao"],
		["pickup_shotgun_ammo1", "DEBUG_EVENT_PICKUP_SHOTGUN_AMMO1", "hospital_shotgun_municao_no_balcao"],
		["pickup_shotgun_ammo2", "DEBUG_EVENT_PICKUP_SHOTGUN_AMMO2", "hospital_shotgun_municao_no_balcao_2"],
		["pickup_mk3", "DEBUG_EVENT_PICKUP_MK3", "hospital_mk3_no_balcao"],
		["pickup_mk3_ammo1", "DEBUG_EVENT_PICKUP_MK3_AMMO1", "hospital_mk3_municao_no_balcao"],
		["pickup_mk3_ammo2", "DEBUG_EVENT_PICKUP_MK3_AMMO2", "hospital_mk3_municao_no_balcao_2"],
		["pickup_granola", "DEBUG_EVENT_PICKUP_GRANOLA", "hospital_granola_no_balcao"],
		["pickup_granola_ammo1", "DEBUG_EVENT_PICKUP_GRANOLA_AMMO1", "hospital_granola_foguete_no_balcao"],
		["pickup_granola_ammo2", "DEBUG_EVENT_PICKUP_GRANOLA_AMMO2", "hospital_granola_foguete_no_balcao_2"]],
}
## [rotulo, item] — quantidade no inventario.
const DEBUG_QUANTIDADES_POR_CAPITULO := {
	1: [["DEBUG_ITEM_PISTOL_AMMO", "pistol_ammo"]],
	2: [["DEBUG_ITEM_SERINGA", "seringa_adrenalina"], ["DEBUG_ITEM_SERINGA_MAGIA", "seringa_magia"],
		["DEBUG_ITEM_SHOTGUN_AMMO", "shotgun_ammo"], ["DEBUG_ITEM_MK3_AMMO", "mk3_ammo"],
		["DEBUG_ITEM_GRANOLA_AMMO", "granola_ammo"]],
}


func _build_debug_itens_tab() -> void:
	tab_debug_itens = MarginContainer.new()
	tab_debug_itens.name = "Debug Itens"
	_margem_debug(tab_debug_itens)
	var vbox := _rolagem_debug(tab_debug_itens)
	debug_itens_scroll = vbox.get_parent() as ScrollContainer
	debug_itens_first = null

	var dica := Label.new()
	dica.text = tr("DEBUG_DICA_QUANTIDADE")
	dica.add_theme_font_size_override("font_size", 15)
	dica.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(dica)

	for cap in [Eventos.PROLOGO, Eventos.CAPITULO_1, Eventos.CAPITULO_2]:
		_secao_debug(vbox, tr(Eventos.TITULOS_CAPITULO[cap]))
		for par in DEBUG_ITENS_POR_CAPITULO.get(cap, []):
			var item_id: String = par[0]
			_add_event_checkbox(vbox, "item_" + item_id, tr(par[1]), SaveManager.tem_item(item_id), func(val):
				_debug_set_item(item_id, val, 1)
			)
		for arq in DEBUG_ARQUIVOS_POR_CAPITULO.get(cap, []):
			var arq_id: String = arq[2]
			_add_event_checkbox(vbox, arq[0], tr(arq[1]), SaveManager.tem_arquivo(arq_id), func(val):
				_debug_set_array_entry("arquivos_desbloqueados", arq_id, val)
				_atualizar_checks_de_eventos()
			)
		var pickups: Array = DEBUG_PICKUPS_POR_CAPITULO.get(cap, [])
		if not pickups.is_empty():
			_subsecao_debug(vbox, tr("DEBUG_SECAO_PICKUPS"))
		for pk in pickups:
			var pk_id: String = pk[2]
			var texto: String = tr(pk[1]) % tr(pk[3]) if pk.size() > 3 else tr(pk[1])
			_add_event_checkbox(vbox, pk[0], texto, SaveManager.pickups_pegos.has(pk_id), func(val):
				_debug_set_array_entry("pickups_pegos", pk_id, val)
			)
		var quantidades: Array = DEBUG_QUANTIDADES_POR_CAPITULO.get(cap, [])
		if not quantidades.is_empty():
			_subsecao_debug(vbox, tr("DEBUG_SECAO_QUANTIDADES"))
		for q in quantidades:
			var q_item: String = q[1]
			var linha := _linha_quantidade(vbox, tr(q[0]), 0, 999, _debug_get_item_amount(q_item))
			linha.value_changed.connect(func(v):
				_debug_set_item_amount(q_item, int(v))
				if debug_event_checks.has("item_" + q_item):
					debug_event_checks["item_" + q_item].set_pressed_no_signal(SaveManager.tem_item(q_item))
			)

	# --- Recursos (de qualquer capitulo) ---
	_secao_debug(vbox, tr("DEBUG_SECAO_RECURSOS"))
	debug_rusks_spin = _linha_quantidade(vbox, tr("DEBUG_EVENT_IRON_RUSKS"), 0, 99999, SaveManager.iron_rusks)
	debug_rusks_spin.value_changed.connect(func(v):
		SaveManager.alterar_pelo_menu("iron_rusks", SaveManager.debug_definir_iron_rusks.bind(int(v)))
	)
	debug_max_mp_spin = _linha_quantidade(vbox, tr("DEBUG_EVENT_MAX_MP"), 1, 100, SaveManager.max_mp)
	debug_max_mp_spin.value_changed.connect(func(v):
		SaveManager.alterar_pelo_menu("max_mp", SaveManager.set.bind("max_mp", float(v)))
	)
	debug_curr_mp_spin = _linha_quantidade(vbox, tr("DEBUG_EVENT_CURRENT_MP"), 0, 100, SaveManager.current_mp)
	debug_curr_mp_spin.value_changed.connect(func(v):
		SaveManager.alterar_pelo_menu("current_mp", SaveManager.set.bind("current_mp", float(v)))
	)

	tab_container.add_child(tab_debug_itens)


# --- pecas comuns das duas abas de debug ---------------------------------------

func _margem_debug(aba: MarginContainer) -> void:
	aba.add_theme_constant_override("margin_left", 30)
	aba.add_theme_constant_override("margin_right", 30)
	aba.add_theme_constant_override("margin_top", 20)
	aba.add_theme_constant_override("margin_bottom", 20)


## ScrollContainer + VBox. O `follow_focus` e' o que faz a lista rolar sozinha
## acompanhando o direcional.
func _rolagem_debug(aba: Control) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	aba.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	return vbox


func _secao_debug(vbox: Node, titulo: String) -> void:
	var rotulo = Label.new()
	rotulo.text = "--- " + titulo + " ---"
	rotulo.add_theme_font_size_override("font_size", 22)
	rotulo.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(rotulo)


func _subsecao_debug(vbox: Node, titulo: String) -> void:
	var rotulo = Label.new()
	rotulo.text = titulo
	rotulo.add_theme_font_size_override("font_size", 17)
	rotulo.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(rotulo)


## A marca de "voce esta' aqui": fundo claro e borda vermelha. A do tema padrao
## e' um contorno fino que some contra o fundo preto do menu.
var _estilo_foco_debug: StyleBoxFlat

func _foco_debug(controle: Control) -> void:
	if _estilo_foco_debug == null:
		_estilo_foco_debug = StyleBoxFlat.new()
		_estilo_foco_debug.bg_color = Color(1.0, 0.35, 0.35, 0.16)
		_estilo_foco_debug.border_color = Color(1.0, 0.4, 0.4)
		_estilo_foco_debug.set_border_width_all(2)
		_estilo_foco_debug.set_corner_radius_all(4)
		_estilo_foco_debug.content_margin_left = 8
		_estilo_foco_debug.content_margin_right = 8
	controle.add_theme_stylebox_override("focus", _estilo_foco_debug)


## Uma linha de quantidade (ver debug_quantidade.gd): navegavel com o
## direcional e marcada quando esta' em foco.
func _linha_quantidade(vbox: Node, texto: String, minimo: float, maximo: float, atual: float) -> Button:
	var linha = DebugQuantidade.new()
	linha.configurar(texto, minimo, maximo, atual)
	linha.add_theme_font_size_override("font_size", 18)
	linha.custom_minimum_size = Vector2(0, 38)
	_foco_debug(linha)
	vbox.add_child(linha)
	if vbox.get_parent() == debug_itens_scroll and debug_itens_first == null:
		debug_itens_first = linha
	return linha


func _add_event_checkbox(parent: Node, id: String, title: String, current_state: bool, on_toggled: Callable) -> void:
	var check = CheckButton.new()
	check.text = title
	check.add_theme_font_size_override("font_size", 18)
	check.button_pressed = current_state
	check.toggled.connect(on_toggled)
	_foco_debug(check)
	parent.add_child(check)
	debug_event_checks[id] = check
	if parent.get_parent() == debug_itens_scroll and debug_itens_first == null:
		debug_itens_first = check

## Lista do SaveManager pelo nome (ver `SaveManager.debug_marcar_na_lista`).
func _debug_set_array_entry(lista: String, entry_id: String, active: bool) -> void:
	SaveManager.alterar_pelo_menu(lista + ":" + entry_id,
		SaveManager.debug_marcar_na_lista.bind(lista, entry_id, active))

func _debug_set_item(item_id: String, active: bool, amount: int = 1) -> void:
	SaveManager.alterar_pelo_menu("item:" + item_id,
		SaveManager.debug_definir_item.bind(item_id, active, amount))

func _debug_get_item_amount(item_id: String) -> int:
	return SaveManager.debug_quantidade_do_item(item_id)

func _debug_set_item_amount(item_id: String, new_amount: int) -> void:
	# a caixinha do item e a quantidade mexem no mesmo dado: a mais recente vence
	SaveManager.alterar_pelo_menu("item:" + item_id,
		SaveManager.debug_definir_quantidade.bind(item_id, new_amount))

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
		{"name": tr("DEBUG_TRAVEL_JIMMY_WORKSHOP"), "scene": "res://scenes/stages/prolog/oficina_jimmy.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_JIMMY_HOUSE"), "scene": "res://scenes/stages/jimmy_house/casa_jimmy_interior.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_NICE_HOUSE"), "scene": "res://scenes/stages/nice_house/casa_nice_interior.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_HOSPITAL"), "scene": "res://scenes/stages/hospital/hospital.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_SCHOOL"), "scene": "res://scenes/stages/escola/escola.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_CEMETERY"), "scene": "res://scenes/stages/cemiterio/cemiterio.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_HELL"), "scene": "res://scenes/stages/inferno/inferno.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_HELL_2"), "scene": "res://scenes/stages/inferno_2/inferno_2.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_HELL_3"), "scene": "res://scenes/stages/inferno_3/inferno_3.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_HELL_4"), "scene": "res://scenes/stages/inferno_4/inferno_4.tscn", "flag": ""},
		{"name": tr("DEBUG_TRAVEL_ARENA_3"), "scene": "res://scenes/stages/battlefield/battlefield_3.tscn", "flag": ""}
	]

	# duas colunas: em uma so' a lista passava da altura da aba
	var grade = GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 24)
	grade.add_theme_constant_override("v_separation", 18)
	vbox.add_child(grade)

	debug_travel_first_btn = null
	for dest in destinations:
		var btn = Button.new()
		btn.text = dest["name"]
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(350, 45)
		btn.pressed.connect(func(): _fast_travel_to(dest["scene"], dest["flag"]))
		grade.add_child(btn)
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
