extends Node

## O CAPÍTULO 2 DENTRO DO HOSPITAL — quem decide o que acontece em cada visita.
##
## O hospital é uma cena só (`hospital.tscn`, a versão ESCURA gerada); o que
## muda é a etapa da história (`Eventos`). Esta peça lê a etapa no `_ready` do
## hospital e monta o resto:
##
##   CLARO (a Dona Nice morreu, o Jonny ainda não ficou na maca)
##     · o hospital funcionando (`hospital_versoes.gd`), gente pelos corredores
##       e o mapa dos dois andares inteiro aceso — não há o que desbravar;
##     · com o Jonny no colo: a ENFERMEIRA da frente (o "?" do mapa vai com
##       ela) e o enfermeiro do lado; ela leva o Maycow pelo elevador até a
##       cirurgia do 2º andar, onde os médicos esperam em volta da maca;
##     · do lado da maca, "Colocar o Jonny na maca": ele deita o Jonny
##       (estado 6) e a TRANSFORMAÇÃO roda — a onda sai da maca e o hospital
##       vira o escuro (`cutscene_hospital_transforma.gd`); no preto, a DRIZZI
##       (`cutscene_drizzi.gd`); e o Maycow volta no escuro, com a lanterna
##       apagada: a dica pede pra acender, e acesa, o objetivo é sair.
##   ESCURO (depois da maca)
##     · o Jonny deitado na maca, quieto. Save carregado entre a maca e o fim
##       da Drizzi roda a Drizzi de novo. Sair pela porta da rua encerra o
##       Capítulo 2 (`hospital.sair_do_hospital`).
##
## O mapa: claro, os dois andares acesos (`MapaNevoa.revelar_tudo`); na
## transformação, apagados de novo (`MapaNevoa.esquecer`) — o hospital escuro é
## outro lugar, e esse se descobre andando.

const HospitalVersoes := preload("res://scripts/stages/hospital/hospital_versoes.gd")
const Adulto := preload("res://scripts/npcs/escola/adulto_escola.gd")
const EnfermeiraGuia := preload("res://scripts/npcs/hospital/enfermeira_guia.gd")
const EnfermeiroAcompanha := preload("res://scripts/npcs/hospital/enfermeiro_acompanha.gd")
const CutsceneTransforma := preload("res://scripts/stages/hospital/cutscene_hospital_transforma.gd")
const CutsceneBase := preload("res://scripts/cutscenes/cutscene_cap1.gd")
const CutsceneDrizzi := preload("res://scripts/cutscenes/cutscene_drizzi.gd")
const CityNpcScript := preload("res://scripts/npcs/city_npc.gd")

const CENA_JONNY := "res://scenes/npcs/igreja/jonny.tscn"
const CENA_HOSPITAL := "res://scenes/stages/hospital/hospital.tscn"
const MAPAS := ["res://assets/3d_model/stages/hospital/hospitalmap_1.json",
	"res://assets/3d_model/stages/hospital/hospitalmap_2.json"]

## A maca da cirurgia do 2º andar (o nó da mobília e o meio dela no piso).
const NO_MESA := "mobilia/centro_cirurgico_2_mesa_cirurgica"
const MESA := Vector3(27.675, 4.2, 59.025)
## Onde o CORPO que se vê do Maycow fica pra deitar o Jonny: do lado leste da
## maca, de frente pra ela (o -X), as mãos em cima do tampo.
const LADO_DA_MACA := Vector3(28.72, 4.2, 59.0)
const GIRO_PRA_MACA := PI * 0.5
## A que distância (no chão) do lado da maca aparece o prompt.
const RAIO_MACA := 1.8

## Onde a enfermeira e o enfermeiro nascem: no hall, logo à frente do Maycow
## (que entra pela porta da rua olhando pro +X).
const NASCE_ENFERMEIRA := Vector3(9.6, 0.0, 34.2)
const NASCE_ENFERMEIRO := Vector3(7.4, 0.0, 36.4)
## Onde o enfermeiro fica quando a cabine sobe: no corredor, de olho nela.
const ENFERMEIRO_FICA := Vector3(52.6, 0.0, 34.6)
const PORTA_DO_ELEVADOR := Vector3(56.0, 0.0, 31.6)

