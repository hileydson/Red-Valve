extends Area3D

## Ataque 2 do Shadow Seraph: o foguete da bazuca.
##
## Persegue o jogador pra onde ele for e NAO vence por tempo: correr nao
## resolve. A saida e atirar nele — por isso este no fica numa camada que o
## raycast da arma do jogador ve (collision_layer 4, a mesma dos corpos de
## inimigo) e responde a `take_damage`. Abatido assim, estoura no ar sem tirar
## vida nenhuma; so o impacto no jogador e que custa os 40.
##
## A curva de perseguicao e limitada (`turn_rate`): ele erra a primeira passada
## de quem se joga pro lado na hora certa e volta em seguida. Sem esse limite
## o foguete colava no jogador e nao havia o que fazer.

const FX := preload("res://scripts/effects/seraph_fx.gd")

var damage: int = 40
## Velocidade inicial e final: sai lento da bazuca e vai ganhando corpo.
var speed: float = 9.0
var max_speed: float = 18.0
var aceleracao: float = 5.0
## Quanto ele consegue virar por segundo (rad/s). O limite e o que torna o
## ataque esquivavel por um instante.
var turn_rate: float = 1.8
var alvo: Node3D = null
var dono: Node3D = null
## Rede de seguranca: se por algum motivo o alvo desaparecer, nao fica um
## foguete imortal rodando pela cidade pra sempre.
var vida_maxima: float = 22.0

var _dir: Vector3 = Vector3.FORWARD
var _vida: float = 0.0
var _tempo: float = 0.0
var _estourou: bool = false
var _corpo: Node3D
var _luz: OmniLight3D
var _som: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 4   # visivel pro tiro do jogador
	collision_mask = 1    # colide com o corpo do jogador

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.7
	# a capsula nasce em pe; o foguete voa apontado pro -Z
	col.rotation.x = PI * 0.5
	col.shape = cap
	add_child(col)

	_monta_corpo()
	_monta_rastro()
	_monta_som()
	body_entered.connect(_no_corpo)

	if is_instance_valid(alvo):
		_dir = (alvo.global_position + Vector3.UP - global_position).normalized()
	else:
		_dir = -global_transform.basis.z


## Ogiva de sombra com anel de brasa: a mesma leitura do corpo do Seraph (massa
## escura) com o fogo so nas quinas, pra ler contra o ceu escuro da arena.
func _monta_corpo() -> void:
	_corpo = Node3D.new()
	add_child(_corpo)

	var casco := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.5
	cap.radial_segments = 12
	cap.rings = 4
	casco.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.045, 0.06)
	mat.roughness = 0.85
	mat.metallic = 0.4
	casco.material_override = mat
	casco.rotation.x = PI * 0.5
	casco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.add_child(casco)

	# ponta incandescente
	var ponta := MeshInstance3D.new()
	var bico := SphereMesh.new()
	bico.radius = 0.3
	bico.height = 0.6
	ponta.mesh = bico
	ponta.material_override = FX.emissivo(Color(1.0, 0.45, 0.12), 6.0)
	ponta.position = Vector3(0, 0, -0.72)
	ponta.scale = Vector3(0.9, 0.9, 1.5)
	ponta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.add_child(ponta)

	# anel de brasa no meio do casco
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.3
	toro.outer_radius = 0.38
	toro.rings = 16
	anel.mesh = toro
	anel.material_override = FX.emissivo(Color(1.0, 0.55, 0.15), 5.0)
	anel.rotation.x = PI * 0.5
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.add_child(anel)

	# quatro aletas
	for i in 4:
		var aleta := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.34, 0.42)
		aleta.mesh = box
		aleta.material_override = mat
		aleta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(i) / 4.0
		aleta.position = Vector3(sin(a) * 0.26, cos(a) * 0.26, 0.62)
		aleta.rotation.z = -a
		_corpo.add_child(aleta)

	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.5, 0.15)
	_luz.light_energy = 7.0
	_luz.omni_range = 12.0
	_luz.shadow_enabled = false
	add_child(_luz)


