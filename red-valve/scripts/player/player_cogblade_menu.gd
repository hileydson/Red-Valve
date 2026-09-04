extends Node

# Seleção dos poderes da Cogblade.
#
# A ação "ui_cogblade_power" (tecla C / L1) tem dois usos:
#   - SEGURAR: o tempo fica ultra lento e aparece um menu radial (estilo dos
#     plasmids do BioShock) com os poderes disponíveis. O jogador aponta o
#     analógico ESQUERDO (ou o mouse) para a opção desejada e, ao SOLTAR, o
#     poder apontado é executado.
#   - TOQUE RÁPIDO: golpe melee — a cogblade passa uma vez de um lado para o
#     outro, alternando o lado a cada golpe.

var player: CharacterBody3D

const HOLD_MS: int = 220           # Tempo real de "segurar" até abrir o menu
const MENU_TIME_SCALE: float = 0.02 # Tempo ultra lento enquanto escolhe
const MENU_AUDIO_SCALE: float = 0.5
const SELECT_DEADZONE: float = 0.35

# Poderes disponíveis, na ordem em que aparecem no círculo (começa no topo).
# "cost_type" diz de onde sai o custo: "mp" gasta mana (o arremesso, que antes
# ficava no botão Y) e "cogblade" exige o medidor da cogblade cheio.
const POWERS: Array = [
	{
		"id": "thrown",
		"name": "COGBLADE THROWN",
		"desc": "Arremessa a lâmina como um bumerangue",
		"cost_type": "mp",
		"cost": 10.0,
	},
	{
		"id": "slain",
		"name": "COGBLADE SLAIN",
		"desc": "Mergulha do céu e explode a área",
		"cost_type": "cogblade",
		"cost": 100.0,
	},
	{
		"id": "cut",
		"name": "COGBLADE CUT",
		"desc": "Retalha a tela em alta velocidade (deixa 25%)",
		"cost_type": "cogblade",
		"cost": 100.0,
	},
	{
		"id": "fire",
		"name": "COGBLADE FIRE",
		"desc": "Marca um X de fogo e incendeia a arena",
		"cost_type": "cogblade",
		"cost": 100.0,
	},
]

var _pressing: bool = false
var _press_ms: int = 0
var _menu = null
var _menu_layer: CanvasLayer = null
var _options: Array = []
var _selected: int = -1
var _point_vec: Vector2 = Vector2.ZERO
var _mouse_vec: Vector2 = Vector2.ZERO

func _ready() -> void:
	player = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	# Segurança: nunca deixar o jogo preso em câmera lenta
	if is_instance_valid(player) and player.cogblade_menu_open:
		player.cogblade_menu_open = false
		Engine.time_scale = 1.0
		AudioServer.playback_speed_scale = 1.0

func _input(event: InputEvent) -> void:
	# Enquanto o menu está aberto o mouse escolhe a opção em vez de girar a câmera
	if player.cogblade_menu_open and event is InputEventMouseMotion:
		_mouse_vec += event.relative * 0.012
		if _mouse_vec.length() > 1.5:
			_mouse_vec = _mouse_vec.normalized() * 1.5
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	
	if Input.is_action_just_pressed("ui_cogblade_power") and _can_use_action():
		_pressing = true
		_press_ms = Time.get_ticks_msec()
	
	if _pressing and not player.cogblade_menu_open:
		if not _can_use_action():
			_pressing = false
		elif _can_open() and Time.get_ticks_msec() - _press_ms >= HOLD_MS:
			_open_menu()
	
	if player.cogblade_menu_open:
		if not _can_stay_open():
			_close_menu(false)
		else:
			_update_selection()
	
	if Input.is_action_just_released("ui_cogblade_power"):
		if player.cogblade_menu_open:
			# Só executa se o analógico/mouse estiver apontando para uma opção
			_close_menu(true)
		elif _pressing:
			# Não abriu o menu: foi um toque, então sai o golpe melee.
			# Apertar várias vezes executa vários golpes, mas cada um só começa
			# depois que o anterior termina (checado dentro do próprio golpe).
			player.cogblade_melee_slash()
		_pressing = false

# =========================================================================
# CONDIÇÕES
# =========================================================================

# Condições básicas do botão (valem tanto para o menu quanto para o melee)
func _can_use_action() -> bool:
	if GlobalEvents.is_maycow_normal: return false
	if GlobalEvents.in_cutscene or player._cutscene_inputs_disabled: return false
	if player.process_mode == Node.PROCESS_MODE_DISABLED: return false
	if get_tree().paused: return false
	if player.is_using_ultimate or player.is_magic_attacking or player.is_reloading: return false
	return true

# Condições extras para abrir o menu radial de poderes
func _can_open() -> bool:
	if not _can_use_action(): return false
	if player.cogblade_melee_active: return false
	if not player.is_on_floor(): return false
	# Abre se pelo menos um dos poderes estiver disponível
	for p in POWERS:
		if _is_power_available(p): return true
	return false

