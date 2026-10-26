extends Node

## Monta os clipes de primeira pessoa da MK3 e da Granola na
## `armas_fp_clipes.tres` (a biblioteca do AnimationPlayer da mao_armada).
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/maos_fp/gerar_clipes_armas_novas.tscn
##
## Cena (e nao `-s`): a mao_armada tem scripts que leem autoload.
##
## MK3: idle/tiro/sacar/guardar sao os da pistola com os caminhos trocados
## (Armas/Pistola -> Armas/Mk3; o pente da arma e' o `Modelo/Pente`). A recarga
## e' propria: a mao esquerda vai ao pente (na frente do guarda-mato), puxa,
## JOGA FORA (ele sai voando pra esquerda e cai), busca outro no bolso e
## encaixa por baixo; depois bate no ferrolho, como a pistola.
##
## Granola: idle/tiro/sacar/guardar sao os da cacadeira, sem as trilhas da
## dobra e das camaras. A recarga: a mao larga o tubo, pega o foguete no cinto,
## traz ate' a frente da boca e empurra a cauda fina pra dentro; a ogiva fica
## pra fora (o `MunicaoNaArma`, que o codigo liga quando o foguete entra).
##
## As poses-chave da mao e da municao NAO sao chutadas: saem da geometria da
## cena (onde o pente esta' na arma, onde fica a boca do cano), entao o pente
## na mao encaixa exatamente no lugar do pente da arma, e o foguete na mao
## desliza exatamente pra posicao do foguete carregado.
##
## Rodar de novo REESCREVE os clipes mk3_* e granola_* (e so' eles).

const BIBLIOTECA := "res://assets/3d_model/player/hands/maos_fp/armas_fp_clipes.tres"
const CENA := "res://scenes/player/first_person_view/mao_armada.tscn"

var lib: AnimationLibrary
var raiz: Node3D


func _ready() -> void:
	lib = load(BIBLIOTECA)
	raiz = load(CENA).instantiate()
	add_child(raiz)
	raiz.process_mode = Node.PROCESS_MODE_DISABLED
	for nome in lib.get_animation_list():
		if String(nome).begins_with("mk3_") or String(nome).begins_with("granola_"):
			lib.remove_animation(nome)
	_mk3()
	_granola()
	var erro := ResourceSaver.save(lib, BIBLIOTECA)
	print("clipes gravados: ", erro, " ", lib.get_animation_list())
	get_tree().quit()


# ------------------------------------------------------------------ comum
func _copiar(origem: String, destino: String, trocas: Array, fora: Array) -> Animation:
	var a: Animation = lib.get_animation(origem).duplicate(true)
	for t in range(a.get_track_count() - 1, -1, -1):
		var caminho := String(a.track_get_path(t))
		var sai := false
		for f in fora:
			if caminho.contains(f):
				sai = true
		if sai:
			a.remove_track(t)
			continue
		for tr in trocas:
			caminho = caminho.replace(tr[0], tr[1])
		a.track_set_path(t, NodePath(caminho))
	lib.add_animation(destino, a)
	return a


func _trilha(a: Animation, tipo: int, caminho: String) -> int:
	var i := a.find_track(NodePath(caminho), tipo)
	if i >= 0:
		a.remove_track(i)
	i = a.add_track(tipo)
	a.track_set_path(i, NodePath(caminho))
	if tipo == Animation.TYPE_VALUE:
		a.value_track_set_update_mode(i, Animation.UPDATE_DISCRETE if caminho.ends_with(":visible") else Animation.UPDATE_CONTINUOUS)
	return i


func _chaves(a: Animation, tipo: int, caminho: String, chaves: Array) -> void:
	var i := _trilha(a, tipo, caminho)
	for k in chaves:
		match tipo:
			Animation.TYPE_POSITION_3D:
				a.position_track_insert_key(i, k[0], k[1])
			Animation.TYPE_ROTATION_3D:
				var v = k[1]
				var q: Quaternion = v if v is Quaternion else Quaternion.from_euler(v * PI / 180.0)
				a.rotation_track_insert_key(i, k[0], q)
			_:
				a.track_insert_key(i, k[0], k[1])


