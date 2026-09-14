@tool
extends Node3D
## Etapa 08 — adereços de rua espalhados pela cidade.
##
## A cidade tinha casa, rua, poste e mato, mas nada do entulho que faz um lugar
## parecer habitado: lixeira encostada no muro, engradado no quintal, carro
## coberto na guia, ar-condicionado na fachada. Esta etapa põe isso.
##
## Cada adereço vira `MultiMeshInstance3D` — 1 draw call por espécie por bloco,
## transformações na GPU. Fatiar em blocos é o que permite o Godot descartar o
## que está fora da vista; um MultiMesh único cobrindo a cidade inteira nunca é
## descartado pelo frustum.
##
## Onde cada coisa pode cair sai de três fontes que já existem no projeto:
##   * `houses.json` — as 573 caixas de casa (posição, giro, largura, fundo);
##   * `poles.json`  — os 296 postes, que marcam a linha da calçada;
##   * a malha do nó `Roads`, rasterizada aqui num grid de 1 m (mesma ideia do
##     `scripts/npcs/shadow_roads.gd`) — o `city_roads.gltf` é só visual, não dá
##     para sondar com raycast.
##
## ATENÇÃO com o `y` dos JSONs, que não é o chão:
##   * `poles.json/luzes[].y` é a CABEÇA da luminária — fica 8,4 m acima do
##     chão (a `pocas[]` correspondente é que está no piso);
##   * `houses.json/casas[].y` é o PISO da casa, que a mediana põe 0,93 m e no
##     pior caso 3,8 m acima do terreno vizinho.
## Usar qualquer um dos dois como chão faz o adereço flutuar. O chão sai do
## Terrain3D (`data.get_height`), igual ao `greens.gd`, e do asfalto rasterizado
## quando o adereço é de rua. Por isso esta etapa mora na `stage_1`, e não na
## `city.tscn`: é lá que o terreno existe.

const CAMINHO_PH := "res://assets/3d_model/polyhaven/%s/%s_1k.gltf"
## Malhas extraídas dos .gltf. Sem isso cada MultiMesh embute a própria cópia
## da geometria: 37 adereços viraram 74 ArrayMesh embutidos e a cena saltou de
## 0,3 MB para 10 MB — além de desperdiçar VRAM, já que nenhuma cópia é
## compartilhada. Mesmo padrão do `assets/3d_model/mobilia/malhas/`.
const DIR_MALHAS := "res://assets/3d_model/city/malhas_props"

@export_group("Entrada")
@export var houses_json: String = "res://assets/3d_model/city/houses.json"
@export var poles_json: String = "res://assets/3d_model/city/poles.json"
@export var no_ruas: NodePath = ^"../City/Roads"
## O nó do terreno se chama "Terrenasso" — o greens.gd procura por
## "Terrain3D" e por isso nunca acha, caindo em y = 0.
@export var no_terreno: NodePath = ^"../NavigationRegion3D/Terrenasso"
## Deslocamento da cidade no mundo: os JSONs estão em coordenadas locais dela.
@export var no_cidade: NodePath = ^"../City"

@export_group("Espalhamento")
## Trave a semente para o resultado ser sempre o mesmo.
@export var semente: int = 20260914
## Multiplicador geral de quantidade. 1.0 ≈ 1400 adereços.
@export_range(0.0, 3.0, 0.05) var densidade: float = 1.0
## Distância mínima entre dois adereços, em metros.
@export var espacamento: float = 1.6
## Lado do bloco espacial. Igual à vegetação: sem fatiar, a cidade inteira
## renderiza sempre.
@export var bloco: float = 128.0

@export_group("Colisão")
## Barra o jogador só nos volumes grandes (barreira, caixa de força, lixeira).
## O miudê fica decorativo, como a vegetação.
@export var colisao_grandes: bool = true
@export var camada_colisao: int = 2

@export_multiline var last_result: String = ""

## Os MultiMesh ficam EMBUTIDOS na cena, não em .tres separados. Salvar 300
## recursos um a um faz `ResourceSaver.save()` girar o loop principal 300 vezes,
## e a cada giro o editor pode aplicar um reload deste mesmo script @tool — que
## está no meio da execução. É SIGSEGV na certa (a etapa 07 documenta o mesmo
## sintoma). Sem save, a construção inteira roda sem devolver o loop.
##
## A trava abaixo ainda protege contra um segundo `construir` disparado antes do
## primeiro terminar.
var _ocupado: bool = false

@export var construir: bool = false:
	set(v):
		construir = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_construir()
			_ocupado = false

## Passo único, antes do primeiro `construir`: grava as malhas dos adereços em
## `DIR_MALHAS`. Só precisa rodar de novo se um .gltf mudar.
@export var extrair_malhas: bool = false:
	set(v):
		extrair_malhas = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_extrair_malhas()
			_ocupado = false

@export var limpar: bool = false:
	set(v):
		limpar = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_limpar()
			_ocupado = false


