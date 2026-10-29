extends Node

## O CAPÍTULO 1 DENTRO DA ESCOLA — quem decide o que acontece em cada visita.
##
## A escola é uma cena só (`escola.tscn`); o que muda de uma visita pra outra é
## a etapa da história (`Eventos`). Esta peça lê a etapa no `_ready` da escola
## e monta o resto:
##
##   CLARA (até o raio)
##     · a escola acesa, 18 h (`escola_versoes.gd`), cheia de adultos;
##     · 1ª vez: o amuleto sai do pescoço e roda a cutscene da chegada;
##     · a professora da SALA 107 conta que a Dona Nice já levou o Jonny;
##     · depois disso, pisar no pátio dispara a cutscene da QUADRA.
##   LUTA (raio até a morte do Grizzolito)
##     · o Maycow no meio da quadra, o Grizzolito vindo do canto; o amuleto
##       vale aqui (`SaveManager._na_quadra_contra_o_grizzolito`). Morrer aqui,
##       na quadra ou na arena, volta pra este começo de luta.
##   PRESA (porta principal fechada até destrancar o portão do pátio)
##     · a volta da arena roda a cutscene da porta: o Maycow entra no corredor
##       norte e a porta principal bate atrás dele. Daí em diante a escola é a
##       escura de sempre, sem acesso ao pátio, com pouca munição espalhada
##       pelas salas e uma interrogação no mapa no caminho do calabouço.
##
## Do Capítulo 2 em diante (ou antes do 1, pelo debug) isto não faz nada: a
## escola é a escura, como sempre foi.

const EscolaVersoes := preload("res://scripts/stages/escola/escola_versoes.gd")
const Adulto := preload("res://scripts/npcs/escola/adulto_escola.gd")
const CityNpcScript := preload("res://scripts/npcs/city_npc.gd")
const CutsceneAdultos := preload("res://scripts/stages/escola/cutscene_adultos.gd")
const CutsceneQuadra := preload("res://scripts/stages/escola/cutscene_quadra.gd")
const CutscenePortao := preload("res://scripts/stages/escola/cutscene_portao.gd")
const Municao := preload("res://scripts/stages/escola/municao_espalhada.gd")
const PontoNoMapa := preload("res://scripts/ui/ponto_no_mapa.gd")

const CENA_GRIZZOLITO := "res://scenes/enemies/grizzolito.tscn"
const CENA_DONA_NICE := "res://scenes/npcs/igreja/dona_nice.tscn"
const CENA_JONNY := "res://scenes/npcs/igreja/jonny.tscn"
const CLIPES_DONA_NICE := "res://assets/3d_model/npc/escola/dona_nice_escola_clipes.glb"
const CLIPES_JONNY := "res://assets/3d_model/npc/escola/jonny_escola_clipes.glb"
const LACOS := ["andar_de_mao", "parada_de_mao", "parado_de_mao", "mao_no_ceu"]

## O pátio (x0, z0, x1, z1) — depois da conversa da 107, pisar nele (longe do
## portão do corredor, de onde o jogador vem) começa a cena da quadra.
const PATIO_GATILHO := Rect2(0.5, 15.8, 45.0, 32.0)
## Começo da luta (quando a cena carrega já nela).
const LUTA_MAYCOW := Vector3(25.5, 0.0, 30.0)
const LUTA_GRIZZOLITO := Vector3(37.0, 0.0, 20.5)

## A professora da última sala (107): onde ela fica e pra onde olha (a porta).
const PROFESSORA := Vector3(46.4, 0.0, 61.2)
const PROFESSORA_OLHA := Vector3(50.0, 0.0, 57.6)
const PROFESSORA_ALCANCE := 2.6

