extends Node3D

## Um membro inteiro do Shadow Rock que se soltou: braco, mao, ombro, cabeca,
## pe. Ele cai girando como uma peca so — porque ate bater no chao ainda E uma
## peca so — e no impacto se DESPEDACA nas pedras que o formavam.
##
## Essa e a diferenca pro `rock_debris.gd`: la sao cacos que ja nascem soltos e
## so procuram o chao; aqui e um pedaco reconhecivel do corpo dele viajando
## inteiro no ar. O jogador tem de ver O BRACO cair, girando, antes de virar
## monte de pedra — e o que faz o golpe valer como mutilacao e nao como
## particula.
##
## Depois disto o inimigo continua vivo e sem o membro (ver
## `shadow_rock.gd::_arranca_membro`).

const FX := preload("res://scripts/effects/seraph_fx.gd")
const RockFX := preload("res://scripts/effects/rock_fx.gd")

const CHAO := 2
const GRAVIDADE := 20.0

## Pedras do membro, em coordenadas de MUNDO no instante em que caiu:
## [{ "mesh": Mesh, "escala": Vector3, "pos": Vector3, "rot": Vector3 }].
var pecas: Array = []
## Empurrao inicial (ja em m/s, no mundo).
var impulso: Vector3 = Vector3.ZERO
## Quanto tempo os cacos ficam no chao depois de se espatifar.
var permanencia: float = 8.0

var _vel: Vector3 = Vector3.ZERO
var _giro: Vector3 = Vector3.ZERO
var _chao_y: float = -99999.0
var _raio: float = 0.25
var _tempo: float = 0.0
var _caiu: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if pecas.is_empty():
		queue_free()
		return

	# O no nasce no centro das pedras: e em volta desse ponto que o membro gira
	# no ar. Girar em volta da origem do inimigo faria o braco descrever um arco
	# de dois metros, como se tivesse sido chutado.
	var centro := Vector3.ZERO
	for p in pecas:
		centro += p["pos"] as Vector3
	centro /= float(pecas.size())
	global_position = centro

	var longe := 0.0
	for p in pecas:
		var mi := MeshInstance3D.new()
		mi.mesh = p["mesh"]
		mi.scale = p.get("escala", Vector3.ONE * 0.2)
		mi.material_override = RockFX.material_quebrado()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		mi.global_position = p["pos"]
		mi.rotation = p.get("rot", Vector3.ZERO)
		longe = maxf(longe, mi.position.length() + mi.scale.y * 0.5)
	_raio = maxf(longe, 0.15)

	_vel = impulso
	_giro = Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-4.0, 4.0), _rng.randf_range(-5.0, 5.0))
	_acha_chao()

	add_child(RockFX.po(12, 0.35, 1.2))
	FX.som_no_mundo(self, global_position, RockFX.SOM_PEDRA, -13.0, _rng.randf_range(0.38, 0.5))


func _acha_chao() -> void:
	if not is_inside_tree():
		return
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 30.0, CHAO)
	var acerto := espaco.intersect_ray(q)
	if acerto.has("position"):
		_chao_y = (acerto["position"] as Vector3).y


func _process(delta: float) -> void:
	if _caiu:
		return
	_tempo += delta
	_vel.y -= GRAVIDADE * delta
	global_position += _vel * delta
	rotation += _giro * delta

	if _chao_y > -99998.0 and global_position.y <= _chao_y + _raio:
		global_position.y = _chao_y + _raio
		_espatifa()
	elif _tempo > 8.0:
		# sem chao embaixo: some sem barulho em vez de cair pra sempre
		queue_free()


## O impacto. As pedras que formavam o membro viram um monte de cacos soltos —
## nas mesmas posicoes e com as mesmas malhas em que estavam um frame atras,
## entao o olho acompanha o braco virando entulho sem corte nenhum.
func _espatifa() -> void:
	if _caiu:
		return
	_caiu = true

	var modelos: Array = []
	for c in get_children():
		if c is MeshInstance3D:
			modelos.append({
				"mesh": (c as MeshInstance3D).mesh,
				"escala": (c as MeshInstance3D).scale,
				"pos": (c as MeshInstance3D).global_position,
				"rot": (c as MeshInstance3D).global_rotation,
			})

	var pos := global_position
	RockFX.detritos(self, pos, modelos.size(), 3.4, 0.18, permanencia, modelos)
	RockFX.quebra(self, pos, 0.9)
	GlobalUtils.shake_camera(0.12, 0.10)
	queue_free()
