extends CharacterBody3D

@onready var camera = $Camera3D # Certifique-se de que sua câmera se chama Camera3D
@onready var camera_third_person: Camera3D =$SpringArm3D/camera_third_person
@onready var camera_third_person_marker: Marker3D = $SpringArm3D/camera_third_person_marker
@onready var camera_first_person_marker: Marker3D = $camera_first_person_marker

@onready var gun_load: AudioStreamPlayer = $sounds/GunLoad
@onready var load_gun: AudioStreamPlayer = $sounds/LoadGun
@onready var gun_shot: AudioStreamPlayer = $sounds/GunShot
@onready var passos: AudioStreamPlayer = $sounds/Passos
@onready var pistola: AnimatedSprite2D = $Camera3D/CanvasLayer/control_weapons/pistola
@onready var faisca: GPUParticles3D = $Camera3D/hand_with_pistol/faisca
@onready var fire: AnimatedSprite3D = $Camera3D/hand_with_pistol/fire
@onready var bullet_light: OmniLight3D = $Camera3D/Camera3D_Bullet_Time/bullet_light
@onready var flash_tela: ColorRect = $Camera3D/CanvasLayer/control_weapons/flash_tela
@onready var ray_cast_3d: RayCast3D = $Camera3D/RayCast3D
@onready var magic_hand: AnimatedSprite2D = $Camera3D/CanvasLayer/control_magic/magic_hand
@onready var hand_magic_3d: Node3D = $Camera3D/hand_with_magic/hand_magic
@onready var hand_magic_tree: AnimationTree = $Camera3D/hand_with_magic/hand_magic/AnimationTree
@onready var magic_hand_particles: GPUParticles3D = $Camera3D/magic_hand_particles
@onready var crescent_cogblade: Node3D = $"Camera3D/Crescent Cogblade"
@onready var blade_in: AudioStreamPlayer3D = $"Camera3D/Crescent Cogblade/blade_in"
@onready var blade_back: AudioStreamPlayer3D = $"Camera3D/Crescent Cogblade/blade_back"
@onready var blade_out: AudioStreamPlayer = $"Camera3D/Crescent Cogblade/BladeOut"
@onready var camera_3d_bullet_time: Camera3D = $Camera3D/Camera3D_Bullet_Time
@onready var control_weapons: Control = $Camera3D/CanvasLayer/control_weapons
@onready var control_magic: Control = $Camera3D/CanvasLayer/control_magic
@onready var bullet: Node3D = $Camera3D/Camera3D_Bullet_Time/bullet
@onready var camera_bullet_time_mark: Marker3D = $Camera3D/camera_bullet_time_mark
@onready var slay_it: AudioStreamPlayer = $sounds/SlayIt
@onready var blade_light: OmniLight3D = $"Camera3D/Crescent Cogblade/blade_light"
@onready var animation_tree: AnimationTree = $maycow_lopes/AnimationTree
@onready var animation_tree_normal: AnimationTree = $maycow_lopes_normal/AnimationTree
@onready var hand_animations: AnimationPlayer = $Camera3D/hand_animations
@onready var point: Label = $Camera3D/point
@onready var camera_top_view: Camera3D = $camera_top_view
@onready var hand_with_pistol: Node3D = $Camera3D/hand_with_pistol
@onready var hand_with_magic: Node3D = $Camera3D/hand_with_magic
@onready var smoke_effect: AnimatedSprite2D = $Camera3D/CanvasLayer/smoke_effect
@onready var smoke_effect_back: AnimatedSprite2D = $Camera3D/CanvasLayer/smoke_effect_back
@onready var dash_effect: AudioStreamPlayer = $sounds/DashEffect
@onready var dash_effect_particles: GPUParticles3D = $dash_effect_particles
@onready var screen_shader: MeshInstance3D = $camera_third_person/screen_shader

var blood_effect = preload("res://scenes/enemies/blood.tscn")
var capsula_scene = preload("res://scenes/effects/capsula.tscn")

# --- PLAYER HEALTH & HUD ---
@export var max_health: int = 100
var current_health: int = 100
var heartbeat_hud: ColorRect
var blood_overlay: ColorRect
var blur_overlay: ColorRect
# STAMINA & MP
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_bar: ProgressBar
var stamina_fade_timer: float = 0.0
var is_exhausted: bool = false
var mp_bar: ProgressBar

var hud_layer: CanvasLayer
var heartbeat_tween: Tween

@export_group("Damage Feedback")
@export var damage_camera_shake_strength: float = 0.003
@export var damage_camera_shake_duration: float = 0.15
# ---------------------------

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003 # Sensibilidade do mouse
@export var WALK_SPEED: float = 4.0
@export var WALK_SPEED_NORMAL: float = 2.8
@export var RUN_SPEED: float = 7.5 # Velocidade maior para a corrida

#CHANGE LATER - DYNAMICLY
@export var damage_crescent_cogblade:int = 20
@export var damage_pistol:int = 10 #3 
@export var damage_headshoot:int = 100
var current_weapon #: AnimatedSprite2D
var can_shoot_again:bool = true
var is_falling_dead: bool = false
var fall_cam: Camera3D = null

var is_toggle_aim_active: bool = false

var clip_pistol_ammo: int = 5
var max_clip_pistol: int = 5
var ammo_label: Label
var ammo_icon: TextureRect

# CONFIGURACAO DO CONTROLE
@export var JOY_SENSITIVITY: float = 0.04 # Sensibilidade para o analógico
@export var DEADZONE: float = 0.1


# Configurações do balanço da tela (Bobbing)
@export var head_bob_ON: bool = true
var bob_freq = 2.0      # Frequência (quão rápido balança)
var bob_amp = 0.05      # Amplitude (quão longe a câmera vai)
var t_bob = 0.0         # Contador de tempo para o cálculo do Seno


# DASH
@export_group("Dash Settings")
@export var DASH_SPEED : float = 30.0    # Velocidade durante o dash
@export var DASH_DURATION : float = 0.2  # Quanto tempo dura (em segundos)
@export var DASH_COOLDOWN : float = 1.0  # Tempo de espera para usar de novo

var is_dashing : bool = false
var dash_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
var dash_direction : Vector3 = Vector3.ZERO
@onready var trail_particles: GPUParticles3D = $trail_particles # Nó de fumaça
@onready var modelo_visual = $maycow_lopes/Armature/Skeleton3D/char1


# HAND ADJUSTMENTS
@export_group("Left Hand Adjustments")
@export var left_hand_idle_offset: Vector3 = Vector3(0.1, -0.35, 0.0)

@export_group("Cogblade Adjustments")
@export var cogblade_tilt_x: float = 0.0 
@export var cogblade_tilt_y: float = 0.0 
@export var cogblade_tilt_z: float = 0.0 

@export_group("Normal Maycow Run Visuals")
@export var normal_run_offset_x: float = -0.1
@export var normal_run_offset_z: float = 0.85
@export var normal_walkback_offset_x: float = -0.05
@export var normal_walkback_offset_z: float = 0.5

#ORIGINAL POSITION FOR THE LEFT HAND
var magic_hand_pos_original
var hand_magic_3d_pos_original: Vector3
var hand_pistol_pos_original: Vector3
var pistol_2d_pos_original: Vector2
var hand_magic_3d_pos_hidden: Vector3
var is_magic_attacking: bool = false
var is_blade_returning: bool = false
var blade_return_speed: float = 15.0
var damage_blur_timer: float = 0.0
var is_reloading: bool = false
var magic_blade_pos_original
var camera_bullet_time_position
var camera_bullet_time_ON = false

