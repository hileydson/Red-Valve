extends CanvasLayer

@onready var resume: Button = $Control/VSplitContainer/resume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if not self.visible and get_tree().paused:
			return # Não abre se já estiver pausado (ex: Inventário aberto)
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
	get_tree().paused = false
	self.visible = false
	get_tree().change_scene_to_file("res://scenes/configs/main_menu.tscn")

func _on_config_pressed() -> void:
	var config_script = load("res://scripts/ui/config_menu.gd")
	if config_script:
		var config_menu = config_script.new()
		get_parent().add_child(config_menu)
		self.visible = false
