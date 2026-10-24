extends RefCounted
## Converte aderecos pequenos de `MultiMeshInstance3D` em `RigidBody3D` reais
## quando o Maycon se aproxima deles na cidade (`stage_1`).
##
## Por que fazer em tempo de execucao por proximidade:
##   - A cidade tem ~1.800 aderecos espalhados em 400x400 m (`PropsExtra` e
##     `PropsUrbano`). Se todos fossem nos `RigidBody3D` salvos na cena, seriam
##     mais de 5.000 nos extras e 1.800 draw calls fora do MultiMesh.
##   - Mantendo o `MultiMeshInstance3D` intacto e trocando apenas as instancias
##     num raio de 8 m do jogador (escondendo a instancia no MultiMesh com
##     escala zero e criando o `RigidBody3D` na mesma pose), o custo de GPU e
##     de broadphase fica identico ao de uma sala pequena do hospital.

const CELULA := 10.0
const RAIO_ATIVACAO := 8.0
const RAIO_ATIVACAO_QUAD := RAIO_ATIVACAO * RAIO_ATIVACAO
const PASSO_PLAYER_QUAD := 0.16

## Aderecos que NAO devem virar corpo fisico solto:
##   - pecas presas no alto da parede (ar-condicionado, luminaria, camera, cano);
##   - vegetacao, moita, galho seco, toco e tronco caido;
##   - volumes pesados/fixos de infraestrutura (hidrante, caixa de forca,
##     barreira de concreto, cacamba, orelhao, bueiro, mesa de piquenique).
const FIXOS := {
	"exterior_aircon_unit": true,
	"industrial_wall_lamp": true,
	"security_camera_01": true,
	"security_camera_02": true,
	"garden_hose_wall_mounted_01": true,
	"modular_metal_gutter": true,
	"power_box_01": true,
	"industrial_caged_sconce": true,
	"security_light": true,
	"fire_alarm": true,
	"red_valve_pipe_junction": true,
	"weed_plant_02": true,
	"shrub_02": true,
	"shrub_03": true,
	"shrub_04": true,
	"nettle_plant": true,
	"dry_branches_medium_01": true,
	"tree_stump_01": true,
	"dead_tree_trunk_02": true,
	"water_manhole_cover": true,
	"fire_hydrant": true,
	"utility_box_01": true,
	"utility_box_02": true,
	"concrete_road_barrier": true,
	"concrete_road_barrier_02": true,
	"dumpster_kraycik": true,
	"metal_trash_can": true,
	"korean_public_payphone_01": true,
	"wooden_picnic_table": true,
	"wooden_barrels_01": true,
	"stone_fire_pit": true,
	"old_bed_frame": true,
	"painted_wooden_table": true,
	"street_rat": true,
}

var _raiz: Node3D = null
var _camada: int = 2
var _grade: Dictionary = {}
var _formas_cache: Dictionary = {}
var _ultima_pos_player := Vector3(1e9, 1e9, 1e9)
var _contenedor: Node3D = null


func preparar(raiz: Node3D, camada: int = 2) -> void:
	_raiz = raiz
	_camada = camada
	_grade.clear()
	_formas_cache.clear()
	_ultima_pos_player = Vector3(1e9, 1e9, 1e9)

	_contenedor = Node3D.new()
	_contenedor.name = "_corpos_fisicos_ativos"
	_contenedor.top_level = true
	_raiz.add_child(_contenedor)

	for c in _raiz.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		if _eh_fixo(String(mmi.name)):
			continue
		var mm := mmi.multimesh
		var xf_no := mmi.global_transform
		for i in mm.instance_count:
			var xf_inst := mm.get_instance_transform(i)
			var xf_mundo := xf_no * xf_inst
			var chave := Vector2i(
				floori(xf_mundo.origin.x / CELULA),
				floori(xf_mundo.origin.z / CELULA))
			_grade.get_or_add(chave, []).append({
				"mmi": mmi,
				"idx": i,
				"xf": xf_mundo,
				"ativo": false,
			})


func atualizar() -> void:
	if _raiz == null or _grade.is_empty():
		return
	var arvore := _raiz.get_tree()
	if arvore == null:
		return
	var player := arvore.get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pos := player.global_position
	if pos.distance_squared_to(_ultima_pos_player) < PASSO_PLAYER_QUAD:
		return
	_ultima_pos_player = pos

	var cx := floori(pos.x / CELULA)
	var cz := floori(pos.z / CELULA)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var chave := Vector2i(cx + dx, cz + dz)
			if not _grade.has(chave):
				continue
			var lista: Array = _grade[chave]
			for item in lista:
				if item["ativo"]:
					continue
				var xf: Transform3D = item["xf"]
				if xf.origin.distance_squared_to(pos) <= RAIO_ATIVACAO_QUAD:
					item["ativo"] = true
					_materializar(item["mmi"] as MultiMeshInstance3D, int(item["idx"]), xf)


func _eh_fixo(nome_no: String) -> bool:
	for prefixo in FIXOS.keys():
		if nome_no == prefixo or nome_no.begins_with(prefixo + "_"):
			return true
	return false


func _materializar(mmi: MultiMeshInstance3D, idx: int, xf_mundo: Transform3D) -> void:
	if not is_instance_valid(mmi) or mmi.multimesh == null:
		return
	var mm := mmi.multimesh
	var malha := mm.mesh
	if malha == null:
		return

	# Esconde esta instancia especifica no MultiMesh sem recriar o buffer
	mm.set_instance_transform(idx, Transform3D(
		Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0.0, -500.0, 0.0)))

	var esc := xf_mundo.basis.get_scale()
	var aabb := malha.get_aabb()
	var tam := Vector3(
		maxf(0.14, aabb.size.x * esc.x * 0.85),
		maxf(0.14, aabb.size.y * esc.y),
		maxf(0.14, aabb.size.z * esc.z * 0.85))
	var centro := (aabb.position + aabb.size * 0.5) * esc

	var corpo := RigidBody3D.new()
	corpo.collision_layer = _camada
	corpo.collision_mask = _camada
	var volume := tam.x * tam.y * tam.z
	corpo.mass = clampf(2.0 + volume * 10.0, 2.0, 6.0)
	corpo.linear_damp = 2.0
	corpo.angular_damp = 3.0
	corpo.sleeping = true

	var visual := MeshInstance3D.new()
	visual.mesh = malha
	visual.scale = esc
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if mmi.material_override != null:
		visual.material_override = mmi.material_override
	corpo.add_child(visual)

	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	col.position = centro
	corpo.add_child(col)

	_contenedor.add_child(corpo)
	corpo.global_transform = Transform3D(xf_mundo.basis.orthonormalized(), xf_mundo.origin)
	corpo.sleeping = true

