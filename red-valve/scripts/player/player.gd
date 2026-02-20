extends CharacterBody3D

@onready var camera = $Camera3D # Certifique-se de que sua câmera se chama Camera3D
@onready var gun_load: AudioStreamPlayer = $sounds/GunLoad
@onready var gun_shot: AudioStreamPlayer = $sounds/GunShot
@onready var passos: AudioStreamPlayer = $sounds/Passos
@onready var pistola: AnimatedSprite2D = $Camera3D/CanvasLayer/control_weapons/pistola
@onready var faisca: GPUParticles3D = $Camera3D/faisca
@onready var fire: AnimatedSprite2D = $Camera3D/CanvasLayer/control_weapons/fire
@onready var shoot_light: OmniLight3D = $Camera3D/shoot_light
@onready var flash_tela: ColorRect = $Camera3D/CanvasLayer/control_weapons/flash_tela

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003 # Sensibilidade do mouse
const WALK_SPEED = 5.0
const RUN_SPEED = 8.5 # Velocidade maior para a corrida

var current_weapon: AnimatedSprite2D
var can_shoot_again:bool = true

func _ready():

	# Captura o mouse e o esconde ao iniciar o jogo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# a priori sera a pistola... mas precisa ter um change da arma para mudar 
	current_weapon = pistola

func _input(event):
	# Lógica de rotação da câmera
	if event is InputEventMouseMotion:
		# Gira o corpo do personagem no eixo Y (esquerda/direita)
		rotate_y(-event.relative.x * SENSITIVITY)
		
		# Gira apenas a câmera no eixo X (cima/baixo)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		
		# Trava a câmera para não girar 360 graus verticalmente (limitando a 80 graus)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# Adiciona gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# reload
	if Input.is_action_just_pressed("ui_reload"):
		reload()
	
	if Input.is_action_just_pressed("ui_shoot"):
		shoot()
	
	# --- LÓGICA DE VELOCIDADE (CORRIDA) ---
	var velocidade_atual = WALK_SPEED
	if Input.is_action_pressed("ui_run"): # Use 'pressed' para manter a corrida enquanto segura
		velocidade_atual = RUN_SPEED

	# Movimentação
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		# Se estiver correndo, podemos aumentar o pitch do som dos passos para parecer mais rápido
		if Input.is_action_pressed("ui_run"):
			passos.pitch_scale = 1.2 # Som mais rápido
		else:
			passos.pitch_scale = 1.0 # Som normal
			
		if !passos.playing: 
			passos.play()
			
		velocity.x = direction.x * velocidade_atual
		velocity.z = direction.z * velocidade_atual
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade_atual)
		velocity.z = move_toward(velocity.z, 0, velocidade_atual)
		if passos.playing:
			passos.stop() # Para o som quando parar de andar

	move_and_slide()

#
func reload():
	if current_weapon.animation != "reload":
		if not is_instance_valid(current_weapon): return

		var tween = create_tween()
		current_weapon.play("reload")
		gun_load.play()
		tween.tween_interval(0.1)
		tween.tween_property(current_weapon, "rotation_degrees", 15.0, 0.15).set_trans(Tween.TRANS_SINE)
		tween.tween_interval(0.8)
		# Volta para o zero
		tween.tween_property(current_weapon, "rotation_degrees", 8.4, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func shoot():
	if current_weapon.animation != "shoot" and can_shoot_again:
		if not is_instance_valid(current_weapon): return

		var rotation_default = current_weapon.rotation

		var tween = create_tween()
		current_weapon.play("shoot")
		fire.play("shoot")
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
		tween.tween_property(current_weapon, "rotation_degrees", 3.0, 0.05).set_trans(Tween.TRANS_SINE)
		
		# Move para trás (X) e um pouco para cima (Y) AO MESMO TEMPO
		# Ajuste os valores (ex: 10 ou -10) conforme a posição da sua arma na tela
		tween.parallel().tween_property(current_weapon, "position:x", current_weapon.position.x + 10, 0.05).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(current_weapon, "position:y", current_weapon.position.y - 5, 0.05).set_trans(Tween.TRANS_SINE)

		tween.tween_interval(0.1)

		# --- VOLTA PARA A POSIÇÃO PADRÃO ---
		# Usamos TRANS_BACK para dar aquele efeito de mola realista no encaixe
		tween.tween_property(current_weapon, "rotation_degrees", 8.4, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		current_weapon.rotation = rotation_default
		# Volta a posição X e Y originais
		# DICA: É melhor salvar a posição inicial da arma numa variável se você for usar muito isso
		tween.parallel().tween_property(current_weapon, "position:x", current_weapon.position.x, 0.1).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(current_weapon, "position:y", current_weapon.position.y, 0.1).set_trans(Tween.TRANS_BACK)
		
		await get_tree().create_timer(0.56).timeout
		can_shoot_again = true

func _on_pistola_animation_finished() -> void:
	current_weapon.play("idle")
