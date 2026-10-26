extends Node3D

## O sangue de um tiro que acerta um inimigo (substitui o `blood.tscn`, que
## era um punhado de riscos e quadradinhos sem luz).
##
## O impacto e' feito de camadas, cada uma um GPUParticles3D de disparo unico:
##   jato     o grosso, saindo pelo outro lado (a bala atravessa)
##   volta    o respingo pra tras, na direcao de quem atirou
##   nevoa    a nuvem fina que fica no ar um instante
##   pedacos  nacos de carne escura que caem rolando
##   pulsos   duas golfadas atrasadas, como de uma arteria aberta
##   pingos   o que escorre da ferida e cai reto
## e de manchas (Decal) onde o jato bate: no chao embaixo, no chao mais a
## frente e na parede de tras. Elas ficam um tempo e desbotam.
##
## Quem cria poe o no' na arvore e DEPOIS posiciona e gira (`look_at` com a
## normal do acerto): o -Z fica pra fora da ferida, pra quem atirou. Por isso
## o disparo espera o primeiro quadro.

const RESPINGOS := [
	"res://assets/images/vfx/sangue_respingo_1.png",
	"res://assets/images/vfx/sangue_respingo_2.png",
	"res://assets/images/vfx/sangue_respingo_3.png",
]
## Chao e paredes (os inimigos ficam nas camadas 3 e 4).
const MASCARA_CENARIO := 3
## Manchas vivas no mundo; passou disso, a mais velha some.
const MAX_MANCHAS := 40
const VIDA_MANCHA := 25.0
const SUMIR_MANCHA := 3.0

## Malhas e materiais sao os mesmos em todo tiro: montados uma vez so'.
static var _rec := {}
static var _manchas: Array = []

## Acelera o jorro inteiro (particulas e as golfadas atrasadas). A cinematica
## da ultimate deixa o mundo em camera lenta e sobe isto pra compensar; tem de
## vir antes do primeiro quadro, junto com a posicao.
var speed_scale: float = 1.0


func _ready() -> void:
	_disparar.call_deferred()


func _disparar() -> void:
	if not is_inside_tree():
		return
	if _rec.is_empty():
		_montar_recursos()
	_camada("jato", 90, 1.1, 0.92, Vector3(0, 0.12, 1), 18.0, 3.0, 9.0, 0.5, 2.2, "gota")
	_camada("volta", 50, 0.9, 0.95, Vector3(0, 0.35, -1), 50.0, 1.2, 4.0, 0.4, 1.6, "gota")
	_camada("nevoa", 12, 0.7, 1.0, Vector3(0, 0.1, -1), 80.0, 0.2, 1.4, 0.8, 1.6, "nevoa")
	_camada("pedacos", 8, 1.4, 1.0, Vector3(0, 0.45, 0.6), 75.0, 1.5, 4.0, 0.6, 1.8, "pedaco")
	_camada("pingos", 10, 1.2, 0.0, Vector3(0, -1, 0), 10.0, 0.0, 0.3, 0.8, 1.4, "gota")
	var arvore := get_tree()
	var ritmo := maxf(speed_scale, 0.01)
	for atraso in [0.16, 0.42]:
		arvore.create_timer(atraso / ritmo, false).timeout.connect(_pulso)
	_manchar()
	arvore.create_timer(2.4 / ritmo, false).timeout.connect(queue_free)


func _pulso() -> void:
	_camada("pulso", 26, 0.9, 0.7, Vector3(0, 0.25, -1), 14.0, 1.6, 3.4, 0.6, 1.8, "gota")


## Uma camada: `dir` e' no espaco deste no' (-Z = pra quem atirou), as
## particulas ficam no mundo (a ferida anda com o inimigo, o sangue nao).
func _camada(nome: String, quantas: int, vida: float, explosao: float, dir: Vector3,
		abertura: float, vel_min: float, vel_max: float, esc_min: float, esc_max: float,
		malha: String) -> void:
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = quantas
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = explosao
	p.randomness = 0.4
	p.local_coords = false
	p.speed_scale = speed_scale
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var m := ParticleProcessMaterial.new()
	m.direction = dir.normalized()
	m.spread = abertura
	m.initial_velocity_min = vel_min
	m.initial_velocity_max = vel_max
	m.scale_min = esc_min
	m.scale_max = esc_max
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.03
	m.gravity = Vector3(0, -9.8, 0)
	m.color_ramp = _rec["escurece"]
	match malha:
		"gota":
			m.particle_flag_align_y = true
			m.damping_min = 0.4
			m.damping_max = 1.2
		"nevoa":
			m.gravity = Vector3(0, -0.4, 0)
			m.damping_min = 2.0
			m.damping_max = 3.0
			m.scale_curve = _rec["incha"]
			m.color_ramp = _rec["dissipa"]
			m.emission_sphere_radius = 0.06
		"pedaco":
			m.angle_min = -180.0
			m.angle_max = 180.0
			m.angular_velocity_min = -720.0
			m.angular_velocity_max = 720.0
	p.process_material = m
	p.draw_pass_1 = _rec[malha]
	add_child(p)
	p.restart()


