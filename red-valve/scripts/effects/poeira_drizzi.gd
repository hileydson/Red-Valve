extends Node3D

## A TERRA E O SANGUE DA DRIZZI (Capítulo 3, cemitério) — os efeitos da cena
## da capela e da luta, todos por código (partícula CPU, que o renderer mobile
## aceita):
##
##   nuvem(pai, onde, raio, altura, quantas)  poeira que sobe e fica: a terra
##                                           que ela come. `parar()` corta a
##                                           saída e `assentar(s)` faz a que
##                                           ficou no ar descer e sumir devagar
##   estouro(pai, onde, tamanho)             o chão estourando: poeira, torrões
##                                           e um buraco escuro que desbota
##   pingando(no)                            sangue pingando de um nó (o órgão
##                                           na mão dela)
##   respingo(pai, onde, tamanho)            o sangue espirrando no impacto,
##                                           com a mancha no chão
##
## Use `preload` deste script (sem class_name: ver [[project-class-name-travado]]).

const ESTE := "res://scripts/effects/poeira_drizzi.gd"
const MANCHA := "res://assets/images/vfx/sangue_respingo_2.png"
const COR_POEIRA := Color(0.42, 0.37, 0.31)
const COR_TORRAO := Color(0.16, 0.12, 0.09)
const COR_SANGUE := Color(0.34, 0.01, 0.02)

static var _disco: Texture2D

var _particulas: Array[CPUParticles3D] = []
var _materiais: Array[StandardMaterial3D] = []


static func _novo(pai: Node, onde: Vector3, nome: String) -> Node3D:
	var n: Node3D = load(ESTE).new()
	n.name = nome
	pai.add_child(n)
	n.global_position = onde
	return n


