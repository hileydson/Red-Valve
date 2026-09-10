extends Area3D

## Magia 1 do Shadow Seraph: o anel que prende e pesa.
##
## Ele estica um braco pra cima e vai girando a mao ate o anel se fechar;
## depois aponta pra frente e o anel sai atras do jogador. Diferente do orbe
## (ataque 3), este PERSEGUE: a graca dele nao e acertar, e a corrida.
##
## Encostando, o anel se encaixa na cintura do jogador e fica 12 s ali, girando
## e soltando faisca, com ele 60% mais lento. Quem aplica a lentidao e o
## proprio jogador (`apply_slow`), porque e la que mora a velocidade de
## caminhada — e tambem la que ela precisa voltar ao normal se a batalha acabar
## antes do tempo do anel.

const FX := preload("res://scripts/effects/seraph_fx.gd")

## Quem o anel persegue.
var alvo: Node3D = null
var dono: Node3D = null
## Quanto tempo o jogador fica lento.
var duracao: float = 12.0
## Multiplicador de velocidade aplicado no jogador (0.4 = 60% mais lento).
var fator: float = 0.4
var speed: float = 8.5
var turn_rate: float = 3.4
var raio: float = 0.85

const COR := Color(0.7, 0.35, 1.0)
const COR_BRASA := Color(1.0, 0.5, 0.15)

enum Fase { FORMANDO, VOANDO, PRESO, FIM }

var _fase: Fase = Fase.FORMANDO
var _dir: Vector3 = Vector3.FORWARD
var _tempo: float = 0.0
var _vida: float = 0.0
var _anel: Node3D
var _luz: OmniLight3D
var _faiscas: GPUParticles3D
var _mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var col := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = raio
	col.shape = esfera
	add_child(col)

	_monta_anel()
	_monta_faiscas()
	body_entered.connect(_no_corpo)

	# fecha do nada: acompanha a mao girando
	scale = Vector3.ONE * 0.05
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE, 1.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _monta_anel() -> void:
	_anel = Node3D.new()
	add_child(_anel)

	var toro := TorusMesh.new()
	toro.inner_radius = raio * 0.78
	toro.outer_radius = raio
	toro.rings = 32
	toro.ring_segments = 10

	var aro := MeshInstance3D.new()
	aro.mesh = toro
	var mat := FX.emissivo(Color(COR.r, COR.g, COR.b, 0.9), 5.0)
	_mats.append(mat)
	aro.material_override = mat
	aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anel.add_child(aro)

	# runas: oito marcas de brasa presas no aro
	var marca := BoxMesh.new()
	marca.size = Vector3(0.06, 0.16, 0.03)
	var mat_brasa := FX.emissivo(COR_BRASA, 6.0)
	_mats.append(mat_brasa)
	for i in 8:
		var r := MeshInstance3D.new()
		r.mesh = marca
		r.material_override = mat_brasa
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(i) / 8.0
		r.position = Vector3(cos(a) * raio * 0.89, 0.0, sin(a) * raio * 0.89)
		r.rotation.y = -a
		_anel.add_child(r)

	# aro interno girando ao contrario, pra leitura de "engrenagem de magia"
	var toro2 := TorusMesh.new()
	toro2.inner_radius = raio * 0.52
	toro2.outer_radius = raio * 0.6
	toro2.rings = 20
	toro2.ring_segments = 8
	var interno := MeshInstance3D.new()
	interno.name = "AroInterno"
	interno.mesh = toro2
	var mat2 := FX.emissivo(Color(COR.r * 0.8, COR.g * 0.5, 1.0, 0.7), 4.0)
	_mats.append(mat2)
	interno.material_override = mat2
	interno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anel.add_child(interno)

	_luz = OmniLight3D.new()
	_luz.light_color = COR
	_luz.light_energy = 3.0
	_luz.omni_range = 6.0
	_luz.shadow_enabled = false
	add_child(_luz)


