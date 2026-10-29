extends CharacterBody3D

## GRIZZOLITO MAROLIS — o integrante dos Anti-Lopes que a Dona Nice chama na
## quadra da escola (Capítulo 1).
##
## TRÊS FORMAS, um corpo só (os três modelos são filhos e só um aparece):
##
##  0  o homem de terno. É a forma da QUADRA, contra o Maycow normal: anda,
##     corre, soca (jab + direto), chuta e dá voadora até matar. Bala não o
##     derruba — a vida para em PISO_NA_ESCOLA. O jeito é o amuleto: levá-lo
##     pra arena (LB / V), como qualquer inimigo da rua;
##  1  chegando na ARENA ele vira o primeiro monstro (o parasita tomou o lado
##     esquerdo, a garra até o joelho). Morrendo nessa forma...
##  2  ...vira o segundo (o rosto já é do parasita). Esta é a que morre de
##     verdade: só aqui `dead` liga, o `died` sai e a arena encerra a luta.
##
## O que a arena e o amuleto esperam dele é o mesmo contrato dos inimigos
## comuns (`enemy.gd`): grupo "enemies", `dead`, sinal `died`, `cutscene_mode`,
## `player` e `take_damage`.
##
## Os clipes saem de `tools/blender/escola_cap1/` (mesmos nomes nas três
## formas). Frente = +Z.

signal died
signal morreu

const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")

## Por forma: vida, velocidades, dano de cada golpe, altura da cápsula.
const FORMAS := [
	{"vida": 260, "anda": 1.7, "corre": 4.6, "soco": 9, "chute": 16, "voadora": 20,
		"altura": 1.82, "raio": 0.36, "nome": "GRIZZOLITO_NOME"},
	{"vida": 450, "anda": 1.5, "corre": 4.2, "soco": 14, "chute": 22, "voadora": 26,
		"altura": 2.30, "raio": 0.48, "nome": "GRIZZOLITO_MONSTRO_1_NOME"},
	{"vida": 620, "anda": 1.4, "corre": 4.8, "soco": 16, "chute": 25, "voadora": 30,
		"altura": 2.50, "raio": 0.50, "nome": "GRIZZOLITO_MONSTRO_2_NOME"},
]
## Na escola a vida para aqui: quem derruba o Grizzolito é a arena.
const PISO_NA_ESCOLA := 0.30
const GRAVIDADE := 20.0
const GIRO := 6.0
## Distâncias de cada golpe (m).
const ALCANCE_SOCO := 1.7
const ALCANCE_CHUTE := 2.2
const VOADORA_MIN := 4.0
const VOADORA_MAX := 8.5
## Quanto a voadora leva o corpo pra frente, e entre que instantes do clipe.
const VOADORA_SALTO := 5.5
const VOADORA_JANELA := Vector2(0.30, 0.90)
## Instantes de acerto (s), tirados dos clipes.
const SOCO_ACERTOS := [0.16, 0.50]
const CHUTE_ACERTO := 0.42
## Folga entre um golpe e o próximo.
const RESPIRO_ENTRE_GOLPES := Vector2(0.45, 1.1)
const RECUO_NO_JOGADOR := 2.6
## Na arena o empurrão é bem menor: ela é uma plataforma com beirada, e o
## empurrão cheio da quadra jogava o Maycow lá embaixo.
const RECUO_NA_ARENA := 0.4

@export var enemy_name: String = "GRIZZOLITO_NOME"

var player: Node3D
var cutscene_mode: bool = false
var dead: bool = false
var max_health: int = 260
var current_health: int = 260
## Tudo parado até a cutscene da quadra soltar ele (`comecar`).
var ativo: bool = false

var forma: int = 0
var _modelos: Array[Node3D] = []
var _anim: AnimationPlayer
var _ocupado := false
var _respiro := 0.0
var _clipe := &""
var _na_arena := false
var _avisou_amuleto := false
var _acertos_no_piso := 0
var _rel_voadora := 0.0

@onready var forma_colisao: CollisionShape3D = $forma
@onready var som_passos: AudioStreamPlayer3D = $sons/passos
@onready var som_golpe: AudioStreamPlayer3D = $sons/golpe
@onready var som_impacto: AudioStreamPlayer3D = $sons/impacto
@onready var som_voz: AudioStreamPlayer3D = $sons/voz
@onready var som_dano: AudioStreamPlayer3D = $sons/dano

const SONS_DANO := ["res://assets/sounds/igreja/dano_monstro_1.ogg",
	"res://assets/sounds/igreja/dano_monstro_2.ogg", "res://assets/sounds/igreja/dano_monstro_3.ogg"]


