extends RefCounted

## O sangue dos lekrosos: tudo o que nao e' o impacto de tiro (esse continua
## sendo o `sangue_tiro.tscn`, o mesmo de todo inimigo).
##
##   mancha()   uma mancha deitada no chao: rastro esticado, gota, respingo
##   poca()     a poca que cresce devagar embaixo de uma peca ou do corpo
##   pingos()   o que escorre de uma parte do corpo e cai
##   jorro()    o jato que pulsa de um coto aberto (com `pulsar()`)
##   estouro()  o respingo de uma vez so' de um pedaco que saiu
##
## AS MANCHAS NAO SAO DECAL. O renderer mobile aplica no maximo 8 decals por
## malha, e o chao de uma rua inteira (o terreno, o asfalto) e' uma malha so':
## com o rastro, as gotas e as pocas no mesmo pedaco de chao, quase nada
## aparecia — nem a poca embaixo do corpo. Aqui cada textura e' UMA MultiMesh
## de quadrados deitados (um draw call cada, sem teto por malha), num no' so'
## pendurado na cena atual. Cada instancia nasce, cresce, fica e desbota
## sozinha; passou do teto, a mais velha da vez e' reaproveitada.

const TEX_POCA := "res://assets/images/textures/igreja/sangue_poca.png"
const TEX_RESPINGO := "res://assets/images/textures/igreja/sangue_respingo.png"
const RESPINGOS := [
	"res://assets/images/vfx/sangue_respingo_1.png",
	"res://assets/images/vfx/sangue_respingo_2.png",
	"res://assets/images/vfx/sangue_respingo_3.png",
]

## Chao e paredes (camada 2 = chao fisico; 1 = cenario). Inimigos e jogador
## ficam fora.
const MASCARA_CHAO := 3
## Quantas manchas cabem por textura (a mais velha e' reaproveitada).
const MAX_POR_TEXTURA := 110

static var _rec := {}
static var _chao: Chao


# ============================================================ manchas

## Uma mancha no ponto `onde`, deitada na superficie de normal `normal`.
## `tipo`: "rastro" (esticada na direcao `giro`) | "gota" | "respingo" |
## "poca". `giro` = angulo em volta da normal (INF = sorteado).
static func mancha(arvore: SceneTree, onde: Vector3, normal: Vector3, tam: float,
		tipo: String = "respingo", vida: float = 40.0, giro: float = INF,
		atraso: float = 0.0) -> void:
	var chao := _no_chao(arvore)
	if chao == null:
		return
	var textura: String
	var largura := tam
	var comprimento := tam
	match tipo:
		"rastro":
			# o arrastado: um respingo esticado no sentido do passo
			textura = RESPINGOS[randi() % RESPINGOS.size()]
			largura = tam * 0.45
			comprimento = tam * 1.25
		"poca":
			textura = TEX_POCA
		"gota":
			textura = RESPINGOS[randi() % RESPINGOS.size()]
		_:
			textura = TEX_RESPINGO if randf() < 0.5 else RESPINGOS[randi() % RESPINGOS.size()]
	var ang := randf() * TAU if giro == INF else giro
	var cor := Color(randf_range(0.62, 0.85), randf_range(0.42, 0.55), randf_range(0.42, 0.55))
	chao.por(textura, onde, normal, ang, largura, comprimento, cor, vida, atraso, 0.18)


## Uma poca que CRESCE: comeca a um quarto do tamanho e se espalha em
## `duracao` segundos.
static func poca(arvore: SceneTree, mundo: World3D, de: Vector3, tam_final: float,
		duracao: float = 5.0, vida: float = 60.0) -> void:
	var c := chao(mundo, de + Vector3.UP * 0.4, 3.0)
	if c.is_empty():
		return
	var chao_no := _no_chao(arvore)
	if chao_no == null:
		return
	var cor := Color(randf_range(0.7, 0.85), 0.5, 0.5)
	chao_no.por(TEX_POCA, c["position"], c["normal"], randf() * TAU, tam_final, tam_final,
		cor, vida, 0.0, duracao)


## Raio pra baixo a partir de `de`: o chao (posicao, normal) ou vazio.
static func chao(mundo: World3D, de: Vector3, alcance: float = 4.0,
		fora: Array = []) -> Dictionary:
	if mundo == null:
		return {}
	var pular: Array[RID] = []
	pular.assign(fora)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * alcance, MASCARA_CHAO, pular)
	return mundo.direct_space_state.intersect_ray(q)


