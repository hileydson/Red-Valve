extends RefCounted

## Mapa de ruas compartilhado pelo ShadowPerson, ShadowCar e ShadowCrowd.
##
## O problema: o `city_roads.gltf` e SO malha visual — nao tem nenhum no `-col`,
## entao nao existe colisao de rua pra sondar com raycast. Perguntar ao mundo
## fisico "isso aqui e asfalto?" devolvia sempre nao, e todo mundo travava.
##
## A solucao: ler os triangulos da propria malha das ruas uma unica vez e
## rasterizar tudo num grid de celulas vistas de cima. Depois disso cada
## consulta e uma busca num dicionario — mais barato que o raycast que estava
## aqui antes, e sem depender de colisao nenhuma. O grid tambem guarda a altura
## do asfalto por celula, entao da pra assentar carro e pedestre sem raycast.
##
## Se nao achar o no das ruas, o sistema entra em modo permissivo: `is_road`
## responde sempre `true`. E melhor todo mundo andar por tudo do que a cidade
## inteira congelar.

## Lado da celula do grid, em metros.
const CELL := 1.0

static var _cells: Dictionary = {}
static var _built := false
static var _fallback := false
static var _scene_id := 0
static var _bounds_min := Vector2.ZERO
static var _bounds_max := Vector2.ZERO


static func _key(ix: int, iz: int) -> int:
	# duas coordenadas de 32 bits num inteiro so
	return (ix << 32) | (iz & 0xFFFFFFFF)


## Constroi o mapa (uma vez por cena). Chame no _ready de quem for consultar.
static func setup(tree: SceneTree, road_name := "Roads", group := "shadow_road") -> void:
	if tree == null:
		return
	var scene := tree.current_scene
	var sid := scene.get_instance_id() if scene != null else 0
	if _built and sid == _scene_id:
		return
	_cells.clear()
	_built = true
	_fallback = false
	_scene_id = sid

	var roots: Array[Node] = []
	_collect_roots(tree.root, road_name, group, roots)
	if roots.is_empty():
		_fallback = true
		push_warning("ShadowRoads: no de ruas '%s' nao encontrado; sombras liberadas pra andar em qualquer lugar." % road_name)
		return

	var tris := 0
	for r in roots:
		tris += _rasterize(r)

	if _cells.is_empty():
		_fallback = true
		push_warning("ShadowRoads: '%s' nao tem malha legivel; sombras liberadas." % road_name)
	else:
		print("ShadowRoads: %d celulas de rua a partir de %d triangulos." % [_cells.size(), tris])


static func _collect_roots(node: Node, road_name: String, group: String, out: Array[Node]) -> void:
	if node.name == road_name or node.is_in_group(group):
		out.append(node)
		return  # nao precisa descer: a varredura pega os filhos depois
	for c in node.get_children():
		_collect_roots(c, road_name, group, out)


## Marca no grid todas as celulas cobertas pelos triangulos das malhas.
static func _rasterize(root: Node) -> int:
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			if arr.is_empty():
				continue
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if verts.is_empty():
				continue
			# leva os vertices pro espaco do mundo uma vez so
			var world := PackedVector3Array()
			world.resize(verts.size())
			for i in verts.size():
				world[i] = xf * verts[i]
			if idx.is_empty():
				for i in range(0, world.size() - 2, 3):
					_mark_tri(world[i], world[i + 1], world[i + 2])
					total += 1
			else:
				for i in range(0, idx.size() - 2, 3):
					_mark_tri(world[idx[i]], world[idx[i + 1]], world[idx[i + 2]])
					total += 1
	return total


## Marca a caixa do triangulo visto de cima. Os quads do asfalto sao pequenos,
## entao a caixa praticamente coincide com o triangulo — e o erro que sobra e
## sempre pra mais, o que so ajuda a nao deixar buraco no meio da pista.
static func _mark_tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	var x0 := floori(minf(a.x, minf(b.x, c.x)) / CELL)
	var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / CELL)
	var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELL)
	var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELL)
	if (x1 - x0) > 64 or (z1 - z0) > 64:
		return  # triangulo gigante (plano de fundo): ignora
	var y := maxf(a.y, maxf(b.y, c.y))
	for ix in range(x0, x1 + 1):
		for iz in range(z0, z1 + 1):
			var k := _key(ix, iz)
			if not _cells.has(k) or float(_cells[k]) < y:
				_cells[k] = y
	_bounds_min = Vector2(minf(_bounds_min.x, x0 * CELL), minf(_bounds_min.y, z0 * CELL))
	_bounds_max = Vector2(maxf(_bounds_max.x, x1 * CELL), maxf(_bounds_max.y, z1 * CELL))


## Tem rua neste ponto? (Sem mapa, responde sim: modo permissivo.)
static func is_road(pos: Vector3) -> bool:
	if _fallback or not _built:
		return true
	return _cells.has(_key(floori(pos.x / CELL), floori(pos.z / CELL)))


## Altura do asfalto neste ponto, NAN se aqui nao for rua.
static func road_y(pos: Vector3) -> float:
	var k := _key(floori(pos.x / CELL), floori(pos.z / CELL))
	if not _cells.has(k):
		return NAN
	return float(_cells[k])


static func has_map() -> bool:
	return _built and not _fallback


## Ponto de rua mais proximo, em aneis crescentes. Devolve `from` se nao achar.
static func nearest(from: Vector3, max_radius := 30.0, rings := 8, per_ring := 16) -> Vector3:
	if not has_map() or is_road(from):
		return from
	for i in range(1, rings + 1):
		var rad := max_radius * float(i) / float(rings)
		var off := randf() * TAU
		for j in per_ring:
			var a := off + TAU * float(j) / float(per_ring)
			var p := from + Vector3(cos(a) * rad, 0.0, sin(a) * rad)
			if is_road(p):
				var y := road_y(p)
				if not is_nan(y):
					p.y = y
				return p
	return from


## Altura do chao fisico (usada onde o mapa de ruas nao serve).
static func ground_y(world: World3D, pos: Vector3, mask: int, up := 60.0, down := 120.0) -> float:
	if world == null:
		return NAN
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * up, pos + Vector3.DOWN * down)
	q.collision_mask = mask
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y
