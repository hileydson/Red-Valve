extends Node3D

## Um membro que foi ARRANCADO do Unknown Neighbor: braco, mao, perna,
## cabeca.
##
## Primo direto do `rock_limb.gd` (o membro do Shadow Rock), e pela mesma razao:
## o jogador tem de VER o braco cair, girando, antes de virar coisa nenhuma. E
## isso que faz o golpe valer como mutilacao em vez de como particula.
##
## A diferenca e' o que acontece na aterrissagem. A pedra se espatifa; isto
## aqui NAO. Um braco de gente cai, quica uma vez e fica ali no chao — e fica
## MUITO tempo, porque e o unico registro que sobra de que aquilo era uma
## pessoa. No fim da briga o chao em volta dele conta o que aconteceu.
##
## O parasita continua vivo no coto: enquanto o membro esta no chao, as hastes
## que sobraram no corte ainda se mexem, procurando o corpo de onde sairam.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const NFX := preload("res://scripts/effects/neighbor_fx.gd")

const CHAO := 2
const GRAVIDADE := 19.0

## Qual membro e' este ("braco_l", "mao_r", "perna_l", "cabeca"...). So muda a
## forma que se monta.
var tipo: String = "braco_r"
var comprimento: float = 0.58
var grossura: float = 0.075
var cor_pele: Color = Color(0.72, 0.56, 0.45)
var cor_roupa: Color = Color(0.22, 0.24, 0.28)
var cor_veia: Color = Color(0.72, 1.0, 0.24)
var linhagem: int = 1
var impulso: Vector3 = Vector3.ZERO
## Quanto tempo o membro fica no chao depois de parar.
##
## Era 40 s, com a ideia de que o chao em volta dele contasse a briga. Contava
## demais: numa rua com tres vizinhos, e depois numa arena inteira, o cenario
## ficava coberto de braco e cabeca, e o que era registro virou entulho. Doze
## segundos e' o suficiente pra o jogador VER a peca cair, olhar pra ela e
## seguir — que era o unico trabalho dela.
var permanencia: float = 12.0

var _vel: Vector3 = Vector3.ZERO
var _giro: Vector3 = Vector3.ZERO
var _chao_y: float = -99999.0
var _caiu: bool = false
var _tempo: float = 0.0
var _hastes: Array[Node3D] = []
var _sangue: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_monta()
	_vel = impulso
	_giro = Vector3(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-5.0, 5.0),
		_rng.randf_range(-7.0, 7.0))
	_acha_chao()

	_sangue = NFX.respingo(cor_veia.lerp(Color(0.45, 0.03, 0.05), 0.6), 34, 3.4)
	_sangue.one_shot = false
	_sangue.explosiveness = 0.0
	_sangue.amount = 14
	add_child(_sangue)
	FX.som_no_mundo(self, global_position, NFX.SOM_CARNE, -3.0, _rng.randf_range(0.7, 0.9))