var is_first_person = false
var transition_camera = false

var playback 

func _ready():
	$CollisionShape3D.scale = Vector3(1, 1, 1) # Corrigir colisão oval travando nas quinas
		
	hand_pistol_pos_original = hand_with_pistol.position
	pistol_2d_pos_original = pistola.position

	# Captura o mouse e o esconde ao iniciar o jogo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	playback = animation_tree["parameters/playback"]
	
	# a priori sera a pistola... mas precisa ter um change da arma para mudar 
	current_weapon = pistola
	
	magic_hand_pos_original = magic_hand.position
	magic_blade_pos_original = crescent_cogblade.position
	
	# Esconde o sprite 2D antigo
	magic_hand.visible = false
	# Salva a posição original e define a posição de idle deslocada
	hand_magic_3d_pos_original = hand_magic_3d.position
	hand_magic_3d_pos_hidden = hand_magic_3d_pos_original + left_hand_idle_offset
	hand_magic_3d.position = hand_magic_3d_pos_hidden
	#hand_magic_3d.visible = false
	
	# Desativa a física por um breve momento
	set_physics_process(false)
	
	# Espera 2 frames ou um pequeno timer para o terreno carregar
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Reativa a física
	set_physics_process(true)
	
	#setup camera
	camera.current = false
	control_magic.visible = false
	control_weapons.visible = false
	hand_with_pistol.visible = false
	if hand_with_magic: hand_with_magic.visible = false
	camera_third_person.make_current()
	#camera_top_view.make_current()
	point.visible = false
	
	
	
	#check if esta no prologo para carregar modelo correto
	if GlobalEvents.is_maycow_normal:
		playback = animation_tree_normal["parameters/playback"]
		$maycow_lopes.queue_free()
	else:
		$maycow_lopes_normal.queue_free() 
		
	_setup_health_hud()

func _setup_health_hud() -> void:
	current_health = max_health
	
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 100
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var sc = GDScript.new()
	sc.source_code = "extends CanvasLayer
func _process(delta):
	visible = not GlobalEvents.in_cutscene"
	sc.reload()
	hud_layer.set_script(sc)
	add_child(hud_layer)
	
	heartbeat_hud = ColorRect.new()
	heartbeat_hud.anchor_left = 0.0
	heartbeat_hud.anchor_top = 1.0
	heartbeat_hud.anchor_right = 0.0
	heartbeat_hud.anchor_bottom = 1.0
	heartbeat_hud.offset_left = 30
	heartbeat_hud.offset_top = -110
	heartbeat_hud.offset_right = 230
	heartbeat_hud.offset_bottom = -30
	heartbeat_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float speed = 1.0;
uniform float line_thickness = 0.02;

float ekg(float x) {
	x = fract(x); 
	float y = 0.5;
	y += 0.08 * exp(-pow((x - 0.2) * 50.0, 2.0));
	y -= 0.15 * exp(-pow((x - 0.3) * 100.0, 2.0));
	y += 0.45 * exp(-pow((x - 0.35) * 150.0, 2.0));
	y -= 0.20 * exp(-pow((x - 0.4) * 100.0, 2.0));
	y += 0.10 * exp(-pow((x - 0.6) * 30.0, 2.0));
	return y;
}

