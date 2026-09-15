@tool
extends Node3D

## Etapa 09 — pichacao, cartaz e mancha.
##
## A cidade ja' tinha entulho de rua (etapa 08), mas parede limpa. Cidade
## pequena de interior com beco do esgoto nao tem parede limpa: tem pixacao de
## nome de faccao, tem cartaz rasgado colado no muro, tem escorrido de ferrugem
## debaixo da laje e tem mancha de oleo onde o carro fica parado. E' isso que
## esta etapa poe.
##
## CADA RABISCO E' UM QUAD DE DOIS TRIANGULOS colado na superficie, e todos
## dividem UM atlas de textura (`assets/images/textures/pichacao/`). Por isso o
## bloco inteiro cabe num MultiMesh so': o pedaco do atlas que cada instancia
## usa viaja no custom data, lido pelo `shaders/environment/pichacao.gdshader`.
## Sem o atlas, seriam 29 materiais x 25 blocos = 725 chamadas de desenho.
##
## As artes e os retangulos UV saem de `pichacao.json`, gerado por
## `tools/texturas/gerar_pichacao.py`. Nao editar o JSON a mao.
##
## Onde cada coisa pode nascer sai do `CityMapa` (mesmo mapa da etapa 08): as
## faces verticais do no `Walls`, as casas do `houses.json` e o asfalto
## rasterizado do no `Roads`. Por isso esta etapa mora na `stage_1`, e nao na
## `city.tscn`: e' la' que o Terrain3D existe, e o chao de verdade vem dele.
##
## O CARTAZ NAO VAI MAIS NO POSTE. A primeira versao colava um lambe-lambe em
## volta de cada poste, o que lia bem de perto e virava sujeira de longe — o
## poste e' fino e o cartaz aparecia flutuando de perfil. Agora ele vai em
## parede: a maior parte no muro da divisa e uma fracao na fachada da casa,
## sempre na altura do olho de quem cola.
##
## PEGADINHA DO GIRO DAS CASAS: o `rot` do houses.json gira o ponto por
## (x·cos − z·sin, x·sin + z·cos), que em Godot e' uma rotacao de −rot. Um
## adereço simetrico nao denuncia o sinal trocado; um quad denuncia — ele fica
## de perfil ou virado pra dentro da parede. Por isso aqui a normal da face e'
## calculada como vetor, e nao como angulo.

const CityMapa := preload("res://tools/godot/citybuild/city_mapa.gd")
const SHADER := "res://shaders/environment/pichacao.gdshader"
const MANIFESTO := "res://assets/images/textures/pichacao/pichacao.json"

@export_group("Entrada")
@export var houses_json: String = "res://assets/3d_model/city/houses.json"
@export var poles_json: String = "res://assets/3d_model/city/poles.json"
@export var no_ruas: NodePath = ^"../City/Roads"
## Muro da divisa, portao de chapa e cerca de tabua. E' aqui que o grosso da
## pichacao vai parar — a fachada da casa fica recuada atras dele.
@export var no_muros: NodePath = ^"../City/Walls"
## O no do terreno se chama "Terrenasso"; procurar por "Terrain3D" nao acha.
@export var no_terreno: NodePath = ^"../NavigationRegion3D/Terrenasso"
## Deslocamento da cidade no mundo: os JSONs estao em coordenadas locais dela.
@export var no_cidade: NodePath = ^"../City"

@export_group("Espalhamento")
## Trave a semente pro resultado ser sempre o mesmo.
@export var semente: int = 20260915
## Multiplicador geral de quantidade. 1.0 ≈ 900 rabiscos.
@export_range(0.0, 3.0, 0.05) var densidade: float = 1.0
## Lado do bloco espacial. Sem fatiar, a cidade inteira renderiza sempre.
@export var bloco: float = 128.0

@export_group("Parede")
## Quanto o quad descola da parede. Menos que isso briga com a fachada
## (z-fighting); mais que isso a pichacao flutua e a sombra denuncia.
@export var afastamento: float = 0.06
## Fatia das tentativas que exige rua na frente da parede. Pichacao vive de ser
## vista: parede de fundo de quintal quase nao recebe.
@export_range(0.0, 1.0, 0.05) var preferir_rua: float = 0.72
## A que distancia da parede se procura o asfalto pra decidir isso.
@export var alcance_da_rua: float = 5.0

