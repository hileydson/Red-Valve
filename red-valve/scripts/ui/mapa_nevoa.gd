class_name MapaNevoa
extends RefCounted
## O que o jogador já descobriu de uma planta, e a máscara que apaga o resto.
##
## O mapa dos interiores (escola, porão, hospital, igreja) começa APAGADO: a
## textura da planta está inteira lá, mas o shader só deixa passar o que esta
## máscara já marcou. Andar pelo prédio vai marcando.
##
## São dois jeitos de marcar, e quem escolhe é a lista `zonas` do JSON da
## planta — escrita pelos `make_mapa_*.py`, dos mesmos números que desenham o
## desenho:
##
##   "sala"    — entrou, acendeu INTEIRA. Num quarto de 11 x 10 m não há o que
##               descobrir em fatias: da porta já se vê o quarto todo.
##   "gradual" — acende um disco em volta do jogador, RECORTADO na zona. É o
##               corredor, o hall, o pátio, a nave da igreja: aparece o que ele
##               alcança com a vista, e o resto continua escuro.
##
## O recorte é o que segura a coisa de pé. Sem ele, um disco de 12 m andando
## pelo corredor acenderia meia sala dos dois lados ATRAVÉS da parede, e
## descobrir o prédio perderia a graça na primeira esquina.
##
## Zona em que o jogador NÃO pisa (o altar da igreja, o nicho do buraco da
## escola) traz um `gatilho`: um retângulo onde ele pisa e que acende a zona.
## Chegar ao pé da escada do coro é ter visto o altar.
##
## A máscara é um R8 pequeno — 256², uns 30 cm por pixel — esticado por cima da
## planta de 2048². Não precisa de mais: o shader interpola, e é a borda macia
## do disco que faz o mapa CLAREAR em vez de aparecer aos quadrados.
##
## Quem a guarda entre uma sessão e outra é o SaveManager, comprimida e em
## base64 (ver `para_save`).

## Fração do raio que acende no talo; daí até a borda o disco vai apagando.
## É essa faixa que dá o degradê da descoberta.
const MIOLO := 0.62
## Só vale redesenhar depois de o jogador andar isto. A 30 cm por pixel, menos
## que isso não muda pixel nenhum e só queima CPU.
const PASSO_M := 0.60
## De quanto um ponto conta como descoberto, na escala da máscara (0..255).
const LIMIAR := 90

## Máscaras abertas nesta sessão, por caminho do JSON da planta.
##
## Estática porque a máscara tem de sobreviver à troca de CENA: escola ->
## porão -> escola é o caminho normal da fase, e voltar com o mapa em branco
## seria pior do que não ter mapa. Quem esvazia é o SaveManager, ao carregar
## um save ou ao começar de novo — máscara é progresso, e progresso é do save.
static var _abertas: Dictionary = {}

## Caminho do JSON da planta. É a identidade da máscara: o hospital tem duas,
## uma por andar, porque são dois JSON.
var caminho: String = ""
## O que vai para o shader.
var tex: ImageTexture = null
## Há descoberta nova que ainda não foi para o arquivo de save?
var sujo: bool = false

var _n: int = 256
var _bytes: PackedByteArray = PackedByteArray()
var _zonas: Array = []
var _reveladas: Dictionary = {}
var _x0: float = 0.0
var _z0: float = 0.0
var _tam: float = 1.0
## Pixels da máscara por metro de mundo.
var _ppm: float = 1.0
## Raio de quem está FORA de qualquer zona: porta, soleira, cabine do
## elevador, túnel do porão. Pequeno, porque ali não há parede que recorte o
## disco e um raio grande vazaria para dentro de sala nunca vista.
var _raio_solto: float = 5.0
## Quanto cada carimbo transborda da zona, para a PAREDE acender junto com o
## cômodo. Sem isso a sala acesa fica boiando, com contorno preto em volta.
var _margem: float = 0.45
var _ultimo := Vector2(INF, INF)


## A máscara desta planta, ou null quando a planta não tem névoa (o mapa da
## cidade não tem: ele é o mapa de uma cidade em que o Maycow mora).
static func para(dados: MapaDados, caminho_json: String) -> MapaNevoa:
	if dados == null or not dados.ok or not dados.tem_nevoa():
		return null
	if _abertas.has(caminho_json):
		return _abertas[caminho_json]
	var nova := MapaNevoa.new()
	nova._montar(dados, caminho_json)
	_abertas[caminho_json] = nova
	return nova


