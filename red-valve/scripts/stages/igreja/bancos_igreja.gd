extends Node3D

## Os bancos da nave da igreja, soltos do modelo pra poderem ser ARRASTADOS:
## no fim da chegada da Dona Nice, quando ela vira monstro, todos voam pras
## naves laterais e o meio da igreja fica livre pra luta. Dali em diante
## (estado >= 1 do evento) eles ja' nascem la', empilhados e com colisao.
##
## O gerador do Blender (`tools/blender/igreja/gerar_igreja.py`) exporta cada
## banco como objeto proprio, `SM_igr_bancoNN_madeira`. Aqui cada um ganha um
## pivo no chao, no meio dele, e uma vaga nas naves laterais.
##
## As vagas sairam de uma sondagem da colisao da igreja: ao norte (-X) a
## escada ocupa z 2-14 e o entulho do buraco z 10-21; ao sul (+X), o entulho e
## o confessionario z 14-21 e o caracol z 29-31. Os pilares das arcadas ficam
## em z 5, 12, 19 e 26 (~1 m pra cada lado), entao o voo cruza a arcada no z
## da vaga, que cai no meio de um vao livre.
##
## Quem cria este no' e' o `cena_dona_nice.gd`; quem manda afastar e' o
## diretor (`afastar_bancos`) ou o evento (`no_canto`, ao recomecar a luta).
##
## O voo e' um estrago (so' no voo, `no_canto` e' sem efeito):
##   - a onda de choque: um anel vermelho escuro correndo o chao a partir
##     dela, com fuligem rente ao piso atras, e a rajada (som);
##   - o teto: po' descendo na nave e pedras e reboco caindo e quicando;
##   - cada banco: poeira de baixo dele quando arranca, lascas de madeira, o
##     rastro no ar e, onde cai, o baque com mais poeira e mais lascas.
## As velas da cena dobram com a rajada (`cena_dona_nice.afastar_bancos`).

const LAYER_CHAO := 2
## z do meio de cada vao livre, por lado. O banco deita ao longo do z.
const VAOS := {-1: [23.3, 29.5], 1: [8.5, 23.3]}
## |x| de cada fileira na nave lateral (a arcada fica em 7, a parede em 12,6).
const COLUNAS := [8.9, 9.8, 10.7, 11.6]
## O voo cruza a arcada a esta altura, e entra na nave lateral por aqui.
const ALTURA_DO_VOO := 2.4
const ENTRADA_X := [5.3, 6.4]
const SOM_BATIDA := "res://assets/sounds/igreja/tapa_chao.ogg"
const SOM_RAJADA := "res://assets/sounds/igreja/rajada_bancos.ogg"
const COR_ONDA := Color(0.95, 0.12, 0.05)
const COR_PEDRA := Color(0.42, 0.39, 0.36)
## A poeira: escura, com um fundo de sangue seco (e' a igreja do ritual).
const COR_POEIRA := Color(0.40, 0.35, 0.32, 0.34)
const COR_FULIGEM := Color(0.34, 0.22, 0.19, 0.7)
const COR_LASCA := Color(0.24, 0.15, 0.09)

var modelo: Node

var _bancos: Array[Dictionary] = []
var _estado := ""   # "" | "voando" | "no_canto"
var _tween: Tween
var _som: AudioStreamPlayer
## Malhas e materiais da poeira, feitos uma vez.
var _fumaca: QuadMesh
var _fuligem: QuadMesh
var _lasca: BoxMesh
var _pedra: BoxMesh


func _ready() -> void:
	_som = AudioStreamPlayer.new()
	_som.stream = load(SOM_BATIDA)
	_som.volume_db = -9.0
	_som.max_polyphony = 4
	add_child(_som)
	if modelo:
		_preparar()


