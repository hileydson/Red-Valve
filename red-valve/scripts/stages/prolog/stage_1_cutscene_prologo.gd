extends Node3D

var text_chunks = [
	["PROLOG_BEGIN_1_1", "PROLOG_BEGIN_1_2", "PROLOG_BEGIN_1_3", "PROLOG_BEGIN_1_4", "PROLOG_BEGIN_1_5"],
	["PROLOG_BEGIN_2_1"],
	["PROLOG_BEGIN_3_1", "PROLOG_BEGIN_3_2"],
	["PROLOG_BEGIN_4_1", "PROLOG_BEGIN_4_2", "PROLOG_BEGIN_4_3", "PROLOG_BEGIN_4_4"]
]

var current_chunk_index: int = 0
var current_text_index: int = 0
var text_tween: Tween
var is_transitioning: bool = false

# UI Elements
var ui_layer: CanvasLayer
var label: Label

# Cutscene Actors & Elements
var maycow_model: Node3D
var anim_player: AnimationPlayer
var cameras: Array[Camera3D] = []
var fade_node: Node
var rain_instance: Node3D

# Path variables
var start_pos: Vector3
var target_pos: Vector3
var dir: Vector3

func _ready() -> void:
	# 1. Hide/Disable the actual Player if it exists in the scene
	var real_player = find_child("Player", true, false)
	if real_player == null:
		real_player = find_child("player", true, false)
	if real_player:
		real_player.process_mode = Node.PROCESS_MODE_DISABLED
		real_player.visible = false
			
	# 2. Get the references to the buildings
	var jimmy = find_child("auto_pecas_jimmy*", true, false)
	var house = find_child("casa_inteira_por_fora*", true, false)
	
	if jimmy and house:
		start_pos = jimmy.global_position + Vector3(0, 0, 10) 
		target_pos = house.global_position + Vector3(0, 0, 5) 
	else:
		start_pos = Vector3(-10, 0, -10)
		target_pos = Vector3(10, 0, 10)
		
	dir = (target_pos - start_pos).normalized()

	# 3. Spawn Maycow
	var maycow_scene = load("res://assets/3d_model/player/Maycow Lopes/maycow_normal/maycow_normal_rigged.glb")
	if maycow_scene:
		maycow_model = maycow_scene.instantiate()
		add_child(maycow_model)
		maycow_model.global_position = start_pos
		maycow_model.look_at(target_pos, Vector3.UP)
		maycow_model.rotate_y(PI) # Gira 180 graus para consertar o modelo invertido
		
		anim_player = maycow_model.find_child("AnimationPlayer", true, false)
		if anim_player:
			var anim_list = anim_player.get_animation_list()
			var walk_anim = ""
			for a in anim_list:
				if "walk" in a.to_lower() or "andar" in a.to_lower():
					walk_anim = a
					break
			if walk_anim == "" and anim_list.size() > 0:
				walk_anim = anim_list[0]
			
			if walk_anim != "":
				anim_player.play(walk_anim)
				anim_player.speed_scale = 0.5 

	# 4. Load Rain Effect
	var rain_scene = load("res://scenes/effects/rain_effect.tscn")
	if rain_scene:
		rain_instance = rain_scene.instantiate()
		add_child(rain_instance)
		# Define o 'player' da chuva como o nosso modelo da cutscene para ela seguir ele
		rain_instance.player = maycow_model

	# 5. Create Cinematic Cameras
	_create_cinematic_cameras()
	
	# 6. Build UI for Texts
	_build_ui()
	
	# 7. Check for Fade node
	fade_node = find_child("fade", true, false)
	if not fade_node and has_node("fade"):
		fade_node = get_node("fade")
		
	Engine.time_scale = 0.6
	
	await get_tree().create_timer(1.0).timeout
	load_chunk()

