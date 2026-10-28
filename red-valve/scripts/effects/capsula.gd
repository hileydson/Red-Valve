extends RigidBody3D

func _ready():
	# Tempo de vida de 10 segundos para não encher a memória do jogo
	await get_tree().create_timer(10.0).timeout
	queue_free()
