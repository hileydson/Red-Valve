extends Node2D
@onready var english: Button = $Control/VSplitContainer/english
@onready var portuguese: Button = $Control/VSplitContainer/portuguese


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	english.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_english_pressed() -> void:
	TranslationServer.set_locale("en_US")
	get_tree().change_scene_to_file("res://scenes/configs/intro_pacoca_producoes.tscn")


func _on_portuguese_pressed() -> void:
	TranslationServer.set_locale("pt_BR")
	get_tree().change_scene_to_file("res://scenes/configs/intro_pacoca_producoes.tscn")