## [pontos (vazio = parado conversando), olhar_para, falando]
const ADULTOS := [
	[[], Vector3(7.3, 0, 22.6), true, Vector3(6.5, 0, 22.0)],
	[[], Vector3(6.5, 0, 22.0), false, Vector3(7.3, 0, 22.6)],
	[[Vector3(41.5, 0, 46.0), Vector3(41.5, 0, 22.0)], Vector3.ZERO, false, Vector3.ZERO],
	[[Vector3(6.0, 0, 12.85), Vector3(64.0, 0, 12.85)], Vector3.ZERO, false, Vector3.ZERO],
	[[], Vector3(30.8, 0, 13.4), true, Vector3(30.0, 0, 12.3)],
	[[], Vector3(30.0, 0, 12.3), false, Vector3(30.8, 0, 13.4)],
	[[], Vector3(66.0, 0, 5.6), true, Vector3(65.0, 0, 6.6)],
	[[], Vector3(65.0, 0, 6.6), false, Vector3(66.0, 0, 5.6)],
	[[], Vector3(56.8, 0, 19.3), true, Vector3(56.0, 0, 18.6)],
	[[], Vector3(56.0, 0, 18.6), false, Vector3(56.8, 0, 19.3)],
	[[Vector3(73.15, 0, 18.0), Vector3(73.15, 0, 50.0)], Vector3.ZERO, false, Vector3.ZERO],
	[[Vector3(64.0, 0, 54.5), Vector3(8.0, 0, 54.5)], Vector3.ZERO, false, Vector3.ZERO],
	[[], Vector3(52.5, 0, 40.0), false, Vector3(51.6, 0, 38.0)],
	[[], Vector3(36.0, 0, 6.0), true, Vector3(32.2, 0, 6.4)],
]

## As caixas de bala da escola escura: [id do save, (x, altura do raio, z), balas].
## Onde o Maycow preso nasce quando a escola carrega (save, game over): no
## corredor norte, logo depois da porta principal, olhando pro leste.
const PRESO_NASCE := Vector3(21.0, 0.0, 12.8)
## A interrogação do mapa: o buraco do depósito, a entrada do calabouço.
const INTERROGACAO_CALABOUCO := Vector3(67.0, 0.0, 66.42)

const MUNICAO_ESCOLA := [
	["escola_municao_101", Vector3(1.75, 2.0, 5.6), 6],
	["escola_municao_secretaria", Vector3(69.5, 2.0, 8.4), 8],
	["escola_municao_biblioteca", Vector3(55.0, 2.0, 49.8), 6],
	["escola_municao_106", Vector3(28.75, 2.0, 61.6), 7],
]

var escola: Node3D
var versoes
var player: CharacterBody3D
var grizzolito: Node3D
var professora: Node3D
var adultos: Array = []

var _em_cena := false
var _perto_da_professora := false
var _esperando_volta_da_arena := false
var _prompt := "cap1_escola"


func iniciar(dono: Node3D) -> void:
	escola = dono
	player = escola.get_node_or_null("Player") as CharacterBody3D
	if Eventos.capitulo_atual() != Eventos.CAPITULO_1:
		return
	if Eventos.escola_clara():
		_escola_clara()
	elif Eventos.luta_grizzolito():
		_comecar_luta()
	elif Eventos.feito(Eventos.CAP1_GRIZZOLITO_DERROTADO) and not Eventos.feito(Eventos.CAP1_ESCOLA_PRESA):
		_portao_fecha.call_deferred()
	else:
		_escola_presa(true)


## O objetivo da escola é da história enquanto o Capítulo 1 estiver aqui.
func cuida_do_objetivo() -> bool:
	return Eventos.capitulo_atual() == Eventos.CAPITULO_1


func _objetivo(duracao: float = 45.0) -> void:
	var chave := Eventos.objetivo_atual()
	if chave != "":
		GlobalUtils.mostrar_objetivo(tr(chave), duracao)


# ==============================================================================
# CLARA
# ==============================================================================

func _escola_clara() -> void:
	versoes = EscolaVersoes.new(escola)
	escola.add_child(versoes)
	versoes.preparar_clara()
	_povoar()
	if not Eventos.feito(Eventos.CAP1_FALOU_DO_JONNY):
		_criar_professora()
	if not Eventos.feito(Eventos.CAP1_ESCOLA_ADULTOS):
		# a escola de gente: o amuleto vai pro bolso (R3 / H põe de volta na rua)
		SaveManager.amuleto_equipado = false
		_cutscene_da_chegada.call_deferred()
	else:
		_objetivo()


func _cutscene_da_chegada() -> void:
	await get_tree().process_frame
	if not is_instance_valid(player):
		return
	_em_cena = true
	var c = CutsceneAdultos.new()
	c.name = "cutscene_adultos"
	escola.add_child(c)
	c.rodar(escola, player)
	await c.terminou
	_em_cena = false
	Eventos.concluir(Eventos.CAP1_ESCOLA_ADULTOS)
	_objetivo()


func _modelos_de_gente() -> Array:
	var out: Array = []
	var lista: Array = CityNpcScript.MODELOS
	for i in lista.size():
		var n := String(lista[i])
		if n.contains("Police") or n.contains("Firefighter") or n.contains("Doctor") \
				or n.contains("Sheriff") or n.contains("_HM"):
			continue
		out.append(i)
	return out