func _preparar() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1983
	var malhas := modelo.find_children("SM_igr_banco*", "MeshInstance3D", true, false)
	malhas.sort_custom(func(a, b): return String(a.name) < String(b.name))
	var por_lado := {-1: [], 1: []}
	for mi in malhas:
		var caixa: AABB = mi.global_transform * mi.get_aabb()
		var c := caixa.get_center()
		var pivo := Node3D.new()
		pivo.name = String(mi.name).replace("SM_igr_", "").replace("_madeira", "")
		add_child(pivo)
		pivo.global_position = Vector3(c.x, caixa.position.y, c.z)
		mi.owner = null
		mi.reparent(pivo, true)
		var b := {
			"pivo": pivo,
			"inicio": pivo.global_transform,
			"lado": -1 if c.x < 0.0 else 1,
			"altura": caixa.size.y,
			"giro": _giro_do_banco(mi),
		}
		por_lado[b["lado"]].append(b)
		_bancos.append(b)
	for lado in por_lado:
		_vagas(por_lado[lado], lado, rnd)


## O angulo (no plano XZ) do comprimento do banco: o eixo dos dois vertices
## mais distantes, vistos de cima.
func _giro_do_banco(mi: MeshInstance3D) -> float:
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var melhor := 0.0
	var eixo := Vector2.RIGHT
	for i in range(0, v.size(), 3):
		for j in range(i + 1, v.size(), 3):
			var d := Vector2(v[j].x - v[i].x, v[j].z - v[i].z)
			if d.length_squared() > melhor:
				melhor = d.length_squared()
				eixo = d
	return atan2(eixo.y, eixo.x)


## Cada banco ganha uma vaga: os da frente no vao da frente, empilhando quando
## o chao acaba. Um pouco torto de proposito — foram jogados, nao arrumados.
func _vagas(lista: Array, lado: int, rnd: RandomNumberGenerator) -> void:
	lista.sort_custom(func(a, b): return a["inicio"].origin.z < b["inicio"].origin.z)
	var pilhas := {}
	var vaos: Array = VAOS[lado]
	var i := 0
	for b in lista:
		var vao: float = vaos[(i / COLUNAS.size()) % vaos.size()]
		var col: float = COLUNAS[i % COLUNAS.size()]
		i += 1
		var chave := "%s_%s" % [vao, col]
		var y: float = pilhas.get(chave, 0.0)
		pilhas[chave] = y + b["altura"] * 0.82
		# o comprimento do banco vai pro eixo Z (ver `_giro_do_banco`)
		var giro: float = b["giro"] - PI * 0.5 + rnd.randf_range(-0.07, 0.07)
		if rnd.randf() < 0.5:
			giro += PI
		var basis := Basis(Vector3.UP, giro)
		if y > 0.0:
			basis = Basis(Vector3(0, 0, 1), rnd.randf_range(-0.18, 0.18)) * basis
		b["alvo"] = Transform3D(basis, Vector3(lado * (col + rnd.randf_range(-0.08, 0.08)),
			y, vao + rnd.randf_range(-0.15, 0.15)))
		b["vao"] = vao
		b["tombo"] = Vector3(rnd.randf_range(-1, 1), 0.0, rnd.randf_range(-1, 1)).normalized()
		b["tombo_ang"] = rnd.randf_range(0.5, 1.3)
		b["atraso"] = 0.12 + rnd.randf_range(0.0, 0.3)
		b["duracao"] = rnd.randf_range(1.0, 1.4)


## Ela os joga: cada banco sai num voo curto, cruza a arcada e cai na vaga.
func afastar() -> void:
	if _estado != "":
		return
	_estado = "voando"
	var centro := Vector3(0.0, 0.0, 18.0)
	_onda(centro)
	_anel_de_choque(centro)
	_varrida(centro)
	_po_do_teto()
	_pedras_do_teto()
	var rajada := AudioStreamPlayer.new()
	rajada.stream = load(SOM_RAJADA)
	rajada.volume_db = 2.0
	add_child(rajada)
	rajada.play()
	rajada.finished.connect(rajada.queue_free)
	_tween = create_tween().set_parallel(true)
	for b in _bancos:
		var longe := clampf(b["inicio"].origin.distance_to(centro) / 16.0, 0.0, 1.0)
		var atraso: float = b["atraso"] + 0.45 * longe
		_tween.tween_callback(_arrancou.bind(b)).set_delay(atraso)
		_tween.tween_method(_voo.bind(b), 0.0, 1.0, b["duracao"]).set_delay(atraso) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_callback(_pousou.bind(b)).set_delay(atraso + b["duracao"])
	_tween.chain().tween_callback(func(): _estado = "no_canto")


