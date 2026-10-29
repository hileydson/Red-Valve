extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A PRIMEIRA TRAVESSIA DA RED VALVE DO PORÃO (Capítulo 1).
##
## O Maycow entra na câmara grande e a porta o chama: a câmera entra nos olhos
## dele (primeira pessoa, com as mãos — `player_cutscene_fp.tscn`), ele anda
## até a porta, ela abre num tranco, o vento puxa, a câmera é engolida pelo
## redemoinho e a VIAGEM de portal leva ao começo do inferno 4 (as linhas
## roxas de `viagem_portal.gd` — a mesma transição de toda travessia).
##
## Daí em diante a porta só abre por prompt (ver `porao.gd`).

const CENA_FP := "res://scenes/player/cutscene_fp/player_cutscene_fp.tscn"
const ViagemPortal := preload("res://scripts/systems/viagem_portal.gd")
const DUR_ANDAR := 4.2

var porta: Node3D
var _fp: Node3D


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 70.0)
	var olho := _olho()
	var frente := _frente_da_porta()
	_fp = (load(CENA_FP) as PackedScene).instantiate() as Node3D
	cena.add_child(_fp)
	_fp.plantar(olho, porta.global_position + Vector3.UP * 1.4)
	_fp.assumir_camera()
	_fp.tocar(&"idle")
	esconder_modelo(true)
	await esperar(0.6)
	if not vale():
		encerrar()
		return
	# a caminhada até a porta, balançando como passo
	var alvo_olhar := porta.global_position + Vector3.UP * 1.3
	var de := olho
	var ate := frente + Vector3.UP * (olho.y - player.global_position.y)
	await fase(DUR_ANDAR, func(k: float) -> void:
		var e := suave(k)
		var p := de.lerp(ate, e) + Vector3.UP * sin(k * TAU * 4.0) * 0.03
		_fp.mirar(p, alvo_olhar, 6.0, 5.0, sin(k * TAU * 2.0) * 0.012))
	if not vale():
		encerrar()
		return
	await porta.abrir_sem_sugar()
	_fp.tremer(0.02, 1.6)
	_fp.tocar(&"defesa", 1.0, 0.2)
	# o vórtice puxa a câmera pra dentro
	var centro: Vector3 = porta.centro_do_vortice()
	var p0 := _fp.global_position
	Eventos.concluir(Eventos.CAP1_RED_VALVE)
	ViagemPortal.viajar(get_tree(), porta.cena_destino, porta.ponto_destino)
	await fase(1.6, func(k: float) -> void:
		var e := k * k
		_fp.mirar(p0.lerp(centro, e * 0.85), centro, 10.0, 8.0, e * 0.5)
		_fp.lente(75.0 + e * 40.0))
	# a cena troca por baixo da viagem; se não trocou (sem destino), devolve
	encerrar()


func _olho() -> Vector3:
	var marcador = player.get("camera_first_person_marker")
	if is_instance_valid(marcador):
		return (marcador as Node3D).global_position
	return player.global_position + Vector3.UP * 0.6


## No chão, um metro e meio na frente da porta, na altura do jogador.
func _frente_da_porta() -> Vector3:
	var f := porta.global_position + porta.global_basis.z * 1.5
	return Vector3(f.x, player.global_position.y, f.z)


func encerrar(fade_in: float = 1.2) -> void:
	if is_instance_valid(_fp):
		_fp.queue_free()
	super.encerrar(fade_in)
