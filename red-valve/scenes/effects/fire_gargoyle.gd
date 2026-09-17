extends Node3D
## Gárgula de fogo da arena.
##
## O corpo inteiro (tronco, cabeça, chifres, patas, cauda e asas membranosas) é
## montado por código com primitivas + o shader de fogo, no mesmo espírito do
## furacão da arena (ver shaders/battlefield/battlefield.gd).
##
## Comportamento: pousa no topo de um "arena_corner", fica lá alguns segundos
## batendo asa de leve, e então levanta voo em arco até OUTRO canto sorteado.
## Gárgulas irmãs (mesmo grupo) nunca disputam o mesmo canto.

const GROUP := "fire_gargoyle"
const FIRE_SHADER := preload("res://shaders/effects/fire_gargoyle.gdshader")

## Altura (em unidades do modelo) do pivô em torno do qual o corpo deita no voo.
const LEAN_PIVOT_Y := 0.8
## Quanto o corpo deita voando: ~57°, deixando a coluna quase na horizontal.
const FLIGHT_LEAN := -1.0
## Empinada da frenagem no instante do pouso.
const LANDING_FLARE := 0.4

enum State { PERCHED, FLYING, DIRIGIDO }

## Pontos de pouso. Aceita qualquer Node3D (Marker3D, o próprio canto, etc).
@export var perch_paths: Array[NodePath] = []
## Índice do ponto de pouso inicial (-1 = sorteia).
@export var start_perch: int = -1

@export_group("Corpo")
@export var body_scale: float = 1.9
@export var fire_energy: float = 2.0
@export var light_energy: float = 6.0
@export var light_range: float = 14.0

@export_group("Vagar livre")
## Ignora os poleiros e fica cruzando o céu sem parar (usado no trailer).
@export var roam_enabled: bool = false
@export var roam_center: Vector3 = Vector3.ZERO
@export var roam_radius: float = 140.0
@export var roam_height_min: float = 25.0
@export var roam_height_max: float = 70.0
## O centro do vagar acompanha a câmera ativa (à frente dela), de modo que o
## bando esteja sempre no céu da tomada em curso. Sem isto, uma cena longa
## como o trailer deixa quase todas fora de quadro.
@export var roam_follow_camera: bool = true

@export_group("Comportamento")
@export var perch_time_min: float = 7.0
@export var perch_time_max: float = 16.0
@export var flight_speed: float = 12.0
@export var flight_arc_height: float = 10.0
## Quanto o trajeto curva na direção do centro da arena (0 = linha reta).
@export var flight_bow: float = 0.28
## Folga acima do ponto de pouso. A origem do modelo fica na sola do pé, então
## isto é só uma margem para o pé não atravessar a geometria.
@export var hover_offset: float = 0.05
## Velocidade com que a guinada acompanha a trajetória (menor = mais suave).
@export var turn_rate: float = 2.2

var _perches: Array[Node3D] = []
var _state: int = State.PERCHED
var _current: int = 0
var _target: int = 0
var _timer: float = 0.0

var _flight_t: float = 0.0
var _flight_dur: float = 1.0
var _p0: Vector3
var _p1: Vector3
var _p2: Vector3
var _p3: Vector3
var _arena_center: Vector3 = Vector3.ZERO

var _yaw: float = 0.0
var _pitch: float = 0.0
## Alvos da guinada e da arfagem no voo teleguiado (ver a seção no fim).
var _yaw_alvo: float = 0.0
var _pitch_alvo: float = 0.0
var _roll: float = 0.0
var _prev_yaw: float = 0.0

var _model: Node3D
var _lean_pivot: Node3D
var _head_pivot: Node3D
var _wing_pivots: Array[Node3D] = []
var _wing_mats: Array[ShaderMaterial] = []
var _beat_puffs: Array[CPUParticles3D] = []
var _last_beat: int = 0
var _beat_flash: float = 0.0
var _tail_pivots: Array[Node3D] = []
var _tail_base: Array[float] = []
var _light: OmniLight3D
var _trail: CPUParticles3D

var _flap_phase: float = 0.0
var _wing_open: float = 0.0      # 0 = dobrada, 1 = aberta
var _wing_open_target: float = 0.0
var _flap_rate: float = 0.0
var _flap_amp: float = 0.0
var _time: float = 0.0
var _head_yaw: float = 0.0
var _head_yaw_target: float = 0.0
var _head_timer: float = 0.0
var _seed: float = 0.0
var _lean: float = 0.0
var _lean_target: float = 0.0
var _last_dir: Vector3 = Vector3.FORWARD


func _ready() -> void:
	add_to_group(GROUP)
	_seed = randf() * 100.0
	_build_model()

	if roam_enabled:
		_finish_roam_setup()
		return

	for p in perch_paths:
		var n := get_node_or_null(p)
		if n is Node3D:
			_perches.append(n as Node3D)
	if not _perches.is_empty():
		_finish_setup()


## Chamado pelo spawner quando as gárgulas são criadas por código.
func setup(perch_nodes: Array, initial_perch: int = -1) -> void:
	_perches.clear()
	for n in perch_nodes:
		if n is Node3D:
			_perches.append(n)
	start_perch = initial_perch
	if is_inside_tree() and _model != null:
		_finish_setup()


## Liga o modo "vagar livre": sem poleiro, só cruzando o céu de um ponto
## aleatório a outro dentro do cilindro (centro / raio / faixa de altura).
func setup_roam(center: Vector3, radius: float, height_min: float, height_max: float) -> void:
	roam_enabled = true
	roam_center = center
	roam_radius = radius
	roam_height_min = height_min
	roam_height_max = height_max
	if is_inside_tree() and _model != null:
		_finish_roam_setup()


func _finish_roam_setup() -> void:
	_arena_center = roam_center
	global_position = _random_sky_point()
	var a := randf() * TAU
	_last_dir = Vector3(cos(a), 0.0, sin(a))
	_yaw = atan2(-_last_dir.x, -_last_dir.z)
	_prev_yaw = _yaw
	# Nasce já voando: asas abertas, corpo deitado.
	_wing_open = 1.0
	_wing_open_target = 1.0
	_lean = FLIGHT_LEAN
	_lean_target = FLIGHT_LEAN
	_flap_phase = randf() * TAU
	_flap_rate = 6.0
	_flap_amp = 0.8
	if _trail:
		_trail.emitting = true
	_start_roam_leg()
	set_process(true)