@export_group("Chao")
## Quanto o quad sobe do chao.
@export var afastamento_chao: float = 0.03

@export_group("Aparencia")
## Piso de alfa do shader: abaixo disto o pixel e' vazio do atlas. NAO e' o
## desenho da borda — o shader mistura, nao recorta (ver o cabecalho dele).
@export_range(0.0, 0.5, 0.01) var corte: float = 0.02
## Multiplicador do albedo. A cidade roda com LUT sepia.
@export_range(0.0, 2.0, 0.05) var ganho: float = 0.95
## Faixa em que a pichacao some com a distancia.
@export var dist_some_inicio: float = 70.0
@export var dist_some_fim: float = 110.0

@export_multiline var last_result: String = ""

## Sem `ResourceSaver` de proposito: salvar recurso a recurso devolve o loop
## principal ao editor no meio da execucao deste mesmo script @tool, e o reload
## que ele dispara e' SIGSEGV na certa (a etapa 07 documenta o sintoma). Tudo
## aqui fica embutido na cena. A trava abaixo so' evita um segundo `construir`
## antes do primeiro terminar.
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


## Quantos candidatos cada papel tenta gerar, antes da densidade e das
## rejeicoes. O numero final sai bem abaixo disto.
const TENTATIVAS := {
	"muro": 1600, "muro_mancha": 520, "pichacao": 320, "alto": 320,
	"mancha_parede": 260, "cartaz_muro": 520, "cartaz_parede": 260,
	"mancha_chao": 700, "mancha_rua": 420,
}

## Normal local de cada face da caixa da casa, na ordem do `ponto_de_parede`.
const NORMAL_LOCAL := [
	Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0),
	Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0),
]

var _rng := RandomNumberGenerator.new()
var _mapa = null
## nome do atlas -> caminho res:// da textura, lido do manifesto
var _atlas_por_nome: Dictionary = {}
## Chave "indice_da_casa:lado" -> Array de [centro, meia_largura] ja' ocupados
## naquela face. Espacar pichacao por grade do mundo nao funciona: duas faces
## opostas da mesma casa caem na mesma celula e uma bloquearia a outra.
var _fitas: Dictionary = {}
var _esp_chao = null
var _esp_muro = null


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
	_fitas.clear()
	_esp_chao = CityMapa.Espacador.new(1.2)
	_esp_muro = CityMapa.Espacador.new(0.8)

	var artes := _ler_artes()
	if artes.is_empty():
		last_result = "ERRO: nenhuma arte em %s (rode tools/texturas/gerar_pichacao.py)" % MANIFESTO
		return

	_mapa = CityMapa.new()
	if not _mapa.preparar(self,
			get_node_or_null(no_ruas) as Node3D,
			get_node_or_null(no_terreno) as Node3D,
			get_node_or_null(no_cidade) as Node3D,
			houses_json, poles_json):
		last_result = "ERRO: " + _mapa.erro
		return
	_mapa.preparar_muros(get_node_or_null(no_muros) as Node3D,
		get_node_or_null(no_cidade) as Node3D, self)

	# papel -> lista de artes daquele papel, ja' pesada
	var por_papel := {}
	for a in artes:
		por_papel.get_or_add(a["papel"], []).append(a)

	# atlas -> bloco -> lista de {xf, uv, cor}
	var saida := {}
	var contagem := {}
	# o papel do JSON diz que DESENHO e', nao onde ele vai: "pichacao" serve
	# tanto pro muro quanto pra fachada, e quem decide isso e' o despacho aqui
	for papel in TENTATIVAS.keys():
		var arte_papel: String = papel
		match papel:
			"muro": arte_papel = "pichacao"
			"muro_mancha": arte_papel = "mancha_parede"
			"cartaz_muro", "cartaz_parede": arte_papel = "cartaz"
		var lista: Array = por_papel.get(arte_papel, [])
		if lista.is_empty():
			contagem[papel] = 0
			continue
		match papel:
			"muro", "cartaz_muro":
				contagem[papel] = _espalhar_muro(papel, lista, saida, false)
			"muro_mancha":
				contagem[papel] = _espalhar_muro(papel, lista, saida, true)
			"pichacao", "alto", "mancha_parede", "cartaz_parede":
				contagem[papel] = _espalhar_parede(papel, lista, saida)
			"mancha_chao":
				contagem[papel] = _espalhar_chao(lista, saida, false)
			"mancha_rua":
				contagem[papel] = _espalhar_chao(lista, saida, true)

	var nos := _emitir(saida)
	var total := 0
	for k in contagem.keys():
		total += int(contagem[k])

	last_result = ("%d rabiscos | muro %d (+%d mancha), fachada %d, alto %d, "
		+ "mancha de fachada %d, cartaz %d no muro + %d na fachada, chao %d, "
		+ "asfalto %d | %d MultiMesh | %s | %d ms") % [
		total, contagem.get("muro", 0), contagem.get("muro_mancha", 0),
		contagem.get("pichacao", 0), contagem.get("alto", 0),
		contagem.get("mancha_parede", 0), contagem.get("cartaz_muro", 0),
		contagem.get("cartaz_parede", 0),
		contagem.get("mancha_chao", 0), contagem.get("mancha_rua", 0),
		nos, _mapa.resumo(), Time.get_ticks_msec() - t0]
	print("CityPichacao: ", last_result)


