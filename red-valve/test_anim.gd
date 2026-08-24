extends SceneTree

func _init():
	var scene = load("res://scenes/stages/prolog/trailer_final.tscn").instantiate()
	var monster = scene.get_node("the_anti_lopes")
	var anim_player = monster.find_child("AnimationPlayer", true, false)
	for lib_name in anim_player.get_animation_library_list():
		var lib = anim_player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			if anim_name == "Spear_Walk":
				var anim = lib.get_animation(anim_name)
				print("Tracks in Spear_Walk:")
				for i in range(anim.get_track_count()):
					print("Track ", i, " Path: ", anim.track_get_path(i), " Type: ", anim.track_get_type(i))
	quit()
