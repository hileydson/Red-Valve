extends "res://scripts/stages/cenario_aberto.gd"

## ARENA 3 — o Trono do Abismo. A luta do último chefe.
##
## Praça circular de 105 m no topo de uma agulha de rocha, cercada de abismo,
## com o trono no fundo (visível da ponte por onde o jogador chega). O modelo
## sai de `tools/blender/arena_3/gerar_arena_3.py` e a cena de
## `tools/godot/arena_3/gerar_cena_arena_3.py` — luz, prop e navmesh mexidos
## no editor somem na próxima regeração. Este script é só comportamento.
##
## O que a arena faz por conta própria, além do que a base já faz (gárgulas,
## relâmpago, luzes que tremem):
##
##  - CHUVA DE FOGO: de tempos em tempos o vórtice do céu acende, um relâmpago
##    abre a sequência e caem bolas de fogo pela praça. Cada uma avisa onde vai
##    cair (um anel aceso no chão) antes de chegar; quem estiver no raio queima.
##    Parte delas mira PERTO do jogador — a chuva é um terceiro lutador, não
##    enfeite.
##  - REDEMOINHOS de poeira que passeiam pela praça, empurrados pelo vento.
##
## CAPÍTULO 5: quem chega pelo portal do fim do inferno 2
## (`Eventos.luta_arena_3`) luta aqui no lugar do Pastor, que ainda não
## existe: os mesmos dois zumbis e o Husk da arena 2 surgem queimando. No alto
## do pilar partido da esquerda de quem chega, o Jimmy, numa jaula
## (`jaula_do_jimmy.gd`), sacode a grade e grita a luta inteira. Mortos os
## três, a cena do resgate (`cutscene_resgate_jimmy.gd`) e a oficina.

@export_group("Chuva de fogo")
@export var chuva_ativa: bool = true
@export var chuva_espera_min: float = 32.0
@export var chuva_espera_max: float = 64.0
## Bolas por chuva.
@export var chuva_bolas_min: int = 14
@export var chuva_bolas_max: int = 22
## Quanto dura a chuva inteira (as bolas se espalham nesse tempo).
@export var chuva_duracao: float = 5.5
## Fração das bolas que mira perto do jogador.
@export var chuva_mira_jogador: float = 0.35
## Tempo entre o anel acender no chão e a bola chegar. 1,4 s: dá pra sair do
## raio andando rápido (4,8 m/s), não dá pra ignorar.
@export var chuva_aviso: float = 1.4
@export var chuva_raio_dano: float = 3.4
@export var chuva_dano: int = 14

@export_group("Redemoinhos")
@export var redemoinho_velocidade: float = 2.6
@export var redemoinho_raio_max: float = 40.0

## De onde vem a chuva: as bolas caem inclinadas a favor do vento.
const VENTO_QUEDA := Vector3(-26.0, 62.0, -12.0)

var _chuva_prazo: float = 0.0
var _chuva_centro: Vector3 = Vector3.ZERO
var _chuva_raio: float = 44.0
var _raiz_chuva: Node3D
var _modelo_meteoro: Node3D
var _modelo_explosao: GPUParticles3D
var _modelo_fogo_chao: GPUParticles3D
var _modelo_aviso: MeshInstance3D
var _modelo_zunido: AudioStreamPlayer3D
var _modelo_estouro: AudioStreamPlayer3D
var _chovendo: bool = false

var _redemoinhos: Array[Dictionary] = []


func _ready() -> void:
	# a gárgula não pode pousar em cima da jaula: o pouso daquele pilar sai
	# antes de a base soltar as gárgulas
	if Eventos.luta_arena_3():
		_tirar_pouso_da_jaula()
	super._ready()


