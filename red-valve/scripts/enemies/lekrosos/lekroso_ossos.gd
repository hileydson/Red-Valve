extends SkeletonModifier3D

## O que roda no esqueleto do lekroso DEPOIS da animacao, todo quadro.
##
## 1. AS PECAS ARRANCADAS. Cada peca removivel da malha pesa so' em
##    ossos-sombra (`pk_<peca>_<osso>`, filhos do osso original com o mesmo
##    repouso — ver `tools/blender/lekrosos/cortar.py`). Arrancar e' encolher
##    TODOS os ossos-sombra da peca pra UM ponto so', escondido (o fundo da
##    cratera, o meio do coto), preso no osso que fica. A peca some e sobra a
##    cratera ou o coto que ja' estavam embaixo.
##
##    Encolher cada osso-sombra pra cabeca DELE (escala zero simples) nao
##    serve: o antebraco pesa no osso do antebraco E no da mao, e o pulso
##    continua animado mesmo com o membro fora — a malha sumida virava uma
##    vareta do cotovelo ate' o pulso, saindo do coto.
##
##    Tem de ser aqui e nao no `_ready`: a AnimationPlayer reescreve a pose de
##    todo osso a cada quadro.
##
## 2. O NERVO MORTO. Tiques curtos e fora de compasso por cima de qualquer
##    clipe: a cabeca da' um tranco pro lado, um braco estremece, o tronco
##    torce. Sao eles que tiram o andar do zumbi do ritmo de captura — dois
##    lekrosos com o mesmo clipe nunca se mexem igual.

## 0 = sem tique; 1 = o normal; mais = mais ferido, mais nervoso.
var intensidade: float = 1.0

# cada peca arrancada: {ossos: PackedInt32Array, ancora: int, ponto: Vector3}
var _sumidos: Array = []
var _rng := RandomNumberGenerator.new()
var _ultimo_us: int = 0

# os tiques em andamento: {osso, eixo, angulo, t, ataque, segura, volta}
var _tiques: Array = []
var _proximo: float = 1.5
var _candidatos: Array = []      # [indice, peso, angulo maximo]
var _ossos_perdidos := {}        # nome do osso original -> true (braco que caiu nao treme)


func _ready() -> void:
	_rng.randomize()
	_proximo = _rng.randf_range(0.6, 2.5)


## Some com a peca: todos os ossos-sombra dela encolhem pro `ponto_rest`
## (espaco de repouso do esqueleto), que anda com o osso `ancora`.
func sumir(peca: String, ancora: String, ponto_rest: Vector3) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var pre := "pk_%s_" % peca
	var ossos := PackedInt32Array()
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).begins_with(pre):
			ossos.append(i)
	_sumidos.append({"ossos": ossos, "ancora": sk.find_bone(ancora), "ponto": ponto_rest})


## Um membro que caiu nao entra mais no sorteio dos tiques.
func perdeu_osso(nome: String) -> void:
	_ossos_perdidos[nome] = true
	_candidatos.clear()


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var agora := Time.get_ticks_usec()
	var dt := 0.0 if _ultimo_us == 0 else minf(float(agora - _ultimo_us) / 1e6, 0.1)
	_ultimo_us = agora

	# os tiques ANTES: girar um osso original depois moveria o ponto onde as
	# pecas arrancadas estao encolhidas
	if intensidade > 0.0:
		_tiques_do_quadro(sk, dt)

	var nada := Basis.from_scale(Vector3.ONE * 0.0005)
	for s in _sumidos:
		var a: int = s["ancora"]
		var ponto: Vector3 = s["ponto"]
		if a >= 0:
			ponto = (sk.get_bone_global_pose(a) * sk.get_bone_global_rest(a).affine_inverse()) * ponto
		for i in s["ossos"]:
			var rest := sk.get_bone_global_rest(i)
			# pose * repouso^-1 * v = ponto + 0,0005 v: todo vertice vai pro ponto
			sk.set_bone_global_pose(i, Transform3D(nada * rest.basis, ponto + nada * rest.origin))


func _monta_candidatos(sk: Skeleton3D) -> void:
	_candidatos.clear()
	# [osso, peso no sorteio, angulo maximo em graus]
	for c in [["head", 4.0, 22.0], ["neck", 3.0, 16.0], ["upper_chest", 1.0, 8.0],
			["upper_arm.L", 1.5, 18.0], ["upper_arm.R", 1.5, 18.0],
			["forearm.L", 1.2, 26.0], ["forearm.R", 1.2, 26.0],
			["hand.L", 1.0, 30.0], ["hand.R", 1.0, 30.0],
			["fingers.L", 0.8, 35.0], ["fingers.R", 0.8, 35.0]]:
		if _ossos_perdidos.has(c[0]):
			continue
		var i := sk.find_bone(c[0])
		if i >= 0:
			_candidatos.append([i, c[1], c[2]])


func _tiques_do_quadro(sk: Skeleton3D, dt: float) -> void:
	if _candidatos.is_empty():
		_monta_candidatos(sk)
		if _candidatos.is_empty():
			return

	_proximo -= dt * intensidade
	if _proximo <= 0.0:
		_proximo = _rng.randf_range(0.9, 3.6)
		_novo_tique()
		# as vezes vem em rajada: dois ou tres quase juntos
		if _rng.randf() < 0.3:
			_proximo = _rng.randf_range(0.12, 0.3)

	var vivos: Array = []
	for t in _tiques:
		t["t"] += dt
		var tt: float = t["t"]
		var a: float = t["ataque"]
		var s: float = t["segura"]
		var v: float = t["volta"]
		var env := 0.0
		if tt < a:
			env = tt / a
		elif tt < a + s:
			env = 1.0
		elif tt < a + s + v:
			var k := (tt - a - s) / v
			env = 1.0 - k * k * (3.0 - 2.0 * k)
		else:
			continue
		vivos.append(t)
		var i: int = t["osso"]
		var q := Quaternion(t["eixo"], deg_to_rad(t["angulo"]) * env * minf(intensidade, 1.6))
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * q)
	_tiques = vivos


func _novo_tique() -> void:
	var total := 0.0
	for c in _candidatos:
		total += c[1]
	var r := _rng.randf() * total
	var esc: Array = _candidatos[0]
	for c in _candidatos:
		r -= c[1]
		if r <= 0.0:
			esc = c
			break
	var eixo := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.4),
		_rng.randf_range(-1, 1)).normalized()
	_tiques.append({
		"osso": esc[0], "eixo": eixo,
		"angulo": _rng.randf_range(0.45, 1.0) * float(esc[2]),
		"t": 0.0, "ataque": _rng.randf_range(0.04, 0.09),
		"segura": _rng.randf_range(0.03, 0.18), "volta": _rng.randf_range(0.25, 0.6),
	})