void fragment() {
	// 2 batimentos por tela, movendo para a esquerda
	float x = UV.x * 2.0 + TIME * speed;
	float target_y = ekg(x);
	
	float dist = abs(UV.y - target_y);
	float glow = line_thickness / (dist + 0.005);
	
	// Fundo totalmente transparente
	vec4 bg = vec4(0.0, 0.0, 0.0, 0.0);
	
	COLOR = mix(bg, vec4(line_color.rgb, 1.0), clamp(glow, 0.0, 1.0) * line_color.a);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	heartbeat_hud.material = mat
	
	hud_layer.add_child(heartbeat_hud)

	# Adicionando BackBufferCopy para garantir captura da tela
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	hud_layer.add_child(back_buffer)

	var blur_overlay = ColorRect.new()
	blur_overlay.name = "MotionBlurOverlay"
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_overlay.visible = false
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
	var blur_mat = ShaderMaterial.new()
	blur_mat.shader = blur_shader
	blur_overlay.material = blur_mat
	hud_layer.add_child(blur_overlay)

	
	blood_overlay = ColorRect.new()
	blood_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blood_shader = Shader.new()
	blood_shader.code = """
shader_type canvas_item;
uniform vec4 color : source_color = vec4(0.8, 0.0, 0.0, 1.0);
uniform float multiplier = 0.0;
uniform float softness = 0.8;

void fragment() {
	float value = distance(UV, vec2(0.5));
	value = smoothstep(0.5 - softness, 0.5, value);
	COLOR = vec4(color.rgb, value * multiplier);
}
"""
	var blood_mat = ShaderMaterial.new()
	blood_mat.shader = blood_shader
	blood_overlay.material = blood_mat
	hud_layer.add_child(blood_overlay)

	# Blur Setup
	

	
	ammo_label = Label.new()
	ammo_label.anchor_left = 1.0
	ammo_label.anchor_top = 1.0
	ammo_label.anchor_right = 1.0
	ammo_label.anchor_bottom = 1.0
	ammo_label.offset_left = -300
	ammo_label.offset_top = -100
	ammo_label.offset_right = -80
	ammo_label.offset_bottom = -30
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ammo_label.add_theme_font_size_override("font_size", 48)
	ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	ammo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	ammo_label.add_theme_constant_override("outline_size", 6)
	hud_layer.add_child(ammo_label)
	
	ammo_icon = TextureRect.new()
	ammo_icon.texture = load("res://assets/images/menu/itens/mostragem_bullets/mostragem_bullets.png")
	ammo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ammo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ammo_icon.anchor_left = 1.0
	ammo_icon.anchor_top = 1.0
	ammo_icon.anchor_right = 1.0
	ammo_icon.anchor_bottom = 1.0
	ammo_icon.offset_left = -70
	ammo_icon.offset_top = -85
	ammo_icon.offset_right = -30
	ammo_icon.offset_bottom = -45
	hud_layer.add_child(ammo_icon)
	
	update_ammo_ui()

	# MP Bar
	mp_bar = ProgressBar.new()
	mp_bar.anchor_left = 0.5
	mp_bar.anchor_top = 1.0
	mp_bar.anchor_right = 0.5
	mp_bar.anchor_bottom = 1.0
	mp_bar.offset_left = -100
	mp_bar.offset_top = -35
	mp_bar.offset_right = 100
	mp_bar.offset_bottom = -25
	mp_bar.show_percentage = false
	var mp_sb = StyleBoxFlat.new()
	mp_sb.bg_color = Color(0.2, 0.4, 0.9, 0.8)
	mp_sb.corner_radius_top_left = 4
	mp_sb.corner_radius_top_right = 4
	mp_sb.corner_radius_bottom_left = 4
	mp_sb.corner_radius_bottom_right = 4
	mp_bar.add_theme_stylebox_override("fill", mp_sb)
	var mp_bg = StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	mp_bg.corner_radius_top_left = 4
	mp_bg.corner_radius_top_right = 4
	mp_bg.corner_radius_bottom_left = 4
	mp_bg.corner_radius_bottom_right = 4
	mp_bar.add_theme_stylebox_override("background", mp_bg)
	hud_layer.add_child(mp_bar)

	# Stamina Bar
	stamina_bar = ProgressBar.new()
	stamina_bar.anchor_left = 0.5
	stamina_bar.anchor_top = 1.0
	stamina_bar.anchor_right = 0.5
	stamina_bar.anchor_bottom = 1.0
	stamina_bar.offset_left = -150
	stamina_bar.offset_top = -50
	stamina_bar.offset_right = 150
	stamina_bar.offset_bottom = -40
	stamina_bar.show_percentage = false
	var st_sb = StyleBoxFlat.new()
	st_sb.bg_color = Color(0.9, 0.9, 0.9, 0.7)
	st_sb.corner_radius_top_left = 2
	st_sb.corner_radius_top_right = 2
	st_sb.corner_radius_bottom_left = 2
	st_sb.corner_radius_bottom_right = 2
	stamina_bar.add_theme_stylebox_override("fill", st_sb)
	var st_bg = StyleBoxFlat.new()
	st_bg.bg_color = Color(0.1, 0.1, 0.1, 0.3)
	st_bg.corner_radius_top_left = 2
	st_bg.corner_radius_top_right = 2
	st_bg.corner_radius_bottom_left = 2
	st_bg.corner_radius_bottom_right = 2
	stamina_bar.add_theme_stylebox_override("background", st_bg)
	hud_layer.add_child(stamina_bar)
	
	_start_heartbeat_pulse()

func update_ammo_ui() -> void:
	if not is_instance_valid(ammo_label): return
	
	var is_pistol_equipped = SaveManager.is_equipped("pistol")
	
	if GlobalEvents.is_maycow_normal or not is_pistol_equipped:
		ammo_label.visible = false
		if is_instance_valid(ammo_icon): ammo_icon.visible = false
	else:
		ammo_label.visible = true
		if is_instance_valid(ammo_icon): ammo_icon.visible = true
		var total = SaveManager.get_item_amount("pistol_ammo")
		ammo_label.text = str(clip_pistol_ammo) + " / " + str(total)

func _start_heartbeat_pulse() -> void:
	if current_health <= 0:
		heartbeat_hud.visible = false
		return
		
	if heartbeat_tween:
		heartbeat_tween.kill()
		
	heartbeat_tween = create_tween().set_parallel(true)
	
	var target_speed = 1.0
	var target_color = Color(0, 1, 0, 1.0) # Verde
	
	if current_health < 30:
		target_color = Color(1, 0, 0, 1.0) # Vermelho
		target_speed = 2.8
	elif current_health < 70:
		target_color = Color(1, 1, 0, 1.0) # Amarelo
		target_speed = 2.0
		
	var mat = heartbeat_hud.material as ShaderMaterial
	if not mat: return
	
	var current_color = mat.get_shader_parameter("line_color")
	if current_color == null: current_color = Color(0, 1, 0, 1.0)
	
	var current_speed = mat.get_shader_parameter("speed")
	if current_speed == null: current_speed = 1.0
	
	# Transição suave de cor e velocidade do ECG
	heartbeat_tween.tween_method(func(val): mat.set_shader_parameter("line_color", val), current_color, target_color, 0.5)
	heartbeat_tween.tween_method(func(val): mat.set_shader_parameter("speed", val), current_speed, target_speed, 0.5) 
	

func _input(event):
	if camera_bullet_time_ON:
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Aplica a rotação horizontal no corpo (Maycow)
		rotate_y(-event.relative.x * SENSITIVITY)
		
		# Aplica a rotação vertical na câmera atual
		var camera_atual = get_viewport().get_camera_3d()
		camera_atual.rotate_x(-event.relative.y * SENSITIVITY)
		
		# Trava o ângulo vertical
		var v_down = -10 if camera_atual == camera_third_person else -80
		var v_up = 20 if camera_atual == camera_third_person else 80
		camera_atual.rotation.x = clamp(camera_atual.rotation.x, deg_to_rad(v_down), deg_to_rad(v_up))


# Adicione estas variáveis no topo do script (fora do _process) se ainda não tiver
var hold_timer: float = 0.0
var hold_threshold: float = 0.15 # 200 milisegundos para confirmar o "segurar"
var limite_rotacao_lateral = deg_to_rad(15) # O máximo que ele pode "virar" (ex: 35 graus)
var velocidade_giro = 4.0
func _physics_process(delta: float) -> void:

	var is_in_house = get_tree().current_scene.name == "the_house" if get_tree() and get_tree().current_scene else false
	var can_run_normal = GlobalEvents.is_maycow_normal and not is_in_house
	var stamina_active = not GlobalEvents.is_maycow_normal or can_run_normal
	
	# --- STAMINA EXHAUSTION LOGIC ---
	if current_stamina <= 0.5:
		is_exhausted = true
	elif current_stamina >= 25.0:
		is_exhausted = false
		
	# --- STAMINA LOGIC ---
	var is_running_stam = Input.is_action_pressed("ui_run") and velocity.length() > 0.1 and current_stamina > 0 and stamina_active and not is_exhausted
	if is_running_stam:
		current_stamina -= 20.0 * delta
		if current_stamina < 0: current_stamina = 0
		stamina_fade_timer = 2.0
		if is_instance_valid(stamina_bar): stamina_bar.modulate.a = 1.0
	else:
		if current_stamina < max_stamina:
			current_stamina += 15.0 * delta
			if current_stamina > max_stamina: current_stamina = max_stamina
			stamina_fade_timer = 2.0
			if is_instance_valid(stamina_bar): stamina_bar.modulate.a = 1.0
		else:
			if stamina_fade_timer > 0:
				stamina_fade_timer -= delta
			else:
				if is_instance_valid(stamina_bar):
					stamina_bar.modulate.a = move_toward(stamina_bar.modulate.a, 0.0, delta)
	
	if is_instance_valid(stamina_bar):
		stamina_bar.visible = stamina_active
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
		
	if is_instance_valid(mp_bar):
		mp_bar.visible = not GlobalEvents.is_maycow_normal
		mp_bar.max_value = SaveManager.max_mp
		mp_bar.value = SaveManager.current_mp
	# ---------------------

	if is_instance_valid(blood_overlay):
		blood_overlay.visible = not GlobalEvents.in_cutscene
	if is_instance_valid(heartbeat_hud):
		heartbeat_hud.visible = not GlobalEvents.in_cutscene
	
	if is_instance_valid(fall_cam):
		fall_cam.look_at(global_position, Vector3.UP)
		
	if global_position.y < -10.0 and current_health > 0 and not is_falling_dead:
		_trigger_fall_death()
		
	#somente poder executar ações do jogo se nao for prologo
	if !GlobalEvents.is_maycow_normal:
	
		# 1. LÓGICA DE VISÃO (PRIMEIRA/TERCEIRA PESSOA)
		var holding_view = false
		
		if SaveManager.config["aim_mode"] == "toggle":
			if Input.is_action_just_pressed("ui_hold_first_person_view"):
				is_toggle_aim_active = !is_toggle_aim_active
			holding_view = is_toggle_aim_active
			hold_timer = 0.0 # Reseta o timer pra não conflitar
		else:
			if Input.is_action_pressed("ui_hold_first_person_view"):
				hold_timer += delta
			else:
				hold_timer = 0.0
			holding_view = hold_timer >= hold_threshold

		if holding_view and !is_first_person:
			is_first_person = true
			transicao_camera(camera_third_person, camera, camera_first_person_marker, true)
		elif !holding_view and is_first_person:
			is_first_person = false
			transicao_camera(camera, camera_third_person, camera_third_person_marker, false)
			
		point.visible = is_first_person
		
		# 3. GRAVIDADE
		if not is_on_floor():
			velocity += get_gravity() * delta

		# 4. PULO E RECARGA
		if Input.is_action_just_pressed("ui_accept") and is_on_floor() and !holding_view:
			velocity.y = JUMP_VELOCITY
			playback.travel("jump")
			
		if Input.is_action_just_pressed("ui_reload") and !transition_camera and !is_magic_attacking:
			reload()
		
		if Input.is_action_just_pressed("ui_shoot") and !transition_camera and !is_magic_attacking:
			shoot(Input)
		
		if !is_magic_attacking and Input.is_action_just_pressed("ui_magic_attack") and !transition_camera and camera.current and SaveManager.current_mp >= 10.0:
			magic_hand_attack()
			
		if camera_bullet_time_ON:
			return
			
		# 5. ROTAÇÃO DA CÂMERA (ANALÓGICO DIREITO)
		if !camera_bullet_time_ON:
			var joy_dir = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
			if joy_dir.length() > DEADZONE:
				var camera_atual = get_viewport().get_camera_3d()
				
				# Girar o corpo (Horizontal) - multiplicado por delta para suavidade
				rotate_y(-joy_dir.x * JOY_SENSITIVITY * delta * 100)
				
				# Girar a câmera (Vertical)
				camera_atual.rotate_x(-joy_dir.y * JOY_SENSITIVITY * delta * 100)
				
				# Trava o ângulo vertical (mesma lógica do mouse)
				var v_down = -10 if camera_atual == camera_third_person else -80
				var v_up = 20 if camera_atual == camera_third_person else 80
				camera_atual.rotation.x = clamp(camera_atual.rotation.x, deg_to_rad(v_down), deg_to_rad(v_up))
	
		# 6. GESTÃO DO DASH (COOLDOWN E EXECUÇÃO)
		if dash_cooldown_timer > 0:
			dash_cooldown_timer -= delta

		if Input.is_action_just_pressed("ui_dash") and not is_dashing and dash_cooldown_timer <= 0 and current_stamina >= 30.0:
			current_stamina -= 30.0
			stamina_fade_timer = 2.0
			stamina_bar.modulate.a = 1.0
			dash()
			

		# 7. MOVIMENTAÇÃO (DASH VS CAMINHADA)
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# No seu item 7 do _physics_process:
		if is_dashing:
			# MOVIMENTO DE DASH
			velocity.x = dash_direction.x * DASH_SPEED
			velocity.z = dash_direction.z * DASH_SPEED
			
			dash_timer -= delta
			if dash_timer <= 0:
				is_dashing = false
		else:
			# MOVIMENTO NORMAL (WALK/RUN)
			var velocidade_atual = RUN_SPEED if (Input.is_action_pressed("ui_run") and current_stamina > 0 and not is_exhausted) else WALK_SPEED
			var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var velocity_Y_zero: bool = velocity.y <= 0

			if direction and !transition_camera:
				# Animações e Sons
				if Input.is_action_pressed("ui_run"):
					if pistola.animation not in ["reload", "run"]: pistola.play("run")
					if is_on_floor() and velocity_Y_zero: playback.travel("run")
				else:
					if pistola.animation not in ["reload", "walk"]: pistola.play("walk")
					if is_on_floor() and velocity_Y_zero: playback.travel("walk")
				
				if !passos.playing and is_on_floor():
					if Input.is_action_pressed("ui_run"):
						passos.pitch_scale = randf_range(1.15, 1.3)
						passos.volume_db = randf_range(-8.0, -5.0)
					else:
						passos.pitch_scale = randf_range(0.65, 0.75)
						passos.volume_db = randf_range(-11.0, -8.0)
					passos.play()
				
				velocity.x = direction.x * velocidade_atual
				velocity.z = direction.z * velocidade_atual
			else:
				# IDLE / PARADA
				if is_on_floor() and velocity_Y_zero: playback.travel("idle")
				velocity.x = move_toward(velocity.x, 0, velocidade_atual)
				velocity.z = move_toward(velocity.z, 0, velocidade_atual)
				if passos.playing: passos.stop()
		
		# FX DURANTE CORRIDA (FOV e Blur leve)
		var camera = get_viewport().get_camera_3d()
		if camera and not is_dashing:
			var is_running = Input.is_action_pressed("ui_run") and velocity.length() > 0.1 and current_stamina > 0 and not is_exhausted and not is_exhausted
			var target_run_fov = 95.0 if is_running else 75.0
			camera.fov = lerp(camera.fov, target_run_fov, 5.0 * delta)
			


		# 8. ROTAÇÃO VISUAL DO MODELO (MAYCOW LOPES)
		if input_dir.y <= 0.1: 
			var alvo_y = PI 
			if input_dir.x > 0: alvo_y = PI - limite_rotacao_lateral 
			elif input_dir.x < 0: alvo_y = PI + limite_rotacao_lateral 

			var modelo = get_node_or_null("maycow_lopes")
			if modelo:
				modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_y, delta * velocidade_giro)
		
	# DAQUI PRA FRENTE É O MAYCOW SEM PODERES 	
	else:
		
		# 3. GRAVIDADE
		if not is_on_floor():
			velocity += get_gravity() * delta

		# 5. ROTAÇÃO DA CÂMERA (ANALÓGICO DIREITO)
		if !camera_bullet_time_ON:
			var joy_dir = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
			if joy_dir.length() > DEADZONE:
				var camera_atual = get_viewport().get_camera_3d()
				
				# Girar o corpo (Horizontal) - multiplicado por delta para suavidade
				rotate_y(-joy_dir.x * JOY_SENSITIVITY * delta * 100)
				
				# Girar a câmera (Vertical)
				camera_atual.rotate_x(-joy_dir.y * JOY_SENSITIVITY * delta * 100)
				
				# Trava o ângulo vertical (mesma lógica do mouse)
				var v_down = -10 if camera_atual == camera_third_person else -80
				var v_up = 20 if camera_atual == camera_third_person else 80
				camera_atual.rotation.x = clamp(camera_atual.rotation.x, deg_to_rad(v_down), deg_to_rad(v_up))
			

		# 7. MOVIMENTAÇÃO (DASH VS CAMINHADA)
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# MOVIMENTO NORMAL (WALK/RUN)
		var is_running = Input.is_action_pressed("ui_run") and current_stamina > 0 and can_run_normal and not is_exhausted
		var velocidade_atual = RUN_SPEED if is_running else WALK_SPEED_NORMAL
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var velocity_Y_zero: bool = velocity.y <= 0
		var target_fov: float = 75.0

		if direction:
			var visao_frente = -global_transform.basis.z
			var alinhamento = direction.dot(visao_frente)
			
			if is_on_floor():
				# Calcula se a direção do movimento é paralela ou oposta à frente do personagem
				if alinhamento < -0.2:
					# Movimento para trás
					playback.travel("walk_back")
					target_fov = 65.0
				else:
					# Movimento para frente ou corrida
					if is_running:
						playback.travel("run")
						target_fov = 95.0
					else:
						playback.travel("walk")
			
			if !passos.playing and is_on_floor(): 
				if alinhamento < -0.2:
					passos.pitch_scale = randf_range(0.95, 1.05)
					passos.volume_db = randf_range(-11.0, -8.0)
				elif is_running:
					passos.pitch_scale = randf_range(1.15, 1.3)
					passos.volume_db = randf_range(-8.0, -5.0)
				else:
					passos.pitch_scale = randf_range(0.85, 0.95)
					passos.volume_db = randf_range(-11.0, -8.0)
				passos.play()
			
			velocity.x = direction.x * velocidade_atual
			velocity.z = direction.z * velocidade_atual
		else:
			# IDLE / PARADA
			if is_on_floor(): 
				playback.travel("idle")
			velocity.x = move_toward(velocity.x, 0, velocidade_atual)
			velocity.z = move_toward(velocity.z, 0, velocidade_atual)
			if passos.playing: 
				passos.stop()

		var fov_lerp_speed = 1.0 if target_fov == 65.0 else 5.0
		var camera = get_viewport().get_camera_3d()
		if camera:
			camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)


		# 8. ROTAÇÃO VISUAL E POSIÇÃO DO MODELO (MAYCOW LOPES NORMAL)
		var modelo = get_node_or_null("maycow_lopes_normal")
		if modelo:
			var alvo_y = 0.0
			if input_dir.y <= 0.1: 
				if input_dir.x > 0: alvo_y = -limite_rotacao_lateral 
				elif input_dir.x < 0: alvo_y = limite_rotacao_lateral 
			modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_y, delta * velocidade_giro)
			
			var is_walking_back = direction and direction.dot(-global_transform.basis.z) < -0.2
			var target_pos_x = 0.0
			var target_pos_z = 0.3995
			if is_running:
				target_pos_x = normal_run_offset_x
				target_pos_z = normal_run_offset_z
			elif is_walking_back:
				target_pos_x = normal_walkback_offset_x
				target_pos_z = normal_walkback_offset_z
			modelo.position.x = lerp(modelo.position.x, target_pos_x, 5.0 * delta)
			modelo.position.z = lerp(modelo.position.z, target_pos_z, 5.0 * delta)

		# Inclinação e Encolhimento da arma 2D ao correr
		if is_instance_valid(pistola) and typeof(pistol_2d_pos_original) == TYPE_VECTOR2:
			is_running = Input.is_action_pressed("ui_run") and velocity.length() > 0.1 and current_stamina > 0 and not is_exhausted
			# Rotação 2D (positivo = horário = descer ponta da arma) e empurrar para baixo/fora da tela
			var target_tilt = deg_to_rad(35.0) if is_running else 0.0
			var target_pos = pistol_2d_pos_original + (Vector2(50.0, 150.0) if is_running else Vector2.ZERO)
			
			pistola.rotation = lerp(pistola.rotation, target_tilt, 12.0 * delta)
			pistola.position = pistola.position.lerp(target_pos, 12.0 * delta)

	# 9. FINALIZAÇÃO
	move_and_slide()

	if head_bob_ON:
		head_bob(delta) # Lembre-se de incluir a vibração dentro da sua função head_bob!


	# GIRO DA COGBLADE
	if is_instance_valid(crescent_cogblade) and crescent_cogblade.top_level:
		# Usa o eixo Global Y para girar, assim a angulação do Inspector (Pitch) é preservada
		# e a lâmina gira como um frisbee independentemente de quão tombada estiver
		crescent_cogblade.global_rotate(Vector3.UP, -15.0 * delta)

	# LÓGICA DO BUMERANGUE (COGBLADE RETORNANDO)
	if is_blade_returning and is_instance_valid(crescent_cogblade):
		# Alvo dinâmico é a mão do jogador atualizada em tempo real
		var target_pos = camera.global_transform.origin + camera.global_transform.basis * magic_blade_pos_original
		crescent_cogblade.global_transform.origin = crescent_cogblade.global_transform.origin.move_toward(target_pos, delta * blade_return_speed)
		
		if crescent_cogblade.global_transform.origin.distance_to(target_pos) < 0.8:
			is_blade_returning = false
			crescent_cogblade.top_level = false
			crescent_cogblade.position = magic_blade_pos_original
			crescent_cogblade.rotation = Vector3.ZERO # Reseta a rotação para ficar reta na mão
			crescent_cogblade.hide()
			
			var bb = crescent_cogblade.get_node_or_null("blade_back")
			if bb: bb.play()
			
			var faiscas = crescent_cogblade.get_node_or_null("Faiscas")
			if faiscas: faiscas.emitting = false
			
			is_magic_attacking = false
			if hand_magic_tree:
				var pb = hand_magic_tree["parameters/playback"]
				if pb: pb.travel("idle")
				
			# Mão volta para o Idle lentamente (Cooldown visual)
			var tween_hand = create_tween()
			tween_hand.tween_interval(0.2)
			tween_hand.tween_property(hand_magic_3d, "position", hand_magic_3d_pos_hidden, 1.5).set_trans(Tween.TRANS_SINE)

