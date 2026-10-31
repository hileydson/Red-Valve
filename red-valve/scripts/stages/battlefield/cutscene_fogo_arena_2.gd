extends Node

## A CENA DO FOGO NA ARENA 2 (fim do Capítulo 4).
##
## Vencida a luta no lugar do chefe, o Maycow parasita — o da primeira pessoa
## — fica de joelhos no meio do adro, em cima da grelha da Boca, morto de
## cansaço. Depois de uns instantes de respiração pesada as labaredas sobem pela
## grelha e o tomam: em câmera lenta ele agoniza com o amuleto na mão direita,
## o corpo inteiro pegando fogo, e a câmera passeia pelo que queima — o braço,
## o rosto, o peito, os joelhos, as costas — até parar no amuleto, e a tela se
## apaga bem devagar.
##
## O jogador fica escondido (é primeira pessoa: o corpo dele nem é desenhado)
## e quem aparece é um DUBLÊ do parasita (`maycow_lopes.glb`) com os clipes de
## `maycow_parasita_clipes.glb` (gerados por `tools/blender/capitulo_4`). O
## fogo é o do braço do parasita (`parasite_fire.tscn`) espalhado pelos
## membros, com a pele queimando por baixo (`dissolver_corpo.gd`: veias,
## carvão e buracos de brasa).
##
## Quem chama: `battlefield_2.gd`, depois do último inimigo. `rodar` volta com
## a tela no preto; quem troca de cena é a arena.
##
## Os tempos são de RELÓGIO (a câmera lenta não estica a cena): `_relogio`
## soma o delta do jogo dividido pela escala do tempo, e pára com o jogo
## pausado.

const MODELO := "res://assets/3d_model/player/Maycow Lopes/maycow_lopes.glb"
const CLIPES := "res://assets/3d_model/npc/capitulo_4/maycow_parasita_clipes.glb"
const LACOS := ["ajoelhado_ofegante", "agonia_fogo"]
const FOGO := preload("res://scenes/effects/parasite_fire.tscn")
const DissolverCorpo := preload("res://scripts/effects/dissolver_corpo.gd")
const AuraDoAmuleto := preload("res://scripts/systems/aura_do_amuleto.gd")
const SOM_RESPIRACAO := "res://assets/sounds/capitulo_4/respiracao_maycow.ogg"
const SOM_GRITO := "res://assets/sounds/capitulo_4/grito_fogo.ogg"
const SOM_FOGO := "res://assets/sounds/capitulo_4/fogo_rugindo.ogg"
const SOM_ERUPCAO := "res://assets/sounds/capitulo_4/erupcao_fogo.ogg"
const SOM_BATIMENTO := "res://assets/sounds/igreja/batimento_lento.ogg"

## O meio do adro (a grelha da Boca); a altura sai de um raio no chão.
const CENTRO := Vector2(0.0, 0.0)
## O dublê olha pro +Z, pro lado de onde o jogador chegou.
const GIRO := PI
## Onde o jogador fica escondido enquanto a cena roda (o ponto onde ele nasce):
## as mãos de primeira pessoa são filhas da câmera dele e continuariam no
## mundo, no meio da tomada.
const JOGADOR_LONGE := Vector3(0.0, 1.2, 33.0)
## A câmera lenta das labaredas.
const LENTO := 0.3
## O amuleto na palma direita: altura no mundo, e o ponto da pegada a partir
## da origem do osso RightHand, em metros no espaço do osso (o osso cresce pro
## +Y, ao longo dos dedos; medido nos clipes pelo `anim_capitulo_4.py`).
const AMULETO_ALTURA := 0.09
const PALMA := Vector3(0.072, 0.103, 0.057)
## Pontas de cada fogo de membro (do osso de cima ao de baixo) e o raio dele.
const MEMBROS := [["LeftArm", "LeftHand", 0.09], ["RightArm", "RightHand", 0.09],
	["LeftUpLeg", "LeftFoot", 0.12], ["RightUpLeg", "RightFoot", 0.12]]

signal terminou

var arena: Node3D
var player: CharacterBody3D
var ator: Node3D
var modelo: Node3D
var esqueleto: Skeleton3D
var ap: AnimationPlayer
var cam: Camera3D

