extends RefCounted

## Ferramentaria do "Unknown Neighbor" — o inimigo que era uma pessoa comum.
##
## Mesmo contrato do `seraph_fx.gd`: uma biblioteca de malhas modeladas que
## carrega UMA vez pro jogo inteiro, mais os materiais e particulas que os
## poderes dele usam. O que e proprio daqui sao as LINHAGENS: as quatro
## variacoes do bicho, que compartilham a mesma silhueta e se distinguem pela
## cor do parasita e pelo formato da coroa.
##
## As pecas vem do `tools/blender/vizinho/gerar_vizinho.py`, na mesma convencao
## do Seraph (membro pende de y=0 a y=-1, tronco sobe de y=0 a y=1, tudo dentro
## de [-0.5, 0.5] em x e z, frente no -Z). Sem o `.glb` importado, `peca()`
## devolve null e quem chama cai na primitiva de reserva: o inimigo fica feio,
## mas fica de pe.

const FX := preload("res://scripts/effects/seraph_fx.gd")

const BIBLIOTECA := "res://assets/3d_model/enemies/folded_neighbor/vizinho.glb"
const SHADER_PARASITA := "res://shaders/enemies/folded_neighbor_parasite.gdshader"

const SOM_DOBRA := "res://assets/sounds/player/espaco_travel.mp3"
const SOM_GRITO := "res://assets/sounds/enemies/seco_scream.mp3"
const SOM_SORRISO := "res://assets/sounds/enemies/scary_smile.mp3"
const SOM_CARNE := "res://assets/sounds/player/blood_out.mp3"
const SOM_DOR := "res://assets/sounds/episodios/pain.mp3"
const SOM_GLITCH := "res://assets/sounds/episodios/trailer/glitch.mp3"

# --------------------------------------------------------------- linhagens
#
# As quatro variacoes. O pedido era "parecido mas facil de distinguir a
# diferenca", entao a diferenca esta em DOIS canais que se leem ao mesmo tempo
# e a qualquer distancia:
#
#   COR       — o parasita inteiro (flor da cabeca, veias, foice, casca) e de
#               uma cor so, e ela e a primeira coisa que o jogador ve na
#               nevoa.
#   COROA     — o formato das petalas que abrem na cabeca. Em contraluz, onde
#               a cor morre, a silhueta ainda separa um do outro.
#
# Os numeros (vida, dano, velocidade) vem depois: sao o que o jogador descobre
# brigando, nao o que ele usa pra reconhecer.

enum Linhagem { PALIDO, BILIAR, ESCARLATE, CINZENTO }

const LINHAGENS := [
	{
		"id": "PALIDO",
		"nome": "NEIGHBOR_PALE",
		"cor": Color(0.88, 0.90, 0.86),
		"cor_veia": Color(0.62, 0.86, 1.0),
		"cor_luz": Color(0.55, 0.78, 1.0),
		"coroa": "petala_lisa",
		"petalas": 4,
		"vida": 0.80, "dano": 0.85, "velocidade": 1.30, "dobra": 1.0, "escala": 0.97,
	},
	{
		"id": "BILIAR",
		"nome": "NEIGHBOR_BILE",
		"cor": Color(0.47, 0.58, 0.16),
		"cor_veia": Color(0.72, 1.0, 0.24),
		"cor_luz": Color(0.55, 0.95, 0.25),
		"coroa": "petala_bulbo",
		"petalas": 5,
		"vida": 1.0, "dano": 0.95, "velocidade": 0.95, "dobra": 1.0, "escala": 1.0,
	},
	{
		"id": "ESCARLATE",
		"nome": "NEIGHBOR_CRIMSON",
		"cor": Color(0.42, 0.06, 0.08),
		"cor_veia": Color(1.0, 0.16, 0.12),
		"cor_luz": Color(1.0, 0.18, 0.14),
		"coroa": "petala_espinho",
		"petalas": 6,
		"vida": 1.35, "dano": 1.25, "velocidade": 0.88, "dobra": 0.8, "escala": 1.06,
	},
	{
		"id": "CINZENTO",
		"nome": "NEIGHBOR_ASH",
		"cor": Color(0.22, 0.21, 0.23),
		"cor_veia": Color(1.0, 0.58, 0.22),
		"cor_luz": Color(1.0, 0.52, 0.20),
		"coroa": "petala_chifre",
		"petalas": 3,
		"vida": 1.15, "dano": 1.0, "velocidade": 0.92, "dobra": 1.9, "escala": 1.02,
	},
]


static func linhagem(i: int) -> Dictionary:
	return LINHAGENS[clampi(i, 0, LINHAGENS.size() - 1)]


# --------------------------------------------------------- biblioteca de pecas

static var _pecas: Dictionary = {}
static var _pecas_lidas: bool = false


## Uma peca do parasita pelo nome ("nucleo", "foice", "petala_lisa"...).
## `null` quando o `.glb` nao esta importado — mesmo contrato da biblioteca do
## Seraph e da de pedras do Shadow Rock.
static func peca(nome: String) -> Mesh:
	_carrega()
	return _pecas.get(nome, null) as Mesh


