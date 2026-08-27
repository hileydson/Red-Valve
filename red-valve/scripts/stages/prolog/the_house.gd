extends Node3D

@export var tempo_para_telefone: float = 120.0

var player_na_porta: bool = false
var player_no_telefone: bool = false
var player_na_tv: bool = false
var telefone_tocando: bool = false
var telefone_atendido: bool = false
var tv_ligada: bool = true
var phone_audio: AudioStreamPlayer
var ui_layer: CanvasLayer

# --- Váriaveis da Cutscene do Telefone em Tempo Real ---
var in_phone_cutscene: bool = false
var current_phone_text_index: int = 0
var phone_overlay: ColorRect
var phone_label: Label
var is_text_transitioning: bool = false
var current_text_generation: int = 0
var phone_typing_audio: AudioStreamPlayer
var phone_texts = [
	"PROLOG_PHONE_1_1", "PROLOG_PHONE_1_2", "PROLOG_PHONE_1_3", "PROLOG_PHONE_1_4", "PROLOG_PHONE_1_5", "PROLOG_PHONE_1_6", "PROLOG_PHONE_1_7",
	"PROLOG_PHONE_2_1", "PROLOG_PHONE_2_2", "PROLOG_PHONE_2_3", "PROLOG_PHONE_2_4", "PROLOG_PHONE_2_5", "PROLOG_PHONE_2_6", "PROLOG_PHONE_2_7", "PROLOG_PHONE_2_8",
	"PROLOG_PHONE_3_1", "PROLOG_PHONE_3_2", "PROLOG_PHONE_3_3", "PROLOG_PHONE_3_4"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveManager.prolog_finished = false
	SaveManager.save_game()
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()
	
	# Cria uma camada UI por cima de todos os shaders
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 128
	add_child(ui_layer)
	
	_show_intro_text()
	_play_phone_ring_after_delay()

func _play_phone_ring_after_delay() -> void:
	# Aguarda o tempo configurado no inspetor (padrão 120 segundos)
	await get_tree().create_timer(tempo_para_telefone).timeout
	
	telefone_tocando = true
	
	phone_audio = AudioStreamPlayer.new()
	phone_audio.stream = load("res://assets/cutscenes/sound/telefone_ring.mp3")
	add_child(phone_audio)
	phone_audio.play()
	
	# Quando o áudio terminar, remove o node da memória para otimização
	phone_audio.finished.connect(phone_audio.queue_free)

func _show_intro_text() -> void:
	await get_tree().create_timer(1.0).timeout
	
	# Exibe o título "PRÓLOGO" em vermelho bem grande no centro da tela (tamanho 120 com a fonte Tiny5 do splash)
	var title_label = Label.new()
	title_label.text = tr("TXT_PROLOGUE").to_upper()
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 180)
	title_label.add_theme_color_override("font_color", Color(0.705882, 0.0, 0.0))
	
	var custom_font = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
	if custom_font:
		title_label.add_theme_font_override("font", custom_font)
		
	ui_layer.add_child(title_label)
	
	title_label.modulate.a = 0.0
	var title_tween_in = create_tween()
	title_tween_in.tween_property(title_label, "modulate:a", 1.0, 1.0)
	await title_tween_in.finished
	
	await get_tree().create_timer(3.0).timeout
	
	if is_instance_valid(title_label):
		var title_tween_out = create_tween()
		title_tween_out.tween_property(title_label, "modulate:a", 0.0, 1.0)
		await title_tween_out.finished
		title_label.queue_free()
	
	await get_tree().create_timer(1.0).timeout
	
	GlobalUtils.show_center_message("narrativa_tv", tr("TXT_HOUSE_TV"), 18, 4.0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if in_phone_cutscene:
		if Input.is_action_just_pressed("ui_accept"):
			if is_text_transitioning and phone_label and phone_label.visible_characters < phone_label.text.length():
				# Pula a digitação
				phone_label.visible_characters = phone_label.text.length()
				is_text_transitioning = false
			elif not is_text_transitioning:
				_next_phone_text()
		return
		
	if Input.is_action_just_pressed("ui_accept"):
		if player_na_porta:
			# Previne que o jogador aperte o botão várias vezes
			player_na_porta = false
			GlobalEvents.in_cutscene = true
			GlobalUtils.hide_center_message("interacao_casa")
			
			# Chama o efeito de fade out
			$ambient/fade.fade_out()
			
			# Aguarda 2 segundos para o efeito terminar
			await get_tree().create_timer(2.0).timeout
			
			# Transporta para a cena stage_1 seguindo o padrão atual do projeto
			LoadingScreen.load_scene("res://scenes/stages/stage_1/stage_1.tscn")
		elif player_no_telefone and telefone_tocando:
			player_no_telefone = false
			telefone_tocando = false
			telefone_atendido = true
			GlobalEvents.in_cutscene = true
			GlobalUtils.hide_center_message("interacao_casa")
			
			if is_instance_valid(phone_audio):
				phone_audio.stop()
				phone_audio.queue_free()
			
			# Inicia cutscene em tempo real
			_start_phone_cutscene()
		elif player_na_tv:
			tv_ligada = not tv_ligada
			_update_prompt()
			
			var tv_video = $ambient/casa/itens_da_casa/tv/SubViewport/VideoStreamPlayer
			var tv_audio = $"ambient/casa/itens_da_casa/tv/Sketchfab_model/5836d5dd2aa14c29a482c9966515dc07_fbx/RootNode/Cube_003/Cube_003_Screen_0/AudioStreamPlayer3D"
			var tv_light = $"ambient/casa/itens_da_casa/tv/Sketchfab_model/5836d5dd2aa14c29a482c9966515dc07_fbx/RootNode/Cube_003/Cube_003_Screen_0/SpotLight3D"
			
			if tv_ligada:
				tv_video.process_mode = Node.PROCESS_MODE_INHERIT
				tv_video.visible = true
				tv_audio.process_mode = Node.PROCESS_MODE_INHERIT
				tv_light.visible = true
			else:
				tv_video.process_mode = Node.PROCESS_MODE_DISABLED
				tv_video.visible = false
				tv_audio.process_mode = Node.PROCESS_MODE_DISABLED
				tv_light.visible = false


func _update_prompt() -> void:
	GlobalUtils.hide_center_message("interacao_casa")
	if player_na_porta:
		GlobalUtils.show_center_message("interacao_casa", tr("PROMPT_LEAVE_HOUSE"), 16)
	elif player_no_telefone and telefone_tocando:
		GlobalUtils.show_center_message("interacao_casa", tr("PROMPT_ANSWER_PHONE"), 16)
	elif player_na_tv:
		if tv_ligada:
			GlobalUtils.show_center_message("interacao_casa", tr("PROMPT_TURN_OFF_TV"), 16)
		else:
			GlobalUtils.show_center_message("interacao_casa", tr("PROMPT_TURN_ON_TV"), 16)


func _on_area_3d_body_entered(body: Node3D) -> void:
	# Verifica se quem entrou na área foi o player e se já atendeu o telefone
	if (body.name == "player" or body.is_in_group("player")) and telefone_atendido:
		player_na_porta = true
		_update_prompt()


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_na_porta = false
		_update_prompt()


func _on_area_3d_telefone_body_entered(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_no_telefone = true
		_update_prompt()

func _on_area_3d_telefone_body_exited(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_no_telefone = false
		_update_prompt()


func _on_area_3d_tv_body_entered(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_na_tv = true
		_update_prompt()

func _on_area_3d_tv_body_exited(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_na_tv = false
		_update_prompt()

# --- Funções da Cutscene do Telefone em Tempo Real ---

func _start_phone_cutscene() -> void:
	in_phone_cutscene = true
	is_text_transitioning = true
	
	$ambient/fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	
	var cam_telefone = find_child("camera_telefone", true, false)
	if cam_telefone:
		cam_telefone.make_current()
		
	var cutscene_bars = find_child("cutscene", true, false)
	if cutscene_bars:
		cutscene_bars.visible = true
		
	_setup_phone_cutscene_ui()
	current_phone_text_index = 0
	
	$ambient/fade.fade_in()
	await get_tree().create_timer(1.0).timeout
	_show_phone_text()

func _setup_phone_cutscene_ui() -> void:
	if not phone_typing_audio:
		phone_typing_audio = AudioStreamPlayer.new()
		phone_typing_audio.volume_db = -5.0
		var typing_sound_path = "res://assets/sounds/episodios/prologo/typing.mp3"
		if ResourceLoader.exists(typing_sound_path):
			phone_typing_audio.stream = load(typing_sound_path)
		add_child(phone_typing_audio)

	if not phone_overlay:
		phone_overlay = ColorRect.new()
		phone_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		phone_overlay.color = Color(0.05, 0.05, 0.05, 0.85)
		phone_overlay.modulate.a = 0.0
		ui_layer.add_child(phone_overlay)
		
		phone_label = Label.new()
		phone_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		phone_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		phone_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		phone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		phone_label.add_theme_font_override("font", load("res://assets/fonts/Montserrat-ExtraBold.ttf"))
		phone_label.add_theme_font_size_override("font_size", 28)
		phone_label.add_theme_color_override("font_color", Color.WHITE)
		phone_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		phone_label.add_theme_constant_override("shadow_outline_size", 4)
		phone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		phone_label.custom_minimum_size = Vector2(800, 0)
		phone_label.modulate.a = 0.0
		ui_layer.add_child(phone_label)
		
	var t = create_tween()
	t.tween_property(phone_overlay, "modulate:a", 1.0, 1.0)

func _show_phone_text() -> void:
	if current_phone_text_index < phone_texts.size():
		var full_text = tr(phone_texts[current_phone_text_index])
		phone_label.text = full_text
		phone_label.visible_characters = 0
		phone_label.modulate.a = 1.0
		
		is_text_transitioning = true
		current_text_generation += 1
		var my_generation = current_text_generation
		
		for i in range(full_text.length()):
			if my_generation != current_text_generation:
				return # Loop cancelado por outra chamada
			if phone_label.visible_characters >= full_text.length():
				break # Skipped pelo usuário
				
			phone_label.visible_characters += 1
			if full_text[i] != " " and is_instance_valid(phone_typing_audio) and phone_typing_audio.stream != null:
				# Varia sutilmente o pitch para o som não ficar artificial
				phone_typing_audio.pitch_scale = randf_range(0.95, 1.05)
				phone_typing_audio.play()
			
			await get_tree().create_timer(0.05).timeout
			
		is_text_transitioning = false
	else:
		_end_phone_cutscene()

func _next_phone_text() -> void:
	is_text_transitioning = true
	var t = create_tween()
	t.tween_property(phone_label, "modulate:a", 0.0, 0.3)
	await t.finished
	
	current_phone_text_index += 1
	_show_phone_text()

func _end_phone_cutscene() -> void:
	is_text_transitioning = true
	
	$ambient/fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	
	if phone_overlay: phone_overlay.modulate.a = 0.0
	if phone_label: phone_label.modulate.a = 0.0
	
	var cutscene_bars = find_child("cutscene", true, false)
	if cutscene_bars:
		cutscene_bars.visible = false
		
	var player = find_child("player", true, false)
	if player:
		var cam = player.find_child("Camera3D", true, false)
		if cam:
			cam.make_current()
	
	$ambient/fade.fade_in()
	
	in_phone_cutscene = false
	GlobalEvents.in_cutscene = false

