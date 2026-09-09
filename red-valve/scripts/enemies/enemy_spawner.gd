extends Node3D
class_name EnemySpawner

const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")

## Solta inimigos ao redor do jogador enquanto ele anda pela cidade, em
## intervalos aleatorios, e os apaga da memoria quando ele se afasta.
##
## A ideia e a mesma do ShadowCrowd (que povoa a cidade de sombras), com duas
## diferencas de proposito:
##   1. Aqui NAO existe pool. O jogador bate no inimigo, tira vida dele, mata:
##      um inimigo reciclado voltaria com a barra pela metade ou no meio da
##      animacao de morte. Cada um nasce novo e e liberado de vez
##      (`queue_free`) quando fica longe demais.
##   2. Nunca ha muitos ao mesmo tempo — isto e encontro de rua, nao horda.
##
## Regras que protegem a ilusao (herdadas do ShadowCrowd):
##   - ninguem nasce dentro do campo de visao, a nao ser bem longe, onde a
##     nevoa da stage_1 disfarca o surgimento;
##   - ninguem some perto do jogador nem na cara dele;
##   - o ponto de spawn sai do navmesh quando ele cobre a area e, quando nao
##     cobre (que e o caso da cidade da stage_1), de raycast no chao fisico,
##     exigindo que o ponto esteja sobre o grid de ruas do ShadowRoads.
##
## Quem liga isto e a `stage_1.gd`, e SO no Capitulo 1: no prologo o mapa tem
## de continuar vazio.

@export_group("Inimigos")
## Cenas sorteadas a cada nascimento. Vazio = zombie_1 + the_cobalt_husker.
@export var enemy_scenes: Array[PackedScene] = []
## Quantos podem estar vivos ao mesmo tempo vindos daqui.
@export var max_active: int = 3
## Sobrescreve o `distance_to_aproach` do inimigo, para que ele perceba o
## jogador a partir do anel onde nasceu. 0 = deixa o valor da cena.
@export var distance_to_aproach: float = 45.0

@export_group("Ritmo")
## Espera antes do primeiro inimigo, contada do inicio do capitulo. Da tempo da
## intro do Capitulo 1 sair da tela.
@export var initial_delay: float = 20.0
## Faixa de espera entre um nascimento e o proximo, sorteada a cada vez.
@export var min_interval: float = 12.0
@export var max_interval: float = 35.0
## De quanto em quanto tempo o sistema reavalia quem entra e quem sai.
@export var tick_interval: float = 0.5
## Tentativas de sorteio de ponto antes de desistir e tentar no proximo tick.
@export var spawn_tries: int = 12

@export_group("Distancias")
## Anel (em metros) onde os inimigos nascem, medido a partir do jogador.
@export var spawn_ring_min: float = 15.0
@export var spawn_ring_max: float = 35.0
## Dentro deste raio nunca se apaga ninguem, visivel ou nao.
@export var keep_distance: float = 60.0
## Alem disso o inimigo e liberado da memoria assim que sair da tela.
@export var despawn_distance: float = 90.0
## Alem disso some mesmo estando na tela (a nevoa ja o engoliu).
@export var hard_despawn_distance: float = 140.0
## Distancia minima entre dois inimigos recem nascidos.
@export var min_spacing: float = 8.0

@export_group("Terreno")
## Tolerancia horizontal ao encaixar o ponto sorteado no navmesh.
@export var nav_snap_tolerance: float = 2.5
## Camadas fisicas do chao. Na stage_1 o terreno e os pisos estao na camada 2.
@export_flags_3d_physics var ground_mask: int = 2
## Desnivel maximo aceito entre o jogador e o ponto de spawn. Segura o caso do
## raycast acertar a laje de um predio ou o fundo de um buraco.
@export var max_height_diff: float = 6.0
## Nome do no das ruas da cidade (fonte do grid do ShadowRoads).
@export var road_node_name: String = "Roads"
## Alternativa ao nome: nos de rua marcados neste grupo.
@export var road_group: String = "shadow_road"

@export_group("Camera")
## Impede que inimigos nascam dentro do campo de visao.
@export var avoid_camera: bool = true
## A partir desta distancia aceita-se nascer na tela.
@export var onscreen_ok_beyond: float = 28.0

@export_group("Debug")
@export var debug_log: bool = false

## Sentinela de "nao achei ponto". Evita devolver Variant/null, que o projeto
## trata como erro de parse (INFERRED_DECLARATION).
const NO_SPOT := Vector3(0.0, -99999.0, 0.0)

## Cada item: {raiz: Node3D da cena do inimigo, corpo: CharacterBody3D dele}.
var _spawned: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _tick := 0.0
var _cooldown := 0.0
var _player: Node3D = null
var _player_retry := 0.0
var _warned_no_nav := false


