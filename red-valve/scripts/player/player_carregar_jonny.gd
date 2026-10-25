extends Node

## O Jonny no hospital (evento da Dona Nice): no colo do Maycow
## (`SaveManager.evento_dona_nice == 4`) ou deitado onde foi deixado (5).
##
## NO COLO ele so' ANDA: o `player.carregando_jonny` trava mira, tiro, recarga,
## corrida, dash, lanterna e atalho, e segura o passo no de quem carrega
## alguem. O corpo INTEIRO do Maycow sai da AnimationTree e toca os clipes da
## cutscene da igreja (`parado_carregando` / `andar_carregando`, biblioteca
## `maycow_clipes.tres`): e' a mesma pose do colo da cutscene, e pra mudar ela
## se mexe no clipe, nao aqui.
##
## O Jonny vai SOBRE AS DUAS MAOS (`AtorIgreja.alvo_nas_maos`, a mesma conta da
## cutscene). Pra mao e menino nunca se descolarem, o AnimationPlayer daqui
## roda em modo MANUAL: este script avanca o clipe e, no mesmo quadro, le' as
## maos e poe o Jonny nelas — sem depender da ordem dos `_process`.
##
## `ui_largar` (B no controle, G no teclado) poe o Jonny no chao (clipe
## `largar_jonny`). Deitado, ele vira um ponto no mapa (`ponto_no_mapa.gd`) e
## ganha o prompt "Pegar Jonny no colo": aceitando, o Maycow se encaixa atras
## dele e o ergue (`pegar_jonny`), e volta tudo pro colo. Onde ele ficou vai
## pro save (estado 5).
##
## Quem cria este no' e' o `hospital.gd`, como filho do player.

signal largou
signal pegou

const CENA_JONNY := "res://scenes/npcs/igreja/jonny.tscn"
const CLIPES_MAYCOW := "res://assets/3d_model/npc/igreja/maycow_clipes.tres"
const SUPORTE := "res://scripts/player/suporte_colo.gd"
const PONTO_NO_MAPA := "res://scripts/ui/ponto_no_mapa.gd"
const MODELO := "maycow_lopes_normal"
const ESQUELETO := "maycow_lopes_normal/Armature/Skeleton3D"
const MALHA := "maycow_lopes_normal/Armature/Skeleton3D/char1"

const PARADO := &"parado_carregando"
const ANDANDO := &"andar_carregando"
const LARGAR := &"largar_jonny"
const PEGAR := &"pegar_jonny"
## Velocidade (m/s) em que o `andar_carregando` casa o passo com o chao (medida
## nos pes do clipe). Andando mais rapido ou mais devagar, o clipe acompanha.
const PASSO_DO_CLIPE := 0.95
## `largar_jonny` (3,2 s): o Jonny encosta no chao em 1,6 s.
const DURACAO_LARGAR := 3.2
const NO_CHAO := 1.6
## `pegar_jonny` (3,3 s): ele sai do chao em 1,7 s e chega ao colo em 3,3 s —
## os tempos da cutscene da igreja.
const DURACAO_PEGAR := 3.3
const SAI_DO_CHAO := 1.7
## Onde o Maycow fica pra pegar: atras do Jonny, de frente, a 62 cm — onde o
## duble para na cutscene da igreja. E quanto leva pra se encaixar ali.
const ATRAS_DO_JONNY := 0.62
const ENCAIXE := 0.35
## Ate' que distancia (no chao) aparece o "Pegar Jonny no colo".
const RAIO_PEGAR := 1.5

var player: CharacterBody3D
var jonny: Node3D
## Comeca com o Jonny deitado no lugar do save (estado 5), e nao no colo.
var comecar_no_chao := false

var _modelo: Node3D
var _arvore: AnimationTree
var _ap: AnimationPlayer
var _suporte: Node3D
var _ponto: Node
## "colo", "chao", "largando", "pegando".
var _modo := ""
## 1 = Jonny nas maos, 0 = no `_base` (o chao). No meio, misturado.
var _peso_maos := 1.0
var _base := Transform3D.IDENTITY
var _perto := false


