extends Node3D

## A PISTOLA DO JIMMY, guardada na gaveta do criado-mudo do quarto dele (q3).
##
## A arma é do Jimmy: o Maycow acha ela na casa do patrão, e não mais no altar
## da Dona Nice. O criado-mudo fica selecionável como qualquer pickup
## (`item_selecionavel.gd`, prompt "Abrir a gaveta?"); abrir faz a gaveta
## deslizar pra fora e mostra a pistola e uma caixa de balas lá dentro. Os dois
## são itens de balcão normais (`item_de_balcao.gd`), filhos da gaveta: pegar,
## tela de item obtido, save e "já peguei" são os de sempre.
##
## A gaveta aberta fica no save (`pickups_pegos`, id GAVETA): voltando à casa
## ela continua aberta, com o que sobrou dentro.
##
## Quem cria é a cena da casa (`casa_jimmy_interior.gd`).

const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")
const ItemDeBalcao := preload("res://scripts/stages/hospital/item_de_balcao.gd")

const GAVETA := "casa_jimmy_gaveta_aberta"
const PISTOLA := "casa_jimmy_pistola_gaveta"
const MUNICAO := "casa_jimmy_municao_gaveta"

## Nó da gaveta dentro do .gltf do criado-mudo da Poly Haven.
const NO_GAVETA := "painted_wooden_nightstand_drawer"
const MODELO_PISTOLA := "res://assets/3d_model/player/the_negotiator_V1/the_negotiator_v1.glb"
const MODELO_MUNICAO := "res://assets/3d_model/player/the_negotiator_V1/cartridge/scene.gltf"
const SOM_ABRIR := "res://assets/sounds/igreja/destrancar_porta.ogg"

## A gaveta tem 42 cm de fundo; sai 26 e o fundo dela fica à vista.
const CURSO := 0.26
const TEMPO_ABRIR := 0.5
## Fundo interno da gaveta, no espaço do nó dela (a caixa vai de -0,045 a 0,05).
const FUNDO := -0.03

## Id do save da gaveta aberta. A gaveta da chave da Dona Nice
## (`gaveta_chave.gd`) herda daqui e troca o id e o que vai dentro.
var id_gaveta: String = GAVETA

var _gaveta: Node3D
var _selecao: Node


## Monta tudo em cima do criado-mudo `movel` (o nó da mobília).
func instalar(movel: Node3D) -> bool:
	_gaveta = movel.find_child(NO_GAVETA, true, false) as Node3D
	if _gaveta == null:
		push_warning("gaveta_pistola: %s sem a gaveta '%s'" % [movel.name, NO_GAVETA])
		return false
	global_transform = movel.global_transform

	if SaveManager.pickup_ja_pego(id_gaveta):
		_gaveta.position.z += CURSO
		_por_itens()
		return true

	# Área generosa: a cápsula do jogador tem 1,35 m e para longe do móvel.
	var area := Area3D.new()
	area.collision_layer = 0
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(3.2, 2.0, 3.2)
	forma.shape = caixa
	forma.position = Vector3(0, 0.6, 0.5)
	area.add_child(forma)
	add_child(area)

	_selecao = ItemSelecionavel.new()
	add_child(_selecao)
	_selecao.configurar(_gaveta, area, "PROMPT_ABRIR_GAVETA")
	_selecao.pegar.connect(_abrir)
	return true


func _abrir() -> void:
	_selecao.disponivel = false
	SaveManager.marcar_pickup(id_gaveta)
	SaveManager.save_game()
	ItemDeBalcao.tocar_som(get_tree(), SOM_ABRIR, -6.0)

	var tween := create_tween()
	tween.tween_property(_gaveta, "position:z", _gaveta.position.z + CURSO, TEMPO_ABRIR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_selecao.queue_free()
	_por_itens()


## Pistola deitada no fundo da gaveta e a caixa de balas do lado. Cada um some
## sozinho se já foi pego (`item_de_balcao._ja_foi_recolhido`).
func _por_itens() -> void:
	# Deitada de lado como no altar: 0,115 devolve os 22 cm do .glb e 0,021 é a
	# meia espessura que a tira de dentro do fundo.
	var deitada := Transform3D(Basis(Vector3(0.115, 0, 0), Vector3(0, 0, -0.115),
		Vector3(0, 0.115, 0)), Vector3(0, 0.021, 0))
	_item(PISTOLA, "pistol", 1, "PROMPT_TAKE_PISTOL", "PICKUP_PISTOL_JIMMY", "",
		MODELO_PISTOLA, deitada, Vector3(0.06, FUNDO, -0.17), 1.4)
	_item(MUNICAO, "pistol_ammo", 12, "PROMPT_TAKE_AMMO", "PICKUP_AMMO", "PICKUP_AMMO_AGAIN",
		MODELO_MUNICAO, Transform3D(Basis(), Vector3(0, 0.036, 0)), Vector3(-0.09, FUNDO, -0.25), 0.1)


func _item(id: String, item: String, quantidade: int, prompt: String, texto: String,
		repetido: String, modelo: String, pose_modelo: Transform3D, onde: Vector3, giro: float) -> void:
	var no := Node3D.new()
	no.name = id
	no.set_meta("id", id)
	no.set_meta("item", item)
	no.set_meta("quantidade", quantidade)
	no.set_meta("prompt", prompt)
	no.set_meta("texto", texto)
	no.set_meta("repetido", repetido)
	no.position = onde
	no.rotation.y = giro

	var malha := (load(modelo) as PackedScene).instantiate() as Node3D
	malha.name = "modelo"
	malha.transform = pose_modelo
	no.add_child(malha)

	var area := Area3D.new()
	area.name = "area"
	area.collision_layer = 0
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(3.2, 2.0, 3.2)
	forma.shape = caixa
	area.add_child(forma)
	no.add_child(area)

	# o script por último: o _ready dele procura "area" e lê as metadatas
	no.set_script(ItemDeBalcao)
	_gaveta.add_child(no)
