extends CharacterBody3D

const SPEED = 5.0

@onready var player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	# 1. Gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if player:
		# 2. Direção Direta (Ignore obstáculos por um momento para testar o FPS)
		var direction = (player.global_position - global_position)
		direction.y = 0
		direction = direction.normalized()
		
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# 3. Olhar para o player
		var look_pos = player.global_position
		look_pos.y = global_position.y
		if global_position.distance_to(look_pos) > 0.5:
			look_at(look_pos, Vector3.UP)

	# 4. Move
	move_and_slide()
