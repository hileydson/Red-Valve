extends Node3D

## A JAULA DO JIMMY — no alto de um pilar partido da arena 3 (Capítulo 5).
##
## Montada por código, como tudo que a arena gerada não sabe (regerar a arena
## não a apaga): um capitel de pedra em cima do entulho do pilar (o apoio, pra
## nada ficar no ar) e, nele, a jaula de ferro — piso, teto, cantoneiras,
## barras e a PORTA, numa dobradiça própria, que o Maycow arranca na cena do
## resgate (`arrancar_porta`).
##
## Dentro, o Jimmy (`ator_jimmy.gd`), de frente pra porta, as mãos nas barras:
## sacode a grade, soca a barra, põe o braço pra fora gritando — sorteando,
## sem parar, enquanto a luta acontece lá embaixo (`agitar`).
##
## A frente da jaula (a porta) é o +Z deste nó. O nó fica no TOPO do capitel.
##
##     var jaula = JaulaDoJimmy.new()
##     arena.add_child(jaula)
##     jaula.global_transform = Transform3D(Basis(Vector3.UP, giro), topo)
##     jaula.agitar()

const AtorJimmy := preload("res://scripts/npcs/jimmy/ator_jimmy.gd")
const SOM_PANCADA := "res://assets/sounds/capitulo_5/grade_pancada.ogg"

## Meia largura e altura da jaula (m).
const MEIA := 0.85
const ALTURA := 2.3
const BARRA_RAIO := 0.022
const BARRA_PASSO := 0.19
## O Jimmy fica a este tanto da frente (as mãos dele alcançam as barras).
const JIMMY_DA_FRENTE := 0.46
## O capitel: largura e altura, e quanto a jaula fica recuada nele (sobra
## chão na frente da porta pro Maycow).
const CAPITEL := Vector3(3.6, 0.55, 3.6)
const RECUO := 0.55

var jimmy: Node3D
var porta: Node3D
## Com capitel (o alto do pilar) ou só a jaula (o flash da conversa).
var com_capitel := true

var _ferro: StandardMaterial3D
var _pedra: Material
var _agitando := false
var _som: AudioStreamPlayer3D


func _ready() -> void:
	_ferro = StandardMaterial3D.new()
	_ferro.albedo_color = Color(0.2, 0.13, 0.09)
	_ferro.metallic = 0.55
	_ferro.roughness = 0.75
	if com_capitel:
		_montar_capitel()
	var raiz := Node3D.new()
	raiz.name = "jaula"
	add_child(raiz)
	raiz.position = Vector3(0.0, 0.0, -RECUO if com_capitel else 0.0)
	_montar_jaula(raiz)
	jimmy = AtorJimmy.new()
	jimmy.name = "jimmy_preso"
	raiz.add_child(jimmy)
	jimmy.position = Vector3(0.0, 0.12, MEIA - JIMMY_DA_FRENTE)
	_acender(raiz)
	_som = AudioStreamPlayer3D.new()
	_som.stream = load(SOM_PANCADA)
	_som.unit_size = 14.0
	_som.max_distance = 90.0
	raiz.add_child(_som)
	_som.position = Vector3(0.0, 1.5, MEIA)


## A arena 3 é de noite: sem luz própria a jaula some no céu. Dois SPOTS (o
## renderer mobile conta omni e spot à parte, e a arena já está no teto de 8
## omni por malha): um de cima, cor de brasa, e um de frente, do lado da
## praça, que é de onde o Maycow olha.
func _acender(raiz: Node3D) -> void:
	var de_cima := SpotLight3D.new()
	de_cima.name = "luz_de_cima"
	de_cima.light_color = Color(1.0, 0.6, 0.32)
	de_cima.light_energy = 7.0
	de_cima.spot_range = 8.5
	de_cima.spot_angle = 36.0
	de_cima.shadow_enabled = true
	raiz.add_child(de_cima)
	de_cima.position = Vector3(0.0, ALTURA + 3.0, 0.2)
	de_cima.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	var de_frente := SpotLight3D.new()
	de_frente.name = "luz_de_frente"
	de_frente.light_color = Color(0.85, 0.72, 1.0)
	de_frente.light_energy = 4.5
	de_frente.spot_range = 10.0
	de_frente.spot_angle = 26.0
	raiz.add_child(de_frente)
	var de := Vector3(0.6, 2.4, MEIA + 3.6)
	var para := Vector3(0.0, 1.3, MEIA - JIMMY_DA_FRENTE)
	de_frente.transform = Transform3D(Basis.looking_at(para - de, Vector3.UP), de)


