extends Node3D
## Fogo do Maycow parasita (GAMEPLAY) — mão esquerda e braço esquerdo.
##
## É um efeito SEPARADO do hand_fire.tscn, que é o take da mão no trailer e
## deve continuar como está. A leitura aqui é outra:
##
##   * a pele vira crosta de lava rachada (parasite_fire.gdshader);
##   * a chama é feita de poucas partículas GRANDES e bem transparentes, que se
##     sobrepõem e borram — em vez de línguas nítidas, que denunciam o "desenho"
##     da partícula quando ficam muito visíveis;
##   * as partículas vivem em coordenadas de MUNDO (local_coords = false), então
##     não ficam grudadas na mão: ficam para trás e viram rastro.
##
## Opcionalmente o fogo pode ficar preso a um membro (máscara em cápsula entre
## dois ossos), para queimar só o braço esquerdo de um corpo inteiro.
##
## Uso:
##     var f = preload("res://scenes/effects/parasite_fire.tscn").instantiate()
##     f.mask_skeleton = skel        # opcional
##     f.mask_bone_from = "LeftArm"  # opcional
##     f.mask_bone_to = "LeftHand"   # opcional
##     alvo.add_child(f)
##     f.ignite(alvo)

const FIRE_SHADER := preload("res://shaders/effects/parasite_fire.gdshader")
const SMOKE_TEX := preload("res://assets/images/vfx/smoke.png")

## Tempo até a lava tomar o membro inteiro.
@export var fade_in: float = 1.4
## Multiplicador geral do tamanho das chamas.
@export var flame_scale: float = 1.0
## Opacidade das chamas. Baixo de propósito: é a soma de várias camadas quase
## transparentes que dá o aspecto embaçado.
@export_range(0.0, 1.0) var flame_opacity: float = 0.13
## Quanto tempo o rastro fica no ar depois de a mão passar.
@export var trail_life: float = 0.9
## Brilho da lava na pele.
@export var lava_intensity: float = 1.5
## Quanto a crosta cobre a pele original (1 = cobre tudo).
@export_range(0.0, 1.0) var crust_opacity: float = 0.7
@export var light_energy: float = 1.6
@export var light_range: float = 2.4

@export_group("Máscara por osso")
## Preenchendo os três, o fogo fica preso a UM membro da malha, acompanhando
## qualquer animação. Precisa ser configurado ANTES de chamar ignite().
@export var mask_bone_from: String = ""
@export var mask_bone_to: String = ""
## Raio da cápsula, em unidades de mundo. 0 = calcula pelo comprimento do membro.
@export var mask_radius: float = 0.0
var mask_skeleton: Skeleton3D

const MASK_POINTS := 32

var _meshes: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _emitters: Array[CPUParticles3D] = []

var _ignite: float = 0.0
var _time: float = 0.0
var _size: float = 0.2
var _extents: Vector3 = Vector3.ONE * 0.1
var _burning: bool = false

var _mask_active: bool = false
var _bone_from: int = -1
var _bone_to: int = -1
var _mask_radius: float = 0.1
var _mask_a: Vector3 = Vector3.ZERO
var _mask_b: Vector3 = Vector3.ZERO


func _ready() -> void:
	set_process(false)


## Acende. `target` é a raiz cujas malhas viram lava.
func ignite(target: Node3D) -> void:
	_collect_meshes(target)
	if _meshes.is_empty():
		push_warning("parasite_fire: nenhum MeshInstance3D em %s" % target.name)
		return
	_setup_mask()
	_measure()
	_apply_skin_material()
	_build_particles()
	_build_light()
	_burning = true
	set_process(true)