# --------------------------------------------------------------------------
# catálogo
# --------------------------------------------------------------------------
# papel: onde o adereço pode nascer.
#   fachada  — encostado na parede da casa, virado para fora
#   parede   — preso na parede, a certa altura
#   calcada  — junto ao poste
#   beira    — na guia, alinhado com a rua (obra/interdição)
#   fundo    — quintal / terreno entre casas
#   asfalto  — em cima da rua (só bueiro)
# base_y: quanto subir para o modelo assentar (é o -y_min dele).
# raio: meia-largura usada no espaçamento.
const CATALOGO := [
	# --- encostado na fachada -------------------------------------------
	{"n": "metal_trash_can", "papel": "fachada", "peso": 5, "base_y": 0.16, "raio": 1.1, "esc": [0.95, 1.05], "grande": true, "col": [2.1, 1.2, 0.7]},
	{"n": "trashbag", "papel": "fachada", "peso": 15, "base_y": 0.0, "raio": 0.4, "esc": [0.85, 1.2]},
	{"n": "cardboard_box_01", "papel": "fachada", "peso": 12, "base_y": 0.01, "raio": 0.35, "esc": [0.9, 1.25]},
	{"n": "wooden_crate_01", "papel": "fachada", "peso": 10, "base_y": 0.01, "raio": 0.5, "esc": [0.9, 1.15]},
	{"n": "wooden_crate_02", "papel": "fachada", "peso": 6, "base_y": 0.01, "raio": 0.6, "esc": [0.9, 1.15]},
	{"n": "plastic_crate_02", "papel": "fachada", "peso": 10, "base_y": 0.0, "raio": 0.35, "esc": [0.9, 1.2]},
	{"n": "barrel_03", "papel": "fachada", "peso": 6, "base_y": 0.0, "raio": 0.4, "esc": [0.9, 1.1]},
	{"n": "Barrel_02", "papel": "fachada", "peso": 5, "base_y": 0.0, "raio": 0.35, "esc": [0.9, 1.1]},
	{"n": "propane_tank", "papel": "fachada", "peso": 5, "base_y": 0.0, "raio": 0.3, "esc": [0.9, 1.1]},
	{"n": "compost_bag_02", "papel": "fachada", "peso": 5, "base_y": 0.01, "raio": 0.4, "esc": [0.9, 1.2]},
	{"n": "wooden_ladder", "papel": "fachada", "peso": 4, "base_y": 0.0, "raio": 0.6, "esc": [0.95, 1.05]},
	{"n": "plastic_monobloc_chair_01", "papel": "fachada", "peso": 5, "base_y": 0.0, "raio": 0.45, "esc": [0.95, 1.05]},
	{"n": "planter_box_01", "papel": "fachada", "peso": 8, "base_y": 0.0, "raio": 0.55, "esc": [0.9, 1.1]},
	{"n": "planter_box_02", "papel": "fachada", "peso": 4, "base_y": 0.0, "raio": 0.7, "esc": [0.9, 1.1]},
	{"n": "planter_box_03", "papel": "fachada", "peso": 4, "base_y": 0.0, "raio": 0.55, "esc": [0.9, 1.1]},
	{"n": "hand_truck", "papel": "fachada", "peso": 3, "base_y": 0.0, "raio": 0.5, "esc": [0.95, 1.05]},
	{"n": "old_tyre", "papel": "fachada", "peso": 4, "base_y": 0.3, "raio": 0.4, "esc": [0.9, 1.1]},

	# --- preso na parede --------------------------------------------------
	{"n": "exterior_aircon_unit", "papel": "parede", "peso": 4, "alt": [2.2, 3.4], "esc": [0.95, 1.05]},
	{"n": "industrial_wall_lamp", "papel": "parede", "peso": 6, "alt": [2.4, 3.2], "esc": [0.95, 1.1]},
	{"n": "security_camera_01", "papel": "parede", "peso": 1, "alt": [2.8, 3.8], "esc": [0.95, 1.05]},
	{"n": "garden_hose_wall_mounted_01", "papel": "parede", "peso": 7, "alt": [1.3, 1.9], "esc": [0.95, 1.05]},

	# --- calçada, junto ao poste -----------------------------------------
	{"n": "fire_hydrant", "papel": "calcada", "peso": 2, "base_y": 0.0, "raio": 0.5, "esc": [0.95, 1.05], "grande": true, "col": [0.9, 0.85, 0.4]},
	{"n": "utility_box_01", "papel": "calcada", "peso": 6, "base_y": 0.0, "raio": 0.4, "esc": [0.95, 1.05], "grande": true, "col": [0.6, 1.15, 0.5]},
	{"n": "utility_box_02", "papel": "calcada", "peso": 4, "base_y": 0.0, "raio": 0.6, "esc": [0.95, 1.05], "grande": true, "col": [1.0, 1.15, 0.5]},
	{"n": "planter_box_03", "papel": "calcada", "peso": 6, "base_y": 0.0, "raio": 0.55, "esc": [0.9, 1.1]},
	{"n": "trashbag", "papel": "calcada", "peso": 6, "base_y": 0.0, "raio": 0.4, "esc": [0.85, 1.2]},
	{"n": "weed_plant_02", "papel": "calcada", "peso": 7, "base_y": 0.01, "raio": 0.9, "esc": [0.8, 1.3]},
	{"n": "shrub_03", "papel": "calcada", "peso": 5, "base_y": 0.0, "raio": 0.7, "esc": [0.8, 1.3]},
	{"n": "barrel_03", "papel": "calcada", "peso": 4, "base_y": 0.0, "raio": 0.4, "esc": [0.9, 1.1]},
	{"n": "cardboard_box_01", "papel": "calcada", "peso": 4, "base_y": 0.01, "raio": 0.35, "esc": [0.9, 1.25]},
	{"n": "metal_trash_can", "papel": "calcada", "peso": 4, "base_y": 0.16, "raio": 1.1, "esc": [0.95, 1.05], "grande": true, "col": [2.1, 1.2, 0.7]},

	# --- na guia, alinhado com a rua -------------------------------------
	{"n": "concrete_road_barrier", "papel": "beira", "peso": 4, "base_y": 0.01, "raio": 0.9, "esc": [0.95, 1.05], "grande": true, "col": [1.6, 0.85, 0.7]},

	# --- quintal e terreno entre casas -----------------------------------
	{"n": "wine_barrel_01", "papel": "fundo", "peso": 5, "base_y": 0.0, "raio": 0.5, "esc": [0.9, 1.1]},
	{"n": "wooden_picnic_table", "papel": "fundo", "peso": 4, "base_y": 0.0, "raio": 1.6, "esc": [0.95, 1.05], "grande": true, "col": [2.3, 0.8, 3.1]},
	{"n": "stone_fire_pit", "papel": "fundo", "peso": 4, "base_y": 0.19, "raio": 0.9, "esc": [0.9, 1.1]},
	{"n": "tree_stump_01", "papel": "fundo", "peso": 5, "base_y": 0.19, "raio": 0.9, "esc": [0.85, 1.15]},
	{"n": "dead_tree_trunk_02", "papel": "fundo", "peso": 3, "base_y": 0.33, "raio": 2.2, "esc": [0.85, 1.15]},
	{"n": "shrub_02", "papel": "fundo", "peso": 7, "base_y": 0.2, "raio": 1.3, "esc": [0.8, 1.2]},
	{"n": "shrub_03", "papel": "fundo", "peso": 12, "base_y": 0.0, "raio": 0.7, "esc": [0.8, 1.3]},
	{"n": "weed_plant_02", "papel": "fundo", "peso": 14, "base_y": 0.01, "raio": 0.9, "esc": [0.8, 1.3]},
	{"n": "old_tyre", "papel": "fundo", "peso": 5, "base_y": 0.3, "raio": 0.4, "esc": [0.9, 1.15]},
	{"n": "street_rat", "papel": "fundo", "peso": 3, "base_y": 0.0, "raio": 0.2, "esc": [1.0, 1.0]},

	# --- no asfalto --------------------------------------------------------
	{"n": "water_manhole_cover", "papel": "asfalto", "peso": 10, "base_y": 0.03, "raio": 0.5, "esc": [1.0, 1.0]},
]

