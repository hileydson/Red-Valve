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
	GlobalEvents.in_cutscene = false
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
			player.global_position = spawn_point.global_position
			player.global_rotation.y = spawn_point.global_rotation.y + PI

	var bloqueio = get_node_or_null("bloqueio_prologo_oficina_jimmy")
	if not bloqueio:
		bloqueio = find_child("bloqueio_prologo_oficina_jimmy", true, false)
	if bloqueio:
		bloqueio.queue_free()
		
	# Remove os inimigos imediatamente se ainda estiver no prólogo
	if not GlobalEvents.entering_chapter_1:
		var enemies_node = get_node_or_null("enemies")
		if not enemies_node:
			enemies_node = find_child("enemies", true, false)
		if enemies_node:
			enemies_node.queue_free()
		
	if not is_instance_valid(prompt_label):
		var center_container = CenterContainer.new()
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		prompt_label = Label.new()
		prompt_label.text = tr("PROMPT_ENTER_WORKSHOP")
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt_label.add_theme_font_size_override("font_size", 24)
		prompt_label.add_theme_constant_override("outline_size", 4)
		
		center_container.add_child(prompt_label)
		ui_layer.add_child(center_container)
		center_container.visible = false
		
		# Guardamos a referência ao container para poder ligar/desligar a visibilidade
		# Como o prompt_label é var, vamos sobrescrever o funcionamento usando a variável do prompt
		prompt_label.set_meta("container", center_container)
	
	# Inicia a exibição do texto introdutório
	_play_intro_text()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#real_time_label.text = "Time: "+str(sky_3d.game_time)
	
	if player_na_oficina and Input.is_action_just_pressed("ui_accept"):
		player_na_oficina = false
		if is_instance_valid(prompt_label):
			if prompt_label.has_meta("container"):
				prompt_label.get_meta("container").visible = false
			prompt_label.visible = false
		
		$fade.fade_out()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/stages/prolog/oficina_jimmy.tscn")


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
	if SaveManager.prolog_finished:
		return
	if body.name.to_lower() == "player" or body.is_in_group("player"):
		player_na_oficina = true
		if is_instance_valid(prompt_label):
			if prompt_label.has_meta("container"):
				prompt_label.get_meta("container").visible = true
			prompt_label.visible = true


func _on_area_3d_jimmy_house_body_exited(body: Node3D) -> void:
	if SaveManager.prolog_finished:
		return
	if body.name.to_lower() == "player" or body.is_in_group("player"):
		player_na_oficina = false
		if is_instance_valid(prompt_label):
			if prompt_label.has_meta("container"):
				prompt_label.get_meta("container").visible = false
			prompt_label.visible = false

func _play_intro_text() -> void:
	if GlobalEvents.entering_chapter_1:
		GlobalEvents.entering_chapter_1 = false
		# Exibe o título "CAPÍTULO 1" em vermelho bem grande no centro da tela (tamanho 120 como no splash)
		await get_tree().create_timer(1.0, false).timeout
		
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
		
		await get_tree().create_timer(3.5, false).timeout
		
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
	await get_tree().create_timer(1.5, false).timeout
	
	var intro_keys = [
		"NO_POWER_1_WALK_1", "NO_POWER_1_WALK_2", "NO_POWER_1_WALK_3", 
		"NO_POWER_1_WALK_4", "NO_POWER_1_WALK_5", "NO_POWER_1_WALK_6"
	]
	
	for key in intro_keys:
		GlobalUtils.show_center_message("intro_stage_1", tr(key), 18)
		await get_tree().create_timer(4.5, false).timeout
		GlobalUtils.hide_center_message("intro_stage_1")
		await get_tree().create_timer(0.5, false).timeout
