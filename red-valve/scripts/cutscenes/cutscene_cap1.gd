extends Node

## A BASE DAS CUTSCENES DO CAPÍTULO 1 (escola): o que toda cena de câmera
## precisa e que a do mirante do inferno 4 (`cutscene_mirante.gd`) já fazia —
## travar o jogador, uma Camera3D própria, as tarjas de cinema, a tela preta
## pros cortes e o relógio que para quando o jogo pausa.
##
## Quem herda escreve só o roteiro:
##
##     func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
##         travar(dono, jogador)
##         await fase(3.0, func(k): plantar(..., ...))
##         encerrar()
##
## `encerrar` devolve TUDO ao jogador (controle, câmera, HUD) e vale também se a
## cena morrer no meio — o input nunca fica preso.
##
## ACABAMENTO DE CINEMA (`FiltroCinema`): quem passa um `clima` pro `travar`
## ganha a grade de cor, a halação, o grão e a câmera "na mão" do filtro, e os
## momentos (`clarao`, `tremer`, `impacto`, `foco`) passam por ele. Sem clima a
## cena fica como sempre foi (as do Capítulo 2 ainda não pedem). O filtro é só
## da cutscene: some no `encerrar`, junto com ela.

signal terminou

const ALTURA_TARJA := 0.11
const FiltroCinema := preload("res://scripts/cutscenes/filtro_cinema.gd")

var cena: Node3D
var player: CharacterBody3D
var cam: Camera3D

var _camada: CanvasLayer
var _tela: ColorRect
var _tarja_cima: ColorRect
var _tarja_baixo: ColorRect
var _modelo_escondido := false
var _acabou := false
## O filtro de cinema (null quando a cena não pediu clima).
var filtro = null


func travar(dono: Node3D, jogador: CharacterBody3D, fov: float = 60.0, clima: String = "") -> void:
	cena = dono
	player = jogador
	GlobalEvents.in_cutscene = true
	GlobalUtils.esconder_objetivo()
	cam = Camera3D.new()
	cam.name = "camera_" + String(name)
	cam.near = 0.05
	cam.far = 600.0
	cena.add_child(cam)
	var atual := get_viewport().get_camera_3d()
	if atual:
		cam.global_transform = atual.global_transform
		cam.fov = atual.fov
	cam.make_current()
	create_tween().tween_property(cam, "fov", fov, 0.8)
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
		player.cutscene_set_hud_enabled(false)
		player.cutscene_set_player_control(false)
		player.cutscene_set_camera_current(false)
	_camada = CanvasLayer.new()
	_camada.layer = 90
	add_child(_camada)
	_tarja_cima = _faixa(true)
	_tarja_baixo = _faixa(false)
	_tela = ColorRect.new()
	_tela.color = Color.BLACK
	_tela.modulate.a = 0.0
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(_tela)
	var t := create_tween().set_parallel(true)
	t.tween_property(_tarja_cima, "anchor_bottom", ALTURA_TARJA, 0.9).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_tarja_baixo, "anchor_top", 1.0 - ALTURA_TARJA, 0.9).set_trans(Tween.TRANS_CUBIC)
	if clima != "":
		# as tarjas continuam sendo as daqui (por cima da UI); o filtro entra sem
		filtro = FiltroCinema.criar(self, clima, -1)
		filtro.entrar(0.9, 0.0)


