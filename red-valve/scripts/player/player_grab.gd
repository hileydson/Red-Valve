extends Node

## O AGARRAO: o que acontece quando o jogador encosta num inimigo FORA da arena.
##
## Antes, encostar num inimigo na cidade arrastava o jogador para a arena
## (player_amulet.force_battle_from_touch). Agora o inimigo AGARRA: a camera
## entra no corpo do Maycow, as maos aparecem se defendendo, e conforme o
## inimigo ele MORDE (e solta) ou LEVANTA e ARREMESSA o jogador longe. O dano
## sai dai — e' o dano padrao do encostao fora da arena.
##
## DENTRO da arena nada disto vale: la' o encostao continua sendo a pancada de
## sempre (empurrao + `take_damage`), que e' o que o combate espera.
##
## Quem entra aqui: `<inimigo>._tenta_agarrao()` -> `player.grab_from_touch()`
## -> este componente. Vale para TODOS os inimigos, cada um com os proprios
## scripts (enemy.gd, shadow_rock.gd, shadow_seraph.gd, folded_neighbor.gd);
## por isso tudo que este arquivo le' do inimigo e' lido com `in`/`has_method`,
## nunca assumindo um tipo.
##
## A camera e as maos moram numa cena separada e reaproveitavel
## (scenes/player/cutscene_fp/player_cutscene_fp.tscn). O `player.tscn` NAO e'
## tocado: so' o modelo de 3a pessoa some enquanto a cena roda.

const CENA_FP := "res://scenes/player/cutscene_fp/player_cutscene_fp.tscn"

## A ORIGEM DO JOGADOR NAO FICA NOS PES.
##
## A CollisionShape3D do player.tscn esta em y = 0 com uma capsula de 2 m: a
## origem e' o MEIO dela, cerca de 1 m acima do chao. Tratar a origem como se
## fossem os pes enterrava metade do corpo no chao no arremesso e deixava a
## camera um metro acima da cabeca do inimigo.
##
## Por isso duas medidas separadas, as duas tiradas do proprio jogador em vez
## de chutadas: `_altura_do_olho()` (o marcador de 1a pessoa) e
## `_altura_do_corpo` (raio para baixo, medido quando a cena comeca).
const ALTURA_OLHO_PADRAO := 0.5
const ALTURA_CORPO_PADRAO := 1.0
## Altura do olho ACIMA DO CHAO de quem esta caido, apoiado nas proprias maos.
const ALTURA_CAIDO := 0.5

## Quanto do sangue que AINDA RESTA cada agarrao cobra. Fracao, e nao valor
## fixo, pelo mesmo motivo do toque antigo: um numero fixo mata quem esta no
## fim da barra e nao arranha quem esta cheio.
const DANO_MORDIDA := 0.26
const DANO_ARREMESSO := 0.32
## Piso, para o agarrao nunca sair de graca quando o jogador esta com pouca vida.
const DANO_MINIMO := 7

## Quanto o jogador voa no arremesso (metros), antes de encurtar por parede.
const DISTANCIA_ARREMESSO := 7.5

## Nenhum outro inimigo agarra dentro desta janela depois de um agarrao. Sem
## isso, cair no meio de tres inimigos vira uma fila de cinematicas e o jogador
## nunca mais joga.
const ESPERA_ENTRE_AGARROES := 5.0
## E logo depois de ser solto ele ainda tem um respiro sem levar dano.
const INVULNERAVEL_DEPOIS := 1.6

## Tempo maximo da cena. O watchdog em GlobalUtils destrava o input se a
## sequencia morrer no meio (troca de cena, jogador morreu, inimigo sumiu).
const TETO_DA_CENA := 14.0

## --- a troca de camera (3a <-> 1a pessoa) ---
##
## Os dois momentos em que a imagem troca de dono sao os mais faceis de
## estragar: sem nada, a cinematica comeca e acaba com um CORTE seco. O que
## costura e' sempre o mesmo par — a lente abre para `FOV_TROCA` e volta, e um
## borrao radial entra no talo e cai. Na entrada a camera anda PARA FRENTE
## enquanto a lente fecha (zoom in); na saida ela recua enquanto a lente abre
## (zoom out).
## Valores de proposito CURTOS: o pedido era um borrao pequeno, e a lente
## abrindo 15 graus ja' entorta as bordas o bastante para a troca ler como
## movimento. Mais que isto vira efeito de menu de opcoes.
const FOV_TROCA := 90.0
const BORRAO_TROCA := 0.7
## Quanto dura o mergulho da entrada (camera de 3a pessoa -> olho).
const DURACAO_MERGULHO := 0.34
## Quanto dura o recuo da saida (olho -> marcador de 3a pessoa).
const DURACAO_RECUO := 0.34
## E quanto o borrao ainda fica na tela DEPOIS de a camera do jogador voltar a
## mandar: e' esse rabo que faz a volta parecer uma coisa so'.
const DESCIDA_DO_BORRAO := 0.34

