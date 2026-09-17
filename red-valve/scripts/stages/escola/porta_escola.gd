extends Node3D

## Uma porta da escola. A de uma folha, a de duas, o portão da rua e o portão
## do pátio usam este mesmo script — o que muda é a metadata.
##
## A cena é gerada por `tools/godot/escola/gerar_cena_escola.py`, que monta
## cada porta assim:
##
##     p_xxx (este nó)               +X corre ao longo do vão, +Z é "pra fora"
##       pivo      (dobradiça esquerda)
##         folha   (malha)
##         corpo   (AnimatableBody3D — a colisão da folha)
##       pivo_b    (só nas duplas; dobradiça direita, já nasce virada 180)
##       area      (Area3D que cobre os DOIS lados do vão)
##
## ==========================================================================
## OS TRÊS PAPÉIS
##
## `saida`  — o portão da rua. Não gira: acionar troca de cena e devolve o
##            jogador à cidade.
## `portao` — o portão do pátio. É a regra de jogo desta fase: ele está
##            trancado, e só destranca de UM LADO (o do corredor sul). Pelo
##            pátio, enquanto isso não aconteceu, ele só informa.
## nenhum   — porta comum.
##
## ==========================================================================
## A PORTA NÃO TEM MAIS PROMPT: ELA É EMPURRADA
##
## Porta comum não pede mais "aperte para abrir". O jogador ANDA PRA DENTRO
## DELA: o `_empurrando()` vê que ele está vindo de frente pro vão, o braço
## direito dele se estica (player.gd -> `esticar_mao_para`) e a folha gira.
##
## O que continua no aperto de botão, de propósito: a porta TRANCADA (que só
## informa), o PORTÃO do pátio enquanto trancado (destrancar é escolha do
## jogador, e é a regra desta fase) e o portão de SAÍDA (que troca de cena — e
## trocar de cena sem querer, só por passar perto, seria imperdoável).
##
## O nome da sala continua aparecendo na tela. Ele não era o prompt, era a
## informação útil dentro do prompt: "Abrir — Sala 103" virou "Sala 103".
##
## ==========================================================================
## ABRIR PRA DENTRO E PRA FORA
##
## A porta abre SEMPRE PRA LONGE do jogador. Porta que abre por cima de quem
## está na soleira empurra a câmera pra dentro da parede e, pior, prende o
## jogador entre a folha e o batente. Descobrir o lado é uma conta só:
## `to_local()` põe o jogador em coordenadas da porta, e o sinal do Z diz de
## que lado ele está.
##
## O giro das duas folhas tem sinal TROCADO porque a `pivo_b` já nasce girada
## 180 graus (é o que permite as duas usarem a mesma malha). Girada, o +X local
## dela aponta pro outro lado, então o mesmo ângulo levaria as folhas pra lados
## opostos.

const ABERTURA := PI * 0.5
## A porta ABRE NO TEMPO DE QUEM CHEGA. Parado ou andando devagar ela abre
## pesada; correndo, ela sai da frente a tempo. Um valor único não serve: o
## lento em cima de quem corre vira uma folha fechando na cara do jogador (ele
## percorre os 1,2 m da área em 0,34 s correndo), e o rápido em cima de quem
## anda vira a porta antiga, que abria como se fosse de papel.
const TEMPO_ABRIR_LENTO := 1.10
const TEMPO_ABRIR_RAPIDO := 0.45
## As duas pontas da régua de velocidade. A de cima é a corrida DE INTERIOR
## (player.gd: RUN_SPEED_INTERIOR), que é a única corrida que existe aqui.
const VEL_ANDANDO := 1.0
const VEL_CORRENDO := 3.5
const TEMPO_FECHAR := 1.30
## Devagar demais pra contar como empurrão (m/s).
const EMPURRAO_VEL_MINIMA := 0.6
## O quanto o movimento tem de ir PRA DENTRO DO VÃO. Sem isto, passar correndo
## rente a uma porta no corredor abre ela de raspão.
const EMPURRAO_ALINHAMENTO := 0.55
## Já dentro do vão (metros do plano da porta), qualquer movimento empurra.
const NA_SOLEIRA := 0.25
## ONDE O EMPURRÃO ACONTECE.
##
## A área da porta tem 1,2 m de cada lado, e disparar na borda dela abria a
## porta com o Maycow ainda longe: a mão esticava no ar e a folha já estava
## girando. O empurrão espera ele CHEGAR.
##
## `DISTANCIA_PARADA` é onde o corpo dele trava: raio da cápsula do jogador
## (0,674) mais a meia espessura da folha. `ANTECEDENCIA` são os poucos
## centésimos antes disso — e vão multiplicados pela velocidade, senão quem
## corre bate na folha fechada e quem anda vê a porta abrir cedo demais.
const DISTANCIA_PARADA := 0.72
const ANTECEDENCIA := 0.10
## A folha só começa a girar depois que a mão saiu. Nunca mais do que o tempo
## que falta pro jogador chegar — atrasar além disso é bater na porta.
const ATRASO_DA_FOLHA := 0.12
## Altura e duração do gesto da mão.
const ALTURA_MAO := 1.05
const TEMPO_MAO := 0.45
## Quanto tempo a porta fica aberta antes de se fechar sozinha.
const ESPERA_FECHAR := 5.0
## Se o jogador estiver mais perto que isto da dobradiça na hora de fechar, a
## porta espera. Sem isso ela fecha em cima de quem parou na soleira — e como a
## folha é um corpo sólido, ele fica preso.
const RAIO_SEGURANCA := 2.1

