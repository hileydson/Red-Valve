extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A QUADRA DA ESCOLA (Capítulo 1): o raio da Dona Nice.
##
##  1. o Maycow chega no meio da quadra e vê a Dona Nice indo embora pelo
##     portão da rua, de mão dada com o Jonny;
##  2. ela para e olha pra trás — a câmera fecha no rosto dela, que o vê;
##  3. ela ergue a mão direita pro céu; a câmera sobe com a mão até o céu;
##  4. um RAIO cai no meio da quadra. A Dona Nice e o Jonny somem no clarão, e
##     a escola começa a virar a escura: a onda sai da quadra e a câmera vai
##     mostrando os lugares sendo tomados (o pátio, o corredor norte, a
##     biblioteca, a grade aparecendo no corredor sul) — os adultos somem
##     quando ela passa por eles;
##  5. do canto da quadra vem o Grizzolito, andando, olhando pro Maycow.
##
## O evento `CAP1_ESCOLA_TRANSFORMADA` é concluído no raio: fechar o jogo no
## meio da cena já volta na luta. Quem monta os atores e solta a luta no fim
## é o `capitulo_1_escola.gd`.

const SOM_TROVAO := "res://assets/sounds/cenarios/trovao.ogg"
const SOM_SUMIR := "res://assets/sounds/igreja/teleporte_some.ogg"
const TELEPORTE := preload("res://scripts/effects/teleporte_dona_nice.gd")
const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")

## O meio da quadra (onde o raio cai) e onde o Maycow fica.
const QUADRA := Vector3(23.0, 0.0, 28.0)
const MAYCOW := Vector3(25.5, 0.0, 30.0)
## A Dona Nice sai daqui e vai pro portão da rua.
const NICE_INICIO := Vector3(19.0, 0.0, 30.8)
const PORTAO_RUA := Vector3(3.2, 0.0, 33.0)
const VELOCIDADE := 0.9
## O canto da quadra de onde vem o Grizzolito.
const CANTO := Vector3(39.0, 0.0, 18.4)

var versoes: Node
var dona: Node3D
var jonny: Node3D
var grizzolito: Node3D
var adultos: Array = []

var _andando := false
var _dir := Vector3.LEFT


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 50.0)
	await escurecer(1.0, 0.4)
	_posicionar()
	await esperar(0.2)
	if vale():
		await _eles_indo_embora()
	if vale():
		await _ela_olha_pra_tras()
	if vale():
		await _mao_pro_ceu()
	if vale():
		await _o_raio()
	if vale():
		await _a_escola_escurece()
	if vale():
		await _o_grizzolito()
	encerrar(0.8)


func _posicionar() -> void:
	var y := _chao(MAYCOW)
	player.global_position = Vector3(MAYCOW.x, y + 1.0, MAYCOW.z)
	player.rotation.y = PI * 0.5   # o corpo olha pro -Z; +90 graus = pro -X (o portão)
	player.velocity = Vector3.ZERO
	_dir = (PORTAO_RUA - NICE_INICIO).normalized()
	var giro := atan2(_dir.x, _dir.z)
	# o Jonny vai do lado ESQUERDO dela (a mão direita dele na esquerda dela)
	var lado_esquerdo := -Vector3(-_dir.z, 0.0, _dir.x)
	dona.global_position = Vector3(NICE_INICIO.x, _chao(NICE_INICIO), NICE_INICIO.z)
	dona.rotation.y = giro
	jonny.global_position = dona.global_position + lado_esquerdo * 0.55
	jonny.rotation.y = giro
	dona.visible = true
	jonny.visible = true
	dona.tocar(&"escola/andar_de_mao", 0.0)
	jonny.tocar(&"escola/andar_de_mao", 0.0)
	_andando = true
	if is_instance_valid(grizzolito):
		grizzolito.visible = false


func _process(delta: float) -> void:
	if not _andando or not is_instance_valid(dona):
		return
	var passo := _dir * VELOCIDADE * delta
	dona.global_position += passo
	jonny.global_position += passo


# ============================================================ 1) indo embora

func _eles_indo_embora() -> void:
	# atrás do Maycow, por cima do ombro direito: ele no canto do quadro, os
	# dois indo embora lá na frente
	var pra_eles := (dona.global_position - player.global_position)
	pra_eles.y = 0.0
	pra_eles = pra_eles.normalized()
	var lado := Vector3(-pra_eles.z, 0.0, pra_eles.x)
	var de := player.global_position - pra_eles * 2.6 + lado * 0.9 + Vector3.UP * 0.9
	await escurecer(0.0, 0.5)
	legenda("CAP1_CENA_MAYCOW_CHAMA", 2.4)
	await fase(3.4, func(k: float) -> void:
		var alvo := (dona.global_position + jonny.global_position) * 0.5 + Vector3.UP * 0.9
		plantar(de + pra_eles * (suave(k) * 1.0), alvo))


