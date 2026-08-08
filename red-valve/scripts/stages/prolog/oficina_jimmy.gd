extends Node3D

@onready var camera_oficina: Camera3D = $camera_oficina
@onready var player = $Player
@onready var enemy = $TheCobaltHusker
@onready var pecas = $pecas
@onready var fade = $fade

var look_at_target: Node3D = null
var look_at_offset: Vector3 = Vector3(0, 1.5, 0)

func _ready() -> void:
	GlobalEvents.is_maycow_normal = true
	
	# === 1. PREPARAÇÃO DA CUTSCENE ===
	camera_oficina.make_current()
	
	# Usamos process_mode = DISABLED em vez de set_physics_process para ter certeza absoluta 
	# que o player não vai andar, mesmo que os scripts internos dele tentem ligar a física de novo
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	if enemy:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if pecas:
		pecas.process_mode = Node.PROCESS_MODE_DISABLED
		
	# Inicia o filme
	iniciar_cutscene()

func _process(delta: float) -> void:
	# A câmera sempre olha fixamente para o alvo atual
	if look_at_target:
		camera_oficina.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)
		
	# Avança as animações manualmente já que os scripts e físicas estão pausados
	if player and player.process_mode == Node.PROCESS_MODE_DISABLED:
		# Player se move em velocidade normal (idle)
		var pt1 = player.get_node_or_null("maycow_lopes_normal/AnimationTree")
		var pt2 = player.get_node_or_null("maycow_lopes/AnimationTree")
		if pt1 and pt1.active: pt1.advance(delta)
		if pt2 and pt2.active: pt2.advance(delta)
		
	if enemy and enemy.process_mode == Node.PROCESS_MODE_DISABLED:
		# Inimigo se move em câmera lenta (15% da velocidade)
		var et = enemy.get_node_or_null("enemy/enemy_model/AnimationTree")
		if et and et.active: et.advance(delta * 0.15)

func iniciar_cutscene() -> void:
	if not enemy or not player:
		return
		
	# Espera inicial para o fade_in e estabilizar a engine
	await get_tree().create_timer(1.0).timeout
	# Reforça a câmera caso o script do player tenha tentado roubar o foco atrasado
	camera_oficina.make_current() 
	
	var enemy_pos = enemy.global_position
	var player_pos = player.global_position
	
	# ---------------------------------------------------------
	# FASE 1: Inicia focando o Player de frente
	# ---------------------------------------------------------
	look_at_target = player
	
	# Pega a direção para onde o player está olhando (o vetor -Z no Godot)
	var player_forward = -player.global_transform.basis.z.normalized()
	if player_forward.length() < 0.1: player_forward = Vector3.FORWARD
	
	# Coloca a câmera de frente pro player (2.5 metros na frente do rosto)
	var camera_start_pos = player_pos + Vector3(0, 1.5, 0) + (player_forward * 2.5)
	camera_oficina.global_position = camera_start_pos
	
	# Dá um tempinho de 1.5 segundos admirando o player no começo do jogo
	await get_tree().create_timer(1.5).timeout
	
	# ---------------------------------------------------------
	# FASE 2: Câmera viaja até o Inimigo (com Efeito de Zoom)
	# ---------------------------------------------------------
	look_at_target = enemy
	
	var pivot = Node3D.new()
	pivot.global_position = enemy_pos + Vector3(0, 1.5, 0)
	add_child(pivot)
	
	var dir_to_enemy = (pivot.global_position - camera_oficina.global_position).normalized()
	# Posição de chegada: uns 3.5 metros do inimigo para focar bem nele
	var orbit_start_pos = pivot.global_position - (dir_to_enemy * 3.5)
	
	var travel_tween = create_tween().set_parallel(true)
	travel_tween.tween_property(camera_oficina, "global_position", orbit_start_pos, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Faz um "zoom in" abaixando o campo de visão (FOV) da câmera para dar um ar cinematográfico
	travel_tween.tween_property(camera_oficina, "fov", 50.0, 3.0).set_trans(Tween.TRANS_SINE)
	await travel_tween.finished
	
	# ---------------------------------------------------------
	# FASE 3: Orbita 360 graus envolta do inimigo
	# ---------------------------------------------------------
	var cam_transform = camera_oficina.global_transform
	camera_oficina.get_parent().remove_child(camera_oficina)
	pivot.add_child(camera_oficina)
	camera_oficina.global_transform = cam_transform
	camera_oficina.make_current() # Impede roubo de câmera
	
	var orbit_tween = create_tween()
	orbit_tween.tween_property(pivot, "rotation:y", PI * 2, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await orbit_tween.finished
	
	# ---------------------------------------------------------
	# FASE 4: Volta voando para o Player (Mais de perto e baixo)
	# ---------------------------------------------------------
	look_at_target = player
	
	cam_transform = camera_oficina.global_transform
	pivot.remove_child(camera_oficina)
	add_child(camera_oficina)
	camera_oficina.global_transform = cam_transform
	camera_oficina.make_current() # Impede roubo de câmera
	
	var return_tween = create_tween().set_parallel(true)
	# Posição final: de frente pro player, mais baixo (Y=1.0) e bem mais perto (1.5m)
	var final_pos = player_pos + Vector3(0, 1.0, 0) + (player_forward * 1.5)
	return_tween.tween_property(camera_oficina, "global_position", final_pos, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Mais zoom no player
	return_tween.tween_property(camera_oficina, "fov", 45.0, 2.5).set_trans(Tween.TRANS_SINE)
	await return_tween.finished
	
	# ---------------------------------------------------------
	# FASE 5: Fim do Filme (Fade Out e retoma controle)
	# ---------------------------------------------------------
	if fade:
		fade.fade_out()
		await get_tree().create_timer(1.5).timeout
		
	pivot.queue_free()
	look_at_target = null
	
	# Restaura controles e inteligência artificial soltando os processos base
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		# A câmera padrão de combate é a third_person, não a genérica
		var player_cam = player.get_node_or_null("SpringArm3D/camera_third_person")
		if not player_cam:
			player_cam = player.get_node_or_null("Camera3D")
			
		if player_cam:
			player_cam.make_current()
			
	if pecas:
		pecas.process_mode = Node.PROCESS_MODE_INHERIT
		
	if enemy:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		
	if fade:
		fade.fade_in()
		
	camera_oficina.queue_free()
