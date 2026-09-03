extends CanvasLayer

@onready var resume: Button = $Control/VSplitContainer/resume
@onready var mapa_btn: Button = $Control/VSplitContainer/mapa

func _ready() -> void:
	self.visible = false
	
	# Configurar os sons de foco e clique para todos os botões do menu de pause
	for btn in $Control/VSplitContainer.get_children():
		if btn is Button:
			btn.focus_entered.connect(func(): GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/mudar_selecao.mp3"))
			btn.mouse_entered.connect(func(): btn.grab_focus())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if not self.visible and (get_tree().paused or GlobalEvents.in_cutscene):
			return # Não abre se já estiver pausado (ex: Inventário aberto) ou em cutscene
		toogle_pause()

func toogle_pause():
	if get_tree().paused:
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/sair_menu.mp3")
		get_tree().paused = false
		self.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/entrar_menu.mp3")
		get_tree().paused = true
		self.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# a aba do mapa só existe onde há mapa de cidade (hoje, o stage_1) e
		# com o Maycow normal — a mesma condição do minimapa do HUD
		mapa_btn.visible = _mapa_disponivel() != null
		resume.grab_focus()

func _on_resume_pressed() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
	get_tree().paused = false
	self.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_exit_pressed() -> void:
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item_voltar.mp3")
	GlobalUtils.force_clear_all_screen_messages()
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


## O nó do mapa se anuncia pelo grupo "mapa_cidade". Perguntar pelo grupo, e
## não pelo caminho da cena, evita amarrar o menu de pausa ao stage_1: se
## outra fase ganhar mapa, a aba aparece sozinha.
func _mapa_disponivel() -> Node:
	var m := get_tree().get_first_node_in_group("mapa_cidade")
	if m != null and m.has_method("pode_abrir_mapa") and m.pode_abrir_mapa():
		return m
	return null


func _on_mapa_pressed() -> void:
	var m := _mapa_disponivel()
	if m == null:
		return
	GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
	if not m.mapa_fechado.is_connected(_ao_fechar_mapa):
		m.mapa_fechado.connect(_ao_fechar_mapa)
	self.visible = false
	m.abrir_mapa()


func _ao_fechar_mapa() -> void:
	# volta para o menu, não para o jogo: quem fechou o mapa pediu o mapa,
	# não pediu para despausar
	if get_tree().paused:
		self.visible = true
		resume.grab_focus()
