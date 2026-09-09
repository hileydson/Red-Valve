extends Node3D
class_name ShadowCrowd

const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")

## Povoa a cidade de ShadowPerson ao redor do jogador, dando a impressao de
## que ela esta cheia sem nunca pagar por uma cidade cheia de verdade.
##
## A ideia: existe um numero FIXO de sombras (o pool, criado uma unica vez no
## _ready). Elas nao sao criadas nem destruidas durante o jogo — apenas ligadas
## e desligadas. Quem fica longe demais do jogador e recolhido para a "garagem"
## (um ponto morto fora do mapa) e volta a nascer mais adiante, no caminho para
## onde ele esta indo. O custo de memoria e de CPU e constante e previsivel.
##
## Duas regras protegem a ilusao:
##   1. Nada some na cara do jogador: uma sombra so e recolhida se estiver fora
##      do campo de visao, ou tao longe que a nevoa ja a engoliu.
##   2. Nada nasce na frente dele: os pontos de spawn sao sorteados fora do
##      frustum da camera. Se todos os candidatos estiverem visiveis, o sistema
##      aceita um ponto distante, onde a nevoa do stage disfarca o surgimento.
##
## Os pontos de spawn saem sempre do navmesh, entao ninguem nasce dentro de um
## predio ou boiando. Se o navmesh nao estiver pronto, cai para um raycast
## vertical no chao.
##
## O mesmo esquema vale para os ShadowCar, num pool separado: pool proprio,
## anel proprio (maior, porque carro anda mais rapido) e uma exigencia a mais —
## o ponto tem que estar sobre o no das ruas e ter pista continuando a frente,
## senao o carro nasceria entalado numa quina.

@export_group("Populacao")
## Cena da sombra. Se ficar vazio, usa res://scenes/npcs/shadow_person.tscn.
@export var shadow_scene: PackedScene
## Quantas instancias existem na memoria. Custo fixo do sistema.
@export var pool_size: int = 26
## Quantas ficam ativas ao mesmo tempo. Sempre <= pool_size.
@export var max_active: int = 16
## Raio em que cada sombra vaga a partir de onde nasceu. 0 = nao mexe no valor
## que vier da cena.
@export var wander_radius: float = 16.0

@export_group("Carros")
## Cena do carro. Vazio = res://scenes/npcs/shadow_car.tscn. 0 carros = desliga.
@export var car_scene: PackedScene
## Carros na memoria. Poucos de proposito: a cidade nao e uma avenida.
@export var car_pool_size: int = 8
## Quantos rodam ao mesmo tempo.
@export var max_active_cars: int = 5
## Anel onde os carros nascem. Maior que o das pessoas: carro cobre distancia
## rapido e nascer perto demais fica na cara.
@export var car_spawn_ring_min: float = 30.0
@export var car_spawn_ring_max: float = 80.0
## Dentro disso nao se recolhe carro nenhum.
@export var car_keep_distance: float = 60.0
## Alem disso o carro some mesmo estando na tela.
@export var car_despawn_distance: float = 110.0
## Distancia minima entre dois carros recem nascidos.
@export var car_min_spacing: float = 25.0
## Nome do no das ruas da cidade.
@export var road_node_name: String = "Roads"
## Alternativa ao nome: nos de rua marcados neste grupo.
@export var road_group: String = "shadow_road"
## Camada fisica da colisao da cidade.
@export_flags_3d_physics var road_mask: int = 2

@export_group("Distancias")
## Anel (em metros) onde as sombras nascem, medido a partir do jogador.
@export var spawn_ring_min: float = 14.0
@export var spawn_ring_max: float = 50.0
## Dentro deste raio nunca se recolhe ninguem, visivel ou nao. Evita que uma
## sombra evapore logo atras do ombro do jogador quando ele gira a camera.
@export var keep_distance: float = 40.0
## Alem disso some sempre, mesmo que esteja na tela (a nevoa ja escondeu).
@export var despawn_distance: float = 70.0
## Distancia minima entre duas sombras recem nascidas.
@export var min_spacing: float = 3.0

@export_group("Ritmo")
## De quanto em quanto tempo o sistema reavalia quem entra e quem sai.
@export var tick_interval: float = 0.25
## Teto de nascimentos por avaliacao, para nao aparecer um bolo de gente de uma
## vez quando o jogador entra correndo numa area nova.
@export var spawns_per_tick: int = 2
## Tentativas de sorteio de ponto por nascimento antes de desistir no tick.
@export var spawn_tries: int = 10

