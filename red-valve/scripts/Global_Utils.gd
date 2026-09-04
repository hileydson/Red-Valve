extends Node


var current_time_tween: Tween = null

# --- SISTEMA DE MENSAGENS CENTRAIS GLOBAIS ---
var message_canvas_layer: CanvasLayer
var message_vbox: VBoxContainer
var active_messages: Dictionary = {}

# --- SISTEMA GLOBAL DE TEXTOS CINEMÁTICOS ---
var in_cinematic_cutscene: bool = false
var _cutscene_overlay: ColorRect
var _cutscene_label: Label
var _cutscene_audio: AudioStreamPlayer
var _cutscene_texts: Array = []
var _current_cutscene_idx: int = 0
var _cutscene_text_transitioning: bool = false
var _cutscene_text_gen: int = 0
var _cutscene_bars_node: Node = null
var _cutscene_skip_ui: Control = null
var _cutscene_skip_layer: CanvasLayer = null

signal cinematic_cutscene_finished

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	message_canvas_layer = CanvasLayer.new()
	message_canvas_layer.layer = 120
	add_child(message_canvas_layer)
	
	message_vbox = VBoxContainer.new()
	message_vbox.set_anchors_preset(Control.PRESET_CENTER)
	message_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	message_vbox.add_theme_constant_override("separation", 20)
	message_vbox.process_mode = Node.PROCESS_MODE_PAUSABLE
	message_canvas_layer.add_child(message_vbox)

func play_ui_sound(sound_path: String) -> void:
	if ResourceLoader.exists(sound_path):
		var p = AudioStreamPlayer.new()
		p.stream = load(sound_path)
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func show_center_message(message_id: String, text: String, font_size: int = 18, duration: float = 0.0) -> void:
	var label: Label
	if active_messages.has(message_id):
		label = active_messages[message_id]
	else:
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(800, 0)
		label.add_theme_constant_override("outline_size", 5)
		label.modulate.a = 0.0
		message_vbox.add_child(label)
		active_messages[message_id] = label
		
		# Animação de entrada
		var tween = create_tween()
		tween.bind_node(label)
		tween.tween_property(label, "modulate:a", 1.0, 0.5)

	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	
	if duration > 0.0:
		# Verifica se a label ainda existe e se o ID não foi sobrescrito ou apagado nesse meio tempo
		await get_tree().create_timer(duration, false).timeout
		hide_center_message(message_id)

func hide_center_message(message_id: String) -> void:
	if active_messages.has(message_id):
		var label = active_messages[message_id]
		active_messages.erase(message_id)
		
		if is_instance_valid(label):
			var tween = create_tween()
			tween.bind_node(label)
			tween.tween_property(label, "modulate:a", 0.0, 0.5)
			await tween.finished
			if is_instance_valid(label):
				label.queue_free()

func clear_all_messages() -> void:
	for id in active_messages.keys():
		var label = active_messages[id]
		if is_instance_valid(label):
			label.queue_free()
	active_messages.clear()

# Limpa IMEDIATAMENTE (sem tween/await) qualquer mensagem central ou texto cinemático
# que esteja na tela. Usado ao sair pro menu principal, já que essas mensagens vivem
# neste autoload e não são destruídas junto com a cena do jogo.
func force_clear_all_screen_messages() -> void:
	clear_all_messages()

	if is_instance_valid(_cutscene_skip_ui):
		_cutscene_skip_ui.queue_free()
	_cutscene_skip_ui = null

	if is_instance_valid(_cutscene_label):
		_cutscene_label.queue_free()
	_cutscene_label = null

	if is_instance_valid(_cutscene_overlay):
		_cutscene_overlay.queue_free()
	_cutscene_overlay = null

	_cutscene_text_transitioning = false
	in_cinematic_cutscene = false

func ativar_camera_lenta(escala: float, duracao: float, sound:bool):
	Engine.time_scale = escala
	
	if sound:
		AudioServer.set_playback_speed_scale(escala)
	
	await get_tree().create_timer(duracao * escala, true, false, true).timeout
	
	if current_time_tween and current_time_tween.is_valid():
		current_time_tween.kill()
		
	current_time_tween = create_tween()
	current_time_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_time_tween.tween_property(Engine, "time_scale", 1.0, 0.2)
	
	if sound:
		current_time_tween.finished.connect(func():
			AudioServer.set_playback_speed_scale(1.0)
		)


func ativar_camera_lenta_com_fim(escala: float, duracao: float, sound:bool):
	Engine.time_scale = escala
	
	if sound:
		AudioServer.set_playback_speed_scale(escala)
	
	await get_tree().create_timer(duracao * escala, true, false, true).timeout
	
	if current_time_tween and current_time_tween.is_valid():
		current_time_tween.kill()
		
	current_time_tween = create_tween()
	current_time_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_time_tween.tween_property(Engine, "time_scale", 1.0, 0.2)
	current_time_tween.finished.connect(func(): 
		remover_camera_lenta()
	)
	
