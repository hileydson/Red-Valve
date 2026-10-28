extends Node

## O INTERLÚDIO NO INFERNO 2 da cutscene da oficina (prólogo).
##
## Na oficina, a porta red valve abre, o Husk estica a mão, pega o Maycow pelo
## pescoço e o arrasta pra dentro dela (`agarrao_red_valve.gd`). A viagem
## (`viagem_portal.gd`) traz os dois pro anel de chegada do inferno 2 com o
## ponto "cutscene_oficina", e o `inferno_2.gd` roda isto em vez da chegada
## normal:
##
##  1. o Husk SALTA do anel com o Maycow pendurado pelo pescoço, cai pesado
##     (quase ajoelha), levanta e ruge na cara dele, de perfil;
##  2. agacha, toma impulso e arremessa ele pro alto; uma GÁRGULA passa e ele
##     se agarra nos pés dela;
##  3. ela voa pelo mapa (fenda, mirante, cascata, forja, garganta, agulha) e,
##     cortando o voo em CLARÕES, o anel de chegada sugando inimigos — eles
##     estão escapando pro mundo real. A volta de cada clarão já entra com ela
##     no meio do voo;
##  4. ela volta e atira o Maycow no anel; a viagem leva de volta pra oficina
##     (ponto "cutscene_volta"), que segue do Maycow caindo no chão.
##
## Os atores são os .glb crus (visual, sem IA); a pose de agarrar, pendurar e
## espernear é `pose_apontada.gd`, que os rigs não têm clipe pra isso. O corpo
## do Husk (cair, agachar, levantar) é o clipe de arremesso percorrido na mão. Nada
## aqui grava jogo: a cena não salva quando o ponto começa com "cutscene_"
## (ver `cenario_aberto.gd`). Segurar o pular volta pra oficina direto na luta.

const ViagemPortal := preload("res://scripts/systems/viagem_portal.gd")
const PoseApontada := preload("res://scripts/cutscenes/pose_apontada.gd")
const HUSK := "res://assets/3d_model/enemies/the-cobalt-husker.glb"
const MAYCOW := "res://assets/3d_model/player/Maycow Lopes/maycow_normal/maycow_normal_rigged.glb"
const GARGULA := "res://scenes/effects/fire_gargoyle.tscn"
const OFICINA := "res://scenes/stages/prolog/oficina_jimmy.tscn"
const FUGITIVOS := [
	"res://assets/3d_model/enemies/zombie.glb",
	"res://assets/3d_model/enemies/the-cobalt-husker.glb",
	"res://assets/3d_model/enemies/zombie_2.glb",
	"res://assets/3d_model/enemies/the_anti_lopes.glb",
	"res://assets/3d_model/enemies/zombie_3.glb",
]
const SOM_ROSNADO := "res://assets/sounds/enemies/growl_1.mp3"
const SOM_DOR := "res://assets/sounds/episodios/pain.mp3"
const SOM_SOPRO := "res://assets/sounds/player/dash_effect.mp3"
const SOM_GRITO := "res://assets/sounds/igreja/rugido_monstro.ogg"
const SOM_BAQUE := "res://assets/sounds/common/explosao.mp3"

## Por onde a gárgula passa, em ordem (marcadores `areas/*` da cena). Entre um
## trecho e outro corta um clarão: o voo pode pular de um lugar pro outro.
const ROTEIRO := [["area_2_fenda", "area_3_mirante"], ["area_4_cascata", "area_5_forja"],
	["area_7_garganta", "area_9_agulha"]]
## Quantos inimigos atravessam o anel em cada clarão.
const FUGAS := [2, 3, 3, 5]
## A frente VISÍVEL dos .glb Meshy é o +Z da raiz.
const SINAL_FRENTE := 1.0
## O Husk cru é um bicho curvado de ~1,4 m; a cena de inimigo dele o aumenta
## assim (the_cobalt_husker.tscn), e é desse tamanho que ele ergue um homem.
const ESCALA_HUSK := 1.6
## O corpo do Husk sai do clipe de agarrar e arremessar (o braço direito é a
## pose): de pé, agachado quase de joelhos, e de pé de novo. São tempos do
## clipe, que a cutscene percorre na mão.
const CLIPE_CORPO := "Female_Crouch_Pick_Throw_Forward"
const CORPO_EM_PE := 0.75
const CORPO_AGACHADO := 1.95
const CORPO_LEVANTADO := 2.98
## De pé SEGURANDO o Maycow (o cara a cara): o começo do soco no chão, firme,
## pernas abertas e plantadas. O "de pé" do clipe de arremesso é um corpo
## torcido de pernas cruzadas — servia de passagem, não de pose parada.
const CLIPE_FIRME := "Charged_Ground_Slam"
## Quanto além do pulso fica a palma da garra, em fração do antebraço: o osso
## da mão termina no pulso, e pendurar ali deixava o Maycow no meio do braço.
const PALMA := 0.5

