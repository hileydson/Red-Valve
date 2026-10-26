extends SceneTree

## Deriva as pecas moveis da MK3 (the_negotiator_V2) e do foguete da Granola
## (the_negotiator_V4), preservando UVs e materiais. Mesmo caminho do
## `preparar_pistola_fp.gd`: corta pela posicao do centro de cada triangulo.
##
##     Godot_v4.6.1 --headless --path red-valve -s res://tools/maos_fp/preparar_armas_novas_fp.gd
##
## MK3: o pente e' tudo que fica na frente do guarda-mato e abaixo do corpo
## (x < PENTE_X e y < PENTE_Y no espaco do .glb, que tem o cano no -X e o alto
## no +Y). O pente sobe ate' o poco, em y 0,24, e e' inclinado: o canto de tras
## dele chega a x -0,10 (o guarda-mato comeca em -0,03). Sai `mk3_corpo.res` + `mk3_pente.res`, o pente com a origem no TOPO
## dele (o ponto que entra no poco) — e' por ali que a mao segura e encaixa.
## A cena `mk3_fp.tscn` monta os dois no lugar de origem (Corpo + Pente), e
## `pente_mk3.tscn` e' o pente sozinho (na mao, caindo no chao).
const PASTA_MK3 := "res://assets/3d_model/player/the_negotiator_V2/"
const PENTE_X := -0.07
const PENTE_Y := 0.235

func _initialize():
	var original: Node3D = load(PASTA_MK3 + "the_negotiator_V2.glb").instantiate()
	var fonte := original.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var corpo := ArrayMesh.new()
	var pente := ArrayMesh.new()
	var topo := Vector3.ZERO
	# primeiro passo: o topo do pente (centro em x/z, y mais alto do pedaco)
	var minimo := Vector3.INF
	var maximo := -Vector3.INF
	for s in fonte.mesh.get_surface_count():
		var arrays := fonte.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for f in range(0, indices.size(), 3):
			var c := (vertices[indices[f]] + vertices[indices[f + 1]] + vertices[indices[f + 2]]) / 3.0
			if c.x < PENTE_X and c.y < PENTE_Y:
				for j in 3:
					minimo = minimo.min(vertices[indices[f + j]])
					maximo = maximo.max(vertices[indices[f + j]])
	topo = Vector3((minimo.x + maximo.x) * 0.5, maximo.y, (minimo.z + maximo.z) * 0.5)
	print("pente: min=", minimo, " max=", maximo, " topo=", topo)
	for s in fonte.mesh.get_surface_count():
		var arrays := fonte.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var normais: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for parte in 2:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(fonte.get_active_material(s))
			var quantidade := 0
			for f in range(0, indices.size(), 3):
				var c := (vertices[indices[f]] + vertices[indices[f + 1]] + vertices[indices[f + 2]]) / 3.0
				var no_pente := c.x < PENTE_X and c.y < PENTE_Y
				if no_pente != (parte == 1): continue
				for j in 3:
					var i := indices[f + j]
					if not normais.is_empty(): st.set_normal(normais[i])
					if not uvs.is_empty(): st.set_uv(uvs[i])
					# o pente vai com a origem no topo dele
					st.add_vertex(vertices[i] - (topo if parte == 1 else Vector3.ZERO))
					quantidade += 1
			if quantidade > 0:
				if not uvs.is_empty(): st.generate_tangents()
				st.commit(corpo if parte == 0 else pente)
	ResourceSaver.save(corpo, PASTA_MK3 + "mk3_corpo.res")
	ResourceSaver.save(pente, PASTA_MK3 + "mk3_pente.res")

	# a arma montada: corpo + pente no lugar de origem
	var raiz := Node3D.new()
	raiz.name = "Mk3Articulada"
	raiz.set_meta("topo_do_pente", topo)
	var m_corpo := MeshInstance3D.new()
	m_corpo.name = "Corpo"
	m_corpo.mesh = load(PASTA_MK3 + "mk3_corpo.res")
	raiz.add_child(m_corpo)
	m_corpo.owner = raiz
	var m_pente := MeshInstance3D.new()
	m_pente.name = "Pente"
	m_pente.mesh = load(PASTA_MK3 + "mk3_pente.res")
	m_pente.position = topo
	raiz.add_child(m_pente)
	m_pente.owner = raiz
	var cena := PackedScene.new()
	cena.pack(raiz)
	var erro := ResourceSaver.save(cena, PASTA_MK3 + "mk3_fp.tscn")
	print("MK3 articulada: ", erro)
	raiz.free()

	# o pente sozinho
	var so := Node3D.new()
	so.name = "PenteMk3"
	var m := MeshInstance3D.new()
	m.name = "Pente"
	m.mesh = load(PASTA_MK3 + "mk3_pente.res")
	so.add_child(m)
	m.owner = so
	cena = PackedScene.new()
	cena.pack(so)
	erro = ResourceSaver.save(cena, PASTA_MK3 + "pente_mk3.tscn")
	print("pente MK3: ", erro)
	so.free()
	original.free()
	quit(erro)
