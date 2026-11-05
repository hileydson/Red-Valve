extends Node

## Jogada automática da história (descartável): roda as etapas do HISTORIA.md
## pelo caminho real do jogo e anota o que bate e o que não bate.

const LOG := "/tmp/claude-1000/-home-dev-Documents-Development-Game-Development-Red-Valve-Red-Valve/1118b691-2792-4b66-83a7-435fde40be9a/scratchpad/teste_historia.log"
const SKIP_UI := "res://scripts/ui/skip_cutscene_ui.gd"

var arq: FileAccess
var falhas := 0
var etapa := ""
var _inicio := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inicio = Time.get_ticks_msec()
	if FileAccess.file_exists(LOG):
		arq = FileAccess.open(LOG, FileAccess.READ_WRITE)
		arq.seek_end()
	else:
		arq = FileAccess.open(LOG, FileAccess.WRITE)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--etapa="):
			etapa = a.substr(8)
	_rodar.call_deferred()


func _rodar() -> void:
	var scr = load("res://tools/teste_historia/roteiro.gd")
	if scr == null or not scr.can_instantiate():
		log_("ROTEIRO NÃO COMPILA")
		get_tree().quit(2)
		return
	var roteiro = scr.new()
	roteiro.x = self
	add_child(roteiro)
	log_("==================== ETAPA %s ====================" % etapa)
	var metodo := "etapa_" + etapa
	if roteiro.has_method(metodo):
		await roteiro.call(metodo)
	else:
		log_("ETAPA DESCONHECIDA: " + etapa)
	log_("---- fim da etapa %s: %d falha(s) | %s" % [etapa, falhas, estado()])
	arq.flush()
	get_tree().quit()


# ==============================================================================

func log_(s: String) -> void:
	var t := (Time.get_ticks_msec() - _inicio) / 1000.0
	var linha := "[%6.1f] %s" % [t, s]
	print("HIST ", linha)
	arq.store_line(linha)
	arq.flush()


func ok(nome: String, cond: bool, detalhe: String = "") -> bool:
	if not cond:
		falhas += 1
	log_(("  OK   " if cond else "  FALHA ") + nome + ("" if detalhe == "" else "  — " + detalhe))
	return cond


func nota(s: String) -> void:
	log_("  NOTA " + s)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func quadro() -> void:
	await get_tree().process_frame


func cena() -> String:
	var c := get_tree().current_scene
	return c.scene_file_path if c else ""


## Espera uma condição (Callable -> bool) por até `limite` segundos reais.
func ate(cond: Callable, limite: float, pular := false) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < limite:
		if cond.call():
			return true
		if pular:
			pular_cutscenes()
		await quadro()
	return cond.call()


func ate_cena(parte: String, limite: float, pular := false) -> bool:
	return await ate(func() -> bool: return cena().contains(parte), limite, pular)


func ate_evento(id: String, limite: float, pular := false) -> bool:
	return await ate(func() -> bool: return Eventos.feito(id), limite, pular)


func ir(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)
	await ate(func() -> bool: return cena() == caminho, 60.0)
	await esperar(1.0)


## Emite o `skipped` de toda tela de pular cutscene aberta (é o que segurar o
## botão faz).
func pular_cutscenes() -> int:
	var n := 0
	for no in get_tree().root.find_children("*", "Control", true, false):
		var s = no.get_script()
		if s and s.resource_path == SKIP_UI and not no.get("is_skipping"):
			no.set("is_skipping", true)
			no.skipped.emit()
			n += 1
	return n


func apertar(acao: String) -> void:
	var e := InputEventAction.new()
	e.action = acao
	e.pressed = true
	Input.parse_input_event(e)
	await quadro()
	await quadro()
	var r := InputEventAction.new()
	r.action = acao
	r.pressed = false
	Input.parse_input_event(r)
	await quadro()


func enter() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.physical_keycode = KEY_ENTER
	e.pressed = true
	Input.parse_input_event(e)
	await quadro()
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await quadro()


## Fecha as telas de item/arquivo/leitura que pausam o jogo.
func fechar_telas() -> int:
	var n := 0
	for no in get_tree().root.get_children():
		if no is CanvasLayer and no.has_method("fechar"):
			no.call("fechar")
			n += 1
		elif no is CanvasLayer and no.has_method("_fechar") and no.has_signal("fechado"):
			no.call("_fechar")
			n += 1
	return n


