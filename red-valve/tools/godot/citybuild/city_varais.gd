@tool
extends Node3D

## Etapa 11 — o que fica pendurado numa corda: varal de quintal e bandeirinha
## de festa atravessando a rua.
##
## As etapas 08 a 10 encheram a cidade de COISA. Coisa parada nao e' vida: uma
## cidade com trezentos engradados e nenhuma roupa no varal continua parecendo
## maquete. Faltava o sinal de que alguem mora ali e de que hoje foi dia de
## lavar roupa — e, no caso da bandeirinha, de que a rua inteira combinou uma
## festa.
##
## E' a unica etapa da serie que se MEXE. O balanco nao esta' na cena nem em
## AnimationPlayer nenhum: esta' no vertex() do `shaders/environment/varal.gdshader`,
## que torce cada peca em torno da borda de cima, com a fase tirada da posicao
## dela no mundo. Custo de CPU por quadro: zero.
##
## COMO UMA LINHA VIRA GEOMETRIA
## -----------------------------
## Cada varal e cada corda de bandeirinha e' uma CATENARIA aproximada por
## parabola entre dois pontos. Dela saem duas coisas:
##
##   * a corda — N caixinhas finas, uma por trecho, todas no mesmo MultiMesh;
##   * as pecas — um quad por peca, com o TOPO no ponto da corda.
##
## Ninguem repara na corda; todo mundo repara se a roupa flutua sem corda. Por
## isso a corda e' feita primeiro, e a peca e' pendurada no ponto exato dela.
##
## ONDE CADA UM NASCE
## ------------------
##   * varal — no quintal, entre dois mourões fincados no chao. O terreno sai
##     do Terrain3D via `CityMapa`, entao o varal acompanha o declive do lote.
##   * bandeirinha — entre DOIS POSTES de calcadas opostas, com o meio do vao
##     em cima do asfalto. E' essa checagem que impede a corda de atravessar
##     uma casa: dois postes vizinhos da MESMA calcada tem o meio do vao em
##     cima da calcada, e nao da rua.

const CityMapa := preload("res://tools/godot/citybuild/city_mapa.gd")
const SHADER := "res://shaders/environment/varal.gdshader"
const MANIFESTO := "res://assets/images/textures/varal/varal.json"

@export_group("Entrada")
@export var houses_json: String = "res://assets/3d_model/city/houses.json"
@export var poles_json: String = "res://assets/3d_model/city/poles.json"
@export var no_ruas: NodePath = ^"../City/Roads"
## O no do terreno se chama "Terrenasso"; procurar por "Terrain3D" nao acha.
@export var no_terreno: NodePath = ^"../NavigationRegion3D/Terrenasso"
@export var no_cidade: NodePath = ^"../City"

@export_group("Espalhamento")
## Adereços que ja' existem na cena e tambem ocupam lugar. As etapas 08 e 10
## tem grades de ocupacao proprias e nenhuma enxerga a outra: sem ler as
## posicoes delas aqui, o mourão do varal e' fincado dentro de um engradado.
## Separe varios caminhos com virgula. Vazio = nao considera nada.
@export var nos_props_existentes: String = "../PropsExtra,../_CityUrbano"
@export var semente: int = 20260915
@export_range(0.0, 3.0, 0.05) var densidade: float = 1.0
## Lado do bloco espacial. Sem fatiar, a cidade inteira renderiza sempre.
@export var bloco: float = 128.0

@export_group("Varal de quintal")
@export var varais_tentativas: int = 420
## Vao da corda, em metros.
@export var varal_vao := Vector2(2.6, 5.2)
## Altura da corda acima do chao.
@export var varal_altura := Vector2(1.65, 1.95)
## Quanto a corda cede no meio, em fracao do vao.
@export_range(0.0, 0.3, 0.005) var varal_barriga: float = 0.045
## Pecas penduradas por varal.
@export var varal_pecas := Vector2i(3, 7)
## Mourão nas pontas. Sem ele a corda comeca e termina no ar.
@export var varal_mouroes: bool = true

