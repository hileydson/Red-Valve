extends CharacterBody3D

## A DONA NICE GIGANTE — fase 2 da luta da igreja (5 m, flutua).
##
## Sempre de frente pro Maycow, ela troca de jeito de tempos em tempos:
##   - VAGA: flutua a esmo pela nave, pra pontos sorteados;
##   - LONGE: se afasta e fica a ~10 m dele, cuspindo mais vezes;
##   - CACA: paira em volta dele (a orbita de antes) — e so' aqui ela investe.
## E, de vez em quando, se TELETRANSPORTA: o corpo queima e some
## (`teleporte_dona_nice.gd`) e ela surge noutro canto da nave — ou, as
## vezes, bem perto dele.
## Em qualquer jeito:
##   - deixa POCAS de baba por onde passa (queimam e deixam lento, e somem em 2 s);
##   - CUSPE: recolhe a cabeca e cospe uma bola de gosma em arco;
##   - INVESTIDA + TAPA (so' caçando): vem rapido ate' o ponto em que a mao
##     cai em cima dele, PARA um instante (o aviso: as veias acendem) e bate
##     de cima pra baixo com a mao enorme. So' pega quem ficou perto da mao.
## Morre com ~30 tiros de pistola (medido no dano da pistola, como a fase 1).
##
## Movimento sem fisica de chao: ela flutua, entao a posicao e' escrita direto
## (o corpo existe so' pra receber tiro). Frente = +Z, como a fase 1.
## Os movimentos sao clipes da biblioteca editavel
## `dona_nice_monster_fase_2_clipes.tres` (flutuar, cuspir, investida, tapa,
## dano, morrer, surgir).

signal morreu

const TIROS_PARA_MORRER := 30
const ALTURA_FLUTUA := 0.55
const RAIO_ORBITA := 7.5
const VELOCIDADE := 1.6
const GIRO := 1.6
const INTERVALO_POCA := 1.7
const MAX_POCAS := 9
const INTERVALO_CUSPE := Vector2(3.6, 5.5)
## De longe ela cospe mais.
const INTERVALO_CUSPE_LONGE := Vector2(1.9, 3.0)
const INTERVALO_TAPA := Vector2(8.0, 11.5)
const AVISO_DO_TAPA := 0.5
## Raio, em volta de onde a mao bate no chao, que machuca.
const RAIO_DO_TAPA := 1.3
## Onde a mao do `tapa` bate, em relacao ao corpo dela (medido no clipe, no
## IMPACTO_DO_TAPA): a investida para com esse ponto em cima dele.
const MAO_DO_TAPA := Vector3(-1.0, 0.0, 1.87)
const DANO_TAPA := 24
## o quadro do clipe `tapa` em que a mao bate no chao
const IMPACTO_DO_TAPA := 1.05
## Os limites da nave: ela nao atravessa parede nem sai pelo portal.
const LIMITE_X := 5.5
const LIMITE_Z := Vector2(5.5, 31.0)
## Quanto dura cada jeito (s), sorteado.
const DURACAO_DO_JEITO := Vector2(5.0, 8.5)
## A distancia em que ela fica no jeito LONGE.
const DISTANCIA_LONGE := 10.0
const VELOCIDADE_VAGANDO := 2.0
## Fora da investida ela nunca para em cima dele (5 m de corpo por cima da
## camera): o alvo do movimento fica no minimo a esta distancia.
const DISTANCIA_MINIMA := 4.0
## De quanto em quanto tempo ela se teletransporta (s), e a chance de surgir
## perto dele (a RAIO_PERTO).
const INTERVALO_TELEPORTE := Vector2(9.0, 15.0)
const CHANCE_PERTO := 0.4
const RAIO_PERTO := Vector2(4.2, 5.5)
const TEMPO_SUMINDO := 0.75
const TEMPO_SURGINDO := 0.7
const TELEPORTE := preload("res://scripts/effects/teleporte_dona_nice.gd")

const CENA_POCA := "res://scenes/enemies/dona_nice/gosma_poca.tscn"
const CENA_PROJETIL := "res://scenes/enemies/dona_nice/gosma_projetil.tscn"