## Quantos candidatos cada papel tenta gerar (antes da densidade e das
## rejeições). O número final sai bem abaixo disto.
const TENTATIVAS := {
	"fachada": 1500, "parede": 340, "calcada": 900,
	"beira": 45, "fundo": 1800, "asfalto": 150,
}

const CELULA_RUA := 1.0
## Altura do braço do poste. `poles.json/luzes[].y` é a cabeça da luminária;
## medido contra a poça de luz correspondente, a diferença é 8,26–8,50 m.
const ALTURA_LUMINARIA := 8.4

var _rng := RandomNumberGenerator.new()
var _ruas: Dictionary = {}          # chave da célula -> altura do asfalto
var _casas: Array = []
var _grade_casas: Dictionary = {}   # célula de 16 m -> índices de casa
var _ocupacao: Dictionary = {}      # célula do espaçamento -> true
var _ocupacao_parede: Dictionary = {}
var _terreno: Node3D = null
var _desloc := Vector3.ZERO
var _sem_terreno := 0


# --------------------------------------------------------------------------
func _limpar() -> void:
	var n := 0
	for c in get_children():
		remove_child(c)
		c.free()
		n += 1
	last_result = "removidos %d nós" % n


func _construir() -> void:
	var t0 := Time.get_ticks_msec()
	_limpar()
	_rng.seed = semente
	_ocupacao.clear()
	_ocupacao_parede.clear()

	var malhas := _colher_malhas()
	if malhas.is_empty():
		last_result = "ERRO: nenhuma malha de adereço carregada"
		return

	_casas = _ler_json(houses_json).get("casas", [])
	var postes: Array = _ler_json(poles_json).get("luzes", [])
	if _casas.is_empty():
		last_result = "ERRO: houses.json vazio (%s)" % houses_json
		return
	_indexar_casas()

	_terreno = get_node_or_null(no_terreno) as Node3D
	var cidade := get_node_or_null(no_cidade) as Node3D
	_desloc = cidade.global_position - global_position if cidade != null else Vector3.ZERO
	_sem_terreno = 0
	if _terreno == null:
		push_warning("CityPropsExtra: Terrain3D não encontrado em '%s'; o chão virá do asfalto mais próximo." % no_terreno)

	var tris_ruas := _rasterizar_ruas()
	var calib := _calibrar_terreno()

	# papel -> lista de transformações por espécie
	var saida: Dictionary = {}
	for item in CATALOGO:
		saida[item["n"]] = []

	var por_papel := {}
	for item in CATALOGO:
		por_papel.get_or_add(item["papel"], []).append(item)

	var n_fachada := _espalhar_fachada(por_papel.get("fachada", []), saida)
	var n_parede := _espalhar_parede(por_papel.get("parede", []), saida)
	var n_calcada := _espalhar_calcada(por_papel.get("calcada", []), postes, saida)
	var n_beira := _espalhar_beira(por_papel.get("beira", []), postes, saida)
	var n_fundo := _espalhar_fundo(por_papel.get("fundo", []), saida)
	var n_asfalto := _espalhar_asfalto(por_papel.get("asfalto", []), saida)

	var total := n_fachada + n_parede + n_calcada + n_beira + n_fundo + n_asfalto
	var nos := _emitir(saida, malhas)
	var grandes := _emitir_colisoes(saida) if colisao_grandes else 0

	last_result = ("%d adereços | fachada %d, parede %d, calçada %d, guia %d, "
		+ "quintal %d, asfalto %d | %d MultiMesh, %d colisões | "
		+ "%d células de rua de %d triângulos | %d sem terreno | %s | %d ms") % [
		total, n_fachada, n_parede, n_calcada, n_beira, n_fundo, n_asfalto,
		nos, grandes, _ruas.size(), tris_ruas, _sem_terreno, calib, Time.get_ticks_msec() - t0]
	print("CityPropsExtra: ", last_result)