@export_group("Bandeirinha")
@export var bandeiras_tentativas: int = 260
## Vao aceito entre os dois postes.
@export var bandeira_vao := Vector2(9.0, 20.0)
## Altura da corda acima do chao. Bem abaixo da luminaria (que fica a 8,4 m).
@export var bandeira_altura := Vector2(5.0, 6.2)
@export_range(0.0, 0.3, 0.005) var bandeira_barriga: float = 0.07
## Espaco entre uma bandeirinha e a seguinte, em metros.
@export var bandeira_passo: float = 1.15

@export_group("Aparencia")
@export_range(0.0, 1.5, 0.01) var balanco: float = 0.32
@export_range(0.0, 4.0, 0.05) var velocidade_do_vento: float = 0.8
@export_range(0.0, 2.0, 0.05) var ganho: float = 1.0
## Trechos de caixinha por corda. Mais trechos = curva mais macia.
@export var trechos_da_corda: int = 8

@export_multiline var last_result: String = ""

## Sem `ResourceSaver`: salvar recurso a recurso devolve o loop principal ao
## editor no meio deste script @tool, e o reload que ele dispara e' SIGSEGV
## (a etapa 07 documenta o sintoma). Tudo aqui fica embutido na cena.
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


var _rng := RandomNumberGenerator.new()
var _mapa = null
var _esp = null
var _esp_props = null
var _atlas_caminho := ""


# --------------------------------------------------------------------------
func _limpar() -> void:
	var n := 0
	for c in get_children():
		remove_child(c)
		c.free()
		n += 1
	last_result = "removidos %d nos" % n


func _construir() -> void:
	var t0 := Time.get_ticks_msec()
	_limpar()
	_rng.seed = semente
	_esp = CityMapa.Espacador.new(1.5)
	_esp_props = CityMapa.Espacador.new(0.7)

	var pecas := _ler_pecas()
	if pecas.is_empty():
		last_result = "ERRO: nenhuma peca em %s (rode tools/texturas/gerar_varal.py)" % MANIFESTO
		return

	_mapa = CityMapa.new()
	if not _mapa.preparar(self,
			get_node_or_null(no_ruas) as Node3D,
			get_node_or_null(no_terreno) as Node3D,
			get_node_or_null(no_cidade) as Node3D,
			houses_json, poles_json):
		last_result = "ERRO: " + _mapa.erro
		return

	var herdados := 0
	for caminho in nos_props_existentes.split(",", false):
		herdados += _semear_ocupacao(get_node_or_null(NodePath(caminho.strip_edges())) as Node3D)

	var por_papel := {}
	for p in pecas:
		por_papel.get_or_add(p["papel"], []).append(p)

	# bloco -> lista de {xf, uv, cor} das PECAS; e bloco -> transformacoes da corda
	var panos := {}
	var cordas := {}
	var mouroes := {}

	var n_varais := _varais(por_papel.get("roupa", []), panos, cordas, mouroes)
	var n_bandeiras := _bandeiras(por_papel.get("bandeira", []), panos, cordas)

	var n_panos := 0
	for b in panos.keys():
		n_panos += (panos[b] as Array).size()

	var nos := _emitir_panos(panos)
	nos += _emitir_barras(cordas, "corda", Vector3(1.0, 0.013, 0.013), Color(0.16, 0.15, 0.14))
	nos += _emitir_barras(mouroes, "mourao", Vector3(1.0, 0.07, 0.07), Color(0.32, 0.26, 0.19))

	last_result = ("%d varais + %d cordas de bandeirinha | %d pecas penduradas | "
		+ "%d MultiMesh | desviando de %d adereços ja' postos | %s | %d ms") % [
		n_varais, n_bandeiras, n_panos, nos, herdados,
		_mapa.resumo(), Time.get_ticks_msec() - t0]
	print("CityVarais: ", last_result)


# --------------------------------------------------------------------------
# manifesto
# --------------------------------------------------------------------------
func _ler_pecas() -> Array:
	var txt := FileAccess.get_file_as_string(MANIFESTO)
	if txt.is_empty():
		push_error("CityVarais: %s nao existe." % MANIFESTO)
		return []
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return []
	_atlas_caminho = d.get("atlas", "")
	return d.get("pecas", [])


func _sortear(lista: Array) -> Dictionary:
	var soma := 0
	for it in lista:
		soma += int(it["peso"])
	var r := _rng.randi_range(0, maxi(1, soma) - 1)
	for it in lista:
		r -= int(it["peso"])
		if r < 0:
			return it
	return lista[-1]


