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

# --- ULTIMATE CINEMÁTICA ---
@export_group("Ultimate Cinemática")
@export var ult_model_distance: float = 1.7
@export var ult_cogblade_rot_x: float = -70.0
@export var ult_cogblade_rot_y: float = -90.0
@export var ult_cogblade_rot_z: float = 0.0
var mp_bar: ProgressBar

var hud_layer: CanvasLayer
var amulet_counter_label: Label
var amulet_crosshair: Panel

var is_teleporting_enemies: bool = false
var is_playing_return_effect: bool = false
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

var last_rotation_y: float = 0.0
var last_camera_rot_x: float = 0.0

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

var is_aiming = false
var _run_toggle_active: bool = false

var cogblade_hud: TextureProgressBar
var cogblade_hud_label: Label
var cogblade_power_value: float = 0.0
var cogblade_pulsing: bool = false
var cogblade_pulse_tween: Tween
var cogblade_particles: CPUParticles2D
var is_using_ultimate: bool = false
var amuleto_node: Node3D
var amuleto_particles: CPUParticles3D
var amulet_hovered_enemy: Node3D = null
var amulet_selected_enemies: Array[Node3D] = []

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
	
	if !GlobalEvents.is_maycow_normal:
		cogblade_hud = TextureProgressBar.new()
		var cog_tex = load("res://assets/images/menu/itens/red_valve/cogblade.png")
		cogblade_hud.texture_under = cog_tex
		cogblade_hud.texture_progress = cog_tex
		cogblade_hud.tint_under = Color(1, 1, 1, 0.25) # Marca d'água permanente na tela
		cogblade_hud.tint_progress = Color(1, 1, 1, 1.0) # Cor de preenchimento
		cogblade_hud.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		cogblade_hud.min_value = 0
		cogblade_hud.max_value = 100
		cogblade_hud.value = 0
		cogblade_hud.anchor_left = 0.0
		cogblade_hud.anchor_top = 0.0
		cogblade_hud.anchor_right = 0.0
		cogblade_hud.anchor_bottom = 0.0
		cogblade_hud.offset_left = 20
		cogblade_hud.offset_top = 20
		cogblade_hud.scale = Vector2(0.4, 0.4)
		hud_layer.add_child(cogblade_hud)
		
		cogblade_hud_label = Label.new()
		cogblade_hud_label.text = "PODER DA COGBLADE"
		cogblade_hud_label.add_theme_font_size_override("font_size", 64)
		cogblade_hud_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
		cogblade_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		cogblade_hud_label.visible = false
		hud_layer.add_child(cogblade_hud_label)

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
	#hud_layer.add_child(blood_overlay) # Removido a marca de sangue conforme pedido

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
	
	# Mira do Amuleto (Círculo Estilo DOOM)
	amulet_crosshair = Panel.new()
	amulet_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	amulet_crosshair.custom_minimum_size = Vector2(32, 32)
	amulet_crosshair.offset_left = -16
	amulet_crosshair.offset_top = -16
	amulet_crosshair.offset_right = 16
	amulet_crosshair.offset_bottom = 16
	amulet_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0) # Transparente no meio
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.9, 0.2, 1.0, 0.8) # Roxo/Magia
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.anti_aliasing = true
	amulet_crosshair.add_theme_stylebox_override("panel", style)
	amulet_crosshair.visible = false
	hud_layer.add_child(amulet_crosshair)
	
	# Amulet Counter Label
	amulet_counter_label = Label.new()
	amulet_counter_label.add_theme_font_size_override("font_size", 54)
	amulet_counter_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	amulet_counter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	amulet_counter_label.add_theme_constant_override("outline_size", 10)
	amulet_counter_label.anchor_left = 1.0
	amulet_counter_label.anchor_right = 1.0
	amulet_counter_label.offset_left = -250
	amulet_counter_label.offset_top = 40
	amulet_counter_label.offset_right = -40
	amulet_counter_label.offset_bottom = 150
	amulet_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amulet_counter_label.visible = false
	hud_layer.add_child(amulet_counter_label)
	
	# Piscar em tons de vermelho
	var counter_tween = create_tween().set_loops()
	counter_tween.tween_property(amulet_counter_label, "theme_override_colors/font_color", Color(1.0, 0.2, 0.2, 1.0), 0.4)
	counter_tween.tween_property(amulet_counter_label, "theme_override_colors/font_color", Color(0.5, 0.0, 0.0, 1.0), 0.4)
	
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
	if GlobalEvents.in_cutscene:
		return
		
	if event.is_action_pressed("ui_cogblade_power") and !GlobalEvents.is_maycow_normal:
		if GlobalEvents.in_cutscene or process_mode == Node.PROCESS_MODE_DISABLED:
			return
		if cogblade_power_value >= 100.0 and not is_using_ultimate and is_on_floor():
			cogblade_power_value = 0.0
			cogblade_pulsing = false
			if cogblade_pulse_tween: cogblade_pulse_tween.kill()
			if cogblade_particles: cogblade_particles.emitting = false
			if cogblade_hud: 
				cogblade_hud.value = 0.0
				cogblade_hud.tint_progress = Color(1, 1, 1, 1.0)
				cogblade_hud.modulate = Color(1, 1, 1, 1.0)
			_activate_cogblade_ultimate()

	if is_using_ultimate:
		return
	if camera_bullet_time_ON:
		return
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens_mult = SaveManager.config.get("sensitivity_aim", 0.4) if is_aiming else SaveManager.config.get("sensitivity_look", 1.0)
		
		# Aplica a rotação horizontal no corpo (Maycow)
		rotate_y(-event.relative.x * SENSITIVITY * sens_mult)
		
		# Aplica a rotação vertical na câmera atual
		var camera_atual = get_viewport().get_camera_3d()
		camera_atual.rotate_x(-event.relative.y * SENSITIVITY * sens_mult)
		
		# Trava o ângulo vertical
		var v_down = -25 if camera_atual == camera_third_person else -80
		var v_up = 20 if camera_atual == camera_third_person else 80
		camera_atual.rotation.x = clamp(camera_atual.rotation.x, deg_to_rad(v_down), deg_to_rad(v_up))


