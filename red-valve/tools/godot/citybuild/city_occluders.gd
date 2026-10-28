@tool
extends Node3D
## Etapa 09 — gera o oclusor da cidade a partir dos volumes das casas.
##
## O projeto tem `occlusion_culling = true` e nenhum oclusor: hoje isso é
## custo puro sem benefício. Uma caixa por casa, num único ArrayOccluder3D,
## dá oclusão real num tecido denso por ~8 mil triângulos.
##
## As caixas são deliberadamente MENORES que a casa. Um oclusor maior que a
## geometria descarta coisa visível — buraco na imagem. Menor só desperdiça
## um pouco de oclusão.

@export var volumes_json: String = "res://assets/3d_model/city/houses.json"
@export var save_path: String = "res://assets/3d_model/city/occ_city.tres"
## Fração da menor dimensão em planta usada como meia-extensão. 0.42 mantém
## a caixa dentro da casa em qualquer orientação.
@export var encolhe_planta: float = 0.42
@export var encolhe_altura: float = 0.85

@export_multiline var last_result: String = ""

## `ResourceSaver.save()` gira o loop principal, e o plugin MCP aproveita
## para processar a próxima mensagem da fila. Um segundo `construir`
## entrava no meio do primeiro e derrubava o editor com SIGSEGV dentro
## do MultiMesh. Uma trava simples resolve.
var _ocupado: bool = false

@export var construir: bool = false:
	set(v):
		construir = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_construir()
			_ocupado = false


func _caixa(v: PackedVector3Array, idx: PackedInt32Array,
		centro: Vector3, meia: Vector3, rot: float) -> void:
	var b := Basis(Vector3.UP, rot)
	var base := v.size()
	for sx in [-1.0, 1.0]:
		for sy in [0.0, 1.0]:
			for sz in [-1.0, 1.0]:
				v.append(centro + b * Vector3(
					sx * meia.x, sy * meia.y * 2.0, sz * meia.z))
	# 8 vértices na ordem (sx, sy, sz): 0..7
	const FACES := [
		0, 2, 6, 0, 6, 4,   # -X
		1, 5, 7, 1, 7, 3,   # +X
		0, 4, 5, 0, 5, 1,   # -Z
		2, 3, 7, 2, 7, 6,   # +Z
		1, 3, 2, 1, 2, 0,   # baixo
		4, 6, 7, 4, 7, 5,   # topo
	]
	for i in FACES:
		idx.append(base + i)


func _construir() -> void:
	var txt := FileAccess.get_file_as_string(volumes_json)
	if txt.is_empty():
		last_result = "ERRO: não consegui ler %s" % volumes_json
		return
	var dados = JSON.parse_string(txt)
	if typeof(dados) != TYPE_DICTIONARY or not dados.has("casas"):
		last_result = "ERRO: houses.json inválido"
		return

	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for c in dados["casas"]:
		var w: float = float(c["w"])
		var d: float = float(c["d"])
		var h: float = float(c["h"])
		var lado: float = minf(w, d) * encolhe_planta
		var meia := Vector3(lado, h * encolhe_altura * 0.5, lado)
		var centro := Vector3(float(c["x"]), float(c["y"]), float(c["z"]))
		_caixa(v, idx, centro, meia, float(c["rot"]))

	var occ := ArrayOccluder3D.new()
	occ.set_arrays(v, idx)
	var err := ResourceSaver.save(occ, save_path)
	if err != OK:
		last_result = "ERRO ao salvar oclusor: %d" % err
		return

	for c in get_children():
		remove_child(c)
		c.free()
	var oi := OccluderInstance3D.new()
	oi.name = "CityOccluder"
	oi.occluder = load(save_path)
	add_child(oi)
	oi.owner = get_tree().edited_scene_root

	last_result = "oclusor: %d casas, %d vértices, %d triângulos" % [
		dados["casas"].size(), v.size(), idx.size() / 3]
