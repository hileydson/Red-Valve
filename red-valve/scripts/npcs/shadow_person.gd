extends CharacterBody3D
class_name ShadowPerson

## NPC "sombra de gente": silhueta humana montada por codigo (cabeca, torax,
## bracos, maos, pernas, pes), feita de escuridao. Ao entrar na cena ele sorteia
## uma silhueta (gordo, magro, cabeludo, careca...), vaga pela cidade e, quando
## encontra outra sombra, para e gesticula como se estivesse conversando.
## Depois de um tempo aleatorio se despede e volta a vagar.
##
## Adultos: conversam com adultos e de vez em quando param pra catar algo do chao.
## Criancas: correm de um lado pro outro, brincam de pega-pega SO com outras
## criancas, e as vezes andam junto de um adulto por um tempo.

enum State { WANDER, APPROACH, TALK, LEAVE, PICKUP, FOLLOW, PLAY }

const GRAVITY := 18.0
const BASE_HEIGHT := 1.75

@export_group("Silhueta")
## Auto = sorteia usando child_chance. Adulto/Crianca forcam o tipo.
@export_enum("Auto", "Adulto", "Crianca") var age_group: int = 0
## Chance de nascer crianca quando age_group = Auto.
@export_range(0.0, 1.0) var child_chance: float = 0.25
## -1 = sorteia no _ready. 0..N = forca uma variacao da lista da idade.
@export var variant_index: int = -1
## Semente propria; 0 = usa aleatoriedade global.
@export var variant_seed: int = 0

@export_group("Movimento")
@export var walk_speed: float = 1.3
## Criancas usam este passo no lugar do walk_speed.
@export var child_walk_speed: float = 1.7
## Multiplicador de velocidade nas corridinhas e no pega-pega.
@export var run_multiplier: float = 2.0
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

@export_group("Adulto")
## Intervalo (s) entre uma catada de chao e outra.
@export var pickup_interval_min: float = 25.0
@export var pickup_interval_max: float = 70.0

@export_group("Crianca")
## Raio de busca por um adulto pra acompanhar.
@export var follow_radius: float = 14.0
## Chance, a cada novo destino, de sair atras de um adulto.
@export_range(0.0, 1.0) var follow_chance: float = 0.25
@export var follow_duration_min: float = 8.0
@export var follow_duration_max: float = 20.0
## Distancia que a crianca tenta manter do adulto.
@export var follow_distance: float = 1.8

@export_group("Passos")
## Volume dos passos do adulto, somado ao volume do proprio no de audio.
@export var step_volume_db: float = 0.0
## Crianca pisa mais leve: este valor e SOMADO ao de cima (negativo = mais baixo).
@export var child_step_volume_db: float = -7.0
@export var step_pitch: float = 1.0
## Pitch dos passos da crianca andando...
@export var child_step_pitch: float = 1.35
## ...e correndo (interpolado conforme a velocidade).
@export var child_run_step_pitch: float = 1.75
## Variacao aleatoria de pitch, pra dois passos nunca soarem iguais.
@export var step_pitch_jitter: float = 0.06

var state: State = State.WANDER
var partner: ShadowPerson = null
## Adultos so interagem com adultos, criancas so com criancas.
var is_child := false

var _rng := RandomNumberGenerator.new()
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _nav: NavigationAgent3D
var _nav_ready := false
var _scan_timer := 0.0
var _state_timer := 0.0
var _cooldown := 0.0
var _repath := 0.0
var _speed_mul := 1.0
var _dart_timer := 0.0
var _action_timer := 0.0
var _pickup_dur := 3.0
var _follow_target: ShadowPerson = null
var _play_center := Vector3.ZERO
var _play_chaser := false
var _play_dir := 1.0

# fases proprias pra que duas sombras nunca gesticulem igual
var _walk_phase := 0.0
var _gesture_phase := 0.0
var _gesture_seed := 0.0
var _speaking := true
var _speak_timer := 0.0

