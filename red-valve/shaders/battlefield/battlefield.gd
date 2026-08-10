extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveManager.save_game()
	GlobalEvents.set_high_nevoa()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
