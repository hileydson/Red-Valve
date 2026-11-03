extends "res://scripts/npcs/jimmy/ator_jimmy.gd"

## O JIMMY SEGUINDO O MAYCOW (fim do Capítulo 5): da oficina ao hospital, por
## onde o Maycow for.
##
## Ele anda pela TRILHA do próprio Maycow — as posições por onde o jogador
## passou, um ponto a cada `PASSO_TRILHA` — e não em linha reta até ele: a rua
## da cidade não tem colisão e o navmesh da stage_1 não cobre a área jogável
## (ver [[project-navmesh-stage1]]), mas por onde o Maycow passou dá pra
## passar, e porta, corredor e esquina vêm de graça. Fica uns 2 m atrás; com
## atraso, corre; longe demais ou noutro andar (o elevador do hospital), some e
## reaparece atrás dele, num ponto da trilha nova.
##
## Sem colisão própria: o chão é um raio pra baixo a cada passo, na layer 2 —
## a única que o player enxerga (o resto é carro, gente, prop).
##
##     var j = JimmySegue.new()
##     cena.add_child(j)
##     j.global_position = atras_do_maycow
##     j.comecar(player)

const PASSO_TRILHA := 0.4
## Pára a esta distância (pela trilha) do Maycow.
const PERTO := 2.1
const ANDA := 1.45
const CORRE := 4.8
## Atraso (m pela trilha) a partir do qual ele corre.
const CORRER_ACIMA := 5.0
## Atraso a partir do qual ele some e reaparece atrás do Maycow.
const SUMIR_ACIMA := 30.0
## Desnível que conta como "outro andar" (o elevador, uma escada).
const OUTRO_ANDAR := 2.2
## Quanto de trilha nova ele espera, sumido, antes de reaparecer.
const REAPARECE_ATRAS := 3.2
const MAX_PONTOS := 300
## A velocidade em que os clipes foram capturados (a do pé no chão).
const ANDAR_CLIPE := 1.35
const CORRER_CLIPE := 4.2
## A layer do chão do jogo.
const LAYER_CHAO := 2

var jogador: Node3D
## A cena manda nele (uma cutscene): ele pára de seguir.
var parado_de_proposito := false

## As posições do PÉ do Maycow, da mais velha pra mais nova.
var _trilha: Array[Vector3] = []
var _altura_pe := 1.0
var _vel := 0.0
var _sumido := false
var _relogio_pe := 0.0


func _ready() -> void:
	super._ready()
	tocar(&"parado", 0.0)


## Começa a seguir. A trilha nasce com o ponto onde ele está e o pé do Maycow.
func comecar(j: Node3D) -> void:
	jogador = j
	_trilha.clear()
	_trilha.append(global_position)
	if is_instance_valid(jogador):
		_trilha.append(_pe_do_jogador())
	_sumido = false
	visible = true


## Põe ele de pé em `onde` (com o chão achado por raio) olhando pro Maycow, e
## recomeça a trilha dali.
func plantar(onde: Vector3) -> void:
	global_position = _no_chao(onde, onde.y)
	if is_instance_valid(jogador):
		olhar_para(jogador.global_position)
	comecar(jogador)


func _physics_process(delta: float) -> void:
	if parado_de_proposito or not is_instance_valid(jogador) or anim == null:
		return
	if get_tree().paused:
		return
	_medir_pe(delta)
	_gravar_trilha()
	var pe := _pe_do_jogador()
	if _sumido:
		_esperar_pra_reaparecer()
		return
	if absf(pe.y - global_position.y) > OUTRO_ANDAR:
		_sumir()
		return
	var atraso := _atraso()
	if atraso > SUMIR_ACIMA:
		_reaparecer_na_trilha()
		return
	_andar(delta, atraso)


# ==============================================================================
# A TRILHA
# ==============================================================================

func _pe_do_jogador() -> Vector3:
	return jogador.global_position - Vector3(0.0, _altura_pe, 0.0)


## Da origem do player até o chão embaixo dele (medido só com ele no chão).
func _medir_pe(delta: float) -> void:
	_relogio_pe -= delta
	if _relogio_pe > 0.0:
		return
	_relogio_pe = 0.5
	if not (jogador is CharacterBody3D) or not (jogador as CharacterBody3D).is_on_floor():
		return
	var p := jogador.global_position
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 3.0, LAYER_CHAO)
	q.exclude = [(jogador as CollisionObject3D).get_rid()]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		_altura_pe = clampf(p.y - (h.position as Vector3).y, 0.0, 2.0)