func _monta() -> void:
	var mat_pele := StandardMaterial3D.new()
	mat_pele.albedo_color = cor_pele
	mat_pele.roughness = 0.75
	var mat_roupa := StandardMaterial3D.new()
	mat_roupa.albedo_color = cor_roupa
	mat_roupa.roughness = 0.92

	if tipo == "cabeca":
		# a cabeca e' uma esfera achatada; nao tem parte de roupa
		_malha(_esfera(grossura * 1.55, 1.12), Vector3.ZERO, mat_pele)
	else:
		# Metade de roupa (a que estava presa ao corpo) e metade de pele: e o
		# contraste das duas que diz de onde no corpo aquilo saiu.
		_malha(_capsula(grossura, comprimento * 0.52),
			Vector3(0, comprimento * 0.24, 0), mat_roupa)
		_malha(_capsula(grossura * 0.92, comprimento * 0.56),
			Vector3(0, -comprimento * 0.24, 0), mat_pele)
		if tipo.begins_with("mao"):
			for i in 4:
				var a := TAU * i / 4.0
				_malha(_capsula(grossura * 0.30, comprimento * 0.42),
					Vector3(cos(a) * grossura * 0.5, -comprimento * 0.48, sin(a) * grossura * 0.5),
					mat_pele)

	# O CORTE: o coto do parasita virado pra cima, no lugar onde o membro se
	# soltou, com as hastes ainda se mexendo.
	var mat_par := NFX.material_parasita(linhagem)
	var coto := MeshInstance3D.new()
	var malha := NFX.peca("coto")
	coto.mesh = malha if malha != null else _esfera(grossura * 1.3, 0.8)
	coto.scale = Vector3.ONE * grossura * 3.2
	coto.position = Vector3(0, comprimento * 0.5, 0)
	coto.material_override = mat_par
	coto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coto)

	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var pivo := Node3D.new()
		pivo.position = Vector3(cos(a) * grossura * 0.5, comprimento * 0.5,
			sin(a) * grossura * 0.5)
		add_child(pivo)
		var h := MeshInstance3D.new()
		var mh := NFX.peca("haste")
		h.mesh = mh if mh != null else _capsula(grossura * 0.22, grossura * 2.0)
		h.scale = Vector3(grossura * 1.1, grossura * _rng.randf_range(3.0, 5.0), grossura * 1.1)
		h.rotation.x = PI   # a haste pende da peca; vira ela pra cima
		h.material_override = mat_par
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivo.add_child(h)
		_hastes.append(pivo)

	var luz := OmniLight3D.new()
	luz.light_color = cor_veia
	luz.light_energy = 1.1
	luz.omni_range = 1.6
	luz.position.y = comprimento * 0.5
	add_child(luz)


func _malha(m: Mesh, onde: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = onde
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _capsula(raio: float, comp: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = raio
	m.height = maxf(comp, raio * 2.05)
	m.radial_segments = 8
	m.rings = 3
	return m


func _esfera(raio: float, achata: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = raio * 2.0 * achata
	m.radial_segments = 10
	m.rings = 6
	return m


func _acha_chao() -> void:
	if not is_inside_tree():
		return
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 30.0, CHAO)
	var hit := espaco.intersect_ray(q)
	if not hit.is_empty():
		_chao_y = (hit["position"] as Vector3).y


func _physics_process(delta: float) -> void:
	_tempo += delta

	# as hastes do corte continuam procurando o corpo — vivas depois do membro
	for i in _hastes.size():
		var pivo: Node3D = _hastes[i]
		if is_instance_valid(pivo):
			pivo.rotation.x = sin(_tempo * 3.4 + float(i)) * 0.45
			pivo.rotation.z = cos(_tempo * 2.7 + float(i) * 1.3) * 0.40

	if _caiu:
		return

	_vel.y -= GRAVIDADE * delta
	global_position += _vel * delta
	rotation += _giro * delta

	if _chao_y > -99998.0 and global_position.y <= _chao_y + grossura:
		_pousa()
	elif _tempo > 6.0:
		# nao achou chao (caiu num buraco da cidade): some em silencio
		queue_free()


func _pousa() -> void:
	_caiu = true
	global_position.y = _chao_y + grossura * 0.9
	# deita: nada de membro espetado no chao em pe
	rotation = Vector3(PI * 0.5, _rng.randf_range(0.0, TAU), 0.0)
	if is_instance_valid(_sangue):
		_sangue.amount = 4
		var t := create_tween()
		t.tween_interval(2.0)
		t.tween_callback(func() -> void:
			if is_instance_valid(_sangue):
				_sangue.emitting = false)
	FX.som_no_mundo(self, global_position, NFX.SOM_CARNE, -12.0, 0.5)

	var saida := create_tween()
	saida.tween_interval(permanencia)
	saida.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.9)
	saida.tween_callback(queue_free)
