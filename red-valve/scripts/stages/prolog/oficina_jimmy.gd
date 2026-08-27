extends Node3D

@onready var camera_oficina: Camera3D = $camera_oficina
@onready var player = $Player
@onready var enemy = $TheCobaltHusker
@onready var pecas = $pecas
@onready var fade = $fade

var look_at_target: Node3D = null
var look_at_offset: Vector3 = Vector3(0, 1.5, 0)
var is_starting: bool = false
var pos_inicial: Vector3 = Vector3.ZERO
var time_passed: float = 0.0

func _ready() -> void:
	GlobalEvents.in_cutscene = true
	SaveManager.save_game()
	GlobalEvents.is_maycow_normal = true
	
	# === 1. PREPARAÇÃO DA CUTSCENE ===
	
	# Usamos process_mode = DISABLED em vez de set_physics_process para ter certeza absoluta 
	# que o player não vai andar, mesmo que os scripts internos dele tentem ligar a física de novo
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	if enemy:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		# Configura o inimigo para o modo de arremesso de peças
		var enemy_node = enemy.get_node_or_null("enemy")
		if enemy_node:
			enemy_node.is_ranged_attacker = true
			enemy_node.shoots_fireball = false
			enemy_node.projectile_source = pecas
			enemy_node.ranged_attack_cooldown = 6.0
			enemy_node.attack_damage = 20
	if pecas:
		pecas.process_mode = Node.PROCESS_MODE_DISABLED
		
	if pecas:
		pecas.process_mode = Node.PROCESS_MODE_DISABLED
		
	# Inicia o filme
	iniciar_cutscene()

func _criar_faiscas_inimigo() -> void:
	if not enemy: return
	
	var particles = GPUParticles3D.new()
	particles.name = "FireSparks"
	particles.amount = 40
	# Lifetime maior para as partículas durarem mais tempo no ar já que estão lentas
	particles.lifetime = 2.5 
	
	var proc_mat = ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc_mat.emission_ring_axis = Vector3(0, 1, 0)
	proc_mat.emission_ring_height = 0.1
	proc_mat.emission_ring_radius = 1.5
	proc_mat.direction = Vector3(0, 1, 0)
	proc_mat.spread = 15.0
	# Velocidade inicial mais baixa para o fogo subir devagarzinho
	proc_mat.initial_velocity_min = 0.5
	proc_mat.initial_velocity_max = 1.5
	# Gravidade puxando pra cima de forma muito suave
	proc_mat.gravity = Vector3(0, 1.0, 0) 
	
	# Tamanho base menor
	proc_mat.scale_min = 0.03
	proc_mat.scale_max = 0.05 # Diminuido
	
	# Curva de escala para diminuir as bolas de fogo no final
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0)) # Nasce no tamanho original (100%)
	scale_curve.add_point(Vector2(1.0, 0.02)) # Morre bem pequena (2%)
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	proc_mat.scale_curve = scale_tex
	
	# Gradiente de cores (Amarelo -> Laranja -> Vermelho -> Transparente)
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.5, 1.0),
		Color(1.0, 0.5, 0.0, 1.0),
		Color(1.0, 0.1, 0.0, 1.0),
		Color(1.0, 0.0, 0.0, 0.0)
	])
	
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	proc_mat.color_ramp = grad_tex
	
	particles.process_material = proc_mat
	
	# Criando a textura circular suave procedural (Bolinha brilhante em vez de quadrado)
	var radial_grad = Gradient.new()
	radial_grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	radial_grad.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0.6), Color(1,1,1,0)])
	var spark_tex = GradientTexture2D.new()
	spark_tex.gradient = radial_grad
	spark_tex.fill = GradientTexture2D.FILL_RADIAL
	spark_tex.fill_from = Vector2(0.5, 0.5)
	spark_tex.fill_to = Vector2(1.0, 0.5)
	spark_tex.width = 64
	spark_tex.height = 64
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = spark_tex # Aplica a textura de bolinha
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	
	var mesh = QuadMesh.new()
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	# Adiciona no inimigo, posicionado nos pés dele
	enemy.add_child(particles)
	particles.position = Vector3(0, 0.05, 0)

