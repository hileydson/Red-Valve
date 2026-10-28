extends Node3D

## Interior da casa do Jimmy.
##
## Mesma lógica da the_house (casa do Maycow): cena fechada, atmosfera pesada,
## e uma porta que devolve o jogador ao mapa. A diferença é que aqui a volta
## precisa cair no ponto exato em frente à casa lá no stage_1 — quem cuida
## disso é GlobalEvents.voltando_da_casa_jimmy, lido pelo stage_1 no spawn.

const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"

@onready var fade: ColorRect = $fade

var player_na_porta: bool = false
var _saindo: bool = false

## Lâmpadas com metadata "piscar"; cada uma guarda a energia original para o
## piscar oscilar em torno dela em vez de um valor fixo.
var _lampadas_piscando: Array[Dictionary] = []


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	# A poeira fina do ar é a mesma da the_house: partículas do próprio player.
	GlobalEvents.set_minimum_nevoa()

	# save_game() já toma o caminho da cena atual como checkpoint.
	SaveManager.save_game()

	_preparar_lampadas()


func _preparar_lampadas() -> void:
	for luz in $luzes.get_children():
		if not (luz is Light3D):
			continue
		if not luz.has_meta("piscar"):
			continue
		_lampadas_piscando.append({
			"luz": luz,
			"tipo": String(luz.get_meta("piscar")),
			"base": (luz as Light3D).light_energy,
			"proximo": 0.0,
		})


func _process(delta: float) -> void:
	_atualizar_lampadas(delta)

	if _saindo or GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return

	if player_na_porta and Input.is_action_just_pressed("ui_accept"):
		_sair_da_casa()


## Duas falhas diferentes: a "nervosa" é uma lâmpada velha que treme; a
## "quebrada" fica apagada e só dá estouros curtos de vez em quando.
func _atualizar_lampadas(delta: float) -> void:
	for lamp in _lampadas_piscando:
		var luz: Light3D = lamp["luz"]
		if not is_instance_valid(luz):
			continue
		lamp["proximo"] -= delta
		if lamp["proximo"] > 0.0:
			continue
		if lamp["tipo"] == "nervoso":
			luz.light_energy = lamp["base"] * randf_range(0.55, 1.15)
			lamp["proximo"] = randf_range(0.04, 0.18)
		else:
			var acesa := randf() < 0.12
			luz.light_energy = lamp["base"] * (randf_range(0.9, 1.6) if acesa else 0.0)
			lamp["proximo"] = randf_range(0.05, 0.35) if acesa else randf_range(0.6, 3.2)


func _sair_da_casa() -> void:
	_saindo = true
	player_na_porta = false
	GlobalEvents.in_cutscene = true
	GlobalUtils.hide_center_message("interacao_casa_jimmy")

	# Marca a volta antes de trocar de cena: o stage_1 usa isto para pôr o
	# jogador de volta na porta, e não no spawn padrão do mapa.
	GlobalEvents.voltando_da_casa_jimmy = true

	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	LoadingScreen.load_scene(CENA_MAPA)


func _ao_entrar_na_porta(body: Node3D) -> void:
	if not _eh_player(body):
		return
	player_na_porta = true
	GlobalUtils.show_center_message("interacao_casa_jimmy", tr("PROMPT_LEAVE_HOUSE"), 16)


func _ao_sair_da_porta(body: Node3D) -> void:
	if not _eh_player(body):
		return
	player_na_porta = false
	GlobalUtils.hide_center_message("interacao_casa_jimmy")


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
