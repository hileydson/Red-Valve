extends Node

## O AGARRÃO NA PORTA RED VALVE: a parte da cutscene da oficina (prólogo) em
## que o Maycow abre a porta e o Husk sai. Roda dentro da sub-cena
## `cutscene_sub_scene_portal_jimmy.tscn` (a porta, o redemoinho atrás, o Husk
## e a câmera de primeira pessoa) — o roteiro antigo dela (`open_dor`) não roda
## mais.
##
##  1. a porta abre num tranco e o redemoinho aparece atrás dela;
##  2. o Husk sai dele correndo, para no batente e ESTICA o braço: o antebraço
##     cresce até alcançar o pescoço do Maycow;
##  3. agarra — relâmpago, a câmera é puxada e erguida, tremendo, a tela pulsa
##     vermelho;
##  4. ele recua pro redemoinho ARRASTANDO o Maycow; a tela escurece devagar e
##     as linhas roxas tomam conta (`viagem_portal.gd`). A viagem leva os dois
##     ao inferno 2 (`cutscene_husk_inferno_2.gd`), e de lá a oficina volta no
##     Maycow caindo no chão.
##
## Os rigs não têm clipe de agarrar: o braço é `pose_apontada.gd`.

const ViagemPortal := preload("res://scripts/systems/viagem_portal.gd")
const PoseApontada := preload("res://scripts/cutscenes/pose_apontada.gd")
const INFERNO_2 := "res://scenes/stages/inferno_2/inferno_2.tscn"
## O Husk cru tem ~1,4 m; assim ele passa curvado pelo batente de 1,9 m.
const ESCALA_HUSK := 1.3
## Onde a porta fica aberta (as chaves do `open_dor` antigo: gira na dobradiça).
const PORTA_ABERTA_GIRO := Quaternion(0.0, -0.69020706, 0.0, 0.72361195)
const PORTA_ABERTA_POS := Vector3(-1.541, 0.0, 0.524)
## O chão da sub-cena (a porta de 1,9 m tem o centro na origem).
const CHAO := -0.95
## Quanto o olho sobe pra ver a cara do Husk no batente (rad).
const OLHAR_PRA_CIMA := 0.3

var oficina: Node
var sub: Node3D
var cam: Camera3D
var husk: Node3D
var pose
var porta: Node3D
var _vermelho: ColorRect


func rodar(dono: Node, sub_cena: Node3D) -> void:
	oficina = dono
	sub = sub_cena
	var ap := sub.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		ap.stop()
	# o borrão da oficina fica zerado até ele ser arrastado: antes disso ele só
	# apagava a porta abrindo e o Husk saindo
	var blur = oficina.get("motion_blur_mat")
	if blur:
		blur.set_shader_parameter("blur_strength", 0.0)
	cam = sub.get_node("Camera3D") as Camera3D
	porta = sub.get_node("portal_red_valve") as Node3D
	husk = sub.get_node("the-cobalt-husker") as Node3D
	_preparar_husk()
	_preparar_tela()
	await _abrir_a_porta()
	if _cancelado():
		return
	await _husk_sai()
	if _cancelado():
		return
	await _estica_e_agarra()
	if _cancelado():
		return
	await _arrasta_pra_dentro()


func _cancelado() -> bool:
	return not is_inside_tree() or bool(oficina.get("cutscene_skipped"))


func _preparar_husk() -> void:
	var malha := husk.find_child("char1", true, false) as MeshInstance3D
	if malha:
		var i := malha.find_blend_shape_by_name("transparency")
		if i >= 0:
			malha.set_blend_shape_value(i, 0.0)
	husk.scale = Vector3.ONE * ESCALA_HUSK
	husk.position = Vector3(0.0, CHAO, -2.8)
	husk.rotation = Vector3.ZERO
	husk.visible = false
	var sk := husk.find_child("Skeleton3D", true, false) as Skeleton3D
	pose = PoseApontada.new()
	sk.add_child(pose)


func _preparar_tela() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 112
	add_child(camada)
	_vermelho = ColorRect.new()
	_vermelho.color = Color(0.55, 0.0, 0.02, 0.0)
	_vermelho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vermelho.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_vermelho)


# ============================================================ 1) a porta

