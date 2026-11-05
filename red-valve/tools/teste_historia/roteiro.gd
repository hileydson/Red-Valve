extends Node

## As etapas do HISTORIA.md, na ordem. Cada `etapa_*` continua do save que a
## anterior deixou no slot 9.

const CIDADE := "res://scenes/stages/stage_1/stage_1.tscn"

const AREAS_CIDADE := {
	"oficina": ["itens_caminho_jimmy/auto_pecas_jimmy/Area3D_jimmy_house", "player_na_oficina"],
	"casa_jimmy": ["itens_caminho_jimmy/casa_jimmy/area_entrada", "player_na_casa_jimmy"],
	"casa_maycow": ["area_entrada_casa_maycow", "player_na_casa_maycow"],
	"casa_nice": ["casa_nice/area_entrada", "player_na_casa_nice"],
	"igreja": ["area_entrada_igreja", "player_na_igreja"],
	"hospital": ["locais_importantes/hospital_exterior/area_entrada", "player_no_hospital"],
	"escola": ["locais_importantes/escola_exterior/area_entrada", "player_na_escola"],
}

var x


# ==============================================================================
# AJUDAS
# ==============================================================================

func ok(n: String, c: bool, d: String = "") -> bool:
	return x.ok(n, c, d)


## Põe o jogador dentro de `area` (na forma dela, depois no nó) até `flag`
## de `dono` ligar. Se o teleporte não acender a área (geometria do teste), liga
## a flag à mão — só se a área tiver o sinal ligado — e avisa.
func pisar(area: Area3D, dono: Node, flag: String) -> bool:
	x.por(Vector3(0, 400, 0))
	for i in 6:
		await get_tree().physics_frame
	var pontos := []
	for f in area.find_children("*", "CollisionShape3D", false, false):
		pontos.append((f as Node3D).global_position)
	pontos.append(area.global_position)
	for p in pontos:
		x.por(p)
		for i in 12:
			await get_tree().physics_frame
		if bool(dono.get(flag)):
			return true
	x.nota("a área '%s' não acendeu '%s' com o jogador dentro" % [area.name, flag])
	return false


## Encosta o jogador na área de um lugar da cidade e devolve o texto do prompt.
func encostar_na_porta(local: String) -> String:
	var cidade := get_tree().current_scene
	var a: Array = AREAS_CIDADE[local]
	var area := cidade.get_node_or_null(a[0]) as Area3D
	if area == null:
		area = cidade.find_child(String(a[0]).get_file(), true, false) as Area3D
	if not ok("área da porta '%s' existe" % local, area != null):
		return ""
	# como quem sai andando de uma porta: nenhuma área fica marcada
	for l in AREAS_CIDADE:
		cidade.set(AREAS_CIDADE[l][1], false)
	ok("jogador dentro da área '%s'" % local, await pisar(area, cidade, a[1]))
	var lbl = cidade.get("prompt_label")
	if lbl and String(lbl.text) == "":
		return ""
	return String(lbl.text) if lbl else ""


## Aperta o aceitar diante da porta e diz se a cena mudou para `destino`.
func entrar(local: String, destino: String, limite := 40.0) -> bool:
	var txt = await encostar_na_porta(local)
	x.log_("  prompt de '%s': \"%s\"" % [local, txt])
	await x.apertar("ui_accept")
	await x.esperar(0.5)
	await x.apertar("ui_accept")   # a igreja: o 1º aperto gira a chave
	return await x.ate_cena(destino, limite)


func checar_locais(esperado: Dictionary, quando: String) -> void:
	var errado := []
	for l in esperado:
		if Eventos.local_aberto(l) != bool(esperado[l]):
			errado.append("%s deveria estar %s" % [l, "ABERTO" if esperado[l] else "FECHADO"])
	ok("lugares da cidade (%s)" % quando, errado.is_empty(), ", ".join(errado) if not errado.is_empty() else x.locais())


func objetivo(chave: String, quando: String) -> void:
	ok("objetivo %s = %s" % [quando, chave], Eventos.objetivo_atual() == chave,
		"está " + Eventos.objetivo_atual())


func const_de(no: Object, nome: String) -> Variant:
	return no.get_script().get_script_constant_map().get(nome)


## Abre a gaveta (o selecionável dela) e pega os itens `itens` que nascerem.
func abrir_gaveta(gaveta: Node, itens: Array) -> void:
	if gaveta == null:
		return
	x.pegar(gaveta)
	await x.esperar(3.0)
	var achados := []
	for n in get_tree().current_scene.find_children("*", "", true, false):
		if n.has_method("_pegar") and String(n.get_meta("item", "")) in itens:
			achados.append(n)
	x.log_("  na gaveta: " + str(achados.map(func(n): return "%s(%s)" % [n.name, n.get_meta("item")])))
	for n in achados:
		if is_instance_valid(n):
			n.call("_pegar")
			await x.esperar(0.8)
			await x.fechar_tela_quando_vier(5.0)


func no_com_script(base: Node, fim: String) -> Node:
	for n in base.find_children("*", "", true, false):
		var sc = n.get_script()
		if sc and sc.resource_path.ends_with(fim):
			return n
	return null


## Pertinho de um portal (vórtice): `dentro` = no raio de captura.
func perto_do_portal(portal: Node3D, dentro: bool) -> void:
	var frente: Vector3 = portal.get("frente") if portal.get("frente") != null else Vector3.BACK
	var raio: float = float(portal.get("raio_captura")) if portal.get("raio_captura") != null else 6.0
	var d := 1.0 if dentro else raio + 1.5
	x.por(portal.global_position + frente * d + Vector3.UP * 1.0)
	for i in 8:
		await get_tree().physics_frame


