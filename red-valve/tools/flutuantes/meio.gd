extends Node

## Lista os corpos FIXOS (StaticBody3D) de mobília que ficam longe de qualquer
## parede — os que atrapalham a passagem. Uso:
##   godot --headless --path . res://tools/flutuantes/meio.tscn -- <cena.tscn> <pai_dos_moveis> [limite_m]

func _ready() -> void:
	SaveManager.current_slot = 9
	var args := OS.get_cmdline_user_args()
	var cena := (load(args[0]) as PackedScene).instantiate()
	var pai: String = args[1]
	var limite := float(args[2]) if args.size() > 2 else 0.4
	get_tree().root.add_child.call_deferred(cena)
	for i in 4:
		await get_tree().physics_frame
	var espaco := (cena as Node3D).get_world_3d().direct_space_state
	var moveis := cena.get_node(pai)
	var todos: Array[RID] = []
	for c in cena.find_children("*", "CollisionObject3D", true, false):
		if moveis.is_ancestor_of(c) or c is CharacterBody3D or c is RigidBody3D:
			todos.append((c as CollisionObject3D).get_rid())
	var grupos: Array = []
	for c in moveis.find_children("*", "StaticBody3D", true, false) + ([moveis] if moveis is StaticBody3D else []):
		var formas: Array = (c as Node).find_children("*", "CollisionShape3D", true, false)
		# corpo único com muitas formas (a escola): cada forma é um móvel
		if formas.size() > 3:
			for f in formas:
				grupos.append([f, [f]])
		else:
			grupos.append([c, formas])
	for g in grupos:
		var corpo: Node = g[0]
		var caixa := AABB()
		var primeira := true
		for cs in g[1]:
			var sh = (cs as CollisionShape3D).shape
			if sh == null:
				continue
			var a: AABB = (cs as Node3D).global_transform * sh.get_debug_mesh().get_aabb()
			caixa = a if primeira else caixa.merge(a)
			primeira = false
		if primeira:
			continue
		var c3 := caixa.get_center()
		c3.y = caixa.position.y + 0.3
		var menor := INF
		for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var r := PhysicsRayQueryParameters3D.create(c3, c3 + d * 6.0, 0xFFFFFFFF, todos)
			var hit := espaco.intersect_ray(r)
			if hit.is_empty():
				continue
			var folga: float = c3.distance_to(hit.position) - absf(d.dot(caixa.size)) * 0.5
			menor = minf(menor, folga)
		if menor > limite:
			print("MEIO ", str(cena.get_path_to(corpo)), " folga_parede=", snappedf(menor, 0.01), " tam=", caixa.size.snapped(Vector3.ONE * 0.01), " centro=", caixa.get_center().snapped(Vector3.ONE * 0.01))
	get_tree().quit()