# Adicione estas variáveis no topo do script (fora do _process) se ainda não tiver
var hold_timer: float = 0.0
var hold_threshold: float = 0.15 # 200 milisegundos para confirmar o "segurar"
var limite_rotacao_lateral = deg_to_rad(15) # O máximo que ele pode "virar" (ex: 35 graus)
var velocidade_giro = 4.0
func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null: return
	if GlobalEvents.in_cutscene:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	if is_using_ultimate:
		# Apenas processa a gravidade, caso ele estivesse caindo no momento, 
		# mas normalmente a animação vai travar ele. Retorna para não mover.
		return

	var is_in_house = get_tree().current_scene.name == "the_house" if get_tree() and get_tree().current_scene else false
	var can_run_normal = GlobalEvents.is_maycow_normal and not is_in_house
	var stamina_active = not GlobalEvents.is_maycow_normal or can_run_normal
	
	var camera_atual_check = get_viewport().get_camera_3d()
	var current_camera_rot_x = camera_atual_check.rotation.x if camera_atual_check else 0.0
	var is_turning_camera = abs(rotation.y - last_rotation_y) > 0.001 or abs(current_camera_rot_x - last_camera_rot_x) > 0.001
	last_rotation_y = rotation.y
	last_camera_rot_x = current_camera_rot_x
	
	if SaveManager.config.get("run_mode", "hold") == "toggle":
		if Input.is_action_just_pressed("ui_run"):
			_run_toggle_active = not _run_toggle_active
		if velocity.length() < 0.1 or is_aiming or is_exhausted or current_stamina <= 0:
			_run_toggle_active = false
	else:
		_run_toggle_active = Input.is_action_pressed("ui_run")

	
	# --- STAMINA EXHAUSTION LOGIC ---
	if current_stamina <= 0.5:
		is_exhausted = true
	elif current_stamina >= 25.0:
		is_exhausted = false
		
	# --- STAMINA LOGIC ---
	var is_running_stam = _run_toggle_active and velocity.length() > 0.1 and current_stamina > 0 and stamina_active and not is_exhausted and not is_aiming
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
	
		# 1. LÓGICA DE MIRA (AIM/ZOOM EM PRIMEIRA PESSOA)
		is_first_person = true # Sempre em primeira pessoa
		
		# Força a câmera de 1ª pessoa a ser a atual se não for (ex: ao entrar na cena)
		if not camera.current and not transition_camera and not camera_bullet_time_ON:
			camera.make_current()
			if camera_third_person:
				camera_third_person.current = false
			control_weapons.visible = true
			hand_with_pistol.visible = SaveManager.is_equipped("pistol")
			if hand_with_magic: hand_with_magic.visible = true
			control_magic.visible = true
			
		is_aiming = Input.is_action_pressed("ui_hold_first_person_view")
		point.visible = true
		
		# 3. GRAVIDADE
		if not is_on_floor():
			velocity += get_gravity() * delta

		# 4. PULO E RECARGA
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
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
				var sens_mult = SaveManager.config.get("sensitivity_aim", 0.4) if is_aiming else SaveManager.config.get("sensitivity_look", 1.0)
				rotate_y(-joy_dir.x * JOY_SENSITIVITY * sens_mult * delta * 100)
				
				# Girar a câmera (Vertical)
				camera_atual.rotate_x(-joy_dir.y * JOY_SENSITIVITY * sens_mult * delta * 100)
				
				# Trava o ângulo vertical (mesma lógica do mouse)
				var v_down = -25 if camera_atual == camera_third_person else -80
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
			var velocidade_atual = WALK_SPEED
			if is_aiming:
				velocidade_atual = WALK_SPEED * 0.4
			elif _run_toggle_active and current_stamina > 0 and not is_exhausted:
				velocidade_atual = RUN_SPEED
			
			# Mais lento ao andar para trás
			if input_dir.y > 0.1:
				velocidade_atual *= 0.65
				
			var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var velocity_Y_zero: bool = velocity.y <= 0

			if direction and !transition_camera:
				# Animações e Sons
				if _run_toggle_active and not is_aiming:
					if pistola.animation not in ["reload", "run"]: pistola.play("run")
					if is_on_floor() and velocity_Y_zero: playback.travel("run")
				else:
					if pistola.animation not in ["reload", "walk"]: pistola.play("walk")
					if is_on_floor() and velocity_Y_zero: playback.travel("walk")
				
				if !passos.playing and is_on_floor():
					if _run_toggle_active and not is_aiming:
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
		
		# FX DURANTE CORRIDA (FOV e Blur leve - Diferenciado para 1ª Pessoa e 3ª Pessoa)
		var camera = get_viewport().get_camera_3d()
		if camera and not is_dashing:
			var is_running = _run_toggle_active and velocity.length() > 0.1 and current_stamina > 0 and not is_exhausted and not is_aiming
			var direction_check := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var visao_frente = -global_transform.basis.z
			var alinhamento = direction_check.dot(visao_frente) if direction_check else 0.0
			
			var target_run_fov = 75.0
			if is_aiming:
				target_run_fov = 50.0
			elif direction_check and alinhamento < -0.2:
				target_run_fov = 73.0 if is_first_person else 70.0
			elif is_running:
				target_run_fov = 80.0 if is_first_person else 88.0
				
			if not is_first_person and input_dir.length() < 0.1 and not is_aiming:
				target_run_fov -= 12.0
				
			var cur_fov_speed = 5.0
			if is_aiming:
				cur_fov_speed = 8.0
			elif not is_running and not is_first_person:
				cur_fov_speed = 0.8
				
			camera.fov = lerp(camera.fov, target_run_fov, cur_fov_speed * delta)
			


		# 8. ROTAÇÃO VISUAL DO MODELO (MAYCOW LOPES)
		if input_dir.y <= 0.1: 
			var alvo_y = PI 
			var alvo_pos_x = 0.0
			var speed_y = 0.6
			var speed_x = 5.0
			if input_dir.x > 0: 
				alvo_y = PI - (limite_rotacao_lateral * 1.5) 
			elif input_dir.x < -0.1: 
				alvo_y = PI + (limite_rotacao_lateral * 1.8) 
				speed_y = 0.6
				speed_x = 1.5
				var current_is_running = _run_toggle_active and velocity.length() > 0.1 and current_stamina > 0 and not is_exhausted and not is_aiming
				if not current_is_running:
					alvo_pos_x = -0.15

			var modelo = get_node_or_null("maycow_lopes")
			if modelo:
				modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_y, delta * velocidade_giro * speed_y)
				modelo.position.x = lerp(modelo.position.x, alvo_pos_x, speed_x * delta)
		
	# DAQUI PRA FRENTE É O MAYCOW SEM PODERES 	
	else:
		
		# 2.5 LÓGICA DO AMULETO (PRIMEIRA PESSOA COM ZOOM EM 3ª PESSOA)
		if Input.is_action_just_released("ui_hold_first_person_view"):
			if is_first_person and is_instance_valid(camera_third_person):
				# Estava na primeira pessoa. Retorna para a 3ª pessoa já com zoom in, 
				# para que o lerp normal faça o zoom out suave até o FOV padrão (75)
				camera_third_person.fov = 40.0
			_on_amulet_magic_released()
			if is_teleporting_enemies: return
			if not is_inside_tree(): return

		if Input.is_action_pressed("ui_hold_first_person_view"):
			is_aiming = true
			if is_instance_valid(camera_third_person) and camera_third_person.fov <= 55.0:
				# O zoom da 3ª pessoa chegou perto o suficiente. Pula para a 1ª pessoa.
				is_first_person = true
				if not camera.current:
					camera.make_current()
					camera.fov = 75.0 # Primeira pessoa não tem zoom distorcido
				if camera_third_person: camera_third_person.current = false
				if hand_with_magic: hand_with_magic.visible = true
				if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = true
				if point: point.visible = false # Esconde a mira normal
				
				# Ativa o Motion Blur forte
				if is_instance_valid(hud_layer):
					var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
					if motion_blur:
						motion_blur.visible = true
						motion_blur.material.set_shader_parameter("blur_strength", 0.08)
						
				_process_amulet_magic(delta)
				_process_amulet_targeting()
			else:
				# Ainda no processo de zoom in na 3ª pessoa
				is_first_person = false
				if camera_third_person and not camera_third_person.current:
					camera_third_person.make_current()
				if hand_with_magic: hand_with_magic.visible = false
				if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
				
				# Desativa o Motion Blur
				if is_instance_valid(hud_layer) and not is_playing_return_effect:
					var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
					if motion_blur:
						motion_blur.material.set_shader_parameter("blur_strength", 0.0)
						motion_blur.visible = false
						
				_hide_amulet_magic()
				_clear_amulet_hover()
		else:
			is_aiming = false
			is_first_person = false
			if camera_third_person and not camera_third_person.current:
				camera_third_person.make_current()
			if hand_with_magic: hand_with_magic.visible = false
			if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
			
			# Desativa o Motion Blur
			if is_instance_valid(hud_layer) and not is_playing_return_effect:
				var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
				if motion_blur:
					motion_blur.material.set_shader_parameter("blur_strength", 0.0)
					motion_blur.visible = false
					
			_hide_amulet_magic()
			_clear_amulet_hover()
		
		# 3. GRAVIDADE
		if not is_on_floor():
			velocity += get_gravity() * delta

		# 5. ROTAÇÃO DA CÂMERA (ANALÓGICO DIREITO)
		if !camera_bullet_time_ON:
			var joy_dir = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
			if joy_dir.length() > DEADZONE:
				var camera_atual = get_viewport().get_camera_3d()
				var sens_mult = SaveManager.config.get("sensitivity_look", 1.0)
				
				# Girar o corpo (Horizontal) - multiplicado por delta para suavidade
				rotate_y(-joy_dir.x * JOY_SENSITIVITY * sens_mult * delta * 100)
				
				# Girar a câmera (Vertical)
				camera_atual.rotate_x(-joy_dir.y * JOY_SENSITIVITY * sens_mult * delta * 100)
				
				# Trava o ângulo vertical (mesma lógica do mouse)
				var v_down = -25 if camera_atual == camera_third_person else -80
				var v_up = 20 if camera_atual == camera_third_person else 80
				camera_atual.rotation.x = clamp(camera_atual.rotation.x, deg_to_rad(v_down), deg_to_rad(v_up))
			

		# 7. MOVIMENTAÇÃO (DASH VS CAMINHADA)
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# MOVIMENTO NORMAL (WALK/RUN)
		var is_running = _run_toggle_active and current_stamina > 0 and can_run_normal and not is_exhausted and not is_aiming
		var velocidade_atual = RUN_SPEED if is_running else WALK_SPEED_NORMAL
		if input_dir.y > 0.1:
			velocidade_atual *= 0.65
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var velocity_Y_zero: bool = velocity.y <= 0
		var target_fov: float = 75.0
		if is_aiming:
			if is_first_person:
				target_fov = 75.0 # Primeira pessoa fica com FOV normal
			else:
				target_fov = 40.0 # Zoom IN pesado na terceira pessoa (alvo)

		if direction:
			var visao_frente = -global_transform.basis.z
			var alinhamento = direction.dot(visao_frente)
			
			if is_on_floor():
				# Calcula se a direção do movimento é paralela ou oposta à frente do personagem
				if alinhamento < -0.2:
					# Movimento para trás
					playback.travel("walk_back")
					if not is_aiming:
						target_fov = 73.0 if is_first_person else 70.0
				else:
					# Movimento para frente ou corrida
					if is_running:
						playback.travel("run")
						if not is_aiming:
							target_fov = 80.0 if is_first_person else 88.0
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

		var fov_lerp_speed = 5.0
		if is_aiming:
			fov_lerp_speed = 12.0
		elif not is_running and not is_first_person:
			fov_lerp_speed = 0.8
			
		var camera = get_viewport().get_camera_3d()
		if camera:
			if not is_first_person and input_dir.length() < 0.1 and not is_aiming:
				target_fov -= 12.0
			camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)


		# 8. ROTAÇÃO VISUAL E POSIÇÃO DO MODELO (MAYCOW LOPES NORMAL)
		var modelo = get_node_or_null("maycow_lopes_normal")
		if modelo:
			var alvo_y = 0.0
			var speed_y = 0.6
			if input_dir.y <= 0.1: 
				if input_dir.x > 0: 
					alvo_y = -(limite_rotacao_lateral * 1.5) 
				elif input_dir.x < -0.1: 
					alvo_y = (limite_rotacao_lateral * 1.8) 
					speed_y = 0.6
			modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_y, delta * velocidade_giro * speed_y)
			
			var is_walking_back = direction and direction.dot(-global_transform.basis.z) < -0.2
			var target_pos_x = 0.0
			var target_pos_z = 0.3995
			if is_running:
				target_pos_x = normal_run_offset_x
				target_pos_z = normal_run_offset_z
			elif is_walking_back:
				target_pos_x = normal_walkback_offset_x
				target_pos_z = normal_walkback_offset_z
				
			var speed_x = 5.0
			if input_dir.x < -0.1:
				speed_x = 1.5
				if not is_running:
					target_pos_x -= 0.15
				
			modelo.position.x = lerp(modelo.position.x, target_pos_x, speed_x * delta)
			modelo.position.z = lerp(modelo.position.z, target_pos_z, 5.0 * delta)

		# Inclinação e Encolhimento da arma 2D ao correr (bloqueado ao mirar)
		if is_instance_valid(pistola) and typeof(pistol_2d_pos_original) == TYPE_VECTOR2:
			is_running = _run_toggle_active and velocity.length() > 0.1 and current_stamina > 0 and not is_exhausted and not is_aiming
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
		
		# FOV Punch (Sensação de velocidade extra - mais suave em 1ª Pessoa)
		var camera = get_viewport().get_camera_3d()
		if camera:
			var base_fov = camera.fov
			var fov_boost = 6.0 if is_first_person else 12.0
			tween_blur.tween_property(camera, "fov", base_fov + fov_boost, DASH_DURATION * 0.3).set_trans(Tween.TRANS_SINE)
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
	if _run_toggle_active and not is_aiming:
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
		await get_tree().create_timer(0.2).timeout
			
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
				add_cogblade_power(10.0) # Adiciona 10 de poder por tiro
		
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
	if is_using_ultimate:
		return
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
			tween_blur.chain().tween_callback(func(): if not _run_toggle_active: motion_blur.visible = false)
	
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
	
