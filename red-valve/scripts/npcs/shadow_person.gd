extends CharacterBody3D
class_name ShadowPerson

## NPC "sombra de gente": silhueta humana montada por codigo (cabeca, torax,
## bracos, maos, pernas, pes), feita de escuridao. Ao entrar na cena ele sorteia
## uma silhueta (gordo, magro, cabeludo, careca...), vaga pela cidade e, quando
## encontra outra sombra, para e gesticula como se estivesse conversando.
## Depois de um tempo aleatorio se despede e volta a vagar.

enum State { WANDER, APPROACH, TALK, LEAVE }

const GRAVITY := 18.0
const BASE_HEIGHT := 1.75

@export_group("Silhueta")
## -1 = sorteia no _ready. 0..N = forca uma variacao especifica.
@export var variant_index: int = -1
## Semente propria; 0 = usa aleatoriedade global.
@export var variant_seed: int = 0

@export_group("Movimento")
@export var walk_speed: float = 1.3
@export var turn_speed: float = 6.0
## Raio (em metros) ao redor da posicao inicial em que ele fica vagando.
@export var wander_radius: float = 25.0
@export var use_navigation: bool = true

@export_group("Conversa")
@export var talk_detect_radius: float = 7.0
@export var talk_distance: float = 1.5
@export var talk_duration_min: float = 6.0
@export var talk_duration_max: float = 18.0
## Tempo minimo vagando antes de aceitar uma nova conversa.
@export var talk_cooldown: float = 8.0

var state: State = State.WANDER
var partner: ShadowPerson = null

var _rng := RandomNumberGenerator.new()
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _nav: NavigationAgent3D
var _nav_ready := false
var _scan_timer := 0.0
var _state_timer := 0.0
var _cooldown := 0.0
var _repath := 0.0

# fases proprias pra que duas sombras nunca gesticulem igual
var _walk_phase := 0.0
var _gesture_phase := 0.0
var _gesture_seed := 0.0
var _speaking := true
var _speak_timer := 0.0

# rig
var _rig: Node3D
var _hips: Node3D
var _spine: Node3D
var _neck: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D

var _profile: Dictionary = {}

static var _shared_material: ShaderMaterial

## Variacoes de silhueta. Todas usam o mesmo esqueleto, mudam as proporcoes.
const VARIANTS: Array[Dictionary] = [
	{"name": "magro_alto", "height": 1.10, "girth": 0.78, "limb": 0.80, "shoulders": 0.92, "belly": 0.0, "hair": "short"},
	{"name": "magro_cabeludo", "height": 1.02, "girth": 0.80, "limb": 0.82, "shoulders": 0.95, "belly": 0.0, "hair": "long"},
	{"name": "gordo", "height": 0.96, "girth": 1.45, "limb": 1.30, "shoulders": 1.10, "belly": 0.55, "hair": "short"},
	{"name": "gordo_careca", "height": 0.99, "girth": 1.35, "limb": 1.25, "shoulders": 1.15, "belly": 0.45, "hair": "bald"},
	{"name": "careca_forte", "height": 1.04, "girth": 1.15, "limb": 1.15, "shoulders": 1.25, "belly": 0.10, "hair": "bald"},
	{"name": "medio", "height": 1.00, "girth": 1.00, "limb": 1.00, "shoulders": 1.00, "belly": 0.05, "hair": "short"},
	{"name": "baixinho", "height": 0.86, "girth": 1.05, "limb": 1.05, "shoulders": 0.98, "belly": 0.15, "hair": "short"},
	{"name": "cabelo_preso", "height": 0.98, "girth": 0.92, "limb": 0.92, "shoulders": 0.90, "belly": 0.0, "hair": "bun"},
	{"name": "cabelo_espetado", "height": 1.05, "girth": 0.95, "limb": 0.95, "shoulders": 1.05, "belly": 0.0, "hair": "tuft"},
	{"name": "curvado", "height": 0.94, "girth": 1.08, "limb": 1.02, "shoulders": 0.88, "belly": 0.25, "hair": "long"},
]


func _ready() -> void:
	add_to_group("shadow_person")
	if variant_seed != 0:
		_rng.seed = variant_seed
	else:
		_rng.randomize()

	_home = global_position
	_target = _home
	_gesture_seed = _rng.randf() * 100.0
	_walk_phase = _rng.randf() * TAU
	_cooldown = _rng.randf_range(0.0, talk_cooldown)

	_build_body()
	_setup_collision()
	_setup_nav()
	_pick_wander_target()