func _ready() -> void:
	add_to_group("enemies")
	for nome in ["forma_humano", "forma_monstro_1", "forma_monstro_2"]:
		var m := get_node(nome) as Node3D
		_modelos.append(m)
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for clipe in ["parado", "andar", "correr"]:
				if ap.has_animation(clipe):
					ap.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR
	_trocar_forma(0)
	player = get_tree().get_first_node_in_group("player")


func comecar() -> void:
	ativo = true
	_respiro = 0.6


# ==============================================================================
# FORMAS
# ==============================================================================

func _trocar_forma(f: int) -> void:
	forma = f
	for i in _modelos.size():
		_modelos[i].visible = i == f
	_anim = _modelos[f].find_child("AnimationPlayer", true, false) as AnimationPlayer
	var dados: Dictionary = FORMAS[f]
	max_health = int(dados["vida"])
	current_health = max_health
	enemy_name = String(dados["nome"])
	var capsula := forma_colisao.shape as CapsuleShape3D
	if capsula:
		capsula = capsula.duplicate() as CapsuleShape3D
		capsula.height = float(dados["altura"])
		capsula.radius = float(dados["raio"])
		forma_colisao.shape = capsula
		forma_colisao.position.y = float(dados["altura"]) * 0.5
	_clipe = &""
	_tocar(&"parado", 0.0)


