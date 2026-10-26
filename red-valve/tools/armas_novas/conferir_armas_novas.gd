extends Node

## Confere, sem abrir o jogo, se a MK3 e a Granola estao inteiras de ponta a
## ponta.
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/armas_novas/conferir_armas_novas.tscn
##
## (CENA, e nao `-s`: quase tudo aqui pergunta ao SaveManager.)
##
## Irmao do `tools/shotgun/conferir_shotgun.gd`, e pelo mesmo motivo: nada do
## que esta' checado aqui QUEBRA quando da' errado. O pente cortado some e a
## recarga mostra uma arma sem pente; a chave de traducao some e o prompt vira
## o nome dela; o clipe de primeira pessoa nao existe e a mao fica parada; o
## item cai fora do EQUIPAMENTO_EXCLUSIVO e duas armas ficam na mao.

const HOSPITAL := "res://scenes/stages/hospital/hospital.tscn"
const CASA_NICE := "res://scenes/stages/nice_house/casa_nice_interior.tscn"
const CLIPES := "res://assets/3d_model/player/hands/maos_fp/armas_fp_clipes.tres"
const MAO_ARMADA := "res://scenes/player/first_person_view/mao_armada.tscn"

const PECAS := [
	"res://assets/3d_model/player/the_negotiator_V2/mk3_fp.tscn",
	"res://assets/3d_model/player/the_negotiator_V2/pente_mk3.tscn",
	"res://assets/3d_model/player/the_negotiator_V4/the_negotiator_V4.glb",
	"res://assets/3d_model/player/the_negotiator_V4/cartridge/the_negotiator_V4_bullet.glb",
	"res://assets/sounds/player/guns/mk3/mk3_tiro.ogg",
	"res://assets/sounds/player/guns/mk3/mk3_pente_sai.ogg",
	"res://assets/sounds/player/guns/mk3/mk3_pente_cai.ogg",
	"res://assets/sounds/player/guns/mk3/mk3_pente_entra.ogg",
	"res://assets/sounds/player/guns/mk3/mk3_ferrolho.ogg",
	"res://assets/sounds/player/guns/granola/granola_disparo.ogg",
	"res://assets/sounds/player/guns/granola/granola_foguete_entra.ogg",
	"res://assets/sounds/player/guns/granola/granola_trava.ogg",
]

const SCRIPTS := [
	"res://scripts/player/player_gun_hold.gd",
	"res://scripts/player/player_mk3_hold.gd",
	"res://scripts/player/player_shotgun_hold.gd",
	"res://scripts/player/player_granola_hold.gd",
	"res://scripts/player/player_combat.gd",
	"res://scripts/player/player_hud.gd",
	"res://scripts/player/maos_fp_armas.gd",
	"res://scripts/effects/foguete_granola.gd",
	"res://scripts/player/player.gd",
	"res://scripts/ui/config_menu.gd",
]

const CHAVES := [
	"ITEM_MK3_NAME", "ITEM_MK3_DESC", "ITEM_MK3_AMMO_NAME", "ITEM_MK3_AMMO_DESC",
	"ITEM_GRANOLA_NAME", "ITEM_GRANOLA_DESC", "ITEM_GRANOLA_AMMO_NAME", "ITEM_GRANOLA_AMMO_DESC",
	"PROMPT_TAKE_MK3", "PROMPT_TAKE_MK3_AMMO", "PICKUP_MK3", "PICKUP_MK3_AMMO",
	"PROMPT_TAKE_GRANOLA", "PROMPT_TAKE_GRANOLA_AMMO", "PICKUP_GRANOLA", "PICKUP_GRANOLA_AMMO",
	"DEBUG_ITEM_MK3", "DEBUG_ITEM_GRANOLA", "DEBUG_ITEM_MK3_AMMO", "DEBUG_ITEM_GRANOLA_AMMO",
	"DEBUG_EVENT_PICKUP_MK3", "DEBUG_EVENT_PICKUP_GRANOLA",
]

const NO_BALCAO := ["mk3_no_balcao", "mk3_municao_no_balcao", "mk3_municao_no_balcao_2",
	"granola_no_balcao", "granola_foguete_no_balcao", "granola_foguete_no_balcao_2",
	"granola_foguete_no_balcao_3"]

var _falhas := 0


func _ready() -> void:
	SaveManager.current_slot = 9
	_as_pecas_carregam()
	_os_itens_existem()
	_os_textos_existem()
	_os_scripts_carregam()
	_os_pickups_estao_no_lugar()
	_a_primeira_pessoa_tem_tudo()
	await _o_ciclo_da_mk3()
	await _o_ciclo_da_granola()
	await _a_explosao_machuca()
	print("")
	if _falhas == 0:
		print("== tudo certo ==")
	else:
		print("== %d PROBLEMA(S) ==" % _falhas)
	get_tree().quit(_falhas)


