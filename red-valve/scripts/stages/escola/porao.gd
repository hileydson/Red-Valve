extends Node3D

## O porão da escola: o túnel de barro cavado por baixo dela.
##
## Geometria, luz, entulho, colisão e navmesh são gerados por
## `tools/godot/escola/gerar_cena_porao.py` a partir do traçado em
## `tools/godot/escola/porao.py`. Este script cuida só do comportamento.
##
## ==========================================================================
## POR QUE ESTA CENA É TÃO ESCURA
##
## Foi pedido assim: aqui a lanterna deixa de ser conforto e vira ferramenta. A
## `ambient_light_energy` do ambiente é 0,42 contra 1,75 da escola, e as
## lâmpadas do teto são poucas, fracas e a maioria morta — elas MARCAM o
## caminho, não o iluminam. Ver a próxima lâmpada acesa a vinte metros no preto
## é a única orientação que o jogador tem aqui dentro.
##
## Por isso este script faz uma coisa que o da escola não faz: se o jogador
## chega sem a lanterna no inventário, ele avisa. Sem o aviso, quem desceu sem
## ela acha que o jogo quebrou, e não que ele esqueceu alguma coisa.
##
## ==========================================================================
## AS DUAS BOCAS
##
## O túnel liga os dois buracos da escola e anda nos DOIS sentidos:
##
##     boca_entrada  ->  o buraco do DEPÓSITO      (canto sudeste da escola)
##     boca_saida    ->  o buraco do ALMOXARIFADO  (canto sudoeste)
##
## Quem desce pelo depósito nasce na boca de entrada; quem desce de volta pelo
## almoxarifado nasce na de saída. Mão dupla de propósito — ver `buraco.gd`.

const LAYER_CHAO := 2
const CENA_ESCOLA := "res://scenes/stages/escola/escola.tscn"
const TEMPO_FADE := 2.0

## Depois de quanto tempo no escuro o aviso da lanterna aparece. Não é na hora:
## o jogador acabou de trocar de cena e a tela ainda está clareando do fade.
const ESPERA_AVISO := 2.6

@onready var fade: ColorRect = $fade

var _lampadas: Array[Dictionary] = []
var _saindo: bool = false


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()

	_conferir_colisao()
	_preparar_lampadas()
	_posicionar_jogador()

	SaveManager.save_game()
	GlobalUtils.mostrar_objetivo(tr("OBJ_POR_ATRAVESSAR"))
	_avisar_da_lanterna()


func _conferir_colisao() -> void:
	var fora := 0
	for corpo in find_children("*", "StaticBody3D", true, false):
		if corpo.collision_layer != LAYER_CHAO:
			corpo.collision_layer = LAYER_CHAO
			corpo.collision_mask = 0
			fora += 1
	if fora > 0:
		push_warning("porao: %d corpo(s) estático(s) estavam fora da layer %d"
			% [fora, LAYER_CHAO])


## Por qual das duas bocas o jogador entrou. O marcador mora na cena gerada, e
## não em constante aqui: mexer no traçado move a boca, e uma coordenada
## escrita neste arquivo ficaria mentindo até alguém nascer dentro da terra.
func _posicionar_jogador() -> void:
	var destino := String(GlobalEvents.porao_chegada)
	GlobalEvents.porao_chegada = ""
	if destino.is_empty():
		return
	var marcador := get_node_or_null("chegada_" + destino) as Node3D
	var jogador := _jogador()
	if marcador == null or jogador == null:
		return
	jogador.global_position = marcador.global_position
	jogador.global_rotation.y = marcador.global_rotation.y


func _jogador() -> Node3D:
	var no := get_node_or_null("Player") as Node3D
	if no == null:
		no = get_tree().get_first_node_in_group("player") as Node3D
	return no


## O aviso da lanterna. Só aparece se ele realmente não tiver o item: quem já
## a pegou na igreja não precisa de tutorial nenhum.
func _avisar_da_lanterna() -> void:
	if SaveManager.tem_item("lanterna"):
		return
	await get_tree().create_timer(ESPERA_AVISO).timeout
	if is_instance_valid(self):
		GlobalUtils.show_center_message(
			"porao_lanterna", tr("AVISO_POR_SEM_LANTERNA"), 18, 5.0)


func _preparar_lampadas() -> void:
	for luz in find_children("*", "Light3D", true, false):
		if not luz.has_meta("piscar"):
			continue
		_lampadas.append({
			"luz": luz,
			"tipo": String(luz.get_meta("piscar")),
			"base": (luz as Light3D).light_energy,
			"proximo": randf() * 0.5,
		})


## Chamada pelas duas bocas (`buraco.gd`).
##
## `papel` é "boca_entrada" ou "boca_saida"; daí sai por qual buraco da escola
## o jogador reaparece. O nome do destino é o do CÔMODO, e não o do buraco: é
## assim que `escola.gd` procura o marcador dele.
func usar_buraco(papel: String) -> void:
	if _saindo:
		return
	_saindo = true
	GlobalEvents.escola_chegada = ("deposito" if papel == "boca_entrada"
		else "almoxarifado")
	GlobalEvents.in_cutscene = true
	GlobalUtils.esconder_objetivo()
	fade.fade_out()
	await get_tree().create_timer(TEMPO_FADE).timeout
	LoadingScreen.load_scene(CENA_ESCOLA)


func _process(delta: float) -> void:
	for lamp in _lampadas:
		var luz: Light3D = lamp["luz"]
		if not is_instance_valid(luz):
			continue
		lamp["proximo"] -= delta
		if lamp["proximo"] > 0.0:
			continue
		if lamp["tipo"] == "nervoso":
			# A lâmpada pelada no fio balança, e o reator dela está indo. O
			# tremor aqui é mais largo que o da escola de propósito: é o que
			# se vê de longe, e é ele que faz o jogador reparar que ainda tem
			# uma acesa lá na frente.
			luz.light_energy = lamp["base"] * randf_range(0.55, 1.25)
			lamp["proximo"] = randf_range(0.06, 0.30)
		else:
			var acesa := randf() < 0.11
			luz.light_energy = lamp["base"] * (randf_range(0.8, 1.7) if acesa else 0.0)
			lamp["proximo"] = randf_range(0.05, 0.3) if acesa else randf_range(0.9, 4.2)