var cena: Node3D
var cam: Camera3D
var husk: Node3D
var pose_husk
var maycow: Node3D
var pose_maycow
var gargula: Node3D
## Luz de recorte que anda com o Husk (o azul-escuro dele some no vermelho) e
## a luz de frente, do lado da câmera.
var _recorte: OmniLight3D
var _chave: OmniLight3D
var _pes_gargula: Array[Node] = []

var centro: Vector3
var frente: Vector3
var lado: Vector3
var piso: float
var _clarao: ColorRect
var _pulando: bool = false
var _t: float = 0.0


func rodar(dono: Node3D) -> void:
	cena = dono
	_preparar()
	await _sair_do_anel()
	if _vale():
		await _arremesso()
	if _vale():
		await _voo()
	if _vale():
		await _volta_ao_anel()


func _process(delta: float) -> void:
	_t += delta


# ============================================================ 1) do anel

func _sair_do_anel() -> void:
	husk = _ator(HUSK)
	pose_husk = _pose(husk)
	maycow = _ator(MAYCOW)
	pose_maycow = _pose(maycow)
	_corpo(CORPO_EM_PE)
	_animar(maycow, "Long_Breathe_and_Look_Around")
	husk.scale = Vector3.ONE * ESCALA_HUSK
	var pouso := Vector3(centro.x, piso, centro.z) + frente * 4.5
	# a borda de baixo do redemoinho fica ~1,5 m acima do tampo: ele salta dali
	var boca := Vector3(centro.x, piso + 1.6, centro.z) + frente * 0.3
	_virar(husk, frente)
	_virar(maycow, -frente)
	husk.global_position = boca
	husk.visible = false
	maycow.visible = false
	_recorte = _luz(Color(1.0, 0.62, 0.45), 3.5, 8.0)
	_chave = _luz(Color(1.0, 0.8, 0.65), 2.2, 9.0)
	var estouro := _luz(Color(1.0, 0.5, 0.2), 0.0, 18.0)
	estouro.global_position = boca + frente * 1.5 + Vector3.UP * 2.0
	# de lado e de baixo: o salto inteiro de perfil, recortado contra o anel
	# aceso (de frente o Maycow, pendurado na frente dele, tapava o bicho)
	cam.fov = 52.0
	cam.global_position = pouso + frente * 1.6 + lado * 4.4 + Vector3.UP * 0.8
	var mira0 := pouso.lerp(boca, 0.45) + Vector3.UP * 2.0
	cam.look_at(mira0)
	_tocar(SOM_SOPRO, 0.45, 4.0)
	# o anel incha antes de cuspir
	await _fase(0.7, func(k: float) -> void:
		estouro.light_energy = 6.0 * k * k)
	husk.visible = true
	maycow.visible = true
	_piscar_cor(Color(1.0, 0.6, 0.3), 0.45, 0.5)
	_tocar(SOM_ROSNADO, 0.8, 6.0)
	_tocar(SOM_DOR, 1.1, -2.0)
	create_tween().tween_property(estouro, "light_energy", 0.0, 1.2)
	# o SALTO pra fora do anel, com o Maycow pendurado na mão
	await _fase(0.85, func(k: float) -> void:
		husk.global_position = _bezier(boca, boca + frente * 1.2 + Vector3.UP * 1.4,
			pouso + Vector3.UP * 1.6 - frente * 0.4, pouso, k)
		_corpo(lerpf(CORPO_EM_PE, 1.25, k))
		_segurar_pelo_pescoco(1.0)
		_iluminar()
		cam.look_at(mira0.lerp(husk.global_position + Vector3.UP * 2.2, 0.6 * k)))
	# a queda: o chão treme e ele afunda até quase ajoelhar
	_tremer(0.45, 0.16)
	_poeira(pouso)
	_tocar(SOM_BAQUE, 0.5, 0.0)
	GlobalUtils.vibrate_controller(null, 0.9, 0.8, 0.4)
	var mira1 := husk.global_position + Vector3.UP * 2.2
	await _fase(0.35, func(k: float) -> void:
		_corpo(lerpf(1.3, CORPO_AGACHADO, smoothstep(0.0, 1.0, k)))
		_segurar_pelo_pescoco(lerpf(1.0, 0.45, k))
		_iluminar()
		cam.look_at(mira1.lerp(husk.global_position + Vector3.UP * 1.7, k)))
	await _fase(0.9, func(k: float) -> void:
		_corpo(lerpf(CORPO_AGACHADO, CORPO_LEVANTADO, smoothstep(0.0, 1.0, k)))
		_segurar_pelo_pescoco(lerpf(0.45, 1.0, smoothstep(0.0, 1.0, k)))
		_iluminar()
		cam.look_at((husk.global_position + Vector3.UP * 1.7).lerp(mira1, k)))
	await _cara_a_cara()


