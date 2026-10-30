extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A AURA DO AMULETO (Capítulo 1, altar do começo do inferno 4).
##
## Uma chama roxa pequena flutua em cima do altar. O Maycow chega perto, tira o
## amuleto do bolso, passa ele pela chama — ela entra no amuleto, que fica com
## a aura —, olha pro amuleto e guarda de novo. Conclui `CAP1_AURA_AMULETO`,
## que libera o primeiro poder da cogblade (o arremesso). A tela do poder novo
## vem depois, já em jogo (`inferno_4.gd`).
##
## O Maycow normal não tem clipe de pegar nada: o braço ESQUERDO (a direita
## costuma estar com a arma) é posto por `pose_apontada.gd`, mirando pontos do
## mundo — o bolso, a chama, a frente do rosto —, e o amuleto acompanha a ponta
## do braço quadro a quadro. A cabeça mira o amuleto pelo mesmo modificador.
##
## Quem chama: `inferno_4.gd`, ao pegar a chama (o selecionável do altar).

const PoseApontada := preload("res://scripts/cutscenes/pose_apontada.gd")
const AuraDoAmuleto := preload("res://scripts/systems/aura_do_amuleto.gd")
const SOM_AURA := "res://assets/sounds/player/espaco_travel.mp3"

const CAMINHO_ESQUELETO := "maycow_lopes_normal/Armature/Skeleton3D"
const OSSOS_BRACO := ["LeftArm", "LeftForeArm"]
const OSSO_MAO := "LeftHand"
const OSSO_CABECA := "Head"
## Até onde ele anda: a chama a esta distância (no chão) da frente dele.
const PERTO := 0.9
## Tamanho do amuleto na mão (o maior lado, em metros).
const TAMANHO_AMULETO := 0.075
## Da ponta do braço (o pulso) até o meio da mão.
const PALMA := 0.07

var chama: Node3D
## Onde a chama flutuava: se a cena cair antes dela entrar no amuleto, volta.
var _chama_origem := Vector3.ZERO
var _pose: SkeletonModifier3D
var _amuleto: Node3D
var _alvo := Vector3.ZERO
var _polo := Vector3.ZERO
var _peso := 0.0
var _cabeca_ponta := ""
var _peso_cabeca := 0.0
var _frente := Vector3.FORWARD
var _esquerda := Vector3.LEFT


func rodar(dono: Node3D, jogador: CharacterBody3D, a_chama: Node3D) -> void:
	chama = a_chama
	_chama_origem = chama.global_position
	travar(dono, jogador, 50.0)
	await _chegar_perto()
	if vale():
		await _gesto()
	_soltar()
	encerrar(0.8)


# ============================================================ a caminhada

func _chegar_perto() -> void:
	var c := chama.global_position
	var d := _no_chao(c - player.global_position)
	if d.length() > PERTO + 0.05:
		player.rotation.y = atan2(-d.x, -d.z)
		player.cutscene_set_auto_walk(true)
		var t := 0.0
		var parado := 0.0
		var antes := player.global_position
		while t < 4.0:
			await get_tree().process_frame
			if not vale():
				return
			if get_tree().paused:
				continue
			var dt := get_process_delta_time()
			t += dt
			d = _no_chao(c - player.global_position)
			player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 0.15)
			var dir := d.normalized() if d.length() > 0.01 else _frente
			var lado := Vector3(-dir.z, 0.0, dir.x)
			plantar(player.global_position - dir * 2.6 + lado * 0.9 + Vector3.UP * 1.75, c)
			if d.length() < PERTO:
				break
			# encostou no altar: o passo não leva mais pra frente
			parado = parado + dt if player.global_position.distance_to(antes) < dt * 0.25 else 0.0
			antes = player.global_position
			if parado > 0.3:
				break
		player.cutscene_set_auto_walk(false)
		player.velocity = Vector3.ZERO
	d = _no_chao(c - player.global_position)
	if d.length() > 0.01:
		player.rotation.y = atan2(-d.x, -d.z)
	_frente = -player.global_basis.z
	_frente.y = 0.0
	_frente = _frente.normalized()
	# o corpo olha pro -Z: a direita é o +X dele, a esquerda o -X
	_esquerda = -player.global_basis.x
	_esquerda.y = 0.0
	_esquerda = _esquerda.normalized()


# ============================================================ o gesto

