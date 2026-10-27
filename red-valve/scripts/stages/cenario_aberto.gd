extends Node3D

## Base dos cenários a céu aberto gerados por script (arena 3, cemitério e
## inferno). Junta o que o `battlefield_2.gd` faz e os três repetiriam:
##
##  - põe a colisão importada do .glb na layer 2 (o player só enxerga ela);
##  - faz tremer as luzes marcadas com `metadata/piscar`;
##  - solta as gárgulas de fogo (pousando nos `pousos` ou cruzando o céu);
##  - relâmpago: clarão na luz `relampago`, no céu e um trovão atrasado.
##
## Quem herda escreve só o que é dele em `_preparar()` e `_passo(delta)`.

## A layer do chão. Ver o comentário de `LAYER_CHAO` no battlefield_2.gd.
const LAYER_CHAO := 2
const GARGULA := preload("res://scenes/effects/fire_gargoyle.tscn")

@export_group("Jogador")
## Maycow normal (cidade) ou o de batalha (arenas, o outro lado).
@export var maycow_normal: bool = false
## Arena: devolve a arma guardada (`SaveManager.entrar_na_arena`). A arena
## nunca vira checkpoint — ver SaveManager._pode_virar_checkpoint.
@export var e_arena: bool = false
## Grava o checkpoint ao entrar (lugares de passagem, não arenas).
@export var salvar_ao_entrar: bool = false
## Partículas de névoa que o próprio player carrega: "alta", "baixa", "minima".
@export var nevoa_do_player: String = "alta"

@export_group("Gárgulas")
## Quantas pousam nos marcadores do nó `pousos`.
@export var gargulas_poleiro: int = 0
## Quantas só cruzam o céu, sem pousar.
@export var gargulas_ceu: int = 0
@export var ceu_centro: Vector3 = Vector3.ZERO
@export var ceu_raio: float = 120.0
@export var ceu_altura_min: float = 30.0
@export var ceu_altura_max: float = 70.0
## O bando do céu acompanha a câmera (fica sempre no céu da tomada).
@export var ceu_segue_camera: bool = true
## As do céu voam LONGE: a omni delas só gastaria a cota de 8 por malha do
## renderer mobile sem iluminar nada que se veja.
@export var ceu_com_luz: bool = false
## Alcance da omni das que pousam (a de fábrica é 14).
@export var gargula_alcance: float = 10.0

@export_group("Relâmpago")
@export var relampagos: bool = false
@export var relampago_espera_min: float = 9.0
@export var relampago_espera_max: float = 24.0
## Energia de pico da direcional `relampago`.
@export var relampago_energia: float = 2.6

@export_group("Ar")
## As partículas do grupo `segue_camera` acompanham também a ALTURA da câmera,
## mantendo a posição local de cada uma como distância vertical até ela. Para
## mapa que sobe e desce dezenas de metros (o funil do inferno 2).
@export var segue_camera_altura: bool = false

var _lampadas_piscando: Array[Dictionary] = []
## Partículas do grupo `segue_camera` (cinza, névoa rasteira): o mapa é grande
## demais pra uma caixa de emissão só; elas nascem em volta de onde se olha.
var _segue_camera: Array[Node3D] = []
var _segue_camera_dy: Array[float] = []
var _tempo: float = 0.0
var _relampago_prazo: float = 0.0
var _luz_relampago: DirectionalLight3D
var _ceu_material: ShaderMaterial
var _trovao: AudioStreamPlayer


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = maycow_normal
	if e_arena:
		SaveManager.entrar_na_arena()
	elif salvar_ao_entrar:
		SaveManager.save_game()
	match nevoa_do_player:
		"alta":
			GlobalEvents.set_high_nevoa()
		"baixa":
			GlobalEvents.set_low_nevoa()
		"minima":
			GlobalEvents.set_minimum_nevoa()

	_corrigir_colisao()
	for no in get_tree().get_nodes_in_group("segue_camera"):
		if no is Node3D and is_ancestor_of(no):
			_segue_camera.append(no)
			_segue_camera_dy.append((no as Node3D).position.y)
	_preparar_lampadas()
	_soltar_gargulas()
	_preparar_relampagos()
	_preparar()


## Para quem herda.
func _preparar() -> void:
	pass


