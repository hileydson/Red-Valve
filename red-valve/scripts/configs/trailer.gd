extends Node3D

@export var inicio: Marker3D
@export var fim: Marker3D
var ui_fader: ColorRect

func _enter_tree() -> void:
	# 0. Garante que o modelo poderoso NÃO seja deletado no _ready do player
	GlobalEvents.is_maycow_normal = false

func _ready() -> void:
	# Cria a tela preta de Fade In/Out
	ui_fader = ColorRect.new()
	ui_fader.color = Color(0, 0, 0, 1)
	ui_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_fader.modulate.a = 0.0 # Começa transparente
	
	var canvas = CanvasLayer.new()
	canvas.layer = 120 # Fica acima de todas as outras HUDs
	canvas.add_child(ui_fader)
	add_child(canvas)

	# Se os markers não tiverem sido assinalados pelo inspector, procura em toda a cena
	if not inicio:
		inicio = get_tree().current_scene.find_child("inicio", true, false) as Marker3D
	if not fim:
		fim = get_tree().current_scene.find_child("fim", true, false) as Marker3D
		
	# MATA qualquer AnimationPlayer antigo que esteja rodando e roubando a câmera!
	var anim_player = get_tree().current_scene.find_child("AnimationPlayer", true, false)
	if anim_player and anim_player is AnimationPlayer:
		anim_player.stop()
		anim_player.active = false
		
	# Chama a sequência
	cutscene_trailer_sequence()

func cutscene_trailer_sequence() -> void:
	print("--- CUTSCENE TRAILER INICIADA ---")
	if not inicio or not fim:
		push_error("ERRO CRITICO: Markers 'inicio' e 'fim' não encontrados! Crie-os na cena.")
		print("FALHOU: Markers nulos!")
		return
		
	var players = get_tree().get_nodes_in_group("player")
	var player = null
	
	if players.is_empty(): 
		print("Nenhum player encontrado na cena. Instanciando automaticamente!")
		var player_scene = load("res://scenes/player/player.tscn")
		if player_scene:
			player = player_scene.instantiate()
			add_child(player)
		else:
			push_error("Não foi possível carregar a cena do player!")
			return
	else:
		player = players[0]
		
	print("Player pronto: ", player.name)
	
	# 1. PREPARAÇÃO
	print("1. Forçando modelo maycow_lopes...")
	cutscene_force_maycow_lopes_only()
	print("Desativando hud e controle...")
	player.cutscene_set_hud_enabled(false)
	player.cutscene_set_player_control(false)
	player.cutscene_set_camera_current(false)
	
	print("Posicionando player no INICIO...")
	player.global_position = inicio.global_position + Vector3(0, 1.0, 0)
	var target_pos = fim.global_position
	target_pos.y = player.global_position.y
	player.look_at(target_pos, Vector3.UP)
	
	# 2. CÂMERA DE COSTAS E CAMINHAR
	print("2. Criando câmera de COSTAS...")
	var cam_costas = Camera3D.new()
	player.add_child(cam_costas)
	cam_costas.position = Vector3(0, 1.8, 3.5)
	cam_costas.rotation_degrees = Vector3(-10, 0, 0)
	cam_costas.make_current()
	
	print("Ativando auto walk...")
	player.cutscene_set_auto_walk(true)
	
	print("Esperando 3 segundos...")
	await get_tree().create_timer(3.0).timeout
	print("... 3 segundos passaram!")
	
	# 3. CÂMERA DE CIMA
	print("3. Criando câmera de CIMA...")
	var cam_cima = Camera3D.new()
	player.add_child(cam_cima)
	cam_cima.position = Vector3(0, 8.0, 0)
	cam_cima.rotation_degrees = Vector3(-90, 0, 0)
	cam_cima.make_current()
	
	print("Esperando 3 segundos...")
	await get_tree().create_timer(3.0).timeout
	print("... 3 segundos passaram!")
	
	# 4. PRIMEIRA PESSOA
	print("4. Criando câmera de PRIMEIRA PESSOA (FPS)...")
	var cam_fps = Camera3D.new()
	player.add_child(cam_fps)
	cam_fps.position = Vector3(0, 1.6, 0)
	cam_fps.make_current()
	
	print("Ocultando modelo...")
	var model = player.get_node_or_null("maycow_lopes")
	if model:
		model.visible = false
		
	print("Reativando hud e desativando partes visuais...")
	player.cutscene_set_hud_enabled(true)
	if "stamina_bar" in player and is_instance_valid(player.stamina_bar): player.stamina_bar.visible = false
	if "control_weapons" in player and is_instance_valid(player.control_weapons): player.control_weapons.visible = false
	if "point" in player and is_instance_valid(player.point): player.point.visible = false
	if "blood_overlay" in player and is_instance_valid(player.blood_overlay): player.blood_overlay.visible = false
	if "mp_bar" in player and is_instance_valid(player.mp_bar): player.mp_bar.visible = false
	if "heartbeat_hud" in player and is_instance_valid(player.heartbeat_hud): player.heartbeat_hud.visible = false
	
	print("Aplicando motion blur e mudando para auto_run...")
	player.cutscene_set_motion_blur(20)
	player.cutscene_set_auto_walk(false)
	player.cutscene_set_auto_run(true)
	
	print("Esperando 3 segundos...")
	await get_tree().create_timer(3.0).timeout
	print("... 3 segundos passaram!")
	
	# 5. VELOCIDADE EXTREMA ATÉ O MARCADOR FIM
	print("5. Iniciando velocidade EXTREMA até o FIM...")
	player.cutscene_set_auto_run(false)
	player.cutscene_set_motion_blur(100)
	
	var tempo_sprint = 1.0 
	var tween_corrida = create_tween()
	tween_corrida.tween_property(player, "global_position", fim.global_position, tempo_sprint).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await tween_corrida.finished
	print("Fim da corrida extrema alcançado!")
	
	# 6. FADE OUT RÁPIDO AO CHEGAR
	print("6. Iniciando Fade Out...")
	var tween_fade = create_tween()
	tween_fade.tween_property(ui_fader, "modulate:a", 1.0, 0.4)
	
	await tween_fade.finished
	print("--- CUTSCENE TRAILER FINALIZADA ---")


func cutscene_force_maycow_lopes_only() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		
		for child in player.get_children():
			if child is Node3D and "visible" in child:
				# Ignorar câmeras e colisões/springarms para não quebrar o jogo
				if child is Camera3D or child is SpringArm3D or child is Marker3D or child is CollisionShape3D:
					continue
				
				# Deixa apenas o maycow_lopes visível e esconde os outros (incluindo braços e o normal)
				if child.name == "maycow_lopes":
					child.visible = true
				elif child.name == "maycow_lopes_normal" or "hand" in child.name.to_lower() or child is MeshInstance3D:
					child.visible = false
