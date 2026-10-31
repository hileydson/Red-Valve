extends Node3D

## Interior da igreja da cidade.
##
## Mesma mecânica da casa do Jimmy e da casa do Maycow: cena fechada, o jogador
## entra pelo portal lá no mapa e volta pela mesma porta. Quem devolve ele na
## soleira certa é `GlobalEvents.voltando_da_igreja`, lido pelo stage_1 no
## spawn — sem isso ele reapareceria no ponto de entrada padrão do mapa, do
## outro lado da cidade.
##
## O modelo é gerado por `tools/blender/igreja/gerar_igreja.py` e a cena por
## `tools/godot/igreja/gerar_cena_igreja.py`; este script cuida só do que é
## comportamento: colisão, luz que treme e a saída.
##
## O evento da Dona Nice (cutscene, luta, o Jonny) é um componente à parte,
## `evento_dona_nice.gd`, criado aqui — a cena gerada não sabe dele, e assim
## regerar a igreja não apaga nada do evento.

const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"
const EVENTO := preload("res://scripts/stages/igreja/evento_dona_nice.gd")
## O despertar no pentagrama (fim do Capítulo 4, começo do 5).
const DESPERTAR := preload("res://scripts/stages/igreja/despertar_capitulo_5.gd")
## A seringa de adrenalina da igreja, no `item_secreto` da galeria (a
## interrogacao do mapa). Posta por codigo: a cena da igreja e' regerada por
## script, e no' colocado a mao no .tscn some na proxima geracao.
const SERINGA := preload("res://scenes/stages/igreja/seringa_igreja.tscn")

## A layer em que o chão do jogo vive. O player é `CharacterBody3D` com
## `collision_mask = 2`: ele SÓ enxerga a layer 2. O importador de .glb cria o
## StaticBody3D do `-colonly` na layer 1, e o jogador atravessaria a igreja
## inteira em queda livre. Corrigir aqui, e não na cena, porque a cena é
## regerada por script e o corpo importado nem aparece nela.
const LAYER_CHAO := 2

@onready var fade: ColorRect = $fade

var player_na_porta: bool = false
var _saindo: bool = false
var _evento: Node = null

## Luzes com metadata "piscar" (as tochas e os candelabros). Guarda a energia
## original de cada uma: o tremor oscila em torno dela, senão uma vela e um
## feixe de janela acabariam na mesma intensidade.
var _lampadas_piscando: Array[Dictionary] = []


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()

	_corrigir_colisao()
	_preparar_lampadas()
	_por_seringa()

	# save_game() toma o caminho da cena atual como checkpoint — igual à casa
	# do Jimmy, a igreja vale como ponto de retorno.
	SaveManager.save_game()

	var area := get_node_or_null("porta") as Area3D
	if area:
		if not area.body_entered.is_connected(_ao_entrar_na_porta):
			area.body_entered.connect(_ao_entrar_na_porta)
		if not area.body_exited.is_connected(_ao_sair_da_porta):
			area.body_exited.connect(_ao_sair_da_porta)

	# `sem_evento`: harness de foto/teste que quer a igreja vazia
	if not has_meta("sem_evento"):
		_evento = EVENTO.new()
		_evento.name = "evento_dona_nice"
		add_child(_evento)
		# fim do Capítulo 4: ele acorda no pentagrama (usa a cena do evento)
		if Eventos.despertar_na_igreja():
			var despertar = DESPERTAR.new()
			despertar.name = "despertar_capitulo_5"
			add_child(despertar)
			despertar.rodar(self, _evento)


## A seringa vai no marcador; ja' pega, ela mesma se apaga (`item_de_balcao`).
func _por_seringa() -> void:
	var marca := get_node_or_null("item_secreto") as Node3D
	if marca == null:
		return
	var seringa := SERINGA.instantiate() as Node3D
	add_child(seringa)
	# o marcador fica uns 18 cm acima do piso da galeria: a seringa desce ate'
	# o chao que tiver embaixo dele
	var pos := marca.global_position
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 2.0)
	var chao: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not chao.is_empty():
		pos = chao["position"]
	seringa.global_position = pos


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
		push_warning("igreja: nenhuma colisão no modelo — o .glb foi importado "
			+ "sem o objeto CL_igreja-colonly?")


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
		})


func _process(delta: float) -> void:
	_atualizar_lampadas(delta)

	if _saindo or GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return

	if Input.is_action_just_pressed("ui_accept") and player_na_porta \
			and not _luta_em_andamento():
		_sair_da_igreja()


## Duas falhas diferentes, como na casa do Jimmy: a "nervosa" é chama de tocha,
## que treme o tempo todo; a "quebrada" ficou quase apagada e só dá estouros
## curtos — é o que faz o fundo da nave respirar em vez de ficar parado.
func _atualizar_lampadas(delta: float) -> void:
	for lamp in _lampadas_piscando:
		var luz: Light3D = lamp["luz"]
		if not is_instance_valid(luz):
			continue
		lamp["proximo"] -= delta
		if lamp["proximo"] > 0.0:
			continue
		if lamp["tipo"] == "nervoso":
			luz.light_energy = lamp["base"] * randf_range(0.72, 1.18)
			lamp["proximo"] = randf_range(0.05, 0.2)
		else:
			var acesa := randf() < 0.15
			luz.light_energy = lamp["base"] * (randf_range(0.8, 1.5) if acesa else 0.05)
			lamp["proximo"] = randf_range(0.06, 0.4) if acesa else randf_range(0.8, 3.4)


func _sair_da_igreja() -> void:
	_saindo = true
	player_na_porta = false
	GlobalEvents.in_cutscene = true
	GlobalUtils.hide_center_message("interacao_igreja")

	# Marca a volta ANTES de trocar de cena: o stage_1 consome isto no spawn
	# para pôr o jogador de volta no adro, de frente para o portal.
	GlobalEvents.voltando_da_igreja = true
	# Capítulo 5: saindo depois de acordar no pentagrama, as forças voltam e o
	# objetivo aparece lá fora (a cidade grava ao abrir)
	if Eventos.pode(Eventos.CAP5_SAIU_IGREJA):
		Eventos.concluir(Eventos.CAP5_SAIU_IGREJA, false)

	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	LoadingScreen.load_scene(CENA_MAPA)


## Durante a luta a porta nao serve: fugir no meio deixaria a Dona Nice
## parada esperando, e a volta recomecaria a fase de qualquer jeito.
func _luta_em_andamento() -> bool:
	return is_instance_valid(_evento) and _evento.luta_em_andamento()


func _ao_entrar_na_porta(body: Node3D) -> void:
	if not _eh_player(body):
		return
	# durante a cutscene (o Maycow para encostado na porta) e a luta, nada de
	# "Sair da igreja?"
	if _luta_em_andamento() or GlobalEvents.in_cutscene:
		return
	player_na_porta = true
	GlobalUtils.show_center_message("interacao_igreja", tr("PROMPT_LEAVE_CHURCH"), 16)


func _ao_sair_da_porta(body: Node3D) -> void:
	if not _eh_player(body):
		return
	player_na_porta = false
	GlobalUtils.hide_center_message("interacao_igreja")


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