func _povoar() -> void:
	var modelos := _modelos_de_gente()
	modelos.shuffle()
	var k := 0
	for a in ADULTOS:
		var npc = Adulto.new()
		npc.name = "adulto_%d" % k
		npc.modelo_index = modelos[k % modelos.size()]
		npc.escala = randf_range(0.95, 1.06)
		var pontos: Array = a[0]
		if pontos.is_empty():
			npc.olhar_para = a[1]
			npc.falando = a[2]
			npc.position = a[3]
		else:
			npc.pontos = pontos
			npc.position = pontos[0]
		escola.add_child(npc)
		adultos.append(npc)
		k += 1


func _criar_professora() -> void:
	var modelos := _modelos_de_gente().filter(func(i): return String(CityNpcScript.MODELOS[i]).contains("Female"))
	var npc = Adulto.new()
	npc.name = "professora_107"
	npc.modelo_index = modelos[3 % modelos.size()] if not modelos.is_empty() else -1
	npc.olhar_para = PROFESSORA_OLHA
	npc.falando = false
	npc.position = PROFESSORA
	escola.add_child(npc)
	professora = npc
	adultos.append(npc)


## A conversa da 107. Nenhuma câmera nova: o jogador para, as falas passam no
## meio da tela (o aceitar adianta) e a história anda.
func _conversar() -> void:
	_em_cena = true
	GlobalUtils.hide_center_message(_prompt)
	GlobalEvents.in_cutscene = true
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
		player.cutscene_set_player_control(false)
	if is_instance_valid(professora):
		professora.falando = true
	for chave in ["CAP1_107_MAYCOW_1", "CAP1_107_PROF_1", "CAP1_107_PROF_2", "CAP1_107_MAYCOW_2"]:
		GlobalUtils.show_center_message("dialogo_107", tr(chave), 20)
		await _segurar_fala(3.4)
	GlobalUtils.hide_center_message("dialogo_107")
	if is_instance_valid(professora):
		professora.falando = false
	if is_instance_valid(player):
		player.cutscene_set_player_control(true)
	GlobalEvents.in_cutscene = false
	Eventos.concluir(Eventos.CAP1_FALOU_DO_JONNY)
	_em_cena = false
	_objetivo()


## Espera `segundos` ou o aceitar (o que vier antes).
func _segurar_fala(segundos: float) -> void:
	var t := 0.0
	await get_tree().process_frame
	while t < segundos:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 0.35 and Input.is_action_just_pressed("ui_accept"):
			return


func _cutscene_da_quadra() -> void:
	_em_cena = true
	GlobalUtils.hide_center_message(_prompt)
	var dona := _ator(CENA_DONA_NICE, CLIPES_DONA_NICE)
	var jonny := _ator(CENA_JONNY, CLIPES_JONNY)
	for som in jonny.find_children("*", "AudioStreamPlayer3D", true, false):
		som.queue_free()
	# parado e invisível no canto até a cena mostrar ele chegando (inativo,
	# ele não anda; invisível, o amuleto não o enxerga)
	grizzolito = (load(CENA_GRIZZOLITO) as PackedScene).instantiate() as Node3D
	grizzolito.visible = false
	escola.add_child(grizzolito)
	grizzolito.global_position = LUTA_GRIZZOLITO + Vector3.UP * 0.2

	var c = CutsceneQuadra.new()
	c.name = "cutscene_quadra"
	c.versoes = versoes
	c.dona = dona
	c.jonny = jonny
	c.grizzolito = grizzolito
	c.adultos = adultos
	escola.add_child(c)
	c.rodar(escola, player)
	await c.terminou
	for ator in [dona, jonny]:
		if is_instance_valid(ator):
			ator.queue_free()
	adultos.clear()
	_em_cena = false
	_soltar_luta()


## Um ator da igreja (Dona Nice, Jonny) com a biblioteca "escola" somada à
## dele: os clipes novos vêm de um .glb só de esqueleto, com as mesmas trilhas.
func _ator(cena: String, clipes: String) -> Node3D:
	var ator := (load(cena) as PackedScene).instantiate() as Node3D
	ator.set("clipe_inicial", &"")
	ator.visible = false
	escola.add_child(ator)
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


# ==============================================================================
# LUTA
# ==============================================================================

