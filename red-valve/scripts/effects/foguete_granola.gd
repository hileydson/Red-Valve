extends Node3D

## O MINI-FOGUETE DA GRANOLA.
##
## Sai da boca do cano na direcao da mira e voa quase reto (um pouco de queda
## no fim), com fogo na cauda e rastro de fumaca. Explode no PRIMEIRO coisa que
## tocar — inimigo, parede, chao — e alem do dano no alvo atingido espalha dano
## em volta, caindo com a distancia ate' a borda do raio.
##
## O caminho e' varrido por raio a cada quadro (de onde estava ate' onde vai):
## a 34 m/s ele anda meio metro por quadro, e uma area de colisao atravessaria
## um inimigo magro sem nunca encostar.
##
## Com um `alvo` (o inimigo marcado pela mira da Granola) ele o PERSEGUE:
## a cada quadro o rumo gira na direcao do meio do corpo dele, no maximo
## `curva` radianos por segundo — persegue, mas faz curva de foguete, e um
## inimigo que desvia de lado no ultimo instante ainda escapa. Sem gravidade
## enquanto persegue; alvo morto ou sumido, ele segue reto e volta a cair.
##
## A explosao e' a mesma do Shadow Seraph (`seraph_fx.gd`): clarao, onda,
## faiscas, fumaca e o som de explosao do projeto.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")
const MODELO := preload("res://assets/3d_model/player/the_negotiator_V4/cartridge/the_negotiator_V4_bullet.glb")

## 48 cm de foguete (o .glb tem 1,91 unidade, com a ponta no -X).
const ESCALA := 0.25
const COR := Color(1.0, 0.55, 0.18)

var dono: Node3D = null
var dano_direto := 140
var dano_area := 80
var raio := 3.6
var velocidade := 34.0
var gravidade := 1.6
var vida_maxima := 5.0
## Camadas que o foguete enxerga: cenario (1 e 2), corpos de inimigo (3) e
## hitboxes (4) — a mesma mascara do tiro da pistola mais o chao e as paredes.
var mascara := 15
## O inimigo perseguido (null: voo reto) e a altura, acima da origem dele, do
## ponto em que o foguete mira.
var alvo: Node3D = null
var altura_no_alvo := 0.9
var curva := 4.5

var _vel := Vector3.ZERO
var _vida := 0.0
var _estourou := false
var _fogo: GPUParticles3D
var _fumaca: GPUParticles3D
var _luz: OmniLight3D


func lancar(direcao: Vector3) -> void:
	_vel = direcao.normalized() * velocidade
	_virar_para(_vel)


func _ready() -> void:
	var corpo := MODELO.instantiate() as Node3D
	# a ponta do modelo e' o -X; o foguete voa pro -Z deste no'
	corpo.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	corpo.scale = Vector3.ONE * ESCALA
	add_child(corpo)
	_luz = OmniLight3D.new()
	_luz.light_color = COR
	_luz.light_energy = 2.4
	_luz.omni_range = 3.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0, 0, 0.3)
	add_child(_luz)
	_fogo = _particulas_de_fogo()
	_fogo.position = Vector3(0, 0, 0.26)
	add_child(_fogo)
	_fumaca = _particulas_de_fumaca()
	_fumaca.position = Vector3(0, 0, 0.3)
	add_child(_fumaca)
	var chiado := AudioStreamPlayer3D.new()
	chiado.stream = FX.som_em_laco(FX.SOM_FOGO)
	chiado.volume_db = -6.0
	chiado.pitch_scale = 1.6
	chiado.unit_size = 8.0
	chiado.autoplay = true
	add_child(chiado)


func _physics_process(delta: float) -> void:
	if _estourou:
		return
	_vida += delta
	if _perseguindo():
		var quero := alvo.global_position + Vector3.UP * altura_no_alvo - global_position
		var rumo := _vel.normalized()
		var angulo := rumo.angle_to(quero.normalized())
		if angulo > 0.0001:
			rumo = rumo.slerp(quero.normalized(), minf(curva * delta / angulo, 1.0))
		_vel = rumo * velocidade
	else:
		_vel.y -= gravidade * delta
	var de := global_position
	var para := de + _vel * delta
	var consulta := PhysicsRayQueryParameters3D.create(de, para, mascara)
	consulta.collide_with_areas = true
	if is_instance_valid(dono) and dono is CollisionObject3D:
		consulta.exclude = [(dono as CollisionObject3D).get_rid()]
	var toque := get_world_3d().direct_space_state.intersect_ray(consulta)
	# inimigo de sombra (sem o amuleto) esta na outra realidade: o foguete passa
	var fora: Array[RID] = consulta.exclude
	while not toque.is_empty() and Realidade.em_outra_realidade(toque.get("collider")) and fora.size() < 8:
		fora.append(toque["rid"])
		consulta.exclude = fora
		toque = get_world_3d().direct_space_state.intersect_ray(consulta)
	if not toque.is_empty():
		global_position = toque["position"]
		_explodir(toque.get("collider"), toque["normal"])
		return
	global_position = para
	_virar_para(_vel)
	if _vida > vida_maxima:
		_explodir(null, Vector3.UP)


