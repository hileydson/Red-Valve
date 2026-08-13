extends Control

@onready var image_rect: TextureRect = $ImageRect
@onready var label: Label = $TextBackground/Label
@onready var fade = $fade
@onready var audio_player: AudioStreamPlayer = $Begin

var slides = [
	{
		"image_path": "res://assets/cutscenes/prolog/end_first_fight/end_fight_1.png",
		"texts": [
			"END_FIGHT_1_1", "END_FIGHT_1_2", "END_FIGHT_1_3", "END_FIGHT_1_4",
			"END_FIGHT_1_5"
		]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/end_first_fight/end_fight_2.png",
		"texts": [
			"END_FIGHT_2_1", "END_FIGHT_2_2", "END_FIGHT_2_3", "END_FIGHT_2_4",
			"END_FIGHT_2_5", "END_FIGHT_2_6", "END_FIGHT_2_7"
		]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/end_first_fight/end_fight_3.png",
		"texts": [
			"END_FIGHT_3_1", "END_FIGHT_3_2", "END_FIGHT_3_3", "END_FIGHT_3_4",
			"END_FIGHT_3_5"
		]
	},
	{
		"image_path": "res://assets/cutscenes/prolog/end_first_fight/end_fight_4.png",
		"texts": [
			"END_FIGHT_4_1", "END_FIGHT_4_2", "END_FIGHT_4_3"
		]
	}
]

var current_slide_index: int = 0
var current_text_index: int = 0
var image_tween: Tween
var text_tween: Tween
var is_transitioning: bool = false
var waiting_for_input: bool = false
var finished: bool = false

func _ready() -> void:
	# -- INJEÇÃO DO FILTRO VHS --
	var vhs_mat = ShaderMaterial.new()
	vhs_mat.shader = load("res://shaders/vhs_filter.gdshader")
	if "image_rect" in self and self.get("image_rect") != null:
		self.get("image_rect").material = vhs_mat
	elif has_node("ImageRect"):
		get_node("ImageRect").material = vhs_mat
	# ---------------------------

	# Instancia o UI de Skip
	var skip_layer = CanvasLayer.new()
	skip_layer.layer = 128
	var skip_ui = load("res://scripts/ui/skip_cutscene_ui.gd").new()
	skip_layer.add_child(skip_ui)
	add_child(skip_layer)
	skip_ui.skipped.connect(finish_cutscene)
	
	# Fade-in suave no áudio para não começar estourando
	var target_volume = audio_player.volume_db
	audio_player.volume_db = -80.0
	var audio_tween = create_tween()
	audio_tween.tween_property(audio_player, "volume_db", target_volume, 4.0)
	
	# Esconde tudo inicialmente
	image_rect.modulate.a = 0
	$TextBackground.modulate.a = 0
	
	# Inicia o primeiro slide após o fade in (fade_in é chamado no _ready do fade.gd)
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
	image_rect.position = Vector2(0, 0) # Deixa a imagem iniciar no centro
	
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
		
		# Define o tempo baseado na quantidade de letras (0.05 segundos por letra)
		var text_length = label.text.length()
		var duration = text_length * 0.05
		
		text_tween = create_tween()
		text_tween.tween_property(label, "visible_characters", text_length, duration)
		
		# Mostra fundo escuro do texto se estiver oculto
		if $TextBackground.modulate.a == 0:
			var tween = create_tween()
			tween.tween_property($TextBackground, "modulate:a", 1.0, 0.5)
		
		is_transitioning = false
		waiting_for_input = true
	else:
		# Acabaram os textos deste slide, vai para o próximo
		next_slide()


func next_slide() -> void:
	is_transitioning = true
	waiting_for_input = false
	
	# Esconde o texto e a imagem do slide atual
	var hide_tween = create_tween().set_parallel(true)
	hide_tween.tween_property($TextBackground, "modulate:a", 0.0, 0.5)
	hide_tween.tween_property(image_rect, "modulate:a", 0.0, 1.0)
	await hide_tween.finished
	
	current_slide_index += 1
	load_slide()


func finish_cutscene() -> void:
	if finished: return
	finished = true
	
	if image_tween: image_tween.kill()
	if text_tween: text_tween.kill()
	
	is_transitioning = true
	waiting_for_input = false
	
	# Esconde o background do texto
	var hide_tween = create_tween()
	hide_tween.tween_property($TextBackground, "modulate:a", 0.0, 0.5)
	
	# Fade-out do áudio junto com o fade_out visual
	var audio_out_tween = create_tween()
	audio_out_tween.tween_property(audio_player, "volume_db", -80.0, 2.0)
	
	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	
	# Despausa o jogo caso a cutscene estivesse pausada
	get_tree().paused = false
	
	# Transição para a próxima cena (battlefield_1)
	get_tree().change_scene_to_file("res://scenes/stages/battlefield/battlefield_1.tscn")


func _process(delta: float) -> void:
	if waiting_for_input and not is_transitioning:
		if Input.is_action_just_pressed("ui_accept"):
			# Se o texto ainda está sendo animado, completa ele imediatamente
			if label.visible_characters >= 0 and label.visible_characters < label.text.length():
				if text_tween:
					text_tween.kill()
				label.visible_characters = -1
			else:
				# Se o texto já foi todo lido, avança para o próximo
				current_text_index += 1
				show_text()
