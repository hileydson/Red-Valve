extends Node3D

@onready var start: Button = $Control/VSplitContainer/start
@onready var timer: Timer = $Timer_flick
@onready var red_valve: Sprite2D = $VideoStreamPlayer/RedValveSpriteNoBackground
@onready var timer_play_animation_label: Timer = $Timer_play_animation_label
@onready var red_valve_animation: AnimatedSprite2D = $red_valve_animation

var last_animation_label_go:bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start.grab_focus()
	
	var tween = create_tween().set_loops()
	# TAU = 360 graus em radianos. 
	# as_relative faz ele somar 360 à rotação atual a cada ciclo.
	tween.tween_property(red_valve, "rotation", TAU, 16.0).as_relative().set_trans(Tween.TRANS_LINEAR)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1.tscn")


func _on_exit_pressed() -> void:
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
