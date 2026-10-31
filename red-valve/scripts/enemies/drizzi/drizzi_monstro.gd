extends CharacterBody3D

## A DRIZZI WISNY MONSTRO — a chefe do cemitério (Capítulo 3).
##
## A mãe do Jonny tomada pelo parasita: sem pernas, a barriga aberta e as
## tripas penduradas embaixo, o braço esquerdo de garra. Ela FLUTUA (como a
## Dona Nice gigante da igreja): a posição é escrita direto, a meio metro do
## chão que estiver embaixo dela (lápide, túmulo, o piso da arena), e o corpo
## existe só pra receber tiro. Sempre de frente pro Maycow, ela o rodeia,
## às vezes se afasta, e:
##
##  - POEIRA: enfia a mão na BOCA, tira a terra que comeu e arremessa nele
##    (`projetil_drizzi.gd`, POEIRA: dano e a tela suja de terra);
##  - ÓRGÃO: leva a mão às tripas de baixo, arranca um órgão, segura ele um
##    instante — pingando e espirrando sangue pra todo lado — e arremessa
##    (ORGAO: mais dano, sangue onde bate);
##  - SE ENTERRA: despenca no chão (sobe poeira), come a terra e afunda
##    cavando; some, e o chão estoura noutro canto — ela sai cavando de baixo
##    pra cima. É o teleporte dela.
##
## Com 15% do sangue ela CAI (`derrotada`): o corpo tomba e a luta acaba — o
## resto (ela voltando a ser gente nos braços do Maycow) é do cemitério
## (`capitulo_3_cemiterio.gd`). O céu é aberto: o amuleto a leva pra arena,
## e lá ela luta igual. Por isso o contrato é o dos inimigos comuns: grupo
## "enemies", `dead`, `died`, `cutscene_mode`, `player` e `take_damage`.
##
## Os clipes são de `tools/blender/drizzi/anim_drizzi_monstro.py`; os
## instantes de arremesso estão copiados aqui. Frente = +Z.

signal died
## Caiu com 15% (o cemitério roda a cena da verdade). `onde` = onde ela caiu.
signal derrotada(onde: Transform3D)

const Projetil := preload("res://scripts/enemies/drizzi/projetil_drizzi.gd")
const Poeira := preload("res://scripts/effects/poeira_drizzi.gd")
const AtorDrizzi := preload("res://scripts/npcs/drizzi/ator_drizzi.gd")

## Tiros de pistola (no dano da pistola) pra ela cair (chegar a LIMIAR).
const TIROS_PARA_CAIR := 40
const LIMIAR := 0.15
## Do chão à ponta das tripas.
const ALTURA_FLUTUA := 0.55
const RAIO_ORBITA := 7.5
const DISTANCIA_LONGE := 11.5
const VELOCIDADE := 2.3
const GIRO := 2.2
const INTERVALO_POEIRA := Vector2(3.4, 5.4)
const INTERVALO_ORGAO := Vector2(9.0, 13.5)
const INTERVALO_TOCA := Vector2(13.0, 19.0)
## Quanto dura cada jeito ("roda" em volta dele ou "longe").
const DURACAO_DO_JEITO := Vector2(5.0, 8.0)
## Instantes (s) de `anim_drizzi_monstro.py`.
const NA_BOCA := 0.6
const LANCA_POEIRA := 1.55
const FIM_POEIRA := 2.2
const PEGA_ORGAO := 1.35
const LANCA_ORGAO := 3.15
const FIM_ORGAO := 3.6
## O teleporte: quanto ela leva pra afundar e pra sair, e a profundidade.
const AFUNDAR := 1.7
const EMERGIR := 1.5
const FUNDO := 3.2
## Os limites do cemitério (o muro invisível do gerador fica em 56,9 x 60,9;
## a capela, no fundo norte).
const LIMITE_X := 50.0
const LIMITE_Z := 54.0
const CAPELA := Rect2(-15.0, -64.0, 30.0, 22.0)
const LAYER_CHAO := 2

