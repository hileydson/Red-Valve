extends Node

## O RESGATE: o que acontece quando o jogador cai da arena (battlefield_1).
##
## Antes, sair do chao da arena era morte por queda (`player._trigger_fall_death`,
## disparado em y < -10). A arena flutua no ar e a borda e' curta: morrer por
## escorregar dela nao e' desafio, e' pedagio. Agora uma GARGULA DE FOGO passa
## voando, pega o jogador no ar, sobe com ele e larga num ponto SORTEADO da
## arena. Ao bater no chao estouram as mesmas pedras de lava da chegada na
## arena, e a gargula vai embora voando ate sumir.
##
## Nenhum dano: o pedido e' que cair nao mate mais, e cobrar sangue por um
## tropeco de borda seria a mesma punicao com outro nome.
##
## Quem entra aqui: `player._physics_process` -> `player._pedir_resgate_da_arena()`
## -> `battlefield.resgatar_do_abismo()` -> este no'.
##
## A camera e as maos sao as MESMAS do agarrao
## (scenes/player/cutscene_fp/player_cutscene_fp.tscn), e pelo mesmo motivo: as
## animacoes que esta cena precisa — se defender com a mao, ficar pendurado,
## cair, apoiar a palma no chao e levantar — ja' estao todas naquele rig. O
## `player.tscn` nao e' tocado.
##
## O corpo de verdade fica CONGELADO (`process_mode`) o tempo todo: sem isso a
## gravidade continuaria puxando o jogador para baixo durante o voo e o
## `_physics_process` dele voltaria a pedir resgate todo quadro.

const CENA_FP := "res://scenes/player/cutscene_fp/player_cutscene_fp.tscn"
const CENA_GARGULA := "res://scenes/effects/fire_gargoyle.tscn"

## A origem do jogador NAO fica nos pes: a capsula do player.tscn tem 2 m e
## esta centrada em y = 0, entao a origem fica ~1 m acima do chao. Medido em
## `_medir_altura_do_corpo` em vez de chutado (mesmo cuidado de player_grab.gd).
const ALTURA_OLHO_PADRAO := 0.5
const ALTURA_CORPO_PADRAO := 1.0
## Altura do olho ACIMA DO CHAO de quem esta caido, apoiado nas proprias maos.
const ALTURA_CAIDO := 0.5

## Teto da cena, para o watchdog destravar o input se algo morrer no meio.
const TETO_DA_CENA := 16.0

## O TOMBO COBRA 20% DO SANGUE QUE AINDA RESTA.
##
## Fracao do que resta, e nao valor fixo — mesma escolha do agarrao
## (player_grab.gd): um numero fixo mata quem esta no fim da barra e nao
## arranha quem esta cheio.
##
## E de proposito SEM piso minimo, ao contrario do agarrao: 20% do que resta
## nunca chega a zero, e o pedido desta cena inteira e' que cair na arena nao
## mate. Um piso reabriria justamente essa porta.
const DANO_DA_QUEDA := 0.20

## MOTION BLUR DA QUEDA.
##
## O borrao radial da cena de 1a pessoa (o mesmo desenho do "MotionBlurOverlay"
## do HUD) tambem serve de motion blur: ele puxa a tela para o centro, que e'
## exatamente o que a vista faz despencando. Aqui ele acompanha a curva da
## QUEDA — entra junto com a aceleracao, em vez de ser tweenado a parte.
const BORRAO_QUEDA := 0.85
## Pico no instante da batida, e quanto ele leva para descer depois.
##
## Pouco acima do borrao da queda, e nao muito: este borrao soma na tela com o
## flash da batida e com a vinheta de sangue do dano, e no talo (1,15) os tres
## juntos apagavam a imagem inteira no quadro que mais importa.
const BORRAO_IMPACTO := 0.98
const BORRAO_DESCIDA := 0.6