## Plano médio de lado, na altura dos dois: a garra no pescoço, o Maycow
## agarrado no pulso dele, esperneando, e o bicho rugindo na cara dele.
func _cara_a_cara() -> void:
	var base := husk.global_position
	var f := _frente_de(husk)
	# de perfil, na altura das duas cabeças: o bicho de um lado, o Maycow do outro
	var meio := base + Vector3.UP * 2.2 + f * 0.5
	cam.fov = 48.0
	var de := meio + lado * 3.4 + f * 1.1
	var ate := meio + lado * 2.6 + f * 0.9 + Vector3.UP * 0.1
	_tocar(SOM_ROSNADO, 0.65, 8.0)
	await _fase(2.4, func(k: float) -> void:
		_firme()
		# traz o Maycow pra frente da cara, rugindo
		_segurar_pelo_pescoco(lerpf(1.0, 0.25, smoothstep(0.0, 0.5, k)), 0.0,
			smoothstep(0.1, 0.6, k))
		_iluminar()
		var tremor := Vector3.ZERO
		if k > 0.2 and k < 0.75:
			tremor = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.03
		cam.global_position = de.lerp(ate, smoothstep(0.0, 1.0, k)) + tremor
		var cabeca: Vector3 = pose_husk.osso_no_mundo("Head")
		# a chave vem pra cara dele: o corpo azul-escuro some no vermelho
		_chave.light_energy = 3.0
		_chave.global_position = cabeca.lerp(cam.global_position, 0.45) + Vector3.UP * 0.3
		cam.look_at(cabeca.lerp(pose_maycow.osso_no_mundo("Head"), 0.5)))


## A mão do Husk à frente; o pescoço do Maycow nela, as mãos dele no pulso do
## Husk e as pernas esperneando. `alto` 0..1: quanto o braço sobe. `cara` 0..1:
## quanto a mão vem pra frente do rosto dele (pra rugir na cara do Maycow).
func _segurar_pelo_pescoco(alto: float, atras: float = 0.0, cara: float = 0.0) -> void:
	var base := husk.global_position
	var f := _frente_de(husk)
	var mao := base + Vector3.UP * lerpf(2.3, 3.0, alto) + f * lerpf(1.3, 0.85, alto) - f * atras
	mao = mao.lerp(base + Vector3.UP * 2.25 + f * 0.95, cara)
	pose_husk.mirar("braco", ["RightArm", "RightForeArm"], "RightHand", mao)
	var punho: Vector3 = pose_husk.ponta_mirada("braco")
	var ombro: Vector3 = pose_husk.osso_no_mundo("RightArm")
	var ao_longo := (punho - ombro).normalized()
	# o pescoço vai na PALMA da garra, um palmo além do pulso
	var palma: Vector3 = punho + ao_longo * pose_husk.segmento("braco", 1) * PALMA
	_pendurar(palma)
	# as duas mãos dele fecham no pulso do Husk, logo atrás da garra
	var de_lado := ao_longo.cross(Vector3.UP).normalized()
	var pulso := punho - ao_longo * 0.04
	_maos_em(pulso + de_lado * 0.07, pulso - de_lado * 0.07)
	_espernear(1.0)


## As mãos do Maycow em dois pontos, cotovelos dobrando pra fora e pra baixo.
func _maos_em(esquerda: Vector3, direita: Vector3) -> void:
	var peito: Vector3 = pose_maycow.osso_no_mundo("Spine02")
	var oe: Vector3 = pose_maycow.osso_no_mundo("LeftArm")
	var od: Vector3 = pose_maycow.osso_no_mundo("RightArm")
	# cada mão vai pro ponto do lado dela
	if esquerda.distance_to(oe) + direita.distance_to(od) > esquerda.distance_to(od) + direita.distance_to(oe):
		var troca := esquerda
		esquerda = direita
		direita = troca
	var baixo := -maycow.global_basis.y.normalized()
	pose_maycow.mirar("braco_e", ["LeftArm", "LeftForeArm"], "LeftHand", esquerda, 1.0,
		(oe - peito).normalized() + baixo)
	pose_maycow.mirar("braco_d", ["RightArm", "RightForeArm"], "RightHand", direita, 1.0,
		(od - peito).normalized() + baixo)


func _pendurar(ponto: Vector3) -> void:
	var pescoco: Vector3 = pose_maycow.osso_no_mundo("neck")
	maycow.global_position += ponto - pescoco - Vector3.UP * 0.08


