extends Node

func _ready() -> void:
	SaveManager.current_slot = 9
	var ex = load("res://tools/teste_historia/executor.gd").new()
	ex.name = "ExecutorHistoria"
	get_tree().root.add_child.call_deferred(ex)