# --- a troca de camera (jogo <-> cinematica) ---
# Mesmo par do agarrao: a lente abre para `FOV_TROCA` e volta, e um borrao
# radial entra no talo e cai. E' o que faz a passagem ler como zoom em vez de
# corte seco.
const FOV_TROCA := 90.0
const BORRAO_TROCA := 0.7
const DURACAO_MERGULHO := 0.34
const DURACAO_RECUO := 0.34
const DESCIDA_DO_BORRAO := 0.34

# --- tempos da sequencia ---
## Quanto a gargula demora para chegar, vindo de longe.
const DUR_APROXIMACAO := 1.3
## O instante do agarrao propriamente dito.
const DUR_AGARRAO := 0.35
## A subida, com o jogador pendurado, ate' o ponto de largada.
const DUR_SUBIDA := 2.7
## A queda livre depois que ela solta.
const DUR_LARGADA := 0.8
## O respiro caido no chao, antes de levantar.
const DUR_CAIDO := 0.55
## Quanto dura o levantar (a animacao `levantar` das maos tem 2,4 s).
const DUR_LEVANTAR := 1.75
## A fuga da gargula depois de soltar, ate' ela sumir.
const DUR_FUGA := 2.6

# --- geometria do voo ---
## Quanto o jogador ainda despenca enquanto a gargula vem buscar.
const QUEDA_NA_APROXIMACAO := 7.0
## De que distancia ela entra em quadro.
const DISTANCIA_DE_ENTRADA := 34.0
## E de que altura, em relacao ao ponto do agarrao.
const ALTURA_DE_ENTRADA := 13.0
## Altura de onde ela larga o jogador, acima do chao da arena.
const ALTURA_DA_LARGADA := 16.0
## Quanto o olho fica ABAIXO da origem da gargula enquanto pendurado (a origem
## do modelo dela fica na sola do pe, entao o jogador vem logo abaixo das garras).
const PENDURADO := 1.5
## E quanto ele fica ARRASTADO PARA TRAS dela.
##
## Pendurado reto embaixo, a camera aponta para o zenite: o `looking_at` perde a
## referencia de "cima" e a gargula nem entra em quadro — o jogador passa o voo
## inteiro olhando para um ceu vazio. Puxado para tras, a linha de visao fica em
## ~55 graus e da' para ver a asa batendo por cima dele.
const ARRASTADO := 1.7

var player: CharacterBody3D
var arena: Node

var _altura_do_corpo: float = ALTURA_CORPO_PADRAO
var _process_mode_antes: int = Node.PROCESS_MODE_INHERIT
var _modelo_estava_visivel: bool = true


func _ready() -> void:
	arena = get_parent()


# ============================================================ porta de entrada

func resgatar(jogador: CharacterBody3D) -> void:
	player = jogador
	GlobalEvents.agarrao_rodando = true
	GlobalEvents.agarrao_id += 1
	GlobalUtils.watchdog_agarrao(TETO_DA_CENA, GlobalEvents.agarrao_id)
	_sequencia()


# ============================================================ a cena

