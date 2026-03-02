extends Node2D

@onready var resume: Button = $Control/VSplitContainer/resume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_pause"):
		toogle_pause()
		

func toogle_pause():
	if get_tree().paused:
		get_tree().paused = false
		self.visible = false
	else:
		get_tree().paused = true
		self.visible = true
		resume.grab_focus()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	self.visible = false


func _on_exit_pressed() -> void:
	get_tree().quit()
