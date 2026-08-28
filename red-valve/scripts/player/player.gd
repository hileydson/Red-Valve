extends CharacterBody3D

@onready var camera = $Camera3D # Certifique-se de que sua câmera se chama Camera3D
@onready var camera_third_person: Camera3D =$SpringArm3D/camera_third_person
@onready var camera_third_person_marker: Marker3D = $SpringArm3D/camera_third_person_marker
@onready var camera_first_person_marker: Marker3D = $camera_first_person_marker

@onready var gun_load: AudioStreamPlayer = $sounds/GunLoad
@onready var load_gun: AudioStreamPlayer = $sounds/LoadGun
@onready var gun_shot: AudioStreamPlayer = $sounds/GunShot
@onready var passos: AudioStreamPlayer3D = $sounds_3d/Passos
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
# @onready var screen_shader: MeshInstance3D = $camera_third_person/screen_shader

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
var iron_rusks_value_label: Label

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
@export var WALK_SPEED: float = 3.0
@export var WALK_SPEED_NORMAL: float = 2.8
@export var RUN_SPEED: float = 4.8 # Velocidade maior para a corrida

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
var amulet_magic_active: bool = false
var max_amulet_targets: int = 3

var playback 

# --- CUTSCENE HELPER VARS ---
var _cutscene_inputs_disabled: bool = false
var _cutscene_auto_walk: bool = false
var _cutscene_auto_run: bool = false
var _cutscene_camera_shake_intensity: float = 0.0
var _cutscene_shake_h_base: float = 0.0
var _cutscene_shake_v_base: float = 0.0
var _is_cutscene_shaking: bool = false
var _cutscene_hud_hidden: bool = false
var _cutscene_camera_disabled: bool = false

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
	if not GlobalEvents.in_cutscene:
		camera_third_person.make_current()
	#camera_top_view.make_current()
	point.visible = false
	
	
	
	#check if esta no prologo para carregar modelo correto
	if GlobalEvents.is_maycow_normal:
		playback = animation_tree_normal["parameters/playback"]
		$maycow_lopes.queue_free()
	else:
		$maycow_lopes_normal.queue_free() 
		
	# Instancia Componente HUD
	var hud_component = load("res://scripts/player/player_hud.gd").new()
	hud_component.name = "PlayerHUD"
	add_child(hud_component)
	
	# Instancia Componente Cutscene
	var cutscene_component = load("res://scripts/player/player_cutscene.gd").new()
	cutscene_component.name = "PlayerCutscene"
	add_child(cutscene_component)
	
	# Instancia Componente Combat
	var combat_component = load("res://scripts/player/player_combat.gd").new()
	combat_component.name = "PlayerCombat"
	add_child(combat_component)

	# Instancia Componente Dash
	var dash_component = load("res://scripts/player/player_dash.gd").new()
	dash_component.name = "PlayerDash"
	add_child(dash_component)
	
	# Instancia Componente Ultimate
	var ult_component = load("res://scripts/player/player_ultimate.gd").new()
	ult_component.name = "PlayerUltimate"
	add_child(ult_component)
	
	# Instancia Componente Amulet
	var amulet_component = load("res://scripts/player/player_amulet.gd").new()
	amulet_component.name = "PlayerAmulet"
	add_child(amulet_component)

func update_ammo_ui() -> void:
	var hud = get_node_or_null("PlayerHUD")
	if hud: hud.update_ammo_ui()

func _start_heartbeat_pulse() -> void:
	var hud = get_node_or_null("PlayerHUD")
	if hud: hud._start_heartbeat_pulse()

func _input(event):
	if GlobalEvents.in_cutscene or _cutscene_inputs_disabled:
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
		
		# Trava o ângulo vertical (modifica rotation.x diretamente para evitar 'flip' do Euler)
		var v_down = -25 if camera_atual == camera_third_person else -60
		var v_up = 20 if camera_atual == camera_third_person else 60
		
		var target_pitch = camera_atual.rotation.x - (event.relative.y * SENSITIVITY * sens_mult)
		camera_atual.rotation.x = clamp(target_pitch, deg_to_rad(v_down), deg_to_rad(v_up))