func _update_roam_center() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Um pouco à frente da câmera, para o bando cruzar o campo de visão.
	var fwd := -cam.global_transform.basis.z
	var c := cam.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * (roam_radius * 0.5)
	roam_center = Vector3(c.x, 0.0, c.z)

	# A câmera do trailer salta entre tomadas: quem ficar longe demais volta
	# para o céu da tomada atual em vez de sumir para sempre.
	var away := global_position - roam_center
	away.y = 0.0
	if away.length() > roam_radius * 2.2:
		global_position = _random_sky_point()
		_start_roam_leg()


func _random_sky_point() -> Vector3:
	var a := randf() * TAU
	var r: float = roam_radius * sqrt(randf())
	return Vector3(
		roam_center.x + cos(a) * r,
		randf_range(roam_height_min, roam_height_max),
		roam_center.z + sin(a) * r)


## Uma perna do vagar. O ponto de controle de saída segue a tangente da perna
## anterior, então as pernas emendam numa curva contínua em vez de virarem
## uma sequência de arcos com freada no meio.
func _start_roam_leg() -> void:
	_p0 = global_position
	_p3 = _random_sky_point()
	var d: float = max(_p0.distance_to(_p3), 8.0)
	_p1 = _p0 + _last_dir * d * 0.42
	var a := randf() * TAU
	_p2 = _p3 + Vector3(cos(a), 0.0, sin(a)) * d * 0.42
	_p1.y = clamp(_p1.y, roam_height_min, roam_height_max)
	_p2.y = clamp(_p2.y, roam_height_min, roam_height_max)
	_flight_t = 0.0
	_flight_dur = max(d * 1.25 / max(flight_speed, 0.1), 2.0)
	_state = State.FLYING
	_last_beat = int(floor((_flap_phase - PI * 1.5) / TAU))


func _finish_setup() -> void:
	if _perches.is_empty():
		set_process(false)
		return

	_arena_center = Vector3.ZERO
	for p in _perches:
		_arena_center += p.global_position
	_arena_center /= float(_perches.size())

	_current = start_perch if start_perch >= 0 and start_perch < _perches.size() \
		else randi() % _perches.size()
	_target = _current
	global_position = _perch_point(_current)
	_yaw = atan2(_arena_center.x - global_position.x, _arena_center.z - global_position.z) + PI
	_prev_yaw = _yaw
	_enter_perched(randf_range(perch_time_min * 0.3, perch_time_max))
	set_process(true)


func _perch_point(index: int) -> Vector3:
	return _perches[index].global_position + Vector3.UP * hover_offset


# =============================================================
# Montagem do corpo
# =============================================================

func _build_model() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise

	_model = Node3D.new()
	_model.name = "model"
	_model.scale = Vector3.ONE * body_scale
	add_child(_model)

	# Pivô da inclinação de voo, na altura do peito: girando por aqui (e não
	# pelos pés) o corpo deita sem que a silhueta saia de cima da trajetória.
	_lean_pivot = Node3D.new()
	_lean_pivot.name = "lean_pivot"
	_lean_pivot.position = Vector3(0, LEAN_PIVOT_Y, 0)
	_model.add_child(_lean_pivot)

	var body := Node3D.new()
	body.name = "body"
	body.position = Vector3(0, -LEAN_PIVOT_Y, 0)
	_lean_pivot.add_child(body)

	# --- tronco / peito ---
	var pelvis := CapsuleMesh.new()
	pelvis.radius = 0.155
	pelvis.height = 0.8
	pelvis.radial_segments = 12
	pelvis.rings = 6
	_add_part(body, "pelvis", pelvis, Vector3(0, 0.52, 0.02), Vector3(0.35, 0, 0), noise_tex, 0.52)

	var chest := SphereMesh.new()
	chest.radius = 0.19
	chest.height = 0.66
	chest.radial_segments = 14
	chest.rings = 8
	_add_part(body, "chest", chest, Vector3(0, 0.86, -0.06), Vector3.ZERO, noise_tex, 0.86)

	var neck := CapsuleMesh.new()
	neck.radius = 0.085
	neck.height = 0.36
	neck.radial_segments = 8
	neck.rings = 4
	_add_part(body, "neck", neck, Vector3(0, 1.06, -0.14), Vector3(0.55, 0, 0), noise_tex, 1.06)

	# --- cabeça (num pivô próprio, para olhar em volta enquanto pousada) ---
	_head_pivot = Node3D.new()
	_head_pivot.name = "head_pivot"
	_head_pivot.position = Vector3(0, 1.22, -0.28)
	body.add_child(_head_pivot)

	var skull := SphereMesh.new()
	skull.radius = 0.185
	skull.height = 0.34
	skull.radial_segments = 12
	skull.rings = 7
	_add_part(_head_pivot, "skull", skull, Vector3.ZERO, Vector3.ZERO, noise_tex, 1.18)

	var muzzle := CylinderMesh.new()
	muzzle.top_radius = 0.03
	muzzle.bottom_radius = 0.135
	muzzle.height = 0.36
	muzzle.radial_segments = 8
	_add_part(_head_pivot, "muzzle", muzzle, Vector3(0, -0.035, -0.2), Vector3(-PI * 0.5, 0, 0), noise_tex, 1.15)

	for side in [-1.0, 1.0]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.006
		horn.bottom_radius = 0.085
		horn.height = 0.6
		horn.radial_segments = 6
		_add_part(_head_pivot, "horn", horn, Vector3(0.105 * side, 0.14, 0.04),
			Vector3(0.95, 0, -0.3 * side), noise_tex, 1.33)

		var ear := CylinderMesh.new()
		ear.top_radius = 0.006
		ear.bottom_radius = 0.06
		ear.height = 0.28
		ear.radial_segments = 6
		_add_part(_head_pivot, "ear", ear, Vector3(0.145 * side, 0.05, 0.08),
			Vector3(0.2, 0, -0.9 * side), noise_tex, 1.23)

	_add_eyes(_head_pivot)

	# --- patas traseiras (agachadas, prontas para agarrar a pedra) ---
	for side in [-1.0, 1.0]:
		var thigh := CapsuleMesh.new()
		thigh.radius = 0.095
		thigh.height = 0.36
		thigh.radial_segments = 8
		thigh.rings = 4
		_add_part(body, "thigh", thigh, Vector3(0.14 * side, 0.44, 0.07),
			Vector3(-0.32, 0, 0), noise_tex, 0.44)

		var shin := CapsuleMesh.new()
		shin.radius = 0.075
		shin.height = 0.34
		shin.radial_segments = 8
		shin.rings = 4
		_add_part(body, "shin", shin, Vector3(0.155 * side, 0.19, -0.05),
			Vector3(0.34, 0, 0), noise_tex, 0.19)

		var foot := CylinderMesh.new()
		foot.top_radius = 0.12
		foot.bottom_radius = 0.05
		foot.height = 0.14
		foot.radial_segments = 6
		_add_part(body, "foot", foot, Vector3(0.155 * side, 0.045, -0.12),
			Vector3(0.2, 0, 0), noise_tex, 0.045)

		# bracinhos dobrados junto ao peito
		var arm := CapsuleMesh.new()
		arm.radius = 0.06
		arm.height = 0.32
		arm.radial_segments = 6
		arm.rings = 3
		_add_part(body, "arm", arm, Vector3(0.2 * side, 0.78, -0.18),
			Vector3(1.0, 0, -0.4 * side), noise_tex, 0.78)

	# Crista de espinhos da nuca até a base da cauda.
	for i in range(5):
		var t := float(i) / 4.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.004
		spike.bottom_radius = 0.045 - 0.006 * float(i)
		spike.height = 0.26 - 0.04 * float(i)
		spike.radial_segments = 5
		_add_part(body, "crest", spike, Vector3(0, lerp(1.06, 0.62, t), lerp(0.02, 0.24, t)),
			Vector3(-0.35 - 0.25 * t, 0, 0), noise_tex, lerp(1.06, 0.62, t))

	_build_tail(body, noise_tex)
	_build_wings(body, noise_tex)

	# --- luz e brasas ---
	_light = OmniLight3D.new()
	_light.name = "fire_light"
	_light.position = Vector3(0, 0.85, 0)
	_light.light_color = Color(1.0, 0.47, 0.18)
	_light.light_energy = light_energy
	_light.omni_range = light_range / max(body_scale, 0.001)
	_light.omni_attenuation = 0.9
	_light.shadow_enabled = false
	body.add_child(_light)

	body.add_child(_make_embers())
	_trail = _make_trail()
	body.add_child(_trail)


