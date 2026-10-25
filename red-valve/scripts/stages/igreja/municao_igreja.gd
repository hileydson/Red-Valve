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

var _perto := false
var _disponivel := true

@onready var modelo: Node3D = $modelo
@onready var area: Area3D = $area


func _ready() -> void:
	area.body_entered.connect(func(b): _ao_entrar(b))
	area.body_exited.connect(func(b): _ao_sair(b))


func _process(_delta: float) -> void:
	if not _disponivel or not _perto:
		return
	if GlobalEvents.in_cutscene or GlobalEvents.agarrao_rodando:
		return
	if Input.is_action_just_pressed("ui_accept"):
		_pegar()


func _ao_entrar(b: Node3D) -> void:
	if not b.is_in_group("player"):
		return
	_perto = true
	if _disponivel:
		GlobalUtils.show_center_message("municao_igreja_" + name, tr("PROMPT_TAKE_AMMO"), 16)


func _ao_sair(b: Node3D) -> void:
	if not b.is_in_group("player"):
		return
	_perto = false
	GlobalUtils.hide_center_message("municao_igreja_" + name)


func _pegar() -> void:
	_disponivel = false
	GlobalUtils.hide_center_message("municao_igreja_" + name)
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
	_disponivel = true
	if _perto:
		GlobalUtils.show_center_message("municao_igreja_" + name, tr("PROMPT_TAKE_AMMO"), 16)