@export_group("Camera")
## Impede que sombras nascam dentro do campo de visao.
@export var avoid_camera: bool = true
## A partir desta distancia aceita-se nascer na tela: e longe o bastante para a
## nevoa cobrir o surgimento, e sem isso o sistema trava em ruas muito abertas.
@export var onscreen_ok_beyond: float = 46.0

@export_group("Navegacao")
## Tolerancia horizontal ao encaixar o ponto sorteado no navmesh. Acima disso
## o candidato caiu fora da area andavel e o sistema tenta o chao fisico.
@export var nav_snap_tolerance: float = 2.5
## Camadas fisicas do chao, usadas quando o navmesh nao cobre a regiao. Na
## stage_1 o terreno e os pisos estao na camada 2.
@export_flags_3d_physics var ground_mask: int = 2
## Desnivel maximo aceito entre o jogador e o ponto de spawn. Segura o caso do
## raycast acertar a laje de um predio ou o fundo de um buraco.
@export var max_height_diff: float = 6.0

@export_group("Carga")
## Quantas sombras/carros sao instanciados por frame ao montar o pool. Montar
## os 34 nos de uma vez (cada um monta o proprio corpo em codigo) era o segundo
## maior engasgo da entrada na stage_1; espalhando, a cidade demora um segundo
## a mais pra encher e ninguem ve a diferenca.
@export var build_per_frame: int = 2
## Orcamento por frame, em ms, da rasterizacao do mapa de ruas.
@export var road_build_budget_ms: float = 2.0

@export_group("Debug")
@export var debug_log: bool = false

const GARAGE := Vector3(0.0, -900.0, 0.0)
## Sentinela de "nao achei ponto". Evita devolver Variant/null, que o projeto
## trata como erro de parse (INFERRED_DECLARATION).
const NO_SPOT := Vector3(0.0, -99999.0, 0.0)

var _pool: Array[Node3D] = []
var _active: Array[Node3D] = []
var _idle: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _tick := 0.0
var _player: Node3D = null
var _player_retry := 0.0
var _nav_layers := 0
var _warned_no_nav := false

var _car_pool: Array[Node3D] = []
var _car_active: Array[Node3D] = []
var _car_idle: Array[Node3D] = []
var _last_car_heading := 0.0


## Nada aqui e feito no frame em que a stage entra. O mapa de ruas e o pool
## sao montados aos poucos, frame a frame, e o loop de spawn so liga quando
## tudo esta pronto — ate la a cidade fica vazia por um segundo, o que e bem
## menos perceptivel do que a tela congelar.
func _ready() -> void:
	_rng.randomize()
	set_physics_process(false)
	if shadow_scene == null:
		shadow_scene = load("res://scenes/npcs/shadow_person.tscn") as PackedScene
	if shadow_scene == null:
		push_error("ShadowCrowd: shadow_person.tscn nao encontrada; a cidade fica vazia.")
		return
	max_active = mini(max_active, pool_size)
	await ShadowRoads.setup_async(get_tree(), road_node_name, road_group, road_build_budget_ms)
	if not is_inside_tree():
		return
	await _build_pool()
	if not is_inside_tree():
		return
	await _build_car_pool()
	if not is_inside_tree():
		return
	# o NavigationAgent3D de cada sombra so existe alguns frames depois do
	# _ready dela (o proprio script espera a nav map sincronizar)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_sync_nav_layers()
	set_physics_process(true)


## Mesmo esquema do pool de pessoas, so que para os carros. Cada carro nasce
## com o proprio sumico-por-distancia DESLIGADO: quem manda em quem aparece e
## quem some passa a ser este no, senao os dois sistemas brigariam.
func _build_car_pool() -> void:
	await get_tree().process_frame  # esta funcao sempre suspende: veja _ready
	if car_pool_size <= 0 or max_active_cars <= 0:
		return
	if car_scene == null:
		car_scene = load("res://scenes/npcs/shadow_car.tscn") as PackedScene
	if car_scene == null:
		push_warning("ShadowCrowd: shadow_car.tscn nao encontrada; a cidade fica sem carros.")
		return
	max_active_cars = mini(max_active_cars, car_pool_size)
	for i in car_pool_size:
		var car := car_scene.instantiate() as Node3D
		if car == null:
			continue
		if "despawn_enabled" in car:
			car.despawn_enabled = false
		if "road_node_name" in car:
			car.road_node_name = road_node_name
			car.road_group = road_group
			car.road_mask = road_mask
		add_child(car)
		car.global_position = GARAGE
		_car_pool.append(car)
		_park_car(car)
		if build_per_frame > 0 and (i + 1) % build_per_frame == 0:
			await get_tree().process_frame
			if not is_inside_tree():
				return
	if debug_log:
		print("ShadowCrowd: pool de ", _car_pool.size(), " carros pronto.")


