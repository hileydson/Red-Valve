extends Node

## O evento da Dona Nice dentro da igreja: a cutscene da primeira entrada, as
## duas fases da luta, a morte dela, o Jonny esperando e a saida carregando
## ele pro hospital.
##
## Quem cria este no' e' o `igreja_interior.gd`. Tudo o que se ve' (atores,
## camera, luz, som) mora em `scenes/stages/igreja/cena_dona_nice.tscn`,
## editavel no AnimationPlayer `diretor`; aqui fica so' a ORDEM das coisas e a
## gameplay entre elas.
##
## Onde o evento esta' fica no save (`SaveManager.evento_dona_nice`):
##   0 -> roda a chegada          1 -> luta, fase 1
##   2 -> luta, fase 2            3 -> ela morreu, o Jonny espera no chao
##   4/5 -> o Jonny ja' foi levado: a igreja fica so' com o que sobrou
## Morrer na luta volta pro CHECKPOINT, que e' gravado no comeco de cada fase
## — o jogador recomeca a fase em que estava, sem rever a cutscene.

signal luta_comecou
signal luta_acabou

const CENA := "res://scenes/stages/igreja/cena_dona_nice.tscn"
const CENA_BOSS_1 := "res://scenes/enemies/dona_nice/boss_dona_nice.tscn"
const CENA_BOSS_2 := "res://scenes/enemies/dona_nice/boss_dona_nice_fase_2.tscn"
const CENA_MUNICAO := "res://scenes/stages/igreja/municao_igreja.tscn"
const CENA_MAPA := "res://scenes/stages/stage_1/stage_1.tscn"
const CENA_HOSPITAL := "res://scenes/stages/hospital/hospital.tscn"

## As tochas da galeria apagam enquanto o evento existir: as fatias do meio da
## nave ja' estao no teto de 8 omni por malha, e a luz das velas do ritual e o
## clarao dos tiros precisam de vaga (ver o gerador da igreja).
const TOCHAS_DA_GALERIA := ["tocha_6", "tocha_7", "tocha_8"]
## A rebote_rombo cede o lugar pro pulso vermelho da transformacao.
const LUZ_DO_PULSO := "rebote_rombo"

## Onde o Maycow fica quando ganha o controle (o duble para aqui na cutscene).
const POS_MAYCOW := Vector3(0.0, 1.05, 4.2)
## Caixas de municao no chao da nave, junto aos bancos.
const MUNICAO := [Vector3(1.55, 0.0, 7.6), Vector3(-1.55, 0.0, 11.8),
	Vector3(1.55, 0.0, 23.8), Vector3(-1.55, 0.0, 27.4), Vector3(0.7, 0.0, 30.5)]
## Segurar este tempo o botao de confirmar pula a cutscene.
const SEGURAR_PRA_PULAR := 1.2
## Raio em volta do Jonny em que aparece o "Levar Jonny ao hospital".
const RAIO_DO_JONNY := 1.9

var igreja: Node3D
var cena: Node3D
var boss: Node3D
var _municoes: Array[Node] = []
var _em_cutscene := false
var _segurando := 0.0
var _jonny_esperando := false
var _perto_do_jonny := false
var _levando := false


func _ready() -> void:
	igreja = get_parent()
	cena = load(CENA).instantiate()
	igreja.add_child.call_deferred(cena)
	await get_tree().process_frame
	await get_tree().process_frame
	_apagar_tochas()
	match SaveManager.evento_dona_nice:
		0:
			_chegada()
		1:
			_luta_1(true)
		2:
			_luta_2(true)
		3:
			_jonny_no_chao()
		_:
			_o_que_sobrou()


func luta_em_andamento() -> bool:
	return is_instance_valid(boss) and not boss.dead


# ==============================================================================
# CONTROLE DO JOGADOR
# ==============================================================================
func _jogador() -> CharacterBody3D:
	return igreja.get_node_or_null("Player") as CharacterBody3D


