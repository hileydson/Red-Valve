extends SkeletonModifier3D

## POSE POR ALVO, pra cutscene: cada CADEIA de ossos (braço + antebraço, coxa +
## perna) aponta pra um ponto do MUNDO, por cima do que a animação escreveu.
##
## É o mesmo desenho do `player_door_reach.gd`, generalizado: os rigs do Husk e
## do Maycow normal são Meshy/Mixamo (o osso cresce pro +Y local, sem dedo) e
## não têm clipe de agarrar, de pendurar nem de espernear. Em vez de ângulo
## chutado por osso, cada osso gira pelo arco que leva a direção dele (da
## origem até a do filho) até o alvo — vale pra qualquer convenção de eixo e
## qualquer giro do modelo.
##
## O arco parte da pose de REPOUSO (o T do rig), não da animação: braço caído
## na animação e alvo lá em cima dão meia-volta, e o eixo de uma meia-volta é
## indefinido — o braço saía torcido em volta de si mesmo. Do T, qualquer alvo
## fica a no máximo um quarto de volta e a torção é a do repouso.
##
## Com `polo` a cadeia de dois ossos DOBRA (IK de dois ossos): o cotovelo, ou o
## joelho, vai pro lado do polo quando o alvo está mais perto que o braço
## esticado. Sem polo ela fica reta e passa do alvo.
##
## O alvo vira coordenada de osso pela global da MALHA (`char1`), não do
## esqueleto: no .glb a malha vem girada 180° e descida (ver
## [[project-char1-espaco-dos-ossos]]).
##
##     var pose := PoseApontada.new()
##     esqueleto.add_child(pose)
##     pose.mirar("braco_d", ["RightArm", "RightForeArm"], "RightHand", alvo)
##     pose.esticar("braco_d", 2.2)   # o antebraço cresce (o Husk "estica a mão")

## nome -> {ids: PackedInt32Array, ponta: int, alvo: Vector3, peso: float,
## estica: float, polo: Vector3}
var _cadeias: Dictionary = {}
var _malha: MeshInstance3D


## Cria ou troca o alvo da cadeia `nome`. `ponta`: o osso cuja ORIGEM é a
## ponta do último da cadeia (o pulso, o tornozelo). `polo`: direção do MUNDO
## pra onde a junta do meio dobra (zero = cadeia reta).
func mirar(nome: String, ossos: Array, ponta: String, alvo: Vector3, peso: float = 1.0,
		polo: Vector3 = Vector3.ZERO) -> void:
	var c: Dictionary = _cadeias.get(nome, {})
	if c.is_empty():
		var sk := get_skeleton()
		if sk == null:
			return
		var ids := PackedInt32Array()
		for o in ossos:
			var i := sk.find_bone(o)
			if i < 0:
				push_warning("pose_apontada: rig sem o osso %s" % o)
				return
			ids.append(i)
		c = {"ids": ids, "ponta": sk.find_bone(ponta), "estica": 1.0}
		_cadeias[nome] = c
	c["alvo"] = alvo
	c["peso"] = peso
	c["polo"] = polo


func peso(nome: String, valor: float) -> void:
	if _cadeias.has(nome):
		_cadeias[nome]["peso"] = valor


## O ÚLTIMO osso da cadeia cresce `fator` vezes no comprimento (e a ponta é
## encolhida de volta, pra mão não sair esticada junto).
func esticar(nome: String, fator: float) -> void:
	if _cadeias.has(nome):
		_cadeias[nome]["estica"] = fator


## Onde fica, no mundo, a origem do osso `osso` agora.
func osso_no_mundo(osso: String) -> Vector3:
	var sk := get_skeleton()
	if sk == null:
		return Vector3.ZERO
	var i := sk.find_bone(osso)
	if i < 0:
		return sk.global_position
	return _espaco(sk) * sk.get_bone_global_pose(i).origin


## Comprimento da cadeia no mundo (o último osso já esticado).
func comprimento(nome: String) -> float:
	var c: Dictionary = _cadeias.get(nome, {})
	if c.is_empty():
		return 0.0
	var total := 0.0
	var n := (c["ids"] as PackedInt32Array).size()
	for k in n:
		total += segmento(nome, k) * (float(c["estica"]) if k == n - 1 else 1.0)
	return total


## O osso `k` da cadeia no mundo, SEM o esticar. Medido pelo deslocamento do
## filho (a pose global lida de fora já traz a escala que o esticar deixou).
func segmento(nome: String, k: int) -> float:
	var sk := get_skeleton()
	var c: Dictionary = _cadeias.get(nome, {})
	if sk == null or c.is_empty():
		return 0.0
	var ids: PackedInt32Array = c["ids"]
	var filho: int = ids[k + 1] if k + 1 < ids.size() else int(c["ponta"])
	if filho < 0:
		return 0.0
	return sk.get_bone_pose(filho).origin.length() * _espaco(sk).basis.get_scale().x