## Para quem herda: roda todo quadro depois das luzes e do relâmpago.
func _passo(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	_tempo += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		for k in range(_segue_camera.size()):
			var no := _segue_camera[k]
			var y := cam.global_position.y + _segue_camera_dy[k] if segue_camera_altura else no.global_position.y
			no.global_position = Vector3(cam.global_position.x, y, cam.global_position.z)
	_tremer_luzes(delta)
	_relampago_passo(delta)
	_passo(delta)


## Põe todo corpo estático vindo do .glb na layer do chão.
func _corrigir_colisao() -> void:
	var modelo := get_node_or_null("modelo")
	if modelo == null:
		return
	var achou := false
	for corpo in modelo.find_children("*", "StaticBody3D", true, false):
		corpo.collision_layer = LAYER_CHAO
		corpo.collision_mask = 0
		achou = true
	if not achou:
		push_warning("%s: nenhum StaticBody3D no modelo — .glb sem o objeto -colonly?" % name)


# ==============================================================================
# LUZES QUE TREMEM
# ==============================================================================
func _preparar_lampadas() -> void:
	var luzes := get_node_or_null("luzes")
	if luzes == null:
		return
	for luz in luzes.get_children():
		if not (luz is Light3D) or not luz.has_meta("piscar"):
			continue
		_lampadas_piscando.append({
			"luz": luz,
			"tipo": String(luz.get_meta("piscar")),
			"base": (luz as Light3D).light_energy,
			"proximo": 0.0,
			"fase": randf() * TAU,
		})


func _tremer_luzes(delta: float) -> void:
	for lamp in _lampadas_piscando:
		var luz: Light3D = lamp["luz"]
		if not is_instance_valid(luz):
			continue
		match lamp["tipo"]:
			"pulso":
				var t: float = _tempo * 0.7 + float(lamp["fase"])
				luz.light_energy = lamp["base"] * (0.72 + 0.28 * sin(t) + 0.08 * sin(t * 3.1))
			"vela":
				lamp["proximo"] -= delta
				if lamp["proximo"] <= 0.0:
					luz.light_energy = lamp["base"] * randf_range(0.82, 1.08)
					lamp["proximo"] = randf_range(0.04, 0.11)
			_:
				lamp["proximo"] -= delta
				if lamp["proximo"] <= 0.0:
					luz.light_energy = lamp["base"] * randf_range(0.7, 1.22)
					lamp["proximo"] = randf_range(0.05, 0.18)


# ==============================================================================
# GÁRGULAS
# ==============================================================================
func _soltar_gargulas() -> void:
	var ninho := Node3D.new()
	ninho.name = "gargulas"
	add_child(ninho)

	var raiz := get_node_or_null("pousos")
	var poleiros: Array[Node3D] = []
	if raiz:
		for p in raiz.get_children():
			if p is Node3D:
				poleiros.append(p as Node3D)
	if gargulas_poleiro > 0 and poleiros.size() >= 2:
		# começam em poleiros espalhados, não lado a lado
		var passo: int = maxi(1, poleiros.size() / gargulas_poleiro)
		for i in range(gargulas_poleiro):
			var g = GARGULA.instantiate()
			g.light_range = gargula_alcance
			ninho.add_child(g)
			g.setup(poleiros, (i * passo) % poleiros.size())

	for i in range(gargulas_ceu):
		var g = GARGULA.instantiate()
		g.body_scale = randf_range(1.6, 2.6)
		g.flight_speed = randf_range(9.0, 15.0)
		g.roam_follow_camera = ceu_segue_camera
		ninho.add_child(g)
		g.setup_roam(ceu_centro, ceu_raio, ceu_altura_min, ceu_altura_max)
		if not ceu_com_luz:
			for luz in g.find_children("*", "OmniLight3D", true, false):
				luz.visible = false


# ==============================================================================
# RELÂMPAGO
# ==============================================================================
func _preparar_relampagos() -> void:
	_luz_relampago = get_node_or_null("relampago") as DirectionalLight3D
	_trovao = get_node_or_null("trovao") as AudioStreamPlayer
	var amb := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if amb and amb.environment and amb.environment.sky:
		_ceu_material = amb.environment.sky.sky_material as ShaderMaterial
	if _luz_relampago:
		_luz_relampago.light_energy = 0.0
	_relampago_prazo = randf_range(relampago_espera_min * 0.4, relampago_espera_max * 0.6)


func _relampago_passo(delta: float) -> void:
	if not relampagos:
		return
	_relampago_prazo -= delta
	if _relampago_prazo <= 0.0:
		_relampago_prazo = randf_range(relampago_espera_min, relampago_espera_max)
		disparar_relampago()


## Pública: a chuva de fogo da arena 3 abre com um relâmpago.
func disparar_relampago(forca: float = 1.0) -> void:
	var t := create_tween()
	# dois ou três estalos curtos, como relâmpago de verdade
	var estalos := randi_range(2, 3)
	for k in estalos:
		var pico := forca * randf_range(0.55, 1.0)
		t.tween_method(_aplicar_relampago, 0.0, pico, 0.035)
		t.tween_method(_aplicar_relampago, pico, pico * 0.15, randf_range(0.06, 0.14))
	t.tween_method(_aplicar_relampago, forca * 0.15, 0.0, 0.5)
	if _trovao and _trovao.stream:
		await get_tree().create_timer(randf_range(0.6, 2.2)).timeout
		if is_instance_valid(_trovao):
			_trovao.pitch_scale = randf_range(0.8, 1.05)
			_trovao.play()


func _aplicar_relampago(v: float) -> void:
	if _luz_relampago:
		_luz_relampago.light_energy = v * relampago_energia
	if _ceu_material:
		_ceu_material.set_shader_parameter("relampago", v)
