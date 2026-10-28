extends Node3D

## O LADO DE DENTRO da porta red valve na cutscene da oficina: só fogo.
##
## A sub-cena (`cutscene_sub_scene_portal_jimmy.tscn`) é só a porta, a câmera e
## o Husk, soltos no meio da oficina — aberta a porta, o vão mostrava a sala de
## madeira atrás dela. Isto monta em volta da porta (centro na origem, 1,25 m ×
## 1,9 m, chão em y = -0,95, frente pro +Z):
##
##  - uma PAREDE com o vão da porta e o chão na frente, pra porta ter onde estar;
##  - atrás do vão, um TÚNEL de fogo opaco (`fogo_tunel.gdshader`): de qualquer
##    ângulo, e até com a câmera lá dentro, tudo é fogo;
##  - CORTINAS de labareda (`labareda.gdshader`) em fila no túnel: quem anda
##    por dentro delas sai do fogo, e quem é arrastado pra dentro some nele;
##  - fogo e brasa vazando pelo vão, e a luz tremendo.
##
## `rajada()` é a porta escancarando: a labareda cospe pra fora e a luz estoura.

const TUNEL := preload("res://shaders/effects/fogo_tunel.gdshader")
const LABAREDA := preload("res://shaders/effects/labareda.gdshader")

const CHAO := -0.95
const VAO_LARGURA := 1.26
const VAO_ALTURA := 1.92
## Fundura das cortinas de labareda dentro do túnel (z).
const CORTINAS := [-0.55, -1.4, -2.4, -3.6]

var _luz_dentro: OmniLight3D
var _luz_vao: OmniLight3D
var _cortinas: Array[MeshInstance3D] = []
var _vazando: CPUParticles3D
var _rajada: CPUParticles3D
var _forca: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	var ruido := _ruido()
	_montar_parede()
	_montar_tunel(ruido)
	for i in CORTINAS.size():
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.5, 2.7)
		m.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = LABAREDA
		mat.set_shader_parameter("ruido", ruido)
		mat.set_shader_parameter("semente", float(i) * 3.7)
		mat.set_shader_parameter("velocidade", 1.0 + 0.15 * float(i))
		mat.set_shader_parameter("altura", 0.95)
		mat.set_shader_parameter("intensidade", 0.0)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(0.0, CHAO + 1.3, CORTINAS[i])
		add_child(m)
		_cortinas.append(m)
	_luz_dentro = _luz(Vector3(0.0, 0.2, -1.0), 0.0, 6.0)
	_luz_vao = _luz(Vector3(0.0, 0.3, 0.45), 0.0, 4.0)
	_vazando = _particulas(60, 1.0, false)
	_rajada = _particulas(140, 0.7, true)


func _process(delta: float) -> void:
	_t += delta
	# a luz do fogo nunca fica parada
	var tremor := 0.75 + 0.25 * sin(_t * 23.0) * sin(_t * 7.3 + 1.1)
	_luz_dentro.light_energy = 5.0 * _forca * tremor
	_luz_vao.light_energy = 2.2 * _forca * tremor


## O fogo lá dentro acende (ou apaga) em `duracao` segundos.
func acender(forca: float, duracao: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "_forca", forca, duracao)
	for m in _cortinas:
		t.tween_property(m.material_override, "shader_parameter/intensidade", 0.6 * forca, duracao)
	_vazando.emitting = forca > 0.01


## A porta escancara: a labareda cospe pra fora do vão e a luz estoura.
func rajada() -> void:
	_rajada.restart()
	_rajada.emitting = true
	_forca = 3.0
	acender(1.0, 1.2)


func _ruido() -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.018
	fn.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = fn
	return tex