func _process(delta: float) -> void:
	time_passed += delta
	var active_cam = get_viewport().get_camera_3d()
	if active_cam:
		active_cam.h_offset = sin(time_passed * 2.0) * 0.04
		active_cam.v_offset = cos(time_passed * 2.5) * 0.04
		
		# Trava absoluta e agressiva nos primeiros segundos para evitar pulos de tela (Frame 0 glitch)
		if is_starting:
			active_cam.global_position = pos_inicial
			if look_at_target:
				active_cam.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)
			return
			
		# A câmera sempre olha fixamente para o alvo atual
		if look_at_target:
			active_cam.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)
		
	# Avança as animações manualmente já que os scripts e físicas estão pausados
	if player and player.process_mode == Node.PROCESS_MODE_DISABLED:
		# Player se move em velocidade normal (idle)
		var pt1 = player.get_node_or_null("maycow_lopes_normal/AnimationTree")
		var pt2 = player.get_node_or_null("maycow_lopes/AnimationTree")
		if pt1 and pt1.active: pt1.advance(delta)
		if pt2 and pt2.active: pt2.advance(delta)
		
	if enemy and enemy.process_mode == Node.PROCESS_MODE_DISABLED:
		# Inimigo se move em câmera lenta (15% da velocidade)
		var et = enemy.get_node_or_null("enemy/enemy_model/AnimationTree")
		if et and et.active: et.advance(delta * 0.15)

var motion_blur_layer: CanvasLayer = null
var motion_blur_overlay: ColorRect = null
var motion_blur_mat: ShaderMaterial = null
var slow_mo_audio_player: AudioStreamPlayer = null
var pitch_effect: AudioEffectPitchShift = null

func _aplicar_pitch_audio_lento(lento: bool, duracao: float = 1.0) -> void:
	var target_bus = AudioServer.get_bus_index("Master")
	pitch_effect = null
	for i in AudioServer.get_bus_effect_count(target_bus):
		var eff = AudioServer.get_bus_effect(target_bus, i)
		if eff is AudioEffectPitchShift:
			pitch_effect = eff
			break
			
	if not pitch_effect:
		pitch_effect = AudioEffectPitchShift.new()
		AudioServer.add_bus_effect(target_bus, pitch_effect)
		
	var target_pitch = 0.45 if lento else 1.0
	var audio_tween = create_tween().set_ignore_time_scale(true)
	audio_tween.tween_property(pitch_effect, "pitch_scale", target_pitch, duracao)
	
	if lento:
		if not slow_mo_audio_player:
			slow_mo_audio_player = AudioStreamPlayer.new()
			var sound = load("res://assets/sounds/player/dash_effect.mp3")
			if sound:
				slow_mo_audio_player.stream = sound
				slow_mo_audio_player.pitch_scale = 0.35
				slow_mo_audio_player.volume_db = 3.0
				add_child(slow_mo_audio_player)
		if slow_mo_audio_player:
			slow_mo_audio_player.play()

