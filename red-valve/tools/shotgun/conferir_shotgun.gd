extends Node

## Confere, sem abrir o jogo, se a cacadeira esta' inteira de ponta a ponta.
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/shotgun/conferir_shotgun.tscn
##
## (tem de ser CENA, e nao `-s script`: com `-s` o Godot nao carrega autoload
## nenhum, e quase tudo aqui pergunta ao SaveManager.)
##
## Irmao do `tools/hospital/testar_navmesh.gd`, e pelo mesmo motivo dele: nada
## do que esta' checado aqui QUEBRA quando da' errado. O .glb carrega sem o no'
## da charneira e a arma simplesmente nunca dobra; a chave de traducao some e o
## prompt vira o proprio nome dela na tela; o item cai fora do
## EQUIPAMENTO_EXCLUSIVO e o jogador anda com amuleto e cacadeira ao mesmo
## tempo, disputando o botao de mira. Tudo isso passa pelo editor calado.

const MODELO := "res://assets/3d_model/player/the_negotiator_V3/the_negotiator_V3_dobravel.glb"
const CARTUCHOS := "res://assets/3d_model/player/the_negotiator_V3/cartridge/the_negotiator_V3_bullet_x2.glb"
const CAPSULA := "res://scenes/effects/capsula_shotgun.tscn"
const HOSPITAL := "res://scenes/stages/hospital/hospital.tscn"

const SCRIPTS := [
	"res://scripts/player/arma_ik.gd",
	"res://scripts/player/player_shotgun_hold.gd",
	"res://scripts/player/player_combat.gd",
	"res://scripts/player/player_hud.gd",
	"res://scripts/player/player.gd",
]

## As chaves de traducao que a arma estreou. Sem elas o jogador le' a CHAVE.
const CHAVES := [
	"ITEM_SHOTGUN_NAME", "ITEM_SHOTGUN_DESC",
	"ITEM_SHOTGUN_AMMO_NAME", "ITEM_SHOTGUN_AMMO_DESC",
	"PROMPT_TAKE_SHOTGUN", "PROMPT_TAKE_SHOTGUN_AMMO",
	"PICKUP_SHOTGUN", "PICKUP_SHOTGUN_AMMO", "PICKUP_SHOTGUN_AMMO_AGAIN",
]

## Os objetos que o gerador do hospital tem de ter posto no balcao.
const NO_BALCAO := [
	"shotgun_no_balcao",
	"shotgun_municao_no_balcao",
	"shotgun_municao_no_balcao_2",
]

var _falhas := 0


func _ready() -> void:
	_o_modelo_dobra()
	_os_itens_existem()
	_os_textos_existem()
	_os_scripts_carregam()
	_o_balcao_tem_tudo()
	await _o_ciclo_funciona()

	print("")
	if _falhas == 0:
		print("== tudo certo ==")
	else:
		print("== %d PROBLEMA(S) ==" % _falhas)
	get_tree().quit(1 if _falhas > 0 else 0)


func _ok(condicao: bool, texto: String) -> void:
	print(("  ok   " if condicao else "  FALHA ") + texto)
	if not condicao:
		_falhas += 1


