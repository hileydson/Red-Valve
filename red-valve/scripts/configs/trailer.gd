extends Node3D

@export var inicio: Marker3D
@export var fim: Marker3D
var ui_fader: ColorRect
var lightning_flash_rect: ColorRect

# Canvas layers para filtros visuais
var old_film_layer: CanvasLayer = null
var motion_blur_layer: CanvasLayer = null
var motion_blur_rect: ColorRect = null
var motion_blur_mat: ShaderMaterial = null

# Audio players
var zoom_sound_player: AudioStreamPlayer = null
var rain_audio_player: AudioStreamPlayer = null
var thunder_audio_player: AudioStreamPlayer = null

# Sistema de Chuva 3D
var rain_particles: CPUParticles3D = null

# Sistema de Relâmpagos e Céu
var lightning_light: DirectionalLight3D = null
var lightning_loop_active: bool = false

# Controle de câmera dinâmica ("solta" / assíncrona)
var loop_bolas_fogo: bool = false
var active_cam: Camera3D = null
var target_local_pos: Vector3 = Vector3.ZERO
var target_local_rot: Vector3 = Vector3.ZERO
var cam_follow_speed: float = 4.0
var cam_rot_speed: float = 3.0
var is_loose_camera_active: bool = false

# Controle de balanço da cabeça (Head Bob em 1ª pessoa)
var is_head_bob_active: bool = false
var head_bob_intensity: float = 0.0 # 0.1 = caminhada leve, 1.0 = corrida
var head_bob_time: float = 0.0

var player_ref: Node3D = null
var anti_lopes_ref: Node3D = null
var anti_lopes_fixed_pos: Vector3 = Vector3.ZERO
var thunder_sounds_played: int = 0

func _enter_tree() -> void:
	GlobalEvents.is_maycow_normal = false

func _ready() -> void:
	# Canvas Layer para Fader e Clarão do Relâmpago
	var canvas = CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	
	# Clarão de Relâmpago na Tela
	lightning_flash_rect = ColorRect.new()
	lightning_flash_rect.color = Color(0.9, 0.95, 1.0, 1.0)
	lightning_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	lightning_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lightning_flash_rect.modulate.a = 0.0
	canvas.add_child(lightning_flash_rect)

	# Fader de transição (Fade In/Out)
	ui_fader = ColorRect.new()
	ui_fader.color = Color(0, 0, 0, 1)
	ui_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_fader.modulate.a = 0.0
	canvas.add_child(ui_fader)

	if not inicio:
		inicio = get_tree().current_scene.find_child("inicio", true, false) as Marker3D
	if not fim:
		fim = get_tree().current_scene.find_child("fim", true, false) as Marker3D
		
	var anim_player = get_tree().current_scene.find_child("AnimationPlayer", true, false)
	if anim_player and anim_player is AnimationPlayer:
		anim_player.stop()
		anim_player.active = false
		
	_setup_audio_system()
	_setup_rain_particles()
	_setup_comet_particles()
	_setup_lightning_light()
	_setup_anti_lopes()
	
	cutscene_trailer_sequence()

func _process(delta: float) -> void:
	# Trava o the_anti_lopes no local exato do cenário sem descimento
	if is_instance_valid(anti_lopes_ref):
		anti_lopes_ref.global_position = anti_lopes_fixed_pos

	if not is_instance_valid(player_ref) or not is_instance_valid(active_cam):
		return
		
	# Atualiza a posição das partículas de chuva para acompanhar a câmera ativa
	if is_instance_valid(rain_particles):
		rain_particles.global_position = active_cam.global_position + Vector3(0, 8.0, 0)

	# 1. Movimento de câmera solta com assincronia / atraso orgânico (Lerp Damping)
	if is_loose_camera_active:
		var target_world_trans = player_ref.global_transform * Transform3D(
			Basis.from_euler(Vector3(
				deg_to_rad(target_local_rot.x),
				deg_to_rad(target_local_rot.y),
				deg_to_rad(target_local_rot.z)
			)),
			target_local_pos
		)
		active_cam.global_position = active_cam.global_position.lerp(target_world_trans.origin, delta * cam_follow_speed)
		active_cam.global_basis = active_cam.global_basis.slerp(target_world_trans.basis, delta * cam_rot_speed)

	# 2. Efeito de balanço de cabeça (Head Bob em 1ª pessoa)
	if is_head_bob_active:
		var is_running = (head_bob_intensity > 0.5)
		head_bob_time += delta * (14.0 if is_running else 4.5)
		
		var amp_y = 0.08 if is_running else 0.01
		var amp_x = 0.05 if is_running else 0.005
		var amp_z = 3.0 if is_running else 0.25
		
		var offset_y = sin(head_bob_time * 2.0) * amp_y
		var offset_x = cos(head_bob_time) * amp_x
		var tilt_z = cos(head_bob_time) * amp_z
		
		var bob_offset = Vector3(offset_x, offset_y, 0)
		var base_pos = player_ref.global_transform * Vector3(0, 1.6, 0)
		active_cam.global_position = active_cam.global_position.lerp(base_pos + bob_offset, delta * 12.0)
		active_cam.rotation_degrees.z = lerp(active_cam.rotation_degrees.z, tilt_z, delta * 10.0)

