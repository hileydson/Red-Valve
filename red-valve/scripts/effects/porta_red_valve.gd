extends Node3D

## A PORTA RED VALVE como portal de verdade (a da oficina é só cutscene).
##
## A cena (`scenes/effects/porta_red_valve.tscn`) fica encostada numa parede,
## olhando pro +Z local: a porta gira na dobradiça da esquerda e, atrás dela,
## o vão é um poço preto com o redemoinho vermelho (`portal_vortice.gdshader`).
##
##  - quem chega a `raio_abrir` da porta perde o controle; ela abre num tranco
##    e o vento começa a entrar; o portal (`portal_vortice.gd`) suga o jogador
##    e a viagem leva a `cena_destino` / `ponto_destino`;
##  - quem CHEGA por ela (`chegar`, chamado pela cena quando o ponto de chegada
##    é o nome deste nó): a porta abre de supetão, o jogador sai cuspido até o
##    marcador `chegada` e ela fecha. Só volta a abrir depois que ele se afasta.

const PortalVortice := preload("res://scripts/effects/portal_vortice.gd")

@export_file("*.tscn") var cena_destino: String = ""
## O marcador de chegada lá (vazio = onde a cena nasce).
@export var ponto_destino: String = ""
## Distância (da frente da porta) em que ela abre e puxa.
@export var raio_abrir: float = 2.6
## Quanto a folha gira aberta (rad, negativo = abre pra frente).
@export var giro_aberta: float = -1.75
## A luz vermelha fechada: pouca, vazando pela fresta — no escuro do porão é
## ela que anuncia a porta de longe.
@export var luz_fechada: float = 0.45
## Com prompt: chegar perto só PERGUNTA ("Atravessar a Red Valve?") e o aceitar
## abre. Sem, ela abre e puxa sozinha. A do porão passa a ter prompt depois da
## primeira travessia do Capítulo 1 (ver `porao.gd`).
@export var com_prompt: bool = false
## Desligada de todo (nem abre, nem pergunta): a da primeira travessia do
## Capítulo 1, que é a cutscene que abre.
var bloqueada: bool = false

@onready var _dobradica: Node3D = $dobradica
@onready var _vortice: MeshInstance3D = $vortice
@onready var _luz: OmniLight3D = $luz
@onready var _som_abrir: AudioStreamPlayer3D = $som_abrir
@onready var _chegada: Marker3D = $chegada

var _portal
var _ocupada: bool = false
var _luz_aberta: float = 2.6


func _ready() -> void:
	_luz_aberta = _luz.light_energy
	_luz.light_energy = luz_fechada
	_portal = PortalVortice.new()
	_portal.name = "portal"
	_portal.casca_vento = 4.5
	_portal.captura_fixa = raio_abrir + 1.5
	_portal.cor = Color(1.0, 0.22, 0.16)
	add_child(_portal)
	_portal.montar(_vortice, 1.0, global_basis.z, cena_destino, ponto_destino)
	_portal.bloqueado = true
	_portal.ventar(false)


func _physics_process(_delta: float) -> void:
	if _ocupada or cena_destino == "" or GlobalEvents.in_cutscene or bloqueada:
		_perguntar(false)
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	var perto := _distancia(player) < raio_abrir
	if com_prompt:
		_perguntar(perto)
		if perto and Input.is_action_just_pressed("ui_accept"):
			_perguntar(false)
			_abrir_e_sugar(player)
		return
	if perto:
		_abrir_e_sugar(player)


var _perguntando := false

func _perguntar(sim: bool) -> void:
	if sim == _perguntando:
		return
	_perguntando = sim
	if sim:
		GlobalUtils.show_center_message("red_valve_" + name, tr("PROMPT_ATRAVESSAR_RED_VALVE"), 16)
	else:
		GlobalUtils.hide_center_message("red_valve_" + name)


## A cutscene da primeira travessia abre a porta e cuida da viagem ela mesma.
func abrir_sem_sugar() -> void:
	_ocupada = true
	_portal.ventar(true)
	await _abrir(0.9)


## O ponto do redemoinho atrás da porta (pra onde a câmera é puxada).
func centro_do_vortice() -> Vector3:
	return _vortice.global_position


func _abrir_e_sugar(player: CharacterBody3D) -> void:
	_ocupada = true
	if player.has_method("cutscene_set_player_control"):
		player.cutscene_set_player_control(false)
	player.velocity = Vector3.ZERO
	GlobalEvents.in_cutscene = true
	_portal.ventar(true)
	await _abrir(0.9)
	if not is_instance_valid(player):
		return
	_portal.bloqueado = false
	_portal.sugar(player)


## Chegou por esta porta: ela abre de supetão e cospe o jogador no marcador.
func chegar(player: CharacterBody3D) -> void:
	_ocupada = true
	_portal.bloqueado = false
	_portal.ventar(true)
	_abrir(0.25)
	await _portal.ejetar(player, _chegada)
	_portal.bloqueado = true
	await get_tree().create_timer(0.5, false).timeout
	_portal.ventar(false)
	await _fechar(1.1)
	# só arma de novo com ele longe, senão abriria em cima de quem acabou de sair
	while is_inside_tree():
		await get_tree().create_timer(0.3, false).timeout
		if not is_instance_valid(player) or _distancia(player) > raio_abrir + 2.5:
			break
	_ocupada = false


func _abrir(duracao: float) -> void:
	_som_abrir.play()
	GlobalUtils.vibrate_controller(null, 0.5, 0.4, 0.4)
	var t := create_tween().set_parallel(true)
	t.tween_property(_dobradica, "rotation:y", giro_aberta, duracao).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_luz, "light_energy", _luz_aberta, duracao)
	await t.finished


func _fechar(duracao: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_dobradica, "rotation:y", 0.0, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_luz, "light_energy", luz_fechada, duracao)
	await t.finished
	GlobalUtils.vibrate_controller(null, 0.4, 0.3, 0.2)


## Da frente da porta (o meio do vão, no chão) até o jogador, no plano.
func _distancia(player: Node3D) -> float:
	var frente := global_position + global_basis.z * 0.6
	return Vector2(player.global_position.x - frente.x, player.global_position.z - frente.z).length()
