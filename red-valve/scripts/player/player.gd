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

# --- PLAYER HEALTH & HUD ---
@export var max_health: int = 100
var current_health: int = 100
var heartbeat_hud: ColorRect
var blood_overlay: ColorRect
var heartbeat_tween: Tween
# ---------------------------

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003 # Sensibilidade do mouse
@export var WALK_SPEED = 4.0
@export var WALK_SPEED_NORMAL = 2.8
@export var RUN_SPEED = 7.5 # Velocidade maior para a corrida

#CHANGE LATER - DYNAMICLY
@export var damage_crescent_cogblade:int = 14
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
@export var JOY_SENSITIVITY = 0.04 # Sensibilidade para o analógico
@export var DEADZONE = 0.1


# Configurações do balanço da tela (Bobbing)
@export var head_bob_ON = true
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


#ORIGINAL POSITION FOR THE LEFT HAND
var magic_hand_pos_original
var hand_magic_3d_pos_original: Vector3
var hand_magic_3d_pos_hidden: Vector3
var is_magic_attacking: bool = false
var magic_blade_pos_original
var camera_bullet_time_position
var camera_bullet_time_ON = false

var is_first_person = false
var transition_camera = false

var playback 

func _ready():		
		
	# Captura o mouse e o esconde ao iniciar o jogo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	playback = animation_tree["parameters/playback"]
	
	# a priori sera a pistola... mas precisa ter um change da arma para mudar 
	current_weapon = pistola
	
	magic_hand_pos_original = magic_hand.position
	magic_blade_pos_original = crescent_cogblade.position
	
	# Esconde o sprite 2D antigo
	magic_hand.visible = false
	# Configura a nova mão 3D escondida atrás e abaixo da câmera
	hand_magic_3d_pos_original = hand_magic_3d.position
	hand_magic_3d_pos_hidden = hand_magic_3d_pos_original + Vector3(0, -0.8, 1.0)
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
	
	var hud_layer = CanvasLayer.new()
	hud_layer.layer = 100
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
	
	_start_heartbeat_pulse()

func update_ammo_ui() -> void:
	if not is_instance_valid(ammo_label): return
	if GlobalEvents.is_maycow_normal:
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
	if camera_bullet_time_ON or is_magic_attacking:
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
var limite_rotacao_lateral = deg_to_rad(35) # O máximo que ele pode "virar" (ex: 35 graus)
var velocidade_giro = 8.0
func _physics_process(delta: float) -> void:
	
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
		
		# 2. TRAVA DE ATAQUE MÁGICO
		if is_magic_attacking:
			return 
		
		# 3. GRAVIDADE
		if not is_on_floor():
			velocity += get_gravity() * delta

		# 4. PULO E RECARGA
		if Input.is_action_just_pressed("ui_accept") and is_on_floor() and !holding_view:
			velocity.y = JUMP_VELOCITY
			playback.travel("jump")
			
		if Input.is_action_just_pressed("ui_reload") and !transition_camera:
			reload()
		
		if Input.is_action_just_pressed("ui_shoot") and !transition_camera:
			shoot(Input)
		
		if !is_magic_attacking and Input.is_action_just_pressed("ui_magic_attack") and !transition_camera and camera.current:
			magic_hand_attack()
			
		if camera_bullet_time_ON:
			return
			
		# 5. ROTAÇÃO DA CÂMERA (ANALÓGICO DIREITO)
		if !camera_bullet_time_ON and !is_magic_attacking:
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

		if Input.is_action_just_pressed("ui_dash") and not is_dashing and dash_cooldown_timer <= 0:
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
			var velocidade_atual = RUN_SPEED if Input.is_action_pressed("ui_run") else WALK_SPEED
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
		if !camera_bullet_time_ON and !is_magic_attacking:
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
		var velocidade_atual = WALK_SPEED_NORMAL
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var velocity_Y_zero: bool = velocity.y <= 0
		var target_fov: float = 75.0

		if direction:
			var visao_frente = -global_transform.basis.z
			var alinhamento = direction.dot(visao_frente)
			
			if is_on_floor():
				# Calcula se a direção do movimento é paralela ou oposta à frente do personagem
				# transform.basis.z aponta para a "trás" padrão no Godot (ou ajustado ao seu modelo)
				# O produto escalar nos dá um valor positivo se for para a frente e negativo se for para trás
				if alinhamento < -0.2:
					# Movimento para trás
					playback.travel("walk_back")
					target_fov = 65.0
				else:
					# Movimento para frente
					playback.travel("walk")
			
			if !passos.playing and is_on_floor(): 
				if alinhamento < -0.2:
					passos.pitch_scale = randf_range(0.95, 1.05)
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

		var camera = get_viewport().get_camera_3d()
		if camera:
			camera.fov = lerp(camera.fov, target_fov, 5.0 * delta)


		# 8. ROTAÇÃO VISUAL DO MODELO (MAYCOW LOPES)
		#if input_dir.y <= 0.1: 
			#var alvo_y = PI 
			#if input_dir.x > 0: alvo_y = PI - limite_rotacao_lateral 
			#elif input_dir.x < 0: alvo_y = PI + limite_rotacao_lateral 
