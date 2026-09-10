extends Node

const language_pt_br = "PT-BR"
const language_en = "EN"

# data to be saved
var can_load:bool = false
var in_cutscene:bool = false:
	set(val):
		in_cutscene = val
		if val and GlobalUtils:
			GlobalUtils.clear_all_messages()

var telefone_cutscene_active: bool = false
var save_array = {}
var default_language:String = language_pt_br

var is_maycow_normal = false
var entering_chapter_1: bool = false

## Ligado pela cena do interior da casa do Jimmy no instante em que o jogador
## sai pela porta. O stage_1 consome (e zera) isto no spawn para devolver o
## jogador à soleira da casa em vez do ponto de entrada padrão do mapa.
var voltando_da_casa_jimmy: bool = false
## Ligado pela the_house ao sair pela porta de volta à stage_1.
var voltando_da_casa_maycow: bool = false
## Ligado pela stage_1 ao interagir para entrar de volta na casa do Maycow.
var entrando_na_casa_maycow: bool = false
var game_weapon_events = {taken_pistol=false, taken_smg=false, taken_cogblade=false, taken_magic_hand_1=false}

# --- estado de UI, só em memória (de propósito fora do save) ---

## Última aba aberta no menu do jogo (0 inventário, 1 mapa, 2 arquivos).
## O menu é destruído ao fechar e recriado ao abrir, então a lembrança tem de
## morar aqui fora. Some ao fechar o jogo, que é o que se quer.
var menu_ultima_aba: int = 0

## Qual dispositivo o jogador está usando AGORA. A UI usa isto para mostrar a
## legenda de controle ou a de mouse, nunca as duas ao mesmo tempo.
var usando_controle: bool = false

var paused_scene_for_amulet: Node3D = null
var amulet_captured_enemies: Array[Node] = []
var previous_is_maycow_normal: bool = false

## --- Batalha forçada pelo toque (inimigo encosta no Maycow normal na cidade) ---
## Ligado enquanto a sequência (dano em câmera lenta + viagem) está rodando.
## Segura um segundo inimigo de disparar a mesma coisa por cima e faz os toques
## que chegarem no meio da cinemática não tirarem vida nenhuma.
var forced_battle_running: bool = false
## Sangue com que o Maycow de combate deve nascer na arena. A arena instancia um
## player.tscn novo, que nasceria com a vida cheia e apagaria o tranco levado na
## rua; quem consome (e zera) isto é o player_hud.gd. -1 = nasce cheio.
var forced_battle_health: int = -1

func _ready() -> void:
	# PROCESS_MODE_ALWAYS por causa do `_input` abaixo: com a árvore pausada
	# (menu aberto) um autoload PAUSABLE não recebe entrada nenhuma, e a
	# detecção de dispositivo congelava justamente onde ela é usada.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	pass #print(back_caminho_das_pedras)


func set_in_cutscene() ->void:
	in_cutscene = true;
func unset_in_cutscene() ->void:
	in_cutscene = false;

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		usando_controle = true
	elif event is InputEventJoypadMotion:
		# limiar alto, e não a zona morta: analógico solto fica tremendo perto
		# de zero e trocaria a legenda sozinho, sem ninguém encostar nele
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			usando_controle = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion \
			or event is InputEventKey:
		usando_controle = false


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
		
		LoadingScreen.load_scene("res://scenes/stages/stage_1/stage_1.tscn")
		