@export var enemy_name: String = "IGR_BOSS_NOME_2"
var dead := false
var max_health := 300
var current_health := 300

var _ativa := false
var _ocupada := false
var _tempo := 0.0
var _prox_poca := 0.0
var _prox_cuspe := 0.0
var _prox_tapa := 0.0
var _angulo := 0.0
var _sentido := 1.0
var _tiros := 0
var _pocas: Array[Node] = []
var _projeteis: Array[Node] = []
## "caca", "vaga" ou "longe"
var _jeito := "caca"
var _fim_do_jeito := 0.0
var _destino := Vector3.ZERO
var _prox_teleporte := 0.0
## Sumida no meio do teleporte: tiro nao pega.
var _sumida := false
## Durante o tapa ela fica no angulo da investida (NAN = olha pra ele).
var _giro_fixo := NAN

@onready var visual: Node3D = $visual
@onready var som_respira: AudioStreamPlayer3D = $sons/respira
@onready var som_dano: AudioStreamPlayer3D = $sons/dano
@onready var som_cuspe: AudioStreamPlayer3D = $sons/cuspe
@onready var som_tapa: AudioStreamPlayer3D = $sons/tapa
@onready var som_grito: AudioStreamPlayer3D = $sons/grito

const SONS_DANO := ["res://assets/sounds/igreja/dano_monstro_1.ogg",
	"res://assets/sounds/igreja/dano_monstro_2.ogg",
	"res://assets/sounds/igreja/dano_monstro_3.ogg"]


func _ready() -> void:
	add_to_group("enemies")
	var jogador := _jogador()
	var dano := 10
	if jogador and "damage_pistol" in jogador:
		dano = int(jogador.damage_pistol)
	max_health = TIROS_PARA_MORRER * dano
	current_health = max_health
	visual.tocar(&"flutuar", 0.0)


func comecar() -> void:
	_ativa = true
	som_respira.play()
	var j := _jogador()
	if j:
		var d := global_position - j.global_position
		_angulo = atan2(d.x, d.z)
	_prox_cuspe = _tempo + randf_range(INTERVALO_CUSPE.x, INTERVALO_CUSPE.y)
	_prox_tapa = _tempo + randf_range(INTERVALO_TAPA.x, INTERVALO_TAPA.y)
	_prox_teleporte = _tempo + randf_range(INTERVALO_TELEPORTE.x, INTERVALO_TELEPORTE.y)
	_fim_do_jeito = _tempo + randf_range(DURACAO_DO_JEITO.x, DURACAO_DO_JEITO.y)


func _jogador() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	_tempo += delta
	if dead or not _ativa:
		return
	var j := _jogador()
	if j == null:
		return
	_encarar(j, delta)
	if _ocupada or GlobalEvents.agarrao_rodando:
		_flutuar_no_lugar()
		return

	if _tempo > _fim_do_jeito:
		_trocar_de_jeito(j)
	var alvo := _alvo_do_jeito(j, delta)
	var dele := Vector3(alvo.x - j.global_position.x, 0.0, alvo.z - j.global_position.z)
	if dele.length() < DISTANCIA_MINIMA:
		if dele.length() < 0.01:
			dele = Vector3(global_position.x - j.global_position.x, 0.0, global_position.z - j.global_position.z)
		alvo = _dentro_da_nave(j.global_position + dele.normalized() * DISTANCIA_MINIMA)
	var vel := VELOCIDADE_VAGANDO if _jeito == "vaga" else VELOCIDADE * 1.4
	var p := global_position
	var plano := Vector3(alvo.x - p.x, 0.0, alvo.z - p.z)
	var passo := minf(plano.length(), vel * delta)
	if plano.length() > 0.01:
		p += plano.normalized() * passo
	p.y = ALTURA_FLUTUA + sin(_tempo * 1.3) * 0.22
	global_position = p

	if _tempo > _prox_poca:
		_prox_poca = _tempo + INTERVALO_POCA
		criar_poca(Vector3(p.x, 0.0, p.z) + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)))
	if _tempo > _prox_teleporte:
		_teleportar(j, randf() < CHANCE_PERTO)
	elif _tempo > _prox_tapa and _jeito == "caca":
		_investir_e_bater(j)
	elif _tempo > _prox_cuspe:
		_cuspir(j)


