extends SceneTree

func _init():
	var scene = load("res://assets/3d_model/player/Maycow Lopes/maycow_lopes.glb")
	var instance = scene.instantiate()
	var ap = instance.get_node("AnimationPlayer")
	print("ANIMATIONS:", ap.get_animation_list())
	quit()
