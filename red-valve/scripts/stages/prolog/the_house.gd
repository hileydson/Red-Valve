extends Node3D

@export var tempo_para_telefone: float = 120.0

var player_na_porta: bool = false
var player_no_telefone: bool = false
var player_na_tv: bool = false
var telefone_tocando: bool = false
var telefone_atendido: bool = false
var tv_ligada: bool = true
var prompt_label: Label
var phone_audio: AudioStreamPlayer
var ui_layer: CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveManager.save_game()
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()
	
	# Cria uma camada UI por cima de todos os shaders
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 128
	add_child(ui_layer)
	
	# Cria o prompt visual por código
	prompt_label = Label.new()
	prompt_label.text = tr("PROMPT_LEAVE_HOUSE")
	prompt_label.visible = false
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Aumentando o tamanho da fonte para melhor leitura
	prompt_label.add_theme_font_size_override("font_size", 16)
	# Adicionando um contorno na fonte para destacar na cena
	prompt_label.add_theme_constant_override("outline_size", 4)
	ui_layer.add_child(prompt_label)
	
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
	await get_tree().create_timer(3.0).timeout
	
	var tv_label = Label.new()
	tv_label.text = tr("TXT_HOUSE_TV")
	tv_label.set_anchors_preset(Control.PRESET_CENTER)
	tv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Fonte levemente maior para esse texto narrativo
	tv_label.add_theme_font_size_override("font_size", 18)
	tv_label.add_theme_constant_override("outline_size", 4)
	ui_layer.add_child(tv_label)
	
	# Efeito de Fade In suave
	tv_label.modulate.a = 0
	var tween_in = create_tween()
	tween_in.tween_property(tv_label, "modulate:a", 1.0, 1.0)
	await tween_in.finished
	
	# Fica na tela por 3 segundos
	await get_tree().create_timer(3.0).timeout
	
	# Efeito de Fade Out e remove da memória
	var tween_out = create_tween()
	tween_out.tween_property(tv_label, "modulate:a", 0.0, 1.0)
	await tween_out.finished
	tv_label.queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if player_na_porta:
			# Previne que o jogador aperte o botão várias vezes
			player_na_porta = false
			prompt_label.visible = false
			
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
			prompt_label.visible = false
			
			if is_instance_valid(phone_audio):
				phone_audio.stop()
				phone_audio.queue_free()
			
			# Fade out antes de pausar
			$ambient/fade.fade_out()
			await get_tree().create_timer(2.0).timeout
			
			var cutscene_scene = load("res://scenes/stages/prolog/cutscene_telefone.tscn")
			var cutscene_instance = cutscene_scene.instantiate()
			
			# Cria um CanvasLayer para renderizar acima do fade e independente da pausa
			var canvas = CanvasLayer.new()
			canvas.layer = 100
			canvas.process_mode = Node.PROCESS_MODE_ALWAYS
			canvas.add_child(cutscene_instance)
			get_tree().root.add_child(canvas)
			
			get_tree().paused = true
			
			# Aguarda a cutscene se destruir para voltar o jogo
			await cutscene_instance.tree_exited
			
			# O jogo já foi despausado pela cutscene, fazemos o fade in para revelar a sala
			$ambient/fade.fade_in()
		elif player_na_tv:
			tv_ligada = not tv_ligada
			_update_prompt()
			
			var tv_video = $ambient/casa/itens_da_casa/tv/SubViewport/VideoStreamPlayer
			var tv_audio = $"ambient/casa/itens_da_casa/tv/Sketchfab_model/5836d5dd2aa14c29a482c9966515dc07_fbx/RootNode/Cube_003/Cube_003_Screen_0/AudioStreamPlayer3D"
			var tv_light = $"ambient/casa/itens_da_casa/tv/Sketchfab_model/5836d5dd2aa14c29a482c9966515dc07_fbx/RootNode/Cube_003/Cube_003_Screen_0/SpotLight3D"
			
			if tv_ligada:
				tv_video.paused = false
				tv_video.visible = true
				tv_audio.stream_paused = false
				tv_light.visible = true
			else:
				tv_video.paused = true
				tv_video.visible = false
				tv_audio.stream_paused = true
				tv_light.visible = false


func _update_prompt() -> void:
	if player_na_porta:
		prompt_label.text = tr("PROMPT_LEAVE_HOUSE")
		prompt_label.visible = true
	elif player_no_telefone and telefone_tocando:
		prompt_label.text = tr("PROMPT_ANSWER_PHONE")
		prompt_label.visible = true
	elif player_na_tv:
		if tv_ligada:
			prompt_label.text = tr("PROMPT_TURN_OFF_TV")
		else:
			prompt_label.text = tr("PROMPT_TURN_ON_TV")
		prompt_label.visible = true
	else:
		prompt_label.visible = false


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
