extends RefCounted

## A CARTELA DE CAPÍTULO ("CAPÍTULO N" bem grande, em vermelho, no meio da
## tela, e o nome do capítulo embaixo), com o acabamento de abertura de filme.
## Uma só para o jogo todo: a cidade (`stage_1`, Capítulos 1 a 4) e o despertar
## na igreja (Capítulo 5) mostram a mesma.
##
##     const CartelaDeCapitulo := preload("res://scripts/cutscenes/cartela_de_capitulo.gd")
##     await CartelaDeCapitulo.mostrar(self, camada, "TXT_CHAPTER_5", "TXT_CHAPTER_5_SUBTITULO")
##
## `dono` é quem segura os tweens e o som; `camada`, o CanvasLayer onde ela
## aparece. Sem `class_name` (ver [[project-class-name-travado]]).

## A cartela do capitulo. Mesmo tempo de sempre (1 s entrando, 3,5 s parada,
## 1 s saindo) e mesmo vermelho, com o acabamento de abertura de filme: uma
## faixa escura macia atras, as letras chegando espacadas e se fechando
## (tracking), um halo vermelho por tras delas, dois filetes que se abrem do
## centro, o nome do capitulo entrando um instante depois e um grave por baixo
## no quadro em que o titulo aparece. Tudo devagar, nada pisca.
static func mostrar(dono: Node, camada: Node, chave_titulo: String, chave_subtitulo: String) -> void:
	const VERMELHO := Color(0.705882, 0.0, 0.0)
	const ENTRA := 1.0
	const PARADO := 3.5
	const SAI := 1.0

	var custom_font = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
	# Espacamento das letras animavel: o tracking e' o que da o ar de abertura.
	var fonte := FontVariation.new()
	if custom_font:
		fonte.base_font = custom_font
	fonte.spacing_glyph = 46

	var cartela := Control.new()
	cartela.set_anchors_preset(Control.PRESET_FULL_RECT)
	cartela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(cartela)

	# Faixa escura atras do titulo, sumindo nas bordas de cima e de baixo.
	var faixa := TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 4
	grad_tex.height = 128
	faixa.texture = grad_tex
	faixa.stretch_mode = TextureRect.STRETCH_SCALE
	faixa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	faixa.set_anchors_preset(Control.PRESET_FULL_RECT)
	faixa.anchor_top = 0.26
	faixa.anchor_bottom = 0.80
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartela.add_child(faixa)

	var chapter_label = Label.new()
	chapter_label.text = dono.tr(chave_titulo).to_upper()
	chapter_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_label.add_theme_font_size_override("font_size", 180)
	chapter_label.add_theme_color_override("font_color", VERMELHO)
	chapter_label.add_theme_font_override("font", fonte)

	# O halo: o mesmo texto por tras, com contorno largo e quase transparente.
	var halo = chapter_label.duplicate()
	halo.add_theme_color_override("font_color", Color(1.0, 0.05, 0.02, 0.22))
	halo.add_theme_color_override("font_outline_color", Color(0.85, 0.0, 0.0, 0.16))
	halo.add_theme_constant_override("outline_size", 34)
	cartela.add_child(halo)
	cartela.add_child(chapter_label)

	# O nome do capitulo, pequeno e no mesmo vermelho, logo abaixo.
	var subtitle_label = Label.new()
	subtitle_label.text = dono.tr(chave_subtitulo)
	subtitle_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	subtitle_label.offset_top = 170
	subtitle_label.offset_bottom = 170
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 48)
	subtitle_label.add_theme_color_override("font_color", VERMELHO)
	if custom_font:
		subtitle_label.add_theme_font_override("font", custom_font)
	cartela.add_child(subtitle_label)

	# Filetes acima e abaixo do nome, abrindo do centro.
	var filetes: Array[ColorRect] = []
	for dy in [118.0, 222.0]:
		var f := ColorRect.new()
		f.color = Color(VERMELHO.r, VERMELHO.g, VERMELHO.b, 0.85)
		f.anchor_left = 0.5
		f.anchor_right = 0.5
		f.anchor_top = 0.5
		f.anchor_bottom = 0.5
		f.offset_top = dy
		f.offset_bottom = dy + 2.0
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cartela.add_child(f)
		filetes.append(f)

	var tamanho := dono.get_viewport().get_visible_rect().size
	cartela.pivot_offset = tamanho * 0.5
	cartela.scale = Vector2(1.035, 1.035)
	cartela.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	halo.modulate.a = 0.0

	_grave(dono)

	var tween_in = dono.create_tween().set_parallel(true)
	tween_in.tween_property(cartela, "modulate:a", 1.0, ENTRA).set_trans(Tween.TRANS_SINE)
	tween_in.tween_property(fonte, "spacing_glyph", 10, ENTRA + PARADO).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(cartela, "scale", Vector2.ONE, ENTRA + PARADO + SAI).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(halo, "modulate:a", 1.0, ENTRA * 1.6).set_delay(ENTRA * 0.3)
	tween_in.tween_property(subtitle_label, "modulate:a", 1.0, ENTRA).set_delay(ENTRA * 0.6)
	for f in filetes:
		tween_in.tween_property(f, "offset_left", -340.0, ENTRA * 1.4).set_delay(ENTRA * 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween_in.tween_property(f, "offset_right", 340.0, ENTRA * 1.4).set_delay(ENTRA * 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await dono.get_tree().create_timer(ENTRA, false).timeout

	await dono.get_tree().create_timer(PARADO, false).timeout

	if is_instance_valid(cartela):
		var tween_out = dono.create_tween().set_parallel(true)
		tween_out.tween_property(cartela, "modulate:a", 0.0, SAI).set_trans(Tween.TRANS_SINE)
		tween_out.tween_property(fonte, "spacing_glyph", 2, SAI)
		await tween_out.finished
		cartela.queue_free()


## O grave de cinema no quadro em que a cartela aparece.
static func _grave(dono: Node) -> void:
	var stream := load("res://assets/sounds/common/explosao.mp3") as AudioStream
	if stream == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = stream
	a.pitch_scale = 0.34
	a.volume_db = -12.0
	dono.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
