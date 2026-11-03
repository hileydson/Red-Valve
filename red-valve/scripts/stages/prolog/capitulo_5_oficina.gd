extends Node

## A OFICINA DO JIMMY NO CAPÍTULO 5.
##
## A cena da oficina é a do prólogo (`oficina_jimmy.tscn`: o filme, a luta com
## o Husk, as peças voando). Do Capítulo 5 em diante ela vira um lugar comum, e
## é esta peça que assume, antes de o filme começar (`assumir`, chamado no topo
## do `_ready` da oficina):
##
##  - sem filme, sem Husk, sem o redemoinho; as peças ficam paradas no chão e
##    uma luz de trabalho acende no meio do galpão;
##  - o armário fica arrastado (como o prólogo deixou) e, no lugar do portal
##    de lá, uma RED VALVE de verdade (`porta_red_valve.tscn`) que leva ao
##    começo do inferno 1. Na primeira vez (`Eventos.CAP5_RED_VALVE_OFICINA`),
##    chegar perto dela roda a cena em primeira pessoa da escola
##    (`cutscene_red_valve.gd`) — o mesmo jeito de entrar da red valve do
##    calabouço. Depois, ela pergunta. Quem volta do inferno 1 sai cuspido por
##    ela (o ponto de chegada é o nome dela);
##  - a porta da rua (onde se nasce vindo da cidade) pergunta e devolve o
##    Maycow à calçada (`GlobalEvents.voltando_da_oficina`);
##  - depois da arena 3 (`Eventos.conversa_na_oficina`), a red valve cospe o
##    Maycow e o Jimmy e roda a CONVERSA (`cutscene_conversa_oficina.gd`). No
##    fim dela o save já aponta pra cidade, e a cidade abre do preto devagar.
##
## Sem `class_name` (ver [[project-class-name-travado]]): preload deste script.

const ESTE := "res://scripts/stages/prolog/capitulo_5_oficina.gd"
const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"
const CENA_INFERNO_1 := "res://scenes/stages/inferno/inferno.tscn"
const PORTA_RED_VALVE := preload("res://scenes/effects/porta_red_valve.tscn")
const CutsceneRedValve := preload("res://scripts/stages/escola/cutscene_red_valve.gd")
const CutsceneConversa := preload("res://scripts/cutscenes/cutscene_conversa_oficina.gd")
const Capitulo5Cidade := preload("res://scripts/stages/stage_1/capitulo_5_cidade.gd")
const ViagemPortal := preload("res://scripts/systems/viagem_portal.gd")

## O nome da porta: é o ponto de chegada de quem volta pelo portal do começo do
## inferno 1.
const NOME_PORTA := "red_valve"
## Onde ela fica: logo na frente do lugar do portal do prólogo (-6,42; -6,49),
## encostada na estante do fundo — no ponto exato dele há uma peça da estante
## (o chão sai de um raio).
const LUGAR_PORTA := Vector3(-6.42, 0.0, -5.75)
## A porta da rua: é onde se nasce vindo da cidade.
const SAIDA := Vector3(4.54, 0.0, 2.91)
const RAIO_SAIDA := 2.2
## A que distância da frente da red valve a primeira travessia começa.
const RAIO_CENA := 4.2
const LAYER_CHAO := 2
## A altura do piso do galpão.
const PISO := -5.32

var oficina: Node3D
var player: CharacterBody3D
var porta: Node3D

var _cutscene_armada := false
var _saida_armada := false
var _perguntando_saida := false
var _saindo := false
var _em_cena := false


## Chamado no topo do `_ready` da oficina. Devolve true quando a oficina é a
## do Capítulo 5 (e o filme do prólogo não deve rodar).
static func assumir(dono: Node3D) -> bool:
	if not SaveManager.prolog_finished or Eventos.capitulo_atual() != Eventos.CAPITULO_5:
		return false
	var c = (load(ESTE) as GDScript).new()
	c.name = "capitulo_5_oficina"
	dono.add_child(c)
	c.iniciar(dono)
	return true


func iniciar(dono: Node3D) -> void:
	oficina = dono
	player = oficina.get_node_or_null("Player") as CharacterBody3D
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	GlobalUtils.esconder_objetivo()
	# o filme do prólogo (a câmera que treme, o Husk em câmera lenta) não roda
	oficina.set_process(false)
	_desmontar_o_prologo()
	_montar_red_valve()
	if is_instance_valid(player) and player.has_method("cutscene_set_camera_current"):
		player.cutscene_set_camera_current(true)

	if Eventos.conversa_na_oficina():
		_conversa.call_deferred()
		return
	SaveManager.save_game()
	var ponto := ViagemPortal.pegar_chegada(oficina.scene_file_path)
	if ponto == NOME_PORTA and porta and is_instance_valid(player):
		porta.chegar.call_deferred(player)
	if Eventos.oficina_aberta():
		if Eventos.pode(Eventos.CAP5_RED_VALVE_OFICINA):
			porta.set("bloqueada", true)
			_cutscene_armada = true
		else:
			porta.set("com_prompt", true)
		_mostrar_objetivo()
	else:
		# Capítulo 5 fora do caminho do Jimmy (debug): a porta não abre
		porta.set("bloqueada", true)


func _mostrar_objetivo() -> void:
	await get_tree().create_timer(1.8, false).timeout
	var chave := Eventos.objetivo_atual()
	if is_inside_tree() and chave != "":
		GlobalUtils.mostrar_objetivo(tr(chave), 30.0)


# ==============================================================================
# A OFICINA SEM O PRÓLOGO
# ==============================================================================