func _add_part(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3,
		rot: Vector3, noise_tex: Texture2D, heat_offset: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.material_override = _make_fire_material(noise_tex, heat_offset)
	parent.add_child(mi)
	return mi


func _make_fire_material(noise_tex: Texture2D, heat_offset: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FIRE_SHADER
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("energy", fire_energy)
	mat.set_shader_parameter("seed", _seed + randf() * 10.0)
	mat.set_shader_parameter("part_offset_y", heat_offset)
	mat.set_shader_parameter("body_height", 1.6)
	mat.set_shader_parameter("noise_scale", 3.0)
	mat.set_shader_parameter("turbulence", 0.045)
	mat.set_shader_parameter("dissolve", 0.28)
	mat.set_shader_parameter("rim_mix", 0.8)
	mat.set_shader_parameter("scroll_speed", randf_range(0.8, 1.1))
	return mat


func _add_eyes(parent: Node3D) -> void:
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.95, 0.75)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.85, 0.4)
	eye_mat.emission_energy_multiplier = 12.0
	eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eye_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.032
		eye.height = 0.064
		eye.radial_segments = 6
		eye.rings = 4
		eye.material = eye_mat
		var mi := MeshInstance3D.new()
		mi.name = "eye"
		mi.mesh = eye
		mi.position = Vector3(0.075 * side, 0.05, -0.17)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(mi)


## Cauda: cai para trás/para baixo e recurva na ponta, como a de uma gárgula
## de catedral. A pose de repouso fica guardada em _tail_base e a animação
## apenas soma a ondulação por cima dela.
func _build_tail(body: Node3D, noise_tex: Texture2D) -> void:
	# Ângulo de repouso de cada junta: positivo = desce.
	var droop: Array[float] = [0.15, 0.12, 0.08, 0.0, -0.1, -0.2, -0.28]
	var parent: Node3D = body
	var pos := Vector3(0, 0.5, 0.26)
	for i in range(droop.size()):
		var pivot := Node3D.new()
		pivot.name = "tail_%d" % i
		pivot.position = pos
		pivot.rotation = Vector3(droop[i], 0, 0)
		parent.add_child(pivot)
		_tail_pivots.append(pivot)
		_tail_base.append(droop[i])

		var seg := SphereMesh.new()
		var r: float = 0.11 - 0.013 * float(i)
		seg.radius = r
		seg.height = r * 2.2
		seg.radial_segments = 8
		seg.rings = 5
		_add_part(pivot, "tail_seg", seg, Vector3.ZERO, Vector3.ZERO, noise_tex, 0.5)

		parent = pivot
		pos = Vector3(0, 0.0, 0.17)

	# ponta em forma de lâmina
	var blade := CylinderMesh.new()
	blade.top_radius = 0.004
	blade.bottom_radius = 0.085
	blade.height = 0.26
	blade.radial_segments = 6
	_add_part(parent, "tail_blade", blade, Vector3(0, 0, 0.13), Vector3(PI * 0.5, 0, 0),
		noise_tex, 0.5)