# ==========================================================================
func _o_modelo_dobra() -> void:
	print("-- o modelo dobravel --")
	var pacote: PackedScene = load(MODELO)
	if pacote == null:
		_ok(false, "o .glb nao carrega (rode tools/blender/shotgun/gerar_shotgun.py)")
		return
	var arma: Node3D = pacote.instantiate()
	add_child(arma)

	var corpo := arma.find_child("corpo", true, false) as Node3D
	var charneira := arma.find_child("charneira", true, false) as Node3D
	_ok(corpo != null, "tem a peca 'corpo' (bascula + coronha)")
	_ok(charneira != null, "tem o vazio 'charneira' (o pino)")
	if charneira == null:
		return
	var canos := charneira.find_child("canos", true, false) as Node3D
	_ok(canos != null, "os 'canos' estao pendurados na charneira")
	if canos == null:
		return

	# O que importa nao e' a hierarquia existir: e' girar a charneira MOVER os
	# canos e NAO mover o corpo. Se o gerador pendurar a peca errada, tudo
	# acima passa e a arma dobra ao contrario.
	# Repare que o teste e' na BASE e nao na posicao: o no' `canos` esta' em
	# cima do proprio pino (local zero), entao a origem dele nao anda quando a
	# charneira gira — so' a orientacao. Quem anda sao os vertices, e e' isso
	# que o teste da boca do cano, logo abaixo, mede.
	var antes: Basis = canos.global_transform.basis
	var corpo_antes: Transform3D = corpo.global_transform if corpo else Transform3D.IDENTITY
	charneira.rotation.z = deg_to_rad(32.0)
	_ok(not canos.global_transform.basis.is_equal_approx(antes),
		"girar a charneira gira os canos")
	if corpo:
		_ok(corpo.global_transform.is_equal_approx(corpo_antes),
			"e NAO mexe no corpo")

	# A boca do cano tem de DESCER quando abre — o contrario e' a arma dobrando
	# pro lado errado, que e' exatamente o erro que nao da' erro.
	var boca_fechada := Vector3(-0.930, -0.010, 0.0)
	charneira.rotation.z = 0.0
	var y_fechada: float = (canos.global_transform * boca_fechada).y
	charneira.rotation.z = deg_to_rad(32.0)
	var y_aberta: float = (canos.global_transform * boca_fechada).y
	_ok(y_aberta < y_fechada - 0.1,
		"a boca do cano DESCE ao abrir (%.3f -> %.3f)" % [y_fechada, y_aberta])

	arma.queue_free()

	var par: PackedScene = load(CARTUCHOS)
	_ok(par != null, "o par de cartuchos do balcao carrega")
	var capsula: PackedScene = load(CAPSULA)
	_ok(capsula != null, "a capsula que cai no chao carrega")


func _os_itens_existem() -> void:
	print("-- o inventario --")
	for id in ["shotgun", "shotgun_ammo"]:
		_ok(SaveManager.item_db.has(id), "item_db tem '%s'" % id)
		if not SaveManager.item_db.has(id):
			continue
		var info: Dictionary = SaveManager.item_db[id]
		for chave in ["icon_path", "model_path"]:
			var caminho := String(info.get(chave, ""))
			_ok(caminho != "" and ResourceLoader.exists(caminho),
				"'%s' -> %s existe (%s)" % [id, chave, caminho])
	_ok("shotgun" in SaveManager.EQUIPAMENTO_EXCLUSIVO,
		"a cacadeira disputa o botao de mira com o amuleto")
	_ok("shotgun" in SaveManager.ARMAS_DE_FOGO,
		"a arena devolve a cacadeira como arma")
	for id in ["shotgun", "shotgun_ammo"]:
		_ok(id in SaveManager.ITENS_COMPARTILHADOS,
			"'%s' vale nos dois inventarios (cidade e arena)" % id)


func _os_textos_existem() -> void:
	print("-- os textos --")
	for chave in CHAVES:
		# `tr` devolve a propria chave quando nao acha a traducao.
		_ok(tr(chave) != chave, "%s traduzido" % chave)


func _os_scripts_carregam() -> void:
	print("-- os scripts --")
	for caminho in SCRIPTS:
		_ok(load(caminho) != null, caminho)


func _o_balcao_tem_tudo() -> void:
	print("-- o balcao do hospital --")
	var pacote: PackedScene = load(HOSPITAL)
	if pacote == null:
		_ok(false, "o hospital nao carrega")
		return
	# `EDIT_STATE_INSTANCE` monta a cena sem rodar `_ready` de ninguem: aqui so'
	# interessa o que o GERADOR escreveu, e nao o que o jogo faz com isso.
	var cena: Node = pacote.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for nome in NO_BALCAO:
		var no := cena.find_child(nome, true, false)
		_ok(no != null, "'%s' esta' na cena" % nome)
		if no == null:
			continue
		_ok(no.has_meta("item") and no.has_meta("prompt"),
			"'%s' tem as metadatas do item_de_balcao" % nome)
		var id_item := String(no.get_meta("item", ""))
		_ok(SaveManager.item_db.has(id_item),
			"'%s' aponta pra um item que existe ('%s')" % [nome, id_item])
	cena.queue_free()


