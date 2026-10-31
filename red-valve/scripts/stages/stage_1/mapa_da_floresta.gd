extends RefCounted

## A PRANCHA DA FLORESTA do Capítulo 3 — a textura do minimapa e da aba MAPA
## enquanto o Maycow está dentro do contorno (`capitulo_3_cidade.gd`).
##
## Desenhada aqui, e não assada num .png como a da cidade: o contorno sai do
## `floresta_local` e do `cemiterio_local`, e quem mexer nesses dois Marker3D
## na stage_1 tem o mapa acompanhando sem regerar nada. O recorte (x0, z0,
## tamanho) é o do `florestamap.json` e tem de cobrir os dois pontos com folga.
##
## O que aparece: a mata fechada em volta (quase preta, como a borda leste do
## mapa da cidade), o chão por onde dá pra andar em terra clara, e as copas das
## árvores — as de dentro mais vivas, que são as que ele contorna.

const JSON_DA_FLORESTA := "res://assets/3d_model/city/florestamap.json"
const LADO := 512

const COR_MATA := Color8(16, 20, 17)
const COR_COPA_FORA := Color8(26, 34, 27)
const COR_CHAO := Color8(74, 70, 54)
const COR_CHAO_ESCURO := Color8(58, 56, 44)
const COR_BEIRA := Color8(36, 44, 34)
const COR_COPA := Color8(34, 58, 38)
const COR_COPA_MIOLO := Color8(48, 78, 50)
## Raio da copa no mapa, em metros, na escala 1 da árvore.
const RAIO_COPA := 2.2


## `arvores`: [x, y, z, escala] de mundo (as do scatter e as da beira).
static func montar(contorno: PackedVector2Array, arvores: Array) -> ImageTexture:
	var dados := MapaDados.new(JSON_DA_FLORESTA)
	if not dados.ok:
		return null
	var m_por_px := dados.tam / float(LADO)
	var img := Image.create(LADO, LADO, false, Image.FORMAT_RGB8)
	img.fill(COR_MATA)
	# o contorno em pixels
	var poli := PackedVector2Array()
	for v in contorno:
		poli.append(dados.uv(v.x, v.y) * float(LADO))
	# o chão de dentro, linha a linha (varredura: os cruzamentos de cada linha
	# com as arestas dão os trechos de dentro), com manchas de terra
	var ruido := FastNoiseLite.new()
	ruido.seed = 3313
	ruido.frequency = 0.035
	var n := poli.size()
	for y in LADO:
		var cy := float(y) + 0.5
		var cortes: Array = []
		for i in n:
			var a: Vector2 = poli[i]
			var b: Vector2 = poli[(i + 1) % n]
			if (a.y <= cy) != (b.y <= cy):
				cortes.append(a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x))
		cortes.sort()
		for k in range(0, cortes.size() - 1, 2):
			var x0 := clampi(int(round(cortes[k])), 0, LADO)
			var x1 := clampi(int(round(cortes[k + 1])), 0, LADO)
			for x in range(x0, x1):
				var t := clampf(ruido.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, COR_CHAO_ESCURO.lerp(COR_CHAO, t))
	# a beira: o chão escurece colado no muro
	for i in n:
		var a: Vector2 = poli[i]
		var b: Vector2 = poli[(i + 1) % n]
		var passos := int(a.distance_to(b))
		for k in passos + 1:
			_disco(img, a.lerp(b, float(k) / float(maxi(passos, 1))), 2.2, COR_BEIRA)
	# as copas: as de fora quase somem na mata, as de dentro têm miolo
	for arv in arvores:
		var p := dados.uv(float(arv[0]), float(arv[2])) * float(LADO)
		var r := RAIO_COPA * float(arv[3]) / m_por_px
		if Geometry2D.is_point_in_polygon(p, poli):
			_disco(img, p, r, COR_COPA)
			_disco(img, p + Vector2(-0.3, -0.3) * r, r * 0.5, COR_COPA_MIOLO)
		else:
			_disco(img, p, r, COR_COPA_FORA)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _disco(img: Image, c: Vector2, r: float, cor: Color) -> void:
	var x0 := maxi(0, int(c.x - r))
	var x1 := mini(LADO - 1, int(c.x + r) + 1)
	var y0 := maxi(0, int(c.y - r))
	var y1 := mini(LADO - 1, int(c.y + r) + 1)
	var r2 := r * r
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if (float(x) + 0.5 - c.x) * (float(x) + 0.5 - c.x) + (float(y) + 0.5 - c.y) * (float(y) + 0.5 - c.y) <= r2:
				img.set_pixel(x, y, cor)
