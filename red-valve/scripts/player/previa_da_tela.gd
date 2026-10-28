@tool
extends Camera3D

## A origem desta camera E a origem do olho em jogo. Nao ha enquadramento
## inverso: a cena e as animacoes sao as mesmas nos dois lugares.
## Selecione o rig para escolher arma, acao e instante; ou use AnimationPlayer.
@export var arma := "shotgun":
	set(valor):
		arma = valor
		if Engine.is_editor_hint() and is_inside_tree():
			var rig := get_parent().get_node_or_null("rig")
			if rig != null:
				rig.arma_previa = valor

func _validate_property(propriedade: Dictionary) -> void:
	if propriedade.name != "arma" or not is_inside_tree(): return
	var rig := get_parent().get_node_or_null("rig")
	if rig == null: return
	var grupo := rig.get_node_or_null("Armas")
	if grupo == null: return
	var ids := PackedStringArray()
	for no in grupo.get_children():
		if "item_id" in no: ids.append(no.item_id)
	propriedade.hint = PROPERTY_HINT_ENUM
	propriedade.hint_string = ",".join(ids)