func _build_wings(body: Node3D, noise_tex: Texture2D) -> void:
	for i in range(2):
		var side := 1.0 if i == 0 else -1.0
		var pivot := Node3D.new()
		pivot.name = "wing_pivot_%d" % i
		pivot.position = Vector3(0.21 * side, 0.98, 0.05)
		body.add_child(pivot)
		_wing_pivots.append(pivot)

		var mi := MeshInstance3D.new()
		mi.name = "wing"
		mi.mesh = _build_wing_mesh(side < 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var mat := _make_fire_material(noise_tex, 0.45)
		mat.set_shader_parameter("flap_amount", 0.1)
		mat.set_shader_parameter("flap_span", 4.2)
		mat.set_shader_parameter("edge_heat", 0.45)
		mat.set_shader_parameter("rim_mix", 0.1)
		mat.set_shader_parameter("energy", fire_energy * 1.5)
		mat.set_shader_parameter("dissolve", 0.24)
		mat.set_shader_parameter("noise_scale", 2.2)
		mat.set_shader_parameter("turbulence", 0.02)
		mi.material_override = mat
		_wing_mats.append(mat)
		pivot.add_child(mi)

		# Sopro de fogo na ponta da asa, disparado a cada batida.
		var puff := _make_beat_puff()
		puff.position = Vector3(1.15 * side, 0.35, 0.0)
		pivot.add_child(puff)
		_beat_puffs.append(puff)


## Membrana de morcego: borda de ataque em arco, membrana que incha no meio e
## fecha na ponta, com três recortes entre os "dedos".
func _build_wing_mesh(mirror: bool) -> ArrayMesh:
	const SPAN_STEPS := 22
	const CHORD_STEPS := 6
	const SPAN := 1.55

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var sx := -1.0 if mirror else 1.0

	for i in range(SPAN_STEPS + 1):
		var u := float(i) / float(SPAN_STEPS)
		var lead_y := 0.08 + 0.58 * sin(u * PI * 0.78)
		var width := (0.36 + 1.25 * u) * (1.0 - pow(u, 3.0))
		width *= 1.0 - 0.24 * abs(sin(u * PI * 3.0))
		for k in range(CHORD_STEPS + 1):
			var v := float(k) / float(CHORD_STEPS)
			verts.append(Vector3(u * SPAN * sx, lead_y - width * v, 0.0))
			uvs.append(Vector2(u, v))
			normals.append(Vector3(0, 0, 1))

	var row := CHORD_STEPS + 1
	for i in range(SPAN_STEPS):
		for k in range(CHORD_STEPS):
			var a := i * row + k
			var b := a + row
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## `manter_escala` liga o `billboard_keep_scale`. SEM ele o billboard descarta a
## escala da partícula e `scale_amount_min/max` não valem nada — a brasa sai
## sempre do tamanho do raio da malha. Fica desligado por padrão só porque é o
## que as brasas antigas sempre fizeram; quem precisa de brasa GRANDE (o manto
## do modo de perto) tem de pedir.
func _fire_particle_mesh(radius: float, manter_escala: bool = false) -> SphereMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.28, 0.03)
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = manter_escala

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 4
	mesh.material = mat
	return mesh


func _fire_ramps() -> Array:
	var initial := Gradient.new()
	initial.offsets = [0.0, 0.35, 0.7, 1.0]
	initial.colors = [
		Color(1.0, 0.66, 0.2, 1.0),
		Color(1.0, 0.34, 0.03, 1.0),
		Color(1.0, 0.15, 0.0, 1.0),
		Color(0.55, 0.02, 0.0, 1.0),
	]
	var alpha := Gradient.new()
	alpha.offsets = [0.0, 0.15, 0.6, 1.0]
	alpha.colors = [
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.7),
		Color(1, 1, 1, 0.0),
	]
	return [initial, alpha]


## Brasas que sobem do corpo o tempo todo.
func _make_embers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "embers"
	p.amount = 45
	p.lifetime = 1.5
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, 0.55, 0.35)
	p.position = Vector3(0, 0.8, 0)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_min = 0.5 * body_scale
	p.scale_amount_max = 1.3 * body_scale
	p.scale_amount_curve = curve

	var ramps := _fire_ramps()
	p.color_initial_ramp = ramps[0]
	p.color_ramp = ramps[1]
	p.mesh = _fire_particle_mesh(0.06)
	return p


## Sopro disparado a cada remada da asa: uma lufada curta de brasas empurrada
## para baixo/para trás, como se a asa jogasse o fogo contra o ar.
func _make_beat_puff() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "beat_puff"
	p.amount = 16
	p.lifetime = 0.85
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.direction = Vector3.DOWN
	p.spread = 40.0
	p.gravity = Vector3(0, -1.0, 0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.damping_min = 2.0
	p.damping_max = 4.0

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_min = 1.0 * body_scale
	p.scale_amount_max = 2.4 * body_scale
	p.scale_amount_curve = curve

	var ramps := _fire_ramps()
	p.color_initial_ramp = ramps[0]
	p.color_ramp = ramps[1]
	p.mesh = _fire_particle_mesh(0.08)
	return p


## Rastro deixado durante o voo (ligado só quando está no ar).
func _make_trail() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "trail"
	p.amount = 90
	p.lifetime = 2.2
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.55, 0.5, 0.5)
	p.position = Vector3(0, 0.85, 0.1)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.0
	p.damping_min = 0.4
	p.damping_max = 1.2

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.35, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_min = 0.8 * body_scale
	p.scale_amount_max = 2.0 * body_scale
	p.scale_amount_curve = curve

	var ramps := _fire_ramps()
	p.color_initial_ramp = ramps[0]
	p.color_ramp = ramps[1]
	p.mesh = _fire_particle_mesh(0.09)
	return p


# =============================================================
# Máquina de estados
# =============================================================

func _process(delta: float) -> void:
	# O voo teleguiado vem ANTES da guarda dos poleiros: a gárgula do resgate
	# não tem poleiro nenhum, e sem isto ela sairia do `_process` sem nunca
	# bater asa.
	if _state == State.DIRIGIDO:
		_time += delta
		_passo_dirigido(delta)
		_animate(delta)
		return

	if _perches.is_empty() and not roam_enabled:
		return
	_time += delta

	if roam_enabled and roam_follow_camera:
		_update_roam_center()

	match _state:
		State.PERCHED:
			_process_perched(delta)
		State.FLYING:
			_process_flying(delta)

	_animate(delta)


