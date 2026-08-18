extends Node


var current_time_tween: Tween = null

# --- SISTEMA DE MENSAGENS CENTRAIS GLOBAIS ---
var message_canvas_layer: CanvasLayer
var message_vbox: VBoxContainer
var active_messages: Dictionary = {}

func _ready() -> void:
	message_canvas_layer = CanvasLayer.new()
	message_canvas_layer.layer = 128
	add_child(message_canvas_layer)
	
	message_vbox = VBoxContainer.new()
	message_vbox.set_anchors_preset(Control.PRESET_CENTER)
	message_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	message_vbox.add_theme_constant_override("separation", 20)
	message_canvas_layer.add_child(message_vbox)

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
		tween.tween_property(label, "modulate:a", 1.0, 0.5)

	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	
	if duration > 0.0:
		# Verifica se a label ainda existe e se o ID não foi sobrescrito ou apagado nesse meio tempo
		await get_tree().create_timer(duration).timeout
		hide_center_message(message_id)

func hide_center_message(message_id: String) -> void:
	if active_messages.has(message_id):
		var label = active_messages[message_id]
		active_messages.erase(message_id)
		
		if is_instance_valid(label):
			var tween = create_tween()
			tween.tween_property(label, "modulate:a", 0.0, 0.5)
			await tween.finished
			if is_instance_valid(label):
				label.queue_free()

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
	

func vibrate_controller(input:Variant, low_strengh:float, high_strengh:float, time:float):
	input.start_joy_vibration(0,low_strengh, high_strengh, time)
	
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