var _camada: CanvasLayer
var _preto: ColorRect
var _relogio := 0.0
## O plano da câmera agora: {osso, de, ate, mira, fov_de, fov_ate, ini, dur, giro}.
var _plano_atual: Dictionary = {}
var _corpo: RefCounted
var _fogos: Array[Node] = []
var _amuleto: Node3D
## 0..1 do quanto o corpo já queimou (veias, carvão, buracos).
var _queima := 0.0
var _queimando := false
## A Boca: 0 parada, 1 brasa subindo (aviso), 2 cuspindo.
var _boca := 0
var _boca_k := 0.0
var _estouro_em := 0.0
var _sons: Dictionary = {}


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	arena = dono
	player = jogador
	_montar_tela()
	await _fade(1.0, 1.1)
	_travar_jogador()
	_preparar_boca()
	_montar_ator()
	_montar_camera()
	_tocar(&"ajoelhar_cansado", 0.0)
	ap.pause()

	# --- 1. o largo: ele, sozinho no meio da ruína, cai de joelhos
	_som("respiracao", SOM_RESPIRACAO, -4.0, true)
	_plano("Hips", Vector3(-1.9, 0.55, 4.4), Vector3(-1.3, 0.7, 3.0), Vector3(0, 0.2, 0), 48.0, 42.0, 6.0)
	_fade(0.0, 2.4)
	await _esperar(1.0)
	ap.play()
	await _esperar_plano()

	# --- 2. as costas curvadas, o fôlego que não volta
	_tocar(&"ajoelhado_ofegante", 0.4)
	_som("batimento", SOM_BATIMENTO, -8.0, true)
	_plano("Spine", Vector3(1.1, 0.45, -1.3), Vector3(0.85, 0.35, -1.05), Vector3(0, 0.05, 0), 42.0, 40.0, 4.2)
	await _esperar_plano()

	# --- 3. o rosto; embaixo dele a grelha começa a brilhar
	_boca = 1
	_aviso_da_boca()
	# a cabeça pende: o rosto só aparece debaixo da aba do chapéu
	_plano("Head", Vector3(0.3, -0.62, 0.62), Vector3(0.22, -0.55, 0.48), Vector3(0, -0.06, 0), 38.0, 34.0, 3.6)
	await _esperar_plano()

	# --- 4. as labaredas sobem: câmera lenta, o fogo toma ele
	_plano("Hips", Vector3(-1.6, 0.25, 3.4), Vector3(-1.4, 0.4, 3.0), Vector3(0, 0.5, 0), 48.0, 50.0, 3.2)
	_erupcao()
	await _esperar(0.35)
	_lento(LENTO, 0.6)
	_tocar(&"agonia_fogo", 0.25)
	_acender_corpo()
	_som("grito", SOM_GRITO, 2.0, false, 0.78)
	await _esperar_plano()

	# --- 5. o que queima, de perto. O jato da Boca foi o ESTOURO: dentro da
	# coluna a câmera só via branco, e daqui em diante quem queima é o corpo
	_apagar_jato()
	_plano("LeftForeArm", Vector3(-0.75, 0.15, 0.55), Vector3(-0.6, 0.25, 0.4), Vector3(0, 0, 0), 38.0, 34.0, 2.8)
	await _esperar_plano()
	_som("grito2", SOM_GRITO, 0.0, false, 0.66)
	_plano("Head", Vector3(0.2, -0.55, 0.55), Vector3(0.05, -0.5, 0.42), Vector3(0, 0.05, 0), 40.0, 36.0, 2.8)
	await _esperar_plano()
	_plano("Spine01", Vector3(0.75, 0.05, 0.7), Vector3(-0.75, 0.1, 0.7), Vector3(0, 0, 0), 42.0, 42.0, 3.0)
	await _esperar_plano()
	_plano("LeftLeg", Vector3(-0.5, 0.05, 0.9), Vector3(0.1, 0.1, 1.0), Vector3(0.25, 0.05, 0), 44.0, 40.0, 2.6)
	await _esperar_plano()
	_plano("Spine", Vector3(-0.6, 1.4, -1.5), Vector3(-0.4, 1.0, -1.1), Vector3(0, 0, 0), 46.0, 42.0, 2.8)
	await _esperar_plano()

	# --- 6. o amuleto na mão que queima, e a tela some devagar
	_tocar(&"queimando_final", 0.4)
	_mirar_no_amuleto(0.58, 0.3, 8.5)
	await _esperar(2.4)
	_fade(1.0, 5.5)
	_calar(5.5)
	await _esperar_plano()
	await _esperar(0.8)

	_lento(1.0, 0.0)
	_boca = 0
	terminou.emit()