# ==============================================================================
# ÁUDIO, CHUVA E RELÂMPAGOS
# ==============================================================================

func _setup_audio_system() -> void:
	# 1. Som de Zoom/Dash
	zoom_sound_player = AudioStreamPlayer.new()
	var dash_snd = load("res://assets/sounds/player/dash_effect.mp3")
	if dash_snd:
		zoom_sound_player.stream = dash_snd
		zoom_sound_player.pitch_scale = 1.15
		zoom_sound_player.volume_db = -2.0
	add_child(zoom_sound_player)

	# 2. Som de Chuva Ambiente
	rain_audio_player = AudioStreamPlayer.new()
	var rain_snd = load("res://assets/sounds/episodios/prologo/chuva.mp3")
	if rain_snd:
		rain_audio_player.stream = rain_snd
		rain_audio_player.volume_db = 1.0
	add_child(rain_audio_player)
	
	# 3. Som de Trovão (Eco grave de tempestade realista com pitch bem baixo)
	thunder_audio_player = AudioStreamPlayer.new()
	var thunder_snd = load("res://assets/sounds/common/explosao.mp3")
	if thunder_snd:
		thunder_audio_player.stream = thunder_snd
		thunder_audio_player.pitch_scale = 0.32
		thunder_audio_player.volume_db = 1.0
	add_child(thunder_audio_player)

func _setup_rain_particles() -> void:
	rain_particles = CPUParticles3D.new()
	rain_particles.amount = 2200
	rain_particles.lifetime = 1.1
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(16, 1, 16)
	rain_particles.direction = Vector3(-0.15, -1.0, -0.05).normalized()
	rain_particles.spread = 4.0
	rain_particles.gravity = Vector3(0, -26.0, 0)
	rain_particles.initial_velocity_min = 14.0
	rain_particles.initial_velocity_max = 20.0
	rain_particles.color = Color(0.75, 0.85, 1.0, 0.28)
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.005, 0.4) # Chuva fina e delicada
	rain_particles.mesh = mesh
	add_child(rain_particles)

func _setup_comet_particles() -> void:
	var comet_particles = CPUParticles3D.new()
	comet_particles.amount = 35
	comet_particles.lifetime = 6.0
	comet_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	comet_particles.emission_box_extents = Vector3(150, 40, 150)
	comet_particles.direction = Vector3(-1.0, -0.6, 0.0).normalized() # Da direita pra esquerda e caindo
	comet_particles.spread = 15.0
	comet_particles.gravity = Vector3(0, -6.0, 0)
	comet_particles.initial_velocity_min = 35.0
	comet_particles.initial_velocity_max = 50.0
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.05, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(1.5, 4.0) # Forma alongada como um rastro
	mesh.material = mat
	comet_particles.mesh = mesh
	
	# Posiciona globalmente no alto para cobrir toda a área do trailer de longe
	comet_particles.global_position = Vector3(120, 80, -30)
	add_child(comet_particles)

func _setup_lightning_light() -> void:
	lightning_light = DirectionalLight3D.new()
	lightning_light.light_color = Color(0.85, 0.92, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.rotation_degrees = Vector3(-70, 20, 0)
	add_child(lightning_light)

func _iniciar_chuva_e_relampagos() -> void:
	if is_instance_valid(rain_audio_player) and rain_audio_player.stream:
		if not rain_audio_player.finished.is_connected(_on_rain_sound_finished):
			rain_audio_player.finished.connect(_on_rain_sound_finished)
		rain_audio_player.play()
		
	lightning_loop_active = true
	_loop_relampagos_aleatorios()

func _on_rain_sound_finished() -> void:
	if is_instance_valid(rain_audio_player) and GlobalEvents.in_cutscene:
		rain_audio_player.play()

func _loop_relampagos_aleatorios() -> void:
	while lightning_loop_active and GlobalEvents.in_cutscene:
		var wait_time = randf_range(2.5, 5.0)
		await get_tree().create_timer(wait_time).timeout
		if not lightning_loop_active or not GlobalEvents.in_cutscene:
			break
		await _disparar_relampago()

func _setup_anti_lopes() -> void:
	anti_lopes_ref = get_tree().current_scene.find_child("the_anti_lopes", true, false) as Node3D
	if is_instance_valid(anti_lopes_ref):
		anti_lopes_fixed_pos = anti_lopes_ref.global_position
		
		# 1. Iniciar animação Spear_Walk imediatamente ao carregar a cena
		var anim_player = anti_lopes_ref.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player:
			if anim_player.has_animation("Spear_Walk"):
				anim_player.autoplay = "Spear_Walk"
				anim_player.play("Spear_Walk")
			else:
				var anims = anim_player.get_animation_list()
				if anims.size() > 0:
					anim_player.play(anims[0])
					
		# 2. Tornar o modelo meio transparente (efeito com alpha 0.45)
		_apply_transparency_to_node(anti_lopes_ref, 0.45)

func _apply_transparency_to_node(node: Node, alpha: float = 0.2) -> void:
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		var mat_count = mesh_inst.get_surface_override_material_count()
		if mat_count == 0 and mesh_inst.mesh:
			mat_count = mesh_inst.mesh.get_surface_count()
			
		for i in range(max(1, mat_count)):
			var orig_mat = mesh_inst.get_surface_override_material(i)
			if not orig_mat and mesh_inst.mesh and i < mesh_inst.mesh.get_surface_count():
				orig_mat = mesh_inst.mesh.surface_get_material(i)
			
			if orig_mat:
				var new_mat = orig_mat.duplicate()
				if new_mat is BaseMaterial3D:
					if alpha >= 0.99:
						new_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					else:
						new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					new_mat.albedo_color.a = alpha
					mesh_inst.set_surface_override_material(i, new_mat)
				elif "albedo_color" in new_mat:
					new_mat.albedo_color.a = alpha
					mesh_inst.set_surface_override_material(i, new_mat)
			else:
				var std_mat = StandardMaterial3D.new()
				if alpha >= 0.99:
					std_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				else:
					std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				std_mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)
				mesh_inst.set_surface_override_material(i, std_mat)
	
	for child in node.get_children():
		_apply_transparency_to_node(child, alpha)

