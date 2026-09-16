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
const TEMPO_ABRIR := 0.55
const TEMPO_FECHAR := 0.85
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
	if Input.is_action_just_pressed("ui_accept"):
		_acionar()


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
func _abrir() -> void:
	var sinal := 1.0
	if is_instance_valid(_player):
		sinal = -1.0 if to_local(_player.global_position).z > 0.0 else 1.0
	_girar(-ABERTURA * sinal, TEMPO_ABRIR)
	aberta = true
	_conta_regressiva = ESPERA_FECHAR
	_atualizar_prompt()


func _fechar() -> void:
	_girar(0.0, TEMPO_FECHAR)
	aberta = false
	_atualizar_prompt()


func _girar(angulo: float, tempo: float) -> void:
	_mexendo = true
	var tween := create_tween()
	tween.set_parallel(true)
	# No quadro de física: a folha é um AnimatableBody3D, e corpo animado movido
	# no quadro de idle teleporta em vez de se mover — atravessa o jogador em
	# vez de empurrá-lo.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(pivo, "rotation:y", angulo, tempo)
	if pivo_b:
		tween.tween_property(pivo_b, "rotation:y", PI - angulo, tempo)
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
	if aberta:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_ESC_FECHAR"), 16)
		return
	# O nome da sala entra traduzido dentro da frase traduzida: as duas pontas
	# vêm do CSV, então "Abrir — Sala 103" e "Open — Classroom 103" saem certos
	# sem nenhum texto solto no código.
	var sala := String(get_meta("sala", "ESC_SALA_GENERICA"))
	GlobalUtils.show_center_message(
		_id_msg, tr("PROMPT_ESC_ABRIR").format({"sala": tr(sala)}), 16)


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