static func _no_chao(arvore: SceneTree) -> Chao:
	if arvore == null or arvore.current_scene == null:
		return null
	if is_instance_valid(_chao) and _chao.is_inside_tree() \
			and _chao.get_parent() == arvore.current_scene:
		return _chao
	_chao = Chao.new()
	_chao.name = "lekroso_sangue_no_chao"
	arvore.current_scene.add_child(_chao)
	return _chao


## O no' das manchas: uma MultiMesh por textura, envelhecendo as instancias.
class Chao extends Node3D:
	var _camadas := {}
	var _tempo: float = 0.0
	var _relogio: float = 0.0

	func por(textura: String, onde: Vector3, normal: Vector3, giro: float, largura: float,
			comprimento: float, cor: Color, vida: float, atraso: float, crescer: float) -> void:
		var c: Dictionary = _camada(textura)
		var i: int = c["prox"]
		c["prox"] = (i + 1) % MAX_POR_TEXTURA
		var y := normal.normalized()
		var ref := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var x := y.cross(ref).normalized().rotated(y, giro)
		var z := x.cross(y).normalized()
		# 4 mm acima do chao: rente, briga com ele (z-fighting)
		c["base"][i] = Transform3D(Basis(x, y, z), onde + y * 0.004)
		c["tam"][i] = Vector2(largura, comprimento)
		c["nasce"][i] = _tempo + atraso
		c["vida"][i] = vida
		c["cresce"][i] = maxf(crescer, 0.01)
		c["cor"][i] = cor
		c["ativa"][i] = true
		_aplica(c, i)

	func _camada(textura: String) -> Dictionary:
		if _camadas.has(textura):
			return _camadas[textura]
		var plano := PlaneMesh.new()
		plano.size = Vector2.ONE
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(textura)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.22
		mat.metallic_specular = 0.7
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		plano.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = plano
		mm.instance_count = MAX_POR_TEXTURA
		var zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		for k in MAX_POR_TEXTURA:
			mm.set_instance_transform(k, zero)
			mm.set_instance_color(k, Color(1, 1, 1, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		var c := {
			"mm": mm, "prox": 0,
			"base": [], "tam": [], "nasce": PackedFloat32Array(), "vida": PackedFloat32Array(),
			"cresce": PackedFloat32Array(), "cor": [], "ativa": [],
		}
		c["base"].resize(MAX_POR_TEXTURA)
		c["tam"].resize(MAX_POR_TEXTURA)
		c["nasce"].resize(MAX_POR_TEXTURA)
		c["vida"].resize(MAX_POR_TEXTURA)
		c["cresce"].resize(MAX_POR_TEXTURA)
		c["cor"].resize(MAX_POR_TEXTURA)
		c["ativa"].resize(MAX_POR_TEXTURA)
		c["ativa"].fill(false)
		_camadas[textura] = c
		return c

	func _process(delta: float) -> void:
		_tempo += delta
		_relogio -= delta
		if _relogio > 0.0:
			return
		_relogio = 0.08
		for c in _camadas.values():
			for i in MAX_POR_TEXTURA:
				if c["ativa"][i]:
					_aplica(c, i)

	func _aplica(c: Dictionary, i: int) -> void:
		var mm: MultiMesh = c["mm"]
		var t: float = _tempo - c["nasce"][i]
		var vida: float = c["vida"][i]
		var cor: Color = c["cor"][i]
		if t < 0.0:
			mm.set_instance_color(i, Color(cor, 0.0))
			return
		if t > vida + 4.0:
			c["ativa"][i] = false
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			return
		var k := clampf(t / float(c["cresce"][i]), 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		var tam: Vector2 = c["tam"][i] * lerpf(0.3, 1.0, k)
		var base: Transform3D = c["base"][i]
		mm.set_instance_transform(i, Transform3D(base.basis * Basis.from_scale(Vector3(tam.x, 1.0, tam.y)),
			base.origin))
		var a := 1.0 if t < vida else 1.0 - (t - vida) / 4.0
		mm.set_instance_color(i, Color(cor, clampf(a, 0.0, 1.0)))


# ============================================================ particulas

## Pingos que escorrem e caem. Fica no mundo (local_coords false): a parte do
## corpo anda, a gota nao. `forca` 0..1 controla a quantidade.
static func pingos(forca: float = 0.5) -> GPUParticles3D:
	_montar()
	var p := GPUParticles3D.new()
	p.name = "pingos"
	p.amount = maxi(2, int(round(lerpf(3.0, 12.0, forca))))
	p.lifetime = 1.3
	p.explosiveness = 0.0
	p.randomness = 0.8
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-2, -3, -2), Vector3(4, 4, 4))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.DOWN
	m.spread = 12.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.25
	m.gravity = Vector3(0, -9.8, 0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.02
	m.scale_min = 0.45
	m.scale_max = 0.9
	m.particle_flag_align_y = true
	m.color_ramp = _rec["escurece"]
	p.process_material = m
	p.draw_pass_1 = _rec["gota"]
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## O jato do coto. `-Z` do no' e' a direcao do jato (use `look_at`).
static func jorro(forca: float = 1.0) -> GPUParticles3D:
	_montar()
	var p := GPUParticles3D.new()
	p.name = "jorro"
	p.amount = int(round(lerpf(28.0, 64.0, forca)))
	p.lifetime = 0.9
	p.explosiveness = 0.55
	p.randomness = 0.5
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, -1)
	m.spread = 14.0
	m.initial_velocity_min = 1.4 * forca + 0.6
	m.initial_velocity_max = 3.2 * forca + 0.8
	m.gravity = Vector3(0, -9.8, 0)
	m.damping_min = 0.3
	m.damping_max = 1.0
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.018
	m.scale_min = 0.45
	m.scale_max = 1.1
	m.particle_flag_align_y = true
	m.color_ramp = _rec["escurece"]
	p.process_material = m
	p.draw_pass_1 = _rec["gota"]
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Faz o jorro pulsar por `duracao` segundos: a cada golfada `amount_ratio`
## sobe e cai, e a forca geral mingua. Termina so' pingando.
static func pulsar(jato: GPUParticles3D, duracao: float, ritmo: float = 0.55) -> void:
	if not is_instance_valid(jato):
		return
	jato.emitting = true
	var tw := jato.create_tween()
	var golfadas := maxi(1, int(duracao / ritmo))
	for i in golfadas:
		var k := 1.0 - float(i) / float(golfadas)
		tw.tween_property(jato, "amount_ratio", clampf(0.35 + 0.65 * k, 0.05, 1.0), ritmo * 0.25)
		tw.tween_property(jato, "amount_ratio", clampf(0.08 * k, 0.02, 1.0), ritmo * 0.75)
		tw.parallel().tween_property(jato, "speed_scale", lerpf(0.55, 1.0, k), ritmo * 0.75)
	tw.tween_callback(func(): jato.emitting = false)


## Respingos curtos de carne no lugar de um pedaco que saiu (uma vez so').
static func estouro(pai: Node, onde: Vector3, para: Vector3, forca: float = 1.0) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var j := jorro(forca)
	j.one_shot = true
	j.explosiveness = 0.9
	j.amount = int(round(lerpf(20.0, 50.0, forca)))
	pai.add_child(j)
	j.global_position = onde
	var alvo := onde + (para if para.length() > 0.01 else Vector3.UP)
	if absf(para.normalized().dot(Vector3.UP)) > 0.98:
		j.look_at(alvo, Vector3.FORWARD)
	else:
		j.look_at(alvo, Vector3.UP)
	j.restart()
	j.finished.connect(j.queue_free)


# ============================================================ som

static func som(pai: Node, onde: Vector3, caminho: String, volume: float = 0.0,
		tom: float = 1.0, alcance: float = 22.0) -> void:
	if pai == null or not pai.is_inside_tree() or pai.get_tree().current_scene == null:
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(caminho)
	s.volume_db = volume
	s.pitch_scale = tom
	s.max_distance = alcance
	s.unit_size = 3.0
	pai.get_tree().current_scene.add_child(s)
	s.global_position = onde
	s.play()
	s.finished.connect(s.queue_free)


# ============================================================ recursos

static func _montar() -> void:
	if _rec.has("gota"):
		return
	# a gota: esfera esticada (o `align_y` a deita na direcao do voo)
	var gota := SphereMesh.new()
	gota.radius = 0.006
	gota.height = 0.036
	gota.radial_segments = 6
	gota.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.01, 0.02)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.15
	m.metallic_specular = 0.8
	# um fio de emissao pra nao sumir nas ruas escuras (e no filtro PS1)
	m.emission_enabled = true
	m.emission = Color(0.09, 0.0, 0.005)
	gota.material = m
	_rec["gota"] = gota
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(0.55, 0.5, 0.5, 1))
	var rampa := GradientTexture1D.new()
	rampa.gradient = g
	_rec["escurece"] = rampa
