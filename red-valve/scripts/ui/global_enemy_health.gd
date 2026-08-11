extends CanvasLayer

var container: Control
var health_bar: ProgressBar
var name_label: Label
var hide_tween: Tween
var current_enemy: Node3D

func _ready() -> void:
	layer = 128
	
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.modulate.a = 0.0 # Escondido no inicio
	add_child(container)
	
	var panel = PanelContainer.new()
	
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	
	# Garante que vai ter exatos 500 de largura e ficar perfeitamente no meio sempre (independente da tela)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = 30
	panel.offset_bottom = 90
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Estilo elegante escuro com borda sutil
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.expand_margin_left = 10
	style.expand_margin_right = 10
	style.expand_margin_top = 10
	style.expand_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	name_label = Label.new()
	name_label.text = "ENEMY NAME"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	# Adiciona um leve contorno no texto para leitura melhor
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 12)
	health_bar.show_percentage = false
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.2, 0.0, 0.0, 0.8)
	health_bar.add_theme_stylebox_override("background", sb_bg)
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.81, 0.11, 0.11, 1) # Retorna pro vermelho clássico de chefe
	health_bar.add_theme_stylebox_override("fill", sb_fill)
	
	vbox.add_child(name_label)
	vbox.add_child(health_bar)
	panel.add_child(vbox)
	container.add_child(panel)

func show_health(enemy: Node3D, enemy_name: String, current_hp: int, max_hp: int) -> void:
	# Se for um inimigo novo sendo atacado, atualiza nome e máximo de vida
	if current_enemy != enemy:
		current_enemy = enemy
		name_label.text = enemy_name
		health_bar.max_value = max_hp
		health_bar.value = max_hp # Previne a barra descendo a partir do zero
		
	# Reseta qualquer animação de esconder em progresso
	if hide_tween:
		hide_tween.kill()
		
	container.modulate.a = 1.0
	
	# Anima a descida da vida
	var hp_tween = create_tween()
	hp_tween.tween_property(health_bar, "value", current_hp, 0.2).set_trans(Tween.TRANS_SINE)
	
	# Reinicia o timer para sumir
	hide_tween = create_tween()
	hide_tween.tween_interval(2.0) # Espera 2 segundos
	hide_tween.tween_property(container, "modulate:a", 0.0, 0.5) # Fade out de 0.5s

	# Se a vida chegar a zero (ou menor), podemos esconder a barra mais rápido
	if current_hp <= 0:
		hide_tween.kill()
		hide_tween = create_tween()
		hide_tween.tween_interval(0.5)
		hide_tween.tween_property(container, "modulate:a", 0.0, 0.5)
