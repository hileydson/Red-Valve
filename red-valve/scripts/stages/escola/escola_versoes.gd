extends Node

## AS DUAS ESCOLAS DO CAPÍTULO 1: a CLARA e a ESCURA.
##
## A cena gerada (`gerar_cena_escola.py`) é a escola ESCURA — abandonada,
## pichada, com lâmpada piscando, buraco na parede e a grade no corredor sul.
## No começo do Capítulo 1 a escola ainda não é isso: são seis da tarde, fim de
## expediente, tudo aceso e funcionando. Esta peça monta a versão CLARA por
## cima da cena (sem tocar no gerador) e, no raio da Dona Nice, desfaz tudo
## numa ONDA que sai da quadra e escurece o prédio por onde passa.
##
## O que a clara muda, e a onda desfaz:
##  - luz: as lâmpadas param de piscar, as salas mortas (101, 103, 105, 107) e
##    os buracos de lâmpada dos corredores ganham luz, o luar e o brilho dos
##    buracos apagam, a lua vira o sol de fim de tarde;
##  - ambiente e lente: mais luz, menos névoa, sem grão nem vinheta pesada;
##  - chuva no pátio desligada;
##  - sujeira: pichação, decalques (poça, caco, barro, teia), bolinha de papel,
##    lixo, mato, pneu, forro caído, os rabiscos e avisos de abandono;
##  - a GRADE some (e a colisão dela sai) e os dois BURACOS viram parede;
##  - as portas: trancada nenhuma (ver `porta_escola.gd`, que pergunta pelo
##    `Eventos.escola_clara()`).
##
## Quem usa: `capitulo_1_escola.gd`.

const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")
const ONDA := preload("res://shaders/effects/onda_realidade.gdshader")

## As salas sem lâmpada nenhuma na escura, e as lâmpadas que faltam nos
## corredores (os "buracos" da fileira). Mesmas contas do gerador: duas por sala
## a 4,88 m e 9,77 m da parede oeste dela; corredor a cada 8,79 m.
const LUZES_SALA := [
	Vector3(5.233, 3.18, 5.175), Vector3(10.117, 3.18, 5.175),     # 101
	Vector3(35.233, 3.18, 5.175), Vector3(40.117, 3.18, 5.175),    # 103
	Vector3(17.233, 3.18, 62.5), Vector3(22.117, 3.18, 62.5),      # 105
	Vector3(47.233, 3.18, 62.5), Vector3(52.117, 3.18, 62.5),      # 107
]
const LUZES_CORREDOR := [
	Vector3(13.53125, 3.18, 12.85), Vector3(48.68125, 3.18, 12.85),
	Vector3(4.74375, 3.18, 54.5), Vector3(13.53125, 3.18, 54.5), Vector3(39.89375, 3.18, 54.5),
	Vector3(73.15, 3.18, 24.345), Vector3(73.15, 3.18, 43.005),
]
## Os dois rombos, em coordenadas da planta (x, z do meio da parede), e o
## tamanho do remendo de parede (largura no plano da parede, altura).
const REMENDOS := [
	{"pos": Vector3(67.0, 1.0, 67.825), "tam": Vector3(2.3, 2.05, 0.38)},
	{"pos": Vector3(0.175, 1.0, 62.5), "tam": Vector3(0.38, 2.05, 2.3)},
]
## Nomes (pedaços) de mobília que são sujeira de abandono.
const SUJEIRA := ["lixo", "pneu", "mato", "livros_chao", "saco", "forro", "picareta", "fio_"]
## Textos (chave do CSV no Label3D) que só existem na escola abandonada.
const TEXTOS_DE_ABANDONO := ["ESC_RABISCO", "ESC_CARTAZ_DESAPARECIDO", "ESC_AVISO_FECHADO",
	"ESC_PLACA_INTERDITADO", "ESC_LOUSA_104"]

const RAIO_ONDA := 82.0
const ALTURA_ONDA := 9.0

var escola: Node3D
var clara: bool = false
## Raio atual da onda da transformação (0 antes, RAIO_ONDA no fim).
var raio_onda: float = 0.0

## Cada coisa que a onda escurece: {"pos": Vector3, "fazer": Callable, "nuvem": bool}.
var _elementos: Array = []
var _ambiente_escuro := {}
var _ambiente_claro := {}
var _lente_escura := {}
var _lente_clara := {}
var _lua_escura := {}
var _extras: Array = []


func _init(dono: Node3D) -> void:
	escola = dono
	name = "versoes_da_escola"


# ==============================================================================
# A ESCOLA CLARA
# ==============================================================================

