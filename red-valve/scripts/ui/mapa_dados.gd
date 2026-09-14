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


## O nó que declara QUAL mapa esta cena usa.
##
## É o próprio minimapa do HUD: ele já precisa estar na cena para aparecer no
## canto da tela, já carrega a textura e já está no grupo. A aba MAPA do menu
## pergunta a ele em vez de ter uma lista de cena -> mapa em algum lugar — cena
## nova com mapa novo é só instanciar o minimapa certo lá dentro.
static func perfil(arvore: SceneTree) -> Node:
	return arvore.get_first_node_in_group("mapa_cidade")


## Caminho do JSON de mapa da cena atual, ou "" se esta cena não tem mapa.
static func caminho_da_cena(arvore: SceneTree) -> String:
	var no := perfil(arvore)
	if no == null:
		return ""
	# `get` devolve null quando a propriedade não existe — um minimapa antigo,
	# sem o export, ainda vale como "esta cena tem o mapa da cidade".
	var c = no.get("dados_json")
	if typeof(c) != TYPE_STRING or String(c).is_empty():
		return CAMINHO
	return String(c)


## Este ponto deve aparecer agora?
##
## `oculto_com_item` some quando o jogador tem o item no inventário — é assim
## que a interrogação da lanterna desaparece no instante em que ela é pega. A
## pergunta é ao inventário, e não a uma flag à parte: um save antigo que já
## tenha a lanterna também chega aqui com o mapa limpo.
static func ponto_visivel(p: Dictionary) -> bool:
	var item := String(p.get("oculto_com_item", ""))
	if item.is_empty():
		return true
	return not SaveManager.tem_item(item)