# --------------------------------------------------------------------------
# entrada
# --------------------------------------------------------------------------
func _ler_json(caminho: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(caminho)
	if txt.is_empty():
		return {}
	var d = JSON.parse_string(txt)
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _extrair_malhas() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_MALHAS))
	var n := 0
	var faltou: Array[String] = []
	for item in CATALOGO:
		var nome: String = item["n"]
		var destino := "%s/%s.res" % [DIR_MALHAS, nome]
		if ResourceLoader.exists(destino):
			continue
		var caminho := CAMINHO_PH % [nome, nome]
		if not ResourceLoader.exists(caminho):
			faltou.append(nome)
			continue
		var raiz := (load(caminho) as PackedScene).instantiate()
		var achado := _primeira_malha(raiz)
		if achado != null and achado.mesh != null:
			var m: Mesh = achado.mesh.duplicate(true)
			# o transform local do nó entra aqui, para a malha já sair no lugar
			m.resource_path = ""
			ResourceSaver.save(m, destino)
			n += 1
		raiz.free()
	last_result = "extraídas %d malhas em %s%s" % [
		n, DIR_MALHAS, ("" if faltou.is_empty() else " | faltando: " + ", ".join(faltou))]
	print("CityPropsExtra: ", last_result)


func _colher_malhas() -> Dictionary:
	"""Nome do adereço -> {mesh, xf}. `xf` é o transform local do MeshInstance
	dentro do .gltf, que precisa entrar na conta de cada instância."""
	var out := {}
	for item in CATALOGO:
		var nome: String = item["n"]
		if out.has(nome):
			continue
		var caminho := CAMINHO_PH % [nome, nome]
		if not ResourceLoader.exists(caminho):
			push_warning("CityPropsExtra: falta %s" % caminho)
			continue
		var ps := load(caminho) as PackedScene
		if ps == null:
			continue
		var raiz := ps.instantiate()
		var achado := _primeira_malha(raiz)
		if achado != null:
			# prefere a malha extraída: ela tem caminho próprio, então a cena a
			# referencia em vez de embutir uma cópia por MultiMesh
			var extraida := "%s/%s.res" % [DIR_MALHAS, nome]
			var malha: Mesh = load(extraida) if ResourceLoader.exists(extraida) else achado.mesh
			out[nome] = {"mesh": malha, "xf": _xf_relativo(achado, raiz)}
		raiz.free()
	return out


func _primeira_malha(n: Node) -> MeshInstance3D:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		return mi
	for c in n.get_children():
		var r := _primeira_malha(c)
		if r != null:
			return r
	return null