#
			#var modelo = get_node_or_null("maycow_lopes_normal")
			#if modelo:
				#modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_y, delta * velocidade_giro)


	if head_bob_ON:
		head_bob(delta) # Lembre-se de incluir a vibração dentro da sua função head_bob!
	
	# 9. FINALIZAÇÃO
	move_and_slide()


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
	dash_effect.pitch_scale = 1.0 / 0.2 # Substitua 0.2 pelo valor da sua camera lenta
	dash_effect.play()
	
	dash_effect_particles.emitting = true

	# --- 1. SUA LÓGICA DE FÍSICA E DIREÇÃO JÁ EXISTENTE ---
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction == Vector3.ZERO:
		direction = -transform.basis.z # Dash para frente se parado
	
	dash_direction = direction
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
	GlobalUtils.ativar_camera_lenta_com_fim(0.2, 1.0, true)
	

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
		hand_with_pistol.visible = show_ui
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
		hand_with_pistol.visible = show_ui
		if hand_with_magic: hand_with_magic.visible = show_ui
		)
	
	
	
	
func reload():
	if is_first_person:
		var total = SaveManager.get_item_amount("pistol_ammo")
		if total <= 0 or clip_pistol_ammo >= max_clip_pistol:
			return
			
		var needed = max_clip_pistol - clip_pistol_ammo
		var taken = mini(needed, total)
		SaveManager.remove_item_amount("pistol_ammo", taken)
		clip_pistol_ammo += taken
		update_ammo_ui()
		
		if not is_instance_valid(current_weapon): return

		var tween = create_tween()
		gun_load.play()
		tween.tween_interval(0.1)
		tween.tween_interval(0.8)
		# Volta para o zero
		#tween.tween_property(current_weapon, "rotation_degrees", 8.4, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func magic_hand_attack():
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
		
	# 2. LANÇA A CRESCENT COGBLADE (3D)
	crescent_cogblade.show()
	
	# LIGA AS FAÍSCAS (Certifique-se que o nó está dentro da cogblade)
	# Exemplo: $Camera3D/crescent_cogblade/Faiscas
	var faiscas = crescent_cogblade.get_node("Faiscas") 
	faiscas.emitting = true
	
	# RESET: Posição original
	crescent_cogblade.position = magic_blade_pos_original
	
	var pos_final_local = magic_blade_pos_original + Vector3(0, 0, -5)
	
	# Tween de ida
	tween_magic.tween_property(crescent_cogblade, "position", pos_final_local, 0.8)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Giro 3x (Gira as faíscas junto se elas forem filhas do objeto)
	tween_magic.tween_property(crescent_cogblade, "rotation:y", crescent_cogblade.rotation.y + deg_to_rad(1080), 0.8)

	# 3. RETORNO
	var tween_back = create_tween().set_parallel(true)
	
	# Volta a mão (3D)
	tween_back.tween_property(hand_magic_3d, "position", hand_magic_3d_pos_hidden, 0.5)\
		.set_delay(0.8)\
		.set_trans(Tween.TRANS_SINE)
		
	# Volta a lâmina
	tween_back.tween_property(crescent_cogblade, "position", magic_blade_pos_original, 0.6)\
		.set_delay(0.8)\
		.set_trans(Tween.TRANS_SINE)
	
	# DESLIGA AS FAÍSCAS no meio do caminho de volta ou no fim
	tween_back.tween_callback(func(): faiscas.emitting = false).set_delay(1.2)
	
	await tween_back.finished
	crescent_cogblade.hide()
	
	is_magic_attacking = false
	if hand_magic_tree:
		var pb = hand_magic_tree["parameters/playback"]
		if pb: pb.travel("idle")

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
		hand_with_pistol.visible = true
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
	GlobalUtils.shake_camera(0.015, 0.15)
	
	if is_instance_valid(blood_overlay):
		var mat = blood_overlay.material as ShaderMaterial
		mat.set_shader_parameter("multiplier", 0.4)
		var t = create_tween()
		t.tween_method(func(val): mat.set_shader_parameter("multiplier", val), 0.4, 0.0, 1.5).set_trans(Tween.TRANS_CUBIC)
	
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
		get_tree().change_scene_to_file("res://scenes/stages/prolog/fight_with_power/cutscene_fight_with_power.tscn")
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
