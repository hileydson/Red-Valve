extends Node3D

## Um buraco: o rombo na parede da escola, ou a boca da rampa no porão.
##
## É o MESMO script nas duas cenas, e isso é de propósito. As duas pontas do
## túnel fazem exatamente a mesma coisa — acender um prompt e pedir à cena que
## troque de lugar —, e quem sabe o que "trocar de lugar" significa é a cena,
## não o buraco. Dois scripts quase iguais é como se perde a simetria da ida e
## da volta: um deles ganha uma correção e o outro não.
##
## O acordo com a cena é um método só:
##
##     escola.gd →  usar_buraco("buraco_entrada" | "buraco_saida")
##     porao.gd  →  usar_buraco("boca_entrada"   | "boca_saida")
##
## `metadata/papel` diz qual é, e o gerador é quem escreve isso.
##
## O túnel é de MÃO DUPLA: dá para descer pelo depósito e voltar pelo mesmo
## lugar. Um buraco de mão única viraria armadilha — quem descesse sem lanterna
## ficaria preso no escuro sem poder voltar.

## Chave de tradução do prompt de cada papel.
const PROMPTS := {
	"buraco_entrada": "PROMPT_ESC_BURACO_ENTRAR",
	"buraco_saida": "PROMPT_ESC_BURACO_VOLTAR",
	"boca_entrada": "PROMPT_POR_SUBIR_DEPOSITO",
	"boca_saida": "PROMPT_POR_SUBIR_ALMOX",
}

@onready var area: Area3D = $area

var _papel: String = ""
var _id_msg: String = ""
var _player_perto: bool = false
var _usado: bool = false


func _ready() -> void:
	_papel = String(get_meta("papel", ""))
	_id_msg = "buraco_" + _papel
	area.body_entered.connect(_ao_entrar)
	area.body_exited.connect(_ao_sair)


func _process(_delta: float) -> void:
	if not _player_perto or _usado:
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return
	if Input.is_action_just_pressed("ui_accept"):
		_acionar()


func _acionar() -> void:
	var dono := owner if owner else get_parent()
	if dono == null or not dono.has_method("usar_buraco"):
		return
	# Trava local além da trava da cena: o fade dura dois segundos e, sem isto,
	# sair e entrar da área nesse intervalo reacenderia o prompt por cima da
	# tela já escurecendo.
	_usado = true
	_player_perto = false
	GlobalUtils.hide_center_message(_id_msg)
	dono.usar_buraco(_papel)


func _ao_entrar(body: Node3D) -> void:
	if not _eh_player(body) or _usado:
		return
	_player_perto = true
	GlobalUtils.show_center_message(
		_id_msg, tr(PROMPTS.get(_papel, "PROMPT_ESC_BURACO_ENTRAR")), 16)


func _ao_sair(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_perto = false
	GlobalUtils.hide_center_message(_id_msg)


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