func preparar_clara() -> void:
	clara = true
	escola.set("piscar_lampadas", false)
	_luzes_claras()
	_luminarias_acesas()
	_ambiente_claro_e_lente()
	_sem_chuva()
	_sem_sujeira()
	_sem_grade_nem_buraco()


func _luzes_claras() -> void:
	var luzes := escola.get_node_or_null("luzes")
	if luzes == null:
		return
	var modelo_sala := luzes.get_node_or_null("luz_sala_102_0") as Light3D
	var modelo_sala_amb := luzes.get_node_or_null("luz_sala_102_0_ambiente") as Light3D
	var modelo_corr := luzes.get_node_or_null("fluor_corredor_norte_0") as Light3D
	var modelo_corr_amb := luzes.get_node_or_null("fluor_corredor_norte_0_ambiente") as Light3D
	for luz in luzes.get_children():
		if not (luz is Light3D):
			continue
		var l := luz as Light3D
		var nome := String(l.name)
		if nome.begins_with("luar") or nome.begins_with("brilho_buraco"):
			l.visible = false
			var acender := func() -> void:
				if is_instance_valid(l):
					l.visible = true
			_lembrar(l.global_position, acender, nome.begins_with("brilho"))
		elif l.has_meta("piscar"):
			# a escura pisca a partir da energia autorada; aqui fica firme nela
			var cone := escola.get_node_or_null("cones/cone_" + nome) as Node3D
			if cone:
				cone.visible = true
	for p in LUZES_SALA:
		_luz_extra(modelo_sala, p)
		_luz_extra(modelo_sala_amb, Vector3(p.x, 1.6, p.z))
	for p in LUZES_CORREDOR:
		_luz_extra(modelo_corr, p)
		_luz_extra(modelo_corr_amb, Vector3(p.x, 1.6, p.z))
	var lua := escola.get_node_or_null("lua") as DirectionalLight3D
	if lua:
		_lua_escura = {"cor": lua.light_color, "energia": lua.light_energy}
		lua.light_color = Color(1.0, 0.68, 0.45)
		lua.light_energy = 1.35


func _luz_extra(modelo: Light3D, pos: Vector3) -> void:
	if modelo == null:
		return
	var l := modelo.duplicate() as Light3D
	for m in l.get_meta_list():
		l.remove_meta(m)
	escola.get_node("luzes").add_child(l)
	l.global_position = pos
	l.global_rotation = modelo.global_rotation
	_extras.append(l)
	var apagar := func() -> void:
		if is_instance_valid(l):
			l.queue_free()
	_lembrar(pos, apagar, true)


## As luminárias de tubo morto ganham o material do tubo aceso.
func _luminarias_acesas() -> void:
	var aceso: Material = null
	var mortas: Array = []
	for m in escola.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			if aceso == null and mat.resource_name == "lum_tubo_aceso":
				aceso = mat
			elif mat.resource_name in ["lum_tubo_morto", "lum_bulbo_morto"]:
				mortas.append([mi, i])
	if aceso == null:
		return
	for par in mortas:
		var mi: MeshInstance3D = par[0]
		var i: int = par[1]
		mi.set_surface_override_material(i, aceso)
		var morrer := func() -> void:
			if is_instance_valid(mi):
				mi.set_surface_override_material(i, null)
		_lembrar(mi.global_position, morrer, false)


func _ambiente_claro_e_lente() -> void:
	var we := escola.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env := we.environment
		_ambiente_escuro = _ler_ambiente(env)
		_ambiente_claro = {
			"ambient_light_color": Color(0.46, 0.43, 0.39),
			"ambient_light_energy": 2.3,
			"tonemap_exposure": 1.5,
			"fog_light_color": Color(0.36, 0.30, 0.26),
			"fog_density": 0.006,
			"background_energy_multiplier": 1.4,
			"adjustment_saturation": 1.0,
			"adjustment_contrast": 1.04,
		}
		_aplicar_ambiente(env, _ambiente_claro)
		var ceu := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
		if ceu:
			_ambiente_escuro["ceu_topo"] = ceu.sky_top_color
			_ambiente_escuro["ceu_horizonte"] = ceu.sky_horizon_color
			ceu.sky_top_color = Color(0.22, 0.27, 0.45)
			ceu.sky_horizon_color = Color(0.95, 0.55, 0.32)
	var tela := escola.get_node_or_null("lente/tela") as ColorRect
	if tela and tela.material is ShaderMaterial:
		var mat := tela.material as ShaderMaterial
		for p in ["gama", "grao", "vinheta", "interferencia", "saturacao", "forca_tom", "respiracao"]:
			_lente_escura[p] = mat.get_shader_parameter(p)
		_lente_clara = {"gama": 0.95, "grao": 0.025, "vinheta": 0.32, "interferencia": 0.0,
			"saturacao": 1.0, "forca_tom": 0.18, "respiracao": 0.0}
		for p in _lente_clara:
			mat.set_shader_parameter(p, _lente_clara[p])