@onready var pivo: Node3D = $pivo
@onready var pivo_b: Node3D = get_node_or_null("pivo_b")
@onready var area: Area3D = $area

var aberta: bool = false

var _mexendo: bool = false
var _player_perto: bool = false
var _player: Node3D = null
var _conta_regressiva: float = 0.0
var _id_msg: String = ""
var _trancada: bool = false
var _saida: bool = false
var _portao: bool = false


func _ready() -> void:
	_id_msg = "esc_porta_" + name
	_trancada = get_meta("trancada", false)
	_saida = get_meta("saida", false)
	_portao = get_meta("portao", false)
	area.body_entered.connect(_ao_entrar)
	area.body_exited.connect(_ao_sair)


func _process(delta: float) -> void:
	if aberta and not _mexendo:
		_conta_regressiva -= delta
		if _conta_regressiva <= 0.0:
			if _perto_demais_pra_fechar():
				_conta_regressiva = 1.0
			else:
				_fechar()

	if not _player_perto or _mexendo:
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return
	if _empurrando():
		_empurrar()
		return
	if Input.is_action_just_pressed("ui_accept"):
		_acionar()


## O jogador está entrando no vão? Só isto abre a porta comum.
##
## As duas contas são feitas em coordenadas DA PORTA: o sinal do Z do jogador
## diz de que lado ele está, e o Z da direção do movimento diz pra onde ele
## vai. Sinais diferentes = ele está vindo atravessar.
##
## O portão do pátio só entra nisto DEPOIS de destrancado: trancado, ele é uma
## conversa, e conversa não se tem esbarrando.
func _empurrando() -> bool:
	if aberta or _trancada or _saida or not is_instance_valid(_player):
		return false
	if _portao and not GlobalEvents.escola_portao_destrancado:
		return false
	var v := _velocidade_do_player()
	if v.length() < EMPURRAO_VEL_MINIMA:
		return false
	var lado := to_local(_player.global_position).z
	if absf(lado) < NA_SOLEIRA:
		return true
	var dir := (global_transform.basis.inverse() * v).normalized()
	if absf(dir.z) < EMPURRAO_ALINHAMENTO:
		return false
	if signf(dir.z) == signf(lado):
		return false
	# Só quando ele CHEGA. O quanto de antecedência vale depende de quão rápido
	# ele vem: parado na porta, quase nada; correndo, meio metro.
	return absf(lado) <= DISTANCIA_PARADA + ANTECEDENCIA * v.length()


func _empurrar() -> void:
	_mao_na_folha()
	_abrir(_atraso_da_folha())


## Quanto a folha espera a mão. Nunca mais do que o tempo que falta pro jogador
## encostar nela.
func _atraso_da_folha() -> float:
	if not is_instance_valid(_player):
		return 0.0
	var v := maxf(_velocidade_do_player().length(), 0.1)
	var falta := maxf(absf(to_local(_player.global_position).z) - DISTANCIA_PARADA, 0.0)
	return minf(ATRASO_DA_FOLHA, falta / v)


## Manda o Maycow esticar o braço até a folha, na altura da maçaneta e no
## PEDAÇO DA FOLHA QUE ESTÁ NA FRENTE DELE — não no meio do vão: numa porta
## dupla, o meio do vão é justamente onde não há folha nenhuma.
func _mao_na_folha() -> void:
	if not is_instance_valid(_player) or not _player.has_method("esticar_mao_para"):
		return
	var meia := float(get_meta("largura", 1.0)) * 0.5
	var x := clampf(to_local(_player.global_position).x, -meia + 0.15, meia - 0.15)
	_player.esticar_mao_para(to_global(Vector3(x, ALTURA_MAO, 0.0)), TEMPO_MAO)


func _velocidade_do_player() -> Vector3:
	if not is_instance_valid(_player) or not ("velocity" in _player):
		return Vector3.ZERO
	var v: Vector3 = _player.velocity
	v.y = 0.0
	return v


