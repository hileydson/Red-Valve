extends VideoStreamPlayer
@onready var fade: ColorRect = $"../Fade"
@onready var video_stream_player: VideoStreamPlayer = $"."
@onready var close_valve_intro: ColorRect = $"../close_valve_intro"


signal any_input_pressed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(5.0).timeout 
	# Agora espera o input
	await self.any_input_pressed
	_on_finished()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if Input.is_action_pressed("ui_accept"):
		any_input_pressed.emit("apertou!")
		
	var tempo_atual = video_stream_player.stream_position
	if tempo_atual > 31:
		close_valve_intro.visible = true


func _on_finished() -> void:
	fade.fade_out()
	await get_tree().create_timer(2.0).timeout 
	get_tree().change_scene_to_file("res://scenes/configs/main_menu.tscn")
