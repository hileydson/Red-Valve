extends Button

## Uma linha de QUANTIDADE das abas de debug: "Munição de pistola   ◀ 25 ▶".
##
## Substitui o SpinBox, que tinha dois defeitos no controle:
##
##  - o LineEdit dele toma o cima/baixo pra ele (sobe e desce o valor), então o
##    direcional parava na primeira linha de quantidade e não descia mais —
##    o resto da lista ficava inalcançável sem mouse;
##  - o foco caía no LineEdit, que não desenha marca nenhuma: o jogador não
##    sabia em que linha estava.
##
## Aqui a linha inteira é UM botão: cima/baixo navegam como em qualquer outra
## linha, esquerda/direita mudam o valor (segurando, acelera), e o foco usa o
## estilo de foco das abas de debug (a borda vermelha).

signal value_changed(valor: float)

var min_value: float = 0.0
var max_value: float = 100.0
var step: float = 1.0
var value: float = 0.0:
	set(v):
		var novo := clampf(snappedf(v, step), min_value, max_value)
		if novo == value:
			return
		value = novo
		_redesenhar()
		value_changed.emit(value)

var rotulo: String = ""

# Segurar a seta: a primeira repetição espera um pouco, depois vem rápida e
# cada vez maior (o mesmo ritmo do analógico das outras abas).
const ESPERA_REPETIR := 0.32
const INTERVALO_REPETIR := 0.05

var _direcao := 0
var _segurando := 0.0
var _proxima := 0.0


func configurar(texto: String, minimo: float, maximo: float, atual: float) -> void:
	rotulo = texto
	min_value = minimo
	max_value = maximo
	# chamado antes de quem usa ligar o `value_changed`: o valor inicial nao
	# chega como mudanca
	value = clampf(atual, minimo, maximo)
	_redesenhar()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	_redesenhar()


func _redesenhar() -> void:
	text = "%s     ◀  %d  ▶" % [rotulo, int(value)]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_passo(1, 1.0)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_passo(-1, 1.0)
			accept_event()
		return
	# o repetir de tecla do sistema e' ignorado: o segurar e' contado aqui, igual
	# pro teclado e pro direcional do controle (que nao repete sozinho)
	if event.is_echo():
		if event.is_action("ui_left") or event.is_action("ui_right"):
			accept_event()
		return
	if event.is_action_pressed("ui_left"):
		_comecar(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_comecar(1)
		accept_event()


func _comecar(direcao: int) -> void:
	_direcao = direcao
	_segurando = 0.0
	_proxima = ESPERA_REPETIR
	_passo(direcao, 1.0)


func _process(delta: float) -> void:
	if _direcao == 0:
		return
	var acao := "ui_right" if _direcao > 0 else "ui_left"
	if not has_focus() or not Input.is_action_pressed(acao):
		_direcao = 0
		return
	_segurando += delta
	_proxima -= delta
	if _proxima > 0.0:
		return
	_proxima = INTERVALO_REPETIR
	var mult := 1.0
	if _segurando > 3.5:
		mult = 100.0
	elif _segurando > 2.0:
		mult = 20.0
	elif _segurando > 1.0:
		mult = 5.0
	_passo(_direcao, mult)


## Um passo. Faixa pequena (0-5, 0-100) nao acelera tanto quanto a de milhares.
func _passo(direcao: int, mult: float) -> void:
	var faixa := max_value - min_value
	if faixa <= 10.0:
		mult = 1.0
	elif faixa <= 200.0:
		mult = minf(mult, 5.0)
	elif faixa <= 1000.0:
		mult = minf(mult, 25.0)
	var antes := value
	value = value + direcao * step * mult
	if value != antes:
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3")
