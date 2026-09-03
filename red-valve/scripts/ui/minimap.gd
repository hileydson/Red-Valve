extends CanvasLayer
## Minimapa da cidade, canto superior esquerdo.
##
## Só existe no stage_1, e só aparece no gameplay com o Maycow normal.
##
## O mapa é uma textura assada a partir dos DADOS da cidade
## (tools/blender/citygen/textures/make_minimap.py), não um render da cena:
## fica legível a 200 px, não depende da hora do dia nem da iluminação, e
## regerar custa dois segundos. O recorte do mundo que ela cobre vem no
## `citymap.json` que o mesmo script escreve — nada aqui é número mágico.

## Diâmetro, em metros de mundo, do que cabe dentro do círculo.
@export var alcance_m: float = 130.0
## Lado do minimapa em pixels.
@export var tamanho_px: float = 190.0
## Distância até o canto da tela.
@export var margem_px: Vector2 = Vector2(26.0, 26.0)
## Suavização do giro. 0 = acompanha na hora.
@export var suavidade: float = 12.0
@export var meta_json: String = "res://assets/3d_model/city/citymap.json"

@onready var _mapa: ColorRect = $Raiz/Mapa
@onready var _seta: Polygon2D = $Raiz/Seta

var _mat: ShaderMaterial
var _player: Node3D = null
var _giro: float = 0.0
var _pronto: bool = false

# recorte do mundo coberto pela textura
var _x0: float = 0.0
var _z0: float = 0.0
var _tam: float = 1.0


func _ready() -> void:
	# PROCESS_MODE_ALWAYS: sem isto o `_process` para junto com a árvore
	# quando o jogo pausa, e o minimapa ficaria congelado por cima do menu
	# em vez de sumir.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pronto = _ler_meta()
	if not _pronto:
		push_error("minimap: não consegui ler %s" % meta_json)
		visible = false
		return
	_mat = _mapa.material as ShaderMaterial
	_montar_layout()
	visible = false


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
	return _tam > 0.0


func _montar_layout() -> void:
	var r: Control = $Raiz
	r.position = margem_px
	r.size = Vector2(tamanho_px, tamanho_px)
	_mapa.position = Vector2.ZERO
	_mapa.size = r.size
	_seta.position = r.size * 0.5
	if _mat:
		# raio em UV: metade do alcance, dividido pelo lado do recorte
		_mat.set_shader_parameter("raio_uv", (alcance_m * 0.5) / _tam)


func _process(delta: float) -> void:
	if not _pronto:
		return
	if not _deve_aparecer():
		visible = false
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			visible = false
			return

	var p := _player.global_position
	_mat.set_shader_parameter("centro_uv", Vector2(
		(p.x - _x0) / _tam, (p.z - _z0) / _tam))

	# -rotation.y, e não +. Um nó com rotation.y = θ olha para
	# (-sen θ, 0, -cos θ). Para essa direção cair em CIMA na tela, a matriz
	# que gira a amostragem tem de ser a inversa — ou seja, ângulo -θ.
	var alvo := -_player.global_rotation.y
	if suavidade > 0.0:
		_giro = lerp_angle(_giro, alvo, clampf(delta * suavidade, 0.0, 1.0))
	else:
		_giro = alvo
	_mat.set_shader_parameter("giro", _giro)

	visible = true


func _deve_aparecer() -> bool:
	if get_tree().paused:
		return false
	if not GlobalEvents.is_maycow_normal:
		return false
	if GlobalEvents.in_cutscene:
		return false
	return true
