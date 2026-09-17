extends Node3D

## Uma porta do hospital — a de uma folha e a de duas usam este mesmo script.
##
## A cena e' gerada por `tools/godot/hospital/gerar_cena_hospital.py`, que monta
## cada porta assim:
##
##     porta_xxx (este no')          +X corre ao longo do vao, +Z e' "pra fora"
##       pivo      (dobradica esquerda)
##         folha   (malha)
##         corpo   (AnimatableBody3D — a colisao da folha)
##       pivo_b    (so' nas duplas; dobradica direita, ja' nasce virada 180 graus)
##       area      (Area3D que cobre os DOIS lados do vao)
##
## e deixa em metadata a chave de traducao da sala, a largura e se e' dupla.
##
## ==========================================================================
## A PORTA NAO TEM MAIS PROMPT: ELA E' EMPURRADA
##
## Porta comum nao pede mais "aperte para abrir". O jogador ANDA PRA DENTRO
## DELA: o `_empurrando()` ve' que ele esta' vindo de frente pro vao, o braco
## direito dele se estica (player.gd -> `esticar_mao_para`) e a folha gira.
##
## O que continua no aperto de botao, de proposito: a porta TRANCADA (que so'
## informa) e a porta de SAIDA (que troca de cena — e trocar de cena sem
## querer, so' por passar perto, seria imperdoavel).
##
## O nome da sala continua aparecendo na tela. Ele nao era o prompt, era a
## informacao util dentro do prompt: "Abrir — Quarto 103" virou "Quarto 103".
##
## ==========================================================================
## ABRIR PRA DENTRO E PRA FORA
##
## O pedido foi que a porta abrisse nos dois sentidos. Ela abre — mas nao por
## escolha do jogador, e sim SEMPRE PRA LONGE DELE. Porta que abre por cima de
## quem esta' na soleira empurra a camera pra dentro da parede e, pior, prende
## o jogador entre a folha e o batente.
##
## Descobrir o lado e' uma conta so': `to_local()` poe o jogador em
## coordenadas da porta, e o sinal do Z diz de que lado ele esta'.
##
## O giro das duas folhas tem sinal TROCADO porque a `pivo_b` ja' nasce girada
## 180 graus (e' o que permite as duas usarem a mesma malha). Girada, o +X
## local dela aponta pro outro lado, entao o mesmo angulo levaria as folhas
## pra lados opostos.

const ABERTURA := PI * 0.5
## A porta ABRE NO TEMPO DE QUEM CHEGA. Parado ou andando devagar ela abre
## pesada; correndo, ela sai da frente a tempo. Um valor unico nao serve: o
## lento em cima de quem corre vira uma folha fechando na cara do jogador (ele
## percorre os 1,2 m da area em 0,34 s correndo), e o rapido em cima de quem
## anda vira a porta antiga, que abria como se fosse de papel.
const TEMPO_ABRIR_LENTO := 1.60
const TEMPO_ABRIR_RAPIDO := 0.55
## As duas pontas da regua de velocidade. A de cima e' a corrida DE INTERIOR
## (player.gd: RUN_SPEED_INTERIOR), que e' a unica corrida que existe aqui.
const VEL_ANDANDO := 1.0
const VEL_CORRENDO := 3.5
const TEMPO_FECHAR := 1.30
## Devagar demais pra contar como empurrao (m/s).
const EMPURRAO_VEL_MINIMA := 0.6
## O quanto o movimento tem de ir PRA DENTRO DO VAO. Sem isto, passar correndo
## rente a uma porta no corredor abre ela de raspao.
const EMPURRAO_ALINHAMENTO := 0.55
## Ja' dentro do vao (metros do plano da porta), qualquer movimento empurra.
const NA_SOLEIRA := 0.25
## ONDE O EMPURRAO ACONTECE.
##
## A area da porta tem 1,2 m de cada lado, e disparar na borda dela abria a
## porta com o Maycow ainda longe: a mao esticava no ar e a folha ja' estava
## girando. O empurrao espera ele CHEGAR.
##
## `DISTANCIA_PARADA` e' onde o corpo dele trava: raio da capsula do jogador
## (0,674) mais a meia espessura da folha. `ANTECEDENCIA` e' o pedaco de
## caminhada ANTES disso em que o empurrao ja' vale — e vai multiplicada pela
## velocidade, senao quem corre bate na folha fechada. Ela nao antecipa a
## FOLHA, so' a MAO: quem atrasa a folha e' a `FRACAO_DA_APROXIMACAO`.
const DISTANCIA_PARADA := 0.72
const ANTECEDENCIA := 0.30
## A folha so' comeca a girar depois que a mao saiu — este e' o teto dessa
## espera, em segundos.
const ATRASO_DA_FOLHA := 0.38
## E quanto da caminhada ate' a folha ela deixa passar antes de comecar. Quase
## toda: a mao (que sobe em 0,14 s) ja' esta' ha' tempo na madeira quando a
## folha cede. Subir mais que isto so' faz a folha ceder DEPOIS do encosto, e
## ai' ele para na porta em vez de empurra-la.
##
## Preso a' FRACAO, e nao a um tempo fixo, o corredor continua servido: como a
## ANTECEDENCIA ja' multiplica pela velocidade, o tempo ate' o encosto e' o
## mesmo andando ou correndo — o que muda e' so' a distancia.
const FRACAO_DA_APROXIMACAO := 0.85
## Altura e duracao do gesto da mao.
const ALTURA_MAO := 1.05
const TEMPO_MAO := 0.60
## Quanto tempo a porta fica aberta antes de se fechar sozinha.
const ESPERA_FECHAR := 5.0
## Se o jogador estiver mais perto que isto da dobradica na hora de fechar, a
## porta espera. Sem isso ela fecha em cima de quem parou na soleira — e como a
## folha e' um corpo solido, ele fica preso.
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
## A porta da rua. Ela nao gira: acionar ela troca de cena (ver `_acionar`).
var _saida: bool = false