const SOM_RESPIRA := "res://assets/sounds/igreja/respiracao_monstro.ogg"
const SOM_GRITO := "res://assets/sounds/igreja/grito_monstro.ogg"
const SOM_RUGIDO := "res://assets/sounds/igreja/rugido_monstro.ogg"
const SOM_CUSPE := "res://assets/sounds/igreja/cuspe.ogg"
const SOM_ARREMESSO := "res://assets/sounds/player/dash_effect.mp3"
const SOM_TRIPAS := "res://assets/sounds/igreja/baba.ogg"
const SOM_PINGO := "res://assets/sounds/igreja/gota_sangue.ogg"
const SOM_QUEDA := "res://assets/sounds/igreja/tapa_chao.ogg"
const SOM_MORDIDAS := ["res://assets/sounds/igreja/mordida_1.ogg",
	"res://assets/sounds/igreja/mordida_2.ogg", "res://assets/sounds/igreja/mordida_3.ogg"]
const SONS_DANO := ["res://assets/sounds/igreja/dano_monstro_1.ogg",
	"res://assets/sounds/igreja/dano_monstro_2.ogg", "res://assets/sounds/igreja/dano_monstro_3.ogg"]
const SOM_MORTE := "res://assets/sounds/igreja/morte_monstro.ogg"

@export var enemy_name: String = "DRIZZI_MONSTRO_NOME"

var player: Node3D
var cutscene_mode: bool = false
var dead: bool = false
var max_health: int = 400
var current_health: int = 400

var _ativa := false
var _ocupada := false
var _sumida := false
var _tempo := 0.0
var _prox_poeira := 0.0
var _prox_orgao := 0.0
var _prox_toca := 0.0
var _jeito := "roda"
var _fim_do_jeito := 0.0
var _angulo := 0.0
var _sentido := 1.0
var _chao := 0.0
var _gritou_metade := false
var _anim: AnimationPlayer
var _clipe := &""

@onready var visual: Node3D = $visual
@onready var forma: CollisionShape3D = $forma
@onready var som_voz: AudioStreamPlayer3D = $sons/voz
@onready var som_golpe: AudioStreamPlayer3D = $sons/golpe
@onready var som_dano: AudioStreamPlayer3D = $sons/dano
@onready var som_respira: AudioStreamPlayer3D = $sons/respira


func _ready() -> void:
	add_to_group("enemies")
	_ajustar_modelo()
	_anim = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for clipe in [&"flutuar", &"cavar"]:
			if _anim.has_animation(clipe):
				_anim.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR
	for m in visual.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).extra_cull_margin = 1.5
	player = get_tree().get_first_node_in_group("player")
	var dano := 10
	if player and "damage_pistol" in player:
		dano = int(player.damage_pistol)
	max_health = int(ceil(TIROS_PARA_CAIR * dano / (1.0 - LIMIAR)))
	current_health = max_health
	if ResourceLoader.exists(SOM_RESPIRA):
		som_respira.stream = load(SOM_RESPIRA)
	_chao = global_position.y - ALTURA_FLUTUA
	_tocar(&"flutuar", 0.0)


## O .glb sai do Blender na altura do scan: aqui ele fica com a altura da
## cena (a mesma do ator da cena da capela) e a ponta das tripas na origem.
func _ajustar_modelo() -> void:
	var modelo := visual.get_node_or_null("modelo") as Node3D
	if modelo == null:
		return
	var caixa := AtorDrizzi._caixa(modelo)
	if caixa.size.y <= 0.0:
		return
	modelo.scale = Vector3.ONE * (AtorDrizzi.ALTURA_MONSTRO / caixa.size.y)
	caixa = AtorDrizzi._caixa(modelo)
	modelo.position -= Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)


## Solta a luta (a cena da capela acabou, ou ela chegou flutuando pronta).
func comecar() -> void:
	_ativa = true
	som_respira.play()
	var j := _jogador()
	if j:
		var d := global_position - j.global_position
		_angulo = atan2(d.x, d.z)
	_prox_poeira = _tempo + randf_range(1.2, 2.4)
	_prox_orgao = _tempo + randf_range(INTERVALO_ORGAO.x * 0.6, INTERVALO_ORGAO.y * 0.6)
	_prox_toca = _tempo + randf_range(INTERVALO_TOCA.x, INTERVALO_TOCA.y)
	_fim_do_jeito = _tempo + randf_range(DURACAO_DO_JEITO.x, DURACAO_DO_JEITO.y)
	_barra()