## A cena carregou já na luta (save, game over): sem cutscene, direto nela.
func _comecar_luta() -> void:
	SaveManager.amuleto_equipado = true
	SaveManager.current_mp = maxf(SaveManager.current_mp, SaveManager.max_mp * 0.5)
	grizzolito = (load(CENA_GRIZZOLITO) as PackedScene).instantiate() as Node3D
	escola.add_child(grizzolito)
	grizzolito.global_position = LUTA_GRIZZOLITO + Vector3.UP * 0.2
	if is_instance_valid(player):
		player.global_position = LUTA_MAYCOW + Vector3.UP * 1.05
		var d := LUTA_GRIZZOLITO - LUTA_MAYCOW
		player.rotation.y = atan2(-d.x, -d.z)
		var para := LUTA_MAYCOW - LUTA_GRIZZOLITO
		grizzolito.rotation.y = atan2(para.x, para.z)
	await get_tree().create_timer(1.6, false).timeout
	_soltar_luta()


func _soltar_luta() -> void:
	if not is_instance_valid(grizzolito):
		return
	grizzolito.visible = true
	grizzolito.comecar()
	_esperando_volta_da_arena = true
	_objetivo(0.0)
	GlobalUtils.show_center_message("grizzolito_amuleto",
		tr("AVISO_GRIZZOLITO_AMULETO_PAD" if GlobalEvents.usando_controle
			else "AVISO_GRIZZOLITO_AMULETO_KEY"), 20, 6.0)


# ==============================================================================
# PRESA
# ==============================================================================

func _portao_fecha() -> void:
	await get_tree().process_frame
	if not is_instance_valid(player):
		return
	_em_cena = true
	GlobalUtils.esconder_objetivo()
	var c = CutscenePortao.new()
	c.name = "cutscene_portao"
	c.porta = escola.get_node_or_null("portas/porta_principal")
	escola.add_child(c)
	c.rodar(escola, player)
	await c.terminou
	_em_cena = false
	_escola_presa()


## `ao_carregar`: a cena acabou de abrir (e não a cutscene acabou de rodar).
func _escola_presa(ao_carregar: bool = false) -> void:
	Municao.espalhar(escola, MUNICAO_ESCOLA)
	if Eventos.escola_presa():
		# Veio da cidade, do save ou do game over: o pátio está fechado, então ele
		# nasce do lado de dentro. Vindo pelo buraco, o marcador dele já vale.
		if ao_carregar and String(escola.get("chegada")) == "" and is_instance_valid(player):
			player.global_position = PRESO_NASCE + Vector3.UP * 1.05
			player.rotation.y = -PI * 0.5
		marcar_interrogacao(escola, INTERROGACAO_CALABOUCO)
	_objetivo()


## Uma interrogação no mapa (a aba MAPA e o minimapa), presa a um nó parado.
static func marcar_interrogacao(dono: Node3D, onde: Vector3) -> void:
	var no := Node3D.new()
	no.name = "interrogacao_calabouco"
	dono.add_child(no)
	no.global_position = onde
	var ponto = PontoNoMapa.new()
	ponto.chave = "MAP_POI_CALABOUCO"
	ponto.tipo = "interrogacao"
	ponto.sempre_visivel = true
	no.add_child(ponto)


# ==============================================================================
# O QUE SE CHECA A CADA QUADRO
# ==============================================================================

func _process(_delta: float) -> void:
	if _em_cena or not is_instance_valid(player) or GlobalEvents.in_cutscene:
		return
	# a volta da arena: a escola reaparece e o Grizzolito já morreu lá
	if _esperando_volta_da_arena and Eventos.feito(Eventos.CAP1_GRIZZOLITO_DERROTADO):
		_esperando_volta_da_arena = false
		_em_cena = true
		await get_tree().create_timer(3.0, false).timeout
		_portao_fecha()
		return
	if not Eventos.escola_clara():
		return
	if Eventos.pode(Eventos.CAP1_FALOU_DO_JONNY):
		_professora_perto()
	elif Eventos.pode(Eventos.CAP1_ESCOLA_TRANSFORMADA):
		var p := player.global_position
		if PATIO_GATILHO.has_point(Vector2(p.x, p.z)):
			_cutscene_da_quadra()


func _professora_perto() -> void:
	if not is_instance_valid(professora):
		return
	var d := player.global_position.distance_to(professora.global_position)
	var perto := d < PROFESSORA_ALCANCE
	if perto != _perto_da_professora:
		_perto_da_professora = perto
		if perto:
			GlobalUtils.show_center_message(_prompt, tr("PROMPT_FALAR_PROFESSORA"), 18)
		else:
			GlobalUtils.hide_center_message(_prompt)
	if perto and Input.is_action_just_pressed("ui_accept"):
		_perto_da_professora = false
		_conversar()