## De que lado do vão o jogador está? Para o portão do pátio isto é tudo o que
## importa: "por dentro" é o lado do CORREDOR, e é só de lá que ele destranca.
##
## O gerador põe o portão no muro sul do pátio, que corre em X, com o +Z local
## apontando para o corredor. Então Z local positivo = lado do corredor.
func _no_lado_de_dentro() -> bool:
	if not is_instance_valid(_player):
		return false
	return to_local(_player.global_position).z > 0.0


func _acionar() -> void:
	# O portão do pátio: destranca só por dentro, e fica destrancado. O estado
	# vive em GlobalEvents porque o jogador vai e volta entre esta cena e a do
	# porão — guardado aqui no nó, ele se perderia na primeira troca de cena.
	if _portao and not GlobalEvents.escola_portao_destrancado:
		if _no_lado_de_dentro():
			GlobalEvents.escola_portao_destrancado = true
			GlobalUtils.show_center_message(
				_id_msg, tr("PROMPT_ESC_PORTAO_DESTRANCADO"), 16, 2.2)
			_abrir()
			return
		GlobalUtils.show_center_message(
			_id_msg, tr("PROMPT_ESC_PORTAO_TRANCADO"), 16, 1.8)
		return

	if _trancada:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_ESC_TRANCADA"), 16, 1.6)
		return

	# O portão da rua é a única porta que não é uma porta: quem manda nela é a
	# cena, porque sair daqui é voltar pra cidade. O dono responde pelo método —
	# não por sinal — para seguir o mesmo acordo que a igreja e o hospital já
	# usam com as deles.
	if _saida:
		_player_perto = false
		GlobalUtils.hide_center_message(_id_msg)
		var dono := owner if owner else get_parent()
		if dono and dono.has_method("sair_da_escola"):
			dono.sair_da_escola()
		return

	if aberta:
		_fechar()
	else:
		_abrir()


## Abre pro lado oposto ao do jogador. `sinal` = +1 quer dizer "as folhas vão
## pro +Z local".
func _abrir(atraso: float = 0.0) -> void:
	var sinal := 1.0
	if is_instance_valid(_player):
		sinal = -1.0 if to_local(_player.global_position).z > 0.0 else 1.0
	_girar(-ABERTURA * sinal, _tempo_de_abrir(), atraso)
	aberta = true
	_conta_regressiva = ESPERA_FECHAR
	_atualizar_prompt()


## Quanto mais rápido o jogador chega, mais rápido a folha sai da frente.
func _tempo_de_abrir() -> float:
	var v := _velocidade_do_player().length()
	var t := clampf(inverse_lerp(VEL_ANDANDO, VEL_CORRENDO, v), 0.0, 1.0)
	return lerpf(TEMPO_ABRIR_LENTO, TEMPO_ABRIR_RAPIDO, t)


func _fechar() -> void:
	_girar(0.0, TEMPO_FECHAR)
	aberta = false
	_atualizar_prompt()


func _girar(angulo: float, tempo: float, atraso: float = 0.0) -> void:
	_mexendo = true
	var tween := create_tween()
	tween.set_parallel(true)
	# No quadro de física: a folha é um AnimatableBody3D, e corpo animado movido
	# no quadro de idle teleporta em vez de se mover — atravessa o jogador em
	# vez de empurrá-lo.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	# `atraso` é a mão saindo na frente: a folha só começa a girar depois que o
	# braço do Maycow chegou nela. Com `set_parallel`, cada tweener carrega o
	# próprio atraso — as duas folhas continuam saindo juntas.
	tween.tween_property(pivo, "rotation:y", angulo, tempo).set_delay(atraso)
	if pivo_b:
		tween.tween_property(pivo_b, "rotation:y", PI - angulo, tempo).set_delay(atraso)
	await tween.finished
	_mexendo = false


func _perto_demais_pra_fechar() -> bool:
	if not is_instance_valid(_player):
		return false
	var d := _player.global_position - global_position
	d.y = 0.0
	return d.length() < RAIO_SEGURANCA


func _ao_entrar(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player = body
	_player_perto = true
	_atualizar_prompt()


func _ao_sair(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_perto = false
	GlobalUtils.hide_center_message(_id_msg)


func _atualizar_prompt() -> void:
	if not _player_perto:
		return
	if _portao and not GlobalEvents.escola_portao_destrancado:
		GlobalUtils.show_center_message(
			_id_msg,
			tr("PROMPT_ESC_PORTAO_ABRIR") if _no_lado_de_dentro()
			else tr("PROMPT_ESC_PORTAO_TRANCADO"), 16)
		return
	if _trancada:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_ESC_TRANCADA"), 16)
		return
	if _saida:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_ESC_SAIR"), 16)
		return
	# Porta comum: não há mais o que apertar, então o que fica na tela é só o
	# NOME DA SALA — que era a única informação útil do prompt antigo. Ele sai
	# do CSV traduzido, igual antes.
	var sala := String(get_meta("sala", "ESC_SALA_GENERICA"))
	GlobalUtils.show_center_message(_id_msg, tr(sala), 16)


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