var player: CharacterBody3D
var _rodando: bool = false
var _liberado_em: float = 0.0
## Como o modelo de 3a pessoa estava antes da cena, para devolver igual.
var _modelo_estava_visivel: bool = true
## Quanto a origem do jogador fica acima do chao (ver as constantes).
var _altura_do_corpo: float = ALTURA_CORPO_PADRAO


func _ready() -> void:
	player = get_parent()


# ============================================================ porta de entrada

## Chamado pelo inimigo que encostou. true = o toque foi consumido e o inimigo
## NAO deve aplicar o dano normal dele.
func grab_from_touch(inimigo: Node3D) -> bool:
	if not _pode_agarrar(inimigo):
		return false

	# Um segundo inimigo encostando durante a cena tem o toque consumido do
	# mesmo jeito: deixar cair no dano normal seria tirar vida por cima da
	# cinematica, e poderia matar o jogador no meio dela.
	if _rodando or GlobalEvents.agarrao_rodando:
		return true

	_rodando = true
	GlobalEvents.agarrao_rodando = true
	GlobalEvents.agarrao_id += 1
	GlobalUtils.watchdog_agarrao(TETO_DA_CENA, GlobalEvents.agarrao_id)
	_sequencia(inimigo)
	return true


func _pode_agarrar(inimigo: Node3D) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(inimigo):
		return false
	if not player.is_inside_tree() or get_tree() == null:
		return false
	if ("dead" in inimigo) and inimigo.dead:
		return false
	# FORA DA ARENA, e so'. `is_maycow_normal` e' exatamente esta pergunta: a
	# arena (battlefield e battlefield_2) e a unica coisa no jogo que liga o
	# Maycow de combate.
	if not GlobalEvents.is_maycow_normal:
		return false
	var cena := get_tree().current_scene
	if cena != null and cena.scene_file_path.contains("battlefield"):
		return false
	if Time.get_ticks_msec() / 1000.0 < _liberado_em:
		return false
	if player.current_health <= 0:
		return false
	if player.invulnerable or GlobalEvents.in_cutscene:
		return false
	if player.get("is_using_ultimate") == true:
		return false
	if player.get("is_teleporting_enemies") == true or player.get("is_playing_return_effect") == true:
		return false
	if GlobalUtils.in_cinematic_cutscene or GlobalEvents.telefone_cutscene_active:
		return false
	return true


# ============================================================ a cena