func _ready() -> void:
	_id_msg = "hosp_porta_" + name
	_trancada = get_meta("trancada", false)
	_saida = get_meta("saida", false)
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


## O jogador esta' entrando no vao? So' isto abre a porta comum.
##
## As duas contas sao feitas em coordenadas DA PORTA: o sinal do Z do jogador
## diz de que lado ele esta', e o Z da direcao do movimento diz pra onde ele
## vai. Sinais diferentes = ele esta' vindo atravessar.
func _empurrando() -> bool:
	if aberta or _trancada or _saida or not is_instance_valid(_player):
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
	# So' quando ele CHEGA. O quanto de antecedencia vale depende de quao
	# rapido ele vem: parado na porta, quase nada; correndo, meio metro.
	return absf(lado) <= DISTANCIA_PARADA + ANTECEDENCIA * v.length()


func _empurrar() -> void:
	_mao_na_folha()
	_abrir(_atraso_da_folha())


## Quanto a folha espera a mao. Nunca mais do que o tempo que falta pro jogador
## encostar nela.
func _atraso_da_folha() -> float:
	if not is_instance_valid(_player):
		return 0.0
	var v := maxf(_velocidade_do_player().length(), 0.1)
	var falta := maxf(absf(to_local(_player.global_position).z) - DISTANCIA_PARADA, 0.0)
	return minf(ATRASO_DA_FOLHA, falta / v * FRACAO_DA_APROXIMACAO)


## Manda o Maycow esticar o braco ate' a folha, na altura da macaneta e no
## PEDACO DA FOLHA QUE ESTA' NA FRENTE DELE — nao no meio do vao: numa porta
## dupla, o meio do vao e' justamente onde nao ha' folha nenhuma.
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


func _acionar() -> void:
	if _trancada:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_HOSP_TRANCADA"), 16, 1.6)
		return
	# A porta da rua e' a unica que nao e' uma porta: quem manda nela e' a cena,
	# porque sair daqui e' voltar pra cidade. O dono responde pelo metodo — nao
	# por sinal — pra seguir o mesmo acordo que a igreja ja' usa com a dela.
	if _saida:
		_player_perto = false
		GlobalUtils.hide_center_message(_id_msg)
		var dono := owner if owner else get_parent()
		if dono and dono.has_method("sair_do_hospital"):
			dono.sair_do_hospital()
		return
	if aberta:
		_fechar()
	else:
		_abrir()


## Abre pro lado oposto ao do jogador. `sinal` = +1 quer dizer "as folhas vao
## pro +Z local".
func _abrir(atraso: float = 0.0) -> void:
	var sinal := 1.0
	if is_instance_valid(_player):
		sinal = -1.0 if to_local(_player.global_position).z > 0.0 else 1.0
	_girar(-ABERTURA * sinal, _tempo_de_abrir(), atraso)
	aberta = true
	_conta_regressiva = ESPERA_FECHAR
	_atualizar_prompt()


## Quanto mais rapido o jogador chega, mais rapido a folha sai da frente.
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
	# No quadro de fisica: a folha e' um AnimatableBody3D, e corpo animado
	# movido no quadro de idle teleporta em vez de se mover — atravessa o
	# jogador em vez de empurra-lo.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	# `atraso` e' a mao saindo na frente: a folha so' comeca a girar depois que
	# o braco do Maycow chegou nela. Com `set_parallel`, cada tweener carrega o
	# proprio atraso — as duas folhas continuam saindo juntas.
	tween.tween_property(pivo, "rotation:y", angulo, tempo).set_delay(atraso)
	if pivo_b:
		# a segunda folha nasce virada 180 graus, entao o angulo dela e' o
		# simetrico — com o mesmo sinal as duas iam pra lados opostos
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
	if _trancada:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_HOSP_TRANCADA"), 16)
		return
	if _saida:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_HOSP_SAIR"), 16)
		return
	# Porta comum: nao ha' mais o que apertar, entao o que fica na tela e' so' o
	# NOME DA SALA — que era a unica informacao util do prompt antigo. Ele sai
	# do CSV traduzido, igual antes.
	var sala := String(get_meta("sala", "HOSP_SALA_GENERICA"))
	GlobalUtils.show_center_message(_id_msg, tr(sala), 16)


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
