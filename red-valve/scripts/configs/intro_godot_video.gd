extends Node2D

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
var is_fading: bool = false

func _ready() -> void:
	# Fade In
	video.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(video, "modulate:a", 1.0, 1.5)

func _process(delta: float) -> void:
	if is_fading: return
	
	# Inicia o fade out 1.5s antes do vídeo terminar (Duração total aprox: 9.95s)
	if video.stream_position >= 8.45:
		_start_fade_out()
	
	# Permite pular o video
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_menu_game"):
		_start_fade_out()

func _start_fade_out() -> void:
	if is_fading: return
	is_fading = true
	
	# Fade Out
	var tween = create_tween()
	tween.tween_property(video, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/configs/intro_pacoca_producoes.tscn"))

func _on_finished() -> void:
	# Fallback caso o vídeo termine antes do stream_position atingir o alvo por algum bug de framerate
	if not is_fading:
		_start_fade_out()
