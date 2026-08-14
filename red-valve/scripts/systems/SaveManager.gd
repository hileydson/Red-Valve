extends Node

const SAVE_PATH = "user://save_game.json"

var current_stage: String = ""
var inventory_normal: Array = []
var inventory_combat: Array = []
var equipped_items: Array = ["cogblade"] # Cogblade sempre equipada
var max_mp: float = 30.0
var current_mp: float = 30.0

var brightness_rect: ColorRect

var default_config = {
	"aim_mode": "hold",
	"language": "pt",
	"run_mode": "hold",
	"deadzone": 0.2,
	"sensitivity_look": 1.0,
	"sensitivity_aim": 0.4,
	"resolution": "1080p",
	"display_mode": "windowed",
	"brightness": 1.0
}

var config = default_config.duplicate()
var _last_applied_mode: String = ""
var _last_applied_resolution: String = ""

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
		"model_path": "res://assets/3d_model/player/Maycow Lopes/relogio.glb",
		"stackable": false,
		"type": "inspectable"
	},
	"pistol": {
		"name_key": "ITEM_PISTOL_NAME",
		"desc_key": "ITEM_PISTOL_DESC",
		"icon_path": "res://assets/images/menu/itens/red_valve/pistola.png",
		"stackable": false,
		"type": "equippable"
	},
	"cogblade": {
		"name_key": "ITEM_COGBLADE_NAME",
		"desc_key": "ITEM_COGBLADE_DESC",
		"icon_path": "res://assets/images/menu/itens/red_valve/cogblade.png",
		"stackable": false,
		"type": "equippable"
	},
	"pistol_ammo": {
		"name_key": "ITEM_AMMO_NAME",
		"desc_key": "ITEM_AMMO_DESC",
		"icon_path": "res://assets/images/menu/itens/red_valve/pistola_bala.png",
		"stackable": true,
		"type": "inspectable"
	}
}

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var canvas = CanvasLayer.new()
	canvas.layer = 125
	add_child(canvas)
	brightness_rect = ColorRect.new()
	brightness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brightness_rect.color = Color(0, 0, 0, 0)
	canvas.add_child(brightness_rect)
	
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
						for key in data["config"].keys():
							config[key] = data["config"][key]
						
	apply_configs()

func apply_configs() -> void:
	TranslationServer.set_locale(config["language"])
	
	var cur_mode = config.get("display_mode", "windowed")
	var cur_res = config.get("resolution", "1080p")
	
	var res_map = {
		"720p": Vector2i(1280, 720),
		"1080p": Vector2i(1920, 1080),
		"1440p": Vector2i(2560, 1440)
	}
	var target_res = res_map.get(cur_res, Vector2i(1920, 1080))
	
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_size = target_res
	
	if cur_mode != _last_applied_mode or cur_res != _last_applied_resolution:
		_last_applied_mode = cur_mode
		_last_applied_resolution = cur_res
		
		if cur_mode == "fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(target_res)
			var screen_size = DisplayServer.screen_get_size()
			var win_size = DisplayServer.window_get_size()
			DisplayServer.window_set_position((screen_size - win_size) / 2)
		
	var actions = ["ui_left", "ui_right", "ui_up", "ui_down", "ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down"]
	for action in actions:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, config["deadzone"])
			
	if is_instance_valid(brightness_rect):
		var b = clamp(config["brightness"], 0.1, 2.0)
		if b <= 1.0:
			brightness_rect.color = Color(0, 0, 0, 1.0 - b)
		else:
			brightness_rect.color = Color(1, 1, 1, (b - 1.0) * 0.5)

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
		"equipped_items": equipped_items,
		"max_mp": max_mp,
		"current_mp": current_mp,
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
				equipped_items = data.get("equipped_items", ["cogblade"])
				max_mp = data.get("max_mp", 30.0)
				current_mp = data.get("current_mp", 30.0)
				
				if data.has("config"):
					for key in data["config"].keys():
						config[key] = data["config"][key]
				apply_configs()
				
				if current_stage != "" and ResourceLoader.exists(current_stage):
					print("Game Loaded! ", current_stage)
					LoadingScreen.load_scene(current_stage)
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


func is_equipped(item_id: String) -> bool:
	return item_id in equipped_items

func equip_item(item_id: String) -> void:
	if not item_id in equipped_items:
		equipped_items.append(item_id)

func unequip_item(item_id: String) -> void:
	if item_id == "cogblade": return # Cogblade nao desequipa
	if item_id in equipped_items:
		equipped_items.erase(item_id)

var menu_instance = null
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu_game"):
		if get_tree().current_scene and (get_tree().current_scene.scene_file_path.contains("main_menu") or get_tree().current_scene.scene_file_path.contains("cutscene")):
			return # Não abre menu nessas telas
			
		if GlobalEvents.in_cutscene:
			return # Não abre menu durante a cutscene da oficina
			
		var players = get_tree().get_nodes_in_group("player")
		if players.size() == 0:
			return # Só abre o inventário se o Player estiver presente na cena
			
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
