extends CanvasLayer

## A LEITURA DE UM DIÁRIO: o caderno aberto ao fundo e a escrita na frente.
##
## O jogo para. Atrás, o modelo 3D do caderno flutua devagar num mundo próprio
## (o mesmo truque de SubViewport da tela de item obtido), escurecido; na
## frente, uma folha com a letra à mão (Caveat) mostra o texto UMA PÁGINA POR
## VEZ — cada parágrafo do arquivo (`ArquivosDados`) é uma página. O botão de
## aceitar vira a página; a última fecha.
##
## Quem abre passa o id do arquivo e o modelo ANTES de pôr na árvore:
##
##     var tela = preload("res://scripts/ui/leitura_diario.gd").new()
##     tela.arquivo = "diario_do_jimmy"
##     tela.model_path = "res://.../binder_notebook_1k.gltf"
##     get_tree().root.add_child(tela)
##     await tela.fechado

signal fechado

const FONTE_LETRA := "res://assets/fonts/Caveat.ttf"
const FONTE_TITULO := "res://assets/fonts/Montserrat-ExtraBold.ttf"
const SOM_PAGINA := "res://assets/sounds/menu_itens/mudar_selecao.mp3"
const COR_PAPEL := Color(0.86, 0.81, 0.69)
const COR_TINTA := Color(0.12, 0.10, 0.16)
const FADE := 0.5
## Só aceita o botão depois disto: sem a folga, o mesmo aperto que pegou o
## caderno já virava a primeira página.
const ESPERA_ANTES_DE_ACEITAR := 0.45

var arquivo: String = ""
var model_path: String = ""

var _paginas: Array = []
var _pagina := 0
var _aceita := false
var _fechando := false
var _relogio := 0.0

var _fade: ColorRect
var _pivo: Node3D
var _folha: PanelContainer
var _texto: Label
var _rodape: Label


func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_paginas = ArquivosDados.paragrafos(arquivo)
	_montar()
	_mostrar_pagina(0)

	_fade.color.a = 1.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 0.0, FADE)
	await tw.finished
	await get_tree().create_timer(ESPERA_ANTES_DE_ACEITAR, true, false, true).timeout
	_aceita = true


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.015, 0.02, 0.92)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	# --- o caderno, ao fundo -------------------------------------------------
	var vc := SubViewportContainer.new()
	vc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vc.stretch = true
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vc.modulate = Color(0.62, 0.58, 0.55)
	add_child(vc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vc.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 1.25)
	cam.fov = 40.0
	vp.add_child(cam)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.7, 0.5, 0.0)
	luz.light_color = Color(1.0, 0.86, 0.66)
	luz.light_energy = 1.3
	vp.add_child(luz)
	var luz2 := DirectionalLight3D.new()
	luz2.rotation = Vector3(0.4, -2.4, 0.0)
	luz2.light_energy = 0.35
	vp.add_child(luz2)
	_pivo = Node3D.new()
	vp.add_child(_pivo)
	_por_modelo()

	# --- a folha escrita, na frente -----------------------------------------
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	_folha = PanelContainer.new()
	_folha.custom_minimum_size = Vector2(760, 520)
	_folha.rotation_degrees = -1.4
	_folha.pivot_offset = Vector2(380, 260)
	var papel := StyleBoxFlat.new()
	papel.bg_color = COR_PAPEL
	papel.set_corner_radius_all(3)
	papel.shadow_color = Color(0, 0, 0, 0.6)
	papel.shadow_size = 18
	papel.content_margin_left = 64
	papel.content_margin_right = 52
	papel.content_margin_top = 46
	papel.content_margin_bottom = 40
	_folha.add_theme_stylebox_override("panel", papel)
	centro.add_child(_folha)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 16)
	_folha.add_child(coluna)

	var titulo := Label.new()
	titulo.text = ArquivosDados.titulo(arquivo)
	titulo.add_theme_font_override("font", load(FONTE_TITULO))
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color(0.45, 0.10, 0.08))
	coluna.add_child(titulo)

	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(640, 360)
	_texto.add_theme_font_override("font", load(FONTE_LETRA))
	_texto.add_theme_font_size_override("font_size", 36)
	_texto.add_theme_color_override("font_color", COR_TINTA)
	_texto.add_theme_constant_override("line_spacing", -4)
	coluna.add_child(_texto)

	_rodape = Label.new()
	_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rodape.add_theme_font_size_override("font_size", 16)
	_rodape.add_theme_color_override("font_color", Color(0.35, 0.30, 0.28))
	coluna.add_child(_rodape)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _por_modelo() -> void:
	if model_path == "" or not ResourceLoader.exists(model_path):
		return
	var modelo := (load(model_path) as PackedScene).instantiate() as Node3D
	_pivo.add_child(modelo)
	var caixa := AABB()
	var primeira := true
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := modelo.global_transform.affine_inverse() * mi.global_transform \
			if mi.is_inside_tree() else mi.transform
		var c: AABB = t * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	modelo.position = -caixa.get_center()
	var maior := maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))
	if maior > 0.0:
		_pivo.scale = Vector3.ONE * (1.1 / maior)
	# deitado de frente pra camera, um pouco inclinado: e' um caderno largado
	# na mesa, visto de cima
	_pivo.rotation = Vector3(1.15, 0.35, 0.12)


func _mostrar_pagina(i: int) -> void:
	_pagina = i
	var linhas := PackedStringArray()
	if i < _paginas.size():
		for chave in _paginas[i]:
			linhas.append(tr(String(chave)))
	_texto.text = "\n\n".join(linhas)
	var total := maxi(_paginas.size(), 1)
	var botao := tr("LEITURA_CONTINUAR_PAD" if GlobalEvents.usando_controle else "LEITURA_CONTINUAR_KEY")
	_rodape.text = "%d / %d     %s" % [i + 1, total, botao]


func _process(delta: float) -> void:
	_relogio += delta
	if is_instance_valid(_pivo):
		_pivo.position.y = sin(_relogio * 0.8) * 0.015


func _input(event: InputEvent) -> void:
	if _fechando or not _aceita:
		return
	var vale: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not vale:
		return
	get_viewport().set_input_as_handled()
	if _pagina + 1 < _paginas.size():
		GlobalUtils.play_ui_sound(SOM_PAGINA)
		_virar(_pagina + 1)
	else:
		_fechar()


## A folha some e volta com a página seguinte (uma virada de página curta).
func _virar(i: int) -> void:
	_aceita = false
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_folha, "modulate:a", 0.0, 0.18)
	await tw.finished
	_mostrar_pagina(i)
	var volta := create_tween()
	volta.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	volta.tween_property(_folha, "modulate:a", 1.0, 0.22)
	await volta.finished
	_aceita = true


func _fechar() -> void:
	_fechando = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	await tw.finished
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GlobalEvents.bloquear_dash_por(300)
	fechado.emit()
	queue_free()
