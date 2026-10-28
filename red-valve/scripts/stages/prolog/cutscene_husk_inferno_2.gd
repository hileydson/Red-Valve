extends Node

## O INTERLÚDIO NO INFERNO 2 da cutscene da oficina (prólogo).
##
## Na oficina, a porta red valve abre, o Husk estica a mão, pega o Maycow pelo
## pescoço e o arrasta pra dentro dela (`agarrao_red_valve.gd`). A viagem
## (`viagem_portal.gd`) traz os dois pro anel de chegada do inferno 2 com o
## ponto "cutscene_oficina", e o `inferno_2.gd` roda isto em vez da chegada
## normal:
##
##  1. o Husk sai do vórtice com o Maycow pendurado pelo pescoço, esperneando;
##  2. arremessa ele pro alto, e uma GÁRGULA passa e agarra no ar;
##  3. ela voa pelo mapa (fenda, mirante, cascata, forja, garganta, agulha) e,
##     cortando o voo em CLARÕES, o anel de chegada sugando inimigos — eles
##     estão escapando pro mundo real;
##  4. ela volta e atira o Maycow no anel; a viagem leva de volta pra oficina
##     (ponto "cutscene_volta"), que segue do Maycow caindo no chão.
##
## Os atores são os .glb crus (visual, sem IA); a pose de agarrar, pendurar e
## espernear é `pose_apontada.gd`, que os rigs não têm clipe pra isso. Nada
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

var cena: Node3D
var cam: Camera3D
var husk: Node3D
var pose_husk
var maycow: Node3D
var pose_maycow
var gargula: Node3D
## Luz de recorte que anda com o Husk (o azul-escuro dele some no vermelho).
var _recorte: OmniLight3D

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
	_animar(husk, "Walking")
	_animar(maycow, "Long_Breathe_and_Look_Around")
	var pouso := Vector3(centro.x, piso, centro.z) + frente * 4.0
	# sai do pé do redemoinho (a borda de baixo fica ~1,5 m acima do tampo)
	var boca := Vector3(centro.x, piso + 2.0, centro.z)
	_virar(husk, frente)
	_virar(maycow, -frente)
	husk.global_position = boca
	husk.scale = Vector3.ONE * 0.3 * ESCALA_HUSK
	_recorte = OmniLight3D.new()
	_recorte.light_color = Color(1.0, 0.62, 0.45)
	_recorte.light_energy = 3.0
	_recorte.omni_range = 7.0
	_recorte.shadow_enabled = false
	cena.add_child(_recorte)
	cam.fov = 55.0
	cam.global_position = pouso + frente * 3.2 + lado * 5.4 + Vector3.UP * 1.7
	cam.look_at(pouso + frente * 0.7 + Vector3.UP * 2.1)
	_tocar(SOM_ROSNADO, 0.85, 4.0)
	await _fase(1.5, func(k: float) -> void:
		var e := 1.0 - pow(1.0 - k, 2.0)
		husk.global_position = _bezier(boca, boca + frente * 1.5 + Vector3.UP * 0.6, pouso + Vector3.UP * 0.8, pouso, e)
		husk.scale = Vector3.ONE * lerpf(0.3, 1.0, smoothstep(0.0, 0.55, k)) * ESCALA_HUSK
		_segurar_pelo_pescoco(1.0)
		cam.look_at(husk.global_position + frente * 0.7 + Vector3.UP * 2.1))
	_tremer(0.3, 0.1)
	# anda dois passos com ele pendurado
	var p0 := husk.global_position
	await _fase(1.7, func(k: float) -> void:
		husk.global_position = p0 + frente * 1.6 * k
		_segurar_pelo_pescoco(1.0)
		cam.look_at(husk.global_position + frente * 0.7 + Vector3.UP * 2.2))
	_tocar(SOM_DOR, 1.0, 0.0)


## A mão do Husk no alto, à frente; o pescoço do Maycow nela, as mãos dele no
## pulso do Husk e as pernas esperneando. `alto` 0..1: quanto o braço sobe.
func _segurar_pelo_pescoco(alto: float, atras: float = 0.0) -> void:
	var base := husk.global_position
	var f := _frente_de(husk)
	var mao := base + Vector3.UP * lerpf(2.3, 3.0, alto) + f * lerpf(1.3, 0.85, alto) - f * atras
	pose_husk.mirar("braco", ["RightArm", "RightForeArm"], "RightHand", mao)
	var na_mao: Vector3 = pose_husk.ponta_mirada("braco")
	if is_instance_valid(_recorte):
		_recorte.global_position = base + f * 1.6 + lado * 1.2 + Vector3.UP * 2.2
	_pendurar(na_mao)
	pose_maycow.mirar("braco_e", ["LeftArm", "LeftForeArm"], "LeftHand", na_mao + Vector3.UP * 0.05)
	pose_maycow.mirar("braco_d", ["RightArm", "RightForeArm"], "RightHand", na_mao - Vector3.UP * 0.05)
	_espernear(1.0)