func _desmontar_o_prologo() -> void:
	for caminho in ["TheCobaltHusker", "cutscene", "camera_oficina", "portal/camera_inicio_cutscene",
			"HeatDistortionFilter", "portal/portal_red_valve", "auto_pecas_jimmy/VortexMagico"]:
		var no := oficina.get_node_or_null(caminho)
		if no:
			no.queue_free()
	var musica := oficina.get_node_or_null("SongFirstBattle") as AudioStreamPlayer
	if musica:
		musica.stop()
	for caminho in ["FireCracling", "AmbientNoiseSlow"]:
		var s := oficina.get_node_or_null(caminho) as AudioStreamPlayer
		if s:
			s.volume_db -= 8.0
	# as peças do prólogo voavam e machucavam: aqui ficam paradas no chão
	var pecas := oficina.get_node_or_null("pecas")
	if pecas:
		pecas.process_mode = Node.PROCESS_MODE_DISABLED
		for peca in pecas.get_children():
			for filho in peca.get_children():
				if filho is Area3D:
					filho.queue_free()
	# o armário arrastado, como o prólogo deixou (`_arrastar_estante`)
	var armario := oficina.get_node_or_null("portal/armario") as Node3D
	if armario:
		armario.global_position -= armario.global_transform.basis.x * 1.9
	# sem o redemoinho do prólogo o galpão fica no breu: a luz de trabalho
	var luz := OmniLight3D.new()
	luz.name = "luz_de_trabalho"
	luz.light_color = Color(1.0, 0.82, 0.62)
	luz.light_energy = 1.7
	luz.omni_range = 17.0
	luz.omni_attenuation = 0.8
	luz.shadow_enabled = true
	oficina.add_child(luz)
	luz.global_position = Vector3(-1.0, _chao(Vector3(-1.0, 0.0, -1.0)) + 3.8, -1.0)


func _montar_red_valve() -> void:
	porta = PORTA_RED_VALVE.instantiate() as Node3D
	porta.name = NOME_PORTA
	porta.set("cena_destino", CENA_INFERNO_1)
	porta.set("ponto_destino", "spawn_entrada")
	oficina.add_child(porta)
	porta.global_position = Vector3(LUGAR_PORTA.x, _chao(LUGAR_PORTA), LUGAR_PORTA.z)
	# olhando pro +Z: pro meio do galpão, de onde o Maycow vem


## O piso da oficina embaixo de `xz` (a layer do chão). O raio sai rente ao
## piso (-5,32): de cima ele bate no teto e no mezanino do fundo do galpão (a
## colisão do galpão é uma malha só).
func _chao(xz: Vector3) -> float:
	var de := Vector3(xz.x, PISO + 1.2, xz.z)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 4.0, LAYER_CHAO)
	var h := oficina.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return PISO
	return (h.position as Vector3).y


# ==============================================================================
# O QUE SE CHECA A CADA QUADRO
# ==============================================================================

func _process(_delta: float) -> void:
	if _em_cena or _saindo or not is_instance_valid(player) or get_tree().paused:
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		_perguntar_saida(false)
		return
	var p := player.global_position
	if _cutscene_armada and porta:
		var frente := porta.global_position + porta.global_basis.z * 0.6
		if Vector2(p.x - frente.x, p.z - frente.z).length() < RAIO_CENA:
			_primeira_travessia()
			return
	var perto := Vector2(p.x - SAIDA.x, p.z - SAIDA.z).length() < RAIO_SAIDA
	# quem acabou de entrar nasce em cima da porta: só arma depois que sair dela
	if not _saida_armada:
		_saida_armada = not perto
		return
	_perguntar_saida(perto)
	if perto and Input.is_action_just_pressed("ui_accept"):
		_sair()


func _perguntar_saida(sim: bool) -> void:
	if sim == _perguntando_saida:
		return
	_perguntando_saida = sim
	if sim:
		GlobalUtils.show_center_message("oficina_sair", tr("PROMPT_LEAVE_WORKSHOP"), 16)
	else:
		GlobalUtils.hide_center_message("oficina_sair")


func _sair() -> void:
	_saindo = true
	_perguntar_saida(false)
	GlobalEvents.in_cutscene = true
	GlobalUtils.esconder_objetivo()
	GlobalEvents.voltando_da_oficina = true
	var fade := oficina.get_node_or_null("fade")
	if fade and fade.has_method("fade_out"):
		fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	LoadingScreen.load_scene(CENA_MAPA)


# ==============================================================================
# A PRIMEIRA TRAVESSIA (a mesma cena do calabouço da escola)
# ==============================================================================

func _primeira_travessia() -> void:
	_cutscene_armada = false
	_em_cena = true
	GlobalUtils.esconder_objetivo()
	var c = CutsceneRedValve.new()
	c.name = "cutscene_red_valve"
	c.porta = porta
	c.evento = Eventos.CAP5_RED_VALVE_OFICINA
	oficina.add_child(c)
	c.rodar(oficina, player)


# ==============================================================================
# A CONVERSA (depois da arena 3)
# ==============================================================================

func _conversa() -> void:
	_em_cena = true
	var c = CutsceneConversa.new()
	c.name = "cutscene_conversa_oficina"
	c.porta = porta
	add_child(c)
	await c.rodar(oficina, player)
	# o capítulo segue na cidade: o save já vai com ela (fechar o jogo agora
	# volta pra calçada da oficina, com o Jimmy)
	Eventos.concluir(Eventos.CAP5_CONVERSA_OFICINA, false)
	SaveManager.save_game(CENA_MAPA)
	GlobalEvents.voltando_da_oficina = true
	Capitulo5Cidade.chegando_da_conversa = true
	GlobalEvents.in_cutscene = false
	LoadingScreen.load_scene(CENA_MAPA)