## Cria as sombras (em lotes de build_per_frame, para nao travar o frame de
## entrada) e as manda direto para a garagem. Elas
## nunca mais sao instanciadas nem liberadas: o resto do sistema so acende e
## apaga. Manter todas na arvore tambem preserva os contadores internos de
## populacao do ShadowPerson, que sao decrementados no _exit_tree.
func _build_pool() -> void:
	await get_tree().process_frame  # esta funcao sempre suspende: veja _ready
	for i in pool_size:
		var npc := shadow_scene.instantiate() as Node3D
		if npc == null:
			continue
		add_child(npc)
		npc.global_position = GARAGE
		if wander_radius > 0.0 and "wander_radius" in npc:
			npc.wander_radius = wander_radius
		_pool.append(npc)
		_park(npc)
		if build_per_frame > 0 and (i + 1) % build_per_frame == 0:
			await get_tree().process_frame
			if not is_inside_tree():
				return
	if debug_log:
		print("ShadowCrowd: pool de ", _pool.size(), " sombras pronto.")


## O navmesh da cidade usa uma camada propria (navigation_layers do
## NavigationRegion3D). Um NavigationAgent3D nasce ouvindo so a camada 1, entao
## sem este ajuste o pathfinding devolve caminho vazio e todo mundo anda em
## linha reta contra os predios.
func _sync_nav_layers() -> void:
	var region := _find_nav_region(get_tree().current_scene)
	if region == null:
		return
	_nav_layers = region.navigation_layers
	if _nav_layers == 0:
		return
	for npc in _pool:
		var agent := _find_agent(npc)
		if agent != null:
			agent.navigation_layers = _nav_layers
	if debug_log:
		print("ShadowCrowd: navigation_layers = ", _nav_layers)


func _find_nav_region(node: Node) -> NavigationRegion3D:
	if node == null:
		return null
	if node is NavigationRegion3D:
		return node as NavigationRegion3D
	for c in node.get_children():
		var r := _find_nav_region(c)
		if r != null:
			return r
	return null


func _find_agent(node: Node) -> NavigationAgent3D:
	for c in node.get_children():
		if c is NavigationAgent3D:
			return c as NavigationAgent3D
	return null


# ------------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = tick_interval

	if not is_instance_valid(_player):
		_player_retry -= tick_interval
		if _player_retry <= 0.0:
			_player = _find_player()
			_player_retry = 1.0
		if not is_instance_valid(_player):
			return

	var cam := get_viewport().get_camera_3d()
	var ppos := _player.global_position

	_retire_far(ppos, cam)
	_fill(ppos, cam)
	_retire_far_cars(ppos, cam)
	_fill_cars(ppos, cam)


## Recolhe quem ja nao faz falta. A ordem dos testes importa: a distancia curta
## tem prioridade sobre a visibilidade, senao uma sombra logo atras do jogador
## sumiria toda vez que ele virasse de costas para ela.
func _retire_far(ppos: Vector3, cam: Camera3D) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var npc: Node3D = _active[i]
		if not is_instance_valid(npc):
			_active.remove_at(i)
			continue
		var d := ppos.distance_to(npc.global_position)
		if d <= keep_distance:
			continue
		if d > despawn_distance or _offscreen(cam, npc.global_position):
			_park(npc)
			_active.remove_at(i)


func _fill(ppos: Vector3, cam: Camera3D) -> void:
	var budget := spawns_per_tick
	while _active.size() < max_active and budget > 0 and not _idle.is_empty():
		var p := _pick_spawn_point(ppos, cam)
		if p == NO_SPOT:
			break
		_deploy(p)
		budget -= 1


