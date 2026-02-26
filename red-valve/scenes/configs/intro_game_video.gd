extends VideoStreamPlayer
@onready var fade: ColorRect = $"../Fade"


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


func _on_finished() -> void:
	fade.fade_out()
	await get_tree().create_timer(2.0).timeout 
	get_tree().change_scene_to_file("res://scenes/configs/main_menu.tscn")
