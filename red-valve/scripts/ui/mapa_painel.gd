extends Control
## Mapa da cidade em tamanho grande, para a aba MAPA do menu do jogo.
##
## Norte sempre para cima e quem gira é a seta do player — ao contrário do
## minimapa do HUD. Com rótulo escrito na tela, girar o mapa deixaria os
## nomes de cabeça para baixo.
##
## Controles: analógico esquerdo move, analógico direito dá zoom, roda do
## mouse dá zoom no ponto sob o cursor, arrastar move, R centraliza.

## Altura da janela visível, em metros, nos extremos do zoom.
##
## 80 e não 40: a textura tem 3,01 px/m, e a 40 m de altura o painel a amplia
## 4,5 vezes — vira borrão. A 80 m a ampliação é 2,2x, que ainda lê bem.
@export var zoom_min_m: float = 80.0
## 560 e não 680 (o lado inteiro da textura): o papel tem 680 m mas a cidade
## só ocupa 600 x 420 no meio dele. Deixar afastar até ver o papel inteiro só
## rendia margem de mata vazia em volta.
@export var zoom_max_m: float = 560.0
@export var zoom_inicial_m: float = 260.0
## Quanto cada passo da roda multiplica o zoom.
@export var passo_zoom: float = 1.18
## Janelas por segundo com o analógico esquerdo no talo.
@export var vel_analogico: float = 0.9
## Multiplicador de zoom por segundo com o analógico direito no talo.
@export var vel_zoom_analogico: float = 2.4
@export var zona_morta: float = 0.2

const COR_TIPO := {
	"marco": Color(0.55, 0.86, 0.70),
	"local": Color(0.95, 0.62, 0.30),
	"casa": Color(0.62, 0.80, 0.96),
}
const COR_PADRAO := Color(0.85, 0.85, 0.85)

@onready var _painel: Control = $Painel
@onready var _mapa: ColorRect = $Painel/Mapa
@onready var _marcas: Control = $Painel/Marcadores
@onready var _seta: Polygon2D = $Painel/Seta
@onready var _escala: Label = $Escala
@onready var _ajuda_pad: Label = $AjudaPad
@onready var _ajuda_mouse: Label = $AjudaMouse
@onready var _indisponivel: Label = $Indisponivel
@onready var _btn_centralizar: Button = $Centralizar

var _dados: MapaDados
var _mat: ShaderMaterial
var _player: Node3D = null
var _centro := Vector2(0.5, 0.5)
var _meia: float = 0.09
var _arrastando: bool = false
var _ativo: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dados = MapaDados.new()
	_mat = _mapa.material as ShaderMaterial
	if _dados.ok and _mat:
		_mat.set_shader_parameter("grade_uv", 100.0 / _dados.tam)
		_criar_marcadores()
	_btn_centralizar.text = tr("MAP_RECENTER")
	_btn_centralizar.pressed.connect(centralizar)
	_ajuda_pad.text = tr("MAP_HELP_PAD")
	_ajuda_mouse.text = tr("MAP_HELP_MOUSE")
	_indisponivel.text = tr("MAP_UNAVAILABLE")
	_mapa.gui_input.connect(_no_mapa)
	set_process(false)


## Chamado pela aba quando ela entra em foco.
func ativar() -> void:
	_ativo = _dados.ok and MapaDados.disponivel(get_tree())
	_painel.visible = _ativo
	_escala.visible = _ativo
	_btn_centralizar.visible = _ativo
	_legendas()
	_indisponivel.visible = not _ativo
	set_process(_ativo)
	if _ativo:
		centralizar()
		_atualizar()


func desativar() -> void:
	_ativo = false
	_arrastando = false
	set_process(false)


func _criar_marcadores() -> void:
	for p in _dados.pontos:
		var cor: Color = COR_TIPO.get(String(p.get("tipo", "")), COR_PADRAO)
		_marcas.add_child(_marca(cor, 7.0, String(p.get("chave", "")), p))


func _marca(cor: Color, r: float, chave: String, dados: Dictionary) -> Control:
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

	if chave != "":
		var lb := Label.new()
		# tr() e não o texto: o nome vem do CSV de tradução. Jimmy, Maycow e
		# Nice são nomes de pessoa e ficam iguais nos dois idiomas.
		lb.text = tr(chave)
		lb.position = Vector2(r + 6.0, -11.0)
		lb.add_theme_color_override("font_color", cor)
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lb.add_theme_constant_override("outline_size", 5)
		lb.add_theme_font_size_override("font_size", 14)
		no.add_child(lb)
		no.set_meta("rotulo", lb)
		no.set_meta("raio", r)
	return no


# ------------------------------------------------------------- por quadro
func _process(delta: float) -> void:
	if not _ativo:
		return
	_analogicos(delta)
	_atualizar()