func _ready() -> void:
	_rng.randomize()
	if enemy_scenes.is_empty():
		_carrega_cenas_padrao()
	if enemy_scenes.is_empty():
		push_error("EnemySpawner: nenhuma cena de inimigo; a cidade fica sem encontros.")
		set_physics_process(false)
		return
	ShadowRoads.setup(get_tree(), road_node_name, road_group)
	_cooldown = initial_delay


func _carrega_cenas_padrao() -> void:
	for caminho in [
		"res://scenes/enemies/zombie_1.tscn",
		"res://scenes/enemies/the_cobalt_husker.tscn",
	]:
		var cena := load(caminho) as PackedScene
		if cena != null:
			enemy_scenes.append(cena)


# ------------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = tick_interval

	if not is_instance_valid(_player):
		_player_retry -= tick_interval
		if _player_retry <= 0.0:
			_player = _acha_player()
			_player_retry = 1.0
		if not is_instance_valid(_player):
			return

	var cam := get_viewport().get_camera_3d()
	var ppos := _player.global_position

	_limpa_e_recolhe(ppos, cam)

	# Durante cutscene o relogio nem anda: um zumbi brotando no meio de um
	# dialogo estraga a cena, e o jogador nao tem como reagir.
	if GlobalEvents.in_cutscene:
		return

	_cooldown -= tick_interval
	if _cooldown > 0.0:
		return
	if _vivos() >= max_active:
		return

	var pos := _sorteia_ponto(ppos, cam)
	if pos == NO_SPOT:
		# Nao achou lugar bom agora (jogador dentro de um beco, tudo na tela):
		# tenta de novo logo, sem gastar o intervalo cheio.
		_cooldown = 1.0
		return

	_nasce(pos, ppos)
	_cooldown = _rng.randf_range(min_interval, max_interval)


## Apaga da memoria quem ficou para tras e esquece quem saiu daqui (o amuleto
## leva os inimigos selecionados para a arena, tirando-os desta arvore).
func _limpa_e_recolhe(ppos: Vector3, cam: Camera3D) -> void:
	for i in range(_spawned.size() - 1, -1, -1):
		var reg: Dictionary = _spawned[i]
		# Sem tipo: um destes pode ja ter sido liberado (o corpo se apaga sozinho
		# depois da animacao de morte), e a atribuicao tipada estoura antes do
		# `is_instance_valid`.
		var raiz = reg["raiz"]
		var corpo = reg["corpo"]

		# O corpo morto se libera sozinho depois da animacao; sobra a raiz vazia.
		# O amuleto tambem reparenta o corpo para a arena.
		if not is_instance_valid(corpo) or corpo.get_parent() != raiz:
			if is_instance_valid(raiz):
				raiz.queue_free()
			_spawned.remove_at(i)
			continue

		if not is_instance_valid(raiz):
			_spawned.remove_at(i)
			continue

		# Quem esta morrendo fica: cortar a animacao de morte no meio, ainda por
		# cima logo depois do jogador matar o bicho, e pior que manter o corpo.
		if "dead" in corpo and corpo.dead:
			continue

		var d := ppos.distance_to(corpo.global_position)
		if d <= keep_distance:
			continue
		if d > hard_despawn_distance or (d > despawn_distance and _fora_da_tela(cam, corpo.global_position)):
			if debug_log:
				print("EnemySpawner: liberando ", raiz.name, " a ", int(d), " m.")
			_libera(raiz, corpo)
			_spawned.remove_at(i)


## Tira o inimigo da memoria sem nada na tela. Some pelas costas do jogador, a
## dezenas de metros: nao pode virar barra de vida de chefe no topo da tela nem
## pagar iron rusks — para ele, aquele zumbi nunca existiu.
##
## Os parametros vao sem tipo de proposito: `clear_all` pode chegar aqui com um
## no ja liberado, e atribuir isso a uma variavel tipada estoura em tempo de
## execucao antes mesmo do `is_instance_valid`.
func _libera(raiz, corpo) -> void:
	if is_instance_valid(corpo) and corpo.has_method("remover_em_silencio"):
		corpo.remover_em_silencio()
	if is_instance_valid(raiz):
		raiz.queue_free()


## Quantos contam para o teto. Os que ja morreram nao seguram a vaga do
## proximo: senao o mapa ficaria parado por 20 s depois de cada briga.
func _vivos() -> int:
	var n := 0
	for reg in _spawned:
		var corpo = reg["corpo"]
		if is_instance_valid(corpo) and not ("dead" in corpo and corpo.dead):
			n += 1
	return n


# ----------------------------------------------------------- nascimento