func _ok(condicao: bool, texto: String) -> void:
	print(("  ok   " if condicao else "  FALHA ") + texto)
	if not condicao:
		_falhas += 1


func _as_pecas_carregam() -> void:
	print("-- as pecas --")
	for caminho in PECAS:
		_ok(ResourceLoader.exists(caminho) and load(caminho) != null, caminho)
	var mk3: Node = load(PECAS[0]).instantiate()
	_ok(mk3.get_node_or_null("Corpo") != null and mk3.get_node_or_null("Pente") != null,
		"a MK3 cortada tem Corpo e Pente")
	mk3.free()


func _os_itens_existem() -> void:
	print("-- o inventario --")
	for id in ["mk3", "mk3_ammo", "granola", "granola_ammo"]:
		_ok(SaveManager.item_db.has(id), "item_db tem '%s'" % id)
		if not SaveManager.item_db.has(id):
			continue
		var info: Dictionary = SaveManager.item_db[id]
		for chave in ["icon_path", "model_path"]:
			var caminho := String(info.get(chave, ""))
			_ok(caminho != "" and ResourceLoader.exists(caminho), "'%s' -> %s existe" % [id, chave])
		_ok(id in SaveManager.ITENS_COMPARTILHADOS, "'%s' vale nos dois inventarios" % id)
	for id in ["mk3", "granola"]:
		_ok(id in SaveManager.EQUIPAMENTO_EXCLUSIVO, "'%s' disputa a mao com as outras armas" % id)
		_ok(id in SaveManager.ARMAS_DE_FOGO, "a arena devolve '%s' como arma" % id)


func _os_textos_existem() -> void:
	print("-- os textos --")
	for chave in CHAVES:
		_ok(tr(chave) != chave, "%s traduzido" % chave)


func _os_scripts_carregam() -> void:
	print("-- os scripts --")
	for caminho in SCRIPTS:
		_ok(load(caminho) != null, caminho)


