extends Node3D

var text_chunks = [
	["PROLOG_BEGIN_1_1", "PROLOG_BEGIN_1_2", "PROLOG_BEGIN_1_3"],
	["PROLOG_BEGIN_1_4", "PROLOG_BEGIN_1_5", "PROLOG_BEGIN_2_1"],
	["PROLOG_BEGIN_3_1", "PROLOG_BEGIN_3_2", "PROLOG_BEGIN_4_1", "PROLOG_BEGIN_4_2"],
	["PROLOG_BEGIN_4_3", "PROLOG_BEGIN_4_4"]
]

var current_chunk_index: int = 0
var current_text_index: int = 0
var text_tween: Tween
var is_transitioning: bool = false
var cutscene_finished: bool = false

# UI Elements
var ui_layer: CanvasLayer
var label: Label
var cut_fade_rect: ColorRect
var title_label: Label
var title_active: bool = false

# Cutscene Actors & Elements
var maycow_model: Node3D
var anim_player: AnimationPlayer
var choque_audio: AudioStreamPlayer
var cameras: Array[Camera3D] = []
var fade_node: Node
var rain_instance: Node3D

# Path variables
var start_pos: Vector3
var target_pos: Vector3
var dir: Vector3

# Cinematic vars
var walk_time: float = 0.0
var cam2_base_pos: Vector3
var take2_time: float = 0.0
var cam4_rot_time: float = 0.0
var cam3_orbit_angle: float = 0.0

func _ready() -> void:
	# 1. Hide/Disable the actual Player if it exists in the scene
	var real_player = find_child("Player", true, false)
	if real_player == null:
		real_player = find_child("player", true, false)
	if real_player:
		real_player.process_mode = Node.PROCESS_MODE_DISABLED
		real_player.visible = false
		for canvas in real_player.find_children("*", "CanvasLayer", true, false):
			canvas.visible = false
			
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

	# 3. Spawn Maycow (Initially hidden)
	var maycow_scene = load("res://assets/3d_model/player/Maycow Lopes/maycow_normal/maycow_normal_rigged.glb")
	if maycow_scene:
		maycow_model = maycow_scene.instantiate()
		add_child(maycow_model)
		# Vai ficar escondido no "vazio" pro take 3
		maycow_model.global_position = Vector3(0, 10000, 0)
		maycow_model.rotation = Vector3(0, PI, 0)
		maycow_model.visible = false
		
		_fix_maycow_materials(maycow_model)
		
		anim_player = maycow_model.find_child("AnimationPlayer", true, false)
		if anim_player:
			var anim_list = anim_player.get_animation_list()
			var walk_anim = ""
			
			if anim_list.has("Walking"):
				walk_anim = "Walking"
			else:
				for a in anim_list:
					if "walk" in a.to_lower() or "andar" in a.to_lower():
						walk_anim = a
						break
			
			if walk_anim == "" and anim_list.size() > 0:
				walk_anim = anim_list[0]
			
			if walk_anim != "":
				anim_player.play(walk_anim)
				anim_player.speed_scale = 0.8 

	# 4. Load Rain Effect
	var rain_scene = load("res://scenes/effects/rain_effect.tscn")
	if rain_scene:
		rain_instance = rain_scene.instantiate()
		add_child(rain_instance)

	# 5. Create Cinematic Cameras
	_create_cinematic_cameras()
	
	choque_audio = AudioStreamPlayer.new()
	choque_audio.stream = load("res://assets/sounds/episodios/prologo/choque.mp3")
	add_child(choque_audio)
	
	# 6. Build UI for Texts
	_build_ui()
	
	# Reparent the cinematic black bars ('cutscene' Node2D) to our ui_layer 
	# so it renders above the rain (which is CanvasLayer 50)
	var cinematic_bars = find_child("cutscene", true, false)
	if not cinematic_bars and has_node("cutscene"):
		cinematic_bars = get_node("cutscene")
	if cinematic_bars:
		cinematic_bars.get_parent().remove_child(cinematic_bars)
		ui_layer.add_child(cinematic_bars)
	
	# 7. Check for Fade node
	fade_node = find_child("fade", true, false)
	if not fade_node and has_node("fade"):
		fade_node = get_node("fade")
		
	Engine.time_scale = 1.0 # Velocidade normal
	
	await get_tree().create_timer(1.0).timeout
	load_chunk()

