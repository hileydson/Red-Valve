extends Node

## O CAPÍTULO 2 NA CIDADE — a interrogação do mapa e a cena da igreja.
##
## Quem cria é a `stage_1` (no `_ready`), em todo capítulo: fora do Capítulo 2
## isto não faz nada. A etapa vem do `Eventos`:
##
##   1. saindo da escola: "Vá em busca de Dona Nice e Jonny" e uma interrogação
##      no mapa diante da porta da igreja. Chegando perto dela, a cena da praça
##      (`cutscene_nice_igreja.gd`, uma vez só): o Maycow vê a Dona Nice
##      entrando na igreja de mão dada com o Jonny;
##   2. a igreja continua trancada e a interrogação vai pra casa da Dona Nice,
##      que abre agora ("Encontre uma forma de entrar na igreja");
##   3. lida a carta dela (ou aberta a igreja), a interrogação volta pra porta
##      da igreja ("Confronte Dona Nice na igreja");
##   4. com ela morta, pra porta do hospital (o Jonny no colo).
##
## A interrogação é um `ponto_no_mapa` com `sempre_visivel`, o mesmo do
## calabouço da escola; ela muda de lugar sozinha a cada evento concluído
## (`Eventos.mudou`).

const CutsceneNiceIgreja := preload("res://scripts/stages/stage_1/cutscene_nice_igreja.gd")
const PontoNoMapa := preload("res://scripts/ui/ponto_no_mapa.gd")

const CENA_DONA_NICE := "res://scenes/npcs/igreja/dona_nice.tscn"
const CENA_JONNY := "res://scenes/npcs/igreja/jonny.tscn"
const CLIPES_DONA_NICE := "res://assets/3d_model/npc/escola/dona_nice_escola_clipes.glb"
const CLIPES_JONNY := "res://assets/3d_model/npc/escola/jonny_escola_clipes.glb"
const LACOS := ["andar_de_mao", "parada_de_mao", "parado_de_mao"]

## A porta da igreja (a fachada olha pro -X; ver `stage_1.IGREJA_PORTA`).
const PORTA_IGREJA := Vector3(582.1, 10.9, -317.7)
## A interrogação da igreja: no gramado do adro, diante da porta.
const INTERROGACAO_IGREJA := Vector3(575.0, 11.0, -317.6)
## Chegando a esta distância da porta, a cena da praça roda.
const RAIO_DA_CENA := 27.0

var cidade: Node3D
var player: CharacterBody3D

var _marca: Node3D
var _marcado_em := "-"
var _em_cena := false


func iniciar(dono: Node3D) -> void:
	cidade = dono
	player = cidade.get_node_or_null("Player") as CharacterBody3D
	Eventos.mudou.connect(_ao_mudar_evento)
	_atualizar_interrogacao()


func _exit_tree() -> void:
	if Eventos.mudou.is_connected(_ao_mudar_evento):
		Eventos.mudou.disconnect(_ao_mudar_evento)


func _ao_mudar_evento(_id: String, _feito: bool) -> void:
	_atualizar_interrogacao()


# ==============================================================================
# A INTERROGAÇÃO DO MAPA
# ==============================================================================

## Pra onde a história manda agora ("" = nenhum lugar marcado).
func _onde_marcar() -> String:
	if Eventos.capitulo_atual() != Eventos.CAPITULO_2:
		return ""
	if not Eventos.feito(Eventos.CAP2_NICE_ENTRA_IGREJA):
		return "igreja"
	if not Eventos.feito(Eventos.CAP2_CARTA_NICE) and not Eventos.feito(Eventos.CAP2_IGREJA_DESTRANCADA):
		return "casa_nice"
	if not Eventos.feito(Eventos.CAP2_DONA_NICE_DERROTADA):
		return "igreja"
	if not Eventos.feito(Eventos.CAP2_JONNY_NA_MACA):
		return "hospital"
	return ""


func _posicao(onde: String) -> Variant:
	match onde:
		"igreja":
			return INTERROGACAO_IGREJA
		"casa_nice":
			var casa := cidade.get_node_or_null("casa_nice") as Node3D
			return casa.global_position if casa else null
		"hospital":
			var hospital: Node3D = cidade.call("_no_do_hospital")
			if hospital:
				var area := hospital.get_node_or_null("area_entrada") as Node3D
				return area.global_position if area else hospital.global_position
	return null


func _atualizar_interrogacao() -> void:
	var onde := _onde_marcar()
	if onde == _marcado_em:
		return
	_marcado_em = onde
	if is_instance_valid(_marca):
		_marca.queue_free()
	_marca = null
	var pos = _posicao(onde)
	if pos == null:
		return
	_marca = Node3D.new()
	_marca.name = "interrogacao_capitulo_2"
	cidade.add_child(_marca)
	_marca.global_position = pos
	var ponto = PontoNoMapa.new()
	ponto.tipo = "interrogacao"
	ponto.sempre_visivel = true
	_marca.add_child(ponto)


# ==============================================================================
# A CENA DA PRAÇA
# ==============================================================================

func _process(_delta: float) -> void:
	if _em_cena or not is_instance_valid(player) or not Eventos.pode(Eventos.CAP2_NICE_ENTRA_IGREJA):
		return
	if Eventos.capitulo_atual() != Eventos.CAPITULO_2:
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene or get_tree().paused:
		return
	# a cidade fica escondida (e o parasita é quem joga) enquanto a arena roda
	if not cidade.visible or not GlobalEvents.is_maycow_normal or not player.is_on_floor():
		return
	var d := player.global_position - PORTA_IGREJA
	if Vector2(d.x, d.z).length() < RAIO_DA_CENA:
		_cena_da_praca()


func _cena_da_praca() -> void:
	_em_cena = true
	var dona := _ator(CENA_DONA_NICE, CLIPES_DONA_NICE)
	var jonny := _ator(CENA_JONNY, CLIPES_JONNY)
	# o gemido e a respiração do Jonny são do menino ferido da igreja
	for som in jonny.find_children("*", "AudioStreamPlayer3D", true, false):
		som.queue_free()
	var c = CutsceneNiceIgreja.new()
	c.name = "cutscene_nice_igreja"
	c.dona = dona
	c.jonny = jonny
	cidade.add_child(c)
	c.rodar(cidade, player)
	await c.terminou
	for ator in [dona, jonny]:
		if is_instance_valid(ator):
			ator.queue_free()
	_em_cena = false
	if Eventos.objetivo_atual() != "":
		GlobalUtils.mostrar_objetivo(tr(Eventos.objetivo_atual()), 45.0)


## Um ator da igreja (Dona Nice, Jonny) com a biblioteca "escola" somada à
## dele — a mesma montagem da quadra da escola (`capitulo_1_escola._ator`):
## os clipes de andar de mão dada vêm de um .glb só de esqueleto.
func _ator(cena: String, clipes: String) -> Node3D:
	var ator := (load(cena) as PackedScene).instantiate() as Node3D
	ator.set("clipe_inicial", &"")
	ator.visible = false
	cidade.add_child(ator)
	var fonte := (load(clipes) as PackedScene).instantiate()
	var ap := fonte.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim := ator.get_node_or_null("anim") as AnimationPlayer
	if ap and anim:
		var lib := AnimationLibrary.new()
		for nome in ap.get_animation_list():
			var a := ap.get_animation(nome)
			if String(nome) in LACOS:
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(nome, a)
		anim.add_animation_library(&"escola", lib)
	fonte.free()
	return ator
