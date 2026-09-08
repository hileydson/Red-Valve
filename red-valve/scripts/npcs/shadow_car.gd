extends CharacterBody3D
class_name ShadowCar

const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")

## Sombra de carro. Mesmo material e mesmo shader das ShadowPerson, entao o
## visual e identico (fumaca, glitch, silhueta esfarelada) — muda so a forma,
## que aqui e de carro.
##
## Ele NAO usa navmesh nem Path3D: a cidade nao tem nenhum dos dois. Em vez
## disso o carro vai sondando o chao com raycast e so anda onde o que esta
## embaixo pertence ao no das ruas ("Roads"). Isso mantem ele no asfalto sem
## voce precisar desenhar rota nenhuma — e continua valendo se a cidade mudar.
##
## Coloque poucos, espalhados, JA EM CIMA de uma rua. Longe do player ele
## simplesmente some, e volta a aparecer quando o player se aproxima.

const GRAVITY := 18.0

@export_group("Forma")
## -1 = sorteia no _ready. 0..N = forca uma das variacoes.
@export var variant_index: int = -1
@export var variant_seed: int = 0

@export_group("Movimento")
## Velocidade de passeio (m/s). Cada carro sorteia entre as duas.
@export var speed_min: float = 2.5
@export var speed_max: float = 7.0
## Quanto ele freia pra fazer curva.
@export var turn_slowdown: float = 0.55
@export var accel: float = 3.0
## Angulo maximo das rodas dianteiras. Carro nao gira em cima do proprio eixo:
## a guinada sai da roda da frente esterçada, entao parado ele NAO vira.
@export var max_steer_deg: float = 32.0
## Velocidade minima que ele mantem no meio de uma curva (nao para pra girar).
@export var min_turn_speed: float = 1.1
## Velocidade de re na manobra de meia-volta.
@export var reverse_speed: float = 1.6

@export_group("Motor (som)")
## Tempo do fade in do motor quando o carro comeca a andar.
@export var engine_fade_in: float = 0.7
## Tempo do fade out ate silenciar quando ele para.
@export var engine_fade_out: float = 0.5
@export var engine_pitch_idle: float = 0.75
@export var engine_pitch_max: float = 1.25

@export_group("Fumaca")
## Os carros sao mais fumacados que as pessoas: superficie lisa e grande
## denuncia a caixa muito mais facil que um corpo cheio de membros.
@export var smoke_billow: float = 0.16
@export var smoke_body_dissolve: float = 0.46
@export var smoke_edge_dissolve: float = 1.75
@export var smoke_scale: float = 4.5
@export var smoke_wisp_scale: float = 16.0

@export_group("Ruas")
## Nome do no que contem as ruas. Qualquer colisor abaixo dele conta como pista.
@export var road_node_name: String = "Roads"
## Alternativa: coloque os nos de rua no grupo abaixo em vez de usar o nome.
@export var road_group: String = "shadow_road"
## Camada fisica onde esta a colisao da cidade.
@export_flags_3d_physics var road_mask: int = 2
## Meia largura da pista usada pra centralizar o carro.
@export var lane_half_width: float = 2.2
## Folga lateral, alem da largura do carro, pra considerar que um pedestre
## esta na frente e o carro precisa parar.
@export var pedestrian_margin: float = 0.9

@export_group("Sumico")
## Alem desta distancia do player o carro some (e volta perto de novo).
@export var despawn_distance: float = 110.0
## 0 desliga o sumico por distancia.
@export var despawn_enabled: bool = true

var _rng := RandomNumberGenerator.new()
var _speed := 4.0
var _cruise := 4.0
var _heading := 0.0
var _probe_timer := 0.0
var _stuck_timer := 0.0
var _blocked := false
var _wheels: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _wheel_radius := 0.34
var _wheelbase := 2.4
var _steer := 0.0
var _reverse := 0.0
var _engine: Node = null
var _engine_target_db := 0.0
var _engine_db := -60.0
var _body_root: Node3D
var _player: Node3D
var _visible_now := true
var _check_timer := 0.0
var _profile: Dictionary = {}

static var _shared_material: ShaderMaterial