func add_cogblade_power(amount: float) -> void:
	if GlobalEvents.is_maycow_normal or not cogblade_hud or is_using_ultimate: return
	cogblade_power_value = clamp(cogblade_power_value + amount, 0.0, 100.0)
	if cogblade_hud: cogblade_hud.value = cogblade_power_value
	
	if cogblade_power_value >= 100.0 and not cogblade_pulsing:
		cogblade_pulsing = true
		_start_cogblade_pulse()

func _start_cogblade_pulse() -> void:
	if not cogblade_hud: return
	
	if cogblade_pulse_tween: cogblade_pulse_tween.kill()
	cogblade_pulse_tween = create_tween().set_loops()
	
	# Pulsa vermelho no preenchimento
	cogblade_pulse_tween.tween_property(cogblade_hud, "tint_progress", Color(1.0, 0.2, 0.2, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	cogblade_pulse_tween.tween_property(cogblade_hud, "tint_progress", Color(1.0, 1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	# Partículas de sangue
	if not cogblade_particles:
		cogblade_particles = CPUParticles2D.new()
		cogblade_particles.emitting = true
		cogblade_particles.amount = 50 # Mais sangue
		cogblade_particles.lifetime = 1.0
		cogblade_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		
		# Faz sair por toda a extensão da imagem
		var w = cogblade_hud.texture_progress.get_width()
		var h = cogblade_hud.texture_progress.get_height()
		cogblade_particles.emission_rect_extents = Vector2(w / 2.0, h / 2.0)
		
		cogblade_particles.gravity = Vector2(0, 300)
		cogblade_particles.color = Color(0.8, 0.0, 0.0, 0.8)
		cogblade_particles.scale_amount_min = 3.0
		cogblade_particles.scale_amount_max = 6.0
		
		cogblade_hud.add_child(cogblade_particles)
		# Centraliza as emissões no meio da imagem
		cogblade_particles.position = Vector2(w / 2.0, h / 2.0)
	else:
		cogblade_particles.emitting = true

func update_equipment_visuals() -> void:
	if is_first_person and not is_reloading and control_weapons.visible:
		hand_with_pistol.visible = SaveManager.is_equipped("pistol")

func _activate_cogblade_ultimate() -> void:
	is_using_ultimate = true
	cogblade_power_value = 0.0
	cogblade_pulsing = false
	if cogblade_pulse_tween: cogblade_pulse_tween.kill()
	if cogblade_particles: cogblade_particles.emitting = false
	if cogblade_hud:
		cogblade_hud.value = 0.0
		cogblade_hud.tint_progress = Color(1, 1, 1, 1.0)
		cogblade_hud.modulate = Color(1, 1, 1, 1.0)
	
	# Cancela a lâmina se estiver no ar/retornando (evita glitch de velocidade)
	is_blade_returning = false
	crescent_cogblade.top_level = false
	crescent_cogblade.position = magic_blade_pos_original
	crescent_cogblade.rotation = Vector3.ZERO
	crescent_cogblade.scale = Vector3.ONE
	crescent_cogblade.hide()
	
	# 1. Preparação
	Engine.time_scale = 0.1
	AudioServer.playback_speed_scale = 0.5 # Deixa os sons graves/lentos
	
	control_magic.visible = false
	control_weapons.visible = false
	hand_with_pistol.visible = false
	if hand_with_magic: hand_with_magic.visible = false
	if point: point.visible = false # Esconde o ponto no meio da tela
	
	if hud_layer:
		hud_layer.visible = false
		var blur = hud_layer.get_node_or_null("MotionBlurOverlay")
		if blur:
			blur.visible = true
			blur.material.set_shader_parameter("blur_strength", 0.2) # Motion blur bem sutil
			
	# Para animações e zera a velocidade para não deslizar
	playback.travel("idle")
	velocity = Vector3.ZERO
	
	# Cria uma câmera temporária cinemática
	var cine_cam = Camera3D.new()
	get_tree().current_scene.add_child(cine_cam)
	cine_cam.global_transform = camera.global_transform
	cine_cam.make_current()
	camera.current = false
	
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
	var start_pos = global_position
	var sky_pos = start_pos + Vector3(0, 20.0, 0)
	
	# A câmera começa a subir
	seq.tween_property(cine_cam, "global_position", sky_pos, 0.35).set_trans(Tween.TRANS_SINE)
	
	var player_model = get_node_or_null("maycow_lopes")
	if is_instance_valid(player_model):
		# Cria um tween separado para o modelo agir de forma perfeitamente simultânea à subida
		var model_tween = create_tween()
		# Aguarda a câmera olhar para o céu (0.15s) que está no seq
		model_tween.tween_interval(0.15)
		model_tween.tween_callback(func():
			player_model.visible = true
			player_model.top_level = true
			player_model.global_rotation = global_rotation
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
				var front_target = cine_cam.global_position - cine_cam.global_transform.basis.z * ult_model_distance + Vector3(0, -1.0, 0)
				player_model.global_position = start_pos.lerp(front_target, progress)
		, 0.0, 1.0, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		
		# Ele termina de subir até o céu junto com a câmera
		var model_up_pos = sky_pos - cine_cam.global_transform.basis.z * ult_model_distance + Vector3(0, -1.0, 0)
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
		crescent_cogblade.show()
		crescent_cogblade.top_level = true
		
		# Rotação fixa virada para baixo
		crescent_cogblade.global_rotation = cine_cam.global_rotation
		crescent_cogblade.rotate_object_local(Vector3(1,0,0), deg_to_rad(ult_cogblade_rot_x)) 
		crescent_cogblade.rotate_object_local(Vector3(0,1,0), deg_to_rad(ult_cogblade_rot_y)) 
		crescent_cogblade.rotate_object_local(Vector3(0,0,1), deg_to_rad(ult_cogblade_rot_z))
		
		# Posição final perfeita (1.5m na frente da câmera e levemente à direita)
		var final_blade_pos = cine_cam.global_position - cine_cam.global_transform.basis.z * 1.5 + cine_cam.global_transform.basis.x * 0.35
		# Começa fora da tela por CIMA e à direita
		var start_blade_pos = cine_cam.global_position + (cine_cam.global_transform.basis.x * 1.8) + (cine_cam.global_transform.basis.y * 1.5) - (cine_cam.global_transform.basis.z * 1.2)
		crescent_cogblade.global_position = start_blade_pos
		crescent_cogblade.scale = Vector3(0.5, 0.5, 0.5)
		
		var blade_audio = AudioStreamPlayer.new()
		blade_audio.stream = load("res://assets/sounds/player/blade_out.mp3")
		add_child(blade_audio)
		blade_audio.play()
		
		# Animação fluida e mais rápida de entrada vindo de cima-direita para a posição final
		var blade_tween = create_tween().set_parallel(true)
		blade_tween.tween_property(crescent_cogblade, "global_position", final_blade_pos, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		blade_tween.tween_property(crescent_cogblade, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
	seq.tween_interval(0.14)
	
	# Passo 5: O mergulho.
	var impact_pos = start_pos + Vector3(0, 0.5, 0)
	
	# A câmera e a cogblade descem exatamete juntas (com offset mantido)
	seq.tween_property(cine_cam, "global_position", impact_pos, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	seq.parallel().tween_property(crescent_cogblade, "global_position", impact_pos - cine_cam.global_transform.basis.z * 1.0 + cine_cam.global_transform.basis.x * 0.35, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# IMPACTO!
	seq.tween_callback(func():
		# Tremer tela pesado
		GlobalUtils.shake_camera(2.0, 1.0)
		
		# Som de explosão
		var boom = AudioStreamPlayer.new()
		boom.stream = load("res://assets/sounds/common/explosao.mp3")
		add_child(boom)
		boom.play()
		
		# Partículas Explosão
		_spawn_explosion_vfx(impact_pos)
		
		# Aplica dano AoE LENTAMENTE (um por um com pequeno atraso)
		_apply_aoe_damage_slowly(impact_pos)
		
		# Esconde a cogblade
		crescent_cogblade.hide()
		crescent_cogblade.top_level = false
		crescent_cogblade.position = magic_blade_pos_original
		crescent_cogblade.rotation = Vector3.ZERO
		crescent_cogblade.scale = Vector3.ONE
		
		# Restaura câmera do player imediatamente após o impacto, mas MANTÉM a câmera lenta!
		if is_instance_valid(cine_cam):
			cine_cam.queue_free()
		camera.make_current()
		
		control_magic.visible = true
		control_weapons.visible = true
		hand_with_pistol.visible = SaveManager.is_equipped("pistol")
		if hand_with_magic: hand_with_magic.visible = true
		if point: point.visible = true # Restaura o ponto no meio da tela
		
		if hud_layer:
			hud_layer.visible = true
			var blur = hud_layer.get_node_or_null("MotionBlurOverlay")
			if blur: blur.visible = false
			
		# Aguarda 0.15 segundos em slow motion antes de devolver controle
		var end_tween = create_tween()
		end_tween.tween_interval(0.15) 
		end_tween.tween_callback(func():
			global_position = start_pos # Garante que o player não é empurrado
			velocity = Vector3.ZERO
			Engine.time_scale = 1.0
			AudioServer.playback_speed_scale = 1.0
			is_using_ultimate = false
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

func _process_amulet_magic(delta: float) -> void:
	if not is_instance_valid(amuleto_node):
		var amuleto_scene = load("res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb")
		if amuleto_scene:
			amuleto_node = amuleto_scene.instantiate()
			if hand_with_magic:
				hand_with_magic.add_child(amuleto_node)
				amuleto_node.position = Vector3(-0.06, 0.15, -0.15) # Em cima da mão esquerda
				amuleto_node.scale = Vector3(0.3, 0.3, 0.3)
				
				amuleto_particles = CPUParticles3D.new()
				amuleto_particles.amount = 120
				amuleto_particles.lifetime = 1.0
				amuleto_particles.local_coords = false # Partículas se espalham no ar independente do giro do amuleto
				amuleto_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
				amuleto_particles.emission_sphere_radius = 0.2
				amuleto_particles.direction = Vector3.UP
				amuleto_particles.spread = 180.0
				amuleto_particles.gravity = Vector3(0, 0.5, 0)
				amuleto_particles.initial_velocity_min = 0.5
				amuleto_particles.initial_velocity_max = 2.0
				
				# Variação de tons: roxos, brancos e vermelhos
				var initial_grad = Gradient.new()
				initial_grad.offsets = [0.0, 0.25, 0.5, 0.75, 1.0]
				initial_grad.colors = [
					Color(0.5, 0.0, 1.0, 1.0), # Roxo puro brilhante
					Color(1.0, 1.0, 1.0, 1.0), # Branco mágico
					Color(0.8, 0.2, 1.0, 1.0), # Lilás/Rosa
					Color(1.0, 0.0, 0.0, 1.0), # Vermelho sangue
					Color(0.3, 0.0, 0.6, 1.0)  # Roxo escuro
				]
				amuleto_particles.color_initial_ramp = initial_grad
				
				# Fade in e fade out no ciclo de vida
				var alpha_grad = Gradient.new()
				alpha_grad.offsets = [0.0, 0.2, 0.8, 1.0]
				alpha_grad.colors = [Color(1,1,1,0), Color(1,1,1,1), Color(1,1,1,1), Color(1,1,1,0)]
				amuleto_particles.color_ramp = alpha_grad
				
				var scale_curve = Curve.new()
				scale_curve.add_point(Vector2(0.0, 0.8))
				scale_curve.add_point(Vector2(1.0, 0.0))
				amuleto_particles.scale_amount_curve = scale_curve
				
				var pmat = StandardMaterial3D.new()
				pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				pmat.vertex_color_use_as_albedo = true # OBRIGATÓRIO para a cor do Gradient funcionar!
				var pmesh = SphereMesh.new()
				pmesh.radius = 0.04
				pmesh.height = 0.08
				pmesh.material = pmat
				amuleto_particles.mesh = pmesh
				
				amuleto_node.add_child(amuleto_particles)
				
	if is_instance_valid(amuleto_node):
		amuleto_node.visible = true
		amuleto_node.rotate_y(8.0 * delta) # Amuleto girando rapidamente
		if amuleto_particles:
			amuleto_particles.emitting = true

func _hide_amulet_magic() -> void:
	if is_instance_valid(amuleto_node):
		amuleto_node.visible = false
		if amuleto_particles:
			amuleto_particles.emitting = false

func _process_amulet_targeting() -> void:
	if not is_inside_tree() or get_tree() == null: return
	
	var prev_hovered = amulet_hovered_enemy
	amulet_hovered_enemy = null
	
	# Detecta o inimigo na mira (usando ray_cast_3d)
	if ray_cast_3d and ray_cast_3d.is_colliding():
		var target = ray_cast_3d.get_collider()
		var current_enemy = target
		while is_instance_valid(current_enemy) and current_enemy != get_tree().current_scene:
			if current_enemy.is_in_group("enemies") or current_enemy.has_method("take_damage"):
				amulet_hovered_enemy = current_enemy
				break
			current_enemy = current_enemy.get_parent()
			
	# Remove silhueta de quem não está mais na mira (e que não foi selecionado)
	if is_instance_valid(prev_hovered) and prev_hovered != amulet_hovered_enemy:
		if prev_hovered not in amulet_selected_enemies:
			_remove_silhouette(prev_hovered)
	
	# Exibe a silhueta roxa se estiver olhando para um que não foi selecionado
	if is_instance_valid(amulet_hovered_enemy) and amulet_hovered_enemy not in amulet_selected_enemies:
		_apply_silhouette(amulet_hovered_enemy, Color(0.8, 0.2, 1.0, 0.35)) # Roxo translucido
		
	# Ação de Selecionar (Tiro)
	if Input.is_action_just_pressed("ui_shoot"):
		if is_instance_valid(amulet_hovered_enemy) and not (amulet_hovered_enemy in amulet_selected_enemies):
			amulet_selected_enemies.append(amulet_hovered_enemy)
			_apply_silhouette(amulet_hovered_enemy, Color(1.0, 0.0, 0.0, 0.6)) # Destaca vermelho a seleção
			
	if is_instance_valid(amulet_counter_label):
		if amulet_selected_enemies.size() > 0:
			amulet_counter_label.text = str(amulet_selected_enemies.size()) + " ALVOS"
			amulet_counter_label.visible = true
			# Pulsar vermelho
			var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			amulet_counter_label.modulate = Color(1.0, pulse, pulse)
		else:
			amulet_counter_label.visible = false

func _clear_amulet_hover() -> void:
	if is_instance_valid(amulet_hovered_enemy) and amulet_hovered_enemy not in amulet_selected_enemies:
		_remove_silhouette(amulet_hovered_enemy)
	amulet_hovered_enemy = null

func _apply_silhouette(enemy: Node, cor: Color) -> void:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true # Faz renderizar por cima de qualquer parede (estilo Left 4 Dead)
	mat.albedo_color = cor
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var meshes = _get_all_meshes(enemy)
	for m in meshes:
		if m is MeshInstance3D:
			m.material_overlay = mat

func _remove_silhouette(enemy: Node) -> void:
	var meshes = _get_all_meshes(enemy)
	for m in meshes:
		if m is MeshInstance3D:
			m.material_overlay = null

func _get_all_meshes(node: Node) -> Array:
	var list = []
	for child in node.get_children():
		if child is MeshInstance3D:
			list.append(child)
		list.append_array(_get_all_meshes(child))
	return list

func _on_amulet_magic_released() -> void:
	if amulet_selected_enemies.size() > 0:
		
		# Guardamos os inimigos para transferir
		GlobalEvents.amulet_captured_enemies.clear()
		for e in amulet_selected_enemies:
			if is_instance_valid(e):
				_remove_silhouette(e)
				GlobalEvents.amulet_captured_enemies.append(e)
				
		amulet_selected_enemies.clear()
		_clear_amulet_hover()
		
		# Limpa os estados do Player para quando voltar da Arena
		is_aiming = false
		is_first_person = false
		if is_instance_valid(camera_third_person):
			camera_third_person.make_current()
			camera_third_person.fov = 75.0
		if is_instance_valid(hand_with_magic):
			hand_with_magic.visible = false
		if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
		if point: point.visible = false
		if is_instance_valid(amulet_counter_label): amulet_counter_label.visible = false
		
		# Desativa o Motion Blur ao sair
		if is_instance_valid(hud_layer):
			var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
			if motion_blur:
				motion_blur.material.set_shader_parameter("blur_strength", 0.0)
				motion_blur.visible = false
				
		_hide_amulet_magic()
		
		GlobalEvents.previous_is_maycow_normal = GlobalEvents.is_maycow_normal
		
		is_teleporting_enemies = true
		
		var tree = get_tree()
		var root = tree.root
		var current = tree.current_scene
		
		# ---- TRANSIÇÃO CINEMÁTICA DIMENSIONAL ----
		process_mode = Node.PROCESS_MODE_DISABLED
		Engine.time_scale = 0.2 # Slow motion global
		
		var cine_cam = Camera3D.new()
		var cam_attr = CameraAttributesPractical.new()
		cam_attr.dof_blur_far_enabled = true
		cam_attr.dof_blur_far_distance = 1.0
		cam_attr.dof_blur_far_transition = 10.0 # Motion blur pesado artificial
		cine_cam.attributes = cam_attr
		cine_cam.fov = 95.0
		
		var center_pos = Vector3.ZERO
		for e in GlobalEvents.amulet_captured_enemies:
			center_pos += e.global_position
		center_pos /= GlobalEvents.amulet_captured_enemies.size()
		
		cine_cam.global_position = center_pos + Vector3(0, 1.5, 4.5)
		current.add_child(cine_cam)
		cine_cam.look_at(center_pos + Vector3(0, 1.0, 0), Vector3.UP)
		cine_cam.make_current()
		
		var tween = tree.create_tween().set_parallel(true).set_ignore_time_scale(true)
		var anim_time = 1.2
		for e in GlobalEvents.amulet_captured_enemies:
			if is_instance_valid(e):
				e.process_mode = Node.PROCESS_MODE_DISABLED
				var target_y = e.global_position.y + 35.0
				tween.tween_property(e, "global_position:y", target_y, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
				tween.tween_property(e, "rotation:y", e.rotation.y + deg_to_rad(1080), anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
				tween.tween_property(e, "scale", Vector3(0.05, 5.0, 0.05), anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		tween.tween_property(cine_cam, "global_position:y", cine_cam.global_position.y + 35.0, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_property(cine_cam, "fov", 130.0, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
		await tween.finished
		
		for e in GlobalEvents.amulet_captured_enemies:
			if is_instance_valid(e):
				e.scale = Vector3.ONE
				e.rotation.x = 0
				e.rotation.z = 0
				
		if is_instance_valid(cine_cam):
			cine_cam.queue_free()
			
		process_mode = Node.PROCESS_MODE_INHERIT
		Engine.time_scale = 1.0 # Retorna ao normal
		
		is_teleporting_enemies = false
		
		# Instancia o campo de batalha antes de removermos a nós mesmos da árvore
		var battlefield_scene = load("res://scenes/stages/battlefield/battlefield_1.tscn").instantiate()
		
		# Pausa a cena atual tirando ela da árvore
		root.remove_child(current)
		GlobalEvents.paused_scene_for_amulet = current
		
		root.add_child(battlefield_scene)
		tree.current_scene = battlefield_scene

func play_return_from_arena_effect() -> void:
	is_playing_return_effect = true
	GlobalUtils.shake_camera(0.6, 1.0)
	
	if is_instance_valid(hud_layer):
		hud_layer.visible = true
		var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
		if motion_blur:
			motion_blur.visible = true
			motion_blur.material.set_shader_parameter("blur_strength", 1.8)
			var tween = create_tween()
			tween.tween_property(motion_blur.material, "shader_parameter/blur_strength", 0.0, 2.5).set_trans(Tween.TRANS_SINE)
			tween.finished.connect(func(): is_playing_return_effect = false)