func _eventos(a: Animation, chaves: Array) -> void:
	var i := _trilha(a, Animation.TYPE_METHOD, ".")
	for k in chaves:
		a.track_insert_key(i, k[0], {"method": &"evento_recarga", "args": [k[1]]})


func _no(caminho: String) -> Node3D:
	return raiz.get_node("rig/" + caminho) as Node3D


func _pose(pos: Vector3, rot_graus: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_graus * PI / 180.0), pos)


## Pulso (controle de mao) a partir de onde a palma deve ficar: -Z do controle
## segue os dedos, +Y aponta pra palma.
func _pulso(palma: Vector3, dedos: Vector3, normal_palma: Vector3, recuo := 0.09, afasta := 0.035) -> Transform3D:
	var z := -dedos.normalized()
	var y := (normal_palma - z * normal_palma.dot(z)).normalized()
	var x := y.cross(z).normalized()
	var b := Basis(x, y, z)
	return Transform3D(b, palma - dedos.normalized() * recuo - normal_palma.normalized() * afasta)


# ------------------------------------------------------------------ MK3
func _mk3() -> void:
	var trocas := [["Armas/Pistola", "Armas/Mk3"], ["Movimento/Carregador:visible", "Movimento/Modelo/Pente:visible"]]
	var fora := ["recuo_ferrolho"]
	for acao in ["idle", "tiro", "sacar", "guardar"]:
		_copiar("pistola_" + acao, "mk3_" + acao, trocas, fora)
	# o coice da rajada e' mais curto (tres tiros em 0,15 s)
	var tiro := lib.get_animation("mk3_tiro")
	tiro.length = 0.12
	_chaves(tiro, Animation.TYPE_POSITION_3D, "Armas/Mk3/Movimento", [
		[0.0, Vector3.ZERO], [0.03, Vector3(0.003, -0.004, 0.02)], [0.12, Vector3.ZERO]])
	_chaves(tiro, Animation.TYPE_ROTATION_3D, "Armas/Mk3/Movimento", [
		[0.0, Vector3.ZERO], [0.03, Vector3(7, 0, -2)], [0.12, Vector3.ZERO]])

	var a := _copiar("pistola_recarga", "mk3_recarga", trocas, fora)
	a.length = 3.0
	# a arma sobe e deita (como a pistola) e fica parada assim ate' 2,65
	var erguida := _pose(Vector3(-0.045, 0.165, -0.015), Vector3(27, -12, -32))
	var modelo := _no("Armas/Mk3/Movimento/Modelo")
	var pente_na_arma := erguida * modelo.transform * (_no("Armas/Mk3/Movimento/Modelo/Pente").transform)
	# a base do pente, no espaco da MK3 com a arma erguida, e os eixos da arma
	var base_do_pente := erguida * modelo.transform * Vector3(-0.50, -0.55, 0.0)
	var direita := erguida.basis * Vector3.RIGHT
	var cima := erguida.basis * Vector3.UP
	var frente := erguida.basis * Vector3.FORWARD
	# a palma por baixo do pente, os dedos fechando pra direita em volta dele
	var pega := _pulso(base_do_pente - cima * 0.01, direita, cima)
	var puxado := Transform3D(pega.basis, pega.origin - cima * 0.07)
	var jogando := Transform3D(pega.basis.rotated(frente, 0.6), pega.origin - cima * 0.13 - direita * 0.22)
	var bolso := _pose(Vector3(-0.388, -0.389, -0.008), Vector3(49.079, -138.0, 136.124))
	var embaixo := Transform3D(pega.basis, pega.origin - cima * 0.10)
	var tapa := Transform3D(pega.basis, pega.origin + cima * 0.012)
	var repouso := _no("Armas/Mk3/ControleRecargaEsquerdo").transform
	var ferrolho := _pose(Vector3(-0.089, 0.223, -0.033), Vector3(49.079, -138.0, 136.124))
	var c := "Armas/Mk3/ControleRecargaEsquerdo"
	var poses := [[0.0, repouso], [0.35, pega], [0.55, puxado], [0.72, jogando], [1.12, bolso],
		[1.65, embaixo], [2.04, pega], [2.12, tapa], [2.24, pega], [2.45, ferrolho],
		[2.6, Transform3D(ferrolho.basis, ferrolho.origin - frente * 0.03)], [2.69, ferrolho], [3.0, repouso]]
	_chaves(a, Animation.TYPE_POSITION_3D, c, poses.map(func(k): return [k[0], (k[1] as Transform3D).origin]))
	_chaves(a, Animation.TYPE_ROTATION_3D, c, poses.map(func(k): return [k[0], (k[1] as Transform3D).basis.get_rotation_quaternion()]))
	# o pente na mao: preso a palma, encaixado onde o pente da arma esta' na
	# hora da pegada e do encaixe (a mao esta' na MESMA pose nas duas)
	var na_mao := pega.affine_inverse() * pente_na_arma
	_chaves(a, Animation.TYPE_POSITION_3D, c + "/CarregadorNaMao", [[0.0, na_mao.origin]])
	_chaves(a, Animation.TYPE_ROTATION_3D, c + "/CarregadorNaMao", [[0.0, na_mao.basis.orthonormalized().get_rotation_quaternion()]])
	_chaves(a, Animation.TYPE_VALUE, c + "/CarregadorNaMao:visible", [[0.0, false], [0.35, true], [0.72, false], [1.12, true], [2.04, false]])
	_chaves(a, Animation.TYPE_VALUE, "Armas/Mk3/Movimento/Modelo/Pente:visible", [[0.0, true], [0.35, false], [2.04, true]])
	# o pente jogado: sai da mao na pose em que ela solta e cai pra esquerda,
	# girando, ate' sumir embaixo da tela
	var solto := erguida.affine_inverse() * jogando * na_mao
	var caido := Transform3D(solto.basis.rotated(Vector3(0.3, 0.2, 1).normalized(), 2.6),
		solto.origin + Vector3(-0.45, -0.95, 0.12))
	var meio := Transform3D(solto.basis.rotated(Vector3(0.3, 0.2, 1).normalized(), 1.1),
		solto.origin + Vector3(-0.22, -0.18, 0.04))
	var s := "Armas/Mk3/Movimento/CarregadorSolto"
	_chaves(a, Animation.TYPE_VALUE, s + ":visible", [[0.0, false], [0.72, true], [1.2, false]])
	_chaves(a, Animation.TYPE_POSITION_3D, s, [[0.0, solto.origin], [0.72, solto.origin], [0.88, meio.origin], [1.2, caido.origin]])
	_chaves(a, Animation.TYPE_ROTATION_3D, s, [[0.0, solto.basis.get_rotation_quaternion()], [0.72, solto.basis.get_rotation_quaternion()],
		[0.88, meio.basis.orthonormalized().get_rotation_quaternion()], [1.2, caido.basis.orthonormalized().get_rotation_quaternion()]])
	_eventos(a, [[0.36, "mk3_pente_sai"], [1.05, "mk3_pente_cai"], [2.04, "mk3_pente"], [2.5, "mk3_ferrolho"]])
	_chaves(a, Animation.TYPE_VALUE, ".:mao_esquerda_na_recarga", [[0.0, 0.0], [0.12, 0.0], [0.35, 1.0], [2.69, 1.0], [3.0, 0.0]])


