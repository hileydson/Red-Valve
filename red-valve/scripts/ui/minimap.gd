extends CanvasLayer
## Mapa da cidade: minimapa no canto e mapa grande do menu.
##
## Só existe no stage_1, e só aparece no gameplay com o Maycow normal.
##
## O mapa é uma textura assada a partir dos DADOS da cidade
## (tools/blender/citygen/textures/make_minimap.py), não um render da cena:
## fica legível a 190 px, não depende da hora do dia nem da iluminação, e
## regerar custa dois segundos. O recorte do mundo e os pontos de interesse
## vêm no `citymap.json` que o mesmo script escreve — nada aqui é número
## mágico, e se a cidade for regerada os dois andam juntos.

## Diâmetro, em metros de mundo, do que cabe dentro do círculo.
@export var alcance_m: float = 130.0
## Lado do minimapa em pixels.
@export var tamanho_px: float = 190.0
## Distância até o canto da tela.
@export var margem_px: Vector2 = Vector2(26.0, 26.0)
## Suavização do giro. 0 = acompanha na hora.
@export var suavidade: float = 12.0
## Mostrar os pontos de interesse também no minimapa (sem rótulo).
@export var pontos_no_minimapa: bool = true
@export var meta_json: String = "res://assets/3d_model/city/citymap.json"

@export_group("Mapa grande")
## Altura da janela visível, em metros, nos dois extremos do zoom.
@export var zoom_min_m: float = 40.0
## 560 e não 680 (o lado inteiro da textura): o papel tem 680 m mas a cidade
## só ocupa 600 x 420 no meio dele. Deixar afastar até ver o papel inteiro só
## rendia margem de mata vazia em volta.
@export var zoom_max_m: float = 560.0
@export var zoom_inicial_m: float = 260.0
## Quanto cada passo da roda multiplica o zoom.
@export var passo_zoom: float = 1.18

const COR_TIPO := {
	"marco": Color(0.55, 0.86, 0.70),
	"local": Color(0.95, 0.62, 0.30),
	"casa": Color(0.62, 0.80, 0.96),
}
const COR_PADRAO := Color(0.85, 0.85, 0.85)

@onready var _raiz: Control = $Raiz
@onready var _mini: ColorRect = $Raiz/Mapa
@onready var _mini_marcas: Control = $Raiz/Marcadores
@onready var _mini_seta: Polygon2D = $Raiz/Seta

@onready var _grande: CanvasLayer = $Grande
@onready var _painel: Control = $Grande/Fundo/Painel
@onready var _big: ColorRect = $Grande/Fundo/Painel/Mapa
@onready var _big_marcas: Control = $Grande/Fundo/Painel/Marcadores
@onready var _big_seta: Polygon2D = $Grande/Fundo/Painel/Seta
@onready var _escala: Label = $Grande/Fundo/Escala

var _mat_mini: ShaderMaterial
var _mat_big: ShaderMaterial
var _player: Node3D = null
var _giro: float = 0.0
var _pronto: bool = false

# recorte do mundo coberto pela textura
var _x0: float = 0.0
var _z0: float = 0.0
var _tam: float = 1.0
var _pontos: Array = []

# estado do mapa grande
var _centro_big := Vector2(0.5, 0.5)
var _meia: float = 0.09
var _arrastando: bool = false


func _ready() -> void:
	# PROCESS_MODE_ALWAYS: sem isto o `_process` para junto com a árvore
	# quando o jogo pausa — o minimapa ficaria congelado por cima do menu em
	# vez de sumir, e o mapa grande não responderia ao zoom (ele só é usado
	# com o jogo pausado).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pronto = _ler_meta()
	if not _pronto:
		push_error("minimap: não consegui ler %s" % meta_json)
		visible = false
		return
	_mat_mini = _mini.material as ShaderMaterial
	_mat_big = _big.material as ShaderMaterial
	_montar_layout()
	_criar_marcadores()
	_grande.visible = false
	visible = false

	$Grande/Fundo/Botoes/menos.pressed.connect(func(): _zoom(1.0 / passo_zoom))
	$Grande/Fundo/Botoes/mais.pressed.connect(func(): _zoom(passo_zoom))
	$Grande/Fundo/Botoes/centralizar.pressed.connect(_centralizar)
	$Grande/Fundo/Botoes/voltar.pressed.connect(fechar_mapa)
	_big.gui_input.connect(_no_mapa_grande)
	_big.mouse_filter = Control.MOUSE_FILTER_STOP


func _ler_meta() -> bool:
	var txt := FileAccess.get_file_as_string(meta_json)
	if txt.is_empty():
		return false
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	_x0 = float(d.get("mundo_x0", 0.0))
	_z0 = float(d.get("mundo_z0", 0.0))
	_tam = float(d.get("tamanho_m", 1.0))
	_pontos = d.get("pontos", [])
	return _tam > 0.0


