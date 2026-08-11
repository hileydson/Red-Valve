extends Node3D

@onready var start: Button = $Control/VBoxContainer/start
@onready var load_btn: Button = $Control/VBoxContainer/load
@onready var timer: Timer = $Timer_flick
@onready var red_valve: Sprite2D = $VideoStreamPlayer/RedValveSpriteNoBackground
@onready var timer_play_animation_label: Timer = $Timer_play_animation_label
@onready var red_valve_animation: AnimatedSprite2D = $red_valve_animation

@onready var ashen: AudioStreamPlayer = $AshenSerenity
@onready var fire: AudioStreamPlayer = $FireCracling

var last_animation_label_go:bool = true
var input_locked: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start.grab_focus()
	
	if not FileAccess.file_exists("user://save_game.json"):
		load_btn.disabled = true
	
	# Fade-in suave nos áudios do menu principal
	var ashen_target = ashen.volume_db
	var fire_target = fire.volume_db
	ashen.volume_db = -80.0
	fire.volume_db = -80.0
	var audio_in_tween = create_tween().set_parallel(true)
	audio_in_tween.tween_property(ashen, "volume_db", ashen_target, 4.0)
	audio_in_tween.tween_property(fire, "volume_db", fire_target, 4.0)
	
	var tween = create_tween().set_loops()
	# TAU = 360 graus em radianos. 
	# as_relative faz ele somar 360 à rotação atual a cada ciclo.
	tween.tween_property(red_valve, "rotation", TAU, 16.0).as_relative().set_trans(Tween.TRANS_LINEAR)
	
	await get_tree().create_timer(2.0).timeout
	input_locked = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_load_pressed() -> void:
	if input_locked: return
	$Control.visible = false
	
	var audio_out_tween = create_tween().set_parallel(true)
	audio_out_tween.tween_property(ashen, "volume_db", -80.0, 2.0)
	audio_out_tween.tween_property(fire, "volume_db", -80.0, 2.0)
	
	$fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	SaveManager.load_game()

func _on_start_pressed() -> void:
	if input_locked: return
	$Control.visible = false
	
	# Fade-out no áudio sincronizado com a tela escurecendo
	var audio_out_tween = create_tween().set_parallel(true)
	audio_out_tween.tween_property(ashen, "volume_db", -80.0, 2.0)
	audio_out_tween.tween_property(fire, "volume_db", -80.0, 2.0)
	
	$fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/stages/prolog/cutscene_prolog.tscn")

func _on_config_pressed() -> void:
	if input_locked: return
	var config_script = load("res://scripts/ui/config_menu.gd")
	if config_script:
		var config_menu = config_script.new()
		# O config_menu foi desenhado para "voltar" reexibindo o nó "Pause", mas no main menu
		# a gente precisa reexibir o Control. O jeito mais fácil é mudar dinamicamente:
		add_child(config_menu)
		$Control.visible = false
		
		# Sobrescreve o comportamento de voltar dinamicamente para o Main Menu
		config_menu.back_btn.pressed.disconnect(config_menu._on_back_pressed)
		config_menu.back_btn.pressed.connect(func():
			SaveManager.save_game()
			$Control.visible = true
			$Control/VBoxContainer/config.grab_focus()
			config_menu.queue_free()
		)

func _on_exit_pressed() -> void:
	if input_locked: return
	get_tree().quit()


func _on_timer_timeout() -> void:
	var nova_opacidade = randf_range(0.5, 0.8) # Nunca fica 100% invisível
	var tempo_transicao = randf_range(0.1, 0.2)
	
	var tween = create_tween()
	tween.tween_property($ColorRect, "modulate:a", nova_opacidade, tempo_transicao)
	
	timer.wait_time = tempo_transicao


func _on_timer_play_animation_label_timeout() -> void:
	if last_animation_label_go:
		last_animation_label_go = false
		red_valve_animation.play("back")
	else:
		last_animation_label_go = true
		red_valve_animation.play("go")