func _preparar() -> void:
	_raiz_chuva = get_node_or_null("chuva_fogo") as Node3D
	if _raiz_chuva:
		_modelo_meteoro = _raiz_chuva.get_node_or_null("meteoro") as Node3D
		_modelo_explosao = _raiz_chuva.get_node_or_null("explosao") as GPUParticles3D
		_modelo_fogo_chao = _raiz_chuva.get_node_or_null("fogo_chao") as GPUParticles3D
		_modelo_aviso = _raiz_chuva.get_node_or_null("aviso") as MeshInstance3D
		_modelo_zunido = _raiz_chuva.get_node_or_null("zunido") as AudioStreamPlayer3D
		_modelo_estouro = _raiz_chuva.get_node_or_null("estouro") as AudioStreamPlayer3D
		for modelo in [_modelo_meteoro, _modelo_explosao, _modelo_fogo_chao, _modelo_aviso]:
			if modelo:
				modelo.visible = false
		if _raiz_chuva.has_meta("centro"):
			_chuva_centro = _raiz_chuva.get_meta("centro")
		if _raiz_chuva.has_meta("raio"):
			_chuva_raio = float(_raiz_chuva.get_meta("raio"))
	# a primeira chuva não cai na chegada: dá tempo de atravessar a ponte e
	# ver o trono antes de o céu abrir
	_chuva_prazo = randf_range(chuva_espera_min * 0.7, chuva_espera_max * 0.7)

	var raiz_red := get_node_or_null("redemoinhos")
	if raiz_red:
		for r in raiz_red.get_children():
			if r is Node3D:
				_redemoinhos.append({"no": r, "alvo": _ponto_redemoinho(), "giro": randf() * TAU})
	if Eventos.luta_arena_3():
		_por_jaula()
		_luta_do_capitulo_5()


func _passo(delta: float) -> void:
	if chuva_ativa and not _chovendo:
		_chuva_prazo -= delta
		if _chuva_prazo <= 0.0:
			_chuva_de_fogo()
	_mover_redemoinhos(delta)


# ==============================================================================
# CHUVA DE FOGO
# ==============================================================================
func _chuva_de_fogo() -> void:
	if _modelo_meteoro == null:
		return
	_chovendo = true
	# o céu avisa primeiro: vórtice acende e um relâmpago forte abre a chuva
	_pulsar_vortice(2.6, 1.4)
	disparar_relampago(1.35)
	await get_tree().create_timer(1.6).timeout

	var bolas := randi_range(chuva_bolas_min, chuva_bolas_max)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for i in bolas:
		if not is_inside_tree():
			return
		var alvo := _sortear_alvo(player)
		_lancar_meteoro(alvo)
		await get_tree().create_timer(chuva_duracao / float(bolas) * randf_range(0.5, 1.5)).timeout

	_pulsar_vortice(1.0, 3.0)
	_chovendo = false
	_chuva_prazo = randf_range(chuva_espera_min, chuva_espera_max)


func _sortear_alvo(player: Node3D) -> Vector3:
	var ponto: Vector3
	if player and randf() < chuva_mira_jogador:
		var a := randf() * TAU
		var r := randf_range(1.5, 7.0)
		ponto = player.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	else:
		var a := randf() * TAU
		var r := _chuva_raio * sqrt(randf())
		ponto = _chuva_centro + Vector3(cos(a) * r, 0.0, sin(a) * r)
	# o chão de verdade: a praça, o patamar do trono ou a escadaria
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 40.0, ponto + Vector3.DOWN * 20.0, LAYER_CHAO)
	var hit := espaco.intersect_ray(q)
	if hit:
		return hit["position"]
	ponto.y = 0.0
	return ponto


func _lancar_meteoro(alvo: Vector3) -> void:
	var aviso := _modelo_aviso.duplicate() as MeshInstance3D
	_raiz_chuva.add_child(aviso)
	aviso.global_position = alvo + Vector3.UP * 0.06
	aviso.visible = true
	aviso.scale = Vector3.ONE * 0.3
	var ta := create_tween()
	ta.tween_property(aviso, "scale", Vector3.ONE, chuva_aviso * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var bola := _modelo_meteoro.duplicate() as Node3D
	_raiz_chuva.add_child(bola)
	var origem := alvo + VENTO_QUEDA * randf_range(0.8, 1.2)
	bola.global_position = origem
	bola.look_at(alvo, Vector3.UP)
	bola.visible = true
	for p in bola.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).emitting = true
	if _modelo_zunido:
		var z := _modelo_zunido.duplicate() as AudioStreamPlayer3D
		bola.add_child(z)
		z.position = Vector3.ZERO
		z.pitch_scale = randf_range(0.85, 1.15)
		z.play()
	var tb := create_tween()
	# acelera caindo: começa devagar lá em cima e chega rápido
	tb.tween_property(bola, "global_position", alvo, chuva_aviso).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tb.tween_callback(_impacto.bind(alvo, bola, aviso))


