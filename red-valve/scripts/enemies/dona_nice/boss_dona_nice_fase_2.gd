extends CharacterBody3D

## A DONA NICE GIGANTE — fase 2 da luta da igreja (5 m, flutua).
##
## Paira em volta do Maycow, sempre de frente pra ele, e alterna:
##   - deixa POCAS de baba por onde passa (queimam e deixam lento, e somem em 2 s);
##   - CUSPE: recolhe a cabeca e cospe uma bola de gosma em arco;
##   - INVESTIDA + TAPA: vem rapido ate' perto dele, PARA um instante (o
##     aviso: as veias acendem) e bate de cima pra baixo com a mao enorme.
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
const INTERVALO_TAPA := Vector2(8.0, 11.5)
const PARADA_DA_INVESTIDA := 3.3
const AVISO_DO_TAPA := 0.5
const RAIO_DO_TAPA := 2.4
const DANO_TAPA := 24
## o quadro do clipe `tapa` em que a mao bate no chao
const IMPACTO_DO_TAPA := 1.05
## Os limites da nave: ela nao atravessa parede nem sai pelo portal.
const LIMITE_X := 5.5
const LIMITE_Z := Vector2(5.5, 31.0)

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

	# orbita em volta dele, trocando de sentido de vez em quando
	if randf() < delta * 0.12:
		_sentido = -_sentido
	_angulo += _sentido * VELOCIDADE / RAIO_ORBITA * delta
	var centro := j.global_position
	var alvo := centro + Vector3(sin(_angulo), 0.0, cos(_angulo)) * RAIO_ORBITA
	alvo = _dentro_da_nave(alvo)
	var p := global_position
	var plano := Vector3(alvo.x - p.x, 0.0, alvo.z - p.z)
	var passo := minf(plano.length(), VELOCIDADE * 1.4 * delta)
	if plano.length() > 0.01:
		p += plano.normalized() * passo
	p.y = ALTURA_FLUTUA + sin(_tempo * 1.3) * 0.22
	global_position = p

	if _tempo > _prox_poca:
		_prox_poca = _tempo + INTERVALO_POCA
		criar_poca(Vector3(p.x, 0.0, p.z) + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)))
	if _tempo > _prox_tapa:
		_investir_e_bater(j)
	elif _tempo > _prox_cuspe:
		_cuspir(j)


func _flutuar_no_lugar() -> void:
	var p := global_position
	p.y = ALTURA_FLUTUA + sin(_tempo * 1.3) * 0.22
	global_position = p


func _encarar(j: Node3D, delta: float) -> void:
	var d := j.global_position - global_position
	rotation.y = rotate_toward(rotation.y, atan2(d.x, d.z), GIRO * delta)


func _dentro_da_nave(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -LIMITE_X, LIMITE_X), p.y, clampf(p.z, LIMITE_Z.x, LIMITE_Z.y))


# ------------------------------------------------------------------ ataques
func _cuspir(j: Node3D) -> void:
	_ocupada = true
	_prox_cuspe = _tempo + randf_range(INTERVALO_CUSPE.x, INTERVALO_CUSPE.y)
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
	# vem rapido ate' ficar a PARADA_DA_INVESTIDA dele
	var d := global_position - j.global_position
	d.y = 0.0
	var fim := j.global_position + d.normalized() * PARADA_DA_INVESTIDA
	fim = _dentro_da_nave(Vector3(fim.x, global_position.y, fim.z))
	var t := create_tween()
	t.tween_property(self, "global_position", fim, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if dead:
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
		return
	_impacto_do_tapa()
	await get_tree().create_timer(1.0, false).timeout
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


# ------------------------------------------------------------------ dano
func take_damage(amount: int) -> void:
	if dead or not _ativa:
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