func _enter_perched(duration: float) -> void:
	_state = State.PERCHED
	_timer = duration
	_current = _target
	global_position = _perch_point(_current)
	# _pitch/_roll/_lean voltam a zero interpolados em _process_perched: zerar
	# aqui de uma vez fazia o corpo estalar na vertical no instante do pouso.
	_lean_target = 0.0
	_wing_open_target = 0.0
	_flap_rate = 0.0
	_flap_amp = 0.05
	if _trail:
		_trail.emitting = false


func _process_perched(delta: float) -> void:
	_timer -= delta
	var settle: float = clamp(delta * 2.0, 0.0, 1.0)
	_pitch = lerp(_pitch, 0.0, settle)
	_roll = lerp(_roll, 0.0, settle)
	# Vira a cabeça de tempos em tempos, vigiando a arena.
	_head_timer -= delta
	if _head_timer <= 0.0:
		_head_timer = randf_range(1.5, 4.0)
		_head_yaw_target = randf_range(-0.7, 0.7)

	# Bate a asa de leve pouco antes de levantar voo (telegrafa a decolagem).
	if _timer < 1.2:
		_wing_open_target = 0.55
		_flap_rate = 5.0
		_flap_amp = 0.35

	if _timer <= 0.0:
		_start_flight()


func _start_flight() -> void:
	var next := _pick_next_perch()
	if next < 0:
		_timer = randf_range(1.0, 2.0)
		return

	_target = next
	_p0 = _perch_point(_current)
	_p3 = _perch_point(_target)

	var flat := _p3 - _p0
	flat.y = 0.0
	var dist: float = max(flat.length(), 1.0)
	var fwd := flat / dist
	var lift: float = flight_arc_height + dist * 0.15

	# Curva o trajeto na direção do centro da arena, para o voo passar por
	# cima do combate em vez de contornar a borda em linha reta.
	var mid := (_p0 + _p3) * 0.5
	var to_center := _arena_center - mid
	to_center.y = 0.0
	var bow := to_center * flight_bow

	_p1 = _p0 + Vector3.UP * lift + fwd * dist * 0.15 + bow
	_p2 = _p3 + Vector3.UP * lift - fwd * dist * 0.15 + bow

	_flight_t = 0.0
	# O comprimento do arco é bem maior que a distância reta: aproxima por 1.35x.
	_flight_dur = max((dist * 1.35 + lift * 2.0) / max(flight_speed, 0.1), 1.5)
	_state = State.FLYING
	_wing_open_target = 1.0
	_last_beat = int(floor((_flap_phase - PI * 1.5) / TAU))
	if _trail:
		_trail.emitting = true


func _process_flying(delta: float) -> void:
	_flight_t = min(_flight_t + delta / _flight_dur, 1.0)
	# Vagando o ritmo é constante; entre poleiros ele acelera e desacelera.
	var t: float = _flight_t if roam_enabled else smoothstep(0.0, 1.0, _flight_t)

	var pos := _bezier(t)
	var ahead := _bezier(min(t + 0.02, 1.0))
	var dir := ahead - pos
	if t >= 0.999:
		dir = _p3 - _bezier(0.96)
	global_position = pos

	_prev_yaw = _yaw
	if dir.length_squared() > 0.0001:
		var flat := Vector3(dir.x, 0.0, dir.z)
		var want := _yaw
		if _flight_t > 0.72 and not roam_enabled:
			# Na descida a tangente da curva fica quase vertical e o atan2
			# enlouquece (era isso que fazia ele girar de repente ao pousar).
			# A partir daqui a mira passa a ser o centro da arena.
			var to_center := _arena_center - global_position
			to_center.y = 0.0
			if to_center.length_squared() > 0.01:
				want = atan2(-to_center.x, -to_center.z)
		elif flat.length() > dir.length() * 0.3:
			want = atan2(-flat.x, -flat.z)
		_yaw = lerp_angle(_yaw, want, clamp(delta * turn_rate, 0.0, 1.0))

		var pitch_want: float = asin(clamp(dir.normalized().y, -1.0, 1.0))
		_pitch = lerp(_pitch, clamp(pitch_want * 0.8, -0.6, 0.6), clamp(delta * 3.0, 0.0, 1.0))

	# Corpo deitado como o de uma ave; empina para frear na chegada.
	_lean_target = FLIGHT_LEAN
	if not roam_enabled and _flight_t >= 0.86:
		_lean_target = LANDING_FLARE

	# Inclina nas curvas, como um pássaro.
	var turn := wrapf(_yaw - _prev_yaw, -PI, PI)
	var roll_want: float = clamp(-turn / max(delta, 0.0001) * 0.18, -0.8, 0.8)
	_roll = lerp(_roll, roll_want, clamp(delta * 2.0, 0.0, 1.0))

	# Bate forte na subida e na chegada; plana no meio do trajeto.
	if roam_enabled:
		# Bate forte quando sobe, plana quando desce.
		var climb: float = clamp(dir.normalized().y * 2.5 + 0.4, 0.0, 1.0)
		_flap_rate = lerp(4.5, 8.5, climb)
		_flap_amp = lerp(0.5, 1.0, climb)
		_wing_open_target = 1.0
	else:
		# Nunca para de bater: no meio do trajeto bate mais devagar e mais
		# curto, na decolagem e na chegada bate forte.
		var effort: float = max(1.0 - _flight_t / 0.3, (_flight_t - 0.68) / 0.32)
		effort = clamp(effort, 0.0, 1.0)
		_flap_rate = lerp(6.0, 9.5, effort)
		_flap_amp = lerp(0.7, 1.05, effort)

	if _flight_t >= 1.0:
		if roam_enabled:
			var exit_dir := _p3 - _p2
			if exit_dir.length_squared() > 0.001:
				_last_dir = exit_dir.normalized()
			_start_roam_leg()
		else:
			_enter_perched(randf_range(perch_time_min, perch_time_max))


func _bezier(t: float) -> Vector3:
	var u := 1.0 - t
	return _p0 * (u * u * u) + _p1 * (3.0 * u * u * t) + _p2 * (3.0 * u * t * t) + _p3 * (t * t * t)