## Sorteia o proximo jeito (nunca o mesmo duas vezes seguidas).
func _trocar_de_jeito(j: Node3D) -> void:
	var opcoes := ["caca", "vaga", "longe"]
	opcoes.erase(_jeito)
	_jeito = opcoes.pick_random()
	_fim_do_jeito = _tempo + randf_range(DURACAO_DO_JEITO.x, DURACAO_DO_JEITO.y)
	if _jeito == "caca":
		var d := global_position - j.global_position
		_angulo = atan2(d.x, d.z)
		# chegando pra caçar, nao bate de cara: da' um tempo pra ele ver
		_prox_tapa = maxf(_prox_tapa, _tempo + 2.5)
	elif _jeito == "vaga":
		_destino = _ponto_da_nave()
	if _jeito == "longe":
		_prox_cuspe = minf(_prox_cuspe, _tempo + 1.0)


func _alvo_do_jeito(j: Node3D, delta: float) -> Vector3:
	match _jeito:
		"vaga":
			var d := Vector2(_destino.x - global_position.x, _destino.z - global_position.z)
			var dele := Vector2(_destino.x - j.global_position.x, _destino.z - j.global_position.z)
			if d.length() < 1.0 or dele.length() < DISTANCIA_MINIMA + 1.0:
				_destino = _ponto_da_nave()
			return _destino
		"longe":
			var fora := global_position - j.global_position
			fora.y = 0.0
			if fora.length() < 0.1:
				fora = Vector3.FORWARD
			return _dentro_da_nave(j.global_position + fora.normalized() * DISTANCIA_LONGE)
	# orbita em volta dele, trocando de sentido de vez em quando
	if randf() < delta * 0.12:
		_sentido = -_sentido
	_angulo += _sentido * VELOCIDADE / RAIO_ORBITA * delta
	var alvo := j.global_position + Vector3(sin(_angulo), 0.0, cos(_angulo)) * RAIO_ORBITA
	return _dentro_da_nave(alvo)


func _ponto_da_nave() -> Vector3:
	return Vector3(randf_range(-LIMITE_X, LIMITE_X), ALTURA_FLUTUA,
		randf_range(LIMITE_Z.x, LIMITE_Z.y))


func _flutuar_no_lugar() -> void:
	var p := global_position
	p.y = ALTURA_FLUTUA + sin(_tempo * 1.3) * 0.22
	global_position = p


func _encarar(j: Node3D, delta: float) -> void:
	var d := j.global_position - global_position
	var alvo := atan2(d.x, d.z) if is_nan(_giro_fixo) else _giro_fixo
	rotation.y = rotate_toward(rotation.y, alvo, GIRO * delta)


func _dentro_da_nave(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -LIMITE_X, LIMITE_X), p.y, clampf(p.z, LIMITE_Z.x, LIMITE_Z.y))


# ------------------------------------------------------------------ ataques
func _cuspir(j: Node3D) -> void:
	_ocupada = true
	var intervalo := INTERVALO_CUSPE_LONGE if _jeito == "longe" else INTERVALO_CUSPE
	_prox_cuspe = _tempo + randf_range(intervalo.x, intervalo.y)
	visual.tocar(&"cuspir", 0.15)
	await get_tree().create_timer(0.62, false).timeout
	if dead:
		return
	som_cuspe.play()
	var boca: Vector3 = visual.posicao_do_osso("head") + global_basis.z * 0.5 + Vector3(0, -0.35, 0)
	var alvo := j.global_position + Vector3(0, -0.6, 0)
	var proj: Node3D = load(CENA_PROJETIL).instantiate()
	get_parent().add_child(proj)
	proj.dono = self
	proj.lancar(boca, alvo, clampf(boca.distance_to(alvo) / 13.0, 0.45, 1.1))
	_projeteis.append(proj)
	await get_tree().create_timer(0.8, false).timeout
	if dead:
		return
	visual.tocar(&"flutuar", 0.4)
	_ocupada = false


