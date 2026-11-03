extends "res://scripts/cutscenes/cutscene_cap1.gd"

## O RESGATE DO JIMMY NA ARENA 3 (Capítulo 5), vencida a luta.
##
## Cortes, como pedido: o Maycow parasita (um dublê de `maycow_lopes.glb` com
## os clipes de `npc/capitulo_5/maycow_parasita_clipes.glb`) atravessa a praça
## até o pilar da jaula; o Jimmy o vê lá de cima; corte, e o Maycow já está
## no capitel, na frente da porta: agarra as barras e ARRANCA a porta, que voa
## e cai do pilar; o Jimmy sai e os dois se abraçam; e, no último corte, os
## dois vão embora juntos pela ponte por onde ele chegou — o caminho de volta.
## A tela se apaga neles; quem troca de cena (a oficina) é a arena.
##
## O jogador (primeira pessoa: só as mãos, filhas da câmera dele) some e fica
## parado enquanto a cena roda.

const MODELO_PARASITA := "res://assets/3d_model/player/Maycow Lopes/maycow_lopes.glb"
const CLIPES := "res://assets/3d_model/npc/capitulo_5/maycow_parasita_clipes.glb"
const LACOS := ["abraco", "Walking"]
const SOM_PORTA := "res://assets/sounds/capitulo_5/porta_arrancada.ogg"
## O meio da praça (de onde ele vem) e a ponte da volta.
const CENTRO := Vector3(0.0, 0.0, 6.0)
const PONTE_DE := Vector3(0.0, 0.0, 57.0)
## Andando: a velocidade do clipe Walking da captura.
const PASSO := 1.3

