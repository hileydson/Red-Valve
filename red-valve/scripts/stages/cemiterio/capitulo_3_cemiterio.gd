extends Node

## O CAPÍTULO 3 NO CEMITÉRIO — a Drizzi Wisny, a luta e o segundo poder da
## cogblade.
##
## Quem cria é o `cemiterio.gd` (no `_preparar`). Antes do Capítulo 3 isto
## não faz nada além de abrir a tela. A etapa vem do `Eventos`:
##
##   1. chegando pela floresta (`GlobalEvents.chegando_ao_cemiterio`) a tela
##      abre DEVAGAR, saindo do preto, e o evento `CAP3_CEMITERIO` conclui;
##   2. a Drizzi (humana) está de costas na porta da capela, no fundo, no meio
##      de muita névoa. Chegando perto dela, a cena da capela
##      (`cutscene_drizzi_encontro.gd`), e no preto do fim ela vira a chefe
##      (`drizzi_monstro.gd`). Daí até ela cair o portão não deixa sair, e o
##      amuleto vale aqui (`SaveManager._no_cemiterio_contra_a_drizzi`) — dá
##      pra levá-la pra arena;
##   3. com 15% ela cai, aqui ou na arena: a cena da verdade
##      (`cutscene_drizzi_verdade.gd`) roda aqui, assim que o cemitério volta;
##   4. no meio da praça, em cima do sigilo, sobe o mesmo púlpito do inferno 4
##      com uma chama VERMELHA: tocá-la é a mesma cena da aura do amuleto, e
##      libera o Cogblade Cut (`CAP3_PODER_CUT`);
##   5. o portão leva de volta à floresta — e o Capítulo 3 acaba
##      (`CAP3_CONCLUIDO`, "CAPÍTULO 4" na chegada).

const AtorDrizzi := preload("res://scripts/npcs/drizzi/ator_drizzi.gd")
const CutsceneEncontro := preload("res://scripts/stages/cemiterio/cutscene_drizzi_encontro.gd")
const CutsceneVerdade := preload("res://scripts/stages/cemiterio/cutscene_drizzi_verdade.gd")
const CutsceneAura := preload("res://scripts/stages/inferno_4/cutscene_aura_amuleto.gd")
const AuraDoAmuleto := preload("res://scripts/systems/aura_do_amuleto.gd")
const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")
const Poeira := preload("res://scripts/effects/poeira_drizzi.gd")

const CENA_CHEFE := "res://scenes/enemies/drizzi/drizzi_monstro.tscn"
const CENA_CIDADE := "res://scenes/stages/stage_1/stage_1.tscn"
const CENA_ITEM_OBTIDO := "res://scenes/ui/item_obtido.tscn"
## O púlpito é o altar de pedra do inferno 4 (`gerar_inferno_3.py`, `chegada`):
## as mesmas três pedras e as duas velas, com os materiais de lá.
const MAT_PEDRA := "res://assets/3d_model/stages/inferno_3/materiais/mat_pedra_clara.tres"
const MAT_VELA := "res://assets/3d_model/stages/inferno_3/materiais/mat_vela.tres"
const MAT_CHAMA := "res://assets/3d_model/stages/cemiterio/materiais/mat_chama.tres"
const SOM_TERRA := "res://assets/sounds/igreja/tapa_chao.ogg"
const SOM_PEDRA := "res://assets/sounds/igreja/rajada_bancos.ogg"

## A Drizzi na escadaria da capela (a fachada fica em z -46; a rampa dos
## degraus vai até z -42,4), de costas pra praça.
const PORTA_CAPELA := Vector3(0.0, 0.0, -44.9)
## A esta distância (no chão) dela, a cena roda.
const PERTO_DELA := 9.0
## O meio da praça: o sigilo de sete pontas do gerador.
const PULPITO := Vector3(0.0, 0.0, 0.0)
## A chama flutua 45 cm acima do tampo (1,12 m), como no inferno 4.
const ALTURA_DA_CHAMA := 1.57
const TAMANHO_DA_CHAMA := 0.16
## O portão (o muro invisível do gerador fica em z 60,9; o jogador nasce em 55).
const PORTAO := Vector3(0.0, 1.5, 59.6)
const PORTAO_AREA := Vector3(9.0, 4.0, 2.6)
## Chegando pela floresta, a tela demora isto pra abrir.
const ABRIR_DEVAGAR := 4.5
## Caiu aqui: a cena espera o tombo acabar.
const ESPERA_DO_TOMBO := 2.4

var cemiterio: Node3D
var player: CharacterBody3D

