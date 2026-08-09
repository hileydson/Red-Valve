extends Control

@onready var image_rect: TextureRect = $ImageRect
@onready var label: Label = $TextBackground/Label
@onready var fade = $fade
@onready var audio_player: AudioStreamPlayer = $Begin

var slides = [
	{
		"image_path": "res://assets/cutscenes/prolog/fight_no_power/no_power_1.png",
		"texts": [
			"NO_POWER_1_SUM_1", "NO_POWER_1_SUM_2", "NO_POWER_1_SUM_3"
		]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/fight_no_power/no_power_2.png",
		"texts": ["NO_POWER_2_01", "NO_POWER_2_02"]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/fight_no_power/no_power_3.png",
		"texts": [
			"NO_POWER_3_01", "NO_POWER_3_02", "NO_POWER_3_03", "NO_POWER_3_04",
			"NO_POWER_3_05", "NO_POWER_3_06", "NO_POWER_3_07", "NO_POWER_3_08",
			"NO_POWER_3_09", "NO_POWER_3_10", "NO_POWER_3_11", "NO_POWER_3_12",
			"NO_POWER_3_13", "NO_POWER_3_14", "NO_POWER_3_15", "NO_POWER_3_16",
			"NO_POWER_3_17", "NO_POWER_3_18", "NO_POWER_3_19", "NO_POWER_3_20",
			"NO_POWER_3_21", "NO_POWER_3_22", "NO_POWER_3_23", "NO_POWER_3_24",
			"NO_POWER_3_25"
		]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/fight_no_power/no_power_4.png",
		"texts": [
			"NO_POWER_4_01", "NO_POWER_4_02", "NO_POWER_4_03", "NO_POWER_4_04",
			"NO_POWER_4_05", "NO_POWER_4_06", "NO_POWER_4_07"
		]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/fight_no_power/no_power_5.png",
		"texts": [
			"NO_POWER_5_01", "NO_POWER_5_02", "NO_POWER_5_03", "NO_POWER_5_04",
			"NO_POWER_5_05", "NO_POWER_5_06", "NO_POWER_5_07", "NO_POWER_5_08",
			"NO_POWER_5_09", "NO_POWER_5_10", "NO_POWER_5_11", "NO_POWER_5_12",
			"NO_POWER_5_13", "NO_POWER_5_14", "NO_POWER_5_15", "NO_POWER_5_16",
			"NO_POWER_5_17", "NO_POWER_5_18", "NO_POWER_5_19"
		]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/fight_no_power/no_power_6.png",
		"texts": [
			"NO_POWER_6_01", "NO_POWER_6_02", "NO_POWER_6_03", "NO_POWER_6_04",
			"NO_POWER_6_05", "NO_POWER_6_06", "NO_POWER_6_07", "NO_POWER_6_08",
			"NO_POWER_6_09", "NO_POWER_6_10", "NO_POWER_6_11"
		]
	}
]

var current_slide_index: int = 0
var current_text_index: int = 0
var image_tween: Tween
var text_tween: Tween
var is_transitioning: bool = false
var waiting_for_input: bool = false

func _ready() -> void:
	# Fade-in suave no áudio para não começar estourando
	var target_volume = audio_player.volume_db
	audio_player.volume_db = -80.0
	var audio_tween = create_tween()
	audio_tween.tween_property(audio_player, "volume_db", target_volume, 4.0)
	
	# Esconde tudo inicialmente
	image_rect.modulate.a = 0
	$TextBackground.modulate.a = 0
	
	# Inicia o primeiro slide após o fade in
	await get_tree().create_timer(1.0).timeout
	load_slide()

func load_slide() -> void:
	if current_slide_index >= slides.size():
		finish_cutscene()
		return
		
	is_transitioning = true
	waiting_for_input = false
	current_text_index = 0
	
	var slide = slides[current_slide_index]
	var tex = load(slide["image_path"])
	if tex:
		image_rect.texture = tex
	
	# Reseta as propriedades da imagem para preparar o efeito "Max Payne"
	image_rect.scale = Vector2(1.1, 1.1)
	image_rect.pivot_offset = Vector2(get_viewport_rect().size.x / 2.0, get_viewport_rect().size.y * 0.2)
	image_rect.position = Vector2(0, 0)
	
	# Inicia a animação de zoom out leve e pan para baixo
	if image_tween:
		image_tween.kill()
	image_tween = create_tween().set_parallel(true)
	image_tween.tween_property(image_rect, "scale", Vector2(1.0, 1.0), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	image_tween.tween_property(image_rect, "position", Vector2(0, 0), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Mostra a imagem com fade
	var show_tween = create_tween().set_parallel(true)
	show_tween.tween_property(image_rect, "modulate:a", 1.0, 1.0)
	await show_tween.finished
	
	# Mostra o primeiro texto
	show_text()

func show_text() -> void:
	var slide = slides[current_slide_index]
	if current_text_index < slide["texts"].size():
		var text_key = slide["texts"][current_text_index]
		label.text = tr(text_key)
		
		# Inicia a animação de máquina de escrever
		label.visible_characters = 0
		if text_tween:
			text_tween.kill()
		
		var text_length = label.text.length()
		var duration = text_length * 0.05
		
		text_tween = create_tween()
		text_tween.tween_property(label, "visible_characters", text_length, duration)
		
		if $TextBackground.modulate.a == 0:
			var tween = create_tween()
			tween.tween_property($TextBackground, "modulate:a", 1.0, 0.5)
		
		is_transitioning = false
		waiting_for_input = true
	else:
		next_slide()

func next_slide() -> void:
	is_transitioning = true
	waiting_for_input = false
	
	var hide_tween = create_tween().set_parallel(true)
	hide_tween.tween_property($TextBackground, "modulate:a", 0.0, 0.5)
	hide_tween.tween_property(image_rect, "modulate:a", 0.0, 1.0)
	await hide_tween.finished
	
	current_slide_index += 1
	load_slide()

func finish_cutscene() -> void:
	is_transitioning = true
	waiting_for_input = false
	
	var hide_tween = create_tween()
	hide_tween.tween_property($TextBackground, "modulate:a", 0.0, 0.5)
	
	var audio_out_tween = create_tween()
	audio_out_tween.tween_property(audio_player, "volume_db", -80.0, 2.0)
	
	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	
	# Muda a cena diretamente para a oficina
	get_tree().change_scene_to_file("res://scenes/stages/prolog/oficina_jimmy.tscn")

func _process(delta: float) -> void:
	if waiting_for_input and not is_transitioning:
		if Input.is_action_just_pressed("ui_accept"):
			if label.visible_characters >= 0 and label.visible_characters < label.text.length():
				if text_tween:
					text_tween.kill()
				label.visible_characters = -1
			else:
				current_text_index += 1
				show_text()