func _xf_relativo(no: Node3D, raiz: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var atual: Node = no
	while atual != null and atual != raiz:
		var n3 := atual as Node3D
		if n3 != null:
			xf = n3.transform * xf
		atual = atual.get_parent()
	return xf


# --------------------------------------------------------------------------
# mapa de ruas (mesma ideia do shadow_roads.gd: a malha é só visual)
# --------------------------------------------------------------------------
func _rasterizar_ruas() -> int:
	_ruas.clear()
	var raiz := get_node_or_null(no_ruas) as Node3D
	if raiz == null:
		push_warning("CityPropsExtra: nó de ruas '%s' não encontrado; nada será rejeitado por asfalto." % no_ruas)
		return 0
	var total := 0
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		for c in n.get_children():
			pilha.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# tudo em coordenadas LOCAIS da cidade, que é o espaço dos JSONs
		var base := (get_node_or_null(no_cidade) as Node3D)
		var xf := (base.global_transform.affine_inverse() if base != null
			else global_transform.affine_inverse()) * mi.global_transform
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			if arr.is_empty():
				continue
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if verts.is_empty():
				continue
			var mundo := PackedVector3Array()
			mundo.resize(verts.size())
			for i in verts.size():
				mundo[i] = xf * verts[i]
			if idx.is_empty():
				for i in range(0, mundo.size() - 2, 3):
					_marcar_tri(mundo[i], mundo[i + 1], mundo[i + 2])
					total += 1
			else:
				for i in range(0, idx.size() - 2, 3):
					_marcar_tri(mundo[idx[i]], mundo[idx[i + 1]], mundo[idx[i + 2]])
					total += 1
	return total


func _marcar_tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	var x0 := floori(minf(a.x, minf(b.x, c.x)) / CELULA_RUA)
	var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / CELULA_RUA)
	var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELULA_RUA)
	var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELULA_RUA)
	if (x1 - x0) > 64 or (z1 - z0) > 64:
		return  # triângulo gigante de fundo
	var y := maxf(a.y, maxf(b.y, c.y))
	for ix in range(x0, x1 + 1):
		for iz in range(z0, z1 + 1):
			var k := _chave(ix, iz)
			if not _ruas.has(k) or float(_ruas[k]) < y:
				_ruas[k] = y


func _chave(ix: int, iz: int) -> int:
	return (ix << 32) | (iz & 0xFFFFFFFF)


## Altura do chão em coordenadas LOCAIS da cidade.
##
## Ordem: terreno (é onde o jogador pisa) -> asfalto mais próximo -> o valor de
## reserva que o chamador passar (o piso da casa). NAN nunca sai daqui.
## Confere o get_height() contra o asfalto rasterizado nas mesmas células.
## Se a mediana não for ~0, o terreno está em outro referencial e é melhor saber
## disso do que enterrar mil adereços.
func _calibrar_terreno() -> String:
	if _terreno == null or _ruas.is_empty():
		return "sem terreno"
	var dados = _terreno.get("data")
	if dados == null:
		return "terreno sem data"
	var difs: Array[float] = []
	var chaves := _ruas.keys()
	var passo := maxi(1, chaves.size() / 400)
	for i in range(0, chaves.size(), passo):
		var k = chaves[i]
		var ix := int(k >> 32)
		var iz := int(k & 0xFFFFFFFF)
		if iz > 0x7FFFFFFF:
			iz -= 0x100000000
		var pl := Vector3(ix * CELULA_RUA, 0.0, iz * CELULA_RUA)
		var yt: float = dados.get_height(pl + _desloc)
		if is_nan(yt):
			continue
		difs.append(yt - float(_ruas[k]))
	if difs.is_empty():
		return "get_height só devolveu NAN"
	difs.sort()
	return "terreno-asfalto mediana %.2f m (n=%d)" % [difs[difs.size() / 2], difs.size()]


func _chao(x: float, z: float, reserva: float) -> float:
	if _terreno != null:
		var dados = _terreno.get("data")
		if dados != null:
			var y: float = dados.get_height(Vector3(x, 0.0, z) + _desloc)
			if not is_nan(y):
				return y
	_sem_terreno += 1
	var yr := _altura_rua_perto(Vector3(x, 0.0, z), 14.0)
	return yr if not is_nan(yr) else reserva


## Asfalto mais próximo, em anéis crescentes de células.
func _altura_rua_perto(p: Vector3, raio_max: float) -> float:
	var ix := floori(p.x / CELULA_RUA)
	var iz := floori(p.z / CELULA_RUA)
	var passos := int(raio_max / CELULA_RUA)
	for r in range(0, passos + 1):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if r > 0 and absi(dx) != r and absi(dz) != r:
					continue   # só a casca do anel
				var k := _chave(ix + dx, iz + dz)
				if _ruas.has(k):
					return float(_ruas[k])
	return NAN


func _eh_rua(p: Vector3) -> bool:
	if _ruas.is_empty():
		return false
	return _ruas.has(_chave(floori(p.x / CELULA_RUA), floori(p.z / CELULA_RUA)))


