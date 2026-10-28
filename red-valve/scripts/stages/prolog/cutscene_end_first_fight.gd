extends ParallaxCutscene

## Cutscene do fim da primeira luta, em 2.5D.
##
## Toda a apresentacao vem da cena base (res://scenes/cutscenes/parallax_cutscene_base.tscn)
## e do motor em ParallaxCutscene. Aqui so existem DADOS: quais camadas, em que
## profundidade, e como a camera se move em cada slide.
##
## CAMADAS
## Arquivos em res://assets/cutscenes/prolog/end_first_fight/ no padrao
## <prefixo>_<nome>.<ext>, por exemplo end_fight_1_background.jpeg. Uma camada de
## quadro inteiro (mesmo tamanho do fundo) fica alinhada automaticamente com as
## outras. Um recorte solto — um personagem menor, um objeto — declara
## `frame_size` (altura em fracao do quadro), `offset` e `roll`.
##
## PROFUNDIDADE
## `depth` e a distancia ate a camera. Menor = mais perto = mais paralaxe.
const FAR := 34.0
const MID := 16.0
const NEAR := 9.5

const DIR := "res://assets/cutscenes/prolog/end_first_fight/"

const HUSKE := Color(0.80, 0.78, 0.90)
const WARM := Color(1.0, 0.78, 0.45)
const RIFT := Color(1.0, 0.62, 0.24)


func _build_slides() -> Array:
	return [
		_slide_porao(),
		_slide_porta(),
		_slide_fenda(),
	]


# -----------------------------------------------------------------------------
# 1. O porao — o Huske arremessa Maycow e volta pela porta
# -----------------------------------------------------------------------------
func _slide_porao() -> Dictionary:
	return {
		"dir": DIR,
		"prefix": "end_fight_1",
		"fallback": DIR + "end_fight_1.png",
		"atmosphere": "poeira", "atmosphere_strength": 0.8,
		"flicker": 0.30,
		"aberration": 1.2,
		# Os chifres do Huske encostam no topo da arte: sobe o corte para nao decepar.
		"frame_offset": Vector2(0.0, -0.11),
		"layers": [
			{
				"name": "background", "depth": FAR, "cover": true,
				"blur": 0.45, "haze": 0.05, "haze_color": Color(0.26, 0.21, 0.18),
				"brightness": 1.06, "contrast": 1.04, "saturation": 1.0,
				"bob": 0.02, "flicker_gain": 0.25, "flicker_color": WARM,
				"enter_dur": 2.0,
			},
			{
				# Maycow e o Huske ja vem compostos na arte (ele a esquerda, o Huske
				# a direita), entao nenhum dos dois precisa de `offset`.
				# Ele leva o golpe, entao fica ATRAS: o braco do Huske passa por
				# cima dele. A ordem do array e o que define quem cobre quem.
				"name": "maycow", "depth": MID,
				"blur": 0.15, "haze": 0.04, "haze_color": Color(0.26, 0.21, 0.18),
				"brightness": 1.04, "contrast": 1.05,
				"rim": 0.24, "rim_color": WARM, "rim_width": 0.005,
				"rim_dir": Vector2(0.80, -0.60),
				"bob": 0.07, "sway": 0.16,
				"flicker_gain": 0.35, "flicker_color": WARM,
			},
			{
				# O Huske avanca NA DIRECAO da camera: e a camada mais proxima,
				# a que mais cresce no push, o que da o peso do golpe.
				"name": "inimigo", "depth": NEAR,
				"blur": 0.0, "haze": 0.0,
				"contrast": 1.05, "saturation": 1.02,
				"rim": 0.26, "rim_color": HUSKE, "rim_width": 0.005,
				"rim_dir": Vector2(-0.7, -0.7),
				"bob": 0.04, "sway": 0.08, "bottom_shade": 0.16,
				"flicker_gain": 0.20, "flicker_color": HUSKE,
			},
		],
		# Deriva para a esquerda, em direcao ao armario — a porta pela qual o Huske
		# some na ultima fala.
		"cam": {
			"from": {"pos": Vector3(0.15, -0.05, 0.0), "rot": Vector3(0.22, -0.30, -0.16), "fov": 45.0},
			"to":   {"pos": Vector3(-0.11, 0.07, -1.9), "rot": Vector3(-0.16, 0.26, 0.16), "fov": 43.5},
			"dur": 34.0,
		},
		"texts": [
			"END_FIGHT_1_1", "END_FIGHT_1_2", "END_FIGHT_1_3",
			"END_FIGHT_1_4", "END_FIGHT_1_5",
		],
	}