func _tocar(clipe: StringName, mistura: float = 0.2, vel: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(clipe):
		return
	if _clipe == clipe and _anim.is_playing():
		return
	_clipe = clipe
	_anim.play(clipe, mistura, vel)


## Chamado uma vez, quando a arena solta a luta: o homem vira o primeiro monstro.
func _chegou_na_arena() -> void:
	_na_arena = true
	if forma == 0:
		await _transformar_em(1)


## A transformação: o corpo se contorce (as mãos na cabeça), fumaça, ossos
## estalando, um clarão vermelho — e o próximo corpo surge rugindo.
func _transformar_em(f: int) -> void:
	_ocupado = true
	velocity = Vector3.ZERO
	som_passos.stop()
	_clipe = &""
	_tocar(&"transformar", 0.15)
	_som(som_voz, "res://assets/sounds/igreja/grito_transformacao.ogg", 0.95)
	_som(som_dano, "res://assets/sounds/igreja/transformacao_ossos.ogg", 1.0)
	GlobalUtils.shake_camera(1.2, 0.25)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.12, 0.08)
	luz.omni_range = 9.0
	luz.light_energy = 0.0
	luz.position = Vector3.UP * 1.4
	add_child(luz)
	var t := create_tween()
	t.tween_property(luz, "light_energy", 6.0, 1.6)
	for i in 4:
		Realidade.nuvem(get_parent(), global_position + Vector3.UP * (0.6 + i * 0.4), 1.5 + i * 0.3, false)
		await get_tree().create_timer(0.45, false).timeout
		if not is_inside_tree():
			return
	_trocar_forma(f)
	var corpo := _modelos[f]
	corpo.scale = Vector3.ONE * 0.75
	create_tween().tween_property(corpo, "scale", Vector3.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Realidade.nuvem(get_parent(), global_position + Vector3.UP * 1.2, 3.0, false)
	_som(som_voz, "res://assets/sounds/igreja/rugido_monstro.ogg", 0.85 if f == 1 else 0.7)
	GlobalUtils.shake_camera(0.8, 0.35)
	_clipe = &""
	_tocar(&"rugido", 0.1)
	var apaga := create_tween()
	apaga.tween_property(luz, "light_energy", 0.0, 1.2)
	apaga.tween_callback(luz.queue_free)
	_barra(true)
	await get_tree().create_timer(2.4, false).timeout
	_ocupado = false
	_respiro = 0.3


# ==============================================================================
# IA
# ==============================================================================

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	else:
		velocity.y = 0.0

	if dead or cutscene_mode or not ativo:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not _na_arena and _esta_na_arena():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_chegou_na_arena()
		return

	if not is_instance_valid(player) or not player.is_inside_tree() \
			or not player.is_in_group("player"):
		player = get_tree().get_first_node_in_group("player")

	if _ocupado:
		# a voadora anda pra frente sozinha; o resto fica no lugar
		if _rel_voadora > 0.0:
			_rel_voadora -= delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return

	if player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		_tocar(&"parado")
		move_and_slide()
		return

	var para := player.global_position - global_position
	para.y = 0.0
	var dist := para.length()
	var alvo_giro := atan2(para.x, para.z)
	rotation.y = rotate_toward(rotation.y, alvo_giro, GIRO * delta)
	var de_frente := absf(angle_difference(rotation.y, alvo_giro)) < 0.5

	_respiro -= delta
	var dados: Dictionary = FORMAS[forma]
	if _respiro <= 0.0 and de_frente and not _jogador_intocavel():
		if dist <= ALCANCE_SOCO:
			_golpe_soco()
			return
		if dist <= ALCANCE_CHUTE and randf() < 0.55:
			_golpe_chute()
			return
		if dist >= VOADORA_MIN and dist <= VOADORA_MAX and randf() < 0.012 + delta:
			_golpe_voadora()
			return

	var vel := 0.0
	if dist > ALCANCE_SOCO * 0.85:
		vel = float(dados["corre"]) if dist > 5.0 else float(dados["anda"])
	var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	velocity.x = frente.x * vel
	velocity.z = frente.z * vel
	if vel > 3.0:
		_tocar(&"correr", 0.2)
	elif vel > 0.0:
		_tocar(&"andar", 0.2)
	else:
		_tocar(&"parado", 0.25)
	if vel > 0.0 and not som_passos.playing:
		som_passos.pitch_scale = 1.25 if vel > 3.0 else 1.0
		som_passos.play()
	elif vel == 0.0:
		som_passos.stop()
	move_and_slide()


func _esta_na_arena() -> bool:
	var cena := get_tree().current_scene
	return cena != null and cena.scene_file_path.contains("battlefield") \
		and not GlobalEvents.is_maycow_normal


func _jogador_intocavel() -> bool:
	return player.get("invulnerable") == true or GlobalEvents.in_cutscene \
		or player.get("is_teleporting_enemies") == true


# ==============================================================================
# GOLPES
# ==============================================================================

func _golpe_soco() -> void:
	_comecar_golpe(&"soco")
	_som(som_voz, "res://assets/sounds/enemies/inimigo_1_voice_attack.mp3", randf_range(0.9, 1.1))
	for i in SOCO_ACERTOS.size():
		var espera: float = SOCO_ACERTOS[i] - (SOCO_ACERTOS[i - 1] if i > 0 else 0.0)
		await get_tree().create_timer(espera, false).timeout
		if not _golpe_vale():
			return
		_som(som_golpe, "res://assets/sounds/player/dash_effect.mp3", randf_range(1.3, 1.6))
		_tentar_acertar(ALCANCE_SOCO + 0.3, int(FORMAS[forma]["soco"]), 1.2)
	await _fim_do_golpe(0.85 - SOCO_ACERTOS[-1])


func _golpe_chute() -> void:
	_comecar_golpe(&"chute")
	await get_tree().create_timer(CHUTE_ACERTO, false).timeout
	if not _golpe_vale():
		return
	_som(som_golpe, "res://assets/sounds/player/dash_effect.mp3", 1.0)
	_tentar_acertar(ALCANCE_CHUTE + 0.3, int(FORMAS[forma]["chute"]), RECUO_NO_JOGADOR)
	await _fim_do_golpe(0.55)


## O salto com a perna esticada: o corpo vai VOADORA_SALTO metros pra frente
## enquanto o clipe está no ar, e acerta quem estiver no caminho.
func _golpe_voadora() -> void:
	_comecar_golpe(&"voadora")
	_som(som_voz, "res://assets/sounds/enemies/inimigo_1_voice_attack.mp3", 0.8)
	await get_tree().create_timer(VOADORA_JANELA.x, false).timeout
	if not _golpe_vale():
		return
	var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var dur := VOADORA_JANELA.y - VOADORA_JANELA.x
	var dist := VOADORA_SALTO
	if is_instance_valid(player):
		var d := player.global_position - global_position
		d.y = 0.0
		dist = clampf(d.length() + 0.4, 2.0, VOADORA_SALTO + 1.5)
	velocity.x = frente.x * dist / dur
	velocity.z = frente.z * dist / dur
	_rel_voadora = dur
	_som(som_golpe, "res://assets/sounds/player/dash_effect.mp3", 0.8)
	var acertou := false
	var t := 0.0
	while t < dur:
		await get_tree().physics_frame
		if not _golpe_vale():
			return
		t += get_physics_process_delta_time()
		if not acertou and _tentar_acertar(1.6, int(FORMAS[forma]["voadora"]), RECUO_NO_JOGADOR + 1.0):
			acertou = true
	_rel_voadora = 0.0
	await _fim_do_golpe(0.45)


func _comecar_golpe(clipe: StringName) -> void:
	_ocupado = true
	velocity.x = 0.0
	velocity.z = 0.0
	som_passos.stop()
	_clipe = &""
	_tocar(clipe, 0.08)


func _golpe_vale() -> bool:
	return is_inside_tree() and not dead and _ocupado


func _fim_do_golpe(resto: float) -> void:
	await get_tree().create_timer(maxf(resto, 0.05), false).timeout
	if dead:
		return
	_ocupado = false
	_respiro = randf_range(RESPIRO_ENTRE_GOLPES.x, RESPIRO_ENTRE_GOLPES.y)


## Acerta se o jogador está no alcance e na frente dele. Devolve se acertou.
func _tentar_acertar(alcance: float, dano: int, recuo: float) -> bool:
	if not is_instance_valid(player) or _jogador_intocavel():
		return false
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() > alcance:
		return false
	var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	if d.length() > 0.5 and frente.dot(d.normalized()) < 0.35:
		return false
	_som(som_impacto, "res://assets/sounds/igreja/cabecada.ogg", randf_range(0.85, 1.1))
	GlobalUtils.shake_camera(0.25, 0.3)
	GlobalUtils.vibrate_controller(null, 0.7, 0.6, 0.25)
	_empurrar(d.normalized() if d.length() > 0.01 else frente,
		recuo * (RECUO_NA_ARENA if _na_arena else 1.0))
	if player.has_method("take_damage"):
		player.take_damage(dano)
	return true


## Empurra o jogador pra trás, parando antes da parede (o tween ignora
## colisão — mesma conta do `enemy._acertar_player`).
func _empurrar(direcao: Vector3, metros: float) -> void:
	var destino: Vector3 = player.global_position + direcao * metros
	if player is PhysicsBody3D:
		var espaco := get_world_3d().direct_space_state
		var altura := Vector3(0, 1.0, 0)
		var consulta := PhysicsRayQueryParameters3D.create(player.global_position + altura,
			destino + altura, (player as PhysicsBody3D).collision_mask)
		consulta.exclude = [(player as PhysicsBody3D).get_rid(), get_rid()]
		var acerto := espaco.intersect_ray(consulta)
		if acerto:
			var livre := maxf(player.global_position.distance_to(acerto.position - altura) - 0.4, 0.0)
			destino = player.global_position + direcao * livre
	var tw := create_tween()
	tw.tween_property(player, "global_position", destino, 0.2).set_trans(Tween.TRANS_QUAD)


# ==============================================================================
# DANO
# ==============================================================================

func take_damage(amount) -> void:
	if dead or not ativo or (_ocupado and _clipe == &"transformar"):
		return
	var dano := int(amount)
	if not _na_arena:
		# na quadra ele aguenta tudo: a vida para no piso e quem resolve e' a arena
		var piso := int(ceil(max_health * PISO_NA_ESCOLA))
		current_health = maxi(piso, current_health - dano)
		if current_health <= piso:
			_acertos_no_piso += 1
			if _acertos_no_piso >= 3 and not _avisou_amuleto:
				_avisou_amuleto = true
				GlobalUtils.show_center_message("grizzolito_amuleto",
					tr("AVISO_GRIZZOLITO_AMULETO_PAD" if GlobalEvents.usando_controle
						else "AVISO_GRIZZOLITO_AMULETO_KEY"), 20, 5.0)
	else:
		current_health = maxi(0, current_health - dano)
	if is_instance_valid(player) and player.has_method("add_cogblade_power"):
		player.add_cogblade_power(float(dano), global_position + Vector3.UP * 1.4)
	if not som_dano.playing or randf() < 0.3:
		_som(som_dano, SONS_DANO[randi() % SONS_DANO.size()], randf_range(0.8, 1.05))
	_barra()
	if current_health <= 0 and _na_arena:
		if forma < 2:
			_transformar_em(forma + 1)
		else:
			_morrer()


## `forma_nova`: a barra só troca nome e máximo quando o inimigo muda, e na
## transformação o corpo é o mesmo — então ela é avisada.
func _barra(forma_nova: bool = false) -> void:
	var root := get_tree().root
	var ui := root.get_node_or_null("GlobalEnemyHealthUI")
	if ui == null:
		ui = load("res://scripts/ui/global_enemy_health.gd").new()
		ui.name = "GlobalEnemyHealthUI"
		root.add_child(ui)
	if forma_nova:
		ui.set("current_enemy", null)
	ui.show_health(self, tr(enemy_name), current_health, max_health)


func _morrer() -> void:
	dead = true
	ativo = false
	_ocupado = true
	som_passos.stop()
	_clipe = &""
	_tocar(&"morrer", 0.1)
	_som(som_voz, "res://assets/sounds/igreja/morte_monstro.ogg", 0.8)
	SaveManager.add_iron_rusks(12)
	Eventos.concluir(Eventos.CAP1_GRIZZOLITO_DERROTADO)
	died.emit()
	morreu.emit()
	set_collision_layer_value(3, false)


func _som(tocador: AudioStreamPlayer3D, caminho: String, tom: float) -> void:
	if tocador == null or not ResourceLoader.exists(caminho):
		return
	tocador.stream = load(caminho)
	tocador.pitch_scale = tom
	tocador.play()
