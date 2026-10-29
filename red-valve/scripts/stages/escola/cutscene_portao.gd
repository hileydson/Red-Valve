extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A PORTA QUE SE FECHA (Capítulo 1, depois da luta com o Grizzolito).
##
## O Maycow volta da arena e entra na escola: atravessa o pátio direto até a
## PORTA PRINCIPAL (a que leva ao corredor norte e às salas), passa por ela —
## e a porta bate atrás dele, segurada por alguma coisa do lado do pátio. A
## escola agora é uma prisão: o mapa dela zera (esta escola não é mais a que
## ele conhecia), toda porta que dá pro pátio fica fechada, e o único jeito de
## voltar à quadra é atravessar o prédio, o porão (o calabouço) e destrancar
## por dentro o portão do pátio, no corredor sul.
##
## Conclui `CAP1_ESCOLA_PRESA`. Quem chama: `capitulo_1_escola.gd`. Quem segura a
## porta fechada depois: `porta_escola._presa_por_dentro`.

const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")
const SOM_BATIDA := "res://assets/sounds/igreja/tapa_chao.ogg"
const SOM_TRANCA := "res://assets/sounds/igreja/destrancar_porta.ogg"
const MAPAS := ["res://assets/3d_model/stages/escola/escolamap.json",
	"res://assets/3d_model/stages/escola/poraomap.json"]

## A porta principal fica em x 20, no muro z 15,525 (o pátio é o lado +Z).
const PORTA := Vector3(20.0, 0.0, 15.525)
## Onde ele para diante dela, no pátio, e onde ele termina, no corredor norte.
const DIANTE_DA_PORTA := Vector3(20.0, 0.0, 18.6)
const NO_CORREDOR := Vector3(20.0, 0.0, 12.7)
## Onde ele começa a andar quando a cena carrega já nela (save no meio do
## pátio, ou longe demais da porta): de frente pra ela.
const PARTIDA := Vector3(20.0, 0.0, 26.0)
const ABERTO := PI * 0.5

var porta: Node3D
## A luz em cima da porta, do lado do corredor: sem ela não se vê a folha batendo.
var _luz: OmniLight3D


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 55.0)
	_acender()
	if Vector2(player.global_position.x - PARTIDA.x,
			player.global_position.z - PARTIDA.z).length() > 9.0:
		await escurecer(1.0, 0.25)
		player.global_position = Vector3(PARTIDA.x, player.global_position.y + 0.2, PARTIDA.z)
		player.velocity = Vector3.ZERO
		await esperar(0.2)
		escurecer(0.0, 0.6)
	await _andar_ate(DIANTE_DA_PORTA, 14.0, 1.4, func(d: Vector3) -> void:
		# atrás e acima do ombro, a porta principal lá na frente
		var dir := d.normalized() if d.length() > 0.01 else Vector3.FORWARD
		var lado := Vector3(-dir.z, 0.0, dir.x)
		plantar(player.global_position - dir * 3.4 + lado * 1.0 + Vector3.UP * 1.1,
			PORTA + Vector3.UP * 1.6))
	if vale():
		await _abrir_porta()
	if vale():
		await _andar_ate(NO_CORREDOR, 6.0, 0.5, func(_d: Vector3) -> void:
			# já do corredor, vendo ele passar pela porta
			plantar(Vector3(24.2, 1.8, 11.4), player.global_position + Vector3.UP * 1.2))
	if vale():
		await _a_porta_bate()
	_prender()
	encerrar(1.0)


func _acender() -> void:
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.62, 0.42)
	_luz.light_energy = 2.4
	_luz.omni_range = 9.0
	add_child(_luz)
	_luz.global_position = Vector3(20.0, 3.0, 13.4)


func _pivos() -> Array:
	if not is_instance_valid(porta):
		return [null, null]
	return [porta.get_node_or_null("pivo"), porta.get_node_or_null("pivo_b")]


## As folhas abrem pra DENTRO (pro corredor, o -Z da porta), longe dele.
func _abrir_porta() -> void:
	var p := _pivos()
	var t := create_tween().set_parallel(true)
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if p[0]:
		t.tween_property(p[0], "rotation:y", ABERTO, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if p[1]:
		t.tween_property(p[1], "rotation:y", PI - ABERTO, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(player) and player.has_method("esticar_mao_para"):
		player.esticar_mao_para(PORTA + Vector3(0.4, 1.05, 0.0), 0.6)
	await t.finished


func _andar_ate(alvo: Vector3, limite: float, chegou: float, camera: Callable) -> void:
	var d := alvo - player.global_position
	d.y = 0.0
	player.rotation.y = atan2(-d.x, -d.z)
	player.cutscene_set_auto_walk(true)
	var t := 0.0
	while t < limite:
		await get_tree().process_frame
		if not vale():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		d = alvo - player.global_position
		d.y = 0.0
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 0.12)
		camera.call(d)
		if d.length() < chegou:
			break
	player.cutscene_set_auto_walk(false)
	player.velocity = Vector3.ZERO


func _a_porta_bate() -> void:
	# ele se vira pra porta aberta (o +Z, o pátio), de costas pro corredor
	player.rotation.y = PI
	var de := Vector3(23.6, 1.6, 11.0)
	var olha := Vector3(20.0, 1.4, 15.5)
	plantar(de, olha)
	await esperar(0.6)
	if not vale():
		return
	var p := _pivos()
	var t := create_tween().set_parallel(true)
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if p[0]:
		t.tween_property(p[0], "rotation:y", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if p[1]:
		t.tween_property(p[1], "rotation:y", PI, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	_som(SOM_BATIDA, 6.0, 0.6)
	_som(SOM_TRANCA, 0.0, 0.7)
	clarao(0.35, 0.5)
	if is_instance_valid(_luz):
		_luz.light_color = Color(1.0, 0.12, 0.08)
		create_tween().tween_property(_luz, "light_energy", 0.5, 2.5)
	GlobalUtils.shake_camera(0.6, 0.4)
	GlobalUtils.vibrate_controller(null, 0.9, 0.8, 0.5)
	Realidade.nuvem(cena, PORTA + Vector3(0.0, 1.2, -0.6), 2.4, false)
	await esperar(0.6)
	legenda("CAP1_CENA_PORTA_FECHOU", 3.4)
	await plano(de, olha, de + Vector3(-1.4, 0.3, 0.6), olha + Vector3(0.0, -0.2, 0.0), 3.2)


## A escola vira prisão: evento, o portão do pátio trancado de novo e o mapa
## das duas plantas (escola e porão) apagado.
func _prender() -> void:
	GlobalEvents.escola_portao_destrancado = false
	for m in MAPAS:
		MapaNevoa.esquecer(m)
	Eventos.concluir(Eventos.CAP1_ESCOLA_PRESA)


func _som(caminho: String, volume: float, tom: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.volume_db = volume
	s.pitch_scale = tom
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
