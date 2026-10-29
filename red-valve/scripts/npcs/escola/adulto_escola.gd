extends CharacterBody3D

## UM ADULTO NA ESCOLA AO FIM DO EXPEDIENTE (Capítulo 1, escola clara).
##
## Professores, inspetores e funcionários: os alunos já foram embora e quem
## sobra anda pelos corredores ou fica parado conversando. O corpo é um dos
## moradores da cidade (`CityNpc.MODELOS`, Mixamo sem clipe nenhum) e a pose
## sai do mesmo `HumanoidPoser` deles — a passada casada com a velocidade, a
## conversa com gesto.
##
## Dois jeitos, escolhidos pelo `pontos`:
##  - com dois ou mais pontos, ele ANDA de um pro outro, ida e volta, parando
##    um pouco em cada ponta;
##  - sem pontos, ele fica PARADO conversando, virado pra `olhar_para`, e
##    `falando` diz se é ele quem gesticula ou quem escuta.
##
## Sem navmesh de propósito: os pontos ficam no mesmo corredor ou na mesma
## sala, em linha reta. Quem monta (`capitulo_1_escola.gd`) escolhe pontos
## que não atravessam parede.
##
## Frente = +Z (a do rig do Mixamo e a do `HumanoidPoser`).

const CityNpcScript := preload("res://scripts/npcs/city_npc.gd")
const HumanoidPoser := preload("res://scripts/npcs/humanoid_poser.gd")

const VELOCIDADE := 1.05
const GIRO := 3.2
const GRAVIDADE := 18.0
const PAUSA_NA_PONTA := Vector2(2.0, 5.5)

var modelo_index: int = -1
var pontos: Array = []
var olhar_para: Vector3 = Vector3.ZERO
var falando: bool = false
## Escala do corpo (a variação de altura entre um e outro).
var escala: float = 1.0

var _poser
var _alvo := 0
var _pausa := 0.0
var _fase_passo := 0.0
var _gesto := 0.0
var _semente := 0.0
var _abertura := 0.0


func _ready() -> void:
	add_to_group("adulto_escola")
	collision_layer = 524288
	collision_mask = 2
	_semente = randf() * 50.0
	_gesto = randf() * 10.0
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	_montar_corpo()
	if pontos.size() >= 2:
		global_position = pontos[0]
		_alvo = 1
		_pausa = randf_range(0.0, 2.0)
	elif olhar_para != Vector3.ZERO:
		var d := olhar_para - global_position
		rotation.y = atan2(d.x, d.z)


func _montar_corpo() -> void:
	var lista: Array = CityNpcScript.MODELOS
	var i := modelo_index if modelo_index >= 0 and modelo_index < lista.size() \
		else randi() % lista.size()
	var cena := load(CityNpcScript.PASTA + String(lista[i]) + ".fbx") as PackedScene
	if cena == null:
		return
	var rig := Node3D.new()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * escala
	add_child(rig)
	var modelo := cena.instantiate() as Node3D
	rig.add_child(modelo)
	var ap := modelo.find_child("AnimationPlayer", true, false)
	if ap:
		ap.queue_free()
	var sk := _esqueleto(modelo)
	if sk == null:
		return
	for m in sk.get_children():
		if m is MeshInstance3D:
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_poser = HumanoidPoser.new()
	if not _poser.setup(sk, 0.0):
		_poser = null


func _esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s := _esqueleto(c)
		if s:
			return s
	return null


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_gesto += delta

	if pontos.size() >= 2:
		_andar(delta)
	move_and_slide()
	_pose(delta)


func _andar(delta: float) -> void:
	if _pausa > 0.0:
		_pausa -= delta
		return
	var alvo: Vector3 = pontos[_alvo]
	var d := alvo - global_position
	d.y = 0.0
	if d.length() < 0.35:
		_alvo = (_alvo + 1) % pontos.size()
		_pausa = randf_range(PAUSA_NA_PONTA.x, PAUSA_NA_PONTA.y)
		return
	var giro := atan2(d.x, d.z)
	rotation.y = rotate_toward(rotation.y, giro, GIRO * delta)
	# só anda de frente pro destino: virar e andar ao mesmo tempo arrasta o pé
	if absf(angle_difference(rotation.y, giro)) < 0.6:
		var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		velocity.x = frente.x * VELOCIDADE
		velocity.z = frente.z * VELOCIDADE


func _pose(delta: float) -> void:
	if _poser == null:
		return
	var plano := Vector2(velocity.x, velocity.z).length()
	var cadencia := 4.2 + plano * 1.6
	if plano > 0.15:
		_fase_passo += delta * cadencia
	_abertura = lerpf(_abertura, _poser.abertura_para(plano, cadencia), clampf(delta * 6.0, 0.0, 1.0))
	if pontos.size() < 2:
		_poser.pose_conversando(_gesto + _semente, falando)
		return
	_poser.pose_locomocao(_fase_passo, _gesto + _semente,
		clampf(plano / VELOCIDADE, 0.0, 1.0), _abertura)