func _gravar_trilha() -> void:
	var pe := _pe_do_jogador()
	if _trilha.is_empty():
		_trilha.append(pe)
		return
	var ultimo: Vector3 = _trilha[_trilha.size() - 1]
	if Vector2(pe.x - ultimo.x, pe.z - ultimo.z).length() >= PASSO_TRILHA:
		_trilha.append(pe)
		if _trilha.size() > MAX_PONTOS:
			_trilha.remove_at(0)


## Quanto falta, pela trilha, até o pé do Maycow.
func _atraso() -> float:
	var total := 0.0
	var de := global_position
	for p in _trilha:
		total += Vector2(p.x - de.x, p.z - de.z).length()
		de = p
	var pe := _pe_do_jogador()
	total += Vector2(pe.x - de.x, pe.z - de.z).length()
	return total


func _andar(delta: float, atraso: float) -> void:
	var alvo_vel := 0.0
	if atraso > PERTO:
		alvo_vel = CORRE if atraso > CORRER_ACIMA else ANDA
	_vel = move_toward(_vel, alvo_vel, delta * (6.0 if alvo_vel > _vel else 9.0))
	var resta := _vel * delta
	var dir := Vector3.ZERO
	while resta > 0.0 and not _trilha.is_empty():
		var p: Vector3 = _trilha[0]
		var para := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
		var d := para.length()
		if d <= resta:
			global_position = Vector3(p.x, global_position.y, p.z)
			resta -= d
			_trilha.remove_at(0)
			if d > 0.001:
				dir = para / d
		else:
			dir = para / d
			global_position += dir * resta
			resta = 0.0
	# o chão: raio pra baixo, com a altura da trilha de reserva
	var ref_y: float = _trilha[0].y if not _trilha.is_empty() else _pe_do_jogador().y
	var y := _no_chao(global_position, ref_y).y
	global_position.y = lerpf(global_position.y, y, minf(1.0, delta * 12.0))
	if dir.length() > 0.1 and _vel > 0.2:
		global_rotation.y = lerp_angle(global_rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 8.0))
	elif _vel <= 0.2:
		var g := giro_para(jogador.global_position)
		global_rotation.y = lerp_angle(global_rotation.y, g, minf(1.0, delta * 3.0))
	if _vel > 2.6:
		tocar(&"correr", 0.25, _vel / CORRER_CLIPE)
	elif _vel > 0.25:
		tocar(&"andar", 0.25, maxf(0.5, _vel / ANDAR_CLIPE))
	else:
		tocar(&"parado", 0.4)


## O chão embaixo de `p` (o mais alto até 1,6 m acima), ou `y_reserva`.
func _no_chao(p: Vector3, y_reserva: float) -> Vector3:
	var de := Vector3(p.x, maxf(p.y, y_reserva) + 1.6, p.z)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 5.0, LAYER_CHAO)
	if is_instance_valid(jogador) and jogador is CollisionObject3D:
		q.exclude = [(jogador as CollisionObject3D).get_rid()]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return Vector3(p.x, y_reserva, p.z)
	return h.position


# ==============================================================================
# SUMIR E REAPARECER
# ==============================================================================

## Noutro andar: some e espera o Maycow andar um pouco por lá.
func _sumir() -> void:
	_sumido = true
	visible = false
	_vel = 0.0
	_trilha.clear()
	_trilha.append(_pe_do_jogador())


func _esperar_pra_reaparecer() -> void:
	var comprimento := 0.0
	for i in range(1, _trilha.size()):
		var a: Vector3 = _trilha[i - 1]
		var b: Vector3 = _trilha[i]
		comprimento += Vector2(b.x - a.x, b.z - a.z).length()
	if comprimento < REAPARECE_ATRAS:
		return
	_sumido = false
	visible = true
	global_position = _no_chao(_trilha[0], _trilha[0].y)
	_trilha.remove_at(0)


## Longe demais no mesmo andar: pula pra um ponto da trilha a uns 3 m dele
## (no meio do trecho, se o trecho for comprido).
func _reaparecer_na_trilha() -> void:
	var pontos: Array[Vector3] = _trilha.duplicate()
	pontos.append(_pe_do_jogador())
	var resta := REAPARECE_ATRAS
	var ponto: Vector3 = pontos[0]
	var corte := 0
	for i in range(pontos.size() - 1, 0, -1):
		var b: Vector3 = pontos[i]
		var a: Vector3 = pontos[i - 1]
		var d := Vector2(b.x - a.x, b.z - a.z).length()
		if d >= resta:
			ponto = b.lerp(a, resta / maxf(d, 0.001))
			corte = i
			break
		resta -= d
	for _k in mini(corte, _trilha.size()):
		_trilha.remove_at(0)
	global_position = _no_chao(ponto, ponto.y)
	_vel = 0.0
