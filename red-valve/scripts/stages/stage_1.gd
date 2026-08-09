extends Node3D

@onready var navigation_region_3d: NavigationRegion3D = $NavigationRegion3D
@onready var real_time_label: Label = $real_time_label
@onready var sky_3d: Sky3D = $WorldEnvironment/Sky3D

var player_na_oficina: bool = false
var prompt_label: Label
var intro_label: Label
var ui_layer: CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalEvents.set_low_nevoa()
	GlobalEvents.is_maycow_normal = true
	#$cameras/camera_1.make_current()
	
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 128
	add_child(ui_layer)
	
	prompt_label = Label.new()
	prompt_label.text = tr("PROMPT_ENTER_WORKSHOP")
	prompt_label.visible = false
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_constant_override("outline_size", 4)
	ui_layer.add_child(prompt_label)
	
	intro_label = Label.new()
	intro_label.text = ""
	intro_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	intro_label.add_theme_font_size_override("font_size", 28)
	intro_label.add_theme_constant_override("outline_size", 5)
	intro_label.modulate.a = 0.0
	ui_layer.add_child(intro_label)
	
	# Inicia a exibição do texto introdutório
	_play_intro_text()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	real_time_label.text = "Time: "+str(sky_3d.game_time)
	
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