# ============================================================ 2) o olhar

func _ela_olha_pra_tras() -> void:
	_andando = false
	jonny.tocar(&"escola/parado_de_mao", 0.3)
	dona.tocar(&"escola/olhar_tras", 0.25)
	var direita := Vector3(-_dir.z, 0.0, _dir.x)
	var rosto_dir := (-_dir * 0.75 + direita * 0.65).normalized()
	var cabeca := dona.global_position + Vector3.UP * 1.47
	var de := cabeca + rosto_dir * 1.9 + Vector3.UP * 0.05
	var ate := cabeca + rosto_dir * 1.25
	await plano(de, cabeca, ate, cabeca, 2.6)
	# o contraplano: por cima do ombro dela, o Maycow lá no meio da quadra
	var ombro := cabeca - rosto_dir * 0.55 + direita * 0.35 + Vector3.UP * 0.1
	var alvo := player.global_position + Vector3.UP * 0.6
	await plano(ombro, alvo, ombro - rosto_dir * 0.2, alvo, 2.0)


# ============================================================ 3) a mão

func _mao_pro_ceu() -> void:
	dona.tocar(&"escola/mao_pro_ceu", 0.2)
	var direita := Vector3(-_dir.z, 0.0, _dir.x)
	var frente_dela := (-_dir * 0.75 + direita * 0.65).normalized()
	var baixo := dona.global_position + frente_dela * 2.4 + Vector3.UP * 0.55
	await fase(1.8, func(k: float) -> void:
		var mao: Vector3 = dona.posicao_do_osso("hand.R")
		plantar(baixo, mao.lerp(dona.global_position + Vector3.UP * 1.5, 0.35 * (1.0 - k))))
	dona.tocar(&"escola/mao_no_ceu", 0.3)
	# a câmera sobe pela mão até o céu
	var mao0: Vector3 = dona.posicao_do_osso("hand.R")
	_tocar_som(SOM_TROVAO, -10.0, 0.7)
	await fase(2.0, func(k: float) -> void:
		var e := suave(k)
		plantar(baixo + Vector3.UP * (e * 1.2), mao0.lerp(mao0 + Vector3.UP * 45.0, e)))


# ============================================================ 4) o raio

func _o_raio() -> void:
	var de := Vector3(8.0, 3.2, 41.0)
	var olhar := QUADRA + Vector3.UP * 7.0
	plantar(de, olhar)
	await esperar(0.35)
	if not vale():
		return
	_raio(QUADRA + Vector3(1.5, 70.0, -2.0), QUADRA)
	clarao(1.0, 0.9)
	_tocar_som(SOM_TROVAO, 4.0, 1.0)
	GlobalUtils.shake_camera(1.0, 0.45)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.8)
	_sumir(dona)
	_sumir(jonny)
	# daqui em diante a escola é a escura, a luta é real e o amuleto vale
	Eventos.concluir(Eventos.CAP1_ESCOLA_TRANSFORMADA, false)
	SaveManager.amuleto_equipado = true
	SaveManager.current_mp = maxf(SaveManager.current_mp, SaveManager.max_mp * 0.5)
	SaveManager.save_game()
	versoes.transformar(QUADRA, 10.0)
	await esperar(1.4)


func _sumir(ator: Node3D) -> void:
	if not is_instance_valid(ator):
		return
	TELEPORTE.criar(ator.get_parent(), ator.global_position, 1.0, false)
	_tocar_som(SOM_SUMIR, -2.0, 1.0)
	if "dissolver" in ator:
		var t := create_tween()
		t.tween_property(ator, "dissolver", 1.0, 0.5)
		t.tween_callback(func() -> void: ator.visible = false)
	else:
		ator.visible = false


## O raio: uma linha quebrada do céu ao chão, em segmentos acesos, que pisca e some.
func _raio(de: Vector3, ate: Vector3) -> void:
	var raiz := Node3D.new()
	cena.add_child(raiz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.86, 0.92, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.82, 1.0)
	mat.emission_energy_multiplier = 8.0
	var pontos: Array[Vector3] = [de]
	var n := 16
	for i in range(1, n):
		var k := float(i) / n
		var p := de.lerp(ate, k)
		p += Vector3(randf_range(-1.6, 1.6), 0.0, randf_range(-1.6, 1.6)) * (1.0 - k * 0.7)
		pontos.append(p)
	pontos.append(ate)
	for i in range(pontos.size() - 1):
		var a: Vector3 = pontos[i]
		var b: Vector3 = pontos[i + 1]
		var seg := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.16, a.distance_to(b), 0.16)
		caixa.material = mat
		seg.mesh = caixa
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(seg)
		seg.global_position = (a + b) * 0.5
		var eixo := (b - a).normalized()
		seg.global_basis = Basis(Quaternion(Vector3.UP, eixo))
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.8, 0.86, 1.0)
	luz.light_energy = 14.0
	luz.omni_range = 40.0
	raiz.add_child(luz)
	luz.global_position = ate + Vector3.UP * 3.0
	_nuvem(ate + Vector3.UP * 0.5, 3.5)
	var t := create_tween()
	t.tween_property(raiz, "visible", false, 0.05).set_delay(0.12)
	t.tween_property(raiz, "visible", true, 0.05)
	t.tween_property(luz, "light_energy", 0.0, 0.5)
	t.tween_callback(raiz.queue_free)


