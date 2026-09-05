extends Node

## Ferramenta de uso único: gera versões leves dos props .glb que vieram
## pesadíssimos do Sketchfab (mesa_telefone tem 686 mil triângulos para uma
## mesinha de canto). Usa o simplificador do próprio Godot — o mesmo que gera
## LOD na importação — e grava o resultado como malha independente.
##
## Rodar pelo editor: res://tools/jimmy_house/simplificar_pesados.tscn

const DESTINO := "res://assets/3d_model/mobilia/"
const ORIGEM := "res://assets/3d_model/stages/prolog/"

## caminho -> orçamento de triângulos da versão leve
const ALVOS := {
	"mesa_telefone.glb": 9000,
	"cozinha_armario.glb": 7000,
	"mesa.glb": 7000,
	"armario.glb": 5000,
	"quadro_3d.glb": 4000,
	"gray_l-shaped_couch.glb": 5000,
}


func _ready() -> void:
	if not ClassDB.can_instantiate("ImporterMesh"):
		push_error("[simplificar] ImporterMesh indisponível nesta build")
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO + "malhas"))

	for chave in ALVOS:
		var arquivo: String = chave
		var orcamento: int = ALVOS[chave]
		var slug := arquivo.get_basename().to_snake_case().replace("-", "_")
		var packed: PackedScene = load(ORIGEM + arquivo)
		if packed == null:
			push_error("[simplificar] não carregou " + arquivo)
			continue

		var raiz := packed.instantiate()
		add_child(raiz)

		var novo := Node3D.new()
		novo.name = slug + "_leve"
		var indice := 0
		var antes := 0
		var depois := 0

		for mi in _malhas(raiz):
			var leve := _simplificar(mi.mesh, orcamento)
			antes += _tris(mi.mesh)
			depois += _tris(leve)

			var caminho := "%smalhas/%s_leve_%d.res" % [DESTINO, slug, indice]
			if ResourceSaver.save(leve, caminho) != OK:
				push_error("[simplificar] falha ao salvar " + caminho)
				continue

			var copia := MeshInstance3D.new()
			copia.name = "%s_%d" % [slug, indice]
			copia.mesh = load(caminho)
			copia.transform = raiz.global_transform.affine_inverse() * mi.global_transform
			novo.add_child(copia)
			copia.owner = novo
			indice += 1

		if indice > 0:
			var cena := PackedScene.new()
			cena.pack(novo)
			var destino_cena := DESTINO + slug + "_leve.tscn"
			if ResourceSaver.save(cena, destino_cena) == OK:
				print("[simplificar] %s: %d -> %d tris (%.1f%%) em %s"
					% [arquivo, antes, depois, 100.0 * depois / maxi(antes, 1), destino_cena])
			else:
				push_error("[simplificar] falha ao salvar " + destino_cena)

		novo.queue_free()
		raiz.queue_free()

	print("[simplificar] concluído")
	get_tree().quit(0)


## Passa a malha pelo gerador de LOD e devolve o nível mais detalhado que ainda
## cabe no orçamento — ou o mais agressivo disponível, se nenhum couber.
func _simplificar(origem: Mesh, orcamento_tris: int) -> ArrayMesh:
	var imp := ImporterMesh.new()
	for s in origem.get_surface_count():
		imp.add_surface(
			origem.surface_get_primitive_type(s),
			origem.surface_get_arrays(s),
			[],
			{},
			origem.surface_get_material(s))
	imp.generate_lods(25.0, 60.0, [])

	var saida := ArrayMesh.new()
	for s in imp.get_surface_count():
		var arrays: Array = imp.get_surface_arrays(s)
		var niveis := imp.get_surface_lod_count(s)
		var escolhido: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		# get_surface_lod_indices devolve do mais detalhado para o mais grosso;
		# vamos descendo enquanto não couber no orçamento.
		for nivel in niveis:
			var idx: PackedInt32Array = imp.get_surface_lod_indices(s, nivel)
			escolhido = idx
			if idx.size() / 3 <= orcamento_tris:
				break

		arrays[Mesh.ARRAY_INDEX] = escolhido
		saida.add_surface_from_arrays(imp.get_surface_primitive_type(s), arrays)
		saida.surface_set_material(s, imp.get_surface_material(s))
	return saida


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		t += (idx.size() / 3) if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX].size() / 3)
	return t


func _malhas(no: Node) -> Array[MeshInstance3D]:
	var saida: Array[MeshInstance3D] = []
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		saida.append(no)
	for f in no.get_children():
		saida.append_array(_malhas(f))
	return saida