func _tamanho(peca: Dictionary) -> Vector2:
	var faixa: Array = peca["largura"]
	var larg := _rng.randf_range(float(faixa[0]), float(faixa[1]))
	var px: Array = peca["px"]
	return Vector2(larg, larg * float(px[1]) / float(px[0]))


## Marca na grade os adereços que as etapas 08 e 10 ja' colocaram.
##
## Vai pra uma grade separada e MUITO mais curta que a dos varais. O passo dela
## e' 0,7 m de proposito: o mourão tem sete centimetros e so' precisa nao estar
## dentro de um engradado. Com 1,1 m o quintal inteiro ficava vetado — mil e
## novecentos adereços ja' postos derrubaram o numero de varais de setenta e
## cinco pra doze.
##
## As posicoes dos MultiMesh estao em MUNDO e a grade vive em coordenadas
## locais da cidade, dai a subtracao do deslocamento.
func _semear_ocupacao(raiz: Node3D) -> int:
	if raiz == null:
		return 0
	var n := 0
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for c in no.get_children():
			pilha.append(c)
		var mmi := no as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var origem: Vector3 = (mmi.global_transform * mm.get_instance_transform(i)).origin
			_esp_props.ocupar(origem - _mapa.desloc, 0.1)
			n += 1
	return n


# --------------------------------------------------------------------------
# a linha
# --------------------------------------------------------------------------
## Ponto da catenaria em `t` (0..1) entre `a` e `b`, cedendo `queda` metros no
## meio. Parabola no lugar de cosseno hiperbolico: com vao curto e queda
## pequena a diferenca nao chega a um centimetro, e sai sem exponencial.
func _na_linha(a: Vector3, b: Vector3, t: float, queda: float) -> Vector3:
	var p := a.lerp(b, t)
	p.y -= queda * 4.0 * t * (1.0 - t)
	return p


func _pendurar(pecas: Array, a: Vector3, b: Vector3, queda: float,
		quantas: int, panos: Dictionary, sway: float) -> int:
	"""Distribui `quantas` pecas ao longo da linha, cada uma com o TOPO no
	ponto da corda. As bordas ficam livres: peca colada no mourão fica com
	cara de erro."""
	if pecas.is_empty() or quantas <= 0:
		return 0
	var n := 0
	var dir := (b - a)
	dir.y = 0.0
	if dir.length() < 0.01:
		return 0
	dir = dir.normalized()
	for i in quantas:
		var t := (i + 0.85) / float(quantas + 0.7)
		var peca := _sortear(pecas)
		var tam := _tamanho(peca)
		var ponto := _na_linha(a, b, t, queda)
		# o quad e' centrado, mas quem esta' na corda e' a borda de cima
		ponto.y -= tam.y * 0.5
		var uv: Array = peca["uv"]
		_guardar_pano(panos, ponto, dir, tam,
			Color(float(uv[0]), float(uv[1]), float(uv[2]), float(uv[3])), sway)
		n += 1
	return n


func _guardar_pano(panos: Dictionary, centro: Vector3, dir: Vector3, tam: Vector2,
		uv: Color, sway: float) -> void:
	# o X do quad acompanha a corda; o Z sai perpendicular a ela
	var ex := dir
	var ey := Vector3.UP
	var ez := ex.cross(ey).normalized()
	var xf := Transform3D(Basis(ex * tam.x, ey * tam.y, ez), centro)
	xf.origin += _mapa.desloc
	var b := Vector2i(floori(xf.origin.x / bloco), floori(xf.origin.z / bloco))
	# tom de lavagem: nem toda roupa saiu da mesma agua
	var tom := _rng.randf_range(0.82, 1.06)
	panos.get_or_add(b, []).append({
		"xf": xf,
		"uv": uv,
		"cor": Color(tom, tom * _rng.randf_range(0.97, 1.03), tom * _rng.randf_range(0.95, 1.02), sway),
	})


