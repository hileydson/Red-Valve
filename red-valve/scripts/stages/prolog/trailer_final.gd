extends Node3D

@onready var camera_final: Camera3D = $camera_final
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anti_lopes: Node3D = $the_anti_lopes

const FLOATING_POSITION := Vector3(0, 1.2, 0)
var skeleton_ref: Skeleton3D = null

func _ready() -> void:
	camera_final.make_current()
	animation_player.play("final")
	_setup_anti_lopes()

func _setup_anti_lopes() -> void:
	if not is_instance_valid(anti_lopes):
		return
		
	anti_lopes.position = FLOATING_POSITION
	skeleton_ref = anti_lopes.find_child("GeneralSkeleton", true, false) as Skeleton3D
	
	var internal_anim_player: AnimationPlayer = anti_lopes.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if internal_anim_player:
		internal_anim_player.stop()
		
		# Percorre todas as bibliotecas de animação e remove faixas de posição 3D
		for lib_name in internal_anim_player.get_animation_library_list():
			var lib = internal_anim_player.get_animation_library(lib_name)
			if lib:
				for anim_name in lib.get_animation_list():
					var anim = lib.get_animation(anim_name)
					if anim:
						for i in range(anim.get_track_count() - 1, -1, -1):
							if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
								anim.remove_track(i)
		
		internal_anim_player.clear_caches()
		if internal_anim_player.has_animation("Spear_Walk"):
			internal_anim_player.play("Spear_Walk")

func _process(_delta: float) -> void:
	if is_instance_valid(anti_lopes):
		anti_lopes.position = FLOATING_POSITION
		
		# Trava a posição da bacia (osso 0 / Hips) no esqueleto para impedir qualquer deslocamento acumulado no loop
		if is_instance_valid(skeleton_ref) and skeleton_ref.get_bone_count() > 0:
			skeleton_ref.set_bone_pose_position(0, Vector3.ZERO)
