extends CharacterBody3D

## A DONA NICE MONSTRO — fase 1 da luta da igreja.
##
## Anda DEVAGAR atras do Maycow (o andar cambaleante da captura, no ritmo do
## pe'), e se chegar perto AGARRA PELO PESCOCO: a cena de primeira pessoa do
## agarrao (`player_grab.gd`, ramo "pescoco") — os olhos dele presos entre as
## maos dela enquanto ela morde, babando gosma verde na tela. Morre com
## ~30 tiros de pistola (a vida e' medida no dano da pistola do jogador, nao
## escrita aqui — se a pistola mudar de dano, continuam sendo 30 tiros).
##
## Ela NAO tem AnimationTree: o corpo e' o `AtorIgreja` (`visual`), que toca
## os clipes da biblioteca editavel `dona_nice_monster_clipes.tres`. Pra mudar
## um movimento, e' la' no AnimationPlayer, nao aqui.
##
## Frente = +Z (a mesma convencao dos outros inimigos e do agarrao).

signal morreu

const TIROS_PARA_MORRER := 30
const VELOCIDADE := 0.78          # m/s — o andar_ dela a 0,7 da captura
const GIRO := 2.2                  # rad/s
const ALCANCE_AGARRAO := 1.55
const ESPERA_AGARRAO := 4.5
## A cada quantos tiros ela cambaleia (o clipe `dano`). Todo tiro
## cambaleando vira um boneco travado; nenhum vira uma esponja.
const TIROS_POR_CAMBALEIO := 5
const GRAVIDADE := 18.0

@export var enemy_name: String = "IGR_BOSS_NOME"
## Lido pelo agarrao (player_grab.gd).
var tipo_agarrao := "pescoco"
## O agarrao pelo pescoco (lidos pelo player_grab.gd). A que distancia do
## Maycow ela para pra ter as maos no pescoco dele (as maos do `mordendo` ficam
## ~0,55 m a frente do corpo dela), quanto tempo segura, e os instantes de cada
## mordida — os mesmos do tranco de pescoco do clipe `mordendo`, que comeca
## em INICIO_MORDENDO e morde duas vezes por segundo.
var distancia_do_agarrao := 0.63
var duracao_do_agarrao := 2.45
var mordidas_do_agarrao := [0.43, 0.93, 1.43, 1.93]
## Quanto ela recua cambaleando quando ele se solta.
const RECUO_AO_SOLTAR := 1.35
const INICIO_MORDENDO := 0.3
var altura := 1.82
var cutscene_mode := false
var dead := false

var max_health: int = 300
var current_health: int = 300

var _ativa := false
var _cambaleando := 0.0
var _proximo_agarrao := 0.0
var _tiros := 0
var _agarrada := false
var _ultimo_clipe := &""

@onready var visual: Node3D = $visual
@onready var som_passos: AudioStreamPlayer3D = $sons/passos
@onready var som_dano: AudioStreamPlayer3D = $sons/dano
@onready var som_respira: AudioStreamPlayer3D = $sons/respira
@onready var som_mordida: AudioStreamPlayer3D = $sons/mordida
@onready var som_baba: AudioStreamPlayer3D = $sons/baba
@onready var baba: GPUParticles3D = $baba

const SONS_DANO := ["res://assets/sounds/igreja/dano_monstro_1.ogg",
	"res://assets/sounds/igreja/dano_monstro_2.ogg",
	"res://assets/sounds/igreja/dano_monstro_3.ogg"]
const SONS_MORDIDA := ["res://assets/sounds/igreja/mordida_1.ogg",
	"res://assets/sounds/igreja/mordida_2.ogg", "res://assets/sounds/igreja/mordida_3.ogg"]


func _ready() -> void:
	add_to_group("enemies")
	var jogador := _jogador()
	var dano_pistola := 10
	if jogador and "damage_pistol" in jogador:
		dano_pistola = int(jogador.damage_pistol)
	max_health = TIROS_PARA_MORRER * dano_pistola
	current_health = max_health
	_tocar(&"parado")


## Liga a caca (chamado pela igreja quando a cutscene termina).
func comecar() -> void:
	_ativa = true
	som_respira.play()