func _collect_meshes(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		_meshes.append(mi)
	for c in node.get_children():
		_collect_meshes(c)


func _setup_mask() -> void:
	if mask_skeleton == null or mask_bone_from.is_empty() or mask_bone_to.is_empty():
		return
	_bone_from = mask_skeleton.find_bone(mask_bone_from)
	_bone_to = mask_skeleton.find_bone(mask_bone_to)
	if _bone_from < 0 or _bone_to < 0:
		push_warning("parasite_fire: osso não encontrado (%s / %s)"
			% [mask_bone_from, mask_bone_to])
		return
	_mask_active = true
	_update_mask()
	if mask_radius > 0.0:
		_mask_radius = mask_radius
	else:
		# Um membro tem raio bem menor que o próprio comprimento; 18% cobre o
		# braço sem lamber o tronco.
		_mask_radius = maxf(_mask_a.distance_to(_mask_b) * 0.18, 0.02)


## Pontas da cápsula, em MUNDO. Recalculado a cada quadro: o braço se mexe.
func _update_mask() -> void:
	if _bone_from < 0 or not is_instance_valid(mask_skeleton):
		return
	var sk := mask_skeleton.global_transform
	_mask_a = sk * mask_skeleton.get_bone_global_pose(_bone_from).origin
	_mask_b = sk * mask_skeleton.get_bone_global_pose(_bone_to).origin


## Dimensiona tudo pelo que REALMENTE vai queimar: o membro quando há máscara,
## a malha inteira quando não há.
func _measure() -> void:
	if _mask_active:
		_extents = Vector3.ONE * _mask_radius
		_size = maxf(_mask_radius * 2.0, 0.02)
		return
	var box := AABB()
	var first := true
	for mi in _meshes:
		var b: AABB = mi.global_transform * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	_extents = box.size * 0.5
	_size = max(box.size.x, max(box.size.y, box.size.z))
	if _size <= 0.0001:
		_size = 0.2


func _apply_skin_material() -> void:
	for mi in _meshes:
		var mat := ShaderMaterial.new()
		mat.shader = FIRE_SHADER
		mat.set_shader_parameter("noise_tex", _make_noise())
		mat.set_shader_parameter("ignite", 0.0)
		mat.set_shader_parameter("lava_energy", lava_intensity)
		mat.set_shader_parameter("crust_opacity", crust_opacity)
		# O ruído é medido em espaço de objeto: a escala sai do tamanho do que
		# vai queimar, para dar sempre a mesma densidade de rachaduras.
		var local_size: float = maxf(mi.get_aabb().size.length(), 0.0001)
		if _mask_active:
			var mesh_scale: float = maxf(mi.global_transform.basis.get_scale().x, 0.0001)
			local_size = maxf(_mask_a.distance_to(_mask_b) / mesh_scale, 0.0001)
		mat.set_shader_parameter("noise_scale", 7.0 / local_size)
		mat.set_shader_parameter("scroll_speed", local_size * 0.05)
		mat.set_shader_parameter("inflate", local_size * 0.004)
		if _mask_active:
			mat.set_shader_parameter("mask_enabled", 1.0)
			mat.set_shader_parameter("mask_feather", _mask_radius * 0.5)
		mi.material_overlay = mat
		_mats.append(mat)


func _make_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	return tex


## Borrão radial puro: um degradê do centro para fora, sem nenhum desenho.
## É o que dá o aspecto embaçado — qualquer textura com forma reconhecível
## denuncia a partícula assim que ela fica grande na tela.
func _soft_radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = [0.0, 0.3, 0.65, 1.0]
	g.colors = [
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.6),
		Color(1, 1, 1, 0.2),
		Color(1, 1, 1, 0.0),
	]
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 1.0)
	return t


## Puff transparente. Sozinho não tem forma; é a soma de vários, cada um com
## rotação e tamanho próprios, que vira uma mancha de fogo.
func _soft_puff(size: Vector2, tex: Texture2D) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.disable_receive_shadows = true
	# Sem emission: em blend aditivo ela dobra o brilho e mata a sutileza.

	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = mat
	return mesh


## Sem branco: o branco é o que faz partícula grande parecer fumaça de vapor.
func _ramps(peak_alpha: float, fade_in_frac: float) -> Array:
	var initial := Gradient.new()
	initial.offsets = [0.0, 0.4, 1.0]
	initial.colors = [
		Color(1.0, 0.55, 0.14, 1.0),
		Color(1.0, 0.3, 0.04, 1.0),
		Color(0.7, 0.1, 0.01, 1.0),
	]
	var alpha := Gradient.new()
	alpha.offsets = [0.0, fade_in_frac, 0.55, 1.0]
	alpha.colors = [
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, peak_alpha),
		Color(1, 1, 1, peak_alpha * 0.6),
		Color(1, 1, 1, 0.0),
	]
	return [initial, alpha]