## Pernas chutando no ar, joelhos pra frente (do corpo, não do mundo: no
## arremesso ele gira). O lado de cada pé sai das próprias coxas — um lado
## deduzido da frente do modelo trocava os pés e as pernas se cruzavam.
func _espernear(forca: float) -> void:
	var quadril: Vector3 = pose_maycow.osso_no_mundo("Hips")
	var f := _frente_de(maycow)
	var baixo := -maycow.global_basis.y.normalized()
	var l: Vector3 = pose_maycow.osso_no_mundo("LeftUpLeg") - pose_maycow.osso_no_mundo("RightUpLeg")
	l = (l - baixo * l.dot(baixo)).normalized() if l.length_squared() > 0.0001 else f.cross(baixo).normalized()
	for s: float in [1.0, -1.0]:
		var chute := sin(_t * 9.0 + (0.0 if s > 0.0 else PI)) * forca
		var pe := quadril + baixo * (0.82 - 0.2 * maxf(chute, 0.0)) + f * (0.08 + 0.32 * chute) + l * s * 0.17
		var nome := "LeftUpLeg" if s > 0.0 else "RightUpLeg"
		var perna := "LeftLeg" if s > 0.0 else "RightLeg"
		var tornozelo := "LeftFoot" if s > 0.0 else "RightFoot"
		pose_maycow.mirar("perna_%d" % int(s), [nome, perna], tornozelo, pe, 1.0, f)


# ============================================================ 2) arremesso

func _arremesso() -> void:
	var base := husk.global_position
	var f := _frente_de(husk)
	cam.global_position = base + frente * 4.2 - lado * 2.4 + Vector3.UP * 0.5
	cam.look_at(base + Vector3.UP * 2.4)
	cam.fov = 60.0
	# toma impulso: agacha com o braço lá atrás...
	await _fase(0.6, func(k: float) -> void:
		var e := smoothstep(0.0, 1.0, k)
		_corpo(lerpf(1.3, CORPO_AGACHADO, e))
		_segurar_pelo_pescoco(lerpf(1.0, 0.1, e), 0.9 * e)
		_iluminar()
		cam.look_at(maycow.global_position + Vector3.UP * 1.2))
	_tocar(SOM_ROSNADO, 1.15, 6.0)
	_tocar(SOM_SOPRO, 0.7, 2.0)
	if is_instance_valid(_recorte):
		create_tween().tween_property(_recorte, "light_energy", 0.0, 1.2)
	GlobalUtils.vibrate_controller(null, 0.7, 0.7, 0.4)
	# ...e LEVANTA de uma vez, largando ele lá em cima: o Maycow sobe girando
	var solta := maycow.global_position
	var apice := base + Vector3.UP * 17.0 + f * 7.0
	gargula = (load(GARGULA) as PackedScene).instantiate() as Node3D
	cena.add_child(gargula)
	var g0 := apice + lado * 46.0 + Vector3.UP * 9.0 - frente * 8.0
	gargula.voo_dirigido_iniciar(g0, apice)
	var estado := {"gritou": false, "cortou": false}
	var giro0 := maycow.rotation
	var fov0 := cam.fov
	# depois do arremesso a câmera corta pro alto: o Maycow sobe pro quadro e a
	# gárgula entra de lado e o pega (do chão, ele virava um ponto no céu)
	var no_ar := apice - f * 9.0 + lado * 6.0 + Vector3.UP * 0.5
	await _fase(1.9, func(k: float) -> void:
		var e := 1.0 - pow(1.0 - k, 2.4)
		_corpo(lerpf(CORPO_AGACHADO, CORPO_LEVANTADO, smoothstep(0.0, 0.2, k)))
		var voando := _bezier(solta, solta + Vector3.UP * 7.0, apice - Vector3.UP * 1.0, apice, e)
		var giro := smoothstep(0.0, 0.85, k) * (1.0 - smoothstep(0.85, 1.0, k))
		maycow.rotation = giro0 + Vector3(e * TAU * 1.1 * giro, 0.0, sin(e * 5.0) * 0.4 * giro)
		maycow.global_position = voando
		_debater()
		_segurar_braco_do_husk(lerpf(1.0, 0.0, smoothstep(0.1, 0.4, k)))
		var pg := _bezier(g0, g0 - lado * 12.0, apice + lado * 10.0 + Vector3.UP * 4.0, apice + Vector3.UP * 2.6, smoothstep(0.15, 1.0, k))
		gargula.voo_dirigido_ir(pg, 1.0)
		# a gárgula chega e ele se agarra nos pés dela
		if k > 0.86:
			maycow.rotation = Vector3(0.0, maycow.rotation.y, 0.0)
			_nas_garras(smoothstep(0.86, 1.0, k))
		if not estado.gritou and k > 0.55:
			estado.gritou = true
			_tocar(SOM_GRITO, 1.4, 4.0)
		if k < 0.32:
			cam.look_at(maycow.global_position)
			cam.fov = lerpf(fov0, fov0 + 14.0, e)
		else:
			if not estado.cortou:
				estado.cortou = true
				cam.fov = 52.0
				cam.global_position = no_ar
			_desfoque(cam.global_position.distance_to(maycow.global_position))
			_chave.global_position = maycow.global_position.lerp(cam.global_position, 0.4)
			_chave.light_energy = 2.0
			cam.look_at(maycow.global_position.lerp(pg, 0.3) + Vector3.UP * 0.5))
	maycow.rotation = Vector3(0.0, maycow.rotation.y, 0.0)
	_tremer(0.35, 0.08)
	GlobalUtils.vibrate_controller(null, 0.8, 0.6, 0.5)


