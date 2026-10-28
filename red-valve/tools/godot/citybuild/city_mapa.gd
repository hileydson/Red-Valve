extends RefCounted

## Onde e' chao, onde e' rua e onde e' casa — a base comum das etapas 09 a 11.
##
## A etapa 08 (`city_props_extra.gd`) descobriu essas tres coisas na marra e
## guardou o resultado dentro dela mesma. As etapas novas precisam exatamente do
## mesmo mapa, entao ele saiu de la' pra ca'. A etapa 08 NAO foi mexida de
## proposito: ela ja' esta' construida e aprovada na cena, e reescrever a parte
## que funciona so' pra economizar linha e' risco sem retorno.
##
## As tres fontes, e a pegadinha de cada uma:
##
##   * `houses.json` — 573 caixas de casa. O `y` de la' e' o PISO DA CASA, que
##     a mediana poe 0,93 m e no pior caso 3,8 m acima do terreno vizinho.
##     Nao serve de chao.
##   * `poles.json` — 296 postes. O `y` de la' e' a CABECA DA LUMINARIA, 8,4 m
##     acima do chao. Tambem nao serve de chao.
##   * o no `Roads` — o `city_roads.gltf` e' so' visual: nao tem colisao, entao
##     raycast nao acha rua nenhuma. A malha e' rasterizada aqui num grid de
##     1 m, mesma ideia do `scripts/npcs/shadow_roads.gd`.
##
## O chao de verdade sai do Terrain3D (`data.get_height`). O asfalto
## rasterizado e' o plano B, e o valor de reserva que o chamador passa e' o
## plano C. `chao()` nunca devolve NAN.
##
## Tudo aqui vive em coordenadas LOCAIS DA CIDADE, que e' o espaco dos JSONs.
## `desloc` guarda quanto somar pra chegar no mundo.

const CELULA_RUA := 1.0
const CELULA_CASA := 16.0
## Altura do braco do poste. O `poles.json/luzes[].y` e' a cabeca da luz;
## medido contra a poca de luz correspondente, a diferenca e' 8,26-8,50 m.
const ALTURA_LUMINARIA := 8.4

var casas: Array = []
var postes: Array = []
var desloc := Vector3.ZERO
var tris_ruas := 0
var sem_terreno := 0
var erro := ""

var _ruas: Dictionary = {}          # chave da celula -> altura do asfalto
var _grade_casas: Dictionary = {}   # celula de 16 m -> indices de casa
var _terreno: Node3D = null


## `origem` e' o no que esta' construindo (as posicoes saem relativas a ele).
func preparar(origem: Node3D, no_ruas: Node3D, no_terreno: Node3D, no_cidade: Node3D,
		houses_json: String, poles_json: String) -> bool:
	erro = ""
	sem_terreno = 0
	casas = _ler_json(houses_json).get("casas", [])
	postes = _ler_json(poles_json).get("luzes", [])
	if casas.is_empty():
		erro = "houses.json vazio (%s)" % houses_json
		return false
	_indexar_casas()
	_terreno = no_terreno
	desloc = no_cidade.global_position - origem.global_position if no_cidade != null else Vector3.ZERO
	if _terreno == null:
		push_warning("CityMapa: Terrain3D nao encontrado; o chao vira do asfalto mais proximo.")
	tris_ruas = _rasterizar_ruas(no_ruas, no_cidade, origem)
	return true


func resumo() -> String:
	return ("%d casas, %d postes, %d celulas de rua (%d tri), %d faces de muro "
		+ "(%.0f m2), %d sem terreno | %s") % [
		casas.size(), postes.size(), _ruas.size(), tris_ruas,
		_faces_muro.size(), _area_muro, sem_terreno, _calibrar()]


