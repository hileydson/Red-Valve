extends Node

const SAVE_PATH = "user://save_game.json"

var current_stage: String = ""
var inventory_normal: Array = []
var inventory_combat: Array = []

var config = {
	"aim_mode": "hold",
	"language": "pt"
}

var inventory: Array:
	get:
		if GlobalEvents.is_maycow_normal:
			return inventory_normal
		else:
			return inventory_combat
	set(val):
		if GlobalEvents.is_maycow_normal:
			inventory_normal = val
		else:
			inventory_combat = val

var item_db = {
	"maycow_watch": {
		"name_key": "ITEM_MAYCOW_WATCH_NAME",
		"desc_key": "ITEM_MAYCOW_WATCH_DESC",
		"icon_path": "res://assets/images/menu/itens/relogio.png",
		"stackable": false
	},
	"pistol": {
		"name_key": "ITEM_PISTOL_NAME",
		"desc_key": "ITEM_PISTOL_DESC",
		"icon_path": "res://assets/images/menu/itens/red_valve/pistola.png",
		"stackable": false
	},
	"cogblade": {
		"name_key": "ITEM_COGBLADE_NAME",
		"desc_key": "ITEM_COGBLADE_DESC",
		"icon_path": "res://assets/images/menu/itens/red_valve/cogblade.png",
		"stackable": false
	},
	"pistol_ammo": {
		"name_key": "ITEM_AMMO_NAME",
		"desc_key": "ITEM_AMMO_DESC",
		"icon_path": "res://assets/images/menu/itens/red_valve/pistola_bala.png",
		"stackable": true
	}
}

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	if inventory_normal.is_empty():
		inventory_normal.append({"id": "maycow_watch", "amount": 1})
	if inventory_combat.is_empty():
		inventory_combat.append({"id": "pistol", "amount": 1})
		inventory_combat.append({"id": "cogblade", "amount": 1})
		inventory_combat.append({"id": "pistol_ammo", "amount": 25})
		
	# Lê silenciosamente o save no boot para não apagar dados ao salvar apenas configs depois
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(content) == OK:
				var data = json.get_data()
				if typeof(data) == TYPE_DICTIONARY:
					current_stage = data.get("current_stage", "")
					if data.has("config"):
						config = data["config"]
						
	TranslationServer.set_locale(config["language"])

func save_game(scene_path: String = ""):
	var temp_stage = current_stage
	
	if scene_path != "":
		temp_stage = scene_path
	elif get_tree().current_scene and not get_tree().current_scene.scene_file_path.contains("main_menu"):
		temp_stage = get_tree().current_scene.scene_file_path
		
	# Atualiza a variavel global se for valida
	if temp_stage != "":
		current_stage = temp_stage
		
	var save_data = {
		"current_stage": current_stage,
		"inventory_normal": inventory_normal,
		"inventory_combat": inventory_combat,
		"config": config
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game/Config Saved! Stage: ", current_stage)

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
				inventory_normal = data.get("inventory_normal", [{"id": "maycow_watch", "amount": 1}])
				inventory_combat = data.get("inventory_combat", [
					{"id": "pistol", "amount": 1},
					{"id": "cogblade", "amount": 1},
					{"id": "pistol_ammo", "amount": 25}
				])
				
				if data.has("config"):
					config = data["config"]
				TranslationServer.set_locale(config["language"])
				
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

func get_item_amount(item_id: String) -> int:
	for item in inventory:
		if item["id"] == item_id:
			return item["amount"]
	return 0

func remove_item_amount(item_id: String, amount: int) -> void:
	for i in range(inventory.size()):
		if inventory[i]["id"] == item_id:
			inventory[i]["amount"] -= amount
			if inventory[i]["amount"] < 0:
				inventory[i]["amount"] = 0
			return

var menu_instance = null
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu_game"):
		if get_tree().current_scene and (get_tree().current_scene.scene_file_path.contains("main_menu") or get_tree().current_scene.scene_file_path.contains("cutscene")):
			return # Não abre menu nessas telas
			
		if GlobalEvents.in_cutscene:
			return # Não abre menu durante a cutscene da oficina
			
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