func _disparar_relampago() -> void:
	if not is_instance_valid(lightning_light): return
	
	# Sequência de relâmpago com múltiplos clarões realistas (Visual)
	lightning_light.light_energy = 8.0
	lightning_flash_rect.modulate.a = 0.5
	await get_tree().create_timer(0.04).timeout
	
	lightning_light.light_energy = 1.5
	lightning_flash_rect.modulate.a = 0.1
	await get_tree().create_timer(0.03).timeout
	
	lightning_light.light_energy = 9.5
	lightning_flash_rect.modulate.a = 0.65
	await get_tree().create_timer(0.06).timeout
	
	lightning_light.light_energy = 0.0
	lightning_flash_rect.modulate.a = 0.0
func _iniciar_som_velocidade_continuo() -> void:
	if is_instance_valid(zoom_sound_player) and zoom_sound_player.stream:
		if not zoom_sound_player.finished.is_connected(_on_zoom_sound_finished):
			zoom_sound_player.finished.connect(_on_zoom_sound_finished)
		zoom_sound_player.play()

func _on_zoom_sound_finished() -> void:
	if is_instance_valid(zoom_sound_player) and GlobalEvents.in_cutscene:
		zoom_sound_player.play()

func _parar_som_velocidade() -> void:
	if is_instance_valid(zoom_sound_player):
		if zoom_sound_player.finished.is_connected(_on_zoom_sound_finished):
			zoom_sound_player.finished.disconnect(_on_zoom_sound_finished)
		zoom_sound_player.stop()

# ==============================================================================
# FILTROS VISUAIS (FILME VELHO E MOTION BLUR)
# ==============================================================================

func _setup_old_film_filter() -> void:
	old_film_layer = CanvasLayer.new()
	old_film_layer.layer = 110
	add_child(old_film_layer)
	
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	old_film_layer.add_child(back_buffer)
	
	var film_rect = ColorRect.new()
	film_rect.name = "OldFilmOverlay"
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader_code: String = """
	shader_type canvas_item;

	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	uniform float sepia_amount : hint_range(0.0, 1.0) = 0.35;
	uniform float grain_amount : hint_range(0.0, 1.0) = 0.18;
	uniform float scratch_amount : hint_range(0.0, 1.0) = 0.35;
	uniform float vignette_amount : hint_range(0.0, 1.0) = 0.65;
	uniform float flicker_amount : hint_range(0.0, 1.0) = 0.08;

	float rand(vec2 co) {
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}

	void fragment() {
		vec2 uv = SCREEN_UV;
		vec4 color = texture(screen_texture, uv);
		
		vec3 sepia = vec3(
			dot(color.rgb, vec3(0.393, 0.769, 0.189)),
			dot(color.rgb, vec3(0.349, 0.686, 0.168)),
			dot(color.rgb, vec3(0.272, 0.534, 0.131))
		);
		color.rgb = mix(color.rgb, sepia, sepia_amount);
		
		float noise = rand(uv + vec2(TIME * 18.0, TIME * 33.0));
		color.rgb += (noise - 0.5) * grain_amount;
		
		float scratch_rand = rand(vec2(floor(uv.x * 250.0), floor(TIME * 12.0)));
		if (scratch_rand > (1.0 - scratch_amount * 0.04)) {
			float scratch_int = rand(vec2(uv.x, TIME * 5.0));
			color.rgb -= vec3(scratch_int * 0.35);
		}
		
		float dist = distance(uv, vec2(0.5, 0.5));
		float vignette = smoothstep(0.85, 0.25, dist * vignette_amount);
		color.rgb *= mix(1.0, vignette, vignette_amount);
		
		float flicker = sin(TIME * 35.0) * 0.5 + 0.5;
		color.rgb *= (1.0 - flicker * flicker_amount);
		
		COLOR = color;
	}
	"""
	var shader = Shader.new()
	shader.code = shader_code
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	film_rect.material = mat
	old_film_layer.add_child(film_rect)

