extends RefCounted

## Oficina de pedra do Shadow Rock: as malhas de rocha, os dois materiais e os
## detritos que ficam no chao.
##
## Os pedacos genericos (textura de ponto suave, rampas de cor, quad de
## particula, som no mundo, `mundo()`) NAO sao refeitos aqui — vem do
## `seraph_fx.gd`, que ja mantem um cache unico deles pra tela inteira. Duas
## copias das mesmas texturas na VRAM e exatamente o que aquele arquivo foi
## escrito pra evitar.
##
## O que e proprio daqui:
##   - `pedra()`: uma das 24 rochas da biblioteca feita no Blender
##     (`tools/blender/rochas/gerar_pedras.py`), em duas faixas — detalhada pro
##     corpo, magra pros cacos. Cada malha ja vem com a semente das gretas e a
##     curvatura assadas na cor do vertice, que e o que o shader le;
##   - `material()` / `material_quebrado()`: os dois unicos materiais de pedra
##     do jogo, compartilhados por corpo, pedregulho, espada, parede e detritos;
##   - `detritos()`: o monte de cacos que sobe, cai e FICA no chao por alguns
##     segundos — e o que o inimigo cospe a cada tiro que leva.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const Detritos := preload("res://scripts/effects/rock_debris.gd")

const SHADER := "res://shaders/enemies/shadow_rock_body.gdshader"
const TEXTURA := "res://assets/terrain3d/textures/RealisticTexturePack/rockwall.png"

## Som de pedra: o `explosao.mp3` do projeto rebaixado ate virar desabamento.
## Nao ha sample de rocha no acervo e um estouro a 0,4 de pitch le como bloco
## caindo — e o mesmo caminho que o Seraph usa pro corte da espada.
const SOM_PEDRA := "res://assets/sounds/common/explosao.mp3"

## Biblioteca de pedras feita no Blender (`tools/blender/rochas/gerar_pedras.py`).
## A malha de rocha partida tem PLANOS DE CLIVAGEM — faces chatas encontrando-se
## em quinas vivas — e isso sai de cortar a malha com planos, uma operacao de
## bmesh. O gerador por codigo daqui de baixo so sabe amassar uma esfera, e o
## resultado e batata em vez de pedra; ele ficou como RESERVA, pro caso de o
## arquivo nao estar importado.
const BIBLIOTECA := "res://assets/3d_model/enemies/shadow_rock/pedras.glb"
## Dentro do `.glb`, as `PEDRA_00`..`PEDRA_15` sao as detalhadas e o resto as
## simples. O numero acompanha o `SIMPLES_A_PARTIR_DE` do script do Blender.
const SIMPLES_A_PARTIR_DE := 16

## Quantas pedras o gerador de RESERVA faz quando a biblioteca nao esta la.
const VARIEDADES := 18

## Teto de cacos vivos no mundo ao mesmo tempo, somando todos os montes. Cada
## tiro cospe pedra e o jogador dispara rapido: sem isto uma briga longa deixa
## centenas de MeshInstance3D no chao.
const TETO_DETRITOS := 150

static var _malhas: Array[Mesh] = []
static var _malhas_simples: Array[Mesh] = []
static var _carregada: bool = false
static var _mat: ShaderMaterial
static var _mat_quebrado: ShaderMaterial
static var _quad_po: QuadMesh
static var _quad_brasa: QuadMesh
static var _vivos: int = 0


## Quad de particula PROPRIO, e nao o `FX.quad_particula()` do Seraph, por um
## motivo so — mas decisivo:
##
##   `billboard_mode` faz o Godot reconstruir a base do quad virada pra camera,
##   e essa reconstrucao ORTONORMALIZA a transformada. Ortonormalizar joga fora
##   a escala da particula. Sem `billboard_keep_scale = true`, `scale_min` e
##   `scale_max` do ParticleProcessMaterial nao valem nada e TODA particula sai
##   do tamanho cheio da malha — um metro. Foi assim que duas brasinhas de 3 cm
##   nos olhos viravam uma bola branca do tamanho da cabeca.
##
## O quad do Seraph fica como esta: ele foi ajustado em cima desse
## comportamento, e corrigi-lo la mudaria o fogo dele sem ninguem ter pedido.
static func _quad(aditivo: bool) -> QuadMesh:
	if aditivo and _quad_brasa != null:
		return _quad_brasa
	if not aditivo and _quad_po != null:
		return _quad_po

	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FX.ponto_suave()
	m.disable_receive_shadows = true
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	if aditivo:
		_quad_brasa = q
	else:
		_quad_po = q
	return q