func _build_particles() -> void:
	var s := _size

	# --- corpo da chama: poucas e enormes, quase transparentes ---
	var haze := CPUParticles3D.new()
	haze.name = "haze"
	haze.amount = 24
	haze.lifetime = trail_life
	# MUNDO, não local: é isto que faz o fogo ficar para trás e virar rastro
	# em vez de acompanhar a mão colado.
	haze.local_coords = false
	haze.direction = Vector3.UP
	haze.spread = 22.0
	haze.gravity = Vector3(0, 0.9 * s, 0)
	haze.initial_velocity_min = 0.1 * s
	haze.initial_velocity_max = 0.7 * s
	haze.damping_min = 1.5 * s
	haze.damping_max = 3.0 * s
	haze.angle_min = -180.0
	haze.angle_max = 180.0
	haze.angular_velocity_min = -25.0
	haze.angular_velocity_max = 25.0
	var haze_curve := Curve.new()
	haze_curve.add_point(Vector2(0.0, 0.55))
	haze_curve.add_point(Vector2(0.45, 1.0))
	haze_curve.add_point(Vector2(1.0, 1.35))
	haze.scale_amount_min = 0.8 * flame_scale
	haze.scale_amount_max = 1.5 * flame_scale
	haze.scale_amount_curve = haze_curve
	var haze_ramps := _ramps(flame_opacity, 0.18)
	haze.color_initial_ramp = haze_ramps[0]
	haze.color_ramp = haze_ramps[1]
	# Esticado na vertical: mesmo sendo só um degradê, lê como língua de fogo.
	haze.mesh = _soft_puff(Vector2(s * 0.34, s * 0.62), _soft_radial())
	_add_emitter(haze)

	# --- núcleo: menor, mais quente, vida curta, colado no membro ---
	var core := CPUParticles3D.new()
	core.name = "core"
	core.amount = 18
	core.lifetime = trail_life * 0.45
	core.local_coords = false
	core.direction = Vector3.UP
	core.spread = 20.0
	core.gravity = Vector3(0, 1.3 * s, 0)
	core.initial_velocity_min = 0.15 * s
	core.initial_velocity_max = 0.6 * s
	core.damping_min = 2.0 * s
	core.damping_max = 3.5 * s
	core.angle_min = -180.0
	core.angle_max = 180.0
	var core_curve := Curve.new()
	core_curve.add_point(Vector2(0.0, 0.7))
	core_curve.add_point(Vector2(1.0, 0.2))
	core.scale_amount_min = 0.45 * flame_scale
	core.scale_amount_max = 0.8 * flame_scale
	core.scale_amount_curve = core_curve
	var core_ramps := _ramps(flame_opacity * 1.3, 0.12)
	core.color_initial_ramp = core_ramps[0]
	core.color_ramp = core_ramps[1]
	core.mesh = _soft_puff(Vector2(s * 0.22, s * 0.4), SMOKE_TEX)
	_add_emitter(core)

	# --- brasas: o que dá a leitura de "rastro" quando a mão se move rápido ---
	var ember := CPUParticles3D.new()
	ember.name = "embers"
	ember.amount = 26
	ember.lifetime = trail_life * 1.6
	ember.local_coords = false
	ember.direction = Vector3.UP
	ember.spread = 45.0
	ember.gravity = Vector3(0, 0.7 * s, 0)
	ember.initial_velocity_min = 0.4 * s
	ember.initial_velocity_max = 1.6 * s
	ember.damping_min = 1.0 * s
	ember.damping_max = 2.2 * s
	var ember_curve := Curve.new()
	ember_curve.add_point(Vector2(0.0, 1.0))
	ember_curve.add_point(Vector2(1.0, 0.05))
	ember.scale_amount_min = 0.5 * flame_scale
	ember.scale_amount_max = 1.0 * flame_scale
	ember.scale_amount_curve = ember_curve
	var ember_ramps := _ramps(0.85, 0.08)
	ember.color_initial_ramp = ember_ramps[0]
	ember.color_ramp = ember_ramps[1]
	ember.mesh = _soft_puff(Vector2(s * 0.06, s * 0.06), _soft_radial())
	_add_emitter(ember)