## Parede escura com o vão da porta, batente de ferro e chão na frente.
func _montar_parede() -> void:
	var pedra := StandardMaterial3D.new()
	pedra.albedo_color = Color(0.075, 0.05, 0.04)
	pedra.roughness = 0.95
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.17, 0.075, 0.06)
	ferro.metallic = 0.6
	ferro.roughness = 0.72
	var meia := VAO_LARGURA * 0.5
	var topo := CHAO + VAO_ALTURA
	# parede: esquerda, direita e em cima do vão (a face da frente em z = -0,1)
	_caixa(Vector3(-meia - 2.5, CHAO + 2.5, -0.3), Vector3(5.0, 5.0, 0.4), pedra)
	_caixa(Vector3(meia + 2.5, CHAO + 2.5, -0.3), Vector3(5.0, 5.0, 0.4), pedra)
	_caixa(Vector3(0.0, topo + (5.0 - VAO_ALTURA) * 0.5, -0.3), Vector3(VAO_LARGURA, 5.0 - VAO_ALTURA, 0.4), pedra)
	# chão da frente
	_caixa(Vector3(0.0, CHAO - 0.1, 2.0), Vector3(10.0, 0.2, 4.6), pedra)
	# batente
	_caixa(Vector3(-meia - 0.07, CHAO + VAO_ALTURA * 0.5 + 0.04, -0.06), Vector3(0.14, VAO_ALTURA + 0.08, 0.5), ferro)
	_caixa(Vector3(meia + 0.07, CHAO + VAO_ALTURA * 0.5 + 0.04, -0.06), Vector3(0.14, VAO_ALTURA + 0.08, 0.5), ferro)
	_caixa(Vector3(0.0, topo + 0.08, -0.06), Vector3(VAO_LARGURA + 0.28, 0.16, 0.5), ferro)


## Caixa de fogo aberta na frente, atrás do vão: paredes, chão, teto e fundo.
func _montar_tunel(ruido: Texture2D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = TUNEL
	mat.set_shader_parameter("ruido", ruido)
	mat.set_shader_parameter("brilho", 0.8)
	var largura := 3.0
	var altura := 3.0
	var ini := -0.5
	var fim := -6.5
	var meio := (ini + fim) * 0.5
	var fundo := ini - fim
	var y := CHAO + altura * 0.5
	_caixa(Vector3(0.0, y, fim), Vector3(largura, altura, 0.1), mat)
	_caixa(Vector3(-largura * 0.5, y, meio), Vector3(0.1, altura, fundo), mat)
	_caixa(Vector3(largura * 0.5, y, meio), Vector3(0.1, altura, fundo), mat)
	_caixa(Vector3(0.0, CHAO - 0.05, meio), Vector3(largura, 0.1, fundo), mat)
	_caixa(Vector3(0.0, CHAO + altura, meio), Vector3(largura, 0.1, fundo), mat)
	# o trecho entre o vão e o túnel (a grossura da parede) também queima
	_caixa(Vector3(0.0, CHAO - 0.05, -0.3), Vector3(VAO_LARGURA, 0.1, 0.45), mat)


func _caixa(pos: Vector3, tamanho: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tamanho
	m.mesh = b
	m.material_override = mat
	m.position = pos
	add_child(m)


func _luz(pos: Vector3, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.12)
	l.light_energy = energia
	l.omni_range = alcance
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.position = pos
	add_child(l)
	return l


## Fogo vazando pelo vão (contínuo) ou a cuspida da porta abrindo (`rajada`).
func _particulas(quantas: int, vida: float, rajada_: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = quantas
	p.lifetime = vida
	p.one_shot = rajada_
	p.explosiveness = 0.9 if rajada_ else 0.0
	p.emitting = false
	p.local_coords = false
	p.position = Vector3(0.0, CHAO + VAO_ALTURA * 0.5, -0.35)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(VAO_LARGURA * 0.4, VAO_ALTURA * 0.42, 0.1)
	p.direction = Vector3(0.0, 0.35, 1.0)
	p.spread = 35.0 if rajada_ else 22.0
	p.initial_velocity_min = 2.5 if rajada_ else 0.5
	p.initial_velocity_max = 5.0 if rajada_ else 1.3
	p.damping_min = 2.0 if rajada_ else 0.5
	p.damping_max = 4.0 if rajada_ else 1.0
	p.gravity = Vector3(0.0, 1.8, 0.0)
	p.scale_amount_min = 0.35 if rajada_ else 0.15
	p.scale_amount_max = 0.8 if rajada_ else 0.35
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.4))
	curva.add_point(Vector2(0.3, 1.0))
	curva.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = curva
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.35, 0.05, 0.85), Color(0.35, 0.02, 0.0, 0.0)])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _bolha()
	q.material = mat
	p.mesh = q
	add_child(p)
	return p


func _bolha() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