## A pedra do capitel sai da própria arena (o material do pilar), se der.
func usar_pedra(material: Material) -> void:
	_pedra = material
	for nome in ["capitel", "capitel_base"]:
		var m := get_node_or_null(nome) as MeshInstance3D
		if m and _pedra:
			m.material_override = _pedra


func _montar_capitel() -> void:
	var caixa := BoxMesh.new()
	caixa.size = CAPITEL
	var m := MeshInstance3D.new()
	m.name = "capitel"
	m.mesh = caixa
	m.position = Vector3(0.0, -CAPITEL.y * 0.5, 0.0)
	if _pedra:
		m.material_override = _pedra
	else:
		var p := StandardMaterial3D.new()
		p.albedo_color = Color(0.32, 0.29, 0.27)
		p.roughness = 0.95
		m.material_override = p
	add_child(m)
	# a base do capitel desce dentro do entulho do pilar: é o apoio
	var base := BoxMesh.new()
	base.size = Vector3(CAPITEL.x * 0.7, 1.6, CAPITEL.z * 0.7)
	var b := MeshInstance3D.new()
	b.name = "capitel_base"
	b.mesh = base
	b.position = Vector3(0.0, -CAPITEL.y - 0.8, 0.0)
	b.material_override = m.material_override
	add_child(b)


