extends Node3D

## Caixa de municao da pistola largada num banco da igreja, durante a luta.
##
## As duas fases da Dona Nice pedem ~60 tiros e o jogador pode chegar com o
## pente quase vazio. Diferente do balcao do hospital (pickup unico, gravado
## no save), estas REAPARECEM: pegou, some, e volta `REAPARECE` segundos
## depois — a luta nunca trava por falta de bala. Quem cria e apaga e' o
## `evento_dona_nice.gd`; fora da luta elas nao existem.

const ITEM := "pistol_ammo"
const QUANTIDADE := 12
const REAPARECE := 22.0
## Selecao (realce, prompt e sons) igual a de todo item de cenario.
const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")

var _selecao: Node

@onready var modelo: Node3D = $modelo
@onready var area: Area3D = $area


func _ready() -> void:
	_selecao = ItemSelecionavel.new()
	add_child(_selecao)
	_selecao.configurar(modelo, area, "PROMPT_TAKE_AMMO")
	_selecao.pegar.connect(_pegar)


func _pegar() -> void:
	SaveManager.add_item(ITEM, QUANTIDADE)
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador and jogador.has_method("update_ammo_ui"):
		jogador.update_ammo_ui()
	var nome := tr(String(SaveManager.item_db.get(ITEM, {}).get("name_key", "")))
	GlobalUtils.show_center_message("pegou_municao_igreja",
		tr("PICKUP_AMMO_AGAIN") % [QUANTIDADE, nome], 18, 2.0)
	modelo.visible = false
	await get_tree().create_timer(REAPARECE, false).timeout
	if not is_instance_valid(self):
		return
	modelo.visible = true
	_selecao.disponivel = true