## Quad aditivo (brasa, fogo dos olhos, lascas quentes).
static func quad_brasa() -> QuadMesh:
	return _quad(true)


## Quad com alpha comum (po, fumaca de pedra).
static func quad_po() -> QuadMesh:
	return _quad(false)


# ============================================================== materiais

## Material da pedra inteira (corpo, pedregulho, espada, parede).
static func material() -> ShaderMaterial:
	if _mat != null:
		return _mat
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	var tex := load(TEXTURA)
	if tex != null:
		_mat.set_shader_parameter("textura_rocha", tex)
	return _mat


## Material do que ACABOU de quebrar: as gretas abrem e a brasa vaza. Um
## material a parte (e nao um uniform mexido na hora) porque o material do
## corpo e um so pra tela toda — mudar `fratura` nele acenderia o inimigo
## inteiro junto com o caco.
static func material_quebrado() -> ShaderMaterial:
	if _mat_quebrado != null:
		return _mat_quebrado
	_mat_quebrado = material().duplicate() as ShaderMaterial
	# 0,30 e nao 0,60: `fratura` multiplica o brilho da greta por 1,6, entao
	# meio caminho ja deixa o caco cor de ferrugem no chao. O que se quer e
	# pedra cinza com a fenda ainda quente, nao brasa apagando.
	_mat_quebrado.set_shader_parameter("fratura", 0.30)
	return _mat_quebrado


# =============================================================== malhas

## Uma pedra da biblioteca. `indice` < 0 sorteia.
##
## `simples` pede uma das malhas magras (~55 tris em vez de ~110): e o que os
## CACOS usam. Podem ser 150 no chao ao mesmo tempo, e a essa altura eles sao
## seixos de vinte centimetros — ninguem conta faceta neles, mas o orcamento de
## triangulos conta.
static func pedra(indice: int = -1, simples := false) -> Mesh:
	_carrega_biblioteca()
	var banco: Array[Mesh] = _malhas_simples if simples and not _malhas_simples.is_empty() else _malhas
	if banco.is_empty():
		return null
	if indice < 0:
		indice = randi()
	return banco[abs(indice) % banco.size()]


## Puxa as malhas do `.glb` feito no Blender (ver
## `tools/blender/rochas/gerar_pedras.py`). Uma vez por sessao: instancia a
## cena, colhe as malhas, joga a cena fora — as malhas continuam vivas porque
## este array as segura.
##
## Sem o arquivo (ainda nao importado, ou removido), cai no gerador antigo em
## vez de deixar o inimigo sem corpo. A pedra fica pior — esfera amassada em
## vez de rocha com planos de clivagem — mas o jogo nao quebra por causa de um
## asset faltando.
static func _carrega_biblioteca() -> void:
	if _carregada:
		return
	_carregada = true

	var pack := load(BIBLIOTECA) as PackedScene
	if pack != null:
		var raiz := pack.instantiate()
		var achadas: Array[Node] = raiz.find_children("*", "MeshInstance3D", true, false)
		# Por NOME, nao pela ordem da arvore: o `PEDRA_NN` carrega a faixa (as
		# 16 primeiras sao as detalhadas) e a ordem do importador de glTF nao e
		# contrato de ninguem.
		#
		# `String(a.name)`, e nao `a.name` direto: `name` e um StringName, e o
		# `<` entre StringName compara o ENDERECO interno, nao as letras. Sem a
		# conversao o sort "funciona" sem erro nenhum e devolve uma ordem
		# arbitraria — foi assim que as duas faixas sairam trocadas, com os
		# cacos do chao levando as malhas pesadas e o corpo as magras.
		achadas.sort_custom(func(a: Node, b: Node) -> bool:
			return String(a.name) < String(b.name))
		for no in achadas:
			var m := (no as MeshInstance3D).mesh
			if m == null:
				continue
			if _malhas.size() < SIMPLES_A_PARTIR_DE:
				_malhas.append(m)
			else:
				_malhas_simples.append(m)
		raiz.free()

	if _malhas.is_empty():
		push_warning("RockFX: '%s' nao carregou; usando as pedras de reserva geradas por codigo." % BIBLIOTECA)
		for i in VARIEDADES:
			_malhas.append(_gera_pedra(i * 7919 + 13))


