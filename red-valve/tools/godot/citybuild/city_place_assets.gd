@tool
extends Node3D
## Posiciona os assets do usuário na cidade e cria as placas das casas nomeadas.
##
## As casas nomeadas e a oficina caem em **vagas reservadas**: o gerador de
## casas não constrói proxy naquele ponto e devolve a posição, o ângulo e o
## tamanho do lote em `houses.json`. Assim o modelo entra exatamente onde a
## casa estaria, voltado para a rua certa.
##
## Os assets vêm normalizados em ~2 unidades; a escala aqui é o que os traz
## para metros. `base_y` é o ponto mais baixo do modelo, usado para assentar
## no chão em vez de enterrar ou levitar.

@export var houses_json: String = "res://assets/3d_model/city/houses.json"
@export var atlas_placas: String = "res://assets/3d_model/city/textures/T_signs_alb.png"

@export_group("Igreja")
@export var igreja_pos := Vector2(-72.0, -34.0)   ## local (x, z)
@export var igreja_chao: float = 11.42
@export var igreja_escala: float = 15.0
@export var igreja_base_y: float = -0.95
@export var igreja_giro: float = -0.6

@export_group("Pracinha")
@export var praca_pos := Vector2(0.0, 0.0)
@export var praca_chao: float = 8.15
@export var praca_escala: float = 20.0
@export var praca_base_y: float = -0.58

@export_group("Oficina do Jimmy")
@export var oficina_escala: float = 10.0
@export var oficina_base_y: float = -0.68

@export_group("Casas nomeadas")
@export var casa_escala: float = 5.0
@export var casa_base_y: float = -0.79
## Distância da fachada até a placa, e altura da placa.
@export var placa_frente: float = 1.1
@export var placa_altura: float = 1.85
@export var placa_lado: int = 1        ## 1 ou -1: de que lado fica a fachada

@export_multiline var last_result: String = ""

@export var posicionar: bool = false:
	set(v):
		posicionar = false
		if v and Engine.is_editor_hint():
			_posicionar()


func _vagas() -> Dictionary:
	var txt := FileAccess.get_file_as_string(houses_json)
	if txt.is_empty():
		return {}
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return d.get("vagas_reservadas", {})


func _por(nome: String, pos: Vector3, escala: float, giro: float) -> bool:
	var n := get_node_or_null(NodePath(nome)) as Node3D
	if n == null:
		return false
	n.transform = Transform3D(
		Basis(Vector3.UP, giro).scaled(Vector3.ONE * escala), pos)
	return true


func _placa(nome: String, base: Vector3, giro: float, celula: int) -> void:
	var velho := get_node_or_null(NodePath(nome))
	if velho:
		remove_child(velho)
		velho.free()

	var raiz := Node3D.new()
	raiz.name = nome
	raiz.transform = Transform3D(Basis(Vector3.UP, giro), base)
	add_child(raiz)
	raiz.owner = get_tree().edited_scene_root

	# poste curto
	var poste := MeshInstance3D.new()
	poste.name = "poste"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, placa_altura, 0.07)
	poste.mesh = bm
	poste.position = Vector3(0, placa_altura * 0.5, 0)
	raiz.add_child(poste)
	poste.owner = get_tree().edited_scene_root

	# chapa esmaltada, com a UV apontando para a célula do atlas
	var chapa := MeshInstance3D.new()
	chapa.name = "chapa"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.62, 0.21)
	chapa.mesh = qm
	chapa.position = Vector3(0, placa_altura, 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(atlas_placas)
	mat.uv1_scale = Vector3(1.0 / 2.0, 1.0 / 6.0, 1.0)
	mat.uv1_offset = Vector3(float(celula % 2) / 2.0, float(celula / 2) / 6.0, 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.55
	chapa.material_override = mat
	raiz.add_child(chapa)
	chapa.owner = get_tree().edited_scene_root


func _posicionar() -> void:
	var vagas := _vagas()
	var linhas := PackedStringArray()

	_por("Igreja", Vector3(igreja_pos.x, igreja_chao - igreja_base_y * igreja_escala,
		igreja_pos.y), igreja_escala, igreja_giro)
	linhas.append("Igreja: escala %.0f, topo ~%.1f m" % [
		igreja_escala, 1.9 * igreja_escala])

	_por("Pracinha", Vector3(praca_pos.x, praca_chao - praca_base_y * praca_escala,
		praca_pos.y), praca_escala, 0.0)
	linhas.append("Pracinha: escala %.0f, ~%.0f m de largura" % [
		praca_escala, 1.9 * praca_escala])

	# oficina: centro das vagas reservadas
	if vagas.has("oficina_jimmy") and not vagas["oficina_jimmy"].is_empty():
		var lote: Array = vagas["oficina_jimmy"]
		var c := Vector3.ZERO
		var chao := 0.0
		for s in lote:
			c += Vector3(float(s["x"]), 0.0, float(s["z"]))
			chao += float(s["y"])
		c /= float(lote.size())
		chao /= float(lote.size())
		var giro: float = float(lote[0]["rot"])
		_por("OficinaJimmy", Vector3(c.x, chao - oficina_base_y * oficina_escala, c.z),
			oficina_escala, giro)
		linhas.append("Oficina: %d vagas, centro (%.1f, %.1f)" % [lote.size(), c.x, c.z])

	for par in [["casa_nice", "CasaSraNice", 10], ["casa_maycow", "CasaSrMaycow", 11]]:
		var tag: String = par[0]
		var no: String = par[1]
		var celula: int = par[2]
		if not vagas.has(tag) or vagas[tag].is_empty():
			linhas.append("%s: SEM VAGA" % no)
			continue
		var s: Dictionary = vagas[tag][0]
		var giro := float(s["rot"])
		var chao := float(s["y"])
		var pos := Vector3(float(s["x"]), chao - casa_base_y * casa_escala,
			float(s["z"]))
		_por(no, pos, casa_escala, giro)

		# placa na frente da fachada
		var frente := Basis(Vector3.UP, giro) * Vector3(
			float(placa_lado) * (float(s["d"]) * 0.5 + placa_frente), 0.0, 0.0)
		_placa(no + "_Placa", Vector3(pos.x, chao, pos.z) + frente, giro, celula)
		linhas.append("%s: vaga (%.1f, %.1f), placa célula %d" % [
			no, s["x"], s["z"], celula])

	last_result = "\n".join(linhas)
