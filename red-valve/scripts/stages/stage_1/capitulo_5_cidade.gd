extends Node

## O CAPÍTULO 5 NA CIDADE.
##
## A porta da oficina (reaberta enquanto o Jimmy está do outro lado) é do
## próprio stage_1 (`Eventos.local_aberto("oficina")`); aqui ela só ganha o
## "?" do mapa. Esta peça cuida do fim do capítulo, LEVANDO O JIMMY
## (`Eventos.levando_jimmy`) da oficina ao Jonny, no hospital:
##
##  - o Jimmy segue o Maycow por onde ele for (`jimmy_segue.gd`);
##  - a cidade fica sem amuleto, de graça e sem volta — a de gente, no fim de
##    tarde, com carro de verdade, sem monstro nem sombra
##    (`SaveManager.realidade_normal`); o R3 e o LB só avisam que o amuleto
##    não responde mais; o spawner nem nasce (stage_1);
##  - todo lugar fechado menos o hospital: a porta de cada um diz "Preciso ir
##    ao hospital" (`Eventos.aviso_local_fechado`), e a floresta também;
##  - o "?" do mapa fica no hospital.
##
## Saindo da oficina depois da conversa (`chegando_da_conversa`), a tela abre
## bem devagar do preto — é o fim do fade longo da cena de lá.

const JimmySegue := preload("res://scripts/npcs/jimmy/jimmy_segue.gd")
const PontoNoMapa := preload("res://scripts/ui/ponto_no_mapa.gd")

## Do lado de fora da porta da oficina (o mesmo ponto onde o Capítulo 1 começa).
const MARCA_OFICINA := "itens_caminho_jimmy/auto_pecas_jimmy/maykow_capitulo_1_inicio"
const NO_HOSPITAL := "locais_importantes/hospital_exterior"
## O fade longo da chegada: o preto segura um pouco e abre devagar.
const PRETO_SEGURA := 1.6
const PRETO_ABRE := 5.5

## Ligado pela oficina no fim da conversa: a cidade abre do preto bem devagar.
static var chegando_da_conversa := false

var cidade: Node3D
var player: CharacterBody3D
var jimmy: Node3D


## Fora da volta da oficina do Capítulo 5 nada acontece.
static func posicionar_na_porta_da_oficina(dono: Node3D, jogador: Node3D) -> void:
	var marca := dono.get_node_or_null(MARCA_OFICINA) as Node3D
	if marca == null or jogador == null:
		return
	jogador.global_position = marca.global_position
	# como no começo do Capítulo 1: de costas pra porta, de frente pra rua
	jogador.global_rotation.y = marca.global_rotation.y + PI
	if dono.has_method("_pousar_no_chao"):
		dono.call_deferred("_pousar_no_chao", jogador, marca.global_position)


func iniciar(dono: Node3D) -> void:
	cidade = dono
	player = cidade.get_node_or_null("Player") as CharacterBody3D
	if Eventos.oficina_aberta():
		var marca := cidade.get_node_or_null(MARCA_OFICINA) as Node3D
		if marca:
			_interrogacao(marca.global_position, "MAP_POI_OFICINA_JIMMY")
	if not Eventos.levando_jimmy():
		chegando_da_conversa = false
		return
	var da_conversa := chegando_da_conversa
	chegando_da_conversa = false
	if da_conversa:
		_abrir_do_preto()
	_marcar_hospital()
	_trazer_jimmy()
	_mostrar_objetivo(PRETO_SEGURA + PRETO_ABRE + 1.0 if da_conversa else 2.5)


# ==============================================================================
# O JIMMY
# ==============================================================================

## Nasce atrás do Maycow (de onde ele acabou de sair), quando o chão da cidade
## já tem colisão — o Terrain3D monta ela uns quadros depois da cena abrir.
func _trazer_jimmy() -> void:
	jimmy = JimmySegue.new()
	jimmy.name = "jimmy_seguindo"
	jimmy.visible = false
	cidade.add_child(jimmy)
	for _i in 12:
		await get_tree().physics_frame
	if not is_instance_valid(player) or not is_instance_valid(jimmy):
		return
	var atras := player.global_basis.z
	atras.y = 0.0
	atras = atras.normalized() if atras.length() > 0.01 else Vector3.BACK
	var lado := Vector3.UP.cross(atras).normalized()
	jimmy.jogador = player
	jimmy.plantar(player.global_position + atras * 1.6 + lado * 0.7 + Vector3.DOWN * 0.9)
	jimmy.visible = true


# ==============================================================================
# O MAPA E O OBJETIVO
# ==============================================================================

func _marcar_hospital() -> void:
	var hospital := cidade.get_node_or_null(NO_HOSPITAL) as Node3D
	if hospital == null:
		return
	var area := hospital.get_node_or_null("area_entrada") as Node3D
	_interrogacao(area.global_position if area else hospital.global_position, "MAP_POI_HOSPITAL")


func _interrogacao(onde: Vector3, chave: String) -> void:
	var marca := Node3D.new()
	marca.name = "interrogacao_capitulo_5"
	cidade.add_child(marca)
	marca.global_position = onde
	var ponto = PontoNoMapa.new()
	ponto.tipo = "interrogacao"
	ponto.chave = chave
	ponto.sempre_visivel = true
	marca.add_child(ponto)


func _mostrar_objetivo(espera: float) -> void:
	await get_tree().create_timer(espera, false).timeout
	if not is_inside_tree() or not Eventos.levando_jimmy():
		return
	GlobalUtils.mostrar_objetivo(tr("OBJ_CAP5_HOSPITAL"), 45.0)


## O fim do fade longo da oficina: o preto segura e abre devagar.
func _abrir_do_preto() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 120
	add_child(camada)
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(preto)
	await get_tree().create_timer(PRETO_SEGURA, false).timeout
	if not is_instance_valid(preto):
		return
	var t := create_tween()
	t.tween_property(preto, "color:a", 0.0, PRETO_ABRE).set_trans(Tween.TRANS_SINE)
	t.tween_callback(camada.queue_free)
