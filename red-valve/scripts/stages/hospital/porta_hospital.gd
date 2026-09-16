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
const TEMPO_ABRIR := 0.55
const TEMPO_FECHAR := 0.85
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
	if Input.is_action_just_pressed("ui_accept"):
		_acionar()


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
	# No quadro de fisica: a folha e' um AnimatableBody3D, e corpo animado
	# movido no quadro de idle teleporta em vez de se mover — atravessa o
	# jogador em vez de empurra-lo.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(pivo, "rotation:y", angulo, tempo)
	if pivo_b:
		# a segunda folha nasce virada 180 graus, entao o angulo dela e' o
		# simetrico — com o mesmo sinal as duas iam pra lados opostos
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
	if _trancada:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_HOSP_TRANCADA"), 16)
		return
	if _saida:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_HOSP_SAIR"), 16)
		return
	if aberta:
		GlobalUtils.show_center_message(_id_msg, tr("PROMPT_HOSP_FECHAR"), 16)
		return
	# O nome da sala entra traduzido dentro da frase traduzida: as duas pontas
	# vem do CSV, entao "Abrir — Quarto 103" e "Open — Room 103" saem certos
	# sem nenhum texto solto no codigo.
	var sala := String(get_meta("sala", "HOSP_SALA_GENERICA"))
	GlobalUtils.show_center_message(
		_id_msg, tr("PROMPT_HOSP_ABRIR").format({"sala": tr(sala)}), 16)


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