func _guardar_corda(cordas: Dictionary, a: Vector3, b: Vector3, queda: float) -> void:
	for i in trechos_da_corda:
		var p0 := _na_linha(a, b, i / float(trechos_da_corda), queda)
		var p1 := _na_linha(a, b, (i + 1) / float(trechos_da_corda), queda)
		_guardar_barra(cordas, p0, p1)


## Uma caixinha esticada de `p0` a `p1`. O X local vira o comprimento.
func _guardar_barra(destino: Dictionary, p0: Vector3, p1: Vector3) -> void:
	var v := p1 - p0
	var comp := v.length()
	if comp < 0.001:
		return
	var ex := v / comp
	var ref := Vector3.UP if absf(ex.y) < 0.95 else Vector3.FORWARD
	var ez := ex.cross(ref).normalized()
	var ey := ez.cross(ex)
	var xf := Transform3D(Basis(ex * comp, ey, ez), (p0 + p1) * 0.5)
	xf.origin += _mapa.desloc
	var b := Vector2i(floori(xf.origin.x / bloco), floori(xf.origin.z / bloco))
	destino.get_or_add(b, []).append(xf)


# --------------------------------------------------------------------------
# varal de quintal
# --------------------------------------------------------------------------
func _varais(pecas: Array, panos: Dictionary, cordas: Dictionary, mouroes: Dictionary) -> int:
	if pecas.is_empty():
		return 0
	var n := 0
	var tentativas := int(varais_tentativas * densidade)
	for t in tentativas:
		var casa: Dictionary = _mapa.casas[_rng.randi_range(0, _mapa.casas.size() - 1)]
		var ang := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(maxf(float(casa["w"]), float(casa["d"])) * 0.6 + 1.6, 10.0)
		var meio := Vector3(float(casa["x"]) + cos(ang) * dist, 0.0,
			float(casa["z"]) + sin(ang) * dist)
		var vao := _rng.randf_range(varal_vao.x, varal_vao.y)
		var dir_ang := _rng.randf_range(0.0, TAU)
		var dir := Vector3(cos(dir_ang), 0.0, sin(dir_ang))
		var a := meio - dir * vao * 0.5
		var b := meio + dir * vao * 0.5

		# as duas pontas e o meio precisam de quintal: nem rua, nem dentro de casa
		var livre := true
		for p in [a, meio, b]:
			if _mapa.eh_rua(p) or _mapa.dentro_de_casa(p, 0.6):
				livre = false
				break
		if not livre or not _esp.livre(meio, vao * 0.5 + 0.6):
			continue
		# o mourão e' fincado no chao: as duas pontas precisam estar limpas
		if not _esp_props.livre(a, 0.1) or not _esp_props.livre(b, 0.1):
			continue

		var alt := _rng.randf_range(varal_altura.x, varal_altura.y)
		var ya: float = _mapa.chao(a.x, a.z, float(casa["y"]))
		var yb: float = _mapa.chao(b.x, b.z, float(casa["y"]))
		a.y = ya + alt
		b.y = yb + alt
		var queda := vao * varal_barriga

		_guardar_corda(cordas, a, b, queda)
		if varal_mouroes:
			_guardar_barra(mouroes, Vector3(a.x, ya, a.z), a + Vector3.UP * 0.06)
			_guardar_barra(mouroes, Vector3(b.x, yb, b.z), b + Vector3.UP * 0.06)
		# quantas pecas cabem no vao, respeitando o pedido
		var teto := maxi(1, int(vao / 0.72))
		var quantas := mini(teto, _rng.randi_range(varal_pecas.x, varal_pecas.y))
		_pendurar(pecas, a, b, queda, quantas, panos, 1.0)
		_esp.ocupar(meio, vao * 0.5 + 0.6)
		n += 1
	return n


