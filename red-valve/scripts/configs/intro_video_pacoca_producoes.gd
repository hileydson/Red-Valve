extends VideoStreamPlayer
@onready var fade: ColorRect = $"../Fade"


var is_fading: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(4.0).timeout 
	if not is_fading:
		fade.fade_out()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_fading: return
	
	# Permite pular o video
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_menu_game"):
		_start_fade_out()

func _start_fade_out() -> void:
	if is_fading: return
	is_fading = true
	
	# Fade Out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): 
		RenderingServer.set_default_clear_color(Color.BLACK)
		get_tree().change_scene_to_file("res://scenes/configs/trailer.tscn")
	)

func _on_finished() -> void:
	if not is_fading:
		_start_fade_out()
