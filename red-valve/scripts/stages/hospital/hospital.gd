extends Node3D

## O hospital de Red Valve — dois andares, ligados so' pelo elevador.
##
## O predio inteiro (geometria, luz, movel, colisao e navmesh) e' gerado por
## `tools/godot/hospital/gerar_cena_hospital.py` a partir da planta em
## `tools/godot/hospital/planta.py`. Este script cuida SO' do que e'
## comportamento — o resto tem dono la'.
##
## Portas e elevador tem script proprio (`porta_hospital.gd`,
## `elevador_hospital.gd`); aqui fica o que e' do predio todo: o piscar das
## lampadas e o estado global da cena.

## Layer em que o chao do jogo vive. O player e' `CharacterBody3D` com
## `collision_mask = 2`: ele SO' enxerga a layer 2. Os corpos gerados ja' nascem
## certos, mas um corpo colocado a mao pelo editor nasce na layer 1 e o jogador
## atravessaria o predio em queda livre — daí a varredura de conferencia.
const LAYER_CHAO := 2
const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"
const CARREGAR_JONNY := "res://scripts/player/player_carregar_jonny.gd"
## O Capítulo 2 aqui dentro: o hospital claro, a enfermeira, a maca, a
## transformação e a Drizzi (ver `capitulo_2_hospital.gd`).
const CAPITULO_2_HOSPITAL := "res://scripts/stages/hospital/capitulo_2_hospital.gd"

@onready var fade: ColorRect = $fade

## Lampadas com metadata "piscar". Guarda a energia original de cada uma: o
## tremor oscila em torno dela, senao a fluorescente do corredor e o foco
## cirurgico acabariam na mesma intensidade.
var _lampadas: Array[Dictionary] = []

## Trava a saida: o fade dura dois segundos, e sem isto cada aperto no botao
## durante esses dois segundos empilha mais uma troca de cena.
var _saindo: bool = false

## Desligado no hospital claro (Capítulo 2): lá as lâmpadas funcionam. A onda
## da transformação liga de volta (`hospital_versoes.gd`).
var piscar_lampadas: bool = true:
	set(v):
		piscar_lampadas = v
		if not v:
			_lampadas_firmes()

var _capitulo_2: Node = null


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()

	_conferir_colisao()
	_preparar_lampadas()
	_preparar_cameras()

	# Capítulo 2, hospital claro: o save foi carregado com o Jonny largado aqui
	# dentro (num andar qualquer). A cena recomeça com ele no colo do Maycow, na
	# entrada, com a enfermeira chamando do hall. (Com ele aqui a porta da rua
	# não abre: chegar nesta cena no estado 5 só acontece carregando o save.)
	if Eventos.hospital_claro() and SaveManager.evento_dona_nice == 5 and _jonny_aqui():
		SaveManager.evento_dona_nice = 4
		SaveManager.jonny_no_hospital = []
		SaveManager.jonny_deixado_em = ""

	# save_game() toma o caminho da cena atual como checkpoint, igual a' casa do
	# Jimmy e a' igreja.
	SaveManager.save_game()

	if _jonny_aqui():
		_jonny_no_hospital()
	# no Capítulo 2 o objetivo é da história (ver `capitulo_2_hospital.gd`)
	_capitulo_2 = load(CAPITULO_2_HOSPITAL).new()
	_capitulo_2.name = "capitulo_2_hospital"
	add_child(_capitulo_2)
	if _capitulo_2.iniciar(self):
		return
	if _jonny_aqui():
		GlobalUtils.mostrar_objetivo(tr("OBJ_HOSPITAL_AJUDA_JONNY"))
	else:
		GlobalUtils.mostrar_objetivo(tr("OBJ_HOSP_EXPLORAR"))


## O Jonny chegou da igreja no colo do Maycow (evento da Dona Nice).
##   4 = ainda no colo: o jogador so' anda ate' largar ele (B / G)
##   5 = ja' foi deixado aqui: fica deitado onde ficou, marcado no mapa, e da'
##       pra pegar ele de volta
## Os dois sao o mesmo componente (`player_carregar_jonny.gd`), que passa de um
## pro outro. Nos dois a porta da rua fica trancada (ver `sair_do_hospital`).
## Deixado na cidade, ele nao esta' aqui: o hospital fica como sempre.
func _jonny_no_hospital() -> void:
	var jogador := get_node_or_null("Player")
	if jogador == null:
		jogador = get_tree().get_first_node_in_group("player")
	load(CARREGAR_JONNY).preparar(jogador, scene_file_path)