func _sequencia() -> void:
	_entrar_em_cena()

	var alt_olho := _altura_do_olho()
	var olho_inicial := player.global_position + Vector3.UP * alt_olho
	# Onde ela alcanca o jogador: ele continua despencando enquanto ela vem.
	var ponto_pega := olho_inicial - Vector3.UP * QUEDA_NA_APROXIMACAO
	# De que lado ela entra — sorteado, para a cena nao ser sempre a mesma.
	var lado := Vector3(randf() * 2.0 - 1.0, 0.0, randf() * 2.0 - 1.0)
	if lado.length_squared() < 0.01:
		lado = Vector3.FORWARD
	lado = lado.normalized()

	var chao_alvo := _ponto_de_largada()
	var soltura := chao_alvo + Vector3.UP * ALTURA_DA_LARGADA

	var fp := load(CENA_FP).instantiate() as Node3D
	get_tree().current_scene.add_child(fp)

	# A camera nasce onde a do jogo esta' e mergulha ate' o olho: e' o mergulho,
	# e nao um corte, que faz entender que a imagem passou a ser a dele.
	var cam_jogo := get_viewport().get_camera_3d()
	var partida := cam_jogo.global_position if is_instance_valid(cam_jogo) \
			else olho_inicial + Vector3.UP * 2.5
	fp.plantar(partida, olho_inicial - Vector3.UP * 6.0)
	fp.lente(FOV_TROCA)
	fp.borrar(BORRAO_TROCA)
	fp.assumir_camera()
	# `queda`: os bracos rodando sem apoio. E' a animacao da queda livre.
	fp.tocar(&"queda")
	fp.lente_padrao(DURACAO_MERGULHO)
	fp.borrar(0.0, DURACAO_MERGULHO * 1.25)
	fp.tremer(0.010, DURACAO_MERGULHO)
	GlobalUtils.vibrate_controller(null, 0.35, 0.35, 0.3)

	var g0 := ponto_pega + lado * DISTANCIA_DE_ENTRADA + Vector3.UP * ALTURA_DE_ENTRADA
	var gargula := _nascer_gargula(g0, ponto_pega)

	# --- 1) ela vem vindo, e ele cai de costas vendo ---
	#
	# O mergulho da camera acontece DENTRO desta fase: o olho ja' esta'
	# descendo, e um `await` so' para o mergulho deixaria a gargula parada no ar
	# nesse meio tempo.
	var g1 := g0 - lado * 11.0 + Vector3.UP * 2.0
	var g2 := ponto_pega + lado * 9.0 + Vector3.UP * 7.0
	var defendeu := false
	await _fase(DUR_APROXIMACAO, func(k: float) -> void:
		if not is_instance_valid(fp) or not is_instance_valid(gargula):
			return
		var pos_g := _bezier(g0, g1, g2, ponto_pega, k)
		gargula.voo_dirigido_ir(pos_g, lerpf(0.55, 1.0, k))
		var olho: Vector3 = olho_inicial.lerp(ponto_pega, k)
		# O mergulho da entrada: a camera so' chega no olho no fim dele.
		var entrada: float = clampf(k * DUR_APROXIMACAO / DURACAO_MERGULHO, 0.0, 1.0)
		entrada = Tween.interpolate_value(0.0, 1.0, entrada, 1.0,
				Tween.TRANS_CUBIC, Tween.EASE_OUT)
		var cam: Vector3 = partida.lerp(olho, entrada)
		# Rolagem balancando: quem despenca nao fica com a cabeca no prumo.
		fp.plantar(cam, pos_g, sin(k * TAU * 1.5) * 0.14)
		# A mao sobe para se defender quando ela ja' esta' em cima dele.
		if not defendeu and k > 0.55:
			defendeu = true
			fp.tocar(&"defesa", 1.0, 0.16)
			GlobalUtils.vibrate_controller(null, 0.5, 0.5, 0.25))
	if not _vale_continuar(fp):
		_sair(fp, gargula, chao_alvo)
		return

	# --- 2) agarrou ---
	if is_instance_valid(gargula):
		gargula.voo_dirigido_frear()
	fp.tocar(&"agarrado")
	fp.tremer(0.030, 0.6)
	fp.piscar(Color(1.0, 0.62, 0.25), 0.42, 0.02, 0.35)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.5)

	# O corpo de verdade so' se teleporta AQUI, no comeco do voo: deixa'-lo
	# despencando no vazio o resto da cena manda os inimigos para a borda atras
	# dele. Escondido e congelado, ninguem ve' a mudanca.
	_plantar_jogador(chao_alvo)

	await _fase(DUR_AGARRAO, func(k: float) -> void:
		if not is_instance_valid(fp) or not is_instance_valid(gargula):
			return
		var pos_g: Vector3 = ponto_pega + Vector3.UP * lerpf(0.0, 0.9, k)
		gargula.voo_dirigido_ir(pos_g, 1.0)
		fp.plantar(pos_g - Vector3.UP * PENDURADO - lado * (ARRASTADO * k),
				pos_g + Vector3.UP * 0.9, lerpf(0.14, -0.10, k)))
	if not _vale_continuar(fp):
		_sair(fp, gargula, chao_alvo)
		return

	# --- 3) sobe voando com ele ---
	var s0 := ponto_pega + Vector3.UP * 0.9
	# A curva passa LARGO do ponto de largada e volta: em linha reta a subida
	# seria um elevador, e e' na curva que da' para ver a arena inteira girando
	# la' embaixo.
	var lateral := lado.cross(Vector3.UP).normalized()
	var s1 := s0 + Vector3.UP * (ALTURA_DA_LARGADA * 0.55) + lateral * 8.0
	var s2 := soltura + lateral * 12.0 + Vector3.UP * 5.0
	var anterior := s0
	await _fase(DUR_SUBIDA, func(k: float) -> void:
		if not is_instance_valid(fp) or not is_instance_valid(gargula):
			return
		var suave: float = Tween.interpolate_value(0.0, 1.0, k, 1.0,
				Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		var pos_g := _bezier(s0, s1, s2, soltura, suave)
		var frente := pos_g - anterior
		frente.y = 0.0
		frente = frente.normalized() if frente.length_squared() > 0.0000001 else lado
		anterior = pos_g
		gargula.voo_dirigido_ir(pos_g, lerpf(1.0, 0.7, suave))
		# Pendurado atras e abaixo das garras (ver ARRASTADO).
		var olho := pos_g - Vector3.UP * PENDURADO - frente * ARRASTADO
		# Ele primeiro olha para CIMA, para o que o pegou, e so' depois para
		# baixo, para onde esta' indo parar.
		var alvo: Vector3 = (pos_g + Vector3.UP * 0.9).lerp(
				chao_alvo, smoothstep(0.25, 0.85, suave))
		fp.plantar(olho, alvo, sin(k * TAU * 1.2) * 0.12))
	if not _vale_continuar(fp):
		_sair(fp, gargula, chao_alvo)
		return

	# --- 4) solta ---
	# A fuga roda SOLTA, em paralelo com a queda: a gargula tem de estar indo
	# embora enquanto o jogador despenca, e nao depois que ele bate.
	_fugir(gargula, soltura, lado)
	fp.tocar(&"queda")
	GlobalUtils.vibrate_controller(null, 0.6, 0.6, 0.3)
	var caido := chao_alvo + Vector3.UP * ALTURA_CAIDO
	var olhar_chao := chao_alvo + lado * 0.6 - Vector3.UP * 0.05
	var de_onde := fp.global_position
	await _fase(DUR_LARGADA, func(k: float) -> void:
		if not is_instance_valid(fp):
			return
		var desce: float = Tween.interpolate_value(0.0, 1.0, k, 1.0,
				Tween.TRANS_QUAD, Tween.EASE_IN)
		fp.plantar(de_onde.lerp(caido, desce),
				(de_onde + lado * 3.0).lerp(olhar_chao, desce),
				lerpf(-0.10, -0.85, desce))
		# Motion blur preso a MESMA curva da queda: escrito na hora (duracao 0),
		# senao um tween proprio andaria no ritmo dele e nao no da descida.
		fp.borrar(lerpf(0.0, BORRAO_QUEDA, desce)))
	if not _vale_continuar(fp):
		_sair(fp, gargula, chao_alvo)
		return

	# --- 5) o chao ---
	# As maos batem no chao e absorvem o tranco (`chao`), e as pedras de lava
	# estouram em volta — as MESMAS da chegada na arena.
	fp.tocar(&"chao")
	fp.plantar(caido, olhar_chao, -0.55)
	fp.tremer(0.085, 0.55)
	fp.piscar(Color(1.0, 0.72, 0.35), 0.4, 0.02, 0.45)
	if arena != null and arena.has_method("estourar_chao"):
		arena.estourar_chao(chao_alvo)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.65)
	# O borrao estoura no baque e vai descendo enquanto ele fica caido.
	fp.borrar(BORRAO_IMPACTO)
	fp.borrar(0.0, BORRAO_DESCIDA)
	fp.sangrar(0.42, 1.5)
	_aplicar_dano(DANO_DA_QUEDA)
	_camera_lenta_curta(0.4, 0.25)
	await _esperar(DUR_CAIDO)
	if not _vale_continuar(fp):
		_sair(fp, gargula, chao_alvo)
		return

	# --- 6) apoia as maos e levanta ---
	# A camera sobe junto com a animacao das maos, e e' isso que amarra as duas
	# coisas: a palma desliza para tras e para baixo enquanto o olho sobe.
	fp.tocar(&"levantar")
	var de_pe := chao_alvo + Vector3.UP * (_altura_do_corpo + alt_olho)
	var olhar_pe := chao_alvo + lado * 4.0 \
			+ Vector3.UP * (_altura_do_corpo + alt_olho - 0.25)
	await _fase(DUR_LEVANTAR, func(k: float) -> void:
		if not is_instance_valid(fp):
			return
		var sobe: float = Tween.interpolate_value(0.0, 1.0, k, 1.0,
				Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		fp.plantar(caido.lerp(de_pe, sobe), olhar_chao.lerp(olhar_pe, sobe),
				lerpf(-0.55, 0.0, sobe)))
	if _vale_continuar(fp):
		fp.tocar(&"idle")
		await _esperar(0.3)

	_sair(fp, gargula, chao_alvo)


# ============================================================ a gargula

func _nascer_gargula(pos: Vector3, olhar: Vector3) -> Node3D:
	var g := load(CENA_GARGULA).instantiate() as Node3D
	# Filha da ARENA, e nao deste no': este aqui morre no fim da cena, e a fuga
	# dela ainda esta' rodando quando isso acontece.
	get_tree().current_scene.add_child(g)
	# Esta gargula passa a cena inteira a dois metros da camera, e de perto as
	# primitivas do corpo dela ficam evidentes. O modo de perto a enterra no
	# proprio fogo (ver `modo_fogo_de_perto` em fire_gargoyle.gd).
	g.modo_fogo_de_perto()
	g.voo_dirigido_iniciar(pos, olhar)
	return g


## Ela larga o jogador e vai embora ate' sumir. Quem toca a fuga e' a PROPRIA
## gargula: esta cena acaba (e este no' se apaga) antes de ela sair de quadro.
func _fugir(gargula: Node3D, de: Vector3, lado: Vector3) -> void:
	if not is_instance_valid(gargula):
		return
	gargula.voo_dirigido_fugir(de + lado * 22.0 + Vector3.UP * 16.0,
			de + lado * 70.0 + Vector3.UP * 34.0, DUR_FUGA)


# ============================================================ entra/sai

func _entrar_em_cena() -> void:
	GlobalEvents.in_cutscene = true
	_medir_altura_do_corpo()
	player.velocity = Vector3.ZERO

	if player.has_method("cutscene_set_hud_enabled"):
		player.cutscene_set_hud_enabled(false)
	if player.has_method("cutscene_set_camera_current"):
		player.cutscene_set_camera_current(false)

	# O modelo de 3a pessoa fica DENTRO da camera nova. Nao basta apagar a
	# visibilidade daqui: o `_physics_process` do player a reescreve todo
	# quadro, entao quem manda e' a trava do proprio player.
	var modelo = player.get("modelo_visual")
	if is_instance_valid(modelo):
		_modelo_estava_visivel = modelo.visible
		modelo.visible = false
	if player.has_method("cutscene_set_model_hidden"):
		player.cutscene_set_model_hidden(true)

	# CONGELA o corpo. Diferente do agarrao, aqui o jogador esta' em QUEDA
	# LIVRE: sem desligar a fisica dele a gravidade o levaria embora durante o
	# voo, e o `_physics_process` voltaria a pedir resgate todo quadro.
	_process_mode_antes = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED


## `gargula` vem SEM TIPO de proposito: quando a cena chega ao fim direitinho a
## gargula ja' se apagou sozinha (a fuga dela acaba antes), e passar um objeto
## liberado para um parametro tipado como Node3D e' erro de tipo em tempo de
## execucao — a saida inteira morria ali, com o input travado.
func _sair(fp: Node3D, gargula, chao_alvo: Vector3) -> void:
	# Se a cena morreu no meio (jogador morto, troca de cena), o corpo ainda
	# esta' no vazio: poe'-lo no chao mesmo assim e' melhor que devolver o
	# controle em queda livre.
	if is_instance_valid(player) and player.global_position.y < chao_alvo.y:
		_plantar_jogador(chao_alvo)

	if is_instance_valid(fp):
		fp.tocar(&"guardar")
		fp.piscar(Color(1.0, 0.96, 0.92), 0.35, 0.02, 0.3)
		# ZOOM OUT: o espelho da entrada. A lente ABRE e o borrao SOBE enquanto
		# a camera recua para o lugar da camera do jogo.
		fp.lente(FOV_TROCA, DURACAO_RECUO)
		fp.borrar(BORRAO_TROCA, DURACAO_RECUO * 0.85)

	# Dois quadros de fisica para os marcadores de camera do jogador assentarem
	# na posicao nova antes de serem lidos: ele acabou de ser teleportado.
	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_instance_valid(fp) and is_instance_valid(player):
		var chegada := _camera_do_jogo()
		var mira := chegada + _frente_do_jogador() * 4.0
		await _viajar(fp, fp.global_position, chegada, mira, mira, DURACAO_RECUO)

	# O jogador so' volta a mandar DEPOIS do recuo. Descongelar antes deixaria
	# o `_physics_process` dele retomar a propria camera no meio do caminho — e
	# o recuo, que e' justamente o que costura a volta, sumiria num corte.
	_restaurar()

	# A troca acontece AQUI, no pico do borrao: o 3D desta cena se apaga (as
	# maos ficam coladas na camera dela) mas a TELA fica mais um instante — e' o
	# borrao descendo ja' sobre a imagem do jogo que costura a volta.
	if is_instance_valid(fp):
		fp.apagar_3d()
		fp.borrar(0.0, DESCIDA_DO_BORRAO)
		await _esperar(DESCIDA_DO_BORRAO + 0.06)
	if is_instance_valid(fp):
		fp.queue_free()
	if is_instance_valid(gargula):
		gargula.queue_free()
	queue_free()


func _restaurar() -> void:
	GlobalEvents.agarrao_rodando = false
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	GlobalEvents.in_cutscene = false

	if not is_instance_valid(player):
		return
	# A fisica volta ANTES da camera: e' o `_physics_process` do jogador que
	# retoma a camera dele (ver o bloco do Maycow parasita em player.gd), e com
	# o no' ainda congelado essa retomada nunca aconteceria.
	player.process_mode = _process_mode_antes
	player.velocity = Vector3.ZERO

	if player.has_method("cutscene_set_model_hidden"):
		player.cutscene_set_model_hidden(false)
	var modelo = player.get("modelo_visual")
	if is_instance_valid(modelo):
		modelo.visible = _modelo_estava_visivel
	if player.has_method("cutscene_set_camera_current"):
		player.cutscene_set_camera_current(true)
	if player.has_method("cutscene_set_hud_enabled"):
		player.cutscene_set_hud_enabled(true)


# ============================================================ peças

## Onde ficam os olhos do Maycow — o marcador de 1a pessoa do proprio player.
func _altura_do_olho() -> float:
	var marcador = player.get("camera_first_person_marker")
	if is_instance_valid(marcador):
		return (marcador as Node3D).position.y
	return ALTURA_OLHO_PADRAO


## Quanto a origem do jogador fica acima dos pes. Aqui NAO da' para medir com
## raio como o agarrao faz: quando esta cena comeca o jogador esta' no vazio,
## sem nada embaixo. A medida sai da propria capsula.
func _medir_altura_do_corpo() -> void:
	var forma := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if forma != null and forma.shape is CapsuleShape3D:
		var meio: float = (forma.shape as CapsuleShape3D).height * 0.5 * forma.scale.y
		_altura_do_corpo = clampf(forma.position.y + meio, 0.05, 2.5)


func _frente_do_jogador() -> Vector3:
	return -player.global_transform.basis.z


## Para onde a camera do jogo volta no fim. Na arena o Maycow e' o parasita, que
## joga em 1a pessoa: o destino e' o olho dele, e nao o marcador de ombro.
func _camera_do_jogo() -> Vector3:
	var alvo = player.get("camera_first_person_marker") if not GlobalEvents.is_maycow_normal \
			else player.get("camera_third_person_marker")
	if is_instance_valid(alvo):
		return (alvo as Node3D).global_position
	return player.global_position + Vector3.UP * _altura_do_olho()


## Onde a gargula larga o jogador: um ponto sorteado do chao da arena.
func _ponto_de_largada() -> Vector3:
	if arena != null and arena.has_method("ponto_aleatorio_na_arena"):
		return arena.ponto_aleatorio_na_arena()
	return Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))


