extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fade_in()


func fade_out():
	var tween: Tween = get_tree().create_tween()

	# Fade In: partindo de transparente para totalmente visível
	self.modulate.a = 0 # Garante que começa invisível
	tween.tween_property(self, "modulate", Color(0.0, 0.0, 0.0, 1.0), 2.0)

func fade_in():
	var tween: Tween = get_tree().create_tween()

	# Fade In: partindo de transparente para totalmente visível
	tween.tween_property(self, "modulate", Color(0.0, 0.0, 0.0, 0.0), 2.0)