func _gesto() -> void:
	var sk := player.get_node_or_null(CAMINHO_ESQUELETO) as Skeleton3D
	if sk:
		_pose = PoseApontada.new()
		_pose.name = "pose_aura"
		sk.add_child(_pose)
		var i_cabeca := sk.find_bone(OSSO_CABECA)
		if i_cabeca >= 0 and sk.get_bone_children(i_cabeca).size() > 0:
			_cabeca_ponta = sk.get_bone_name(sk.get_bone_children(i_cabeca)[0])
	_montar_amuleto()

	var pe := _pe()
	var bolso := pe + Vector3.UP * 0.95 + _esquerda * 0.2 + _frente * 0.05
	var rosto := pe + Vector3.UP * 1.5 + _frente * 0.3 + _esquerda * 0.02
	var c0 := chama.global_position
	# o encontro: a chama vem até onde a mão alcança (ela é atraída pelo amuleto)
	_mirar(bolso)
	await get_tree().process_frame
	var ombro: Vector3 = _pose.osso_no_mundo(OSSOS_BRACO[0]) if _pose else pe + Vector3.UP * 1.4
	var alcance: float = _pose.comprimento("braco") if _pose else 0.55
	if alcance < 0.2:
		alcance = 0.55
	var encontro := ombro + (c0 - ombro).normalized() * alcance * 0.85
	if ombro.distance_to(c0) < alcance * 0.85:
		encontro = c0

	# o plano de lado: ele à esquerda, a chama à direita, os dois no quadro
	var meio := (pe + Vector3.UP * 1.25).lerp(c0, 0.5)
	var lado := _frente.cross(Vector3.UP).normalized()
	# do lado de onde a câmera já estava: o corte não pula pro outro lado
	if (pe + lado).distance_to(cam.global_position) > (pe - lado).distance_to(cam.global_position):
		lado = -lado
	var cam_lado := meio + lado * 2.4 + Vector3.UP * 0.2 - _frente * 0.3
	plantar(cam_lado, meio)

	# 1) a mão vai ao bolso
	_polo = -_frente
	await fase(0.6, func(k: float) -> void:
		_peso = suave(k)
		_mirar(bolso))
	if not vale():
		return
	# 2) o amuleto sai do bolso
	if is_instance_valid(_amuleto):
		_amuleto.visible = true
	await esperar(0.2)

	# 3) leva até a chama, e ela vem ao encontro
	await fase(1.2, func(k: float) -> void:
		var e := suave(k)
		_polo = (-_frente).lerp(Vector3.DOWN + _esquerda * 0.6, e).normalized()
		_mirar(bolso.lerp(encontro, e))
		if is_instance_valid(chama):
			chama.global_position = c0.lerp(encontro + Vector3.UP * 0.02, suave(clampf(k * 1.3, 0.0, 1.0)))
		plantar(cam_lado.lerp(meio + lado * 1.7 + Vector3.UP * 0.1, e * 0.5), meio.lerp(encontro, e * 0.4)))
	if not vale():
		return

	# 4) a chama entra no amuleto
	await esperar(0.35)
	_tocar(SOM_AURA, 0.8, -4.0)
	if is_instance_valid(chama):
		chama.absorver(0.6, _amuleto)
	GlobalUtils.vibrate_controller(null, 0.5, 0.5, 0.35)
	await esperar(0.45)
	clarao(0.35, 0.5)
	if is_instance_valid(_amuleto):
		AuraDoAmuleto.vestir(_amuleto, true)
	Eventos.concluir(Eventos.CAP1_AURA_AMULETO)
	await esperar(0.5)
	if not vale():
		return

	# 5) traz pra frente do rosto e olha
	var olho := pe + Vector3.UP * 1.62
	var cam_perto := rosto + _frente * 0.55 + lado * 0.45 + Vector3.UP * 0.08
	await fase(1.0, func(k: float) -> void:
		var e := suave(k)
		_polo = (Vector3.DOWN + _esquerda * 0.6).normalized()
		_mirar(encontro.lerp(rosto, e))
		_peso_cabeca = e * 0.8
		plantar(cam_lado.lerp(cam_perto, e), meio.lerp(rosto.lerp(olho, 0.35), e)))
	if not vale():
		return
	await fase(1.8, func(k: float) -> void:
		_mirar(rosto + Vector3.UP * sin(k * PI) * 0.015)
		if is_instance_valid(_amuleto):
			_amuleto.rotate_y(get_process_delta_time() * 1.2)
		plantar(cam_perto + lado * k * 0.08, rosto.lerp(olho, 0.35)))
	if not vale():
		return

	# 6) guarda de novo
	var cam_fim := pe + _frente * 2.6 + lado * 1.2 + Vector3.UP * 1.5
	await fase(0.8, func(k: float) -> void:
		var e := suave(k)
		_polo = (Vector3.DOWN + _esquerda * 0.6).normalized().lerp(-_frente, e)
		_mirar(rosto.lerp(bolso, e))
		_peso_cabeca = 0.8 * (1.0 - e)
		plantar(cam_perto.lerp(cam_fim, e), rosto.lerp(pe + Vector3.UP * 1.2, e)))
	if is_instance_valid(_amuleto):
		_amuleto.visible = false
	await fase(0.4, func(k: float) -> void:
		_peso = 1.0 - suave(k)
		_mirar(bolso))


