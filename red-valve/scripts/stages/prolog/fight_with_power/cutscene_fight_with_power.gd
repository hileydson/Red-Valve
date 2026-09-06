extends ParallaxCutscene

## Cutscene "com poder" do prologo, em 2.5D.
##
## COMO ADICIONAR AS CAMADAS
## Salve os arquivos em res://assets/cutscenes/prolog/fight_with_power/ seguindo o
## padrao <prefixo>_<nome>.<ext>:
##     with_power_2_background.jpeg
##     with_power_2_maycow.png
##     with_power_2_cogblade.png
## Cada camada e uma imagem de quadro inteiro, no MESMO tamanho das outras, com
## fundo transparente. Enquanto um slide nao tiver camadas, ele cai
## automaticamente na imagem unica antiga (with_power_N.png) e continua rodando.
##
## Exporte em 16:9 (2560x1440, por exemplo). As camadas estao em 2496x1726
## (~1.45:1), entao sobra imagem demais fora do quadro e o corte vertical fica
## agressivo — `frame_offset` abaixo compensa, mas 16:9 resolve de vez.
##
## PROP RECORTADO
## cogblade e amuleto nao sao de quadro inteiro: sao objetos soltos, com resolucao
## propria. Esses declaram `frame_size` (altura do objeto em fracao da altura do
## quadro), `offset` (posicao) e `roll` (inclinacao). Sem `frame_size` a camada e
## tratada como quadro inteiro e alinhada com as demais.
##
## PROFUNDIDADE
## `depth` e a distancia da camada ate a camera, em unidades de mundo. Quanto MENOR,
## mais perto — e mais a camada se desloca e cresce quando a camera anda. E o unico
## numero que controla a forca da paralaxe de cada elemento.
##
## `frame_offset` desloca TODAS as camadas juntas (em fracao de quadro) para
## reposicionar o corte. Negativo em Y mostra mais o topo da arte.
const FAR := 34.0     # fundo
const MID := 16.0     # plano medio
const NEAR := 9.5     # primeiro plano

const DIR := "res://assets/cutscenes/prolog/fight_with_power/"

const FIRE := Color(1.0, 0.52, 0.20)
const PARASITE := Color(0.72, 0.32, 1.0)
const EMBER := Color(1.35, 0.50, 0.16)
const DUST := Color(0.55, 0.52, 0.48)


func _build_slides() -> Array:
	return [
		_slide_arena(),
		_slide_final_blow(),
		_slide_workshop(),
		_slide_notebook(),
	]


