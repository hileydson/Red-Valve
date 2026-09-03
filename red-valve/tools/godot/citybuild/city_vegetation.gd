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
## Distância da troca LOD0 -> LOD1, em metros. Além dela a árvore vira a
## silhueta: mesma altura e mesmo raio máximo, sem as camadas de copa nem o
## tronco. A floresta cai de 44 para 6 triângulos por árvore, a folhosa de
## 84 para 20 — e as duas somam 10.772 das 14.513 plantas do mapa.
@export var dist_lod: float = 140.0
## Faixa de dissolvência em torno da troca, para não haver estalo na tela.
@export var margem_lod: float = 18.0

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

@export var limpar: bool = false:
	set(v):
		limpar = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_limpar()
			_ocupado = false


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
	_persistir_malhas(malhas)

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

		var malha_lod: Mesh = malhas.get(especie + "_LOD", null)

		for chave in blocos.keys():
			var lote: Array = blocos[chave]

			# centro do bloco vira a origem do nó, e as instâncias passam a ser
			# relativas a ele. O alcance de visibilidade do Godot é medido a partir
			# da origem do nó: com todos os blocos em (0,0,0) o LOD trocaria em
			# todos ao mesmo tempo, ou em nenhum.
			var centro := Vector3.ZERO
			for p in lote:
				centro += Vector3(float(p[0]), float(p[1]), float(p[2]))
			centro /= float(lote.size())

			var mm := _fazer_mm(malhas[especie], lote, centro)
			var nome := "%s_%d_%d" % [especie, chave.x, chave.y]
			var perto: bool = centro.length() < sombra_ate
			var sombra: int = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if (lancar_sombra and perto)
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

			var mmi := _instanciar(mm, nome, centro, sombra)
			if malha_lod != null:
				mmi.visibility_range_end = dist_lod
				mmi.visibility_range_end_margin = margem_lod
				mmi.visibility_range_fade_mode = \
					GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

				# mesmas transformações, outra malha. Construído do zero em vez
				# de duplicado: mexer em transform_format/instance_count de um
				# MultiMesh já pronto é exatamente o caminho do SIGSEGV.
				var mml := _fazer_mm(malha_lod, lote, centro)
				var mmil := _instanciar(mml, nome + "_LOD", centro,
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				mmil.visibility_range_begin = dist_lod
				mmil.visibility_range_begin_margin = margem_lod
				mmil.visibility_range_fade_mode = \
					GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

			total += lote.size()
		linhas.append("%s: %d instâncias em %d blocos" % [
			especie, pts.size(), blocos.size()])

	linhas.append("TOTAL: %d plantas em %d MultiMesh" % [total, get_child_count()])
	last_result = "\n".join(linhas)


func _persistir_malhas(malhas: Dictionary) -> void:
	"""Cada malha do kit vira um .tres proprio, uma vez so.

	Sem isto, a malha e o material da arvore sao gravados *dentro* de cada
	.tres de bloco: 20 copias da mesma folhosa. Salvando a parte, os blocos
	passam a referencia-la como recurso externo."""
	for nome in malhas.keys():
		var caminho := "%s/mesh_%s.tres" % [save_dir, nome]
		var malha: Mesh = malhas[nome]
		ResourceSaver.save(malha, caminho)
		malha.take_over_path(caminho)


func _fazer_mm(malha: Mesh, lote: Array, centro: Vector3) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha
	mm.instance_count = lote.size()
	for i in lote.size():
		var p: Array = lote[i]
		var pos := Vector3(float(p[0]), float(p[1]), float(p[2])) - centro
		var b := Basis(Vector3.UP, float(p[3])).scaled(Vector3.ONE * float(p[4]))
		mm.set_instance_transform(i, Transform3D(b, pos))
	return mm


func _instanciar(mm: MultiMesh, nome: String, centro: Vector3,
		sombra: int) -> MultiMeshInstance3D:
	"""Salva o MultiMesh como .tres e pendura um nó nele.

	Nunca embutir na cena: MultiMesh embutido já derrubou o editor na
	releitura ("Instance count must be 0 to change the transform format"
	-> SIGSEGV)."""
	var caminho := "%s/mm_%s.tres" % [save_dir, nome]
	ResourceSaver.save(mm, caminho)
	# take_over_path em vez de load(caminho): o editor guarda em cache o .tres
	# da construcao anterior, e load() devolveria as transformacoes velhas —
	# em coordenadas absolutas, que somadas ao novo `position` do bloco
	# dobravam o tamanho da mata. Assim o recurso novo assume o caminho e o
	# cache passa a apontar para ele.
	mm.take_over_path(caminho)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nome
	mmi.multimesh = mm
	mmi.position = centro
	mmi.cast_shadow = sombra
	add_child(mmi)
	mmi.owner = get_tree().edited_scene_root
	return mmi