## Braço (e cabeça) pro alvo; o amuleto vai pra mão.
func _mirar(alvo: Vector3) -> void:
	_alvo = alvo
	if _pose == null:
		if is_instance_valid(_amuleto):
			_amuleto.global_position = alvo
		return
	_pose.mirar("braco", OSSOS_BRACO, OSSO_MAO, alvo, _peso, _polo)
	if _cabeca_ponta != "":
		# o osso da cabeça cresce pro alto do crânio: mirar ELE no amuleto
		# deitava a cabeça toda. Mira um ponto acima, puxado um pouco pro
		# amuleto — vira um aceno, o rosto descendo pra olhar a mão.
		var cabeca: Vector3 = _pose.osso_no_mundo(OSSO_CABECA)
		var objeto := _amuleto.global_position if is_instance_valid(_amuleto) else alvo
		var olhar := cabeca + Vector3.UP * 0.5 + (objeto - cabeca).normalized() * 0.2
		_pose.mirar("cabeca", [OSSO_CABECA], _cabeca_ponta, olhar, _peso_cabeca)
	if is_instance_valid(_amuleto):
		var ponta: Vector3 = _pose.ponta_mirada("braco")
		var ombro: Vector3 = _pose.osso_no_mundo(OSSOS_BRACO[0])
		var dir := (ponta - ombro).normalized() if ponta.distance_to(ombro) > 0.01 else _frente
		_amuleto.global_position = ponta + dir * PALMA


func _montar_amuleto() -> void:
	var cena_amuleto := load(AuraDoAmuleto.MODELO_AMULETO) as PackedScene
	if cena_amuleto == null:
		return
	_amuleto = Node3D.new()
	_amuleto.name = "amuleto_na_mao"
	cena.add_child(_amuleto)
	var modelo := cena_amuleto.instantiate() as Node3D
	_amuleto.add_child(modelo)
	for col in modelo.find_children("*", "CollisionObject3D", true, false):
		col.collision_layer = 0
		col.collision_mask = 0
	var caixa: AABB = AuraDoAmuleto._caixa(modelo, Transform3D.IDENTITY)
	var maior := maxf(maxf(caixa.size.x, caixa.size.y), caixa.size.z)
	var fator := TAMANHO_AMULETO / maior if maior > 0.0 else 0.24
	modelo.scale = Vector3.ONE * fator
	modelo.position = -caixa.get_center() * fator
	_amuleto.visible = false


func _soltar() -> void:
	if is_instance_valid(_pose):
		_pose.queue_free()
	if is_instance_valid(_amuleto):
		_amuleto.queue_free()
	# a cena caiu antes da chama entrar no amuleto: ela volta pro altar e
	# continua lá pra ser pega (o dono religa a seleção)
	if is_instance_valid(chama) and not Eventos.amuleto_com_aura():
		chama.global_position = _chama_origem


func _tocar(caminho: String, tom: float, volume: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.pitch_scale = tom
	s.volume_db = volume
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## O pé dele. A origem do jogador é o meio da cápsula (~0,9 m acima do chão):
## medida dali, a mão ia "ao bolso" acima da cabeça.
func _pe() -> Vector3:
	var de := player.global_position
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 3.0)
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return de - Vector3.UP * 0.9
	return Vector3(de.x, (h.position as Vector3).y, de.z)


static func _no_chao(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
