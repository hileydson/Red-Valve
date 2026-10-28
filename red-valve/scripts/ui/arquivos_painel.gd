extends Control
class_name ArquivosPainel

## Aba ARQUIVOS do menu do Maycow: a lista de arquivos de um lado, o texto do
## arquivo selecionado do outro.
##
## O painel se monta sozinho em codigo, como o resto do in_game_menu, e se vira
## com o que houver: le o catalogo em ArquivosDados, filtra pelo que o jogador
## ja desbloqueou (SaveManager) e, se ainda nao houver nada, mostra o aviso de
## vazio no lugar da leitura.

const COR_ITEM := Color(0.78, 0.78, 0.78)
const COR_ITEM_SEL := Color(1.0, 1.0, 0.0)
const COR_BORDA := Color(0.35, 0.35, 0.35, 1.0)

var _lista_vbox: VBoxContainer
var _titulo_label: Label
var _corpo_label: Label
var _corpo_scroll: ScrollContainer
var _vazio_label: Label
var _ajuda_label: Label

var _ids: Array = []
var _botoes: Array[Button] = []
var _indice: int = 0
var _ativo: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	_montar()
	set_process_input(false)


func _montar() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 30)
	add_child(hbox)

	# --- lado esquerdo: os nomes dos arquivos
	var esquerda := PanelContainer.new()
	esquerda.custom_minimum_size = Vector2(420, 0)
	esquerda.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	esquerda.size_flags_vertical = Control.SIZE_EXPAND_FILL
	esquerda.add_theme_stylebox_override("panel", _moldura())
	hbox.add_child(esquerda)

	var lista_scroll := ScrollContainer.new()
	lista_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	esquerda.add_child(lista_scroll)

	_lista_vbox = VBoxContainer.new()
	_lista_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_vbox.add_theme_constant_override("separation", 6)
	lista_scroll.add_child(_lista_vbox)

	# --- lado direito: o texto
	var direita := PanelContainer.new()
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direita.size_flags_vertical = Control.SIZE_EXPAND_FILL
	direita.add_theme_stylebox_override("panel", _moldura())
	hbox.add_child(direita)

	var texto_vbox := VBoxContainer.new()
	texto_vbox.add_theme_constant_override("separation", 14)
	direita.add_child(texto_vbox)

	_titulo_label = Label.new()
	_titulo_label.add_theme_font_size_override("font_size", 30)
	_titulo_label.add_theme_color_override("font_color", COR_ITEM_SEL)
	_titulo_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	texto_vbox.add_child(_titulo_label)

	_corpo_scroll = ScrollContainer.new()
	_corpo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_corpo_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto_vbox.add_child(_corpo_scroll)

	_corpo_label = Label.new()
	_corpo_label.add_theme_font_size_override("font_size", 20)
	_corpo_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_corpo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo_scroll.add_child(_corpo_label)

	_ajuda_label = Label.new()
	_ajuda_label.add_theme_font_size_override("font_size", 15)
	_ajuda_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	texto_vbox.add_child(_ajuda_label)

	# --- aviso de "ainda nao tem nada aqui", por cima dos dois lados
	_vazio_label = Label.new()
	_vazio_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vazio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vazio_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vazio_label.add_theme_font_size_override("font_size", 24)
	_vazio_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_vazio_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vazio_label.visible = false
	add_child(_vazio_label)


func _moldura() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = COR_BORDA
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


## Chamado pela aba quando ela entra em foco. Relista do zero, porque o jogador
## pode ter desbloqueado um arquivo desde a ultima vez que abriu o menu.
func ativar() -> void:
	_ativo = true
	set_process_input(true)
	set_process(true)
	_ids = ArquivosDados.desbloqueados()
	_indice = clampi(_indice, 0, maxi(_ids.size() - 1, 0))
	_montar_lista()
	_mostrar_selecionado()
	_atualizar_ajuda()


func desativar() -> void:
	_ativo = false
	set_process_input(false)
	set_process(false)


## A legenda da roda do mouse não faz sentido pra quem está no controle.
func _process(_delta: float) -> void:
	_atualizar_ajuda()


func _atualizar_ajuda() -> void:
	_ajuda_label.text = tr("FILES_HELP_PAD" if GlobalEvents.usando_controle else "FILES_HELP")


func _montar_lista() -> void:
	for b in _botoes:
		# tira da árvore antes de liberar: o queue_free só recolhe no fim do
		# frame, e sem isso a lista apareceria duplicada por um quadro
		_lista_vbox.remove_child(b)
		b.queue_free()
	_botoes.clear()

	for i in _ids.size():
		var btn := Button.new()
		btn.text = ArquivosDados.titulo(String(_ids[i]))
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = false
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.add_theme_font_size_override("font_size", 22)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		btn.mouse_entered.connect(func():
			if _indice != idx:
				_selecionar(idx)
		)
		btn.pressed.connect(func(): _selecionar(idx))
		_lista_vbox.add_child(btn)
		_botoes.append(btn)

	var vazio := _ids.is_empty()
	_vazio_label.visible = vazio
	_vazio_label.text = tr("FILES_EMPTY")
	_titulo_label.visible = not vazio
	_corpo_scroll.visible = not vazio
	_ajuda_label.visible = not vazio
	_atualizar_ajuda()


func _selecionar(idx: int) -> void:
	if idx == _indice:
		return
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
	_indice = idx
	_mostrar_selecionado()


## Pinta o item escolhido e joga o texto dele no painel da direita.
func _mostrar_selecionado() -> void:
	for i in _botoes.size():
		var btn := _botoes[i]
		var sel := i == _indice
		btn.text = ("> " if sel else "  ") + ArquivosDados.titulo(String(_ids[i]))
		var cor := COR_ITEM_SEL if sel else COR_ITEM
		btn.add_theme_color_override("font_color", cor)
		btn.add_theme_color_override("font_hover_color", cor)
		btn.add_theme_color_override("font_focus_color", cor)
		btn.add_theme_color_override("font_pressed_color", cor)

	if _ids.is_empty():
		_titulo_label.text = ""
		_corpo_label.text = ""
		return

	var id := String(_ids[_indice])
	_titulo_label.text = ArquivosDados.titulo(id)
	_corpo_label.text = ArquivosDados.corpo(id)
	_corpo_scroll.scroll_vertical = 0


## Setas trocam de arquivo; a rolagem do texto fica com a roda do mouse e com a
## propria ScrollContainer. As abas (L1/R1) e o fechar do menu continuam com o
## in_game_menu — nao marcamos esses eventos como tratados.
func _input(event: InputEvent) -> void:
	if not _ativo or _ids.size() <= 1:
		return
	if event is InputEventJoypadMotion:
		return
	if event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_selecionar((_indice + 1) % _ids.size())
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_selecionar((_indice - 1 + _ids.size()) % _ids.size())
