extends Area3D

## Ataque 3 do Shadow Seraph: a bola de magia.
##
## Duas vidas no mesmo no. Primeiro ela se FORMA na frente do peito dele
## (filha da ancora das maos, crescendo do nada enquanto ele abre os bracos);
## depois `lancar()` a solta no mundo e ela viaja em linha reta ate o ponto
## onde o jogador estava no instante do arremesso. Nao persegue: e o ataque
## rapido e barato dele, e o jogador tem de poder sair da frente.
##
## Nao da pra destruir a tiro (collision_layer = 0): quem faz esse papel e o
## foguete do ataque 2.

const FX := preload("res://scripts/effects/seraph_fx.gd")

## Dano no jogador (direto ou dentro do raio do estouro).
var damage: int = 15
## Velocidade de voo, em m/s.
var speed: float = 17.0
## Raio do nucleo visivel.
var radius: float = 0.42
## Quem for pego dentro deste raio do estouro leva o dano.
var blast_radius: float = 2.6
var cor: Color = Color(0.55, 0.45, 1.0)
var cor_fogo: Color = Color(1.0, 0.45, 0.1)
## Dono do ataque: nunca se acerta a si mesmo.
var dono: Node3D = null

var _alvo: Vector3 = Vector3.ZERO
var _voando: bool = false
var _vida: float = 0.0
var _tempo: float = 0.0
var _estourou: bool = false

var _nucleo: MeshInstance3D
var _casca: MeshInstance3D
var _luz: OmniLight3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # so o corpo do jogador
	monitoring = true

	var col := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = radius * 1.3
	col.shape = esfera
	add_child(col)

	_monta_visual()
	body_entered.connect(_no_corpo)

	# Nasce do nada: o crescimento acompanha os bracos se abrindo.
	scale = Vector3.ONE * 0.05
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 1.08, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)


func _monta_visual() -> void:

	_nucleo = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = radius
	esfera.height = radius * 2.0
	esfera.radial_segments = 20
	esfera.rings = 10
	_nucleo.mesh = esfera
	var mat := FX.emissivo(Color(1, 1, 1), 7.0, false)
	mat.albedo_texture = FX.ruido_plasma(0.08)
	mat.uv1_scale = Vector3(2.5, 2.5, 1.0)
	mat.emission = cor
	_nucleo.material_override = mat
	_nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_nucleo)

	# casca aditiva maior, girando ao contrario do nucleo
	_casca = MeshInstance3D.new()
	var esfera2 := SphereMesh.new()
	esfera2.radius = radius * 1.45
	esfera2.height = radius * 2.9
	esfera2.radial_segments = 16
	esfera2.rings = 8
	_casca.mesh = esfera2
	var mat2 := FX.emissivo(Color(cor.r, cor.g, cor.b, 0.35), 3.0)
	mat2.albedo_texture = FX.ruido_plasma(0.05)
	mat2.uv1_scale = Vector3(3.0, 3.0, 1.0)
	mat2.cull_mode = BaseMaterial3D.CULL_DISABLED
	_casca.material_override = mat2
	_casca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_casca)

	_luz = OmniLight3D.new()
	_luz.light_color = cor
	_luz.light_energy = 4.5
	_luz.omni_range = 7.0
	_luz.shadow_enabled = false
	add_child(_luz)

	add_child(_particulas())


## Magia roxa com pitadas de fogo puxadas pra tras, como o resto dos poderes
## dele: a silhueta e de magia, o rastro e de brasa.
func _particulas() -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = radius * 0.9
	proc.direction = Vector3(0, 0, 1)
	proc.spread = 35.0
	proc.initial_velocity_min = 0.4
	proc.initial_velocity_max = 1.6
	proc.gravity = Vector3(0, 0.8, 0)
	proc.orbit_velocity_min = 0.25
	proc.orbit_velocity_max = 0.7
	proc.damping_min = 0.5
	proc.damping_max = 1.5
	proc.scale_min = 0.05
	proc.scale_max = 0.16
	proc.scale_curve = FX.curva_pico(0.2)
	proc.color_ramp = FX.rampa(
		[Color(1, 1, 1, 1), cor, cor_fogo, Color(cor_fogo.r * 0.3, 0.06, 0.02, 0.0)],
		[0.0, 0.3, 0.7, 1.0])

	var p := GPUParticles3D.new()
	p.amount = 55
	p.lifetime = 0.7
	p.process_material = proc
	p.draw_pass_1 = FX.quad_particula(true)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3.ONE * -6.0, Vector3.ONE * 12.0)
	p.emitting = true
	return p


## Solta a magia no mundo, mirada no ponto passado. A partir daqui ela deixa de
## ser filha do Seraph: se ele morrer no meio do voo, o golpe ainda chega.
func lancar(destino: Vector3) -> void:
	if _voando:
		return
	var cena := FX.mundo(self)
	if cena != null and get_parent() != cena:
		var mundo := global_transform
		get_parent().remove_child(self)
		cena.add_child(self)
		global_transform = mundo
	_alvo = destino
	_voando = true
	_vida = 0.0


func _physics_process(delta: float) -> void:
	_tempo += delta
	# nucleo e casca girando em sentidos opostos: de perto nao da pra ler a esfera
	if is_instance_valid(_nucleo):
		_nucleo.rotate_y(delta * 1.8)
		_nucleo.rotate_x(delta * 0.9)
	if is_instance_valid(_casca):
		_casca.rotate_y(-delta * 2.6)
	if is_instance_valid(_luz):
		_luz.light_energy = 4.5 + sin(_tempo * 11.0) * 1.2

	if not _voando or _estourou:
		return

	_vida += delta
	var para := _alvo - global_position
	var d := para.length()
	if d <= speed * delta or d < 0.35 or _vida > 5.0:
		global_position = _alvo
		_estourar()
		return
	global_position += para / d * speed * delta


func _no_corpo(corpo: Node3D) -> void:
	if _estourou or corpo == dono:
		return
	if corpo.is_in_group("player") or corpo.has_method("force_battle_from_touch"):
		_estourar(corpo)


func _estourar(acertado: Node3D = null) -> void:
	if _estourou:
		return
	_estourou = true
	var pos := global_position
	FX.explosao(self, pos, cor, blast_radius * 0.9)

	var vitima := acertado
	if vitima == null:
		# Raio de estouro: errar por pouco ainda queima.
		var p: Node = null
		if is_inside_tree():
			p = get_tree().get_first_node_in_group("player")
		if p is Node3D and pos.distance_to((p as Node3D).global_position + Vector3.UP) <= blast_radius:
			vitima = p as Node3D
	if vitima != null and vitima.has_method("take_damage"):
		vitima.take_damage(damage)
		GlobalUtils.shake_camera(0.2, 0.22)

	queue_free()