# -----------------------------------------------------------------------------
# 1. A arena — Maycow e o Huske, a foice se materializa
# -----------------------------------------------------------------------------
func _slide_arena() -> Dictionary:
	return {
		"dir": DIR,
		"prefix": "with_power_1",
		"fallback": DIR + "with_power_1.png",
		"flicker": 1.0,
		"aberration": 1.0,
		# A arte e mais alta que 16:9: sobe o corte para o chapeu de Maycow e os
		# chifres do Huske nao serem decepados.
		"frame_offset": Vector2(0.0, -0.10),
		"layers": [
			{
				"name": "background", "depth": FAR, "cover": true,
				"blur": 0.40, "haze": 0.04, "haze_color": Color(0.40, 0.12, 0.10),
				"brightness": 1.0, "contrast": 1.03, "saturation": 1.02,
				"bob": 0.02, "flicker_gain": 0.5, "flicker_color": FIRE,
				"enter_dur": 2.0,
			},
			{
				# Os dois recortes ocupam quase a mesma area na arte original, entao
				# um esconde o outro. `offset` (em fracao de quadro) abre o
				# enquadramento em over-the-shoulder: Maycow a esquerda e na frente,
				# o Huske a direita e mais ao fundo.
				"name": "inimigo", "depth": MID, "offset": Vector2(0.15, -0.01),
				"blur": 0.35, "haze": 0.05, "haze_color": Color(0.40, 0.12, 0.10),
				"contrast": 1.04, "saturation": 1.05,
				"rim": 0.25, "rim_color": PARASITE, "rim_width": 0.005,
				"rim_dir": Vector2(-0.7, -0.7),
				"bob": 0.04, "sway": 0.07, "bottom_shade": 0.18,
				"flicker_gain": 0.3, "flicker_color": PARASITE,
			},
			{
				"name": "maycow", "depth": NEAR, "offset": Vector2(-0.20, 0.02),
				"blur": 0.0, "haze": 0.0,
				"brightness": 1.06, "contrast": 1.05,
				"rim": 0.28, "rim_color": FIRE, "rim_width": 0.005,
				"rim_dir": Vector2(0.85, -0.5),
				"bob": 0.05, "sway": 0.09, "bottom_shade": 0.22,
				"flicker_gain": 0.6, "flicker_color": FIRE,
			},
		],
		# A bruma entra logo a frente do fundo: passa na frente da cidade e atras
		# dos dois personagens, que e exatamente onde a profundidade se le.
		"haze": [
			{"after": 0, "depth": 26.0, "tint": Color(0.95, 0.32, 0.14),
			 "intensity": 0.07, "scroll": Vector2(0.010, -0.005), "uv_scale": 2.2},
			{"after": 1, "depth": 13.0, "tint": Color(0.70, 0.24, 0.32),
			 "intensity": 0.04, "scroll": Vector2(-0.016, -0.008), "uv_scale": 3.0,
			 "size": 1.25},
		],
		"embers": [
			{"after": 0, "depth": 24.0, "amount": 45, "scale": 0.010,
			 "speed": 0.30, "lifetime": 11.0, "color": EMBER, "spread": 22.0},
			{"after": 1, "depth": 12.5, "amount": 20, "scale": 0.010,
			 "speed": 0.42, "lifetime": 8.0, "color": Color(1.1, 0.44, 0.16), "drift": 0.25},
			# Brasas de primeiro plano, desfocadas e rapidas. E o truque que mais
			# vende profundidade: elas cruzam por cima de tudo, inclusive de Maycow.
			# Poucas e discretas: em excesso viram sujeira de lente.
			{"after": 2, "depth": 7.5, "amount": 5, "scale": 0.012,
			 "speed": 0.75, "lifetime": 6.0, "color": Color(0.95, 0.42, 0.18),
			 "drift": 0.5, "spread": 35.0, "turbulence": 0.9},
		],
		"cam": {
			"from": {"pos": Vector3(0.16, -0.06, 0.0), "rot": Vector3(0.25, -0.35, -0.15), "fov": 45.0},
			"to":   {"pos": Vector3(-0.12, 0.06, -2.2), "rot": Vector3(-0.18, 0.28, 0.18), "fov": 43.5},
			"dur": 30.0,
		},
		"texts": ["WITH_POWER_1_1", "WITH_POWER_1_2", "WITH_POWER_1_3", "WITH_POWER_1_4"],
	}


# -----------------------------------------------------------------------------
# 2. O golpe final — a cogblade na frente, camera mais agressiva
# -----------------------------------------------------------------------------
func _slide_final_blow() -> Dictionary:
	return {
		"dir": DIR,
		"prefix": "with_power_2",
		"fallback": DIR + "with_power_2.png",
		"flicker": 1.2,
		"aberration": 1.6,
		"frame_offset": Vector2(0.04, 0.0),
		"layers": [
			{
				"name": "background", "depth": FAR, "cover": true,
				"blur": 0.30, "haze": 0.04, "haze_color": Color(0.34, 0.11, 0.09),
				"brightness": 1.03, "contrast": 1.05, "saturation": 1.02,
				"bob": 0.02, "flicker_gain": 0.8, "flicker_color": FIRE,
				"enter_dur": 1.8,
			},
			{
				# Maycow caido atravessa o quadro inteiro: fica no plano medio, com
				# o chao correndo atras dele.
				"name": "maycow", "depth": 14.0,
				"blur": 0.10, "haze": 0.03, "haze_color": Color(0.34, 0.11, 0.09),
				"brightness": 1.04, "contrast": 1.05,
				"rim": 0.10, "rim_color": FIRE, "rim_width": 0.005,
				"rim_dir": Vector2(0.55, -0.83),
				"bob": 0.03, "sway": 0.05, "bottom_shade": 0.12,
				"flicker_gain": 0.8, "flicker_color": FIRE,
			},
			{
				# A cogblade caida no chao, em primeiro plano. Prop recortado.
				"name": "cogblade", "depth": 8.0,
				"frame_size": 0.38, "offset": Vector2(0.33, 0.30), "roll": -14.0,
				"blur": 0.15,
				"brightness": 1.05, "contrast": 1.06, "saturation": 1.05,
				"rim": 0.18, "rim_color": Color(1.0, 0.66, 0.26), "rim_width": 0.008,
				"rim_dir": Vector2(-0.5, -0.86),
				"bob": 0.02, "sway": 0.35,
				"flicker_gain": 1.1, "flicker_color": Color(1.0, 0.62, 0.24),
				"enter_delay": 0.5,
			},
		],
		"haze": [
			{"after": 0, "depth": 25.0, "tint": Color(1.0, 0.36, 0.14),
			 "intensity": 0.06, "scroll": Vector2(0.014, -0.007), "uv_scale": 2.0},
			{"after": 1, "depth": 11.0, "tint": Color(0.85, 0.36, 0.20),
			 "intensity": 0.03, "scroll": Vector2(-0.020, -0.010), "uv_scale": 3.2,
			 "size": 1.3},
		],
		"embers": [
			{"after": 0, "depth": 22.0, "amount": 60, "scale": 0.011,
			 "speed": 0.35, "lifetime": 10.0, "color": EMBER},
			{"after": 1, "depth": 10.0, "amount": 24, "scale": 0.012,
			 "speed": 0.55, "lifetime": 7.0, "color": Color(1.1, 0.44, 0.16), "drift": -0.3},
			{"after": 2, "depth": 6.5, "amount": 6, "scale": 0.014,
			 "speed": 0.8, "lifetime": 5.5, "color": Color(0.95, 0.42, 0.18),
			 "drift": 0.5, "spread": 40.0, "turbulence": 1.1},
		],
		# Descida pesada sobre o corpo caido.
		"cam": {
			"from": {"pos": Vector3(0.12, 0.16, 0.0), "rot": Vector3(-0.32, -0.16, 0.22), "fov": 46.0},
			"to":   {"pos": Vector3(-0.07, -0.06, -2.4), "rot": Vector3(0.26, 0.15, -0.18), "fov": 43.0},
			"dur": 24.0,
		},
		"texts": ["WITH_POWER_2_1", "WITH_POWER_2_2", "WITH_POWER_2_3"],
	}