## Esquerdo move, direito dá zoom. `get_vector` devolve o valor analógico,
## então o movimento é proporcional à inclinação do manche. As setas e o WASD
## caem no mesmo `ui_left/right/up/down` e movem o mapa também — de graça.
func _analogicos(delta: float) -> void:
	var mover := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if mover.length() > zona_morta:
		var tam := _painel.size
		var aspecto: float = (tam.x / tam.y) if tam.y > 0.0 else 1.0
		_centro += Vector2(mover.x * aspecto, mover.y) \
			* _meia * 2.0 * vel_analogico * delta
		_limitar_centro()

	var olhar := Input.get_vector(
		"ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
	if absf(olhar.y) > zona_morta:
		# manche para cima (y negativo) aproxima
		_zoom(pow(vel_zoom_analogico, -olhar.y * delta))


func _atualizar() -> void:
	var tam := _painel.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	var aspecto := tam.x / tam.y
	_mat.set_shader_parameter("aspecto", aspecto)
	_mat.set_shader_parameter("centro_uv", _centro)
	_mat.set_shader_parameter("meia_janela", _meia)

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(_player):
		var p := _player.global_position
		_seta.position = _para_tela(_dados.uv(p.x, p.z), tam, aspecto)
		# girar (0,-1) por φ dá (sen φ, -cos φ), que tem de bater com a frente
		# do player, (-sen θ, -cos θ)  ⇒  φ = -θ
		_seta.rotation = -_player.global_rotation.y
		_seta.visible = _dentro(_seta.position, tam)
	else:
		_seta.visible = false

	for no in _marcas.get_children():
		var m: Vector2 = no.get_meta("mundo")
		var q := _para_tela(_dados.uv(m.x, m.y), tam, aspecto)
		no.position = q
		no.visible = _dentro(q, tam)
		if no.visible and no.has_meta("rotulo"):
			_lado_do_rotulo(no, q, tam)

	_legendas()
	_escala.text = tr("MAP_SCALE").format({
		"h": int(round(_meia * 2.0 * _dados.tam)),
		"z": "%.1f" % ((zoom_max_m * 0.5 / _dados.tam) / _meia)})


## Uma legenda ou a outra, nunca as duas: mostra a do dispositivo que o
## jogador está usando de fato. `GlobalEvents` sabe disso porque acompanha os
## eventos de entrada — o painel só pergunta.
func _legendas() -> void:
	var pad: bool = GlobalEvents.usando_controle
	_ajuda_pad.visible = _ativo and pad
	_ajuda_mouse.visible = _ativo and not pad


## Rótulo à direita do losango; perto da borda direita, vira para a esquerda.
## Sem isto o nome sai cortado pelo `clip_contents` do painel.
func _lado_do_rotulo(no: Control, q: Vector2, tam: Vector2) -> void:
	var lb: Label = no.get_meta("rotulo")
	var r: float = no.get_meta("raio")
	var larg := lb.get_minimum_size().x
	if q.x + r + 6.0 + larg > tam.x - 4.0:
		lb.position.x = -(r + 6.0 + larg)
	else:
		lb.position.x = r + 6.0


## Inversa exata do shader: uv = centro + vec2(p.x*aspecto, p.y) * meia
func _para_tela(uv: Vector2, tam: Vector2, aspecto: float) -> Vector2:
	var d := (uv - _centro) / _meia
	var p := Vector2(d.x / aspecto, d.y)
	return Vector2((p.x * 0.5 + 0.5) * tam.x, (p.y * 0.5 + 0.5) * tam.y)


func _dentro(q: Vector2, tam: Vector2) -> bool:
	return q.x >= -40.0 and q.y >= -40.0 and q.x <= tam.x + 40.0 \
		and q.y <= tam.y + 40.0


# ----------------------------------------------------------------- entrada
func centralizar() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(_player):
		var p := _player.global_position
		_centro = _dados.uv(p.x, p.z)
	else:
		_centro = Vector2(0.5, 0.5)
	_meia = (zoom_inicial_m * 0.5) / _dados.tam
	_limitar_centro()


func _input(event: InputEvent) -> void:
	if not _ativo:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		centralizar()
		get_viewport().set_input_as_handled()


func _no_mapa(event: InputEvent) -> void:
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
		_centro -= Vector2(
			(event.relative.x / tam.x) * 2.0 * _meia * aspecto,
			(event.relative.y / tam.y) * 2.0 * _meia)
		_limitar_centro()


## `foco` é a posição do cursor no painel: o ponto sob o cursor fica parado
## durante o zoom, que é o que se espera de um mapa. Sem foco (analógico e
## botões), o zoom é pelo centro.
func _zoom(fator: float, foco := Vector2(-1, -1), tam := Vector2.ZERO) -> void:
	if tam == Vector2.ZERO:
		tam = _painel.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	var aspecto := tam.x / tam.y
	var novo := clampf(_meia / fator,
		(zoom_min_m * 0.5) / _dados.tam, (zoom_max_m * 0.5) / _dados.tam)
	if foco.x >= 0.0:
		var p := Vector2((foco.x / tam.x - 0.5) * 2.0 * aspecto,
						 (foco.y / tam.y - 0.5) * 2.0)
		var sob := _centro + p * _meia
		_centro = sob - p * novo
	_meia = novo
	_limitar_centro()


## Prende a janela dentro do papel. O limite depende do zoom: enquanto a
## janela é menor que o mapa, ela anda até encostar na borda; quando fica
## maior que o mapa, o mapa é centralizado em vez de ficar largado num canto.
func _limitar_centro() -> void:
	var tam := _painel.size
	var aspecto: float = (tam.x / tam.y) if tam.y > 0.0 else 1.0
	_centro.x = _prender(_centro.x, _meia * aspecto)
	_centro.y = _prender(_centro.y, _meia)


func _prender(v: float, meia: float) -> float:
	if meia >= 0.5:
		return 0.5
	return clampf(v, meia, 1.0 - meia)