# --------------------------------------------------------------------------
# entrada
# --------------------------------------------------------------------------
func _ler_json(caminho: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(caminho)
	if txt.is_empty():
		return {}
	var d = JSON.parse_string(txt)
	return d if typeof(d) == TYPE_DICTIONARY else {}


# --------------------------------------------------------------------------
# ruas
# --------------------------------------------------------------------------
func _rasterizar_ruas(raiz: Node3D, base: Node3D, origem: Node3D) -> int:
	_ruas.clear()
	if raiz == null:
		push_warning("CityMapa: no de ruas ausente; nada sera' rejeitado por asfalto.")
		return 0
	var total := 0
	var inv := (base.global_transform.affine_inverse() if base != null
		else origem.global_transform.affine_inverse())
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		for c in n.get_children():
			pilha.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := inv * mi.global_transform
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
		return  # triangulo gigante de fundo
	var y := maxf(a.y, maxf(b.y, c.y))
	for ix in range(x0, x1 + 1):
		for iz in range(z0, z1 + 1):
			var k := chave(ix, iz)
			if not _ruas.has(k) or float(_ruas[k]) < y:
				_ruas[k] = y


func chave(ix: int, iz: int) -> int:
	return (ix << 32) | (iz & 0xFFFFFFFF)


func eh_rua(p: Vector3) -> bool:
	if _ruas.is_empty():
		return false
	return _ruas.has(chave(floori(p.x / CELULA_RUA), floori(p.z / CELULA_RUA)))


func altura_rua(p: Vector3) -> float:
	var k := chave(floori(p.x / CELULA_RUA), floori(p.z / CELULA_RUA))
	return float(_ruas[k]) if _ruas.has(k) else NAN


func celulas_de_rua() -> Array:
	return _ruas.keys()


# --------------------------------------------------------------------------
# muros
# --------------------------------------------------------------------------
## Faces VERTICAIS do no `Walls`, que na cidade sao o muro da divisa, o portao
## de chapa e a cerca de tabua.
##
## E' nelas, e nao na fachada da casa, que a pichacao de rua realmente aparece:
## o muro tem 1,8-2,2 m e fica na calcada, enquanto a casa fica recuada ATRAS
## dele. Quem anda na rua ve' muro; a casa so' aparece do beiral pra cima.
##
## Aqui nao da' pra usar `houses.json`: muro nao esta' em JSON nenhum. Sai da
## malha mesmo — `city_walls.gltf`, 68 mil triangulos —, filtrando o que e'
## vertical. O filtro derruba de uma vez o patamar do lote (horizontal) e a
## "saia" de aterro (vertical, mas com menos de um metro de altura).
##
## Cada face guarda area acumulada, pra sortear ponto proporcional ao tamanho:
## sortear face a face encheria de pichacao os pedacinhos de cerca e deixaria o
## muro de 7 m com um rabisco so'.
var _faces_muro: Array = []          # {a, b, c, n, ymin, ymax, acum}
var _area_muro := 0.0
var _grade_muro: Dictionary = {}     # celula de 1 m -> topo do muro ali

## Altura minima de face pra valer como muro. Abaixo disso e' saia de aterro,
## travessa de cerca ou meio-fio.
const MURO_ALTURA_MIN := 0.9
## Acima disto a face deitou demais pra receber pichacao.
const MURO_NORMAL_MAX_Y := 0.35


func preparar_muros(raiz: Node3D, base: Node3D, origem: Node3D) -> int:
	_faces_muro.clear()
	_grade_muro.clear()
	_area_muro = 0.0
	if raiz == null:
		push_warning("CityMapa: no de muros ausente; nada de pichacao em muro.")
		return 0
	var inv := (base.global_transform.affine_inverse() if base != null
		else origem.global_transform.affine_inverse())
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		for c in n.get_children():
			pilha.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := inv * mi.global_transform
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
			# a normal vem da MALHA, e nao de um produto vetorial dos vertices:
			# o Godot desenha a face da frente com winding HORARIO, entao
			# (b-a)x(c-a) devolve a normal ao contrario. Com o sinal trocado, o
			# rabisco nasce 6 cm DENTRO do muro e some atras dele — sem erro
			# nenhum em log, porque nao e' erro, e' oclusao.
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var girar := xf.basis
			if idx.is_empty():
				for i in range(0, mundo.size() - 2, 3):
					_talvez_muro(mundo[i], mundo[i + 1], mundo[i + 2],
						_normal_media(nrm, girar, i, i + 1, i + 2))
			else:
				for i in range(0, idx.size() - 2, 3):
					_talvez_muro(mundo[idx[i]], mundo[idx[i + 1]], mundo[idx[i + 2]],
						_normal_media(nrm, girar, idx[i], idx[i + 1], idx[i + 2]))
	return _faces_muro.size()


## Media das normais dos tres vertices, ja' no espaco da cidade. Se a malha nao
## tiver normais, cai no produto vetorial COM O SINAL INVERTIDO — ver acima.
func _normal_media(nrm: PackedVector3Array, girar: Basis, i0: int, i1: int, i2: int) -> Vector3:
	if nrm.size() > i2:
		return (girar * (nrm[i0] + nrm[i1] + nrm[i2])).normalized()
	return Vector3.ZERO


func _talvez_muro(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var cruz := (b - a).cross(c - a)
	var area := cruz.length() * 0.5
	if area < 0.05:
		return
	# winding horario: sem normal na malha, o produto vetorial vem ao contrario
	var nrm := normal if normal.length_squared() > 0.25 else -cruz / (area * 2.0)
	if absf(nrm.y) > MURO_NORMAL_MAX_Y:
		return
	var ymin := minf(a.y, minf(b.y, c.y))
	var ymax := maxf(a.y, maxf(b.y, c.y))
	if ymax - ymin < MURO_ALTURA_MIN:
		return
	_area_muro += area
	_faces_muro.append({
		"a": a, "b": b, "c": c,
		"n": Vector3(nrm.x, 0.0, nrm.z).normalized(),
		"ymin": ymin, "ymax": ymax, "acum": _area_muro,
	})
	# pegada no grid, pra dar pra conferir se o rabisco inteiro cai em cima de
	# muro ou se uma das pontas ficou boiando no vao do portao
	var x0 := floori(minf(a.x, minf(b.x, c.x)) / CELULA_RUA)
	var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / CELULA_RUA)
	var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELULA_RUA)
	var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELULA_RUA)
	for ix in range(x0, x1 + 1):
		for iz in range(z0, z1 + 1):
			var k := chave(ix, iz)
			if not _grade_muro.has(k) or float(_grade_muro[k]) < ymax:
				_grade_muro[k] = ymax


