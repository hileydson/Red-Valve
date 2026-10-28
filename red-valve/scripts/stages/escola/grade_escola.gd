extends Node3D

## A grade que atravessa o corredor sul da escola.
##
## Ela não abre, e não tem como abrir: é barra soldada de parede a parede, com
## corrente e cadeado. O caminho para o outro lado é o buraco no fundo do
## depósito.
##
## Este script existe só para o AVISO. Sem ele, o jogador chega numa grade,
## aperta o botão de interagir, não acontece nada, e a leitura é "bug" — não é
## "procure outro caminho". Uma frase resolve, e ela é a única pista explícita
## que esta fase dá.
##
## A área é generosa (4 m) e não justa como a de porta: aqui não existe outro
## prompt por perto para brigar com ela, e o que se quer é que ele leia "não
## passa" ANTES de encostar o nariz na barra.

@onready var area: Area3D = $area

const ID_MSG := "escola_grade"

var _player_perto: bool = false
## Depois de o jogador já ter atravessado uma vez, a grade deixa de ser um
## problema e o aviso vira ruído — ele passa a ver a mensagem toda vez que
## anda pelo corredor sul, que agora é caminho normal.
var _ja_resolvido: bool = false


func _ready() -> void:
	area.body_entered.connect(_ao_entrar)
	area.body_exited.connect(_ao_sair)


func _process(_delta: float) -> void:
	if not _player_perto or _ja_resolvido:
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return
	if Input.is_action_just_pressed("ui_accept"):
		GlobalUtils.show_center_message(ID_MSG, tr("PROMPT_ESC_GRADE_TENTAR"),
			16, 2.4)


func _ao_entrar(body: Node3D) -> void:
	if not _eh_player(body):
		return
	# Quem já destrancou o portão do pátio passou pelo porão, e portanto já
	# entendeu a grade. Daí em diante ela é só cenário.
	_ja_resolvido = GlobalEvents.escola_portao_destrancado
	_player_perto = true
	if not _ja_resolvido:
		GlobalUtils.show_center_message(ID_MSG, tr("PROMPT_ESC_GRADE"), 16)


func _ao_sair(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_perto = false
	GlobalUtils.hide_center_message(ID_MSG)


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
