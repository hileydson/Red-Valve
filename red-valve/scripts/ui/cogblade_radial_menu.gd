extends Control

# Menu radial de escolha dos poderes da Cogblade (estilo dos plasmids do BioShock).
# Os poderes aparecem em círculo e a seleção é feita apontando o analógico
# esquerdo (ou movendo o mouse) na direção da opção desejada. Quem instancia é o
# PlayerCogbladeMenu, que também executa o poder ao soltar o botão.

# Cada opção: { "id": String, "name": String, "desc": String, "enabled": bool }
var options: Array = []
var selected: int = -1
var icon_texture: Texture2D = null
# Direção apontada pelo jogador (coordenadas de tela, Y para baixo)
var point_dir: Vector2 = Vector2.ZERO

var radius: float = 265.0
var option_radius: float = 78.0

var _font: Font = null
var _appear: float = 0.0
var _time: float = 0.0
var _last_ms: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# O menu roda com o jogo em câmera lenta extrema, então a animação usa
	# tempo real (ticks) em vez do delta escalado pelo Engine.time_scale.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ms = Time.get_ticks_msec()
	
	var font_path := "res://assets/fonts/Montserrat-ExtraBold.ttf"
	if ResourceLoader.exists(font_path):
		_font = load(font_path)
	else:
		_font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_delta: float = float(now - _last_ms) / 1000.0
	_last_ms = now
	
	_time += real_delta
	_appear = minf(1.0, _appear + real_delta * 6.0)
	queue_redraw()

# Fecha com uma pequena saída (quem chama libera o nó depois)
func fade_out() -> void:
	set_process(false)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.12)

func _draw() -> void:
	if options.is_empty(): return
	
	var vp := get_viewport_rect().size
	var center := vp * 0.5
	var appear := ease(_appear, 0.35)
	var r := radius * lerpf(0.75, 1.0, appear)
	
	# Escurece a tela por trás do menu
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.45 * appear))
	# Disco central e anel guia
	draw_circle(center, r + option_radius * 1.15, Color(0.02, 0.03, 0.05, 0.45 * appear))
	draw_arc(center, r, 0.0, TAU, 128, Color(0.55, 0.85, 1.0, 0.22 * appear), 3.0, true)
	
	var count := options.size()
	var sector := TAU / float(count)
	
	# Agulha apontando para onde o jogador está mirando
	if point_dir.length() > 0.05:
		var nd := point_dir.normalized()
		draw_line(center + nd * 36.0, center + nd * (r - option_radius * 0.6),
			Color(1.0, 0.85, 0.4, 0.55 * appear), 4.0, true)
	
	for i in range(count):
		var opt: Dictionary = options[i]
		var enabled: bool = bool(opt.get("enabled", true))
		var is_sel: bool = (i == selected)
		var ang: float = -PI * 0.5 + float(i) * sector
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * r
		
		var base_col := Color(0.55, 0.85, 1.0)
		if not enabled:
			base_col = Color(0.45, 0.45, 0.48)
		elif is_sel:
			base_col = Color(1.0, 0.35, 0.3)
		
		var pulse: float = 1.0
		if is_sel and enabled:
			pulse = 1.0 + sin(_time * 9.0) * 0.045
		var orad: float = option_radius * (1.18 if is_sel else 1.0) * pulse * lerpf(0.6, 1.0, appear)
		
		# Fatia destacada da opção selecionada
		if is_sel:
			var pts := PackedVector2Array()
			pts.append(center)
			var a0: float = ang - sector * 0.5
			for k in range(17):
				var aa: float = a0 + sector * (float(k) / 16.0)
				pts.append(center + Vector2(cos(aa), sin(aa)) * (r + orad))
			draw_colored_polygon(pts, Color(base_col.r, base_col.g, base_col.b, 0.13 * appear))
		
		# Base do ícone
		draw_circle(pos, orad, Color(0.04, 0.05, 0.07, 0.85 * appear))
		draw_arc(pos, orad, 0.0, TAU, 64, Color(base_col.r, base_col.g, base_col.b, (0.95 if is_sel else 0.5) * appear), (6.0 if is_sel else 3.0), true)
		
		# Ícone da cogblade
		if icon_texture:
			var isize: float = orad * 1.3
			var rect := Rect2(pos - Vector2(isize, isize) * 0.5, Vector2(isize, isize))
			var icol := Color(1, 1, 1, (1.0 if enabled else 0.35) * appear)
			if is_sel and enabled: icol = Color(1.0, 0.8, 0.75, appear)
			draw_texture_rect(icon_texture, rect, false, icol)
		
		# Nome do poder abaixo do ícone
		var name_txt: String = str(opt.get("name", ""))
		var fsize: int = 28 if is_sel else 24
		var tw: float = _font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var tpos := pos + Vector2(-tw * 0.5, orad + 36.0)
		draw_string_outline(_font, tpos, name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 7, Color(0, 0, 0, 0.9 * appear))
		draw_string(_font, tpos, name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
			Color(base_col.r, base_col.g, base_col.b, (1.0 if enabled else 0.5) * appear))
	
	# Descrição da opção apontada, no centro do círculo
	var center_txt := "ESCOLHA UM PODER"
	if selected >= 0 and selected < count:
		center_txt = str(options[selected].get("desc", ""))
	var cw: float = _font.get_string_size(center_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var cpos := center + Vector2(-cw * 0.5, 8.0)
	draw_string_outline(_font, cpos, center_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 7, Color(0, 0, 0, 0.9 * appear))
	draw_string(_font, cpos, center_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.9 * appear))