## Poe o corpo no chao. `chao` e' o piso; a origem sobe `_altura_do_corpo` a
## partir dali — sem isso metade do corpo fica enterrada.
func _plantar_jogador(chao: Vector3) -> void:
	if not is_instance_valid(player):
		return
	player.velocity = Vector3.ZERO
	player.global_position = chao + Vector3.UP * _altura_do_corpo


## Cobra uma fracao do sangue que AINDA RESTA.
##
## `take_damage` sai fora quando `in_cutscene` esta ligado — e' o que impede
## dano de cutscene em todo o resto do jogo. Aqui o dano E' a cutscene, entao a
## trava cai e volta na MESMA chamada: nada de `await` no meio, nenhum quadro
## passa, e o input continua bloqueado o tempo todo. (Mesmo truque do
## `_aplicar_dano` de player_grab.gd.)
func _aplicar_dano(fracao: float) -> void:
	if not is_instance_valid(player):
		return
	var dano := int(floor(player.current_health * fracao))
	if dano <= 0:
		return
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


# ------------------------------------------------------------------ tempo

## Roda `passo` quadro a quadro por `duracao` segundos, com o andamento (0..1)
## como argumento. E' o motor de todas as fases: a camera e a gargula sao
## escritas no MESMO passo, porque a camera pendura no corpo dela e um tween
## separado para cada uma deixaria as duas um quadro fora de sincronia.
func _fase(duracao: float, passo: Callable) -> void:
	var t := 0.0
	while t < duracao:
		if get_tree() == null:
			return
		await get_tree().process_frame
		t += get_process_delta_time()
		if get_tree() == null:
			return
		passo.call(clampf(t / duracao, 0.0, 1.0))


## Percorre um caminho de camera quadro a quadro. Nao e' tween de transform de
## proposito: interpolar uma Basis em linha reta entorta a imagem no meio do
## caminho, e aqui a camera gira muito.
func _viajar(fp: Node3D, pos_ini: Vector3, pos_fim: Vector3,
		olhar_ini: Vector3, olhar_fim: Vector3, duracao: float) -> void:
	await _fase(duracao, func(k: float) -> void:
		if not is_instance_valid(fp):
			return
		var suave: float = Tween.interpolate_value(0.0, 1.0, k, 1.0,
				Tween.TRANS_CUBIC, Tween.EASE_IN)
		fp.plantar(pos_ini.lerp(pos_fim, suave), olhar_ini.lerp(olhar_fim, suave)))


func _esperar(segundos: float) -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(segundos, true, false, true).timeout


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) \
			+ p3 * (t * t * t)


func _vale_continuar(fp: Node3D) -> bool:
	return is_instance_valid(fp) and is_instance_valid(player) \
			and player.is_inside_tree() and get_tree() != null