## Paga o selo de um portal (100 iron rusks) e entra nele.
func pagar_e_entrar(portal: Node3D, evento: String, destino: String) -> bool:
	if not ok("portal do fim existe", portal != null):
		return false
	var selo := portal.get_node_or_null("selo")
	ok("portal selado (%s)" % evento, selo != null)
	ok("selo bloqueia o portal", bool(portal.get("bloqueado")))
	SaveManager.iron_rusks = 0
	await perto_do_portal(portal, false)
	await x.esperar(0.6)
	await x.apertar("ui_accept")
	await x.esperar(1.0)
	ok("sem iron rusks o selo não abre", not Eventos.feito(evento))
	var antes := SaveManager.iron_rusks
	SaveManager.add_iron_rusks(Eventos.CUSTO_PORTAL)
	x.nota("teste deu %d iron rusks (no jogo vêm dos inimigos)" % Eventos.CUSTO_PORTAL)
	await x.esperar(0.4)
	await x.apertar("ui_accept")
	ok("paga 100 iron rusks e o selo rompe", await x.ate_evento(evento, 10))
	ok("cobrou 100", SaveManager.iron_rusks == antes, str(SaveManager.iron_rusks))
	await x.ate(func() -> bool: return not bool(portal.get("bloqueado")), 15)
	await perto_do_portal(portal, true)
	return await x.ate_cena(destino, 60)


func tem(item: String) -> bool:
	return SaveManager.tem_item(item)


# ==============================================================================
# PRÓLOGO
# ==============================================================================

func etapa_prologo() -> void:
	x.log_("PRÓLOGO — novo jogo, slot 9 zerado")
	SaveManager.current_slot = 9
	SaveManager.reset_progress()
	SaveManager.escolher_slot(9)
	SaveManager.save_game()
	await x.ir("res://scenes/stages/stage_1/stage_1_cutscene_prologo.tscn")
	ok("abertura do prólogo leva à casa do Maycow", await x.ate_cena("the_house", 120, true), x.cena())
	await x.esperar(3.0)
	var casa := get_tree().current_scene
	ok("começa sem a ligação", not Eventos.feito(Eventos.PROLOGO_TELEFONE))
	ok("arquivo da introdução liberado", SaveManager.tem_arquivo("apos_um_dia_de_trabalho"))
	# P3: a Dona Nice liga
	casa.call("_on_phone_timer_timeout")
	var tel := casa.find_child("Area3D_telefone", true, false) as Area3D
	ok("perto do telefone tocando", await pisar(tel, casa, "player_no_telefone") and bool(casa.get("telefone_tocando")))
	await x.apertar("ui_accept")
	ok("P3 atendeu a Dona Nice (arquivo do telefonema)",
		await x.ate_evento(Eventos.PROLOGO_TELEFONE, 120, true))
	await x.esperar(2.0)
	var porta := casa.find_child("porta_saida", true, false).get_node("Area3D") as Area3D
	ok("porta da casa libera depois da ligação", await pisar(porta, casa, "player_na_porta"))
	await x.apertar("ui_accept")
	ok("sai de casa para a cidade", await x.ate_cena("stage_1/stage_1.tscn", 60), x.cena())
	await x.esperar(5.0)
	ok("intro da cidade marcada", Eventos.feito(Eventos.PROLOGO_INTRO_CIDADE))
	x.log_("  " + x.estado())
	# P3: vai à oficina
	ok("P3 entra na oficina", await entrar("oficina", "oficina_jimmy", 60), x.cena())
	await x.esperar(2.0)
	# P4/P5: a red valve, o inferno 2 e a volta (o filme inteiro, sem pular)
	var foi = await x.ate_cena("inferno_2", 240)
	ok("P4-P5 a red valve leva o Maycow ao outro mundo (inferno 2)", foi, x.cena())
	if foi:
		ok("P5 o outro mundo o devolve à oficina", await x.ate_cena("oficina_jimmy", 240), x.cena())
	else:
		x.pular_cutscenes()
		await x.ate_cena("oficina_jimmy", 30)
	# a luta sem poder: o Maycow perde
	await x.esperar(8.0)
	var t0 := Time.get_ticks_msec()
	while x.cena().contains("oficina_jimmy") and Time.get_ticks_msec() - t0 < 150000:
		x.pular_cutscenes()
		var p = x.jogador()
		if p and not bool(GlobalEvents.in_cutscene) and p.has_method("take_damage"):
			p.call("take_damage", 40)
		await x.esperar(1.0)
	ok("perder a luta da oficina leva ao filme do fim da luta", x.cena().contains("end_first_fight") or x.cena().contains("battlefield"), x.cena())
	ok("o filme leva à arena (battlefield 1)", await x.ate_cena("battlefield", 240, true), x.cena())
	ok("intro da arena marcada", await x.ate_evento(Eventos.PROLOGO_ARENA_INTRO, 60))
	t0 = Time.get_ticks_msec()
	while x.cena().contains("battlefield") and Time.get_ticks_msec() - t0 < 180000:
		await x.esperar(1.0)
		x.matar_inimigos()
	ok("vencer a arena leva ao filme do poder", x.cena().contains("fight_with_power") or x.cena().contains("stage_1"), x.cena())
	ok("P6 o filme termina na cidade (Capítulo 1)", await x.ate_cena("stage_1/stage_1.tscn", 300, true), x.cena())
	ok("prólogo concluído", Eventos.feito(Eventos.PROLOGO_CONCLUIDO))
	var veio = await x.ate(func() -> bool: return tem("amuleto"), 120.0)
	ok("abertura do Capítulo 1 entrega o amuleto", veio)
	await x.fechar_tela_quando_vier(10.0)
	ok("capítulo atual = 1", Eventos.capitulo_atual() == 1, str(Eventos.capitulo_atual()))
	x.log_("  " + x.estado())


# ==============================================================================
# CAPÍTULO 1 — O AMULETO
# ==============================================================================

func carregar_save() -> void:
	SaveManager.current_slot = 9
	SaveManager.sem_slot_escolhido = false
	ok("save do slot 9 carrega", SaveManager.load_game(9))
	await x.ate(func() -> bool: return x.cena() == SaveManager.current_stage, 90.0)
	await x.esperar(4.0)
	x.log_("  carregado: " + x.estado())