func _sequencia(inimigo: Node3D) -> void:
	var tipo := "mordida"
	if "tipo_agarrao" in inimigo and String(inimigo.tipo_agarrao) != "":
		tipo = String(inimigo.tipo_agarrao)

	_entrar_em_cena()

	var fp := load(CENA_FP).instantiate() as Node3D
	get_tree().current_scene.add_child(fp)

	var olho := _olho()
	var frente := _direcao_ate(inimigo)
	var alvo_olhar := _cabeca(inimigo)

	# A camera nasce EXATAMENTE onde a de 3a pessoa esta e mergulha ate o olho:
	# e' esse mergulho, e nao um corte, que faz o jogador entender que passou a
	# ver pelos proprios olhos.
	var cam3 := get_viewport().get_camera_3d()
	var partida := cam3.global_position if is_instance_valid(cam3) else olho - frente * 3.0
	fp.plantar(partida, alvo_olhar)
	# A lente entra ABERTA e o borrao no talo, os dois escritos na hora: e' o
	# quadro em que a camera vira a atual, e um FOV tweenado a partir daqui
	# comecaria errado.
	fp.lente(FOV_TROCA)
	fp.borrar(BORRAO_TROCA)
	fp.assumir_camera()
	fp.tocar(&"sacar")
	fp.piscar(Color(1.0, 0.96, 0.92), 0.4, 0.02, 0.28)
	GlobalUtils.vibrate_controller(null, 0.35, 0.35, 0.25)
	# ZOOM IN: a lente fecha no mesmo tempo do mergulho, e o borrao cai um pouco
	# depois — assim ele ainda esta' na tela quando a camera para.
	fp.lente_padrao(DURACAO_MERGULHO)
	fp.borrar(0.0, DURACAO_MERGULHO * 1.25)

	await _viajar(fp, partida, olho, alvo_olhar, alvo_olhar, DURACAO_MERGULHO,
			0.0, 0.0, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	if not _vale_continuar(fp):
		_sair(fp, inimigo)
		return

	# --- o inimigo chega ---
	_congelar_inimigo(inimigo, true)
	fp.tocar(&"defesa")
	var posto := _ponto_na_frente(inimigo, 1.05)
	_mover_inimigo(inimigo, posto, 0.45)
	_rosnar(inimigo)
	fp.mirar(olho - frente * 0.10, _cabeca(inimigo), 6.0, 7.0)
	fp.tremer(0.006, 0.5)
	await _esperar(0.55)
	if not _vale_continuar(fp):
		_sair(fp, inimigo)
		return

	# --- agarrou ---
	_atacar_inimigo(inimigo)
	var preso := olho + frente * 0.16 + Vector3.UP * 0.16
	fp.tocar(&"agarrado")
	fp.mirar(preso, _cabeca(inimigo), 7.0, 8.0, 0.045)
	fp.tremer(0.016, 0.8)
	GlobalUtils.vibrate_controller(null, 0.7, 0.7, 0.5)
	await _esperar(0.7)
	if not _vale_continuar(fp):
		_sair(fp, inimigo)
		return

	if tipo == "arremesso":
		await _ramo_arremesso(fp, inimigo, frente)
	else:
		await _ramo_mordida(fp, inimigo, preso, frente)

	_sair(fp, inimigo)


# ------------------------------------------------------------------ mordida

func _ramo_mordida(fp: Node3D, inimigo: Node3D, preso: Vector3, frente: Vector3) -> void:
	# O bicho puxa o jogador para perto do proprio rosto.
	_mover_inimigo(inimigo, _ponto_na_frente(inimigo, 0.5), 0.22)
	var colado := preso + frente * 0.16
	fp.mirar(colado, _cabeca(inimigo), 11.0, 11.0, 0.08)
	await _esperar(0.26)
	if not _vale_continuar(fp):
		return

	# A MORDIDA.
	fp.tocar(&"mordida")
	fp.tremer(0.055, 0.45)
	fp.piscar(Color(0.85, 0.05, 0.05), 0.34, 0.02, 0.4)
	fp.sangrar(0.55, 1.6)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.55)
	_aplicar_dano(DANO_MORDIDA)
	if player.current_health <= 0:
		return
	_camera_lenta_curta(0.35, 0.30)
	await _esperar(0.45)
	if not _vale_continuar(fp):
		return

	# Solta e recua.
	#
	# A espera acompanha a animacao `mordida`, que dura 1,43 s: o ultimo terco
	# dela e' a supinacao do antebraco voltando para a guarda baixa, e cortar no
	# meio dessa volta deixa o giro parado na metade (era o que acontecia com
	# 0,45 s aqui).
	_mover_inimigo(inimigo, _ponto_na_frente(inimigo, 2.1), 0.35)
	fp.mirar(_olho() - frente * 0.12 - Vector3.UP * 0.08, _cabeca(inimigo), 5.0, 5.0, -0.10)
	await _esperar(0.85)
	if not _vale_continuar(fp):
		return

	# Se recompoe. A mistura e' longa de proposito: a `mordida` para na metade da
	# volta para a guarda baixa e o resto do giro acontece aqui, em linha reta.
	fp.tocar(&"idle", 1.0, 0.55)
	fp.mirar(_olho(), _cabeca(inimigo), 4.0, 4.0, 0.0)
	await _esperar(0.65)


# ----------------------------------------------------------------- arremesso