# ==============================================================================
# O JOGADOR, O DUBLÊ E A CÂMERA
# ==============================================================================
func _travar_jogador() -> void:
	GlobalEvents.in_cutscene = true
	if not is_instance_valid(player):
		return
	player.velocity = Vector3.ZERO
	player.cutscene_set_player_control(false)
	player.cutscene_set_hud_enabled(false)
	player.cutscene_set_camera_current(false)
	player.cutscene_set_model_hidden(true)
	player.global_position = JOGADOR_LONGE


func _montar_ator() -> void:
	ator = Node3D.new()
	ator.name = "maycow_parasita_cena"
	arena.add_child(ator)
	ator.global_position = _chao(CENTRO)
	ator.rotation.y = GIRO
	modelo = (load(MODELO) as PackedScene).instantiate() as Node3D
	# o .glb olha pro +Z: meia volta, igual ao do player (o ator olha pro -Z)
	modelo.rotation.y = PI
	ator.add_child(modelo)
	esqueleto = modelo.find_child("Skeleton3D", true, false) as Skeleton3D
	ap = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var fonte := (load(CLIPES) as PackedScene).instantiate()
	var origem := fonte.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and origem:
		var lib := AnimationLibrary.new()
		for nome in origem.get_animation_list():
			var a := (origem.get_animation(nome) as Animation).duplicate() as Animation
			if String(nome) in LACOS:
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(nome, a)
		ap.add_animation_library(&"cap4", lib)
	fonte.free()
	# o braço esquerdo já queima, como no jogo
	_fogo_no_membro("LeftArm", "LeftHand", 0.0, 0.3, 1.0, true)


func _tocar(clipe: StringName, mistura: float) -> void:
	var nome := StringName("cap4/" + String(clipe))
	if ap == null or not ap.has_animation(nome):
		push_warning("cena do fogo: sem o clipe %s" % nome)
		return
	ap.play(nome, mistura)


func _montar_camera() -> void:
	cam = Camera3D.new()
	cam.name = "camera_fogo"
	cam.near = 0.02
	cam.far = 600.0
	arena.add_child(cam)
	cam.make_current()


## Onde está a origem do osso agora (mundo).
func _osso(nome: String) -> Vector3:
	if esqueleto == null:
		return ator.global_position
	var i := esqueleto.find_bone(nome)
	if i < 0:
		return ator.global_position
	return esqueleto.global_transform * esqueleto.get_bone_global_pose(i).origin


## Um vetor no espaço do dublê (x à direita dele, y pra cima, z pra FRENTE
## dele) em mundo.
func _no_ator(v: Vector3) -> Vector3:
	var b := ator.global_basis
	return b.x * v.x + Vector3.UP * v.y - b.z * v.z


## Um plano: a câmera presa ao osso, andando de `de` a `ate` (espaço do ator)
## em `dur` segundos de relógio, olhando pro osso (+ `mira`).
func _plano(osso: String, de: Vector3, ate: Vector3, mira: Vector3, fov_de: float,
		fov_ate: float, dur: float) -> void:
	_plano_atual = {"osso": osso, "de": de, "ate": ate, "mira": mira, "fov_de": fov_de,
		"fov_ate": fov_ate, "ini": _relogio, "dur": dur, "alvo": null}
	_mover_camera()


## O último plano: a mão do amuleto, a câmera descendo sobre ele. No fim do
## `queimando_final` a mão fica baixa e na frente, de palma pra cima: de cima
## o amuleto aparece na palma; de frente, os dedos o tapavam.
func _mirar_no_amuleto(longe: float, perto: float, dur: float) -> void:
	_plano_atual = {"osso": "RightHand", "de": Vector3(0.22, longe, 0.04),
		"ate": Vector3(0.1, perto, 0.02), "mira": Vector3.ZERO, "fov_de": 36.0,
		"fov_ate": 28.0, "ini": _relogio, "dur": dur, "alvo": _amuleto}
	_mover_camera()


func _mover_camera() -> void:
	if _plano_atual.is_empty() or not is_instance_valid(cam):
		return
	var p := _plano_atual
	var k := clampf((_relogio - float(p["ini"])) / maxf(float(p["dur"]), 0.01), 0.0, 1.0)
	var s := k * k * (3.0 - 2.0 * k)
	var base := _osso(String(p["osso"]))
	var alvo: Node3D = p["alvo"] if is_instance_valid(p["alvo"]) else null
	if alvo:
		base = alvo.global_position
	var de: Vector3 = p["de"]
	var ate: Vector3 = p["ate"]
	cam.global_position = base + _no_ator(de.lerp(ate, s))
	var olhar := base + _no_ator(p["mira"])
	if not cam.global_position.is_equal_approx(olhar):
		cam.look_at(olhar, Vector3.UP)
	cam.fov = lerpf(float(p["fov_de"]), float(p["fov_ate"]), s)