var _drizzi: Node3D
var _chefe: Node3D
var _em_cena := false
var _final_pendente := false
var _final_espera := 0.0
var _onde_caiu := Transform3D.IDENTITY
var _caiu_aqui := false
var _saindo := false
var _aviso_portao := 0.0
var _selecao: Node
var _chama: Node3D
var _camada: CanvasLayer
var _preto: ColorRect


func iniciar(dono: Node3D) -> void:
	cemiterio = dono
	player = cemiterio.get_node_or_null("Player") as CharacterBody3D
	_montar_tela()
	var chegando := GlobalEvents.chegando_ao_cemiterio
	GlobalEvents.chegando_ao_cemiterio = false
	if chegando:
		_abrir_devagar()
	if Eventos.capitulo_atual() < Eventos.CAPITULO_3:
		set_process(false)
		return
	if Eventos.pode(Eventos.CAP3_CEMITERIO):
		Eventos.concluir(Eventos.CAP3_CEMITERIO)
	_montar_portao()
	# a colisão do cenário só existe depois do primeiro quadro de física
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	if Eventos.pode(Eventos.CAP3_DRIZZI_ENCONTRO):
		_drizzi_na_porta()
	elif Eventos.luta_drizzi():
		_comecar_luta(_marcador_do_chefe(), true)
	elif Eventos.pode(Eventos.CAP3_PODER_CUT):
		_montar_pulpito(false)
	if chegando:
		await get_tree().create_timer(ABRIR_DEVAGAR, false).timeout
	else:
		await get_tree().create_timer(1.5, false).timeout
	_mostrar_objetivo()


func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 95
	add_child(_camada)
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.modulate.a = 0.0
	_camada.add_child(_preto)


func _abrir_devagar() -> void:
	_preto.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_property(_preto, "modulate:a", 0.0, ABRIR_DEVAGAR).set_trans(Tween.TRANS_SINE)


func _mostrar_objetivo() -> void:
	if not is_inside_tree() or GlobalEvents.in_cutscene:
		return
	var chave := Eventos.objetivo_atual()
	if chave != "":
		GlobalUtils.mostrar_objetivo(tr(chave), 30.0)


func _process(delta: float) -> void:
	_aviso_portao = maxf(0.0, _aviso_portao - delta)
	if _em_cena or not is_instance_valid(player) or get_tree().paused:
		return
	if not cemiterio.visible or not GlobalEvents.is_maycow_normal:
		return
	if _final_pendente:
		if GlobalEvents.in_cutscene or player.get("is_playing_return_effect") == true:
			return
		_final_espera -= delta
		if _final_espera <= 0.0:
			_verdade()
		return
	if GlobalEvents.in_cutscene:
		return
	if is_instance_valid(_drizzi) and Eventos.pode(Eventos.CAP3_DRIZZI_ENCONTRO) and player.is_on_floor():
		var d := player.global_position - _drizzi.global_position
		if Vector2(d.x, d.z).length() < PERTO_DELA:
			_encontro()


# ==============================================================================
# A DRIZZI NA PORTA DA CAPELA
# ==============================================================================

func _drizzi_na_porta() -> void:
	var p := PORTA_CAPELA
	p.y = _chao(p)
	# de costas pra praça: a frente dela (+Z) vira pro -Z, a porta
	_drizzi = AtorDrizzi.criar(cemiterio, Transform3D(Basis(Vector3.UP, PI), p))
	_drizzi.call("tocar", &"parada", 0.0)
	_nevoa_em_volta(_drizzi)


