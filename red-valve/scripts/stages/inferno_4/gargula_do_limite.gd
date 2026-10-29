extends "res://scripts/stages/battlefield/resgate_gargula.gd"

## A GÁRGULA DO LIMITE (Capítulo 1, inferno 4).
##
## Chegando no portal do FIM, o Maycow ainda é fraco demais para atravessá-lo.
## Uma gárgula de fogo desce do céu, agarra ele, voa por cima do mapa inteiro
## até o portal do COMEÇO e o arremessa lá dentro: ele é cuspido de volta pela
## red valve do calabouço, e lá fala que ainda é fraco demais
## (`porao.gd`, lendo `GlobalEvents.aviso_fraco_no_porao`).
##
## A câmera, as mãos e a gárgula são as do resgate da arena
## (`resgate_gargula.gd`): esta cena só troca o ROTEIRO — ele está de pé no
## chão (não caindo), o voo é longo, e o fim não é uma largada no chão, é a
## viagem pelo portal (`ViagemPortal`), que troca de cena no meio da queda.
##
## Quem chama: `inferno_4.gd`, perto do portal do fim, no Capítulo 1.

const ViagemPortal := preload("res://scripts/systems/viagem_portal.gd")

## A gárgula vem de trás e de cima dele.
const DIST_ENTRADA := 30.0
const ALT_ENTRADA := 16.0
const DUR_CHEGADA := 1.6
## O voo até o portal do começo: velocidade média e os limites de duração.
const VELOCIDADE := 42.0
const DUR_VOO_MIN := 5.0
const DUR_VOO_MAX := 9.0
## Altura de cruzeiro (acima do ponto mais alto das duas pontas) — o mapa tem
## um morro no meio, com a catedral colossal.
const ALT_CRUZEIRO := 38.0
## De onde ela arremessa: na frente do portal do começo, alto.
const ARREMESSO_FRENTE := 14.0
const ARREMESSO_ALTO := 9.0
const DUR_ARREMESSO := 1.5

## Pra onde ele vai (o portal do começo do inferno 4).
var portal: Node3D


func levar(jogador: CharacterBody3D, portal_do_comeco: Node3D) -> void:
	player = jogador
	portal = portal_do_comeco
	GlobalEvents.agarrao_rodando = true
	GlobalEvents.agarrao_id += 1
	GlobalUtils.watchdog_agarrao(30.0, GlobalEvents.agarrao_id)
	_roteiro()


