extends RefCounted

## Pecas soltas que os efeitos do Shadow Seraph reaproveitam: textura de ponto
## suave pras particulas, rampas de cor, materiais emissivos e explosao.
##
## Tudo estatico e em cache: um unico recurso serve a todos os efeitos na tela
## ao mesmo tempo. Sao seis efeitos diferentes (raio, foguete, orbe, espada,
## esfera de fogo, anel) e cada um criava a mesma textura de faisca do zero —
## no renderer Mobile isso virava dezenas de texturas identicas na VRAM.

const SOM_EXPLOSAO := "res://assets/sounds/common/explosao.mp3"
const SOM_FOGO := "res://assets/sounds/common/fire_cracling.mp3"

static var _ponto: GradientTexture2D
static var _quad_fogo: QuadMesh
static var _quad_magia: QuadMesh


## Ponto redondo com borda suave. Sem isto toda faisca sai quadrada.
static func ponto_suave() -> GradientTexture2D:
	if _ponto != null:
		return _ponto
	_ponto = GradientTexture2D.new()
	_ponto.fill = GradientTexture2D.FILL_RADIAL
	_ponto.fill_from = Vector2(0.5, 0.5)
	_ponto.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.55), Color.TRANSPARENT])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5])
	_ponto.gradient = g
	return _ponto


## Rampa de cor pronta pra `ParticleProcessMaterial.color_ramp`.
static func rampa(cores: Array, pontos: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cores)
	g.offsets = PackedFloat32Array(pontos)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Curva "nasce, cresce, morre" pro tamanho das particulas.