## Pedra facetada a partir de uma esfera de baixa resolucao.
##
## Tres coisas acontecem aqui, e as tres importam:
##
##  1. cada vertice e empurrado pra dentro ou pra fora por um numero sorteado —
##     mas o sorteio e indexado pela POSICAO ARREDONDADA do vertice, nao pela
##     ordem em que ele aparece. A esfera do Godot repete vertices na costura
##     das UVs; sorteando por posicao, as copias recebem o mesmo empurrao e a
##     pedra nao abre uma fenda ao longo do meridiano;
##  2. a malha sai DESINDEXADA com uma normal por triangulo. E o facetamento
##     que faz uma esfera amassada virar pedra em vez de batata;
##  3. `COLOR` carrega duas informacoes que o shader nao teria como inventar:
##     em `r` a semente desta pedra (desloca o desenho das gretas) e em `g` o
##     quanto o vertice se projeta pra fora (as reentrancias escurecem).
static func _gera_pedra(semente: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.radial_segments = rng.randi_range(6, 8)
	esf.rings = rng.randi_range(3, 5)
	var arr := esf.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]

	# achatamento e alongamento proprios desta pedra: laje, seixo ou lasca
	var forma := Vector3(
		rng.randf_range(0.68, 1.30),
		rng.randf_range(0.55, 1.25),
		rng.randf_range(0.68, 1.30))

	var sorteado := {}
	var desloc := PackedVector3Array()
	desloc.resize(verts.size())
	var min_r := 9999.0
	var max_r := 0.0
	for i in verts.size():
		var v := verts[i]
		var chave := Vector3i(roundi(v.x * 256.0), roundi(v.y * 256.0), roundi(v.z * 256.0))
		if not sorteado.has(chave):
			# faixa larga: e a diferenca entre uma bola amassada e um bloco
			sorteado[chave] = rng.randf_range(0.58, 1.30)
		var f: float = sorteado[chave]
		var p := v.normalized() * (0.5 * f) * forma
		desloc[i] = p
		var r := p.length()
		min_r = minf(min_r, r)
		max_r = maxf(max_r, r)

	var faixa := maxf(max_r - min_r, 0.0001)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cor_semente := float(abs(semente) % 997) / 997.0
	for f2 in range(0, idx.size() - 2, 3):
		var a := desloc[idx[f2]]
		var b := desloc[idx[f2 + 1]]
		var c := desloc[idx[f2 + 2]]
		var n := (b - a).cross(c - a)
		if n.length() < 0.000001:
			continue
		n = n.normalized()
		for p in [a, b, c]:
			# `g`: 0 no ponto mais afundado da pedra, 1 na quina mais saliente
			var exposto: float = clampf((p.length() - min_r) / faixa, 0.0, 1.0)
			st.set_color(Color(cor_semente, exposto, 1.0, 1.0))
			st.set_normal(n)
			st.add_vertex(p)

	return st.commit() as ArrayMesh