## Espera aparecer uma tela de item/leitura e fecha (até `limite` s).
func fechar_tela_quando_vier(limite := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < limite:
		if fechar_telas() > 0:
			await esperar(0.6)
			fechar_telas()
			return true
		await quadro()
	return false


const SELECIONAVEL := "res://scripts/stages/hospital/item_selecionavel.gd"


## Todo item interativo da cena: [nó do selecionável, raiz, prompt].
func selecionaveis() -> Array:
	var out := []
	for no in get_tree().current_scene.find_children("*", "", true, false):
		var s = no.get_script()
		if s and s.resource_path == SELECIONAVEL:
			out.append(no)
	return out


## "Pega" o item: emite o `pegar` do selecionável que tem `raiz` como objeto,
## ou chama `_pegar` (item de balcão).
func pegar(raiz: Node) -> bool:
	if raiz == null:
		return false
	if raiz.has_method("_pegar") and not raiz.has_signal("pegar"):
		raiz.call("_pegar")
		return true
	for sel in selecionaveis():
		var r = sel.get("_raiz")
		if (r == raiz or raiz.is_ancestor_of(sel) or (r and raiz.is_ancestor_of(r))) and bool(sel.get("disponivel")):
			sel.set("disponivel", false)
			sel.emit_signal("pegar")
			return true
	return false


func jogador() -> Node3D:
	var c := get_tree().current_scene
	if c == null:
		return null
	var p := c.get_node_or_null("Player") as Node3D
	if p == null:
		p = c.find_child("Player", true, false) as Node3D
	if p == null:
		p = c.find_child("player", true, false) as Node3D
	return p


func por(p: Vector3, rot_y = null) -> void:
	var j := jogador()
	if j:
		j.global_position = p
		if rot_y != null:
			j.global_rotation.y = rot_y
		if "velocity" in j:
			j.velocity = Vector3.ZERO


func estado() -> String:
	var feitos: Array = []
	for e in Eventos.CATALOGO:
		if Eventos.feito(String(e["id"])):
			feitos.append(String(e["id"]))
	return "cena=%s cap=%d obj=%s stage=%s ultimo=%s poderes=%s rusks=%d" % [
		cena().get_file(), Eventos.capitulo_atual(), Eventos.objetivo_atual(),
		SaveManager.current_stage.get_file(), feitos.back() if not feitos.is_empty() else "-",
		str(SaveManager.poderes_cogblade), SaveManager.iron_rusks]


func locais() -> String:
	var s := []
	for l in Eventos.LOCAIS:
		s.append("%s:%s" % [l, "A" if Eventos.local_aberto(l) else "f"])
	return " ".join(s)


## Mata todo inimigo da cena atual (vale arena e cena aberta).
func matar_inimigos(base: Node = null) -> int:
	if base == null:
		base = get_tree().current_scene
	var n := 0
	for no in base.find_children("*", "", true, false):
		if no == jogador() or no.is_in_group("player"):
			continue
		if no.has_method("take_damage") and ("dead" in no) and not bool(no.get("dead")):
			if "current_health" in no and int(no.get("current_health")) <= 0:
				continue
			no.call("take_damage", 99999)
			n += 1
	return n


## Leva os inimigos com o amuleto (o que soltar o R2 mirando faz) e vence a
## arena; volta quando a cena de origem reaparecer.
func lutar_na_arena(alvos: Array, limite := 120.0) -> bool:
	var j := jogador()
	var origem := get_tree().current_scene
	j.set("invulnerable", true)
	j.set("current_health", int(j.get("max_health")))
	var lista = j.get("amulet_selected_enemies")
	lista.clear()
	for a in alvos:
		lista.append(a)
	log_("  alvos do amuleto: %d" % lista.size())
	var amu = j.get_node_or_null("PlayerAmulet")
	if amu == null:
		log_("  sem PlayerAmulet")
		return false
	amu.call("_on_amulet_magic_released")
	if not await ate_cena("battlefield", 30.0):
		log_("  a arena não abriu (cena %s)" % cena())
		return false
	log_("  na arena: " + cena())
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < limite:
		await esperar(1.0)
		var c := get_tree().current_scene
		if c == origem or not cena().contains("battlefield"):
			break
		var p := jogador()
		if p and "current_health" in p:
			p.set("current_health", 100)
		matar_inimigos(c)
	await esperar(2.0)
	return get_tree().current_scene == origem
