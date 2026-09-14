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

const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"
const CENA_ITEM_OBTIDO := "res://scenes/ui/item_obtido.tscn"
const ITEM_LANTERNA := "lanterna"
const MODELO_LANTERNA := "res://assets/3d_model/player/lanterna/lanterna.glb"

## A layer em que o chão do jogo vive. O player é `CharacterBody3D` com
## `collision_mask = 2`: ele SÓ enxerga a layer 2. O importador de .glb cria o
## StaticBody3D do `-colonly` na layer 1, e o jogador atravessaria a igreja
## inteira em queda livre. Corrigir aqui, e não na cena, porque a cena é
## regerada por script e o corpo importado nem aparece nela.
const LAYER_CHAO := 2

@onready var fade: ColorRect = $fade

var player_na_porta: bool = false
var player_na_lanterna: bool = false
var _saindo: bool = false
var _pegando_lanterna: bool = false

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

	# save_game() toma o caminho da cena atual como checkpoint — igual à casa
	# do Jimmy, a igreja vale como ponto de retorno.
	SaveManager.save_game()

	var area := get_node_or_null("porta") as Area3D
	if area:
		if not area.body_entered.is_connected(_ao_entrar_na_porta):
			area.body_entered.connect(_ao_entrar_na_porta)
		if not area.body_exited.is_connected(_ao_sair_da_porta):
			area.body_exited.connect(_ao_sair_da_porta)

	_preparar_lanterna_do_chao()


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

	if _saindo or _pegando_lanterna or GlobalEvents.in_cutscene \
			or GlobalUtils.in_cinematic_cutscene:
		return

	if Input.is_action_just_pressed("ui_accept"):
		# a lanterna primeiro: quem está em cima dela quer pegá-la, não sair
		if player_na_lanterna:
			_pegar_lanterna()
		elif player_na_porta:
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


# ==============================================================================
# A LANTERNA DO CHÃO
# ==============================================================================
## Prepara (ou remove) a lanterna largada perto do portal.
##
## Ela é um evento de uma vez só: quem já pegou não a encontra de novo ao
## voltar aqui. A checagem é no inventário salvo, e não numa flag à parte —
## assim um save antigo que já tenha a lanterna também chega com o chão vazio.
func _preparar_lanterna_do_chao() -> void:
	var conjunto := get_node_or_null("lanterna_no_chao")
	if conjunto == null:
		return
	if SaveManager.tem_item(ITEM_LANTERNA):
		conjunto.queue_free()
		return
	var area := conjunto.get_node_or_null("area") as Area3D
	if area:
		if not area.body_entered.is_connected(_ao_entrar_na_lanterna):
			area.body_entered.connect(_ao_entrar_na_lanterna)
		if not area.body_exited.is_connected(_ao_sair_da_lanterna):
			area.body_exited.connect(_ao_sair_da_lanterna)


func _ao_entrar_na_lanterna(body: Node3D) -> void:
	if not _eh_player(body):
		return
	player_na_lanterna = true
	GlobalUtils.show_center_message("pegar_lanterna", tr("PROMPT_TAKE_FLASHLIGHT"), 16)


func _ao_sair_da_lanterna(body: Node3D) -> void:
	if not _eh_player(body):
		return
	player_na_lanterna = false
	GlobalUtils.hide_center_message("pegar_lanterna")


func _pegar_lanterna() -> void:
	_pegando_lanterna = true
	player_na_lanterna = false
	GlobalUtils.hide_center_message("pegar_lanterna")

	SaveManager.add_item(ITEM_LANTERNA, 1)
	SaveManager.save_game()

	var conjunto := get_node_or_null("lanterna_no_chao")
	if conjunto:
		conjunto.queue_free()

	# Espera o prompt sumir ANTES de abrir a tela. `hide_center_message` apaga
	# com um tween de meio segundo, e tween não anda com a árvore pausada — sem
	# esta pausa o "Pegar a lanterna?" ficava congelado atrás do modelo 3D até
	# o jogador fechar a tela.
	await get_tree().create_timer(0.55).timeout

	# A mensagem muda com o dispositivo em uso: quem está no controle procura
	# L3, quem está no teclado procura Y, e falar do botão errado é pior do que
	# não falar de botão nenhum.
	var chave := "PICKUP_FLASHLIGHT_L3" if GlobalEvents.usando_controle \
		else "PICKUP_FLASHLIGHT_KEY"
	var tela: CanvasLayer = load(CENA_ITEM_OBTIDO).instantiate()
	tela.model_path = MODELO_LANTERNA
	tela.texto = tr(chave)
	get_tree().root.add_child(tela)
	await tela.fechado

	# Sai daqui já acesa: o jogador acabou de ver "aperte L3 para ativá-la", e
	# ficar no escuro logo depois de pegar uma lanterna acesa do chão seria
	# exatamente o contrário do que a cena mostrou.
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador and jogador.has_method("acender_lanterna_agora"):
		jogador.acender_lanterna_agora()
	_pegando_lanterna = false


func _sair_da_igreja() -> void:
	_saindo = true
	player_na_porta = false
	GlobalEvents.in_cutscene = true
	GlobalUtils.hide_center_message("interacao_igreja")

	# Marca a volta ANTES de trocar de cena: o stage_1 consome isto no spawn
	# para pôr o jogador de volta no adro, de frente para o portal.
	GlobalEvents.voltando_da_igreja = true

	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	LoadingScreen.load_scene(CENA_MAPA)


func _ao_entrar_na_porta(body: Node3D) -> void:
	if not _eh_player(body):
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
