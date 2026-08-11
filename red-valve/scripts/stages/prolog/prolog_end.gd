extends Control

@onready var label: Label = $Label
@onready var fade = $fade

func _ready() -> void:
	# Oculta o texto inicialmente
	label.modulate.a = 0.0
	
	# Dá um tempo inicial para o fade global terminar
	await get_tree().create_timer(1.0).timeout
	
	# Fade in no texto "FIM DA DEMO"
	var tween_in = create_tween()
	tween_in.tween_property(label, "modulate:a", 1.0, 2.0)
	
	# Aguarda os 10 segundos solicitados
	await get_tree().create_timer(10.0).timeout
	
	# Fade out do texto
	var tween_out = create_tween()
	tween_out.tween_property(label, "modulate:a", 0.0, 2.0)
	await tween_out.finished
	
	# Fade out global da tela
	if fade:
		fade.fade_out()
		await get_tree().create_timer(2.0).timeout
		
	# Redireciona para o Menu Principal
	get_tree().change_scene_to_file("res://scenes/configs/main_menu.tscn")