func dash():
	
	var tween = create_tween()
		# Ativa o rastro de fumaça
	if trail_particles:
		trail_particles.emitting = true
		
	if !is_first_person:
		smoke_effect.process_mode = Node.PROCESS_MODE_ALWAYS
		smoke_effect.speed_scale = 1.0 / 0.2 # Substitua 0.2 pelo valor da sua camera lenta
		smoke_effect.play("smoke")
		smoke_effect_back.process_mode = Node.PROCESS_MODE_ALWAYS
		smoke_effect_back.speed_scale = 1.0 / 0.2 # Substitua 0.2 pelo valor da sua camera lenta
		smoke_effect_back.play("smoke")	
		
	dash_effect.process_mode = Node.PROCESS_MODE_ALWAYS
	dash_effect.pitch_scale = 0.4
	dash_effect.play()
	
	# Efeito Global de Câmera Lenta no Áudio
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var target_bus = sfx_bus if sfx_bus != -1 else 0 # Usa Master se SFX não existir
	
	# Adiciona pitch shift dinamicamente se não existir
	var has_pitch = false
	var effect_idx = -1
	for i in range(AudioServer.get_bus_effect_count(target_bus)):
		if AudioServer.get_bus_effect(target_bus, i) is AudioEffectPitchShift:
			has_pitch = true
			effect_idx = i
			break
			
	if not has_pitch:
		var pitch_effect = AudioEffectPitchShift.new()
		AudioServer.add_bus_effect(target_bus, pitch_effect)
		effect_idx = AudioServer.get_bus_effect_count(target_bus) - 1
		
	var effect = AudioServer.get_bus_effect(target_bus, effect_idx) as AudioEffectPitchShift
	
	var audio_tween = create_tween().set_parallel(true)
	audio_tween.tween_property(effect, "pitch_scale", 0.4, 0.1)
	audio_tween.chain().tween_property(effect, "pitch_scale", 1.0, DASH_DURATION)
	
	dash_effect_particles.emitting = true

	# --- 1. SUA LÓGICA DE FÍSICA E DIREÇÃO JÁ EXISTENTE ---
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction == Vector3.ZERO:
		direction = -transform.basis.z # Dash para frente se parado
	
	dash_direction = direction

	var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
	if motion_blur:
		motion_blur.visible = true
		motion_blur.material.set_shader_parameter("blur_strength", 1.0)
		var tween_blur = create_tween().set_parallel(true)
		tween_blur.tween_property(motion_blur.material, "shader_parameter/blur_strength", 0.0, DASH_DURATION)
		tween_blur.chain().tween_callback(func(): motion_blur.visible = false)
		
		# FOV Punch (Sensação de velocidade extra)
		var camera = get_viewport().get_camera_3d()
		if camera:
			var base_fov = camera.fov
			tween_blur.tween_property(camera, "fov", base_fov + 15.0, DASH_DURATION * 0.3).set_trans(Tween.TRANS_SINE)
			tween_blur.tween_property(camera, "fov", base_fov, DASH_DURATION * 0.7).set_delay(DASH_DURATION * 0.3).set_trans(Tween.TRANS_SINE)
		
	is_dashing = true
	dash_timer = DASH_DURATION # Use o tempo que você já tem
	dash_cooldown_timer = DASH_COOLDOWN

	# --- 2. EFEITO DE ENCOLHER (SQUASH) ---
	if modelo_visual:
		var tween_scale = create_tween()
		
		# Faz o Tween ignorar a câmera lenta para ser instantâneo no seu controle
		tween_scale.set_speed_scale(1.0 / 0.2) 
		
		# ENCOLHER: Vai para escala zero em 0.1 segundos
		# Usamos TRANS_BACK para dar um efeito de "mola" ao sumir, se desejar
		var shrink = tween_scale.tween_property(modelo_visual, "scale", Vector3(0, 0, 0), 0.17)
		if shrink: shrink.set_trans(Tween.TRANS_SINE)
		
		# ESPERA: O tempo que você determinou para o Dash
		tween_scale.tween_interval(DASH_DURATION)
		
		# DESENCOLHER: Volta para a escala normal (1, 1, 1)
		var grow = tween_scale.tween_property(modelo_visual, "scale", Vector3(1, 1, 1), 0.17)
		if grow: grow.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		
	# Ativa o rastro de fumaça
	if trail_particles:
		trail_particles.emitting = true

	
	# --- 3. SEUS EFEITOS DE VIBRAÇÃO E CAMERA LENTA ---
	GlobalUtils.vibrate_controller(Input, 0.5, 0.2, 0.1)
	GlobalUtils.ativar_camera_lenta_com_fim(0.2, 1.0, false)
	