func _travar(travar: bool) -> void:
	var p := _jogador()
	_em_cutscene = travar
	GlobalEvents.in_cutscene = travar
	if p == null:
		return
	p.cutscene_set_hud_enabled(not travar)
	p.cutscene_set_player_control(not travar)
	p.cutscene_set_camera_current(not travar)
	p.cutscene_set_model_hidden(travar)
	if travar:
		p.velocity = Vector3.ZERO


func _por_maycow_na_porta() -> void:
	var p := _jogador()
	if p == null:
		return
	p.global_position = POS_MAYCOW
	p.rotation.y = PI          # olhando pro altar (+Z), como o duble termina
	p.velocity = Vector3.ZERO


## Ele saca a arma no fim da chegada: no jogo ela tem de estar na mao. Quem
## chega aqui sem a pistola (save antigo, depuracao) ganha a arma e um pente —
## a logica da chave da igreja vai garantir isso antes, no roteiro.
func _armar() -> void:
	if not SaveManager.tem_item("pistol"):
		SaveManager.add_item("pistol", 1)
		SaveManager.add_item("pistol_ammo", 24)
	if not SaveManager.is_equipped("pistol"):
		SaveManager.equip_item("pistol")
	var p := _jogador()
	if p:
		if p.has_method("update_equipment_visuals"):
			p.update_equipment_visuals()
		if p.has_method("update_ammo_ui"):
			p.update_ammo_ui()


func _process(delta: float) -> void:
	if _em_cutscene and is_instance_valid(cena) and cena.diretor.is_playing():
		if Input.is_action_pressed("ui_accept"):
			_segurando += delta
			if _segurando >= SEGURAR_PRA_PULAR:
				_segurando = -999.0
				cena.pular()
		else:
			_segurando = 0.0
	if _jonny_esperando and not _levando and not GlobalEvents.in_cutscene:
		_checar_jonny()


# ==============================================================================
# 0 — A CHEGADA
# ==============================================================================
func _chegada() -> void:
	_travar(true)
	_por_maycow_na_porta()
	cena.tocar(&"chegada")
	await cena.terminou
	_luta_1(false)


# ==============================================================================
# 1 — A FASE 1
# ==============================================================================
func _luta_1(recomeco: bool) -> void:
	SaveManager.evento_dona_nice = 1
	_esconder_atores(["DonaNice", "Maycow", "Monstro"])
	boss = load(CENA_BOSS_1).instantiate()
	igreja.add_child(boss)
	var molde := cena.get_node("atores/Monstro") as Node3D
	boss.global_transform = molde.global_transform
	boss.morreu.connect(_fim_da_fase_1)
	_armar()
	if recomeco:
		_travar(false)
		_por_maycow_na_porta()
		boss.visual.tocar(&"rugido", 0.0)
		cena.get_node("sons/rugido").play()
		await get_tree().create_timer(2.6).timeout
	else:
		cena.encerrar_lente()
		_travar(false)
	GlobalUtils.hide_center_message("interacao_igreja")
	# checkpoint: morrer daqui pra frente recomeca ESTA fase
	SaveManager.save_game()
	_espalhar_municao()
	luta_comecou.emit()
	boss.comecar()


func _fim_da_fase_1() -> void:
	# camera lenta no golpe final, e a cena da transformacao
	GlobalUtils.ativar_camera_lenta(0.3, 0.8, false)
	await get_tree().create_timer(0.9, true, false, true).timeout
	_travar(true)
	var palco := cena.get_node("palco_fase_2") as Node3D
	palco.global_position = Vector3(boss.global_position.x, 0.0, boss.global_position.z)
	palco.rotation.y = boss.rotation.y
	boss.queue_free()
	cena.tocar(&"vira_fase_2")
	await cena.terminou
	_luta_2(false)


# ==============================================================================
# 2 — A FASE 2
# ==============================================================================
func _luta_2(recomeco: bool) -> void:
	SaveManager.evento_dona_nice = 2
	_esconder_atores(["DonaNice", "Maycow", "Monstro"])
	var palco := cena.get_node("palco_fase_2") as Node3D
	var gigante := palco.get_node("Gigante") as Node3D
	gigante.visible = false
	boss = load(CENA_BOSS_2).instantiate()
	igreja.add_child(boss)
	if recomeco:
		boss.global_position = Vector3(0.0, 0.0, 17.0)
		boss.rotation.y = PI
		_travar(false)
		_por_maycow_na_porta()
	else:
		boss.global_transform = gigante.global_transform
		cena.encerrar_lente()
		_travar(false)
	boss.morreu.connect(_fim_da_fase_2)
	_armar()
	SaveManager.save_game()
	_espalhar_municao()
	boss.comecar()