func _impacto(alvo: Vector3, bola: Node3D, aviso: Node3D) -> void:
	if is_instance_valid(aviso):
		aviso.queue_free()
	if is_instance_valid(bola):
		# o rastro termina de apagar sozinho antes de sumir
		bola.get_node_or_null("bola").visible = false
		for p in bola.find_children("*", "GPUParticles3D", true, false):
			(p as GPUParticles3D).emitting = false
		get_tree().create_timer(1.6).timeout.connect(bola.queue_free)

	if _modelo_explosao:
		var ex := _modelo_explosao.duplicate() as GPUParticles3D
		_raiz_chuva.add_child(ex)
		ex.global_position = alvo + Vector3.UP * 0.3
		ex.visible = true
		ex.restart()
		ex.emitting = true
		get_tree().create_timer(ex.lifetime + 0.8).timeout.connect(ex.queue_free)
	if _modelo_fogo_chao:
		var fogo := _modelo_fogo_chao.duplicate() as GPUParticles3D
		_raiz_chuva.add_child(fogo)
		fogo.global_position = alvo + Vector3.UP * 0.05
		fogo.visible = true
		fogo.emitting = true
		get_tree().create_timer(randf_range(4.0, 6.5)).timeout.connect(func():
			if is_instance_valid(fogo):
				fogo.emitting = false
				get_tree().create_timer(fogo.lifetime + 0.2).timeout.connect(fogo.queue_free))
	if _modelo_estouro:
		var s := _modelo_estouro.duplicate() as AudioStreamPlayer3D
		_raiz_chuva.add_child(s)
		s.global_position = alvo
		s.pitch_scale = randf_range(0.75, 1.1)
		s.play()
		s.finished.connect(s.queue_free)

	# clarão curto. Alcance pequeno de propósito: luz grande entraria na AABB
	# de meia praça e chutaria um braseiro pra fora da cota de 8 por malha.
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.45, 0.15)
	luz.light_energy = 7.0
	luz.omni_range = 8.0
	luz.shadow_enabled = false
	_raiz_chuva.add_child(luz)
	luz.global_position = alvo + Vector3.UP * 1.2
	var tl := create_tween()
	tl.tween_property(luz, "light_energy", 0.0, 0.55)
	tl.tween_callback(luz.queue_free)

	_queimar(alvo)


