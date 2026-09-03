class_name MapaDados
extends RefCounted
## Recorte do mundo coberto por T_citymap.png, e os pontos de interesse.
##
## Escrito por tools/blender/citygen/textures/make_minimap.py junto com a
## textura. Ler daqui em vez de repetir os números garante que, se a cidade
## for regerada num tamanho diferente, o minimapa e o mapa do menu
## acompanhem sozinhos.
##
## Os pontos trazem `chave`, não texto: quem escreve na tela usa `tr()`.

const CAMINHO := "res://assets/3d_model/city/citymap.json"

var ok: bool = false
var x0: float = 0.0
var z0: float = 0.0
var tam: float = 1.0
var pontos: Array = []


func _init(caminho: String = CAMINHO) -> void:
	var txt := FileAccess.get_file_as_string(caminho)
	if txt.is_empty():
		push_error("MapaDados: não consegui ler %s" % caminho)
		return
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		push_error("MapaDados: %s inválido" % caminho)
		return
	x0 = float(d.get("mundo_x0", 0.0))
	z0 = float(d.get("mundo_z0", 0.0))
	tam = float(d.get("tamanho_m", 1.0))
	pontos = d.get("pontos", [])
	ok = tam > 0.0


## Mundo (X, Z) -> UV da textura.
func uv(mundo_x: float, mundo_z: float) -> Vector2:
	return Vector2((mundo_x - x0) / tam, (mundo_z - z0) / tam)


## Existe mapa utilizável nesta cena, para este Maycow?
static func disponivel(arvore: SceneTree) -> bool:
	if not GlobalEvents.is_maycow_normal:
		return false
	if GlobalEvents.in_cutscene:
		return false
	return arvore.get_first_node_in_group("mapa_cidade") != null