# passos
var _steps: Node = null
var _steps_base_db := 0.0
var _step_half := 0

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

# populacao viva, usada pra segurar a proporcao de criancas na cidade
static var _population := 0
static var _child_population := 0

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

## Criancas: baixas, cabeca grande, pernas curtas, ombros estreitos.
const CHILD_VARIANTS: Array[Dictionary] = [
	{"name": "crianca_pequena", "height": 0.50, "girth": 1.15, "limb": 1.20, "shoulders": 0.80, "belly": 0.20, "hair": "short", "head": 1.30},
	{"name": "crianca_magra", "height": 0.59, "girth": 0.95, "limb": 1.05, "shoulders": 0.78, "belly": 0.05, "hair": "short", "head": 1.22},
	{"name": "crianca_cabeluda", "height": 0.56, "girth": 1.00, "limb": 1.10, "shoulders": 0.76, "belly": 0.10, "hair": "long", "head": 1.26},
	{"name": "crianca_rabo_de_cavalo", "height": 0.58, "girth": 0.98, "limb": 1.08, "shoulders": 0.76, "belly": 0.08, "hair": "bun", "head": 1.24},
	{"name": "crianca_espetada", "height": 0.54, "girth": 1.05, "limb": 1.12, "shoulders": 0.80, "belly": 0.15, "hair": "tuft", "head": 1.28},
	{"name": "crianca_careca", "height": 0.52, "girth": 1.10, "limb": 1.15, "shoulders": 0.78, "belly": 0.18, "hair": "bald", "head": 1.32},
	{"name": "crianca_maior", "height": 0.65, "girth": 0.92, "limb": 1.00, "shoulders": 0.84, "belly": 0.0, "hair": "short", "head": 1.16},
]


func _ready() -> void:
	add_to_group("shadow_person")
	if variant_seed != 0:
		_rng.seed = variant_seed
	else:
		# randomize() pode devolver a MESMA semente pra varios nos criados no
		# mesmo instante (todos sairiam identicos). Misturar o id da instancia
		# com o randi() global garante uma semente diferente pra cada um.
		_rng.seed = hash(str(get_instance_id(), "_", Time.get_ticks_usec(), "_", randi()))

	match age_group:
		1: is_child = false
		2: is_child = true
		_: is_child = _roll_child()

	_home = global_position
	_target = _home
	_gesture_seed = _rng.randf() * 100.0
	_walk_phase = _rng.randf() * TAU
	_cooldown = _rng.randf_range(0.0, talk_cooldown)
	_action_timer = _rng.randf_range(pickup_interval_min * 0.3, pickup_interval_max)
	_dart_timer = _rng.randf_range(1.0, 5.0)
	_population += 1
	if is_child:
		_child_population += 1
		walk_speed = child_walk_speed
		add_to_group("shadow_child")
	else:
		add_to_group("shadow_adult")

	_find_steps_player()
	_build_body()
	_setup_collision()
	_setup_nav()
	_pick_wander_target()


## Sorteia a idade, mas com cota: a proporcao de criancas VIVAS na cena nunca
## passa de child_chance. Sem isso, quatro sombras podiam dar azar e virar
## quatro criancas; com 0.25, so a cada quarta sombra uma pode ser crianca.
func _roll_child() -> bool:
	if child_chance <= 0.0:
		return false
	if _rng.randf() >= child_chance:
		return false
	var ratio := float(_child_population + 1) / float(_population + 1)
	return ratio <= child_chance + 0.0001


func _exit_tree() -> void:
	_population = maxi(0, _population - 1)
	if is_child:
		_child_population = maxi(0, _child_population - 1)