func _pendurar(ponto: Vector3) -> void:
	var pescoco: Vector3 = pose_maycow.osso_no_mundo("neck")
	maycow.global_position += ponto - pescoco - Vector3.UP * 0.08


func _espernear(forca: float) -> void:
	var quadril: Vector3 = pose_maycow.osso_no_mundo("Hips")
	var f := _frente_de(maycow)
	var l := Vector3(-f.z, 0.0, f.x)
	for s: float in [1.0, -1.0]:
		var chute := sin(_t * 9.0 + (0.0 if s > 0.0 else PI)) * 0.35 * forca
		var pe := quadril - Vector3.UP * 0.95 + f * (0.15 + chute) + l * s * 0.18
		var nome := "LeftUpLeg" if s > 0.0 else "RightUpLeg"
		var perna := "LeftLeg" if s > 0.0 else "RightLeg"
		var tornozelo := "LeftFoot" if s > 0.0 else "RightFoot"
		pose_maycow.mirar("perna_%d" % int(s), [nome, perna], tornozelo, pe)


# ============================================================ 2) arremesso

func _arremesso() -> void:
	var base := husk.global_position
	cam.global_position = base + frente * 4.2 - lado * 2.4 + Vector3.UP * 0.5
	cam.look_at(base + Vector3.UP * 2.4)
	cam.fov = 60.0
	# o braço recua...
	await _fase(0.55, func(k: float) -> void:
		_segurar_pelo_pescoco(lerpf(1.0, 0.55, k), 0.6 * k)
		cam.look_at(maycow.global_position + Vector3.UP * 1.2))
	_tocar(SOM_ROSNADO, 1.15, 6.0)
	_tocar(SOM_SOPRO, 0.7, 2.0)
	if is_instance_valid(_recorte):
		create_tween().tween_property(_recorte, "light_energy", 0.0, 1.2)
	GlobalUtils.vibrate_controller(null, 0.7, 0.7, 0.4)
	# ...e LARGA lá em cima: o Maycow sobe girando
	var solta := maycow.global_position
	var apice := base + Vector3.UP * 17.0 + frente * 7.0
	gargula = (load(GARGULA) as PackedScene).instantiate() as Node3D
	cena.add_child(gargula)
	var g0 := apice + lado * 46.0 + Vector3.UP * 9.0 - frente * 8.0
	gargula.voo_dirigido_iniciar(g0, apice)
	var estado := {"gritou": false}
	var giro0 := maycow.rotation
	var fov0 := cam.fov
	await _fase(1.9, func(k: float) -> void:
		var e := 1.0 - pow(1.0 - k, 2.4)
		maycow.global_position = _bezier(solta, solta + Vector3.UP * 7.0, apice - Vector3.UP * 1.0, apice, e)
		maycow.rotation = giro0 + Vector3(e * TAU * 1.1, 0.0, sin(e * 5.0) * 0.4)
		_debater()
		_segurar_braco_do_husk(lerpf(1.0, 0.0, smoothstep(0.0, 0.3, k)))
		var pg := _bezier(g0, g0 - lado * 12.0, apice + lado * 10.0 + Vector3.UP * 4.0, apice + Vector3.UP * 2.6, smoothstep(0.15, 1.0, k))
		gargula.voo_dirigido_ir(pg, 1.0)
		if not estado.gritou and k > 0.55:
			estado.gritou = true
			_tocar(SOM_GRITO, 1.4, 4.0)
		cam.look_at(maycow.global_position.lerp(pg, 0.25 * smoothstep(0.5, 1.0, k)))
		cam.fov = lerpf(fov0, fov0 + 14.0, e))
	maycow.rotation = Vector3(0.0, maycow.rotation.y, 0.0)
	_tremer(0.35, 0.08)
	GlobalUtils.vibrate_controller(null, 0.8, 0.6, 0.5)


func _segurar_braco_do_husk(peso: float) -> void:
	var f := _frente_de(husk)
	pose_husk.mirar("braco", ["RightArm", "RightForeArm"], "RightHand",
		husk.global_position + Vector3.UP * 3.6 + f * 0.4, peso)


## Solto no ar: braços abertos se debatendo, pernas soltas.
func _debater() -> void:
	var peito: Vector3 = pose_maycow.osso_no_mundo("Spine02")
	var f := _frente_de(maycow)
	var l := Vector3(-f.z, 0.0, f.x)
	var cima := maycow.global_basis.y.normalized()
	for s: float in [1.0, -1.0]:
		var bate := sin(_t * 11.0 + (0.0 if s > 0.0 else 1.7)) * 0.5
		var mao := peito + l * s * 0.8 + cima * (0.5 + bate) + f * 0.2
		pose_maycow.mirar("braco_e" if s > 0.0 else "braco_d",
			["LeftArm", "LeftForeArm"] if s > 0.0 else ["RightArm", "RightForeArm"],
			"LeftHand" if s > 0.0 else "RightHand", mao)
	_espernear(1.2)


