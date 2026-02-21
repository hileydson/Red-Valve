extends GPUParticles3D
@onready var mancha: Sprite3D = $mancha

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	emitting = true
	
	var tween = create_tween()
	tween.tween_property(mancha, "modulate:a", 0, 0.3) # Fade out
	#tween.finished.connect(queue_free)
	# Apaga o nó automaticamente após o efeito acabar
	await get_tree().create_timer(lifetime).timeout
	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