func _roteiro() -> void:
	_entrar_em_cena()
	GlobalUtils.esconder_objetivo()

	var alt_olho := _altura_do_olho()
	var olho := player.global_position + Vector3.UP * alt_olho
	var frente := _frente_do_jogador()
	frente.y = 0.0
	frente = frente.normalized() if frente.length_squared() > 0.001 else Vector3.FORWARD
	# Ela vem de TRÁS dele (do lado do caminho já andado) e de cima.
	var lado := -frente
	var ponto_pega := olho + Vector3.UP * 0.9

	var fp := load(CENA_FP).instantiate() as Node3D
	get_tree().current_scene.add_child(fp)
	var cam_jogo := get_viewport().get_camera_3d()
	var partida := cam_jogo.global_position if is_instance_valid(cam_jogo) \
			else olho + Vector3.UP * 2.0 - frente * 3.0
	fp.plantar(partida, olho + frente * 6.0)
	fp.lente(FOV_TROCA)
	fp.borrar(BORRAO_TROCA)
	fp.assumir_camera()
	fp.tocar(&"idle")
	fp.lente_padrao(DURACAO_MERGULHO)
	fp.borrar(0.0, DURACAO_MERGULHO * 1.25)

	var g0 := ponto_pega + lado * DIST_ENTRADA + Vector3.UP * ALT_ENTRADA
	var gargula := _nascer_gargula(g0, ponto_pega)

	# --- 1) ele ouve, se vira, e ela já está em cima ---
	var g1 := g0 - lado * 10.0 - Vector3.UP * 2.0
	var g2 := ponto_pega + lado * 7.0 + Vector3.UP * 5.0
	var defendeu := false
	await _fase(DUR_CHEGADA, func(k: float) -> void:
		if not is_instance_valid(fp) or not is_instance_valid(gargula):
			return
		var pos_g := _bezier(g0, g1, g2, ponto_pega, k)
		gargula.voo_dirigido_ir(pos_g, lerpf(0.6, 1.0, k))
		var entrada: float = clampf(k * DUR_CHEGADA / DURACAO_MERGULHO, 0.0, 1.0)
		entrada = Tween.interpolate_value(0.0, 1.0, entrada, 1.0,
				Tween.TRANS_CUBIC, Tween.EASE_OUT)
		# primeiro olhando pra frente (o portal do fim), depois virando pra ela
		var mira: Vector3 = (olho + frente * 6.0).lerp(pos_g, smoothstep(0.15, 0.6, k))
		fp.plantar(partida.lerp(olho, entrada), mira)
		if not defendeu and k > 0.6:
			defendeu = true
			fp.tocar(&"defesa", 1.0, 0.16)
			GlobalUtils.vibrate_controller(null, 0.5, 0.5, 0.25))
	if not _vale_continuar(fp):
		_desistir(fp, gargula)
		return

	# --- 2) agarrou ---
	if is_instance_valid(gargula):
		gargula.voo_dirigido_frear()
	fp.tocar(&"agarrado")
	fp.tremer(0.030, 0.6)
	fp.piscar(Color(1.0, 0.62, 0.25), 0.42, 0.02, 0.35)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.5)
	await _fase(DUR_AGARRAO, func(k: float) -> void:
		if not is_instance_valid(fp) or not is_instance_valid(gargula):
			return
		var pos_g: Vector3 = ponto_pega + Vector3.UP * lerpf(0.0, 1.2, k)
		gargula.voo_dirigido_ir(pos_g, 1.0)
		fp.plantar(pos_g - Vector3.UP * PENDURADO - lado * (ARRASTADO * k),
				pos_g + Vector3.UP * 0.9, lerpf(0.14, -0.10, k)))
	if not _vale_continuar(fp):
		_desistir(fp, gargula)
		return

	# --- 3) o voo por cima do mapa, até a frente do portal do começo ---
	var centro: Vector3 = portal.global_position
	var saida_portal: Vector3 = portal.get("frente") if portal.get("frente") is Vector3 else Vector3.BACK
	saida_portal.y = 0.0
	saida_portal = saida_portal.normalized() if saida_portal.length_squared() > 0.001 else Vector3.BACK
	var arremesso := centro + saida_portal * ARREMESSO_FRENTE + Vector3.UP * ARREMESSO_ALTO
	var s0 := ponto_pega + Vector3.UP * 1.2
	var cruzeiro := maxf(s0.y, arremesso.y) + ALT_CRUZEIRO
	var s1 := s0.lerp(arremesso, 0.25)
	s1.y = cruzeiro
	var s2 := s0.lerp(arremesso, 0.8)
	s2.y = cruzeiro
	var dur_voo := clampf(s0.distance_to(arremesso) / VELOCIDADE, DUR_VOO_MIN, DUR_VOO_MAX)
	var anterior := s0
	await _fase(dur_voo, func(k: float) -> void:
		if not is_instance_valid(fp) or not is_instance_valid(gargula):
			return
		var suave: float = Tween.interpolate_value(0.0, 1.0, k, 1.0,
				Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		var pos_g := _bezier(s0, s1, s2, arremesso, suave)
		var rumo := pos_g - anterior
		rumo.y = 0.0
		rumo = rumo.normalized() if rumo.length_squared() > 0.0000001 else -lado
		anterior = pos_g
		gargula.voo_dirigido_ir(pos_g, lerpf(1.0, 0.75, suave))
		var olho_voo := pos_g - Vector3.UP * PENDURADO - rumo * ARRASTADO
		# olha pra ela, depois pra frente, e logo pro portal do começo: o mapa
		# é escuro, e é o brilho do vórtice crescendo que conta pra onde ele vai
		var adiante := olho_voo + rumo * 30.0 - Vector3.UP * 12.0
		var alvo: Vector3 = (pos_g + Vector3.UP * 0.9).lerp(adiante, smoothstep(0.05, 0.25, k))
		alvo = alvo.lerp(centro, smoothstep(0.3, 0.6, k))
		fp.plantar(olho_voo, alvo, sin(k * TAU * 1.6) * 0.10))
	if not _vale_continuar(fp):
		_desistir(fp, gargula)
		return

	# --- 4) o arremesso: ela solta e ele cai dentro do portal ---
	_fugir(gargula, arremesso, saida_portal)
	fp.tocar(&"queda")
	GlobalUtils.vibrate_controller(null, 0.7, 0.7, 0.4)
	fp.piscar(Color(1.0, 0.62, 0.25), 0.3, 0.02, 0.3)
	# O aviso do porão e o evento valem ANTES da troca de cena: a viagem leva o
	# jogo embora no meio desta queda.
	GlobalEvents.aviso_fraco_no_porao = true
	Eventos.concluir(Eventos.CAP1_INFERNO_4_LIMITE)
	var de := fp.global_position
	var meio := de.lerp(centro, 0.5) + Vector3.UP * 2.0
	var estado := {"viajou": false}
	await _fase(DUR_ARREMESSO, func(k: float) -> void:
		if not is_instance_valid(fp):
			return
		var e: float = k * k
		var pos: Vector3 = _bezier(de, meio, centro + saida_portal * 3.0, centro, e)
		fp.plantar(pos, centro, sin(k * TAU * 2.0) * 0.3 * k)
		fp.borrar(lerpf(0.0, BORRAO_IMPACTO, e))
		if not estado.viajou and k > 0.35:
			estado.viajou = true
			GlobalEvents.agarrao_rodando = false
			ViagemPortal.viajar(get_tree(), String(portal.get("destino")),
					String(portal.get("ponto_destino")), 1.2, 2.0))
	# Daqui em diante a cena está indo embora: a viagem troca a cena e leva
	# este nó, a gárgula e as mãos junto.


## Algo morreu no meio (troca de cena, jogador sumiu): devolve o controle.
func _desistir(fp: Node3D, gargula) -> void:
	if is_instance_valid(fp):
		fp.queue_free()
	if is_instance_valid(gargula):
		gargula.queue_free()
	_restaurar()
	queue_free()