# --------------------------------------------------------------------------
# bandeirinha atravessando a rua
# --------------------------------------------------------------------------
func _bandeiras(pecas: Array, panos: Dictionary, cordas: Dictionary) -> int:
	"""Corda de festa entre dois postes de calcadas OPOSTAS.

	A prova de que sao calcadas opostas e' o meio do vao estar em cima do
	asfalto. Dois postes seguidos da mesma calcada reprovam nesse teste, e e'
	so' por causa dele que a corda nunca atravessa uma casa."""
	if pecas.is_empty() or _mapa.postes.size() < 2:
		return 0
	var n := 0
	var usados := {}
	var tentativas := int(bandeiras_tentativas * densidade)
	for t in tentativas:
		var ia := _rng.randi_range(0, _mapa.postes.size() - 1)
		if usados.has(ia):
			continue
		var pa: Dictionary = _mapa.postes[ia]
		var melhor := -1
		var melhor_d := 1e9
		for ib in _mapa.postes.size():
			if ib == ia or usados.has(ib):
				continue
			var pb: Dictionary = _mapa.postes[ib]
			var d := Vector2(float(pb["x"]) - float(pa["x"]), float(pb["z"]) - float(pa["z"])).length()
			if d < bandeira_vao.x or d > bandeira_vao.y or d >= melhor_d:
				continue
			# o meio do vao tem que cair no asfalto
			var m := Vector3((float(pa["x"]) + float(pb["x"])) * 0.5, 0.0,
				(float(pa["z"]) + float(pb["z"])) * 0.5)
			if not _mapa.eh_rua(m):
				continue
			melhor = ib
			melhor_d = d
		if melhor < 0:
			continue

		var pb2: Dictionary = _mapa.postes[melhor]
		var alt := _rng.randf_range(bandeira_altura.x, bandeira_altura.y)
		var chao_a: float = _mapa.chao(float(pa["x"]), float(pa["z"]),
			float(pa["y"]) - CityMapa.ALTURA_LUMINARIA)
		var chao_b: float = _mapa.chao(float(pb2["x"]), float(pb2["z"]),
			float(pb2["y"]) - CityMapa.ALTURA_LUMINARIA)
		var a := Vector3(float(pa["x"]), chao_a + alt, float(pa["z"]))
		var b := Vector3(float(pb2["x"]), chao_b + alt, float(pb2["z"]))
		var queda := melhor_d * bandeira_barriga

		_guardar_corda(cordas, a, b, queda)
		var quantas := maxi(3, int(melhor_d / bandeira_passo))
		# papel de seda e' leve: balanca bem mais que pano molhado
		_pendurar(pecas, a, b, queda, quantas, panos, 1.9)
		usados[ia] = true
		usados[melhor] = true
		n += 1
	return n


# --------------------------------------------------------------------------
# saida
# --------------------------------------------------------------------------
func _emitir_panos(panos: Dictionary) -> int:
	if panos.is_empty():
		return 0
	# o quad e' subdividido no vertical: com so' duas linhas de vertice o
	# shader nao tem como curvar o pano, e o balanco vira uma placa inclinada
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Z
	quad.subdivide_depth = 3

	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.set_shader_parameter("atlas", load(_atlas_caminho))
	mat.set_shader_parameter("ganho", ganho)
	mat.set_shader_parameter("balanco", balanco)
	mat.set_shader_parameter("velocidade", velocidade_do_vento)

	var nos := 0
	for b in panos.keys():
		var lista: Array = panos[b]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# a ORDEM importa: mexer nestes dois flags redimensiona o buffer e zera
		# o que ja' foi escrito
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = lista.size()
		for i in lista.size():
			var it: Dictionary = lista[i]
			mm.set_instance_transform(i, it["xf"])
			mm.set_instance_color(i, it["cor"])
			mm.set_instance_custom_data(i, it["uv"])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "pano_%d_%d" % [b.x, b.y]
		mmi.multimesh = mm
		mmi.material_override = mat
		# a sombra sairia do quad PARADO, nao do balancado: o vertex() do
		# shader nao roda no passe de sombra do mesmo jeito, e roupa flutuando
		# com sombra imovel denuncia o truque
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mmi)
		mmi.owner = get_tree().edited_scene_root
		nos += 1
	return nos


func _emitir_barras(dados: Dictionary, nome: String, tamanho: Vector3, cor: Color) -> int:
	"""Corda e mourão: caixinha esticada, um MultiMesh por bloco. A malha tem
	1 m no X de proposito — a escala da instancia carrega o comprimento."""
	if dados.is_empty():
		return 0
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.95
	mat.metallic = 0.0
	var nos := 0
	for b in dados.keys():
		var lista: Array = dados[b]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = caixa
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [nome, b.x, b.y]
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		mmi.owner = get_tree().edited_scene_root
		nos += 1
	return nos