## Sorteia um canto diferente do atual e que nenhuma irmã esteja usando/mirando.
func _pick_next_perch() -> int:
	if _perches.size() < 2:
		return -1
	var taken := {}
	for other in get_tree().get_nodes_in_group(GROUP):
		if other == self or not is_instance_valid(other):
			continue
		if other.has_method("reserved_perch"):
			taken[other.call("reserved_perch")] = true

	var options: Array[int] = []
	var fallback: Array[int] = []
	for i in range(_perches.size()):
		if i == _current:
			continue
		fallback.append(i)
		if not taken.has(i):
			options.append(i)
	# Se houver tanta gárgula quanto poleiro, ninguém acharia destino livre e
	# todas ficariam presas na decolagem: aí vale repetir um poleiro ocupado.
	if options.is_empty():
		options = fallback
	if options.is_empty():
		return -1
	return options[randi() % options.size()]


## Canto que esta gárgula ocupa (ou para onde está indo) — usado pelas irmãs.
func reserved_perch() -> int:
	return _target


# =============================================================
# Animação do corpo
# =============================================================

func _animate(delta: float) -> void:
	transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, _roll))

	_flap_phase += delta * _flap_rate
	_wing_open = lerp(_wing_open, _wing_open_target, clamp(delta * 4.0, 0.0, 1.0))

	# Dobrada: caída ao longo do corpo, recolhida para trás — a asa "encolhe"
	# (escala do pivô) para simular a dobra do cotovelo, senão a folha rígida
	# ficaria enorme para trás. Aberta: quase na horizontal.
	var fold := 1.0 - _wing_open
	var rz: float = lerp(0.12, -1.15, fold) + sin(_flap_phase) * _flap_amp * _wing_open \
		+ sin(_time * 1.1) * 0.04 * fold
	var ry: float = lerp(-0.18, -0.35, fold)
	var rx: float = sin(_flap_phase + 0.6) * 0.18 * _wing_open
	# A asa é uma folha rígida: para "fechar" de verdade, além de girar para
	# baixo ela encolhe no eixo da membrana (Y local), como se os dedos
	# dobrassem. Aberta, volta ao tamanho cheio.
	var wing_len: float = lerp(0.85, 1.0, _wing_open)
	var wing_chord: float = lerp(0.32, 1.0, _wing_open)

	for i in range(_wing_pivots.size()):
		var side := 1.0 if i == 0 else -1.0
		_wing_pivots[i].rotation = Vector3(rx, ry * side, rz * side)
		_wing_pivots[i].scale = Vector3(wing_len, wing_chord, 1.0)
		_wing_mats[i].set_shader_parameter("flap_phase", _flap_phase)
		_wing_mats[i].set_shader_parameter("flap_amount", 0.06 + 0.14 * _wing_open)

	_update_wing_beat(delta)

	# Cauda ondulando com atraso ao longo dos segmentos.
	var tail_speed: float = 1.6 + _flap_rate * 0.3
	for i in range(_tail_pivots.size()):
		var ph := _time * tail_speed - float(i) * 0.55
		var amp: float = 0.06 + 0.015 * float(i)
		_tail_pivots[i].rotation = Vector3(
			_tail_base[i] + sin(ph) * amp * 0.7,
			sin(ph * 0.8) * amp * 1.4,
			0.0)

	# Respiração / pouso: sobe e desce de leve.
	_lean = lerp(_lean, _lean_target, clamp(delta * 2.5, 0.0, 1.0))
	_lean_pivot.rotation.x = _lean

	var bob: float = sin(_time * 1.6) * 0.03 + sin(_flap_phase) * 0.05 * _wing_open
	_model.position.y = bob
	_model.scale = Vector3.ONE * body_scale * (1.0 + sin(_time * 1.9) * 0.015)

	if _head_pivot:
		_head_yaw = lerp(_head_yaw, _head_yaw_target * (1.0 - _wing_open), clamp(delta * 3.0, 0.0, 1.0))
		# Com o corpo deitado a cabeça ficaria olhando para o chão: levanta o
		# pescoço proporcionalmente à inclinação.
		_head_pivot.rotation = Vector3(sin(_time * 1.3) * 0.05 - _lean * 0.75, _head_yaw, 0.0)

	if _light:
		var flicker: float = 0.82 + 0.18 * sin(_time * 11.0 + _seed) * cos(_time * 6.3)
		_light.light_energy = light_energy * flicker * (1.0 + _wing_open * 0.35 + _beat_flash)


## Dispara o sopro no fundo de cada remada (quando sin(fase) atinge o mínimo).
func _update_wing_beat(delta: float) -> void:
	_beat_flash = max(_beat_flash - delta * 3.5, 0.0)
	var beat := int(floor((_flap_phase - PI * 1.5) / TAU))
	if beat == _last_beat:
		return
	_last_beat = beat
	if _wing_open < 0.5:
		return
	_beat_flash = 0.9
	for puff in _beat_puffs:
		puff.restart()


# =============================================================
# Voo teleguiado (cutscene)
# =============================================================
## A gárgula do RESGATE não tem poleiro nenhum: quem manda nela é o script da
## cutscene, que escreve a posição quadro a quadro (ver
## scripts/stages/battlefield/resgate_gargula.gd). O que sobra aqui é o CORPO —
## asa, cauda, cauda ondulando, guinada, arfagem e inclinação continuam saindo
## de `_animate`, iguais aos do voo entre poleiros.
##
## A posição é escrita direto em vez de ser mais um alvo perseguido: a
## cinematica precisa que a gárgula esteja num ponto EXATO em cada instante (é
## dela que a câmera pendura o jogador), e um alvo amortecido chegaria atrasado.
## O que é amortecido é só a ATITUDE do corpo, tirada da direção do movimento.
func voo_dirigido_iniciar(pos: Vector3, olhar: Vector3) -> void:
	_state = State.DIRIGIDO
	_perches.clear()
	global_position = pos

	var dir := olhar - pos
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		_yaw = atan2(-dir.x, -dir.z)
	_prev_yaw = _yaw
	_yaw_alvo = _yaw
	_pitch_alvo = 0.0

	# A asa nasce ABERTA e o corpo já deitado: ela entra em quadro voando, e
	# uma asa se abrindo no primeiro segundo leria como se ela tivesse acabado
	# de largar um poleiro fora da tela.
	_wing_open = 1.0
	_wing_open_target = 1.0
	_lean = FLIGHT_LEAN
	_lean_target = FLIGHT_LEAN
	_flap_rate = 8.0
	_flap_amp = 1.0
	if _trail:
		_trail.emitting = true
	set_process(true)


