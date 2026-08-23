extends Node3D

@onready var camera_final: Camera3D = $camera_final
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anti_lopes: Node3D = $the_anti_lopes

const TARGET_SCALE := Vector3(0.012, 0.012, 0.012)

func _ready() -> void:
	camera_final.make_current()
	animation_player.play("final")
	_setup_anti_lopes()

func _setup_anti_lopes() -> void:
	if not is_instance_valid(anti_lopes):
		return
		
	anti_lopes.scale = TARGET_SCALE
	
	# Busca o AnimationPlayer interno do modelo GLB e limpa as faixas de escala da animação
	var internal_anim_player: AnimationPlayer = anti_lopes.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if internal_anim_player:
		for anim_name in internal_anim_player.get_animation_list():
			var anim = internal_anim_player.get_animation(anim_name)
			if anim:
				for i in range(anim.get_track_count() - 1, -1, -1):
					if anim.track_get_type(i) == Animation.TYPE_SCALE_3D:
						anim.remove_track(i)
		
		if internal_anim_player.has_animation("Spear_Walk"):
			internal_anim_player.autoplay = "Spear_Walk"
			internal_anim_player.play("Spear_Walk")

func _process(_delta: float) -> void:
	if is_instance_valid(anti_lopes):
		anti_lopes.scale = TARGET_SCALE
