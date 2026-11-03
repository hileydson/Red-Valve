extends "res://scripts/stages/hospital/capitulo_2_hospital.gd"

## O FIM DO CAPÍTULO 5 NO HOSPITAL — o Jimmy encontra o Jonny.
##
## Levando o Jimmy (`Eventos.levando_jimmy`) o hospital é o CLARO, o de gente
## (o mesmo do Capítulo 2 antes da maca: `hospital_versoes.gd`, as pessoas
## pelos corredores, os dois andares acesos no mapa), e o Jonny está SENTADO
## na maca da cirurgia do 2º andar, onde o Maycow o deixou — os clipes de
## `npc/capitulo_5/jonny_clipes.glb`. O "?" do mapa fica na porta da cirurgia.
##
## O Jimmy segue o Maycow (`jimmy_segue.gd`); porta não abre pra NPC sozinha,
## então quem abre a dele é esta peça (`porta_hospital.abrir_por`). Abrir a
## porta da cirurgia com ele: o reencontro (`cutscene_final.gd`) e os
## créditos — o fim do jogo.
##
## Herda do diretor do Capítulo 2 o que é igual (a gente dos corredores, a
## maca, a lanterna apagada no claro).

const JimmySegue := preload("res://scripts/npcs/jimmy/jimmy_segue.gd")
const CutsceneFinal := preload("res://scripts/cutscenes/cutscene_final.gd")
const PontoNoMapa := preload("res://scripts/ui/ponto_no_mapa.gd")
const CLIPES_JONNY := "res://assets/3d_model/npc/capitulo_5/jonny_clipes.glb"
const PORTA_CIRURGIA := "portas/p_cirurgia2"
## Com a porta da cirurgia aberta e o Maycow a esta distância dela, o fim.
const RAIO_PORTA := 3.0
## Quem segue tem a porta aberta pra ele a esta distância (no chão).
const RAIO_PORTA_JIMMY := 1.5

var jimmy: Node3D
var jonny: Node3D
var _fim_comecou := false
var _relogio_portas := 0.0
var _portas: Array[Node3D] = []


func iniciar(dono: Node3D) -> bool:
	hospital = dono
	player = hospital.get_node_or_null("Player") as CharacterBody3D
	set_process(false)
	if not Eventos.levando_jimmy():
		return false
	versoes = HospitalVersoes.new(hospital)
	hospital.add_child(versoes)
	versoes.preparar_clara()
	for m in MAPAS:
		MapaNevoa.revelar_tudo(m)
	_povoar()
	_apagar_lanterna.call_deferred()
	_jonny_sentado()
	_marcar_cirurgia()
	var raiz_portas := hospital.get_node_or_null("portas")
	if raiz_portas:
		for p in raiz_portas.get_children():
			if p is Node3D and p.has_method("abrir_por"):
				_portas.append(p)
	_trazer_jimmy()
	_objetivo("OBJ_CAP5_CIRURGIA", 45.0)
	set_process(true)
	return true


# ==============================================================================
# O JONNY SENTADO NA MACA
# ==============================================================================

func _jonny_sentado() -> void:
	jonny = load(CENA_JONNY).instantiate() as Node3D
	jonny.set("clipe_inicial", &"")
	hospital.add_child(jonny)
	var anim := jonny.get_node_or_null("anim") as AnimationPlayer
	var fonte := (load(CLIPES_JONNY) as PackedScene).instantiate()
	var ap := fonte.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and anim:
		var lib := AnimationLibrary.new()
		for nome in ap.get_animation_list():
			var a := (ap.get_animation(nome) as Animation).duplicate() as Animation
			a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(nome, a)
		anim.add_animation_library(&"cap5", lib)
	fonte.free()
	var lugar := lugar_do_jonny()
	jonny.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), lugar)
	jonny.tocar(&"cap5/sentado_maca", 0.0)