func _os_pickups_estao_no_lugar() -> void:
	print("-- o balcao do hospital e a casa da Dona Nice --")
	var cena: Node = (load(HOSPITAL) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for nome in NO_BALCAO:
		var no := cena.find_child(nome, true, false)
		_ok(no != null and SaveManager.item_db.has(String(no.get_meta("item", ""))),
			"'%s' no balcao, apontando pra um item que existe" % nome)
	cena.free()
	cena = (load(CASA_NICE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for nome in ["municao_cozinha", "municao_quarto"]:
		var no := cena.find_child(nome, true, false)
		_ok(no != null and String(no.get_meta("item", "")) == "pistol_ammo", "'%s' na casa da Dona Nice" % nome)
	cena.free()


func _a_primeira_pessoa_tem_tudo() -> void:
	print("-- a primeira pessoa (mao_armada) --")
	var lib: AnimationLibrary = load(CLIPES)
	for arma in ["mk3", "granola"]:
		for acao in ["idle", "tiro", "recarga", "sacar", "guardar"]:
			_ok(lib.has_animation("%s_%s" % [arma, acao]), "clipe %s_%s" % [arma, acao])
	var eventos := []
	for nome in ["mk3_recarga", "granola_recarga"]:
		var a := lib.get_animation(nome)
		var t := a.find_track(NodePath("."), Animation.TYPE_METHOD)
		for k in a.track_get_key_count(t):
			eventos.append(String(a.track_get_key_value(t, k)["args"][0]))
	for ev in ["mk3_pente_sai", "mk3_pente", "granola_foguete"]:
		_ok(ev in eventos, "a recarga chama o evento '%s'" % ev)
	var cena: Node = (load(MAO_ARMADA) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for caminho in ["rig/Armas/Mk3/Movimento/Modelo/Pente", "rig/Armas/Mk3/Movimento/BocaDoCano",
			"rig/Armas/Mk3/ControleRecargaEsquerdo/CarregadorNaMao", "rig/Armas/Granola/Movimento/BocaDoCano",
			"rig/Armas/Granola/Movimento/Articulacao/ApoioEsquerdo", "rig/Armas/Granola/Movimento/MunicaoNaArma",
			"rig/AjusteEsquerdo/ControleEsquerdo/FogueteNaMao"]:
		_ok(cena.get_node_or_null(caminho) != null, caminho)
	cena.free()


# ==========================================================================
# OS CICLOS DE VERDADE
# ==========================================================================
const CENA_PLAYER := "res://scenes/player/player.tscn"


func _novo_player(arma: String) -> Node:
	GlobalEvents.is_maycow_normal = true
	SaveManager.add_item(arma, 1)
	SaveManager.add_item(arma + "_ammo", 40)
	SaveManager.equip_item(arma)
	var p: Node = load(CENA_PLAYER).instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	p.set_physics_process(false)
	return p


func _o_ciclo_da_mk3() -> void:
	print("-- o ciclo da MK3 (rajada, recarga) --")
	var p: Node = await _novo_player("mk3")
	var combate: Node = p.get_node("PlayerCombat")
	_ok(p.clip_mk3_ammo == 18, "nasce com o pente cheio (18)")
	p.can_shoot_again = true
	combate.atirar_mk3()
	await get_tree().create_timer(0.5).timeout
	_ok(p.clip_mk3_ammo == 15, "uma rajada gasta 3 (sobrou %d)" % p.clip_mk3_ammo)
	var caixa := SaveManager.get_item_amount("mk3_ammo")
	await get_tree().create_timer(0.2).timeout
	combate.recarregar_mk3()
	await get_tree().process_frame
	_ok(p.is_reloading, "a recarga comeca com o pente pela metade")
	await get_tree().create_timer(combate.MK3_TEMPO_RECARGA + 0.4).timeout
	_ok(not p.is_reloading and p.clip_mk3_ammo == 18, "o pente voltou cheio (tem %d)" % p.clip_mk3_ammo)
	_ok(caixa - SaveManager.get_item_amount("mk3_ammo") == 3, "saiu da caixa so' o que faltava (3)")
	var caido := false
	for no in get_tree().current_scene.get_children():
		if no.name.begins_with("PenteMk3Caido"):
			caido = true
	_ok(caido, "o pente velho caiu no chao")
	p.queue_free()
	pass


func _o_ciclo_da_granola() -> void:
	print("-- o ciclo da Granola (foguete, recarga) --")
	var p: Node = await _novo_player("granola")
	var combate: Node = p.get_node("PlayerCombat")
	_ok(p.clip_granola_ammo == 1, "nasce carregada (1)")
	p.can_shoot_again = true
	combate.atirar_granola()
	await get_tree().process_frame
	_ok(p.clip_granola_ammo == 0, "o tiro gastou o foguete")
	var foguete := false
	for no in get_tree().current_scene.get_children():
		if no.get_script() == load("res://scripts/effects/foguete_granola.gd"):
			foguete = true
	_ok(foguete, "o foguete saiu voando")
	await get_tree().create_timer(1.2).timeout
	var caixa := SaveManager.get_item_amount("granola_ammo")
	combate.recarregar_granola()
	await get_tree().process_frame
	_ok(p.is_reloading, "a recarga comeca")
	await get_tree().create_timer(combate.GRANOLA_TEMPO_RECARGA + 0.4).timeout
	_ok(not p.is_reloading and p.clip_granola_ammo == 1, "um foguete no tubo de novo")
	_ok(caixa - SaveManager.get_item_amount("granola_ammo") == 1, "saiu 1 foguete da caixa")
	var hold = p.get_node_or_null("maycow_lopes_normal/Armature/Skeleton3D/PlayerGranolaHold")
	_ok(hold != null and hold.carregada, "o foguete aparece na boca do cano (3a pessoa)")
	p.queue_free()


## Alvo de mentira: conta o dano que levou.
class Alvo extends Node3D:
	var levou := 0
	func take_damage(n: int) -> void:
		levou += n


func _a_explosao_machuca() -> void:
	print("-- a explosao do foguete --")
	var no_alvo := Alvo.new()
	var perto := Alvo.new()
	var longe := Alvo.new()
	for a in [no_alvo, perto, longe]:
		a.add_to_group("enemies")
		add_child(a)
	no_alvo.global_position = Vector3(0, 0, 0)
	perto.global_position = Vector3(2.0, 0, 0)
	longe.global_position = Vector3(12.0, 0, 0)
	var f = load("res://scripts/effects/foguete_granola.gd").new()
	add_child(f)
	await get_tree().process_frame
	f._explodir(no_alvo, Vector3.UP)
	_ok(no_alvo.levou == f.dano_direto, "o alvo tocado leva o dano cheio (%d)" % no_alvo.levou)
	_ok(perto.levou > 0 and perto.levou < f.dano_area, "quem esta' a 2 m leva parte da area (%d)" % perto.levou)
	_ok(longe.levou == 0, "quem esta' a 12 m nao leva nada")
	for a in [no_alvo, perto, longe]:
		a.queue_free()
