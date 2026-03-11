extends Node

const language_pt_br = "PT-BR"
const language_en = "EN"

# data to be saved
var can_load:bool = false
var in_cutscene:bool = false
var save_array = {}
var default_language:String = language_pt_br

var game_weapon_events = {taken_pistol=false, taken_smg=false, taken_cogblade=false, taken_magic_hand_1=false}

func _process(delta: float) -> void:
	pass #print(back_caminho_das_pedras)


# EVENTOS DE TEMPO
# emite sinal de nevoa, sendo maior que 0 aplica, se for 0 para
func set_minimum_nevoa() -> void:
	_set_nevoa(500)

func set_low_nevoa() -> void:
	_set_nevoa(1000)

func set_high_nevoa() -> void:
	_set_nevoa(5000)

func _set_nevoa(amount:int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	player.get_node("nevoa").emitting = true
	player.get_node("nevoa").amount = amount
	
func stop_nevoa() -> void:
	var player = get_tree().get_first_node_in_group("player")
	player.get_node("nevoa").emitting = false

func save_progress(fase:String)->void:
	save_array = {}
	save_array["default_language"] = default_language
	save_array["game_weapon_events"] = game_weapon_events
	
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE) 
	var json_string = JSON.stringify(save_array) 
	file.store_line(json_string)

func check_load():
	if FileAccess.file_exists("user://savegame.save"): 
		can_load = true
	
	return can_load
	
		
func load_progress()->void:
	
	if FileAccess.file_exists("user://savegame.save"): 
		can_load = true
		var file = FileAccess.open("user://savegame.save", FileAccess.READ) 
		var json_string = file.get_as_text() 
		save_array = JSON.parse_string(json_string)
		
		default_language = save_array["default_language"]
		game_weapon_events = save_array["game_weapon_events"]
		
		get_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1.tscn")
		