func _setup_motion_blur_filter() -> void:
	motion_blur_layer = CanvasLayer.new()
	motion_blur_layer.layer = 112
	add_child(motion_blur_layer)
	
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	motion_blur_layer.add_child(back_buffer)
	
	motion_blur_rect = ColorRect.new()
	motion_blur_rect.name = "MotionBlurOverlay"
	motion_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	motion_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_blur_rect.visible = false
	
	var shader_code: String = """
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
	var shader = Shader.new()
	shader.code = shader_code
	
	motion_blur_mat = ShaderMaterial.new()
	motion_blur_mat.shader = shader
	motion_blur_mat.set_shader_parameter("blur_strength", 0.0)
	motion_blur_rect.material = motion_blur_mat
	motion_blur_layer.add_child(motion_blur_rect)

func _set_motion_blur_strength(strength: float) -> void:
	if motion_blur_rect and motion_blur_mat:
		motion_blur_mat.set_shader_parameter("blur_strength", strength)
		motion_blur_rect.visible = (strength > 0.0)

# Helper para instanciar a câmera solta (loose tracking)
func _switch_to_loose_camera(initial_local_pos: Vector3, initial_local_rot: Vector3, follow_spd: float = 4.0, rot_spd: float = 3.0) -> Camera3D:
	is_head_bob_active = false
	is_loose_camera_active = false
	
	if is_instance_valid(active_cam):
		active_cam.queue_free()
		
	var cam = Camera3D.new()
	add_child(cam)
	
	target_local_pos = initial_local_pos
	target_local_rot = initial_local_rot
	cam_follow_speed = follow_spd
	cam_rot_speed = rot_spd
	
	var initial_world_trans = player_ref.global_transform * Transform3D(
		Basis.from_euler(Vector3(
			deg_to_rad(initial_local_rot.x),
			deg_to_rad(initial_local_rot.y),
			deg_to_rad(initial_local_rot.z)
		)),
		initial_local_pos
	)
	cam.global_transform = initial_world_trans
	cam.make_current()
	
	active_cam = cam
	is_loose_camera_active = true
	return cam

# ==============================================================================
# SEQUÊNCIA PRINCIPAL DA CUTSCENE
# ==============================================================================

func cutscene_trailer_sequence() -> void:
	print("--- CUTSCENE TRAILER INICIADA ---")
	GlobalEvents.in_cutscene = true
	if not inicio or not fim:
		push_error("ERRO CRITICO: Markers 'inicio' e 'fim' não encontrados!")
		return
		
	var players = get_tree().get_nodes_in_group("player")
	var player = null
	
	if players.is_empty(): 
		var player_scene = load("res://scenes/player/player.tscn")
		if player_scene:
			player = player_scene.instantiate()
			add_child(player)
		else:
			push_error("Não foi possível carregar a cena do player!")
			return
	else:
		player = players[0]
		
	player_ref = player
	_setup_old_film_filter()
	_setup_motion_blur_filter()
	_iniciar_chuva_e_relampagos()
	
	cutscene_force_maycow_lopes_only()
	player.cutscene_set_hud_enabled(false)
	player.cutscene_set_player_control(false)
	player.cutscene_set_camera_current(false)
	
	var model = player.get_node_or_null("maycow_lopes")
	if model and model.has_node("AnimationTree"):
		var anim_tree = model.get_node("AnimationTree") as AnimationTree
		anim_tree.active = true
		if "playback" in player:
			player.playback = anim_tree.get("parameters/playback")
	
	player.global_position = inicio.global_position + Vector3(0, 1.0, 0)
	var target_pos = fim.global_position
	target_pos.y = player.global_position.y
	if player.global_position.distance_squared_to(target_pos) > 0.001:
		player.look_at(target_pos, Vector3.UP)
	
	# Maycow inicia a caminhada contínua em velocidade calma
	player.cutscene_set_auto_walk(true)
	
	# --------------------------------------------------------------------------
	# TAKE 1: CÂMERA DE CIMA COMEÇANDO DA POSIÇÃO EXATA DA CAMERA_1 NO EDITOR
	# --------------------------------------------------------------------------
	print("Take 1: Câmera começando da posição configurada no editor (camera_1)...")
	
	var cam_1 = get_tree().current_scene.get_node_or_null("camera_1") as Camera3D
	var start_local_pos = Vector3(0, 0.2, 2.5)
	var start_local_rot = Vector3(-10, 0, 0)
	
	if cam_1:
		# Pega a posição e rotação relativas ao player exatamente como estão no editor
		var cam_local_trans = player.global_transform.affine_inverse() * cam_1.global_transform
		start_local_pos = cam_local_trans.origin
		
		var euler = cam_local_trans.basis.get_euler()
		start_local_rot = Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))
	
	# Força a câmera começar mais de baixo
	var target_final_y = start_local_pos.y + 6.0
	start_local_pos.y -= 4.0
	
	_switch_to_loose_camera(start_local_pos, start_local_rot, 3.5, 2.5)
	
	# Take 1: Começa de baixo e sobe devagar
	var tween_take1 = create_tween().set_parallel(true)
	tween_take1.tween_property(self, "target_local_rot:x", -70.0, 4.0).set_trans(Tween.TRANS_SINE)
	tween_take1.tween_property(self, "target_local_pos:y", target_final_y, 4.0).set_trans(Tween.TRANS_SINE)
	tween_take1.tween_property(self, "target_local_pos:z", start_local_pos.z, 4.0).set_trans(Tween.TRANS_SINE)
	
	# Segunda metade do take 1: mergulha na cabeça do player
	var tween_take1_p2 = create_tween().set_parallel(true)
	tween_take1_p2.tween_interval(4.5)
	tween_take1_p2.chain().tween_property(self, "target_local_rot:x", 0.0, 3.5).set_trans(Tween.TRANS_SINE)
	tween_take1_p2.parallel().tween_property(self, "target_local_pos:y", 1.6, 3.5).set_trans(Tween.TRANS_SINE)
	tween_take1_p2.parallel().tween_property(self, "target_local_pos:z", -0.5, 3.5).set_trans(Tween.TRANS_SINE)
	
	# Zoom extra de FOV na câmera solta
	if is_instance_valid(active_cam):
		var tween_zoom_take1 = create_tween()
		tween_zoom_take1.tween_interval(4.5)
		tween_zoom_take1.tween_property(active_cam, "fov", 35.0, 3.0).set_trans(Tween.TRANS_SINE)
		tween_zoom_take1.tween_property(active_cam, "fov", 15.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(8.0).timeout
	print("... Take 1 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 2: PRIMEIRA PESSOA - OLHANDO PARA DIREITA E CIMA (CÉU) (6s)
	# --------------------------------------------------------------------------
	print("Take 2: Primeira pessoa, olhando para direita e para o céu (6s)...")
	is_loose_camera_active = false
	if is_instance_valid(active_cam): active_cam.queue_free()
	
	var cam_fps_sky = Camera3D.new()
	add_child(cam_fps_sky)
	cam_fps_sky.global_transform = player.global_transform * Transform3D(Basis(), Vector3(0, 1.6, 0))
	cam_fps_sky.make_current()
	active_cam = cam_fps_sky
	
	if model:
		model.visible = false
		
	is_head_bob_active = true
	head_bob_intensity = 0.5
	
	# Maycow olha pra direita (-45 em Y) e pra cima (+60 em X) 
	var tween_look_sky = create_tween().set_parallel(true)
	tween_look_sky.tween_property(cam_fps_sky, "rotation_degrees:y", -45.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween_look_sky.tween_property(cam_fps_sky, "rotation_degrees:x", 60.0, 2.0).set_trans(Tween.TRANS_SINE)
	
	# Lança a primeira bola de fogo que passa em direção ao céu
	await get_tree().create_timer(1.0).timeout
	var start_pos_fogo = player.global_position + Vector3(30, -5, -10)
	var end_pos_fogo = start_pos_fogo + Vector3(10, 150, -40)
	_criar_bola_de_fogo(start_pos_fogo, end_pos_fogo, 1.5)
	_loop_bolas_de_fogo()
	
	await get_tree().create_timer(2.5).timeout
	
	# Volta a câmera para onde iniciou o take (olhando pra frente)
	var tween_look_back = create_tween().set_parallel(true)
	tween_look_back.tween_property(cam_fps_sky, "rotation_degrees:y", 0.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_look_back.tween_property(cam_fps_sky, "rotation_degrees:x", 0.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_look_back.finished
	
	if model:
		model.visible = true
		
	print("... Take 2 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 3: PRIMEIRA PESSOA ANDANDO - OLHANDO PARA CIMA E VOLTANDO (4s)
	# --------------------------------------------------------------------------
	print("Take 3: Primeira pessoa ANDANDO com olhar para cima em direção à cabeça do enemy (4s)...")
	is_loose_camera_active = false
	if is_instance_valid(active_cam): active_cam.queue_free()
	
	var cam_fps_walk = Camera3D.new()
	add_child(cam_fps_walk)
	cam_fps_walk.global_transform = player.global_transform * Transform3D(Basis(), Vector3(0, 1.6, 0))
	cam_fps_walk.make_current()
	active_cam = cam_fps_walk
	
	if model:
		model.visible = false
		
	is_head_bob_active = true
	head_bob_intensity = 0.1
	
	# Maycow olha para cima (em direção à cabeça do enemy) e depois volta a olhar pra frente
	var tween_look_up = create_tween()
	tween_look_up.tween_property(cam_fps_walk, "rotation_degrees:x", 26.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_look_up.tween_interval(0.4)
	tween_look_up.tween_property(cam_fps_walk, "rotation_degrees:x", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await get_tree().create_timer(4.0).timeout
	print("... Take 3 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 4: ARRANCADA FINAL + ZOOM LEVE NA VÁLVULA + MÃO EM DIREÇÃO À VÁLVULA
	# --------------------------------------------------------------------------
	print("Take 4: Arrancada final até a porta portal_red_valve...")
	
	_iniciar_som_velocidade_continuo()
	_set_motion_blur_strength(0.35)
	
	head_bob_intensity = 1.0
	
	player.cutscene_set_auto_walk(false)
	player.cutscene_set_auto_run(true)
	
	var tempo_sprint = 3.5
	var tween_corrida = create_tween()
	tween_corrida.tween_property(player, "global_position", fim.global_position, tempo_sprint).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	var tween_fov = create_tween()
	tween_fov.tween_property(cam_fps_walk, "fov", 92.0, tempo_sprint).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween_corrida.finished
	print("Chegou à porta! Iniciando zoom LEVE no portal_red_valve...")
	
	# Desativa corrida e balanço extremo
	player.cutscene_set_auto_run(false)
	player.cutscene_set_auto_walk(false)
	is_head_bob_active = false
	_set_motion_blur_strength(0.0)
	
	# 1. ZOOM MODERADO NA VÁLVULA
	var target_zoom_fov = 45.0
	var zoom_duration = 3.5
	var valve_cam_pos = fim.global_position + Vector3(0, 1.4, 2.0)
	
	var tween_zoom_door = create_tween().set_parallel(true)
	tween_zoom_door.tween_property(cam_fps_walk, "fov", target_zoom_fov, zoom_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_zoom_door.tween_property(cam_fps_walk, "global_position", valve_cam_pos, zoom_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Criar ambiente escuro e holofote focando na porta durante o zoom
	var dark_env = Environment.new()
	dark_env.background_mode = Environment.BG_COLOR
	dark_env.background_color = Color.BLACK
	dark_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	dark_env.ambient_light_color = Color.BLACK
	cam_fps_walk.environment = dark_env
	
	var door_spot = SpotLight3D.new()
	door_spot.spot_range = 10.0
	door_spot.spot_angle = 35.0
	door_spot.light_energy = 5.0
	cam_fps_walk.add_child(door_spot)
	# Diminuir som de velocidade mas MANTER chuva e relâmpagos ativos!
	if is_instance_valid(zoom_sound_player):
		pass
		
	# 1. ZOOM NA PORTA DA FRENTE (FOV 45) DURANTE 3 SEGUNDOS E A MÃO APARECE
	var tween_cam = create_tween()
	tween_cam.tween_property(cam_fps_walk, "fov", 45.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var player_hand = player_ref.find_child("hand_with_magic", true, false)
	if player_hand:
		var hand_3d = player_hand.duplicate()
		cam_fps_walk.add_child(hand_3d)
		_set_visible_recursive(hand_3d, true)
		
		# Inicia abaixo da tela, mas com a posição ALVO alterada (MAIS PARA A DIREITA)
		var target_trans = hand_3d.transform
		target_trans.origin.x += 0.55 # BEM mais para a direita
		target_trans.origin.y -= 0.35 # Mais para baixo
		
		# A posição INICIAL é ainda mais para baixo (para dar o efeito de subir durante o tween)
		hand_3d.transform = target_trans
		hand_3d.transform.origin.y -= 0.7
		
		# Sobe devagarzinho em direção à válvula
		var tween_hand = create_tween()
		tween_hand.tween_property(hand_3d, "transform", target_trans, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# Diminuir som de velocidade mas MANTER chuva e relâmpagos ativos!
	if is_instance_valid(zoom_sound_player):
		var tween_audio = create_tween()
		tween_audio.tween_property(zoom_sound_player, "volume_db", -60.0, 3.0)
		
	# Espera um pouco mais durante o foco na porta e movimento da mão
	await get_tree().create_timer(3.0).timeout
	
	# 3. FADE OUT PARA PRETO ENQUANTO A MÃO SE APROXIMA DA VÁLVULA
	var tween_fade_door = create_tween()
	tween_fade_door.tween_property(ui_fader, "modulate:a", 1.0, 1.2)
	await tween_fade_door.finished
	
	# 4. TELA FICA PRETA + SOM iron_goblins_growl (CHUVA E RELÂMPAGOS MANTIDOS ATIVOS!)
	_parar_som_velocidade()
	
	print("Tela preta com chuva/relâmpagos: Tocando iron_goblins_growl...")
	var growl_player = AudioStreamPlayer.new()
	var growl_stream = load("res://assets/sounds/enemies/Iron Goblins/iron_goblins_growl.mp3")
	if growl_stream:
		growl_player.stream = growl_stream
		growl_player.pitch_scale = 0.88
		growl_player.volume_db = 4.0
		add_child(growl_player)
		growl_player.play()
		
	await get_tree().create_timer(1.5).timeout
	
	# 5. REVELAÇÃO DO THE_ANTI_LOPES E ANIMAÇÃO FINAL
	print("Removendo transparência e tocando animação 'final'...")
	
	# Mudar para a camera_final
	var cam_final = get_tree().current_scene.get_node_or_null("camera_final")
	if cam_final and cam_final is Camera3D:
		cam_final.make_current()
	else:
		push_warning("camera_final não encontrada na cena.")
		
	# Remover a transparência
	if is_instance_valid(anti_lopes_ref):
		anti_lopes_ref.visible = true
		_apply_transparency_to_node(anti_lopes_ref, 1.0) # Remove a transparência
	
	var anim_player = get_tree().current_scene.find_child("AnimationPlayer", true, false)
	if anim_player and anim_player is AnimationPlayer:
		anim_player.active = true
		if anim_player.has_animation("final"):
			anim_player.play("final")
		else:
			push_error("Animação 'final' não encontrada no AnimationPlayer da cena!")
	
	# Faz a tela escura sumir revelando a cena no take final
	var tween_reveal = create_tween()
	tween_reveal.tween_property(ui_fader, "modulate:a", 0.0, 1.0)
	
	await get_tree().create_timer(3.0).timeout
	
	# 6. EFEITO PISCANTE NEON DO NOME DO JOGO "RED VALVE" (LETRAS MAIORES E SEM BORDA PRETA)
	print("Exibindo logo 'Red Valve' em letras gigantes (200px) sem borda piscando no centro da tela...")
	var title_canvas = CanvasLayer.new()
	title_canvas.layer = 150
	add_child(title_canvas)
	
	var title_label = Label.new()
	title_label.text = "RED VALVE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.position = Vector2(-600, -130)
	title_label.size = Vector2(1200, 260)
	
	var font_file = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
	if font_file:
		title_label.add_theme_font_override("font", font_file)
	title_label.add_theme_font_size_override("font_size", 200)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.08, 1.0))
	title_label.modulate.a = 0.0
	title_canvas.add_child(title_label)
	
	_flicker_title_effect(title_label, 4.5)
	
	# Aguarda o final
	await get_tree().create_timer(4.5).timeout
	
	# Fade Out Final
	var tween_final = create_tween()
	tween_final.tween_property(ui_fader, "modulate:a", 1.0, 1.0)
	await tween_final.finished
	
	loop_bolas_fogo = false
	lightning_loop_active = false
	if is_instance_valid(rain_audio_player): rain_audio_player.stop()
	if is_instance_valid(old_film_layer): old_film_layer.queue_free()
	if is_instance_valid(motion_blur_layer): motion_blur_layer.queue_free()
	if is_instance_valid(rain_particles): rain_particles.queue_free()
	
	GlobalEvents.in_cutscene = false
	print("--- CUTSCENE TRAILER FINALIZADA COM SUCESSO ---")

func _criar_bola_de_fogo(start_pos: Vector3, end_pos: Vector3, duration: float) -> void:
	var fireball = Node3D.new()
	add_child(fireball)
	fireball.global_position = start_pos
	
	# Som 1 (Cometa) - 3D Positional Audio grave
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/sounds/episodios/trailer/som_cometa.mp3")
	audio.pitch_scale = randf_range(0.5, 0.7) # Grave
	audio.max_db = 6.0
	audio.unit_size = 50.0 # Para ouvir de longe
	fireball.add_child(audio)
	audio.play()
	
	# Som 2 (Rasgando ar - Swoosh) - Também posicional
	var audio_swoosh = AudioStreamPlayer3D.new()
	audio_swoosh.stream = load("res://assets/sounds/player/dash_effect.mp3")
	audio_swoosh.pitch_scale = randf_range(0.8, 1.1)
	audio_swoosh.max_db = 3.0
	audio_swoosh.unit_size = 30.0
	fireball.add_child(audio_swoosh)
	audio_swoosh.play()
	
	# Particulas de rastro volumoso (esféricas em vez de quadradas)
	var parts = CPUParticles3D.new()
	parts.amount = 800
	parts.lifetime = 2.0
	parts.local_coords = false
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 5.0
	parts.gravity = Vector3(0, 5, 0)
	var pmesh = SphereMesh.new()
	pmesh.radius = 2.5
	pmesh.height = 5.0
	var pmat = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.4, 0.0, 0.8)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.material = pmat
	parts.mesh = pmesh
	fireball.add_child(parts)
	
	# Partículas de faíscas explosivas (Sparks - esféricas menores)
	var sparks = CPUParticles3D.new()
	sparks.amount = 500
	sparks.lifetime = 2.5
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 6.0
	sparks.direction = Vector3(0, -1, 0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 10.0
	sparks.initial_velocity_max = 25.0
	sparks.gravity = Vector3(0, -9.8, 0)
	var smesh = SphereMesh.new()
	smesh.radius = 0.4
	smesh.height = 0.8
	var smat = StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.8, 0.2, 1.0)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.5, 0.0)
	smat.emission_energy_multiplier = 15.0
	smesh.material = smat
	sparks.mesh = smesh
	fireball.add_child(sparks)
	
	# Tremer a camera no momento aproximado que ela passa (menos intenso)
	get_tree().create_timer(duration * 0.4).timeout.connect(_shake_camera.bind(0.12, 0.6))
	
	# Curva de movimento mais orgânica / menos linear e robótica
	var tween = create_tween().set_parallel(true)
	tween.tween_property(fireball, "global_position:x", end_pos.x, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(fireball, "global_position:z", end_pos.z, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(fireball, "global_position:y", end_pos.y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(duration).timeout
	
	# Desativa as emissões e deixa o som/partículas sumirem naturalmente
	parts.emitting = false
	sparks.emitting = false
	await get_tree().create_timer(3.0).timeout
	fireball.queue_free()

func _shake_camera(intensity: float, duration: float) -> void:
	if not is_instance_valid(active_cam): return
	var original_h_offset = active_cam.h_offset
	var original_v_offset = active_cam.v_offset
	var shake_tween = create_tween()
	var steps = int(duration * 20.0)
	for i in range(steps):
		shake_tween.tween_property(active_cam, "h_offset", original_h_offset + randf_range(-intensity, intensity), 0.05)
		shake_tween.tween_property(active_cam, "v_offset", original_v_offset + randf_range(-intensity, intensity), 0.05)
	shake_tween.tween_property(active_cam, "h_offset", original_h_offset, 0.05)
	shake_tween.tween_property(active_cam, "v_offset", original_v_offset, 0.05)

func _loop_bolas_de_fogo() -> void:
	loop_bolas_fogo = true
	while loop_bolas_fogo and GlobalEvents.in_cutscene:
		await get_tree().create_timer(randf_range(1.5, 3.5)).timeout
		if not loop_bolas_fogo: break
		
		var player_pos = player_ref.global_position if is_instance_valid(player_ref) else Vector3.ZERO
		var start_x = player_pos.x + randf_range(30, 120)
		var start_z = player_pos.z + randf_range(-100, 30)
		var start_pos = Vector3(start_x, -10, start_z)
		var end_pos = start_pos + Vector3(-120, 450, -100)
		
		_criar_bola_de_fogo(start_pos, end_pos, randf_range(4.0, 7.0))

func _flicker_title_effect(label: Label, duration: float) -> void:
	if not is_instance_valid(label): return
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE
	var elapsed: float = 0.0
	while elapsed < duration:
		if not is_instance_valid(label): break
		var base_alpha = clamp(elapsed / (duration * 0.6), 0.0, 1.0)
		var flicker_factor = 0.1 if randf() < 0.2 else randf_range(0.65, 1.0)
		label.modulate.a = base_alpha * flicker_factor
		var step = randf_range(0.04, 0.1)
		elapsed += step
		await get_tree().create_timer(step).timeout
	if is_instance_valid(label):
		label.modulate.a = 1.0
		label.scale = Vector2.ONE

func cutscene_force_maycow_lopes_only() -> void:
	if not is_instance_valid(player_ref):
		return
	
	# 1. Garantir que o modelo 3D completo do Maycow esteja 100% visível nos takes de 3ª pessoa
	var maycow_model = player_ref.get_node_or_null("maycow_lopes")
	if maycow_model:
		maycow_model.visible = true
		_set_visible_recursive(maycow_model, true)
		
	var maycow_normal = player_ref.get_node_or_null("maycow_lopes_normal")
	if maycow_normal:
		maycow_normal.visible = false
		
	# 2. Ocultar TODAS as mãos de 1ª pessoa, armas e pontos anexados à Camera3D
	var camera_node = player_ref.get_node_or_null("Camera3D")
	if camera_node:
		for child in camera_node.get_children():
			var cname = child.name.to_lower()
			if "hand" in cname or "pistol" in cname or "cogblade" in cname or "blade" in cname or "particles" in cname or "weapon" in cname:
				if child is Node3D or child is CanvasItem:
					child.visible = false
					_set_visible_recursive(child, false)
			if child is CanvasLayer:
				child.visible = false
				_set_visible_recursive(child, false)

	# 3. Remover o ponto de mira central (Reticle point) e elementos de UI
	var point_label = player_ref.find_child("point", true, false)
	if point_label:
		point_label.visible = false

func _set_visible_recursive(node: Node, is_vis: bool) -> void:
	for child in node.get_children():
		if "visible" in child:
			child.visible = is_vis
		_set_visible_recursive(child, is_vis)