func _montar(dados: MapaDados, caminho_json: String) -> void:
	caminho = caminho_json
	_x0 = dados.x0
	_z0 = dados.z0
	_tam = dados.tam
	_zonas = dados.zonas
	_n = maxi(32, int(dados.nevoa.get("resolucao", 256)))
	_raio_solto = float(dados.nevoa.get("raio_m", 5.0))
	_margem = float(dados.nevoa.get("margem_m", 0.45))
	_ppm = float(_n) / maxf(_tam, 0.001)
	_bytes.resize(_n * _n)
	_bytes.fill(0)
	_do_save(SaveManager.mapas_descobertos.get(caminho, {}))
	tex = ImageTexture.create_from_image(_imagem())


# ------------------------------------------------------------- descoberta
## O jogador está aqui: acenda o que ele está vendo.
##
## Chamado a cada quadro pelo minimapa; sai na hora enquanto ele não andou
## PASSO_M, que é o que torna barato chamar sempre.
func visitar(x: float, z: float) -> void:
	var aqui := Vector2(x, z)
	if aqui.distance_to(_ultimo) < PASSO_M:
		return
	_ultimo = aqui

	var mudou := false
	# A zona que recorta o disco é a MENOR das que contêm o jogador: a quadra
	# está dentro do pátio, e quem manda é a de dentro.
	var recorte: Dictionary = {}
	var menor := INF
	for zona in _zonas:
		var dentro := _na_caixa(zona, x, z)
		if dentro:
			var area := _area(zona)
			if area < menor:
				menor = area
				recorte = zona
		if String(zona.get("tipo", "")) != "sala":
			continue
		var ident := String(zona.get("id", ""))
		if _reveladas.has(ident):
			continue
		# `gatilho`: a zona acende de um lugar OUTRO, para o que não se pisa
		# poder ser descoberto de perto.
		if dentro or _na_caixa(zona.get("gatilho", {}), x, z):
			_reveladas[ident] = true
			_carimbar_caixa(zona)
			mudou = true

	var raio: float = float(recorte.get("raio_m", _raio_solto)) \
		if not recorte.is_empty() else _raio_solto
	if _carimbar_disco(x, z, raio, recorte):
		mudou = true
	if mudou:
		_aplicar()


## Este pedaço do mundo já foi descoberto?
func descoberto(x: float, z: float) -> bool:
	var i := int((x - _x0) * _ppm)
	var j := int((z - _z0) * _ppm)
	if i < 0 or j < 0 or i >= _n or j >= _n:
		return false
	return _bytes[j * _n + i] >= LIMIAR


## Este ponto de interesse deve aparecer agora?
##
## Junta as duas perguntas numa só: o item já foi pego (MapaDados) e o lugar
## já foi descoberto (aqui). Losango com o nome da sala escrito em cima de
## planta apagada entregaria justo o que a névoa existe para esconder.
func ponto_visivel(p: Dictionary) -> bool:
	if not MapaDados.ponto_visivel(p):
		return false
	return descoberto(float(p.get("x", 0.0)), float(p.get("z", 0.0)))


# ------------------------------------------------------------- carimbos
## A zona inteira, chapada. Transborda `_margem` para a parede acender junto.
func _carimbar_caixa(caixa: Dictionary) -> void:
	var i0 := maxi(0, _px(float(caixa.get("x0", 0.0)) - _margem - _x0, false))
	var i1 := mini(_n - 1, _px(float(caixa.get("x1", 0.0)) + _margem - _x0, true))
	var j0 := maxi(0, _px(float(caixa.get("z0", 0.0)) - _margem - _z0, false))
	var j1 := mini(_n - 1, _px(float(caixa.get("z1", 0.0)) + _margem - _z0, true))
	for j in range(j0, j1 + 1):
		var linha := j * _n
		for i in range(i0, i1 + 1):
			_bytes[linha + i] = 255


