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
## Quantos indices/vertices por lote antes de olhar o relogio na versao
## fatiada. Grande o bastante pra checagem nao custar nada, pequeno o bastante
## pra nao estourar o orcamento do frame.
const CHUNK := 3072

static var _cells: Dictionary = {}
static var _built := false
## Ligado enquanto a rasterizacao ainda esta sendo fatiada em varios frames.
## Nesse meio tempo o mapa responde como se nao existisse (modo permissivo),
## senao metade da cidade seria dada como "sem rua" so porque ainda nao foi
## marcada.
static var _building := false
static var _fallback := false
static var _scene_id := 0
static var _bounds_min := Vector2.ZERO
static var _bounds_max := Vector2.ZERO


static func _key(ix: int, iz: int) -> int:
	# duas coordenadas de 32 bits num inteiro so
	return (ix << 32) | (iz & 0xFFFFFFFF)


## Constroi o mapa (uma vez por cena). Chame no _ready de quem for consultar.
## Faz tudo de uma vez: use so quando o engasgo nao importa (ou quando o mapa
## ja esta pronto e a chamada e um no-op).
static func setup(tree: SceneTree, road_name := "Roads", group := "shadow_road") -> void:
	_run_setup(tree, road_name, group, 0.0)


## Mesma coisa, mas gastando no maximo `budget_ms` por frame. A malha das ruas
## da cidade tem dezenas de milhares de triangulos; rasterizar tudo num frame
## so era o maior engasgo da entrada na stage_1. Aqui o trabalho e fatiado e o
## jogo continua desenhando enquanto o mapa vai ficando pronto.
static func setup_async(tree: SceneTree, road_name := "Roads", group := "shadow_road", budget_ms := 2.0) -> void:
	await _run_setup(tree, road_name, group, maxf(budget_ms, 0.1))


## Corpo comum. budget_ms <= 0 significa "sem fatiar": a funcao nunca suspende
## e pode ser chamada sem await.
static func _run_setup(tree: SceneTree, road_name: String, group: String, budget_ms: float) -> void:
	if budget_ms > 0.0 and tree != null:
		# garante que a versao async SEMPRE suspende, para o await de quem
		# chamou nunca cair em cima de um valor comum
		await tree.process_frame
	if tree == null:
		return
	var scene := tree.current_scene
	var sid := scene.get_instance_id() if scene != null else 0
	if _built and sid == _scene_id:
		return
	_cells.clear()
	_built = true
	_building = budget_ms > 0.0
	_fallback = false
	_scene_id = sid

	var roots: Array[Node] = []
	_collect_roots(tree.root, road_name, group, roots)
	if roots.is_empty():
		_building = false
		_fallback = true
		push_warning("ShadowRoads: no de ruas '%s' nao encontrado; sombras liberadas pra andar em qualquer lugar." % road_name)
		return

	var meshes: Array[MeshInstance3D] = []
	for r in roots:
		_collect_meshes(r, meshes)

	var deadline := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	var tris := 0
	for mi in meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
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

			# leva os vertices pro espaco do mundo uma vez so, em lotes
			var world := PackedVector3Array()
			world.resize(verts.size())
			var v := 0
			while v < verts.size():
				var stop := mini(v + CHUNK, verts.size())
				while v < stop:
					world[v] = xf * verts[v]
					v += 1
				if budget_ms > 0.0 and Time.get_ticks_usec() > deadline:
					await tree.process_frame
					# trocou de cena no meio da montagem: o mapa que estava
					# sendo construido nao serve mais pra ninguem
					if _scene_id != sid:
						return
					deadline = Time.get_ticks_usec() + int(budget_ms * 1000.0)

			var count := (world.size() if idx.is_empty() else idx.size()) - 2
			var i := 0
			while i < count:
				var stop_t := mini(i + CHUNK, count)
				if idx.is_empty():
					while i < stop_t:
						_mark_tri(world[i], world[i + 1], world[i + 2])
						tris += 1
						i += 3
				else:
					while i < stop_t:
						_mark_tri(world[idx[i]], world[idx[i + 1]], world[idx[i + 2]])
						tris += 1
						i += 3
				if budget_ms > 0.0 and Time.get_ticks_usec() > deadline:
					await tree.process_frame
					# trocou de cena no meio da montagem: o mapa que estava
					# sendo construido nao serve mais pra ninguem
					if _scene_id != sid:
						return
					deadline = Time.get_ticks_usec() + int(budget_ms * 1000.0)

	_building = false
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


## Junta as malhas de uma raiz de rua numa lista plana, para a rasterizacao
## poder ir e voltar entre frames sem carregar uma pilha de travessia junto.
static func _collect_meshes(root: Node, out: Array[MeshInstance3D]) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			out.append(mi)


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
	if _fallback or not _built or _building:
		return true
	return _cells.has(_key(floori(pos.x / CELL), floori(pos.z / CELL)))


## Altura do asfalto neste ponto, NAN se aqui nao for rua.
static func road_y(pos: Vector3) -> float:
	if _building:
		return NAN
	var k := _key(floori(pos.x / CELL), floori(pos.z / CELL))
	if not _cells.has(k):
		return NAN
	return float(_cells[k])


static func has_map() -> bool:
	return _built and not _fallback and not _building


## O mapa ja terminou de ser montado?
static func is_ready() -> bool:
	return _built and not _building


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