func _altura_rua(p: Vector3) -> float:
	var k := _chave(floori(p.x / CELULA_RUA), floori(p.z / CELULA_RUA))
	return float(_ruas[k]) if _ruas.has(k) else NAN


# --------------------------------------------------------------------------
# casas
# --------------------------------------------------------------------------
const CELULA_CASA := 16.0

func _indexar_casas() -> void:
	_grade_casas.clear()
	for i in _casas.size():
		var c: Dictionary = _casas[i]
		# raio bruto: a diagonal da caixa cobre qualquer giro
		var r: float = maxf(float(c["w"]), float(c["d"]))
		var x0 := floori((float(c["x"]) - r) / CELULA_CASA)
		var x1 := floori((float(c["x"]) + r) / CELULA_CASA)
		var z0 := floori((float(c["z"]) - r) / CELULA_CASA)
		var z1 := floori((float(c["z"]) + r) / CELULA_CASA)
		for ix in range(x0, x1 + 1):
			for iz in range(z0, z1 + 1):
				var k := _chave(ix, iz)
				if not _grade_casas.has(k):
					_grade_casas[k] = PackedInt32Array()
				var arr: PackedInt32Array = _grade_casas[k]
				arr.append(i)
				_grade_casas[k] = arr


func _dentro_de_casa(p: Vector3, folga := 0.0) -> bool:
	var k := _chave(floori(p.x / CELULA_CASA), floori(p.z / CELULA_CASA))
	if not _grade_casas.has(k):
		return false
	for i in (_grade_casas[k] as PackedInt32Array):
		var c: Dictionary = _casas[i]
		var d := Vector2(p.x - float(c["x"]), p.z - float(c["z"]))
		var r := -float(c["rot"])
		var lx := d.x * cos(r) - d.y * sin(r)
		var lz := d.x * sin(r) + d.y * cos(r)
		if absf(lx) <= float(c["w"]) * 0.5 + folga and absf(lz) <= float(c["d"]) * 0.5 + folga:
			return true
	return false


# --------------------------------------------------------------------------
# espaçamento
# --------------------------------------------------------------------------
## Grade única para todo mundo: com um passo por raio, um engradado e um carro
## caíam em grades diferentes e nunca se viam.
func _celulas(p: Vector3, raio: float) -> Array:
	var ix := floori(p.x / espacamento)
	var iz := floori(p.z / espacamento)
	var r := ceili(maxf(raio, espacamento * 0.5) / espacamento)
	var out := []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			out.append(_chave(ix + dx, iz + dz))
	return out


func _livre(p: Vector3, raio: float, grade := _ocupacao) -> bool:
	for k in _celulas(p, raio):
		if grade.has(k):
			return false
	return true


func _ocupar(p: Vector3, raio: float, grade := _ocupacao) -> void:
	for k in _celulas(p, raio):
		grade[k] = true


func _sortear(lista: Array) -> Dictionary:
	var soma := 0
	for it in lista:
		soma += int(it["peso"])
	var r := _rng.randi_range(0, soma - 1)
	for it in lista:
		r -= int(it["peso"])
		if r < 0:
			return it
	return lista[-1]


func _transform(item: Dictionary, pos: Vector3, giro: float) -> Transform3D:
	var e: Array = item.get("esc", [1.0, 1.0])
	var s := _rng.randf_range(float(e[0]), float(e[1]))
	var b := Basis(Vector3.UP, giro).scaled(Vector3.ONE * s)
	return Transform3D(b, pos)


# --------------------------------------------------------------------------
# os seis papéis
# --------------------------------------------------------------------------
func _espalhar_fachada(lista: Array, saida: Dictionary) -> int:
	if lista.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["fachada"] * densidade)
	for t in tentativas:
		var casa: Dictionary = _casas[_rng.randi_range(0, _casas.size() - 1)]
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 0.5))
		# escolhe um dos quatro lados e um ponto nele
		var lado := _rng.randi_range(0, 3)
		var w := float(casa["w"]) * 0.5
		var d := float(casa["d"]) * 0.5
		var fora := _rng.randf_range(0.35, 0.9) + raio
		var lx: float
		var lz: float
		var normal: float
		match lado:
			0: lx = _rng.randf_range(-w, w); lz = d + fora; normal = 0.0
			1: lx = _rng.randf_range(-w, w); lz = -d - fora; normal = PI
			2: lx = w + fora; lz = _rng.randf_range(-d, d); normal = PI * 0.5
			_: lx = -w - fora; lz = _rng.randf_range(-d, d); normal = -PI * 0.5
		var rot := float(casa["rot"])
		var p := Vector3(
			float(casa["x"]) + lx * cos(rot) - lz * sin(rot),
			float(casa["y"]),
			float(casa["z"]) + lx * sin(rot) + lz * cos(rot))
		if _eh_rua(p) or _dentro_de_casa(p, raio * 0.8) or not _livre(p, raio):
			continue
		p.y = _chao(p.x, p.z, float(casa["y"])) + float(item.get("base_y", 0.0))
		# de costas para a parede, com uma inclinação de descuido
		var giro := rot + normal + _rng.randf_range(-0.35, 0.35)
		saida[item["n"]].append(_transform(item, p, giro))
		_ocupar(p, raio)
		n += 1
	return n