func _fix_maycow_materials(node: Node):
	var tex = load("res://assets/3d_model/player/Maycow Lopes/maycow_normal/maycow_normal_rigged_texture_0.png")
	if tex:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_apply_material_recursive(node, mat)

func _apply_material_recursive(node: Node, mat: Material):
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _create_cinematic_cameras():
	# Câmera 1: Take da oficina (panorâmica girando devagar)
	var cam1 = Camera3D.new()
	add_child(cam1)
	cam1.global_position = start_pos + dir * 8.0 + Vector3(0, 2.5, 0)
	cam1.look_at(start_pos + Vector3(0, 2.0, 0), Vector3.UP)
	cameras.append(cam1)
	
	# Câmera 2: 1ª Pessoa simulando caminhada (head bobbing)
	var cam2 = Camera3D.new()
	add_child(cam2)
	cam2_base_pos = start_pos + dir * 2.0 + Vector3(0, -1.6, 0)
	cam2.global_position = cam2_base_pos
	cam2.look_at(target_pos + Vector3(0, -1.6, 0), Vector3.UP)
	cameras.append(cam2)
	
	# Câmera 3: Take 3ª pessoa acompanhando o Maycow
	var cam3 = Camera3D.new()
	add_child(cam3)
	cameras.append(cam3)
	
	# Câmera 4: Chão olhando para o céu (chuva caindo)
	var cam4 = Camera3D.new()
	add_child(cam4)
	cam4.global_position = target_pos - dir * 25.0 + Vector3(0, 0.2, 0)
	# Olha levemente pra frente e para o céu para vermos o chão de relance
	cam4.look_at(cam4.global_position + dir * 5.0 + Vector3(0, 2.5, 0), Vector3.UP)
	cameras.append(cam4)
	
	cam1.current = true

func _build_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)
	
	cut_fade_rect = ColorRect.new()
	cut_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cut_fade_rect.color = Color(0, 0, 0, 1)
	ui_layer.add_child(cut_fade_rect)
	
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Margens para não colar nas bordas
	label.offset_left = 60
	label.offset_right = -60
	label.offset_top = 40
	label.offset_bottom = -40
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	label.add_theme_font_override("font", load("res://assets/fonts/Montserrat-ExtraBold.ttf"))
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 6)
	label.modulate.a = 0.0
	
	ui_layer.add_child(label)
	
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.add_theme_font_override("font", load("res://assets/fonts/Montserrat-ExtraBold.ttf"))
	title_label.add_theme_font_size_override("font_size", 220)
	title_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25, 1.0)) # Cinza grafite
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.offset_top -= 150
	title_label.offset_bottom -= 150
	title_label.modulate.a = 0.0
	title_label.text = "RED VALVE"
	title_label.visible = false
	ui_layer.add_child(title_label)
	
	var skip_ui = load("res://scripts/ui/skip_cutscene_ui.gd").new()
	ui_layer.add_child(skip_ui)
	skip_ui.skipped.connect(finish_cutscene)