# -----------------------------------------------------------------------------
# 3. A oficina destruida — respiro calmo, poeira no lugar das brasas
# -----------------------------------------------------------------------------
func _slide_workshop() -> Dictionary:
	return {
		"dir": DIR,
		"prefix": "with_power_3",
		"fallback": DIR + "with_power_3.png",
		"flicker": 0.45,
		"aberration": 0.8,
		"frame_offset": Vector2(0.0, 0.02),
		"layers": [
			{
				"name": "background", "depth": FAR, "cover": true,
				"blur": 0.20, "haze": 0.03, "haze_color": Color(0.30, 0.24, 0.20),
				"brightness": 1.14, "contrast": 1.05, "saturation": 1.0,
				"bob": 0.02, "flicker_gain": 0.35, "flicker_color": Color(1.0, 0.80, 0.50),
				"enter_dur": 2.4,
			},
			{
				# Maycow sentado ocupa a esquerda; sobra a direita para o amuleto.
				"name": "maycow", "depth": MID, "offset": Vector2(-0.06, 0.0),
				"blur": 0.15, "haze": 0.04, "haze_color": Color(0.30, 0.24, 0.20),
				"brightness": 1.10, "saturation": 0.98,
				"rim": 0.08, "rim_color": Color(1.0, 0.82, 0.55), "rim_width": 0.005,
				"rim_dir": Vector2(0.86, -0.5),
				"bob": 0.04, "sway": 0.06, "bottom_shade": 0.14,
				"flicker_gain": 0.35, "flicker_color": Color(1.0, 0.80, 0.50),
			},
			{
				# O amuleto entra como inserto em primeiro plano, do lado vazio do
				# quadro: e a hora em que a historia apresenta o artefato.
				"name": "amuleto", "depth": 7.0,
				"frame_size": 0.44, "offset": Vector2(0.30, 0.16), "roll": -6.0,
				"blur": 0.12, "haze": 0.05, "haze_color": Color(0.30, 0.24, 0.20),
				"brightness": 0.96, "contrast": 1.05, "saturation": 1.06,
				"rim": 0.12, "rim_color": Color(1.0, 0.74, 0.34), "rim_width": 0.007,
				"rim_dir": Vector2(-0.6, -0.8), "rim_directional": 0.65,
				"bob": 0.05, "sway": 0.9,
				"flicker_gain": 1.2, "flicker_color": Color(1.0, 0.70, 0.30),
				"enter_delay": 1.0, "enter_dur": 2.0,
			},
		],
		"haze": [
			{"after": 0, "depth": 24.0, "tint": Color(0.85, 0.66, 0.40),
			 "intensity": 0.05, "scroll": Vector2(0.006, -0.002), "uv_scale": 2.4},
			{"after": 1, "depth": 11.0, "tint": Color(0.70, 0.58, 0.42),
			 "intensity": 0.03, "scroll": Vector2(-0.009, -0.003), "uv_scale": 3.4,
			 "size": 1.25},
		],
		"embers": [
			{"after": 0, "depth": 20.0, "amount": 40, "scale": 0.008,
			 "speed": 0.12, "lifetime": 14.0, "color": Color(0.16, 0.15, 0.14), "spread": 45.0,
			 "lift": 0.10, "turbulence": 0.35},
			{"after": 2, "depth": 6.0, "amount": 6, "scale": 0.011,
			 "speed": 0.2, "lifetime": 10.0, "color": Color(0.20, 0.19, 0.17),
			 "spread": 50.0, "lift": 0.08, "turbulence": 0.5},
		],
		# Sobe devagar com ele acordando.
		"cam": {
			"from": {"pos": Vector3(-0.10, -0.12, 0.0), "rot": Vector3(0.26, 0.16, -0.12), "fov": 44.5},
			"to":   {"pos": Vector3(0.08, 0.11, -1.9), "rot": Vector3(-0.20, -0.14, 0.10), "fov": 43.0},
			"dur": 30.0,
		},
		"texts": ["WITH_POWER_3_1", "WITH_POWER_3_2", "WITH_POWER_3_3"],
	}