func remover_camera_lenta():
	# 1. Volta a velocidade do motor ao normal imediatamente
	Engine.time_scale = 1.0
	
	# 2. Volta o áudio ao normal (usando o AudioServer que configuraste antes)
	AudioServer.set_playback_speed_scale(1.0)
	
	# 3. Se estiveres a usar Tweens para suavizar o tempo, é bom matá-los 
	# para evitar que eles tentem continuar a mudar o time_scale
	# Exemplo: se guardaste o tween numa variável 'tween_tempo'
	# if tween_tempo and tween_tempo.is_valid():
	#    tween_tempo.kill()
	

# --- ESCONDER/RESTAURAR CANVASLAYERS DE UMA CENA PAUSADA ---
# Node3D.visible = false NÃO esconde CanvasLayers (ex: HUD, textos de
# capítulo), pois eles não fazem parte da árvore de visibilidade 3D. Isso é
# usado ao pausar uma cena (ex: entrando na arena de batalha via amuleto) para
# que textos/UI daquela cena não fiquem "grudados" na tela por cima da nova
# cena. Guarda o estado de visibilidade original em cada CanvasLayer via meta,
# para restaurar exatamente como estava (em vez de forçar tudo para visível).
func set_canvas_layers_hidden(node: Node, hide: bool) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			if hide:
				child.set_meta("_was_visible_before_pause", child.visible)
				child.visible = false
			else:
				if child.has_meta("_was_visible_before_pause"):
					child.visible = child.get_meta("_was_visible_before_pause")
					child.remove_meta("_was_visible_before_pause")
				else:
					child.visible = true
		set_canvas_layers_hidden(child, hide)

func vibrate_controller(_input_obj:Variant, low_strengh:float, high_strengh:float, time:float):
	if Input:
		Input.start_joy_vibration(0,low_strengh, high_strengh, time)
	
var current_shake_tween: Tween = null
var base_h_offset: float = 0.0
var base_v_offset: float = 0.0

# No script da sua Camera3D
func shake_camera(duracao: float, forca: float):
	var camera = get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	
	if current_shake_tween and current_shake_tween.is_valid():
		# Se já está tremendo, nós matamos o tween antigo para prolongar com o novo,
		# mas NÃO pegamos a posição atual como original, usamos a que já tínhamos gravado!
		current_shake_tween.kill()
	else:
		# Se não estava tremendo, a posição atual é a original verdadeira
		base_h_offset = camera.h_offset
		base_v_offset = camera.v_offset
	
	current_shake_tween = create_tween()
	
	# Cria várias posições aleatórias rápidas
	for i in range(10):
		var offset_random = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
		current_shake_tween.tween_property(camera, "h_offset", base_h_offset + offset_random.x, duracao / 10)
		current_shake_tween.tween_property(camera, "v_offset", base_v_offset + offset_random.y, duracao / 10)
	
	# Volta para a posição original no final
	current_shake_tween.tween_property(camera, "h_offset", base_h_offset, 0.1)
	current_shake_tween.tween_property(camera, "v_offset", base_v_offset, 0.1)


# =========================================================================
# SISTEMA GLOBAL DE TEXTOS CINEMÁTICOS
# =========================================================================

func show_cutscene_bars() -> void:
	if get_tree().current_scene:
		_cutscene_bars_node = get_tree().current_scene.find_child("cutscene", true, false)
		if _cutscene_bars_node:
			_cutscene_bars_node.visible = true
			var t = create_tween().set_parallel(true)
			for child in _cutscene_bars_node.get_children():
				if child is ColorRect and child.name != "fade":
					child.modulate.a = 0.0
					t.tween_property(child, "modulate:a", 1.0, 1.0)

func hide_cutscene_bars() -> void:
	if _cutscene_bars_node:
		var t = create_tween().set_parallel(true)
		for child in _cutscene_bars_node.get_children():
			if child is ColorRect and child.name != "fade":
				t.tween_property(child, "modulate:a", 0.0, 1.0)
		t.chain().tween_callback(func():
			if is_instance_valid(_cutscene_bars_node):
				_cutscene_bars_node.visible = false
				_cutscene_bars_node = null
		)