## As manchas: o chao embaixo da ferida, o chao onde o jato cai e a parede
## (ou o que estiver) atras do inimigo, cada uma quando o sangue chega la'.
func _manchar() -> void:
	var espaco := get_world_3d().direct_space_state
	var de := global_position
	var jato := global_basis.z.normalized()
	var pulo: Array[RID] = []
	var jogador := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if jogador:
		pulo.append(jogador.get_rid())
	var tiros := [
		[de, de + Vector3(0, -3.0, 0), randf_range(0.35, 0.6), 0.3],
		[de + jato * 1.3, de + jato * 1.3 + Vector3(0, -3.5, 0), randf_range(0.7, 1.1), 0.35],
		[de, de + (jato + Vector3(0, -0.15, 0)).normalized() * 4.0, randf_range(0.6, 1.0), -1.0],
	]
	for t in tiros:
		var q := PhysicsRayQueryParameters3D.create(t[0], t[1], MASCARA_CENARIO, pulo)
		var toque := espaco.intersect_ray(q)
		# o corpo de algum inimigo (ou o do jogador) no caminho nao e' parede
		for _i in 3:
			if toque.is_empty() or not toque["collider"] is CharacterBody3D:
				break
			q.exclude = q.exclude + [toque["rid"]]
			toque = espaco.intersect_ray(q)
		if toque.is_empty() or toque["collider"] is CharacterBody3D:
			continue
		var atraso: float = t[3]
		if atraso < 0.0:
			atraso = 0.05 + de.distance_to(toque["position"]) / 7.0
		_mancha(toque["position"], toque["normal"], t[2], atraso / maxf(speed_scale, 0.01))


func _mancha(onde: Vector3, normal: Vector3, tam: float, atraso: float) -> void:
	var cena := get_tree().current_scene
	if cena == null:
		return
	var d := Decal.new()
	d.texture_albedo = load(RESPINGOS.pick_random())
	d.modulate = Color(randf_range(1.0, 1.3), 0.9, 0.9)
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.size = Vector3(tam, 0.3, tam) * 0.35
	cena.add_child(d)
	# o Decal projeta no -Y: o Y dele vira a normal da superficie
	var y := normal.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x := y.cross(ref).normalized().rotated(y, randf() * TAU)
	d.global_transform = Transform3D(Basis(x, y, x.cross(y)), onde + y * 0.02)
	d.visible = false
	# as de uma cena que ja' foi embora nao contam
	_manchas = _manchas.filter(func(m): return is_instance_valid(m))
	_manchas.append(d)
	while _manchas.size() > MAX_MANCHAS:
		_manchas.pop_front().queue_free()
	var tw := d.create_tween()
	tw.tween_interval(atraso)
	tw.tween_callback(d.show)
	tw.tween_property(d, "size", Vector3(tam, 0.3, tam), 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(VIDA_MANCHA)
	tw.tween_property(d, "modulate:a", 0.0, SUMIR_MANCHA)
	tw.tween_callback(func():
		_manchas.erase(d)
		d.queue_free())


static func _montar_recursos() -> void:
	# a gota: esfera esticada (o `align_y` a deita na direcao do voo)
	var gota := SphereMesh.new()
	gota.radius = 0.011
	gota.height = 0.065
	gota.radial_segments = 6
	gota.rings = 3
	gota.material = _carne(Color(0.45, 0.01, 0.02), 0.18)
	_rec["gota"] = gota
	var pedaco := SphereMesh.new()
	pedaco.radius = 0.02
	pedaco.height = 0.028
	pedaco.radial_segments = 5
	pedaco.rings = 2
	pedaco.material = _carne(Color(0.26, 0.02, 0.02), 0.4)
	_rec["pedaco"] = pedaco
	var nevoa := QuadMesh.new()
	nevoa.size = Vector2(0.32, 0.32)
	var mn := StandardMaterial3D.new()
	mn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mn.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# sem isto o billboard joga fora a escala da particula
	mn.billboard_keep_scale = true
	mn.vertex_color_use_as_albedo = true
	mn.albedo_color = Color(0.5, 0.02, 0.03, 0.75)
	var bola := GradientTexture2D.new()
	bola.fill = GradientTexture2D.FILL_RADIAL
	bola.fill_from = Vector2(0.5, 0.5)
	bola.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	bola.gradient = g
	mn.albedo_texture = bola
	nevoa.material = mn
	_rec["nevoa"] = nevoa
	# o sangue escurece no ar; a nevoa abre e some
	_rec["escurece"] = _rampa([Color(1, 1, 1, 1), Color(0.6, 0.6, 0.6, 1)])
	_rec["dissipa"] = _rampa([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var incha := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(1.0, 1.0))
	incha.curve = c
	_rec["incha"] = incha


## Molhado: pouca rugosidade e reflexo forte, e um fio de emissao pra nao
## sumir no escuro (as igrejas e ruas do jogo sao muito escuras).
static func _carne(cor: Color, rugosidade: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.vertex_color_use_as_albedo = true
	m.roughness = rugosidade
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = cor * 0.8
	return m


static func _rampa(cores: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, cores[0])
	g.set_color(1, cores[1])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