func etapa_cap1() -> void:
	await carregar_save()
	ok("capítulo 1", Eventos.capitulo_atual() == 1)
	ok("amuleto no inventário", tem("amuleto"))
	objetivo("OBJ_CAP1_CASA_JIMMY", "no começo")
	checar_locais({"casa_maycow": true, "casa_jimmy": true, "escola": false, "igreja": false,
		"hospital": false, "casa_nice": false, "oficina": false}, "começo do cap. 1")
	var txt = await encostar_na_porta("escola")
	ok("escola avisa que está fechada", txt == tr("PROMPT_ESCOLA_FECHADA"), txt)
	await x.apertar("ui_accept")
	await x.esperar(3.0)
	ok("escola fechada não troca de cena", x.cena() == CIDADE)
	var of_area := get_tree().current_scene.get_node_or_null(AREAS_CIDADE["oficina"][0]) as Area3D
	var acendeu = await pisar(of_area, get_tree().current_scene, "player_na_oficina")
	ok("oficina fechada no cap. 1 (a porta não reage)", not acendeu)

	# 1. a casa do Jimmy
	ok("C1.1 entra na casa do Jimmy", await entrar("casa_jimmy", "casa_jimmy_interior"), x.cena())
	await x.esperar(2.0)
	var casa := get_tree().current_scene
	var diario := casa.get_node_or_null("diario_jimmy")
	ok("diário em cima da mesa", diario != null)
	ok("pega o diário", x.pegar(diario))
	await x.esperar(1.5)
	await x.fechar_tela_quando_vier(10.0)
	ok("C1.1 diário lido", await x.ate_evento(Eventos.CAP1_DIARIO_JIMMY, 20))
	ok("diário nos arquivos", SaveManager.tem_arquivo("diario_jimmy") or SaveManager.arquivos_desbloqueados.any(func(a): return String(a).contains("diario")),
		str(SaveManager.arquivos_desbloqueados))
	objetivo("OBJ_CAP1_IR_ESCOLA", "depois do diário")
	ok("escola abre depois do diário", Eventos.local_aberto("escola"))
	var gaveta: Node = null
	for n in casa.find_children("*", "", true, false):
		var sc = n.get_script()
		if sc and sc.resource_path.ends_with("gaveta_pistola.gd"):
			gaveta = n
	ok("gaveta da pistola no quarto do Jimmy", gaveta != null)
	await abrir_gaveta(gaveta, ["pistol", "pistol_ammo"])
	ok("pistola do Jimmy pega", tem("pistol"))
	ok("balas da pistola", SaveManager.get_item_amount("pistol_ammo") > 0, str(SaveManager.get_item_amount("pistol_ammo")))
	casa.call("_sair_da_casa")
	ok("sai da casa do Jimmy", await x.ate_cena("stage_1/stage_1.tscn", 40))
	await x.esperar(3.0)

	# 2. a escola clara
	ok("C1.2 entra na escola", await entrar("escola", "escola/escola.tscn"), x.cena())
	await x.esperar(2.0)
	ok("escola clara", Eventos.escola_clara())
	ok("amuleto no bolso na escola", not SaveManager.amuleto_equipado)
	ok("C1.2 cutscene dos adultos", await x.ate_evento(Eventos.CAP1_ESCOLA_ADULTOS, 90, true))
	objetivo("OBJ_CAP1_ULTIMA_SALA", "na escola clara")
	var escola := get_tree().current_scene
	var cap1 = escola.find_child("*capitulo_1*", true, false)
	for n in escola.get_children():
		var sc = n.get_script()
		if sc and sc.resource_path.ends_with("capitulo_1_escola.gd"):
			cap1 = n
	ok("controle do cap. 1 na escola", cap1 != null)
	var prof = cap1.get("professora") if cap1 else null
	ok("professora da sala 107", prof != null)
	var adultos: Array = cap1.get("adultos") if cap1 else []
	ok("adultos pela escola", adultos.size() >= 8, str(adultos.size()))
	var saida_rua: Node3D = null
	for p in escola.find_children("*", "", true, false):
		if p.has_meta("saida") and bool(p.get_meta("saida")):
			saida_rua = p
	if saida_rua:
		var patio: Rect2 = const_de(cap1, "PATIO_GATILHO")
		var sp := saida_rua.global_position
		x.log_("  portão da rua em %s (dentro do gatilho do pátio: %s)" % [sp, patio.has_point(Vector2(sp.x, sp.z))])
	if prof:
		x.por(prof.global_position + Vector3(1.0, 1.05, 0.0))
		await x.esperar(0.6)
		await x.apertar("ui_accept")
		ok("C1.2 a professora conta da Dona Nice", await x.ate_evento(Eventos.CAP1_FALOU_DO_JONNY, 30))
	objetivo("OBJ_CAP1_CASA_NICE", "depois da professora")
	x.nota("o objetivo agora manda à casa da Dona Nice, que no Capítulo 1 está trancada (local_aberto casa_nice=%s)" % Eventos.local_aberto("casa_nice"))

	# 3. a quadra
	x.por(Vector3(24.0, 1.2, 24.0))
	ok("C1.3 cutscene da quadra (raio, escola escura)", await x.ate_evento(Eventos.CAP1_ESCOLA_TRANSFORMADA, 120, true))
	await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 60)
	await x.esperar(2.0)
	var griz = cap1.get("grizzolito") if is_instance_valid(cap1) else null
	ok("Grizzolito na quadra", is_instance_valid(griz))
	ok("amuleto vale na quadra", SaveManager.amuleto_disponivel() if SaveManager.has_method("amuleto_disponivel") else true)
	ok("adultos sumiram", (cap1.get("adultos") as Array).is_empty())
	objetivo("OBJ_CAP1_GRIZZOLITO", "na luta")

	# 4. a luta na arena
	if is_instance_valid(griz):
		ok("C1.4 leva o Grizzolito à arena e vence", await x.lutar_na_arena([griz], 150))
	ok("Grizzolito derrotado", Eventos.feito(Eventos.CAP1_GRIZZOLITO_DERROTADO))
	# 5. presa
	ok("C1.5 porta principal bate (presa)", await x.ate_evento(Eventos.CAP1_ESCOLA_PRESA, 90, true))
	await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 30)
	ok("escola presa", Eventos.escola_presa())
	objetivo("OBJ_CAP1_SAIR_ESCOLA", "presa")
	var interr = escola.find_children("interrogacao*", "", true, false)
	ok("interrogação do calabouço no mapa", not interr.is_empty(), str(escola.get_children().map(func(n): return String(n.name)).filter(func(n): return n.contains("interr"))))
	escola.call("usar_buraco", "buraco_entrada")
	ok("desce pelo buraco do depósito ao porão", await x.ate_cena("porao", 40), x.cena())
	await x.esperar(3.0)
	var porao := get_tree().current_scene
	var lant := porao.get_node_or_null("lanterna_no_chao")
	ok("C1.5 lanterna no chão no começo do calabouço", lant != null)
	ok("pega a lanterna", x.pegar(lant))
	await x.fechar_tela_quando_vier(8.0)
	ok("lanterna no inventário", await x.ate(func() -> bool: return tem("lanterna"), 10))

	# 6. a red valve e o inferno 4
	var camara: Rect2 = const_de(porao, "CAMARA")
	var centro := camara.get_center()
	x.por(Vector3(centro.x, 1.5, centro.y))
	ok("C1.6 a red valve chama (cutscene em 1ª pessoa)", await x.ate_evento(Eventos.CAP1_RED_VALVE, 60))
	ok("C1.6 vai ao inferno 4", await x.ate_cena("inferno_4", 60), x.cena())
	await x.esperar(4.0)
	var inf4 := get_tree().current_scene
	var altar := inf4.get_node_or_null("aura_no_altar")
	ok("chama roxa no altar da chegada", altar != null)
	if altar:
		x.por(altar.global_position + Vector3(0, 0.5, 2.0))
		await x.esperar(0.5)
		x.pegar(altar)
	ok("C1.6 aura do amuleto", await x.ate_evento(Eventos.CAP1_AURA_AMULETO, 40))
	ok("poder Thrown liberado", Eventos.poder_liberado(Eventos.PODER_THROWN))
	await x.fechar_tela_quando_vier(12.0)
	var mir := inf4.get_node_or_null("gatilho_mirante") as Area3D
	if mir:
		x.por(mir.global_position)
		ok("cutscene do mirante", await x.ate_evento(Eventos.CAP1_INFERNO_4_MIRANTE, 120, true))
		await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 30)
	var saida = inf4.get("_portal_saida")
	ok("portal do fim fechado no cap. 1", saida and bool(saida.get("bloqueado")))
	if saida:
		x.por(saida.global_position + Vector3(0, 1.5, 6.0))
	ok("C1.6 gárgula leva ao portal do começo", await x.ate_evento(Eventos.CAP1_INFERNO_4_LIMITE, 120))
	ok("C1.6 o portal cospe de volta no porão", await x.ate_cena("porao", 120), x.cena())
	await x.esperar(4.0)
	porao = get_tree().current_scene
	var rv = porao.get_node_or_null("red_valve")
	ok("red valve agora só abre com prompt", rv and bool(rv.get("com_prompt")) and not bool(rv.get("bloqueada")))
	objetivo("OBJ_CAP1_ATRAVESSAR_PORAO", "de volta ao porão")

	# 7. saída
	porao.call("usar_buraco", "boca_saida")
	ok("C1.7 sobe pelo almoxarifado", await x.ate_cena("escola/escola.tscn", 40), x.cena())
	await x.esperar(3.0)
	escola = get_tree().current_scene
	var portao: Node3D = null
	for p in escola.find_children("*", "", true, false):
		if p.has_meta("portao") and bool(p.get_meta("portao")):
			portao = p
	ok("portão do pátio existe", portao != null)
	if portao:
		var j = x.jogador()
		portao.set("_player", j)
		x.por(portao.to_global(Vector3(0, 1.0, 1.2)))
		await x.esperar(0.3)
		portao.call("_acionar")
	ok("C1.7 destranca o portão do pátio por dentro", await x.ate_evento(Eventos.CAP1_PORTAO_PATIO, 10))
	objetivo("OBJ_CAP1_SAIR_PELO_PATIO", "portão aberto")
	escola.call("sair_da_escola")
	ok("sai pela rua", await x.ate_cena("stage_1/stage_1.tscn", 60), x.cena())
	ok("Capítulo 1 concluído", Eventos.feito(Eventos.CAP1_CONCLUIDO))
	await x.esperar(6.0)
	ok("capítulo 2", Eventos.capitulo_atual() == 2)
	x.log_("  " + x.estado())


