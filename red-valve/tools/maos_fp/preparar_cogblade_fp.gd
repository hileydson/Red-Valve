extends SceneTree
func _initialize() -> void: call_deferred("build")
## Gera somente a variante de primeira pessoa. O modelo dos poderes nao muda.
## Alongamento localizado do cabo, sem esticar a cabeca nem o pomo.
## Godot --headless --path red-valve --script res://tools/maos_fp/preparar_cogblade_fp.gd
func build() -> void:
	var fonte: Node3D = load("res://assets/3d_model/player/Crescent Cogblade/Crescent Cogblade.glb").instantiate()
	var visual: MeshInstance3D = fonte.find_children("*", "MeshInstance3D", true, false)[0]
	var origem := Vector3(0.68, 0.36, 0.0)
	var eixo := Vector3(-0.918, -0.398, 0).normalized()
	var normal := Vector3(-eixo.y, eixo.x, 0)
	var b := Basis(Vector3(0,eixo.x,-normal.x),Vector3(0,eixo.y,-normal.y),Vector3(-1,0,0))
	var escala := 0.6
	var mesh := ArrayMesh.new()
	for s in visual.mesh.get_surface_count():
		var a := visual.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
		for i in vertices.size():
			var v: Vector3 = b * (vertices[i]-origem) * escala
			var dentro := v.y > 0.015 and v.y < 0.14
			v.y += clampf(v.y - 0.015,0,0.125)*2.0
			vertices[i] = v
			var n: Vector3 = b * normals[i]
			if dentro: n.y /= 3.0
			normals[i] = n.normalized()
			if not tangents.is_empty():
				var t := b * Vector3(tangents[4*i],tangents[4*i+1],tangents[4*i+2])
				if dentro: t.y *= 3.0
				t = t.normalized()
				tangents[4*i] = t.x
				tangents[4*i+1] = t.y
				tangents[4*i+2] = t.z
		a[Mesh.ARRAY_VERTEX] = vertices
		a[Mesh.ARRAY_NORMAL] = normals
		a[Mesh.ARRAY_TANGENT] = tangents
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		mesh.surface_set_material(s,visual.mesh.surface_get_material(s))
	var err := ResourceSaver.save(mesh,"res://assets/3d_model/player/Crescent Cogblade/cogblade_duas_maos.res", ResourceSaver.FLAG_COMPRESS)
	print("MODEL_READY ",err," ",mesh.get_aabb())
	fonte.free()
	quit()
