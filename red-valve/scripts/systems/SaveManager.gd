extends Node

const CONFIG_PATH = "user://config.json"
var current_slot: int = 1

func get_save_path(slot_index: int = -1) -> String:
	if slot_index == -1:
		slot_index = current_slot
	return "user://save_game_" + str(slot_index) + ".json"

var current_stage: String = ""
var inventory_normal: Array = []
var inventory_combat: Array = []
var equipped_items: Array = ["cogblade"] # Cogblade sempre equipada
var max_mp: float = 30.0
var current_mp: float = 30.0
var prolog_finished: bool = false
var battlefield_1_intro_played: bool = false
var stage_1_intro_played: bool = false
var iron_rusks: int = 0
var iron_rusks_pending: int = 0 # Ganho na luta atual, ainda não somado visualmente no HUD
var iron_rusks_display: int = 0 # Valor mostrado no canto da tela, só sobe com a animação de tally

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
	iron_rusks_display = iron_rusks
	
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
		
	# Lê apenas as configurações globais
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(content) == OK:
				var data = json.get_data()
				if typeof(data) == TYPE_DICTIONARY:
					for key in data.keys():
						config[key] = data[key]
	apply_configs()

func save_config() -> void:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config))
		file.close()

func is_window_embedded() -> bool:
	if Engine.has_method("is_embedded_in_editor") and Engine.is_embedded_in_editor():
		return true
	var win = get_window() if has_method("get_window") else null
	if win:
		if win.has_method("is_embedded") and win.is_embedded():
			return true
		if win.has_method("get_embedder") and win.get_embedder() != null:
			return true
	if get_tree() and get_tree().root:
		if get_tree().root.has_method("is_embedded") and get_tree().root.is_embedded():
			return true
		if get_tree().root.has_method("get_embedder") and get_tree().root.get_embedder() != null:
			return true
	return false

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
	
	var res_scale_map = {
		"720p": 0.5,
		"1080p": 1.0,
		"1440p": 1.5
	}
	var scale_3d = res_scale_map.get(cur_res, 1.0)
	
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_size = Vector2i(1920, 1080)
		get_tree().root.scaling_3d_scale = scale_3d
	
	if cur_mode != _last_applied_mode or cur_res != _last_applied_resolution:
		_last_applied_mode = cur_mode
		_last_applied_resolution = cur_res
		
		if not is_window_embedded():
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

func get_slots_info() -> Array:
	var info = []
	for i in range(1, 4):
		var path = get_save_path(i)
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				var json = JSON.new()
				if json.parse(content) == OK:
					var data = json.get_data()
					if typeof(data) == TYPE_DICTIONARY:
						var ch = "TXT_PROLOGUE"
						if data.get("prolog_finished", false):
							ch = "TXT_CHAPTER_1"
						info.append({"empty": false, "slot": i, "chapter": ch})
						continue
		info.append({"empty": true, "slot": i, "chapter": ""})
	return info

func save_game(scene_path: String = ""):
	var temp_stage = current_stage
	
	if scene_path != "":
		temp_stage = scene_path
	elif get_tree().current_scene and not get_tree().current_scene.scene_file_path.contains("main_menu"):
		temp_stage = get_tree().current_scene.scene_file_path
		
	if temp_stage != "":
		current_stage = temp_stage
		
	var save_data = {
		"current_stage": current_stage,
		"prolog_finished": prolog_finished,
		"battlefield_1_intro_played": battlefield_1_intro_played,
		"stage_1_intro_played": stage_1_intro_played,
		"inventory_normal": inventory_normal,
		"inventory_combat": inventory_combat,
		"equipped_items": equipped_items,
		"max_mp": max_mp,
		"current_mp": current_mp,
		"iron_rusks": iron_rusks
	}
	
	save_config() # Sempre salvar config junto
	var path = get_save_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game Saved in slot ", current_slot, "! Stage: ", current_stage)

func load_game(slot_id: int = -1) -> bool:
	if slot_id != -1:
		current_slot = slot_id
		
	var path = get_save_path()
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				current_stage = data.get("current_stage", "")
				prolog_finished = data.get("prolog_finished", false)
				battlefield_1_intro_played = data.get("battlefield_1_intro_played", false)
				stage_1_intro_played = data.get("stage_1_intro_played", false)
				inventory_normal = data.get("inventory_normal", [{"id": "maycow_watch", "amount": 1}])
				inventory_combat = data.get("inventory_combat", [
					{"id": "pistol", "amount": 1},
					{"id": "cogblade", "amount": 1},
					{"id": "pistol_ammo", "amount": 25}
				])
				equipped_items = data.get("equipped_items", ["cogblade"])
				max_mp = data.get("max_mp", 30.0)
				current_mp = data.get("current_mp", 30.0)
				iron_rusks = data.get("iron_rusks", 0)
				iron_rusks_display = iron_rusks
				
				if current_stage != "" and ResourceLoader.exists(current_stage):
					print("Game Loaded from slot ", current_slot, "! ", current_stage)
					LoadingScreen.load_scene(current_stage)
					return true
	return false

func reset_progress() -> void:
	current_stage = ""
	prolog_finished = false
	battlefield_1_intro_played = false
	stage_1_intro_played = false
	inventory_normal = [{"id": "maycow_watch", "amount": 1}]
	inventory_combat = [{"id": "pistol", "amount": 1}, {"id": "cogblade", "amount": 1}, {"id": "pistol_ammo", "amount": 25}]
	equipped_items = ["cogblade"]
	max_mp = 30.0
	current_mp = 30.0
	iron_rusks = 0
	iron_rusks_display = 0

func add_iron_rusks(amount: int) -> void:
	iron_rusks += amount
	iron_rusks_pending += amount

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
			
		var player = players[0]
		if "is_using_ultimate" in player and player.is_using_ultimate:
			return # Não abre menu durante o ultimate da cogblade
			
		if menu_instance == null or not is_instance_valid(menu_instance):
			if get_tree().paused:
				return # Não abre se o jogo já estiver pausado (ex: Pause menu)
				
			var menu_script = load("res://scripts/ui/in_game_menu.gd")
			if menu_script:
				menu_instance = menu_script.new()
				menu_instance.name = "InGameMenu"
				get_tree().root.add_child(menu_instance)
		else:
			pass