## Formas de carro. Tudo em metros; "cabin" e a cabine, "bed" a cacamba.
const VARIANTS: Array[Dictionary] = [
	{"name": "sedan", "len": 4.4, "wid": 1.8, "hei": 0.72, "ground": 0.30, "wheel": 0.33,
		"cabin": Vector3(1.9, 0.60, 1.62), "cabin_z": -0.10, "bed": 0.0, "nose": 0.55},
	{"name": "hatch", "len": 3.7, "wid": 1.72, "hei": 0.70, "ground": 0.28, "wheel": 0.31,
		"cabin": Vector3(1.9, 0.62, 1.55), "cabin_z": -0.30, "bed": 0.0, "nose": 0.40},
	{"name": "van", "len": 4.8, "wid": 1.95, "hei": 1.35, "ground": 0.34, "wheel": 0.36,
		"cabin": Vector3(2.6, 0.55, 1.80), "cabin_z": 0.20, "bed": 0.0, "nose": 0.25},
	{"name": "pickup", "len": 5.0, "wid": 1.9, "hei": 0.78, "ground": 0.40, "wheel": 0.40,
		"cabin": Vector3(1.7, 0.72, 1.72), "cabin_z": 0.35, "bed": 1.9, "nose": 0.60},
	{"name": "caminhao", "len": 6.2, "wid": 2.2, "hei": 1.10, "ground": 0.46, "wheel": 0.46,
		"cabin": Vector3(1.8, 1.00, 2.05), "cabin_z": 1.85, "bed": 3.0, "nose": 0.20},
	{"name": "onibus", "len": 8.5, "wid": 2.4, "hei": 2.10, "ground": 0.44, "wheel": 0.44,
		"cabin": Vector3(0.0, 0.0, 0.0), "cabin_z": 0.0, "bed": 0.0, "nose": 0.10},
	{"name": "esportivo", "len": 4.2, "wid": 1.85, "hei": 0.58, "ground": 0.22, "wheel": 0.30,
		"cabin": Vector3(1.7, 0.42, 1.58), "cabin_z": -0.20, "bed": 0.0, "nose": 0.75},
]


func _ready() -> void:
	add_to_group("shadow_car")
	if variant_seed != 0:
		_rng.seed = variant_seed
	else:
		# mesma armadilha do ShadowPerson: randomize() repete a semente quando
		# varios nos nascem no mesmo instante
		_rng.seed = hash(str(get_instance_id(), "_", Time.get_ticks_usec(), "_", randi()))

	ShadowRoads.setup(get_tree(), road_node_name, road_group)
	_cruise = _rng.randf_range(speed_min, speed_max)
	_speed = _cruise * 0.5
	_heading = rotation.y
	_build_car()
	_setup_collision()
	_find_engine()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	call_deferred("_align_to_road")


# ---------------------------------------------------------------- construcao

func _get_material() -> ShaderMaterial:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		# exatamente o mesmo shader das pessoas: o visual tem que bater
		_shared_material.shader = load("res://shaders/npcs/shadow_being.gdshader")
		# mesmo shader das pessoas, so que com a fumaca no talo: a lataria e
		# lisa e grande, entao a forma aparece muito mais facil que num corpo
		_shared_material.set_shader_parameter("billow", smoke_billow)
		_shared_material.set_shader_parameter("body_dissolve", smoke_body_dissolve)
		_shared_material.set_shader_parameter("edge_dissolve", smoke_edge_dissolve)
		_shared_material.set_shader_parameter("smoke_scale", smoke_scale)
		_shared_material.set_shader_parameter("wisp_scale", smoke_wisp_scale)
		_shared_material.set_shader_parameter("bite_scale", 2.4)
		_shared_material.set_shader_parameter("edge_power", 0.9)
	return _shared_material