func _monta_rastro() -> void:
	# jato: fogo saindo do bocal, empurrado pra tras
	var jato_proc := ParticleProcessMaterial.new()
	jato_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	jato_proc.emission_sphere_radius = 0.18
	jato_proc.direction = Vector3(0, 0, 1)
	jato_proc.spread = 14.0
	jato_proc.initial_velocity_min = 4.0
	jato_proc.initial_velocity_max = 9.0
	jato_proc.gravity = Vector3(0, 1.2, 0)
	jato_proc.damping_min = 4.0
	jato_proc.damping_max = 8.0
	jato_proc.scale_min = 0.18
	jato_proc.scale_max = 0.5
	jato_proc.scale_curve = FX.curva_pico(0.15)
	jato_proc.color_ramp = FX.rampa(
		[Color(1, 1, 0.85, 1), Color(1, 0.6, 0.15, 1), Color(0.7, 0.12, 0.02, 0.5), Color(0.1, 0.08, 0.08, 0.0)],
		[0.0, 0.25, 0.6, 1.0])

	var jato := GPUParticles3D.new()
	jato.amount = 110
	jato.lifetime = 0.55
	jato.process_material = jato_proc
	jato.draw_pass_1 = FX.quad_particula()
	jato.local_coords = false
	jato.position = Vector3(0, 0, 0.8)
	jato.visibility_aabb = AABB(Vector3.ONE * -20.0, Vector3.ONE * 40.0)
	jato.emitting = true
	add_child(jato)

	# fumaca grossa marcando o caminho que ele fez
	var fum_proc := ParticleProcessMaterial.new()
	fum_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fum_proc.emission_sphere_radius = 0.3
	fum_proc.direction = Vector3(0, 0.4, 1)
	fum_proc.spread = 30.0
	fum_proc.initial_velocity_min = 0.4
	fum_proc.initial_velocity_max = 1.6
	fum_proc.gravity = Vector3(0, 0.5, 0)
	fum_proc.damping_min = 1.0
	fum_proc.damping_max = 2.0
	fum_proc.scale_min = 0.35
	fum_proc.scale_max = 1.0
	fum_proc.scale_curve = FX.curva_pico(0.6)
	fum_proc.color_ramp = FX.rampa(
		[Color(0.22, 0.2, 0.24, 0.5), Color(0.12, 0.11, 0.14, 0.28), Color(0.05, 0.05, 0.06, 0.0)],
		[0.0, 0.45, 1.0])

	var fumaca := GPUParticles3D.new()
	fumaca.amount = 60
	fumaca.lifetime = 2.4
	fumaca.process_material = fum_proc
	fumaca.draw_pass_1 = FX.quad_particula()
	fumaca.local_coords = false
	fumaca.position = Vector3(0, 0, 0.9)
	fumaca.visibility_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	fumaca.emitting = true
	add_child(fumaca)

	# faiscas em espiral ao redor do casco
	var fai_proc := ParticleProcessMaterial.new()
	fai_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	fai_proc.emission_sphere_radius = 0.45
	fai_proc.direction = Vector3(0, 0, 1)
	fai_proc.spread = 45.0
	fai_proc.initial_velocity_min = 0.5
	fai_proc.initial_velocity_max = 2.0
	fai_proc.orbit_velocity_min = 0.8
	fai_proc.orbit_velocity_max = 1.6
	fai_proc.gravity = Vector3.ZERO
	fai_proc.scale_min = 0.04
	fai_proc.scale_max = 0.12
	fai_proc.scale_curve = FX.curva_pico(0.2)
	fai_proc.color_ramp = FX.rampa(
		[Color(1, 1, 1, 1), Color(1, 0.65, 0.2, 1), Color(0.6, 0.15, 0.3, 0.0)],
		[0.0, 0.4, 1.0])

	var faiscas := GPUParticles3D.new()
	faiscas.amount = 50
	faiscas.lifetime = 0.8
	faiscas.process_material = fai_proc
	faiscas.draw_pass_1 = FX.quad_particula(true)
	faiscas.local_coords = false
	faiscas.visibility_aabb = AABB(Vector3.ONE * -20.0, Vector3.ONE * 40.0)
	faiscas.emitting = true
	add_child(faiscas)


func _monta_som() -> void:
	var stream := FX.som_em_laco(FX.SOM_FOGO)
	if stream == null:
		return
	_som = AudioStreamPlayer3D.new()
	_som.stream = stream
	_som.volume_db = -2.0
	_som.pitch_scale = 1.4
	_som.unit_size = 16.0
	_som.max_distance = 70.0
	add_child(_som)
	_som.play()


func _physics_process(delta: float) -> void:
	if _estourou:
		return
	_tempo += delta
	_vida += delta

	speed = minf(max_speed, speed + aceleracao * delta)

	if is_instance_valid(alvo):
		var desejada := (alvo.global_position + Vector3.UP * 0.9 - global_position).normalized()
		# gira em direcao ao alvo, mas so o tanto que `turn_rate` permite
		_dir = _dir.slerp(desejada, clampf(turn_rate * delta, 0.0, 1.0)).normalized()

	global_position += _dir * speed * delta
	# `look_at` estoura quando a direcao e paralela ao UP (foguete subindo reto).
	if absf(_dir.y) < 0.985:
		look_at(global_position + _dir, Vector3.UP)

	# ogiva rolando em torno do proprio eixo
	if is_instance_valid(_corpo):
		_corpo.rotate_z(delta * 4.0)
	if is_instance_valid(_luz):
		_luz.light_energy = 7.0 + sin(_tempo * 18.0) * 1.5

	if _vida > vida_maxima:
		_estourar(false)


func _no_corpo(corpo: Node3D) -> void:
	if _estourou or corpo == dono:
		return
	if corpo.is_in_group("player") or corpo == alvo:
		_estourar(true, corpo)


## O tiro do jogador chega por aqui. Qualquer dano derruba o foguete: ele nao
## tem barra de vida, a graca e acertar o tiro.
func take_damage(_amount) -> void:
	if _estourou:
		return
	_estourar(false)


func _estourar(acerta_jogador: bool, vitima: Node3D = null) -> void:
	if _estourou:
		return
	_estourou = true
	set_physics_process(false)
	if is_instance_valid(_som):
		_som.stop()

	var pos := global_position
	FX.explosao(self, pos, Color(1.0, 0.5, 0.15), 4.0)

	if acerta_jogador:
		var quem := vitima
		if quem == null:
			quem = alvo
		if is_instance_valid(quem) and quem.has_method("take_damage"):
			quem.take_damage(damage)
		GlobalUtils.shake_camera(0.45, 0.5)
		GlobalUtils.vibrate_controller(null, 0.9, 0.9, 0.4)
	else:
		# Abatido no ar: tranco de camera pra dar o premio, sem dano.
		GlobalUtils.shake_camera(0.25, 0.25)

	queue_free()
