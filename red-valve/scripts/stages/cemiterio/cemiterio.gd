extends "res://scripts/stages/cenario_aberto.gd"

## O CEMITÉRIO da cidade — arena de chefe na névoa.
##
## Modelo de `tools/blender/cemiterio/gerar_cemiterio.py`, cena de
## `tools/godot/cemiterio/gerar_cena_cemiterio.py`: luz, prop e navmesh mexidos
## no editor somem na próxima regeração. Este script é só comportamento.
##
## A névoa (Silent Hill) é o lugar: quase tudo o que este script faz acontece
## NA BORDA DO QUE SE VÊ, entre 25 e 40 m do jogador, onde a névoa ainda deixa
## adivinhar uma forma mas não deixa conferir:
##
##  - OLHOS: um par de olhos acende no meio da névoa, pisca e some;
##  - o SINO de uma igreja que não está ali bate de vez em quando;
##  - SUSSURROS passam perto e vão embora;
##  - a cinza e a névoa rasteira andam junto com a câmera (grupo
##    `segue_camera`, quem move é a base).

@export_group("Olhos na névoa")
@export var olhos_ativos: bool = true
@export var olhos_espera_min: float = 7.0
@export var olhos_espera_max: float = 18.0
@export var olhos_distancia_min: float = 24.0
@export var olhos_distancia_max: float = 38.0

@export_group("Sino e sussurros")
@export var sino_espera_min: float = 28.0
@export var sino_espera_max: float = 65.0
@export var sussurro_espera_min: float = 20.0
@export var sussurro_espera_max: float = 48.0

## Meio-tamanho do terreno útil (o muro invisível está um pouco antes).
const MEIO_X := 55.0
const MEIO_Z := 59.0
const R_PRACA := 21.0

var _modelo_olhos: Node3D
var _olhos_prazo: float = 0.0
var _sino: AudioStreamPlayer3D
var _sino_prazo: float = 0.0
var _sussurro: AudioStreamPlayer3D
var _sussurro_prazo: float = 0.0


func _preparar() -> void:
	_modelo_olhos = get_node_or_null("olhos") as Node3D
	if _modelo_olhos:
		_modelo_olhos.visible = false
	_sino = get_node_or_null("sino") as AudioStreamPlayer3D
	_sussurro = get_node_or_null("sussurro") as AudioStreamPlayer3D
	_olhos_prazo = randf_range(olhos_espera_min, olhos_espera_max)
	_sino_prazo = randf_range(6.0, 14.0)
	_sussurro_prazo = randf_range(sussurro_espera_min, sussurro_espera_max)


func _passo(delta: float) -> void:
	if olhos_ativos and _modelo_olhos:
		_olhos_prazo -= delta
		if _olhos_prazo <= 0.0:
			_olhos_prazo = randf_range(olhos_espera_min, olhos_espera_max)
			_acender_olhos()

	_sino_prazo -= delta
	if _sino_prazo <= 0.0:
		_sino_prazo = randf_range(sino_espera_min, sino_espera_max)
		_badaladas()

	_sussurro_prazo -= delta
	if _sussurro_prazo <= 0.0:
		_sussurro_prazo = randf_range(sussurro_espera_min, sussurro_espera_max)
		_sussurrar()


# ==============================================================================
# O SIGILO DA PRAÇA
# ==============================================================================
## Pública: a luta do chefe acende o sigilo do meio da praça (e apaga depois).
func acender_sigilo(forca: float = 1.0, tempo: float = 2.5) -> void:
	var material := load("res://assets/3d_model/stages/cemiterio/materiais/mat_sigilo_praca.tres") as StandardMaterial3D
	if material == null:
		return
	var t := create_tween()
	t.tween_property(material, "emission_energy_multiplier", lerpf(0.15, 4.0, forca), tempo)


# ==============================================================================
# OLHOS
# ==============================================================================
func _acender_olhos() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var ponto := Vector3.ZERO
	var achou := false
	for _t in 16:
		var a := randf() * TAU
		var r := randf_range(olhos_distancia_min, olhos_distancia_max)
		ponto = player.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		# fora do ringue: no meio da praça não há onde uma coisa se esconda
		if Vector2(ponto.x, ponto.z).length() < R_PRACA + 3.0:
			continue
		achou = true
		break
	if not achou:
		return
	# alguns ficam FORA do muro, na altura de uma coisa muito alta
	var alto := randf() < 0.3
	if not alto:
		ponto.x = clampf(ponto.x, -MEIO_X, MEIO_X)
		ponto.z = clampf(ponto.z, -MEIO_Z, MEIO_Z)
	ponto.y = _chao(ponto) + (randf_range(4.5, 7.5) if alto else randf_range(1.5, 2.2))

	var olhos := _modelo_olhos.duplicate() as Node3D
	add_child(olhos)
	olhos.global_position = ponto
	olhos.look_at(Vector3(player.global_position.x, ponto.y, player.global_position.z), Vector3.UP)
	olhos.scale = Vector3.ONE * (2.2 if alto else 1.0)
	olhos.visible = true
	var mats: Array[StandardMaterial3D] = []
	for m in olhos.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).get_active_material(0)
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			(m as MeshInstance3D).material_override = mat
			mats.append(mat)
	var t := create_tween()
	t.tween_method(_brilho_olhos.bind(mats), 0.0, 1.0, 0.7)
	t.tween_interval(randf_range(0.8, 1.6))
	# pisca uma vez
	t.tween_method(_brilho_olhos.bind(mats), 1.0, 0.0, 0.08)
	t.tween_method(_brilho_olhos.bind(mats), 0.0, 1.0, 0.1)
	t.tween_interval(randf_range(0.6, 1.8))
	t.tween_method(_brilho_olhos.bind(mats), 1.0, 0.0, 0.9)
	t.tween_callback(olhos.queue_free)


func _brilho_olhos(v: float, mats: Array[StandardMaterial3D]) -> void:
	for m in mats:
		m.albedo_color.a = v
		m.emission_energy_multiplier = 5.0 * v


func _chao(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 30.0, LAYER_CHAO)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit["position"].y) if hit else 0.0


# ==============================================================================
# SINO E SUSSURROS
# ==============================================================================
func _badaladas() -> void:
	if _sino == null or _sino.stream == null:
		return
	var vezes := randi_range(1, 3)
	for k in vezes:
		if not is_instance_valid(_sino):
			return
		_sino.pitch_scale = randf_range(0.97, 1.02)
		_sino.play()
		await get_tree().create_timer(2.6).timeout


func _sussurrar() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if _sussurro == null or _sussurro.stream == null or player == null:
		return
	var a := randf() * TAU
	_sussurro.global_position = player.global_position + Vector3(cos(a) * 9.0, 1.6, sin(a) * 9.0)
	_sussurro.pitch_scale = randf_range(0.8, 0.95)
	_sussurro.play()
	# passa por trás do jogador enquanto fala
	var b := a + randf_range(1.6, 2.6) * (1.0 if randf() < 0.5 else -1.0)
	var t := create_tween()
	t.tween_property(_sussurro, "global_position",
		player.global_position + Vector3(cos(b) * 9.0, 1.6, sin(b) * 9.0), 6.0)
