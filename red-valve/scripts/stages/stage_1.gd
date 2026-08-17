extends Node3D

@onready var navigation_region_3d: NavigationRegion3D = $NavigationRegion3D
@onready var real_time_label: Label = $real_time_label
@onready var sky_3d: Sky3D = $WorldEnvironment/Sky3D

var player_na_oficina: bool = false
var prompt_label: Label
var intro_label: Label
var ui_layer: CanvasLayer

var rain_scene = preload("res://scenes/effects/rain_effect.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_instance_valid(real_time_label):
		real_time_label.queue_free()
	SaveManager.save_game()
	GlobalEvents.set_low_nevoa()
	GlobalEvents.is_maycow_normal = true
	#$cameras/camera_1.make_current()
	
	# --- INICIA A CHUVA E ATMOSFERA PESADA ---
	var rain = rain_scene.instantiate()
	add_child(rain)
	
	# Escurecer o ambiente e aumentar a névoa para o clima de tempestade
	var env_node = get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var env = env_node.environment
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.015
		env.volumetric_fog_albedo = Color(0.3, 0.35, 0.4)
		
		env.fog_enabled = true
		env.fog_density = 0.005
		env.fog_light_color = Color(0.2, 0.25, 0.3)
		
		# Reduz levemente a luz ambiente
		env.ambient_light_energy = 0.6
	
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 128
	add_child(ui_layer)
	setup_player_spawn()

func setup_player_spawn() -> void:
	if GlobalEvents.entering_chapter_1:
		var spawn_point = get_node_or_null("itens_caminho_jimmy/auto_pecas_jimmy/maykow_capitulo_1_inicio")
		var player = get_node_or_null("Player")
		if player and spawn_point:
			player.global_transform.origin = spawn_point.global_transform.origin

	prompt_label = Label.new()
	prompt_label.text = tr("PROMPT_ENTER_WORKSHOP")
	prompt_label.visible = false
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_constant_override("outline_size", 4)
	ui_layer.add_child(prompt_label)
	
	intro_label = Label.new()
	intro_label.text = ""
	intro_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	intro_label.add_theme_font_size_override("font_size", 18)
	intro_label.add_theme_constant_override("outline_size", 5)
	intro_label.modulate.a = 0.0
	ui_layer.add_child(intro_label)
	
	# Inicia a exibição do texto introdutório
	_play_intro_text()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#real_time_label.text = "Time: "+str(sky_3d.game_time)
	
	if player_na_oficina and Input.is_action_just_pressed("ui_accept"):
		player_na_oficina = false
		prompt_label.visible = false
		
		$fade.fade_out()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/stages/prolog/cutscene_fight_no_power.tscn")


func _on_timer_timeout() -> void:
	pass #navigation_region_3d.bake_navigation_mesh(true)


func _on_camera_1_area_shape_entered(area_rid: RID, area: Area3D, area_shape_index: int, local_shape_index: int) -> void:
	print("camera 1")
	#$cameras/camera_1.make_current()


func _on_camera_2_body_entered(body: Node3D) -> void:
	print(body)
	print("camera 2")
	#$cameras/camera_2.make_current()


func _on_area_3d_jimmy_house_body_entered(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_na_oficina = true
		prompt_label.visible = true


func _on_area_3d_jimmy_house_body_exited(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_na_oficina = false
		prompt_label.visible = false

func _play_intro_text() -> void:
	if GlobalEvents.entering_chapter_1:
		GlobalEvents.entering_chapter_1 = false
		# Exibe o título "CAPÍTULO 1" em vermelho bem grande no centro da tela (tamanho 120 como no splash)
		await get_tree().create_timer(1.0).timeout
		
		var chapter_label = Label.new()
		chapter_label.text = tr("TXT_CHAPTER_1").to_upper()
		chapter_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chapter_label.add_theme_font_size_override("font_size", 180)
		chapter_label.add_theme_color_override("font_color", Color(0.705882, 0.0, 0.0))
		
		var custom_font = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
		if custom_font:
			chapter_label.add_theme_font_override("font", custom_font)
			
		ui_layer.add_child(chapter_label)
		
		chapter_label.modulate.a = 0.0
		var tween_in = create_tween()
		tween_in.tween_property(chapter_label, "modulate:a", 1.0, 1.0)
		await tween_in.finished
		
		await get_tree().create_timer(3.5).timeout
		
		if is_instance_valid(chapter_label):
			var tween_out = create_tween()
			tween_out.tween_property(chapter_label, "modulate:a", 0.0, 1.0)
			await tween_out.finished
			chapter_label.queue_free()
		return

	if GlobalEvents.get("has_seen_stage_1_intro") == true:
		return
	GlobalEvents.set("has_seen_stage_1_intro", true)
	
	# Pequena pausa antes de começar para não ser tão brusco
	await get_tree().create_timer(1.5).timeout
	
	var intro_keys = [
		"NO_POWER_1_WALK_1", "NO_POWER_1_WALK_2", "NO_POWER_1_WALK_3", 
		"NO_POWER_1_WALK_4", "NO_POWER_1_WALK_5", "NO_POWER_1_WALK_6"
	]
	
	for key in intro_keys:
		if not is_instance_valid(intro_label):
			return
			
		intro_label.text = tr(key)
		intro_label.modulate.a = 0.0
		
		var tween_in = create_tween()
		tween_in.tween_property(intro_label, "modulate:a", 1.0, 0.5)
		await tween_in.finished
		
		# Mantém a frase na tela por 4 segundos
		await get_tree().create_timer(4.0).timeout
		
		if not is_instance_valid(intro_label):
			return
			
		var tween_out = create_tween()
		tween_out.tween_property(intro_label, "modulate:a", 0.0, 0.5)
		await tween_out.finished
		
		# Pequena pausa entre uma frase e outra
		await get_tree().create_timer(0.5).timeout
