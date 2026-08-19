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
		
		var is_first_time = not SaveManager.battlefield_1_intro_played
		
		# Define qual animação tocar e impede que a câmera desligue no final
		if is_first_time:
			var anim = animation_intro.get_animation("intro_first_time")
			for i in range(anim.get_track_count()):
				if str(anim.track_get_path(i)).ends_with(":current"):
					var key_idx = anim.track_get_key_count(i) - 1
					if key_idx >= 0 and anim.track_get_key_value(i, key_idx) == false:
						anim.track_set_key_value(i, key_idx, true)
						
			camera_intro_2.make_current()
			animation_intro.play("intro_first_time")
			SaveManager.battlefield_1_intro_played = true
			SaveManager.save_game()
		else:
			var anim = animation_intro.get_animation("intro_capitulo_1")
			var last_cam_path = ""
			for i in range(anim.get_track_count()):
				if str(anim.track_get_path(i)).ends_with(":current"):
					var key_idx = anim.track_get_key_count(i) - 1
					if key_idx >= 0 and anim.track_get_key_value(i, key_idx) == false:
						anim.track_set_key_value(i, key_idx, true)
					last_cam_path = str(anim.track_get_path(i)).replace(":current", "")
			
			animation_intro.play("intro_capitulo_1")
			
			# Aplica Blur na câmera para simular Motion Blur (Aplica na última câmera usada na animação)
			if last_cam_path != "":
				var cam_final = get_tree().current_scene.get_node_or_null(last_cam_path)
				if cam_final:
					var blur_attr = CameraAttributesPractical.new()
					blur_attr.dof_blur_far_enabled = true
					blur_attr.dof_blur_far_distance = 2.0
					blur_attr.dof_blur_far_transition = 5.0
					cam_final.attributes = blur_attr
			
		# Aguarda a animação terminar
		await animation_intro.animation_finished
		
		if not is_first_time:
			# Descobre qual foi a câmera final da animação
			var anim = animation_intro.get_animation("intro_capitulo_1")
			var last_cam_path = ""
			for i in range(anim.get_track_count()):
				if str(anim.track_get_path(i)).ends_with(":current"):
					last_cam_path = str(anim.track_get_path(i)).replace(":current", "")
					
			var cam_final = get_tree().current_scene.get_node_or_null(last_cam_path)
			if cam_final:
				cam_final.attributes = null # Remove o blur
			
			# Som de explosão em slow motion
			var exp_sound = AudioStreamPlayer.new()
			exp_sound.stream = preload("res://assets/sounds/common/explosao.mp3")
			exp_sound.pitch_scale = 0.4 # Som grave de câmera lenta
			add_child(exp_sound)
			exp_sound.play()
			
			# Efeito visual da explosão no meio da arena
			var arena_center = Vector3(0, 1.0, 0)
			_spawn_red_explosion_vfx(arena_center)
			
			# Slow motion brutal da explosão
			Engine.time_scale = 0.05
			
			# Vibra o controle (Tremor de tela)
			GlobalUtils.vibrate_controller(Input, 1.0, 1.0, 1.0)
			
			# Tremidinha bruta na câmera de intro final
			if cam_final:
				var tween_shake = create_tween().set_ignore_time_scale(true)
				tween_shake.tween_property(cam_final, "v_offset", 0.8, 0.03)
				tween_shake.tween_property(cam_final, "v_offset", -0.8, 0.03)
				tween_shake.tween_property(cam_final, "v_offset", 0.5, 0.03)
				tween_shake.tween_property(cam_final, "v_offset", -0.5, 0.03)
				tween_shake.tween_property(cam_final, "v_offset", 0.0, 0.03)
				
			# Espera 1.5 segundo real (curtindo a explosão épica e lenta)
			await get_tree().create_timer(1.5, true, false, true).timeout
			
			# Restaura o tempo gradualmente
			var time_tween = create_tween().set_ignore_time_scale(true)
			time_tween.tween_property(Engine, "time_scale", 1.0, 0.5)
			await time_tween.finished
			
			exp_sound.queue_free()
			
		# Restaura os controles e física APÓS o fim de toda a cutscene/explosão
		if is_instance_valid(player):
			player.process_mode = Node.PROCESS_MODE_INHERIT
			if "camera_third_person" in player and is_instance_valid(player.camera_third_person):
				player.camera_third_person.make_current()
				
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.process_mode = Node.PROCESS_MODE_INHERIT
				
		GlobalEvents.in_cutscene = false


func _spawn_red_explosion_vfx(pos: Vector3):
	var node = Node3D.new()
	get_tree().current_scene.add_child(node)
	node.global_position = pos
	
	# Flash de Luz Vermelha
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.1, 0.0)
	flash.light_energy = 30.0
	flash.omni_range = 50.0
	flash.shadow_enabled = false
	node.add_child(flash)
	var tween_light = create_tween()
	tween_light.tween_property(flash, "light_energy", 0.0, 1.2)
	
	# Sparks (Fagulhas volumosas) Vermelhas
	var sparks = CPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 150
	sparks.lifetime = 1.6
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.initial_velocity_min = 20.0
	sparks.initial_velocity_max = 50.0
	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(1.0, 0.1, 0.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.05, 0.0)
	spark_mat.emission_energy_multiplier = 12.0
	var spark_mesh = SphereMesh.new()
	spark_mesh.radius = 0.05
	spark_mesh.height = 0.1
	spark_mesh.material = spark_mat
	sparks.mesh = spark_mesh
	node.add_child(sparks)
	
	# Fumaça expansiva
	var smoke = CPUParticles3D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 50
	smoke.lifetime = 1.5
	smoke.explosiveness = 0.95
	smoke.spread = 180.0
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 18.0
	smoke.gravity = Vector3(0, 3.0, 0)
	var smoke_mat = StandardMaterial3D.new()
	var tex = load("res://assets/images/vfx/smoke.png")
	if tex:
		smoke_mat.albedo_texture = tex
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		smoke_mat.albedo_color = Color(1.0, 0.6, 0.6, 1.0) # Tint avermelhado na fumaça
	var smoke_mesh = QuadMesh.new()
	smoke_mesh.size = Vector2(25, 25)
	smoke_mesh.material = smoke_mat
	smoke.mesh = smoke_mesh
	node.add_child(smoke)
	
	get_tree().create_timer(6.0).timeout.connect(func(): 
		if is_instance_valid(node): 
			node.queue_free()
	)


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
	# O controle de câmera e física agora é feito no final da corrotina _ready()
	# Isso garante que a explosão e o slow motion rodem por completo antes do Player assumir.
	pass