# -----------------------------------------------------------------------------
# 4. O caderno de Jimmy — camera descendo sobre a mesa
# -----------------------------------------------------------------------------
func _slide_notebook() -> Dictionary:
	return {
		"dir": DIR,
		"prefix": "with_power_4",
		"fallback": DIR + "with_power_4.png",
		"flicker": 0.6,
		"aberration": 0.9,
		"layers": [
			{
				# O quarto do Jimmy ja traz a mesa e o caderno em primeiro plano na
				# propria arte; a mesa e que ganha escala quando a camera desce.
				"name": "background", "depth": FAR, "cover": true,
				"blur": 0.18, "haze": 0.03, "haze_color": Color(0.32, 0.24, 0.18),
				"brightness": 1.16, "contrast": 1.05, "saturation": 1.0,
				"bob": 0.02, "flicker_gain": 0.55, "flicker_color": Color(1.0, 0.78, 0.42),
				"enter_dur": 2.2,
			},
			{
				"name": "maycow", "depth": 15.0, "pinhole_fill": 0.0,
				"blur": 0.10, "haze": 0.03, "haze_color": Color(0.32, 0.24, 0.18),
				"brightness": 1.05, "contrast": 1.05,
				"rim": 0.0, "rim_color": Color(1.0, 0.80, 0.48), "rim_width": 0.005,
				"rim_dir": Vector2(0.55, -0.84),
				"bob": 0.04, "sway": 0.05, "bottom_shade": 0.10,
				"flicker_gain": 0.7, "flicker_color": Color(1.0, 0.78, 0.42),
			},
		],
		"haze": [
			{"after": 0, "depth": 24.0, "tint": Color(0.90, 0.62, 0.30),
			 "intensity": 0.05, "scroll": Vector2(0.007, -0.003), "uv_scale": 2.2},
			{"after": 1, "depth": 10.0, "tint": Color(0.75, 0.55, 0.32),
			 "intensity": 0.025, "scroll": Vector2(-0.010, -0.004), "uv_scale": 3.4,
			 "size": 1.25},
		],
		"embers": [
			{"after": 0, "depth": 20.0, "amount": 38, "scale": 0.008,
			 "speed": 0.14, "lifetime": 13.0, "color": Color(0.17, 0.15, 0.12),
			 "spread": 45.0, "lift": 0.10, "turbulence": 0.3},
			{"after": 1, "depth": 8.0, "amount": 6, "scale": 0.011,
			 "speed": 0.25, "lifetime": 9.0, "color": Color(0.21, 0.18, 0.14),
			 "spread": 50.0, "lift": 0.06, "turbulence": 0.4},
		],
		# Desce sobre a mesa enquanto ele le: o caderno cresce, o quarto quase nao.
		"cam": {
			"from": {"pos": Vector3(0.06, 0.18, 0.0), "rot": Vector3(-0.34, -0.12, 0.08), "fov": 45.0},
			"to":   {"pos": Vector3(-0.05, -0.13, -2.2), "rot": Vector3(0.28, 0.11, -0.10), "fov": 43.0},
			"dur": 34.0,
		},
		"texts": ["WITH_POWER_4_1", "WITH_POWER_4_2", "WITH_POWER_4_3", "WITH_POWER_4_4"],
	}


# -----------------------------------------------------------------------------
func _on_finished() -> void:
	SaveManager.prolog_finished = true
	GlobalEvents.entering_chapter_1 = true
	# Garante MP cheio ao entrar no Capitulo 1: o modo parasita da luta final do
	# prologo consome MP, e sem isso o poder do amuleto (que exige current_mp > 0)
	# pode comecar desativado se o MP tiver ficado baixo/zerado na luta.
	SaveManager.current_mp = SaveManager.max_mp
	SaveManager.save_game("res://scenes/stages/stage_1/stage_1.tscn")
	LoadingScreen.load_scene("res://scenes/stages/stage_1/stage_1.tscn")
