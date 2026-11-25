extends CanvasLayer

## ACABAMENTO DE CINEMA para as cutscenes em 3D.
##
## Uma camada de tela (shaders/cutscenes/cinema_tela.gdshader) que da' a
## leitura de filme que as cutscenes 2.5D ja tinham (ParallaxCutscene +
## cutscene_post) e que a abertura do Capitulo 1 tinha no proprio script: grade
## de cor por clima, halacao, aberracao, vinheta, grao e tarjas. Em cima disso,
## o que faz uma cena parecer FILMADA e nao so' renderizada:
##
##  - camera na mao: deriva lenta de ruido coerente, sempre ligada;
##  - tremor por "trauma" (`tremer`): soma, decai sozinho, e e' quadratico — um
##    tranco leve quase nao aparece, um forte sacode;
##  - `impacto`: tremor + clarao + aberracao + borrao radial + vibracao do
##    controle (+ grave opcional) num numero so';
##  - `relampago`: o clarao duplo da tempestade;
##  - `foco`: profundidade de campo de longe (no Mobile so' o desfoque de LONGE
##    presta — ver memoria do projeto), devolvida no fim;
##  - `atmosfera`: poeira, brasas ou cinzas flutuando na frente da camera.
##
## Tudo em espaco de TELA: o filtro nunca mexe na camera. Varias cutscenes
## posicionam a camera a cada quadro (look_at, h_offset absoluto, tweens), e um
## tremor que escrevesse nela brigaria com todas. Os pulsos correm em tempo REAL
## (Time.get_ticks_usec), entao tambem valem nas cameras lentas
## (Engine.time_scale baixo).
##
## Outros scripts da mesma cutscene acham o filtro pelo grupo "filtro_cinema".
##
## Uso:
##     const FiltroCinema := preload("res://scripts/cutscenes/filtro_cinema.gd")
##     var filtro = FiltroCinema.criar(self, "chuva_noite")
##     filtro.entrar()               # fade do filtro + tarjas
##     filtro.impacto(1.0)
##     await filtro.sair()           # tira tudo e se libera

const SHADER := "res://shaders/cutscenes/cinema_tela.gdshader"
const SOM_GRAVE := "res://assets/sounds/common/explosao.mp3"

## 0.11 da tela em cima e embaixo ~ 2.35:1 num quadro 16:9.
const LETTERBOX_PADRAO := 0.11

## Climas. Cada um e' so' a grade; os efeitos de momento (clarao, tremor) sao
## chamados pela cutscene. Valores de cor em 0..1, como no filtro antigo do
## Capitulo 1 (o "aereo" e' exatamente aquele, com a halacao nova).
const PRESETS := {
	"padrao": {
		"halation": 0.25, "halation_limiar": 0.60, "halation_cor": Color(1.0, 0.90, 0.78),
		"aberration": 0.0018, "vignette_amount": 0.40, "grain_amount": 0.030,
		"exposicao": 1.0, "contrast": 1.10, "saturation": 0.95, "haze": 0.08,
		"sombra_tint": Color(0.45, 0.55, 0.72), "luz_tint": Color(1.0, 0.90, 0.76),
		"calor": 0.0,
	},
	# A abertura do Capitulo 1: voo sobre a cidade ao entardecer.
	"aereo": {
		"halation": 0.22, "halation_limiar": 0.62, "halation_cor": Color(1.0, 0.94, 0.84),
		"aberration": 0.0018, "vignette_amount": 0.38, "grain_amount": 0.030,
		"exposicao": 1.0, "contrast": 1.10, "saturation": 0.92, "haze": 0.10,
		"sombra_tint": Color(0.42, 0.56, 0.78), "luz_tint": Color(1.0, 0.90, 0.74),
		"calor": 0.0,
	},
	# O trailer: tempestade, aco frio, relampago estourando na lente.
	"tempestade": {
		"halation": 0.34, "halation_limiar": 0.55, "halation_cor": Color(0.78, 0.86, 1.0),
		"aberration": 0.0022, "vignette_amount": 0.46, "grain_amount": 0.034,
		"exposicao": 1.0, "contrast": 1.16, "saturation": 0.80, "haze": 0.08,
		"sombra_tint": Color(0.36, 0.50, 0.62), "luz_tint": Color(0.96, 0.95, 1.0),
		"calor": 0.0,
	},
	# A abertura na chuva: noite azul, poste de sodio vazando laranja.
	"chuva_noite": {
		"halation": 0.40, "halation_limiar": 0.50, "halation_cor": Color(1.0, 0.80, 0.60),
		"aberration": 0.0020, "vignette_amount": 0.44, "grain_amount": 0.034,
		"exposicao": 1.0, "contrast": 1.12, "saturation": 0.86, "haze": 0.09,
		"sombra_tint": Color(0.38, 0.52, 0.70), "luz_tint": Color(1.0, 0.86, 0.66),
		"calor": 0.0,
	},
	# Casa e oficina: lampada de tungstenio, sombra fria.
	"interior": {
		"halation": 0.32, "halation_limiar": 0.55, "halation_cor": Color(1.0, 0.78, 0.55),
		"aberration": 0.0020, "vignette_amount": 0.50, "grain_amount": 0.038,
		"exposicao": 1.08, "contrast": 1.12, "saturation": 0.90, "haze": 0.06,
		"sombra_tint": Color(0.48, 0.50, 0.64), "luz_tint": Color(1.0, 0.84, 0.64),
		"calor": 0.0,
	},
	# O outro mundo: brasa, ar tremendo, preto avermelhado.
	"inferno": {
		"halation": 0.50, "halation_limiar": 0.48, "halation_cor": Color(1.0, 0.55, 0.30),
		"aberration": 0.0026, "vignette_amount": 0.50, "grain_amount": 0.040,
		"exposicao": 1.0, "contrast": 1.15, "saturation": 1.02, "haze": 0.07,
		"sombra_tint": Color(0.55, 0.24, 0.26), "luz_tint": Color(1.0, 0.80, 0.58),
		"calor": 0.35,
	},
	# A arena: tempestade roxa, fogo das gargulas.
	"arena": {
		"halation": 0.40, "halation_limiar": 0.55, "halation_cor": Color(1.0, 0.70, 0.50),
		"aberration": 0.0022, "vignette_amount": 0.46, "grain_amount": 0.034,
		"exposicao": 1.0, "contrast": 1.14, "saturation": 0.95, "haze": 0.07,
		"sombra_tint": Color(0.46, 0.42, 0.64), "luz_tint": Color(1.0, 0.86, 0.70),
		"calor": 0.0,
	},
}