## O disco em volta do jogador, recortado na zona em que ele está.
##
## O valor cai do meio para a borda e nunca é rebaixado (fica o maior dos
## dois): o rastro de quem passou longe continua meio aceso, que é o que dá a
## leitura de "por aqui eu passei, mas não cheguei perto".
func _carimbar_disco(x: float, z: float, raio: float,
		recorte: Dictionary) -> bool:
	var r := raio * _ppm
	if r < 0.5:
		return false
	var cx := (x - _x0) * _ppm
	var cz := (z - _z0) * _ppm
	var i0 := maxi(0, floori(cx - r))
	var i1 := mini(_n - 1, ceili(cx + r))
	var j0 := maxi(0, floori(cz - r))
	var j1 := mini(_n - 1, ceili(cz + r))
	if not recorte.is_empty():
		i0 = maxi(i0, _px(float(recorte.get("x0", 0.0)) - _margem - _x0, false))
		i1 = mini(i1, _px(float(recorte.get("x1", 0.0)) + _margem - _x0, true))
		j0 = maxi(j0, _px(float(recorte.get("z0", 0.0)) - _margem - _z0, false))
		j1 = mini(j1, _px(float(recorte.get("z1", 0.0)) + _margem - _z0, true))

	var rampa := maxf(1.0 - MIOLO, 0.001)
	var mudou := false
	for j in range(j0, j1 + 1):
		var linha := j * _n
		var dz := (float(j) + 0.5) - cz
		for i in range(i0, i1 + 1):
			var dx := (float(i) + 0.5) - cx
			var d := sqrt(dx * dx + dz * dz) / r
			if d >= 1.0:
				continue
			var v := int(255.0 * clampf((1.0 - d) / rampa, 0.0, 1.0))
			if _bytes[linha + i] < v:
				_bytes[linha + i] = v
				mudou = true
	return mudou


func _aplicar() -> void:
	tex.update(_imagem())
	sujo = true


func _imagem() -> Image:
	return Image.create_from_data(_n, _n, false, Image.FORMAT_R8, _bytes)


## Metro de mundo -> pixel da máscara. `alto` arredonda para fora, para o
## carimbo nunca ficar um pixel menor que a zona que ele representa.
func _px(metros: float, alto: bool) -> int:
	var v := metros * _ppm
	return ceili(v) if alto else floori(v)


func _na_caixa(caixa: Dictionary, x: float, z: float) -> bool:
	if caixa.is_empty():
		return false
	return x >= float(caixa.get("x0", 0.0)) and x <= float(caixa.get("x1", 0.0)) \
		and z >= float(caixa.get("z0", 0.0)) and z <= float(caixa.get("z1", 0.0))


func _area(caixa: Dictionary) -> float:
	return absf(float(caixa.get("x1", 0.0)) - float(caixa.get("x0", 0.0))) \
		* absf(float(caixa.get("z1", 0.0)) - float(caixa.get("z0", 0.0)))


# ------------------------------------------------------------------ save
## A máscara como ela vai para o JSON do save.
##
## Comprimida antes do base64, e não crua: 65.536 bytes de um mapa quase todo
## em zero viram algumas centenas. Sem isso, três plantas descobertas
## engordariam o save em um quarto de mega de texto.
func para_save() -> Dictionary:
	return {
		"n": _n,
		"m": Marshalls.raw_to_base64(
			_bytes.compress(FileAccess.COMPRESSION_DEFLATE)),
		"z": _reveladas.keys(),
	}


func _do_save(guardado) -> void:
	if typeof(guardado) != TYPE_DICTIONARY:
		return
	# Resolução diferente = a planta foi regerada com outra máscara. Recomeçar
	# do zero é melhor do que esticar a antiga por cima de um desenho novo.
	if int(guardado.get("n", 0)) != _n:
		return
	var cru := Marshalls.base64_to_raw(String(guardado.get("m", "")))
	if cru.is_empty():
		return
	var b := cru.decompress(_n * _n, FileAccess.COMPRESSION_DEFLATE)
	if b.size() != _n * _n:
		push_warning("MapaNevoa: mascara corrompida em %s" % caminho)
		return
	_bytes = b
	for ident in guardado.get("z", []):
		_reveladas[String(ident)] = true


## Despeja no dicionário do save tudo o que está aberto, e marca como gravado.
static func recolher(destino: Dictionary) -> Dictionary:
	for c in _abertas:
		var n: MapaNevoa = _abertas[c]
		destino[c] = n.para_save()
		n.sujo = false
	return destino


## Há descoberta que ainda não foi para o arquivo?
static func ha_novidade() -> bool:
	for c in _abertas:
		if (_abertas[c] as MapaNevoa).sujo:
			return true
	return false


## Esquece tudo o que está na memória. Chamado ao carregar um save ou ao
## começar um jogo novo: sem isto, a escola descoberta no slot 1 apareceria
## descoberta no slot 2.
static func esquecer_tudo() -> void:
	_abertas.clear()
