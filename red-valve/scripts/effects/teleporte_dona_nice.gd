extends Node3D

## O rastro do teleporte da Dona Nice monstro (as duas fases da igreja).
##
## Onde ela some e onde ela surge fica o mesmo estrago: uma coluna de fumaca
## cor de sangue subindo do chao, brasas da cor da borda do dissolver dela
## (o corpo queima pra sumir), um anel de nevoa escura correndo rente ao
## chao, um clarao vermelho que estoura e apaga no meio, e uma mancha preta
## que fica no piso e desbota. O som e' o sopro
## sugado (`some`) ou o estouro de carne (`surge`).
##
## Use `criar(pai, onde, escala, surgindo)` (preload deste script); o no' se
## apaga sozinho. `escala` 1 = a fase 1 (gente), ~2,4 = a gigante.

const ESTE := "res://scripts/effects/teleporte_dona_nice.gd"
const SOM_SOME := "res://assets/sounds/igreja/teleporte_some.ogg"
const SOM_SURGE := "res://assets/sounds/igreja/teleporte_surge.ogg"
const MANCHA := "res://assets/images/vfx/sangue_respingo_2.png"
const COR_FUMACA := Color(0.32, 0.03, 0.04, 0.75)
const COR_NEVOA := Color(0.26, 0.04, 0.05, 0.6)
const COR_CLARAO := Color(1.0, 0.18, 0.05)
const COR_BRASA := Color(1.0, 0.28, 0.06)

var escala := 1.0
var surgindo := false

static var _rec := {}


static func criar(pai: Node, onde: Vector3, tamanho: float = 1.0, surge: bool = false) -> Node3D:
	var n: Node3D = load(ESTE).new()
	n.escala = tamanho
	n.surgindo = surge
	pai.add_child(n)
	n.global_position = onde
	return n


func _ready() -> void:
	if _rec.is_empty():
		_montar_recursos()
	var e := escala
	# a coluna: sobe do chao ate' a altura dela
	var col := _camada("coluna", 90, 1.8, 0.35, _rec["fumaca"])
	var m := col.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.35, 0.9, 0.35) * e
	col.position = Vector3(0.0, 0.9 * e, 0.0)
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = 0.6 * e
	m.initial_velocity_max = 1.6 * e
	m.damping_min = 0.8
	m.damping_max = 1.4
	m.gravity = Vector3.ZERO
	m.scale_min = 0.6 * e
	m.scale_max = 1.4 * e
	# as brasas: giram subindo em volta do corpo
	var br := _camada("brasas", 70, 1.3, 0.6, _rec["brasa"])
	m = br.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.55 * e
	br.position = Vector3(0.0, 0.9 * e, 0.0)
	m.direction = Vector3.UP
	m.spread = 60.0
	m.initial_velocity_min = 0.8 * e
	m.initial_velocity_max = 2.4 * e
	m.orbit_velocity_min = 0.3
	m.orbit_velocity_max = 0.7
	m.gravity = Vector3(0, 0.6, 0)
	m.damping_min = 0.5
	m.damping_max = 1.0
	m.scale_min = 0.5
	m.scale_max = 1.3
	m.scale_curve = _rec["encolhe"]
	# o anel rente ao chao
	var an := _camada("anel", 60, 1.4, 0.95, _rec["nevoa"])
	m = an.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 0.5 * e
	m.emission_ring_inner_radius = 0.3 * e
	m.emission_ring_height = 0.05
	an.position = Vector3(0.0, 0.12, 0.0)
	m.direction = Vector3.UP
	m.spread = 5.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.2
	m.radial_velocity_min = 3.0 * e
	m.radial_velocity_max = 5.0 * e
	m.damping_min = 3.0
	m.damping_max = 4.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.7 * e
	m.scale_max = 1.4 * e
	for p in [col, br, an]:
		(p as GPUParticles3D).emitting = true
	_mancha()
	_clarao()
	var som := AudioStreamPlayer3D.new()
	som.stream = load(SOM_SURGE if surgindo else SOM_SOME)
	som.unit_size = 10.0 * e
	som.volume_db = 2.0
	som.position = Vector3(0.0, 1.0 * e, 0.0)
	add_child(som)
	som.play()
	get_tree().create_timer(6.0, false).timeout.connect(queue_free)


