extends Node

# Poderes da Cogblade:
#   - Cogblade Slain: mergulho do céu com impacto em área (zera o acúmulo).
#   - Cogblade Cut:   rasga o meio da tela em várias direções (deixa 25% do acúmulo).
# Ambos compartilham o mesmo padrão de cinemática: câmera lenta, o player perde
# o controle da câmera (assumida por uma Camera3D temporária da engine) e só
# recupera no final, quando o time_scale volta ao normal.

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func _activate_cogblade_slain() -> void:
	# Mata qualquer tween de câmera lenta pendente (ex: do impacto da cogblade)
	# para que ele não force o time_scale de volta a 1.0 no meio da cinemática do ultimate
	if GlobalUtils.current_time_tween and GlobalUtils.current_time_tween.is_valid():
		GlobalUtils.current_time_tween.kill()

	player.is_using_ultimate = true
	_reset_cogblade_gauge(0.0) # O Slain zera o medidor
	
	# Cancela a lâmina se estiver no ar/retornando (evita glitch de velocidade)
	player.is_blade_returning = false
	_cancel_melee()
	_reset_blade_to_hand()
	
	# 1. Preparação
	Engine.time_scale = 0.1
	AudioServer.playback_speed_scale = 0.5 # Deixa os sons graves/lentos
	
	_hide_combat_hud()
			
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
		_reset_blade_to_hand()
		
		# Restaura câmera do player imediatamente após o impacto, mas MANTÉM a câmera lenta!
		if is_instance_valid(cine_cam):
			cine_cam.queue_free()
		player.camera.make_current()
		
		_show_combat_hud()
			
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

# =========================================================================
# HELPERS COMPARTILHADOS PELOS PODERES DA COGBLADE
# =========================================================================

# Reposiciona o medidor da cogblade. O Slain zera (0.0); o Cut deixa 25%.
func _reset_cogblade_gauge(value: float) -> void:
	player.cogblade_power_value = value
	player.cogblade_pulsing = false
	if player.cogblade_pulse_tween: player.cogblade_pulse_tween.kill()
	if player.cogblade_particles: player.cogblade_particles.emitting = false
	if player.cogblade_hud:
		player.cogblade_hud.value = value
		player.cogblade_hud.tint_progress = Color(1, 1, 1, 1.0)
		player.cogblade_hud.modulate = Color(1, 1, 1, 1.0)

# Interrompe um golpe melee em andamento (usado quando um poder maior começa).
func _cancel_melee() -> void:
	if _melee_tween and _melee_tween.is_valid():
		_melee_tween.kill()
	_melee_tween = null
	player.cogblade_melee_active = false
	_melee_start_cooldown()
	_melee_return_hand()
	if is_instance_valid(player):
		for child in player.get_children():
			if child is CanvasLayer and child.name == "CogbladeMeleeFX":
				child.queue_free()

# Devolve a lâmina para a mão (posição original, escondida e sem top_level).
func _reset_blade_to_hand() -> void:
	if not is_instance_valid(player.crescent_cogblade): return
	var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas")
	if faiscas: faiscas.emitting = false
	player.crescent_cogblade.top_level = false
	player.crescent_cogblade.position = player.magic_blade_pos_original
	player.crescent_cogblade.rotation = Vector3.ZERO
	player.crescent_cogblade.scale = Vector3.ONE
	player.crescent_cogblade.hide()

func _hide_combat_hud() -> void:
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

func _show_combat_hud() -> void:
	player.control_magic.visible = true
	player.control_weapons.visible = true
	player.hand_with_pistol.visible = SaveManager.is_equipped("pistol")
	if player.hand_with_magic: player.hand_with_magic.visible = true
	if player.point: player.point.visible = true # Restaura o ponto no meio da tela
	
	if player.hud_layer:
		player.hud_layer.visible = true
		var blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
		if blur: blur.visible = false