## Ja' no lugar, sem voo (o recomeco da luta, e quem pulou a cutscene).
func no_canto() -> void:
	if _estado == "no_canto":
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	for b in _bancos:
		if not b.has("alvo"):
			continue
		(b["pivo"] as Node3D).global_transform = b["alvo"]
		_colisao(b)
	_estado = "no_canto"


func _voo(k: float, b: Dictionary) -> void:
	var p0: Vector3 = b["inicio"].origin
	var p3: Vector3 = b["alvo"].origin
	var lado: float = b["lado"]
	var vao: float = b["vao"]
	# cubica: as duas alcas ficam no z da vaga, entao quando o banco cruza a
	# arcada ele ja' esta' no vao livre, longe dos pilares
	var p1 := Vector3(lado * ENTRADA_X[0], ALTURA_DO_VOO, vao)
	var p2 := Vector3(lado * ENTRADA_X[1], ALTURA_DO_VOO, vao)
	var u := 1.0 - k
	var p := u * u * u * p0 + 3.0 * u * u * k * p1 + 3.0 * u * k * k * p2 + k * k * k * p3
	var q0: Quaternion = b["inicio"].basis.get_rotation_quaternion()
	var q1: Quaternion = b["alvo"].basis.get_rotation_quaternion()
	var q := q0.slerp(q1, k)
	# rodopia no ar e chega reto
	q = Quaternion(b["tombo"], b["tombo_ang"] * sin(PI * k)) * q
	(b["pivo"] as Node3D).global_transform = Transform3D(Basis(q), p)


func _pousou(b: Dictionary) -> void:
	(b["pivo"] as Node3D).global_transform = b["alvo"]
	_colisao(b)
	var rastro := (b["pivo"] as Node3D).get_node_or_null("rastro") as GPUParticles3D
	if rastro:
		rastro.emitting = false
		_soltar(rastro)
	_poeira((b["alvo"] as Transform3D).origin, Vector3(0.6, 0.1, 1.4), 32, 3.0, 1.0, 2.6,
		Vector3.UP, 75.0, Vector2(0.6, 1.6))
	_lascas((b["alvo"] as Transform3D).origin + Vector3.UP * 0.4)
	_som.pitch_scale = randf_range(0.8, 1.15)
	_som.play()


# ------------------------------------------------------------------ poeira
## O banco arranca do chao: a poeira que estava embaixo dele sobe, voam
## lascas, e ele sai puxando um rastro de po'.
func _arrancou(b: Dictionary) -> void:
	var pivo := b["pivo"] as Node3D
	var mi := pivo.get_child(0) as MeshInstance3D
	var caixa: AABB = mi.global_transform * mi.get_aabb()
	var chao := Vector3(caixa.get_center().x, (b["inicio"] as Transform3D).origin.y, caixa.get_center().z)
	_poeira(chao, Vector3(caixa.size.x * 0.5, 0.05, caixa.size.z * 0.5), 44, 3.4, 1.2, 3.0,
		Vector3.UP, 40.0, Vector2(0.3, 1.3))
	_lascas(chao + Vector3.UP * 0.3)
	var rastro := _particulas("rastro", pivo, 40, 1.6, 0.0, _fumaca)
	rastro.position = Vector3(0.0, caixa.size.y * 0.5, 0.0)
	var m := rastro.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.4, 0.2, 0.6)
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.3
	m.gravity = Vector3(0, -0.15, 0)
	m.scale_min = 0.8
	m.scale_max = 1.8
	# solta po' o voo inteiro, ate' pousar
	rastro.one_shot = false
	rastro.emitting = true


## A onda: um anel de fuligem que sai dela rente ao chao, empurrado pra fora,
## e corre a nave inteira.
func _onda(centro: Vector3) -> void:
	var p := _particulas("onda", self, 320, 3.8, 0.92, _fuligem)
	p.global_position = centro + Vector3.UP * 0.15
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 1.2
	m.emission_ring_inner_radius = 0.6
	m.emission_ring_height = 0.1
	m.direction = Vector3.UP
	m.spread = 10.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.5
	m.radial_velocity_min = 7.0
	m.radial_velocity_max = 11.0
	m.damping_min = 2.0
	m.damping_max = 3.2
	m.gravity = Vector3(0, -0.2, 0)
	m.scale_min = 2.0
	m.scale_max = 4.0
	p.emitting = true
	_soltar(p)