## A marca no chao: preta, com a borda de sangue. Fica no cenario (o efeito
## se apaga antes dela) e desbota.
func _mancha() -> void:
	var cena := get_tree().current_scene
	if cena == null:
		return
	var d := Decal.new()
	d.texture_albedo = load(MANCHA)
	d.modulate = Color(0.35, 0.12, 0.12, 0.0)
	d.size = Vector3(1.8, 0.6, 1.8) * escala
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	cena.add_child(d)
	d.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), global_position)
	var tw := d.create_tween()
	tw.tween_property(d, "modulate:a", 1.0, 0.4)
	tw.tween_interval(8.0)
	tw.tween_property(d, "modulate:a", 0.0, 3.0)
	tw.tween_callback(d.queue_free)


## Um brilho vermelho do tamanho dela que estoura e apaga (soma luz: nao
## usa as omni da igreja, que ja' estao no teto do renderer mobile).
func _clarao() -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0) * escala
	var m := (_rec["clarao"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	q.material = m
	mi.mesh = q
	mi.position = Vector3(0.0, 0.9 * escala, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.scale = Vector3.ONE * 0.3
	m.albedo_color.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.45, 0.08)
	tw.chain().tween_property(m, "albedo_color:a", 0.0, 0.45)


func _camada(nome: String, quantas: int, vida: float, explosao: float, malha: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = quantas
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = explosao
	p.randomness = 0.5
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-6, -1, -6) * escala, Vector3(12, 12, 12) * escala)
	p.draw_pass_1 = malha
	var m := ParticleProcessMaterial.new()
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.scale_curve = _rec["cresce"]
	m.color_ramp = _rec["some"]
	p.process_material = m
	add_child(p)
	return p


static func _montar_recursos() -> void:
	var bola := GradientTexture2D.new()
	bola.fill = GradientTexture2D.FILL_RADIAL
	bola.fill_from = Vector2(0.5, 0.5)
	bola.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.add_point(0.4, Color(1, 1, 1, 0.4))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	bola.gradient = g
	_rec["fumaca"] = _quad(COR_FUMACA, bola, 0.9, false)
	_rec["nevoa"] = _quad(COR_NEVOA, bola, 1.1, false)
	_rec["brasa"] = _quad(COR_BRASA, bola, 0.09, true)
	var clarao := _quad(COR_CLARAO, bola, 1.0, true).material as StandardMaterial3D
	clarao.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	clarao.vertex_color_use_as_albedo = false
	clarao.albedo_color = Color(COR_CLARAO.r * 0.9, COR_CLARAO.g * 0.9, COR_CLARAO.b * 0.9, 1.0)
	# o miolo soma, a borda some: sem o disco chapado do gradiente da fumaca
	var miolo := GradientTexture2D.new()
	miolo.fill = GradientTexture2D.FILL_RADIAL
	miolo.fill_from = Vector2(0.5, 0.5)
	miolo.fill_to = Vector2(1.0, 0.5)
	var gm := Gradient.new()
	gm.set_color(0, Color(1, 1, 1, 1))
	gm.add_point(0.25, Color(1, 1, 1, 0.45))
	gm.add_point(0.6, Color(1, 1, 1, 0.08))
	gm.set_color(gm.get_point_count() - 1, Color(1, 1, 1, 0))
	miolo.gradient = gm
	clarao.albedo_texture = miolo
	_rec["clarao"] = clarao
	var cresce := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(1.0, 1.0))
	cresce.curve = c
	_rec["cresce"] = cresce
	var encolhe := CurveTexture.new()
	var c2 := Curve.new()
	c2.add_point(Vector2(0.0, 1.0))
	c2.add_point(Vector2(1.0, 0.0))
	encolhe.curve = c2
	_rec["encolhe"] = encolhe
	var gs := Gradient.new()
	gs.set_color(0, Color(1, 1, 1, 0.0))
	gs.add_point(0.1, Color(1, 1, 1, 1.0))
	gs.set_color(gs.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var some := GradientTexture1D.new()
	some.gradient = gs
	_rec["some"] = some


## Um quad virado pra camera (com a escala da particula). As brasas somam luz
## (brilham no escuro); a fumaca cobre.
static func _quad(cor: Color, tex: Texture2D, tam: float, brilha: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = cor
	m.albedo_texture = tex
	if brilha:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(cor.r * 2.5, cor.g * 2.5, cor.b * 2.5, 1.0)
	q.material = m
	return q
