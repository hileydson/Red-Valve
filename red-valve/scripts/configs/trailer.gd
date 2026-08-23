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
					
		# 2. Tornar o modelo quase transparente (efeito fantasma com alpha 0.2)
		_apply_transparency_to_node(anti_lopes_ref, 0.2)

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
					new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					new_mat.albedo_color.a = alpha
					mesh_inst.set_surface_override_material(i, new_mat)
				elif "albedo_color" in new_mat:
					new_mat.albedo_color.a = alpha
					mesh_inst.set_surface_override_material(i, new_mat)
			else:
				var std_mat = StandardMaterial3D.new()
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
	
	# Trovão sonoro apenas em no máximo 2 relâmpagos em toda a cutscene!
	if thunder_sounds_played < 2:
		thunder_sounds_played += 1
		await get_tree().create_timer(randf_range(0.12, 0.35)).timeout
		if is_instance_valid(thunder_audio_player) and thunder_audio_player.stream:
			thunder_audio_player.pitch_scale = randf_range(0.28, 0.38)
			thunder_audio_player.volume_db = randf_range(1.0, 3.5)
			thunder_audio_player.play()

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
	# TAKE 1: CÂMERA DE CIMA (OVERHEAD) COM ROTAÇÃO E SEGUIMENTO SOLTO (8s)
	# --------------------------------------------------------------------------
	print("Take 1: Câmera de CIMA solta com giro lento (8s)...")
	_switch_to_loose_camera(Vector3(0, 7.5, 0.5), Vector3(-80, 0, 0), 3.5, 2.5)
	
	var tween_rot1 = create_tween()
	tween_rot1.tween_property(self, "target_local_rot:y", 15.0, 8.0).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(8.0).timeout
	print("... Take 1 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 2: CÂMERA NOS PÉS (MAIS BAIXA y=0.12) COM SEGUIMENTO SOLTO (8s)
	# --------------------------------------------------------------------------
	print("Take 2: Câmera nos PÉS (mais baixa, y=0.12) com giro lento (8s)...")
	_switch_to_loose_camera(Vector3(0.35, 0.12, 1.1), Vector3(-5, 10, 0), 4.5, 3.0)
	
	var tween_rot3 = create_tween()
	tween_rot3.tween_property(self, "target_local_rot:y", -8.0, 8.0).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(8.0).timeout
	print("... Take 2 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 3: VISÃO DE FRENTE DESCENDO ATÉ O CHÃO (y=0.15) (8s)
	# --------------------------------------------------------------------------
	print("Take 3: Visão de FRENTE descendo até o nível dos tornozelos (8s)...")
	_switch_to_loose_camera(Vector3(0.0, 2.4, -2.5), Vector3(-10, 180, 0), 4.0, 3.0)
	
	var tween_frente = create_tween().set_parallel(true)
	tween_frente.tween_property(self, "target_local_pos:y", 0.15, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_frente.tween_property(self, "target_local_rot:y", 192.0, 8.0).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(8.0).timeout
	print("... Take 3 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 4: CÂMERA DE COSTAS SOLTA COM ROTAÇÃO LENTA (8s)
	# --------------------------------------------------------------------------
	print("Take 4: Câmera de COSTAS acompanhando com movimento solto (8s)...")
	_switch_to_loose_camera(Vector3(0, 1.8, 3.2), Vector3(-8, 0, 0), 3.5, 2.5)
	
	var tween_rot5 = create_tween()
	tween_rot5.tween_property(self, "target_local_rot:y", 12.0, 8.0).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(8.0).timeout
	print("... Take 4 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 5: PRIMEIRA PESSOA ANDANDO COM BALANÇO SUAVE REDUZIDO (8s)
	# --------------------------------------------------------------------------
	print("Take 5: Primeira pessoa ANDANDO com balanço leve de cabeça (8s)...")
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
	
	await get_tree().create_timer(8.0).timeout
	print("... Take 5 concluído!")
	
	# --------------------------------------------------------------------------
	# TAKE 6: PRIMEIRA PESSOA CORRENDO COM BALANÇO FORTE + SOM CONTINUO + BLUR
	# --------------------------------------------------------------------------
	print("Take 6: Arrancada final com BALANÇO FORTE de corrida, som contínuo e blur...")
	
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
	print("Fim da corrida extrema alcançado!")
	
	# --------------------------------------------------------------------------
	# FADE OUT FINAL E LIMPEZA
	# --------------------------------------------------------------------------
	print("Iniciando Fade Out final...")
	is_head_bob_active = false
	lightning_loop_active = false
	
	var tween_fade = create_tween()
	tween_fade.tween_property(ui_fader, "modulate:a", 1.0, 0.5)
	
	await tween_fade.finished
	
	_parar_som_velocidade()
	if is_instance_valid(rain_audio_player): rain_audio_player.stop()
	if is_instance_valid(old_film_layer): old_film_layer.queue_free()
	if is_instance_valid(motion_blur_layer): motion_blur_layer.queue_free()
	if is_instance_valid(rain_particles): rain_particles.queue_free()
	
	GlobalEvents.in_cutscene = false
	print("--- CUTSCENE TRAILER FINALIZADA ---")

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