func _fim_da_fase_2() -> void:
	GlobalUtils.ativar_camera_lenta(0.3, 0.8, false)
	await get_tree().create_timer(0.9, true, false, true).timeout
	_travar(true)
	_limpar_municao()
	if boss.has_method("limpar_gosma"):
		boss.limpar_gosma()
	boss.queue_free()
	cena.tocar(&"morte_final")
	await cena.terminou
	SaveManager.evento_dona_nice = 3
	SaveManager.save_game()
	luta_acabou.emit()
	cena.encerrar_lente()
	_travar(false)
	_jonny_no_chao()


# ==============================================================================
# 3 — O JONNY NO CHAO
# ==============================================================================
func _jonny_no_chao() -> void:
	SaveManager.evento_dona_nice = 3
	_esconder_atores(["DonaNice", "Maycow"])
	cena.mostrar_corpo_da_monstro()
	_jonny_esperando = true


func _checar_jonny() -> void:
	var p := _jogador()
	var jonny := cena.get_node_or_null("atores/Jonny") as Node3D
	if p == null or jonny == null:
		return
	var perto := p.global_position.distance_to(jonny.global_position) < RAIO_DO_JONNY + 1.0
	if perto != _perto_do_jonny:
		_perto_do_jonny = perto
		if perto:
			GlobalUtils.show_center_message("levar_jonny", tr("PROMPT_CARRY_JONNY"), 18)
		else:
			GlobalUtils.hide_center_message("levar_jonny")
	if perto and Input.is_action_just_pressed("ui_accept"):
		_levar_jonny()


func _levar_jonny() -> void:
	_levando = true
	_jonny_esperando = false
	GlobalUtils.hide_center_message("levar_jonny")
	await get_tree().create_timer(0.55).timeout
	_travar(true)
	_esconder_atores([])
	cena.get_node("atores/Maycow").visible = true
	cena.tocar(&"pega_jonny")
	await cena.terminou
	# Daqui ele so' para no hospital. O save ja' aponta pra la': quem fechar o
	# jogo no meio da corrida volta direto com o Jonny no colo.
	SaveManager.evento_dona_nice = 4
	SaveManager.save_game(CENA_HOSPITAL)
	GlobalEvents.corrida_com_jonny = true
	LoadingScreen.load_scene(CENA_MAPA)


# ==============================================================================
# 4/5 — O QUE SOBROU
# ==============================================================================
func _o_que_sobrou() -> void:
	_esconder_atores(["DonaNice", "Maycow", "Jonny"])
	cena.mostrar_corpo_da_monstro()
	cena.apagar_velas()


# ==============================================================================
func _esconder_atores(nomes: Array) -> void:
	for n in nomes:
		var a := cena.get_node_or_null("atores/" + n) as Node3D
		if a:
			a.visible = false


func _apagar_tochas() -> void:
	var luzes := igreja.get_node_or_null("luzes")
	if luzes == null:
		return
	for nome in TOCHAS_DA_GALERIA:
		var l := luzes.get_node_or_null(nome) as Light3D
		if l:
			l.visible = false
	var reb := luzes.get_node_or_null(LUZ_DO_PULSO) as Light3D
	if reb:
		reb.visible = false


func _espalhar_municao() -> void:
	_limpar_municao()
	for p in MUNICAO:
		var m: Node3D = load(CENA_MUNICAO).instantiate()
		igreja.add_child(m)
		m.global_position = p
		m.rotation.y = randf() * TAU
		_municoes.append(m)


func _limpar_municao() -> void:
	for m in _municoes:
		if is_instance_valid(m):
			m.queue_free()
	_municoes.clear()
