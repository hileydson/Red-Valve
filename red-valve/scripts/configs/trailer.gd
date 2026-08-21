extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func cutscene_force_maycow_lopes_only() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		
		for child in player.get_children():
			if child is Node3D and "visible" in child:
				# Ignorar câmeras e colisões/springarms para não quebrar o jogo
				if child is Camera3D or child is SpringArm3D or child is Marker3D or child is CollisionShape3D:
					continue
				
				# Deixa apenas o maycow_lopes visível e esconde os outros (incluindo braços e o normal)
				if child.name == "maycow_lopes":
					child.visible = true
				elif child.name == "maycow_lopes_normal" or "hand" in child.name.to_lower() or child is MeshInstance3D:
					child.visible = false
