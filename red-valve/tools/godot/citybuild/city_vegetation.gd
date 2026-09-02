@tool
extends Node3D
## Etapa 07 — instancia a vegetação a partir de scatter.json.
##
## Usa MultiMeshInstance3D (1 draw call por espécie, transformações na GPU)
## em vez do Proton Scatter: o Blender já resolveu ONDE plantar, contra o
## mesmo heightfield que gerou o terreno, então não há nada a re-espalhar —
## só a instanciar. Trocar a árvore depois é apontar `multimesh.mesh` para
## outra malha, inclusive as BIRCH/SPRUCE que já existem no projeto.

@export var kit_scene: String = "res://assets/3d_model/city/city_vegkit.gltf"
@export var scatter_json: String = "res://assets/3d_model/city/scatter.json"
@export var save_dir: String = "res://assets/3d_model/city/multimesh"
@export var lancar_sombra: bool = true
## Lado do bloco espacial, em metros. Um MultiMesh único cobrindo 1280 x 768 m
## nunca é descartado pelo frustum — a mata atrás do jogador renderiza junto.
## Fatiando, o Godot descarta blocos fora de vista: numa vista típica sobra
## cerca de um quarto do anel.
@export var bloco: float = 256.0
## Sombra só perto: a mata distante projeta sombra que ninguém vê.
@export var sombra_ate: float = 180.0

@export_multiline var last_result: String = ""

@export var construir: bool = false:
	set(v):
		construir = false
		if v and Engine.is_editor_hint():
			_construir()

@export var limpar: bool = false:
	set(v):
		limpar = false
		if v and Engine.is_editor_hint():
			_limpar()


func _limpar() -> void:
	# remove_child + free em vez de queue_free: o free diferido deixaria os
	# nós antigos vivos ao criar os novos, e o Godot renomearia os novos
	# (TREE_forest -> @MultiMeshInstance3D@909xx) para evitar colisão.
	var n := 0
	for c in get_children():
		remove_child(c)
		c.free()
		n += 1
	last_result = "removidos %d nós" % n


func _colher_malhas() -> Dictionary:
	"""Nome da espécie -> Mesh, lidos do kit exportado pelo Blender."""
	var out := {}
	var ps := load(kit_scene)
	if ps == null:
		return out
	var raiz: Node = ps.instantiate()
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var nd: Node = pilha.pop_back()
		if nd is MeshInstance3D and nd.mesh != null:
			out[nd.name] = nd.mesh
		for c in nd.get_children():
			pilha.append(c)
	raiz.queue_free()
	return out


func _construir() -> void:
	var malhas := _colher_malhas()
	if malhas.is_empty():
		last_result = "ERRO: nenhuma malha em %s" % kit_scene
		return

	var txt := FileAccess.get_file_as_string(scatter_json)
	if txt.is_empty():
		last_result = "ERRO: não consegui ler %s" % scatter_json
		return
	var dados = JSON.parse_string(txt)
	if typeof(dados) != TYPE_DICTIONARY or not dados.has("especies"):
		last_result = "ERRO: scatter.json inválido"
		return

	_limpar()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))

	var linhas := PackedStringArray()
	var total := 0
	for especie in dados["especies"].keys():
		var pts: Array = dados["especies"][especie]
		if pts.is_empty():
			continue
		if not malhas.has(especie):
			linhas.append("%s: SEM MALHA no kit — pulado" % especie)
			continue

		# agrupa por bloco espacial
		var blocos := {}
		for p in pts:
			var chave := Vector2i(
				int(floor(float(p[0]) / bloco)), int(floor(float(p[2]) / bloco)))
			if not blocos.has(chave):
				blocos[chave] = []
			blocos[chave].append(p)

		for chave in blocos.keys():
			var lote: Array = blocos[chave]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = malhas[especie]
			mm.instance_count = lote.size()
			var centro := Vector3.ZERO
			for i in lote.size():
				var p: Array = lote[i]
				var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
				var b := Basis(Vector3.UP, float(p[3])).scaled(
					Vector3.ONE * float(p[4]))
				mm.set_instance_transform(i, Transform3D(b, pos))
				centro += pos
			centro /= float(lote.size())

			var nome := "%s_%d_%d" % [especie, chave.x, chave.y]
			var caminho := "%s/mm_%s.tres" % [save_dir, nome]
			ResourceSaver.save(mm, caminho)

			var mmi := MultiMeshInstance3D.new()
			mmi.name = nome
			mmi.multimesh = load(caminho)
			# distância do bloco ao centro da cidade decide a sombra
			var perto: bool = centro.length() < sombra_ate
			mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if (lancar_sombra and perto)
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			add_child(mmi)
			mmi.owner = get_tree().edited_scene_root
			total += lote.size()
		linhas.append("%s: %d instâncias em %d blocos" % [
			especie, pts.size(), blocos.size()])

	linhas.append("TOTAL: %d plantas em %d MultiMesh" % [total, get_child_count()])
	last_result = "\n".join(linhas)