## Os médicos na cirurgia: [lugar, modelo]. Todos olhando a maca.
const MEDICOS := [
	[Vector3(26.25, 4.2, 59.5), "Character_25_Doctor"],
	[Vector3(27.75, 4.2, 61.25), "Character_23_Female_Doctor"],
	[Vector3(26.4, 4.2, 60.9), "Character_26_Doctor"],
]

## A gente pelos corredores dos dois andares, no formato do adulto da escola:
## [pontos (vazio = parado conversando), olhar_para, falando, lugar]. Os
## pontos ficam no mesmo corredor, em linha reta (sem navmesh), longe do
## caminho da enfermeira até o elevador.
const PESSOAS := [
	[[Vector3(5.0, 0, 12.85), Vector3(46.0, 0, 12.85)], Vector3.ZERO, false, Vector3.ZERO],
	[[Vector3(46.0, 0, 55.5), Vector3(5.0, 0, 55.5)], Vector3.ZERO, false, Vector3.ZERO],
	[[Vector3(53.15, 0, 52.0), Vector3(53.15, 0, 40.0)], Vector3.ZERO, false, Vector3.ZERO],
	[[Vector3(33.0, 0, 41.2), Vector3(48.0, 0, 41.2)], Vector3.ZERO, false, Vector3.ZERO],
	[[Vector3(3.0, 0, 41.6), Vector3(20.0, 0, 41.6)], Vector3.ZERO, false, Vector3.ZERO],
	[[], Vector3(7.4, 0, 28.6), true, Vector3(6.5, 0, 28.0)],
	[[], Vector3(6.5, 0, 28.0), false, Vector3(7.4, 0, 28.6)],
	[[], Vector3(24.8, 0, 40.2), true, Vector3(24.0, 0, 41.0)],
	[[], Vector3(24.0, 0, 41.0), false, Vector3(24.8, 0, 40.2)],
	[[Vector3(5.0, 4.2, 31.0), Vector3(40.0, 4.2, 31.0)], Vector3.ZERO, false, Vector3.ZERO],
	[[Vector3(5.0, 4.2, 15.2), Vector3(50.0, 4.2, 15.2)], Vector3.ZERO, false, Vector3.ZERO],
	[[], Vector3(10.8, 4.2, 48.2), true, Vector3(10.0, 4.2, 47.5)],
	[[], Vector3(10.0, 4.2, 47.5), false, Vector3(10.8, 4.2, 48.2)],
	[[Vector3(4.0, 4.2, 51.5), Vector3(20.0, 4.2, 51.5)], Vector3.ZERO, false, Vector3.ZERO],
]

var hospital: Node3D
var player: CharacterBody3D
var versoes
## Todo mundo do hospital claro (a onda leva).
var pessoas: Array = []
var guia: Node3D
var jonny_na_maca: Node3D

var _em_cena := false
var _perto_da_maca := false


## Monta a visita. Devolve true quando o objetivo é desta peça (Capítulo 2).
func iniciar(dono: Node3D) -> bool:
	hospital = dono
	player = hospital.get_node_or_null("Player") as CharacterBody3D
	set_process(false)
	# deitado na maca ele fica, em qualquer capítulo
	if SaveManager.evento_dona_nice == 6:
		_jonny_na_maca()
	if Eventos.capitulo_atual() != Eventos.CAPITULO_2:
		return false
	if Eventos.hospital_claro():
		_hospital_claro()
		return true
	if Eventos.feito(Eventos.CAP2_JONNY_NA_MACA):
		if not Eventos.feito(Eventos.CAP2_DRIZZI):
			_drizzi_ao_carregar.call_deferred()
		else:
			_objetivo(Eventos.objetivo_atual())
		return true
	return false


