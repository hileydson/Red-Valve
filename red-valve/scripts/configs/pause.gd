extends CanvasLayer

@onready var resume: Button = $Control/VSplitContainer/resume
@onready var salvar: Button = $Control/VSplitContainer/salvar

## A cena onde salvar a posicao exata faz sentido: so o mapa da cidade.
const CENA_STAGE_1 := "res://scenes/stages/stage_1/stage_1.tscn"

var _aviso_salvo: Label

func _ready() -> void:
	self.visible = false
	
	# Configurar os sons de foco e clique para todos os botões do menu de pause
	for btn in $Control/VSplitContainer.get_children():
		if btn is Button:
			btn.focus_entered.connect(func(): GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3"))
			btn.mouse_entered.connect(func(): btn.grab_focus())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if not self.visible and (get_tree().paused or GlobalEvents.in_cutscene):
			return # Não abre se já estiver pausado (ex: Inventário aberto) ou em cutscene
		toogle_pause()
		get_viewport().set_input_as_handled()
	elif self.visible and (event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed)):
		toogle_pause()
		get_viewport().set_input_as_handled()

func toogle_pause():
	if get_tree().paused:
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/sair_menu.mp3")
		get_tree().paused = false
		self.visible = false
		# O B que fechou o menu é o mesmo botão do dash: sem isto o Maycow sai
		# em disparada ao despausar.
		GlobalEvents.bloquear_dash_por()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/entrar_menu.mp3")
		get_tree().paused = true
		self.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_atualiza_botao_salvar()
		resume.grab_focus()

func _on_resume_pressed() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
	get_tree().paused = false
	self.visible = false
	GlobalEvents.bloquear_dash_por()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_exit_pressed() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
	# Também limpa a cena que fica pausada por trás da arena do amuleto
	GlobalUtils.cleanup_gameplay_leftovers()
	self.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# NÃO despausa antes de trocar de cena: enquanto a árvore está pausada, os inimigos
	# (cujo _physics_process respeita a pausa) não processam física durante a troca de
	# cena. Despausar antes fazia com que, no instante de destruir/trocar a cena, os
	# inimigos perdessem o chão por um frame, caíssem abaixo de y=-10 e disparassem o
	# "fall death" de todos de uma vez, somando Iron Rusks indevidamente. A cena do menu
	# principal já garante despausar no seu _ready().
	get_tree().change_scene_to_file("res://scenes/configs/main_menu_v2.tscn")

func _on_config_pressed() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	var config_script = load("res://scripts/ui/config_menu.gd")
	if config_script:
		var config_menu = config_script.new()
		get_parent().add_child(config_menu)
		self.visible = false
		
		# Certificar de que toca som ao voltar das config no pause menu (se possível)
		# Normalmente config_menu_voltar emitirá som por conta do script do config menu, 
		# mas caso precise, aqui seria reconectado.


## O botao "Salvar" fica sempre visivel, mas so clicavel fora do prologo, dentro do
## mapa da cidade e com o Maycow normal (o de combate nao salva posicao).
func pode_salvar() -> bool:
	if not SaveManager.prolog_finished:
		return false
	if not GlobalEvents.is_maycow_normal:
		return false
	var cena := get_tree().current_scene
	if not is_instance_valid(cena) or cena.scene_file_path != CENA_STAGE_1:
		return false
	return _pega_player() != null


func _pega_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p is Node3D:
			return p
	return null


func _atualiza_botao_salvar() -> void:
	if is_instance_valid(salvar):
		salvar.disabled = not pode_salvar()
	if is_instance_valid(_aviso_salvo):
		_aviso_salvo.visible = false


func _on_salvar_pressed() -> void:
	if not pode_salvar():
		return
	var player := _pega_player()
	if player == null:
		return
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	SaveManager.save_player_position(player.global_position, player.global_rotation.y)
	_mostra_aviso_salvo()


func _mostra_aviso_salvo() -> void:
	if not is_instance_valid(_aviso_salvo):
		_aviso_salvo = Label.new()
		_aviso_salvo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_aviso_salvo.add_theme_font_size_override("font_size", 20)
		_aviso_salvo.add_theme_constant_override("outline_size", 4)
		_aviso_salvo.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_aviso_salvo.offset_top = 60.0
		_aviso_salvo.offset_bottom = 100.0
		_aviso_salvo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aviso_salvo.text = "TXT_GAME_SAVED"
		add_child(_aviso_salvo)
	_aviso_salvo.visible = true
