extends Node3D
## Põe fogo numa mão (ou em qualquer Node3D com malhas) em primeira pessoa.
##
## São três coisas somadas, porque nenhuma delas sozinha convence:
##   1. a própria pele carboniza e queima (material_overlay com hand_fire.gdshader);
##   2. chama, brasas e fumaça saindo do volume da mão (CPUParticles3D);
##   3. uma luz laranja tremeluzente, que é o que faz o resto da cena reagir.
##
## Uso:
##     var fogo = preload("res://scenes/effects/hand_fire.tscn").instantiate()
##     mao.add_child(fogo)
##     fogo.ignite(mao)

const FIRE_SHADER := preload("res://shaders/effects/hand_fire.gdshader")
const SMOKE_TEX := preload("res://assets/images/vfx/smoke.png")

## Tempo até o fogo tomar a mão inteira.
@export var fade_in: float = 1.1
## Multiplicador geral do tamanho das chamas.
@export var flame_scale: float = 1.0
@export var light_energy: float = 3.2
@export var light_range: float = 2.2

var _target: Node3D
var _meshes: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _emitters: Array[CPUParticles3D] = []

var _ignite: float = 0.0
var _time: float = 0.0
var _size: float = 0.2
var _extents: Vector3 = Vector3.ONE * 0.1
var _burning: bool = false


## Acende. `target` é a raiz cujas malhas vão queimar (normalmente o pai deste nó).
func ignite(target: Node3D) -> void:
	_target = target
	_collect_meshes(target)
	if _meshes.is_empty():
		push_warning("hand_fire: nenhum MeshInstance3D encontrado em %s" % target.name)
		return

	_measure()
	_apply_skin_material()
	_build_particles()
	_build_light()
	_burning = true
	set_process(true)


func _ready() -> void:
	set_process(false)


func _collect_meshes(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		_meshes.append(mi)
	for c in node.get_children():
		_collect_meshes(c)


## Mede a mão em unidades de MUNDO: as chamas e a luz são dimensionadas a
## partir daqui, então funciona com qualquer modelo/escala.
func _measure() -> void:
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
		# O ruído é medido em espaço de objeto: ajusta a escala pelo tamanho
		# real da malha para dar sempre ~5 células de chama ao longo da mão.
		var local_size: float = maxf(mi.get_aabb().size.length(), 0.0001)
		mat.set_shader_parameter("noise_scale", 5.5 / local_size)
		mat.set_shader_parameter("scroll_speed", local_size * 0.22)
		mat.set_shader_parameter("inflate", local_size * 0.004)
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


func _fire_ramps() -> Array:
	var initial := Gradient.new()
	initial.offsets = [0.0, 0.22, 0.6, 1.0]
	initial.colors = [
		Color(1.0, 0.72, 0.3, 1.0),
		Color(1.0, 0.42, 0.06, 1.0),
		Color(1.0, 0.19, 0.01, 1.0),
		Color(0.55, 0.05, 0.0, 1.0),
	]
	var alpha := Gradient.new()
	alpha.offsets = [0.0, 0.12, 0.55, 1.0]
	alpha.colors = [
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0.0),
	]
	return [initial, alpha]


func _puff_mesh(size: float, additive: bool, tint: Color) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.albedo_texture = SMOKE_TEX
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.disable_receive_shadows = true
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.08)
		mat.emission_energy_multiplier = 1.6

	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	mesh.material = mat
	return mesh