## A onda de choque: um anel vermelho escuro rente ao chao, que sai dela e
## varre a nave em menos de um segundo, apagando enquanto corre.
func _anel_de_choque(centro: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(2.0, 2.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = COR_ONDA
	var anel := GradientTexture2D.new()
	anel.fill = GradientTexture2D.FILL_RADIAL
	anel.fill_from = Vector2(0.5, 0.5)
	anel.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.0))
	g.add_point(0.85, Color(1, 1, 1, 1.0))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	anel.gradient = g
	m.albedo_texture = anel
	plano.material = m
	mi.mesh = plano
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = centro + Vector3.UP * 0.04
	mi.scale = Vector3(0.6, 1.0, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(20.0, 1.0, 20.0), 0.95) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.95).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## A rajada em si: poeira na altura do peito saindo dela em todas as
## direcoes, rapida, e freando contra as paredes.
func _varrida(centro: Vector3) -> void:
	var p := _particulas("varrida", self, 180, 2.2, 0.9, _fumaca)
	p.global_position = centro + Vector3.UP * 1.0
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 1.5
	m.emission_ring_inner_radius = 1.0
	m.emission_ring_height = 1.4
	m.direction = Vector3.UP
	m.spread = 15.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.8
	m.radial_velocity_min = 11.0
	m.radial_velocity_max = 16.0
	m.damping_min = 4.0
	m.damping_max = 6.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.6
	m.scale_max = 1.5
	p.emitting = true
	_soltar(p)


## Pedras e reboco soltos do teto: caem na nave e quicam no piso.
func _pedras_do_teto() -> void:
	var chao := GPUParticlesCollisionBox3D.new()
	chao.name = "chao_das_pedras"
	chao.size = Vector3(16.0, 1.0, 36.0)
	add_child(chao)
	chao.global_position = Vector3(0.0, -0.5, 18.0)
	var p := _particulas("pedras", self, 120, 4.0, 0.0, _pedra)
	p.global_position = Vector3(0.0, 9.0, 18.0)
	p.one_shot = false
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(6.0, 0.3, 13.0)
	m.direction = Vector3.DOWN
	m.spread = 10.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 1.0
	m.gravity = Vector3(0, -9.8, 0)
	m.angular_velocity_min = -400.0
	m.angular_velocity_max = 400.0
	m.scale_min = 0.5
	m.scale_max = 2.2
	m.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	m.collision_bounce = 0.25
	m.collision_friction = 0.8
	# pedra nao some aos poucos nem cresce
	m.color_ramp = null
	m.scale_curve = null
	p.collision_base_size = 0.05
	p.emitting = true
	get_tree().create_timer(2.2, false).timeout.connect(func(): p.emitting = false)
	_soltar(p, 2.2)
	get_tree().create_timer(p.lifetime + 3.0, false).timeout.connect(chao.queue_free)


## O tranco solta o po' do teto: cai devagar sobre a nave por varios segundos.
func _po_do_teto() -> void:
	var p := _particulas("po_do_teto", self, 260, 7.0, 0.0, _fumaca)
	p.global_position = Vector3(0.0, 9.0, 18.0)
	p.one_shot = false
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(6.5, 0.5, 14.0)
	m.direction = Vector3.DOWN
	m.spread = 20.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.6
	m.gravity = Vector3(0, -0.35, 0)
	m.damping_min = 0.3
	m.damping_max = 0.6
	m.scale_min = 0.35
	m.scale_max = 1.0
	p.emitting = true
	# para de cair depois de uns segundos e some quando o ultimo grao chega
	get_tree().create_timer(4.0, false).timeout.connect(func(): p.emitting = false)
	_soltar(p, 4.0)


func _poeira(onde: Vector3, caixa: Vector3, quantas: int, vida: float, esc_min: float,
		esc_max: float, rumo: Vector3, abertura: float, vel: Vector2) -> void:
	var p := _particulas("poeira", self, quantas, vida, 0.85, _fumaca)
	p.global_position = onde
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = caixa
	m.direction = rumo
	m.spread = abertura
	m.initial_velocity_min = vel.x
	m.initial_velocity_max = vel.y
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.gravity = Vector3(0, -0.1, 0)
	m.scale_min = esc_min
	m.scale_max = esc_max
	p.emitting = true
	_soltar(p)