# ==============================================================================
# CAPÍTULO 2 — DONA NICE
# ==============================================================================

func etapa_cap2() -> void:
	await carregar_save()
	ok("capítulo 2", Eventos.capitulo_atual() == 2)
	objetivo("OBJ_CAP2_BUSCAR_NICE_JONNY", "no começo")
	checar_locais({"casa_maycow": true, "casa_jimmy": true, "escola": true, "igreja": false,
		"hospital": false, "casa_nice": false, "oficina": false}, "começo do cap. 2")
	# 1. a praça
	x.por(Vector3(560.0, 14.0, -317.6))
	ok("C2.1 cena da praça: Dona Nice entra na igreja com o Jonny",
		await x.ate_evento(Eventos.CAP2_NICE_ENTRA_IGREJA, 120, true))
	await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 30)
	objetivo("OBJ_CAP2_ENTRAR_IGREJA", "depois da praça")
	checar_locais({"casa_nice": true, "igreja": true, "hospital": false}, "depois da praça")
	ok("igreja continua trancada", not SaveManager.igreja_aberta())
	var txt = await encostar_na_porta("igreja")
	ok("igreja avisa trancada", txt == tr("PROMPT_CHURCH_LOCKED"), txt)

	# 2. a casa da Dona Nice
	ok("C2.2 entra na casa da Dona Nice", await entrar("casa_nice", "casa_nice_interior"), x.cena())
	await x.esperar(2.0)
	var casa := get_tree().current_scene
	var carta := casa.get_node_or_null("carta_nice")
	ok("carta na laje do ritual", carta != null)
	x.pegar(carta)
	await x.esperar(1.0)
	await x.fechar_tela_quando_vier(10.0)
	ok("C2.2 carta lida", await x.ate_evento(Eventos.CAP2_CARTA_NICE, 15))
	ok("carta nos arquivos", SaveManager.tem_arquivo("carta_da_dona_nice"))
	for nome in ["shotgun_laje", "shotgun_municao_laje"]:
		var it := casa.get_node_or_null(nome)
		ok("%s na casa" % nome, it != null)
		if it:
			it.call("_pegar")
			await x.esperar(0.8)
			await x.fechar_tela_quando_vier(5.0)
	ok("C2.2 espingarda pega", tem("shotgun"))
	ok("dois cartuchos", SaveManager.get_item_amount("shotgun_ammo") == 2, str(SaveManager.get_item_amount("shotgun_ammo")))
	await abrir_gaveta(casa.get_node_or_null("gaveta_chave"), ["chave_igreja"])
	ok("C2.2 chave reserva da igreja", tem("chave_igreja"))
	objetivo("OBJ_CAP2_ENTRAR_IGREJA", "com a chave")
	casa.call("_sair_da_casa")
	ok("sai da casa da Dona Nice", await x.ate_cena("stage_1/stage_1.tscn", 40))
	await x.esperar(3.0)

	# 3. a igreja
	ok("C2.3 a chave abre a igreja", await entrar("igreja", "igreja_interior", 40), x.cena())
	ok("chave usada (some do inventário)", not tem("chave_igreja"))
	ok("igreja destrancada", Eventos.feito(Eventos.CAP2_IGREJA_DESTRANCADA))
	await x.esperar(3.0)
	var igreja := get_tree().current_scene
	var ev = igreja.get_node_or_null("evento_dona_nice")
	ok("evento da Dona Nice", ev != null)
	var t0 := Time.get_ticks_msec()
	while not Eventos.feito(Eventos.CAP2_DONA_NICE_DERROTADA) and Time.get_ticks_msec() - t0 < 300000:
		await x.esperar(1.0)
		var cena = ev.get("cena")
		if cena and cena.get("diretor") and cena.diretor.is_playing() and Time.get_ticks_msec() - t0 > 4000:
			cena.call("pular")
		var b = ev.get("boss")
		if is_instance_valid(b) and not bool(b.get("dead")) and not GlobalEvents.in_cutscene:
			b.call("take_damage", 99999)
		var p = x.jogador()
		if p:
			p.set("current_health", 100)
	ok("C2.3 Dona Nice morta nas duas formas", Eventos.feito(Eventos.CAP2_DONA_NICE_DERROTADA))
	await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 60)
	await x.esperar(1.0)
	var jonny = ev.get("cena").get_node_or_null("atores/Jonny")
	if jonny:
		x.por(jonny.global_position + Vector3(0.8, 1.05, 0))
		await x.esperar(0.5)
		await x.apertar("ui_accept")
	ok("C2.3 sai carregando o Jonny", await x.ate_cena("stage_1/stage_1.tscn", 90, true), x.cena())
	await x.esperar(4.0)
	ok("Jonny no colo (estado 4)", SaveManager.evento_dona_nice == 4, str(SaveManager.evento_dona_nice))
	objetivo("OBJ_LEVAR_JONNY_HOSPITAL", "com o Jonny")
	ok("hospital só agora abre", Eventos.local_aberto("hospital"))
	txt = await encostar_na_porta("casa_jimmy")
	x.log_("  com o Jonny no colo, a casa do Jimmy diz: \"%s\"" % txt)

	# 4. o hospital
	ok("C2.4 entra no hospital com o Jonny", await entrar("hospital", "hospital/hospital.tscn", 40), x.cena())
	await x.esperar(4.0)
	var hosp := get_tree().current_scene
	ok("hospital claro", Eventos.hospital_claro())
	var cap2 = no_com_script(hosp, "capitulo_2_hospital.gd")
	ok("enfermeira guia", cap2 and is_instance_valid(cap2.get("guia")) if cap2 and "guia" in cap2 else false)
	var lado: Vector3 = const_de(cap2, "LADO_DA_MACA")
	x.por(lado + Vector3(0, 1.05, 0))
	for i in 20:
		await get_tree().physics_frame
	await x.apertar("ui_accept")
	ok("C2.4 deita o Jonny na maca", await x.ate_evento(Eventos.CAP2_JONNY_NA_MACA, 30))
	# 5-6. a transformação e a Drizzi
	ok("C2.5-6 transformação e a Drizzi no escuro", await x.ate_evento(Eventos.CAP2_DRIZZI, 180, true))
	ok("hospital escuro", not Eventos.hospital_claro())
	await x.esperar(3.0)
	var p = x.jogador()
	if p and p.has_method("acender_lanterna_agora"):
		p.call("acender_lanterna_agora")
	await x.esperar(2.0)
	objetivo("OBJ_CAP2_SAIR_HOSPITAL", "no escuro")
	# 7. saída
	hosp.call("sair_do_hospital")
	ok("C2.7 sai do hospital", await x.ate_cena("stage_1/stage_1.tscn", 40), x.cena())
	ok("Capítulo 2 concluído", Eventos.feito(Eventos.CAP2_CONCLUIDO))
	await x.esperar(6.0)
	ok("capítulo 3", Eventos.capitulo_atual() == 3)
	x.log_("  " + x.estado())