func _ready() -> void:
	player = get_parent()
	if not GlobalEvents.is_maycow_normal:
		return
	_modelo = player.get_node_or_null(MODELO) as Node3D
	var sk := player.get_node_or_null(ESQUELETO) as Skeleton3D
	var malha := player.get_node_or_null(MALHA) as Node3D
	if _modelo == null or sk == null or malha == null:
		push_warning("player_carregar_jonny: rig do Maycow normal nao encontrado")
		return
	_arvore = _modelo.get_node_or_null("AnimationTree") as AnimationTree
	_suporte = load(SUPORTE).new()
	_suporte.name = "SuporteColo"
	_suporte.esqueleto = sk
	malha.add_child(_suporte)
	_ap = AnimationPlayer.new()
	_ap.name = "AnimColo"
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_modelo.add_child(_ap)
	_ap.add_animation_library("", load(CLIPES_MAYCOW))

	jonny = load(CENA_JONNY).instantiate()
	jonny.clipe_inicial = &"deitado" if comecar_no_chao else &"no_colo"
	jonny.sangue = 0.45
	player.get_parent().add_child(jonny)
	if comecar_no_chao and SaveManager.jonny_no_hospital.size() == 4:
		var p: Array = SaveManager.jonny_no_hospital
		jonny.global_position = Vector3(p[0], p[1], p[2])
		jonny.rotation.y = p[3]
		_no_chao()
	else:
		_no_colo()
		_mostrar_dica()


func _mostrar_dica() -> void:
	var chave := "AVISO_LARGAR_JONNY_CONTROLE" if GlobalEvents.usando_controle \
		else "AVISO_LARGAR_JONNY_TECLADO"
	GlobalUtils.show_center_message("largar_jonny", tr(chave), 16)


func _process(delta: float) -> void:
	if _ap == null or _modo == "":
		return
	if _modo == "chao":
		_checar_perto()
		return
	# todo quadro, e nao uma vez: os componentes das armas nascem depois deste
	# no' (o player os cria no proprio _ready, um quadro adiante)
	_suspender_armas(true)
	if _modo == "colo":
		_escolher_passo()
	_ap.advance(delta)
	_jonny_nas_maos()
	if _modo == "colo" and not GlobalEvents.in_cutscene \
			and Input.is_action_just_pressed("ui_largar") and player.is_on_floor():
		_largar()


# ==============================================================================
# NO COLO
# ==============================================================================
func _no_colo() -> void:
	player.carregando_jonny = true
	_suspender_armas(true)
	_corpo_nos_clipes(true)
	_ap.speed_scale = 1.0
	_ap.play(PARADO, 0.3)
	jonny.tocar(&"no_colo", 0.3)
	_peso_maos = 1.0
	_modo = "colo"


## Parado ou andando, no ritmo do chao. De costas o passo roda ao contrario.
func _escolher_passo() -> void:
	var v := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var rapidez := v.length()
	var clipe := ANDANDO if rapidez > 0.15 else PARADO
	if _ap.current_animation != String(clipe):
		_ap.play(clipe, 0.3)
	if clipe == ANDANDO:
		var de_costas := v.dot(-player.global_basis.z) < -0.3 * rapidez
		_ap.speed_scale = clampf(rapidez / PASSO_DO_CLIPE, 0.6, 1.6) * (-1.0 if de_costas else 1.0)
	else:
		_ap.speed_scale = 1.0


func _jonny_nas_maos() -> void:
	var alvo: Transform3D = jonny.alvo_nas_maos(_suporte)
	jonny.global_transform = alvo if _peso_maos >= 1.0 else _base.interpolate_with(alvo, _peso_maos)


## A AnimationTree e o colo nao dividem o esqueleto: com o Jonny nos bracos o
## corpo todo e' dos clipes daqui.
func _corpo_nos_clipes(sim: bool) -> void:
	if _arvore:
		_arvore.active = not sim
	if not sim:
		_ap.stop()


func _suspender_armas(sim: bool) -> void:
	for caminho in ["PlayerGunHold", "PlayerShotgunHold"]:
		var h := player.get_node_or_null(ESQUELETO + "/" + caminho)
		if h and "suspensa" in h:
			h.suspensa = sim