func tem_muros() -> bool:
	return not _faces_muro.is_empty()


func ha_muro_em(p: Vector3) -> bool:
	return _grade_muro.has(chave(floori(p.x / CELULA_RUA), floori(p.z / CELULA_RUA)))


## Sorteia um ponto na superficie do muro, proporcional a area da face.
## Devolve {"p", "n", "ymin", "ymax"} ou {} se nao houver muro.
func sortear_muro(rng: RandomNumberGenerator) -> Dictionary:
	if _faces_muro.is_empty():
		return {}
	var alvo := rng.randf() * _area_muro
	# busca binaria na area acumulada
	var lo := 0
	var hi := _faces_muro.size() - 1
	while lo < hi:
		var meio := (lo + hi) / 2
		if float(_faces_muro[meio]["acum"]) < alvo:
			lo = meio + 1
		else:
			hi = meio
	var f: Dictionary = _faces_muro[lo]
	# ponto uniforme no triangulo (a raiz espelha o quadrado pra dentro dele)
	var u := sqrt(rng.randf())
	var v := rng.randf()
	var a: Vector3 = f["a"]
	var p: Vector3 = a + (f["b"] - a) * (u * (1.0 - v)) + (f["c"] - a) * (u * v)
	return {"p": p, "n": f["n"], "ymin": f["ymin"], "ymax": f["ymax"]}


## Ponto no centro da celula de asfalto `k`, ja' com a altura do asfalto.
func ponto_da_celula(k: int) -> Vector3:
	var ix := int(k >> 32)
	var iz := int(k & 0xFFFFFFFF)
	if iz > 0x7FFFFFFF:
		iz -= 0x100000000
	return Vector3((ix + 0.5) * CELULA_RUA, float(_ruas[k]), (iz + 0.5) * CELULA_RUA)


func _altura_rua_perto(p: Vector3, raio_max: float) -> float:
	var ix := floori(p.x / CELULA_RUA)
	var iz := floori(p.z / CELULA_RUA)
	var passos := int(raio_max / CELULA_RUA)
	for r in range(0, passos + 1):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if r > 0 and absi(dx) != r and absi(dz) != r:
					continue   # so' a casca do anel
				var k := chave(ix + dx, iz + dz)
				if _ruas.has(k):
					return float(_ruas[k])
	return NAN


# --------------------------------------------------------------------------
# chao
# --------------------------------------------------------------------------
func chao(x: float, z: float, reserva: float) -> float:
	if _terreno != null:
		var dados = _terreno.get("data")
		if dados != null:
			var y: float = dados.get_height(Vector3(x, 0.0, z) + desloc)
			if not is_nan(y):
				return y
	sem_terreno += 1
	var yr := _altura_rua_perto(Vector3(x, 0.0, z), 14.0)
	return yr if not is_nan(yr) else reserva


## Confere o get_height() contra o asfalto rasterizado nas mesmas celulas. Se a
## mediana nao for ~0, o terreno esta' em outro referencial — melhor saber
## disso do que enterrar mil adereços.
func _calibrar() -> String:
	if _terreno == null or _ruas.is_empty():
		return "sem terreno"
	var dados = _terreno.get("data")
	if dados == null:
		return "terreno sem data"
	var difs: Array[float] = []
	var chaves := _ruas.keys()
	var passo := maxi(1, chaves.size() / 400)
	for i in range(0, chaves.size(), passo):
		var p := ponto_da_celula(chaves[i])
		var yt: float = dados.get_height(Vector3(p.x, 0.0, p.z) + desloc)
		if is_nan(yt):
			continue
		difs.append(yt - p.y)
	if difs.is_empty():
		return "get_height so' devolveu NAN"
	difs.sort()
	return "terreno-asfalto mediana %.2f m (n=%d)" % [difs[difs.size() / 2], difs.size()]


