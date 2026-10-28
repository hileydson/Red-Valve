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
## O alvo vira coordenada de osso pela global da MALHA (`char1`), não do
## esqueleto: no .glb a malha vem girada 180° e descida (ver
## [[project-char1-espaco-dos-ossos]]).
##
##     var pose := PoseApontada.new()
##     esqueleto.add_child(pose)
##     pose.mirar("braco_d", ["RightArm", "RightForeArm"], "RightHand", alvo)
##     pose.esticar("braco_d", 2.2)   # o antebraço cresce (o Husk "estica a mão")

## nome -> {ids: PackedInt32Array, ponta: int, alvo: Vector3, peso: float, estica: float}
var _cadeias: Dictionary = {}
var _malha: MeshInstance3D


## Cria ou troca o alvo da cadeia `nome`. `ponta`: o osso cuja ORIGEM é a
## ponta do último da cadeia (o pulso, o tornozelo).
func mirar(nome: String, ossos: Array, ponta: String, alvo: Vector3, peso: float = 1.0) -> void:
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
	var sk := get_skeleton()
	var c: Dictionary = _cadeias.get(nome, {})
	if sk == null or c.is_empty():
		return 0.0
	var esp := _espaco(sk)
	var ids: PackedInt32Array = c["ids"]
	var total := 0.0
	for k in ids.size():
		var filho: int = ids[k + 1] if k + 1 < ids.size() else int(c["ponta"])
		if filho < 0:
			break
		var d := (esp * sk.get_bone_global_pose(ids[k]).origin).distance_to(esp * sk.get_bone_global_pose(filho).origin)
		total += d * (float(c["estica"]) if k == ids.size() - 1 else 1.0)
	return total


## Onde a PONTA da cadeia fica depois da mira. Não dá pra ler do esqueleto: fora
## do passo do modificador ele devolve a pose da animação, sem a mira. A cadeia
## mirada fica reta, então a ponta é a raiz + a direção do alvo × o comprimento.
func ponta_mirada(nome: String) -> Vector3:
	var sk := get_skeleton()
	var c: Dictionary = _cadeias.get(nome, {})
	if sk == null or c.is_empty():
		return Vector3.ZERO
	var raiz := _espaco(sk) * sk.get_bone_global_pose((c["ids"] as PackedInt32Array)[0]).origin
	var d := (c["alvo"] as Vector3) - raiz
	if d.length_squared() < 0.000001:
		return raiz
	return raiz + d.normalized() * comprimento(nome)


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
		var alvo: Vector3 = espaco * (c["alvo"] as Vector3)
		var ids: PackedInt32Array = c["ids"]
		var g := sk.get_bone_global_pose(ids[0])
		var g_pai := Transform3D.IDENTITY
		for k in ids.size():
			var i := ids[k]
			var filho: int = ids[k + 1] if k + 1 < ids.size() else int(c["ponta"])
			if filho < 0:
				break
			var l_filho := sk.get_bone_pose(filho)
			var g_novo := _apontar(g, (g * l_filho).origin, alvo, p)
			if k == 0:
				sk.set_bone_global_pose(i, g_novo)
			else:
				sk.set_bone_pose(i, g_pai.affine_inverse() * g_novo)
			g_pai = g_novo
			g = g_novo * l_filho


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
