extends CharacterBody3D

@onready var camera = $Camera3D # Certifique-se de que sua câmera se chama Camera3D
@onready var pistola: AnimatedSprite2D = $CanvasLayer/control_weapons/pistola
@onready var gun_load: AudioStreamPlayer = $sounds/GunLoad
@onready var gun_shot: AudioStreamPlayer = $sounds/GunShot
@onready var passos: AudioStreamPlayer = $sounds/Passos

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003 # Sensibilidade do mouse
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
	
	#testrwadwad
	if current_weapon:
		print(current_weapon.rotation)
		
		
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

	# Movimentação
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# transform.basis garante que "frente" seja para onde você está olhando
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		print("andando")
		if !passos.playing: passos.play()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

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
		gun_shot.play()
		can_shoot_again = false
		
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