func head_bob(delta: float):
	t_bob += delta * velocity.length() * float(is_on_floor())
	
	var cam_atual: Camera3D
	var marker_referencia: Marker3D # Precisamos saber onde a câmera DEVERIA estar
	
	if is_first_person:
		cam_atual = camera
		marker_referencia = camera_first_person_marker
	else:
		cam_atual = camera_third_person
		marker_referencia = camera_third_person_marker
	
	var ajuste_intensidade = 0.8
	if Input.is_action_pressed("ui_run"):
		bob_freq = 2.1
		
		if is_first_person:
			ajuste_intensidade = 1.0
			bob_freq = 4.5
	else:
		bob_freq = 2.0 # Voltei para 2.0 porque 1.0 é muito lento

	var pos_bob = Vector3.ZERO
	if is_on_floor() and velocity.length() > 0.1:
		pos_bob.y = sin(t_bob * bob_freq) * bob_amp * ajuste_intensidade
		pos_bob.x = cos(t_bob * bob_freq * 0.5) * bob_amp * 0.5 * ajuste_intensidade
	
	# O SEGREDO: A posição da câmera deve ser a posição do MARKER + o balanço
	# Se não estiver em transição, mantemos a câmera colada no marker com o balanço
	if !transition_camera:
		cam_atual.global_transform.origin = marker_referencia.global_transform.origin + pos_bob
	

