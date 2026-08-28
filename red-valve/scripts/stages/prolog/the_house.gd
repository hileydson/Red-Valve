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
	await get_tree().create_timer(tempo_para_telefone, false).timeout
	
	telefone_tocando = true
	
	phone_audio = AudioStreamPlayer.new()
	phone_audio.stream = load("res://assets/cutscenes/sound/telefone_ring.mp3")
	phone_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	if GlobalUtils.in_cinematic_cutscene:
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
	GlobalEvents.in_cutscene = true
	
	# Mostrar bordas antes do fade_out para estarem prontas no fade_in
	GlobalUtils.show_cutscene_bars()
	
	$ambient/fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	
	var cam_telefone = find_child("camera_telefone", true, false)
	if cam_telefone:
		cam_telefone.make_current()
	
	$ambient/fade.fade_in()
	await get_tree().create_timer(1.0).timeout
	
	GlobalUtils.start_cinematic_text_cutscene(phone_texts)
	await GlobalUtils.cinematic_cutscene_finished
	
	# Quando o texto global termina, faz o fade e devolve a câmera
	$ambient/fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	
	var player = find_child("player", true, false)
	if player:
		var cam = player.find_child("Camera3D", true, false)
		if cam:
			cam.make_current()
			
	# Remove as bordas enquanto a tela está preta (antes do último fade_in)
	GlobalUtils.hide_cutscene_bars()
	
	$ambient/fade.fade_in()
	
	GlobalEvents.in_cutscene = false