func _espalhar_parede(lista: Array, saida: Dictionary) -> int:
	if lista.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["parede"] * densidade)
	for t in tentativas:
		var casa: Dictionary = _casas[_rng.randi_range(0, _casas.size() - 1)]
		var h := float(casa["h"])
		if h < 2.8:
			continue
		var item := _sortear(lista)
		var alt: Array = item.get("alt", [2.2, 3.0])
		var y := _rng.randf_range(float(alt[0]), float(alt[1]))
		if y > h - 0.4:
			continue
		var lado := _rng.randi_range(0, 3)
		var w := float(casa["w"]) * 0.5
		var d := float(casa["d"]) * 0.5
		var lx: float
		var lz: float
		var normal: float
		match lado:
			0: lx = _rng.randf_range(-w * 0.75, w * 0.75); lz = d + 0.12; normal = 0.0
			1: lx = _rng.randf_range(-w * 0.75, w * 0.75); lz = -d - 0.12; normal = PI
			2: lx = w + 0.12; lz = _rng.randf_range(-d * 0.75, d * 0.75); normal = PI * 0.5
			_: lx = -w - 0.12; lz = _rng.randf_range(-d * 0.75, d * 0.75); normal = -PI * 0.5
		var rot := float(casa["rot"])
		var px := float(casa["x"]) + lx * cos(rot) - lz * sin(rot)
		var pz := float(casa["z"]) + lx * sin(rot) + lz * cos(rot)
		var p := Vector3(px, _chao(px, pz, float(casa["y"])) + y, pz)
		# na parede o espaçamento é em 3D: duas peças podem dividir a mesma
		# planta baixa em alturas diferentes, então uso um raio pequeno
		if not _livre(p, 0.9, _ocupacao_parede):
			continue
		saida[item["n"]].append(_transform(item, p, rot + normal))
		_ocupar(p, 0.9, _ocupacao_parede)
		n += 1
	return n


func _espalhar_calcada(lista: Array, postes: Array, saida: Dictionary) -> int:
	if lista.is_empty() or postes.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["calcada"] * densidade)
	for t in tentativas:
		var poste: Dictionary = postes[_rng.randi_range(0, postes.size() - 1)]
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 0.5))
		var rot := float(poste["rot"])
		# desliza ao longo da calçada (perpendicular ao braço do poste)
		var ao_longo := _rng.randf_range(1.5, 8.0) * (1 if _rng.randf() < 0.5 else -1)
		# negativo = para trás do poste, ou seja, para a calçada
		var afasta := _rng.randf_range(-2.6, -0.4)
		var p := Vector3(
			float(poste["x"]) + cos(rot) * afasta - sin(rot) * ao_longo,
			0.0,
			float(poste["z"]) + sin(rot) * afasta + cos(rot) * ao_longo)
		if _eh_rua(p) or _dentro_de_casa(p, raio) or not _livre(p, raio):
			continue
		# ALTURA_LUMINARIA: o y do poste é a cabeça da luz, não o piso
		p.y = _chao(p.x, p.z, float(poste["y"]) - ALTURA_LUMINARIA) + float(item.get("base_y", 0.0))
		saida[item["n"]].append(_transform(item, p, rot + _rng.randf_range(-0.25, 0.25)))
		_ocupar(p, raio)
		n += 1
	return n


func _espalhar_beira(lista: Array, postes: Array, saida: Dictionary) -> int:
	"""A barreira encosta na guia, alinhada com a pista.
	O braço do poste aponta para a rua, então a direção da rua é ele girado 90°."""
	if lista.is_empty() or postes.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["beira"] * densidade)
	for t in tentativas:
		var poste: Dictionary = postes[_rng.randi_range(0, postes.size() - 1)]
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 1.0))
		var rot := float(poste["rot"])
		var ao_longo := _rng.randf_range(3.0, 9.0) * (1 if _rng.randf() < 0.5 else -1)
		var afasta := _rng.randf_range(1.6, 3.0)   # para dentro da pista
		var p := Vector3(
			float(poste["x"]) + cos(rot) * afasta - sin(rot) * ao_longo,
			0.0,
			float(poste["z"]) + sin(rot) * afasta + cos(rot) * ao_longo)
		# aqui a rua é obrigatória: é onde se estaciona
		var yr := _altura_rua(p)
		if is_nan(yr) or _dentro_de_casa(p, raio) or not _livre(p, raio):
			continue
		p.y = yr + float(item.get("base_y", 0.0))
		# o volume é comprido no Z local, então alinha o Z com a pista
		var giro := rot + PI * 0.5 + _rng.randf_range(-0.05, 0.05)
		if _rng.randf() < 0.5:
			giro += PI
		saida[item["n"]].append(_transform(item, p, giro))
		_ocupar(p, raio)
		n += 1
	return n