## Um passo do voo teleguiado. `esforco` 0 = planando, 1 = remada forte.
func voo_dirigido_ir(pos: Vector3, esforco: float = 1.0) -> void:
	if _state != State.DIRIGIDO:
		return
	var dir := pos - global_position
	global_position = pos
	if dir.length_squared() > 0.000001:
		var reta := dir.normalized()
		_last_dir = reta
		var plano := Vector3(dir.x, 0.0, dir.z)
		# Quase na vertical (a subida com o jogador, o mergulho) o atan2 do
		# plano vira ruído e a gárgula gira em torno do próprio eixo. Abaixo
		# deste limite a guinada simplesmente fica onde está.
		if plano.length() > dir.length() * 0.25:
			_yaw_alvo = atan2(-plano.x, -plano.z)
		_pitch_alvo = clampf(asin(clampf(reta.y, -1.0, 1.0)) * 0.8, -0.6, 0.6)
	var e := clampf(esforco, 0.0, 1.0)
	_flap_rate = lerpf(4.5, 9.5, e)
	_flap_amp = lerpf(0.55, 1.05, e)
	_lean_target = FLIGHT_LEAN


## Empina e freia: o instante em que ela para no ar para pegar o jogador.
func voo_dirigido_frear() -> void:
	_lean_target = LANDING_FLARE
	_flap_rate = 9.5
	_flap_amp = 1.05


func _passo_dirigido(delta: float) -> void:
	_prev_yaw = _yaw
	_yaw = lerp_angle(_yaw, _yaw_alvo, clampf(delta * turn_rate * 1.6, 0.0, 1.0))
	_pitch = lerpf(_pitch, _pitch_alvo, clampf(delta * 3.0, 0.0, 1.0))
	# Mesma inclinação de curva do voo normal: o giro por segundo vira rolagem.
	var turn := wrapf(_yaw - _prev_yaw, -PI, PI)
	var roll_want: float = clampf(-turn / maxf(delta, 0.0001) * 0.18, -0.8, 0.8)
	_roll = lerpf(_roll, roll_want, clampf(delta * 2.0, 0.0, 1.0))


## Larga o jogador e vai embora, subindo e se afastando ate' sumir — e se apaga
## sozinha no fim.
##
## A fuga roda AQUI, e nao no script da cutscene, de proposito: a cinematica
## acaba (e o no' dela se apaga) enquanto a gargula ainda esta' cruzando o ceu,
## e uma corrotina do no' morto e' um erro de "instancia sumiu" no meio do voo.
func voo_dirigido_fugir(meio: Vector3, longe: Vector3, duracao: float) -> void:
	var de := global_position
	var t := 0.0
	while t < duracao:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k: float = Tween.interpolate_value(0.0, 1.0, minf(t, duracao), duracao,
				Tween.TRANS_QUAD, Tween.EASE_IN)
		var u := 1.0 - k
		voo_dirigido_ir(de * (u * u * u) + (de + (meio - de) * 0.15) * (3.0 * u * u * k)
				+ meio * (3.0 * u * k * k) + longe * (k * k * k), 1.0)
	queue_free()


# =============================================================
# Modo de perto: o corpo some dentro do próprio fogo
# =============================================================
## De LONGE — as gárgulas pousadas nos cantos da arena — o corpo montado com
## primitivas lê como uma silhueta de brasa, e está ótimo assim. De PERTO não: o
## resgate põe a câmera a dois metros dela, e aí a cápsula do tronco e a esfera
## do peito ficam evidentes, dá para contar os anéis da malha.
##
## O conserto tem duas metades, e a segunda é a que resolve:
##
## 1. O shader do corpo ondula MUITO mais e abre mais buraco (`turbulence`,
##    `dissolve`, `noise_scale`): o contorno liso da primitiva vira uma borda
##    rasgada que mexe.
## 2. Um MANTO de brasas grandes envolve o corpo inteiro. É ele que de fato
##    esconde a geometria — o shader sozinho continuaria desenhando a forma da
##    cápsula, só que com a borda tremendo.
##
## As ASAS ficam de fora da primeira metade de propósito: são folhas finas, não
## volumes, e a mesma ondulação que quebra a cápsula só rasgaria a membrana.
##
## Só a gárgula do resgate chama isto. Nas dos cantos seria partícula gasta à
## toa, e de longe o manto vira uma bola laranja sem forma nenhuma.
func modo_fogo_de_perto() -> void:
	for mi in _pecas_de_fogo():
		var mat := mi.material_override as ShaderMaterial
		mat.set_shader_parameter("turbulence", 0.10)
		mat.set_shader_parameter("noise_scale", 4.2)
		mat.set_shader_parameter("dissolve", 0.34)
		mat.set_shader_parameter("scroll_speed", randf_range(1.2, 1.6))
		_vestir_casca(mi)

	# As ASAS levam um tratamento MAIS FRACO, e nenhuma casca.
	#
	# A membrana é uma folha fina: uma casca por fora dela seria só uma segunda
	# folha flutuando ao lado, e a ondulação forte do corpo a rasga em tiras. O
	# que ela precisa é só perder o corte limpo da borda, senão a asa fica
	# nítida do lado de um corpo todo borrado — e é justamente o contraste que
	# denuncia que ali tem geometria.
	for mat in _wing_mats:
		mat.set_shader_parameter("turbulence", 0.075)
		mat.set_shader_parameter("dissolve", 0.31)
		mat.set_shader_parameter("noise_scale", 4.0)

	var corpo := _lean_pivot.get_node_or_null("body") if _lean_pivot != null else null
	if corpo == null:
		return
	corpo.add_child(_manto_de_fogo())

	# As brasas de sempre também engrossam um pouco: elas cobrem o que sobe do
	# corpo, e de perto a nuvem rala de antes deixava buraco.
	var brasas := corpo.get_node_or_null("embers") as CPUParticles3D
	if brasas != null:
		brasas.emission_box_extents = Vector3(0.38, 0.7, 0.46)
		brasas.amount = 70
	if _trail != null:
		_trail.amount = 120

	# Luz mais forte e mais curta: de perto ela é a fonte de luz da cena, e o
	# alcance grande do poleiro só lavava o chão lá embaixo.
	light_energy *= 1.15
	light_range = 9.0
	if _light != null:
		_light.omni_range = light_range