func _esperar_plano() -> void:
	if _plano_atual.is_empty():
		return
	await _esperar(float(_plano_atual["ini"]) + float(_plano_atual["dur"]) - _relogio)


## Espera em segundos de RELÓGIO (a câmera lenta não estica).
func _esperar(seg: float) -> void:
	var fim := _relogio + seg
	while _relogio < fim and is_inside_tree():
		await get_tree().process_frame


func _process(delta: float) -> void:
	_relogio += delta / maxf(Engine.time_scale, 0.01)
	_mover_camera()
	_esconder_maos()
	_passo_queima(delta)
	_passo_boca(delta)


## As mãos de primeira pessoa são filhas da câmera do jogador: continuam no
## mundo mesmo com outra câmera ligada.
func _esconder_maos() -> void:
	if not is_instance_valid(player):
		return
	for nome in ["hand_with_magic", "hand_with_pistol"]:
		var m = player.get(nome)
		if m is Node3D and is_instance_valid(m):
			(m as Node3D).visible = false


func _chao(xz: Vector2) -> Vector3:
	var de := Vector3(xz.x, 8.0, xz.y)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 20.0)
	q.collision_mask = 2
	var h := arena.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3) if not h.is_empty() else Vector3(xz.x, 1.68, xz.y)


# ==============================================================================
# O FOGO
# ==============================================================================
## A Boca na mão da cena: o ciclo sorteado da arena pára (sem dano nenhum).
func _preparar_boca() -> void:
	arena.set("fogareu_da_cena", true)
	if arena.has_method("_apagar_fogareu"):
		arena.call("_apagar_fogareu")


func _passo_boca(delta: float) -> void:
	if _boca == 0:
		return
	arena.set("_luz_boca_presa", true)
	_boca_k = minf(_boca_k + delta / 3.0, 1.0)
	if _boca == 1:
		arena.call("_acender_boca", 1.0 + 3.0 * _boca_k * _boca_k + 0.8 * _boca_k * sin(_relogio * 30.0),
			1.0 + 0.4 * _boca_k)
	else:
		# o clarão do estouro, e depois a brasa do corpo em cima da grelha
		var forca := lerpf(5.0, 2.2, clampf((_relogio - _estouro_em) / 3.0, 0.0, 1.0))
		arena.call("_acender_boca", forca + randf_range(-0.5, 0.5), 1.45)


## A grelha começa a brilhar: brasa subindo, chiado.
func _aviso_da_boca() -> void:
	var aviso := arena.get("_aviso") as GPUParticles3D
	if aviso:
		aviso.emitting = true
	var chiado := arena.get("_chiado") as AudioStreamPlayer3D
	if chiado and not chiado.playing:
		chiado.play()


func _erupcao() -> void:
	_boca = 2
	_estouro_em = _relogio
	var jato := arena.get("_jato") as GPUParticles3D
	if jato:
		jato.emitting = true
	var estouro := arena.get("_estouro") as AudioStreamPlayer3D
	if estouro:
		estouro.play()
	_som("erupcao", SOM_ERUPCAO, 3.0, false)
	_som("fogo", SOM_FOGO, 0.0, true, 0.85)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 1.2)


## Corte seco: as partículas do jato vivem 1,7 s de jogo, quase 6 s na câmera
## lenta — escondidas, somem no corte.
func _apagar_jato() -> void:
	var jato := arena.get("_jato") as GPUParticles3D
	if jato:
		jato.emitting = false
		jato.visible = false


## O corpo inteiro pega fogo: um fogo por membro e um no tronco (por último —
## a crosta de lava é um `material_overlay` só por malha, e o último que acende
## é o que fica), e a pele começa a queimar por baixo. O amuleto entra DEPOIS:
## ele não queima.
func _acender_corpo() -> void:
	_corpo = DissolverCorpo.vestir(modelo)
	if _corpo:
		_corpo.parametro("cor_sangue", Color(0.035, 0.022, 0.018))
		_corpo.parametro("cor_borda", Color(1.0, 0.42, 0.08))
	for fogo in _fogos:
		if is_instance_valid(fogo):
			fogo.queue_free()
	_fogos.clear()
	# chama baixa e rala: são cinco fogos somando na mesma tomada, e os closes
	# ficam a meio metro deles
	for m in MEMBROS:
		_fogo_no_membro(String(m[0]), String(m[1]), float(m[2]), 0.2, 0.85, false)
	_fogo_no_membro("Hips", "Head", 0.34, 0.26, 1.25, true)
	_queimando = true
	_por_amuleto()