func _espalhar_fundo(lista: Array, saida: Dictionary) -> int:
	"""Quintal: perto de uma casa mas fora dela e fora da rua."""
	if lista.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["fundo"] * densidade)
	for t in tentativas:
		var casa: Dictionary = _casas[_rng.randi_range(0, _casas.size() - 1)]
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 0.5))
		var ang := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(maxf(float(casa["w"]), float(casa["d"])) * 0.7 + 1.4, 13.0)
		var p := Vector3(
			float(casa["x"]) + cos(ang) * dist,
			0.0,
			float(casa["z"]) + sin(ang) * dist)
		if _eh_rua(p) or _dentro_de_casa(p, raio + 0.4) or not _livre(p, raio):
			continue
		p.y = _chao(p.x, p.z, float(casa["y"])) + float(item.get("base_y", 0.0))
		saida[item["n"]].append(_transform(item, p, _rng.randf_range(0.0, TAU)))
		_ocupar(p, raio)
		n += 1
	return n


func _espalhar_asfalto(lista: Array, saida: Dictionary) -> int:
	"""Bueiro: o único que fica em cima da pista."""
	if lista.is_empty() or _ruas.is_empty():
		return 0
	var chaves := _ruas.keys()
	var n := 0
	var tentativas := int(TENTATIVAS["asfalto"] * densidade)
	for t in tentativas:
		var k = chaves[_rng.randi_range(0, chaves.size() - 1)]
		var ix := int(k >> 32)
		var iz := int(k & 0xFFFFFFFF)
		if iz > 0x7FFFFFFF:
			iz -= 0x100000000
		var p := Vector3((ix + 0.5) * CELULA_RUA, float(_ruas[k]), (iz + 0.5) * CELULA_RUA)
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 0.5))
		if not _livre(p, maxf(raio, 6.0)):   # bueiros bem espalhados
			continue
		p.y += float(item.get("base_y", 0.0))
		saida[item["n"]].append(_transform(item, p, _rng.randf_range(0.0, TAU)))
		_ocupar(p, maxf(raio, 6.0))
		n += 1
	return n


# --------------------------------------------------------------------------
# saída: um MultiMeshInstance3D por espécie por bloco
# --------------------------------------------------------------------------
func _emitir(saida: Dictionary, malhas: Dictionary) -> int:
	var nos := 0
	for nome in saida.keys():
		var lista: Array = saida[nome]
		if lista.is_empty() or not malhas.has(nome):
			continue
		var info: Dictionary = malhas[nome]
		var local: Transform3D = info["xf"]
		# separa por bloco para o frustum poder descartar
		var blocos := {}
		for xf in lista:
			# as posições vêm no espaço da cidade; os nós vivem na raiz da cena
			var mundo: Transform3D = xf
			mundo.origin += _desloc
			var b := Vector2i(floori(mundo.origin.x / bloco), floori(mundo.origin.z / bloco))
			blocos.get_or_add(b, []).append(mundo * local)
		for b in blocos.keys():
			var trs: Array = blocos[b]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = info["mesh"]
			mm.instance_count = trs.size()
			for i in trs.size():
				mm.set_instance_transform(i, trs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [nome, b.x, b.y]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mmi.visibility_range_end = 0.0
			mmi.lod_bias = 1.0
			add_child(mmi)
			mmi.owner = get_tree().edited_scene_root
			nos += 1
	return nos


func _emitir_colisoes(saida: Dictionary) -> int:
	"""Um StaticBody3D só, com uma caixa por volume grande. Corpo único porque
	573 corpos separados custariam bem mais no broadphase do que 573 formas."""
	var grandes := {}
	for item in CATALOGO:
		if item.get("grande", false):
			grandes[item["n"]] = item
	var corpo := StaticBody3D.new()
	corpo.name = "colisao_adereços"
	corpo.collision_layer = camada_colisao
	corpo.collision_mask = 0
	add_child(corpo)
	corpo.owner = get_tree().edited_scene_root
	var n := 0
	for nome in saida.keys():
		if not grandes.has(nome):
			continue
		var item: Dictionary = grandes[nome]
		var c: Array = item.get("col", [1.2, 1.4, 1.2])
		var altura := float(c[1])
		for xf in (saida[nome] as Array):
			var forma := CollisionShape3D.new()
			var caixa := BoxShape3D.new()
			caixa.size = Vector3(float(c[0]), altura, float(c[2]))
			forma.shape = caixa
			forma.transform = Transform3D(xf.basis.orthonormalized(),
				xf.origin + _desloc + Vector3.UP * altura * 0.5)
			corpo.add_child(forma)
			forma.owner = get_tree().edited_scene_root
			n += 1
	if n == 0:
		corpo.queue_free()
	return n