static func _ler_ambiente(env: Environment) -> Dictionary:
	return {
		"ambient_light_color": env.ambient_light_color,
		"ambient_light_energy": env.ambient_light_energy,
		"tonemap_exposure": env.tonemap_exposure,
		"fog_light_color": env.fog_light_color,
		"fog_density": env.fog_density,
		"background_energy_multiplier": env.background_energy_multiplier,
		"adjustment_saturation": env.adjustment_saturation,
		"adjustment_contrast": env.adjustment_contrast,
	}


static func _aplicar_ambiente(env: Environment, valores: Dictionary) -> void:
	for k in valores:
		if k in env:
			env.set(k, valores[k])


func _sem_chuva() -> void:
	var chuva := escola.get_node_or_null("chuva_patio") as GPUParticles3D
	if chuva:
		chuva.emitting = false
		chuva.visible = false
	var som := escola.get_node_or_null("detalhes/sons/chuva") as AudioStreamPlayer3D
	if som:
		som.stop()


func _sem_sujeira() -> void:
	for caminho in ["pichacao", "detalhes/decalques", "detalhes/bolinhas", "detalhes/feixes"]:
		var grupo := escola.get_node_or_null(caminho)
		if grupo == null:
			continue
		for filho in grupo.get_children():
			if filho is Node3D:
				_esconder(filho as Node3D, caminho == "pichacao")
	var textos := escola.get_node_or_null("detalhes/textos")
	if textos:
		for t in textos.get_children():
			if t is Label3D and _texto_de_abandono(String((t as Label3D).text)):
				_esconder(t as Node3D, false)
	var mobilia := escola.get_node_or_null("mobilia")
	if mobilia:
		for m in mobilia.get_children():
			var nome := String(m.name)
			for s in SUJEIRA:
				if nome.contains(s):
					_esconder(m as Node3D, false)
					break


static func _texto_de_abandono(chave: String) -> bool:
	for p in TEXTOS_DE_ABANDONO:
		if chave.begins_with(p):
			return true
	return false


## Some com o nó (e tira o corpo dele da física, se for um), e marca a volta.
func _esconder(no: Node3D, com_nuvem: bool) -> void:
	if no == null or not no.visible:
		return
	no.visible = false
	var modo := no.process_mode
	no.process_mode = Node.PROCESS_MODE_DISABLED
	var voltar := func() -> void:
		if is_instance_valid(no):
			no.process_mode = modo
			no.visible = true
	_lembrar(no.global_position, voltar, com_nuvem)


func _sem_grade_nem_buraco() -> void:
	var grade := escola.get_node_or_null("grade") as Node3D
	if grade:
		_esconder(grade, true)
	for nome in ["buraco_entrada", "buraco_saida"]:
		var b := escola.get_node_or_null(nome) as Node3D
		if b:
			b.process_mode = Node.PROCESS_MODE_DISABLED
			var area := b.get_node_or_null("area") as Area3D
			if area:
				area.monitoring = false
			var abrir := func() -> void:
				if is_instance_valid(b):
					b.process_mode = Node.PROCESS_MODE_INHERIT
					if is_instance_valid(area):
						area.monitoring = true
			_lembrar(b.global_position, abrir, true)
	var material := _material_de_parede()
	for r in REMENDOS:
		var corpo := StaticBody3D.new()
		corpo.name = "remendo_buraco"
		corpo.collision_layer = 2
		corpo.collision_mask = 0
		var malha := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = r["tam"]
		caixa.material = material
		malha.mesh = caixa
		corpo.add_child(malha)
		var forma := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = r["tam"]
		forma.shape = b
		corpo.add_child(forma)
		escola.add_child(corpo)
		corpo.global_position = r["pos"]
		_extras.append(corpo)
		var desfazer := func() -> void:
			if is_instance_valid(corpo):
				corpo.queue_free()
		_lembrar(r["pos"], desfazer, true)


## O material da barra de baixo das paredes de dentro (a mesma tinta das salas).
func _material_de_parede() -> Material:
	for nome in ["parede_dado", "parede_tijolo", "parede_alta"]:
		for m in escola.get_node("estrutura").find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i)
				if mat and mat.resource_name == nome:
					return mat
	var simples := StandardMaterial3D.new()
	simples.albedo_color = Color(0.62, 0.6, 0.55)
	return simples


func _lembrar(pos: Vector3, fazer: Callable, nuvem: bool) -> void:
	_elementos.append({"pos": pos, "fazer": fazer, "nuvem": nuvem})


