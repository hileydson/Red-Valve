extends Node

var player: CharacterBody3D
var enemies: Array = []
var camera_intro: Camera3D
var look_at_target: Node3D
var look_at_offset: Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveManager.save_game()
	GlobalEvents.set_high_nevoa()
	
	player = get_tree().get_first_node_in_group("player")
	enemies = get_tree().get_nodes_in_group("enemies")
	
	if player:
		# Trava a cena para modo cutscene
		player.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Cria a câmera da introdução
		camera_intro = Camera3D.new()
		add_child(camera_intro)
		
		# Coloca todos os inimigos em slow motion
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.process_mode = Node.PROCESS_MODE_DISABLED
				
		GlobalEvents.in_cutscene = true
		iniciar_cutscene()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_instance_valid(camera_intro):
		camera_intro.make_current()
		
	if look_at_target and is_instance_valid(camera_intro) and camera_intro.current:
		camera_intro.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)
		
	# Avança as animações manualmente
	if player and player.process_mode == Node.PROCESS_MODE_DISABLED:
		var pt1 = player.get_node_or_null("maycow_lopes_normal/AnimationTree")
		var pt2 = player.get_node_or_null("maycow_lopes/AnimationTree")
		if pt1 and pt1.active: pt1.advance(delta)
		if pt2 and pt2.active: pt2.advance(delta)
		
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.process_mode == Node.PROCESS_MODE_DISABLED:
			if "animation_tree" in enemy and enemy.animation_tree and enemy.animation_tree.active:
				enemy.animation_tree.advance(delta * 0.15)


func iniciar_cutscene() -> void:
	if not player or not camera_intro: return
	
	var player_pos = player.global_position
	look_at_target = player
	look_at_offset = Vector3(0, 1.0, 0) # Foca no tronco do player
	
	# FASE 1: Posição super alta para visão panorâmica
	# Reduzida a altura (Y) de 30 para 18 e o raio para não ficar tão longe
	var pos_alto = player_pos + Vector3(15.0, 18.0, 12.0)
	camera_intro.global_position = pos_alto
	camera_intro.make_current()
	
	await get_tree().create_timer(1.0).timeout
	
	# FASE 2: Giro suave no alto para ver o campo de batalha
	var pos_giro = player_pos + Vector3(-12.0, 15.0, 15.0)
	var sweep_tween = create_tween()
	sweep_tween.tween_property(camera_intro, "global_position", pos_giro, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await sweep_tween.finished
	
	# FASE 3: Mergulho até o player
	var player_forward = -player.global_transform.basis.z.normalized()
	if player_forward.length() < 0.1: player_forward = Vector3.FORWARD
	
	# Posição final próxima das costas do player
	var pos_costas = player_pos - player_forward * 2.5 + Vector3(0, 2.0, 0)
	
	var dive_tween = create_tween()
	dive_tween.tween_property(camera_intro, "global_position", pos_costas, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dive_tween.finished
	
	# Encerramento: Restaura física e controles
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
		if "camera_third_person" in player and is_instance_valid(player.camera_third_person):
			player.camera_third_person.make_current()
			
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			
	GlobalEvents.in_cutscene = false
	if is_instance_valid(camera_intro):
		camera_intro.queue_free()