func _queimar(alvo: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var d := player.global_position.distance_to(alvo)
		if d < chuva_raio_dano and player.has_method("take_damage"):
			player.take_damage(chuva_dano)
		if d < 14.0:
			_tremer_camera(clampf(1.0 - d / 14.0, 0.0, 1.0))
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if inimigo is Node3D and inimigo.has_method("take_damage") \
				and (inimigo as Node3D).global_position.distance_to(alvo) < chuva_raio_dano:
			inimigo.take_damage(chuva_dano)


func _tremer_camera(forca: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or forca <= 0.0:
		return
	var h0 := cam.h_offset
	var v0 := cam.v_offset
	var t := create_tween()
	for k in 5:
		var a := 0.09 * forca * (1.0 - k / 5.0)
		t.tween_property(cam, "h_offset", h0 + randf_range(-a, a), 0.035)
		t.parallel().tween_property(cam, "v_offset", v0 + randf_range(-a, a), 0.035)
	t.tween_property(cam, "h_offset", h0, 0.05)
	t.parallel().tween_property(cam, "v_offset", v0, 0.05)


## O olho do céu acende durante a chuva e volta devagar.
func _pulsar_vortice(alvo_brilho: float, tempo: float) -> void:
	if _ceu_material == null:
		return
	var t := create_tween()
	t.tween_method(func(v): _ceu_material.set_shader_parameter("vortice_brilho", v),
		float(_ceu_material.get_shader_parameter("vortice_brilho")), alvo_brilho, tempo)


# ==============================================================================
# REDEMOINHOS
# ==============================================================================
func _ponto_redemoinho() -> Vector3:
	for _t in 20:
		var a := randf() * TAU
		var r := randf_range(10.0, redemoinho_raio_max)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		# longe do zigurate do trono (ao norte)
		if p.z < -20.0 and absf(p.x) < 24.0:
			continue
		return p
	return Vector3(0, 0, 20)


func _mover_redemoinhos(delta: float) -> void:
	for r in _redemoinhos:
		var no: Node3D = r["no"]
		if not is_instance_valid(no):
			continue
		var alvo: Vector3 = r["alvo"]
		var para := alvo - no.position
		para.y = 0.0
		if para.length() < 2.0:
			r["alvo"] = _ponto_redemoinho()
			continue
		# anda torto, como coisa empurrada pelo vento
		r["giro"] = float(r["giro"]) + delta * 0.7
		var lado := Vector3(-para.z, 0.0, para.x).normalized() * sin(float(r["giro"])) * 0.6
		no.position += (para.normalized() + lado).normalized() * redemoinho_velocidade * delta


# ==============================================================================
# CAPÍTULO 5 — A LUTA NO LUGAR DO PASTOR
#
# O chefe desta arena ainda não foi feito. Até ele existir a luta é a mesma da
# arena 2 no Capítulo 4: dois zumbis e um Husk, que surgem queimando (o
# teleporte da Dona Nice) nos marcadores do nó `enemies`. O jogador nasce na
# ponte (z 84) olhando pro -Z; os marcadores ficam a uns 30 m do meio da praça.
# ==============================================================================
const CENA_ZUMBI := "res://scenes/enemies/zombie_1.tscn"
const CENA_HUSK := "res://scenes/enemies/the_cobalt_husker.tscn"
const CENA_OFICINA := "res://scenes/stages/prolog/oficina_jimmy.tscn"
const TELEPORTE := preload("res://scripts/effects/teleporte_dona_nice.gd")
const JaulaDoJimmy := preload("res://scripts/stages/battlefield/jaula_do_jimmy.gd")
const CutsceneResgate := preload("res://scripts/stages/battlefield/cutscene_resgate_jimmy.gd")
## [cena, marcador] de cada um.
const LUTADORES := [[CENA_ZUMBI, "enemy_1"], [CENA_ZUMBI, "enemy_12"], [CENA_HUSK, "enemy_6"]]
## Respiro entre chegar (cuspido pelo portal) e eles surgirem.
const LUTA_ESPERA := 2.4
const LUTA_ALCANCE := 200.0
## O pilar da jaula: o partido da esquerda de quem chega pela ponte (o
## `pilar_10` de `gerar_arena_3.py`) — o centro no chão e a altura onde o
## fuste quebra; o entulho do topo sobe até uns 2 m acima disso.
const PILAR_DA_JAULA := Vector3(-33.71, 16.66, 28.28)
const MALHA_DO_PILAR := "SM_ar3_pilar_10_pedra_esc"
## O capitel da jaula assenta acima do entulho.
const CAPITEL_ACIMA := 2.0

var jaula: Node3D
var _lutadores: Array[Node] = []
var _luta_acabou := false


func _tirar_pouso_da_jaula() -> void:
	var pousos := get_node_or_null("pousos")
	if pousos == null:
		return
	for p in pousos.get_children():
		var m := p as Node3D
		if m and Vector2(m.position.x - PILAR_DA_JAULA.x, m.position.z - PILAR_DA_JAULA.z).length() < 3.0:
			pousos.remove_child(m)
			m.free()


func _por_jaula() -> void:
	jaula = JaulaDoJimmy.new()
	jaula.name = "jaula_do_jimmy"
	add_child(jaula)
	var topo := Vector3(PILAR_DA_JAULA.x, PILAR_DA_JAULA.y + CAPITEL_ACIMA, PILAR_DA_JAULA.z)
	# a porta (o +Z da jaula) olha pro meio da praça
	var para := Vector3(0.0, 0.0, 6.0) - topo
	jaula.global_transform = Transform3D(Basis(Vector3.UP, atan2(para.x, para.z)), topo)
	var malha := find_child(MALHA_DO_PILAR, true, false) as MeshInstance3D
	if malha and malha.mesh:
		jaula.usar_pedra(malha.get_active_material(0))
	# duas chamas das fogueiras da arena nos cantos da frente do capitel: o
	# fogo tremendo lá no alto é o que puxa o olho de quem luta lá embaixo
	var chama := get_node_or_null("fogo/chama_0") as GPUParticles3D
	if chama:
		for lado in [-1.0, 1.0]:
			var c := chama.duplicate() as GPUParticles3D
			jaula.add_child(c)
			c.position = Vector3(lado * 1.45, 0.0, 1.45)
			c.scale = Vector3.ONE * 0.55
			c.emitting = true
	jaula.agitar()


func _luta_do_capitulo_5() -> void:
	await get_tree().create_timer(LUTA_ESPERA, false).timeout
	if not is_inside_tree():
		return
	var raiz := get_node_or_null("enemies")
	if raiz == null:
		push_warning("arena 3: sem o nó `enemies` — cena regerada sem os marcadores?")
		return
	for par in LUTADORES:
		var marca := raiz.get_node_or_null(String(par[1])) as Node3D
		if marca == null:
			continue
		var casca := (load(String(par[0])) as PackedScene).instantiate() as Node3D
		raiz.add_child(casca)
		casca.global_position = marca.global_position + Vector3.UP * 0.3
		casca.global_rotation = marca.global_rotation
		TELEPORTE.criar(self, marca.global_position, 1.0, true)
		# a raiz das cenas de inimigo é uma casca sem script: quem tem `dead`
		# e `died` é o filho "enemy"
		var corpo := _corpo_do_inimigo(casca)
		if corpo == null:
			continue
		if not corpo.is_in_group("enemies"):
			corpo.add_to_group("enemies")
		corpo.set("distance_to_aproach", LUTA_ALCANCE)
		corpo.set("activation_distance", LUTA_ALCANCE)
		corpo.died.connect(_ao_morrer_lutador)
		_lutadores.append(corpo)
		await get_tree().create_timer(0.45, false).timeout


func _corpo_do_inimigo(no: Node) -> Node:
	if "dead" in no and no.has_signal("died"):
		return no
	for filho in no.get_children():
		var c := _corpo_do_inimigo(filho)
		if c:
			return c
	return null


func _ao_morrer_lutador() -> void:
	if _luta_acabou or _lutadores.size() < LUTADORES.size():
		return
	for corpo in _lutadores:
		if is_instance_valid(corpo) and not corpo.dead:
			return
	_luta_acabou = true
	_fim_da_luta()


## O último caiu: câmera lenta no golpe, a tela vai ao preto e o resgate
## começa. No fim dele o save já aponta pra oficina.
func _fim_da_luta() -> void:
	GlobalEvents.in_cutscene = true
	chuva_ativa = false
	var player := get_node_or_null("Player") as CharacterBody3D
	if player:
		player.set("invulnerable", true)
	var barra := get_tree().root.get_node_or_null("GlobalEnemyHealthUI")
	if barra:
		barra.queue_free()
	Engine.time_scale = 0.2
	await get_tree().create_timer(1.6, true, false, true).timeout
	Engine.time_scale = 1.0
	var cena = CutsceneResgate.new()
	cena.name = "cutscene_resgate_jimmy"
	cena.jaula = jaula
	add_child(cena)
	await cena.rodar(self, player)
	# A arena nunca vira checkpoint: o save da volta nasce aqui, já na oficina.
	# Quem chegou sem passar pelo caminho (Debug Travel) fecha o caminho aqui:
	# o resgate depende dele, e o `concluir` recusaria.
	for id in [Eventos.CAP5_SAIU_IGREJA, Eventos.CAP5_RED_VALVE_OFICINA,
			Eventos.CAP5_PORTAL_INFERNO_1, Eventos.CAP5_PORTAL_INFERNO_2]:
		Eventos.concluir(id, false)
	Eventos.concluir(Eventos.CAP5_JIMMY_RESGATADO, false)
	SaveManager.sair_da_arena()
	SaveManager.save_game(CENA_OFICINA)
	GlobalEvents.in_cutscene = false
	LoadingScreen.load_scene(CENA_OFICINA)
