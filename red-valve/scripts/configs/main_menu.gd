extends Node3D

@onready var start: Button = $Control/VSplitContainer/start

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start.grab_focus()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
