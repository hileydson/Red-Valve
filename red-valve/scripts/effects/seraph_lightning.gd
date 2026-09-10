extends Node3D

## Ataque 1 do Shadow Seraph: o raio do ceu (so na arena).
##
## Tres momentos, nessa ordem, todos tocados por quem cria:
##   1. `invocar()`  — ele levanta os bracos e um raio azul desce do ceu ate um
##                     ponto acima da cabeca dele, estalando no lugar;
##   2. `pegar()`    — ele pula, a parte do ceu apaga e o que sobra fica preso
##                     entre as maos dele (segue a ancora);
##   3. `arremessar()` — o raio desaba sobre o ponto onde o jogador ESTAVA no
##                     instante do arremesso. Nao persegue: dar pra desviar e
##                     o que faz valer a pena ler a animacao dos bracos.
##
## O raio e desenhado com uma fileira de caixas finas reposicionadas a cada
## frame (nao ha malha de raio pronta no projeto). Dezoito segmentos + dois
## galhos dao o estalo sem custar nada: e a mesma ideia do rig de codigo das
## sombras, onde primitivas baratas formam a silhueta.

const FX := preload("res://scripts/effects/seraph_fx.gd")

## Altura de onde o raio desce.
const ALTURA_CEU := 48.0
const SEGMENTOS := 18
const GALHOS := 3

var cor: Color = Color(0.45, 0.72, 1.0)
var dano: int = 30
## Raio do estouro no chao.
var blast_radius: float = 3.4
## No que o raio acompanha enquanto esta na mao dele.
var ancora: Node3D = null
var dono: Node3D = null

enum Fase { CEU, MAO, QUEDA, FIM }

var _fase: Fase = Fase.CEU
var _topo: Vector3 = Vector3.ZERO
var _base: Vector3 = Vector3.ZERO
var _tempo: float = 0.0
var _opacidade: float = 1.0
var _mat: StandardMaterial3D
var _mat_halo: StandardMaterial3D
var _segs: Array[MeshInstance3D] = []
var _galhos: Array[MeshInstance3D] = []
var _luz: OmniLight3D
var _faiscas: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_mat = FX.emissivo(Color(0.8, 0.92, 1.0), 9.0)
	_mat_halo = FX.emissivo(Color(cor.r, cor.g, cor.b, 0.35), 3.0)

	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE

	# nucleo branco fino + halo azul grosso por cima do mesmo traçado
	for i in SEGMENTOS:
		_segs.append(_novo_segmento(caixa, _mat_halo, true))
		_segs.append(_novo_segmento(caixa, _mat, false))
	for i in GALHOS:
		_galhos.append(_novo_segmento(caixa, _mat, false))

	_luz = OmniLight3D.new()
	_luz.light_color = cor
	_luz.light_energy = 6.0
	_luz.omni_range = 16.0
	_luz.shadow_enabled = false
	add_child(_luz)

	_faiscas = _monta_faiscas()
	add_child(_faiscas)