# ------------------------------------------------------------------ Granola
func _granola() -> void:
	var trocas := [["Armas/Shotgun", "Armas/Granola"]]
	# a Granola nao dobra: fora a dobra, as camaras e a pose do apoio (que na
	# cacadeira e' relativa a Articulacao dela)
	var fora := ["Articulacao/Camara"]
	for acao in ["idle", "tiro", "sacar", "guardar"]:
		var c := _copiar("shotgun_" + acao, "granola_" + acao, trocas, fora)
		_tirar_trilhas_de_pose(c, ["Armas/Granola/Movimento/Articulacao", "Armas/Granola/Movimento/Articulacao/ApoioEsquerdo"])
	# o coice do foguete: mais lento que o da cacadeira, e o cano sobe mais
	var tiro := lib.get_animation("granola_tiro")
	_chaves(tiro, Animation.TYPE_POSITION_3D, "Armas/Granola/Movimento", [
		[0.0, Vector3.ZERO], [0.06, Vector3(0.004, -0.004, 0.07)], [0.2, Vector3(0, 0, 0.03)], [0.65, Vector3.ZERO]])
	_chaves(tiro, Animation.TYPE_ROTATION_3D, "Armas/Granola/Movimento", [
		[0.0, Vector3.ZERO], [0.06, Vector3(16, 0, -3)], [0.22, Vector3(6, 0, 0)], [0.65, Vector3.ZERO]])

	var a := _copiar("shotgun_recarga", "granola_recarga", trocas, fora)
	_tirar_trilhas_de_pose(a, ["Armas/Granola/Movimento/Articulacao", "Armas/Granola/Movimento/Articulacao/ApoioEsquerdo"])
	a.length = 2.9
	# tira as chaves de cartucho/dobra da cacadeira que sobraram
	for t in range(a.get_track_count() - 1, -1, -1):
		var caminho := String(a.track_get_path(t))
		if caminho.contains("CartuchoNaMao") or caminho == "." or caminho.contains("ControleEsquerdo") \
				or caminho.ends_with(":apoio_esquerdo") or caminho == "Armas/Granola/Movimento":
			a.remove_track(t)
	# a arma sobe, o cano vira pra cima e pra esquerda (a boca vem pra mao) e
	# recua pro peito, pra boca ficar ao alcance e o foguete entrar sem o braco
	# esticado
	var erguida := _pose(Vector3(-0.03, -0.24, 0.19), Vector3(28, 24, -10))
	_chaves(a, Animation.TYPE_POSITION_3D, "Armas/Granola/Movimento", [
		[0.0, Vector3.ZERO], [0.35, erguida.origin], [2.35, erguida.origin], [2.7, Vector3.ZERO]])
	_chaves(a, Animation.TYPE_ROTATION_3D, "Armas/Granola/Movimento", [
		[0.0, Vector3.ZERO], [0.35, erguida.basis.get_rotation_quaternion()], [2.35, erguida.basis.get_rotation_quaternion()], [2.7, Vector3.ZERO]])
	_chaves(a, Animation.TYPE_VALUE, ".:apoio_esquerdo", [[0.0, 1.0], [0.25, 1.0], [0.45, 0.0], [2.3, 0.0], [2.55, 1.0]])

	# tudo da mao livre (AjusteEsquerdo/ControleEsquerdo) e' no espaco do rig
	var no_rig := _no("Armas").transform * _no("Armas/Granola").transform * erguida
	var municao := _no("Armas/Granola/Movimento/MunicaoNaArma").transform
	var carregado := no_rig * municao
	var tras := (no_rig.basis * Vector3.BACK).normalized()      # do cano pra culatra
	var dir_da_arma := (no_rig.basis * Vector3.RIGHT).normalized()
	# a ogiva do foguete carregado (x -0,6 do .glb dele) e a mao segurando-a
	# pela esquerda, os dedos correndo pro lado da culatra
	var ogiva := carregado * Vector3(-0.6, 0.0, 0.0)
	var empurra := _pulso(ogiva, tras, dir_da_arma, 0.075, 0.04)
	var na_frente := Transform3D(empurra.basis, empurra.origin - tras * 0.24)
	var afasta := Transform3D(empurra.basis, empurra.origin - tras * 0.08 - dir_da_arma * 0.05)
	var repouso := _pose(Vector3(-0.23, -0.19, -0.32), Vector3(21.582, -8.531, -88.977))
	var cinto := _pose(Vector3(-0.406, -0.569, -0.217), Vector3(43.875, -91.901, 157.469))
	var c := "AjusteEsquerdo/ControleEsquerdo"
	var poses := [[0.0, repouso], [0.45, _pose(Vector3(-0.30, -0.45, -0.20), Vector3(43.875, -91.901, 157.469))],
		[0.7, cinto], [0.85, cinto], [1.3, na_frente], [1.62, empurra], [1.8, afasta], [2.3, repouso], [2.9, repouso]]
	_chaves(a, Animation.TYPE_POSITION_3D, c, poses.map(func(k): return [k[0], (k[1] as Transform3D).origin]))
	_chaves(a, Animation.TYPE_ROTATION_3D, c, poses.map(func(k): return [k[0], (k[1] as Transform3D).basis.get_rotation_quaternion()]))
	# o foguete na mao: preso a mao na pose do empurrao, onde ele coincide com
	# o carregado (e na frente, 24 cm antes, ele esta' fora do tubo)
	var na_mao := empurra.affine_inverse() * carregado
	_chaves(a, Animation.TYPE_POSITION_3D, c + "/FogueteNaMao", [[0.0, na_mao.origin]])
	_chaves(a, Animation.TYPE_ROTATION_3D, c + "/FogueteNaMao", [[0.0, na_mao.basis.orthonormalized().get_rotation_quaternion()]])
	_chaves(a, Animation.TYPE_VALUE, c + "/FogueteNaMao:visible", [[0.0, false], [0.78, true], [1.62, false]])
	_chaves(a, Animation.TYPE_VALUE, c + "/CartuchoNaMao:visible", [[0.0, false]])
	# dedos: abertos indo, fechados no foguete, abertos voltando
	var aberta := Vector3(18, 24, 16)
	var fechada := Vector3(48, 52, 30)
	for dedo in ["indicador", "medio", "anelar", "mindinho"]:
		_chaves(a, Animation.TYPE_VALUE, c + ":" + dedo, [[0.0, aberta], [0.7, aberta], [0.82, fechada], [1.62, fechada], [1.72, aberta]])
	_chaves(a, Animation.TYPE_VALUE, c + ":polegar", [[0.0, Vector3(20, 20, 12)], [0.82, Vector3(8, 15, 10)], [1.72, Vector3(20, 20, 12)]])
	_chaves(a, Animation.TYPE_VALUE, c + ":torcao_antebraco", [[0.0, 0.0]])
	_eventos(a, [[1.6, "granola_foguete"], [2.45, "granola_trava"]])
	_chaves(a, Animation.TYPE_VALUE, ".:mao_esquerda_na_recarga", [[0.0, 0.0]])
	# nos clipes da pistola/cacadeira tambem ha' estas trilhas; aqui garantem
	# que o foguete da mao nao vaze pra outros clipes
	for nome in ["granola_idle", "granola_tiro", "granola_sacar", "granola_guardar", "mk3_idle", "mk3_tiro",
			"mk3_sacar", "mk3_guardar", "mk3_recarga"]:
		_chaves(lib.get_animation(nome), Animation.TYPE_VALUE, c + "/FogueteNaMao:visible", [[0.0, false]])


func _tirar_trilhas_de_pose(a: Animation, caminhos: Array) -> void:
	for t in range(a.get_track_count() - 1, -1, -1):
		var tipo := a.track_get_type(t)
		if (tipo == Animation.TYPE_POSITION_3D or tipo == Animation.TYPE_ROTATION_3D) \
				and String(a.track_get_path(t)) in caminhos:
			a.remove_track(t)