## Poeira subindo em volta de `onde` e ficando no ar (até `parar`).
static func nuvem(pai: Node, onde: Vector3, raio: float, altura: float, quantas: int = 90) -> Node3D:
	var n := _novo(pai, onde, "nuvem_de_poeira")
	var p: CPUParticles3D = n._camada(quantas, 7.0, raio * 0.8, COR_POEIRA, 0.55)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(raio * 0.5, 0.3, raio * 0.5)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = altura * 0.35
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.gravity = Vector3(0.0, -0.05, 0.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.8
	p.position.y = 0.3
	return n


## O chão estourando em `onde` (a cova que ela abre pra entrar ou sair).
static func estouro(pai: Node, onde: Vector3, tamanho: float = 1.0) -> Node3D:
	var n := _novo(pai, onde, "estouro_de_terra")
	var po: CPUParticles3D = n._camada(int(46 * tamanho), 3.2, 1.6 * tamanho, COR_POEIRA, 0.6)
	po.one_shot = true
	po.explosiveness = 0.85
	po.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	po.emission_sphere_radius = 0.6 * tamanho
	po.direction = Vector3.UP
	po.spread = 55.0
	po.initial_velocity_min = 1.5 * tamanho
	po.initial_velocity_max = 4.5 * tamanho
	po.damping_min = 1.2
	po.damping_max = 2.2
	po.gravity = Vector3(0.0, -0.4, 0.0)
	po.scale_amount_min = 0.8
	po.scale_amount_max = 1.6
	var to: CPUParticles3D = n._camada(int(28 * tamanho), 1.6, 0.16 * tamanho, COR_TORRAO, 1.0, false)
	to.one_shot = true
	to.explosiveness = 0.95
	to.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	to.emission_sphere_radius = 0.4 * tamanho
	to.direction = Vector3.UP
	to.spread = 40.0
	to.initial_velocity_min = 3.0 * tamanho
	to.initial_velocity_max = 6.5 * tamanho
	to.gravity = Vector3(0.0, -14.0, 0.0)
	to.scale_amount_min = 0.5
	to.scale_amount_max = 1.4
	n._buraco(1.1 * tamanho, 9.0)
	n._apagar_depois(10.0)
	return n


## Sangue pingando de `no` enquanto ele existir (o órgão na mão dela).
static func pingando(no: Node3D, forca: float = 1.0) -> Node3D:
	var n: Node3D = load(ESTE).new()
	n.name = "sangue_pingando"
	no.add_child(n)
	var p: CPUParticles3D = n._camada(int(40 * forca), 0.9, 0.05, COR_SANGUE, 0.95, false)
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3.DOWN
	p.spread = 35.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.4 * forca
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	# os esguichos de lado
	var e: CPUParticles3D = n._camada(int(18 * forca), 0.6, 0.04, COR_SANGUE, 0.95, false)
	e.local_coords = false
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.06
	e.direction = Vector3.UP
	e.spread = 180.0
	e.initial_velocity_min = 1.2
	e.initial_velocity_max = 3.0 * forca
	e.gravity = Vector3(0.0, -9.8, 0.0)
	return n


## O sangue espirrando em `onde`, e a mancha que fica no chão.
static func respingo(pai: Node, onde: Vector3, tamanho: float = 1.0, mancha: bool = true) -> Node3D:
	var n := _novo(pai, onde, "respingo_de_sangue")
	var p: CPUParticles3D = n._camada(int(60 * tamanho), 0.9, 0.07 * tamanho, COR_SANGUE, 0.95, false)
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 5.0 * tamanho
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	if mancha:
		n._mancha(1.3 * tamanho, 14.0)
	n._apagar_depois(16.0)
	return n


# ============================================================ a nuvem

## Para de soltar poeira (a que está no ar continua).
func parar() -> void:
	for p in _particulas:
		p.emitting = false


## A poeira que ficou no ar desce e some em `duracao` segundos; o nó se apaga.
func assentar(duracao: float) -> void:
	parar()
	for p in _particulas:
		p.gravity = Vector3(0.0, -0.35, 0.0)
	var t := create_tween().set_parallel(true)
	for m in _materiais:
		t.tween_property(m, "albedo_color:a", 0.0, duracao).set_trans(Tween.TRANS_SINE)
	await t.finished
	queue_free()


## Engrossa (ou afina) a nuvem: `fator` multiplica a opacidade de cada grão.
func densidade(fator: float, duracao: float) -> void:
	var t := create_tween().set_parallel(true)
	for m in _materiais:
		t.tween_property(m, "albedo_color:a", clampf(fator, 0.0, 1.0), duracao)


# ============================================================ peças

func _camada(quantas: int, vida: float, tamanho: float, cor: Color, opaco: float,
		macia: bool = true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(quantas, 1)
	p.lifetime = vida
	p.randomness = 0.4
	p.local_coords = false
	var curva := Curve.new()
	if macia:
		curva.add_point(Vector2(0.0, 0.35))
		curva.add_point(Vector2(0.4, 1.0))
		curva.add_point(Vector2(1.0, 1.25))
	else:
		curva.add_point(Vector2(0.0, 1.0))
		curva.add_point(Vector2(1.0, 0.6))
	p.scale_amount_curve = curva
	var cores := Gradient.new()
	if macia:
		cores.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
		cores.colors = PackedColorArray([Color(cor, 0.0), Color(cor, 0.85), Color(cor.darkened(0.1), 0.6),
			Color(cor.darkened(0.2), 0.0)])
	else:
		cores.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
		cores.colors = PackedColorArray([cor, cor, Color(cor, 0.0)])
	p.color_ramp = cores
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * tamanho
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if not macia else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_color = Color(1, 1, 1, opaco)
	m.albedo_texture = _textura_disco()
	m.disable_receive_shadows = true
	if macia:
		# poeira grande colada na câmera vira cortina chapada
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 0.4
		m.distance_fade_max_distance = 2.2
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_particulas.append(p)
	_materiais.append(m)
	return p


static func _textura_disco() -> Texture2D:
	if _disco == null:
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(0.5, 0.0)
		var cores := Gradient.new()
		cores.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		cores.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		g.gradient = cores
		g.width = 64
		g.height = 64
		_disco = g
	return _disco


## O buraco escuro no chão, que desbota em `dura` segundos.
func _buraco(raio: float, dura: float) -> void:
	var d := MeshInstance3D.new()
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * raio * 2.0
	malha.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.02, 0.015, 0.01, 0.95)
	m.albedo_texture = _textura_disco()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	malha.material = m
	d.mesh = malha
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(d)
	d.position.y = 0.04
	var t := create_tween()
	t.tween_interval(dura * 0.6)
	t.tween_property(m, "albedo_color:a", 0.0, dura * 0.4)


func _mancha(raio: float, dura: float) -> void:
	var tex := load(MANCHA) as Texture2D
	if tex == null:
		return
	var dec := Decal.new()
	dec.texture_albedo = tex
	dec.modulate = Color(0.55, 0.02, 0.03)
	dec.size = Vector3(raio * 2.0, 1.2, raio * 2.0)
	dec.rotation.y = randf() * TAU
	add_child(dec)
	var t := create_tween()
	t.tween_interval(dura * 0.7)
	t.tween_property(dec, "modulate:a", 0.0, dura * 0.3)


func _apagar_depois(segundos: float) -> void:
	await get_tree().create_timer(segundos, false).timeout
	if is_inside_tree():
		queue_free()
