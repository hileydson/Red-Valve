extends SceneTree

## Deriva pecas moveis para a primeira pessoa, preservando UVs e materiais.
## O modelo original e a terceira pessoa continuam usando seu proprio .glb.
const PASTA := "res://assets/3d_model/player/the_negotiator_V1/"
func _initialize():
	var original: Node3D = load(PASTA + "the_negotiator_v1.glb").instantiate()
	var fonte := original.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var corpo := ArrayMesh.new()
	var ferrolho := ArrayMesh.new()
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
			for f in range(0,indices.size(),3):
				var centro := (vertices[indices[f]]+vertices[indices[f+1]]+vertices[indices[f+2]])/3.0
				var superior := centro.y > 0.23
				if superior != (parte == 1): continue
				for j in 3:
					var i := indices[f+j]
					if not normais.is_empty(): st.set_normal(normais[i])
					if not uvs.is_empty(): st.set_uv(uvs[i])
					st.add_vertex(vertices[i])
					quantidade += 1
			if quantidade > 0:
				if not uvs.is_empty(): st.generate_tangents()
				st.commit(corpo if parte == 0 else ferrolho)
	ResourceSaver.save(corpo, PASTA + "corpo_fp.res")
	ResourceSaver.save(ferrolho, PASTA + "ferrolho_fp.res")
	var raiz := Node3D.new()
	raiz.name = "PistolaArticulada"
	for nome in ["Corpo", "Ferrolho"]:
		var malha := MeshInstance3D.new()
		malha.name = nome
		malha.mesh = load(PASTA + ("corpo_fp.res" if nome == "Corpo" else "ferrolho_fp.res"))
		raiz.add_child(malha)
		malha.owner = raiz
	var cena := PackedScene.new()
	cena.pack(raiz)
	var erro := ResourceSaver.save(cena, PASTA + "pistola_fp.tscn")
	print("Pistola articulada: ", erro)
	raiz.free()
	original.free()
	quit(erro)
