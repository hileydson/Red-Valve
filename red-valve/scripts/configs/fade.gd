extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_in()


func fade_out():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.visible = true
	var tween: Tween = create_tween()

	# Fade In: partindo de transparente para totalmente visível
	self.modulate.a = 0 # Garante que começa invisível
	tween.tween_property(self, "modulate", Color(0.0, 0.0, 0.0, 1.0), 2.0)

func fade_in():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.visible = true
	var tween: Tween = create_tween()

	# Fade In: partindo de transparente para totalmente visível
	tween.tween_property(self, "modulate", Color(0.0, 0.0, 0.0, 0.0), 2.0)
	tween.tween_callback(func(): self.visible = false)
