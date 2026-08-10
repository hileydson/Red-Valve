extends Control

signal skipped

var progress: float = 0.0
var hold_time: float = 1.5
var is_skipping: bool = false
var default_font = ThemeDB.fallback_font

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	self.process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_skipping: return
	
	if Input.is_action_pressed("ui_pause"):
		progress += delta / hold_time
		if progress >= 1.0:
			progress = 1.0
			is_skipping = true
			skipped.emit()
	else:
		progress -= delta * 2.0
		if progress < 0.0:
			progress = 0.0
			
	queue_redraw()

func _draw() -> void:
	if progress <= 0.0: return
	
	# Position: Bottom Right
	var center = get_viewport_rect().size - Vector2(120, 100)
	var radius = 40.0
	var width = 6.0
	
	# Draw background circle (faint)
	draw_arc(center, radius, 0, PI * 2, 64, Color(1, 1, 1, 0.2 * progress), width, true)
	
	# Draw progress arc (Starts at Top (-PI/2) and goes clockwise)
	if progress > 0.0:
		draw_arc(center, radius, -PI/2, -PI/2 + (PI * 2 * progress), 64, Color(1, 1, 1, 0.8), width, true)
		
	# Draw "HOLD" / "SEGURE" text below the circle
	var font_size = 18
	var str = tr("UI_HOLD")
	var string_size = default_font.get_string_size(str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	# O y é ajustado usando o radius (40) mais uma margem de 25 pixels para ficar embaixo do círculo
	var text_pos = center + Vector2(-string_size.x / 2.0, radius + 25)
	
	# A opacidade do texto pode ficar um pouco maior (0.3 base + progress) para ser sempre legível
	draw_string(default_font, text_pos, str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, min(1.0, 0.4 + progress)))