## Quanto a camera "na mao" deriva (0 desliga). 1.0 = operador parado
## segurando a camera; 2.0 = andando.
var mao: float = 1.0

var _mat: ShaderMaterial
var _rect: ColorRect
var _base: Dictionary = {}
var _intensidade: float = 0.0
var _letterbox: float = 0.0
var _trauma: float = 0.0
## Quanto o trauma cai por segundo.
var _trauma_queda: float = 1.1
var _pulsos: Dictionary = {}       # nome -> { pico, dur, t }
var _flash_cor: Color = Color(1, 1, 1, 0)
var _ruido: FastNoiseLite
var _relogio: float = 0.0
var _ultimo_us: int = 0
var _zoom: float = 1.0

var _attrs_originais: Dictionary = {}   # Camera3D -> CameraAttributes (ou null)
var _efeitos: Array[Node] = []


## Cria o filtro como filho de `dono`, ja' no clima pedido e INVISIVEL
## (intensidade 0) — `entrar()` e' que mostra.
static func criar(dono: Node, preset: String = "padrao", camada: int = -1) -> CanvasLayer:
	var filtro = load("res://scripts/cutscenes/filtro_cinema.gd").new()
	filtro.name = "FiltroCinema"
	filtro.layer = camada
	filtro._preset_inicial = preset
	dono.add_child(filtro)
	return filtro


var _preset_inicial: String = "padrao"


func _ready() -> void:
	# Quem precisa do filtro de outra cena da cutscene (os takes de rua, o
	# agarrao) acha por aqui, sem caminho de no' fixo.
	add_to_group("filtro_cinema")
	_ruido = FastNoiseLite.new()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	_ruido.seed = randi()
	_ultimo_us = Time.get_ticks_usec()

	var copia := BackBufferCopy.new()
	copia.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copia)

	_rect = ColorRect.new()
	_rect.name = "Cinema"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_rect.material = _mat
	add_child(_rect)

	aplicar_preset(_preset_inicial, 0.0)
	# fora dos presets, mas `ajustar` precisa de um ponto de partida
	_set_base(0.0, "borrao_radial")
	_mat.set_shader_parameter("intensity", 0.0)
	_mat.set_shader_parameter("letterbox", 0.0)


# ==============================================================================
# ENTRADA E SAIDA
# ==============================================================================

