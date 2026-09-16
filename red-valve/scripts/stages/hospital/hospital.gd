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

@onready var fade: ColorRect = $fade

## Lampadas com metadata "piscar". Guarda a energia original de cada uma: o
## tremor oscila em torno dela, senao a fluorescente do corredor e o foco
## cirurgico acabariam na mesma intensidade.
var _lampadas: Array[Dictionary] = []


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()

	_conferir_colisao()
	_preparar_lampadas()

	# save_game() toma o caminho da cena atual como checkpoint, igual a' casa do
	# Jimmy e a' igreja.
	SaveManager.save_game()

	GlobalUtils.mostrar_objetivo(tr("OBJ_HOSP_EXPLORAR"))


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


func _process(delta: float) -> void:
	_atualizar_lampadas(delta)


## Duas falhas diferentes, as mesmas da casa do Jimmy e da igreja: a "nervosa"
## e' o reator velho da fluorescente, que treme o tempo todo sem nunca apagar;
## a "quebrada" ja' morreu e so' da' estouros curtos, com longos intervalos de
## escuro entre eles.
##
## O intervalo de cada lampada e' proprio e sorteado, e e' isso que importa:
## sincronizadas, as lampadas de um corredor piscam como um pisca-pisca de
## natal em vez de um corredor de hospital quebrado.
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