func _objetivo(chave: String, duracao: float = 45.0) -> void:
	if chave != "":
		GlobalUtils.mostrar_objetivo(tr(chave), duracao)


# ==============================================================================
# O HOSPITAL CLARO
# ==============================================================================

func _hospital_claro() -> void:
	versoes = HospitalVersoes.new(hospital)
	hospital.add_child(versoes)
	versoes.preparar_clara()
	for m in MAPAS:
		MapaNevoa.revelar_tudo(m)
	_povoar()
	_medicos()
	# hospital aceso: a lanterna (que entra acesa em toda cena) vai pro bolso
	_apagar_lanterna.call_deferred()
	if load("res://scripts/player/player_carregar_jonny.gd").jonny_esta_em(CENA_HOSPITAL):
		_enfermeiros.call_deferred()
		_objetivo("OBJ_CAP2_SIGA_ENFERMEIRA")
	set_process(true)


func _apagar_lanterna() -> void:
	await get_tree().process_frame
	if is_instance_valid(player):
		player.apagar_lanterna_agora()


func _indice(nome: String) -> int:
	return CityNpcScript.MODELOS.find(nome)


func _gente_comum() -> Array:
	var out: Array = []
	var lista: Array = CityNpcScript.MODELOS
	for i in lista.size():
		var n := String(lista[i])
		if n.contains("Police") or n.contains("Firefighter") or n.contains("Sheriff") or n.contains("_HM"):
			continue
		out.append(i)
	return out


func _povoar() -> void:
	var modelos := _gente_comum()
	modelos.shuffle()
	var k := 0
	for a in PESSOAS:
		var npc = Adulto.new()
		npc.name = "pessoa_hospital_%d" % k
		npc.modelo_index = modelos[k % modelos.size()]
		npc.escala = randf_range(0.95, 1.06)
		var pontos: Array = a[0]
		if pontos.is_empty():
			npc.olhar_para = a[1]
			npc.falando = a[2]
			npc.position = a[3] + Vector3.UP * 0.05
		else:
			var subidos: Array = []
			for p in pontos:
				subidos.append(p + Vector3.UP * 0.05)
			npc.pontos = subidos
			npc.position = subidos[0]
		hospital.add_child(npc)
		pessoas.append(npc)
		k += 1


func _medicos() -> void:
	for m in MEDICOS:
		var npc = Adulto.new()
		npc.name = "medico_%d" % pessoas.size()
		npc.modelo_index = _indice(String(m[1]))
		npc.olhar_para = MESA
		npc.falando = false
		npc.position = m[0] + Vector3.UP * 0.05
		hospital.add_child(npc)
		pessoas.append(npc)


func _enfermeiros() -> void:
	await get_tree().process_frame
	var elevador := hospital.get_node_or_null("elevador") as Node3D
	guia = EnfermeiraGuia.new()
	guia.name = "enfermeira_guia"
	guia.modelo_index = _indice("Character_24_Female_Doctor")
	guia.jogador = player
	guia.elevador = elevador
	guia.position = NASCE_ENFERMEIRA + Vector3.UP * 0.05
	hospital.add_child(guia)
	guia.rotation.y = -PI * 0.5   # de frente pro Maycow, que entra olhando pro +X
	pessoas.append(guia)

	var ao_lado = EnfermeiroAcompanha.new()
	ao_lado.name = "enfermeiro_acompanha"
	ao_lado.modelo_index = _indice("Character_Male_36")
	ao_lado.jogador = player
	ao_lado.position = NASCE_ENFERMEIRO + Vector3.UP * 0.05
	hospital.add_child(ao_lado)
	pessoas.append(ao_lado)

	await get_tree().create_timer(1.2, false).timeout
	if not is_instance_valid(guia):
		return
	_enfermeiro_fica_no_elevador(ao_lado)
	await guia.conduzir()
	if is_instance_valid(guia) and not Eventos.feito(Eventos.CAP2_JONNY_NA_MACA):
		_objetivo("OBJ_CAP2_MACA", 60.0)