## Fade do filtro e tarjas entrando. `letterbox` 0 = sem tarjas (cenas que ja
## tem as barras do `cutscene_takes`).
func entrar(dur: float = 1.2, letterbox: float = LETTERBOX_PADRAO) -> void:
	var t := _tween()
	t.tween_method(_set_intensidade, _intensidade, 1.0, dur).set_trans(Tween.TRANS_SINE)
	if letterbox > 0.0:
		t.tween_method(_set_letterbox, _letterbox, letterbox, dur * 0.7)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Tira o filtro devagar, devolve o foco das cameras, apaga a atmosfera e (por
## padrao) se libera.
func sair(dur: float = 0.8, liberar: bool = true) -> void:
	devolver_foco()
	for e in _efeitos:
		if is_instance_valid(e) and e is CPUParticles3D:
			(e as CPUParticles3D).emitting = false
	var t := _tween()
	t.tween_method(_set_intensidade, _intensidade, 0.0, dur).set_trans(Tween.TRANS_SINE)
	t.tween_method(_set_letterbox, _letterbox, 0.0, dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	if liberar and is_instance_valid(self):
		_limpar_efeitos()
		queue_free()


## Some na hora (pulo de cutscene, troca de cena).
func desligar() -> void:
	devolver_foco()
	_limpar_efeitos()
	queue_free()


func set_letterbox(valor: float, dur: float = 0.6) -> void:
	var t := _tween()
	t.tween_method(_set_letterbox, _letterbox, valor, dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Troca o clima (de uma vez ou numa transicao de `dur` segundos).
func aplicar_preset(nome: String, dur: float = 0.0) -> void:
	var alvo: Dictionary = PRESETS.get(nome, PRESETS["padrao"])
	if dur <= 0.0:
		for chave in alvo:
			_set_base(alvo[chave], chave)
		return
	var t := _tween()
	for chave in alvo:
		var de = _base.get(chave, alvo[chave])
		t.tween_method(_set_base.bind(chave), de, alvo[chave], dur).set_trans(Tween.TRANS_SINE)


## Muda um parametro so' (valor de base, sem pulso), opcionalmente em `dur` s.
func ajustar(nome: String, valor, dur: float = 0.0) -> void:
	if dur <= 0.0:
		_set_base(valor, nome)
		return
	var t := _tween()
	t.tween_method(_set_base.bind(nome), _base.get(nome, valor), valor, dur).set_trans(Tween.TRANS_SINE)


# ==============================================================================
# MOMENTOS
# ==============================================================================

## Soma trauma (0..1). O tremor e' trauma², entao 0.3 e' um tranco e 1.0 e' o
## chao sumindo. `queda` = quanto trauma some por segundo.
func tremer(trauma: float, queda: float = 1.1) -> void:
	_trauma = clampf(_trauma + trauma, 0.0, 1.0)
	_trauma_queda = queda


## Um valor que sobe na hora para `pico` e volta sozinho em `dur` segundos.
## Vale para: aberration, borrao_radial, exposicao, calor, halation.
func pulso(nome: String, pico: float, dur: float) -> void:
	var atual: Dictionary = _pulsos.get(nome, {})
	if not atual.is_empty() and _valor_pulso(atual) > pico:
		return
	_pulsos[nome] = {"pico": pico, "dur": maxf(dur, 0.01), "t": 0.0}


## Clarao de luz que some sozinho.
func clarao(cor: Color, forca: float, dur: float) -> void:
	_flash_cor = Color(cor.r, cor.g, cor.b, 1.0)
	pulso("flash", clampf(forca, 0.0, 1.0), dur)


## Pancada: tremor, clarao, lente estourando, borrao radial e o controle
## vibrando. `com_som` acrescenta um grave por baixo do som da propria cena.
func impacto(forca: float = 1.0, cor: Color = Color(1.0, 0.94, 0.86), com_som: bool = false) -> void:
	tremer(0.7 * forca, 1.3)
	clarao(cor, 0.45 * forca, 0.25 + 0.3 * forca)
	pulso("aberration", 0.010 * forca, 0.6)
	pulso("borrao_radial", 0.55 * forca, 0.45)
	pulso("exposicao", 0.25 * forca, 0.35)
	GlobalUtils.vibrate_controller(null, clampf(0.55 * forca, 0.0, 1.0), clampf(0.45 * forca, 0.0, 1.0), 0.25 + 0.25 * forca)
	if com_som:
		som_grave(forca)


## O relampago: dois estalos de luz fria e um rabo, com a lente vazando.
func relampago(forca: float = 1.0) -> void:
	var fria := Color(0.86, 0.92, 1.0)
	clarao(fria, 0.55 * forca, 0.08)
	pulso("halation", 0.6 * forca, 0.5)
	await _esperar_real(0.07)
	if not is_inside_tree():
		return
	clarao(fria, 0.25 * forca, 0.05)
	await _esperar_real(0.06)
	if not is_inside_tree():
		return
	clarao(fria, 0.70 * forca, 0.45)
	pulso("halation", 0.9 * forca, 0.7)
	tremer(0.12 * forca)


## O grave de cinema por baixo de um impacto.
func som_grave(forca: float = 1.0) -> void:
	var stream := load(SOM_GRAVE) as AudioStream
	if stream == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = stream
	a.pitch_scale = 0.36
	a.volume_db = -14.0 + 8.0 * clampf(forca, 0.0, 1.0)
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


# ==============================================================================
# CAMERA
# ==============================================================================

## Desfoque de LONGE na camera: o que estiver alem de `distancia` borra. A
## camera ganha uma COPIA dos atributos que ela (ou o mundo) ja tinha, entao a
## exposicao da cena nao muda; `devolver_foco` (chamado no `sair`) desfaz.
func foco(cam: Camera3D, distancia: float, transicao: float = 12.0, quanto: float = 0.06) -> void:
	if not is_instance_valid(cam):
		return
	if not _attrs_originais.has(cam):
		_attrs_originais[cam] = cam.attributes
	var origem: CameraAttributes = _attrs_originais[cam]
	if origem == null and cam.get_world_3d():
		origem = cam.get_world_3d().camera_attributes
	var at: CameraAttributesPractical
	if origem is CameraAttributesPractical:
		at = (origem as CameraAttributesPractical).duplicate()
	else:
		at = CameraAttributesPractical.new()
	at.dof_blur_far_enabled = true
	at.dof_blur_far_distance = maxf(distancia, 0.5)
	at.dof_blur_far_transition = transicao
	at.dof_blur_amount = quanto
	cam.attributes = at


func devolver_foco() -> void:
	for cam in _attrs_originais:
		if is_instance_valid(cam):
			cam.attributes = _attrs_originais[cam]
	_attrs_originais.clear()


## Particulas de ar na frente da camera: "poeira" (graos de luz parados no ar),
## "brasas" (fagulhas subindo) ou "cinzas" (flocos caindo). Ficam presas a'
## camera mas soltas no mundo (local_coords falso): a camera anda e elas ficam
## para tras, que e' o que da' a profundidade.
func atmosfera(cam: Camera3D, tipo: String = "poeira", quantidade: int = -1) -> CPUParticles3D:
	if not is_instance_valid(cam):
		return null
	var p := CPUParticles3D.new()
	p.name = "atmosfera_" + tipo
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.spread = 180.0
	var cor_ramp := Gradient.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.albedo_texture = _textura_redonda()
	mat.disable_receive_shadows = true

	match tipo:
		"brasas":
			p.amount = quantidade if quantidade > 0 else 70
			p.lifetime = 4.0
			p.emission_box_extents = Vector3(5.0, 1.5, 5.0)
			p.position = Vector3(0.0, -1.5, -3.5)
			p.direction = Vector3(0.0, 1.0, 0.0)
			p.spread = 35.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0.0, 0.35, 0.0)
			p.scale_amount_min = 0.018
			p.scale_amount_max = 0.05
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			cor_ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
			cor_ramp.colors = PackedColorArray([Color(1.0, 0.75, 0.35, 0.0), Color(1.0, 0.6, 0.2, 1.0),
				Color(1.0, 0.3, 0.05, 0.8), Color(0.8, 0.1, 0.0, 0.0)])
		"cinzas":
			p.amount = quantidade if quantidade > 0 else 90
			p.lifetime = 7.0
			p.emission_box_extents = Vector3(6.0, 1.0, 6.0)
			p.position = Vector3(0.0, 3.0, -3.0)
			p.direction = Vector3(0.3, -1.0, 0.1)
			p.spread = 25.0
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.gravity = Vector3(0.15, -0.25, 0.0)
			p.scale_amount_min = 0.02
			p.scale_amount_max = 0.045
			cor_ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
			cor_ramp.colors = PackedColorArray([Color(0.55, 0.52, 0.5, 0.0), Color(0.6, 0.57, 0.55, 0.7),
				Color(0.5, 0.48, 0.46, 0.6), Color(0.4, 0.4, 0.4, 0.0)])
		_:
			p.amount = quantidade if quantidade > 0 else 110
			p.lifetime = 8.0
			p.emission_box_extents = Vector3(3.5, 2.0, 3.5)
			p.position = Vector3(0.0, 0.0, -3.0)
			p.direction = Vector3(0.2, 0.1, 0.0)
			p.initial_velocity_min = 0.03
			p.initial_velocity_max = 0.12
			p.gravity = Vector3(0.0, -0.015, 0.0)
			p.scale_amount_min = 0.008
			p.scale_amount_max = 0.022
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			cor_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
			cor_ramp.colors = PackedColorArray([Color(1.0, 0.92, 0.78, 0.0), Color(1.0, 0.92, 0.78, 0.45),
				Color(1.0, 0.9, 0.75, 0.35), Color(1.0, 0.9, 0.75, 0.0)])

	p.color_ramp = cor_ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	p.mesh = quad
	p.preprocess = p.lifetime
	cam.add_child(p)
	_efeitos.append(p)
	return p


# ==============================================================================
# POR DENTRO
# ==============================================================================

func _process(_delta: float) -> void:
	if _mat == null:
		return
	var agora := Time.get_ticks_usec()
	var dt := clampf(float(agora - _ultimo_us) / 1000000.0, 0.0, 0.1)
	_ultimo_us = agora
	_relogio += dt

	_trauma = move_toward(_trauma, 0.0, dt * _trauma_queda)
	var choque := _trauma * _trauma

	# deriva lenta (mao) + sacudida rapida (choque), cada eixo com seu ruido
	var m := maxf(mao, 0.0)
	var dx := _ruido.get_noise_2d(_relogio * 0.32, 11.0) * 0.0026 * m \
		+ _ruido.get_noise_2d(_relogio * 19.0, 41.0) * 0.022 * choque
	var dy := _ruido.get_noise_2d(73.0, _relogio * 0.27) * 0.0022 * m \
		+ _ruido.get_noise_2d(57.0, _relogio * 21.0) * 0.022 * choque
	var g := _ruido.get_noise_2d(_relogio * 0.21, 131.0) * 0.0028 * m \
		+ _ruido.get_noise_2d(_relogio * 15.0, 173.0) * 0.030 * choque

	# zoom so' o necessario para a borda nunca aparecer, pelo envelope (nao pelo
	# valor do quadro) — senao a imagem "respira" junto com o tremor
	var env_off := 0.0026 * m + 0.022 * choque
	var env_giro := 0.0028 * m + 0.030 * choque
	var alvo_zoom := 1.0 + env_off * 2.2 + env_giro * 1.9
	_zoom = lerpf(_zoom, alvo_zoom, clampf(dt * 8.0, 0.0, 1.0))

	_mat.set_shader_parameter("deslocamento", Vector2(dx, dy))
	_mat.set_shader_parameter("giro", g)
	_mat.set_shader_parameter("zoom", _zoom)

	# pulsos somados ao valor de base
	var extra := {}
	for nome in _pulsos.keys():
		var p: Dictionary = _pulsos[nome]
		p["t"] = float(p["t"]) + dt
		if float(p["t"]) >= float(p["dur"]):
			_pulsos.erase(nome)
			extra[nome] = 0.0
		else:
			extra[nome] = _valor_pulso(p)
	for nome in ["aberration", "borrao_radial", "exposicao", "calor", "halation"]:
		_mat.set_shader_parameter(nome, float(_base.get(nome, 0.0)) + float(extra.get(nome, 0.0)))
	var f := float(extra.get("flash", 0.0))
	_mat.set_shader_parameter("flash_cor", Color(_flash_cor.r, _flash_cor.g, _flash_cor.b, f))


## Sobe na hora e cai com curva quadratica: o pico e' o quadro do impacto.
func _valor_pulso(p: Dictionary) -> float:
	var k := 1.0 - clampf(float(p["t"]) / float(p["dur"]), 0.0, 1.0)
	return float(p["pico"]) * k * k


func _set_base(valor, nome: String) -> void:
	_base[nome] = valor
	if _mat == null:
		return
	if valor is Color:
		var c: Color = valor
		_mat.set_shader_parameter(nome, Vector3(c.r, c.g, c.b))
	else:
		_mat.set_shader_parameter(nome, valor)


func _set_intensidade(valor: float) -> void:
	_intensidade = valor
	if _mat:
		_mat.set_shader_parameter("intensity", valor)


func _set_letterbox(valor: float) -> void:
	_letterbox = valor
	if _mat:
		_mat.set_shader_parameter("letterbox", valor)


## Tween que ignora o time_scale: o filtro anda no tempo do espectador, mesmo
## com a cena em camera lenta.
func _tween() -> Tween:
	return create_tween().set_parallel(true).set_ignore_time_scale(true)


func _esperar_real(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout


func _textura_redonda() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _limpar_efeitos() -> void:
	for e in _efeitos:
		if is_instance_valid(e):
			e.queue_free()
	_efeitos.clear()


func _exit_tree() -> void:
	devolver_foco()
	_limpar_efeitos()