static func _carrega() -> void:
	if _pecas_lidas:
		return
	_pecas_lidas = true
	if not ResourceLoader.exists(BIBLIOTECA):
		push_warning("NeighborFX: %s nao encontrado; o parasita cai nas primitivas." % BIBLIOTECA)
		return
	var cena := load(BIBLIOTECA) as PackedScene
	if cena == null:
		return
	var raiz := cena.instantiate()
	_colhe(raiz)
	raiz.queue_free()


static func _colhe(no: Node) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		if mi.mesh != null:
			# String(): `name` e StringName, e chave StringName nao bate com
			# busca por literal no dicionario.
			_pecas[String(mi.name)] = mi.mesh
	for f in no.get_children():
		_colhe(f)


# ------------------------------------------------------------------ materiais

## Um ShaderMaterial por linhagem, guardado pro jogo inteiro: sao dezenas de
## malhas por bicho e o shader nao tem nada por instancia alem da cor.
static var _mat_parasita: Dictionary = {}


static func material_parasita(l: int) -> Material:
	if _mat_parasita.has(l):
		return _mat_parasita[l]
	var dados := linhagem(l)
	var m := ShaderMaterial.new()
	var sh := load(SHADER_PARASITA) as Shader
	if sh == null:
		# Sem o shader o bicho ainda tem de aparecer, so que sem veia.
		var st := StandardMaterial3D.new()
		st.albedo_color = dados["cor"]
		st.emission_enabled = true
		st.emission = dados["cor_veia"]
		st.emission_energy_multiplier = 1.4
		st.roughness = 0.35
		_mat_parasita[l] = st
		return st
	m.shader = sh
	m.set_shader_parameter("carne", dados["cor"])
	m.set_shader_parameter("veia", dados["cor_veia"])
	_mat_parasita[l] = m
	return m


## Sangue/seiva: a mesma funcao serve pro corte de membro e pro impacto, so
## muda a quantidade. Aditivo NAO — sangue que brilha vira faisca.
static func respingo(cor: Color, quantos: int, forca: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(quantos, 1)
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.92
	p.draw_pass_1 = _quad_gota()

	var mp := ParticleProcessMaterial.new()
	mp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mp.emission_sphere_radius = 0.10
	mp.direction = Vector3(0, 1, 0)
	mp.spread = 62.0
	mp.initial_velocity_min = forca * 0.4
	mp.initial_velocity_max = forca
	mp.gravity = Vector3(0, -9.0, 0)
	mp.scale_min = 0.05
	mp.scale_max = 0.16
	mp.color = cor
	mp.color_ramp = FX.rampa(
		[cor, Color(cor.r * 0.5, cor.g * 0.5, cor.b * 0.5, 0.8), Color(0, 0, 0, 0)],
		[0.0, 0.55, 1.0])
	p.process_material = mp
	p.emitting = true
	return p


## Quad das gotas. Opaco-alfa (nao aditivo): e liquido, nao luz.
static var _gota_cache: QuadMesh = null


static func _quad_gota() -> QuadMesh:
	if _gota_cache != null:
		return _gota_cache
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# billboard_keep_scale LIGADO. Sem ele o billboard DESCARTA a escala da
	# particula e todo `scale_min/max` do ParticleProcessMaterial vira letra
	# morta: cada gota sai do tamanho do quad (1 m) e o corte de um braco vira
	# uma nuvem de bolhas brancas do tamanho de uma pessoa. Foi exatamente isso
	# na primeira rodada de teste. (O `quad_particula` do seraph_fx nao tem a
	# flag; por isso este arquivo tem os proprios quads em vez de reusar o de
	# la — mexer naquele mudaria o fogo do Seraph.)
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FX.ponto_suave()
	m.disable_receive_shadows = true
	q.material = m
	_gota_cache = q
	return q


## Quad do esporo: aditivo, com billboard_keep_scale pela mesma razao da gota.
static var _esporo_cache: QuadMesh = null


static func _quad_esporo() -> QuadMesh:
	if _esporo_cache != null:
		return _esporo_cache
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FX.ponto_suave()
	m.disable_receive_shadows = true
	q.material = m
	_esporo_cache = q
	return q


## Esporo: poeira lenta que sobe, usada pela flor da cabeca e pelas hastes.
static func esporo(cor: Color, quantos: int, raio: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(quantos, 1)
	p.lifetime = 3.4
	p.draw_pass_1 = _quad_esporo()

	var mp := ParticleProcessMaterial.new()
	mp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mp.emission_sphere_radius = raio
	mp.direction = Vector3(0, 1, 0)
	mp.spread = 34.0
	mp.initial_velocity_min = 0.05
	mp.initial_velocity_max = 0.30
	mp.gravity = Vector3(0, 0.22, 0)
	mp.scale_min = 0.02
	mp.scale_max = 0.07
	mp.scale_curve = FX.curva_pico(0.35)
	mp.color_ramp = FX.rampa(
		[Color(cor.r, cor.g, cor.b, 0.0), cor, Color(cor.r, cor.g, cor.b, 0.0)],
		[0.0, 0.3, 1.0])
	p.process_material = mp
	p.emitting = true
	return p
