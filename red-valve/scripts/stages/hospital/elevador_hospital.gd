extends Node3D

## O elevador do hospital: o unico jeito de chegar no segundo andar.
##
## A cena e' gerada por `tools/godot/hospital/gerar_cena_hospital.py`:
##
##     elevador (este no', no eixo do poco)
##       cabine                      <- e' ESTE no' que sobe e desce (position.y)
##         corpo, chao, painel, luz_cabine, area_dentro
##         portas_cabine/folha_n, folha_s
##       pavimento_1 / pavimento_2   <- as portas de pavimento, uma por andar
##         folha_n, folha_s, area_chamar
##
## ==========================================================================
## A SEQUENCIA
##
##   1. O jogador chega na porta do pavimento -> "Chamar o elevador".
##   2. Se a cabine estiver no outro andar, ela vem primeiro (devagar).
##      Chegando, as duas portas (a do pavimento e a da cabine) abrem juntas.
##   3. Ele entra. Dentro, o prompt vira "Subir para o 2o andar".
##   4. Aciona -> as portas fecham, o elevador da' um tranco e sobe DEVAGAR.
##   5. Chegou, as portas abrem.
##
## ==========================================================================
## COMO O JOGADOR SOBE JUNTO
##
## O chao da cabine e' `AnimatableBody3D` com `sync_to_physics`, que ja' deveria
## carregar um CharacterBody3D em cima. "Deveria": esse acoplamento depende de o
## jogador estar com `is_on_floor()` no quadro certo, e num elevador lento, com
## a gravidade puxando, ele pisca entre apoiado e nao apoiado — e cada pisca e'
## um tranco, ou uma queda pra dentro da cabine.
##
## Entao aqui a subida do jogador e' EXPLICITA: enquanto ele estiver dentro da
## area da cabine, o mesmo delta de altura que a cabine andou e' somado a' posicao
## dele. Os dois mecanismos convivem — o corpo animado continua impedindo que
## ele atravesse o chao, e a soma garante que ele nunca fique pra tras.
##
## Duas armadilhas que custaram caro e estao resolvidas aqui:
##
## 1. TWEEN NO QUADRO DE FISICA. Tween nasce rodando no quadro de IDLE. Mexer a
##    cabine por ali faz o `AnimatableBody3D` do chao TELEPORTAR entre dois
##    passos de fisica em vez de se MOVER: ele nao gera velocidade nenhuma, nao
##    empurra ninguem, e o jogador fica parado vendo a cabine subir sem ele.
##    Por isso todo tween daqui e' TWEEN_PROCESS_PHYSICS.
##
## 2. A AREA SOBE JUNTO. `area_dentro` e' filha da cabine, entao ela sobe com a
##    cabine. Se o jogador ficar pra tras um unico quadro, ele sai da area,
##    `_player_dentro` vira falso e a elevacao dele para de vez — o erro se
##    consolida em vez de se corrigir. Durante a viagem o passageiro fica
##    TRAVADO: quem entrou, viajou.

enum { PARADO, CHAMANDO, ABRINDO, ABERTO, FECHANDO, VIAJANDO }

const TEMPO_PORTA := 1.9
## Metros por segundo. 4,2 m de percurso a 0,55 m/s da' uns 8 segundos de
## viagem — lento de proposito, que foi o pedido: e' o tempo em que o jogador
## fica trancado numa caixa de metal sem saber o que tem la' em cima.
const VELOCIDADE := 0.55
const TRANCO := 0.45
## Quanto a folha corre pra abrir (metade do vao de 2,20 m).
const CURSO_FOLHA := 1.10
const ESPERA_ABERTA := 9.0

@onready var cabine: Node3D = $cabine
@onready var area_dentro: Area3D = $cabine/area_dentro

var estado: int = PARADO
var andar_atual: int = 1
var _cotas := {1: 0.0, 2: 4.2}
var _player: Node3D = null
var _player_dentro: bool = false
## Passageiro travado durante a viagem (ver a armadilha 2 no cabecalho).
var _viajando_com_player: bool = false
var _player_no_pavimento: int = 0
var _y_anterior: float = 0.0
var _espera: float = 0.0


func _ready() -> void:
	_cotas[1] = float(get_meta("andar_1", 0.0))
	_cotas[2] = float(get_meta("andar_2", 4.2))
	cabine.position.y = _cotas[1]
	_y_anterior = cabine.position.y

	area_dentro.body_entered.connect(_ao_entrar_na_cabine)
	area_dentro.body_exited.connect(_ao_sair_da_cabine)
	for andar in [1, 2]:
		var area: Area3D = get_node("pavimento_%d/area_chamar" % andar)
		area.body_entered.connect(_ao_chegar_no_pavimento.bind(andar))
		area.body_exited.connect(_ao_sair_do_pavimento.bind(andar))
	_portas_instantaneas(false)