# --------------------------------------------------------------------------
# casas
# --------------------------------------------------------------------------
func _indexar_casas() -> void:
	_grade_casas.clear()
	for i in casas.size():
		var c: Dictionary = casas[i]
		# raio bruto: a diagonal da caixa cobre qualquer giro
		var r: float = maxf(float(c["w"]), float(c["d"]))
		var x0 := floori((float(c["x"]) - r) / CELULA_CASA)
		var x1 := floori((float(c["x"]) + r) / CELULA_CASA)
		var z0 := floori((float(c["z"]) - r) / CELULA_CASA)
		var z1 := floori((float(c["z"]) + r) / CELULA_CASA)
		for ix in range(x0, x1 + 1):
			for iz in range(z0, z1 + 1):
				var k := chave(ix, iz)
				if not _grade_casas.has(k):
					_grade_casas[k] = PackedInt32Array()
				var arr: PackedInt32Array = _grade_casas[k]
				arr.append(i)
				_grade_casas[k] = arr


func dentro_de_casa(p: Vector3, folga := 0.0) -> bool:
	var k := chave(floori(p.x / CELULA_CASA), floori(p.z / CELULA_CASA))
	if not _grade_casas.has(k):
		return false
	for i in (_grade_casas[k] as PackedInt32Array):
		var c: Dictionary = casas[i]
		var d := Vector2(p.x - float(c["x"]), p.z - float(c["z"]))
		var r := -float(c["rot"])
		var lx := d.x * cos(r) - d.y * sin(r)
		var lz := d.x * sin(r) + d.y * cos(r)
		if absf(lx) <= float(c["w"]) * 0.5 + folga and absf(lz) <= float(c["d"]) * 0.5 + folga:
			return true
	return false


## Ponto na PAREDE de uma casa, com a normal apontando pra fora.
##
## `lado` 0..3 escolhe a face; `ao_longo` -1..1 desliza nela; `fora` afasta da
## parede. Devolve {"p": Vector3 (com y = 0), "giro": float, "casa": Dictionary}.
## O y fica por conta do chamador, que sabe se o adereço assenta no chao ou
## pendura na altura.
func ponto_de_parede(casa: Dictionary, lado: int, ao_longo: float, fora: float) -> Dictionary:
	var w := float(casa["w"]) * 0.5
	var d := float(casa["d"]) * 0.5
	var lx: float
	var lz: float
	var normal: float
	match lado:
		0: lx = ao_longo * w; lz = d + fora; normal = 0.0
		1: lx = ao_longo * w; lz = -d - fora; normal = PI
		2: lx = w + fora; lz = ao_longo * d; normal = PI * 0.5
		_: lx = -w - fora; lz = ao_longo * d; normal = -PI * 0.5
	var rot := float(casa["rot"])
	return {
		"p": Vector3(
			float(casa["x"]) + lx * cos(rot) - lz * sin(rot),
			0.0,
			float(casa["z"]) + lx * sin(rot) + lz * cos(rot)),
		"giro": rot + normal,
		"casa": casa,
	}


## Largura util da face `lado` (0 e 1 sao as faces de largura w; 2 e 3, de d).
func largura_do_lado(casa: Dictionary, lado: int) -> float:
	return float(casa["w"]) if lado < 2 else float(casa["d"])


# --------------------------------------------------------------------------
# espacamento — grade unica pra todo mundo, senao dois adereços de raio
# diferente caem em grades diferentes e nunca se enxergam
# --------------------------------------------------------------------------
class Espacador extends RefCounted:
	var passo: float
	var _ocupado: Dictionary = {}

	func _init(p: float) -> void:
		passo = p

	func _celulas(pos: Vector3, raio: float) -> Array:
		var ix := floori(pos.x / passo)
		var iz := floori(pos.z / passo)
		var r := ceili(maxf(raio, passo * 0.5) / passo)
		var out := []
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				out.append((ix + dx) << 32 | ((iz + dz) & 0xFFFFFFFF))
		return out

	func livre(pos: Vector3, raio: float) -> bool:
		for k in _celulas(pos, raio):
			if _ocupado.has(k):
				return false
		return true

	func ocupar(pos: Vector3, raio: float) -> void:
		for k in _celulas(pos, raio):
			_ocupado[k] = true

	func limpar() -> void:
		_ocupado.clear()
