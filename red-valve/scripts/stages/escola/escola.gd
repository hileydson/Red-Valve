extends Node3D

## A escola de Red Valve — um andar, com um pátio descoberto no meio.
##
## O prédio inteiro (geometria, luz, móvel, colisão, navmesh e pichação) é
## gerado por `tools/godot/escola/gerar_cena_escola.py` a partir da planta em
## `tools/godot/escola/planta.py`. Este script cuida SÓ do que é comportamento
## — o resto tem dono lá.
##
## Portas, buracos e grade têm script próprio (`porta_escola.gd`, `buraco.gd`);
## aqui fica o que é do prédio todo: o piscar das lâmpadas, onde o jogador
## nasce e as três saídas desta cena (a rua e os dois buracos).
##
## ==========================================================================
## O CAMINHO QUE ESTA FASE DESENHA
##
## O jogador chega da cidade e cai no PÁTIO. Do pátio ele entra no prédio pela
## porta principal, anda o corredor norte, desce pelo leste e trombra na GRADE,
## no meio do corredor sul. Ela não abre. O que abre é o BURACO no fundo do
## depósito, que leva ao porão (outra cena) e o devolve no ALMOXARIFADO — do
## outro lado da grade, com o resto do prédio e o PORTÃO do pátio à mão.
##
## O portão só destranca por dentro, e é ele que fecha o atalho de volta.

const LAYER_CHAO := 2
const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"
const CENA_PORAO := "res://scenes/stages/escola/porao.tscn"

## Quanto tempo o fade leva antes da troca de cena. O mesmo do hospital e da
## igreja, para a transição entre os prédios da cidade ter um ritmo só.
const TEMPO_FADE := 2.0

@onready var fade: ColorRect = $fade

## Lâmpadas com metadata "piscar". Guarda a energia original de cada uma: o
## tremor oscila em torno dela, senão a fluorescente do corredor e o refletor
## da quadra acabariam na mesma intensidade.
var _lampadas: Array[Dictionary] = []

## Trava a troca de cena: o fade dura dois segundos, e sem isto cada aperto no
## botão durante esses dois segundos empilha mais uma troca.
var _saindo: bool = false


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()

	_conferir_colisao()
	_preparar_lampadas()
	_posicionar_jogador()

	# save_game() toma o caminho da cena atual como checkpoint, igual à casa do
	# Jimmy, à igreja e ao hospital.
	SaveManager.save_game()

	GlobalUtils.mostrar_objetivo(tr("OBJ_ESC_EXPLORAR"))


## Varre a cena atrás de corpo estático fora da layer do chão. Barato, roda uma
## vez, e evita a classe de bug mais chata deste projeto: o jogador nasce e cai
## para sempre porque UM corpo ficou na layer errada.
func _conferir_colisao() -> void:
	var fora := 0
	for corpo in find_children("*", "StaticBody3D", true, false):
		if corpo.collision_layer != LAYER_CHAO:
			corpo.collision_layer = LAYER_CHAO
			corpo.collision_mask = 0
			fora += 1
	if fora > 0:
		push_warning("escola: %d corpo(s) estático(s) estavam fora da layer %d"
			% [fora, LAYER_CHAO])


## Onde o jogador nasce depende de POR ONDE ele entrou.
##
## São três portas para esta cena — a rua e os dois buracos —, e cada uma tem o
## seu marcador na própria cena gerada. Os marcadores moram lá, e não em
## constantes aqui, pelo mesmo motivo do hospital: mexer na planta move o
## buraco, e uma coordenada escrita neste arquivo ficaria mentindo sem ninguém
## perceber até um jogador nascer dentro da parede.
func _posicionar_jogador() -> void:
	var destino := String(GlobalEvents.escola_chegada)
	GlobalEvents.escola_chegada = ""
	if destino.is_empty():
		return    # veio da cidade: o Player já nasce no pátio, pelo gerador
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


func _preparar_lampadas() -> void:
	var cones := get_node_or_null("cones")
	for luz in find_children("*", "Light3D", true, false):
		if not luz.has_meta("piscar"):
			continue
		var cone: Node3D = null
		if cones:
			cone = cones.get_node_or_null("cone_" + luz.name)
		_lampadas.append({
			"luz": luz,
			"cone": cone,
			"tipo": String(luz.get_meta("piscar")),
			"base": (luz as Light3D).light_energy,
			"proximo": randf() * 0.5,
		})


# ==============================================================================
# AS TRÊS SAÍDAS
# ==============================================================================

## Chamada pelo portão da rua (`porta_escola.gd`, meta `saida`).
##
## Marca a volta ANTES de trocar de cena: o stage_1 consome o sinal no spawn
## para pôr o jogador de volta no portão da escola. Sem isso ele reapareceria
## no ponto de entrada padrão do mapa, do outro lado da cidade.
func sair_da_escola() -> void:
	if _saindo:
		return
	_saindo = true
	GlobalEvents.in_cutscene = true
	GlobalEvents.voltando_da_escola = true
	GlobalUtils.esconder_objetivo()
	fade.fade_out()
	await get_tree().create_timer(TEMPO_FADE).timeout
	LoadingScreen.load_scene(CENA_MAPA)


## Chamada pelos dois buracos (`buraco.gd`).
##
## `papel` é "buraco_entrada" (o do depósito) ou "buraco_saida" (o do
## almoxarifado), e ele diz por qual das duas bocas o porão tem de começar. O
## túnel é de MÃO DUPLA de propósito: quem descer sem lanterna precisa poder
## voltar por onde entrou, senão o buraco vira armadilha.
func usar_buraco(papel: String) -> void:
	if _saindo:
		return
	_saindo = true
	GlobalEvents.porao_chegada = ("entrada" if papel == "buraco_entrada"
		else "saida")
	GlobalEvents.in_cutscene = true
	GlobalUtils.esconder_objetivo()
	fade.fade_out()
	await get_tree().create_timer(TEMPO_FADE).timeout
	LoadingScreen.load_scene(CENA_PORAO)


func _process(delta: float) -> void:
	_atualizar_lampadas(delta)


## Duas falhas diferentes, as mesmas da casa do Jimmy, da igreja e do hospital:
## a "nervosa" é o reator velho da fluorescente, que treme o tempo todo sem
## nunca apagar; a "quebrada" já morreu e só dá estouros curtos, com longos
## intervalos de escuro entre eles.
##
## O intervalo de cada lâmpada é próprio e sorteado, e é isso que importa:
## sincronizadas, as lâmpadas de um corredor piscam como pisca-pisca de natal
## em vez de um corredor de escola quebrado.
func _atualizar_lampadas(delta: float) -> void:
	for lamp in _lampadas:
		var luz: Light3D = lamp["luz"]
		if not is_instance_valid(luz):
			continue
		lamp["proximo"] -= delta
		if lamp["proximo"] > 0.0:
			continue
		if lamp["tipo"] == "nervoso":
			luz.light_energy = lamp["base"] * randf_range(0.68, 1.14)
			lamp["proximo"] = randf_range(0.05, 0.22)
		else:
			var acesa := randf() < 0.13
			luz.light_energy = lamp["base"] * (randf_range(0.85, 1.55) if acesa else 0.0)
			lamp["proximo"] = randf_range(0.05, 0.3) if acesa else randf_range(0.7, 3.6)
			var cone: Node3D = lamp["cone"]
			if is_instance_valid(cone):
				cone.visible = acesa
