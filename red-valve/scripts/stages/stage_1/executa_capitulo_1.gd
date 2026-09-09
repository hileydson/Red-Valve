extends AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func set_in_cutscene()->void:
	GlobalEvents.set_in_cutscene()
func unset_in_cutscene()->void:
	GlobalEvents.unset_in_cutscene()