func _nasce(pos: Vector3, ppos: Vector3) -> void:
	var cena: PackedScene = enemy_scenes[_rng.randi() % enemy_scenes.size()]
	var raiz := cena.instantiate() as Node3D
	if raiz == null:
		return
	add_child(raiz)
	raiz.global_position = pos
	# De cara olhando para o jogador, senao o primeiro giro dele parece um
	# despertar em camera lenta.
	var alvo := Vector3(ppos.x, pos.y, ppos.z)
	if pos.distance_to(alvo) > 0.5:
		raiz.look_at(alvo, Vector3.UP)

	var corpo := _acha_corpo(raiz)
	if corpo == null:
		raiz.queue_free()
		return
	if distance_to_aproach > 0.0 and "distance_to_aproach" in corpo:
		corpo.distance_to_aproach = distance_to_aproach

	_spawned.append({"raiz": raiz, "corpo": corpo})
	if debug_log:
		print("EnemySpawner: ", raiz.name, " nasceu a ", int(ppos.distance_to(pos)), " m.")


## As cenas de inimigo sao um Node3D de embrulho com o CharacterBody3D "enemy"
## dentro; e o corpo que anda, leva dano e entra no grupo "enemies".
func _acha_corpo(raiz: Node3D) -> Node3D:
	if raiz is CharacterBody3D:
		return raiz
	for c in raiz.get_children():
		if c is CharacterBody3D:
			return c as CharacterBody3D
	return null


## Sorteia um ponto no anel ao redor do jogador que esteja no chao, na rua,
## longe dos outros inimigos e fora do campo de visao. NO_SPOT se nao achar
## nada bom neste tick — melhor esperar do que fazer um zumbi brotar na frente
## da camera.
func _sorteia_ponto(ppos: Vector3, cam: Camera3D) -> Vector3:
	var map := get_world_3d().navigation_map
	var tem_nav := NavigationServer3D.map_get_iteration_id(map) > 0 \
		and not NavigationServer3D.map_get_regions(map).is_empty()

	for _i in spawn_tries:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(spawn_ring_min, spawn_ring_max)
		var cand := ppos + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)

		var pos := _encaixa_no_chao(cand, map, tem_nav)
		if pos == NO_SPOT:
			continue
		# telhado, laje ou fundo de buraco: longe demais do nivel do jogador
		if absf(pos.y - ppos.y) > max_height_diff:
			continue
		# na rua: dentro de um predio o inimigo nasceria preso na parede
		if ShadowRoads.has_map() and not ShadowRoads.is_road(pos):
			continue

		var real_d := ppos.distance_to(pos)
		if real_d < spawn_ring_min or real_d > spawn_ring_max:
			continue
		if avoid_camera and real_d < onscreen_ok_beyond and not _fora_da_tela(cam, pos):
			continue
		if _perto_demais_de_outro(pos):
			continue
		return pos
	return NO_SPOT


## Encaixa o candidato no chao. Prefere o navmesh, onde o ponto e andavel por
## construcao. Na stage_1 o navmesh nao cobre a cidade (fica a ~200 m de onde
## se joga), entao o normal e cair no raycast contra a camada 2.
func _encaixa_no_chao(cand: Vector3, map: RID, tem_nav: bool) -> Vector3:
	if tem_nav:
		var snapped := NavigationServer3D.map_get_closest_point(map, cand)
		if Vector2(snapped.x - cand.x, snapped.z - cand.z).length() <= nav_snap_tolerance:
			return snapped
		if not _warned_no_nav:
			_warned_no_nav = true
			push_warning("EnemySpawner: navmesh nao cobre esta area; usando o chao fisico.")
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cand + Vector3.UP * 40.0, cand + Vector3.DOWN * 40.0, ground_mask)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NO_SPOT
	return hit["position"]


func _perto_demais_de_outro(pos: Vector3) -> bool:
	for reg in _spawned:
		var corpo = reg["corpo"]
		if is_instance_valid(corpo) and corpo.global_position.distance_to(pos) < min_spacing:
			return true
	return false


## Fora do campo de visao. Mede na altura do peito: um ponto no chao pode cair
## logo abaixo da borda da tela enquanto o corpo ainda aparece.
func _fora_da_tela(cam: Camera3D, pos: Vector3) -> bool:
	if cam == null:
		return true
	return not cam.is_position_in_frustum(pos + Vector3.UP * 1.0)


func _acha_player() -> Node3D:
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

## Quantos inimigos deste spawner estao vivos agora.
func active_count() -> int:
	return _vivos()


## Apaga todos os que ainda estao aqui e segura os proximos por `pausa`
## segundos. Util antes de uma cutscene.
func clear_all(pausa := 0.0) -> void:
	for reg in _spawned:
		_libera(reg["raiz"], reg["corpo"])
	_spawned.clear()
	_cooldown = maxf(_cooldown, pausa)