## Sorteia um ponto no anel ao redor do jogador que esteja no navmesh, longe das
## outras sombras e fora do campo de visao. Devolve NO_SPOT se nao achar nada
## bom neste tick — melhor esperar do que fazer alguem brotar na frente da
## camera.
func _pick_spawn_point(ppos: Vector3, cam: Camera3D) -> Vector3:
	var map := get_world_3d().navigation_map
	var has_nav := NavigationServer3D.map_get_iteration_id(map) > 0 \
		and not NavigationServer3D.map_get_regions(map).is_empty()

	for _i in spawn_tries:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(spawn_ring_min, spawn_ring_max)
		var cand := ppos + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)

		var pos := _snap_to_ground(cand, map, has_nav)
		if pos == NO_SPOT:
			continue
		# telhado, laje ou fundo de buraco: longe demais do nivel do jogador
		if absf(pos.y - ppos.y) > max_height_diff:
			continue
		# nasce na rua: senao a sombra apareceria na calcada e voltaria
		# andando pro asfalto na frente do jogador
		if ShadowRoads.has_map() and not ShadowRoads.is_road(pos):
			continue

		var real_d := ppos.distance_to(pos)
		if real_d < spawn_ring_min or real_d > spawn_ring_max:
			continue
		if avoid_camera and real_d < onscreen_ok_beyond and not _offscreen(cam, pos):
			continue
		if _too_close_to_others(pos):
			continue
		return pos
	return NO_SPOT


## Encaixa o candidato no chao. Prefere o navmesh, porque ali o ponto e andavel
## por construcao e o pathfinding das sombras funciona.
##
## Se o navmesh existe mas nao cobre este pedaco do mapa, NAO descarta o ponto:
## cai para o chao fisico. Na stage_1 isso e a regra, nao a excecao — o
## NavigationRegion3D da cena cobre uma area distante de onde se joga, e sem
## este fallback a cidade inteira ficaria vazia.
func _snap_to_ground(cand: Vector3, map: RID, has_nav: bool) -> Vector3:
	if has_nav:
		var snapped := NavigationServer3D.map_get_closest_point(map, cand)
		if Vector2(snapped.x - cand.x, snapped.z - cand.z).length() <= nav_snap_tolerance:
			return snapped
		if not _warned_no_nav:
			_warned_no_nav = true
			push_warning("ShadowCrowd: navmesh nao cobre esta area; usando o chao fisico.")
	# fallback: procura chao logo abaixo/acima do candidato
	var space := get_world_3d().direct_space_state
	var from := cand + Vector3.UP * 40.0
	var to := cand + Vector3.DOWN * 40.0
	var q := PhysicsRayQueryParameters3D.create(from, to, ground_mask)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NO_SPOT
	return hit["position"]


func _too_close_to_others(pos: Vector3) -> bool:
	for npc in _active:
		if is_instance_valid(npc) and npc.global_position.distance_to(pos) < min_spacing:
			return true
	return false


## Fora do campo de visao. Mede na altura do peito: um ponto no chao pode cair
## logo abaixo da borda da tela enquanto o corpo ainda aparece.
func _offscreen(cam: Camera3D, pos: Vector3) -> bool:
	if cam == null:
		return true
	return not cam.is_position_in_frustum(pos + Vector3.UP * 1.0)


# ---------------------------------------------------------------- carros

func _retire_far_cars(ppos: Vector3, cam: Camera3D) -> void:
	for i in range(_car_active.size() - 1, -1, -1):
		var car: Node3D = _car_active[i]
		if not is_instance_valid(car):
			_car_active.remove_at(i)
			continue
		var d := ppos.distance_to(car.global_position)
		if d <= car_keep_distance:
			continue
		if d > car_despawn_distance or _offscreen(cam, car.global_position):
			_park_car(car)
			_car_active.remove_at(i)


func _fill_cars(ppos: Vector3, cam: Camera3D) -> void:
	var budget := spawns_per_tick
	while _car_active.size() < max_active_cars and budget > 0 and not _car_idle.is_empty():
		var spot := _pick_car_spot(ppos, cam)
		if spot == NO_SPOT:
			break
		_deploy_car(spot)
		budget -= 1


