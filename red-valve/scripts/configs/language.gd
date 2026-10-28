extends Node2D
@onready var english: Button = $Control/VSplitContainer/english
@onready var portuguese: Button = $Control/VSplitContainer/portuguese


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Verifica se já existe um jogo salvo para pular a tela de idioma
	if FileAccess.file_exists(SaveManager.CONFIG_PATH):
		# Pula direto para a introdução (as configurações já foram lidas no SaveManager)
		get_tree().change_scene_to_file("res://scenes/configs/intro_godot_video.tscn")
		return

	# Caso não exista save, foca no botão para o jogador escolher o idioma
	english.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_english_pressed() -> void:
	TranslationServer.set_locale("en_US")
	SaveManager.config["language"] = "en"
	SaveManager.save_config()
	get_tree().change_scene_to_file("res://scenes/configs/intro_godot_video.tscn")


func _on_portuguese_pressed() -> void:
	TranslationServer.set_locale("pt_BR")
	SaveManager.config["language"] = "pt"
	SaveManager.save_config()
	get_tree().change_scene_to_file("res://scenes/configs/intro_godot_video.tscn")
