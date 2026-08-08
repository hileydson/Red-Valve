extends Node3D

@onready var camera_oficina: Camera3D = $camera_oficina

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalEvents.is_maycow_normal = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