func _montar_layout() -> void:
	_raiz.position = margem_px
	_raiz.size = Vector2(tamanho_px, tamanho_px)
	_mini.position = Vector2.ZERO
	_mini.size = _raiz.size
	_mini_seta.position = _raiz.size * 0.5
	if _mat_mini:
		_mat_mini.set_shader_parameter("raio_uv", (alcance_m * 0.5) / _tam)
	if _mat_big:
		_mat_big.set_shader_parameter("grade_uv", 100.0 / _tam)
	_meia = (zoom_inicial_m * 0.5) / _tam


## Um nó por ponto, criado uma vez. No minimapa é só um losango; no mapa
## grande vai o rótulo junto.
func _criar_marcadores() -> void:
	for p in _pontos:
		var cor: Color = COR_TIPO.get(String(p.get("tipo", "")), COR_PADRAO)
		_mini_marcas.add_child(_marca(cor, 3.5, "", p))
		_big_marcas.add_child(_marca(cor, 7.0, String(p.get("nome", "")), p))


func _marca(cor: Color, r: float, rotulo: String, dados: Dictionary) -> Control:
	var no := Control.new()
	no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no.set_meta("mundo", Vector2(float(dados["x"]), float(dados["z"])))

	var losango := Polygon2D.new()
	losango.polygon = PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	losango.color = cor
	no.add_child(losango)

	# contorno escuro: sobre a rua clara do mapa um losango claro sozinho
	# desaparece
	var borda := Line2D.new()
	borda.points = PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0),
		Vector2(0, -r)])
	borda.width = 1.6
	borda.default_color = Color(0.05, 0.05, 0.05, 0.85)
	no.add_child(borda)

	if rotulo != "":
		var lb := Label.new()
		lb.text = rotulo
		lb.position = Vector2(r + 6.0, -11.0)
		lb.add_theme_color_override("font_color", cor)
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lb.add_theme_constant_override("outline_size", 5)
		lb.add_theme_font_size_override("font_size", 14)
		no.add_child(lb)
	return no


# ------------------------------------------------------------- por quadro
func _process(delta: float) -> void:
	if not _pronto:
		return
	if not _deve_aparecer():
		visible = false
		if _grande.visible:
			fechar_mapa()
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			visible = false
			return

	var p := _player.global_position
	var uv := Vector2((p.x - _x0) / _tam, (p.z - _z0) / _tam)

	# -rotation.y, e não +. Um nó com rotation.y = θ olha para
	# (-sen θ, 0, -cos θ). Para essa direção cair em CIMA na tela, a matriz
	# que gira a amostragem tem de ser a inversa — ou seja, ângulo -θ.
	var alvo := -_player.global_rotation.y
	if suavidade > 0.0:
		_giro = lerp_angle(_giro, alvo, clampf(delta * suavidade, 0.0, 1.0))
	else:
		_giro = alvo

	_mat_mini.set_shader_parameter("centro_uv", uv)
	_mat_mini.set_shader_parameter("giro", _giro)
	_pos_marcas_mini(uv)

	# o minimapa some enquanto o mapa grande está aberto: são a mesma coisa
	_raiz.visible = not _grande.visible
	if _grande.visible:
		_atualizar_grande(uv, alvo)
	visible = true


func _pos_marcas_mini(centro: Vector2) -> void:
	if not pontos_no_minimapa:
		_mini_marcas.visible = false
		return
	var raio_uv: float = (alcance_m * 0.5) / _tam
	var meio := _raiz.size * 0.5
	# inversa do shader: p = R(-giro) · (uv - centro) / raio
	var s := sin(-_giro)
	var c := cos(-_giro)
	for no in _mini_marcas.get_children():
		var m: Vector2 = no.get_meta("mundo")
		var d := (Vector2((m.x - _x0) / _tam, (m.y - _z0) / _tam) - centro) / raio_uv
		var q := Vector2(d.x * c - d.y * s, d.x * s + d.y * c)
		if q.length() > 0.94:
			no.visible = false
			continue
		no.visible = true
		no.position = meio + q * meio


func _atualizar_grande(uv_player: Vector2, yaw: float) -> void:
	var tam := _painel.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	var aspecto := tam.x / tam.y
	_mat_big.set_shader_parameter("aspecto", aspecto)
	_mat_big.set_shader_parameter("centro_uv", _centro_big)
	_mat_big.set_shader_parameter("meia_janela", _meia)

	_big_seta.position = _uv_para_tela(uv_player, tam, aspecto)
	# mesma dedução do minimapa: girar (0,-1) por φ dá (sen φ, -cos φ), que
	# tem de bater com a frente do player (-sen θ, -cos θ)  ⇒  φ = -θ
	_big_seta.rotation = -yaw
	_big_seta.visible = _dentro(_big_seta.position, tam)

	for no in _big_marcas.get_children():
		var m: Vector2 = no.get_meta("mundo")
		var q := _uv_para_tela(
			Vector2((m.x - _x0) / _tam, (m.y - _z0) / _tam), tam, aspecto)
		no.position = q
		no.visible = _dentro(q, tam)

	_escala.text = "%d m de altura  ·  zoom %.1fx" % [
		int(round(_meia * 2.0 * _tam)),
		(zoom_max_m * 0.5 / _tam) / _meia]