# Função auxiliar para não repetir código
func transicao_camera(origem: Camera3D, camera_destino: Camera3D, destino: Marker3D, show_ui: bool):
	transition_camera = true
	#COLOCA CADA CAMERA NO SEU LUGAR ANTES DE PROCESSAR
	camera.global_transform = camera_first_person_marker.global_transform
	camera_third_person.global_transform = camera_third_person_marker.global_transform
	
	# Mostra/Esconde a UI rapido pra nao ficar estranho se for pra esconder a arma
	if camera_destino == camera_third_person:
		control_magic.visible = show_ui
		control_weapons.visible = show_ui
		hand_with_pistol.visible = show_ui and SaveManager.is_equipped("pistol")
		if hand_with_magic: hand_with_magic.visible = show_ui
		await get_tree().create_timer(0.1).timeout
		GlobalUtils.remover_camera_lenta()
	else:
		load_gun.play()
		

	# IMPORTANTE: Garante que a câmera que vai "viajar" seja a atual
	origem.make_current()

	var tween = create_tween()
	# Fazemos a câmera que está ativa (origem) viajar até o lugar da outra (destino)
	tween.tween_property(origem, "global_transform", destino.global_transform, 0.15)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)

	# Quando o movimento acabar, garantimos que o foco mude oficialmente para a câmera de destino
	tween.finished.connect(func(): 
		if !camera_bullet_time_ON:
			camera_destino.make_current()
		
		transition_camera = false
		# FAZER A ARMA VIM SURGINDO DE BAIXO PRA CIMA DEPOIS
		# TODO: FAZER
		# Mostra/Esconde a UI com delay pra nao ficar estranho
		control_magic.visible = show_ui
		control_weapons.visible = show_ui
		hand_with_pistol.visible = show_ui and SaveManager.is_equipped("pistol")
		if hand_with_magic: hand_with_magic.visible = show_ui
		)
	
	
	
	
func reload():
	if is_first_person and not is_reloading and not is_magic_attacking:
		var total = SaveManager.get_item_amount("pistol_ammo")
		if total <= 0 or clip_pistol_ammo >= max_clip_pistol:
			return
			
		is_reloading = true
		
		var needed = max_clip_pistol - clip_pistol_ammo
		var taken = mini(needed, total)
		SaveManager.remove_item_amount("pistol_ammo", taken)
		clip_pistol_ammo += taken
		update_ammo_ui()
		
		if not is_instance_valid(current_weapon): 
			is_reloading = false
			return

		gun_load.play()
		
		# Coloca a mão na posição original para animação
		if is_instance_valid(hand_magic_3d): 
			hand_magic_3d.position = hand_magic_3d_pos_original
			hand_magic_3d.visible = true
			
		if hand_magic_tree:
			var pb = hand_magic_tree["parameters/playback"]
			if pb: pb.travel("magic_reload")
		
		if hand_animations:
			hand_animations.play("reload")
			await hand_animations.animation_finished
		else:
			await get_tree().create_timer(1.0).timeout
			
		# Atraso extra para a animação da mão mágica terminar com folga
		await get_tree().create_timer(0.8).timeout
			
		# Retorna para a posição de idle escondida lentamente e suave
		if is_instance_valid(hand_magic_3d): 
			var tween_retorno = create_tween()
			tween_retorno.tween_property(hand_magic_3d, "position", hand_magic_3d_pos_hidden, 0.6).set_trans(Tween.TRANS_SINE)
			
		is_reloading = false