func _setup_motion_blur() -> void:
	motion_blur_layer = CanvasLayer.new()
	motion_blur_layer.layer = 110
	add_child(motion_blur_layer)
	
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	motion_blur_layer.add_child(back_buffer)

	motion_blur_overlay = ColorRect.new()
	motion_blur_overlay.name = "MotionBlurOverlay"
	motion_blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	motion_blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_blur_overlay.visible = false
	
	var blur_shader = Shader.new()
	blur_shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	uniform float blur_strength = 0.0;
	
	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		vec2 uv = SCREEN_UV;
		vec2 dir = center - uv;
		vec4 c = texture(screen_texture, uv);
		c += texture(screen_texture, uv + dir * blur_strength * 0.05);
		c += texture(screen_texture, uv + dir * blur_strength * 0.10);
		c += texture(screen_texture, uv + dir * blur_strength * 0.15);
		c += texture(screen_texture, uv + dir * blur_strength * 0.20);
		c += texture(screen_texture, uv + dir * blur_strength * 0.25);
		c += texture(screen_texture, uv + dir * blur_strength * 0.30);
		c += texture(screen_texture, uv + dir * blur_strength * 0.35);
		COLOR = c / 8.0;
	}
	"""
	motion_blur_mat = ShaderMaterial.new()
	motion_blur_mat.shader = blur_shader
	motion_blur_mat.set_shader_parameter("blur_strength", 0.0)
	motion_blur_overlay.material = motion_blur_mat
	motion_blur_layer.add_child(motion_blur_overlay)

func _ativar_motion_blur(ativar: bool) -> void:
	if motion_blur_overlay:
		motion_blur_overlay.visible = ativar

func iniciar_cutscene() -> void:
	if not enemy or not player:
		return
		
	# Esconde o player, inimigo e vortex temporariamente
	player.visible = false
	enemy.visible = false
	var vortex = get_node_or_null("auto_pecas_jimmy/VortexMagico")
	if vortex:
		vortex.visible = false
		
	# Barra da cutscene
	var cutscene_bars = get_node_or_null("cutscene")
	if cutscene_bars:
		cutscene_bars.visible = true
		cutscene_bars.z_index = 100
		
	var camera_inicio = get_node_or_null("portal/camera_inicio_cutscene")
	
	if not camera_inicio:
		iniciar_cutscene_antiga()
		return
		
	camera_inicio.make_current()
	look_at_target = null
	
	# Camada de texto
	var text_layer = CanvasLayer.new()
	text_layer.layer = 120
	add_child(text_layer)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	text_layer.add_child(label)
	
	var is_en = SaveManager.config.get("language", "pt") == "en"
	
	await get_tree().create_timer(1.0).timeout
	
	# Frase 1
	label.text = "What happened here?" if is_en else "O que houve aqui?"
	var t1 = create_tween()
	t1.tween_property(label, "modulate:a", 1.0, 0.8)
	
	# Inclinada suave na rotacao pra esquerda
	var t_rot = create_tween()
	t_rot.tween_property(camera_inicio, "rotation:y", camera_inicio.rotation.y + deg_to_rad(15.0), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await t1.finished
	await get_tree().create_timer(2.2).timeout # Total ~3 seconds
	
	var t2 = create_tween()
	t2.tween_property(label, "modulate:a", 0.0, 0.8)
	await t2.finished
	
	# Rodando a camera para a porta/portal no final do cenario
	var vortex_pos = Vector3.ZERO
	var portal_rv = get_node_or_null("portal/portal_red_valve")
	if portal_rv:
		vortex_pos = portal_rv.global_position
	elif vortex:
		vortex_pos = vortex.global_position
	else:
		var p = get_node_or_null("portal")
		if p: vortex_pos = p.global_position
		
	var dummy_rot = Camera3D.new()
	add_child(dummy_rot)
	dummy_rot.global_transform = camera_inicio.global_transform
	dummy_rot.look_at(vortex_pos + Vector3(0, 1.0, 0), Vector3.UP)
	var target_quat = dummy_rot.global_transform.basis.get_rotation_quaternion()
	dummy_rot.queue_free()
	
	var start_quat = camera_inicio.global_transform.basis.get_rotation_quaternion()
	var turn_tween = create_tween()
	turn_tween.tween_method(func(t: float):
		if is_instance_valid(camera_inicio):
			camera_inicio.global_transform.basis = Basis(start_quat.slerp(target_quat, t))
	, 0.0, 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await turn_tween.finished
	
	# Mover devagar proximo da porta, ao redor de onde esta o vortex
	var dir_to_vortex = (vortex_pos - camera_inicio.global_position).normalized()
	var dist_to_vortex = camera_inicio.global_position.distance_to(vortex_pos)
	var target_pos = camera_inicio.global_position + dir_to_vortex * (dist_to_vortex - 2.0)
	
	var move_tween = create_tween()
	move_tween.tween_property(camera_inicio, "global_position", target_pos, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Durante o trajeto, colocar o texto
	await get_tree().create_timer(1.0).timeout
	label.text = "There is something wrong with this place..." if is_en else "Tem algo errado nesse lugar..."
	var t3 = create_tween()
	t3.tween_property(label, "modulate:a", 1.0, 0.8)
	await t3.finished
	
	await get_tree().create_timer(3.0).timeout
	
	var t4 = create_tween()
	t4.tween_property(label, "modulate:a", 0.0, 0.8)
	await t4.finished
	
	# Espere mais alguns segundos
	await get_tree().create_timer(1.5).timeout
	
	# Então mostre
	label.text = "I need to find out what it is" if is_en else "Eu preciso descobrir o que é"
	var t5 = create_tween()
	t5.tween_property(label, "modulate:a", 1.0, 0.8)
	await t5.finished
	
	await get_tree().create_timer(2.5).timeout
	
	var t6 = create_tween()
	t6.tween_property(label, "modulate:a", 0.0, 0.8)
	await t6.finished
	
	if move_tween.is_running():
		await move_tween.finished
		
	# Restaura elementos
	if is_instance_valid(enemy):
		enemy.visible = true
	if is_instance_valid(player):
		player.visible = true
	if is_instance_valid(vortex):
		vortex.visible = true
	
	# Inicia cutscene antiga
	if is_instance_valid(text_layer):
		text_layer.queue_free()
		
	if is_instance_valid(camera_inicio):
		camera_inicio.current = false
		camera_inicio.clear_current()
		
	await get_tree().process_frame
	
	iniciar_cutscene_antiga()

func iniciar_cutscene_antiga() -> void:
	if not enemy or not player:
		return
		
	# Instancia o filtro de Motion Blur
	_setup_motion_blur()
	
	# Esconde o player para o modo primeira pessoa inicial
	player.visible = false
	
	# Camada de texto cinematográfica
	var text_layer = CanvasLayer.new()
	text_layer.layer = 120
	add_child(text_layer)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	text_layer.add_child(label)
		
	var enemy_pos = enemy.global_position
	var player_pos = player.global_position
	
	var player_forward = -player.global_transform.basis.z.normalized()
	var player_right = player.global_transform.basis.x.normalized()
	if player_forward.length() < 0.1: player_forward = Vector3.FORWARD
	if player_right.length() < 0.1: player_right = Vector3.RIGHT
	
	# Liga as faíscas do inimigo e a iluminação
	_criar_faiscas_inimigo()
	if enemy.has_node("enemy/OmniLight3D"):
		enemy.get_node("enemy/OmniLight3D").visible = true
	var vortex = get_node_or_null("auto_pecas_jimmy/VortexMagico")
	if vortex:
		vortex.visible = true
	
	# ---------------------------------------------------------
	# FASE 0: Posicionamento Imediato no Boss (Antes do clarear)
	# ---------------------------------------------------------
	var dir_to_player = (player_pos - enemy_pos).normalized()
	if dir_to_player.length() < 0.1: dir_to_player = Vector3.BACK
	
	pos_inicial = enemy_pos + (dir_to_player * 1.0) + Vector3(0, 1.5, 0)
	
	look_at_target = enemy
	look_at_offset = Vector3(0, 1.5, 0)
	
	camera_oficina.current = true
	camera_oficina.global_position = pos_inicial
	camera_oficina.look_at(enemy_pos + look_at_offset, Vector3.UP)
	camera_oficina.make_current()
	
	is_starting = true
	await get_tree().create_timer(0.4).timeout
	is_starting = false
	
	# ---------------------------------------------------------
	# FASE 1: Arremesso em 1ª Pessoa (Voo + Inclinação fluida para o piso no final do arremesso)
	# ---------------------------------------------------------
	_ativar_motion_blur(true)
	_aplicar_pitch_audio_lento(true, 0.5)
	Engine.time_scale = 0.12
	
	var landing_pos = player_pos + Vector3(0, 0.3, 0)
	# Olha intensamente para baixo, quase reto para o piso
	var floor_look_target = landing_pos + (player_forward * 0.05) + Vector3(0, -2.0, 0)
	
	# Translação da câmera (arremesso)
	var throw_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	throw_tween.tween_property(camera_oficina, "global_position", landing_pos, 3.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if motion_blur_mat:
		motion_blur_mat.set_shader_parameter("blur_strength", 1.4)
		var blur_tween = create_tween().set_ignore_time_scale(true)
		blur_tween.tween_property(motion_blur_mat, "shader_parameter/blur_strength", 0.0, 3.5).set_trans(Tween.TRANS_SINE)
	
	# Nos últimos 1.2s do arremesso (aproximação do chão), desliga a trava no inimigo e inclina suavemente para o piso
	await get_tree().create_timer(2.3, true, false, true).timeout
	look_at_target = null
	
	var dummy_floor = Camera3D.new()
	add_child(dummy_floor)
	dummy_floor.global_position = landing_pos
	dummy_floor.look_at(floor_look_target, Vector3.UP)
	var floor_target_quat = dummy_floor.global_transform.basis.get_rotation_quaternion()
	dummy_floor.queue_free()
	
	var start_floor_quat = camera_oficina.global_transform.basis.get_rotation_quaternion()
	var tilt_floor_tween = create_tween().set_ignore_time_scale(true)
	tilt_floor_tween.tween_method(func(t: float):
		camera_oficina.global_transform.basis = Basis(start_floor_quat.slerp(floor_target_quat, t))
	, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await throw_tween.finished
	
	# Restaura velocidade e desliga o blur no baque exato do chão
	Engine.time_scale = 1.0
	_ativar_motion_blur(false)
	_aplicar_pitch_audio_lento(false, 1.0)
	
	# ---------------------------------------------------------
	# FASE 2: Balança a cabeça no chão (Sem subir a posição!)
	# ---------------------------------------------------------
	camera_oficina.global_position = landing_pos
	camera_oficina.look_at(floor_look_target, Vector3.UP)
	
	var head_shake_tween = create_tween()
	head_shake_tween.tween_property(camera_oficina, "rotation:z", deg_to_rad(14.0), 0.25)
	head_shake_tween.tween_property(camera_oficina, "rotation:z", deg_to_rad(-14.0), 0.3)
	head_shake_tween.tween_property(camera_oficina, "rotation:z", deg_to_rad(8.0), 0.25)
	head_shake_tween.tween_property(camera_oficina, "rotation:z", deg_to_rad(-8.0), 0.25)
	head_shake_tween.tween_property(camera_oficina, "rotation:z", 0.0, 0.25)
	await head_shake_tween.finished
	
	# Pausa de impacto no chão
	await get_tree().create_timer(0.8).timeout
	
	# ---------------------------------------------------------
	# FASE 3: Olha pra frente BEM DEVAGAR em direção ao inimigo (Permanecendo no chão, sem subir!)
	# ---------------------------------------------------------
	look_at_target = null
	var enemy_look_target = enemy_pos + Vector3(0, 1.5, 0)
	
	var dummy_ground_look = Camera3D.new()
	add_child(dummy_ground_look)
	dummy_ground_look.global_position = landing_pos
	dummy_ground_look.look_at(enemy_look_target, Vector3.UP)
	var ground_look_quat = dummy_ground_look.global_transform.basis.get_rotation_quaternion()
	dummy_ground_look.queue_free()
	
	var start_enemy_quat = camera_oficina.global_transform.basis.get_rotation_quaternion()
	var turn_to_enemy_tween = create_tween()
	turn_to_enemy_tween.tween_method(func(t: float):
		camera_oficina.global_transform.basis = Basis(start_enemy_quat.slerp(ground_look_quat, t))
	, 0.0, 1.0, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await turn_to_enemy_tween.finished
	
	look_at_target = enemy
	look_at_offset = Vector3(0, 1.5, 0)
	await get_tree().create_timer(0.8).timeout
	
	# ---------------------------------------------------------
	# FASE 4: Frase "O que acabou de acontecer?" (E aguarda sumir)
	# ---------------------------------------------------------
	label.text = "What just happened?" if SaveManager.config.get("language", "pt") == "en" else "O que acabou de acontecer?"
	
	var label_in_tween = create_tween()
	label_in_tween.tween_property(label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	await label_in_tween.finished
	
	await get_tree().create_timer(2.0).timeout
	
	var label_out_tween = create_tween()
	label_out_tween.tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	await label_out_tween.finished
	
	# Somente depois de sumir a frase!
	await get_tree().create_timer(0.5).timeout
	
	# ---------------------------------------------------------
	# FASE 5: Câmera que roda o inimigo e se aproxima
	# ---------------------------------------------------------
	player.visible = true
	
	var start_orbit_radius = 4.0
	var end_orbit_radius = 1.2
	var orbit_center = enemy_pos + Vector3(0, 1.5, 0)
	var dir_enemy_to_player = (player_pos - enemy_pos).normalized()
	var base_angle = atan2(dir_enemy_to_player.x, dir_enemy_to_player.z)
	
	look_at_target = null
	
	var orbit_tween = create_tween()
	orbit_tween.tween_method(func(progress: float):
		var angle = base_angle + (progress * TAU * 0.75)
		var current_radius = lerp(start_orbit_radius, end_orbit_radius, progress)
		var cam_pos = orbit_center + Vector3(sin(angle) * current_radius, 0.3, cos(angle) * current_radius)
		camera_oficina.global_position = cam_pos
		camera_oficina.look_at(orbit_center, Vector3.UP)
	, 0.0, 1.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await orbit_tween.finished
	
	# Transita da órbita para a frente do player
	look_at_target = player
	look_at_offset = Vector3(0, 0.4, 0)
	
	var frontal_pos = player_pos + Vector3(0, 0.4, 0) + (player_forward * 1.5)
	var reveal_tween = create_tween().set_parallel(true)
	reveal_tween.tween_property(camera_oficina, "global_position", frontal_pos, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.tween_property(camera_oficina, "fov", 45.0, 1.5).set_trans(Tween.TRANS_SINE)
	await reveal_tween.finished
	
	await get_tree().create_timer(1.0).timeout
	
	# ---------------------------------------------------------
	# FASE 6: Fim do Filme (Fade Out e retoma controle)
	# ---------------------------------------------------------
	if fade:
		fade.fade_out()
		await get_tree().create_timer(1.5).timeout
		
	look_at_target = null
	Engine.time_scale = 1.0
	_aplicar_pitch_audio_lento(false, 0.1)
	
	# Restaura controles e inteligência artificial
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		var player_cam = player.get_node_or_null("SpringArm3D/camera_third_person")
		if not player_cam:
			player_cam = player.get_node_or_null("Camera3D")
			
		if player_cam:
			player_cam.make_current()
			
	if pecas:
		pecas.process_mode = Node.PROCESS_MODE_INHERIT
		
	if enemy:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		
	GlobalEvents.in_cutscene = false
		
	if fade:
		fade.fade_in()
		
	if is_instance_valid(text_layer):
		text_layer.queue_free()
		
	if is_instance_valid(motion_blur_layer):
		motion_blur_layer.queue_free()
		
	camera_oficina.queue_free()