# Cada poder tem o seu próprio custo: o arremesso gasta mana, os dois ultimates
# exigem o medidor da cogblade cheio.
func _is_power_available(p: Dictionary) -> bool:
	var custo: float = float(p.get("cost", 0.0))
	if str(p.get("cost_type", "cogblade")) == "mp":
		# Mesmas condições que o arremesso tinha quando era no botão Y
		if player.transition_camera: return false
		if is_instance_valid(player.camera) and not player.camera.current: return false
		return SaveManager.current_mp >= custo
	return player.cogblade_power_value >= custo

func _can_stay_open() -> bool:
	if GlobalEvents.in_cutscene or player._cutscene_inputs_disabled: return false
	if get_tree().paused: return false
	if player.is_using_ultimate: return false
	return true

# =========================================================================
# MENU
# =========================================================================

func _open_menu() -> void:
	player.cogblade_menu_open = true
	_selected = -1
	_point_vec = Vector2.ZERO
	_mouse_vec = Vector2.ZERO
	
	# Um tween de câmera lenta pendente devolveria o time_scale para 1.0
	if GlobalUtils.current_time_tween and GlobalUtils.current_time_tween.is_valid():
		GlobalUtils.current_time_tween.kill()
	
	Engine.time_scale = MENU_TIME_SCALE
	AudioServer.playback_speed_scale = MENU_AUDIO_SCALE
	
	_options = []
	for p in POWERS:
		_options.append({
			"id": p["id"],
			"name": p["name"],
			"desc": p["desc"],
			"enabled": _is_power_available(p),
		})
	
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "CogbladeRadialLayer"
	_menu_layer.layer = 130
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	player.add_child(_menu_layer)
	
	_menu = load("res://scripts/ui/cogblade_radial_menu.gd").new()
	_menu.options = _options
	var icon_path := "res://assets/images/menu/itens/red_valve/cogblade.png"
	if ResourceLoader.exists(icon_path):
		_menu.icon_texture = load(icon_path)
	_menu_layer.add_child(_menu)
	
	GlobalUtils.vibrate_controller(Input, 0.15, 0.15, 0.1)

func _update_selection() -> void:
	if not is_instance_valid(_menu): return
	
	# Analógico esquerdo tem prioridade; o mouse serve para teclado.
	# Enquanto o menu está aberto o player não anda (_physics_process do
	# player.gd retorna cedo), então o analógico fica livre para escolher.
	var stick := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if stick.length() > SELECT_DEADZONE:
		_point_vec = stick
		_mouse_vec = Vector2.ZERO
	elif _mouse_vec.length() > SELECT_DEADZONE:
		_point_vec = _mouse_vec
	elif stick.length() <= 0.05 and _mouse_vec.length() <= 0.05:
		_point_vec = Vector2.ZERO
	
	var previous := _selected
	_selected = _index_from_direction(_point_vec)
	
	if _selected != previous and _selected >= 0:
		GlobalUtils.vibrate_controller(Input, 0.1, 0.1, 0.05)
	
	_menu.selected = _selected
	_menu.point_dir = _point_vec

# Converte a direção apontada no índice da fatia correspondente.
# As opções ficam distribuídas no círculo começando pelo topo.
func _index_from_direction(dir: Vector2) -> int:
	if dir.length() < SELECT_DEADZONE: return -1
	var count := _options.size()
	if count == 0: return -1
	
	var sector := TAU / float(count)
	var ang := atan2(dir.y, dir.x)
	# Alinha o índice 0 com o topo da tela (-PI/2 em coordenadas de tela)
	var rel := fposmod(ang + PI * 0.5 + sector * 0.5, TAU)
	return clampi(int(rel / sector), 0, count - 1)

func _close_menu(execute: bool) -> void:
	var chosen: int = _selected if execute else -1
	
	player.cogblade_menu_open = false
	_selected = -1
	_point_vec = Vector2.ZERO
	_mouse_vec = Vector2.ZERO
	
	if is_instance_valid(_menu):
		_menu.fade_out()
	if is_instance_valid(_menu_layer):
		var layer := _menu_layer
		var t := create_tween()
		t.set_ignore_time_scale(true)
		t.tween_interval(0.13)
		t.tween_callback(func():
			if is_instance_valid(layer): layer.queue_free()
		)
	_menu = null
	_menu_layer = null
	
	# Devolve o tempo ao normal. Se um poder for executado, ele mesmo
	# reconfigura o time_scale da própria cinemática logo em seguida.
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	
	if chosen < 0 or chosen >= _options.size(): return
	var opt: Dictionary = _options[chosen]
	if not bool(opt.get("enabled", false)): return
	_execute_power(str(opt.get("id", "")))

func _execute_power(id: String) -> void:
	if player.is_using_ultimate: return
	match id:
		"thrown":
			if not player.is_magic_attacking and not player.cogblade_melee_active:
				player.magic_hand_attack()
		"slain":
			player._activate_cogblade_slain()
		"cut":
			player._activate_cogblade_cut()
		"fire":
			player._activate_cogblade_fire()
