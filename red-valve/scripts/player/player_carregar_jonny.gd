extends Node

## O Maycow com o Jonny no colo, jogando (evento da Dona Nice, dentro do
## hospital — `SaveManager.evento_dona_nice == 4`).
##
## Ele so' ANDA: o `player.carregando_jonny` trava mira, tiro, recarga,
## corrida, dash, lanterna e atalho. Os bracos ficam na pose do colo
## (`player_carry_hold.gd`, um SkeletonModifier3D por cima da AnimationTree) e
## o Jonny anda preso ao peito dele (o `seguir` do AtorIgreja, apontado pro
## `suporte_colo.gd` pendurado na malha).
##
## `ui_largar` (B no controle, G no teclado) poe o Jonny no chao: o Maycow
## ajoelha (clipe `largar_jonny`), pousa ele, e volta a ter tudo de volta. O
## lugar onde ele ficou vai pro save (estado 5) — a cena do hospital o poe la'
## de novo nas visitas seguintes.
##
## Quem cria este no' e' o `hospital.gd`.

signal largou

const CENA_JONNY := "res://scenes/npcs/igreja/jonny.tscn"
const CLIPES_MAYCOW := "res://assets/3d_model/npc/igreja/maycow_clipes.tres"
const MODELO := "maycow_lopes_normal"
const ESQUELETO := "maycow_lopes_normal/Armature/Skeleton3D"
const MALHA := "maycow_lopes_normal/Armature/Skeleton3D/char1"
## Onde o Jonny pousa, a partir do peito (no espaco do corpo: +Z frente).
const COLO := Vector3(0.0, -0.42, 0.34)
## Duracao do `largar_jonny` e o instante em que ele encosta no chao.
const DURACAO_LARGAR := 3.2
const NO_CHAO := 1.6

var player: CharacterBody3D
var jonny: Node3D
var _hold: SkeletonModifier3D
var _suporte: Node3D
var _largando := false


func _ready() -> void:
	player = get_parent()
	if not GlobalEvents.is_maycow_normal:
		return
	player.carregando_jonny = true
	var sk := player.get_node_or_null(ESQUELETO) as Skeleton3D
	var malha := player.get_node_or_null(MALHA) as Node3D
	if sk == null or malha == null:
		push_warning("player_carregar_jonny: rig do Maycow normal nao encontrado")
		return
	_hold = load("res://scripts/player/player_carry_hold.gd").new()
	_hold.name = "PlayerCarryHold"
	sk.add_child(_hold)
	_suspender_armas(true)
	_suporte = load("res://scripts/player/suporte_colo.gd").new()
	_suporte.name = "SuporteColo"
	_suporte.esqueleto = sk
	malha.add_child(_suporte)

	jonny = load(CENA_JONNY).instantiate()
	jonny.clipe_inicial = &"no_colo"
	jonny.sangue = 0.45
	player.get_parent().add_child(jonny)
	jonny.osso_mao_direita = "Spine"
	jonny.osso_mao_esquerda = "Spine"
	jonny.seguir_offset = COLO
	jonny.seguir_giro_y = 90.0
	jonny.seguir = jonny.get_path_to(_suporte)
	jonny.seguir_peso = 1.0
	_mostrar_dica()


func _mostrar_dica() -> void:
	var chave := "AVISO_LARGAR_JONNY_CONTROLE" if GlobalEvents.usando_controle \
		else "AVISO_LARGAR_JONNY_TECLADO"
	GlobalUtils.show_center_message("largar_jonny", tr(chave), 16)


func _process(_delta: float) -> void:
	if _largando or not player.carregando_jonny:
		return
	if GlobalEvents.in_cutscene or get_tree().paused:
		return
	if Input.is_action_just_pressed("ui_largar") and player.is_on_floor():
		_largar()


func _suspender_armas(sim: bool) -> void:
	for caminho in ["PlayerGunHold", "PlayerShotgunHold"]:
		var h := player.get_node_or_null(ESQUELETO + "/" + caminho)
		if h and "suspensa" in h:
			h.suspensa = sim


func _largar() -> void:
	_largando = true
	GlobalUtils.hide_center_message("largar_jonny")
	player.cutscene_set_player_control(false)
	player.velocity = Vector3.ZERO

	# o chao em frente a ele, onde o Jonny fica deitado (atravessado)
	var frente := (_suporte.global_basis.z * Vector3(1, 0, 1)).normalized()
	var chao := _chao_em(player.global_position + frente * 0.72)
	var giro := Basis.looking_at(-frente, Vector3.UP) * Basis(Vector3.UP, deg_to_rad(90.0))
	jonny.seguir_peso = 1.0
	jonny._base_seguir = Transform3D(giro, chao)

	# o Maycow ajoelha e pousa: o clipe da cutscene, tocado no proprio modelo
	var modelo := player.get_node(MODELO)
	var arvore := modelo.get_node_or_null("AnimationTree") as AnimationTree
	var ap := AnimationPlayer.new()
	ap.name = "AnimLargar"
	modelo.add_child(ap)
	ap.add_animation_library("", load(CLIPES_MAYCOW))
	if arvore:
		arvore.active = false
	_hold.peso_alvo = 0.0
	ap.play(&"largar_jonny", 0.2)
	jonny.tocar(&"sendo_largado", 0.2)
	var t := create_tween()
	t.tween_property(jonny, "seguir_peso", 0.0, NO_CHAO).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(DURACAO_LARGAR).timeout

	if arvore:
		arvore.active = true
	ap.queue_free()
	jonny.tocar(&"deitado", 0.4)
	jonny.seguir = NodePath()
	_suspender_armas(false)
	player.carregando_jonny = false
	player.cutscene_set_player_control(true)
	if is_instance_valid(_hold):
		_hold.queue_free()
	if is_instance_valid(_suporte):
		_suporte.queue_free()

	SaveManager.evento_dona_nice = 5
	SaveManager.jonny_no_hospital = [jonny.global_position.x, jonny.global_position.y,
		jonny.global_position.z, jonny.global_rotation.y]
	SaveManager.save_game()
	largou.emit()
	queue_free()


func _chao_em(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 3.0)
	q.collision_mask = 2
	q.exclude = [player.get_rid()]
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return Vector3(p.x, player.global_position.y - 1.0, p.z)
	return r["position"]