# Adicione estas variáveis no topo do script (fora do _process) se ainda não tiver
var hold_timer: float = 0.0
var hold_threshold: float = 0.15 # 200 milisegundos para confirmar o "segurar"
var limite_rotacao_lateral = deg_to_rad(15) # O máximo que ele pode "virar" (ex: 35 graus)
var velocidade_giro = 4.0
func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null: return
	
	# --- CUTSCENE CAMERA SHAKE ---
	if _cutscene_camera_shake_intensity > 0.0 and is_instance_valid(camera_third_person):
		if not _is_cutscene_shaking:
			_cutscene_shake_h_base = camera_third_person.h_offset
			_cutscene_shake_v_base = camera_third_person.v_offset
			_is_cutscene_shaking = true
		
		var forca = _cutscene_camera_shake_intensity * 0.1
		camera_third_person.h_offset = _cutscene_shake_h_base + randf_range(-forca, forca)
		camera_third_person.v_offset = _cutscene_shake_v_base + randf_range(-forca, forca)
	elif _is_cutscene_shaking and is_instance_valid(camera_third_person):
		_is_cutscene_shaking = false
		camera_third_person.h_offset = _cutscene_shake_h_base
		camera_third_person.v_offset = _cutscene_shake_v_base
		
	if is_using_ultimate:
		# Processa a gravidade caso ele estivesse caindo no momento, 
		# e processa o combate para que a cogblade possa girar e voar.
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		
		var combat_comp = get_node_or_null("PlayerCombat")
		if combat_comp: combat_comp.process_combat(delta)
		
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
		
	# PARASITE MAYCOW (1ª Pessoa)
	if !GlobalEvents.is_maycow_normal:
	
		# 1. LÓGICA DE MIRA (AIM/ZOOM EM PRIMEIRA PESSOA)
		is_first_person = true # Sempre em primeira pessoa
		
		# Força a câmera de 1ª pessoa a ser a atual se não for (ex: ao entrar na cena)
		if not GlobalEvents.in_cutscene and not _cutscene_camera_disabled and not camera.current and not transition_camera and not camera_bullet_time_ON:
			camera.make_current()
			if camera_third_person:
				camera_third_person.current = false
			control_weapons.visible = true
			hand_with_pistol.visible = SaveManager.is_equipped("pistol")
			if hand_with_magic: hand_with_magic.visible = true
			control_magic.visible = true
			
		var wants_to_aim = Input.is_action_pressed("ui_hold_first_person_view")
		var has_mp = SaveManager.current_mp > 0
		
		if Input.is_action_just_released("ui_hold_first_person_view") or (is_aiming and wants_to_aim and not has_mp):
			if amulet_selected_enemies.size() == 0:
				AudioServer.playback_speed_scale = 1.0
			_on_amulet_magic_released()

		if wants_to_aim and not has_mp and Input.is_action_just_pressed("ui_hold_first_person_view"):
			if is_instance_valid(gun_load): gun_load.play()

		is_aiming = wants_to_aim and has_mp
		
		if is_aiming:
			SaveManager.current_mp -= 3.5 * delta
			if SaveManager.current_mp < 0: SaveManager.current_mp = 0
			
			if Input.is_action_just_pressed("ui_hold_first_person_view"):
				AudioServer.playback_speed_scale = 0.5
				
			if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
			if point: point.visible = not GlobalEvents.in_cutscene and not _cutscene_hud_hidden
			
			# Ativa o Motion Blur forte
			if is_instance_valid(hud_layer):
				var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
				if motion_blur:
					motion_blur.visible = true
					motion_blur.material.set_shader_parameter("blur_strength", 0.08)
					
			_process_amulet_magic(delta)
			_process_amulet_targeting()
		else:
			if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
			if point: point.visible = not GlobalEvents.in_cutscene and not _cutscene_hud_hidden
			
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

		# 4. PULO E RECARGA
		if not _cutscene_inputs_disabled:
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
				
				# Girar a câmera (Vertical) evitando flip
				var v_down = -25 if camera_atual == camera_third_person else -60
				var v_up = 20 if camera_atual == camera_third_person else 60
				
				var target_pitch = camera_atual.rotation.x - (joy_dir.y * JOY_SENSITIVITY * sens_mult * delta * 100)
				camera_atual.rotation.x = clamp(target_pitch, deg_to_rad(v_down), deg_to_rad(v_up))
	
		# 6. GESTÃO DO DASH (COOLDOWN E EXECUÇÃO)
		if dash_cooldown_timer > 0:
			dash_cooldown_timer -= delta

		if not _cutscene_inputs_disabled and Input.is_action_just_pressed("ui_dash") and not is_dashing and dash_cooldown_timer <= 0 and current_stamina >= 30.0:
			current_stamina -= 30.0
			stamina_fade_timer = 2.0
			stamina_bar.modulate.a = 1.0
			dash()
			

		# 7. MOVIMENTAÇÃO (DASH VS CAMINHADA)
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# --- CUTSCENE INPUT OVERRIDES ---
		if GlobalEvents.in_cutscene or _cutscene_inputs_disabled:
			input_dir = Vector2.ZERO
		if _cutscene_auto_walk:
			input_dir.y = -1.0
			_run_toggle_active = false
		if _cutscene_auto_run:
			input_dir.y = -1.0
			_run_toggle_active = true
		
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
			if GlobalEvents.in_cutscene and _cutscene_auto_walk:
				velocidade_atual = WALK_SPEED * 0.45
			elif is_aiming:
				velocidade_atual = WALK_SPEED * 0.4
			elif _run_toggle_active and current_stamina > 0 and not is_exhausted:
				velocidade_atual = RUN_SPEED
			
			# Mais lento ao andar para trás
			if input_dir.y > 0.1:
				velocidade_atual *= 0.65
				
			var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var velocity_Y_zero: bool = velocity.y <= 0

			if direction and !transition_camera:
				var is_actually_running = _run_toggle_active and current_stamina > 0 and not is_exhausted and not is_aiming

				# Animações e Sons
				if is_actually_running:
					if pistola.animation not in ["reload", "run"]: pistola.play("run")
					if is_on_floor() and velocity_Y_zero: playback.travel("run")
				else:
					if pistola.animation not in ["reload", "walk"]: pistola.play("walk")
					if is_on_floor() and velocity_Y_zero: playback.travel("walk")
				
				if !passos.playing and is_on_floor():
					var cutscene_boost = 8.0 if GlobalEvents.in_cutscene else 0.0
					if is_actually_running:
						passos.pitch_scale = randf_range(1.15, 1.3)
						passos.volume_db = randf_range(-8.0, -5.0) + cutscene_boost
					else:
						passos.pitch_scale = randf_range(0.65, 0.75)
						passos.volume_db = randf_range(-11.0, -8.0) + (cutscene_boost * 0.5)
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
		
	# DAQUI PRA FRENTE É O MAYCOW SEM PODERES (E NORMAL APOS PROLOGO)
	else:
		var normal_can_aim = SaveManager.prolog_finished and not _cutscene_inputs_disabled
		is_aiming = normal_can_aim and Input.is_action_pressed("ui_hold_first_person_view")

		# A troca de câmera para 1ª pessoa é controlada pelo poder do amuleto
		# (player_amulet.gd), que faz o zoom gradual da 3ª pessoa antes de trocar.
		if not GlobalEvents.in_cutscene and not _cutscene_camera_disabled and not is_first_person:
			if camera_third_person and not camera_third_person.current:
				camera_third_person.make_current()

		if normal_can_aim:
			if Input.is_action_just_released("ui_hold_first_person_view"):
				if amulet_selected_enemies.size() == 0:
					AudioServer.playback_speed_scale = 1.0
				_on_amulet_magic_released()

			if is_aiming:
				if Input.is_action_just_pressed("ui_hold_first_person_view"):
					AudioServer.playback_speed_scale = 0.5
					
				if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = true
				if point: point.visible = false
				
				if is_instance_valid(hud_layer):
					var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
					if motion_blur:
						motion_blur.visible = true
						motion_blur.material.set_shader_parameter("blur_strength", 0.08)
						
				_process_amulet_magic(delta)
			else:
				if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
				if point: point.visible = not GlobalEvents.in_cutscene and not _cutscene_hud_hidden
				
				if is_instance_valid(hud_layer) and not is_playing_return_effect:
					var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
					if motion_blur:
						motion_blur.material.set_shader_parameter("blur_strength", 0.0)
						motion_blur.visible = false
						
				_hide_amulet_magic()
				_clear_amulet_hover()
				
			if is_aiming and not is_magic_attacking and Input.is_action_just_pressed("ui_magic_attack") and SaveManager.current_mp >= 10.0:
				magic_hand_attack()
		else:
			if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
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
				
				# Girar a câmera (Vertical) evitando flip
				var v_down = -25 if camera_atual == camera_third_person else -60
				var v_up = 20 if camera_atual == camera_third_person else 60
				
				var target_pitch = camera_atual.rotation.x - (joy_dir.y * JOY_SENSITIVITY * sens_mult * delta * 100)
				camera_atual.rotation.x = clamp(target_pitch, deg_to_rad(v_down), deg_to_rad(v_up))
			

		# 7. MOVIMENTAÇÃO (DASH VS CAMINHADA)
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# --- CUTSCENE INPUT OVERRIDES ---
		if GlobalEvents.in_cutscene or _cutscene_inputs_disabled:
			input_dir = Vector2.ZERO
		if _cutscene_auto_walk:
			input_dir.y = -1.0
			_run_toggle_active = false
		if _cutscene_auto_run:
			input_dir.y = -1.0
			_run_toggle_active = true
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
		head_bob(delta)


	var combat_comp = get_node_or_null("PlayerCombat")
	if combat_comp: combat_comp.process_combat(delta)