static func curva_pico(pico: float = 0.25) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(pico, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t


## Quad billboard aditivo usado como draw_pass das particulas. Dois sabores
## (fogo e magia) porque sao os dois unicos que aparecem, e cache-los evita um
## material novo por particula instanciada.
static func quad_particula(magia := false) -> QuadMesh:
	if magia and _quad_magia != null:
		return _quad_magia
	if not magia and _quad_fogo != null:
		return _quad_fogo

	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = ponto_suave()
	m.disable_receive_shadows = true
	q.material = m
	if magia:
		_quad_magia = q
	else:
		_quad_fogo = q
	return q


## Material emissivo simples (nucleos de magia, lamina, olhos).
static func emissivo(cor: Color, energia: float = 5.0, aditivo := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = energia
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if aditivo:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	return m


## Textura de ruido celular, usada pra dar cara de plasma aos nucleos.
static func ruido_plasma(freq: float = 0.05) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.noise = n
	t.seamless = true
	return t


## Carrega um som em laco. O `fire_cracling.mp3` do projeto nao vem marcado
## como loop, entao tocado direto ele dava um estalo de fogo e silencio — e o
## corpo do Seraph precisa queimar sem parar. Duplica o recurso antes de mexer
## no `loop`: o mesmo mp3 e usado em outros lugares (menu, fogueira) que NAO
## devem virar laco.
static func som_em_laco(caminho: String) -> AudioStream:
	var base := load(caminho) as AudioStream
	if base == null:
		return null
	var copia := base.duplicate() as AudioStream
	if copia == null:
		return base
	if "loop" in copia:
		copia.set("loop", true)
	return copia


## Onde pendurar um efeito que tem de viver mais que quem o criou. O normal e a
## cena atual; durante uma troca de cena ela pode ser `null` por um instante, e
## nesse caso a raiz da arvore serve — melhor um efeito orfao que um
## `add_child` em null derrubando o ataque inteiro.
static func mundo(pai: Node) -> Node:
	if pai == null or not pai.is_inside_tree():
		return null
	var t := pai.get_tree()
	if t == null:
		return null
	if t.current_scene != null:
		return t.current_scene
	return t.root


## Som 3D solto no mundo, que se apaga sozinho quando acaba. Criar um
## AudioStreamPlayer3D filho do projetil nao serve: o projetil e liberado no
## mesmo frame da explosao e o som morreria junto.
static func som_no_mundo(pai: Node, pos: Vector3, caminho: String,
		volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var cena := mundo(pai)
	if cena == null:
		return
	var stream := load(caminho) as AudioStream
	if stream == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.volume_db = volume_db
	a.pitch_scale = pitch
	a.unit_size = 22.0
	a.max_distance = 90.0
	cena.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


## Estouro generico: clarao, onda de choque, faiscas e fumaca. Serve pro raio,
## pro foguete e pro orbe — muda so cor e tamanho.
##
## Vive sozinho na cena (nao e filho de quem explodiu), porque quem explodiu
## e liberado no mesmo frame.
static func explosao(pai: Node, pos: Vector3, cor: Color, raio: float = 2.5,
		com_som := true) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var cena := mundo(pai)
	if cena == null:
		return

	var raiz := Node3D.new()
	raiz.name = "SeraphExplosao"
	cena.add_child(raiz)
	raiz.global_position = pos

	# clarao: esfera aditiva que cresce e desaparece
	var clarao := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = raio * 0.35
	esfera.height = raio * 0.7
	esfera.radial_segments = 16
	esfera.rings = 8
	clarao.mesh = esfera
	var mat_clarao := emissivo(cor, 8.0)
	clarao.material_override = mat_clarao
	clarao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(clarao)

	# onda de choque: anel achatado abrindo no chao
	var onda := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = raio * 0.5
	toro.outer_radius = raio * 0.62
	toro.rings = 24
	onda.mesh = toro
	onda.material_override = emissivo(cor, 4.0)
	onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	onda.scale = Vector3(0.2, 0.2, 0.2)
	raiz.add_child(onda)

	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 14.0
	luz.omni_range = raio * 6.0
	luz.shadow_enabled = false
	raiz.add_child(luz)

	raiz.add_child(_faiscas_estouro(cor, raio))
	raiz.add_child(_fumaca_estouro(raio))

	if com_som:
		som_no_mundo(pai, pos, SOM_EXPLOSAO, -2.0, randf_range(0.85, 1.15))

	var t := raiz.create_tween().set_parallel(true)
	t.tween_property(clarao, "scale", Vector3.ONE * 2.9, 0.50).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float): mat_clarao.albedo_color = Color(cor.r, cor.g, cor.b, v), 1.0, 0.0, 0.60)
	t.tween_property(onda, "scale", Vector3(2.1, 0.3, 2.1), 0.75).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(luz, "light_energy", 0.0, 0.70).set_trans(Tween.TRANS_EXPO)
	# as particulas ainda estao no ar quando o clarao acaba: o no so sai depois
	t.chain().tween_interval(2.2)
	t.chain().tween_callback(raiz.queue_free)


static func _faiscas_estouro(cor: Color, raio: float) -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = raio * 0.2
	proc.direction = Vector3(0, 0.35, 0)
	proc.spread = 180.0
	proc.initial_velocity_min = raio * 2.0
	proc.initial_velocity_max = raio * 6.5
	proc.gravity = Vector3(0, -9.0, 0)
	proc.damping_min = 1.0
	proc.damping_max = 3.0
	proc.scale_min = 0.05
	proc.scale_max = 0.18
	proc.scale_curve = curva_pico(0.12)
	proc.color_ramp = rampa(
		[Color(1, 1, 1, 1), cor, Color(cor.r * 0.3, cor.g * 0.12, cor.b * 0.1, 0.0)],
		[0.0, 0.3, 1.0])

	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 1.0
	p.process_material = proc
	p.draw_pass_1 = quad_particula()
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3.ONE * -raio * 4.0, Vector3.ONE * raio * 8.0)
	p.emitting = true
	return p


static func _fumaca_estouro(raio: float) -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = raio * 0.4
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 80.0
	proc.initial_velocity_min = 0.6
	proc.initial_velocity_max = 2.4
	proc.gravity = Vector3(0, 0.4, 0)
	proc.damping_min = 1.5
	proc.damping_max = 3.0
	proc.scale_min = raio * 0.4
	proc.scale_max = raio * 0.9
	proc.scale_curve = curva_pico(0.55)
	proc.color_ramp = rampa(
		[Color(0.18, 0.16, 0.2, 0.55), Color(0.1, 0.09, 0.12, 0.3), Color(0.05, 0.05, 0.06, 0.0)],
		[0.0, 0.4, 1.0])

	var quad := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = ponto_suave()
	m.disable_receive_shadows = true
	quad.material = m

	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 2.0
	p.one_shot = true
	p.explosiveness = 0.8
	p.process_material = proc
	p.draw_pass_1 = quad
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3.ONE * -raio * 4.0, Vector3.ONE * raio * 8.0)
	p.emitting = true
	return p