## O braço que arremessou fica lá em cima, aberto, e depois volta pro clipe.
func _segurar_braco_do_husk(peso: float) -> void:
	var f := _frente_de(husk)
	pose_husk.mirar("braco", ["RightArm", "RightForeArm"], "RightHand",
		husk.global_position + Vector3.UP * 3.6 + f * 0.4, peso)


## Solto no ar: braços abertos se debatendo, pernas chutando.
func _debater() -> void:
	var peito: Vector3 = pose_maycow.osso_no_mundo("Spine02")
	var f := _frente_de(maycow)
	var cima := maycow.global_basis.y.normalized()
	var l := cima.cross(f).normalized()
	for s: float in [1.0, -1.0]:
		var bate := sin(_t * 11.0 + (0.0 if s > 0.0 else 1.7)) * 0.35
		var mao := peito + l * s * 0.55 + cima * (0.35 + bate) + f * 0.15
		var polo := l * s - cima * 0.5
		pose_maycow.mirar("braco_e" if s > 0.0 else "braco_d",
			["LeftArm", "LeftForeArm"] if s > 0.0 else ["RightArm", "RightForeArm"],
			"LeftHand" if s > 0.0 else "RightHand", mao, 1.0, polo)
	_espernear(1.2)


# ============================================================ 3) o voo

## As garras (os pés) da gárgula no mundo. Ela é montada por código, então os
## pés são as duas peças "foot" do corpo, inclinadas com o voo. Só a primeira
## guarda o nome (a segunda ganha um nome gerado): acha as duas pela malha.
func _garras() -> Array[Vector3]:
	var pes: Array[Vector3] = []
	if _pes_gargula.is_empty():
		for n in gargula.find_children("*", "MeshInstance3D", true, false):
			var c := (n as MeshInstance3D).mesh as CylinderMesh
			if c and is_equal_approx(c.height, 0.14) and is_equal_approx(c.top_radius, 0.12):
				_pes_gargula.append(n)
	for p in _pes_gargula:
		if is_instance_valid(p):
			pes.append((p as Node3D).global_transform * Vector3(0.0, -0.05, 0.0))
	if pes.size() < 2:
		var g := gargula.global_position - Vector3.UP * 0.2
		pes = [g + lado * 0.3, g - lado * 0.3]
	return pes


## Pendura o Maycow nas garras da gárgula: cada mão num pé dela, os braços
## quase esticados, ele colado embaixo do corpo. `peso` < 1 puxa ele pra lá.
func _nas_garras(peso: float = 1.0) -> void:
	var pes := _garras()
	var f := _frente_de(gargula, -1.0)
	_virar(maycow, f)
	var meio := (pes[0] + pes[1]) * 0.5
	var ombros: Vector3 = (pose_maycow.osso_no_mundo("LeftArm") + pose_maycow.osso_no_mundo("RightArm")) * 0.5
	var braco: float = pose_maycow.comprimento("braco_e")
	if braco < 0.1:
		braco = 0.55
	var quer := maycow.global_position + (meio - Vector3.UP * braco * 0.9) - ombros
	maycow.global_position = maycow.global_position.lerp(quer, peso)
	_maos_em(pes[0], pes[1])
	_espernear(0.7)
	# o Maycow, escuro, sumia embaixo do fogo da gárgula: luz de frente nele
	if is_instance_valid(_chave):
		_chave.light_energy = 2.0
		_chave.global_position = maycow.global_position.lerp(cam.global_position, 0.4) + Vector3.UP * 0.5


func _voo() -> void:
	var areas := cena.get_node_or_null("areas")
	var anterior := gargula.global_position
	for trecho in ROTEIRO.size():
		var pontos: Array[Vector3] = []
		for nome in ROTEIRO[trecho]:
			var m := areas.get_node_or_null(nome) as Node3D if areas else null
			if m:
				pontos.append(m.global_position + Vector3.UP * 26.0)
		if pontos.size() < 2:
			continue
		# do lugar de antes (ou do primeiro marcador, depois de um clarão) ao
		# segundo, passando pelo primeiro
		var a := anterior if trecho == 0 else pontos[0] - (pontos[1] - pontos[0]).normalized() * 40.0
		var b := pontos[0]
		var c := pontos[1]
		if trecho > 0:
			gargula.voo_dirigido_iniciar(a, b)
		var dur := clampf((a.distance_to(b) + b.distance_to(c) * 0.5) / 26.0, 3.0, 5.0)
		await _trecho_de_voo(a, b, c, dur, 1.0 if trecho % 2 == 0 else -1.0, trecho > 0)
		if not _vale():
			return
		anterior = gargula.global_position
		await _clarao_de_fuga(FUGAS[trecho])
		if not _vale():
			return