## A fumaça do cemitério em volta dela: cópias das partículas da cena — a
## fumaça que sai das covas abertas, subindo dos pés dela, e uma camada fina
## da névoa rasteira. Pouca névoa rasteira: as folhas dela têm 9 m e, juntas
## no mesmo lugar, viram uma bolha branca que a esconde de longe.
func _nevoa_em_volta(alvo: Node3D) -> void:
	var cova := cemiterio.get_node_or_null("ar/fumaca_cova_0") as GPUParticles3D
	if cova:
		for par in [[Vector3(1.2, 0.05, 1.2), 34], [Vector3(2.8, 0.05, 2.8), 30]]:
			var f := cova.duplicate() as GPUParticles3D
			var pm := (cova.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
			pm.emission_box_extents = par[0]
			f.process_material = pm
			f.amount = int(par[1])
			f.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 8, 12))
			alvo.add_child(f)
			f.position = Vector3(0.0, 0.05, 0.0)
	var rasteira := cemiterio.get_node_or_null("ar/segue/nevoa_rasteira") as GPUParticles3D
	if rasteira:
		var n := rasteira.duplicate() as GPUParticles3D
		for g in n.get_groups():
			n.remove_from_group(g)
		var pm2 := (rasteira.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm2.emission_box_extents = Vector3(3.0, 0.3, 3.0)
		pm2.initial_velocity_min = 0.05
		pm2.initial_velocity_max = 0.25
		n.process_material = pm2
		n.amount = 9
		n.lifetime = 12.0
		n.preprocess = 10.0
		n.visibility_aabb = AABB(Vector3(-9, -3, -9), Vector3(18, 8, 18))
		alvo.add_child(n)
		n.position = Vector3(0.0, 0.4, 0.0)


func _encontro() -> void:
	_em_cena = true
	GlobalUtils.esconder_objetivo()
	var c = CutsceneEncontro.new()
	c.name = "cutscene_drizzi_encontro"
	cemiterio.add_child(c)
	c.no_preto.connect(func(onde: Transform3D) -> void:
		# ela vira a chefe ali mesmo, no preto
		Eventos.concluir(Eventos.CAP3_DRIZZI_ENCONTRO)
		_comecar_luta(onde, false))
	c.rodar(cemiterio, player, _drizzi)
	await c.terminou
	_drizzi = null
	_em_cena = false
	if is_instance_valid(_chefe):
		_chefe.call("comecar")
	_mostrar_objetivo()
	_dica_da_arena()


# ==============================================================================
# A LUTA
# ==============================================================================

func _marcador_do_chefe() -> Transform3D:
	var m := cemiterio.get_node_or_null("chefe") as Node3D
	var p := m.global_position if m else Vector3(0.0, 0.0, -10.0)
	p.y = _chao(p)
	var t := Transform3D.IDENTITY
	t.origin = p
	return t


## `voltando` = o save carregou no meio da luta: ela sai do chão e começa.
func _comecar_luta(onde: Transform3D, voltando: bool) -> void:
	_chefe = load(CENA_CHEFE).instantiate() as Node3D
	cemiterio.add_child(_chefe)
	var p := onde.origin
	p.y = _chao(p) + 0.55
	_chefe.global_transform = Transform3D(Basis(Vector3.UP, onde.basis.get_euler().y), p)
	_chefe.connect("derrotada", _ao_derrotar)
	if cemiterio.has_method("acender_sigilo"):
		cemiterio.call("acender_sigilo", 0.6, 3.0)
	if voltando:
		Poeira.estouro(cemiterio, Vector3(p.x, p.y - 0.55, p.z), 1.6)
		await get_tree().create_timer(1.4, false).timeout
		if is_instance_valid(_chefe):
			_chefe.call("comecar")
		_dica_da_arena()


## Uma vez por luta: o céu é aberto, o amuleto a leva pra arena.
func _dica_da_arena() -> void:
	await get_tree().create_timer(6.0, false).timeout
	if not is_inside_tree() or not Eventos.luta_drizzi() or GlobalEvents.in_cutscene:
		return
	GlobalUtils.show_center_message("drizzi_arena",
		tr("AVISO_DRIZZI_ARENA_PAD" if GlobalEvents.usando_controle else "AVISO_DRIZZI_ARENA_KEY"), 18, 5.0)


## Ela caiu com 15% — aqui ou na arena (o sinal chega do mesmo jeito: a
## conexão vai junto com ela). A cena da verdade roda quando o cemitério
## estiver de volta na tela.
func _ao_derrotar(onde: Transform3D) -> void:
	_final_pendente = true
	_onde_caiu = onde
	_caiu_aqui = get_tree().current_scene == cemiterio
	_final_espera = ESPERA_DO_TOMBO if _caiu_aqui else 1.2
	var ui := get_tree().root.get_node_or_null("GlobalEnemyHealthUI")
	if ui and ui.has_method("hide_if_showing") and is_instance_valid(_chefe):
		ui.hide_if_showing(_chefe)


func _verdade() -> void:
	_em_cena = true
	_final_pendente = false
	GlobalUtils.esconder_objetivo()
	var monstro: Node3D = _chefe if _caiu_aqui and is_instance_valid(_chefe) else null
	var c = CutsceneVerdade.new()
	c.name = "cutscene_drizzi_verdade"
	cemiterio.add_child(c)
	c.rodar(cemiterio, player, monstro, _onde_caiu)
	await c.terminou
	if is_instance_valid(_chefe):
		_chefe.queue_free()
	_chefe = null
	_em_cena = false
	if not Eventos.feito(Eventos.CAP3_DRIZZI_DERROTADA):
		# a cena caiu no meio (morte, troca de cena): a luta volta na próxima visita
		return
	if cemiterio.has_method("acender_sigilo"):
		cemiterio.call("acender_sigilo", 0.0, 4.0)
	await get_tree().create_timer(1.2, false).timeout
	_montar_pulpito(true)
	await get_tree().create_timer(3.4, false).timeout
	_mostrar_objetivo()


# ==============================================================================
# O PÚLPITO E A CHAMA VERMELHA
# ==============================================================================

## O altar de pedra do inferno 4 no meio do sigilo, com a chama vermelha.
## `surgindo`: ele sobe da terra (logo depois da cena da verdade).
func _montar_pulpito(surgindo: bool) -> void:
	if get_node_or_null("pulpito") != null or cemiterio.get_node_or_null("pulpito") != null:
		return
	var p := PULPITO
	p.y = _chao(p)
	var pulpito := Node3D.new()
	pulpito.name = "pulpito"
	cemiterio.add_child(pulpito)
	pulpito.global_position = p
	var pedra := load(MAT_PEDRA) as Material
	var vela := load(MAT_VELA) as Material
	# base, coluna e tampo (as três pedras do altar do inferno 4)
	for bloco in [[Vector3(2.2, 0.55, 1.4), -0.025], [Vector3(1.6, 0.75, 0.9), 0.625],
			[Vector3(2.0, 0.12, 1.2), 1.06]]:
		var mi := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = bloco[0]
		caixa.material = pedra
		mi.mesh = caixa
		pulpito.add_child(mi)
		mi.position.y = float(bloco[1])
	for v in [[Vector3(-0.75, 1.12, -0.4), 0.2], [Vector3(0.8, 1.12, 0.35), 0.14]]:
		var mi := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.05
		cil.bottom_radius = 0.05
		cil.height = float(v[1])
		cil.radial_segments = 6
		cil.material = vela
		mi.mesh = cil
		pulpito.add_child(mi)
		mi.position = v[0] + Vector3.UP * float(v[1]) * 0.5
		var fogo := MeshInstance3D.new()
		var ponta := CylinderMesh.new()
		ponta.top_radius = 0.002
		ponta.bottom_radius = 0.02
		ponta.height = 0.06
		ponta.radial_segments = 4
		ponta.material = load(MAT_CHAMA)
		fogo.mesh = ponta
		fogo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pulpito.add_child(fogo)
		fogo.position = v[0] + Vector3.UP * (float(v[1]) + 0.03)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 2
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.2, 1.6, 1.4)
	forma.shape = bx
	corpo.add_child(forma)
	pulpito.add_child(corpo)
	forma.position.y = 0.6
	# a seleção (o mesmo do altar do inferno 4: área folgada, a cápsula para longe)
	var area := Area3D.new()
	area.name = "area"
	area.collision_layer = 0
	area.monitorable = false
	var fa := CollisionShape3D.new()
	var ca := BoxShape3D.new()
	ca.size = Vector3(4.4, 2.6, 4.4)
	fa.shape = ca
	area.add_child(fa)
	pulpito.add_child(area)
	area.position = Vector3(0.0, 0.8, 0.0)
	_selecao = ItemSelecionavel.new()
	pulpito.add_child(_selecao)
	_selecao.configurar(pulpito, area, "PROMPT_TOCAR_CHAMA_VERMELHA")
	_selecao.pegar.connect(_pegar_chama)
	# a chama entra DEPOIS do configurar (os quads não são malha pra contorno)
	_chama = AuraDoAmuleto.chama(TAMANHO_DA_CHAMA, AuraDoAmuleto.VERMELHO, AuraDoAmuleto.ROSADO)
	pulpito.add_child(_chama)
	_chama.position = Vector3.UP * ALTURA_DA_CHAMA
	if not surgindo:
		return
	# sobe da terra, no meio de poeira — e não em cima dele
	_selecao.disponivel = false
	if is_instance_valid(player):
		var d := Vector3(player.global_position.x - p.x, 0.0, player.global_position.z - p.z)
		if d.length() < 2.4:
			d = d.normalized() if d.length() > 0.05 else Vector3.BACK
			player.global_position += d * (3.4 - Vector2(player.global_position.x - p.x,
				player.global_position.z - p.z).length())
	pulpito.position.y -= 1.7
	_chama.visible = false
	Poeira.estouro(cemiterio, p, 1.8)
	var nuvem := Poeira.nuvem(cemiterio, p, 3.0, 2.0, 60)
	_som_em(SOM_PEDRA, 0.6, p)
	_som_em(SOM_TERRA, 0.5, p)
	GlobalUtils.shake_camera(2.4, 0.25)
	var t := create_tween()
	t.tween_property(pulpito, "position:y", pulpito.position.y + 1.7, 2.6).set_trans(Tween.TRANS_SINE)
	await t.finished
	nuvem.call("assentar", 3.0)
	if not is_instance_valid(_chama):
		return
	_chama.visible = true
	_chama.scale = Vector3.ONE * 0.05
	create_tween().tween_property(_chama, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_selecao):
		_selecao.disponivel = true


