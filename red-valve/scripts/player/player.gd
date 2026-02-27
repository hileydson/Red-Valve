extends CharacterBody3D

@onready var camera = $Camera3D # Certifique-se de que sua câmera se chama Camera3D
@onready var camera_third_person: Camera3D = $camera_third_person
@onready var camera_third_person_marker: Marker3D = $camera_third_person_marker
@onready var camera_first_person_marker: Marker3D = $camera_first_person_marker

@onready var gun_load: AudioStreamPlayer = $sounds/GunLoad
@onready var gun_shot: AudioStreamPlayer = $sounds/GunShot
@onready var passos: AudioStreamPlayer = $sounds/Passos
@onready var pistola: AnimatedSprite2D = $Camera3D/CanvasLayer/control_weapons/pistola
@onready var faisca: GPUParticles3D = $Camera3D/faisca
@onready var fire: AnimatedSprite2D = $Camera3D/CanvasLayer/control_weapons/fire
@onready var bullet_light: OmniLight3D = $Camera3D/Camera3D_Bullet_Time/bullet_light
@onready var flash_tela: ColorRect = $Camera3D/CanvasLayer/control_weapons/flash_tela
@onready var ray_cast_3d: RayCast3D = $Camera3D/RayCast3D
@onready var magic_hand: AnimatedSprite2D = $Camera3D/CanvasLayer/control_magic/magic_hand
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
@onready var point: Label = $Camera3D/point

var blood_effect = preload("res://scenes/enemies/blood.tscn")

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003 # Sensibilidade do mouse
@export var WALK_SPEED = 4.0
@export var RUN_SPEED = 7.5 # Velocidade maior para a corrida

#CHANGE LATER - DYNAMICLY
@export var damage_crescent_cogblade:int = 14
@export var damage_pistol:int = 10 #3 
@export var damage_headshoot:int = 100
var current_weapon: AnimatedSprite2D
var can_shoot_again:bool = true

#ORIGINAL POSITION FOR THE LEFT HAND
var magic_hand_pos_original
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
	camera_third_person.make_current()
	point.visible = false
	
	

func _input(event):
	#se estiver no bullet time sai vazado pra nao interferir no movimento da camera
	if camera_bullet_time_ON or magic_hand.animation =="attack":
		return
	
	# Lógica de rotação da câmera
	# No seu script de Input de Mouse:
	var camera_atual = get_viewport().get_camera_3d()

	if event is InputEventMouseMotion:
		# Gira o corpo do personagem no eixo Y (esquerda/direita)
		rotate_y(-event.relative.x * SENSITIVITY)
		
		# Gira apenas a câmera no eixo X (cima/baixo)
		camera_atual.rotate_x(-event.relative.y * SENSITIVITY)
		
		# Trava a câmera para não girar 360 graus verticalmente (limitando a 80 graus)
		#olhar pra baixo travado pra terceira pessoa
		var value_look_down = -80
		var value_look_up = 80
		if camera_atual == camera_third_person: 
			value_look_down = -10
			value_look_up = 20
		camera_atual.rotation.x = clamp(camera_atual.rotation.x, deg_to_rad(value_look_down), deg_to_rad(value_look_up))


