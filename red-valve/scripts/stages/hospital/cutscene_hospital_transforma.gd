extends "res://scripts/cutscenes/cutscene_cap1.gd"

## O HOSPITAL VIRA O ESCURO (Capítulo 2, o Jonny acabou de ficar na maca).
##
##  1. o Jonny deitado na maca, os médicos em volta;
##  2. o foco cirúrgico treme, um ronco grave sobe do prédio;
##  3. a ONDA sai da maca e o hospital vai virando o escuro por onde ela passa
##     (`hospital_versoes.transformar`); a câmera vai mostrando os lugares
##     sendo tomados — a sala, o saguão do 2º andar, o corredor do elevador, o
##     hall de entrada, o corredor norte — e quem estiver no caminho some;
##  4. a tela escurece de vez e fica preta: `no_escuro` avisa. Quem chamou
##     roda a Drizzi por cima e só depois chama `encerrar`.

signal no_escuro

const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")
const SOM_RONCO := "res://assets/sounds/cenarios/drone_inferno.ogg"
const SOM_SUMIR := "res://assets/sounds/igreja/teleporte_some.ogg"
const MESA := Vector3(27.675, 4.2, 59.025)
const DURACAO_ONDA := 12.0

## Planos amarrados ao raio da onda: cada um começa quando ela está chegando
## no lugar dele. [raio em que entra, de, olhando, até, olhando]
const PLANOS_DA_ONDA := [
	[0.0, Vector3(31.4, 6.3, 55.6), MESA + Vector3(0, 0.9, 0), Vector3(31.0, 6.5, 56.2), MESA + Vector3(0, 1.0, 0)],
	[13.0, Vector3(41.0, 5.9, 45.2), Vector3(16.0, 5.0, 50.0), Vector3(39.0, 6.0, 45.6), Vector3(16.0, 5.0, 50.5)],
	[27.0, Vector3(53.6, 5.9, 30.4), Vector3(18.0, 5.4, 31.0), Vector3(51.0, 5.9, 30.6), Vector3(18.0, 5.3, 31.0)],
	[38.0, Vector3(3.2, 1.9, 30.0), Vector3(22.0, 1.0, 37.5), Vector3(5.0, 1.9, 30.6), Vector3(22.0, 1.0, 37.5)],
	[50.0, Vector3(3.0, 1.7, 12.85), Vector3(45.0, 1.5, 12.85), Vector3(7.0, 1.7, 12.85), Vector3(45.0, 1.4, 12.85)],
]

var versoes: Node
var jonny: Node3D
## Todo mundo que a onda leva (médicos, enfermeiras, gente pelos corredores).
var pessoas: Array = []

var _ronco: AudioStreamPlayer


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 50.0)
	if vale():
		await _o_jonny_na_maca()
	if vale():
		await _o_foco_treme()
	if vale():
		await _a_onda()
	if vale():
		await escurecer(1.0, 1.4)
	if is_instance_valid(_ronco):
		var t := create_tween()
		t.tween_property(_ronco, "volume_db", -40.0, 1.2)
		t.tween_callback(_ronco.stop)
	no_escuro.emit()


# ============================================================ 1) a maca

func _o_jonny_na_maca() -> void:
	var alvo := jonny.global_position + Vector3.UP * 0.25 if is_instance_valid(jonny) else MESA + Vector3.UP
	var de := MESA + Vector3(-2.0, 2.1, -1.9)
	await plano(de, alvo, de + Vector3(0.45, -0.15, 0.4), alvo, 2.6)


# ============================================================ 2) o foco

func _o_foco_treme() -> void:
	_ronco = AudioStreamPlayer.new()
	if ResourceLoader.exists(SOM_RONCO):
		_ronco.stream = load(SOM_RONCO)
	_ronco.volume_db = -30.0
	_ronco.pitch_scale = 0.7
	add_child(_ronco)
	_ronco.play()
	create_tween().tween_property(_ronco, "volume_db", -6.0, 3.0)
	var luzes := _luzes_da_sala()
	var base := {}
	for l in luzes:
		base[l] = l.light_energy
	var de := MESA + Vector3(1.6, 3.2, 2.4)
	var olha := MESA + Vector3(0, 2.6, 0)
	await fase(2.2, func(k: float) -> void:
		for l in luzes:
			if is_instance_valid(l):
				l.light_energy = base[l] * (randf_range(0.1, 1.2) if randf() < 0.35 + k * 0.4 else 1.0)
		plantar(de.lerp(de + Vector3(-0.3, -0.4, 0.2), suave(k)), olha.lerp(MESA + Vector3(0, 1.0, 0), suave(k))))
	GlobalUtils.shake_camera(0.5, 0.35)
	GlobalUtils.vibrate_controller(null, 0.6, 0.5, 0.5)


func _luzes_da_sala() -> Array:
	var out: Array = []
	for l in cena.find_children("*", "Light3D", true, false):
		var p := (l as Light3D).global_position
		if p.y > 4.2 and absf(p.x - MESA.x) < 6.0 and absf(p.z - MESA.z) < 6.0:
			out.append(l)
	return out


# ============================================================ 3) a onda

func _a_onda() -> void:
	versoes.transformar(MESA, DURACAO_ONDA)
	_tocar(SOM_SUMIR, -2.0, 0.6)
	for p in PLANOS_DA_ONDA:
		while vale() and versoes.raio_onda < float(p[0]):
			_some_quem_a_onda_pegou()
			await get_tree().process_frame
		if not vale():
			return
		await plano(p[1], p[2], p[3], p[4], 2.3, func(_k: float) -> void:
			_some_quem_a_onda_pegou())
	for a in pessoas:
		if is_instance_valid(a):
			a.queue_free()


func _some_quem_a_onda_pegou() -> void:
	for a in pessoas:
		if not is_instance_valid(a) or not a.visible:
			continue
		var d := Vector2(a.global_position.x - MESA.x, a.global_position.z - MESA.z).length()
		if d <= versoes.raio_onda:
			Realidade.nuvem(cena, a.global_position + Vector3.UP, 1.3, false)
			a.visible = false
			a.process_mode = Node.PROCESS_MODE_DISABLED


func _tocar(caminho: String, volume: float, tom: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.volume_db = volume
	s.pitch_scale = tom
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


func _exit_tree() -> void:
	super._exit_tree()
	if is_instance_valid(_ronco):
		_ronco.stop()
