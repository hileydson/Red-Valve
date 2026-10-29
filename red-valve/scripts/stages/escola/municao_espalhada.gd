extends RefCounted

## A MUNIÇÃO LARGADA PELA ESCOLA E PELO PORÃO (Capítulo 1).
##
## Pouca de propósito: o Maycow sai da luta com o Grizzolito quase sem bala, e o
## que ele acha pelas salas e pelo túnel é o bastante pra se virar, não pra
## sobrar. Cada caixa é um item de cenário comum (`item_de_balcao.gd`, o mesmo
## das balas do hospital e da casa da Dona Nice): seleciona, pega, e o id dela
## vai pro save — pega uma vez, some pra sempre.
##
## O lugar é dado no chão (x, z) e a altura sai de um raio: a caixa pousa no
## que estiver ali — tampo de mesa, banco ou o próprio chão.

const SCRIPT_ITEM := preload("res://scripts/stages/hospital/item_de_balcao.gd")
const MODELO := "res://assets/3d_model/player/the_negotiator_V1/cartridge/scene.gltf"


## `itens`: [[id, Vector3 (x, altura de onde o raio desce, z), quantidade], ...]
static func espalhar(cena: Node3D, itens: Array) -> void:
	await cena.get_tree().physics_frame
	await cena.get_tree().physics_frame
	if not is_instance_valid(cena) or not cena.is_inside_tree():
		return
	var espaco := cena.get_world_3d().direct_space_state
	for it in itens:
		var id: String = it[0]
		if SaveManager.pickup_ja_pego(id):
			continue
		var p: Vector3 = it[1]
		var consulta := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 6.0, 2)
		var batida := espaco.intersect_ray(consulta)
		var chao: Vector3 = batida.position if batida else Vector3(p.x, 0.0, p.z)
		_criar(cena, id, chao, int(it[2]))


static func _criar(cena: Node3D, id: String, pos: Vector3, quantidade: int) -> void:
	var no := Node3D.new()
	no.name = id
	no.set_meta("id", id)
	no.set_meta("item", "pistol_ammo")
	no.set_meta("quantidade", quantidade)
	no.set_meta("prompt", "PROMPT_TAKE_AMMO")
	no.set_meta("texto", "PICKUP_AMMO")
	no.set_meta("repetido", "PICKUP_AMMO_AGAIN")
	no.set_script(SCRIPT_ITEM)
	var modelo := (load(MODELO) as PackedScene).instantiate() as Node3D
	modelo.name = "modelo"
	modelo.position.y = 0.036
	no.add_child(modelo)
	var area := Area3D.new()
	area.name = "area"
	area.collision_layer = 0
	area.monitorable = false
	area.position.y = 0.25
	var forma := CollisionShape3D.new()
	forma.name = "forma"
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(2.6, 2.4, 2.6)
	forma.shape = caixa
	area.add_child(forma)
	no.add_child(area)
	no.position = pos
	no.rotation.y = randf() * TAU
	cena.add_child(no)