func _novo_segmento(malha: Mesh, mat: Material, halo: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("halo", halo)
	mi.visible = false
	add_child(mi)
	return mi


func _monta_faiscas() -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.35
	proc.direction = Vector3(0, -1, 0)
	proc.spread = 90.0
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 5.0
	proc.gravity = Vector3(0, -3.0, 0)
	proc.damping_min = 2.0
	proc.damping_max = 5.0
	proc.scale_min = 0.03
	proc.scale_max = 0.11
	proc.scale_curve = FX.curva_pico(0.15)
	proc.color_ramp = FX.rampa(
		[Color(1, 1, 1, 1), cor, Color(0.1, 0.25, 0.7, 0.0)],
		[0.0, 0.35, 1.0])

	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 0.6
	p.process_material = proc
	p.draw_pass_1 = FX.quad_particula(true)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	p.emitting = true
	return p


# ------------------------------------------------------------------- roteiro

## Desce do ceu ate `ponto`. O raio fica estalando ali, parado, enquanto ele
## mantem os bracos pra cima.
func invocar(ponto: Vector3) -> void:
	_base = ponto
	_topo = ponto + Vector3.UP * ALTURA_CEU
	_fase = Fase.CEU
	global_position = ponto
	FX.som_no_mundo(self, ponto, FX.SOM_EXPLOSAO, -8.0, 0.45)


## Ele pegou: o cordao que vinha do ceu apaga e o resto fica na mao.
func pegar() -> void:
	if _fase != Fase.CEU:
		return
	_fase = Fase.MAO
	FX.som_no_mundo(self, global_position, FX.SOM_FOGO, -6.0, 1.9)


## Arremessa no ponto passado. Quem chamar nao precisa esperar: o no se apaga
## sozinho depois do estouro.
func arremessar(destino: Vector3) -> void:
	if _fase == Fase.QUEDA or _fase == Fase.FIM:
		return
	_fase = Fase.QUEDA
	_topo = _ponta_da_mao()
	_base = destino
	# o raio desaba: o topo corre atras da base em 0,12 s, nao ao contrario
	var t := create_tween()
	t.tween_method(_desce_topo, 0.0, 1.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(_impacto)


func _desce_topo(f: float) -> void:
	_topo = _ponta_da_mao().lerp(_base + Vector3.UP * 6.0, f)


func _impacto() -> void:
	FX.explosao(self, _base, cor, blast_radius)
	GlobalUtils.shake_camera(0.5, 0.6)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.5)

	var p: Node = null
	if is_inside_tree():
		p = get_tree().get_first_node_in_group("player")
	if p is Node3D and p != dono and (p as Node3D).has_method("take_damage"):
		var d := (p as Node3D).global_position + Vector3.UP * 0.9
		# distancia medida no plano: o raio e uma coluna, nao uma bola
		if Vector2(d.x - _base.x, d.z - _base.z).length() <= blast_radius:
			(p as Node3D).take_damage(dano)

	_fase = Fase.FIM
	if is_instance_valid(_faiscas):
		_faiscas.emitting = false
	var t := create_tween()
	t.tween_method(func(v: float): _opacidade = v, 1.0, 0.0, 0.22)
	t.tween_callback(queue_free)


func _ponta_da_mao() -> Vector3:
	if is_instance_valid(ancora):
		return ancora.global_position
	return _base


# ------------------------------------------------------------------ desenho

func _process(delta: float) -> void:
	_tempo += delta

	match _fase:
		Fase.CEU:
			if is_instance_valid(ancora):
				_base = ancora.global_position + Vector3.UP * 1.6
			_topo = _base + Vector3.UP * ALTURA_CEU
		Fase.MAO:
			_base = _ponta_da_mao()
			# sobra um toco curto chacoalhando entre as maos
			_topo = _base + Vector3.UP * 0.9
		_:
			pass

	_redesenha()
	_posiciona_extras()


func _redesenha() -> void:
	var de := _topo
	var para := _base
	var total := de.distance_to(para)
	if total < 0.01:
		for mi in _segs:
			mi.visible = false
		for mi in _galhos:
			mi.visible = false
		return

	# jitter lateral cresce no meio do raio e e zero nas duas pontas, senao a
	# ponta descola da mao e do ponto de impacto
	var eixo := (para - de) / total
	var lado := eixo.cross(Vector3.UP)
	if lado.length_squared() < 0.001:
		lado = eixo.cross(Vector3.RIGHT)
	lado = lado.normalized()
	var outro := eixo.cross(lado).normalized()

	var amplitude: float = clampf(total * 0.055, 0.08, 1.1)
	var semente := floorf(_tempo * 22.0)  # o raio "troca de forma" 22 vezes por segundo
	var pontos: Array[Vector3] = []
	for i in SEGMENTOS + 1:
		var f := float(i) / float(SEGMENTOS)
		var p := de.lerp(para, f)
		if i > 0 and i < SEGMENTOS:
			var peso := sin(f * PI)
			var a := _ruido(semente + float(i) * 7.3)
			var b := _ruido(semente + float(i) * 13.1 + 91.0)
			p += lado * (a - 0.5) * amplitude * 2.0 * peso
			p += outro * (b - 0.5) * amplitude * 2.0 * peso
		pontos.append(p)

	var espessura: float = clampf(total * 0.006, 0.018, 0.07) * _opacidade
	for i in SEGMENTOS:
		var halo_mi := _segs[i * 2]
		var nucleo_mi := _segs[i * 2 + 1]
		_coloca(halo_mi, pontos[i], pontos[i + 1], espessura * 3.2)
		_coloca(nucleo_mi, pontos[i], pontos[i + 1], espessura)

	# galhos: saem de pontos sorteados do tronco e morrem no ar
	for gi in GALHOS:
		var idx := int(_ruido(semente + float(gi) * 31.7) * float(SEGMENTOS - 2)) + 1
		var origem := pontos[idx]
		var dirg := (lado * (_ruido(semente + float(gi) * 5.1) - 0.5) \
			+ outro * (_ruido(semente + float(gi) * 17.9) - 0.5) \
			+ eixo * 0.35).normalized()
		_coloca(_galhos[gi], origem, origem + dirg * amplitude * 3.5, espessura * 0.8)


## Encaixa uma caixa unitaria entre dois pontos: vira o segmento do raio.
func _coloca(mi: MeshInstance3D, a: Vector3, b: Vector3, esp: float) -> void:
	var d := b - a
	var comp := d.length()
	if comp < 0.001 or _opacidade <= 0.01:
		mi.visible = false
		return
	var z := d / comp
	var ref := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x).normalized()
	mi.visible = true
	mi.global_transform = Transform3D(Basis(x * esp, y * esp, z * comp), (a + b) * 0.5)


func _posiciona_extras() -> void:
	if is_instance_valid(_luz):
		_luz.global_position = _base
		var base_energia := 6.0 if _fase == Fase.CEU else 9.0
		_luz.light_energy = (base_energia + sin(_tempo * 31.0) * 2.5) * _opacidade
	if is_instance_valid(_faiscas):
		_faiscas.global_position = _base


## Ruido barato e estavel: a mesma entrada devolve sempre o mesmo valor, entao o
## raio fica parado dentro de cada "quadro" de 1/22 s em vez de tremer sozinho.
func _ruido(x: float) -> float:
	var v := sin(x * 12.9898) * 43758.5453
	return v - floorf(v)
