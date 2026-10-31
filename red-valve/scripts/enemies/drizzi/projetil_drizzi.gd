extends Node3D

## O que a Drizzi monstro arremessa no Maycow (`drizzi_monstro.gd`):
##
##   POEIRA  um bolo de terra e poeira que ela tirou da boca: voa em arco
##           soltando poeira, e no Maycow faz dano e suja a tela de terra;
##           no chão vira uma nuvem.
##   ORGAO   um órgão dela, arrancado das tripas de baixo: voa girando e
##           espirrando sangue, e explode em sangue onde bate.
##
##     var p = Projetil.criar(pai, Projetil.Tipo.ORGAO)
##     p.lancar(origem, alvo, 0.9)

enum Tipo { POEIRA, ORGAO }

const ESTE := "res://scripts/enemies/drizzi/projetil_drizzi.gd"
const Poeira := preload("res://scripts/effects/poeira_drizzi.gd")
const GRAVIDADE := 9.0
const DANO := {Tipo.POEIRA: 7, Tipo.ORGAO: 13}
const RAIO := {Tipo.POEIRA: 0.7, Tipo.ORGAO: 0.5}
const SOM_POEIRA := "res://assets/sounds/igreja/gosma_cai.ogg"
const SOM_ORGAO := "res://assets/sounds/igreja/gota_impacto.ogg"
const COR_NA_TELA := Color(0.36, 0.29, 0.21)

var tipo: Tipo = Tipo.POEIRA
var velocidade := Vector3.ZERO
var _vida := 0.0
var _rastro: Node3D
var _corpo: Node3D


static func criar(pai: Node, de_que: Tipo) -> Node3D:
	var p: Node3D = load(ESTE).new()
	p.tipo = de_que
	p.name = "projetil_drizzi"
	pai.add_child(p)
	return p


## O órgão que fica na mão dela antes do arremesso (o mesmo do voo).
static func orgao() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "orgao"
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.04, 0.06)
	m.roughness = 0.25
	m.metallic_specular = 0.8
	m.rim_enabled = true
	m.rim = 0.4
	var corpo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.11
	esfera.height = 0.2
	esfera.radial_segments = 12
	esfera.rings = 6
	esfera.material = m
	corpo.mesh = esfera
	corpo.scale = Vector3(1.25, 0.85, 1.0)
	raiz.add_child(corpo)
	# o pedaço de tripa que vem junto, pendurado
	var tripa := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.035
	cap.height = 0.32
	cap.radial_segments = 8
	cap.rings = 2
	var mt := m.duplicate() as StandardMaterial3D
	mt.albedo_color = Color(0.48, 0.12, 0.12)
	cap.material = mt
	tripa.mesh = cap
	tripa.position = Vector3(0.05, -0.15, 0.0)
	tripa.rotation.z = 0.5
	raiz.add_child(tripa)
	return raiz


func _ready() -> void:
	if tipo == Tipo.ORGAO:
		_corpo = orgao()
		add_child(_corpo)
	else:
		_corpo = Node3D.new()
		add_child(_corpo)
		var bola := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.22
		esfera.height = 0.4
		esfera.radial_segments = 10
		esfera.rings = 5
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.15, 0.1)
		m.roughness = 1.0
		esfera.material = m
		bola.mesh = esfera
		_corpo.add_child(bola)


## Arco que chega em `alvo` em `tempo` segundos.
func lancar(origem: Vector3, alvo: Vector3, tempo: float) -> void:
	global_position = origem
	var d := alvo - origem
	velocidade = Vector3(d.x / tempo, (d.y + 0.5 * GRAVIDADE * tempo * tempo) / tempo, d.z / tempo)
	# o rastro nasce já no lugar (as partículas ficam no mundo, atrás dela)
	if tipo == Tipo.ORGAO:
		_rastro = Poeira.pingando(_corpo, 1.4)
	else:
		_rastro = Poeira.nuvem(self, global_position, 0.6, 1.0, 26)


func _physics_process(delta: float) -> void:
	_vida += delta
	velocidade.y -= GRAVIDADE * delta
	var antes := global_position
	global_position += velocidade * delta
	if is_instance_valid(_corpo):
		_corpo.rotate_x(delta * (9.0 if tipo == Tipo.ORGAO else 4.0))
		_corpo.rotate_z(delta * 5.0)
	var jogador := get_tree().get_first_node_in_group("player") as Node3D
	if jogador and global_position.distance_to(jogador.global_position + Vector3(0, 0.3, 0)) < float(RAIO[tipo]) + 0.35:
		if not GlobalEvents.in_cutscene and not GlobalEvents.agarrao_rodando \
				and jogador.get("invulnerable") != true:
			if jogador.has_method("take_damage"):
				jogador.take_damage(int(DANO[tipo]))
			_acertou_o_maycow()
		_estourar()
		return
	var q := PhysicsRayQueryParameters3D.create(antes, global_position + Vector3(0, -0.05, 0))
	q.collision_mask = 2
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() or _vida > 4.0:
		if not r.is_empty():
			global_position = r["position"]
		_estourar()


func _acertou_o_maycow() -> void:
	GlobalUtils.shake_camera(0.3, 0.35 if tipo == Tipo.ORGAO else 0.25)
	GlobalUtils.vibrate_controller(null, 0.7, 0.6, 0.3)
	if tipo == Tipo.POEIRA:
		_terra_na_tela()


## A terra no rosto: a tela fica marrom e embaçada um instante.
func _terra_na_tela() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 60
	get_tree().root.add_child(camada)
	var r := ColorRect.new()
	r.color = Color(COR_NA_TELA, 0.62)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(r)
	var t := camada.create_tween()
	t.tween_interval(0.35)
	t.tween_property(r, "color:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_callback(camada.queue_free)


func _estourar() -> void:
	set_physics_process(false)
	var pai := get_parent()
	if tipo == Tipo.ORGAO:
		Poeira.respingo(pai, global_position, 1.3)
		_som(SOM_ORGAO, randf_range(0.7, 0.85))
	else:
		var n := Poeira.nuvem(pai, global_position, 2.2, 2.0, 40)
		n.call("assentar", 3.5)
		_som(SOM_POEIRA, randf_range(0.6, 0.75))
	if is_instance_valid(_corpo):
		_corpo.visible = false
	if is_instance_valid(_rastro):
		_rastro.reparent(pai)
		_rastro.call("assentar", 1.5)
	await get_tree().create_timer(1.6, false).timeout
	if is_inside_tree():
		queue_free()


func _som(caminho: String, tom: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(caminho)
	s.pitch_scale = tom
	s.max_distance = 30.0
	s.volume_db = 2.0
	get_parent().add_child(s)
	s.global_position = global_position
	s.play()
	s.finished.connect(s.queue_free)