func _monta_faiscas() -> void:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc.emission_ring_radius = raio * 0.92
	proc.emission_ring_inner_radius = raio * 0.8
	proc.emission_ring_height = 0.05
	proc.emission_ring_axis = Vector3(0, 1, 0)
	proc.direction = Vector3(0, 0, 0)
	proc.spread = 180.0
	proc.initial_velocity_min = 0.2
	proc.initial_velocity_max = 1.0
	proc.gravity = Vector3.ZERO
	proc.orbit_velocity_min = 0.5
	proc.orbit_velocity_max = 1.2
	proc.damping_min = 0.5
	proc.damping_max = 1.5
	proc.scale_min = 0.03
	proc.scale_max = 0.1
	proc.scale_curve = FX.curva_pico(0.2)
	proc.color_ramp = FX.rampa(
		[Color(1, 1, 1, 1), COR, COR_BRASA, Color(0.2, 0.05, 0.3, 0.0)],
		[0.0, 0.3, 0.72, 1.0])

	_faiscas = GPUParticles3D.new()
	_faiscas.amount = 60
	_faiscas.lifetime = 0.9
	_faiscas.process_material = proc
	_faiscas.draw_pass_1 = FX.quad_particula(true)
	_faiscas.visibility_aabb = AABB(Vector3.ONE * -6.0, Vector3.ONE * 12.0)
	add_child(_faiscas)


## Solta o anel atras do alvo.
func lancar(quem: Node3D) -> void:
	if _fase != Fase.FORMANDO:
		return
	alvo = quem
	var cena := FX.mundo(self)
	if cena != null and get_parent() != cena:
		var mundo := global_transform
		get_parent().remove_child(self)
		cena.add_child(self)
		global_transform = mundo
	if is_instance_valid(alvo):
		_dir = (alvo.global_position + Vector3.UP - global_position).normalized()
	else:
		_dir = -global_transform.basis.z
	_fase = Fase.VOANDO
	_vida = 0.0
	FX.som_no_mundo(self, global_position, FX.SOM_FOGO, -10.0, 1.6)


func _physics_process(delta: float) -> void:
	_tempo += delta
	if is_instance_valid(_anel):
		_anel.rotate_y(delta * 2.4)
		var interno := _anel.get_node_or_null("AroInterno")
		if interno is Node3D:
			(interno as Node3D).rotate_y(-delta * 4.2)
	if is_instance_valid(_luz):
		_luz.light_energy = 3.0 + sin(_tempo * 6.0) * 0.8

	match _fase:
		Fase.VOANDO:
			_vida += delta
			if is_instance_valid(alvo):
				var desejada := (alvo.global_position + Vector3.UP * 0.9 - global_position).normalized()
				_dir = _dir.slerp(desejada, clampf(turn_rate * delta, 0.0, 1.0)).normalized()
			elif _vida > 1.0:
				_encerra()
				return
			global_position += _dir * speed * delta
			# o aro nasce deitado (eixo Y). Girar 90 graus depois do look_at poe
			# o eixo dele na direcao do voo: chega no jogador como um arco em pe.
			if absf(_dir.y) < 0.985:
				look_at(global_position + _dir, Vector3.UP)
				rotate_object_local(Vector3.RIGHT, PI * 0.5)
			if _vida > 14.0:
				_encerra()
		Fase.PRESO:
			_vida += delta
			if not is_instance_valid(alvo):
				_encerra()
				return
			if _vida >= duracao:
				_encerra()
		_:
			pass


func _no_corpo(corpo: Node3D) -> void:
	if _fase != Fase.VOANDO or corpo == dono:
		return
	if corpo != alvo and not corpo.is_in_group("player"):
		return
	_prende(corpo)


## Encaixa o anel na cintura do jogador e manda a lentidao.
func _prende(quem: Node3D) -> void:
	_fase = Fase.PRESO
	_vida = 0.0
	alvo = quem

	if get_parent() != null:
		get_parent().remove_child(self)
	quem.add_child(self)
	position = Vector3(0, 0.95, 0)
	rotation = Vector3.ZERO
	scale = Vector3.ONE * 1.25

	if quem.has_method("apply_slow"):
		quem.apply_slow(fator, duracao)

	FX.explosao(self, global_position, COR, 1.6, false)
	GlobalUtils.shake_camera(0.3, 0.3)
	GlobalUtils.vibrate_controller(null, 0.6, 0.6, 0.4)


func _encerra() -> void:
	if _fase == Fase.FIM:
		return
	_fase = Fase.FIM
	set_physics_process(false)
	if is_instance_valid(_faiscas):
		_faiscas.emitting = false
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", scale * 1.5, 0.4).set_trans(Tween.TRANS_SINE)
	for m in _mats:
		t.tween_property(m, "albedo_color:a", 0.0, 0.4)
		t.tween_property(m, "emission_energy_multiplier", 0.0, 0.4)
	if is_instance_valid(_luz):
		t.tween_property(_luz, "light_energy", 0.0, 0.4)
	t.chain().tween_callback(queue_free)
