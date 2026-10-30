extends Node3D

## A AURA DO AMULETO — o fogo roxo do altar do inferno 4 e o brilho que fica no
## amuleto depois que o Maycow passa ele pela chama (`Eventos.CAP1_AURA_AMULETO`).
##
## Dois jeitos, o mesmo fogo:
##  - CHAMA: a chama pequena que flutua em cima do altar, subindo, com luz;
##  - AURA: o mesmo roxo, mais fraco e espalhado, em volta do amuleto (na mão
##    da cutscene, na visão do amuleto, no inventário e na tela do poder novo).
##
## Tudo é criado por código (partícula CPU + luz, que o renderer mobile aceita):
##
##     var chama := AuraDoAmuleto.chama(0.16)
##     altar.add_child(chama)
##     AuraDoAmuleto.vestir(modelo_do_amuleto)    # mede o modelo e encaixa

const MODELO_AMULETO := "res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb"
const ROXO := Color(0.62, 0.28, 1.0)
const LILAS := Color(0.78, 0.55, 1.0)

enum Modo { CHAMA, AURA }

var modo: Modo = Modo.CHAMA
## Tamanho de referência, em unidades do PAI (o raio da chama/da aura).
var raio: float = 0.16
## Luz junto? (na tela do poder novo o modelo já tem a luz da tela)
var com_luz: bool = true
## Partículas no espaço do pai: na tela que gira, a aura gira junto.
var local: bool = false

var _luz: OmniLight3D
var _nucleo: MeshInstance3D
var _fogo: CPUParticles3D
var _tempo: float = 0.0
var _forca: float = 1.0


static func chama(tamanho: float) -> Node3D:
	var a = load("res://scripts/systems/aura_do_amuleto.gd").new()
	a.name = "chama_da_aura"
	a.modo = Modo.CHAMA
	a.raio = tamanho
	return a


## Põe a aura em volta de `modelo` (o amuleto), no tamanho dele. Mede a caixa
## das malhas no espaço do próprio modelo e centra a aura nela.
static func vestir(modelo: Node3D, luz: bool = true, no_espaco_do_modelo: bool = false) -> Node3D:
	if modelo == null:
		return null
	var velha := modelo.get_node_or_null("aura_do_amuleto")
	if velha:
		return velha
	var caixa := _caixa(modelo, Transform3D.IDENTITY)
	var a = load("res://scripts/systems/aura_do_amuleto.gd").new()
	a.name = "aura_do_amuleto"
	a.modo = Modo.AURA
	a.raio = maxf(maxf(caixa.size.x, caixa.size.y), caixa.size.z) * 0.6 if caixa.has_volume() else 0.1
	a.com_luz = luz
	a.local = no_espaco_do_modelo
	modelo.add_child(a)
	a.position = caixa.get_center()
	return a


## Este modelo é o amuleto, e ele já tem a aura? Veste. (Inventário e telas.)
static func vestir_se_for_amuleto(caminho: String, modelo: Node3D) -> void:
	if caminho == MODELO_AMULETO and Eventos.amuleto_com_aura():
		vestir(modelo, false, true)


static func _caixa(no: Node, xf: Transform3D) -> AABB:
	var caixa := AABB()
	var tem := false
	if no is VisualInstance3D and not (no is Light3D) and not (no is GPUParticles3D) \
			and not (no is CPUParticles3D):
		caixa = xf * (no as VisualInstance3D).get_aabb()
		tem = true
	for filho in no.get_children():
		if filho is Node3D:
			var c := _caixa(filho, xf * (filho as Node3D).transform)
			if c.has_volume():
				caixa = caixa.merge(c) if tem else c
				tem = true
	return caixa


func _ready() -> void:
	var r := raio
	var chama_ := modo == Modo.CHAMA
	_fogo = CPUParticles3D.new()
	_fogo.name = "fogo"
	_fogo.local_coords = local
	_fogo.amount = 48 if chama_ else 36
	_fogo.lifetime = 0.9 if chama_ else 1.3
	_fogo.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fogo.emission_sphere_radius = r * (0.32 if chama_ else 0.75)
	_fogo.direction = Vector3.UP
	_fogo.spread = 14.0 if chama_ else 180.0
	_fogo.gravity = Vector3.UP * r * (2.2 if chama_ else 0.4)
	_fogo.initial_velocity_min = r * (1.2 if chama_ else 0.15)
	_fogo.initial_velocity_max = r * (2.4 if chama_ else 0.45)
	_fogo.scale_amount_min = 0.7
	_fogo.scale_amount_max = 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.55 if chama_ else 0.3))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	_fogo.scale_amount_curve = curva
	var cores := Gradient.new()
	cores.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
	cores.colors = PackedColorArray([Color(LILAS, 0.0), Color(LILAS, 0.75),
		Color(ROXO, 0.65), Color(0.25, 0.04, 0.5, 0.0)])
	_fogo.color_ramp = cores
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * r * (0.9 if chama_ else 0.45)
	quad.material = _material_brilho()
	_fogo.mesh = quad
	add_child(_fogo)

	if chama_:
		# o miolo claro da chama: sem ele o fogo é só fumaça roxa
		_nucleo = MeshInstance3D.new()
		_nucleo.name = "nucleo"
		var bola := QuadMesh.new()
		bola.size = Vector2.ONE * r * 1.1
		var m := _material_brilho()
		m.albedo_color = Color(0.7, 0.42, 1.0, 0.75)
		m.vertex_color_use_as_albedo = false
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bola.material = m
		_nucleo.mesh = bola
		_nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_nucleo)

	if com_luz:
		_luz = OmniLight3D.new()
		_luz.name = "luz"
		_luz.light_color = ROXO
		_luz.light_energy = 1.8 if chama_ else 0.6
		_luz.omni_range = 4.0 if chama_ else 1.2
		_luz.shadow_enabled = false
		add_child(_luz)


## Quad que sempre encara a câmera, aditivo, com o disco suave no meio.
func _material_brilho() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# sem isto a curva de escala das partículas não vale nada
	m.billboard_keep_scale = true
	m.no_depth_test = false
	var disco := GradientTexture2D.new()
	disco.fill = GradientTexture2D.FILL_RADIAL
	disco.fill_from = Vector2(0.5, 0.5)
	disco.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	disco.gradient = g
	disco.width = 64
	disco.height = 64
	m.albedo_texture = disco
	return m


func _process(delta: float) -> void:
	_tempo += delta
	var tremor := 0.85 + 0.1 * sin(_tempo * 13.0) + 0.05 * sin(_tempo * 31.0 + 1.7)
	if _luz:
		_luz.light_energy = (1.8 if modo == Modo.CHAMA else 0.6) * tremor * _forca
	if _nucleo:
		_nucleo.scale = Vector3.ONE * (0.9 + 0.12 * sin(_tempo * 9.0)) * maxf(_forca, 0.001)
		_nucleo.position.y = sin(_tempo * 1.6) * raio * 0.08


## A chama entra no amuleto: encolhe, a luz cai, as partículas param e o nó
## some. `para`, se vier, é o ponto (mundo) pra onde ela é puxada.
func absorver(duracao: float, para: Node3D = null) -> void:
	if _fogo:
		_fogo.emitting = false
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "_forca", 0.0, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "scale", Vector3.ONE * 0.05, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if para:
		var de := global_position
		t.tween_method(func(k: float) -> void:
			if is_instance_valid(para):
				global_position = de.lerp(para.global_position, k), 0.0, 1.0, duracao)
	await t.finished
	queue_free()