func _perseguindo() -> bool:
	if not is_instance_valid(alvo) or not alvo.is_inside_tree():
		return false
	if Realidade.em_outra_realidade(alvo):
		return false
	return not ("dead" in alvo and alvo.dead)


func _virar_para(v: Vector3) -> void:
	if v.length_squared() < 0.0001:
		return
	var cima := Vector3.UP if absf(v.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	look_at(global_position + v, cima)


func _explodir(alvo: Object, normal: Vector3) -> void:
	if _estourou:
		return
	_estourou = true
	var p := global_position
	FX.explosao(self, p + normal * 0.2, COR, raio * 0.85)
	var combate: Node = dono.get_node_or_null("PlayerCombat") if is_instance_valid(dono) else null

	# o alvo tocado: dano cheio, e o corpo dele nao leva o dano de area de novo
	var ja_levou: Array = []
	if alvo != null and alvo is Node and alvo.has_method("take_damage"):
		alvo.take_damage(dano_direto)
		ja_levou.append(alvo)
		if alvo is Area3D and (alvo as Node).get_parent() != null:
			ja_levou.append((alvo as Node).get_parent())
		if combate and combate.has_method("spawn_blood_raycast") and (alvo as Node).is_in_group("enemies"):
			combate.spawn_blood_raycast(p, normal)

	# em volta: so' corpos (as areas de cabeca encaminham o dano pro corpo, e
	# contariam duas vezes)
	for no in get_tree().get_nodes_in_group("enemies"):
		if not (no is Node3D) or no is Area3D or no in ja_levou:
			continue
		if not no.has_method("take_damage") or ("dead" in no and no.dead):
			continue
		if Realidade.em_outra_realidade(no):
			continue
		var d := (no as Node3D).global_position.distance_to(p)
		if d > raio + 1.0:
			continue
		var k := clampf(1.0 - maxf(d - 1.0, 0.0) / raio, 0.0, 1.0)
		if k <= 0.0:
			continue
		no.take_damage(int(round(dano_area * sqrt(k))))
		if combate and combate.has_method("spawn_blood_raycast"):
			combate.spawn_blood_raycast((no as Node3D).global_position + Vector3.UP, Vector3.UP)

	# o tranco: quanto mais perto do jogador, mais forte
	if is_instance_valid(dono):
		var perto := clampf(1.0 - dono.global_position.distance_to(p) / 18.0, 0.15, 1.0)
		GlobalUtils.shake_camera(0.45 * perto, 0.5)
		GlobalUtils.vibrate_controller(Input, perto, perto * 0.7, 0.35)

	# a fumaca da cauda fica no ar mais um pouco; o resto some agora
	for filho in get_children():
		if filho != _fumaca:
			filho.queue_free()
	if is_instance_valid(_fumaca):
		_fumaca.emitting = false
	set_physics_process(false)
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _particulas_de_fogo() -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 0, 1)
	proc.spread = 9.0
	proc.initial_velocity_min = 2.0
	proc.initial_velocity_max = 4.0
	proc.gravity = Vector3.ZERO
	proc.scale_min = 0.10
	proc.scale_max = 0.22
	proc.scale_curve = FX.curva_pico(0.15)
	proc.color_ramp = FX.rampa([Color(1, 0.95, 0.7, 1), COR, Color(0.6, 0.12, 0.04, 0)], [0.0, 0.35, 1.0])
	var p := GPUParticles3D.new()
	p.amount = 32
	p.lifetime = 0.18
	p.process_material = proc
	p.draw_pass_1 = FX.quad_particula()
	p.local_coords = false
	return p


func _particulas_de_fumaca() -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 0, 1)
	proc.spread = 14.0
	proc.initial_velocity_min = 0.3
	proc.initial_velocity_max = 0.9
	proc.gravity = Vector3(0, 0.35, 0)
	proc.damping_min = 0.6
	proc.damping_max = 1.4
	proc.scale_min = 0.25
	proc.scale_max = 0.55
	proc.scale_curve = FX.curva_pico(0.3)
	proc.color_ramp = FX.rampa([Color(0.55, 0.52, 0.5, 0.5), Color(0.3, 0.29, 0.3, 0.28), Color(0.2, 0.2, 0.2, 0.0)], [0.0, 0.4, 1.0])
	var quad := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FX.ponto_suave()
	quad.material = m
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.6
	p.process_material = proc
	p.draw_pass_1 = quad
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	return p