## MeshInstance3D de pedra pronto pra pendurar em qualquer lugar: malha
## sorteada, giro sorteado, tamanho `escala` com variacao.
static func bloco(pai: Node3D, onde: Vector3, escala: float, rng: RandomNumberGenerator,
		variacao := 0.35, quebrado := false, simples := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = pedra(rng.randi(), simples)
	mi.material_override = material_quebrado() if quebrado else material()
	mi.position = onde
	mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var s := escala
	mi.scale = Vector3(
		s * rng.randf_range(1.0 - variacao, 1.0 + variacao),
		s * rng.randf_range(1.0 - variacao, 1.0 + variacao),
		s * rng.randf_range(1.0 - variacao, 1.0 + variacao))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if pai != null:
		pai.add_child(mi)
	return mi


# ============================================================== detritos

## Quantos cacos ainda cabem no mundo. Quem for soltar detrito pergunta antes.
static func cabe_detrito(quantos: int) -> int:
	return clampi(TETO_DETRITOS - _vivos, 0, quantos)


static func _conta(n: int) -> void:
	_vivos = maxi(0, _vivos + n)


## O monte de cacos: sobe, cai, bate no chao e FICA la por `permanencia`
## segundos antes de afundar. E o efeito central deste inimigo — cada dano que
## ele leva arranca pedra dele, e a pedra tem de ficar visivel no chao.
##
## Devolve o no criado (ou null se o teto de cacos estourou).
##
## A ordem aqui nao e livre: o monte so e MONTADO depois de posicionado, porque
## e do `global_position` que sai o raycast do chao. Montar no `_ready` (que
## roda no `add_child`, com o no ainda na origem) procuraria chao a dezenas de
## metros de onde a pedra caiu.
static func detritos(pai: Node, origem: Vector3, quantos: int, forca: float,
		escala: float = 0.16, permanencia: float = 7.0,
		modelos: Array = [], direcao: Vector3 = Vector3.ZERO) -> Node3D:
	if pai == null or not pai.is_inside_tree():
		return null
	var cena := FX.mundo(pai)
	if cena == null:
		return null
	quantos = cabe_detrito(quantos)
	if quantos <= 0:
		return null

	var no = Detritos.new()
	no.quantidade = quantos
	no.forca = forca
	no.escala = escala
	no.permanencia = permanencia
	no.modelos = modelos
	no.direcao = direcao
	cena.add_child(no)
	no.global_position = origem
	no.iniciar()
	if not is_instance_valid(no):
		return null
	_conta(quantos)
	no.tree_exited.connect(func() -> void: _conta(-quantos))
	return no


## Nuvem de po: acompanha toda pedra que quebra. Sem ela o caco parece plastico
## aparecendo do nada.
static func po(quantos: int, tamanho: float, vida := 1.6) -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = tamanho * 0.5
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 75.0
	proc.initial_velocity_min = 0.3
	proc.initial_velocity_max = 1.8
	# po sobe um pouco e assenta: gravidade fraca e positiva no comeco seria
	# fumaca. Aqui ele cai devagar, como poeira de obra.
	proc.gravity = Vector3(0, -0.45, 0)
	proc.damping_min = 1.2
	proc.damping_max = 3.0
	proc.scale_min = tamanho * 0.5
	proc.scale_max = tamanho * 1.5
	proc.scale_curve = FX.curva_pico(0.35)
	proc.color_ramp = FX.rampa(
		[Color(0.58, 0.55, 0.51, 0.55), Color(0.42, 0.40, 0.38, 0.30), Color(0.3, 0.29, 0.28, 0.0)],
		[0.0, 0.45, 1.0])

	var p := GPUParticles3D.new()
	p.amount = quantos
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 0.9
	p.process_material = proc
	p.draw_pass_1 = quad_po()
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3.ONE * -6.0, Vector3.ONE * 12.0)
	p.emitting = true
	return p


## Lascas: os cacos pequenos demais pra virar malha. Saem rapido e somem.
## Junto com o `po`, e o que da o "estalo" visual de pedra sendo arrancada.
static func lascas(quantos: int, forca: float) -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.12
	proc.direction = Vector3(0, 0.4, 0)
	proc.spread = 180.0
	proc.initial_velocity_min = forca * 0.4
	proc.initial_velocity_max = forca
	proc.gravity = Vector3(0, -14.0, 0)
	proc.damping_min = 0.2
	proc.damping_max = 1.0
	proc.scale_min = 0.03
	proc.scale_max = 0.10
	proc.color_ramp = FX.rampa(
		[Color(0.72, 0.68, 0.63, 1.0), Color(0.45, 0.42, 0.40, 0.9), Color(0.3, 0.28, 0.27, 0.0)],
		[0.0, 0.6, 1.0])

	var p := GPUParticles3D.new()
	p.amount = quantos
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 1.0
	p.process_material = proc
	p.draw_pass_1 = quad_po()
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3.ONE * -8.0, Vector3.ONE * 16.0)
	p.emitting = true
	return p


## Estouro de pedra: po + lascas + um clarao curto e quente na fratura.
## Serve pro pedregulho batendo, pro membro se espatifando e pra parede caindo.
static func quebra(pai: Node, pos: Vector3, tamanho: float, com_som := true) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var cena := FX.mundo(pai)
	if cena == null:
		return
	var raiz := Node3D.new()
	raiz.name = "PedraQuebrando"
	cena.add_child(raiz)
	raiz.global_position = pos

	raiz.add_child(po(int(14 + tamanho * 12.0), tamanho * 0.8))
	raiz.add_child(lascas(int(18 + tamanho * 20.0), 3.0 + tamanho * 3.0))

	# clarao de brasa: so um instante, e o que sobra da greta que se partiu
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.45, 0.14)
	luz.light_energy = 2.6 + tamanho
	luz.omni_range = 2.0 + tamanho * 2.5
	luz.shadow_enabled = false
	raiz.add_child(luz)

	if com_som:
		# pitch bem baixo: e o que transforma um estouro em desabamento
		FX.som_no_mundo(pai, pos, SOM_PEDRA, -9.0 + tamanho * 2.0,
			randf_range(0.34, 0.48))

	var t := raiz.create_tween()
	t.tween_property(luz, "light_energy", 0.0, 0.35)
	t.tween_interval(2.0)
	t.tween_callback(raiz.queue_free)
