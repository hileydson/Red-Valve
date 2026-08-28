extends Node3D

@export var inicio: Marker3D
@export var fim: Marker3D
@export_group("Take Final - Mao")
@export var hand_start_marker: Marker3D
@export var hand_end_marker: Marker3D
@export var hand_rotation_offset: Vector3 = Vector3.ZERO
@export var hand_position_offset: Vector3 = Vector3.ZERO
var ui_fader: ColorRect
var lightning_flash_rect: ColorRect

# Canvas layers para filtros visuais
var old_film_layer: CanvasLayer = null
var old_film_mat: ShaderMaterial = null
var vhs_layer: CanvasLayer = null
var vhs_mat: ShaderMaterial = null
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
	RenderingServer.set_default_clear_color(Color(0.3, 0.3, 0.3, 1.0))
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

var cutscene_skipped: bool = false
var skip_fade_canvas: CanvasLayer = null

func skip_cutscene() -> void:
	if cutscene_skipped: return
	cutscene_skipped = true
	
	skip_fade_canvas = CanvasLayer.new()
	skip_fade_canvas.layer = 200
	var skip_fade_rect = ColorRect.new()
	skip_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_fade_rect.color = Color(0, 0, 0, 0)
	skip_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_fade_canvas.add_child(skip_fade_rect)
	add_child(skip_fade_canvas)
	
	# Faz o som ir reduzindo aos poucos
	var t = create_tween().set_parallel(true)
	t.tween_property(skip_fade_rect, "color:a", 1.0, 2.0)
	for audio in get_tree().current_scene.find_children("*", "AudioStreamPlayer", true, false):
		t.tween_property(audio, "volume_db", -60.0, 2.0)
	await t.finished
	
	loop_bolas_fogo = false
	lightning_loop_active = false
	if is_instance_valid(rain_audio_player): rain_audio_player.stop()
	if is_instance_valid(old_film_layer): old_film_layer.queue_free()
	if is_instance_valid(motion_blur_layer): motion_blur_layer.queue_free()
	if is_instance_valid(rain_particles): rain_particles.queue_free()
	
	GlobalEvents.in_cutscene = false
	print("--- CUTSCENE TRAILER SKIPPADA COM SUCESSO, INDO PARA MAIN MENU ---")
	get_tree().change_scene_to_file("res://scenes/configs/main_menu_v2.tscn")

func _process(delta: float) -> void:
	if not cutscene_skipped and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_menu_game")):
		skip_cutscene()

	# Trava o the_anti_lopes no local exato do cenário sem descimento
	if is_instance_valid(anti_lopes_ref):
		anti_lopes_ref.global_position = anti_lopes_fixed_pos

	if not is_instance_valid(player_ref) or not is_instance_valid(active_cam):
		return
		
	# Atualiza a posição das partículas de chuva para acompanhar a câmera ativa
	if is_instance_valid(rain_particles):
		rain_particles.global_position = active_cam.global_position + Vector3(0, 8.0, 0)

	# 1. Movimento de câmera solta com assincronia / atraso orgânico (Lerp Damping) e balanço suave de caminhada
	if is_loose_camera_active:
		head_bob_time += delta * 4.5
		var sway_x = cos(head_bob_time) * 0.012
		var sway_y = sin(head_bob_time * 2.0) * 0.012
		var sway_rot_z = cos(head_bob_time) * 0.15
		
		var target_world_trans = player_ref.global_transform * Transform3D(
			Basis.from_euler(Vector3(
				deg_to_rad(target_local_rot.x),
				deg_to_rad(target_local_rot.y),
				deg_to_rad(target_local_rot.z + sway_rot_z)
			)),
			target_local_pos + Vector3(sway_x, sway_y, 0)
		)
		active_cam.global_position = active_cam.global_position.lerp(target_world_trans.origin, delta * cam_follow_speed)
		active_cam.global_basis = active_cam.global_basis.slerp(target_world_trans.basis, delta * cam_rot_speed)

	# 2. Efeito de balanço de cabeça (Head Bob em 1ª pessoa)
	if is_head_bob_active:
		var is_running = (head_bob_intensity > 0.5)
		head_bob_time += delta * (14.0 if is_running else 4.5)
		
		var walking_mult = clamp(head_bob_intensity, 0.05, 1.0)
		var amp_y = 0.08 if is_running else (0.008 * walking_mult)
		var amp_x = 0.05 if is_running else (0.004 * walking_mult)
		var amp_z = 3.0 if is_running else (0.15 * walking_mult)
		
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
		thunder_audio_player.volume_db = -12.0
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
			# Remove as trilhas de escala das animações para evitar que o monstro fique gigante ao dar play
			for anim_name in anim_player.get_animation_list():
				var anim = anim_player.get_animation(anim_name)
				for i in range(anim.get_track_count() - 1, -1, -1):
					if anim.track_get_type(i) == Animation.TYPE_SCALE_3D:
						anim.remove_track(i)
						
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