func _ramo_arremesso(fp: Node3D, inimigo: Node3D, frente: Vector3) -> void:
	# `chao` e' o PISO onde ele vai cair. Todas as alturas desta sequencia
	# saem dali, e nao da origem do jogador — que fica no meio da capsula.
	var chao := _ponto_de_queda(inimigo)
	var alt_olho := _altura_do_olho()

	# 1) Levantado do chao.
	#
	# O olhar NAO vai para a cabeca do inimigo: la' de cima, com ele a meio
	# metro, isso aponta a camera quase reto para o chao e o jogador passa a
	# cena olhando para o asfalto. Um ponto acima da cabeca dele deixa o
	# angulo em ~45 graus — da' para ver quem esta segurando.
	fp.tocar(&"arremesso")
	var alto := _olho() + Vector3.UP * 1.15 + frente * 0.25
	var olhar_alto := _cabeca(inimigo) + Vector3.UP * 0.8
	await _viajar(fp, fp.global_position, alto, _cabeca(inimigo), olhar_alto,
			0.55, 0.045, -0.28, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	if not _vale_continuar(fp):
		return
	GlobalUtils.vibrate_controller(null, 0.9, 0.9, 0.35)

	# 2) O voo. O olhar fica preso no inimigo enquanto o corpo se afasta: e' o
	# que da a leitura de "fui jogado", e nao de "a camera andou pra tras".
	fp.tocar(&"queda")
	var no_ar := chao + Vector3.UP * (alt_olho + _altura_do_corpo + 0.4)
	await _viajar(fp, alto, no_ar, olhar_alto, _cabeca(inimigo) + Vector3.UP * 0.3,
			0.42, -0.28, -0.95, Tween.TRANS_QUAD, Tween.EASE_IN)
	if not _vale_continuar(fp):
		return

	# 3) O chao. O corpo de verdade so' se teleporta AQUI: antes disto ele
	# continua onde estava, e o inimigo nao perde o alvo no meio do voo.
	_plantar_jogador(chao)
	var caido := chao + Vector3.UP * ALTURA_CAIDO
	var olhar_chao := chao + frente * 0.55 - Vector3.UP * 0.05
	fp.tocar(&"chao")
	fp.plantar(caido, olhar_chao, -0.55)
	fp.tremer(0.075, 0.5)
	fp.piscar(Color(0.8, 0.1, 0.08), 0.38, 0.02, 0.45)
	fp.sangrar(0.6, 1.8)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.6)
	_aplicar_dano(DANO_ARREMESSO)
	if player.current_health <= 0:
		return
	_camera_lenta_curta(0.4, 0.25)
	await _esperar(0.55)
	if not _vale_continuar(fp):
		return

	# 4) Apoia as maos e levanta. A camera sobe junto com a animacao das maos
	# (`levantar` dura 2,4 s), e e' isso que amarra as duas coisas.
	fp.tocar(&"levantar")
	var de_pe := chao + Vector3.UP * (_altura_do_corpo + alt_olho)
	var olhar_pe := chao + _direcao_ate(inimigo) * 3.0 \
			+ Vector3.UP * (_altura_do_corpo + alt_olho - 0.25)
	await _viajar(fp, caido, de_pe, olhar_chao, olhar_pe, 1.75,
			-0.55, 0.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	if not _vale_continuar(fp):
		return
	fp.tocar(&"idle")
	await _esperar(0.3)


# ============================================================ entra/sai

func _entrar_em_cena() -> void:
	GlobalEvents.in_cutscene = true
	player.velocity = Vector3.ZERO
	_medir_altura_do_corpo()
	if player.has_method("cutscene_set_hud_enabled"):
		player.cutscene_set_hud_enabled(false)
	if player.has_method("cutscene_set_camera_current"):
		player.cutscene_set_camera_current(false)

	# O modelo de 3a pessoa fica DENTRO da camera nova: sem esconder, a tela
	# inteira vira o peito do Maycow.
	#
	# E nao basta apagar a visibilidade daqui: o `_physics_process` do player
	# REESCREVE `modelo_visual.visible` todo quadro a partir da camera de 1a
	# pessoa dele, entao o corpo voltava no quadro seguinte e dava para ver o
	# Maycow inteiro de pe' ao lado da cinematica. Quem manda e' a trava do
	# proprio player.
	var modelo = player.get("modelo_visual")
	if is_instance_valid(modelo):
		_modelo_estava_visivel = modelo.visible
		modelo.visible = false
	if player.has_method("cutscene_set_model_hidden"):
		player.cutscene_set_model_hidden(true)


func _sair(fp: Node3D, inimigo: Node3D) -> void:
	_congelar_inimigo(inimigo, false)

	if is_instance_valid(fp):
		fp.tocar(&"guardar")
		fp.piscar(Color(1.0, 0.96, 0.92), 0.35, 0.02, 0.3)
		# ZOOM OUT: o espelho da entrada. A lente ABRE e o borrao SOBE enquanto a
		# camera recua para o ombro — e o pico dos dois cai junto com a troca.
		fp.lente(FOV_TROCA, DURACAO_RECUO)
		fp.borrar(BORRAO_TROCA, DURACAO_RECUO * 0.85)

	# Deixa o SpringArm assentar na posicao nova antes de ler o marcador: logo
	# depois de um arremesso ele ainda esta com o valor do lugar antigo.
	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_instance_valid(fp) and is_instance_valid(player):
		var marcador = player.get("camera_third_person_marker")
		if is_instance_valid(marcador):
			var chegada: Vector3 = marcador.global_position
			await _viajar(fp, fp.global_position, chegada,
					_olho() + _frente_do_jogador() * 4.0, _olho() + _frente_do_jogador() * 4.0,
					DURACAO_RECUO, 0.0, 0.0, Tween.TRANS_CUBIC, Tween.EASE_IN)

	_restaurar()

	# A troca acontece AQUI, no pico do borrao. O 3D desta cena se apaga (as maos
	# ficam coladas na camera dela, que parou exatamente onde a de 3a pessoa
	# esta': sem apagar, elas apareceriam penduradas na frente do Maycow), mas a
	# TELA dela fica mais um instante — e' o borrao descendo ja' sobre a imagem de
	# terceira pessoa que faz a volta parecer uma coisa so', e nao um corte.
	if is_instance_valid(fp):
		fp.apagar_3d()
		fp.borrar(0.0, DESCIDA_DO_BORRAO)
		await _esperar(DESCIDA_DO_BORRAO + 0.06)
	if is_instance_valid(fp):
		fp.queue_free()


func _restaurar() -> void:
	GlobalEvents.agarrao_rodando = false
	_rodando = false
	_liberado_em = Time.get_ticks_msec() / 1000.0 + ESPERA_ENTRE_AGARROES
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	GlobalEvents.in_cutscene = false

	if not is_instance_valid(player):
		return
	if player.has_method("cutscene_set_model_hidden"):
		player.cutscene_set_model_hidden(false)
	var modelo = player.get("modelo_visual")
	if is_instance_valid(modelo):
		modelo.visible = _modelo_estava_visivel
	if player.has_method("cutscene_set_camera_current"):
		player.cutscene_set_camera_current(true)
	if player.has_method("cutscene_set_hud_enabled"):
		player.cutscene_set_hud_enabled(true)
	player.velocity = Vector3.ZERO

	# Respiro: sem isto o mesmo inimigo (ou o vizinho dele) conecta um golpe no
	# quadro seguinte, com o jogador ainda sem controle nenhum na mao.
	if player.current_health > 0:
		player.invulnerable = true
		await get_tree().create_timer(INVULNERAVEL_DEPOIS).timeout
		if is_instance_valid(player):
			player.invulnerable = false


# ============================================================ peças

## Onde ficam os olhos do Maycow. O marcador de 1a pessoa do proprio player e'
## a fonte: e' exatamente onde a Camera3D dele senta.
func _altura_do_olho() -> float:
	var marcador = player.get("camera_first_person_marker")
	if is_instance_valid(marcador):
		return (marcador as Node3D).position.y
	return ALTURA_OLHO_PADRAO


func _olho() -> Vector3:
	return player.global_position + Vector3.UP * _altura_do_olho()


## Mede, com um raio para baixo, a que altura do chao a origem do jogador esta.
## Medir em vez de assumir: a capsula pode mudar, e o mesmo numero serve para
## pousar o corpo no arremesso sem enterrar nem flutuar.
func _medir_altura_do_corpo() -> void:
	if not is_instance_valid(player) or player.get_world_3d() == null:
		return
	var espaco := player.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 0.2,
			player.global_position - Vector3.UP * 5.0, player.collision_mask)
	consulta.exclude = [player.get_rid()]
	var piso := espaco.intersect_ray(consulta)
	if piso:
		_altura_do_corpo = clampf(player.global_position.y - piso.position.y, 0.05, 2.5)


