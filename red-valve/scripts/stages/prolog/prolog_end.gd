extends Control

@onready var label: Label = $Label
@onready var fade = $fade

func _ready() -> void:
	# -- INJEÇÃO DO FILTRO VHS --
	var vhs_mat = ShaderMaterial.new()
	vhs_mat.shader = load("res://shaders/vhs_filter.gdshader")
	if "image_rect" in self and self.get("image_rect") != null:
		self.get("image_rect").material = vhs_mat
	elif has_node("ImageRect"):
		get_node("ImageRect").material = vhs_mat
	# ---------------------------

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
	get_tree().change_scene_to_file("res://scenes/configs/main_menu_v2.tscn")