func dash():
	var comp = get_node_or_null("PlayerDash")
	if comp: comp.dash()

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
	
	var ajuste_intensidade = 0.3 # Bem suave para caminhada padrão
	if _run_toggle_active and not is_aiming:
		bob_freq = 2.1
		
		if is_first_person:
			ajuste_intensidade = 0.7 # Corrida mais suave, menos violenta
			bob_freq = 3.0           # Frequência reduzida para balançar mais lentamente
	else:
		bob_freq = 2.0
		
	var pos_bob = Vector3.ZERO
	if is_on_floor() and velocity.length() > 0.1:
		pos_bob.y = sin(t_bob * bob_freq) * bob_amp * ajuste_intensidade
		pos_bob.x = cos(t_bob * bob_freq * 0.5) * bob_amp * 0.5 * ajuste_intensidade
	
	# Mantém a câmera colada no marker com o balanço
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
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.reload()

func magic_hand_attack():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.magic_hand_attack()

func cast_spell():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.cast_spell()

func shoot(input:Variant):
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.shoot(input)

func raycast_process_shoot():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.raycast_process_shoot()

func bullet_time_back():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.bullet_time_back()

func spawn_blood_raycast(pos, normal):
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.spawn_blood_raycast(pos, normal)

func spawn_blood_effect(body: Node3D):
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.spawn_blood_effect(body)