# -----------------------------------------------------------------------------
# 2. A porta — a oficina de um lado, Aurora City infernal do outro
# -----------------------------------------------------------------------------
func _slide_porta() -> Dictionary:
	return {
		"dir": DIR,
		"prefix": "end_fight_2",
		"fallback": DIR + "end_fight_2.png",
		"atmosphere": "fogo", "atmosphere_strength": 0.22,
		"flicker": 0.75,
		"aberration": 1.4,
		"frame_offset": Vector2(0.0, 0.02),
		"layers": [
			{
				"name": "background", "depth": FAR, "cover": true,
				"blur": 0.40, "haze": 0.05, "haze_color": Color(0.34, 0.16, 0.14),
				"brightness": 1.08, "contrast": 1.05, "saturation": 1.03,
				"bob": 0.02, "flicker_gain": 0.60, "flicker_color": Color(1.0, 0.45, 0.20),
				"enter_dur": 2.2,
			},
			{
				# O "inimigo" aqui e o proprio Maycow ja transformado, do lado de la
				# da porta. Fica mais fundo que o Maycow normal: a travessia se le
				# na diferenca de profundidade entre os dois.
				"name": "inimigo", "depth": 17.0,
				"frame_size": 0.72, "offset": Vector2(0.30, -0.04),
				"blur": 0.18, "haze": 0.05, "haze_color": Color(0.34, 0.16, 0.14),
				"contrast": 1.05,
				"rim": 0.34, "rim_color": Color(1.0, 0.50, 0.22), "rim_width": 0.006,
				"rim_dir": Vector2(-0.75, -0.66),
				"bob": 0.04, "sway": 0.07, "bottom_shade": 0.14,
				"flicker_gain": 0.70, "flicker_color": Color(1.0, 0.48, 0.20),
				"enter_delay": 0.6,
			},
			{
				"name": "maycow", "depth": 10.0,
				"frame_size": 0.66, "offset": Vector2(-0.31, -0.08),
				"blur": 0.0,
				"brightness": 1.05, "contrast": 1.04,
				"rim": 0.28, "rim_color": WARM, "rim_width": 0.005,
				"rim_dir": Vector2(0.80, -0.60),
				"bob": 0.05, "sway": 0.09, "bottom_shade": 0.18,
				"flicker_gain": 0.45, "flicker_color": WARM,
			},
		],
		# Acompanha a travessia: sai da oficina e entra na porta.
		"cam": {
			"from": {"pos": Vector3(-0.13, 0.03, 0.0), "rot": Vector3(0.10, 0.28, 0.12), "fov": 45.0},
			"to":   {"pos": Vector3(0.15, -0.04, -2.6), "rot": Vector3(-0.08, -0.26, -0.12), "fov": 43.0},
			"dur": 38.0,
		},
		"texts": [
			"END_FIGHT_2_1", "END_FIGHT_2_2", "END_FIGHT_2_3", "END_FIGHT_2_4",
			"END_FIGHT_2_5", "END_FIGHT_2_6", "END_FIGHT_2_7",
		],
	}


# -----------------------------------------------------------------------------
# 3. A fenda — o amuleto acende e os dois sao arrancados dali
# -----------------------------------------------------------------------------
func _slide_fenda() -> Dictionary:
	return {
		"dir": DIR,
		"prefix": "end_fight_3",
		"fallback": DIR + "end_fight_3.png",
		"atmosphere": "fogo", "atmosphere_strength": 0.40,
		# O fundo inteiro e energia em movimento: e o slide que mais pulsa.
		"flicker": 1.30,
		"aberration": 1.5,
		"frame_offset": Vector2(0.0, 0.04),
		"layers": [
			{
				"name": "background", "depth": FAR, "cover": true,
				"blur": 0.35, "haze": 0.04, "haze_color": Color(0.42, 0.18, 0.10),
				"brightness": 1.05, "contrast": 1.06, "saturation": 1.06,
				"bob": 0.03, "flicker_gain": 0.85, "flicker_color": RIFT,
				"enter_dur": 1.8,
			},
			{
				"name": "inimigo", "depth": 15.0,
				"frame_size": 0.88, "offset": Vector2(0.27, 0.02), "roll": 4.0,
				"blur": 0.22, "haze": 0.04, "haze_color": Color(0.42, 0.18, 0.10),
				"contrast": 1.05,
				"rim": 0.16, "rim_color": Color(0.85, 0.45, 1.0), "rim_width": 0.006,
				"rim_dir": Vector2(-0.72, -0.70),
				"bob": 0.06, "sway": 0.12, "bottom_shade": 0.12,
				"flicker_gain": 0.55, "flicker_color": Color(0.85, 0.45, 1.0),
			},
			{
				# Camada de quadro inteiro: ja vem posicionado a esquerda, com o
				# amuleto aceso. E o unico ponto quente estavel do quadro.
				"name": "maycow", "depth": NEAR,
				"blur": 0.0, "haze": 0.0,
				"brightness": 1.04, "contrast": 1.05,
				"rim": 0.16, "rim_color": RIFT, "rim_width": 0.005,
				"rim_dir": Vector2(0.55, -0.84),
				"bob": 0.05, "sway": 0.09,
				"flicker_gain": 1.10, "flicker_color": RIFT,
			},
		],
		# Empurrao mais forte de toda a cutscene: e o momento em que sao arrancados.
		"cam": {
			"from": {"pos": Vector3(0.11, 0.07, 0.0), "rot": Vector3(-0.20, -0.26, 0.14), "fov": 46.0},
			"to":   {"pos": Vector3(-0.09, -0.06, -2.4), "rot": Vector3(0.18, 0.24, -0.14), "fov": 42.5},
			"dur": 26.0,
		},
		"texts": [
			"END_FIGHT_3_1", "END_FIGHT_3_2", "END_FIGHT_3_3", "END_FIGHT_3_4",
		],
	}