## Quando a cabine chega pra enfermeira, o enfermeiro para no corredor.
func _enfermeiro_fica_no_elevador(ao_lado: Node3D) -> void:
	var elevador := hospital.get_node_or_null("elevador")
	while is_instance_valid(guia) and is_instance_valid(elevador) and not elevador.guiado:
		await get_tree().process_frame
	if is_instance_valid(ao_lado):
		ao_lado.ficar_em(ENFERMEIRO_FICA, PORTA_DO_ELEVADOR)


# ==============================================================================
# A MACA
# ==============================================================================

func _process(_delta: float) -> void:
	if _em_cena or not is_instance_valid(player) or GlobalEvents.in_cutscene or get_tree().paused:
		return
	var carregando: bool = player.get("carregando_jonny") == true
	var d := player.global_position - LADO_DA_MACA
	var perto := carregando and Vector2(d.x, d.z).length() < RAIO_MACA and absf(d.y - 1.0) < 1.5
	if perto != _perto_da_maca:
		_perto_da_maca = perto
		if perto:
			GlobalUtils.show_center_message("maca_jonny", tr("PROMPT_COLOCAR_JONNY_MACA"), 18)
		else:
			GlobalUtils.hide_center_message("maca_jonny")
	if perto and Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
		_deitar_na_maca()