func _process(delta: float) -> void:
	if not maycow_model: return
	
	var cam1 = cameras[0]
	var cam2 = cameras[1]
	var cam3 = cameras[2]
	var cam4 = cameras[3]
	
	if cam1.current:
		# Movimento suave de pan na oficina
		cam1.global_position += (dir.cross(Vector3.UP).normalized() * 0.4) * delta
		cam1.look_at(start_pos + Vector3(0, 2.0, 0), Vector3.UP)
		
	elif cam2.current:
		take2_time += delta
		# 1ª Pessoa - Caminhada, head bobbing e olhando em volta
		walk_time += delta * 3.5 # velocidade dos passos
		cam2_base_pos += dir * 2.0 * delta
		var head_bob_y = sin(walk_time * 2.0) * 0.05
		var head_bob_x = cos(walk_time) * 0.03
		var right = dir.cross(Vector3.UP).normalized()
		cam2.global_position = cam2_base_pos + Vector3(0, head_bob_y, 0) + right * head_bob_x
		
		var current_dir = dir
		if take2_time > 6.0 and take2_time < 12.0:
			var t = 0.0
			if take2_time < 7.5:
				t = (take2_time - 6.0) / 1.5
			elif take2_time < 10.5:
				t = 1.0
			else:
				t = 1.0 - ((take2_time - 10.5) / 1.5)
			t = smoothstep(0.0, 1.0, t)
			var q_forward = Quaternion(Vector3.UP, 0)
			var q_back = Quaternion(Vector3.UP, PI * 0.95) # Quase 180 graus
			var q_current = q_forward.slerp(q_back, t)
			current_dir = q_current * dir
		
		# Simula olhar para a chuva e depois para a casa
		var look_target = cam2_base_pos + current_dir * 5.0
		# Dá uma leve levantada na cabeça para ver a chuva e desce depois
		var tilt = sin(walk_time * 0.25) * 0.6 
		look_target.y += tilt
		
		cam2.look_at(look_target, Vector3.UP)
		
	elif cam3.current:
		# 3ª Pessoa no ambiente - Caminhando e câmera girando suavemente para a direita
		cam3_orbit_angle += delta * 0.15
		maycow_model.global_position += maycow_model.transform.basis.z * 2.5 * delta
		var offset = Vector3(sin(cam3_orbit_angle) * 2.0, 1.2, cos(cam3_orbit_angle) * -1.5)
		var rotated_offset = offset.rotated(Vector3.UP, maycow_model.rotation.y)
		var cam3_target = maycow_model.global_position + rotated_offset
		cam3.global_position = cam3.global_position.lerp(cam3_target, delta * 5.0)
		cam3.look_at(maycow_model.global_position + Vector3(0, 1.2, 0), Vector3.UP)
		
	elif cam4.current:
		# Foco no céu/chuva girando levemente e parando
		cam4_rot_time += delta
		if cam4_rot_time < 3.0:
			cam4.rotate_z(0.015 * delta)
			
		# Camera indo para tras suavemente
		cam4.global_position -= dir * 0.5 * delta
		
		maycow_model.global_position += dir * 1.5 * delta

	if title_active and title_label:
		if randf() > 0.4:
			title_label.visible = true
			title_label.modulate.a = randf_range(0.01, 0.12)
		else:
			title_label.visible = false

func load_chunk() -> void:
	if current_chunk_index >= text_chunks.size():
		finish_cutscene()
		return
		
	is_transitioning = true
	current_text_index = 0
	
	if current_chunk_index == 1:
		take2_time = 0.0
		
	# Atualiza Câmera
	if current_chunk_index < cameras.size():
		for c in cameras:
			c.current = false
		cameras[current_chunk_index].current = true
		
		if rain_instance:
			rain_instance.player = cameras[current_chunk_index]
			# Ocultar a chuva no take 3 (vazio)
			rain_instance.visible = (current_chunk_index != 2)
		
	# Atualiza o estado do modelo
	if current_chunk_index == 2:
		maycow_model.visible = true
		maycow_model.global_position = cam2_base_pos + dir * 2.0
		maycow_model.global_position.y = cam2_base_pos.y - 0.5
		maycow_model.look_at(target_pos, Vector3.UP)
		maycow_model.rotate_y(PI)
		
		# Evitar que a cam3 voe da origem para o target rapidamente, inicializando-a na posicao certa
		cam3_orbit_angle = 0.0
		var offset = Vector3(sin(cam3_orbit_angle) * 2.0, 1.2, cos(cam3_orbit_angle) * -1.5)
		var rotated_offset = offset.rotated(Vector3.UP, maycow_model.rotation.y)
		cameras[2].global_position = maycow_model.global_position + rotated_offset
		cameras[2].look_at(maycow_model.global_position + Vector3(0, 1.2, 0), Vector3.UP)
		
		get_viewport().use_taa = true
	elif current_chunk_index == 3:
		get_viewport().use_taa = false
		# Mostra no take 4 de longe
		maycow_model.visible = true
		maycow_model.global_position = target_pos - dir * 4.0
		maycow_model.look_at(target_pos, Vector3.UP)
		maycow_model.rotate_y(PI)
	else:
		maycow_model.visible = false
		
	# Alterna o alinhamento do texto a cada take para dar dinamismo
	if current_chunk_index == 2:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		if current_chunk_index % 2 == 0:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
	# Fade in da cena (mantendo texto invisivel por enquanto)
	if cut_fade_rect:
		var t = create_tween()
		t.tween_property(cut_fade_rect, "modulate:a", 0.0, 1.0)
		t.tween_callback(show_text)
	else:
		show_text()