func _add_emitter(p: CPUParticles3D) -> void:
	p.emitting = false
	if _mask_active:
		# Nascem ao longo do osso: a chama gruda no membro em qualquer pose.
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		p.emission_points = _mask_points()
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = _extents * 0.7
	add_child(p)
	_emitters.append(p)


## Pontos ao longo da cápsula, em espaço LOCAL deste nó (que fica no meio do
## membro, com os eixos do mundo).
func _mask_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var mid := (_mask_a + _mask_b) * 0.5
	for i in range(MASK_POINTS):
		var t := float(i) / float(MASK_POINTS - 1)
		var base := _mask_a.lerp(_mask_b, t)
		var jitter := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * _mask_radius * 1.2
		pts.append(base + jitter - mid)
	return pts


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "fire_light"
	_light.light_color = Color(1.0, 0.45, 0.15)
	_light.light_energy = 0.0
	_light.omni_range = light_range * maxf(_size / 0.2, 0.5)
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	if not _burning:
		return
	_time += delta
	_ignite = minf(_ignite + delta / maxf(fade_in, 0.001), 1.0)

	# Este nó fica no centro do que queima, com os eixos alinhados ao MUNDO:
	# assim a chama sobe de verdade, sem herdar a inclinação da câmera ou do
	# osso. As partículas, sendo globais, ficam onde nasceram.
	if _mask_active:
		_update_mask()
		global_transform = Transform3D(Basis.IDENTITY, (_mask_a + _mask_b) * 0.5)
		var pts := _mask_points()
		for p in _emitters:
			p.emission_points = pts
	else:
		var box := AABB()
		var first := true
		for mi in _meshes:
			if not is_instance_valid(mi):
				continue
			var b: AABB = mi.global_transform * mi.get_aabb()
			if first:
				box = b
				first = false
			else:
				box = box.merge(b)
		if not first:
			global_transform = Transform3D(Basis.IDENTITY, box.get_center())

	_update_materials()
	_start_emitters()
	_update_light()


func _update_materials() -> void:
	for i in range(_meshes.size()):
		var mi := _meshes[i]
		if not is_instance_valid(mi):
			continue
		var mat := _mats[i]
		mat.set_shader_parameter("ignite", _ignite)
		var up: Vector3 = (mi.global_transform.basis.inverse() * Vector3.UP).normalized()
		mat.set_shader_parameter("local_up", up)
		var aabb := mi.get_aabb()
		var lo: float = INF
		var hi: float = -INF
		for c in range(8):
			var d: float = aabb.get_endpoint(c).dot(up)
			lo = minf(lo, d)
			hi = maxf(hi, d)
		mat.set_shader_parameter("h_min", lo)
		mat.set_shader_parameter("h_max", hi)
		if _mask_active:
			var inv := mi.global_transform.affine_inverse()
			mat.set_shader_parameter("mask_a", inv * _mask_a)
			mat.set_shader_parameter("mask_b", inv * _mask_b)
			mat.set_shader_parameter("mask_radius",
				_mask_radius / maxf(mi.global_transform.basis.get_scale().x, 0.0001))


func _start_emitters() -> void:
	for i in range(_emitters.size()):
		var start: float = 0.05 + float(i) * 0.2
		if not _emitters[i].emitting and _time >= start:
			_emitters[i].emitting = true


func _update_light() -> void:
	if _light == null:
		return
	# Tremulação lenta: lava não pisca como fogueira.
	var f: float = 0.8 \
		+ 0.11 * sin(_time * 5.3) \
		+ 0.09 * sin(_time * 9.1 + 1.1)
	_light.light_energy = light_energy * _ignite * f


## Apaga suavemente e devolve a pele ao normal.
func extinguish(duration: float = 1.0) -> void:
	_burning = false
	for p in _emitters:
		p.emitting = false
	var tw := create_tween()
	tw.set_parallel(true)
	for mat in _mats:
		var m := mat
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("ignite", v),
			_ignite, 0.0, duration)
	if _light:
		tw.tween_property(_light, "light_energy", 0.0, duration)
