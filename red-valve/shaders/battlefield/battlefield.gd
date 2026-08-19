extends Node
@onready var animation_intro: AnimationPlayer = $intro_camera/animation_intro
@onready var camera_intro_2: Camera3D = $intro_camera/camera_intro_2


var player: CharacterBody3D
var enemies: Array = []
var camera_intro: Camera3D
var look_at_target: Node3D
var look_at_offset: Vector3 = Vector3.ZERO
var final_sequence_started: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveManager.save_game()
	GlobalEvents.set_high_nevoa()
	GlobalEvents.is_maycow_normal = false
	
	player = get_tree().get_first_node_in_group("player")
	enemies = get_tree().get_nodes_in_group("enemies")
	
	if player:
		# Trava a cena para modo cutscene
		player.process_mode = Node.PROCESS_MODE_DISABLED
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.process_mode = Node.PROCESS_MODE_DISABLED
		GlobalEvents.in_cutscene = true
		
		# Define qual animação tocar
		camera_intro_2.make_current()
		if not SaveManager.battlefield_1_intro_played:
			animation_intro.play("intro_first_time")
			SaveManager.battlefield_1_intro_played = true
			SaveManager.save_game()
		else:
			animation_intro.play("intro_capitulo_1")
			
		# Aguarda a animação terminar
		await animation_intro.animation_finished
		
		# Restaura os controles e física
		if is_instance_valid(player):
			player.process_mode = Node.PROCESS_MODE_INHERIT
			if "camera_third_person" in player and is_instance_valid(player.camera_third_person):
				player.camera_third_person.make_current()
				
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.process_mode = Node.PROCESS_MODE_INHERIT
				
		GlobalEvents.in_cutscene = false


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
				
	# --- VERIFICAÇÃO DO ÚLTIMO INIMIGO ---
	if not final_sequence_started and not GlobalEvents.in_cutscene and enemies.size() > 0:
		var all_dead = true
		for enemy in enemies:
			if is_instance_valid(enemy) and "dead" in enemy and not enemy.dead:
				all_dead = false
				break
				
		if all_dead:
			_start_final_sequence()

func _start_final_sequence() -> void:
	final_sequence_started = true
	GlobalEvents.in_cutscene = true
	
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	
	# 1. Ultra Câmera Lenta
	Engine.time_scale = 0.15
	
	# 2. Esconde Interface
	var ui = get_tree().root.get_node_or_null("GlobalEnemyHealthUI")
	if ui: ui.queue_free()
	
	# 3. Faz o Fade Out super lento (ignorando time_scale)
	var fade = get_tree().current_scene.get_node_or_null("fade")
	if fade:
		fade.modulate.a = 0.0
		var tween = create_tween().set_ignore_time_scale(true)
		tween.tween_property(fade, "modulate:a", 1.0, 4.0) # 4 segundos de fade
		
	# 4. Espera a animação terminar em tempo real
	await get_tree().create_timer(5.0, true, false, true).timeout
	
	# 5. Restaura e vai para a Cutscene
	Engine.time_scale = 1.0
	GlobalEvents.in_cutscene = false
	get_tree().change_scene_to_file("res://scenes/stages/prolog/fight_with_power/cutscene_fight_with_power.tscn")


func iniciar_cutscene() -> void:
	if not player or not camera_intro: return
	
	camera_intro.make_current()
	
	var anim_player = get_tree().current_scene.get_node_or_null("intro_camera/animation_intro")
	if anim_player:
		if not SaveManager.battlefield_1_intro_played:
			anim_player.play("intro_first_time")
			SaveManager.battlefield_1_intro_played = true
			SaveManager.save_game()
		else:
			anim_player.play("intro_capitulo_1")
			
		await anim_player.animation_finished
	else:
		# Fallback se não encontrar a animação
		await get_tree().create_timer(1.0).timeout
	
	# Encerramento: Restaura física e controles
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
		if "camera_third_person" in player and is_instance_valid(player.camera_third_person):
			player.camera_third_person.make_current()
			
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			
	GlobalEvents.in_cutscene = false
	# Opcional: deletar a câmera de intro apenas se nós a criamos por código
	if is_instance_valid(camera_intro) and not get_tree().current_scene.get_node_or_null("intro_camera/camera_intro_4"):
		camera_intro.queue_free()


func _on_animation_intro_animation_finished(anim_name: StringName) -> void:
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