var jaula: Node3D
var maycow: Node3D
var _modelo: Node3D
var _ap: AnimationPlayer


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 50.0)
	await escurecer(1.0, 0.01)
	# a arena é de noite: uma luz presa à câmera acende o que ela olha (spot,
	# que conta à parte das omni da arena)
	var luz := SpotLight3D.new()
	luz.light_color = Color(0.95, 0.85, 0.8)
	luz.light_energy = 3.2
	luz.spot_range = 22.0
	luz.spot_angle = 30.0
	cam.add_child(luz)
	luz.position = Vector3(0.35, 0.25, 0.0)
	# as mãos de primeira pessoa são filhas da câmera dele: o jogador inteiro some
	if is_instance_valid(player):
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
	_montar_maycow()
	var jimmy: Node3D = jaula.jimmy
	var porta_dir := jaula.global_basis.z
	porta_dir.y = 0.0
	porta_dir = porta_dir.normalized()
	var base := Vector3(jaula.global_position.x, 0.0, jaula.global_position.z)
	base.y = _chao(base + porta_dir * 8.0)

	# --- 1. ele atravessa a praça até o pilar, olhando pra jaula lá em cima
	var p1 := base + porta_dir * 8.0
	var p0 := base + (CENTRO - base).normalized() * 22.0
	p0.y = _chao(p0)
	p1.y = _chao(p1)
	_por(maycow, p0, p1)
	_tocar(&"Walking", 0.0)
	var dur1 := p0.distance_to(p1) / PASSO
	var olhar_jaula := jaula.global_position + Vector3.UP * 1.6
	escurecer(0.0, 1.4)
	await fase(minf(dur1, 5.5), func(k: float) -> void:
		maycow.global_position = p0.lerp(p1, k * minf(1.0, 5.5 / dur1))
		var atras := maycow.global_position - (p1 - p0).normalized() * 3.2 + Vector3.UP * 1.1
		plantar(atras, maycow.global_position.lerp(olhar_jaula, 0.35 + 0.4 * k)))
	if not vale():
		return

	# --- 2. o Jimmy, lá em cima, vê quem vem
	jaula.parar()
	jimmy.tocar(&"jaula_sacudir", 0.4)
	var rosto: Vector3 = jimmy.cabeca()
	var de_frente := rosto + porta_dir * 2.4 + Vector3.DOWN * 0.5
	await plano(de_frente + jaula.global_basis.x * 0.6, rosto, de_frente - jaula.global_basis.x * 0.3, rosto, 2.8)
	if not vale():
		return

	# --- 3. corte: ele já está no capitel, e arranca a porta
	var na_porta: Vector3 = jaula.frente_da_porta(0.75)
	maycow.global_position = na_porta
	maycow.global_rotation.y = atan2(-porta_dir.x, -porta_dir.z)
	_tocar(&"cap5/arrancar_porta", 0.0)
	var lado := jaula.global_basis.x
	var cam_lado := na_porta + lado * 3.0 + porta_dir * 1.2 + Vector3.UP * 1.5
	clarao(0.35, 0.3)
	# lambda copia variável local: a flag vai num Dictionary
	var feito := {"arrancou": false, "apagando": false}
	await fase(3.0, func(k: float) -> void:
		plantar(cam_lado + porta_dir * (0.4 * k), na_porta - porta_dir * 0.4 + Vector3.UP * 1.2)
		if not feito["arrancou"] and k * 3.0 >= 1.85:
			feito["arrancou"] = true
			jaula.arrancar_porta(maycow.global_position + porta_dir * 2.0)
			GlobalUtils.vibrate_controller(null, 0.8, 0.6, 0.5)
			GlobalUtils.shake_camera(0.6, 0.35))
	if not vale():
		return

	# --- 4. o Jimmy sai da jaula, e os dois se abraçam
	var abraco_jimmy: Vector3 = jaula.frente_da_porta(0.45)
	var de_jimmy := jimmy.global_position
	jimmy.tocar(&"andar", 0.25)
	_tocar(&"Idle_11", 0.4)
	await fase(1.3, func(k: float) -> void:
		jimmy.global_position = de_jimmy.lerp(abraco_jimmy, k)
		plantar(na_porta + lado * 2.4 + porta_dir * 1.6 + Vector3.UP * 1.5,
			(na_porta + abraco_jimmy) * 0.5 + Vector3.UP * 1.3))
	jimmy.tocar(&"abraco", 0.35)
	_tocar(&"cap5/abraco", 0.35)
	var meio := (na_porta + abraco_jimmy) * 0.5 + Vector3.UP * 1.35
	# a volta fica do lado de fora da jaula (do lado da praça): de um flanco
	# até quase de frente
	var g0 := atan2(porta_dir.x, porta_dir.z) - deg_to_rad(75.0)
	await fase(6.0, func(k: float) -> void:
		var g := g0 + deg_to_rad(65.0) * suave(k)
		var r := 2.3 - 0.5 * k
		plantar(meio + Vector3(sin(g) * r, 0.25 - 0.15 * k, cos(g) * r), meio))
	if not vale():
		return

	# --- 5. os dois vão embora juntos, pela ponte por onde ele chegou
	await escurecer(1.0, 0.6)
	var ida := Vector3(0.0, 0.0, 1.0)
	var m0 := PONTE_DE + Vector3(-0.55, 0.0, 0.0)
	var j0 := PONTE_DE + Vector3(0.55, 0.0, 0.0)
	m0.y = _chao(m0)
	j0.y = _chao(j0)
	jimmy.get_parent().remove_child(jimmy)
	cena.add_child(jimmy)
	jimmy.global_position = j0
	jimmy.global_rotation.y = atan2(ida.x, ida.z)
	jimmy.tocar(&"andar", 0.0)
	maycow.global_position = m0
	maycow.global_rotation.y = atan2(ida.x, ida.z)
	_tocar(&"Walking", 0.0)
	escurecer(0.0, 0.8)
	await fase(6.0, func(k: float) -> void:
		var anda := ida * (PASSO * 6.0 * k)
		maycow.global_position = m0 + anda
		jimmy.global_position = j0 + anda
		var meio_ponte := (maycow.global_position + jimmy.global_position) * 0.5
		plantar(meio_ponte - ida * (4.5 + 1.5 * k) + Vector3.UP * (1.9 + 0.8 * k), meio_ponte + Vector3.UP * 1.1 + ida * 3.0)
		if k > 0.62 and not feito["apagando"]:
			feito["apagando"] = true
			escurecer(1.0, 2.0))
	await escurecer(1.0, 0.3)


# ==============================================================================
# O DUBLÊ
# ==============================================================================

func _montar_maycow() -> void:
	maycow = Node3D.new()
	maycow.name = "maycow_parasita_resgate"
	cena.add_child(maycow)
	_modelo = (load(MODELO_PARASITA) as PackedScene).instantiate() as Node3D
	maycow.add_child(_modelo)
	_ap = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap == null:
		return
	for nome in LACOS:
		if _ap.has_animation(nome):
			_ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	var fonte := (load(CLIPES) as PackedScene).instantiate()
	var origem := fonte.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if origem:
		var lib := AnimationLibrary.new()
		for nome in origem.get_animation_list():
			var a := (origem.get_animation(nome) as Animation).duplicate() as Animation
			if String(nome) in LACOS:
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(nome, a)
		_ap.add_animation_library(&"cap5", lib)
	fonte.free()


func _tocar(clipe: StringName, mistura: float) -> void:
	if _ap == null or not _ap.has_animation(clipe):
		push_warning("resgate: sem o clipe %s" % clipe)
		return
	_ap.play(clipe, mistura)


## Põe o dublê em `p` olhando pra `alvo` (o .glb olha pro +Z).
func _por(ator: Node3D, p: Vector3, alvo: Vector3) -> void:
	ator.global_position = p
	var d := alvo - p
	ator.global_rotation.y = atan2(d.x, d.z)


func _chao(p: Vector3) -> float:
	var de := Vector3(p.x, 40.0, p.z)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 80.0, 2)
	var h := cena.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3).y if not h.is_empty() else 0.0