func _disparar_relampago_longo() -> void:
	if not is_instance_valid(lightning_light): return
	
	# Sequência de relâmpago mais longa e intensa (transição)
	lightning_light.light_energy = 10.0
	lightning_flash_rect.modulate.a = 0.8
	await get_tree().create_timer(0.08).timeout
	
	lightning_light.light_energy = 4.0
	lightning_flash_rect.modulate.a = 0.3
	await get_tree().create_timer(0.06).timeout
	
	lightning_light.light_energy = 12.0
	lightning_flash_rect.modulate.a = 0.95
	await get_tree().create_timer(0.12).timeout
	
	lightning_light.light_energy = 5.0
	lightning_flash_rect.modulate.a = 0.4
	await get_tree().create_timer(0.05).timeout
	
	lightning_light.light_energy = 10.0
	lightning_flash_rect.modulate.a = 0.75
	await get_tree().create_timer(0.18).timeout
	
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
	old_film_layer.layer = -1
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
	
	old_film_mat = ShaderMaterial.new()
	old_film_mat.shader = shader
	film_rect.material = old_film_mat
	old_film_layer.add_child(film_rect)

func _setup_vhs_filter() -> void:
	vhs_layer = CanvasLayer.new()
	vhs_layer.layer = -1
	add_child(vhs_layer)
	
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	vhs_layer.add_child(back_buffer)
	
	var vhs_rect = ColorRect.new()
	vhs_rect.name = "VHSOverlay"
	vhs_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vhs_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader_code: String = """
	shader_type canvas_item;

	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	uniform float smear : hint_range(0.0, 1.0) = 0.8;
	uniform float tracking_noise : hint_range(0.0, 1.0) = 0.15;
	uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.004;

	const mat3 RGB_TO_YIQ = mat3(
		vec3(0.299, 0.587, 0.114),
		vec3(0.5959, -0.2746, -0.3213),
		vec3(0.2115, -0.5227, 0.3112)
	);

	const mat3 YIQ_TO_RGB = mat3(
		vec3(1.0, 0.956, 0.621),
		vec3(1.0, -0.272, -0.647),
		vec3(1.0, -1.106, 1.703)
	);

	float rand(vec2 co) {
		return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
	}

	void fragment() {
		vec2 uv = SCREEN_UV;
		
		float tracking_pos = fract(TIME * 0.1);
		if (abs(uv.y - tracking_pos) < 0.001) {
			uv.x += (rand(uv * TIME) - 0.5) * tracking_noise;
		}
		
		if (rand(vec2(TIME)) > 0.97) {
			uv.y += (rand(vec2(TIME * 2.0)) - 0.5) * 0.008;
		}

		vec3 color;
		color.r = texture(screen_texture, uv + vec2(chromatic_aberration, 0.0)).r;
		color.g = texture(screen_texture, uv).g;
		color.b = texture(screen_texture, uv - vec2(chromatic_aberration, 0.0)).b;
		
		vec3 yiq = RGB_TO_YIQ * color;
		
		float smear_dist = smear * 0.01;
		vec3 yiq_smear1 = RGB_TO_YIQ * texture(screen_texture, uv - vec2(smear_dist, 0.0)).rgb;
		vec3 yiq_smear2 = RGB_TO_YIQ * texture(screen_texture, uv - vec2(smear_dist * 2.0, 0.0)).rgb;
		
		yiq.y = (yiq.y + yiq_smear1.y + yiq_smear2.y) / 3.0;
		yiq.z = (yiq.z + yiq_smear1.z + yiq_smear2.z) / 3.0;
		
		color = YIQ_TO_RGB * yiq;
		
		color -= sin(uv.y * 900.0) * 0.035;
		color -= rand(uv + TIME) * 0.05;
		
		COLOR = vec4(color, 1.0);
	}
	"""
	var shader = Shader.new()
	shader.code = shader_code
	
	vhs_mat = ShaderMaterial.new()
	vhs_mat.shader = shader
	vhs_rect.material = vhs_mat
	vhs_layer.add_child(vhs_rect)

