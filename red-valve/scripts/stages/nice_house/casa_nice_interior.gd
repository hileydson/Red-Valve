extends Node3D

const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"

@onready var fade: ColorRect = $fade

var player_na_porta := false
var _saindo := false
var _lampadas: Array[Dictionary] = []


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()
	# as escritas dela (paredes, bilhete) dizem a chave do CSV na metadata
	for escrita in find_children("*", "Label3D", false, false):
		if escrita.has_meta("chave"):
			escrita.text = tr(String(escrita.get_meta("chave")))
	SaveManager.save_game()
	for luz in $luzes.get_children():
		if luz is OmniLight3D and luz.has_meta("piscar"):
			_lampadas.append({"luz": luz, "base": luz.light_energy, "tempo": 0.0})


func _process(delta: float) -> void:
	for lampada in _lampadas:
		lampada["tempo"] -= delta
		if lampada["tempo"] <= 0.0:
			lampada["luz"].light_energy = lampada["base"] * randf_range(0.55, 1.12)
			lampada["tempo"] = randf_range(0.08, 0.25)
	if _saindo or GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return
	if player_na_porta and Input.is_action_just_pressed("ui_accept"):
		_sair_da_casa()


func _sair_da_casa() -> void:
	_saindo = true
	player_na_porta = false
	GlobalEvents.in_cutscene = true
	GlobalUtils.hide_center_message("interacao_casa_nice")
	GlobalEvents.voltando_da_casa_nice = true
	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	LoadingScreen.load_scene(CENA_MAPA)


func _ao_entrar_na_porta(body: Node3D) -> void:
	if not _eh_player(body):
		return
	player_na_porta = true
	GlobalUtils.show_center_message("interacao_casa_nice", tr("PROMPT_LEAVE_HOUSE"), 16)


func _ao_sair_da_porta(body: Node3D) -> void:
	if not _eh_player(body):
		return
	player_na_porta = false
	GlobalUtils.hide_center_message("interacao_casa_nice")


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