func _fogo_no_membro(de: String, ate: String, raio: float, opacidade: float,
		tamanho: float, com_luz: bool) -> void:
	if esqueleto == null:
		return
	var fogo = FOGO.instantiate()
	fogo.name = "fogo_%s" % de
	fogo.mask_skeleton = esqueleto
	fogo.mask_bone_from = de
	fogo.mask_bone_to = ate
	fogo.mask_radius = raio
	fogo.flame_scale = tamanho
	fogo.flame_opacity = opacidade
	fogo.fade_in = 0.7
	fogo.lava_intensity = 2.4
	fogo.crust_opacity = 0.9
	modelo.add_child(fogo)
	fogo.ignite(modelo)
	# uma luz só (a do tronco): a arena já está no teto de 8 omni por malha
	if not com_luz:
		var luz = fogo.get("_light")
		if luz is Node:
			(luz as Node).queue_free()
			fogo.set("_light", null)
	_fogos.append(fogo)


func _por_amuleto() -> void:
	if esqueleto == null:
		return
	var preso := BoneAttachment3D.new()
	preso.name = "mao_do_amuleto"
	preso.bone_name = "RightHand"
	esqueleto.add_child(preso)
	# a escala do esqueleto (0,01) chega no attachment: o pivô dentro dele a
	# desfaz (ver [[project-boneattachment-escala]]) e daí pra dentro é metro —
	# a aura mede o amuleto e solta partícula no MUNDO, então ele tem de estar
	# em metro de verdade, como na cena da aura do inferno 4
	var escala_mundo := maxf(preso.global_basis.get_scale().x, 0.0001)
	var pivo := Node3D.new()
	pivo.name = "pivo"
	preso.add_child(pivo)
	pivo.scale = Vector3.ONE / escala_mundo
	pivo.position = PALMA / escala_mundo
	_amuleto = Node3D.new()
	_amuleto.name = "amuleto_na_mao"
	pivo.add_child(_amuleto)
	var peca := (load(AuraDoAmuleto.MODELO_AMULETO) as PackedScene).instantiate() as Node3D
	_amuleto.add_child(peca)
	var caixa := AuraDoAmuleto._caixa(peca, Transform3D.IDENTITY)
	var maior := maxf(maxf(caixa.size.x, caixa.size.y), caixa.size.z) if caixa.has_volume() else 0.0
	var fator := AMULETO_ALTURA / maior if maior > 0.0 else 0.04
	peca.scale = Vector3.ONE * fator
	peca.position = -caixa.get_center() * fator
	AuraDoAmuleto.vestir(_amuleto, true)


## A queima anda com o relógio: as veias primeiro, o carvão por cima, e no fim
## os buracos de brasa (sem chegar a sumir com ele).
func _passo_queima(delta: float) -> void:
	if not _queimando or _corpo == null:
		return
	_queima = minf(_queima + delta / maxf(Engine.time_scale, 0.01) / 22.0, 1.0)
	_corpo.parametro("veias", clampf(_queima * 3.0, 0.0, 1.0))
	_corpo.parametro("sangue", clampf(_queima * 1.6, 0.0, 0.92))
	_corpo.parametro("dissolver", smoothstep(0.35, 1.0, _queima) * 0.42)


# ==============================================================================
# TELA, TEMPO E SOM
# ==============================================================================
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


func _fade(alvo: float, duracao: float) -> void:
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_preto, "modulate:a", alvo, duracao).set_trans(Tween.TRANS_SINE)
	await t.finished


func _lento(escala: float, duracao: float) -> void:
	if duracao <= 0.0:
		Engine.time_scale = escala
		return
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_method(func(v: float) -> void: Engine.time_scale = v, Engine.time_scale, escala, duracao)


func _som(chave: String, caminho: String, volume: float, laco: bool, tom: float = 1.0) -> void:
	var s := AudioStreamPlayer.new()
	s.name = "som_" + chave
	var stream := load(caminho) as AudioStream
	if stream == null:
		return
	if laco:
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	s.stream = stream
	s.volume_db = volume
	s.pitch_scale = tom
	add_child(s)
	s.play()
	_sons[chave] = s


## Todos os sons da cena descem juntos até o silêncio.
func _calar(duracao: float) -> void:
	for s in _sons.values():
		if is_instance_valid(s):
			var t := create_tween().set_ignore_time_scale(true)
			t.tween_property(s, "volume_db", -60.0, duracao).set_trans(Tween.TRANS_SINE)


func _exit_tree() -> void:
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
