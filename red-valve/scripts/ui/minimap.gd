extends CanvasLayer
## Minimapa no canto superior esquerdo, girando com o player.
##
## Só existe no stage_1, e só aparece no gameplay com o Maycow normal.
## O mapa em tamanho grande é outra coisa: fica na aba MAPA do menu do jogo
## (scenes/ui/mapa_painel.tscn).
##
## A textura é assada a partir dos DADOS da cidade
## (tools/blender/citygen/textures/make_minimap.py), não um render da cena:
## fica legível a 190 px, não depende da hora do dia nem da iluminação, e
## regerar custa dois segundos.
##
## O grupo "mapa_cidade" é como o menu descobre que esta fase tem mapa.

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

const COR_TIPO := {
	"marco": Color(0.55, 0.86, 0.70),
	"local": Color(0.95, 0.62, 0.30),
	"casa": Color(0.62, 0.80, 0.96),
}
const COR_PADRAO := Color(0.85, 0.85, 0.85)

@onready var _raiz: Control = $Raiz
@onready var _mini: ColorRect = $Raiz/Mapa
@onready var _marcas: Control = $Raiz/Marcadores
@onready var _seta: Polygon2D = $Raiz/Seta

var _dados: MapaDados
var _mat: ShaderMaterial
var _player: Node3D = null
var _giro: float = 0.0


func _ready() -> void:
	# PROCESS_MODE_ALWAYS: sem isto o `_process` para junto com a árvore
	# quando o jogo pausa, e o minimapa ficaria congelado por cima do menu em
	# vez de sumir.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dados = MapaDados.new()
	if not _dados.ok:
		visible = false
		set_process(false)
		return
	_mat = _mini.material as ShaderMaterial
	_raiz.position = margem_px
	_raiz.size = Vector2(tamanho_px, tamanho_px)
	_mini.position = Vector2.ZERO
	_mini.size = _raiz.size
	_seta.position = _raiz.size * 0.5
	_mat.set_shader_parameter("raio_uv", (alcance_m * 0.5) / _dados.tam)
	_criar_marcadores()
	visible = false


## Losango sem rótulo: nome escrito não cabe em 190 px.
func _criar_marcadores() -> void:
	if not pontos_no_minimapa:
		_marcas.visible = false
		return
	for p in _dados.pontos:
		var cor: Color = COR_TIPO.get(String(p.get("tipo", "")), COR_PADRAO)
		var no := Control.new()
		no.mouse_filter = Control.MOUSE_FILTER_IGNORE
		no.set_meta("mundo", Vector2(float(p["x"]), float(p["z"])))
		var losango := Polygon2D.new()
		losango.polygon = PackedVector2Array([
			Vector2(0, -3.5), Vector2(3.5, 0), Vector2(0, 3.5), Vector2(-3.5, 0)])
		losango.color = cor
		no.add_child(losango)
		var borda := Line2D.new()
		borda.points = PackedVector2Array([
			Vector2(0, -3.5), Vector2(3.5, 0), Vector2(0, 3.5),
			Vector2(-3.5, 0), Vector2(0, -3.5)])
		borda.width = 1.4
		borda.default_color = Color(0.05, 0.05, 0.05, 0.85)
		no.add_child(borda)
		_marcas.add_child(no)


func _process(delta: float) -> void:
	if get_tree().paused or not MapaDados.disponivel(get_tree()):
		visible = false
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			visible = false
			return

	var p := _player.global_position
	var uv := _dados.uv(p.x, p.z)

	# -rotation.y, e não +. Um nó com rotation.y = θ olha para
	# (-sen θ, 0, -cos θ). Para essa direção cair em CIMA na tela, a matriz
	# que gira a amostragem tem de ser a inversa — ou seja, ângulo -θ.
	var alvo := -_player.global_rotation.y
	if suavidade > 0.0:
		_giro = lerp_angle(_giro, alvo, clampf(delta * suavidade, 0.0, 1.0))
	else:
		_giro = alvo

	_mat.set_shader_parameter("centro_uv", uv)
	_mat.set_shader_parameter("giro", _giro)
	_pos_marcas(uv)
	visible = true


func _pos_marcas(centro: Vector2) -> void:
	if not pontos_no_minimapa:
		return
	var raio_uv: float = (alcance_m * 0.5) / _dados.tam
	var meio := _raiz.size * 0.5
	# inversa do shader: p = R(-giro) · (uv - centro) / raio
	var s := sin(-_giro)
	var c := cos(-_giro)
	for no in _marcas.get_children():
		var m: Vector2 = no.get_meta("mundo")
		var d := (_dados.uv(m.x, m.y) - centro) / raio_uv
		var q := Vector2(d.x * c - d.y * s, d.x * s + d.y * c)
		if q.length() > 0.94:
			no.visible = false
			continue
		no.visible = true
		no.position = meio + q * meio