# --------------------------------------------------------------------------
# manifesto
# --------------------------------------------------------------------------
func _ler_artes() -> Array:
	var txt := FileAccess.get_file_as_string(MANIFESTO)
	if txt.is_empty():
		push_error("CityPichacao: %s nao existe." % MANIFESTO)
		return []
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return []
	_atlas_por_nome = d.get("atlas", {})
	return d.get("artes", [])


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


## Largura sorteada e a altura que sai dela pela proporcao do recorte no atlas.
func _tamanho(arte: Dictionary) -> Vector2:
	var faixa: Array = arte["largura"]
	var larg := _rng.randf_range(float(faixa[0]), float(faixa[1]))
	var px: Array = arte["px"]
	return Vector2(larg, larg * float(px[1]) / float(px[0]))


## Tinta gasta: a cor multiplica o albedo e o alfa multiplica o alfa ANTES do
## corte — e' isso que faz o rabisco velho ficar esburacado, e nao so' claro.
func _desgaste() -> Color:
	var t := _rng.randf()
	var luz := _rng.randf_range(0.78, 1.08)
	var quente := _rng.randf_range(0.94, 1.06)
	return Color(luz * quente, luz, luz / quente, lerpf(1.0, 0.55, t * t))


func _guardar(saida: Dictionary, arte: Dictionary, xf: Transform3D) -> void:
	var atlas: String = arte["atlas"]
	var mundo := xf
	mundo.origin += _mapa.desloc
	var b := Vector2i(floori(mundo.origin.x / bloco), floori(mundo.origin.z / bloco))
	var por_bloco: Dictionary = saida.get_or_add(atlas, {})
	var uv: Array = arte["uv"]
	por_bloco.get_or_add(b, []).append({
		"xf": mundo,
		"uv": Color(float(uv[0]), float(uv[1]), float(uv[2]), float(uv[3])),
		"cor": _desgaste(),
	})


# --------------------------------------------------------------------------
# fita de ocupacao da face
# --------------------------------------------------------------------------
func _face_livre(idx: int, lado: int, centro: float, meia: float) -> bool:
	var k := "%d:%d" % [idx, lado]
	if not _fitas.has(k):
		return true
	for par in (_fitas[k] as Array):
		if absf(float(par[0]) - centro) < (float(par[1]) + meia):
			return false
	return true


func _face_ocupar(idx: int, lado: int, centro: float, meia: float) -> void:
	var k := "%d:%d" % [idx, lado]
	if not _fitas.has(k):
		_fitas[k] = []
	(_fitas[k] as Array).append([centro, meia])


