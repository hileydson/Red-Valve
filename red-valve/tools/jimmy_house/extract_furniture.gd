extends Node

## Ferramenta de uso único: quebra o pacote de móveis `house_itens.glb` em
## cenas individuais reaproveitáveis, uma por móvel, com as malhas salvas
## como .res externos (assim várias cenas compartilham a mesma malha em vez
## de embutir uma cópia cada).
##
## Rodar pelo editor (F6 / project_run custom) apontando para
## res://tools/jimmy_house/extract_furniture.tscn

const FONTE := "res://assets/3d_model/stages/prolog/house_itens.glb"
const DESTINO := "res://assets/3d_model/mobilia/"

func _ready() -> void:
	var erros := 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO + "malhas"))

	var packed: PackedScene = load(FONTE)
	if packed == null:
		push_error("[extrair] não consegui carregar " + FONTE)
		get_tree().quit(1)
		return

	var raiz := packed.instantiate()
	# global_transform só existe dentro da árvore, e é dele que sai a pose
	# de cada malha em relação ao móvel que a contém.
	add_child(raiz)
	var grupo := raiz.find_child("GLTF_SceneRootNode", true, false)
	if grupo == null:
		push_error("[extrair] GLTF_SceneRootNode não encontrado")
		get_tree().quit(1)
		return

	for movel in grupo.get_children():
		var slug := _slug(movel.name)
		var novo := Node3D.new()
		novo.name = slug

		var indice := 0
		for mi in _coletar_malhas(movel):
			var caminho_malha := "%smalhas/%s_%d.res" % [DESTINO, slug, indice]
			var ok := ResourceSaver.save(mi.mesh, caminho_malha)
			if ok != OK:
				push_error("[extrair] falha ao salvar malha " + caminho_malha)
				erros += 1
				continue
			var malha: Mesh = load(caminho_malha)

			var copia := MeshInstance3D.new()
			copia.name = "%s_%d" % [slug, indice]
			copia.mesh = malha
			copia.transform = movel.global_transform.affine_inverse() * mi.global_transform
			for s in range(mi.get_surface_override_material_count()):
				copia.set_surface_override_material(s, mi.get_surface_override_material(s))
			novo.add_child(copia)
			copia.owner = novo
			indice += 1

		if indice == 0:
			novo.queue_free()
			continue

		var cena := PackedScene.new()
		cena.pack(novo)
		var destino_cena := DESTINO + slug + ".tscn"
		if ResourceSaver.save(cena, destino_cena) != OK:
			push_error("[extrair] falha ao salvar cena " + destino_cena)
			erros += 1
		else:
			print("[extrair] ok -> %s (%d malha(s))" % [destino_cena, indice])
		novo.queue_free()

	raiz.queue_free()
	print("[extrair] concluído, erros=%d" % erros)
	get_tree().quit(0)


## Achata a sub-árvore do móvel: o pacote aninha MeshInstance3D em vários
## níveis de nós vazios do GLTF, e só as malhas interessam.
func _coletar_malhas(no: Node) -> Array[MeshInstance3D]:
	var saida: Array[MeshInstance3D] = []
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		saida.append(no)
	for filho in no.get_children():
		saida.append_array(_coletar_malhas(filho))
	return saida


func _slug(nome: String) -> String:
	var s := nome.to_snake_case()
	s = s.replace(".", "_").replace("-", "_").replace(" ", "_")
	while s.contains("__"):
		s = s.replace("__", "_")
	return s.strip_edges().trim_prefix("_").trim_suffix("_").to_lower()