func _investir_e_bater(j: Node3D) -> void:
	_ocupada = true
	_prox_tapa = _tempo + randf_range(INTERVALO_TAPA.x, INTERVALO_TAPA.y)
	_prox_cuspe = maxf(_prox_cuspe, _tempo + 3.0)
	visual.tocar(&"investida", 0.15)
	som_grito.play()
	# vem rapido ate' o ponto em que a mao do tapa cai em cima dele, ja'
	# virada pro angulo do golpe (ver MAO_DO_TAPA)
	var d := j.global_position - global_position
	d.y = 0.0
	_giro_fixo = atan2(d.x, d.z)
	var fim := j.global_position - Basis(Vector3.UP, _giro_fixo) * MAO_DO_TAPA
	fim = _dentro_da_nave(Vector3(fim.x, global_position.y, fim.z))
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position", fim, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "rotation:y", rotation.y + wrapf(_giro_fixo - rotation.y, -PI, PI), 0.6)
	await t.finished
	if dead:
		_giro_fixo = NAN
		return
	# o aviso: para e acende
	var aviso := create_tween()
	aviso.tween_property(visual, "veias", 1.0, AVISO_DO_TAPA)
	await get_tree().create_timer(AVISO_DO_TAPA, false).timeout
	if dead:
		return
	visual.tocar(&"tapa", 0.1)
	await get_tree().create_timer(IMPACTO_DO_TAPA, false).timeout
	if dead:
		_giro_fixo = NAN
		return
	_impacto_do_tapa()
	await get_tree().create_timer(1.0, false).timeout
	_giro_fixo = NAN
	if dead:
		return
	var volta := create_tween()
	volta.tween_property(visual, "veias", 0.25, 0.8)
	visual.tocar(&"flutuar", 0.5)
	_ocupada = false


func _impacto_do_tapa() -> void:
	som_tapa.play()
	var mao: Vector3 = visual.posicao_do_osso("hand.R")
	var chao := Vector3(mao.x, 0.0, mao.z)
	GlobalUtils.shake_camera(0.5, 0.35)
	GlobalUtils.vibrate_controller(Input, 1.0, 1.0, 0.45)
	criar_poca(chao)
	var j := _jogador()
	if j == null or GlobalEvents.in_cutscene or GlobalEvents.agarrao_rodando:
		return
	var dist := Vector2(j.global_position.x - chao.x, j.global_position.z - chao.z).length()
	if dist < RAIO_DO_TAPA and j.has_method("take_damage"):
		j.take_damage(DANO_TAPA)


func criar_poca(p: Vector3) -> void:
	_pocas = _pocas.filter(func(x): return is_instance_valid(x))
	if _pocas.size() >= MAX_POCAS:
		var velha: Node = _pocas.pop_front()
		if is_instance_valid(velha):
			velha.queue_free()
	var poca: Node3D = load(CENA_POCA).instantiate()
	get_parent().add_child(poca)
	poca.global_position = p
	_pocas.append(poca)


func limpar_gosma() -> void:
	for x in _pocas + _projeteis:
		if is_instance_valid(x):
			x.queue_free()
	_pocas.clear()
	_projeteis.clear()