func _frente_do_jogador() -> Vector3:
	return -player.global_transform.basis.z


## Direcao horizontal do jogador para o inimigo.
func _direcao_ate(inimigo: Node3D) -> Vector3:
	if not is_instance_valid(inimigo):
		return _frente_do_jogador()
	var d := inimigo.global_position - player.global_position
	d.y = 0.0
	if d.length_squared() < 0.0004:
		return _frente_do_jogador()
	return d.normalized()


## Onde a camera deve olhar: a cabeca do inimigo, ou o topo dele quando o
## script nao diz a altura.
func _cabeca(inimigo: Node3D) -> Vector3:
	if not is_instance_valid(inimigo):
		return _olho() + _frente_do_jogador() * 3.0
	# Os inimigos vao de um zumbi a um Seraph de quase tres metros, e cada um foi
	# montado de um jeito. Em ordem de confianca:
	#
	# 1. `altura` — os que declaram (shadow_rock, shadow_seraph, folded_neighbor).
	# 2. O Area3D "heart", que e' literalmente a area da CABECA nos inimigos do
	#    enemy.tscn: da' a altura certa de graca, sem adivinhar capsula.
	# 3. A capsula "body_shape" (o nome da forma no enemy.tscn nao e'
	#    "CollisionShape3D", entao procurar por esse nome nunca achava nada).
	if "altura" in inimigo and float(inimigo.altura) > 0.5:
		return inimigo.global_position + Vector3.UP * (float(inimigo.altura) * 0.88)

	var coracao := inimigo.get_node_or_null("heart") as Node3D
	if coracao != null:
		return coracao.global_position

	for nome in ["body_shape", "CollisionShape3D"]:
		var forma := inimigo.get_node_or_null(nome) as CollisionShape3D
		if forma != null and forma.shape is CapsuleShape3D:
			var alt: float = (forma.shape as CapsuleShape3D).height * forma.scale.y
			return inimigo.global_position + Vector3.UP * (forma.position.y + alt * 0.42)

	return inimigo.global_position + Vector3.UP * 1.55


