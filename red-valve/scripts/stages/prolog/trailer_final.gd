extends Node3D

@onready var camera_final: Camera3D = $camera_final
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anti_lopes: Node3D = $the_anti_lopes


func _ready() -> void:
	camera_final.make_current()
	#animation_player.play("final")
	