func _build_particles() -> void:
	var ramps := _fire_ramps()
	var s := _size

	# --- língua de fogo colada na mão ---
	var flame := CPUParticles3D.new()
	flame.name = "flame"
	flame.amount = 95
	flame.lifetime = 0.46
	flame.local_coords = true
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flame.emission_box_extents = _extents * 0.62
	flame.direction = Vector3.UP
	flame.spread = 16.0
	flame.gravity = Vector3(0, 1.7 * s, 0)
	flame.initial_velocity_min = 0.3 * s
	flame.initial_velocity_max = 1.4 * s
	flame.damping_min = 1.2 * s
	flame.damping_max = 2.6 * s
	flame.angle_min = -180.0
	flame.angle_max = 180.0
	var flame_curve := Curve.new()
	flame_curve.add_point(Vector2(0.0, 0.55))
	flame_curve.add_point(Vector2(0.3, 1.0))
	flame_curve.add_point(Vector2(1.0, 0.0))
	flame.scale_amount_min = 0.6 * flame_scale
	flame.scale_amount_max = 1.25 * flame_scale
	flame.scale_amount_curve = flame_curve
	flame.color_initial_ramp = ramps[0]
	flame.color_ramp = ramps[1]
	flame.mesh = _puff_mesh(s * 0.36, true, Color(1, 1, 1, 1))
	_add_emitter(flame)

	# --- brasas se soltando ---
	var ember := CPUParticles3D.new()
	ember.name = "embers"
	ember.amount = 40
	ember.lifetime = 1.3
	ember.local_coords = true
	ember.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ember.emission_box_extents = _extents * 0.6
	ember.direction = Vector3.UP
	ember.spread = 35.0
	ember.gravity = Vector3(0, 1.1 * s, 0)
	ember.initial_velocity_min = 1.0 * s
	ember.initial_velocity_max = 3.4 * s
	ember.damping_min = 1.0 * s
	ember.damping_max = 2.5 * s
	var ember_curve := Curve.new()
	ember_curve.add_point(Vector2(0.0, 1.0))
	ember_curve.add_point(Vector2(1.0, 0.1))
	ember.scale_amount_min = 0.55 * flame_scale
	ember.scale_amount_max = 1.2 * flame_scale
	ember.scale_amount_curve = ember_curve
	ember.color_initial_ramp = ramps[0]
	ember.color_ramp = ramps[1]
	ember.mesh = _puff_mesh(s * 0.075, true, Color(1, 1, 1, 1))
	_add_emitter(ember)

	# --- fumaça, só acima da chama ---
	var smoke := CPUParticles3D.new()
	smoke.name = "smoke"
	smoke.amount = 14
	smoke.lifetime = 1.1
	smoke.local_coords = true
	smoke.position = Vector3(0, _extents.y * 1.3, 0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = _extents * 0.5
	smoke.direction = Vector3.UP
	smoke.spread = 22.0
	smoke.gravity = Vector3(0, 1.0 * s, 0)
	smoke.initial_velocity_min = 0.4 * s
	smoke.initial_velocity_max = 1.2 * s
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.angular_velocity_min = -35.0
	smoke.angular_velocity_max = 35.0
	var smoke_curve := Curve.new()
	smoke_curve.add_point(Vector2(0.0, 0.5))
	smoke_curve.add_point(Vector2(1.0, 2.2))
	smoke.scale_amount_min = 0.8 * flame_scale
	smoke.scale_amount_max = 1.5 * flame_scale
	smoke.scale_amount_curve = smoke_curve

	var smoke_color := Gradient.new()
	smoke_color.offsets = [0.0, 0.25, 1.0]
	smoke_color.colors = [
		Color(0.2, 0.14, 0.11, 0.0),
		Color(0.13, 0.11, 0.1, 0.32),
		Color(0.07, 0.065, 0.06, 0.0),
	]
	smoke.color_ramp = smoke_color
	smoke.mesh = _puff_mesh(s * 0.45, false, Color(1, 1, 1, 1))
	_add_emitter(smoke)


func _add_emitter(p: CPUParticles3D) -> void:
	p.emitting = false
	add_child(p)
	_emitters.append(p)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "fire_light"
	_light.light_color = Color(1.0, 0.52, 0.2)
	_light.light_energy = 0.0
	_light.omni_range = light_range * max(_size / 0.2, 0.5)
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	if not _burning:
		return
	_time += delta
	_ignite = min(_ignite + delta / max(fade_in, 0.001), 1.0)

	# Este nó vive pendurado na mão (que por sua vez está pendurada na câmera).
	# Zerando a rotação, os eixos locais voltam a ser os do mundo — assim a
	# chama sobe de verdade em vez de acompanhar a inclinação da câmera.
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

	# As chamas começam pequenas e crescem enquanto o fogo pega.
	for i in range(_meshes.size()):
		var mi := _meshes[i]
		if not is_instance_valid(mi):
			continue
		var mat := _mats[i]
		mat.set_shader_parameter("ignite", _ignite)
		# "Para cima" do mundo no espaço de objeto desta malha.
		var up: Vector3 = (mi.global_transform.basis.inverse() * Vector3.UP).normalized()
		mat.set_shader_parameter("local_up", up)
		# Faixa de alturas da malha ao longo dessa direção: é o que diz ao
		# shader onde a chama nasce e onde ela deve se desfazer.
		var aabb := mi.get_aabb()
		var lo: float = INF
		var hi: float = -INF
		for c in range(8):
			var d: float = aabb.get_endpoint(c).dot(up)
			lo = minf(lo, d)
			hi = maxf(hi, d)
		mat.set_shader_parameter("h_min", lo)
		mat.set_shader_parameter("h_max", hi)

	# Acende os emissores escalonados, para o fogo "pegar" em vez de aparecer.
	for i in range(_emitters.size()):
		var start: float = 0.05 + float(i) * 0.22
		if not _emitters[i].emitting and _time >= start:
			_emitters[i].emitting = true

	if _light:
		# Tremulação: duas senóides incomensuráveis + um ruído lento, para não
		# virar uma pulsação regular (que é o que denuncia fogo falso).
		var f: float = 0.72 \
			+ 0.16 * sin(_time * 17.3) \
			+ 0.09 * sin(_time * 29.7 + 1.3) \
			+ 0.09 * sin(_time * 6.1 + 0.7)
		_light.light_energy = light_energy * _ignite * f


## Apaga o fogo suavemente e devolve a mão ao normal.
func extinguish(duration: float = 0.8) -> void:
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