## Um trecho do voo com a câmera colada. `depois_do_clarao`: a tela está
## branca; o trecho já entra com a gárgula no meio do voo (a câmera assentada
## nela) e só então o branco sai — senão a volta parecia ela começando a voar.
func _trecho_de_voo(a: Vector3, b: Vector3, c: Vector3, dur: float, lado_cam: float, depois_do_clarao: bool) -> void:
	var k0 := 0.12 if depois_do_clarao else 0.0
	var dir := (c - a).normalized()
	var l := Vector3(-dir.z, 0.0, dir.x) * lado_cam
	var estado := {"pos": Vector3.ZERO, "primeiro": true}
	var passo := func(k: float) -> void:
		var kk := lerpf(k0, 1.0, k)
		var pg := _bezier(a, b, b.lerp(c, 0.5), c.lerp(b, 0.25), kk)
		gargula.voo_dirigido_ir(pg, 0.6 + 0.4 * sin(_t * 1.7))
		_nas_garras()
		var quer := pg - dir * 9.5 + l * 5.5 + Vector3.UP * 1.2
		estado.pos = quer if estado.primeiro else (estado.pos as Vector3).lerp(quer, 0.3)
		cam.global_position = estado.pos
		cam.look_at(pg.lerp(maycow.global_position, 0.35) + dir * 3.0)
		_desfoque(cam.global_position.distance_to(maycow.global_position))
		if estado.primeiro:
			estado.primeiro = false
			if depois_do_clarao:
				_piscar_saida(0.2)
	await _fase(dur, passo)


# ============================================================ os clarões

## Corta pro anel de chegada: inimigos correm e são sugados pra dentro dele —
## estão fugindo pro mundo real. Clarão branco na entrada e na saída; a saída
## fica BRANCA, e quem volta pra gárgula tira o branco já com ela voando.
func _clarao_de_fuga(quantos: int) -> void:
	await _piscar(0.08)
	_desfoque(0.0)
	var pe := Vector3(centro.x, piso, centro.z)
	var l := lado if randf() < 0.5 else -lado
	cam.global_position = pe + frente * 19.0 + l * 3.0 + Vector3.UP * 1.7
	cam.look_at(pe + frente * 5.0 + Vector3.UP * 3.0)
	var fov_volta := cam.fov
	cam.fov = 64.0
	var fugindo: Array[Dictionary] = []
	for i in quantos:
		var f := _ator(FUGITIVOS[(i + quantos) % FUGITIVOS.size()])
		var ini := pe + frente * randf_range(8.0, 13.0) + lado * randf_range(-4.0, 4.0)
		f.global_position = ini
		_virar(f, (centro - ini) * Vector3(1, 0, 1))
		_animar(f, "Running", randf_range(1.1, 1.4))
		fugindo.append({"no": f, "ini": ini, "atraso": randf_range(0.0, 0.35), "giro": f.rotation.y})
	_tocar(SOM_SOPRO, randf_range(0.5, 0.7), 2.0)
	await _piscar_saida(0.12)
	await _fase(1.35, func(k: float) -> void:
		for d in fugindo:
			var n: Node3D = d.no
			var kk := clampf((k - float(d.atraso)) / (1.0 - float(d.atraso)), 0.0, 1.0)
			var e := kk * kk
			var ini: Vector3 = d.ini
			n.global_position = _bezier(ini, ini + Vector3.UP * 1.5, centro + frente * 4.0, centro, e)
			n.rotation.y = float(d.giro) + e * TAU * 2.0
			var some := 1.0 - smoothstep(0.55, 1.0, kk) * 0.92
			n.scale = Vector3(1.0 - 0.35 * e, 1.0 + 0.8 * e, 1.0 - 0.35 * e) * some)
	_tocar(SOM_ROSNADO, randf_range(0.7, 0.9), 0.0)
	await _piscar(0.08)
	for d in fugindo:
		(d.no as Node3D).queue_free()
	cam.fov = fov_volta


# ============================================================ 4) a volta