## Onde a PONTA da cadeia fica depois da mira. Não dá pra ler do esqueleto: fora
## do passo do modificador ele devolve a pose da animação, sem a mira. Reta, a
## ponta é a raiz + a direção do alvo × o comprimento; dobrando, é o alvo (se
## ele estiver ao alcance).
func ponta_mirada(nome: String) -> Vector3:
	var sk := get_skeleton()
	var c: Dictionary = _cadeias.get(nome, {})
	if sk == null or c.is_empty():
		return Vector3.ZERO
	var raiz := _espaco(sk) * sk.get_bone_global_pose((c["ids"] as PackedInt32Array)[0]).origin
	var d := (c["alvo"] as Vector3) - raiz
	if d.length_squared() < 0.000001:
		return raiz
	var alcance := comprimento(nome)
	if (c.get("polo", Vector3.ZERO) as Vector3) != Vector3.ZERO:
		alcance = minf(alcance, d.length())
	return raiz + d.normalized() * alcance


func _espaco(sk: Skeleton3D) -> Transform3D:
	if not is_instance_valid(_malha):
		for filho in sk.get_children():
			if filho is MeshInstance3D:
				_malha = filho
				break
	return _malha.global_transform if is_instance_valid(_malha) else sk.global_transform


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var espaco := _espaco(sk).affine_inverse()
	for c in _cadeias.values():
		var p: float = c.get("peso", 0.0)
		_escala(sk, c, c["estica"] if p > 0.001 else 1.0)
		if p <= 0.001:
			continue
		var ids: PackedInt32Array = c["ids"]
		var alvo: Vector3 = espaco * (c["alvo"] as Vector3)
		var alvos: Array[Vector3] = []
		var polo: Vector3 = c.get("polo", Vector3.ZERO)
		if polo != Vector3.ZERO and ids.size() == 2 and int(c["ponta"]) >= 0:
			alvos.append(_cotovelo(sk, c, alvo, (espaco.basis * polo).normalized()))
		alvos.append(alvo)
		var pai := sk.get_bone_parent(ids[0])
		var g_pai := sk.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
		for k in ids.size():
			var i := ids[k]
			var filho: int = ids[k + 1] if k + 1 < ids.size() else int(c["ponta"])
			if filho < 0:
				break
			var pose := sk.get_bone_pose(i)
			var esc := pose.basis.get_scale()
			var g_anim := g_pai * pose
			# o mesmo osso na torção do repouso, com a escala de agora (o esticar)
			var repouso := Basis(sk.get_bone_rest(i).basis.get_rotation_quaternion()) * Basis.from_scale(esc)
			var g_rep := g_pai * Transform3D(repouso, pose.origin)
			var ponta := g_rep * sk.get_bone_pose(filho).origin
			var mira: Vector3 = alvos[k] if k < alvos.size() else alvos[alvos.size() - 1]
			var g_mira := _apontar(g_rep, ponta, mira, 1.0)
			var q := g_anim.basis.get_rotation_quaternion().slerp(g_mira.basis.get_rotation_quaternion(), p)
			var g_pai_q := g_pai.basis.get_rotation_quaternion()
			var local := Transform3D(Basis(g_pai_q.inverse() * q) * Basis.from_scale(esc), pose.origin)
			sk.set_bone_pose(i, local)
			g_pai = g_pai * local


## IK de dois ossos: onde o cotovelo tem de ficar pra mão chegar em `alvo`
## dobrando pro lado do `polo` (tudo no espaço do esqueleto).
func _cotovelo(sk: Skeleton3D, c: Dictionary, alvo: Vector3, polo: Vector3) -> Vector3:
	var ids: PackedInt32Array = c["ids"]
	var raiz := sk.get_bone_global_pose(ids[0]).origin
	var a := sk.get_bone_pose(ids[1]).origin.length()
	var b := sk.get_bone_pose(int(c["ponta"])).origin.length() * float(c["estica"])
	var para := alvo - raiz
	var d := clampf(para.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := para.normalized() if para.length_squared() > 0.000001 else Vector3.DOWN
	var lado := polo - dir * polo.dot(dir)
	if lado.length_squared() < 0.000001:
		lado = dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.FORWARD)
	lado = lado.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	return raiz + dir * (cos_a * a) + lado * (sqrt(1.0 - cos_a * cos_a) * a)


## Escala ABSOLUTA (as animações destes rigs não escrevem escala: multiplicar a
## de agora faria o braço crescer a cada quadro). Volta a 1 quando desliga.
func _escala(sk: Skeleton3D, c: Dictionary, e: float) -> void:
	if absf(e - 1.0) < 0.01 and not c.get("esticado", false):
		return
	c["esticado"] = absf(e - 1.0) >= 0.01
	var ids: PackedInt32Array = c["ids"]
	sk.set_bone_pose_scale(ids[ids.size() - 1], Vector3(1.0, e, 1.0))
	if int(c["ponta"]) >= 0:
		sk.set_bone_pose_scale(int(c["ponta"]), Vector3(1.0, 1.0 / e, 1.0))


static func _apontar(g: Transform3D, ponta: Vector3, alvo: Vector3, peso: float) -> Transform3D:
	var atual := ponta - g.origin
	var desejado := alvo - g.origin
	if atual.length_squared() < 0.0001 or desejado.length_squared() < 0.0001:
		return g
	var giro := Quaternion(atual.normalized(), desejado.normalized())
	giro = Quaternion.IDENTITY.slerp(giro, peso)
	return Transform3D(Basis(giro) * g.basis, g.origin)
