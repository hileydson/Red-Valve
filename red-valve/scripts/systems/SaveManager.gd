extends Node

const SAVE_PATH = "user://save_game.json"

var current_stage: String = ""
var inventory: Array = []

var item_db = {
	"maycow_watch": {
		"name_key": "ITEM_MAYCOW_WATCH_NAME",
		"desc_key": "ITEM_MAYCOW_WATCH_DESC",
		"icon_path": "res://assets/images/menu/itens/relogio.png",
		"stackable": false
	}
}

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	if inventory.is_empty():
		add_item("maycow_watch")

func save_game(scene_path: String = ""):
	if scene_path != "":
		current_stage = scene_path
	elif get_tree().current_scene:
		current_stage = get_tree().current_scene.scene_file_path
		
	# Só salva se tivermos um stage válido
	if current_stage == "" or current_stage.contains("main_menu"):
		return
		
	var save_data = {
		"current_stage": current_stage,
		"inventory": inventory
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game Saved! ", current_stage)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				current_stage = data.get("current_stage", "")
				inventory = data.get("inventory", [])
				
				if current_stage != "" and ResourceLoader.exists(current_stage):
					print("Game Loaded! ", current_stage)
					get_tree().change_scene_to_file(current_stage)
					return true
	return false

func add_item(item_id: String, amount: int = 1):
	if not item_db.has(item_id): return
	
	if item_db[item_id]["stackable"]:
		var found = false
		for item in inventory:
			if item["id"] == item_id:
				item["amount"] += amount
				found = true
				break
		if not found:
			inventory.append({"id": item_id, "amount": amount})
	else:
		var found = false
		for item in inventory:
			if item["id"] == item_id:
				found = true
				break
		if not found:
			inventory.append({"id": item_id, "amount": 1})

var menu_instance = null
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu_game"):
		if get_tree().current_scene and get_tree().current_scene.scene_file_path.contains("main_menu"):
			return # Não abre menu no main menu
			
		if menu_instance == null or not is_instance_valid(menu_instance):
			if get_tree().paused:
				return # Não abre se o jogo já estiver pausado (ex: Pause menu)
				
			var menu_script = load("res://scripts/ui/in_game_menu.gd")
			if menu_script:
				menu_instance = menu_script.new()
				get_tree().root.add_child(menu_instance)
		else:
			# O próprio script do menu fechará e chamará queue_free()
			pass