func take_damage(number:int):
	if is_using_ultimate:
		return
	if current_health <= 0:
		return
		
	current_health -= number
	if current_health <= 0:
		current_health = 0
		_play_death_sound()
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
	
	_start_heartbeat_pulse()

func _trigger_fall_death() -> void:
	if is_falling_dead: return
	is_falling_dead = true
	current_health = 0
	_play_death_sound()
	
	fall_cam = Camera3D.new()
	get_tree().current_scene.add_child(fall_cam)
	fall_cam.global_position = Vector3(global_position.x, 20.0, global_position.z + 12.0)
	fall_cam.make_current()
	
	if is_instance_valid(camera_third_person):
		camera_third_person.current = false
		
	await get_tree().create_timer(3.0).timeout
	_trigger_game_over()

func _play_death_sound() -> void:
	var death_audio = AudioStreamPlayer.new()
	var sound_path = "res://assets/sounds/player/player_death_groan.wav"
	if ResourceLoader.exists(sound_path):
		death_audio.stream = load(sound_path)
		death_audio.volume_db = 2.0
		death_audio.process_mode = Node.PROCESS_MODE_ALWAYS 
		get_tree().root.add_child(death_audio)
		death_audio.play()
		death_audio.finished.connect(func(): death_audio.queue_free())

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
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._on_area_3d_body_entered(body)

func _on_area_3d_body_exited(body: Node3D) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._on_area_3d_body_exited(body)

func _on_bullet_touch_body_entered(body: Node3D) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._on_bullet_touch_body_entered(body)

func add_cogblade_power(amount: float) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.add_cogblade_power(amount)

func _start_cogblade_pulse() -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._start_cogblade_pulse()

func update_equipment_visuals() -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.update_equipment_visuals()



func _activate_cogblade_ultimate() -> void:
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._activate_cogblade_ultimate()

func _apply_aoe_damage_slowly(pos: Vector3):
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._apply_aoe_damage_slowly(pos)

func _spawn_explosion_vfx(pos: Vector3):
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._spawn_explosion_vfx(pos)

func _process_amulet_magic(delta: float) -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._process_amulet_magic(delta)

func _hide_amulet_magic() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._hide_amulet_magic()

func _process_amulet_targeting() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._process_amulet_targeting()

func _clear_amulet_hover() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._clear_amulet_hover()

func _apply_silhouette(enemy: Node, cor: Color) -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._apply_silhouette(enemy, cor)

func _remove_silhouette(enemy: Node) -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._remove_silhouette(enemy)

func _get_all_meshes(node: Node) -> Array:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: return comp._get_all_meshes(node)
	return []

func _on_amulet_magic_released() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._on_amulet_magic_released()

func play_return_from_arena_effect() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp.play_return_from_arena_effect()
func cutscene_set_hud_enabled(enabled: bool) -> void:
	_cutscene_hud_hidden = not enabled
	if is_instance_valid(hud_layer):
		hud_layer.visible = enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_hud_enabled(enabled)

func cutscene_set_player_control(enabled: bool) -> void:
	_cutscene_inputs_disabled = not enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_player_control(enabled)

func cutscene_set_auto_walk(enabled: bool) -> void:
	_cutscene_auto_walk = enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_auto_walk(enabled)

func cutscene_set_auto_run(enabled: bool) -> void:
	_cutscene_auto_run = enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_auto_run(enabled)

func cutscene_set_motion_blur(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_motion_blur(intensity_percent)

func cutscene_set_slow_motion(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_slow_motion(intensity_percent)

func cutscene_set_slow_motion_no_audio(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_slow_motion_no_audio(intensity_percent)

func cutscene_set_camera_shake(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_camera_shake(intensity_percent)

func cutscene_set_camera_current(is_current: bool) -> void:
	_cutscene_camera_disabled = not is_current
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_camera_current(is_current)