# ==========================================================================
# O CICLO DE VERDADE: dois tiros, recarga, dois tiros de novo
#
# Tudo acima confere que as PECAS existem. Isto confere que elas se encaixam —
# e e' o unico teste daqui que pega a regra que o jogador vai sentir: a arma
# nao aceita recarga com cartucho na agulha.
# ==========================================================================
const CENA_PLAYER := "res://scenes/player/player.tscn"

var _player: Node = null
var _combate: Node = null


func _o_ciclo_funciona() -> void:
	print("-- o ciclo (tiro, tiro, recarga) --")
	GlobalEvents.is_maycow_normal = true
	SaveManager.add_item("shotgun", 1)
	SaveManager.add_item("shotgun_ammo", 4)
	SaveManager.equip_item("shotgun")

	_player = load(CENA_PLAYER).instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_player.set_physics_process(false)

	_combate = _player.get_node_or_null("PlayerCombat")
	if _combate == null:
		_ok(false, "o componente de combate subiu")
		return

	_ok(_player.clip_shotgun_ammo == 2,
		"a arma nasce com 2 tiros (tem %d)" % _player.clip_shotgun_ammo)

	# A recarga com a arma CHEIA tem de ser recusada em silencio.
	_combate.recarregar_shotgun()
	await get_tree().process_frame
	_ok(not _player.is_reloading, "recarregar com a arma cheia nao faz nada")

	_atirar()
	_ok(_player.clip_shotgun_ammo == 1, "depois de um tiro sobra 1")
	# A cadencia trava o segundo tiro; destravar na mao e' o que um jogador
	# fazendo o segundo disparo faz — so' que mais devagar.
	_player.can_shoot_again = true
	_atirar()
	_ok(_player.clip_shotgun_ammo == 0, "depois do segundo tiro sobra 0")

	var municao_antes := SaveManager.get_item_amount("shotgun_ammo")
	_combate.recarregar_shotgun()
	await get_tree().process_frame
	_ok(_player.is_reloading, "com os dois canos vazios, a recarga comeca")

	var hold = _player.get_node_or_null(
		"maycow_lopes_normal/Armature/Skeleton3D/PlayerShotgunHold")
	_ok(hold != null and hold.esta_recarregando(),
		"o componente da arma tambem entrou em recarga")

	# O gesto inteiro, mais uma folga. Roda em tempo real porque e' de `await`
	# em timer que ele e' feito.
	await get_tree().create_timer(_combate.TEMPO_RECARGA_SHOTGUN + 0.4).timeout

	_ok(not _player.is_reloading, "a recarga terminou")
	_ok(_player.clip_shotgun_ammo == 2,
		"a arma voltou com 2 (tem %d)" % _player.clip_shotgun_ammo)
	var gastou := municao_antes - SaveManager.get_item_amount("shotgun_ammo")
	_ok(gastou == 2, "saiu 2 da mochila (saiu %d)" % gastou)

	# Conta pela CENA DE ORIGEM, e nao pelo nome: o Godot renomeia o segundo
	# no' irmao de mesmo nome, e contar por prefixo perdia um dos dois.
	var capsulas := 0
	for no in get_tree().current_scene.get_children():
		if no.scene_file_path == CAPSULA:
			capsulas += 1
	_ok(capsulas == 2, "cairam 2 capsulas no chao (cairam %d)" % capsulas)

	_player.queue_free()


func _atirar() -> void:
	# `atirar_shotgun` e' corrotina (ela espera a cadencia no fim). Chamar sem
	# `await` roda tudo ate' o primeiro `await` dela — que e' depois de gastar a
	# bala, tocar o som e lancar o raio. E' exatamente o que interessa medir.
	_combate.atirar_shotgun()