func _deitar_na_maca() -> void:
	_em_cena = true
	_perto_da_maca = false
	GlobalUtils.hide_center_message("maca_jonny")
	GlobalUtils.hide_center_message("fala_enfermeira")
	GlobalUtils.esconder_objetivo()
	var colo := player.get_node_or_null("CarregarJonny")
	if colo == null:
		_em_cena = false
		return
	# encaixa o corpo que se VÊ no lado da maca (o modelo não fica na origem
	# do player: o desvio gira junto — ver `player_carregar_jonny._pegar`)
	player.cutscene_set_player_control(false)
	player.velocity = Vector3.ZERO
	var modelo := player.get_node_or_null("maycow_lopes_normal") as Node3D
	var desvio := Vector3.ZERO
	if modelo:
		desvio = player.global_basis.inverse() * (modelo.global_position - player.global_position)
		desvio.y = 0.0
	var alvo := LADO_DA_MACA - Basis(Vector3.UP, GIRO_PRA_MACA) * desvio
	alvo.y = player.global_position.y
	var giro_ini := player.rotation.y
	var t := create_tween().set_parallel(true)
	t.tween_property(player, "global_position", alvo, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_method(func(k: float): player.rotation.y = lerp_angle(giro_ini, GIRO_PRA_MACA, k),
		0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	await t.finished
	await colo.deitar_na_maca(_tampo(), GIRO_PRA_MACA)
	jonny_na_maca = colo.jonny
	SaveManager.save_game()
	_transformacao(colo)


## O meio do tampo da maca, na superfície (o topo das malhas dela).
func _tampo() -> Vector3:
	var mesa := hospital.get_node_or_null(NO_MESA) as Node3D
	if mesa == null:
		return MESA + Vector3(0.0, 1.0, 0.0)
	var caixa := AABB()
	var primeira := true
	for m in mesa.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var c: AABB = mi.global_transform * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return Vector3(caixa.get_center().x, caixa.end.y, caixa.get_center().z)


# ==============================================================================
# A TRANSFORMAÇÃO E A DRIZZI
# ==============================================================================

func _transformacao(colo: Node) -> void:
	var cena = CutsceneTransforma.new()
	cena.name = "cutscene_hospital_transforma"
	cena.versoes = versoes
	cena.jonny = jonny_na_maca
	cena.pessoas = pessoas
	hospital.add_child(cena)
	cena.rodar(hospital, player)
	# a câmera já cortou pro Jonny: o corpo do Maycow volta pra AnimationTree
	await get_tree().process_frame
	if is_instance_valid(colo):
		colo.soltar_corpo()
	await cena.no_escuro
	for m in MAPAS:
		MapaNevoa.esquecer(m)
	pessoas.clear()
	await _drizzi_no_escuro(cena)


## O fim do capítulo neste hospital: a Drizzi no preto, e o Maycow volta no
## escuro com a lanterna apagada.
func _drizzi_no_escuro(cena: Node) -> void:
	if is_instance_valid(player):
		player.apagar_lanterna_agora()
	var d = CutsceneDrizzi.new()
	d.name = "cutscene_drizzi"
	hospital.add_child(d)
	await d.terminou
	Eventos.concluir(Eventos.CAP2_DRIZZI)
	if is_instance_valid(player):
		player.apagar_lanterna_agora()
	cena.encerrar(1.8)
	await cena.terminou
	_em_cena = false
	set_process(false)
	_pedir_a_lanterna()


## Save carregado entre a maca e o fim da Drizzi: o hospital já é o escuro; o
## Maycow, do lado da maca; e a Drizzi roda de novo, no preto.
func _drizzi_ao_carregar() -> void:
	await get_tree().process_frame
	if not is_instance_valid(player):
		return
	_em_cena = true
	var modelo := player.get_node_or_null("maycow_lopes_normal") as Node3D
	var desvio := Vector3.ZERO
	if modelo:
		desvio = player.global_basis.inverse() * (modelo.global_position - player.global_position)
		desvio.y = 0.0
	player.global_position = LADO_DA_MACA + Vector3(0.6, 1.05, 0.0) - Basis(Vector3.UP, GIRO_PRA_MACA) * desvio
	player.rotation.y = GIRO_PRA_MACA
	var cena = CutsceneBase.new()
	cena.name = "cutscene_drizzi_base"
	hospital.add_child(cena)
	cena.travar(hospital, player)
	await cena.escurecer(1.0, 0.01)
	await _drizzi_no_escuro(cena)


## No escuro, de lanterna apagada: a dica fica na tela até ele acender, e aí
## o objetivo é sair.
func _pedir_a_lanterna() -> void:
	if not is_instance_valid(player):
		return
	if SaveManager.tem_item("lanterna") and not player.lanterna_ligada:
		var no_controle := GlobalEvents.usando_controle
		GlobalUtils.show_center_message("dica_lanterna",
			tr("AVISO_LIGAR_LANTERNA_PAD" if no_controle else "AVISO_LIGAR_LANTERNA_KEY"), 20)
		while is_instance_valid(player) and not player.lanterna_ligada:
			await get_tree().process_frame
			if GlobalEvents.usando_controle != no_controle and GlobalUtils.active_messages.has("dica_lanterna"):
				no_controle = GlobalEvents.usando_controle
				GlobalUtils.show_center_message("dica_lanterna",
					tr("AVISO_LIGAR_LANTERNA_PAD" if no_controle else "AVISO_LIGAR_LANTERNA_KEY"), 20)
		GlobalUtils.hide_center_message("dica_lanterna")
		await get_tree().create_timer(0.8, false).timeout
	_objetivo(Eventos.objetivo_atual(), 60.0)


# ==============================================================================
# O JONNY NA MACA (estado 6)
# ==============================================================================

## Deitado na maca, quieto, respirando. No colo do Maycow ele é do
## `player_carregar_jonny`; aqui ele é só do hospital (não se pega mais).
func _jonny_na_maca() -> void:
	var jonny := load(CENA_JONNY).instantiate() as Node3D
	jonny.set("clipe_inicial", &"deitado")
	jonny.set("sangue", 0.45)
	hospital.add_child(jonny)
	var p: Array = SaveManager.jonny_no_hospital
	var tampo := _tampo()
	var giro := 0.0
	if p.size() == 4:
		tampo = Vector3(p[0], p[1], p[2])
		giro = float(p[3])
	jonny.global_transform = jonny.no_chao(Transform3D(Basis(Vector3.UP, giro), tampo))
	jonny_na_maca = jonny