func magic_hand_attack():
	SaveManager.current_mp -= 10.0
	if SaveManager.current_mp < 0: SaveManager.current_mp = 0
	if is_reloading: return
	
	# 1. ANIMAÇÃO DA MÃO (3D)
	is_magic_attacking = true
	slay_it.play()
	blade_out.play()
	
	if hand_magic_tree:
		var pb = hand_magic_tree["parameters/playback"]
		if pb: pb.travel("attack")
		
	var tween_magic = create_tween().set_parallel(true)
	
	# Mão vai para frente (recuada levemente para não invadir tanto a tela)
	var pos_alvo = hand_magic_3d_pos_original + Vector3(0, 0, 0.1)
	hand_magic_3d.visible = true
	tween_magic.tween_property(hand_magic_3d, "position", pos_alvo, 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	# 2. LANÇA A CRESCENT COGBLADE (GLOBAL)
	crescent_cogblade.show()
	crescent_cogblade.top_level = true # Desprende da câmera fisicamente
	
	var faiscas = crescent_cogblade.get_node_or_null("Faiscas") 
	if faiscas: faiscas.emitting = true
	
	# Força a lâmina a deitar usando a inclinação customizada no Inspector
	# e aponta ela para a mesma direção que o jogador está olhando
	crescent_cogblade.global_rotation_degrees = Vector3(cogblade_tilt_x, camera.global_rotation_degrees.y + cogblade_tilt_y, cogblade_tilt_z)
	
	# Ponto final no espaço global (frente de onde o jogador está olhando)
	var dir = -camera.global_transform.basis.z
	var pos_final_global = crescent_cogblade.global_transform.origin + (dir * 11.0) # Distância intermediária
	
	# Tween de ida (Global) - BEM mais lento
	tween_magic.tween_property(crescent_cogblade, "global_transform:origin", pos_final_global, 1.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Giro é controlado no _physics_process agora (para evitar problemas de interpolação de Euler)
	
	await tween_magic.finished
	
	# Inicia a fase de retorno bumerangue
	is_blade_returning = true
	
	# Mão puxa (recuo) avisando que está puxando a lâmina de volta
	var tween_hand = create_tween()
	var pos_recuo = hand_magic_3d_pos_original + Vector3(0.0, -0.4, 0.6)
	tween_hand.tween_property(hand_magic_3d, "position", pos_recuo, 0.5)\
		.set_trans(Tween.TRANS_QUAD)

func cast_spell():
	# Reinicia o efeito
	magic_hand_particles.emitting = true
	blade_light.visible = true
	print("entrou")
	
	# Cria um Tween para aumentar a intensidade da cor ou escala
	var tween = create_tween()
	magic_hand_particles.amount = 50 # Aumenta a densidade
	
	# Faz o círculo "crescer" e depois sumir
	tween.tween_property(magic_hand_particles.process_material, "scale_min", 2.0, 0.5)
	await get_tree().create_timer(3.0).timeout
	magic_hand_particles.emitting = false
	blade_light.visible = false
	print("saiu")
	
func shoot(input:Variant):
	if not SaveManager.is_equipped("pistol"): return
	if is_reloading: return
	
	if can_shoot_again and camera.current:
		if clip_pistol_ammo <= 0:
			return
			
		clip_pistol_ammo -= 1
		update_ammo_ui()
		
		if not is_instance_valid(current_weapon): return

		#TEMP TROCA POR NOVA ARMA 3D
		current_weapon = hand_with_pistol
		var rotation_default = current_weapon.rotation

		var tween = create_tween()
		#current_weapon.play("shoot")
		fire.play("shoot")
		GlobalUtils.shake_camera(0.03, 0.05)
		GlobalUtils.vibrate_controller(input, 0.5, 0.0, 0.1)
		faisca.restart()
		faisca.emitting = true
		gun_shot.play()
		can_shoot_again = false
		
		# --- EJEÇÃO DA CÁPSULA (Cápsula física independente) ---
		if capsula_scene:
			var capsula = capsula_scene.instantiate()
			# Adiciona na raiz para não seguir o player
			get_tree().current_scene.add_child(capsula)
			
			# Impede que a cápsula bata no corpo do próprio jogador ao nascer
			capsula.add_collision_exception_with(self)
			
			# Define a posição de saída (mais para a direita, um pouco acima, e BEM mais pra frente)
			var spawn_pos = camera.global_position + camera.global_transform.basis * Vector3(0.4, -0.1, -0.75)
			capsula.global_position = spawn_pos
			capsula.global_rotation = camera.global_rotation
			
			# Joga a cápsula ESTRITAMENTE para a direita e para cima
			var eject_dir = camera.global_transform.basis * Vector3(1.0, 1.0, 0.0) 
			capsula.apply_central_impulse(eject_dir * randf_range(1.5, 2.0))
			
			# Dá um torque (giro) mais leve para não espalhar tanto
			capsula.apply_torque(Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))
		
		# --- EFEITO DE LUZ (CLARÃO) ---
		var flash_tween = create_tween()
		
		# 1. Faz o flash aparecer com uns 20% ou 30% de opacidade instantaneamente
		# Não coloque 1.0 (100%) se não a tela fica toda branca e você não vê nada
		flash_tela.color.a = 0.1 
		
		# 2. Faz ele sumir suavemente
		flash_tween.tween_property(flash_tela, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		
		# --- IMPACTO DO TIRO (IDR PARA TRÁS E GIRAR) ---
		# Rotaciona 3 graus
		#tween.tween_property(current_weapon, "rotation_degrees", 3.0, 0.05).set_trans(Tween.TRANS_SINE)
		
		# Move para trás (X) e um pouco para cima (Y) AO MESMO TEMPO
		# Ajuste os valores (ex: 10 ou -10) conforme a posição da sua arma na tela
		tween.parallel().tween_property(current_weapon, "position:x", current_weapon.position.x + 0.01, 0.05).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(current_weapon, "position:y", current_weapon.position.y - 0.01, 0.05).set_trans(Tween.TRANS_SINE)

		tween.tween_interval(0.1)

		# --- VOLTA PARA A POSIÇÃO PADRÃO ---
		# Usamos TRANS_BACK para dar aquele efeito de mola realista no encaixe
		#tween.tween_property(current_weapon, "rotation_degrees", 8.4, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		current_weapon.rotation = rotation_default
		# Volta a posição X e Y originais
		# DICA: É melhor salvar a posição inicial da arma numa variável se você for usar muito isso
		tween.parallel().tween_property(current_weapon, "position:x", current_weapon.position.x, 0.1).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(current_weapon, "position:y", current_weapon.position.y, 0.1).set_trans(Tween.TRANS_BACK)
		
		#processa raycast - pega o inimigo e plota o sange/dano
		raycast_process_shoot()		
				
		await get_tree().create_timer(0.56).timeout
		can_shoot_again = true

func raycast_process_shoot():
	#get enemy - set blood
	if ray_cast_3d.is_colliding():
		var target = ray_cast_3d.get_collider()
		
		#set damage
		#recheck if target stell exists
		if target and target.has_method("take_damage"):
			target.take_damage(damage_pistol)
			
			# Verifica se o que atingimos é um inimigo
			if target.is_in_group("enemies"):
				spawn_blood_raycast(ray_cast_3d.get_collision_point(), ray_cast_3d.get_collision_normal())
		
			var ponto_colisao = ray_cast_3d.get_collision_point()
			# A distância entre a origem do RayCast e onde ele bateu
			var distancia = ray_cast_3d.global_position.distance_to(ponto_colisao)
			
			# HEARTSHOT
			if target.name == "heart" and distancia > 7:
				#ativa camera bullet time
				bullet.visible = true
				target.take_damage(damage_pistol+damage_headshoot)
					
				# 1. CALCULAMOS O ALVO REAL (Um pouco acima do centro do inimigo)
				# Pegamos a posição global do inimigo e subimos ex: 1.5 metros no eixo Y
				var offset_altura = Vector3(0.25, -0.3, 0) 
				var alvo_ajustado = target.global_position + offset_altura

				# Se você quiser que a câmera foque EXATAMENTE onde a bala bateu, mas um pouco acima:
				# var alvo_ajustado = ponto_colisao + Vector3(0, 0.5, 0)
					
				#LOGICA PARA GIRAR A BALA
				var tween_bullet = create_tween()
				# 2. GIRA A BALA (O Efeito que você quer)
				# 360 graus = 1 volta completa. 1800 graus = 5 voltas.
				# deg_to_rad converte para o formato que o Godot entende (radianos)
				var voltas = deg_to_rad(1800) 
				# Animamos a rotação no eixo Z (para girar como uma hélice) 
				# ou Y (se ela girar como um disco)
				tween_bullet.tween_property(bullet, "rotation:z", bullet.rotation.z + voltas, 2.5)\
					.set_trans(Tween.TRANS_LINEAR) # Linear faz o giro ser constante	
					
					
				control_weapons.visible = false
				hand_with_pistol.visible = false
				if hand_with_magic: hand_with_magic.visible = false
				control_magic.visible = false
				bullet_light.visible = true
				bullet.visible = true
				camera_bullet_time_ON = true
				GlobalUtils.ativar_camera_lenta(0.1, 60.0, true)
				
				# 3. Cria o movimento da câmera
				var tween_cam = create_tween()
				
				camera_3d_bullet_time.global_position = camera.global_position
				camera_3d_bullet_time.make_current()
				
				# No lugar do seu ponto 3 e 4, use isto:
				# 3. Movimento da posição
				tween_cam.tween_property(camera_3d_bullet_time, "global_position", alvo_ajustado + (ray_cast_3d.global_transform.basis.z * 2.0), 0.9)\
					.set_trans(Tween.TRANS_QUINT)\
					.set_ease(Tween.EASE_OUT)

				# 4. Rastreamento do Olhar (Faz a câmera atualizar o foco a cada frame do Tween)
				tween_cam.parallel().tween_method(
				func(pos): camera_3d_bullet_time.look_at(alvo_ajustado), # Função que olha pro alvo
					0.0, # Valor inicial (não importa)
					1.0, # Valor final (não importa)
					0.9  # Mesma duração do movimento
				)

				# 5. Espera um pouco no alvo e volta
				tween_cam.tween_interval(0.05) # Pausa dramática no inimigo

				tween_cam.tween_property(camera_3d_bullet_time, "global_position", camera.global_position, 0.4)\
					.set_trans(Tween.TRANS_SINE)
				
				#tween_cam.tween_callback(bullet_time_back)
				
				await get_tree().create_timer(0.65).timeout
				if camera_bullet_time_ON: bullet_time_back()

func bullet_time_back():	
	camera_bullet_time_ON = false
	bullet.visible = false
	GlobalUtils.remover_camera_lenta()
	
	if is_first_person:
		camera.make_current()
		control_weapons.visible = true
		hand_with_pistol.visible = SaveManager.is_equipped("pistol")
		if hand_with_magic: hand_with_magic.visible = true
		control_magic.visible = true
	else:
		camera_third_person.make_current()
	
	await get_tree().create_timer(0.16).timeout
	bullet_light.visible = false
	



func spawn_blood_raycast(pos, normal):
	var blood = blood_effect.instantiate()
	get_tree().root.add_child(blood) # Adiciona na raiz para não mover com o player
	blood.global_position = pos
	
	# Faz o sangue espirrar na direção oposta ao impacto (opcional)
	if normal != Vector3.ZERO:
		blood.look_at(pos + normal, Vector3.UP)
		
func spawn_blood_effect(body: Node3D):
	var blood = blood_effect.instantiate()
	get_tree().root.add_child(blood)
	blood.global_position = body.global_position
	blood.global_position.y += 2 # para sair um pouco do chao... ficar mais alto
		
		
func take_damage(number:int):
	if current_health <= 0:
		return
		
	current_health -= number
	if current_health <= 0:
		current_health = 0
		_trigger_game_over()
		
	GlobalUtils.vibrate_controller(Input, 0.5, 0.5, 0.2)
	GlobalUtils.shake_camera(damage_camera_shake_strength, damage_camera_shake_duration)
	
	if is_instance_valid(blood_overlay):
		var mat = blood_overlay.material as ShaderMaterial
		mat.set_shader_parameter("multiplier", 0.4)
		var t = create_tween()
		t.tween_method(func(val): mat.set_shader_parameter("multiplier", val), 0.4, 0.0, 1.5).set_trans(Tween.TRANS_CUBIC)
	
	if is_instance_valid(hud_layer):
		var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
		if motion_blur:
			motion_blur.visible = true
			motion_blur.material.set_shader_parameter("blur_strength", 0.8)
			damage_blur_timer = 0.4
			var tween_blur = create_tween().set_parallel(true)
			tween_blur.tween_property(motion_blur.material, "shader_parameter/blur_strength", 0.0, 0.4)
			tween_blur.chain().tween_callback(func(): if not Input.is_action_pressed("ui_run"): motion_blur.visible = false)
	
	print("Damage taken by the player: "+str(number) + " | HP: " + str(current_health))
	
	# Atualiza o visual do batimento sempre que leva dano
	_start_heartbeat_pulse()

func _trigger_fall_death() -> void:
	if is_falling_dead: return
	is_falling_dead = true
	current_health = 0
	
	# Cria uma câmera estática acompanhando a queda lá de cima
	fall_cam = Camera3D.new()
	# Fica parada na altura do abismo (Y=15) para ver o chão, os inimigos e o player caindo
	fall_cam.global_position = Vector3(global_position.x, 20.0, global_position.z + 12.0)
	
	get_tree().current_scene.add_child(fall_cam)
	fall_cam.make_current()
	
	if is_instance_valid(camera_third_person):
		camera_third_person.current = false
		
	await get_tree().create_timer(3.0).timeout
	_trigger_game_over()

func _trigger_game_over() -> void:
	if SaveManager.current_stage.contains("oficina_jimmy") or (get_tree().current_scene and get_tree().current_scene.scene_file_path.contains("oficina_jimmy")):
		var fade = get_tree().current_scene.get_node_or_null("fade")
		if fade:
			fade.fade_out()
			await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/stages/prolog/cutscene_end_first_fight.tscn")
		return
		
	var game_over_script = load("res://scripts/ui/game_over.gd")
	if game_over_script:
		var game_over_node = CanvasLayer.new()
		game_over_node.set_script(game_over_script)
		get_tree().root.add_child(game_over_node)
	

		
func _on_pistola_animation_finished() -> void:
	pass #current_weapon.play("idle")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if is_magic_attacking:
		blade_in.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true) # Velocidade 20% por meio segundo
		body.take_damage(damage_crescent_cogblade)
	

func _on_area_3d_body_exited(body: Node3D) -> void:
	if is_magic_attacking:
		blade_back.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true) # Velocidade 20% por meio segundo
		body.take_damage(damage_crescent_cogblade)


func _on_bullet_touch_body_entered(body: Node3D) -> void:
	#bullet_time_back()
	bullet.visible = false
	#bullet_light.visible = false
	spawn_blood_effect(body)

func update_equipment_visuals() -> void:
	if is_first_person and not is_reloading and control_weapons.visible:
		hand_with_pistol.visible = SaveManager.is_equipped("pistol")

func prevent_dash_leak() -> void:
	dash_cooldown_timer = 0.2