## Põe uma CASCA de fogo por fora de uma peça do corpo.
##
## É a metade que realmente resolve o problema, e é por isto que ela existe em
## vez de simplesmente afogar tudo em partícula: a casca é a MESMA malha, um
## pouco maior, com o mesmo shader no talo da ondulação e da dissolução e com
## alfa baixo. O contorno que o jogador vê passa a ser o dela — rasgado, cheio
## de buraco e mexendo —, enquanto a peça de verdade continua desenhando o
## VOLUME por dentro.
##
## Afogar em partícula apaga o bicho junto: a cabeça some e sobra uma bola
## branca. A casca borra a forma sem tirar a leitura de "é uma gárgula".
func _vestir_casca(mi: MeshInstance3D) -> void:
	var casca := MeshInstance3D.new()
	casca.name = "casca_" + mi.name
	casca.mesh = mi.mesh
	casca.transform = mi.transform
	casca.scale = mi.scale * 1.22
	casca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casca.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var base := mi.material_override as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = FIRE_SHADER
	mat.set_shader_parameter("noise_tex", base.get_shader_parameter("noise_tex"))
	mat.set_shader_parameter("energy", fire_energy * 0.65)
	mat.set_shader_parameter("seed", randf() * 100.0)
	mat.set_shader_parameter("part_offset_y", base.get_shader_parameter("part_offset_y"))
	mat.set_shader_parameter("body_height", 1.6)
	# Ondulação grande e corte alto: é o que faz a borda ficar rasgada em vez de
	# ser uma cápsula um número maior por cima da outra.
	mat.set_shader_parameter("noise_scale", 2.6)
	mat.set_shader_parameter("turbulence", 0.26)
	mat.set_shader_parameter("dissolve", 0.44)
	# Menos contorno e mais superfície que a peça de dentro: a casca tem de
	# preencher o vão entre as duas, não desenhar mais um anel.
	mat.set_shader_parameter("rim_mix", 0.35)
	mat.set_shader_parameter("alpha_gain", 0.38)
	mat.set_shader_parameter("scroll_speed", randf_range(1.5, 2.0))
	casca.material_override = mat

	mi.get_parent().add_child(casca)


## Toda peça de fogo do CORPO — as asas ficam de fora (ver modo_fogo_de_perto).
func _pecas_de_fogo() -> Array[MeshInstance3D]:
	var achadas: Array[MeshInstance3D] = []
	if _model == null:
		return achadas
	var pilha: Array[Node] = [_model]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for c in no.get_children():
			pilha.append(c)
		var mi := no as MeshInstance3D
		if mi == null or not (mi.material_override is ShaderMaterial):
			continue
		if _wing_mats.has(mi.material_override):
			continue
		if mi.name.begins_with("casca_"):
			continue
		achadas.append(mi)
	return achadas


## O manto: uma crosta de brasas MIÚDAS e densas colada no corpo.
##
## Miúdas e muitas, e não poucas e grandes: com brasa grande o blend aditivo
## empilha e a gárgula vira uma bola branca sem forma nenhuma — de perto E de
## longe. O que se quer é o contrário, quebrar a SUPERFÍCIE sem apagar a
## silhueta: ela tem de continuar lendo como um bicho voando.
func _manto_de_fogo() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "manto"
	p.amount = 55
	p.lifetime = 0.7
	# COORDENADAS LOCAIS, ao contrário das outras brasas desta gárgula. Em
	# espaço de mundo cada brasa nasce e FICA PARA TRÁS: voando a 12 m/s o corpo
	# sai de dentro do próprio fogo em menos de um quadro e a geometria volta a
	# aparecer limpa. O manto tem de viajar junto.
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# Caixa cobrindo o CORPO INTEIRO, e não só o peito: concentrada no tronco, a
	# nuvem apagava a cabeça e deixava asa e cauda limpas — o pior dos dois.
	p.emission_box_extents = Vector3(0.34, 0.78, 0.44)
	p.position = Vector3(0, 0.78, -0.04)
	p.direction = Vector3.UP
	# Espalhamento largo e velocidade baixa: é uma nuvem que lambe o corpo, não
	# um jato. O que sobe em coluna já são as `embers`.
	p.spread = 85.0
	p.gravity = Vector3(0, 0.7, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.6
	p.damping_min = 1.5
	p.damping_max = 3.0

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	# SEM multiplicar por `body_scale`: em coordenadas locais a partícula já
	# herda a escala do `_model`. As brasas de mundo (embers/trail) precisam do
	# fator na mão justamente porque não herdam.
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.scale_amount_curve = curve

	p.color_initial_ramp = _fire_ramps()[0]
	# Rampa de alfa PRÓPRIA, mais fraca que a das outras brasas: são 150 quadros
	# aditivos empilhados sobre o mesmo corpo, e no alfa cheio a soma estoura em
	# branco no meio do peito.
	var alfa := Gradient.new()
	alfa.offsets = [0.0, 0.2, 0.65, 1.0]
	alfa.colors = [
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.17),
		Color(1, 1, 1, 0.10),
		Color(1, 1, 1, 0.0),
	]
	p.color_ramp = alfa

	var malha := _fire_particle_mesh(0.09, true)
	(malha.material as StandardMaterial3D).emission_energy_multiplier = 0.22
	p.mesh = malha
	return p