func _make_part(parent: Node3D, mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = _get_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _build_car() -> void:
	var idx := variant_index
	if idx < 0 or idx >= VARIANTS.size():
		idx = _rng.randi_range(0, VARIANTS.size() - 1)
	_profile = VARIANTS[idx].duplicate()

	# nenhum carro identico ao outro
	var sl := _rng.randf_range(0.94, 1.07)
	var sw := _rng.randf_range(0.95, 1.05)
	var sh := _rng.randf_range(0.92, 1.08)

	var ln := float(_profile["len"]) * sl
	var wd := float(_profile["wid"]) * sw
	var ht := float(_profile["hei"]) * sh
	var ground := float(_profile["ground"])
	_wheel_radius = float(_profile["wheel"])

	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)

	# carroceria
	var body_y := ground + ht * 0.5
	_make_part(_body_root, _box(Vector3(wd, ht, ln)), Vector3(0, body_y, 0))

	# capo mais baixo na frente (+Z e a frente)
	var nose := float(_profile["nose"])
	if nose > 0.01:
		var nl := ln * 0.26
		var n := _make_part(_body_root, _box(Vector3(wd * 0.94, ht * 0.72, nl)),
			Vector3(0, body_y - ht * 0.16 * nose, ln * 0.5 - nl * 0.45))
		n.scale = Vector3(1.0, 1.0 - nose * 0.15, 1.0)

	# cabine / teto
	var cab: Vector3 = _profile["cabin"]
	if cab.x > 0.01:
		_make_part(_body_root, _box(Vector3(cab.z * sw, cab.y * sh, cab.x * sl)),
			Vector3(0, ground + ht + cab.y * sh * 0.5, float(_profile["cabin_z"]) * sl))

	# cacamba aberta da pickup / bau do caminhao
	var bed := float(_profile["bed"])
	if bed > 0.01:
		var bz := -ln * 0.5 + bed * sl * 0.5
		var bh: float = ht * (1.4 if String(_profile["name"]) == "caminhao" else 0.55)
		_make_part(_body_root, _box(Vector3(wd * 0.98, bh, bed * sl)),
			Vector3(0, ground + ht * 0.5 + bh * 0.4, bz))

	# rodas: pivo gira em X (eixo lateral), o cilindro deitado fica dentro
	var axle_z := ln * 0.34
	var axle_x := wd * 0.5 - _wheel_radius * 0.35
	_wheelbase = axle_z * 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_wheel(Vector3(sx * axle_x, _wheel_radius, sz * axle_z))

	# caminhao e onibus ganham um eixo traseiro extra
	if bed > 2.0 or String(_profile["name"]) == "onibus":
		for sx in [-1.0, 1.0]:
			_add_wheel(Vector3(sx * axle_x, _wheel_radius, -axle_z + _wheel_radius * 2.2))

	set_meta("variant", _profile["name"])
	set_meta("size", Vector3(wd, ground + ht, ln))


