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
