extends VideoStreamPlayer

var is_fading: bool = false

func _ready() -> void:
	# Fade In
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.5)

func _process(_delta: float) -> void:
	if is_fading: return
	
	# Permite pular o video
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_menu_game"):
		_start_fade_out()

func _start_fade_out() -> void:
	if is_fading: return
	is_fading = true
	RenderingServer.set_default_clear_color(Color.BLACK)

	# Fade Out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/configs/trailer.tscn")
	)

func _on_finished() -> void:
	if not is_fading:
		_start_fade_out()