## Procura o no de audio de passos que voce tiver colocado na cena. Aceita
## AudioStreamPlayer3D ou 2D, com qualquer nome parecido com "passos"/"steps";
## se nao achar por nome, pega o primeiro player de audio filho.
func _find_steps_player() -> void:
	var fallback: Node = null
	for c in get_children():
		var is_player := c is AudioStreamPlayer3D or c is AudioStreamPlayer or c is AudioStreamPlayer2D
		if not is_player:
			continue
		if fallback == null:
			fallback = c
		var n := String(c.name).to_lower()
		if n.contains("step") or n.contains("passo") or n.contains("foot"):
			_steps = c
			break
	if _steps == null:
		_steps = fallback
	if _steps != null:
		_steps_base_db = _steps.volume_db
		_steps.volume_db = _steps_base_db + step_volume_db + (child_step_volume_db if is_child else 0.0)


## Toca um passo. Crianca correndo sobe o pitch junto com a velocidade.
func _play_step(speed_ratio: float) -> void:
	if _steps == null:
		return
	var pitch := step_pitch
	if is_child:
		pitch = lerpf(child_step_pitch, child_run_step_pitch, clampf(speed_ratio - 1.0, 0.0, 1.0))
	pitch += _rng.randf_range(-step_pitch_jitter, step_pitch_jitter)
	_steps.pitch_scale = maxf(pitch, 0.05)
	_steps.play()


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
	var list := CHILD_VARIANTS if is_child else VARIANTS
	var idx := variant_index
	if idx < 0 or idx >= list.size():
		idx = _rng.randi_range(0, list.size() - 1)
	_profile = list[idx].duplicate()

	# um empurraozinho aleatorio pra nao existirem duas sombras identicas
	_profile["height"] = float(_profile["height"]) * _rng.randf_range(0.94, 1.06)
	_profile["girth"] = float(_profile["girth"]) * _rng.randf_range(0.92, 1.08)
	_profile["limb"] = float(_profile["limb"]) * _rng.randf_range(0.93, 1.07)

	var h := BASE_HEIGHT * float(_profile["height"])
	var girth := float(_profile["girth"])
	var limb := float(_profile["limb"])

	# crianca: perna curta, tronco e cabeca proporcionalmente maiores
	var leg_len := h * (0.42 if is_child else 0.47)
	var thigh := leg_len * 0.54
	var shin := leg_len - thigh
	var torso_len := h * (0.32 if is_child else 0.30)
	var head_r := h * 0.072 * float(_profile.get("head", 1.0))
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
	set_meta("is_child", is_child)


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
	cap.radius = 0.20 if is_child else 0.28
	cap.height = maxf(h, 0.6)
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
	_speed_mul = move_toward(_speed_mul, 1.0, delta * 1.2)

	match state:
		State.WANDER:
			_scan_for_partner(delta)
			if is_child:
				_update_darting(delta)
			else:
				_update_pickup_urge(delta)
			_move_towards(_target, delta)
			if _reached(_target) or _state_timer <= 0.0:
				_pick_wander_target()
		State.PICKUP:
			# para, abaixa, cata algo do chao e levanta
			velocity.x = move_toward(velocity.x, 0.0, walk_speed * 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, walk_speed * 6.0 * delta)
			if _state_timer <= 0.0:
				state = State.WANDER
				_pick_wander_target()
		State.FOLLOW:
			if not is_instance_valid(_follow_target) or _state_timer <= 0.0:
				_follow_target = null
				state = State.WANDER
				_pick_wander_target()
			else:
				_scan_for_partner(delta)
				var ap := _follow_target.global_position
				var d := global_position.distance_to(ap)
				if d > follow_distance * 1.4:
					# fica pra tras: corre pra alcancar
					_speed_mul = maxf(_speed_mul, 1.0 + minf(d * 0.12, run_multiplier - 1.0))
					_move_towards(ap, delta)
				else:
					velocity.x = move_toward(velocity.x, 0.0, walk_speed * 5.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, walk_speed * 5.0 * delta)
					_face(ap, delta * 0.6)
		State.PLAY:
			if not _partner_valid():
				_end_interaction()
			else:
				_update_play(delta)
		State.APPROACH:
			if not _partner_valid():
				_end_interaction()
			else:
				var p := partner.global_position
				if global_position.distance_to(p) <= talk_distance:
					_begin_interaction()
				else:
					_move_towards(p, delta)
					if _state_timer <= 0.0:  # nao alcancou, desiste
						_end_interaction()
		State.TALK:
			velocity.x = 0.0
			velocity.z = 0.0
			if not _partner_valid():
				_end_interaction()
			else:
				_face(partner.global_position, delta * 0.8)
				_update_speaking(delta)
				if _state_timer <= 0.0:
					_end_interaction()
		State.LEAVE:
			_move_towards(_target, delta)
			if _reached(_target) or _state_timer <= 0.0:
				state = State.WANDER
				_pick_wander_target()

	move_and_slide()
	_animate(delta)