func _barra(pai: Node3D, de: Vector3, ate: Vector3, raio: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = de.distance_to(ate)
	c.radial_segments = 6
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	m.material_override = _ferro
	pai.add_child(m)
	var meio := (de + ate) * 0.5
	var eixo := (ate - de).normalized()
	var b := Basis()
	if absf(eixo.dot(Vector3.UP)) < 0.999:
		var x := eixo.cross(Vector3.UP).normalized()
		b = Basis(x, eixo, x.cross(eixo))
	m.transform = Transform3D(b, meio)


func _chapa(pai: Node3D, centro: Vector3, tamanho: Vector3) -> void:
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	var m := MeshInstance3D.new()
	m.mesh = caixa
	m.material_override = _ferro
	m.position = centro
	pai.add_child(m)


func _montar_jaula(raiz: Node3D) -> void:
	var h := ALTURA
	_chapa(raiz, Vector3(0.0, 0.06, 0.0), Vector3(MEIA * 2.0 + 0.1, 0.12, MEIA * 2.0 + 0.1))
	_chapa(raiz, Vector3(0.0, h, 0.0), Vector3(MEIA * 2.0 + 0.1, 0.08, MEIA * 2.0 + 0.1))
	# argola no teto
	_barra(raiz, Vector3(0.0, h, 0.0), Vector3(0.0, h + 0.35, 0.0), 0.05)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_barra(raiz, Vector3(sx * MEIA, 0.1, sz * MEIA), Vector3(sx * MEIA, h, sz * MEIA), 0.045)
	# os três lados fixos: barras e duas cintas
	var n := int(round(MEIA * 2.0 / BARRA_PASSO))
	for lado in [[Vector3(-MEIA, 0, -MEIA), Vector3(MEIA, 0, -MEIA)],
			[Vector3(-MEIA, 0, -MEIA), Vector3(-MEIA, 0, MEIA)],
			[Vector3(MEIA, 0, -MEIA), Vector3(MEIA, 0, MEIA)]]:
		var a: Vector3 = lado[0]
		var b: Vector3 = lado[1]
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			_barra(raiz, p + Vector3.UP * 0.1, p + Vector3.UP * h, BARRA_RAIO)
		for y in [0.25, 1.15, h - 0.12]:
			_barra(raiz, a + Vector3.UP * y, b + Vector3.UP * y, 0.03)
	# a porta: a frente inteira, presa na dobradiça da esquerda (-X)
	porta = Node3D.new()
	porta.name = "porta"
	raiz.add_child(porta)
	porta.position = Vector3(-MEIA, 0.0, MEIA)
	var largura := MEIA * 2.0
	for k in range(1, n):
		var x := largura * float(k) / n
		_barra(porta, Vector3(x, 0.1, 0.0), Vector3(x, h, 0.0), BARRA_RAIO)
	for y in [0.25, 1.15, h - 0.12]:
		_barra(porta, Vector3(0.0, y, 0.0), Vector3(largura, y, 0.0), 0.03)
	# o cadeado, do lado de fora, na cinta do meio
	_chapa(porta, Vector3(largura - 0.12, 1.1, 0.05), Vector3(0.1, 0.13, 0.05))


# ==============================================================================
# O JIMMY PRESO
# ==============================================================================

## Sorteia os gestos sem parar: sacode, grita com o braço pra fora, soca.
func agitar() -> void:
	if _agitando:
		return
	_agitando = true
	var ultimo := &""
	while _agitando and is_inside_tree() and is_instance_valid(jimmy):
		var opcoes := [&"jaula_sacudir", &"jaula_gritar", &"jaula_bater"]
		opcoes.erase(ultimo)
		var clipe: StringName = opcoes[randi() % opcoes.size()]
		ultimo = clipe
		jimmy.tocar(clipe, 0.35)
		match clipe:
			&"jaula_sacudir":
				await _esperar(2.4 * randi_range(2, 3))
			&"jaula_gritar":
				await _esperar(3.0 * randi_range(1, 2))
			_:
				# as duas pancadas do clipe na barra
				_pancada_em(0.6)
				_pancada_em(1.1)
				await _esperar(2.4)


func parar() -> void:
	_agitando = false


func _pancada_em(t: float) -> void:
	await _esperar(t)
	if is_instance_valid(_som) and _agitando:
		_som.pitch_scale = randf_range(0.9, 1.1)
		_som.play()


func _esperar(seg: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(seg, false).timeout


## A porta arrancada: sai da dobradiça e voa pra trás de quem puxou, girando,
## até cair do pilar (`para` = de onde veio o puxão, em mundo).
func arrancar_porta(para: Vector3) -> void:
	if not is_instance_valid(porta):
		return
	var g := porta.global_transform
	var arena := get_parent()
	porta.get_parent().remove_child(porta)
	arena.add_child(porta)
	porta.global_transform = g
	if is_instance_valid(_som):
		_som.pitch_scale = 0.7
		_som.play()
	var dir := para - porta.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else -global_basis.z
	var de := porta.global_position
	var ate := de + dir * 7.0 + Vector3.DOWN * 22.0
	var t := create_tween().set_parallel(true)
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(porta):
			# sobe um pouco no tranco e cai em arco
			porta.global_position = de.lerp(ate, k) + Vector3.UP * (sin(k * PI) * 2.5)
			porta.rotation = Vector3(k * 5.0, k * 2.0, k * 3.5), 0.0, 1.0, 1.8)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(porta):
			porta.queue_free())


## O ponto (mundo) bem na frente da porta, no chão do capitel.
func frente_da_porta(distancia: float = 0.75) -> Vector3:
	var raiz := get_node_or_null("jaula") as Node3D
	var base := raiz.global_transform if raiz else global_transform
	return base * Vector3(0.0, 0.0, MEIA + distancia)