func _jogador() -> Node3D:
	if not is_instance_valid(player) or not player.is_inside_tree() or not player.is_in_group("player"):
		player = get_tree().get_first_node_in_group("player")
	return player


func _tocar(clipe: StringName, mistura: float = 0.25, vel: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(clipe):
		return
	if _clipe == clipe and _anim.is_playing() and _anim.get_animation(clipe).loop_mode != Animation.LOOP_NONE:
		return
	_clipe = clipe
	_anim.play(clipe, mistura, vel)
	if _anim.current_animation == String(clipe) and _anim.get_animation(clipe).loop_mode == Animation.LOOP_NONE:
		_anim.seek(0.0, true)


# ==============================================================================
# O VOO
# ==============================================================================

func _physics_process(delta: float) -> void:
	_tempo += delta
	if dead or not _ativa or cutscene_mode:
		return
	var j := _jogador()
	if j == null:
		return
	if not _sumida:
		_encarar(j, delta)
	if _ocupada or GlobalEvents.agarrao_rodando:
		if not _sumida:
			_pairar(delta)
		return
	if _tempo > _fim_do_jeito:
		_jeito = "longe" if _jeito == "roda" else "roda"
		_fim_do_jeito = _tempo + randf_range(DURACAO_DO_JEITO.x, DURACAO_DO_JEITO.y)
		if _jeito == "roda":
			var d := global_position - j.global_position
			_angulo = atan2(d.x, d.z)
	var alvo := _alvo(j, delta)
	var p := global_position
	var plano := Vector3(alvo.x - p.x, 0.0, alvo.z - p.z)
	var passo := minf(plano.length(), VELOCIDADE * delta)
	if plano.length() > 0.05:
		var novo := p + plano.normalized() * passo
		# não vai pra onde não tem chão (a beirada da arena)
		var chao := _chao_em(novo)
		if not is_nan(chao):
			p = novo
	global_position = p
	_pairar(delta)

	if _tempo > _prox_toca:
		_se_enterrar(j)
	elif _tempo > _prox_orgao:
		_arrancar_orgao(j)
	elif _tempo > _prox_poeira:
		_jogar_poeira(j)


func _alvo(j: Node3D, delta: float) -> Vector3:
	if _jeito == "longe":
		var fora := global_position - j.global_position
		fora.y = 0.0
		if fora.length() < 0.1:
			fora = Vector3.FORWARD
		return _nos_limites(j.global_position + fora.normalized() * DISTANCIA_LONGE)
	if randf() < delta * 0.15:
		_sentido = -_sentido
	_angulo += _sentido * VELOCIDADE / RAIO_ORBITA * delta
	return _nos_limites(j.global_position + Vector3(sin(_angulo), 0.0, cos(_angulo)) * RAIO_ORBITA)


## Sobe e desce devagar a meio metro do que estiver embaixo dela.
func _pairar(delta: float) -> void:
	var chao := _chao_em(global_position)
	if not is_nan(chao):
		_chao = lerpf(_chao, chao, clampf(delta * 4.0, 0.0, 1.0))
	var p := global_position
	p.y = _chao + ALTURA_FLUTUA + sin(_tempo * 1.4) * 0.18
	global_position = p


func _encarar(j: Node3D, delta: float) -> void:
	var d := j.global_position - global_position
	rotation.y = rotate_toward(rotation.y, atan2(d.x, d.z), GIRO * delta)


## O chão embaixo de `p` (NAN = não tem).
func _chao_em(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 30.0, LAYER_CHAO)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return float(r["position"].y) if r else NAN


func _no_cemiterio() -> bool:
	var cena := get_tree().current_scene
	return cena != null and cena.scene_file_path.contains("cemiterio")


func _nos_limites(p: Vector3) -> Vector3:
	if not _no_cemiterio():
		return p
	p.x = clampf(p.x, -LIMITE_X, LIMITE_X)
	p.z = clampf(p.z, -LIMITE_Z, LIMITE_Z)
	if CAPELA.has_point(Vector2(p.x, p.z)):
		p.z = CAPELA.end.y
	return p


# ==============================================================================
# OS ATAQUES
# ==============================================================================

func _vale() -> bool:
	return is_inside_tree() and not dead and _ativa


func _jogar_poeira(j: Node3D) -> void:
	_ocupada = true
	_prox_poeira = _tempo + randf_range(INTERVALO_POEIRA.x, INTERVALO_POEIRA.y)
	if _jeito == "longe":
		_prox_poeira -= 1.0
	_tocar(&"jogar_poeira", 0.15)
	await _esperar(NA_BOCA)
	if not _vale():
		return
	_som(som_golpe, SOM_MORDIDAS.pick_random(), randf_range(0.6, 0.75))
	Poeira.nuvem(get_parent(), _osso("head") + global_basis.z * 0.3, 0.8, 0.6, 14).call("assentar", 1.4)
	await _esperar(LANCA_POEIRA - NA_BOCA)
	if not _vale():
		return
	_som(som_golpe, SOM_ARREMESSO, 0.7)
	_lancar(Projetil.Tipo.POEIRA, j, 14.0)
	await _esperar(FIM_POEIRA - LANCA_POEIRA)
	if not _vale():
		return
	_tocar(&"flutuar", 0.3)
	_ocupada = false


func _arrancar_orgao(j: Node3D) -> void:
	_ocupada = true
	_prox_orgao = _tempo + randf_range(INTERVALO_ORGAO.x, INTERVALO_ORGAO.y)
	_prox_poeira = maxf(_prox_poeira, _tempo + FIM_ORGAO + 1.0)
	_tocar(&"pegar_orgao", 0.15)
	_som(som_golpe, SOM_TRIPAS, 0.8)
	await _esperar(PEGA_ORGAO)
	if not _vale():
		return
	# o órgão na mão, pingando e espirrando
	var mao := _mao()
	var orgao := Projetil.orgao()
	if mao:
		mao.add_child(orgao)
		orgao.position = Vector3(0.0, 0.06, 0.12)
		orgao.global_basis = orgao.global_basis.orthonormalized()
		orgao.scale = Vector3.ONE * 1.0 / maxf(mao.global_basis.get_scale().x, 0.001)
	else:
		add_child(orgao)
		orgao.position = Vector3(0.0, 1.6, 0.6)
	Poeira.pingando(orgao, 1.6)
	_som(som_voz, SOM_GRITO, randf_range(0.85, 1.0))
	Poeira.respingo(get_parent(), orgao.global_position, 0.7, false)
	var segura := LANCA_ORGAO - PEGA_ORGAO
	var t := 0.0
	var pingo := 0.0
	while t < segura:
		await get_tree().physics_frame
		if not _vale():
			if is_instance_valid(orgao):
				orgao.queue_free()
			return
		t += get_physics_process_delta_time()
		pingo -= get_physics_process_delta_time()
		if pingo <= 0.0 and is_instance_valid(orgao):
			pingo = 0.45
			_som(som_dano, SOM_PINGO, randf_range(0.8, 1.2))
			if randf() < 0.5:
				Poeira.respingo(get_parent(), orgao.global_position, 0.35, false)
	var de := orgao.global_position if is_instance_valid(orgao) else _osso("hand.R")
	if is_instance_valid(orgao):
		orgao.queue_free()
	_som(som_golpe, SOM_ARREMESSO, 0.6)
	_lancar(Projetil.Tipo.ORGAO, j, 15.0, de)
	await _esperar(FIM_ORGAO - LANCA_ORGAO)
	if not _vale():
		return
	_tocar(&"flutuar", 0.3)
	_ocupada = false


## O arco até onde ele está (um pouco à frente se ele corre).
func _lancar(tipo: Projetil.Tipo, j: Node3D, velocidade: float, de: Vector3 = Vector3.INF) -> void:
	var origem := de if de != Vector3.INF else _osso("hand.R")
	var alvo := j.global_position + Vector3(0, -0.4, 0)
	if j is CharacterBody3D:
		alvo += Vector3((j as CharacterBody3D).velocity.x, 0.0, (j as CharacterBody3D).velocity.z) * 0.35
	var p = Projetil.criar(get_parent(), tipo)
	p.lancar(origem, alvo, clampf(origem.distance_to(alvo) / velocidade, 0.45, 1.3))


## O teleporte: cai, come a terra e afunda cavando; sai noutro canto.
func _se_enterrar(j: Node3D) -> void:
	_ocupada = true
	_prox_toca = _tempo + randf_range(INTERVALO_TOCA.x, INTERVALO_TOCA.y)
	_prox_poeira = maxf(_prox_poeira, _tempo + 6.5)
	_prox_orgao = maxf(_prox_orgao, _tempo + 8.0)
	# despenca
	_tocar(&"cair", 0.1)
	var chao := _chao_em(global_position)
	if is_nan(chao):
		chao = _chao
	var cai := create_tween()
	cai.tween_property(self, "global_position:y", chao - 0.15, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await cai.finished
	if not _vale():
		return
	_som(som_golpe, SOM_QUEDA, 0.7)
	GlobalUtils.shake_camera(0.4, 0.3)
	Poeira.estouro(get_parent(), Vector3(global_position.x, chao, global_position.z), 1.3)
	# come a terra e afunda
	_tocar(&"cavar", 0.2)
	var nuvem := Poeira.nuvem(get_parent(), Vector3(global_position.x, chao, global_position.z), 3.0, 2.2, 60)
	var afunda := create_tween()
	afunda.tween_property(self, "global_position:y", chao - FUNDO, AFUNDAR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var morde := 0.0
	var t := 0.0
	while t < AFUNDAR:
		await get_tree().physics_frame
		if not _vale():
			nuvem.call("assentar", 2.0)
			return
		t += get_physics_process_delta_time()
		morde -= get_physics_process_delta_time()
		if morde <= 0.0:
			morde = 0.28
			_som(som_golpe, SOM_MORDIDAS.pick_random(), randf_range(0.55, 0.75))
	_sumida = true
	visual.visible = false
	forma.disabled = true
	nuvem.call("assentar", 3.0)
	await _esperar(0.9)
	if not _vale():
		return
	# sai noutro canto, cavando de baixo pra cima
	var destino := _lugar_pra_sair(j)
	var chao2 := _chao_em(destino)
	if is_nan(chao2):
		chao2 = chao
	global_position = Vector3(destino.x, chao2 - FUNDO, destino.z)
	var d := j.global_position - global_position
	rotation.y = atan2(d.x, d.z)
	Poeira.estouro(get_parent(), Vector3(destino.x, chao2, destino.z), 1.5)
	var sobe_poeira := Poeira.nuvem(get_parent(), Vector3(destino.x, chao2, destino.z), 2.6, 2.6, 50)
	_som(som_golpe, SOM_QUEDA, 0.55)
	_som(som_voz, SOM_RUGIDO, randf_range(0.8, 0.95))
	GlobalUtils.shake_camera(0.6, 0.35)
	visual.visible = true
	_tocar(&"surgir", 0.0)
	_chao = chao2
	var sobe := create_tween()
	sobe.tween_property(self, "global_position:y", chao2 + ALTURA_FLUTUA, EMERGIR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await sobe.finished
	sobe_poeira.call("assentar", 3.0)
	if not _vale():
		return
	_sumida = false
	forma.disabled = false
	await _esperar(0.5)
	if not _vale():
		return
	_tocar(&"flutuar", 0.3)
	_ocupada = false
	_prox_poeira = minf(_prox_poeira, _tempo + 1.0)


func _lugar_pra_sair(j: Node3D) -> Vector3:
	var arena := get_tree().current_scene
	for _i in 14:
		var p: Vector3
		if not _no_cemiterio() and arena and arena.has_method("ponto_aleatorio_na_arena"):
			p = arena.call("ponto_aleatorio_na_arena", 3.5)
		else:
			var ang := randf() * TAU
			var r := randf_range(6.0, 13.0)
			p = _nos_limites(j.global_position + Vector3(sin(ang), 0.0, cos(ang)) * r)
		var longe := Vector2(p.x - j.global_position.x, p.z - j.global_position.z).length()
		if longe > 5.0 and not is_nan(_chao_em(p)):
			return p
	return global_position


# ==============================================================================
# DANO
# ==============================================================================

func take_damage(amount) -> void:
	if dead or not _ativa or _sumida or cutscene_mode:
		return
	var dano := int(amount)
	current_health = maxi(0, current_health - dano)
	var j := _jogador()
	if is_instance_valid(j) and j.has_method("add_cogblade_power"):
		j.add_cogblade_power(float(dano), global_position + Vector3.UP * 1.4)
	if not som_dano.playing or randf() < 0.3:
		_som(som_dano, SONS_DANO.pick_random(), randf_range(0.75, 0.95))
	_barra()
	if current_health <= int(max_health * LIMIAR):
		_cair()
		return
	if not _gritou_metade and current_health <= max_health / 2 and not _ocupada:
		_gritou_metade = true
		_gritar()
	elif not _ocupada and randf() < 0.12:
		_tocar(&"dano", 0.05)
		await _esperar(0.5)
		if _vale() and not _ocupada:
			_tocar(&"flutuar", 0.3)


func _gritar() -> void:
	_ocupada = true
	_tocar(&"gritar", 0.1)
	_som(som_voz, SOM_GRITO, 0.8)
	GlobalUtils.shake_camera(1.0, 0.3)
	await _esperar(2.4)
	if not _vale():
		return
	_tocar(&"flutuar", 0.3)
	_ocupada = false


func _barra() -> void:
	var root := get_tree().root
	var ui := root.get_node_or_null("GlobalEnemyHealthUI")
	if ui == null:
		ui = load("res://scripts/ui/global_enemy_health.gd").new()
		ui.name = "GlobalEnemyHealthUI"
		root.add_child(ui)
	ui.show_health(self, tr(enemy_name), current_health, max_health)


## 15%: o corpo tomba sem força e desce até o chão. A luta acaba aqui.
func _cair() -> void:
	dead = true
	_ativa = false
	_ocupada = true
	som_respira.stop()
	_tocar(&"derrotada", 0.1)
	_som(som_voz, SOM_MORTE, 0.75)
	GlobalUtils.shake_camera(0.8, 0.3)
	set_collision_layer_value(3, false)
	var chao := _chao_em(global_position)
	if is_nan(chao):
		chao = _chao
	var cai := create_tween()
	cai.tween_interval(0.8)
	cai.tween_property(self, "global_position:y", chao - 0.1, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	cai.tween_callback(func() -> void:
		if is_inside_tree():
			Poeira.estouro(get_parent(), Vector3(global_position.x, chao, global_position.z), 1.0))
	derrotada.emit(global_transform)
	died.emit()


func _osso(nome: String) -> Vector3:
	var sk := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		var i := sk.find_bone(nome)
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin
	return global_position + Vector3.UP * 1.6


## Um nó preso na mão direita (pro órgão).
func _mao() -> Node3D:
	var sk := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone("hand.R") < 0:
		return null
	var preso := sk.get_node_or_null("mao_r") as BoneAttachment3D
	if preso == null:
		preso = BoneAttachment3D.new()
		preso.name = "mao_r"
		preso.bone_name = "hand.R"
		sk.add_child(preso)
	return preso


func _esperar(s: float) -> void:
	await get_tree().create_timer(maxf(s, 0.01), false).timeout


func _som(tocador: AudioStreamPlayer3D, caminho: String, tom: float) -> void:
	if tocador == null or not ResourceLoader.exists(caminho):
		return
	tocador.stream = load(caminho)
	tocador.pitch_scale = tom
	tocador.play()