func _pegar_chama() -> void:
	if not is_instance_valid(player) or not is_instance_valid(_chama):
		return
	var cena = CutsceneAura.new()
	cena.name = "cutscene_chama_vermelha"
	cena.evento = Eventos.CAP3_PODER_CUT
	cena.cor_aura = AuraDoAmuleto.VERMELHO
	cemiterio.add_child(cena)
	cena.rodar(cemiterio, player, _chama)
	await cena.terminou
	if not Eventos.feito(Eventos.CAP3_PODER_CUT):
		# a cena caiu no meio: a chama continua no púlpito, pra pegar de novo
		if is_instance_valid(_selecao):
			_selecao.disponivel = true
		return
	if is_instance_valid(_selecao):
		_selecao.queue_free()
	await get_tree().create_timer(2.0, false).timeout
	_mostrar_poder_novo()
	await get_tree().create_timer(1.0).timeout
	_mostrar_objetivo()


## A tela do poder novo: o amuleto com a aura vermelha e o nome do poder.
func _mostrar_poder_novo() -> void:
	var tela: CanvasLayer = load(CENA_ITEM_OBTIDO).instantiate()
	tela.model_path = AuraDoAmuleto.MODELO_AMULETO
	tela.aura = true
	tela.cor_aura = AuraDoAmuleto.VERMELHO
	tela.texto = tr("PODER_NOVO_COGBLADE")
	tela.destaque = tr(Eventos.rotulo_poder(Eventos.PODER_CUT))
	tela.detalhe = tr("PODER_NOVO_USO_PAD" if GlobalEvents.usando_controle else "PODER_NOVO_USO_KEY")
	get_tree().root.add_child(tela)