# ============================================================ 3) o voo

## Pendura o Maycow nas garras da gárgula: as duas mãos dele pra cima.
func _nas_garras() -> void:
	var garra := gargula.global_position - Vector3.UP * 1.1
	# as mãos, esticadas pra cima, batem na garra: acerta a raiz pelos ombros
	var ombros: Vector3 = (pose_maycow.osso_no_mundo("LeftArm") + pose_maycow.osso_no_mundo("RightArm")) * 0.5
	var braco: float = pose_maycow.comprimento("braco_e")
	maycow.global_position += garra - (ombros + Vector3.UP * (braco if braco > 0.1 else 0.6) * 0.95)
	var f := _frente_de(gargula, -1.0)
	_virar(maycow, f)
	var l := Vector3(-f.z, 0.0, f.x)
	pose_maycow.mirar("braco_e", ["LeftArm", "LeftForeArm"], "LeftHand", garra + l * 0.12 + Vector3.UP * 0.3)
	pose_maycow.mirar("braco_d", ["RightArm", "RightForeArm"], "RightHand", garra - l * 0.12 + Vector3.UP * 0.3)
	_espernear(0.7)


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
		var lado_cam := 1.0 if trecho % 2 == 0 else -1.0
		var suave := {"pos": a - Vector3.UP * 0.0}
		await _fase(dur, func(k: float) -> void:
			var pg := _bezier(a, b, b.lerp(c, 0.5), c.lerp(b, 0.25), k)
			gargula.voo_dirigido_ir(pg, 0.6 + 0.4 * sin(_t * 1.7))
			_nas_garras()
			var dir := (c - a).normalized()
			var l := Vector3(-dir.z, 0.0, dir.x) * lado_cam
			var quer := pg - dir * 5.5 + l * 2.6 + Vector3.UP * 0.6
			suave.pos = (suave.pos as Vector3).lerp(quer, 0.12) if k > 0.02 else quer
			cam.global_position = suave.pos
			cam.look_at(maycow.global_position + Vector3.UP * 1.6 + dir * 3.0))
		if not _vale():
			return
		anterior = gargula.global_position
		await _clarao_de_fuga(FUGAS[trecho])
		if not _vale():
			return


# ============================================================ os clarões

## Corta pro anel de chegada: inimigos correm e são sugados pra dentro dele —
## estão fugindo pro mundo real. Clarão branco na entrada e na saída.
func _clarao_de_fuga(quantos: int) -> void:
	await _piscar(0.08)
	var cam_volta := cam.global_transform
	var fov_volta := cam.fov
	var pe := Vector3(centro.x, piso, centro.z)
	var l := lado if randf() < 0.5 else -lado
	cam.global_position = pe + frente * 19.0 + l * 3.0 + Vector3.UP * 1.7
	cam.look_at(pe + frente * 5.0 + Vector3.UP * 3.0)
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
	cam.global_transform = cam_volta
	cam.fov = fov_volta
	await _piscar_saida(0.15)


# ============================================================ 4) a volta

func _volta_ao_anel() -> void:
	var a := centro + frente * 70.0 + Vector3.UP * 6.0 + lado * 20.0
	var b := centro + frente * 22.0 + Vector3.UP * 1.0
	var solta_em := centro + frente * 9.0
	gargula.voo_dirigido_iniciar(a, b)
	var suave := {"pos": a - frente * 10.0}
	await _fase(2.6, func(k: float) -> void:
		var pg := _bezier(a, a.lerp(b, 0.4), b, solta_em, k)
		gargula.voo_dirigido_ir(pg, 1.0)
		_nas_garras()
		var quer := pg + frente * 6.5 + lado * 2.2 + Vector3.UP * 1.4
		suave.pos = (suave.pos as Vector3).lerp(quer, 0.15) if k > 0.02 else quer
		cam.global_position = suave.pos
		cam.look_at(centro.lerp(maycow.global_position, 0.5)))
	# larga: o Maycow é atirado no vórtice e a gárgula arremete pra cima
	_tocar(SOM_GRITO, 1.5, 4.0)
	var p0 := maycow.global_position
	var g := gargula.global_position
	gargula.voo_dirigido_fugir(g + Vector3.UP * 12.0 - frente * 6.0, g + Vector3.UP * 60.0 + lado * 80.0, 3.0)
	var estado := {"foi": false}
	var giro0 := maycow.rotation
	await _fase(1.6, func(k: float) -> void:
		var e := k * k
		maycow.global_position = _bezier(p0, p0 - frente * 2.0 + Vector3.UP * 1.0, centro + frente * 2.5, centro, e)
		maycow.rotation = giro0 + Vector3(e * TAU, e * TAU * 1.5, 0.0)
		maycow.scale = Vector3.ONE * (1.0 - smoothstep(0.5, 1.0, k) * 0.9)
		_debater()
		cam.look_at(maycow.global_position.lerp(centro, 0.3))
		if not estado.foi and k > 0.45:
			estado.foi = true
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
