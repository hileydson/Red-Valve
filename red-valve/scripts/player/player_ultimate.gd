extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func _activate_cogblade_ultimate() -> void:
	# Mata qualquer tween de câmera lenta pendente (ex: do impacto da cogblade)
	# para que ele não force o time_scale de volta a 1.0 no meio da cinemática do ultimate
	if GlobalUtils.current_time_tween and GlobalUtils.current_time_tween.is_valid():
		GlobalUtils.current_time_tween.kill()

	player.is_using_ultimate = true
	player.cogblade_power_value = 0.0
	player.cogblade_pulsing = false
	if player.cogblade_pulse_tween: player.cogblade_pulse_tween.kill()
	if player.cogblade_particles: player.cogblade_particles.emitting = false
	if player.cogblade_hud:
		player.cogblade_hud.value = 0.0
		player.cogblade_hud.tint_progress = Color(1, 1, 1, 1.0)
		player.cogblade_hud.modulate = Color(1, 1, 1, 1.0)
	
	# Cancela a lâmina se estiver no ar/retornando (evita glitch de velocidade)
	player.is_blade_returning = false
	player.crescent_cogblade.top_level = false
	player.crescent_cogblade.position = player.magic_blade_pos_original
	player.crescent_cogblade.rotation = Vector3.ZERO
	player.crescent_cogblade.scale = Vector3.ONE
	player.crescent_cogblade.hide()
	
	# 1. Preparação
	Engine.time_scale = 0.1
	AudioServer.playback_speed_scale = 0.5 # Deixa os sons graves/lentos
	
	player.control_magic.visible = false
	player.control_weapons.visible = false
	player.hand_with_pistol.visible = false
	if player.hand_with_magic: player.hand_with_magic.visible = false
	if player.point: player.point.visible = false # Esconde o ponto no meio da tela
	
	if player.hud_layer:
		player.hud_layer.visible = false
		var blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
		if blur:
			blur.visible = true
			blur.material.set_shader_parameter("blur_strength", 0.2) # Motion blur bem sutil
			
	# Para animações e zera a velocidade para não deslizar
	player.playback.travel("idle")
	player.velocity = Vector3.ZERO
	
	# Cria uma câmera temporária cinemática
	var cine_cam = Camera3D.new()
	get_tree().current_scene.add_child(cine_cam)
	cine_cam.global_transform = player.camera.global_transform
	cine_cam.make_current()
	player.camera.current = false
	
	# Passo 1: Olhar para cima lentamente
	var seq = create_tween()
	var rot_look_up = cine_cam.global_rotation
	rot_look_up.x = deg_to_rad(70) # Olha pro céu
	seq.tween_property(cine_cam, "global_rotation:x", rot_look_up.x, 0.15)
	
	# Cria partículas de velocidade antes de subir
	seq.tween_callback(func():
		var speed_lines = CPUParticles3D.new()
		speed_lines.name = "speed_lines"
		speed_lines.amount = 400 # Várias partículas
		speed_lines.lifetime = 0.2
		speed_lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		speed_lines.emission_box_extents = Vector3(4, 4, 4)
		speed_lines.direction = Vector3(0, -1, 0) # Cai de cima pra baixo (ilusão de subir)
		speed_lines.spread = 0.0
		speed_lines.gravity = Vector3(0, -40, 0) 
		speed_lines.initial_velocity_min = 10.0
		speed_lines.initial_velocity_max = 20.0
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(1, 1, 1)
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mesh = QuadMesh.new()
		mesh.size = Vector2(0.01, 0.4) # Menores e mais sutis
		mesh.material = mat
		speed_lines.mesh = mesh
		
		cine_cam.add_child(speed_lines)
		speed_lines.position = Vector3(0, 0, -3) # Um pouco na frente da câmera
	)
	
	# Passo 2: Câmera começa a subir e o modelo aparece flutuando
	var start_pos = player.global_position
	var sky_pos = start_pos + Vector3(0, 20.0, 0)
	
	# A câmera começa a subir
	seq.tween_property(cine_cam, "global_position", sky_pos, 0.35).set_trans(Tween.TRANS_SINE)
	
	var player_model = player.get_node_or_null("maycow_lopes")
	if is_instance_valid(player_model):
		# Cria um tween separado para o modelo agir de forma perfeitamente simultânea à subida
		var model_tween = create_tween()
		# Aguarda a câmera olhar para o céu (0.15s) que está no seq
		model_tween.tween_interval(0.15)
		model_tween.tween_callback(func():
			player_model.visible = true
			player_model.top_level = true
			player_model.global_rotation = player.global_rotation
			player_model.rotate_y(deg_to_rad(180)) # Gira o modelo para ficar de costas para a câmera
			player_model.scale = Vector3.ONE # Garante escala normal ao aparecer
			
			# Rastro sutil em tons de cinza no modelo 3D que se apaga por onde passa
			var model_trail = player_model.get_node_or_null("model_trail") as CPUParticles3D
			if not is_instance_valid(model_trail):
				model_trail = CPUParticles3D.new()
				model_trail.name = "model_trail"
				model_trail.amount = 120
				model_trail.lifetime = 0.45
				model_trail.local_coords = false # Partículas ficam fixas no espaço formando o rastro
				model_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
				model_trail.emission_sphere_radius = 0.08
				model_trail.gravity = Vector3(0, 0.2, 0) # Leve subida de fumaça
				
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.6, 0.6, 0.6, 0.18) # Fumaça translúcida bem suave
				mat.emission_enabled = false # Sem brilho (aspecto de fumaça real)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES # Garante visibilidade pra câmera
				
				var mesh = QuadMesh.new()
				mesh.size = Vector2(0.04, 0.04) # Fumaça sutil
				mesh.material = mat
				model_trail.mesh = mesh
				
				var scale_curve = Curve.new()
				scale_curve.add_point(Vector2(0, 1.0))
				scale_curve.add_point(Vector2(1.0, 0.0)) # Apaga suavemente
				model_trail.scale_amount_curve = scale_curve
				
				player_model.add_child(model_trail)
				model_trail.position = Vector3(0, 0.5, 0)
			else:
				model_trail.emitting = true
		)
		
		# Ele surge do chão e se ajusta à câmera que já está subindo
		model_tween.tween_method(func(progress: float):
			if is_instance_valid(player_model) and is_instance_valid(cine_cam):
				# Posição na frente da câmera (distância editável no Inspector)
				var front_target = cine_cam.global_position - cine_cam.global_transform.basis.z * player.ult_model_distance + Vector3(0, -1.0, 0)
				player_model.global_position = start_pos.lerp(front_target, progress)
		, 0.0, 1.0, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		
		# Ele termina de subir até o céu junto com a câmera
		var model_up_pos = sky_pos - cine_cam.global_transform.basis.z * player.ult_model_distance + Vector3(0, -1.0, 0)
		model_tween.tween_property(player_model, "global_position", model_up_pos, 0.20).set_trans(Tween.TRANS_SINE)
		
		# Tween separado para encolher a escala bem rapidamente durante o voo
		var scale_tween = create_tween()
		scale_tween.tween_interval(0.18) # Começa quase instantaneamente assim que aparece na frente da câmera
		scale_tween.tween_property(player_model, "scale", Vector3.ZERO, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
		# Assim que sumir, a câmera treme violentamente no trajeto final até o topo
		scale_tween.tween_callback(func():
			GlobalUtils.shake_camera(0.25, 1.2) # Duração suficiente para acabar exatamente no topo
		)
	
	# Quando chegar no céu, olha para baixo
	seq.chain().tween_callback(func():
		# Mantemos as speed_lines ativas durante a queda!
		
		# Tremidinha leve no topo indicando a suspensão no ar antes da queda
		GlobalUtils.shake_camera(0.2, 0.2)
			
		if is_instance_valid(player_model):
			var model_trail = player_model.get_node_or_null("model_trail")
			if is_instance_valid(model_trail): model_trail.queue_free()
			player_model.visible = false # Some pro mergulho em primeira pessoa
			player_model.top_level = false
			player_model.position = Vector3.ZERO
			player_model.scale = Vector3.ONE # Restaura para o normal
	)
	var down_rot = cine_cam.global_rotation
	down_rot.x = deg_to_rad(-90) # 90 graus exatos pra baixo
	seq.tween_property(cine_cam, "global_rotation", down_rot, 0.1)
	
	# A Cogblade surge e desliza suavemente para a posição ideal na tela
	seq.tween_callback(func():
		player.crescent_cogblade.show()
		player.crescent_cogblade.top_level = true
		
		# Rotação fixa virada para baixo
		player.crescent_cogblade.global_rotation = cine_cam.global_rotation
		player.crescent_cogblade.rotate_object_local(Vector3(1,0,0), deg_to_rad(player.ult_cogblade_rot_x)) 
		player.crescent_cogblade.rotate_object_local(Vector3(0,1,0), deg_to_rad(player.ult_cogblade_rot_y)) 
		player.crescent_cogblade.rotate_object_local(Vector3(0,0,1), deg_to_rad(player.ult_cogblade_rot_z))
		
		# Posição final perfeita (1.5m na frente da câmera e levemente à direita)
		var final_blade_pos = cine_cam.global_position - cine_cam.global_transform.basis.z * 1.5 + cine_cam.global_transform.basis.x * 0.35
		# Começa fora da tela por CIMA e à direita
		var start_blade_pos = cine_cam.global_position + (cine_cam.global_transform.basis.x * 1.8) + (cine_cam.global_transform.basis.y * 1.5) - (cine_cam.global_transform.basis.z * 1.2)
		player.crescent_cogblade.global_position = start_blade_pos
		player.crescent_cogblade.scale = Vector3(0.5, 0.5, 0.5)
		
		var blade_audio = AudioStreamPlayer.new()
		blade_audio.stream = load("res://assets/sounds/player/blade_out.mp3")
		player.add_child(blade_audio)
		blade_audio.play()
		
		# Animação fluida e mais rápida de entrada vindo de cima-direita para a posição final
		var blade_tween = create_tween().set_parallel(true)
		blade_tween.tween_property(player.crescent_cogblade, "global_position", final_blade_pos, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		blade_tween.tween_property(player.crescent_cogblade, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
	seq.tween_interval(0.14)
	
	# Passo 5: O mergulho.
	var impact_pos = start_pos + Vector3(0, 0.5, 0)
	
	# A câmera e a cogblade descem exatamete juntas (com offset mantido)
	seq.tween_property(cine_cam, "global_position", impact_pos, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	seq.parallel().tween_property(player.crescent_cogblade, "global_position", impact_pos - cine_cam.global_transform.basis.z * 1.0 + cine_cam.global_transform.basis.x * 0.35, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# IMPACTO!
	seq.tween_callback(func():
		# Tremer tela pesado
		GlobalUtils.shake_camera(2.0, 1.0)
		
		# Som de explosão
		var boom = AudioStreamPlayer.new()
		boom.stream = load("res://assets/sounds/common/explosao.mp3")
		player.add_child(boom)
		boom.play()
		
		# Partículas Explosão
		_spawn_explosion_vfx(impact_pos)
		
		# Aplica dano AoE LENTAMENTE (um por um com pequeno atraso)
		_apply_aoe_damage_slowly(impact_pos)
		
		# Esconde a cogblade
		player.crescent_cogblade.hide()
		player.crescent_cogblade.top_level = false
		player.crescent_cogblade.position = player.magic_blade_pos_original
		player.crescent_cogblade.rotation = Vector3.ZERO
		player.crescent_cogblade.scale = Vector3.ONE
		
		# Restaura câmera do player imediatamente após o impacto, mas MANTÉM a câmera lenta!
		if is_instance_valid(cine_cam):
			cine_cam.queue_free()
		player.camera.make_current()
		
		player.control_magic.visible = true
		player.control_weapons.visible = true
		player.hand_with_pistol.visible = SaveManager.is_equipped("pistol")
		if player.hand_with_magic: player.hand_with_magic.visible = true
		if player.point: player.point.visible = true # Restaura o ponto no meio da tela
		
		if player.hud_layer:
			player.hud_layer.visible = true
			var blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
			if blur: blur.visible = false
			
		# Aguarda 0.15 segundos em slow motion antes de devolver controle
		var end_tween = create_tween()
		end_tween.tween_interval(0.15) 
		end_tween.tween_callback(func():
			player.global_position = start_pos # Garante que o player não é empurrado
			player.velocity = Vector3.ZERO
			Engine.time_scale = 1.0
			AudioServer.playback_speed_scale = 1.0
			player.is_using_ultimate = false
		)
	)

func _apply_aoe_damage_slowly(pos: Vector3):
	var inimigos = get_tree().get_nodes_in_group("enemies")
	var afetados = []
	for inimigo in inimigos:
		if is_instance_valid(inimigo) and inimigo.has_method("take_damage"):
			if inimigo.global_position.distance_to(pos) <= 15.0:
				afetados.append(inimigo)
				
	# Aplica o dano em sequência para dar peso
	for i in range(afetados.size()):
		var inimigo = afetados[i]
		var t = create_tween()
		t.tween_interval(0.02 * i) # Intervalo minúsculo, mas perceptível no slow-mo
		t.tween_callback(func():
			if is_instance_valid(inimigo):
				inimigo.take_damage(30)
				
				# Efeito de Knockback
				var dir_away = (inimigo.global_position - pos).normalized()
				dir_away.y = 0
				var push_pos = inimigo.global_position + dir_away * 2.5
				var pt = create_tween()
				pt.tween_property(inimigo, "global_position", push_pos, 0.2).set_trans(Tween.TRANS_EXPO)
		)

func _spawn_explosion_vfx(pos: Vector3):
	var node = Node3D.new()
	get_tree().current_scene.add_child(node)
	node.global_position = pos
	
	# Flash de Luz
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.4, 0.0)
	flash.light_energy = 25.0
	flash.omni_range = 40.0
	flash.shadow_enabled = false # Garante que não calcule sombras pesadas
	node.add_child(flash)
	var tween_light = create_tween()
	tween_light.tween_property(flash, "light_energy", 0.0, 1.2)
	
	# Sparks (Fagulhas volumosas)
	var sparks = CPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 130
	sparks.lifetime = 1.6
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.initial_velocity_min = 20.0
	sparks.initial_velocity_max = 45.0
	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(1.0, 0.35, 0.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.4, 0.0)
	spark_mat.emission_energy_multiplier = 10.0
	var spark_mesh = SphereMesh.new()
	spark_mesh.radius = 0.04 # Bolinhas voadoras bem pequeninas
	spark_mesh.height = 0.08
	spark_mesh.material = spark_mat
	sparks.mesh = spark_mesh
	node.add_child(sparks)
	
	# Smoke (Fumaça expansiva e constante)
	var smoke = CPUParticles3D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 40
	smoke.lifetime = 1.2
	smoke.explosiveness = 0.95
	smoke.spread = 180.0
	smoke.initial_velocity_min = 5.0
	smoke.initial_velocity_max = 12.0
	smoke.gravity = Vector3(0, 2.0, 0)
	var smoke_mat = StandardMaterial3D.new()
	var tex = load("res://assets/images/vfx/smoke.png")
	if tex:
		smoke_mat.albedo_texture = tex
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var smoke_mesh = QuadMesh.new()
	smoke_mesh.size = Vector2(22, 22) # Tamanho expansivo padronizado para qualquer inimigo
	smoke_mesh.material = smoke_mat
	smoke.mesh = smoke_mesh
	node.add_child(smoke)
	
	get_tree().create_timer(6.0).timeout.connect(func(): 
		if is_instance_valid(node): 
			node.queue_free()
	)