# ---------------------------------------------------------------- construcao

func _get_material() -> ShaderMaterial:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = load("res://shaders/npcs/shadow_being.gdshader")
	return _shared_material


func _make_part(parent: Node3D, mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = _get_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.05)
	m.radial_segments = 10
	m.rings = 4
	return m


func _sphere(radius: float, squash := 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * squash
	m.radial_segments = 12
	m.rings = 8
	return m


## Cria um osso: pivo (Node3D) + membro pendurado pra baixo a partir dele.
func _make_limb(parent: Node3D, name_: String, len_: float, radius: float, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = at
	parent.add_child(pivot)
	_make_part(pivot, _capsule(radius, len_), Vector3(0, -len_ * 0.5, 0))
	return pivot


func _build_body() -> void:
	var idx := variant_index
	if idx < 0 or idx >= VARIANTS.size():
		idx = _rng.randi_range(0, VARIANTS.size() - 1)
	_profile = VARIANTS[idx].duplicate()

	# um empurraozinho aleatorio pra nao existirem duas sombras identicas
	_profile["height"] = float(_profile["height"]) * _rng.randf_range(0.94, 1.06)
	_profile["girth"] = float(_profile["girth"]) * _rng.randf_range(0.92, 1.08)
	_profile["limb"] = float(_profile["limb"]) * _rng.randf_range(0.93, 1.07)

	var h := BASE_HEIGHT * float(_profile["height"])
	var girth := float(_profile["girth"])
	var limb := float(_profile["limb"])

	var leg_len := h * 0.47
	var thigh := leg_len * 0.54
	var shin := leg_len - thigh
	var torso_len := h * 0.30
	var head_r := h * 0.072
	var hip_w := h * 0.055 * girth
	var shoulder_w := h * 0.105 * float(_profile["shoulders"])
	var arm_len := h * 0.335
	var upper_arm := arm_len * 0.53
	var forearm := arm_len - upper_arm

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0, leg_len, 0)
	_rig.add_child(_hips)

	# quadril / bacia
	_make_part(_hips, _capsule(h * 0.062 * girth, h * 0.10 * girth), Vector3.ZERO)

	_spine = Node3D.new()
	_spine.name = "Spine"
	_spine.rotation.x = deg_to_rad(_rng.randf_range(-2.0, 6.0))  # postura
	_hips.add_child(_spine)

	# torax
	_make_part(_spine, _capsule(h * 0.070 * girth, torso_len), Vector3(0, torso_len * 0.45, 0))
	# barriga (so aparece em quem tem)
	var belly := float(_profile["belly"])
	if belly > 0.01:
		var b := _make_part(_spine, _sphere(h * 0.070 * girth * (0.85 + belly), 0.9), Vector3(0, torso_len * 0.18, h * 0.012 * belly))
		b.scale = Vector3(1.0, 0.85, 1.0 + belly * 0.35)
	# ombros
	_make_part(_spine, _capsule(h * 0.045 * girth, shoulder_w * 2.0),
		Vector3(0, torso_len * 0.92, 0)).rotation.z = PI * 0.5

	# pescoco + cabeca
	_neck = Node3D.new()
	_neck.name = "Neck"
	_neck.position = Vector3(0, torso_len * 0.98, 0)
	_spine.add_child(_neck)
	_make_part(_neck, _capsule(h * 0.026, h * 0.055), Vector3(0, h * 0.025, 0))
	var head := _make_part(_neck, _sphere(head_r), Vector3(0, h * 0.052 + head_r * 0.9, 0))
	head.scale = Vector3(0.92, 1.12, 1.0)
	_add_hair(_neck, String(_profile["hair"]), head_r, h)

	# bracos
	_shoulder_l = _make_limb(_spine, "ShoulderL", upper_arm, h * 0.030 * limb,
		Vector3(shoulder_w, torso_len * 0.88, 0))
	_elbow_l = _make_limb(_shoulder_l, "ElbowL", forearm, h * 0.025 * limb, Vector3(0, -upper_arm, 0))
	_make_part(_elbow_l, _sphere(h * 0.030 * limb, 0.65), Vector3(0, -forearm - h * 0.018, 0))  # mao

	_shoulder_r = _make_limb(_spine, "ShoulderR", upper_arm, h * 0.030 * limb,
		Vector3(-shoulder_w, torso_len * 0.88, 0))
	_elbow_r = _make_limb(_shoulder_r, "ElbowR", forearm, h * 0.025 * limb, Vector3(0, -upper_arm, 0))
	_make_part(_elbow_r, _sphere(h * 0.030 * limb, 0.65), Vector3(0, -forearm - h * 0.018, 0))

	# pernas
	_hip_l = _make_limb(_hips, "HipL", thigh, h * 0.040 * limb, Vector3(hip_w, 0, 0))
	_knee_l = _make_limb(_hip_l, "KneeL", shin, h * 0.032 * limb, Vector3(0, -thigh, 0))
	_add_foot(_knee_l, shin, h)

	_hip_r = _make_limb(_hips, "HipR", thigh, h * 0.040 * limb, Vector3(-hip_w, 0, 0))
	_knee_r = _make_limb(_hip_r, "KneeR", shin, h * 0.032 * limb, Vector3(0, -thigh, 0))
	_add_foot(_knee_r, shin, h)

	set_meta("body_height", h)
	set_meta("variant", _profile["name"])


func _add_foot(knee: Node3D, shin: float, h: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(h * 0.055, h * 0.035, h * 0.13)
	_make_part(knee, box, Vector3(0, -shin - h * 0.012, h * 0.030))


func _add_hair(neck: Node3D, kind: String, head_r: float, h: float) -> void:
	var head_y := h * 0.052 + head_r * 0.9
	match kind:
		"bald":
			pass
		"short":
			var s := _make_part(neck, _sphere(head_r * 1.06), Vector3(0, head_y + head_r * 0.10, 0))
			s.scale = Vector3(0.95, 1.0, 1.02)
		"long":
			var t := _make_part(neck, _sphere(head_r * 1.08), Vector3(0, head_y + head_r * 0.08, 0))
			t.scale = Vector3(0.98, 1.0, 1.02)
			var fall := _make_part(neck, _capsule(head_r * 0.78, head_r * 2.6),
				Vector3(0, head_y - head_r * 0.9, -head_r * 0.45))
			fall.scale = Vector3(1.05, 1.0, 0.6)
		"bun":
			var b := _make_part(neck, _sphere(head_r * 1.04), Vector3(0, head_y + head_r * 0.08, 0))
			b.scale = Vector3(0.96, 1.0, 1.0)
			_make_part(neck, _sphere(head_r * 0.55), Vector3(0, head_y + head_r * 0.55, -head_r * 0.95))
		"tuft":
			var c := _make_part(neck, _sphere(head_r * 1.05), Vector3(0, head_y + head_r * 0.12, 0))
			c.scale = Vector3(0.95, 1.15, 1.0)


func _setup_collision() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			return  # a cena ja traz um collider proprio
	var h := float(get_meta("body_height", BASE_HEIGHT))
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = maxf(h, 0.8)
	shape.shape = cap
	shape.position = Vector3(0, h * 0.5, 0)
	add_child(shape)


func _setup_nav() -> void:
	if not use_navigation:
		return
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.4
	_nav.target_desired_distance = 0.6
	_nav.path_max_distance = 3.0
	_nav.avoidance_enabled = false
	add_child(_nav)
	# a nav map so fica pronta depois da primeira sincronizacao
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var map := get_world_3d().navigation_map
	_nav_ready = NavigationServer3D.map_get_iteration_id(map) > 0 \
		and not NavigationServer3D.map_get_regions(map).is_empty()
	if _nav_ready:
		_nav.target_position = _target


# ------------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_cooldown = maxf(0.0, _cooldown - delta)
	_state_timer -= delta

	match state:
		State.WANDER:
			_scan_for_partner(delta)
			_move_towards(_target, delta)
			if _reached(_target) or _state_timer <= 0.0:
				_pick_wander_target()
		State.APPROACH:
			if not _partner_valid():
				_end_talk()
			else:
				var p := partner.global_position
				if global_position.distance_to(p) <= talk_distance:
					_begin_talk()
				else:
					_move_towards(p, delta)
					if _state_timer <= 0.0:  # nao alcancou, desiste
						_end_talk()
		State.TALK:
			velocity.x = 0.0
			velocity.z = 0.0
			if not _partner_valid():
				_end_talk()
			else:
				_face(partner.global_position, delta * 0.8)
				_update_speaking(delta)
				if _state_timer <= 0.0:
					_end_talk()
		State.LEAVE:
			_move_towards(_target, delta)
			if _reached(_target) or _state_timer <= 0.0:
				state = State.WANDER
				_pick_wander_target()

	move_and_slide()
	_animate(delta)


func _reached(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < 0.7


func _move_towards(dest: Vector3, delta: float) -> void:
	var next := dest
	if _nav_ready and _nav != null:
		_repath -= delta
		if _repath <= 0.0 or _nav.target_position.distance_to(dest) > 1.0:
			_nav.target_position = dest
			_repath = 0.5
		if not _nav.is_navigation_finished():
			next = _nav.get_next_path_position()

	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 4.0 * delta)
		return
	dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * walk_speed, walk_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * walk_speed, walk_speed * 6.0 * delta)
	_face(global_position + dir, delta)


func _face(target: Vector3, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	var want := atan2(to.x, to.z)
	rotation.y = rotate_toward(rotation.y, want, turn_speed * delta)


func _pick_wander_target() -> void:
	var ang := _rng.randf() * TAU
	var dist := _rng.randf_range(wander_radius * 0.25, wander_radius)
	_target = _home + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
	if _nav_ready:
		_target = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, _target)
	_state_timer = _rng.randf_range(8.0, 20.0)
	_repath = 0.0


# ---------------------------------------------------------------- conversa

func _partner_valid() -> bool:
	return is_instance_valid(partner) and partner.is_inside_tree()


func _scan_for_partner(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = _rng.randf_range(0.4, 0.9)
	if _cooldown > 0.0 or partner != null:
		return

	var best: ShadowPerson = null
	var best_d := talk_detect_radius
	for n in get_tree().get_nodes_in_group("shadow_person"):
		var other := n as ShadowPerson
		if other == null or other == self:
			continue
		if other.state != State.WANDER or other.partner != null or other._cooldown > 0.0:
			continue
		# so um dos dois puxa assunto, senao os dois se convidam ao mesmo tempo
		if other.get_instance_id() < get_instance_id():
			continue
		var d := global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other

	if best != null:
		_invite(best)


func _invite(other: ShadowPerson) -> void:
	partner = other
	other.partner = self
	var t := _rng.randf_range(6.0, 12.0)
	state = State.APPROACH
	_state_timer = t
	other.state = State.APPROACH
	other._state_timer = t


func _begin_talk() -> void:
	var dur := _rng.randf_range(talk_duration_min, talk_duration_max)
	state = State.TALK
	_state_timer = dur
	_speaking = _rng.randf() < 0.5
	_speak_timer = _rng.randf_range(1.5, 3.5)
	if _partner_valid() and partner.state != State.TALK:
		partner.state = State.TALK
		partner._state_timer = dur
		partner._speaking = not _speaking
		partner._speak_timer = _speak_timer


func _update_speaking(delta: float) -> void:
	_speak_timer -= delta
	if _speak_timer <= 0.0:
		_speaking = not _speaking
		_speak_timer = _rng.randf_range(1.5, 4.0)
		if _partner_valid() and partner.state == State.TALK:
			partner._speaking = not _speaking
			partner._speak_timer = _speak_timer


func _end_talk() -> void:
	var other := partner
	partner = null
	_cooldown = talk_cooldown
	state = State.LEAVE
	_pick_wander_target()
	_state_timer = _rng.randf_range(6.0, 12.0)
	if is_instance_valid(other) and other.partner == self:
		other.partner = null
		other._cooldown = other.talk_cooldown
		other.state = State.LEAVE
		other._pick_wander_target()


# ------------------------------------------------------------------ animacao

func _animate(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var moving := planar > 0.15
	var talking := state == State.TALK

	if moving:
		_walk_phase += delta * (4.2 + planar * 1.6)
	_gesture_phase += delta

	var blend := clampf(planar / maxf(walk_speed, 0.01), 0.0, 1.0)
	_apply_walk(blend)
	if talking:
		_apply_talk(delta)
	else:
		_apply_idle(blend)


func _apply_walk(blend: float) -> void:
	var t := _walk_phase
	var swing := 0.62 * blend
	var s := sin(t)
	var s2 := sin(t + PI)

	_hip_l.rotation.x = s * swing
	_hip_r.rotation.x = s2 * swing
	# joelho dobra pra TRAS (calcanhar sobe) na fase em que a perna vem pra frente
	_knee_l.rotation.x = (0.06 + maxf(0.0, -sin(t + 1.5)) * 1.05 * blend)
	_knee_r.rotation.x = (0.06 + maxf(0.0, -sin(t + PI + 1.5)) * 1.05 * blend)

	# tronco balanca de leve e o quadril sobe/desce a cada passo
	_hips.position.y = _hips_rest() + absf(sin(t)) * 0.035 * blend
	_hips.rotation.y = sin(t) * 0.10 * blend
	_spine.rotation.y = -sin(t) * 0.12 * blend
	_spine.rotation.z = sin(t) * 0.03 * blend

	if state != State.TALK:
		_shoulder_l.rotation.x = s2 * swing * 0.8
		_shoulder_r.rotation.x = s * swing * 0.8
		_shoulder_l.rotation.z = -0.09 - 0.05 * blend
		_shoulder_r.rotation.z = 0.09 + 0.05 * blend
		_elbow_l.rotation.x = -0.25 - 0.35 * blend * maxf(0.0, s2)
		_elbow_r.rotation.x = -0.25 - 0.35 * blend * maxf(0.0, s)


func _hips_rest() -> float:
	if _hips.has_meta("rest_y"):
		return float(_hips.get_meta("rest_y"))
	_hips.set_meta("rest_y", _hips.position.y)
	return _hips.position.y


func _apply_idle(blend: float) -> void:
	var b := 1.0 - blend
	if b <= 0.01:
		_neck.rotation = Vector3.ZERO
		return
	var t := _gesture_phase + _gesture_seed
	# respiracao e um leve olhar em volta quando esta parado
	_spine.rotation.z = lerp(_spine.rotation.z, sin(t * 0.7) * 0.02 * b, 0.2)
	_neck.rotation.y = lerp(_neck.rotation.y, sin(t * 0.35) * 0.45 * b, 0.06)
	_neck.rotation.x = lerp(_neck.rotation.x, sin(t * 0.9) * 0.05 * b, 0.1)
	_hips.position.y = _hips_rest() + sin(t * 1.1) * 0.006 * b


## Gesticulacao de conversa: quem esta "falando" mexe muito os bracos,
## quem escuta faz movimentos pequenos e acena com a cabeca.
func _apply_talk(delta: float) -> void:
	var t := _gesture_phase * (2.1 if _speaking else 1.1) + _gesture_seed
	var amp := 1.0 if _speaking else 0.28
	var w := clampf(delta * 8.0, 0.0, 1.0)

	var up_l := -0.75 - sin(t * 1.3) * 0.45 * amp - 0.25 * amp
	var up_r := -0.70 - sin(t * 1.1 + 1.7) * 0.45 * amp - 0.25 * amp
	_shoulder_l.rotation.x = lerp(_shoulder_l.rotation.x, up_l * amp, w)
	_shoulder_r.rotation.x = lerp(_shoulder_r.rotation.x, up_r * amp, w)
	_shoulder_l.rotation.z = lerp(_shoulder_l.rotation.z, -0.22 - sin(t * 0.8) * 0.20 * amp, w)
	_shoulder_r.rotation.z = lerp(_shoulder_r.rotation.z, 0.22 + sin(t * 0.9 + 0.6) * 0.20 * amp, w)

	var el_l := -1.15 - sin(t * 1.7 + 0.4) * 0.55 * amp
	var el_r := -1.10 - sin(t * 1.5 + 2.2) * 0.55 * amp
	_elbow_l.rotation.x = lerp(_elbow_l.rotation.x, el_l * (0.5 + amp * 0.5), w)
	_elbow_r.rotation.x = lerp(_elbow_r.rotation.x, el_r * (0.5 + amp * 0.5), w)

	# cabeca: quem fala balanca, quem ouve concorda
	var nod := sin(t * (1.6 if _speaking else 2.4)) * (0.07 if _speaking else 0.13)
	_neck.rotation.x = lerp(_neck.rotation.x, nod, w)
	_neck.rotation.y = lerp(_neck.rotation.y, sin(t * 0.9) * 0.10 * amp, w)
	_spine.rotation.y = lerp(_spine.rotation.y, sin(t * 0.6) * 0.08 * amp, w)
	_hips.position.y = _hips_rest() + sin(t * 1.4) * 0.008
