extends "res://scripts/cutscenes/cutscene_cap1.gd"

## O REENCONTRO — o fim do jogo (Capítulo 5).
##
## O Maycow abre a porta da cirurgia do 2º andar com o Jimmy atrás dele. Lá
## dentro, sentado na beira da maca onde o Maycow o deitou no Capítulo 2, está
## o Jonny, de cabeça baixa. O Jimmy para na porta; depois vai, devagar, até o
## filho. O Jonny estende os braços, o Jimmy se curva sobre ele, e os dois
## ficam abraçados, em prantos, enquanto a câmera gira em volta deles — e a
## música entra ("I Want to go Home", `assets/sounds/capitulo_5`). Um último
## plano sobe devagar e a tela apaga MUITO devagar, com a música tocando; aí
## rolam os créditos (`creditos.gd`), que levam ao menu.
##
## Quem cria: `capitulo_5_hospital.gd`, ao abrir a porta da cirurgia.

const Creditos := preload("res://scripts/ui/creditos.gd")
## O passo lento do `andar_devagar` (a velocidade do pé no chão do clipe).
const PASSO_DEVAGAR := 0.75

var diretor: Node
var jimmy: Node3D
var jonny: Node3D
var porta: Node3D

var _creditos: Node


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 46.0)
	if is_instance_valid(jimmy):
		jimmy.set("parado_de_proposito", true)
		jimmy.visible = true
	var lugar_jonny: Vector3 = jonny.global_position
	var abraco: Vector3 = diretor.lugar_do_abraco()
	var y := abraco.y
	var na_porta := porta.global_position
	na_porta.y = y
	var pra_dentro := Vector3(lugar_jonny.x - na_porta.x, 0.0, lugar_jonny.z - na_porta.z).normalized()
	var lado := pra_dentro.cross(Vector3.UP).normalized()
	# o Jimmy entra logo atrás do Maycow, do lado dele
	var jimmy_porta := na_porta + pra_dentro * 0.6 + lado * 0.7
	jimmy.global_position = jimmy_porta
	jimmy.olhar_para(lugar_jonny)
	jimmy.tocar(&"parado", 0.3)
	var cab_jonny := lugar_jonny + Vector3.UP * 0.62

	# --- 1. de dentro da sala: o Jonny de costas, quieto, e o Jimmy na porta
	var atras_jonny := lugar_jonny - Vector3(0.9, -0.95, 0.0) + Vector3(0.0, 0.0, -0.5)
	plantar(atras_jonny, jimmy_porta + Vector3.UP * 1.5)
	await plano(atras_jonny, jimmy_porta + Vector3.UP * 1.5,
		atras_jonny + Vector3(0.1, 0.05, 0.25), jimmy_porta + Vector3.UP * 1.55, 3.6)
	if not vale():
		return

	# --- 2. o rosto do Jimmy: é ele
	var cab_jimmy: Vector3 = jimmy.cabeca()
	await plano(cab_jimmy + pra_dentro * 1.1 + lado * 0.3, cab_jimmy,
		cab_jimmy + pra_dentro * 0.85 + lado * 0.22, cab_jimmy - Vector3.UP * 0.03, 2.8)
	if not vale():
		return

	# --- 3. ele vai, devagar, até o filho (contornando a ponta da maca)
	var curva := abraco + Vector3(0.7, 0.0, -1.3)
	var rota := [jimmy_porta, curva, abraco]
	var comp := jimmy_porta.distance_to(curva) + curva.distance_to(abraco)
	var dur := comp / PASSO_DEVAGAR
	jimmy.tocar(&"andar_devagar", 0.4)
	var de_lado := (jimmy_porta + abraco) * 0.5 + lado * -2.2 + Vector3.UP * 1.4
	await fase(dur, func(k: float) -> void:
		var p := _na_rota(rota, k * comp)
		var prox := _na_rota(rota, minf(k * comp + 0.3, comp))
		jimmy.global_position = p
		if prox.distance_to(p) > 0.01:
			jimmy.olhar_para(prox)
		var meio := (p + lugar_jonny) * 0.5 + Vector3.UP * 1.2
		plantar(de_lado.lerp(meio + (lado * -1.6) + pra_dentro * -0.8 + Vector3.UP * 0.3, suave(k)), meio))
	if not vale():
		return

	# --- 4. o abraço; a música entra
	jimmy.global_position = abraco
	jimmy.olhar_para(lugar_jonny)
	jimmy.tocar(&"abraco_jonny", 0.9)
	jonny.tocar(&"cap5/abraco_sentado", 0.9)
	_creditos = Creditos.comecar(get_tree())
	var centro := (abraco + lugar_jonny) * 0.5 + Vector3.UP * 1.25
	var g0 := atan2(lado.x, lado.z)
	# a volta inteira, devagar, subindo um pouco
	await fase(15.0, func(k: float) -> void:
		var g := g0 + TAU * 0.85 * suave(k)
		var r := 1.95 - 0.25 * sin(k * PI)
		plantar(centro + Vector3(sin(g) * r, 0.15 + 0.35 * k, cos(g) * r), centro))
	if not vale():
		return

	# --- 5. de perto: o rosto do Jimmy por cima da cabeça do filho
	var cab: Vector3 = jimmy.cabeca()
	var frente_j := Vector3(lugar_jonny.x - abraco.x, 0.0, lugar_jonny.z - abraco.z).normalized()
	var lado_j := frente_j.cross(Vector3.UP).normalized()
	await plano(cab + frente_j * 0.75 + lado_j * 0.55, (cab + cab_jonny) * 0.5,
		cab + frente_j * 0.6 + lado_j * 0.4, (cab + cab_jonny) * 0.5 + Vector3.DOWN * 0.04, 6.0)
	if not vale():
		return

	# --- 6. a câmera sobe devagar e a tela apaga muito devagar, com a música
	_creditos.apagar(11.0)
	var de := centro + Vector3(sin(g0 + 0.6) * 2.2, 0.3, cos(g0 + 0.6) * 2.2)
	await fase(12.0, func(k: float) -> void:
		var e := suave(k)
		plantar(de.lerp(centro + Vector3(sin(g0 + 0.9) * 3.2, 3.0, cos(g0 + 0.9) * 3.2), e), centro - Vector3.UP * 0.2 * e))
	# o jogo acabou: grava, e os créditos levam ao menu
	Eventos.concluir(Eventos.CAP5_FIM)
	if is_instance_valid(_creditos):
		_creditos.rolar()


func _na_rota(rota: Array, s: float) -> Vector3:
	var resto := s
	for i in range(rota.size() - 1):
		var a: Vector3 = rota[i]
		var b: Vector3 = rota[i + 1]
		var d := a.distance_to(b)
		if resto <= d or i == rota.size() - 2:
			return a.lerp(b, clampf(resto / maxf(d, 0.001), 0.0, 1.0))
		resto -= d
	return rota[rota.size() - 1]