func _faixa(cima: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if cima else 1.0
	r.anchor_bottom = 0.0 if cima else 1.0
	_camada.add_child(r)
	return r


func encerrar(fade_in: float = 1.2) -> void:
	if _acabou:
		return
	_acabou = true
	if is_instance_valid(player):
		player.cutscene_set_auto_walk(false)
		if _modelo_escondido:
			esconder_modelo(false)
		player.cutscene_set_camera_current(true)
		player.cutscene_set_player_control(true)
		player.cutscene_set_hud_enabled(true)
	if is_instance_valid(filtro):
		filtro.sair(fade_in, false)
	if is_instance_valid(cam):
		cam.queue_free()
	GlobalEvents.in_cutscene = false
	if is_inside_tree() and is_instance_valid(_tela):
		var t := create_tween().set_parallel(true)
		t.tween_property(_tela, "modulate:a", 0.0, fade_in)
		t.tween_property(_tarja_cima, "anchor_bottom", 0.0, fade_in)
		t.tween_property(_tarja_baixo, "anchor_top", 1.0, fade_in)
		await t.finished
	terminou.emit()
	queue_free()


func _exit_tree() -> void:
	# a cena saiu no meio (morte, troca de cena): o input não pode ficar preso
	if not _acabou:
		GlobalEvents.in_cutscene = false


# ============================================================ peças

func vale() -> bool:
	return is_instance_valid(player) and player.is_inside_tree() and is_instance_valid(cam) \
			and is_inside_tree()


func esconder_modelo(sim: bool) -> void:
	_modelo_escondido = sim
	if not is_instance_valid(player):
		return
	player.cutscene_set_model_hidden(sim)
	if not sim:
		var modelo = player.get("modelo_visual")
		if is_instance_valid(modelo):
			modelo.visible = true


## A câmera em `pos`, olhando `alvo`, com `rolagem` rad em torno do próprio eixo.
func plantar(pos: Vector3, alvo: Vector3, rolagem: float = 0.0) -> void:
	if not is_instance_valid(cam) or pos.distance_squared_to(alvo) < 0.0001:
		return
	cam.look_at_from_position(pos, alvo, Vector3.UP)
	if rolagem != 0.0:
		cam.rotate_object_local(Vector3.FORWARD, rolagem)


## Um plano: a câmera vai de (p0 olhando l0) até (p1 olhando l1) em `duracao`.
func plano(p0: Vector3, l0: Vector3, p1: Vector3, l1: Vector3, duracao: float,
		extra: Callable = Callable()) -> void:
	await fase(duracao, func(k: float) -> void:
		var e := suave(k)
		plantar(p0.lerp(p1, e), l0.lerp(l1, e))
		if extra.is_valid():
			extra.call(k))


## Tela preta (1) ou aberta (0).
func escurecer(alvo: float, duracao: float) -> void:
	if not is_instance_valid(_tela):
		return
	var tw := create_tween()
	tw.tween_property(_tela, "modulate:a", alvo, duracao).set_trans(Tween.TRANS_SINE)
	await tw.finished


## Um clarão branco (o raio). Com o filtro ele é luz na lente (as tarjas
## continuam pretas e o claro vaza); sem ele, um retângulo branco por cima.
func clarao(forca: float = 1.0, descida: float = 0.6) -> void:
	if is_instance_valid(filtro):
		filtro.clarao(Color(0.92, 0.95, 1.0), forca, descida)
		filtro.pulso("halation", 0.9 * forca, descida * 1.5)
		filtro.pulso("aberration", 0.008 * forca, descida)
		return
	if not is_instance_valid(_camada):
		return
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, forca)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, descida)
	tw.tween_callback(r.queue_free)


## O chão treme (trauma 0..1, ver FiltroCinema.tremer). Sem filtro, o tremor
## antigo, na câmera.
func tremer(trauma: float, queda: float = 1.1) -> void:
	if is_instance_valid(filtro):
		filtro.tremer(trauma, queda)
	else:
		GlobalUtils.shake_camera(0.4 + trauma * 0.4, trauma * 0.5)


## Pancada de cinema: tremor, clarão, lente estourando, controle vibrando.
func impacto(forca: float = 1.0, cor: Color = Color(1.0, 0.94, 0.86), com_som: bool = false) -> void:
	if is_instance_valid(filtro):
		filtro.impacto(forca, cor, com_som)
	else:
		clarao(0.4 * forca, 0.5)
		GlobalUtils.vibrate_controller(null, 0.6 * forca, 0.5 * forca, 0.4)


## Profundidade de campo: o que estiver além de `distancia` da câmera borra.
## 0 devolve a câmera nítida.
func foco(distancia: float, transicao: float = 10.0, quanto: float = 0.05) -> void:
	if not is_instance_valid(filtro):
		return
	if distancia <= 0.0:
		filtro.devolver_foco()
	else:
		filtro.foco(cam, distancia, transicao, quanto)


## Roda `passo` quadro a quadro por `duracao` segundos, com o andamento (0..1).
## Com o jogo pausado o relógio da cena para junto.
func fase(duracao: float, passo: Callable) -> void:
	var t := 0.0
	while t < duracao:
		await get_tree().process_frame
		if not vale():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		passo.call(clampf(t / duracao, 0.0, 1.0))


func esperar(segundos: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(segundos, false).timeout


## Uma fala na parte de baixo da tela, como legenda.
func legenda(chave: String, segundos: float) -> void:
	GlobalUtils.show_center_message("legenda_" + String(name), tr(chave), 20, segundos)


static func suave(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)
