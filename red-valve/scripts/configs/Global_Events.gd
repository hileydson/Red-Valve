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
		