# ==============================================================================
# LARGAR
# ==============================================================================
func _largar() -> void:
	_modo = "largando"
	GlobalUtils.hide_center_message("largar_jonny")
	player.cutscene_set_player_control(false)
	player.velocity = Vector3.ZERO

	# o chao em frente a ele, onde o Jonny fica deitado (atravessado)
	var frente := (_suporte.global_basis.z * Vector3(1, 0, 1)).normalized()
	var chao := _chao_em(player.global_position + frente * 0.72)
	var giro := Basis.looking_at(-frente, Vector3.UP) * Basis(Vector3.UP, deg_to_rad(90.0))
	_base = Transform3D(giro, chao)
	_peso_maos = 1.0
	_ap.speed_scale = 1.0
	_ap.play(LARGAR, 0.2)
	jonny.tocar(&"sendo_largado", 0.2)
	var t := create_tween()
	t.tween_property(self, "_peso_maos", 0.0, NO_CHAO).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(DURACAO_LARGAR, false).timeout

	jonny.global_transform = _base
	jonny.tocar(&"deitado", 0.4)
	_corpo_nos_clipes(false)
	_suspender_armas(false)
	player.carregando_jonny = false
	player.cutscene_set_player_control(true)
	SaveManager.evento_dona_nice = 5
	SaveManager.jonny_no_hospital = [jonny.global_position.x, jonny.global_position.y,
		jonny.global_position.z, jonny.global_rotation.y]
	SaveManager.save_game()
	_no_chao()
	largou.emit()


func _chao_em(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 3.0)
	q.collision_mask = 2
	q.exclude = [player.get_rid()]
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return Vector3(p.x, player.global_position.y - 1.0, p.z)
	return r["position"]


# ==============================================================================
# NO CHAO
# ==============================================================================
func _no_chao() -> void:
	_modo = "chao"
	_perto = false
	_ponto = load(PONTO_NO_MAPA).new()
	_ponto.name = "ponto_no_mapa"
	_ponto.chave = "MAP_POI_JONNY"
	_ponto.tipo = "pessoa"
	jonny.add_child(_ponto)


func _checar_perto() -> void:
	var d := jonny.global_position - player.global_position
	var perto := Vector2(d.x, d.z).length() < RAIO_PEGAR and absf(d.y) < 1.8 \
		and not GlobalEvents.in_cutscene and not get_tree().paused
	if perto != _perto:
		_perto = perto
		if perto:
			GlobalUtils.show_center_message("pegar_jonny", tr("PROMPT_PICK_JONNY_UP"), 18)
		else:
			GlobalUtils.hide_center_message("pegar_jonny")
	if perto and Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
		_pegar()


# ==============================================================================
# PEGAR DE VOLTA
# ==============================================================================
func _pegar() -> void:
	_modo = "pegando"
	_perto = false
	GlobalUtils.hide_center_message("pegar_jonny")
	if is_instance_valid(_ponto):
		_ponto.queue_free()
	player.cutscene_set_player_control(false)
	player.velocity = Vector3.ZERO
	player.carregando_jonny = true
	_suspender_armas(true)
	_base = jonny.global_transform
	_peso_maos = 0.0

	# Encaixa atras dele, de frente, como o duble na cutscene: o Jonny deitado
	# e' o colo girado 90 graus, entao a frente de quem pega sai do giro dele.
	var colo := jonny.global_basis.orthonormalized() * Basis(Vector3.UP, deg_to_rad(-90.0))
	var frente := (colo.z * Vector3(1, 0, 1)).normalized()
	var giro_alvo := atan2(-frente.x, -frente.z)
	# o corpo que se ve' nao fica na origem do player: o desvio gira junto
	var desvio := player.global_basis.inverse() * (_modelo.global_position - player.global_position)
	desvio.y = 0.0
	var corpo := jonny.global_position - frente * ATRAS_DO_JONNY
	var pos_alvo := corpo - Basis(Vector3.UP, giro_alvo) * desvio
	pos_alvo.y = player.global_position.y
	var giro_ini := player.rotation.y
	var t := create_tween().set_parallel(true)
	t.tween_property(player, "global_position", pos_alvo, ENCAIXE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(k: float): player.rotation.y = lerp_angle(giro_ini, giro_alvo, k),
		0.0, 1.0, ENCAIXE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	_corpo_nos_clipes(true)
	_ap.speed_scale = 1.0
	_ap.play(PEGAR, 0.25)
	jonny.tocar(&"sendo_erguido", 0.3)
	var ergue := create_tween()
	ergue.tween_interval(SAI_DO_CHAO)
	ergue.tween_property(self, "_peso_maos", 1.0, DURACAO_PEGAR - SAI_DO_CHAO) \
		.set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(DURACAO_PEGAR, false).timeout

	SaveManager.evento_dona_nice = 4
	SaveManager.save_game()
	_no_colo()
	player.cutscene_set_player_control(true)
	_mostrar_dica()
	pegou.emit()