# ==============================================================================
# CAPÍTULO 3 — O CEMITÉRIO
# ==============================================================================

func etapa_cap3() -> void:
	await carregar_save()
	ok("capítulo 3", Eventos.capitulo_atual() == 3)
	objetivo("OBJ_CAP3_CEMITERIO", "no começo")
	ok("floresta aberta", Eventos.floresta_aberta())
	var cidade := get_tree().current_scene
	var f := cidade.get_node_or_null("locais_importantes/floresta_local") as Node3D
	var c := cidade.get_node_or_null("locais_importantes/cemiterio_local") as Node3D
	ok("pontos da floresta e do cemitério", f != null and c != null)
	# 1. a floresta
	x.por(f.global_position + Vector3(0, 2.0, 0))
	ok("C3.1 entra na mata (cena dele andando)", await x.ate_evento(Eventos.CAP3_FLORESTA, 120, true))
	await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 30)
	await x.esperar(2.0)
	ok("floresta prende na 1ª vez", Eventos.floresta_presa())
	objetivo("OBJ_CAP3_ATRAVESSAR_FLORESTA", "na mata")
	x.por(f.global_position + Vector3(0, 2.0, 0) + (c.global_position - f.global_position).normalized() * 9.0)
	await x.esperar(3.0)
	ok("a volta pela beira da mata não leva à cidade", x.cena() == CIDADE and Eventos.floresta_presa())
	x.por(c.global_position + Vector3(0, 2.0, 0))
	ok("chega ao cemitério", await x.ate_cena("cemiterio", 60), x.cena())
	await x.esperar(5.0)
	ok("cemitério marcado", Eventos.feito(Eventos.CAP3_CEMITERIO))
	objetivo("OBJ_CAP3_CAPELA", "no cemitério")
	var cem := get_tree().current_scene
	var cap3 = no_com_script(cem, "capitulo_3_cemiterio.gd")
	ok("controle do cap. 3", cap3 != null)
	var drizzi = cap3.get("_drizzi")
	ok("C3.2 Drizzi de costas na porta da capela", is_instance_valid(drizzi))
	# 4. o portão não deixa sair (testa antes da luta, depois do encontro)
	if is_instance_valid(drizzi):
		x.por(drizzi.global_position + Vector3(0, 1.5, 6.0))
	ok("C3.2-3 encontro: acusa, come terra, volta monstro", await x.ate_evento(Eventos.CAP3_DRIZZI_ENCONTRO, 180, true))
	await x.ate(func() -> bool: return is_instance_valid(cap3.get("_chefe")) and not GlobalEvents.in_cutscene, 60)
	await x.esperar(2.0)
	objetivo("OBJ_CAP3_DRIZZI", "na luta")
	var portao: Vector3 = const_de(cap3, "PORTAO")
	x.por(portao + Vector3(0, 0.5, 0))
	await x.esperar(2.0)
	ok("C3.4 o portão não deixa sair na luta", x.cena().contains("cemiterio") and not Eventos.feito(Eventos.CAP3_CONCLUIDO))
	var chefe = cap3.get("_chefe")
	ok("Drizzi monstro existe", is_instance_valid(chefe))
	if is_instance_valid(chefe):
		x.por(chefe.global_position + Vector3(0, 1.5, 8.0))
		await x.esperar(0.5)
		ok("C3.4 o amuleto a leva à arena e ela cai", await x.lutar_na_arena([chefe], 150))
	ok("C3.5 a verdade nos braços do Maycow", await x.ate_evento(Eventos.CAP3_DRIZZI_DERROTADA, 180, true))
	await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 60)
	objetivo("OBJ_CAP3_PULPITO", "depois da verdade")
	var pulpito = await x.ate(func() -> bool: return cem.get_node_or_null("pulpito") != null, 20)
	ok("C3.6 púlpito sobe da terra no pentagrama", pulpito)
	await x.esperar(4.0)
	var pul := cem.get_node_or_null("pulpito")
	if pul:
		x.por(pul.global_position + Vector3(0, 1.5, 2.2))
		await x.esperar(0.5)
		ok("toca a chama vermelha", x.pegar(pul))
	ok("C3.6 Cogblade Cut", await x.ate_evento(Eventos.CAP3_PODER_CUT, 40))
	ok("poder Cut liberado", Eventos.poder_liberado(Eventos.PODER_CUT))
	await x.fechar_tela_quando_vier(12.0)
	objetivo("OBJ_CAP3_RED_VALVE_ESCOLA", "depois do poder")
	await x.esperar(2.0)
	x.por(portao + Vector3(0, 0.5, 0))
	ok("C3.7 sai pelo portão", await x.ate_cena("stage_1/stage_1.tscn", 60), x.cena())
	ok("Capítulo 3 concluído", Eventos.feito(Eventos.CAP3_CONCLUIDO))
	await x.esperar(6.0)
	ok("capítulo 4", Eventos.capitulo_atual() == 4)
	ok("volta pela floresta (no cemiterio_local)", x.jogador() and x.jogador().global_position.distance_to(get_tree().current_scene.get_node("locais_importantes/cemiterio_local").global_position) < 40.0)
	x.log_("  " + x.estado())