func _jogador() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _tocar(clipe: StringName, mistura := 0.3, vel := 1.0) -> void:
	if _ultimo_clipe == clipe and visual.anim.is_playing():
		return
	_ultimo_clipe = clipe
	visual.tocar(clipe, mistura, vel)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0

	if dead or not _ativa or cutscene_mode or _agarrada:
		move_and_slide()
		return

	var jogador := _jogador()
	if jogador == null:
		move_and_slide()
		return

	if _cambaleando > 0.0:
		_cambaleando -= delta
		move_and_slide()
		return

	var para := jogador.global_position - global_position
	para.y = 0.0
	var dist := para.length()

	# vira devagar pra ele (frente = +Z)
	var alvo_giro := atan2(para.x, para.z)
	rotation.y = rotate_toward(rotation.y, alvo_giro, GIRO * delta)

	if dist < ALCANCE_AGARRAO and Time.get_ticks_msec() * 0.001 > _proximo_agarrao:
		_tentar_agarrar(jogador)
	elif dist > 0.9:
		var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		velocity.x = frente.x * VELOCIDADE
		velocity.z = frente.z * VELOCIDADE
		_tocar(&"andar")
		if not som_passos.playing:
			som_passos.play()
	else:
		_tocar(&"parado")
	move_and_slide()


func _tentar_agarrar(jogador: Node3D) -> void:
	if not jogador.has_method("grab_from_touch"):
		return
	_proximo_agarrao = Time.get_ticks_msec() * 0.001 + ESPERA_AGARRAO
	jogador.grab_from_touch(self)


## Gancho do player_grab: o bote. Ela levanta os bracos (comeco do `agarrar`)
## e fecha as maos no pescoco dele (`mordendo`); as mordidas caem nos instantes
## de `mordidas_do_agarrao`, que o agarrao usa pro dano e pro tranco da camera.
func agarrao_atacar() -> void:
	_agarrada = true
	_tocar(&"agarrar", 0.1)
	await get_tree().create_timer(INICIO_MORDENDO, false).timeout
	if dead or not _agarrada:
		return
	_tocar(&"mordendo", 0.2)
	baba.amount_ratio = 1.0
	som_baba.play()
	_tela_de_gosma(0.85, 0.5)
	var antes := INICIO_MORDENDO
	for i in mordidas_do_agarrao.size():
		await get_tree().create_timer(mordidas_do_agarrao[i] - antes, false).timeout
		antes = mordidas_do_agarrao[i]
		if dead or not _agarrada:
			break
		som_mordida.stream = load(SONS_MORDIDA[i % SONS_MORDIDA.size()])
		som_mordida.play()


## Onde esta' o pescoco do Maycow: entre as maos dela.
func ponto_do_agarrao() -> Vector3:
	return (visual.posicao_do_osso("hand.L") + visual.posicao_do_osso("hand.R")) * 0.5


## Pra onde ele olha enquanto ela morde: o rosto dela (um pouco a frente e
## acima do osso da cabeca, que fica na nuca).
func cabeca_do_agarrao() -> Vector3:
	return visual.posicao_do_osso("head") + global_basis.z * 0.08 + Vector3.UP * 0.07


## Ele se soltou: ela cambaleia pra tras (o tranco do `dano`) e a camera so'
## volta pra 3a pessoa com ela ja' fora da pose de agarrar.
func agarrao_soltou() -> void:
	if not _agarrada:
		return
	_agarrada = false
	baba.amount_ratio = 0.35
	_ultimo_clipe = &""
	_tocar(&"dano", 0.15)
	_cambaleando = 1.1
	var j := _jogador()
	if j:
		var para_tras := global_position - j.global_position
		para_tras.y = 0.0
		if para_tras.length_squared() > 0.0001:
			var fim := j.global_position + para_tras.normalized() * RECUO_AO_SOLTAR
			fim.y = global_position.y
			var t := create_tween()
			t.tween_property(self, "global_position", fim, 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# a gosma escorre e some devagar — e' o que fica de lembranca
	_tela_de_gosma(0.0, 3.5)


func _tela_de_gosma(valor: float, segundos: float) -> void:
	var cena := get_tree().get_first_node_in_group("cena_dona_nice")
	if cena == null:
		return
	var t := create_tween()
	t.tween_property(cena, "gosma_na_tela", valor, segundos)


func take_damage(amount: int) -> void:
	if dead or not _ativa:
		return
	current_health = maxi(0, current_health - amount)
	_tiros += 1
	if not som_dano.playing or randf() < 0.3:
		som_dano.stream = load(SONS_DANO[randi() % SONS_DANO.size()])
		som_dano.pitch_scale = randf_range(0.85, 1.1)
		som_dano.play()
	_piscar_carne()
	_barra()
	if current_health <= 0:
		_morrer()
		return
	if _tiros % TIROS_POR_CAMBALEIO == 0 and not _agarrada:
		_ultimo_clipe = &""
		_tocar(&"dano", 0.08)
		_cambaleando = 0.85


func _piscar_carne() -> void:
	var t := create_tween()
	visual.veias = 1.0
	t.tween_property(visual, "veias", 0.35, 0.4)


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
	som_passos.stop()
	som_respira.stop()
	baba.emitting = false
	_ultimo_clipe = &""
	_tocar(&"morrer", 0.15)
	morreu.emit()