# ==============================================================================
# A ONDA QUE ESCURECE
# ==============================================================================

## Escurece a escola a partir de `centro`, em `duracao` segundos. Quem quiser
## acompanhar lê `raio_onda`.
func transformar(centro: Vector3, duracao: float) -> void:
	if not clara:
		return
	clara = false
	_elementos.sort_custom(func(a, b) -> bool:
		return Vector2(a["pos"].x - centro.x, a["pos"].z - centro.z).length() \
			< Vector2(b["pos"].x - centro.x, b["pos"].z - centro.z).length())
	var muro := _montar_onda(centro)
	# a chuva desaba junto com o raio
	var chuva := escola.get_node_or_null("chuva_patio") as GPUParticles3D
	if chuva:
		chuva.visible = true
		chuva.emitting = true
	var som := escola.get_node_or_null("detalhes/sons/chuva") as AudioStreamPlayer3D
	if som:
		som.play()
	var mat := muro.material_override as ShaderMaterial
	var we := escola.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env := we.environment if we else null
	var tela := escola.get_node_or_null("lente/tela") as ColorRect
	var lente := tela.material as ShaderMaterial if tela else null
	var lua := escola.get_node_or_null("lua") as DirectionalLight3D
	var ceu := env.sky.sky_material as ProceduralSkyMaterial if env and env.sky else null

	var i := 0
	var t := 0.0
	var nuvens := 0
	while t < duracao:
		await escola.get_tree().process_frame
		if not is_instance_valid(escola) or not escola.is_inside_tree():
			return
		if escola.get_tree().paused:
			continue
		t += escola.get_process_delta_time()
		var k := clampf(t / duracao, 0.0, 1.0)
		raio_onda = (1.0 - pow(1.0 - k, 1.6)) * RAIO_ONDA
		muro.scale = Vector3(maxf(raio_onda, 0.05), ALTURA_ONDA, maxf(raio_onda, 0.05))
		mat.set_shader_parameter("alpha", smoothstep(0.0, 0.04, k) * (1.0 - smoothstep(0.75, 1.0, k)))
		# o que a onda já passou escurece
		while i < _elementos.size():
			var e: Dictionary = _elementos[i]
			var d := Vector2(e["pos"].x - centro.x, e["pos"].z - centro.z).length()
			if d > raio_onda:
				break
			(e["fazer"] as Callable).call()
			# fumaça só em parte das coisas: são centenas, e cada nuvem custa
			if e["nuvem"] and nuvens < 60:
				nuvens += 1
				Realidade.nuvem(escola, e["pos"], 1.4, false)
			i += 1
		# o ambiente escurece junto, na mesma curva
		var a := smoothstep(0.0, 0.85, k)
		if env:
			for chave in _ambiente_claro:
				env.set(chave, _misturar(_ambiente_claro[chave], _ambiente_escuro[chave], a))
		if ceu and _ambiente_escuro.has("ceu_topo"):
			ceu.sky_top_color = Color(0.22, 0.27, 0.45).lerp(_ambiente_escuro["ceu_topo"], a)
			ceu.sky_horizon_color = Color(0.95, 0.55, 0.32).lerp(_ambiente_escuro["ceu_horizonte"], a)
		if lente:
			for p in _lente_clara:
				lente.set_shader_parameter(p, _misturar(_lente_clara[p], _lente_escura[p], a))
		if lua and not _lua_escura.is_empty():
			lua.light_color = Color(1.0, 0.68, 0.45).lerp(_lua_escura["cor"], a)
			lua.light_energy = lerpf(1.35, _lua_escura["energia"], a)
	# o resto, de uma vez (o que estiver além do raio final)
	while i < _elementos.size():
		(_elementos[i]["fazer"] as Callable).call()
		i += 1
	_elementos.clear()
	muro.queue_free()
	escola.set("piscar_lampadas", true)
	raio_onda = RAIO_ONDA


static func _misturar(a, b, k: float):
	if a is Color:
		return (a as Color).lerp(b, k)
	return lerpf(float(a), float(b), k)


## O muro da onda: o mesmo da troca de realidade, vermelho-sangue.
func _montar_onda(centro: Vector3) -> MeshInstance3D:
	var muro := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 1.0
	m.bottom_radius = 1.0
	m.height = 1.0
	m.radial_segments = 96
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	muro.mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = ONDA
	mat.set_shader_parameter("cor", Color(0.85, 0.06, 0.08))
	mat.set_shader_parameter("alpha", 0.0)
	muro.material_override = mat
	muro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	escola.add_child(muro)
	muro.global_position = centro + Vector3.UP * (ALTURA_ONDA * 0.5 - 1.0)
	return muro
