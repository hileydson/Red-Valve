@tool
extends Node
## Etapa 01 — importa o heightmap derivado das ruas para o Terrain3D
## e permite conferir as cotas resultantes.
##
## Acionado setando `run_import` / `probe_api` / `probe_heights` = true.
## O desfecho vai para `last_result`, que pode ser lido de volta.
## Ver docs/plano-cidade-blender.md §0.2 (as ruas geram o terreno).

@export var terrain_path: NodePath = NodePath("../NavigationRegion3D/Terrenasso")
@export var height_file: String = "res://assets/terrain3d/import/city_height.f32"
@export var img_width: int = 768
@export var img_height: int = 512
@export var corner: Vector3 = Vector3(256, 0, -512)

## Origem da cidade no mundo: X = origin_x + px ; Z = origin_z - py
@export var origin_x: float = 640.0
@export var origin_z: float = -280.0

@export_multiline var last_result: String = ""

@export var probe_api: bool = false:
	set(v):
		probe_api = false
		if v and Engine.is_editor_hint():
			_probe_api()

@export var probe_heights: bool = false:
	set(v):
		probe_heights = false
		if v and Engine.is_editor_hint():
			_probe_heights()

@export var run_import: bool = false:
	set(v):
		run_import = false
		if v and Engine.is_editor_hint():
			_run()


func _terrain() -> Node:
	return get_node_or_null(terrain_path)


func _probe_api() -> void:
	var t := _terrain()
	if t == null:
		last_result = "ERRO: Terrain3D nao encontrado em %s" % terrain_path
		return
	var bits := PackedStringArray(["classe=%s" % t.get_class()])
	if "data" in t and t.data != null:
		var d = t.data
		bits.append("data.classe=%s" % d.get_class())
		var meths := PackedStringArray()
		for m in d.get_method_list():
			var n: String = m.name
			if n.begins_with("get_h") or n.begins_with("import") or n.begins_with("save"):
				meths.append(n)
		bits.append("metodos=" + ", ".join(meths))
	last_result = "\n".join(bits)


## Amostra a cota do terreno em pontos conhecidos da cidade (coords locais).
func _probe_heights() -> void:
	var t := _terrain()
	if t == null or t.data == null:
		last_result = "ERRO: Terrain3D/data indisponivel"
		return
	var d = t.data
	if not d.has_method("get_height"):
		last_result = "ERRO: Terrain3DData nao expoe get_height"
		return

	var pontos := {
		"praca (0,0)": Vector2(0, 0),
		"noroeste (-340,140)": Vector2(-340, 140),
		"sudeste (260,-280)": Vector2(260, -280),
		"ETE (-150,-230)": Vector2(-150, -230),
		"igreja (-72,34)": Vector2(-72, 34),
		"cemiterio (-233,1)": Vector2(-233, 1),
	}
	var linhas := PackedStringArray(["regioes=%d" % d.get_region_count()])
	for nome in pontos:
		var p: Vector2 = pontos[nome]
		var gp := Vector3(origin_x + p.x, 0.0, origin_z - p.y)
		var h: float = d.get_height(gp)
		linhas.append("%s -> mundo(%.0f, %.0f) h=%.2f" % [nome, gp.x, gp.z, h])
	last_result = "\n".join(linhas)


func _run() -> void:
	var t := _terrain()
	if t == null:
		last_result = "ERRO: Terrain3D nao encontrado em %s" % terrain_path
		return
	if not FileAccess.file_exists(height_file):
		last_result = "ERRO: heightmap ausente: %s" % height_file
		return

	var f := FileAccess.open(height_file, FileAccess.READ)
	if f == null:
		last_result = "ERRO: nao consegui abrir %s" % height_file
		return
	var buf := f.get_buffer(f.get_length())
	f.close()

	var esperado := img_width * img_height * 4
	if buf.size() != esperado:
		last_result = "ERRO: tamanho %d, esperado %d" % [buf.size(), esperado]
		return

	var img := Image.create_from_data(img_width, img_height, false, Image.FORMAT_RF, buf)
	if img == null:
		last_result = "ERRO: Image.create_from_data falhou"
		return

	var d = t.data
	if d == null or not d.has_method("import_images"):
		last_result = "ERRO: Terrain3D.data sem import_images"
		return

	var antes: int = d.get_region_count()
	d.import_images([img, null, null], corner, 0.0, 1.0)
	var depois: int = d.get_region_count()

	var salvo := "nao tentado"
	if d.has_method("save_directory"):
		d.save_directory(t.data_directory)
		salvo = "save_directory(%s)" % t.data_directory

	last_result = "OK: import em %s | regioes %d -> %d | %s" % [
		str(corner), antes, depois, salvo]