func _abrir_a_porta() -> void:
	_tocar("PortalRedValve")
	await _esperar(0.5)
	var t := create_tween().set_parallel(true)
	t.tween_property(porta, "quaternion", PORTA_ABERTA_GIRO, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(porta, "position", PORTA_ABERTA_POS, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GlobalUtils.vibrate_controller(null, 0.5, 0.4, 0.4)
	# o susto: o olho recua um palmo
	var p0 := cam.position
	await _fase(1.1, func(k: float) -> void:
		cam.position = p0 + Vector3(0.0, 0.0, 0.12 * sin(k * PI * 0.5))
		cam.rotation.x = -0.02 * sin(k * PI))


# ============================================================ 2) o Husk

func _husk_sai() -> void:
	husk.visible = true
	_animar("Running", 1.3)
	_tocar("Growl1")
	var de := husk.position
	var ate := Vector3(0.0, CHAO, -0.55)
	# o olho sobe acompanhando o bicho, que é mais alto que a porta
	var x0 := cam.rotation.x
	await _fase(0.9, func(k: float) -> void:
		husk.position = de.lerp(ate, 1.0 - pow(1.0 - k, 2.0))
		cam.rotation.x = lerpf(x0, OLHAR_PRA_CIMA, smoothstep(0.2, 1.0, k)))
	_animar("Walking", 0.0)


## O braço vai ao pescoço: o alvo é logo abaixo do olho. O antebraço estica o
## que faltar pra chegar.
func _alvo_pescoco() -> Vector3:
	return cam.global_position - cam.global_basis.y * 0.3 - cam.global_basis.z * 0.05


## Antes de pegar, a garra vem na cara: dentro do quadro, um palmo à frente do
## olho (no pescoço ela nunca apareceria).
func _alvo_rosto() -> Vector3:
	return cam.global_position - cam.global_basis.z * 0.32 - cam.global_basis.y * 0.08


func _esticar_ate(alvo: Vector3, peso: float) -> void:
	pose.mirar("braco", ["RightArm", "RightForeArm"], "RightHand", alvo, peso)
	var ombro: Vector3 = pose.osso_no_mundo("RightArm")
	var cotovelo: Vector3 = pose.osso_no_mundo("RightForeArm")
	var pulso: Vector3 = pose.osso_no_mundo("RightHand")
	var braco := ombro.distance_to(cotovelo)
	var ante := maxf(cotovelo.distance_to(pulso), 0.01)
	var precisa := clampf((ombro.distance_to(alvo) - braco) / ante, 1.0, 3.5)
	pose.esticar("braco", lerpf(1.0, precisa, peso))


func _estica_e_agarra() -> void:
	_tocar("Growl1", 0.8)
	await _fase(0.6, func(k: float) -> void:
		_esticar_ate(_alvo_rosto(), smoothstep(0.0, 1.0, k)))
	# AGARRA
	if oficina.has_method("_disparar_relampago_sub_scene"):
		oficina._disparar_relampago_sub_scene()
	_tocar("Pain")
	GlobalUtils.vibrate_controller(null, 1.0, 0.9, 0.8)
	var p0 := cam.position
	var p1 := p0 + Vector3(0.0, 0.38, -0.45)
	await _fase(1.0, func(k: float) -> void:
		var e := smoothstep(0.0, 0.35, k)
		var tremor := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.03 * (1.0 - k * 0.5)
		cam.position = p0.lerp(p1, e) + tremor
		cam.rotation = Vector3(lerpf(OLHAR_PRA_CIMA, 0.05, e) + randf_range(-0.03, 0.03), 0.0, 0.22 * sin(k * 9.0) * (1.0 - k * 0.4))
		_vermelho.color.a = 0.32 * absf(sin(k * PI * 3.0))
		_esticar_ate(_alvo_rosto().lerp(_alvo_pescoco(), smoothstep(0.0, 0.3, k)), 1.0))


# ============================================================ 3) pra dentro

func _arrasta_pra_dentro() -> void:
	if oficina.has_method("_ativar_motion_blur"):
		oficina._ativar_motion_blur(true)
	var blur = oficina.get("motion_blur_mat")
	if blur:
		create_tween().tween_property(blur, "shader_parameter/blur_strength", 1.3, 1.2)
	_animar("Running", -1.0)
	_tocar("Growl1", 0.65)
	var h0 := husk.position
	var c0 := cam.position
	var r0 := cam.rotation
	var fov0 := cam.fov
	var estado := {"viajou": false}
	await _fase(3.2, func(k: float) -> void:
		var e := k * k
		husk.position = h0 + Vector3(0.0, 0.0, -3.6 * e)
		cam.position = c0.lerp(Vector3(0.0, 0.15, -2.6), e)
		cam.rotation = Vector3(r0.x * (1.0 - e), 0.0, r0.z + e * TAU * 1.3)
		cam.fov = lerpf(fov0, fov0 + 38.0, e)
		_vermelho.color.a = 0.2 * (1.0 - k)
		_esticar_ate(_alvo_pescoco(), 1.0)
		if not estado.viajou and k > 0.12 and not _cancelado():
			estado.viajou = true
			# "fade out lento" e as linhas roxas: a entrada da viagem é longa
			ViagemPortal.viajar(get_tree(), INFERNO_2, "cutscene_oficina", 2.8, 2.2))


# ============================================================ peças

func _animar(clipe: String, vel: float) -> void:
	var ap := husk.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(clipe):
		ap.play(clipe, 0.15, vel, vel < 0.0)


func _tocar(no: String, tom: float = 1.0) -> void:
	var s := sub.get_node_or_null(no) as AudioStreamPlayer
	if s:
		s.pitch_scale = tom
		s.play()


func _fase(duracao: float, passo: Callable) -> void:
	var t := 0.0
	while t < duracao:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if _cancelado():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		passo.call(clampf(t / duracao, 0.0, 1.0))


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, false).timeout