## Ponto a `metros` do jogador, na direcao do inimigo — onde ele deve ficar.
func _ponto_na_frente(inimigo: Node3D, metros: float) -> Vector3:
	var p := player.global_position + _direcao_ate(inimigo) * metros
	p.y = inimigo.global_position.y if is_instance_valid(inimigo) else player.global_position.y
	return p


## Para onde o jogador voa — devolve o ponto no CHAO, nao a posicao do corpo
## (quem soma a altura do corpo e' `_plantar_jogador`). Encurta antes de
## qualquer parede: e' o mesmo cuidado do empurrao em enemy.gd, que sem isto
## atravessava o jogador para fora do cenario.
func _ponto_de_queda(inimigo: Node3D) -> Vector3:
	var fuga := -_direcao_ate(inimigo)
	var destino := player.global_position + fuga * DISTANCIA_ARREMESSO
	var espaco := player.get_world_3d().direct_space_state
	var altura := Vector3(0.0, 1.0, 0.0)

	var consulta := PhysicsRayQueryParameters3D.create(
			player.global_position + altura, destino + altura, player.collision_mask)
	consulta.exclude = [player.get_rid()]
	var parede := espaco.intersect_ray(consulta)
	if parede:
		var livre: float = maxf(player.global_position.distance_to(parede.position) - 0.8, 0.0)
		destino = player.global_position + fuga * livre

	var chao := PhysicsRayQueryParameters3D.create(
			destino + Vector3.UP * 4.0, destino - Vector3.UP * 12.0, player.collision_mask)
	chao.exclude = [player.get_rid()]
	var piso := espaco.intersect_ray(chao)
	if piso:
		destino.y = piso.position.y
	else:
		# Sem chao debaixo do ponto de queda, devolve o chao de ONDE ELE ESTA:
		# melhor cair de pe no mesmo nivel do que afundar num buraco.
		destino.y = player.global_position.y - _altura_do_corpo
	return destino


## Poe o corpo no ponto de queda. `chao` e' o piso; a origem do jogador sobe
## `_altura_do_corpo` a partir dali — sem isso metade do corpo fica enterrada.
func _plantar_jogador(chao: Vector3) -> void:
	if not is_instance_valid(player):
		return
	player.velocity = Vector3.ZERO
	player.global_position = chao + Vector3.UP * _altura_do_corpo


