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

func _ready() -> void:
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
			enemy_node.projectile_source = pecas
			enemy_node.ranged_attack_cooldown = 10.0
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
	# Trava absoluta e agressiva nos primeiros segundos para evitar pulos de tela (Frame 0 glitch)
	if is_starting:
		if camera_oficina and look_at_target:
			camera_oficina.make_current()
			camera_oficina.global_position = pos_inicial
			camera_oficina.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)
		return
		
	# A câmera sempre olha fixamente para o alvo atual
	if look_at_target:
		camera_oficina.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)
		
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

func iniciar_cutscene() -> void:
	if not enemy or not player:
		return
		
	var enemy_pos = enemy.global_position
	var player_pos = player.global_position
	
	# Pega a direção para onde o player está olhando (o vetor -Z no Godot) e o vetor da direita (+X)
	var player_forward = -player.global_transform.basis.z.normalized()
	var player_right = player.global_transform.basis.x.normalized()
	if player_forward.length() < 0.1: player_forward = Vector3.FORWARD
	if player_right.length() < 0.1: player_right = Vector3.RIGHT
	
	# ---------------------------------------------------------
	# FASE 0: Posicionamento Imediato (Antes do fade clarear)
	# ---------------------------------------------------------
	look_at_target = player
	look_at_offset = Vector3(0, 0.25, 0) # Altura bem mais baixa, focando do peito pra baixo
	
	# Coloca a câmera mais na frente do player e um pouco à direita, e bem mais baixa
	pos_inicial = player_pos + Vector3(0, 0.25, 0) + (player_right * 0.5) + (player_forward * 1.8)
	camera_oficina.current = true
	camera_oficina.global_position = pos_inicial
	
	# Desliga também a OmniLight3D nativa do inimigo (caso exista) para não vazar clarão
	if enemy.has_node("enemy/OmniLight3D"):
		enemy.get_node("enemy/OmniLight3D").visible = false
		
	# Desliga o VortexMagico original (que emite luz) embaixo do inimigo
	var vortex = get_node_or_null("auto_pecas_jimmy/VortexMagico")
	if vortex:
		vortex.visible = false
	
	# Força a câmera a olhar pro player no mesmíssimo milissegundo para evitar o primeiro frame torto
	camera_oficina.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)
	camera_oficina.make_current()
	
	# Ativa a trava agressiva do _process para garantir que nenhum outro frame pisque fora de lugar
	is_starting = true
		
	# Espera inicial para o fade_in e estabilizar a engine
	await get_tree().create_timer(1.0).timeout
	
	# Desliga a trava para podermos viajar livremente
	is_starting = false
	
	# ---------------------------------------------------------
	# FASE 1: Gira de leve (drift) sem ir para as costas
	# ---------------------------------------------------------
	# Um movimento suave e muito curto pro lado, sem tentar ir para trás para não clipar na parede
	var pos_drift = player_pos + Vector3(0, 0.25, 0) + (player_right * 0.9) + (player_forward * 1.5)
	
	var sweep_tween = create_tween()
	sweep_tween.tween_property(camera_oficina, "global_position", pos_drift, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await sweep_tween.finished
	
	# Pequena pausa antes de viajar pro boss
	await get_tree().create_timer(0.3).timeout
	
	# ---------------------------------------------------------
	# FASE 2: Câmera viaja até o Inimigo (com Efeito de Zoom)
	# ---------------------------------------------------------
	look_at_target = enemy
	look_at_offset = Vector3(0, 1.5, 0) # O Inimigo é maior, focamos mais alto
	
	# Cria e liga o fogo do inimigo EXATAMENTE agora, assim não tem como ele existir antes disso
	_criar_faiscas_inimigo()
	# Liga a luz nativa do inimigo de volta e o vortex mágico original
	if enemy.has_node("enemy/OmniLight3D"):
		enemy.get_node("enemy/OmniLight3D").visible = true
	vortex = get_node_or_null("auto_pecas_jimmy/VortexMagico")
	if vortex:
		vortex.visible = true
	
	var pivot = Node3D.new()
	pivot.global_position = enemy_pos + Vector3(0, 1.5, 0)
	add_child(pivot)
	
	var dir_to_enemy = (pivot.global_position - camera_oficina.global_position).normalized()
	# Posição de chegada: uns 3.5 metros do inimigo para focar bem nele
	var orbit_start_pos = pivot.global_position - (dir_to_enemy * 3.5)
	
	var travel_tween = create_tween().set_parallel(true)
	travel_tween.tween_property(camera_oficina, "global_position", orbit_start_pos, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Faz um "zoom in" abaixando o campo de visão (FOV) da câmera para dar um ar cinematográfico
	travel_tween.tween_property(camera_oficina, "fov", 50.0, 3.0).set_trans(Tween.TRANS_SINE)
	await travel_tween.finished
	
	# ---------------------------------------------------------
	# FASE 3: Orbita 360 graus envolta do inimigo
	# ---------------------------------------------------------
	var cam_transform = camera_oficina.global_transform
	camera_oficina.get_parent().remove_child(camera_oficina)
	pivot.add_child(camera_oficina)
	camera_oficina.global_transform = cam_transform
	camera_oficina.make_current() # Impede roubo de câmera
	
	var orbit_tween = create_tween()
	orbit_tween.tween_property(pivot, "rotation:y", PI * 2, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await orbit_tween.finished
	
	# ---------------------------------------------------------
	# FASE 4: Volta voando para o Player (Mais de perto e baixo)
	# ---------------------------------------------------------
	look_at_target = player
	look_at_offset = Vector3(0, 0.4, 0) # Bem baixo pra dar tensão final no rosto
	
	cam_transform = camera_oficina.global_transform
	pivot.remove_child(camera_oficina)
	add_child(camera_oficina)
	camera_oficina.global_transform = cam_transform
	camera_oficina.make_current() # Impede roubo de câmera
	
	var return_tween = create_tween().set_parallel(true)
	# Posição final: de frente pro player, mais baixo (Y=0.4) e bem mais perto (1.5m)
	var final_pos = player_pos + Vector3(0, 0.4, 0) + (player_forward * 1.5)
	return_tween.tween_property(camera_oficina, "global_position", final_pos, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Mais zoom no player
	return_tween.tween_property(camera_oficina, "fov", 45.0, 2.5).set_trans(Tween.TRANS_SINE)
	await return_tween.finished
	
	# ---------------------------------------------------------
	# FASE 5: Fim do Filme (Fade Out e retoma controle)
	# ---------------------------------------------------------
	if fade:
		fade.fade_out()
		await get_tree().create_timer(1.5).timeout
		
	pivot.queue_free()
	look_at_target = null
	
	# Restaura controles e inteligência artificial soltando os processos base
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		# A câmera padrão de combate é a third_person, não a genérica
		var player_cam = player.get_node_or_null("SpringArm3D/camera_third_person")
		if not player_cam:
			player_cam = player.get_node_or_null("Camera3D")
			
		if player_cam:
			player_cam.make_current()
			
	if pecas:
		pecas.process_mode = Node.PROCESS_MODE_INHERIT
		
	if enemy:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		
	if fade:
		fade.fade_in()
		
	camera_oficina.queue_free()