# --------------------------------------------------------------------------
# geometria
# --------------------------------------------------------------------------
## Normal da face `lado` da casa, no espaco da cidade. Vetor, e nao angulo: o
## `rot` do JSON gira ao contrario do Godot (ver o cabecalho).
func _normal_da_face(casa: Dictionary, lado: int) -> Vector3:
	var nl: Vector3 = NORMAL_LOCAL[lado]
	var rot := float(casa["rot"])
	return Vector3(
		nl.x * cos(rot) - nl.z * sin(rot),
		0.0,
		nl.x * sin(rot) + nl.z * cos(rot)).normalized()


## Quad em pe', olhando pra `normal`, com `tam` metros de largura por altura.
func _xf_parede(centro: Vector3, normal: Vector3, tam: Vector2, giro_z: float) -> Transform3D:
	var ez := normal
	var ex := Vector3.UP.cross(ez).normalized()
	var ey := ez.cross(ex)
	if giro_z != 0.0:
		# cartaz colado torto, pichacao escrita subindo: gira no proprio plano
		var c := cos(giro_z)
		var s := sin(giro_z)
		var nx := ex * c + ey * s
		ey = ey * c - ex * s
		ex = nx
	return Transform3D(Basis(ex * tam.x, ey * tam.y, ez), centro)


## Quad deitado, olhando pra cima.
func _xf_chao(centro: Vector3, giro: float, tam: Vector2) -> Transform3D:
	var ez := Vector3.UP
	var ex := Vector3(cos(giro), 0.0, -sin(giro))
	var ey := ez.cross(ex)
	return Transform3D(Basis(ex * tam.x, ey * tam.y, ez), centro)


# --------------------------------------------------------------------------
# os papeis
# --------------------------------------------------------------------------
func _espalhar_parede(papel: String, lista: Array, saida: Dictionary) -> int:
	var n := 0
	var tentativas := int(TENTATIVAS[papel] * densidade)
	for t in tentativas:
		var idx := _rng.randi_range(0, _mapa.casas.size() - 1)
		var casa: Dictionary = _mapa.casas[idx]
		var h := float(casa["h"])
		if papel == "alto" and h < 4.5:
			continue

		var arte := _sortear(lista)
		var tam := _tamanho(arte)
		var lado := _rng.randi_range(0, 3)
		var larg_face: float = _mapa.largura_do_lado(casa, lado)
		if tam.x > larg_face - 0.6:
			continue   # nao cabe nessa face

		# posicao ao longo da face, em metros a partir do centro dela
		var alcance: float = (larg_face - tam.x) * 0.5 - 0.3
		if alcance <= 0.0:
			continue
		var centro_fita := _rng.randf_range(-alcance, alcance)
		var meia := tam.x * 0.5 + 0.25
		if not _face_livre(idx, lado, centro_fita, meia):
			continue

		var normal := _normal_da_face(casa, lado)
		var ponto: Dictionary = _mapa.ponto_de_parede(
			casa, lado, centro_fita / maxf(larg_face * 0.5, 0.01), afastamento)
		var p: Vector3 = ponto["p"]

		# pichacao vive de ser vista: na maioria das vezes exige rua na frente
		if papel != "mancha_parede" and _rng.randf() < preferir_rua:
			var frente := p + normal * alcance_da_rua
			if not _mapa.eh_rua(frente):
				continue
		# nunca em parede que da' de cara com a parede do vizinho
		if _mapa.dentro_de_casa(p + normal * 1.2, 0.0):
			continue
		# cartaz na fachada so' vale se o muro da divisa NAO estiver na frente:
		# colado a 1,5 m do chao atras de um muro de 2 m, ninguem na rua le'.
		# Sobram as casas de lote sem divisa, que e' onde o lambe-lambe de
		# fachada acontece de verdade.
		if papel == "cartaz_parede":
			var tapado := false
			for d in [1.5, 2.5, 3.5, 4.5]:
				if _mapa.ha_muro_em(p + normal * d):
					tapado = true
					break
			if tapado:
				continue

		var piso: float = _mapa.chao(p.x, p.z, float(casa["y"]))
		var y: float
		match papel:
			"alto":
				# o telhado morde 0,35 m e o muro esconde ate' ~2,4 m: a faixa
				# util de uma casa de 4,3 m (a mediana) e' menos de dois metros
				var topo: float = piso + h - 0.35
				var base: float = piso + maxf(2.4, h * 0.5)
				if topo - base < tam.y:
					continue
				y = _rng.randf_range(base + tam.y * 0.5, topo - tam.y * 0.5)
			"mancha_parede":
				# escorrido pendura a partir do topo: ancora o TOPO do quad
				var alto: float = piso + minf(h - 0.2, _rng.randf_range(1.8, maxf(2.0, h - 0.2)))
				y = alto - tam.y * 0.5
				if y - tam.y * 0.5 < piso - 0.3:
					continue
			"cartaz_parede":
				# lambe-lambe vai na altura do olho de quem cola, nao do teto
				var altura: float = piso + _rng.randf_range(1.15, 2.0)
				y = clampf(altura, piso + tam.y * 0.5 + 0.1, piso + h - tam.y * 0.5 - 0.2)
				if y < piso:
					continue
			_:
				var meio: float = piso + _rng.randf_range(0.9, 2.1)
				y = clampf(meio, piso + tam.y * 0.5 + 0.1, piso + h - tam.y * 0.5 - 0.2)
				if y < piso:
					continue

		p.y = y
		var torto := _rng.randf_range(-0.07, 0.07) if papel != "mancha_parede" else 0.0
		_guardar(saida, arte, _xf_parede(p, normal, tam, torto))
		_face_ocupar(idx, lado, centro_fita, meia)
		n += 1
	return n