func _reached(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < 0.7


func _move_towards(dest: Vector3, delta: float, with_nav := true) -> void:
	var next := dest
	if with_nav and _nav_ready and _nav != null:
		_repath -= delta
		if _repath <= 0.0 or _nav.target_position.distance_to(dest) > 1.0:
			_nav.target_position = dest
			_repath = 0.5
		if not _nav.is_navigation_finished():
			next = _nav.get_next_path_position()

	var spd := walk_speed * _speed_mul
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, spd * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, spd * 4.0 * delta)
		return
	dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * spd, spd * 6.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, spd * 6.0 * delta)
	_face(global_position + dir, delta)


func _face(target: Vector3, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	var want := atan2(to.x, to.z)
	rotation.y = rotate_toward(rotation.y, want, turn_speed * delta)


func _pick_wander_target() -> void:
	# crianca solta perto de um adulto as vezes larga tudo e vai atras dele
	if is_child and state == State.WANDER and partner == null \
			and _rng.randf() < follow_chance and _try_follow_adult():
		return
	var ang := _rng.randf() * TAU
	# crianca nao vai longe: fica indo e voltando em trechos curtos
	var dist := _rng.randf_range(wander_radius * 0.10, wander_radius * 0.35) if is_child \
		else _rng.randf_range(wander_radius * 0.25, wander_radius)
	_target = _home + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
	if _nav_ready:
		_target = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, _target)
	_state_timer = _rng.randf_range(4.0, 9.0) if is_child else _rng.randf_range(8.0, 20.0)
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
		if other.is_child != is_child:
			continue  # adulto conversa com adulto, crianca brinca com crianca
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


## Adultos param e conversam; criancas comecam a brincar de pega-pega.
func _begin_interaction() -> void:
	var dur := _rng.randf_range(talk_duration_min, talk_duration_max)
	if is_child:
		_begin_play(dur * 1.2)
		return
	state = State.TALK
	_state_timer = dur
	_speaking = _rng.randf() < 0.5
	_speak_timer = _rng.randf_range(1.5, 3.5)
	if _partner_valid() and partner.state != State.TALK:
		partner.state = State.TALK
		partner._state_timer = dur
		partner._speaking = not _speaking
		partner._speak_timer = _speak_timer


func _begin_play(dur: float) -> void:
	var center := global_position
	if _partner_valid():
		center = (global_position + partner.global_position) * 0.5
	_play_center = center
	_play_chaser = _rng.randf() < 0.5
	_play_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	state = State.PLAY
	_state_timer = dur
	if _partner_valid() and partner.state != State.PLAY:
		partner._play_center = center
		partner._play_chaser = not _play_chaser
		partner._play_dir = -_play_dir
		partner.state = State.PLAY
		partner._state_timer = dur


func _update_speaking(delta: float) -> void:
	_speak_timer -= delta
	if _speak_timer <= 0.0:
		_speaking = not _speaking
		_speak_timer = _rng.randf_range(1.5, 4.0)
		if _partner_valid() and partner.state == State.TALK:
			partner._speaking = not _speaking
			partner._speak_timer = _speak_timer


func _end_interaction() -> void:
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


# --------------------------------------------------- catar do chao (adulto)

