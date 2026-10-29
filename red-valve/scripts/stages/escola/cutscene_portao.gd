extends "res://scripts/cutscenes/cutscene_cap1.gd"

## O PORTÃO QUE SE FECHA (Capítulo 1, depois da luta com o Grizzolito).
##
## O Maycow volta da arena e vai embora: o portão da rua está ABERTO, ele anda
## até lá — e o portão bate na cara dele, preso por alguma coisa do outro lado.
## A escola agora é uma prisão: o mapa dela zera (esta escola não é mais a que
## ele conhecia) e o único jeito de sair é atravessar o prédio inteiro, o porão
## e voltar ao pátio pelo portão que se destranca por dentro.
##
## Conclui `CAP1_ESCOLA_PRESA`. Quem chama: `capitulo_1_escola.gd`.

const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")
const SOM_BATIDA := "res://assets/sounds/igreja/tapa_chao.ogg"
const SOM_TRANCA := "res://assets/sounds/igreja/destrancar_porta.ogg"
const MAPAS := ["res://assets/3d_model/stages/escola/escolamap.json",
	"res://assets/3d_model/stages/escola/poraomap.json"]

## Onde o Maycow para, de frente pro portão da rua (x 0,175, z 33).
const DIANTE_DO_PORTAO := Vector3(3.4, 0.0, 33.0)
const ABERTO := 1.15

var portao: Node3D
## A luz em cima do portão durante a cena: no escuro do pátio sem ela não se vê
## a folha batendo.
var _luz: OmniLight3D


## Onde o Maycow começa a andar quando a cena carrega já nela (o save nasce no
## portão da rua, colado nele): o meio do pátio, de frente pro portão.
const PARTIDA := Vector3(15.0, 0.0, 31.0)


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 55.0)
	_abrir_portao()
	if Vector2(player.global_position.x - DIANTE_DO_PORTAO.x,
			player.global_position.z - DIANTE_DO_PORTAO.z).length() < 8.0:
		await escurecer(1.0, 0.25)
		player.global_position = Vector3(PARTIDA.x, player.global_position.y + 0.2, PARTIDA.z)
		player.velocity = Vector3.ZERO
		await esperar(0.2)
		escurecer(0.0, 0.6)
	await _andar_ate_o_portao()
	if vale():
		await _o_portao_bate()
	_prender()
	encerrar(1.0)


func _abrir_portao() -> void:
	if not is_instance_valid(portao):
		return
	var a := portao.get_node_or_null("pivo") as Node3D
	var b := portao.get_node_or_null("pivo_b") as Node3D
	if a:
		a.rotation.y = -ABERTO
	if b:
		b.rotation.y = PI + ABERTO
	# do lado de fora não existe cidade nesta cena: um breu fecha o vão aberto
	var breu := MeshInstance3D.new()
	breu.name = "breu_da_rua"
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.2, 4.0, 5.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.0, 0.0)
	caixa.material = mat
	breu.mesh = caixa
	cena.add_child(breu)
	breu.global_position = Vector3(-2.2, 2.0, 33.0)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.62, 0.42)
	_luz.light_energy = 2.4
	_luz.omni_range = 10.0
	add_child(_luz)
	_luz.global_position = Vector3(1.6, 3.1, 33.0)


func _andar_ate_o_portao() -> void:
	var d := DIANTE_DO_PORTAO - player.global_position
	d.y = 0.0
	player.rotation.y = atan2(-d.x, -d.z)
	player.cutscene_set_auto_walk(true)
	var t := 0.0
	while t < 14.0:
		await get_tree().process_frame
		if not vale():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		d = DIANTE_DO_PORTAO - player.global_position
		d.y = 0.0
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 0.12)
		# a câmera atrás e acima do ombro, olhando o portão aberto lá na frente
		var dir := d.normalized() if d.length() > 0.01 else Vector3.LEFT
		var lado := Vector3(-dir.z, 0.0, dir.x)
		plantar(player.global_position - dir * 3.4 + lado * 1.0 + Vector3.UP * 1.1,
			Vector3(0.0, 1.6, 33.0))
		if d.length() < 2.6:
			break
	player.cutscene_set_auto_walk(false)
	player.velocity = Vector3.ZERO


func _o_portao_bate() -> void:
	var de := Vector3(6.8, 1.5, 36.0)
	plantar(de, Vector3(0.2, 1.4, 33.0))
	await esperar(0.25)
	if not vale():
		return
	var a := portao.get_node_or_null("pivo") as Node3D if is_instance_valid(portao) else null
	var b := portao.get_node_or_null("pivo_b") as Node3D if is_instance_valid(portao) else null
	var t := create_tween().set_parallel(true)
	if a:
		t.tween_property(a, "rotation:y", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if b:
		t.tween_property(b, "rotation:y", PI, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	_som(SOM_BATIDA, 6.0, 0.6)
	_som(SOM_TRANCA, 0.0, 0.7)
	clarao(0.35, 0.5)
	if is_instance_valid(_luz):
		_luz.light_color = Color(1.0, 0.12, 0.08)
		create_tween().tween_property(_luz, "light_energy", 0.5, 2.5)
	GlobalUtils.shake_camera(0.6, 0.4)
	GlobalUtils.vibrate_controller(null, 0.9, 0.8, 0.5)
	Realidade.nuvem(cena, Vector3(0.8, 1.2, 33.0), 2.4, false)
	var breu := cena.get_node_or_null("breu_da_rua")
	if breu:
		breu.queue_free()
	await esperar(0.6)
	legenda("CAP1_CENA_PORTAO_FECHOU", 3.0)
	await plano(de, Vector3(0.2, 1.4, 33.0), de + Vector3(1.6, 0.6, 1.2), Vector3(0.2, 1.2, 33.0), 3.0)


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
