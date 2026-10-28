extends Node

## SELECAO DE ITEM DE CENARIO PARA QUEM NAO E' ITEM DE BALCAO.
##
## Todo item que se pega do cenario passa pelo mesmo ritual do balcao do
## hospital (`item_de_balcao.gd`): chegando perto, ele fica SELECIONADO — realce
## ambar, prompt, um clique sutil — e so' entao o `ui_accept` pega, com o som de
## ir pro bolso. Este no' leva esse ritual pra pickups cujo "pegar" mora em outro
## script (a lanterna da escola, a municao que reaparece na igreja): ele cuida
## da selecao e avisa por `pegar`; o dono decide o que acontece depois.
##
## Ele entra na MESMA disputa dos itens de balcao (o grupo e a arbitragem pela
## mira sao os de la'), entao dois pickups lado a lado nunca acendem juntos,
## seja qual for o script de cada um.
##
## Uso:
##     var sel := preload("res://scripts/stages/hospital/item_selecionavel.gd").new()
##     add_child(sel)
##     sel.configurar(objeto, area, "PROMPT_TAKE_X")
##     sel.pegar.connect(_pegar)
##     # e `sel.disponivel = false` enquanto nao houver o que pegar

signal pegar

const Balcao := preload("res://scripts/stages/hospital/item_de_balcao.gd")
const MarcaDeItem := preload("res://scripts/stages/hospital/marca_de_item.gd")

## Falso enquanto nao ha' o que pegar (ja' pego, esperando reaparecer...).
var disponivel: bool = true

## O objeto: o que acende e o ponto que a mira procura.
var _raiz: Node3D = null
var _prompt: String = ""
var _perto: bool = false
var _malhas: Array = []
var _overlay_atual: ShaderMaterial = null
var _prompt_ligado: bool = false
var _marca: Node3D = null


func configurar(objeto: Node3D, area: Area3D, chave_prompt: String) -> void:
	_raiz = objeto
	_prompt = chave_prompt
	_malhas = _recolher_malhas(objeto)
	add_to_group(Balcao.GRUPO)
	# o indicador de perto; deferido porque o dono pode estar no meio do _ready
	_marca = MarcaDeItem.new()
	_marca.dono = objeto
	_marca.malhas = _malhas
	objeto.add_child.call_deferred(_marca)
	if area:
		area.body_entered.connect(_ao_entrar)
		area.body_exited.connect(_ao_sair)


func _exit_tree() -> void:
	if Balcao._selecionado == self:
		Balcao._selecionado = null
	_mostrar_prompt(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_raiz):
		return
	if is_instance_valid(_marca):
		_marca.ativa = disponivel
	Balcao._arbitrar(get_tree(), get_viewport().get_camera_3d())

	var escolhido: bool = Balcao._selecionado == self
	if escolhido:
		_pintar(Balcao._material_selecao())
	elif _disputando():
		_pintar(Balcao._material_realce())
	else:
		_pintar(null)
	_mostrar_prompt(escolhido)

	if escolhido and Input.is_action_just_pressed("ui_accept"):
		disponivel = false
		Balcao._selecionado = null
		_pintar(null)
		_mostrar_prompt(false)
		Balcao.tocar_som(get_tree(), Balcao.SOM_PEGAR, Balcao.VOLUME_PEGAR)
		pegar.emit()


## Chamado pela arbitragem do `item_de_balcao.gd`, como em qualquer item dela.
func _disputando() -> bool:
	if not disponivel or not _perto or not is_instance_valid(_raiz):
		return false
	if not _raiz.is_visible_in_tree():
		return false
	return not (GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene \
		or GlobalEvents.agarrao_rodando)


## Mesma nota dos itens de balcao: distancia ao centro da tela.
func _nota_de_mira(camera: Camera3D) -> float:
	if camera == null or not is_instance_valid(_raiz):
		return INF
	var ponto := _raiz.global_position + Vector3.UP * Balcao.ALTURA_DA_MIRA
	if camera.is_position_behind(ponto):
		return INF
	var tela := camera.unproject_position(ponto)
	var janela := Vector2(camera.get_viewport().get_visible_rect().size)
	if janela.y <= 0.0:
		return INF
	return tela.distance_to(janela * 0.5) / janela.y


func _recolher_malhas(no: Node) -> Array:
	var achadas: Array = []
	if no is MeshInstance3D:
		achadas.append(no)
	for filho in no.get_children():
		achadas.append_array(_recolher_malhas(filho))
	return achadas


## Mesma regra do balcao: so' mexe em overlay vazio ou nosso.
func _pintar(desejado: ShaderMaterial) -> void:
	if desejado == _overlay_atual:
		return
	_overlay_atual = desejado
	for m in _malhas:
		if not is_instance_valid(m):
			continue
		if not (m.material_overlay == null or m.material_overlay == Balcao._mat_realce
				or m.material_overlay == Balcao._mat_selecao):
			continue
		m.material_overlay = desejado


## So' na virada, pelo mesmo motivo do balcao.
func _mostrar_prompt(ligado: bool) -> void:
	if ligado == _prompt_ligado:
		return
	_prompt_ligado = ligado
	if ligado:
		Balcao.tocar_som(get_tree(), Balcao.SOM_SELECIONAR, Balcao.VOLUME_SELECIONAR)
		GlobalUtils.show_center_message(_chave_mensagem(), tr(_prompt), 16)
	else:
		GlobalUtils.hide_center_message(_chave_mensagem())


func _chave_mensagem() -> String:
	return "pegar_" + str(get_instance_id())


func _ao_entrar(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower() == "player":
		_perto = true


func _ao_sair(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower() == "player":
		_perto = false