func _lascas(onde: Vector3) -> void:
	var p := _particulas("lascas", self, 22, 1.6, 1.0, _lasca)
	p.global_position = onde
	var m := p.process_material as ParticleProcessMaterial
	m.direction = Vector3.UP
	m.spread = 70.0
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 4.5
	m.gravity = Vector3(0, -9.8, 0)
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -600.0
	m.angular_velocity_max = 600.0
	m.scale_min = 0.5
	m.scale_max = 1.4
	# a lasca nao some aos poucos (o rampa da fumaca e' so' pras nuvens)
	m.color_ramp = null
	m.scale_curve = null
	p.emitting = true
	_soltar(p)


## Uma camada de particulas de disparo unico, no mundo (o banco voa, a poeira
## fica). Fumaca cresce e se dissolve; as outras malhas ficam como sao.
func _particulas(nome: String, pai: Node, quantas: int, vida: float, explosao: float,
		malha: Mesh) -> GPUParticles3D:
	if _fumaca == null:
		_montar_poeira()
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = quantas
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = explosao
	p.randomness = 0.5
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-16, -10, -16), Vector3(32, 20, 32))
	p.draw_pass_1 = malha
	var m := ParticleProcessMaterial.new()
	var cresce := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(1.0, 1.0))
	cresce.curve = c
	m.scale_curve = cresce
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.12, Color(1, 1, 1, 1.0))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var rampa := GradientTexture1D.new()
	rampa.gradient = g
	m.color_ramp = rampa
	m.angle_min = -180.0
	m.angle_max = 180.0
	p.process_material = m
	pai.add_child(p)
	return p


func _soltar(p: GPUParticles3D, extra: float = 0.0) -> void:
	get_tree().create_timer(p.lifetime + extra + 0.5, false).timeout.connect(p.queue_free)


func _montar_poeira() -> void:
	var bola := GradientTexture2D.new()
	bola.fill = GradientTexture2D.FILL_RADIAL
	bola.fill_from = Vector2(0.5, 0.5)
	bola.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	# borda bem macia: as nuvens se fundem numa poeira so', sem tufos
	g.set_color(0, Color(1, 1, 1, 0.75))
	g.add_point(0.35, Color(1, 1, 1, 0.35))
	g.add_point(0.7, Color(1, 1, 1, 0.08))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	bola.gradient = g
	_fumaca = _nuvem(COR_POEIRA, bola, 1.0)
	_fuligem = _nuvem(COR_FULIGEM, bola, 0.9)
	_pedra = BoxMesh.new()
	_pedra.size = Vector3(0.12, 0.08, 0.1)
	var reboco := StandardMaterial3D.new()
	reboco.albedo_color = COR_PEDRA
	reboco.roughness = 1.0
	_pedra.material = reboco
	_lasca = BoxMesh.new()
	_lasca.size = Vector3(0.025, 0.012, 0.14)
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = COR_LASCA
	madeira.roughness = 0.9
	_lasca.material = madeira


## Nuvem: um quad virado pra camera (sem perder a escala da particula), com
## sombra propria nenhuma — numa igreja escura o po' cinza e' que aparece.
func _nuvem(cor: Color, tex: Texture2D, tam: float) -> QuadMesh:
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
	m.disable_receive_shadows = true
	q.material = m
	return q


## Empilhado na nave lateral ele vira obstaculo de verdade (na nave, no
## lugar de antes, nunca teve colisao).
func _colisao(b: Dictionary) -> void:
	var pivo := b["pivo"] as Node3D
	if pivo.has_node("corpo"):
		return
	var mi := pivo.get_child(0) as MeshInstance3D
	var caixa: AABB = mi.transform * mi.get_aabb()
	var corpo := StaticBody3D.new()
	corpo.name = "corpo"
	corpo.collision_layer = LAYER_CHAO
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = caixa.size
	forma.shape = box
	forma.position = caixa.get_center()
	corpo.add_child(forma)
	pivo.add_child(corpo)
