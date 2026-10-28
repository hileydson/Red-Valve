extends "res://scripts/player/player_mira_granola.gd"

## A MIRA DA VISAO DO AMULETO: os mesmos dois circulos da Granola, em roxo.
##
## Com a visao aberta (segurar `ui_amuleto`), um inimigo que passa pelo miolo
## da tela prende a mira: ela sai do centro, gruda nele e pisca com um bipe
## mais baixo e mais macio que o da Granola. E' esse o inimigo que o gatilho
## marca (`player_amulet.gd` pergunta `alvo_travado()` antes do raio do
## centro). Marcado, ele sai da lista de quem a mira procura — ela solta, volta
## pro meio e vai atras do proximo ainda nao selecionado.

const COR_AMULETO := Color(0.7, 0.3, 1.0)


func _ready() -> void:
	super._ready()
	cor_da_mira = COR_AMULETO
	_bip.volume_db = -27.0
	_bip.pitch_scale = 0.82
	_trava.volume_db = -21.0
	_trava.pitch_scale = 0.88


func _process(delta: float) -> void:
	super._process(delta)
	# a mira quadrada antiga da visao: esta toma o lugar dela
	if ativa and is_instance_valid(player.amulet_crosshair):
		player.amulet_crosshair.visible = false


func _deve_aparecer() -> bool:
	if not is_instance_valid(player) or not GlobalEvents.is_maycow_normal:
		return false
	if GlobalEvents.in_cutscene or player._cutscene_hud_hidden:
		return false
	if player.has_method("are_cutscene_inputs_blocked") and player.are_cutscene_inputs_blocked():
		return false
	return player.amulet_magic_active and player.is_first_person


## So' quem ainda nao foi selecionado, e dentro do alcance da selecao do
## amuleto.
func _vivo(no) -> bool:
	if not super._vivo(no):
		return false
	if player.amulet_selected_enemies.has(no):
		return false
	var amuleto = player.get_node_or_null("PlayerAmulet")
	var alcance: float = amuleto.MIRA_DIST_MAX if amuleto else ALCANCE
	return player.global_position.distance_to((no as Node3D).global_position) <= alcance