func _nuvem(pos: Vector3, tamanho: float) -> void:
	Realidade.nuvem(cena, pos, tamanho, false)


# ============================================================ 5) a escola escurece

## Planos amarrados ao raio da onda: cada um começa quando ela está chegando
## no lugar dele. [raio em que entra, de, olhando, até, olhando]
const PLANOS_DA_ONDA := [
	[0.0, Vector3(4.0, 7.5, 48.0), QUADRA + Vector3.UP, Vector3(6.0, 8.5, 44.0), QUADRA + Vector3(4, 1, 0)],
	[10.0, Vector3(4.0, 1.7, 12.9), Vector3(40.0, 1.6, 12.9), Vector3(9.0, 1.7, 12.9), Vector3(40.0, 1.5, 12.9)],
	[30.0, Vector3(47.5, 2.4, 33.5), Vector3(55.0, 1.0, 47.0), Vector3(48.5, 2.3, 34.5), Vector3(55.5, 0.9, 47.5)],
	[40.0, Vector3(46.0, 1.7, 54.4), Vector3(58.2, 1.3, 54.5), Vector3(50.0, 1.6, 54.4), Vector3(58.2, 1.2, 54.5)],
]


func _a_escola_escurece() -> void:
	for i in PLANOS_DA_ONDA.size():
		var p: Array = PLANOS_DA_ONDA[i]
		# espera a onda chegar perto do lugar deste plano
		while vale() and versoes.raio_onda < float(p[0]):
			_some_quem_a_onda_pegou()
			await get_tree().process_frame
		if not vale():
			return
		await plano(p[1], p[2], p[3], p[4], 2.4, func(_k: float) -> void:
			_some_quem_a_onda_pegou())
	# o resto dos adultos (os que estão longe) some de vez
	for a in adultos:
		if is_instance_valid(a):
			a.queue_free()


func _some_quem_a_onda_pegou() -> void:
	for a in adultos:
		if not is_instance_valid(a) or not a.visible:
			continue
		var d := Vector2(a.global_position.x - QUADRA.x, a.global_position.z - QUADRA.z).length()
		if d <= versoes.raio_onda:
			_nuvem(a.global_position + Vector3.UP, 1.3)
			a.visible = false
			a.process_mode = Node.PROCESS_MODE_DISABLED


# ============================================================ 6) o Grizzolito

func _o_grizzolito() -> void:
	if not is_instance_valid(grizzolito):
		return
	# o Maycow vira pro canto de onde ele vem
	var d := CANTO - player.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	grizzolito.global_position = Vector3(CANTO.x, _chao(CANTO) + 0.1, CANTO.z)
	var para := player.global_position - CANTO
	grizzolito.rotation.y = atan2(para.x, para.z)
	grizzolito.visible = true
	_nuvem(CANTO + Vector3.UP, 2.6)
	_tocar_som(SOM_SUMIR, 0.0, 0.6)
	var anim := grizzolito.get("_anim") as AnimationPlayer
	if anim:
		anim.play(&"andar")
	var frente := Vector3(sin(grizzolito.rotation.y), 0.0, cos(grizzolito.rotation.y))
	var de := CANTO + frente * 4.0 + Vector3(-1.6, 1.0, 0.0)
	await fase(3.6, func(k: float) -> void:
		grizzolito.global_position += frente * 1.25 * get_process_delta_time()
		var peito: Vector3 = grizzolito.global_position + Vector3.UP * 1.5
		plantar(de + frente * (k * 1.5), peito))
	if not vale():
		return
	# por cima do ombro dele: o Maycow lá no meio da quadra
	var costas := grizzolito.global_position - frente * 1.6 + Vector3.UP * 2.0 \
		+ Vector3(-frente.z, 0.0, frente.x) * 0.7
	await plano(costas, player.global_position + Vector3.UP * 0.8,
		costas + frente * 0.6, player.global_position + Vector3.UP * 0.8, 2.0,
		func(_k: float) -> void:
			grizzolito.global_position += frente * 1.25 * get_process_delta_time())


# ============================================================ peças

func _chao(p: Vector3) -> float:
	var espaco := cena.get_world_3d().direct_space_state
	var c := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 4.0, 2)
	var r := espaco.intersect_ray(c)
	return r.position.y if r else p.y


func _tocar_som(caminho: String, volume: float, tom: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.volume_db = volume
	s.pitch_scale = tom
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