func show_text() -> void:
	var chunk = text_chunks[current_chunk_index]
	if current_text_index < chunk.size():
		var text_key = chunk[current_text_index]
		label.text = tr(text_key)
		
		# Textos mais lentos no geral
		var read_time = max(3.0, label.text.length() * 0.08)
		var fade_time = 0.8
		
		if current_chunk_index == 0:
			# Take 1: Bem menor
			read_time = max(1.5, label.text.length() * 0.05)
			fade_time = 0.4
		elif current_chunk_index == 2:
			# Take 3: Volta a ficar um pouco maior
			read_time = max(1.5, label.text.length() * 0.05)
			fade_time = 0.4
		elif current_chunk_index == 1:
			# Take 2: Tempo padrão, sem extensão exagerada
			pass
		
		if text_tween: text_tween.kill()
		text_tween = create_tween()
		
		# Fade in
		label.modulate.a = 0.0
		text_tween.tween_property(label, "modulate:a", 1.0, fade_time)
		
		# Dispara o glitch na última frase do take 4
		if current_chunk_index == 3 and current_text_index == chunk.size() - 1:
			text_tween.tween_callback(func(): 
				title_active = true
				if choque_audio: choque_audio.play()
			)
		
		# Tempo de leitura
		text_tween.tween_interval(read_time)
		
		# Fade out
		text_tween.tween_property(label, "modulate:a", 0.0, fade_time)
		
		# Pausa para o Take 4 e pro Take 3
		if current_chunk_index == 2 and current_text_index == chunk.size() - 1:
			text_tween.tween_interval(1.5) # Deixa somente um pouquinho depois da ultima frase
		elif current_chunk_index == 3 and current_text_index == chunk.size() - 1:
			text_tween.tween_interval(3.0) # Tempo extra na última frase antes de sumir tudo
		
		# Próxima fala
		text_tween.tween_callback(func():
			current_text_index += 1
			show_text()
		)
	else:
		next_chunk()

func next_chunk() -> void:
	if current_chunk_index >= text_chunks.size() - 1:
		finish_cutscene()
		return
		
	is_transitioning = true
	
	# Fade out da cena 3D (para a transicao)
	if cut_fade_rect:
		var t = create_tween()
		t.tween_property(cut_fade_rect, "modulate:a", 1.0, 1.0)
		t.tween_callback(func():
			current_chunk_index += 1
			load_chunk()
		)
	else:
		current_chunk_index += 1
		load_chunk()

func finish_cutscene() -> void:
	if cutscene_finished: return
	cutscene_finished = true
	is_transitioning = true
	
	if text_tween: text_tween.kill()
	
	var hide_tween = create_tween()
	hide_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	
	title_active = false
	if title_label:
		title_label.visible = false
		
	# Corta de vez (Black screen imediata)
	if cut_fade_rect:
		cut_fade_rect.modulate.a = 1.0
		
	if fade_node and fade_node.has_method("fade_out"):
		fade_node.fade_out()
	
	# Aguarda um tempinho antes de carregar a próxima cena
	await get_tree().create_timer(3.0).timeout
	LoadingScreen.load_scene("res://scenes/stages/prolog/the_house.tscn")