func _jonny_aqui() -> bool:
	return load(CARREGAR_JONNY).jonny_esta_em(scene_file_path)


## A lente e' exclusiva desta instancia do player; o FOV continua sob controle
## do script de movimento/mira para nao alterar a jogabilidade.
func _preparar_cameras() -> void:
	for caminho in ["Player/Camera3D", "Player/SpringArm3D/camera_third_person"]:
		var camera_local := get_node_or_null(caminho) as Camera3D
		if camera_local == null:
			continue
		var lente := CameraAttributesPractical.new()
		lente.exposure_multiplier = 0.96
		camera_local.attributes = lente
		camera_local.far = 115.0


## Varre a cena atras de corpo estatico fora da layer do chao. Barato, roda uma
## vez, e evita a classe de bug mais chata deste projeto: o jogador nasce e cai
## pra sempre porque UM corpo ficou na layer errada.
func _conferir_colisao() -> void:
	var fora := 0
	for corpo in find_children("*", "StaticBody3D", true, false):
		if corpo.collision_layer != LAYER_CHAO:
			corpo.collision_layer = LAYER_CHAO
			corpo.collision_mask = 0
			fora += 1
	if fora > 0:
		push_warning("hospital: %d corpo(s) estatico(s) estavam fora da layer %d"
			% [fora, LAYER_CHAO])


## Junta cada lampada ao CONE de luz dela.
##
## O cone e' o feixe no ar, e existe como malha porque o renderer do projeto e'
## o mobile, que nao tem nevoa volumetrica (ver o cabecalho do gerador). Como
## ele e' malha, ele nao sabe que a lampada apagou: sem este pareamento, a
## lampada "quebrada" apaga e o feixe dela fica aceso no ar, pendurado sozinho
## no escuro — que e' o defeito mais visivel que esta cena pode ter.
##
## O par sai do NOME: o gerador batiza o cone de "cone_" + nome da luz.
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


## Chamado pela porta da rua (`porta_hospital.gd`, meta `saida`).
##
## Marca a volta ANTES de trocar de cena: o stage_1 consome o sinal no spawn
## para pôr o jogador no tablado da entrada, de costas para a porta. Sem isso
## ele reapareceria no ponto de entrada padrão do mapa, do outro lado da cidade.
func sair_do_hospital() -> void:
	if _saindo:
		return
	# Com o Jonny aqui dentro a porta nao abre — a saida vem com a chave, que e'
	# outra parte da historia.
	if _jonny_aqui():
		var aviso := "AVISO_HOSPITAL_CUIDAR_DO_JONNY" if Eventos.hospital_claro() \
			else "AVISO_HOSPITAL_TRANCADO"
		GlobalUtils.show_center_message("hospital_trancado", tr(aviso), 16, 2.2)
		return
	_saindo = true
	# Saiu do hospital escuro depois da Drizzi: acabou o Capítulo 2. A stage_1
	# mostra o "CAPÍTULO 3" na chegada.
	if Eventos.pode(Eventos.CAP2_CONCLUIDO):
		Eventos.concluir(Eventos.CAP2_CONCLUIDO)
		GlobalEvents.entering_chapter_3 = true
	GlobalEvents.in_cutscene = true
	GlobalEvents.voltando_do_hospital = true
	GlobalUtils.esconder_objetivo()
	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	LoadingScreen.load_scene(CENA_MAPA)


func _process(delta: float) -> void:
	_atualizar_lampadas(delta)


## Sem piscar: toda lâmpada na energia de projeto e com o feixe aceso.
func _lampadas_firmes() -> void:
	for lamp in _lampadas:
		var luz: Light3D = lamp["luz"]
		if is_instance_valid(luz):
			luz.light_energy = lamp["base"]
		var cone: Node3D = lamp["cone"]
		if is_instance_valid(cone):
			cone.visible = true


## Duas falhas diferentes, as mesmas da casa do Jimmy e da igreja: a "nervosa"
## e' o reator velho da fluorescente, que treme o tempo todo sem nunca apagar;
## a "quebrada" ja' morreu e so' da' estouros curtos, com longos intervalos de
## escuro entre eles.
##
## O intervalo de cada lampada e' proprio e sorteado, e e' isso que importa:
## sincronizadas, as lampadas de um corredor piscam como um pisca-pisca de
## natal em vez de um corredor de hospital quebrado.
func _atualizar_lampadas(delta: float) -> void:
	if not piscar_lampadas:
		return
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