# ==============================================================================
# CAPÍTULO 4 — ALÉM DA VIDA
# ==============================================================================

func etapa_cap4() -> void:
	await carregar_save()
	ok("capítulo 4", Eventos.capitulo_atual() == 4)
	objetivo("OBJ_CAP3_RED_VALVE_ESCOLA", "no começo")
	ok("C4.1 floresta não prende mais", not Eventos.floresta_presa())
	ok("C4.1 beira da mata ganha nome no mapa", Eventos.floresta_com_nomes())
	var cidade := get_tree().current_scene
	var f := cidade.get_node_or_null("locais_importantes/floresta_local") as Node3D
	var c := cidade.get_node_or_null("locais_importantes/cemiterio_local") as Node3D
	x.por(f.global_position + Vector3(0, 2.0, 0) + (c.global_position - f.global_position).normalized() * 9.0)
	await x.esperar(6.0)
	var j = x.jogador()
	ok("C4.1 a beira da mata leva de volta à cidade",
		j.global_position.distance_to(f.global_position) > 12.0, str(j.global_position))
	checar_locais({"escola": true, "casa_nice": false, "oficina": false}, "cap. 4")
	# 2. a red valve da escola
	ok("C4.2 volta à escola", await entrar("escola", "escola/escola.tscn"), x.cena())
	await x.esperar(3.0)
	ok("escola escura", not Eventos.escola_clara())
	get_tree().current_scene.call("usar_buraco", "buraco_entrada")
	ok("desce ao calabouço", await x.ate_cena("porao", 40))
	await x.esperar(3.0)
	var rv = get_tree().current_scene.get_node_or_null("red_valve")
	ok("red valve com prompt", rv and bool(rv.get("com_prompt")))
	if rv:
		x.por(rv.global_position + rv.global_basis.z * 1.5 + Vector3.UP)
		await x.esperar(0.5)
		await x.apertar("ui_accept")
	ok("C4.2 atravessa até o inferno 4", await x.ate_cena("inferno_4", 60), x.cena())
	await x.esperar(4.0)
	var inf4 := get_tree().current_scene
	ok("sem chama roxa repetida no altar", inf4.get_node_or_null("aura_no_altar") == null)
	ok("sem gárgula do limite no cap. 4", not bool(inf4.get("_fim_trancado")))
	ok("C4.2 portal do fim → inferno 3",
		await pagar_e_entrar(inf4.get("_portal_saida"), Eventos.CAP4_PORTAL_INFERNO_4, "inferno_3"), x.cena())
	await x.esperar(4.0)
	var inf3 := get_tree().current_scene
	objetivo("OBJ_CAP4_INFERNO_3", "no inferno 3")
	var ent = inf3.get("_portal_entrada")
	ok("C4.2 portal do começo do inferno 3 volta ao inferno 4", ent and String(ent.get("destino")).contains("inferno_4"), str(ent.get("destino")) if ent else "")
	var pul := inf3.get_node_or_null("pulpito_slain")
	ok("púlpito da chama branca no começo do inferno 3", pul != null)
	if pul:
		x.por(pul.global_position + Vector3(0, 1.5, 2.2))
		await x.esperar(0.5)
		x.pegar(pul)
		ok("Cogblade Slain", await x.ate_evento(Eventos.CAP4_PODER_SLAIN, 40))
		await x.fechar_tela_quando_vier(12.0)
	# 3. a catedral
	ok("C4.3 portal da catedral → arena 2",
		await pagar_e_entrar(inf3.get("_portal_saida"), Eventos.CAP4_PORTAL_INFERNO_3, "battlefield_2"), x.cena())
	# 4. a arena 2
	await x.esperar(6.0)
	ok("C4.4 Maycow parasita na arena", not GlobalEvents.is_maycow_normal)
	var t0 := Time.get_ticks_msec()
	while x.cena().contains("battlefield_2") and not GlobalEvents.in_cutscene and Time.get_ticks_msec() - t0 < 60000:
		await x.esperar(1.0)
		var p = x.jogador()
		if p:
			p.set("current_health", 100)
		x.matar_inimigos()
	ok("C4.4 vence (2 zumbis e 1 Husk)", GlobalEvents.in_cutscene or Eventos.feito(Eventos.CAP4_ARENA_2))
	# 5-6. o fogo e o pentagrama
	ok("C4.5 queima com o amuleto e acorda na igreja", await x.ate_cena("igreja_interior", 120, true), x.cena())
	ok("arena 2 concluída", Eventos.feito(Eventos.CAP4_ARENA_2))
	ok("C4.6 o despertar no pentagrama", await x.ate_evento(Eventos.CAP4_CONCLUIDO, 120, true))
	await x.ate(func() -> bool: return not GlobalEvents.in_cutscene, 60)
	await x.esperar(3.0)
	ok("capítulo 5", Eventos.capitulo_atual() == 5)
	ok("Maycow normal", GlobalEvents.is_maycow_normal)
	x.log_("  " + x.estado())