func _add_wheel(at: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	_body_root.add_child(pivot)
	var cyl := CylinderMesh.new()
	cyl.top_radius = _wheel_radius
	cyl.bottom_radius = _wheel_radius
	cyl.height = _wheel_radius * 0.65
	cyl.radial_segments = 10
	cyl.rings = 1
	var mi := _make_part(pivot, cyl, Vector3.ZERO)
	mi.rotation.z = PI * 0.5  # deita o cilindro no eixo lateral
	_wheels.append(pivot)
	if at.z > 0.0:
		_front_wheels.append(pivot)   # so estas esterçam


func _setup_collision() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			return  # a cena ja traz um collider proprio
	var sz := Vector3(2.0, 1.5, 4.5)
	if has_meta("size"):
		sz = get_meta("size")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(sz.x, maxf(sz.y, 0.8), sz.z)
	shape.shape = box
	shape.position = Vector3(0, box.size.y * 0.5, 0)
	add_child(shape)


# -------------------------------------------------------------------- ruas

func _forward() -> Vector3:
	return Vector3(sin(_heading), 0.0, cos(_heading))


## Existe rua embaixo deste ponto? (mesma sonda que as pessoas usam)
func _is_road_at(pos: Vector3) -> bool:
	return ShadowRoads.is_road(pos)


## Sonda o asfalto a frente e decide pra onde apontar. Sem rua na frente,
## procura uma saida pros lados; sem saida nenhuma, da meia volta.
func _choose_heading(delta: float) -> void:
	_probe_timer -= delta
	if _probe_timer > 0.0:
		return
	_probe_timer = 0.12

	var look := clampf(3.0 + _speed * 0.9, 3.0, 10.0)
	var fwd := _forward()
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	var origin := global_position

	if _is_road_at(origin + fwd * look):
		_blocked = false
		# centraliza na pista: se so tem asfalto de um lado, corrige pro outro
		var l := _is_road_at(origin + fwd * look * 0.6 - right * lane_half_width)
		var r := _is_road_at(origin + fwd * look * 0.6 + right * lane_half_width)
		if l != r:
			# so ha asfalto de um lado: esta na beirada, volta pro meio
			_heading += -0.22 if l else 0.22
		return

	# cruzamento ou fim de rua: escolhe uma curva valida
	var options: Array[float] = []
	for ang in [PI * 0.5, -PI * 0.5, PI * 0.25, -PI * 0.25]:
		var dir := Vector3(sin(_heading + ang), 0.0, cos(_heading + ang))
		if _is_road_at(origin + dir * look * 0.8):
			options.append(ang)
	if options.is_empty():
		_heading += PI  # beco sem saida: retorna
		_blocked = false
		return
	_heading += options[_rng.randi_range(0, options.size() - 1)]
	_blocked = false


## Pedestre atravessando a pista: para e espera ele sair da frente.
func _pedestrian_ahead() -> bool:
	var fwd := _forward()
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	var half := 1.2
	if has_meta("size"):
		half = (get_meta("size") as Vector3).x * 0.5
	half += pedestrian_margin
	var stop_d := clampf(3.0 + _speed * 1.1, 3.5, 12.0)
	for n in get_tree().get_nodes_in_group("shadow_person"):
		var p := n as Node3D
		if p == null or not p.is_inside_tree() or not p.visible:
			continue
		var to := p.global_position - global_position
		if absf(to.y) > 3.0:
			continue   # pedestre em outro nivel, nao esta na minha frente
		to.y = 0.0
		var ahead := to.dot(fwd)
		if ahead < -1.0 or ahead > stop_d:
			continue
		if absf(to.dot(right)) < half:
			return true
	return false


## Nao entra em cima de outro carro: se tem um logo a frente, freia.
func _car_ahead() -> bool:
	var fwd := _forward()
	for n in get_tree().get_nodes_in_group("shadow_car"):
		var other := n as Node3D
		if other == null or other == self:
			continue
		var to := other.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 8.0 or d < 0.01:
			continue
		if fwd.dot(to / d) > 0.80:
			return true
	return false


# ------------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	if despawn_enabled:
		_check_distance(delta)
		if not _visible_now:
			return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_choose_heading(delta)

	var err := angle_difference(rotation.y, _heading)
	var max_steer := deg_to_rad(max_steer_deg)
	var blocked := _car_ahead() or _pedestrian_ahead()

	# manobra de meia-volta: quando o rumo pedido esta quase pra tras, um carro
	# de verdade nao pivota — ele entra na curva, para e volta de re esterçado
	# pro outro lado. Sem isto ele girava no lugar, que era o que estava feio.
	if _reverse > 0.0:
		_reverse -= delta
	elif not blocked and absf(err) > 2.0 and _speed < 0.9:
		_reverse = 1.3

	var reversing := _reverse > 0.0
	_steer = clampf(err, -max_steer, max_steer)
	if reversing:
		_steer = -_steer   # de re, o volante vai pro lado contrario

	# alvo de velocidade: freia pra curva, mas nunca para pra girar
	var target := 0.0
	if blocked:
		target = 0.0
	elif reversing:
		target = -reverse_speed
	else:
		var t := _cruise * (1.0 - clampf(absf(_steer) / max_steer, 0.0, 1.0) * turn_slowdown)
		target = maxf(t, min_turn_speed)
	_speed = move_toward(_speed, target, accel * delta)

	# guinada do modelo de bicicleta: so gira o que anda. Parado, tan(volante)
	# multiplica zero e o carro fica reto — igual carro de verdade.
	var yaw_rate := (_speed / maxf(_wheelbase, 0.5)) * tan(_steer)
	rotation.y += yaw_rate * delta

	var dir := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed
	move_and_slide()

	# travou em algo (poste, muro): da re e tenta outro rumo
	if absf(_speed) > 0.5 and velocity.length() < 0.3:
		_stuck_timer += delta
		if _stuck_timer > 1.0:
			_reverse = 1.2
			_heading += PI * (0.5 if _rng.randf() < 0.5 else -0.5)
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

	_spin_wheels(delta)
	_update_engine(delta)


func _spin_wheels(delta: float) -> void:
	var spin := _speed / maxf(_wheel_radius, 0.05) * delta
	for w in _wheels:
		w.rotation.x += spin
	# so as rodas da frente viram; as de tras seguem fixas no eixo
	for w in _front_wheels:
		w.rotation.y = lerp(w.rotation.y, _steer, clampf(delta * 6.0, 0.0, 1.0))
	# leve inclinacao do corpo na curva
	if _body_root != null:
		_body_root.rotation.z = lerp(_body_root.rotation.z, -_steer * 0.12,
			clampf(delta * 4.0, 0.0, 1.0))


## Longe do player o carro some por inteiro (nao processa, nao aparece).
func _check_distance(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.5
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var far := global_position.distance_to(_player.global_position) > despawn_distance
	if far == _visible_now:
		_visible_now = not far
		visible = _visible_now
		# some de verdade: sem colisao e sem custo de fisica
		set_collision_layer_value(20, _visible_now)
		if _visible_now:
			_speed = 0.0


## Aponta o carro pra direcao em que existe rua, pra ele nao sair de re no muro.
func _align_to_road() -> void:
	if _is_road_at(global_position + _forward() * 6.0):
		return
	var best := _heading
	var found := false
	for i in 16:
		var a := TAU * float(i) / 16.0
		var dir := Vector3(sin(a), 0.0, cos(a))
		if _is_road_at(global_position + dir * 6.0):
			best = a
			found = true
			break
	if found:
		_heading = best
		rotation.y = best


## Chamado pelo ShadowCrowd quando o carro e reaproveitado noutro ponto da
## cidade: zera a inercia e o rumo, senao ele sairia do nada em alta e curvando.
func relocate(pos: Vector3, heading := NAN) -> void:
	global_position = pos
	if not is_nan(heading):
		_heading = heading
		rotation.y = heading
	else:
		_heading = rotation.y
	_speed = 0.0
	velocity = Vector3.ZERO
	ShadowRoads.setup(get_tree(), road_node_name, road_group)
	_cruise = _rng.randf_range(speed_min, speed_max)
	_stuck_timer = 0.0
	_probe_timer = 0.0
	_visible_now = true


# ------------------------------------------------------------ som do motor

## Acha o no de audio do motor colocado na cena (nome com "motor"/"engine"/
## "som", ou o primeiro player de audio filho).
func _find_engine() -> void:
	var fallback: Node = null
	for c in get_children():
		if not (c is AudioStreamPlayer3D or c is AudioStreamPlayer or c is AudioStreamPlayer2D):
			continue
		if fallback == null:
			fallback = c
		var n := String(c.name).to_lower()
		if n.contains("motor") or n.contains("engine") or n.contains("som"):
			_engine = c
			break
	if _engine == null:
		_engine = fallback
	if _engine == null:
		return
	_engine_target_db = _engine.volume_db
	_engine_db = -60.0
	_engine.volume_db = _engine_db
	# motor tem que ser continuo: sem loop o mp3 toca uma vez e cala
	var st: Resource = _engine.stream
	if st != null and "loop" in st:
		st.loop = true


## Sobe o motor num fade quando o carro anda e silencia quando ele para.
func _update_engine(delta: float) -> void:
	if _engine == null:
		return
	var moving := absf(_speed) > 0.3
	if moving:
		if not _engine.playing:
			_engine.volume_db = _engine_db
			_engine.play()
		var step := (_engine_target_db + 60.0) / maxf(engine_fade_in, 0.01)
		_engine_db = move_toward(_engine_db, _engine_target_db, step * delta)
		var ratio := clampf(absf(_speed) / maxf(_cruise, 0.1), 0.0, 1.0)
		_engine.pitch_scale = lerpf(engine_pitch_idle, engine_pitch_max, ratio)
	else:
		var step := (_engine_target_db + 60.0) / maxf(engine_fade_out, 0.01)
		_engine_db = move_toward(_engine_db, -60.0, step * delta)
		if _engine_db <= -59.0 and _engine.playing:
			_engine.stop()
	_engine.volume_db = _engine_db


func _exit_tree() -> void:
	if _engine != null and _engine.playing:
		_engine.stop()


## Silencia o motor na hora. Usado pelo ShadowCrowd quando o carro e recolhido
## pra garagem: sem isto o som continuaria tocando com o carro invisivel.
func stop_engine() -> void:
	if _engine == null:
		return
	_engine.stop()
	_engine_db = -60.0
	_engine.volume_db = _engine_db