# ------------------------------------------------------------------ teleporte
## O corpo queima e some (o dissolver dela, com as brasas da borda), e ela
## surge noutro canto — ou perto dele, a RAIO_PERTO, num ponto da nave.
func _teleportar(j: Node3D, perto: bool) -> void:
	_ocupada = true
	_prox_teleporte = _tempo + randf_range(INTERVALO_TELEPORTE.x, INTERVALO_TELEPORTE.y)
	var destino := _lugar_perto(j) if perto else _lugar_longe(j)
	visual.tocar(&"dano", 0.1)
	TELEPORTE.criar(get_parent(), Vector3(global_position.x, 0.0, global_position.z), 2.4, false)
	var some := create_tween().set_parallel(true)
	some.tween_property(visual, "dissolver", 1.0, TEMPO_SUMINDO).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	some.tween_property(visual, "veias", 1.0, TEMPO_SUMINDO * 0.5)
	await some.finished
	if dead:
		return
	_sumida = true
	visual.visible = false
	await get_tree().create_timer(0.35, false).timeout
	if dead:
		return
	global_position = Vector3(destino.x, ALTURA_FLUTUA, destino.z)
	var d := j.global_position - global_position
	rotation.y = atan2(d.x, d.z)
	TELEPORTE.criar(get_parent(), Vector3(destino.x, 0.0, destino.z), 2.4, true)
	await get_tree().create_timer(0.25, false).timeout
	if dead:
		return
	visual.visible = true
	visual.tocar(&"flutuar", 0.3)
	var surge := create_tween().set_parallel(true)
	surge.tween_property(visual, "dissolver", 0.0, TEMPO_SURGINDO).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	surge.tween_property(visual, "veias", 0.25, TEMPO_SURGINDO * 1.5)
	await surge.finished
	_sumida = false
	if dead:
		return
	# surgiu do lado dele: caça (e cospe logo, se surgiu longe)
	if perto:
		_jeito = "caca"
		_fim_do_jeito = _tempo + randf_range(DURACAO_DO_JEITO.x, DURACAO_DO_JEITO.y)
		var dd := global_position - j.global_position
		_angulo = atan2(dd.x, dd.z)
		_prox_tapa = maxf(_prox_tapa, _tempo + 1.5)
	else:
		_prox_cuspe = minf(_prox_cuspe, _tempo + 0.8)
	_ocupada = false


func _lugar_perto(j: Node3D) -> Vector3:
	for _i in 12:
		var ang := randf() * TAU
		var r := randf_range(RAIO_PERTO.x, RAIO_PERTO.y)
		var p := j.global_position + Vector3(sin(ang), 0.0, cos(ang)) * r
		if absf(p.x) <= LIMITE_X and p.z >= LIMITE_Z.x and p.z <= LIMITE_Z.y:
			return p
	return _dentro_da_nave(j.global_position + (global_position - j.global_position).normalized() * RAIO_PERTO.x)


func _lugar_longe(j: Node3D) -> Vector3:
	var melhor := _ponto_da_nave()
	for _i in 8:
		var p := _ponto_da_nave()
		if Vector2(p.x - j.global_position.x, p.z - j.global_position.z).length() > 7.0 \
				and p.distance_to(global_position) > 6.0:
			return p
		melhor = p
	return melhor


# ------------------------------------------------------------------ dano
func take_damage(amount: int) -> void:
	if dead or not _ativa or _sumida:
		return
	current_health = maxi(0, current_health - amount)
	_tiros += 1
	if not som_dano.playing or randf() < 0.25:
		som_dano.stream = load(SONS_DANO[randi() % SONS_DANO.size()])
		som_dano.pitch_scale = randf_range(0.6, 0.8)
		som_dano.play()
	var t := create_tween()
	visual.veias = maxf(visual.veias, 0.8)
	t.tween_property(visual, "veias", 0.25, 0.35)
	_barra()
	if current_health <= 0:
		_morrer()
		return
	if _tiros % 8 == 0 and not _ocupada:
		visual.tocar(&"dano", 0.05)
		await get_tree().create_timer(0.6, false).timeout
		if not dead and not _ocupada:
			visual.tocar(&"flutuar", 0.3)


func _barra() -> void:
	var root := get_tree().root
	var ui := root.get_node_or_null("GlobalEnemyHealthUI")
	if ui == null:
		ui = load("res://scripts/ui/global_enemy_health.gd").new()
		ui.name = "GlobalEnemyHealthUI"
		root.add_child(ui)
	ui.show_health(self, tr(enemy_name), current_health, max_health)


func _morrer() -> void:
	dead = true
	_ativa = false
	som_respira.stop()
	visual.tocar(&"morrer", 0.1)
	morreu.emit()