## Sorteia um ponto de rua no anel ao redor do jogador. Alem das regras das
## pessoas (fora da tela, longe das outras), o ponto precisa ter asfalto embaixo
## E pista continuando em alguma direcao. O rumo inicial dessa checagem fica em
## _last_car_heading, ja que o retorno so cabe a posicao.
func _pick_car_spot(ppos: Vector3, cam: Camera3D) -> Vector3:
	var world := get_world_3d()
	for _i in spawn_tries:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(car_spawn_ring_min, car_spawn_ring_max)
		var cand := ppos + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)

		if not ShadowRoads.is_road(cand):
			continue
		var y := ShadowRoads.road_y(cand)
		if is_nan(y):
			y = ShadowRoads.ground_y(world, cand, road_mask)
		if is_nan(y):
			continue
		var pos := Vector3(cand.x, y + 0.15, cand.z)
		if absf(pos.y - ppos.y) > max_height_diff:
			continue
		var real_d := ppos.distance_to(pos)
		if real_d < car_spawn_ring_min or real_d > car_spawn_ring_max:
			continue
		if avoid_camera and real_d < onscreen_ok_beyond and not _offscreen(cam, pos):
			continue
		if _too_close_to_cars(pos):
			continue
		# precisa de rua continuando a frente, senao nasce sem saida
		var heading := _road_heading(world, pos)
		if is_nan(heading):
			continue
		_last_car_heading = heading
		return pos
	return NO_SPOT


## Em qual direcao a rua continua a partir daqui? NAN se nenhuma.
func _road_heading(world: World3D, pos: Vector3) -> float:
	var off := _rng.randf() * TAU
	for k in 8:
		var a := off + TAU * float(k) / 8.0
		var ahead := pos + Vector3(sin(a), 0.0, cos(a)) * 9.0
		if ShadowRoads.is_road(ahead):
			return a
	return NAN


func _too_close_to_cars(pos: Vector3) -> bool:
	for car in _car_active:
		if is_instance_valid(car) and car.global_position.distance_to(pos) < car_min_spacing:
			return true
	return false


func _park_car(car: Node3D) -> void:
	if car.has_method("stop_engine"):
		car.stop_engine()
	car.visible = false
	car.process_mode = Node.PROCESS_MODE_DISABLED
	car.global_position = GARAGE
	if car is CharacterBody3D:
		car.velocity = Vector3.ZERO
	if not _car_idle.has(car):
		_car_idle.append(car)


func _deploy_car(pos: Vector3) -> void:
	var car: Node3D = _car_idle.pop_back()
	if car == null or not is_instance_valid(car):
		return
	car.global_position = pos
	car.rotation.y = _last_car_heading
	car.process_mode = Node.PROCESS_MODE_INHERIT
	car.visible = true
	if car.has_method("relocate"):
		car.relocate(pos, _last_car_heading)
	_car_active.append(car)


# ------------------------------------------------------- ligar e desligar

func _park(npc: Node3D) -> void:
	npc.visible = false
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	npc.global_position = GARAGE
	if npc is CharacterBody3D:
		npc.velocity = Vector3.ZERO
	if not _idle.has(npc):
		_idle.append(npc)


func _deploy(pos: Vector3) -> void:
	var npc: Node3D = _idle.pop_back()
	if npc == null or not is_instance_valid(npc):
		return
	npc.global_position = pos
	npc.process_mode = Node.PROCESS_MODE_INHERIT
	npc.visible = true
	# reensina a sombra que a casa dela agora e aqui; sem isto ela tentaria
	# voltar andando para o ponto onde nasceu da primeira vez
	if npc.has_method("relocate"):
		npc.relocate(pos)
	_active.append(npc)


func _find_player() -> Node3D:
	var p := get_tree().get_first_node_in_group("player")
	if p is Node3D:
		return p as Node3D
	var scene := get_tree().current_scene
	if scene != null:
		var byname := scene.find_child("player", true, false)
		if byname is Node3D:
			return byname as Node3D
	return null


# ------------------------------------------------------------------ api

## Quantas sombras estao acesas agora.
func active_count() -> int:
	return _active.size()


## Quantos carros estao rodando agora.
func active_car_count() -> int:
	return _car_active.size()


## Recolhe todo mundo. Util antes de uma cutscene, para a cidade nao andar
## no fundo do plano.
func clear_all() -> void:
	for i in range(_active.size() - 1, -1, -1):
		var npc: Node3D = _active[i]
		if is_instance_valid(npc):
			_park(npc)
	_active.clear()
	for i in range(_car_active.size() - 1, -1, -1):
		var car: Node3D = _car_active[i]
		if is_instance_valid(car):
			_park_car(car)
	_car_active.clear()
