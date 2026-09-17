extends Node

## OS ATALHOS DO DIRECIONAL — trocar o item equipado sem abrir o menu.
##
## Existe por causa de uma regra: o Maycow normal só carrega UM equipável por vez
## (`SaveManager.EQUIPAMENTO_EXCLUSIVO`), porque amuleto e pistola disputam o
## mesmo botão de mira. Sem um atalho, trocar de um para o outro no meio da rua
## custaria abrir o menu, achar o item, abrir o menu de ação e equipar — quatro
## passos para uma decisão que o jogo pede no susto.
##
## Quem AMARRA o item a uma direção é o menu (aba inventário > ação "Atalho").
## Aqui só se lê o que foi amarrado.
##
## ==========================================================================
## POR QUE AÇÕES NOVAS, E NÃO `ui_left`/`ui_right`
##
## As ações de direção deste projeto são de MOVIMENTO: `ui_left` junta o D-pad,
## o analógico esquerdo, o A e a seta do teclado. Usar elas aqui faria o Maycow
## trocar de item toda vez que andasse de lado.
##
## Por isso `ui_atalho_*` são ações próprias, e propositalmente estreitas:
##   - no controle, SÓ o D-pad (o analógico continua sendo andar);
##   - no teclado, SÓ o teclado numérico 4/8/6/2, que é o único direcional que
##     não está em uso (as setas também andam).

const DIRECOES := {
	"ui_atalho_esquerda": "esquerda",
	"ui_atalho_cima": "cima",
	"ui_atalho_direita": "direita",
	"ui_atalho_baixo": "baixo",
}

## Tempo que a mensagem de "Equipado: X" fica na tela.
const TEMPO_AVISO := 1.6

var player: CharacterBody3D


func _ready() -> void:
	player = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or GlobalEvents.in_cutscene:
		return
	if not is_instance_valid(player) or player.are_cutscene_inputs_blocked():
		return
	# No meio do ultimate da cogblade a tela é toda dela: trocar de item ali
	# deixaria o jogador sem entender o que aconteceu.
	if player.is_using_ultimate or player.camera_bullet_time_ON:
		return

	for acao in DIRECOES.keys():
		if event.is_action_pressed(acao):
			get_viewport().set_input_as_handled()
			_equipar_do_atalho(String(DIRECOES[acao]))
			return


func _equipar_do_atalho(direcao: String) -> void:
	var item_id := SaveManager.item_do_atalho(direcao)
	if item_id == "":
		return
	# Atalho para item que ele não tem (ou perdeu) não faz nada — nem barulho de
	# erro: o atalho pode ter sido criado para um item de mais adiante no jogo.
	if not SaveManager.tem_item(item_id):
		return
	if SaveManager.is_equipped(item_id):
		return

	SaveManager.equip_item(item_id)
	SaveManager.save_game()

	if is_instance_valid(player):
		player.update_ammo_ui()
		player.update_equipment_visuals()

	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	var nome := tr(String(SaveManager.item_db.get(item_id, {}).get("name_key", "")))
	GlobalUtils.show_center_message("atalho_equipado",
		tr("SHORTCUT_EQUIPPED") % nome, 18, TEMPO_AVISO)
