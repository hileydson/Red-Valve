extends VideoStreamPlayer
@onready var fade: ColorRect = $"../Fade"



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(4.0).timeout 
	fade.fade_out()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_finished() -> void:
	await get_tree().create_timer(2.0).timeout 
	get_tree().change_scene_to_file("res://scenes/configs/intro_game_video.tscn")