func _update_pickup_urge(delta: float) -> void:
	_action_timer -= delta
	if _action_timer > 0.0 or partner != null:
		return
	_action_timer = _rng.randf_range(pickup_interval_min, pickup_interval_max)
	_pickup_dur = _rng.randf_range(2.6, 4.2)
	_state_timer = _pickup_dur
	state = State.PICKUP


# ------------------------------------------------- corridinhas e pega-pega

## Crianca nao anda em linha reta: dispara pra um lado, freia, dispara pro outro.
func _update_darting(delta: float) -> void:
	_dart_timer -= delta
	if _dart_timer > 0.0:
		return
	_dart_timer = _rng.randf_range(1.5, 4.5)
	_speed_mul = _rng.randf_range(1.4, run_multiplier)
	# vira bruscamente pra um dos lados e sai correndo
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var ang := rotation.y + side * _rng.randf_range(0.8, 2.4)
	var dist := _rng.randf_range(2.5, 7.0)
	_target = global_position + Vector3(sin(ang), 0.0, cos(ang)) * dist
	if _nav_ready:
		_target = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, _target)
	_state_timer = _rng.randf_range(3.0, 6.0)
	_repath = 0.0


func _update_play(delta: float) -> void:
	var pp := partner.global_position
	var dist := global_position.distance_to(pp)
	_speed_mul = maxf(_speed_mul, run_multiplier * 0.9)

	if _play_chaser:
		_move_towards(pp, delta, false)
		if dist < 0.9:
			_swap_play_roles()   # pegou! troca quem corre atras
	else:
		# foge, mas sem sair da area da brincadeira
		var away := global_position - pp
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		away = away.normalized().rotated(Vector3.UP, _play_dir * 0.5)
		var dest := global_position + away * 3.0
		if _play_center.distance_to(dest) > 6.0:
			dest = _play_center
			_play_dir = -_play_dir
		_move_towards(dest, delta, false)

	# pulinhos de empolgacao
	if is_on_floor() and _rng.randf() < delta * 0.9:
		velocity.y = 3.0

	if _state_timer <= 0.0:
		_end_interaction()


func _swap_play_roles() -> void:
	_play_chaser = false
	_play_dir = -_play_dir
	if is_on_floor():
		velocity.y = 3.4
	if _partner_valid():
		partner._play_chaser = true
		if partner.is_on_floor():
			partner.velocity.y = 3.0


# ------------------------------------------- crianca acompanhando um adulto

func _try_follow_adult() -> bool:
	var best: ShadowPerson = null
	var best_d := follow_radius
	for n in get_tree().get_nodes_in_group("shadow_adult"):
		var a := n as ShadowPerson
		if a == null or a.is_child:
			continue
		var d := global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		return false
	_follow_target = best
	state = State.FOLLOW
	_state_timer = _rng.randf_range(follow_duration_min, follow_duration_max)
	_repath = 0.0
	return true


# ------------------------------------------------------------------ animacao