func _setup_motion_blur_filter() -> void:
	motion_blur_layer = CanvasLayer.new()
	motion_blur_layer.layer = -1
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

# ==============================================================================
# LETREIROS "R" e "V" GIGANTES NOS TAKES ESPECÍFICOS
# ==============================================================================
var text_canvas: CanvasLayer
var flash_label: Label

func _setup_trailer_title() -> void:
	text_canvas = CanvasLayer.new()
	text_canvas.layer = 150 # Por cima de tudo
	add_child(text_canvas)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_canvas.add_child(center)
	
	flash_label = Label.new()
	
	var font = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
	if font:
		flash_label.add_theme_font_override("font", font)
		
	flash_label.add_theme_font_size_override("font_size", 900) # AINDA MAIOR
	flash_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	flash_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	flash_label.add_theme_constant_override("outline_size", 8)
	
	flash_label.modulate.a = 0.0 # Começa invisível
	center.add_child(flash_label)

func _start_title_sequence() -> void:
	# MEIO DO TAKE 1 (4.0s de cena)
	await get_tree().create_timer(4.0).timeout
	if not GlobalEvents.in_cutscene: return
	
	_tocar_trovao_e_relampago()
	flash_label.text = "R"
	flash_label.modulate.a = 0.08 # Um pouquinho menos transparente que 0.05
	var t1 = create_tween()
	t1.tween_property(flash_label, "modulate:a", 0.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# TAKE 3 (Cometa) começa aos 14.0s. 
	# Já esperamos 4s, então esperamos mais 11.5s para bater 15.5s (meio do take 3)
	await get_tree().create_timer(11.5).timeout
	if not GlobalEvents.in_cutscene: return
	
	_tocar_trovao_e_relampago()
	flash_label.text = "V"
	flash_label.modulate.a = 0.08 # Um pouquinho menos transparente que 0.05
	var t2 = create_tween()
	t2.tween_property(flash_label, "modulate:a", 0.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _tocar_trovao_e_relampago() -> void:
	if is_instance_valid(thunder_audio_player):
		thunder_audio_player.play()
	_disparar_relampago()


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
	_setup_vhs_filter()
	
	if old_film_layer:
		old_film_layer.visible = false
	if vhs_layer:
		vhs_layer.visible = true
		
	_setup_motion_blur_filter()
	_iniciar_chuva_e_relampagos()
	
	_setup_trailer_title()
	_start_title_sequence()
	
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
	# TAKE 1: CÂMERA DO PLAYER
	# --------------------------------------------------------------------------
	print("Take 1: Câmera terceira pessoa do player (8s)...")

	if is_instance_valid(player):
		player.cutscene_set_camera_current(true)

	await get_tree().create_timer(8.0).timeout
	print("... Take 1 concluído!")

	# Congela o player: a partir daqui ele não é mais controlado, só serve de modelo visual
	# nos takes seguintes. Evita que a física dele (gravidade/queda) continue rodando durante
	# a cutscene e dispare _trigger_fall_death() por sair da malha de colisão.
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)

	# --------------------------------------------------------------------------
	# TAKE 2: PRIMEIRA PESSOA - OLHANDO PARA DIREITA E CIMA (CÉU) (6s)
	# --------------------------------------------------------------------------
	print("Take 2: Primeira pessoa, olhando para direita e para o céu (6s)...")
	_disparar_relampago_longo()
	is_loose_camera_active = false
	if is_instance_valid(active_cam): active_cam.queue_free()
	
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
		if player.global_position.y < inicio.global_position.y:
			player.global_position.y = inicio.global_position.y
		player.apply_floor_snap()
	
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
	
	# Usa a câmera "camera_2" já existente na cena (em vez de criar uma via código) para
	# permitir configurar a mão como filha dela diretamente no editor.
	var cam_fps_walk = get_tree().current_scene.find_child("camera_2", true, false) as Camera3D
	if not is_instance_valid(cam_fps_walk):
		push_warning("camera_2 não encontrada na cena, criando câmera via código como fallback.")
		cam_fps_walk = Camera3D.new()
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
	
	# Parar de spawnar novos cometas a partir do Take 4
	loop_bolas_fogo = false
	
	_iniciar_som_velocidade_continuo()
	_set_motion_blur_strength(0.35)
	
	head_bob_intensity = 1.0
	
	player.cutscene_set_auto_walk(false)
	player.cutscene_set_auto_run(true)
	
	var tempo_sprint = 3.5
	var tween_corrida = create_tween()
	
	# Aproxima-se da porta (recua um pouco na direção do movimento para não colar nela)
	var sprint_dir = player.global_position.direction_to(fim.global_position)
	sprint_dir.y = 0
	sprint_dir = sprint_dir.normalized()
	var sprint_target_pos = fim.global_position - (sprint_dir * 4.8) # Afasta mais um pouco da porta
	
	tween_corrida.tween_property(player, "global_position", sprint_target_pos, tempo_sprint).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	# Toca o som de passos manualmente durante a arrancada: o _physics_process do player está
	# desligado desde o fim do Take 1 (para não cair/morrer na cutscene), então o loop normal
	# de footstep dele (que re-dispara o play() a cada frame de física) não roda mais aqui.
	# "passos.mp3" não é um loop (é um passo único), então precisamos retocá-lo manualmente
	# toda vez que ele terminar, igual o player.gd faria via _physics_process.
	if is_instance_valid(player) and "passos" in player and is_instance_valid(player.passos):
		var footstep_active = true
		# Mesmo pitch/volume que o player.gd usa quando "is_running" está true (corrida)
		var _play_running_footstep: Callable = func():
			player.passos.pitch_scale = randf_range(1.15, 1.3)
			player.passos.volume_db = randf_range(-8.0, -5.0)
			player.passos.play()
		var _resume_footstep: Callable
		_resume_footstep = func():
			if footstep_active and is_instance_valid(player) and is_instance_valid(player.passos):
				_play_running_footstep.call()
		player.passos.finished.connect(_resume_footstep)
		_play_running_footstep.call()
		tween_corrida.finished.connect(func():
			footstep_active = false
			if is_instance_valid(player) and is_instance_valid(player.passos):
				if player.passos.finished.is_connected(_resume_footstep):
					player.passos.finished.disconnect(_resume_footstep)
				player.passos.stop()
		)

	var tween_fov = create_tween()
	tween_fov.tween_property(cam_fps_walk, "fov", 92.0, tempo_sprint).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Toca os nós de som 'AntesFinal' e 'FinalZoom' presentes na cena na aproximação da corrida
	var tween_som_final = create_tween()
	tween_som_final.tween_interval(2.4)
	tween_som_final.tween_callback(func():
		_tocar_sons_simultaneos("AntesFinal", "FinalZoom")
	)
	
	await tween_corrida.finished
	print("Chegou à porta! Iniciando zoom LEVE no portal_red_valve...")
	
	# Desativa corrida e balanço extremo
	player.cutscene_set_auto_run(false)
	player.cutscene_set_auto_walk(false)
	is_head_bob_active = false
	_set_motion_blur_strength(0.0)
	
	# 1. ZOOM MODERADO NA VÁLVULA E ESCURECIMENTO CONFORME SE APROXIMA DA PORTA NO ZOOM
	var target_zoom_fov = 45.0
	var zoom_duration = 4.2 # Esticado para cobrir o fade to black e não parar de avançar
	# A câmera avança até o marcador 'fim' (porta do portal)
	var valve_cam_pos = fim.global_position
	valve_cam_pos.y = cam_fps_walk.global_position.y # Mantém altura exata para não dar solavanco vertical
	
	var tween_zoom_door = create_tween().set_parallel(true)
	tween_zoom_door.tween_property(cam_fps_walk, "fov", target_zoom_fov, zoom_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_zoom_door.tween_property(cam_fps_walk, "global_position", valve_cam_pos, zoom_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_zoom_door.tween_property(cam_fps_walk, "rotation_degrees:z", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Prepara o holofote da câmera que acenderá suavemente focando a porta no final do zoom
	var door_spot = SpotLight3D.new()
	door_spot.spot_range = 14.0
	door_spot.spot_angle = 45.0
	door_spot.light_energy = 0.0
	door_spot.light_color = Color(1.0, 0.95, 0.9)
	cam_fps_walk.add_child(door_spot)

	# Prepara o ambiente para escurecimento na câmera
	var dark_env = Environment.new()
	dark_env.background_mode = Environment.BG_COLOR
	dark_env.background_color = Color.BLACK
	dark_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	dark_env.ambient_light_color = Color.BLACK
	dark_env.ambient_light_energy = 1.0
	cam_fps_walk.environment = dark_env

	# Encontra a porta e todas as luzes da cena para a transição suave de iluminação
	var door_node = get_tree().current_scene.get_node_or_null("portal_red_valve")
	if not door_node:
		door_node = get_tree().current_scene.find_child("portal_red_valve", true, false)

	# ESCURECIMENTO SUAVE DURANTE O ZOOM DA PORTA (EASE_IN: começa discreto e escurece perto do final do zoom)
	var tween_escurecer = create_tween().set_parallel(true)
	tween_escurecer.tween_property(dark_env, "ambient_light_energy", 0.0, zoom_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_escurecer.tween_property(door_spot, "light_energy", 10.0, zoom_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	for light in get_tree().current_scene.find_children("*", "Light3D", true, false):
		if light == door_spot:
			continue
		if door_node and door_node.is_ancestor_of(light):
			continue
		if "light_energy" in light:
			tween_escurecer.tween_property(light, "light_energy", 0.0, zoom_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Quase no final do zoom (quando a cena já está escura), oculta os elementos externos do mapa
	get_tree().create_timer(zoom_duration - 0.3).timeout.connect(func():
		for child in get_tree().current_scene.find_children("*", "Node3D", true, false):
			if door_node and (child == door_node or door_node.is_ancestor_of(child)):
				continue
			if cam_fps_walk and (child == cam_fps_walk or cam_fps_walk.is_ancestor_of(child)):
				continue
			if player_ref and (child == player_ref or player_ref.is_ancestor_of(child)):
				continue
			
			child.visible = false

		if door_node:
			door_node.visible = true
			_set_visible_recursive(door_node, true)
			for sub in door_node.get_children():
				var sname = sub.name.to_lower()
				if "anti_lopes" in sname or "monster" in sname or "goblin" in sname:
					sub.visible = false
					_set_visible_recursive(sub, false)
	)
		
	# A mão aparece enquanto a câmera ainda avança
	
	var player_hand = player_ref.find_child("hand_with_magic", true, false)
	if player_hand:
		var hand_3d = player_hand.duplicate()
		_set_visible_recursive(hand_3d, true)
		
		# Para qualquer AnimationPlayer na mão clonada para que a animação (ex: idle)
		# não puxe a mão de volta para a posição original quando o tween acabar
		hand_3d.set_script(null)
		for anim in hand_3d.find_children("*", "AnimationPlayer", true, false):
			anim.stop()
			anim.active = false
			
		if hand_start_marker and hand_end_marker:
			# Adiciona a mão como filha da própria câmera (camera_2) e mantém a rotação/escala
			# original do modelo (a mesma pose já usada normalmente na primeira pessoa) como base,
			# somando "hand_rotation_offset" (giro extra) e "hand_position_offset" (deslocamento
			# extra), ambos ajustáveis pelo Inspector sem precisar mexer nos markers.
			# Tweena apenas a POSIÇÃO local do marker "inicio_mao" até o "inicio_fim" (indo pra frente).
			cam_fps_walk.add_child(hand_3d)
			hand_3d.position = hand_start_marker.position + hand_position_offset
			hand_3d.rotation_degrees += hand_rotation_offset
			hand_3d.visible = true

			var tween_hand = create_tween()
			tween_hand.tween_property(hand_3d, "position", hand_end_marker.position + hand_position_offset, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			# Fallback caso os marcadores não tenham sido configurados no inspetor
			cam_fps_walk.add_child(hand_3d)
			var target_trans = hand_3d.transform
			target_trans.origin = Vector3(0.0, -0.2, -0.8)
			hand_3d.transform.origin = Vector3(0.0, -0.8, 0.2)
			
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
	player.cutscene_set_auto_walk(false)
	
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
	
	# Desativa o filtro VHS e ativa o filtro de filme velho para o último take
	if vhs_layer:
		vhs_layer.visible = false
	if old_film_layer:
		old_film_layer.visible = true
	
	# 5. REVELAÇÃO DO THE_ANTI_LOPES E ANIMAÇÃO FINAL
	print("Removendo transparência e tocando animação 'final'...")
	
	# Mudar para a camera_final (usando find_child para encontrar em $final/camera_final)
	var cam_final = get_tree().current_scene.find_child("camera_final", true, false) as Camera3D
	if cam_final and cam_final is Camera3D:
		cam_final.make_current()
	else:
		push_warning("camera_final não encontrada na cena.")
		
	# Remover a transparência
	if is_instance_valid(anti_lopes_ref):
		anti_lopes_ref.visible = true
		_apply_transparency_to_node(anti_lopes_ref, 1.0) # Remove a transparência
		
	# Restaurar luzes e visibilidade do Maycow, deletar a mão flutuante do Take 4
	for light in get_tree().current_scene.find_children("*", "Light3D", true, false):
		if "light_energy" in light:
			create_tween().tween_property(light, "light_energy", 1.0, 1.5)
			
	if is_instance_valid(player_ref):
		var maycow_model = player_ref.get_node_or_null("maycow_lopes")
		if maycow_model:
			maycow_model.visible = true
			_set_visible_recursive(maycow_model, true)
			
	if is_instance_valid(cam_fps_walk):
		for child in cam_fps_walk.get_children():
			if "hand" in child.name.to_lower():
				child.queue_free()
	
	var anim_player = get_tree().current_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player and anim_player is AnimationPlayer:
		anim_player.active = true
		if anim_player.has_animation("final"):
			var anim = anim_player.get_animation("final")
			for i in range(anim.get_track_count() - 1, -1, -1):
				var track_path = String(anim.track_get_path(i))
				if "camera_final" in track_path:
					anim.track_set_enabled(i, false)
			anim_player.play("final")
		else:
			push_error("Animação 'final' não encontrada no AnimationPlayer da cena!")
	
	# Reforça make_current logo após disparar a animação
	if is_instance_valid(cam_final):
		cam_final.make_current()

	# Amuleto de poder surge piscando (cinza/transparente) na frente do Maycow durante o take final
	if is_instance_valid(player_ref):
		var amulet_scene = load("res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb")
		if amulet_scene:
			var trailer_amulet = amulet_scene.instantiate()
			player_ref.add_child(trailer_amulet)
			trailer_amulet.scale = Vector3(0.6, 0.6, 0.6)
			trailer_amulet.position = Vector3(0, 1.0, -0.7) # Frente do Maycow, um pouco mais para baixo

			var amulet_mat = StandardMaterial3D.new()
			amulet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			amulet_mat.albedo_color = Color(0.3, 0.3, 0.3, 0.0)
			amulet_mat.emission_enabled = true
			amulet_mat.emission = Color(0.15, 0.15, 0.15)
			for mesh in trailer_amulet.find_children("*", "MeshInstance3D", true, false):
				mesh.material_override = amulet_mat

			_flicker_amulet_effect(amulet_mat, 11.0)

	# Órbita da câmera em volta do modelo 3d do maycow parando de frente para ele
	if is_instance_valid(player_ref) and is_instance_valid(cam_final):
		if "playback" in player_ref:
			player_ref.playback.travel("idle")
			
		# O pivot do jogador costuma ficar no centro (Y=1.0). Para abaixar a câmera, precisamos SUBTRAIR desse valor.
		var target_center = player_ref.global_position + Vector3(0, 0.4, 0) 
		var rel_vec = cam_final.global_position - target_center
		var start_radius = Vector2(rel_vec.x, rel_vec.z).length()
		var end_radius = 1.3 # Zoom bem perto nas costas
		
		var start_angle = atan2(rel_vec.x, rel_vec.z)
		
		# Calcula a direção das COSTAS do Maycow (+Z)
		var back_dir = player_ref.global_transform.basis.z
		var back_angle = atan2(back_dir.x, back_dir.z)
		
		# Pega o caminho mais curto para as costas (gira no máximo 180 graus)
		while back_angle - start_angle > PI:
			back_angle -= TAU
		while back_angle - start_angle < -PI:
			back_angle += TAU
			
		var height_offset = 0.0 
		
		# Gira e dá zoom ao mesmo tempo durante os primeiros 5 segundos, depois para e foca nas costas
		var orbit_duration = 5.0 
		var orbit_tween = create_tween().set_parallel(true)
		orbit_tween.tween_method(func(progress: float):
			if is_instance_valid(cam_final) and is_instance_valid(player_ref):
				var center = player_ref.global_position + Vector3(0, 0.4, 0)
				var current_angle = lerp(start_angle, back_angle, progress)
				var current_radius = lerp(start_radius, end_radius, progress)
				var new_pos = center + Vector3(sin(current_angle) * current_radius, height_offset, cos(current_angle) * current_radius)
				cam_final.global_position = new_pos
				cam_final.look_at(center, Vector3.UP)
		, 0.0, 1.0, orbit_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Faz a tela escura sumir revelando a cena no take final
	var tween_reveal = create_tween()
	tween_reveal.tween_property(ui_fader, "modulate:a", 0.0, 6.0)
	
	await get_tree().create_timer(6.0).timeout
	
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
	
	# Toca os nós de som 'LabelFinal' e 'Glitch' da cena no momento exato em que a frase "RED VALVE" aparece
	_tocar_sons_simultaneos("LabelFinal", "Glitch")
	
	_flicker_title_effect(title_label, 4.5)
	
	# Aguarda a tela final rolar por mais tempo
	await get_tree().create_timer(7.0).timeout
	
	# Fade Out Final Imagem e Áudio
	var tween_final = create_tween().set_parallel(true)
	tween_final.tween_property(ui_fader, "modulate:a", 1.0, 2.5)
	
	for audio in get_tree().current_scene.find_children("*", "AudioStreamPlayer", true, false):
		tween_final.tween_property(audio, "volume_db", -60.0, 2.5)
		
	await tween_final.finished
	
	loop_bolas_fogo = false
	lightning_loop_active = false
	if is_instance_valid(rain_audio_player): rain_audio_player.stop()
	if is_instance_valid(old_film_layer): old_film_layer.queue_free()
	if is_instance_valid(motion_blur_layer): motion_blur_layer.queue_free()
	if is_instance_valid(rain_particles): rain_particles.queue_free()
	
	GlobalEvents.in_cutscene = false
	print("--- CUTSCENE TRAILER FINALIZADA COM SUCESSO, INDO PARA MAIN MENU ---")
	get_tree().change_scene_to_file("res://scenes/configs/main_menu_v2.tscn")

func _criar_bola_de_fogo(start_pos: Vector3, end_pos: Vector3, duration: float) -> void:
	var fireball = Node3D.new()
	add_child(fireball)
	fireball.global_position = start_pos
	
	# Som 1 (Cometa) - 3D Positional Audio grave
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/sounds/episodios/trailer/som_cometa.mp3")
	audio.pitch_scale = randf_range(0.5, 0.7) # Grave
	audio.volume_db = 15.0
	audio.max_db = 15.0
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
	
	# Luz forte na ponta do cometa
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 15.0
	light.omni_range = 50.0
	fireball.add_child(light)
	
	# Particulas de rastro volumoso (menores e menos intensas)
	var parts = CPUParticles3D.new()
	parts.amount = 400
	parts.lifetime = 1.5
	parts.local_coords = false
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 2.0
	parts.gravity = Vector3(0, 5, 0)
	var pmesh = SphereMesh.new()
	pmesh.radius = 1.0
	pmesh.height = 2.0
	var pmat = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.5, 0.1, 0.35) # Menos intensa e mais transparente
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.material = pmat
	parts.mesh = pmesh
	fireball.add_child(parts)
	
	# Partículas de faíscas explosivas (Sparks - menores)
	var sparks = CPUParticles3D.new()
	sparks.amount = 300
	sparks.lifetime = 2.0
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 2.5
	sparks.direction = Vector3(0, -1, 0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 15.0
	sparks.gravity = Vector3(0, -9.8, 0)
	var smesh = SphereMesh.new()
	smesh.radius = 0.2
	smesh.height = 0.4
	var smat = StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.6, 0.1)
	smat.emission_energy_multiplier = 8.0 # Menos intenso
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

func _tocar_sons_simultaneos(val1: String, val2: String, volume_db: float = 0.0) -> void:
	_tocar_som(val1, volume_db)
	_tocar_som(val2, volume_db)

func _tocar_som(val: String, volume_db: float = 0.0) -> void:
	# 1. Tenta buscar pelo nome do nó na cena (ex: "LabelFinal", "Glitch", "AntesFinal", "FinalZoom")
	var sound_node = get_node_or_null(val)
	if not sound_node and get_tree() and get_tree().current_scene:
		sound_node = get_tree().current_scene.find_child(val, true, false)
	
	if sound_node and sound_node.has_method("play"):
		sound_node.play()
		return
		
	# 2. Se não for um nó e sim um caminho "res://...", carrega o stream como fallback
	if val.begins_with("res://"):
		var stream = load(val)
		if stream:
			var p = AudioStreamPlayer.new()
			p.stream = stream
			p.volume_db = volume_db
			add_child(p)
			p.play()
			p.finished.connect(p.queue_free)

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

func _flicker_amulet_effect(mat: StandardMaterial3D, duration: float) -> void:
	if not is_instance_valid(mat): return
	var max_alpha = 0.8
	var elapsed: float = 0.0
	while elapsed < duration:
		if not is_instance_valid(mat): break
		var flicker_factor = 0.0 if randf() < 0.35 else randf_range(0.5, 1.0)
		mat.albedo_color.a = max_alpha * flicker_factor
		var step = randf_range(0.06, 0.18)
		elapsed += step
		await get_tree().create_timer(step).timeout
	if is_instance_valid(mat):
		mat.albedo_color.a = 0.0

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