func start_cinematic_text_cutscene(texts: Array) -> void:
	in_cinematic_cutscene = true
	_cutscene_texts = texts
	_current_cutscene_idx = 0
	_cutscene_text_transitioning = true
	
	if not message_canvas_layer:
		_ready()
		
	if not _cutscene_skip_ui:
		# Camada própria, acima da barra preta do "cutscene" (CanvasLayer, layer 150),
		# pra garantir que o aparato de segurar-pra-skip fique sempre por CIMA das barras.
		if not is_instance_valid(_cutscene_skip_layer):
			_cutscene_skip_layer = CanvasLayer.new()
			_cutscene_skip_layer.layer = 155
			add_child(_cutscene_skip_layer)
		_cutscene_skip_ui = load("res://scripts/ui/skip_cutscene_ui.gd").new()
		_cutscene_skip_layer.add_child(_cutscene_skip_ui)
		_cutscene_skip_ui.skipped.connect(_on_cinematic_skipped)
			
	if not _cutscene_audio:
		_cutscene_audio = AudioStreamPlayer.new()
		var typing_sound_path = "res://assets/sounds/episodios/prologo/typing.mp3"
		if ResourceLoader.exists(typing_sound_path):
			_cutscene_audio.stream = load(typing_sound_path)
		add_child(_cutscene_audio)
		
	if not _cutscene_overlay:
		_cutscene_overlay = ColorRect.new()
		_cutscene_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cutscene_overlay.color = Color(0.05, 0.05, 0.05, 0.85)
		_cutscene_overlay.modulate.a = 0.0
		message_canvas_layer.add_child(_cutscene_overlay)
		
		_cutscene_label = Label.new()
		_cutscene_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_cutscene_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_cutscene_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_cutscene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cutscene_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cutscene_label.add_theme_font_override("font", load("res://assets/fonts/Montserrat-ExtraBold.ttf"))
		_cutscene_label.add_theme_font_size_override("font_size", 28)
		
		_cutscene_label.add_theme_color_override("font_color", Color.WHITE)
		_cutscene_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		_cutscene_label.add_theme_constant_override("shadow_outline_size", 4)
		_cutscene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_cutscene_label.custom_minimum_size = Vector2(800, 0)
		_cutscene_label.modulate.a = 0.0
		message_canvas_layer.add_child(_cutscene_label)
		
	# Adjust overlay to not cover the black cinematic bars if they are active
	if _cutscene_bars_node and _cutscene_bars_node.visible:
		_cutscene_overlay.offset_top = 157
		_cutscene_overlay.offset_bottom = -142
	else:
		_cutscene_overlay.offset_top = 0
		_cutscene_overlay.offset_bottom = 0
		
	var t = create_tween()
	t.tween_property(_cutscene_overlay, "modulate:a", 1.0, 1.0)
	await get_tree().create_timer(1.0).timeout
	
	_show_next_cinematic_text()

func _show_next_cinematic_text() -> void:
	if _current_cutscene_idx < _cutscene_texts.size():
		var full_text = tr(_cutscene_texts[_current_cutscene_idx])
		_cutscene_label.text = full_text
		_cutscene_label.visible_characters = 0
		_cutscene_label.modulate.a = 1.0
		
		_cutscene_text_transitioning = true
		_cutscene_text_gen += 1
		var my_gen = _cutscene_text_gen
		
		for i in range(full_text.length()):
			if my_gen != _cutscene_text_gen: return
			if _cutscene_label.visible_characters >= full_text.length(): break
			
			_cutscene_label.visible_characters += 1
			if full_text[i] != " " and is_instance_valid(_cutscene_audio) and _cutscene_audio.stream != null:
				# Variação sutil no som para aumentar a imersão
				_cutscene_audio.pitch_scale = randf_range(0.85, 1.15)
				_cutscene_audio.volume_db = randf_range(-22.0, -16.0)
				_cutscene_audio.play()
				
			await get_tree().create_timer(0.05).timeout
			
		_cutscene_text_transitioning = false
	else:
		_end_cinematic_text()

func _on_cinematic_skipped() -> void:
	_current_cutscene_idx = _cutscene_texts.size()
	_cutscene_text_gen += 1
	_end_cinematic_text()

func _process(delta: float) -> void:
	if in_cinematic_cutscene:
		if Input.is_action_just_pressed("ui_accept"):
			if _cutscene_text_transitioning and _cutscene_label and _cutscene_label.visible_characters < _cutscene_label.text.length():
				_cutscene_label.visible_characters = _cutscene_label.text.length()
				_cutscene_text_transitioning = false
			elif not _cutscene_text_transitioning:
				_cutscene_text_transitioning = true
				var t = create_tween()
				if _cutscene_label:
					t.tween_property(_cutscene_label, "modulate:a", 0.0, 0.3)
				await t.finished
				_current_cutscene_idx += 1
				_show_next_cinematic_text()

func _end_cinematic_text() -> void:
	_cutscene_text_transitioning = true
	var t = create_tween()
	if _cutscene_overlay is CanvasItem: t.tween_property(_cutscene_overlay, "modulate:a", 0.0, 1.0)
	if _cutscene_label is CanvasItem: t.parallel().tween_property(_cutscene_label, "modulate:a", 0.0, 1.0)
	
	if _cutscene_skip_ui:
		if _cutscene_skip_ui is CanvasItem:
			var skip_t = create_tween()
			skip_t.tween_property(_cutscene_skip_ui, "modulate:a", 0.0, 0.5)
	
	# Start song immediately if skipped and we need to play battle song? 
	# Wait, user said: "quando acontece o skipe... o som que nao foi iniciado antes deve se iniciar já que nao houve a cutscene para iniciar ele... o nome é SongFirstBattle do som"
	# That logic should probably be in the stage script, or we emit a signal and pass skipped state.
	
	await t.finished
	
	if _cutscene_skip_ui:
		_cutscene_skip_ui.queue_free()
		_cutscene_skip_ui = null
		
	if _cutscene_label:
		_cutscene_label.queue_free()
		_cutscene_label = null
		
	if _cutscene_overlay:
		_cutscene_overlay.queue_free()
		_cutscene_overlay = null
	
	in_cinematic_cutscene = false

	cinematic_cutscene_finished.emit()