func _volta_ao_anel() -> void:
	var a := centro + frente * 70.0 + Vector3.UP * 6.0 + lado * 20.0
	var b := centro + frente * 22.0 + Vector3.UP * 1.0
	var solta_em := centro + frente * 9.0
	# começa já no ar (a tela ainda está branca do último clarão)
	var k0 := 0.1
	gargula.voo_dirigido_iniciar(_bezier(a, a.lerp(b, 0.4), b, solta_em, k0), b)
	var estado := {"pos": Vector3.ZERO, "primeiro": true}
	await _fase(2.4, func(k: float) -> void:
		var pg := _bezier(a, a.lerp(b, 0.4), b, solta_em, lerpf(k0, 1.0, k))
		gargula.voo_dirigido_ir(pg, 1.0)
		_nas_garras()
		var quer := pg + frente * 10.0 + lado * 4.5 + Vector3.UP * 1.2
		estado.pos = quer if estado.primeiro else (estado.pos as Vector3).lerp(quer, 0.3)
		cam.global_position = estado.pos
		cam.look_at(centro.lerp(maycow.global_position, 0.5))
		_desfoque(cam.global_position.distance_to(maycow.global_position))
		if estado.primeiro:
			estado.primeiro = false
			_piscar_saida(0.2))
	_desfoque(0.0)
	# larga: o Maycow é atirado no vórtice e a gárgula arremete pra cima
	_tocar(SOM_GRITO, 1.5, 4.0)
	var p0 := maycow.global_position
	var g := gargula.global_position
	gargula.voo_dirigido_fugir(g + Vector3.UP * 12.0 - frente * 6.0, g + Vector3.UP * 60.0 + lado * 80.0, 3.0)
	var estado2 := {"foi": false}
	var giro0 := maycow.rotation
	await _fase(1.6, func(k: float) -> void:
		var e := k * k
		maycow.global_position = _bezier(p0, p0 - frente * 2.0 + Vector3.UP * 1.0, centro + frente * 2.5, centro, e)
		maycow.rotation = giro0 + Vector3(e * TAU, e * TAU * 1.5, 0.0)
		maycow.scale = Vector3.ONE * (1.0 - smoothstep(0.5, 1.0, k) * 0.9)
		_debater()
		cam.look_at(maycow.global_position.lerp(centro, 0.3))
		if not estado2.foi and k > 0.45:
			estado2.foi = true
			ViagemPortal.viajar(get_tree(), OFICINA, "cutscene_volta", 2.0, 1.4))


# ============================================================ entra/sai

func _preparar() -> void:
	GlobalEvents.in_cutscene = true
	var player := cena.get_node_or_null("Player") as CharacterBody3D
	if player:
		if player.has_method("cutscene_set_player_control"):
			player.cutscene_set_player_control(false)
			player.cutscene_set_hud_enabled(false)
			player.cutscene_set_camera_current(false)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
	var minimapa := cena.get_node_or_null("minimapa")
	if minimapa and "visible" in minimapa:
		minimapa.visible = false
	var inimigos := cena.get_node_or_null("enemies")
	if inimigos:
		inimigos.process_mode = Node.PROCESS_MODE_DISABLED
		inimigos.visible = false
	var portal := cena.get_node_or_null("portal_entrada")
	if portal:
		portal.set("bloqueado", true)
	var anel := cena.get_node("redemoinho_chegada") as Node3D
	centro = anel.global_position
	var spawn := cena.get_node_or_null("spawn_entrada") as Node3D
	frente = (spawn.global_position - centro) if spawn else anel.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	lado = Vector3(-frente.z, 0.0, frente.x)
	# o anel tem o centro 14 m acima do tampo da plataforma (gerar_inferno_2)
	piso = centro.y - 14.0
	cam = Camera3D.new()
	cam.name = "camera_interludio"
	cam.far = 4000.0
	cam.fov = 62.0
	cena.add_child(cam)
	cam.make_current()
	var camada := CanvasLayer.new()
	camada.layer = 120
	add_child(camada)
	_clarao = ColorRect.new()
	_clarao.color = Color(1.0, 0.96, 0.92, 0.0)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clarao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_clarao)
	var pular := CanvasLayer.new()
	pular.layer = 155
	add_child(pular)
	var ui = load("res://scripts/ui/skip_cutscene_ui.gd").new()
	pular.add_child(ui)
	ui.skipped.connect(_pular)


func _pular() -> void:
	if _pulando:
		return
	_pulando = true
	ViagemPortal.viajar(get_tree(), OFICINA, "cutscene_pular", 0.6, 1.0)


func _vale() -> bool:
	return not _pulando and is_inside_tree() and is_instance_valid(cam)


# ============================================================ peças

func _ator(caminho: String) -> Node3D:
	var a := (load(caminho) as PackedScene).instantiate() as Node3D
	cena.add_child(a)
	return a


## O Husk parado de pé, firme (ver CLIPE_FIRME). Entra sempre num corte de
## câmera: a troca de clipe é seca.
func _firme() -> void:
	var ap := husk.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(CLIPE_FIRME):
		_corpo(CORPO_EM_PE)
		return
	if ap.current_animation != CLIPE_FIRME:
		ap.play(CLIPE_FIRME, 0.0, 0.0)
	ap.seek(0.0, true)


## Põe o corpo do Husk no tempo `t` do clipe de arremesso (parado nele).
func _corpo(t: float) -> void:
	var ap := husk.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(CLIPE_CORPO):
		return
	if ap.current_animation != CLIPE_CORPO:
		ap.play(CLIPE_CORPO, 0.0, 0.0)
	ap.seek(t, true)