# ==============================================================================
# CAPÍTULO 5 — O PASTOR
# ==============================================================================

func etapa_cap5() -> void:
	await carregar_save()
	ok("capítulo 5", Eventos.capitulo_atual() == 5)
	ok("começa na igreja", x.cena().contains("igreja_interior"), x.cena())
	var p = x.jogador()
	var hp_max := int(p.get("max_health"))
	# 1. sem forças
	ok("C5.1 sem forças na igreja", Eventos.sem_forcas_na_igreja())
	x.log_("  sangue %s/%s  magia %.1f/%.1f  rusks %d" % [p.get("current_health"), hp_max,
		SaveManager.current_mp, SaveManager.max_mp, SaveManager.iron_rusks])
	ok("C5.1 ~10%% do sangue", int(p.get("current_health")) <= int(ceil(hp_max * 0.12)), str(p.get("current_health")))
	ok("C5.1 ~10%% da magia", SaveManager.current_mp <= SaveManager.max_mp * 0.12, str(SaveManager.current_mp))
	ok("C5.1 nenhum iron rusk", SaveManager.iron_rusks == 0, str(SaveManager.iron_rusks))
	ok("C5.1 nada diz o que fazer", Eventos.objetivo_atual() == "")
	ok("C5.1 não corre (estamina presa)", p.has_method("_sem_forcas") and bool(p.call("_sem_forcas")))
	var hp_igreja := int(p.get("current_health"))
	var igreja := get_tree().current_scene
	igreja.call("_sair_da_igreja")
	ok("sai da igreja", await x.ate_cena("stage_1/stage_1.tscn", 40), x.cena())
	await x.esperar(4.0)
	ok("saiu da igreja (evento)", Eventos.feito(Eventos.CAP5_SAIU_IGREJA))
	p = x.jogador()
	ok("C5.2 o sangue continua como estava", int(p.get("current_health")) == hp_igreja,
		"%s → %s" % [hp_igreja, p.get("current_health")])
	ok("C5.2 estamina volta ao normal", not bool(p.call("_sem_forcas")))
	objetivo("OBJ_CAP5_OFICINA", "na cidade")
	checar_locais({"oficina": true, "casa_nice": false}, "cap. 5")
	# 2. a oficina
	ok("C5.2 entra na oficina", await entrar("oficina", "oficina_jimmy", 40), x.cena())
	await x.esperar(4.0)
	var of := get_tree().current_scene
	var c5 = no_com_script(of, "capitulo_5_oficina.gd")
	ok("oficina do capítulo 5", c5 != null)
	var porta = c5.get("porta") if c5 else null
	ok("red valve atrás do armário", porta != null)
	if porta:
		x.por(porta.global_position + porta.global_basis.z * 1.5 + Vector3.UP)
	ok("C5.2 a red valve chama na 1ª vez", await x.ate_evento(Eventos.CAP5_RED_VALVE_OFICINA, 40))
	ok("C5.2 leva ao inferno 1", await x.ate_cena("inferno/inferno.tscn", 60), x.cena())
	await x.esperar(4.0)
	var inf1 := get_tree().current_scene
	var ent = inf1.get("_portal_entrada")
	ok("C5.2 portal do começo do inferno 1 → oficina", ent and String(ent.get("destino")).contains("oficina"), str(ent.get("destino")) if ent else "")
	ok("portal do começo só com prompt", ent and bool(ent.get("com_prompt")))
	objetivo("OBJ_CAP5_OFICINA", "no inferno 1 (o evento)")
	var pul := inf1.get_node_or_null("pulpito_fire_cross")
	ok("púlpito da chama amarela no começo do inferno 1", pul != null)
	if pul:
		x.por(pul.global_position + Vector3(0, 1.5, 2.2))
		await x.esperar(0.5)
		x.pegar(pul)
		ok("Cogblade Fire Cross", await x.ate_evento(Eventos.CAP5_PODER_FIRE_CROSS, 40))
		await x.fechar_tela_quando_vier(12.0)
	# 3. os portais selados
	ok("C5.3 portal do fim do inferno 1 → inferno 2",
		await pagar_e_entrar(inf1.get("_portal_saida"), Eventos.CAP5_PORTAL_INFERNO_1, "inferno_2"), x.cena())
	await x.esperar(4.0)
	objetivo("OBJ_CAP5_ARENA_3", "no inferno 2 (o evento)")
	var inf2 := get_tree().current_scene
	ok("C5.3 portal do fim do inferno 2 → arena 3",
		await pagar_e_entrar(inf2.get("_portal_saida"), Eventos.CAP5_PORTAL_INFERNO_2, "battlefield_3"), x.cena())
	# 4. a arena 3
	await x.esperar(6.0)
	var ar := get_tree().current_scene
	ok("C5.4 Jimmy na jaula no alto do pilar", is_instance_valid(ar.get("jaula")))
	var t0 := Time.get_ticks_msec()
	while x.cena().contains("battlefield_3") and not GlobalEvents.in_cutscene and Time.get_ticks_msec() - t0 < 60000:
		await x.esperar(1.0)
		var pp = x.jogador()
		if pp:
			pp.set("current_health", 100)
		x.matar_inimigos()
	# 5. o resgate
	ok("C5.5 o resgate e a volta pela oficina", await x.ate_cena("oficina_jimmy", 180, true), x.cena())
	ok("Jimmy resgatado", Eventos.feito(Eventos.CAP5_JIMMY_RESGATADO))
	# 6. a conversa
	ok("C5.6 a conversa na oficina", await x.ate_evento(Eventos.CAP5_CONVERSA_OFICINA, 240, true))
	ok("C5.6 calçada da oficina com o Jimmy", await x.ate_cena("stage_1/stage_1.tscn", 60), x.cena())
	await x.esperar(6.0)
	# 7. pela cidade
	ok("C5.7 levando o Jimmy", Eventos.levando_jimmy())
	objetivo("OBJ_CAP5_HOSPITAL", "na cidade")
	checar_locais({"casa_maycow": false, "casa_jimmy": false, "escola": false, "igreja": false,
		"hospital": true, "casa_nice": false, "oficina": false}, "levando o Jimmy")
	for l in ["casa_jimmy", "igreja", "escola", "oficina"]:
		ok("porta '%s' diz 'Preciso ir ao hospital'" % l, Eventos.aviso_local_fechado(l) == "AVISO_CAP5_HOSPITAL")
	ok("C5.7 o amuleto não responde (cidade de gente)", SaveManager.realidade_normal())
	var cidade := get_tree().current_scene
	ok("sem inimigos na cidade", cidade.get_node_or_null("enemies") == null)
	var jimmy = cidade.find_child("*immy*", true, false)
	ok("o Jimmy segue o Maycow", jimmy != null, str(jimmy.name) if jimmy else "")
	# 8. o hospital
	ok("C5.8 entra no hospital", await entrar("hospital", "hospital/hospital.tscn", 40), x.cena())
	await x.esperar(5.0)
	var hosp := get_tree().current_scene
	var c5h = no_com_script(hosp, "capitulo_5_hospital.gd")
	ok("hospital do reencontro (claro)", c5h != null)
	objetivo("OBJ_CAP5_HOSPITAL", "no hospital (o evento)")
	var pc := hosp.get_node_or_null("portas/p_cirurgia2")
	ok("porta da cirurgia", pc != null)
	if pc:
		x.por(pc.global_position + Vector3(0, 1.05, 0) + pc.global_basis.z * 1.2)
		await x.esperar(0.3)
		pc.call("abrir_por", x.jogador())
	# 9. o reencontro
	ok("C5.9 o reencontro e os créditos", await x.ate_evento(Eventos.CAP5_FIM, 240, false))
	ok("créditos levam ao menu", await x.ate_cena("main_menu", 300, true), x.cena())
	x.log_("  " + x.estado())