func _espalhar_muro(papel: String, lista: Array, saida: Dictionary, eh_mancha: bool) -> int:
	"""Pichacao no muro da divisa — o caso principal.

	O ponto sai sorteado na superficie do muro, proporcional a area da face
	(ver `CityMapa.sortear_muro`). Duas conferencias depois disso:

	  1. as DUAS pontas do rabisco tem que cair sobre muro. Sem isso, um quad
	     de 2,5 m sorteado a 40 cm do fim do trecho fica com metade boiando no
	     vao do portao;
	  2. a face tem que ser alta o bastante pro desenho. Muro de 1,9 m nao
	     recebe bomba de 2,4 m de altura.

	O espacamento usa a posicao DESLOCADA meio metro pra fora ao longo da
	normal. A grade e' 2D, e o muro tem 20 cm de espessura: sem o deslocamento,
	um rabisco de um lado bloquearia o outro lado do mesmo muro."""
	if not _mapa.tem_muros():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS[papel] * densidade)
	for t in tentativas:
		var s: Dictionary = _mapa.sortear_muro(_rng)
		if s.is_empty():
			break
		var arte := _sortear(lista)
		var tam := _tamanho(arte)
		var p: Vector3 = s["p"]
		var normal: Vector3 = s["n"]
		var ymin: float = s["ymin"]
		var ymax: float = s["ymax"]
		if tam.y > (ymax - ymin) - 0.2:
			continue

		# as duas pontas precisam de muro embaixo
		var tangente := Vector3.UP.cross(normal).normalized()
		var meia := tam.x * 0.5
		if not _mapa.ha_muro_em(p + tangente * meia) or not _mapa.ha_muro_em(p - tangente * meia):
			continue

		var y: float
		if eh_mancha:
			y = ymax - 0.08 - tam.y * 0.5      # escorrido pendura do topo
		elif papel == "cartaz_muro":
			# lambe-lambe vai na altura do olho de quem cola; pichacao sobe o
			# quanto o braco alcanca, cartaz nao
			y = clampf(ymin + _rng.randf_range(1.05, 1.75),
				ymin + tam.y * 0.5 + 0.1, ymax - tam.y * 0.5 - 0.1)
		else:
			y = clampf(p.y, ymin + tam.y * 0.5 + 0.12, ymax - tam.y * 0.5 - 0.12)

		var centro := Vector3(p.x, y, p.z)
		if not _esp_muro.livre(centro + normal * 0.5, meia * 0.85):
			continue
		# pichacao vive de ser vista: o lado de fora do muro e' o que da' pra rua
		if not eh_mancha and _rng.randf() < preferir_rua:
			if not _mapa.eh_rua(centro + normal * 2.5) and not _mapa.eh_rua(centro + normal * 4.0):
				continue

		# cartaz colado a mao entorta bem mais que pichacao feita de braco solto
		var torto := 0.0
		if papel == "cartaz_muro":
			torto = _rng.randf_range(-0.13, 0.13)
		elif not eh_mancha:
			torto = _rng.randf_range(-0.05, 0.05)
		_guardar(saida, arte, _xf_parede(centro + normal * afastamento, normal, tam, torto))
		_esp_muro.ocupar(centro + normal * 0.5, meia * 0.85)
		n += 1
	return n