func _uv_para_tela(uv: Vector2, tam: Vector2, aspecto: float) -> Vector2:
	# inversa exata do shader: uv = centro + vec2(p.x*aspecto, p.y) * meia
	var d := (uv - _centro_big) / _meia
	var p := Vector2(d.x / aspecto, d.y)
	return Vector2((p.x * 0.5 + 0.5) * tam.x, (p.y * 0.5 + 0.5) * tam.y)


func _dentro(q: Vector2, tam: Vector2) -> bool:
	return q.x >= -40.0 and q.y >= -40.0 and q.x <= tam.x + 40.0 \
		and q.y <= tam.y + 40.0


# --------------------------------------------------------------- abre/fecha
func pode_abrir_mapa() -> bool:
	return _pronto and _deve_aparecer_sem_pausa()


func abrir_mapa() -> void:
	if not _pronto:
		return
	_centralizar()
	_grande.visible = true
	visible = true
	$Grande/Fundo/Botoes/voltar.grab_focus()


func fechar_mapa() -> void:
	_grande.visible = false
	_arrastando = false
	mapa_fechado.emit()


signal mapa_fechado


func _centralizar() -> void:
	if is_instance_valid(_player):
		var p := _player.global_position
		_centro_big = Vector2((p.x - _x0) / _tam, (p.z - _z0) / _tam)
	else:
		_centro_big = Vector2(0.5, 0.5)
	_meia = (zoom_inicial_m * 0.5) / _tam
	_limitar_centro()


# ----------------------------------------------------------------- entrada
func _input(event: InputEvent) -> void:
	if not _grande.visible:
		return
	# consumido aqui, em `_input`, para o menu de pausa não ver o mesmo ESC
	# em `_unhandled_input` e reabrir/fechar junto
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause"):
		fechar_mapa()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_centralizar()
		get_viewport().set_input_as_handled()


func _no_mapa_grande(event: InputEvent) -> void:
	var tam := _painel.size
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(passo_zoom, event.position, tam)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(1.0 / passo_zoom, event.position, tam)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_arrastando = event.pressed
	elif event is InputEventMouseMotion and _arrastando:
		var aspecto := tam.x / tam.y
		# arrastar para a direita leva o mapa junto: o centro anda ao contrário
		_centro_big -= Vector2(
			(event.relative.x / tam.x) * 2.0 * _meia * aspecto,
			(event.relative.y / tam.y) * 2.0 * _meia)
		_limitar_centro()


## `foco` é a posição do cursor no painel: o ponto sob o cursor fica parado
## durante o zoom, que é o que se espera de um mapa.
func _zoom(fator: float, foco := Vector2(-1, -1), tam := Vector2.ZERO) -> void:
	if tam == Vector2.ZERO:
		tam = _painel.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	var aspecto := tam.x / tam.y
	var novo := clampf(_meia / fator,
		(zoom_min_m * 0.5) / _tam, (zoom_max_m * 0.5) / _tam)
	if foco.x >= 0.0:
		var p := Vector2((foco.x / tam.x - 0.5) * 2.0 * aspecto,
						 (foco.y / tam.y - 0.5) * 2.0)
		var sob := _centro_big + p * _meia
		_centro_big = sob - p * novo
	_meia = novo
	_limitar_centro()


## Prende a janela dentro do papel. O limite depende do zoom: enquanto a
## janela é menor que o mapa, ela anda até encostar na borda; quando fica
## maior que o mapa, o mapa é centralizado em vez de ficar largado num canto,
## que era o que acontecia no zoom máximo.
func _limitar_centro() -> void:
	var tam := _painel.size
	var aspecto: float = (tam.x / tam.y) if tam.y > 0.0 else 1.0
	_centro_big.x = _prender(_centro_big.x, _meia * aspecto)
	_centro_big.y = _prender(_centro_big.y, _meia)


func _prender(v: float, meia: float) -> float:
	if meia >= 0.5:
		return 0.5
	return clampf(v, meia, 1.0 - meia)


# ------------------------------------------------------------ visibilidade
func _deve_aparecer_sem_pausa() -> bool:
	if not GlobalEvents.is_maycow_normal:
		return false
	if GlobalEvents.in_cutscene:
		return false
	return true


func _deve_aparecer() -> bool:
	# o mapa grande é justamente para ser usado com o jogo pausado
	if get_tree().paused and not _grande.visible:
		return false
	return _deve_aparecer_sem_pausa()