func _animate(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var moving := planar > 0.15
	var talking := state == State.TALK

	if moving:
		var before := _walk_phase
		_walk_phase += delta * (4.2 + planar * 1.6)
		# cada meio ciclo do balanco das pernas e um pe batendo no chao
		var half := int(floor(_walk_phase / PI))
		if half != int(floor(before / PI)) and is_on_floor() and state != State.PICKUP:
			_play_step(planar / maxf(walk_speed, 0.01))
		_step_half = half
	_gesture_phase += delta

	if state == State.PICKUP:
		_apply_pickup(delta)
		return

	var blend := clampf(planar / maxf(walk_speed, 0.01), 0.0, 1.0)
	_apply_walk(blend)
	if talking:
		_apply_talk(delta)
	elif state == State.PLAY:
		_apply_play_anim(delta, blend)
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


## Abaixa, estende o braco ate o chao, segura um instante e levanta.
func _apply_pickup(delta: float) -> void:
	var elapsed := _pickup_dur - _state_timer
	var down := smoothstep(0.0, 1.0, clampf(elapsed / maxf(_pickup_dur * 0.35, 0.01), 0.0, 1.0))
	var up := smoothstep(0.0, 1.0, clampf((elapsed - _pickup_dur * 0.62) / maxf(_pickup_dur * 0.38, 0.01), 0.0, 1.0))
	var p := down * (1.0 - up)
	var w := clampf(delta * 9.0, 0.0, 1.0)

	# agacha: quadril desce, joelhos pra frente, tronco inclina
	_hips.position.y = lerp(_hips.position.y, _hips_rest() - _hips_rest() * 0.30 * p, w)
	_hip_l.rotation.x = lerp(_hip_l.rotation.x, -0.55 * p, w)
	_hip_r.rotation.x = lerp(_hip_r.rotation.x, -0.50 * p, w)
	_knee_l.rotation.x = lerp(_knee_l.rotation.x, 1.05 * p, w)
	_knee_r.rotation.x = lerp(_knee_r.rotation.x, 1.00 * p, w)
	_hips.rotation.y = lerp(_hips.rotation.y, 0.0, w)
	_spine.rotation.x = lerp(_spine.rotation.x, 0.85 * p, w)
	_spine.rotation.y = lerp(_spine.rotation.y, 0.10 * p, w)
	_neck.rotation.x = lerp(_neck.rotation.x, 0.35 * p, w)
	_neck.rotation.y = lerp(_neck.rotation.y, 0.0, w)

	# braco direito estende ate o chao e fecha a mao no fim da descida
	var grab := smoothstep(0.55, 1.0, p)
	_shoulder_r.rotation.x = lerp(_shoulder_r.rotation.x, -0.55 * p, w)
	_shoulder_r.rotation.z = lerp(_shoulder_r.rotation.z, 0.05 + 0.10 * p, w)
	_elbow_r.rotation.x = lerp(_elbow_r.rotation.x, -0.10 * p - 0.35 * (1.0 - grab) * p, w)
	# o outro braco fica pra tras, fazendo contrapeso
	_shoulder_l.rotation.x = lerp(_shoulder_l.rotation.x, 0.45 * p, w)
	_shoulder_l.rotation.z = lerp(_shoulder_l.rotation.z, -0.25 * p, w)
	_elbow_l.rotation.x = lerp(_elbow_l.rotation.x, -0.30 * p, w)


## Brincadeira: bracos pra cima, corpo solto, cabeca balancando.
func _apply_play_anim(delta: float, blend: float) -> void:
	var t := _gesture_phase * 3.2 + _gesture_seed
	var w := clampf(delta * 8.0, 0.0, 1.0)
	var amp := 0.6 + 0.4 * blend

	_shoulder_l.rotation.x = lerp(_shoulder_l.rotation.x, -1.5 - sin(t) * 0.7 * amp, w)
	_shoulder_r.rotation.x = lerp(_shoulder_r.rotation.x, -1.5 - sin(t + 2.1) * 0.7 * amp, w)
	_shoulder_l.rotation.z = lerp(_shoulder_l.rotation.z, -0.45 - sin(t * 1.3) * 0.30 * amp, w)
	_shoulder_r.rotation.z = lerp(_shoulder_r.rotation.z, 0.45 + sin(t * 1.1 + 0.7) * 0.30 * amp, w)
	_elbow_l.rotation.x = lerp(_elbow_l.rotation.x, -0.9 - sin(t * 1.6) * 0.5 * amp, w)
	_elbow_r.rotation.x = lerp(_elbow_r.rotation.x, -0.9 - sin(t * 1.4 + 1.9) * 0.5 * amp, w)
	_neck.rotation.x = lerp(_neck.rotation.x, -0.12 + sin(t * 1.8) * 0.10, w)
	_neck.rotation.y = lerp(_neck.rotation.y, sin(t * 0.7) * 0.35, w)
	_spine.rotation.z = lerp(_spine.rotation.z, sin(t * 0.9) * 0.10 * amp, w)
