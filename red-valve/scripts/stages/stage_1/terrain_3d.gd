extends Terrain3D


# No script do seu Terrain3D (ou de quem o gerencia)
func _ready():
	# Alguns plugins de terreno precisam que você force a atualização da física
	var terrain = $"." # substitua pelo caminho do seu nó
	if terrain.has_method("update_collision"):
		terrain.update_collision()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