## Na beira leste da maca (o lado de onde o Maycow o deitou), de frente pro +X,
## com os joelhos passando da beira e as pernas penduradas.
func lugar_do_jonny() -> Vector3:
	var caixa := _caixa_da_maca()
	if caixa.size == Vector3.ZERO:
		return MESA + Vector3(0.1, 1.0, 0.0)
	return Vector3(caixa.end.x - 0.2, caixa.end.y, caixa.get_center().z)


## Onde o Jimmy fica pra abraçar o Jonny: em pé, logo além dos joelhos dele.
func lugar_do_abraco() -> Vector3:
	var caixa := _caixa_da_maca()
	var x := (caixa.end.x if caixa.size != Vector3.ZERO else MESA.x + 0.4) + 0.2
	var z := caixa.get_center().z if caixa.size != Vector3.ZERO else MESA.z
	return Vector3(x, MESA.y, z)


func _caixa_da_maca() -> AABB:
	var mesa := hospital.get_node_or_null(NO_MESA) as Node3D
	if mesa == null:
		return AABB()
	var caixa := AABB()
	var primeira := true
	for m in mesa.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var c: AABB = mi.global_transform * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return caixa


func _marcar_cirurgia() -> void:
	var porta := hospital.get_node_or_null(PORTA_CIRURGIA) as Node3D
	if porta == null:
		return
	var marca := Node3D.new()
	marca.name = "interrogacao_capitulo_5"
	hospital.add_child(marca)
	marca.global_position = porta.global_position + Vector3.UP * 0.1
	var ponto = PontoNoMapa.new()
	ponto.tipo = "interrogacao"
	ponto.chave = "HOSP_SALA_CIRURGIA2"
	ponto.sempre_visivel = true
	marca.add_child(ponto)


# ==============================================================================
# O JIMMY
# ==============================================================================

## Entra junto com o Maycow, um pouco atrás dele (de onde veio, a rua).
func _trazer_jimmy() -> void:
	jimmy = JimmySegue.new()
	jimmy.name = "jimmy_seguindo"
	jimmy.visible = false
	hospital.add_child(jimmy)
	for _i in 4:
		await get_tree().physics_frame
	if not is_instance_valid(player) or not is_instance_valid(jimmy):
		return
	var atras := player.global_basis.z
	atras.y = 0.0
	atras = atras.normalized() if atras.length() > 0.01 else Vector3.BACK
	jimmy.jogador = player
	jimmy.plantar(player.global_position + atras * 1.4 + Vector3.DOWN * 0.9)
	jimmy.visible = true


func _abrir_portas_pro_jimmy(delta: float) -> void:
	_relogio_portas -= delta
	if _relogio_portas > 0.0 or not is_instance_valid(jimmy) or not jimmy.visible:
		return
	_relogio_portas = 0.2
	var j := jimmy.global_position
	for p in _portas:
		if not is_instance_valid(p) or bool(p.get("aberta")):
			continue
		var d := p.global_position - j
		if absf(d.y) < 1.6 and Vector2(d.x, d.z).length() < RAIO_PORTA_JIMMY:
			p.abrir_por(jimmy)


# ==============================================================================
# A PORTA DA CIRURGIA
# ==============================================================================

func _process(delta: float) -> void:
	if _fim_comecou or not is_instance_valid(player) or get_tree().paused:
		return
	_abrir_portas_pro_jimmy(delta)
	if GlobalEvents.in_cutscene:
		return
	var porta := hospital.get_node_or_null(PORTA_CIRURGIA) as Node3D
	if porta == null or not bool(porta.get("aberta")):
		return
	var d := player.global_position - porta.global_position
	if absf(d.y - 1.0) < 1.8 and Vector2(d.x, d.z).length() < RAIO_PORTA:
		_reencontro(porta)


func _reencontro(porta: Node3D) -> void:
	_fim_comecou = true
	GlobalUtils.esconder_objetivo()
	var c = CutsceneFinal.new()
	c.name = "cutscene_final"
	c.diretor = self
	c.jimmy = jimmy
	c.jonny = jonny
	c.porta = porta
	hospital.add_child(c)
	c.rodar(hospital, player)
