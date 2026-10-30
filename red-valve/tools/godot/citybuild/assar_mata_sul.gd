extends SceneTree
## Assa SÓ a mata do sul (`lib/vegetation.py`, `_mata_sul`) em MultiMesh, sem
## reassar a floresta inteira pelo botão `construir` do `City/Vegetation`.
##
##     Godot --path red-valve --script res://tools/godot/citybuild/assar_mata_sul.gd
##
## SEM `--headless`: com o renderer de mentira o MultiMesh é gravado sem o
## buffer (só o `instance_count`), e a mata sai invisível.
##
## Quem chama é `tools/blender/citygen/assar_mata_sul.py`, que depois pendura
## os nós no `city.tscn`. Aqui: lê o `scatter.json`, separa os pontos da faixa
## sul (Z local da cidade >= Z_SUL), agrupa por bloco como o `city_vegetation.gd`
## faz e grava `mm_<especie>_sul_<bx>_<bz>[_LOD].tres`. No fim imprime uma linha
## `NO|nome|caminho|cx|cy|cz|lod` por nó, que o Python lê.

const SCATTER := "res://assets/3d_model/city/scatter.json"
const DIR := "res://assets/3d_model/city/multimesh"
## Z do Godot 0 é o fim da área importada; no espaço da cidade (origem em
## z -280) isso é 280.
const Z_SUL := 280.5
## O mesmo `bloco` do nó Vegetation da cidade.
const BLOCO := 128.0


func _init() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(SCATTER))
	if typeof(dados) != TYPE_DICTIONARY:
		printerr("scatter.json inválido")
		quit(1)
		return
	var total := 0
	for especie in dados["especies"]:
		var malha := load("%s/mesh_%s.tres" % [DIR, especie]) as Mesh
		var lod_caminho := "%s/mesh_%s_LOD.tres" % [DIR, especie]
		var malha_lod: Mesh = load(lod_caminho) if ResourceLoader.exists(lod_caminho) else null
		var blocos := {}
		for p in dados["especies"][especie]:
			if float(p[2]) < Z_SUL:
				continue
			var chave := Vector2i(int(floor(float(p[0]) / BLOCO)), int(floor(float(p[2]) / BLOCO)))
			if not blocos.has(chave):
				blocos[chave] = []
			blocos[chave].append(p)
		if blocos.is_empty():
			continue
		if malha == null:
			printerr("sem malha pra ", especie)
			continue
		for chave in blocos:
			var lote: Array = blocos[chave]
			var centro := Vector3.ZERO
			for p in lote:
				centro += Vector3(float(p[0]), float(p[1]), float(p[2]))
			centro /= float(lote.size())
			var nome := "%s_sul_%d_%d" % [especie, chave.x, chave.y]
			_gravar(malha, lote, centro, nome, false)
			if malha_lod != null:
				_gravar(malha_lod, lote, centro, nome + "_LOD", true)
			total += lote.size()
	print("TOTAL|", total)
	quit()


func _gravar(malha: Mesh, lote: Array, centro: Vector3, nome: String, lod: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha
	mm.instance_count = lote.size()
	for i in lote.size():
		var p: Array = lote[i]
		var pos := Vector3(float(p[0]), float(p[1]), float(p[2])) - centro
		var b := Basis(Vector3.UP, float(p[3])).scaled(Vector3.ONE * float(p[4]))
		mm.set_instance_transform(i, Transform3D(b, pos))
	var caminho := "%s/mm_%s.tres" % [DIR, nome]
	if mm.buffer.is_empty():
		printerr("MultiMesh sem buffer (rodou --headless?): ", nome)
		quit(1)
		return
	ResourceSaver.save(mm, caminho)
	print("NO|%s|%s|%f|%f|%f|%d" % [nome, caminho, centro.x, centro.y, centro.z, int(lod)])