func _physics_process(delta: float) -> void:
	# O jogador sobe junto com a cabine, quadro a quadro.
	var passo := cabine.position.y - _y_anterior
	var leva := _player_dentro or _viajando_com_player
	if absf(passo) > 0.0 and leva and is_instance_valid(_player):
		_player.global_position.y += passo
	_y_anterior = cabine.position.y

	if estado == ABERTO:
		_espera -= delta
		if _espera <= 0.0 and not _player_dentro:
			_fechar_portas()

	if estado != ABERTO and estado != PARADO:
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	if _player_dentro and estado == ABERTO:
		_viajar(2 if andar_atual == 1 else 1)
	elif _player_no_pavimento != 0 and estado == PARADO:
		_chamar(_player_no_pavimento)


# ==============================================================================
# CHAMADA E VIAGEM
# ==============================================================================

func _chamar(andar: int) -> void:
	if andar == andar_atual:
		_abrir_portas()
		return
	estado = CHAMANDO
	_mensagem("PROMPT_HOSP_ELEVADOR_VINDO", 2.4)
	await _mover_ate(andar)
	_abrir_portas()


func _viajar(destino: int) -> void:
	estado = FECHANDO
	GlobalUtils.hide_center_message(_id_prompt())
	await _animar_portas(false)
	await get_tree().create_timer(0.6).timeout
	await _mover_ate(destino)
	_abrir_portas()


## Leva a cabine ate' o andar, com o tranco de partida e o de chegada.
func _mover_ate(andar: int) -> void:
	estado = VIAJANDO
	_viajando_com_player = _player_dentro
	var alvo: float = _cotas[andar]
	var distancia := absf(alvo - cabine.position.y)
	if distancia < 0.01:
		andar_atual = andar
		return
	var tempo := distancia / VELOCIDADE

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	# Um solavanco curto antes de sair do lugar e outro na chegada. E' o que
	# faz a caixa parecer velha em vez de parecer um plano de camera.
	tween.tween_property(cabine, "position:y",
		cabine.position.y - signf(alvo - cabine.position.y) * 0.04, TRANCO * 0.4)
	tween.tween_property(cabine, "position:y", alvo, tempo)
	await tween.finished
	andar_atual = andar
	_viajando_com_player = false


# ==============================================================================
# PORTAS
# ==============================================================================

func _abrir_portas() -> void:
	estado = ABRINDO
	await _animar_portas(true)
	estado = ABERTO
	_espera = ESPERA_ABERTA
	_atualizar_prompt()


func _fechar_portas() -> void:
	estado = FECHANDO
	await _animar_portas(false)
	estado = PARADO
	_atualizar_prompt()


## Move as quatro folhas de uma vez: as duas da cabine e as duas do pavimento em
## que ela esta'. As do outro andar nao se mexem — a porta de pavimento sem
## cabine atras tem de continuar solida, senao o jogador cai no poco.
func _animar_portas(abrir: bool) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	for folha in _folhas_ativas():
		var lado := signf(folha.position.z)
		if is_zero_approx(lado):
			lado = 1.0
		var fechado: float = lado * CURSO_FOLHA * 0.5
		var destino: float = fechado + (lado * CURSO_FOLHA if abrir else 0.0)
		tween.tween_property(folha, "position:z", destino, TEMPO_PORTA)
	await tween.finished


func _portas_instantaneas(abertas: bool) -> void:
	for folha in _folhas_ativas():
		var lado := signf(folha.position.z)
		if is_zero_approx(lado):
			lado = 1.0
		folha.position.z = lado * CURSO_FOLHA * 0.5 \
			+ (lado * CURSO_FOLHA if abertas else 0.0)


func _folhas_ativas() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for nome in ["folha_n", "folha_s"]:
		lista.append(get_node("cabine/portas_cabine/" + nome))
		lista.append(get_node("pavimento_%d/%s" % [andar_atual, nome]))
	return lista


# ==============================================================================
# PROMPTS
# ==============================================================================

func _id_prompt() -> String:
	return "hosp_elevador"


func _mensagem(chave: String, duracao: float = 0.0) -> void:
	GlobalUtils.show_center_message(_id_prompt(), tr(chave), 16, duracao)


func _atualizar_prompt() -> void:
	if _player_dentro:
		if estado == ABERTO:
			_mensagem("PROMPT_HOSP_ELEVADOR_SUBIR" if andar_atual == 1
				else "PROMPT_HOSP_ELEVADOR_DESCER")
		return
	if _player_no_pavimento != 0 and estado == PARADO:
		_mensagem("PROMPT_HOSP_ELEVADOR_CHAMAR")
		return
	GlobalUtils.hide_center_message(_id_prompt())


func _ao_entrar_na_cabine(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player = body
	_player_dentro = true
	_atualizar_prompt()


func _ao_sair_da_cabine(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_dentro = false
	_atualizar_prompt()


func _ao_chegar_no_pavimento(body: Node3D, andar: int) -> void:
	if not _eh_player(body):
		return
	_player = body
	_player_no_pavimento = andar
	_atualizar_prompt()


func _ao_sair_do_pavimento(body: Node3D, andar: int) -> void:
	if not _eh_player(body) or _player_no_pavimento != andar:
		return
	_player_no_pavimento = 0
	_atualizar_prompt()


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