func _aplicar_dano(fracao: float) -> void:
	if not is_instance_valid(player):
		return
	var dano := maxi(int(floor(player.current_health * fracao)), DANO_MINIMO)
	# `take_damage` sai fora quando `in_cutscene` esta ligado — e' o que impede
	# dano de cutscene em todo o resto do jogo. Aqui o dano E' a cutscene, entao
	# a trava cai e volta na MESMA chamada: nada de `await` no meio, nenhum
	# quadro passa, e o input continua bloqueado o tempo todo.
	var estava := GlobalEvents.in_cutscene
	GlobalEvents.in_cutscene = false
	player.take_damage(dano)
	GlobalEvents.in_cutscene = estava


## Camera lenta curtinha no impacto. Conta em tempo de verdade (o timer ignora
## o time_scale), senao ela mesma esticaria a propria espera.
func _camera_lenta_curta(escala: float, segundos: float) -> void:
	Engine.time_scale = escala
	AudioServer.playback_speed_scale = escala
	await get_tree().create_timer(segundos, true, false, true).timeout
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0


# ------------------------------------------------------------------ inimigo

## Cada inimigo tem o proprio script; nenhum deles herda de um tronco comum.
## Por isso nada aqui assume metodo ou propriedade — tenta o modo de cutscene
## (que enemy.gd tem) e cai no desligamento da fisica quando nao existe.
func _congelar_inimigo(inimigo: Node3D, congelar: bool) -> void:
	if not is_instance_valid(inimigo):
		return
	if "cutscene_mode" in inimigo:
		inimigo.cutscene_mode = congelar
	# O modo de cutscene do enemy.gd ainda roda `move_and_slide()` todo quadro,
	# e ele brigaria com o tween que traz o inimigo para perto: a cada quadro um
	# dos dois desmancharia o outro e o bicho chegaria tremendo. Desligar a
	# fisica inteira e' o que deixa o tween mandar sozinho.
	inimigo.set_physics_process(not congelar)
	if congelar and "velocity" in inimigo:
		inimigo.velocity = Vector3.ZERO


func _mover_inimigo(inimigo: Node3D, destino: Vector3, duracao: float) -> void:
	if not is_instance_valid(inimigo):
		return
	var t := inimigo.create_tween()
	t.tween_property(inimigo, "global_position", destino, duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Encarar o jogador de frente: sem isto o bicho morde de costas.
	var olhar := player.global_position
	olhar.y = destino.y
	if destino.distance_to(olhar) > 0.2:
		var giro := atan2(olhar.x - destino.x, olhar.z - destino.z)
		t.parallel().tween_property(inimigo, "rotation:y", giro, duracao)


func _atacar_inimigo(inimigo: Node3D) -> void:
	if not is_instance_valid(inimigo):
		return
	var arvore = inimigo.get("animation_tree")
	if arvore is AnimationTree:
		GlobalUtils.safe_travel(arvore, &"attack")


func _rosnar(inimigo: Node3D) -> void:
	if not is_instance_valid(inimigo):
		return
	var som = inimigo.get_node_or_null("growl_attack")
	if som is AudioStreamPlayer3D and not som.playing:
		som.play()


# ------------------------------------------------------------------ tempo

## Percorre um caminho de camera quadro a quadro. Nao e' tween de transform de
## proposito: interpolar uma Basis em linha reta entorta a imagem no meio do
## caminho, e aqui a camera gira MUITO (o arremesso passa de -0,95 rad de
## rolagem). Posicao, ponto de olhar e rolagem viajam separados.
func _viajar(fp: Node3D, pos_ini: Vector3, pos_fim: Vector3,
		olhar_ini: Vector3, olhar_fim: Vector3, duracao: float,
		rol_ini: float = 0.0, rol_fim: float = 0.0,
		curva: Tween.TransitionType = Tween.TRANS_SINE,
		suave: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var t := 0.0
	while t < duracao:
		if not is_instance_valid(fp) or get_tree() == null:
			return
		await get_tree().process_frame
		t += get_process_delta_time()
		if not is_instance_valid(fp):
			return
		var k: float = Tween.interpolate_value(0.0, 1.0, minf(t, duracao), duracao, curva, suave)
		fp.plantar(pos_ini.lerp(pos_fim, k), olhar_ini.lerp(olhar_fim, k),
				lerpf(rol_ini, rol_fim, k))


func _esperar(segundos: float) -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(segundos, true, false, true).timeout


func _vale_continuar(fp: Node3D) -> bool:
	return is_instance_valid(fp) and is_instance_valid(player) \
			and player.is_inside_tree() and player.current_health > 0