# ==============================================================================
# O PORTÃO
# ==============================================================================

func _montar_portao() -> void:
	var area := Area3D.new()
	area.name = "saida_portao"
	area.collision_layer = 0
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = PORTAO_AREA
	forma.shape = caixa
	area.add_child(forma)
	cemiterio.add_child(area)
	area.global_position = PORTAO
	area.body_entered.connect(_ao_chegar_no_portao)


func _ao_chegar_no_portao(corpo: Node3D) -> void:
	if corpo != player or _saindo or _em_cena or GlobalEvents.in_cutscene:
		return
	if not Eventos.feito(Eventos.CAP3_PODER_CUT):
		if _aviso_portao <= 0.0:
			_aviso_portao = 6.0
			GlobalUtils.show_center_message("cemiterio_portao", tr("AVISO_CEMITERIO_PORTAO"), 18, 3.0)
		return
	_sair()


## Pelo portão, de volta à floresta (no `cemiterio_local`). A primeira vez é
## o fim do Capítulo 3: a stage_1 mostra o "CAPÍTULO 4".
func _sair() -> void:
	_saindo = true
	if Eventos.pode(Eventos.CAP3_CONCLUIDO):
		Eventos.concluir(Eventos.CAP3_CONCLUIDO)
		GlobalEvents.entering_chapter_4 = true
	GlobalUtils.esconder_objetivo()
	GlobalEvents.in_cutscene = true
	GlobalEvents.voltando_do_cemiterio = true
	player.velocity = Vector3.ZERO
	var t := create_tween()
	t.tween_property(_preto, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	await t.finished
	LoadingScreen.load_scene(CENA_CIDADE)


# ==============================================================================
# PEÇAS
# ==============================================================================

func _chao(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 20.0, 2)
	if is_instance_valid(player):
		q.exclude = [player.get_rid()]
	var r := cemiterio.get_world_3d().direct_space_state.intersect_ray(q)
	return float(r["position"].y) if r else p.y


func _som_em(caminho: String, tom: float, onde: Vector3) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(caminho)
	s.pitch_scale = tom
	s.max_distance = 80.0
	s.unit_size = 12.0
	cemiterio.add_child(s)
	s.global_position = onde
	s.play()
	s.finished.connect(s.queue_free)