func _espalhar_chao(lista: Array, saida: Dictionary, no_asfalto: bool) -> int:
	var n := 0
	var chaves: Array = _mapa.celulas_de_rua()
	var tentativas := int(TENTATIVAS["mancha_rua" if no_asfalto else "mancha_chao"] * densidade)
	if no_asfalto and chaves.is_empty():
		return 0
	for t in tentativas:
		var arte := _sortear(lista)
		var tam := _tamanho(arte)
		var p: Vector3
		if no_asfalto:
			p = _mapa.ponto_da_celula(chaves[_rng.randi_range(0, chaves.size() - 1)])
			p.x += _rng.randf_range(-0.5, 0.5)
			p.z += _rng.randf_range(-0.5, 0.5)
		else:
			# ao redor de uma casa, fora dela e fora da rua: calcada e quintal
			var casa: Dictionary = _mapa.casas[_rng.randi_range(0, _mapa.casas.size() - 1)]
			var ang := _rng.randf_range(0.0, TAU)
			var dist := _rng.randf_range(
				maxf(float(casa["w"]), float(casa["d"])) * 0.6 + 1.0, 12.0)
			p = Vector3(float(casa["x"]) + cos(ang) * dist, 0.0,
				float(casa["z"]) + sin(ang) * dist)
			if _mapa.eh_rua(p) or _mapa.dentro_de_casa(p, 0.3):
				continue
			p.y = _mapa.chao(p.x, p.z, float(casa["y"]))

		var raio := maxf(tam.x, tam.y) * 0.45
		if not _esp_chao.livre(p, raio):
			continue
		p.y += afastamento_chao
		_guardar(saida, arte, _xf_chao(p, _rng.randf_range(0.0, TAU), tam))
		_esp_chao.ocupar(p, raio)
		n += 1
	return n


# --------------------------------------------------------------------------
# saida: um MultiMeshInstance3D por ATLAS por bloco
# --------------------------------------------------------------------------
func _emitir(saida: Dictionary) -> int:
	# quad unitario, virado pro +Z; o tamanho de verdade vem na escala da
	# instancia, senao cada largura de pichacao viraria uma malha diferente
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Z

	var nos := 0
	for atlas in saida.keys():
		var caminho: String = _atlas_por_nome.get(atlas, "")
		if caminho.is_empty() or not ResourceLoader.exists(caminho):
			push_error("CityPichacao: atlas '%s' nao encontrado (%s)" % [atlas, caminho])
			continue
		var mat := _material(caminho)
		for b in (saida[atlas] as Dictionary).keys():
			var lista: Array = saida[atlas][b]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			# a ORDEM importa: mexer nestes dois flags redimensiona o buffer e
			# zera o que ja' foi escrito
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
			mmi.name = "pichacao_%s_%d_%d" % [atlas, b.x, b.y]
			mmi.multimesh = mm
			mmi.material_override = mat
			# rabisco chapado na parede nao projeta sombra nenhuma
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(mmi)
			mmi.owner = get_tree().edited_scene_root
			nos += 1
	return nos


func _material(caminho_atlas: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.set_shader_parameter("atlas", load(caminho_atlas))
	mat.set_shader_parameter("corte", corte)
	mat.set_shader_parameter("ganho", ganho)
	mat.set_shader_parameter("dist_some_inicio", dist_some_inicio)
	mat.set_shader_parameter("dist_some_fim", dist_some_fim)
	return mat
