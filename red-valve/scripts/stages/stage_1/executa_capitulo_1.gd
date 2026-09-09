extends AnimationPlayer

## Cutscene de abertura do Capitulo 1 (nó "cutscene_primeira_vez" da stage_1).
const ANIM_INTRO := "intro"


func _ready() -> void:
	# Nada de autoplay: a intro só existe para a entrada no Capitulo 1, ou seja,
	# quando a stage_1 é carregada vindo do fim do prólogo
	# (GlobalEvents.entering_chapter_1). Voltar da casa do Jimmy, voltar da arena
	# ou carregar um save que já está no capítulo não devem repetir a cutscene.
	if not GlobalEvents.entering_chapter_1:
		return
	if GlobalEvents.voltando_da_casa_jimmy:
		return
	if not has_animation(ANIM_INTRO):
		return

	# stage_1.gd só roda o _ready dele depois dos filhos e zera GlobalEvents.in_cutscene
	# lá; adiar o play garante que a primeira key da animação (set_in_cutscene)
	# não seja apagada logo em seguida.
	play.call_deferred(ANIM_INTRO)


func set_in_cutscene()->void:
	GlobalEvents.set_in_cutscene()
func unset_in_cutscene()->void:
	GlobalEvents.unset_in_cutscene()