# Adicione estas variáveis no topo do script (fora do _process) se ainda não tiver
var hold_timer: float = 0.0
var hold_threshold: float = 0.15 # 200 milisegundos para confirmar o "segurar"
func _physics_process(delta: float) -> void:
	
	# muda pra primeira pessoa
	# Lógica do Cronômetro para o botão
	if Input.is_action_pressed("ui_hold_first_person_view"):
		hold_timer += delta
	else:
		hold_timer = 0.0 # Reset instantâneo ao soltar

	# Só consideramos "holding" se o tempo passar do limite
	var holding_view = hold_timer >= hold_threshold

	if holding_view and !is_first_person:
		# MUDANDO PARA PRIMEIRA PESSOA
		is_first_person = true
		transicao_camera(camera_third_person, camera, camera_first_person_marker, true)

	elif !holding_view and is_first_person:
		# VOLTANDO PARA TERCEIRA PESSOA
		is_first_person = false
		transicao_camera(camera, camera_third_person, camera_third_person_marker, false)
		
	
	#mostra sempre o point quando em primeira pessoa
	if is_first_person:
		point.visible = true
	else:
		point.visible = false
	
	#paralisa jogador enquanto tiver fazendo o magic attack
	if magic_hand.animation =="attack":
		return 
	
	# Adiciona gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and !holding_view:
		velocity.y = JUMP_VELOCITY
		playback.travel("jump")
		
	# reload
	if Input.is_action_just_pressed("ui_reload") and !transition_camera:
		reload()
	
	if pistola.animation!="reload" and Input.is_action_just_pressed("ui_shoot") and !transition_camera:
		shoot()
	
	if magic_hand.animation == "idle" and Input.is_action_just_pressed("ui_magic_attack") and !transition_camera and camera.current:
		magic_hand_attack()
		
	
	#se estiver no bullet time sai vazado pra nao interferir no movimento da camera
	if camera_bullet_time_ON:
		return
	
	# --- LÓGICA DE VELOCIDADE (CORRIDA) ---
	var velocidade_atual = WALK_SPEED
	if Input.is_action_pressed("ui_run"): # Use 'pressed' para manter a corrida enquanto segura
		velocidade_atual = RUN_SPEED

	# Movimentação
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and !transition_camera:
		# Se estiver correndo, podemos aumentar o pitch do som dos passos para parecer mais rápido
		if Input.is_action_pressed("ui_run"):
			if pistola.animation!="reload" and pistola.animation!="run":pistola.play("run")
			passos.pitch_scale = 1.42 # Som mais rápido
			if playback.get_current_node() != "jump": playback.travel("run")
		else:
			if pistola.animation!="reload" and pistola.animation!="walk":pistola.play("walk")
			passos.pitch_scale = 0.924 # Som normal
			if playback.get_current_node() != "jump": playback.travel("walk")
			
		if !passos.playing: passos.play()
			
		velocity.x = direction.x * velocidade_atual
		velocity.z = direction.z * velocidade_atual
	else:
		if playback.get_current_node() != "jump": playback.travel("idle")
		velocity.x = move_toward(velocity.x, 0, velocidade_atual)
		velocity.z = move_toward(velocity.z, 0, velocidade_atual)
		if passos.playing:
			passos.stop() # Para o som quando parar de andar

	move_and_slide()


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
		)
	
	
	
	
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

func magic_hand_attack():
	# 1. ANIMAÇÃO DA MÃO (2D)
	slay_it.play()
	magic_hand.play("attack")
	blade_out.play()
	var tween_magic = create_tween().set_parallel(true)
	
	var pos_alvo_mao = magic_hand_pos_original + Vector2(60, -235)
	tween_magic.tween_property(magic_hand, "position", pos_alvo_mao, 0.4)\
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
	
	# Volta a mão
	tween_back.tween_property(magic_hand, "position", magic_hand_pos_original, 0.5)\
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
	magic_hand.play("idle")

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
	
func shoot():
	if current_weapon.animation != "shoot" and can_shoot_again and camera.current:
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
					control_magic.visible = false
					bullet_light.visible = true
					bullet.visible = true
					camera_bullet_time_ON = true
					GlobalUtils.ativar_camera_lenta(0.1, 60.0)
					AudioServer.set_playback_speed_scale(0.2)
					
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
			
				
		await get_tree().create_timer(0.56).timeout
		can_shoot_again = true

func bullet_time_back():	
	camera_bullet_time_ON = false
	bullet.visible = false
	AudioServer.set_playback_speed_scale(1.0)
	GlobalUtils.remover_camera_lenta()
	
	if is_first_person:
		camera.make_current()
		control_weapons.visible = true
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
	print("Damage taken by the player: "+str(number))
	
	
func _on_pistola_animation_finished() -> void:
	current_weapon.play("idle")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if magic_hand.animation == "attack":
		blade_in.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5) # Velocidade 20% por meio segundo
		body.take_damage(damage_crescent_cogblade)
	

func _on_area_3d_body_exited(body: Node3D) -> void:
	if magic_hand.animation == "attack":
		blade_back.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5) # Velocidade 20% por meio segundo
		body.take_damage(damage_crescent_cogblade)


func _on_bullet_touch_body_entered(body: Node3D) -> void:
	#bullet_time_back()
	bullet.visible = false
	#bullet_light.visible = false
	spawn_blood_effect(body)