## Só a gaveta do quarto do Jimmy (confirma as balas).
func etapa_gaveta() -> void:
	await carregar_save()
	await x.ir("res://scenes/stages/jimmy_house/casa_jimmy_interior.tscn")
	await x.esperar(2.0)
	var casa := get_tree().current_scene
	var gaveta := no_com_script(casa, "gaveta_pistola.gd")
	ok("gaveta", gaveta != null)
	x.log_("  antes: pistol=%d ammo=%d" % [SaveManager.get_item_amount("pistol"), SaveManager.get_item_amount("pistol_ammo")])
	await abrir_gaveta(gaveta, ["pistol", "pistol_ammo"])
	await x.esperar(2.0)
	x.log_("  depois: pistol=%d ammo=%d" % [SaveManager.get_item_amount("pistol"), SaveManager.get_item_amount("pistol_ammo")])
	x.log_("  pickups: " + str(SaveManager.pickups_pegos))
	ok("balas da pistola", SaveManager.get_item_amount("pistol_ammo") > 0)


## Carrega o save já acordado na igreja (começo do Cap. 5) e olha o sangue.
func etapa_sangue() -> void:
	await carregar_save()
	var j = x.jogador()
	ok("sem forças na igreja", Eventos.sem_forcas_na_igreja(), x.cena())
	ok("sangue em ~10%", j != null and int(j.get("current_health")) <= 15,
		"%s/%s" % [j.get("current_health"), j.get("max_health")] if j else "sem player")