func _create_cinematic_cameras():
	# Câmera 1: Parada na frente, vendo ele andar na direção dela
	var cam1 = Camera3D.new()
	add_child(cam1)
	cam1.global_position = start_pos + dir * 8.0 + Vector3(0, 1.5, 0)
	cam1.look_at(start_pos + Vector3(0, 1.0, 0), Vector3.UP)
	cameras.append(cam1)
	
	# Câmera 2: Vai andar junto do modelo (tracking side profile)
	var cam2 = Camera3D.new()
	add_child(cam2)
	cam2.global_position = start_pos + dir.cross(Vector3.UP).normalized() * 3.0 + dir * 1.5 + Vector3(0, 1.2, 0)
	cam2.look_at(start_pos + Vector3(0, 1.2, 0), Vector3.UP)
	cameras.append(cam2)
	
	# Câmera 3: De cima, seguindo ele
	var cam3 = Camera3D.new()
	add_child(cam3)
	cam3.global_position = start_pos + Vector3(0, 8.0, 0) - dir * 2.0
	cam3.look_at(start_pos, Vector3.UP)
	cameras.append(cam3)
	
	# Câmera 4: Perto da casa, vendo ele chegar (ângulo melhor)
	var cam4 = Camera3D.new()
	add_child(cam4)
	cam4.global_position = target_pos + dir * 4.0 + Vector3(2.0, 1.2, -1.0)
	cam4.look_at(target_pos - dir * 3.0, Vector3.UP)
	cameras.append(cam4)
	
	cam1.current = true

func _build_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)
	
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Estilo cinematográfico no meio da tela com texto grande
	label.add_theme_font_override("font", load("res://assets/fonts/Montserrat-ExtraBold.ttf"))
	label.add_theme_font_size_override("font_size", 54)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.add_theme_constant_override("shadow_outline_size", 8)
	label.modulate.a = 0.0
	
	ui_layer.add_child(label)
	
	var skip_ui = load("res://scripts/ui/skip_cutscene_ui.gd").new()
	ui_layer.add_child(skip_ui)
	skip_ui.skipped.connect(finish_cutscene)

func _process(delta: float) -> void:
	if maycow_model:
		# Mova o modelo a frente
		maycow_model.global_position += dir * 1.5 * delta
		
		# Movimentação dinâmica das câmeras
		if cameras.size() > 1 and cameras[1].current:
			# Segue o jogador de lado
			var side_offset = dir.cross(Vector3.UP).normalized() * 3.0
			var cam2_target = maycow_model.global_position + side_offset + dir * 1.5 + Vector3(0, 1.2, 0)
			cameras[1].global_position = cameras[1].global_position.lerp(cam2_target, delta * 3.0)
			cameras[1].look_at(maycow_model.global_position + Vector3(0, 1.2, 0), Vector3.UP)
			
		if cameras.size() > 2 and cameras[2].current:
			# Segue o jogador de cima
			var cam3_target = maycow_model.global_position + Vector3(0, 7.0, 0) - dir * 1.5
			cameras[2].global_position = cameras[2].global_position.lerp(cam3_target, delta * 2.0)
			cameras[2].look_at(maycow_model.global_position, Vector3.UP)
			
		if cameras.size() > 3 and cameras[3].current:
			# Câmera estática acompanhando ele chegando na casa
			cameras[3].look_at(maycow_model.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func load_chunk() -> void:
	if current_chunk_index >= text_chunks.size():
		finish_cutscene()
		return
		
	is_transitioning = true
	current_text_index = 0
	
	if current_chunk_index < cameras.size():
		for c in cameras:
			c.current = false
		cameras[current_chunk_index].current = true
		
	show_text()

func show_text() -> void:
	var chunk = text_chunks[current_chunk_index]
	if current_text_index < chunk.size():
		var text_key = chunk[current_text_index]
		label.text = tr(text_key)
		
		# Calcula tempo de leitura baseado no tamanho do texto
		var read_time = max(2.5, label.text.length() * 0.07)
		
		if text_tween: text_tween.kill()
		text_tween = create_tween()
		
		# Fade in
		label.modulate.a = 0.0
		text_tween.tween_property(label, "modulate:a", 1.0, 1.0)
		
		# Tempo de leitura
		text_tween.tween_interval(read_time)
		
		# Fade out
		text_tween.tween_property(label, "modulate:a", 0.0, 1.0)
		
		# Chama a próxima fala automaticamente
		text_tween.tween_callback(func():
			current_text_index += 1
			show_text()
		)
	else:
		next_chunk()

func next_chunk() -> void:
	is_transitioning = true
	current_chunk_index += 1
	load_chunk()

func finish_cutscene() -> void:
	if is_transitioning and current_chunk_index >= text_chunks.size(): return
	is_transitioning = true
	
	Engine.time_scale = 1.0
	if text_tween: text_tween.kill()
	
	var hide_tween = create_tween()
	hide_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	
	if fade_node and fade_node.has_method("fade_out"):
		fade_node.fade_out()
		
	await get_tree().create_timer(2.0).timeout
	LoadingScreen.load_scene("res://scenes/stages/prolog/the_house.tscn")