func _play_blade_sound(path: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not ResourceLoader.exists(path): return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.pitch_scale = clampf(pitch, 0.05, 4.0)
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(func():
		if is_instance_valid(p): p.queue_free()
	)


# =========================================================================
# COGBLADE CUT
# Em câmera lenta, a lâmina rasga o meio da tela de um lado para o outro:
# começa devagar (direita->esquerda, esquerda->direita) e depois sai para
# direções aleatórias, acelerando rapidamente até uma velocidade altíssima.
# No final aplica dano em área (menor que o do Slain) e devolve 25% do
# acúmulo, ou seja, NÃO zera o medidor da cogblade.
# =========================================================================

var _cut_streak: Line2D = null
var _cut_streak_a: Vector2 = Vector2.ZERO
var _cut_streak_b: Vector2 = Vector2.ZERO

func _activate_cogblade_cut() -> void:
	# Mesma proteção do Slain: nenhum tween de câmera lenta pendente pode
	# devolver o time_scale para 1.0 no meio da cinemática.
	if GlobalUtils.current_time_tween and GlobalUtils.current_time_tween.is_valid():
		GlobalUtils.current_time_tween.kill()

	player.is_using_ultimate = true
	# Diferente do Slain, o Cut deixa parte do acúmulo (25% por padrão)
	_reset_cogblade_gauge(clampf(player.cut_leftover_power, 0.0, 100.0))
	
	# Cancela a lâmina se estiver no ar/retornando (evita glitch de velocidade)
	player.is_blade_returning = false
	_cancel_melee()
	_reset_blade_to_hand()
	
	# 1. Preparação (idêntica ao Slain)
	Engine.time_scale = 0.1
	AudioServer.playback_speed_scale = 0.5
	
	_hide_combat_hud()
	
	player.playback.travel("idle")
	player.velocity = Vector3.ZERO
	
	var start_pos: Vector3 = player.global_position
	
	# Câmera cinemática temporária: a engine assume o controle
	var cine_cam := Camera3D.new()
	get_tree().current_scene.add_child(cine_cam)
	cine_cam.global_transform = player.camera.global_transform
	cine_cam.make_current()
	player.camera.current = false
	
	# Camada 2D onde os rasgos da tela são desenhados
	var fx_layer := CanvasLayer.new()
	fx_layer.name = "CogbladeCutFX"
	fx_layer.layer = 105
	get_tree().current_scene.add_child(fx_layer)
	
	# A câmera não sai do lugar: só o yaw importa daqui pra frente
	var cam_yaw: float = player.camera.global_rotation.y
	var cam_basis := Basis.from_euler(Vector3(0.0, cam_yaw, 0.0))
	var screen_center: Vector3 = player.camera.global_position - cam_basis.z * player.cut_blade_distance
	
	var seq := create_tween()
	
	# Passo 1: a câmera se ajeita LENTAMENTE olhando para frente (nivelada)
	seq.tween_property(cine_cam, "global_rotation:x", 0.0, player.cut_camera_settle_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.parallel().tween_property(cine_cam, "global_rotation:z", 0.0, player.cut_camera_settle_time)\
		.set_trans(Tween.TRANS_SINE)
	
	# Passo 2: a cogblade surge na frente da câmera
	var entry_basis := _cut_blade_basis(cam_basis, cam_yaw, 0.0)
	var entry_from: Vector3 = screen_center + cam_basis.x * 1.6 + cam_basis.y * 1.0
	seq.tween_callback(func():
		if not is_instance_valid(player.crescent_cogblade): return
		player.crescent_cogblade.show()
		player.crescent_cogblade.top_level = true
		var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas")
		if faiscas: faiscas.emitting = true
		_play_blade_sound("res://assets/sounds/player/blade_out.mp3", 0.9)
	)
	seq.tween_method(func(t: float):
		_cut_set_blade(entry_from.lerp(screen_center, ease(t, 0.35)), entry_basis, lerpf(0.55, 1.0, t))
	, 0.0, 1.0, 0.14)
	
	# Passo 3: aguarda um pequeno instante antes dos cortes
	seq.tween_interval(player.cut_blade_hold_time)
	
	# Passo 4: os cortes, acelerando de forma geométrica até ficarem altíssimos
	var count: int = maxi(3, player.cut_slash_count)
	var d0: float = maxf(player.cut_slash_first_duration, 0.005)
	var d1: float = clampf(player.cut_slash_last_duration, 0.001, d0)
	var reach: float = player.cut_blade_distance * 3.0
	
	var travel_sign: float = 1.0 # +1 começa pela direita (corta direita -> esquerda)
	var last_theta: float = 0.0
	for i in range(count):
		var f: float = float(i) / float(count - 1)
		var dur: float = d0 * pow(d1 / d0, f) # decai rápido = acelera rápido
		
		var theta: float = 0.0
		if i <= 1:
			# Os dois primeiros são horizontais: direita->esquerda e esquerda->direita
			theta = 0.0
		else:
			# Sai da direção anterior e parte para outra direção aleatória
			theta = last_theta + randf_range(PI * 0.22, PI * 0.78)
			theta = fmod(theta, PI)
		last_theta = theta
		
		var dir: Vector3 = cam_basis.x * cos(theta) + cam_basis.y * sin(theta)
		var from_pos: Vector3 = screen_center + dir * reach * travel_sign
		var to_pos: Vector3 = screen_center - dir * reach * travel_sign
		var rot_basis := _cut_blade_basis(cam_basis, cam_yaw, theta)
		var kick: float = deg_to_rad(lerpf(1.0, 5.0, f)) * travel_sign
		
		var c_theta := theta
		var c_sign := travel_sign
		var c_dur := dur
		var c_f := f
		
		seq.tween_callback(func(): _cut_begin_slash(fx_layer, c_theta, c_sign, c_f))
		seq.tween_method(func(t: float):
			_cut_set_blade(from_pos.lerp(to_pos, t), rot_basis, 1.0)
			_cut_update_streak(t)
			# Leve "chicote" da câmera acompanhando o corte (volta a zero no fim)
			if is_instance_valid(cine_cam):
				cine_cam.global_rotation.z = -sin(t * PI) * kick
		, 0.0, 1.0, dur)
		seq.tween_callback(func(): _cut_end_slash(c_dur))
		
		if i < count - 1:
			seq.tween_interval(dur * player.cut_slash_gap_ratio)
		
		travel_sign = -travel_sign
	
	# Passo 5: golpe final, dano em área e devolução do controle
	var impact_pos: Vector3 = start_pos + Vector3(0, 0.5, 0)
	seq.tween_callback(func():
		if is_instance_valid(cine_cam): cine_cam.global_rotation.z = 0.0
		
		GlobalUtils.shake_camera(0.3, 0.9)
		GlobalUtils.vibrate_controller(Input, 0.7, 0.7, 0.3)
		_play_blade_sound("res://assets/sounds/common/explosao.mp3", 1.2, -4.0)
		_cut_spawn_flash(fx_layer)
		
		# Dano em área igual ao do Slain, porém um pouco menor
		_apply_aoe_damage_slowly(impact_pos, player.cut_damage, player.cut_damage_radius)
		
		_reset_blade_to_hand()
		
		# Devolve a câmera ao player, mas MANTÉM a câmera lenta por um instante
		if is_instance_valid(cine_cam):
			cine_cam.queue_free()
		player.camera.make_current()
		
		_show_combat_hud()
		
		var end_tween := create_tween()
		end_tween.tween_interval(0.15)
		end_tween.tween_callback(func():
			player.global_position = start_pos # Garante que o player não é empurrado
			player.velocity = Vector3.ZERO
			Engine.time_scale = 1.0
			AudioServer.playback_speed_scale = 1.0
			player.is_using_ultimate = false
			if is_instance_valid(fx_layer): fx_layer.queue_free()
		)
	)

# Orientação da lâmina: parte da pose de arremesso (já calibrada no Inspector)
# e gira no plano da tela para acompanhar a direção do corte.
func _cut_blade_basis(cam_basis: Basis, cam_yaw: float, theta: float) -> Basis:
	var base := Basis.from_euler(Vector3(
		deg_to_rad(player.cut_cogblade_rot_x),
		cam_yaw + deg_to_rad(player.cut_cogblade_rot_y),
		deg_to_rad(player.cut_cogblade_rot_z)))
	var spin := Basis(cam_basis.z.normalized(), theta)
	return spin * base

func _cut_set_blade(pos: Vector3, rot_basis: Basis, s: float) -> void:
	if not is_instance_valid(player.crescent_cogblade): return
	player.crescent_cogblade.global_transform = Transform3D(rot_basis.scaled(Vector3(s, s, s)), pos)

func _cut_begin_slash(fx_layer: CanvasLayer, theta: float, travel_sign: float, f: float) -> void:
	if not is_instance_valid(fx_layer): return
	
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = vp * 0.5
	# Em coordenadas de tela o Y cresce para baixo, por isso o -sin
	var d := Vector2(cos(theta), -sin(theta))
	var half: float = vp.length() * 0.6
	_cut_streak_a = center + d * half * travel_sign
	_cut_streak_b = center - d * half * travel_sign
	
	var line := Line2D.new()
	line.width = lerpf(14.0, 4.0, f)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	
	var grad := Gradient.new()
	grad.set_color(0, Color(0.3, 0.85, 1.0, 0.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	line.gradient = grad
	
	var wcurve := Curve.new()
	wcurve.add_point(Vector2(0.0, 0.05))
	wcurve.add_point(Vector2(0.8, 1.0))
	wcurve.add_point(Vector2(1.0, 0.2))
	line.width_curve = wcurve
	
	line.points = PackedVector2Array([_cut_streak_a, _cut_streak_a])
	fx_layer.add_child(line)
	_cut_streak = line
	
	_play_blade_sound("res://assets/sounds/player/blade_out.mp3", lerpf(0.85, 1.9, f), lerpf(-8.0, -1.0, f))
	
	# A lâmina passou: os inimigos por perto sangram como se estivessem
	# sendo retalhados junto com a tela.
	_cut_spawn_blood_wave(theta)

# Sangue de UMA passada da lâmina: escolhe alguns inimigos no raio do golpe e
# faz o sangue jorrar na direção do corte. O sangue roda com speed_scale maior
# que 1 para compensar o Engine.time_scale da cinemática — assim ele continua
# em câmera lenta, mas rápido o bastante para dar pra ver o jorro inteiro.
func _cut_spawn_blood_wave(theta: float) -> void:
	if player.blood_effect == null: return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(cam): return
	
	var b := cam.global_transform.basis
	var dir: Vector3 = (b.x * cos(theta) + b.y * sin(theta)).normalized()
	var origin: Vector3 = player.global_position
	
	var alvos: Array = []
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(inimigo) or not (inimigo is Node3D): continue
		if inimigo.global_position.distance_to(origin) <= player.cut_damage_radius:
			alvos.append(inimigo)
	if alvos.is_empty(): return
	
	alvos.shuffle()
	var limite: int = mini(alvos.size(), maxi(1, player.cut_blood_targets_per_slash))
	for i in range(limite):
		_cut_spawn_blood_on(alvos[i], dir)
	
	_play_blade_sound("res://assets/sounds/player/blood_out.mp3", randf_range(0.85, 1.15), -7.0)

func _cut_spawn_blood_on(alvo: Node3D, dir: Vector3) -> void:
	if not is_instance_valid(alvo) or player.blood_effect == null: return
	var blood = player.blood_effect.instantiate()
	get_tree().root.add_child(blood)
	
	# Varia o ponto do corte pelo corpo do inimigo
	blood.global_position = alvo.global_position + Vector3(
		randf_range(-0.35, 0.35),
		randf_range(1.0, 2.0),
		randf_range(-0.35, 0.35))
	
	# O jorro sai acompanhando a direção em que a lâmina passou
	var lado: float = 1.0 if randf() < 0.5 else -1.0
	var spray: Vector3 = dir * lado + Vector3(0.0, 0.3, 0.0)
	if spray.length() > 0.01 and absf(spray.normalized().dot(Vector3.UP)) < 0.95:
		blood.look_at(blood.global_position + spray, Vector3.UP)
	
	# Compensa a câmera lenta da cinemática
	blood.speed_scale = maxf(0.1, player.cut_blood_speed_scale)

func _cut_update_streak(t: float) -> void:
	if not is_instance_valid(_cut_streak): return
	_cut_streak.points = PackedVector2Array([_cut_streak_a, _cut_streak_a.lerp(_cut_streak_b, t)])

func _cut_end_slash(dur: float) -> void:
	var line := _cut_streak
	_cut_streak = null
	if not is_instance_valid(line): return
	var t := create_tween()
	t.tween_property(line, "modulate:a", 0.0, maxf(dur * 5.0, 0.04))
	t.tween_callback(func():
		if is_instance_valid(line): line.queue_free()
	)

func _cut_spawn_flash(fx_layer: CanvasLayer) -> void:
	if not is_instance_valid(fx_layer): return
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 1.0, 1.0, 0.75)
	fx_layer.add_child(flash)
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
	)

# =========================================================================
# COGBLADE MELEE (toque rápido em C / L1)
# A lâmina passa UMA vez de um lado para o outro na frente do player,
# alternando o lado a cada uso (esquerda->direita, depois direita->esquerda,
# e assim por diante). É rápido, gasta estamina e só acerta inimigos perto,
# como um golpe corpo a corpo. Só pode ser repetido depois que o golpe atual
# termina, então apertar várias vezes executa vários golpes em sequência.
# =========================================================================

var _melee_sign: float = 1.0 # +1 começa pela direita (corta direita -> esquerda)
var _melee_tween: Tween = null
var _melee_hand_tween: Tween = null
var _melee_hand_active: bool = false
# Momento (em ms de tempo real) a partir do qual um novo golpe pode sair
var _melee_ready_ms: int = 0

func cogblade_melee_slash() -> bool:
	if not is_instance_valid(player.crescent_cogblade): return false
	if player.cogblade_melee_active: return false # espera o golpe atual terminar
	if Time.get_ticks_msec() < _melee_ready_ms: return false # cooldown entre golpes
	if player.is_using_ultimate or player.cogblade_menu_open: return false
	if player.is_magic_attacking or player.is_blade_returning or player.is_reloading: return false
	if player.is_exhausted: return false
	if not (player.current_stamina >= player.melee_stamina_cost or player.infinite_stamina_test):
		return false
	
	if not player.infinite_stamina_test:
		player.current_stamina = maxf(0.0, player.current_stamina - player.melee_stamina_cost)
	player.stamina_fade_timer = 2.0
	
	player.cogblade_melee_active = true
	
	var side: float = _melee_sign
	_melee_sign = -_melee_sign # o próximo golpe vem do lado oposto
	
	player.crescent_cogblade.show()
	player.crescent_cogblade.top_level = true
	var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas")
	if faiscas: faiscas.emitting = true
	
	# A mão esquerda só entra na jogada quando ela está visível na tela
	# (primeira pessoa); em terceira pessoa a lâmina passa sozinha.
	_melee_hand_active = is_instance_valid(player.hand_magic_3d) \
		and is_instance_valid(player.hand_with_magic) \
		and player.hand_with_magic.visible
	if _melee_hand_active:
		if _melee_hand_tween and _melee_hand_tween.is_valid():
			_melee_hand_tween.kill()
		_melee_hand_tween = null
		player.hand_magic_3d.visible = true
	
	_play_blade_sound("res://assets/sounds/player/blade_out.mp3", randf_range(1.3, 1.55), -3.0)
	
	var streak := _melee_spawn_streak()
	var dur: float = maxf(player.melee_duration, 0.05)
	
	var t := create_tween()
	_melee_tween = t
	t.tween_method(func(p: float): _melee_update(p, side, streak), 0.0, 0.5, dur * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# O dano sai no meio do golpe, quando a lâmina passa na frente do player
	t.tween_callback(func(): _melee_apply_damage())
	t.tween_method(func(p: float): _melee_update(p, side, streak), 0.5, 1.0, dur * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_reset_blade_to_hand()
		player.cogblade_melee_active = false
		_melee_start_cooldown()
		_melee_fade_streak(streak)
		_melee_return_hand()
	)
	return true

# Usa tempo real (ticks) de propósito: o cooldown é do jogador, não da cena,
# então não deve esticar se o jogo estiver em câmera lenta.
func _melee_start_cooldown() -> void:
	_melee_ready_ms = Time.get_ticks_msec() + maxi(0, player.melee_cooldown_ms)

# A mão volta devagar para a posição de descanso, do mesmo jeito que acontece
# no fim da animação de recarregar a arma.
func _melee_return_hand() -> void:
	if not _melee_hand_active: return
	_melee_hand_active = false
	if not is_instance_valid(player.hand_magic_3d): return
	if _melee_hand_tween and _melee_hand_tween.is_valid():
		_melee_hand_tween.kill()
	_melee_hand_tween = create_tween()
	_melee_hand_tween.tween_property(player.hand_magic_3d, "position",
		player.hand_magic_3d_pos_hidden, maxf(player.melee_hand_return_time, 0.05))\
		.set_trans(Tween.TRANS_SINE)

func _melee_update(p: float, side: float, streak: Line2D) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(cam): cam = player.camera
	if not is_instance_valid(cam) or not is_instance_valid(player.crescent_cogblade): return
	
	var b := cam.global_transform.basis
	# Ponto na frente do player, na altura do peito
	var center: Vector3 = player.global_position + Vector3(0.0, player.melee_height, 0.0) - b.z * player.melee_distance
	# Diagonal: canto SUPERIOR de um lado até o canto INFERIOR do outro lado
	var offset: Vector3 = b.x * (player.melee_range * 0.75) * side \
		+ b.y * (player.melee_range * player.melee_vertical_ratio)
	var from_pos: Vector3 = center + offset
	var to_pos: Vector3 = center - offset
	var blade_pos: Vector3 = from_pos.lerp(to_pos, p)
	
	# Pose de arremesso, mas acompanhando a inclinação da câmera
	var local := Basis.from_euler(Vector3(
		deg_to_rad(player.cut_cogblade_rot_x),
		deg_to_rad(player.cut_cogblade_rot_y),
		deg_to_rad(player.cut_cogblade_rot_z)))
	_cut_set_blade(blade_pos, b * local, 1.0)
	
	# A mão esquerda acompanha o golpe, como se fosse ela empunhando a lâmina
	_melee_update_hand(blade_pos, center, b, p)
	
	# Rastro 2D acompanhando o golpe (uma faixa curta, não a tela inteira)
	if is_instance_valid(streak):
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var c: Vector2 = vp * 0.5
		# Y da tela cresce para baixo, por isso o canto de cima é -y
		var s_off := Vector2(vp.x * 0.55 * side, -vp.y * 0.55)
		var sa: Vector2 = c + s_off
		var sb: Vector2 = c - s_off
		var tail: float = maxf(0.0, p - 0.4)
		streak.points = PackedVector2Array([sa.lerp(sb, tail), sa.lerp(sb, p)])

# Move a mão esquerda seguindo uma versão reduzida do arco da lâmina, para dar
# a sensação de que é a mão que está desferindo o golpe (e não a lâmina
# voando sozinha). Tudo é recalculado por frame, então a mão continua colada
# na câmera mesmo se o player girar durante o golpe.
func _melee_update_hand(blade_pos: Vector3, center: Vector3, cam_basis: Basis, p: float) -> void:
	if not _melee_hand_active: return
	if not is_instance_valid(player.hand_magic_3d) or not is_instance_valid(player.hand_with_magic): return
	
	var rest_world: Vector3 = player.hand_with_magic.to_global(player.hand_magic_3d_pos_original)
	var follow: Vector3 = (blade_pos - center) * player.melee_hand_follow
	var push: Vector3 = -cam_basis.z * (sin(p * PI) * player.melee_hand_push)
	player.hand_magic_3d.position = player.hand_with_magic.to_local(rest_world + follow + push)

func _melee_apply_damage() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3
	if is_instance_valid(cam):
		forward = -cam.global_transform.basis.z
	else:
		forward = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01: return
	forward = forward.normalized()
	
	var origin: Vector3 = player.global_position
	var acertou := false
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(inimigo) or not inimigo.has_method("take_damage"): continue
		var to: Vector3 = inimigo.global_position - origin
		if to.length() > player.melee_range: continue
		var flat := Vector3(to.x, 0.0, to.z)
		# Só acerta quem está na frente do player
		if flat.length() > 0.01 and flat.normalized().dot(forward) < 0.15: continue
		inimigo.take_damage(player.melee_damage)
		acertou = true
		if player.has_method("spawn_blood_effect"):
			player.spawn_blood_effect(inimigo)
	
	if acertou:
		if is_instance_valid(player.blade_in): player.blade_in.play()
		GlobalUtils.shake_camera(0.12, 0.12)
		GlobalUtils.vibrate_controller(Input, 0.3, 0.3, 0.1)

func _melee_spawn_streak() -> Line2D:
	var layer := CanvasLayer.new()
	layer.name = "CogbladeMeleeFX"
	layer.layer = 104
	player.add_child(layer)
	
	var line := Line2D.new()
	line.width = 22.0
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	
	var grad := Gradient.new()
	grad.set_color(0, Color(0.3, 0.85, 1.0, 0.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.85))
	line.gradient = grad
	
	var wcurve := Curve.new()
	wcurve.add_point(Vector2(0.0, 0.05))
	wcurve.add_point(Vector2(0.85, 1.0))
	wcurve.add_point(Vector2(1.0, 0.25))
	line.width_curve = wcurve
	
	layer.add_child(line)
	line.set_meta("fx_layer", layer)
	return line

func _melee_fade_streak(streak: Line2D) -> void:
	if not is_instance_valid(streak): return
	var layer = streak.get_meta("fx_layer") if streak.has_meta("fx_layer") else null
	var t := create_tween()
	t.tween_property(streak, "modulate:a", 0.0, 0.12)
	t.tween_callback(func():
		if is_instance_valid(layer): layer.queue_free()
		elif is_instance_valid(streak): streak.queue_free()
	)

func _apply_aoe_damage_slowly(pos: Vector3, damage: int = 30, radius: float = 15.0):
	var inimigos = get_tree().get_nodes_in_group("enemies")
	var afetados = []
	for inimigo in inimigos:
		if is_instance_valid(inimigo) and inimigo.has_method("take_damage"):
			if inimigo.global_position.distance_to(pos) <= radius:
				afetados.append(inimigo)
				
	# Aplica o dano em sequência para dar peso
	for i in range(afetados.size()):
		var inimigo = afetados[i]
		var t = create_tween()
		t.tween_interval(0.02 * i) # Intervalo minúsculo, mas perceptível no slow-mo
		t.tween_callback(func():
			if is_instance_valid(inimigo):
				inimigo.take_damage(damage)
				
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