func _luz(cor: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.shadow_enabled = false
	cena.add_child(l)
	return l


## As duas luzes andam com o Husk: o recorte atrás dele, do lado OPOSTO ao da
## câmera (desenha a borda contra o fundo), e a chave entre os dois e a câmera.
func _iluminar() -> void:
	var base := husk.global_position
	var f := _frente_de(husk)
	var meio := base + Vector3.UP * 2.2 + f * 0.5
	var lado_cam := signf((cam.global_position - base).dot(lado))
	if is_instance_valid(_recorte):
		_recorte.global_position = base - f * 1.0 - lado * lado_cam * 1.8 + Vector3.UP * 2.8
	if is_instance_valid(_chave):
		_chave.global_position = meio.lerp(cam.global_position, 0.5) + Vector3.UP * 0.6


## Poeira e brasa levantando do chão onde ele cai.
func _poeira(onde: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.9
	p.emission_ring_inner_radius = 0.3
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0.0, -3.0, 0.0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.55, 0.22, 0.12, 0.8), Color(0.2, 0.06, 0.04, 0.0)])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	var bolha := GradientTexture2D.new()
	var gb := Gradient.new()
	gb.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	bolha.gradient = gb
	bolha.fill = GradientTexture2D.FILL_RADIAL
	bolha.fill_from = Vector2(0.5, 0.5)
	bolha.fill_to = Vector2(1.0, 0.5)
	mat.albedo_texture = bolha
	q.material = mat
	p.mesh = q
	cena.add_child(p)
	p.global_position = onde + Vector3.UP * 0.1
	p.emitting = true
	p.finished.connect(p.queue_free)


func _pose(ator: Node3D):
	var sk := ator.find_child("Skeleton3D", true, false) as Skeleton3D
	var p = PoseApontada.new()
	sk.add_child(p)
	return p


## Toca o clipe em laço (sem mexer no `loop_mode` do recurso, que é
## compartilhado com os inimigos de verdade).
func _animar(ator: Node3D, clipe: String, vel: float = 1.0) -> void:
	var ap := ator.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(clipe):
		return
	ap.play(clipe, 0.2, vel)
	ap.animation_finished.connect(func(_n: StringName) -> void:
		if is_instance_valid(ap):
			ap.play(clipe, 0.0, vel))


func _virar(ator: Node3D, dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized() * SINAL_FRENTE
	ator.rotation.y = atan2(dir.x, dir.z)


func _frente_de(ator: Node3D, sinal: float = SINAL_FRENTE) -> Vector3:
	var z := ator.global_basis.z * sinal
	z.y = 0.0
	return z.normalized() if z.length_squared() > 0.0001 else frente


## Desfoque leve do que fica atrás do Maycow pendurado (a câmera vem de
## longe, e o fundo borrado dá a distância e a velocidade). `foco` é a
## distância até ele; 0 desliga. Só o desfoque de LONGE: o de perto no mobile
## borra tudo.
func _desfoque(foco: float) -> void:
	if foco <= 0.0:
		cam.attributes = null
		return
	var at := cam.attributes as CameraAttributesPractical
	if at == null:
		at = CameraAttributesPractical.new()
		at.dof_blur_amount = 0.05
		at.dof_blur_far_transition = 30.0
		cam.attributes = at
	at.dof_blur_far_enabled = true
	at.dof_blur_far_distance = foco + 4.0


func _tocar(caminho: String, tom: float, volume: float) -> void:
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.pitch_scale = tom
	s.volume_db = volume
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


func _piscar(dur: float) -> void:
	var t := create_tween()
	t.tween_property(_clarao, "color:a", 1.0, dur)
	await t.finished


## Clarão de uma cor que some sozinho (não espera).
func _piscar_cor(cor: Color, forca: float, dur: float) -> void:
	_clarao.color = Color(cor.r, cor.g, cor.b, forca)
	var t := create_tween()
	t.tween_property(_clarao, "color", Color(1.0, 0.96, 0.92, 0.0), dur)


func _piscar_saida(dur: float) -> void:
	var t := create_tween()
	t.tween_property(_clarao, "color:a", 0.0, dur)
	await t.finished


func _tremer(segundos: float, forca: float) -> void:
	var t := 0.0
	while t < segundos and is_instance_valid(cam) and is_inside_tree():
		await get_tree().process_frame
		if not is_instance_valid(cam):
			return
		t += get_process_delta_time()
		var f := (1.0 - t / segundos) * forca
		cam.h_offset = randf_range(-1.0, 1.0) * f
		cam.v_offset = randf_range(-1.0, 1.0) * f
	if is_instance_valid(cam):
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _fase(duracao: float, passo: Callable) -> void:
	var t := 0.0
	while t < duracao:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not _vale():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		passo.call(clampf(t / duracao, 0.0, 1.0))


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t
