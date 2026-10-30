extends Node

## OS DOIS HOSPITAIS DO CAPÍTULO 2: o CLARO e o ESCURO.
##
## A cena gerada (`gerar_cena_hospital.py`) é o hospital ESCURO — mal
## iluminado, lâmpada queimada, luz vermelha de emergência, poeira no ar. Na
## chegada com o Jonny no colo ele ainda não é isso: é um hospital funcionando,
## aceso, com gente andando. Esta peça monta a versão CLARA por cima da cena
## (sem tocar no gerador) e, quando o Jonny fica na maca, desfaz tudo numa
## ONDA que sai da cirurgia e escurece o prédio por onde passa — a mesma ideia
## (e o mesmo shader) da escola do Capítulo 1 (`escola_versoes.gd`).
##
## O que a clara muda, e a onda desfaz:
##  - luz: as lâmpadas param de piscar (as queimadas acendem firmes), os tubos
##    mortos das luminárias acendem e a luz vermelha de emergência apaga;
##  - ambiente e lente: luz branca, mais forte, quase sem névoa, sem a vinheta
##    pesada e sem a poeira no ar;
##  - as armas do balcão da recepção somem (num hospital funcionando não tem
##    escopeta em cima do balcão) — voltam com a onda, no escuro.
##
## Quem usa: `capitulo_2_hospital.gd`.

const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")
const ONDA := preload("res://shaders/effects/onda_realidade.gdshader")

## Da cirurgia do 2º andar até o canto mais longe do prédio (e o poço do
## elevador) dá uns 65 m; a onda vai um pouco além pra fechar o resto.
const RAIO_ONDA := 74.0
## Os dois andares inteiros (0 a 8,4 m), com sobra.
const ALTURA_ONDA := 12.0

var hospital: Node3D
var clara: bool = false
## Raio atual da onda da transformação (0 antes, RAIO_ONDA no fim).
var raio_onda: float = 0.0

## Cada coisa que a onda escurece: {"pos": Vector3, "fazer": Callable, "nuvem": bool}.
var _elementos: Array = []
var _ambiente_escuro := {}
var _ambiente_claro := {}
var _vinheta_escura := 1.0


func _init(dono: Node3D) -> void:
	hospital = dono
	name = "versoes_do_hospital"


# ==============================================================================
# O HOSPITAL CLARO
# ==============================================================================

func preparar_clara() -> void:
	clara = true
	hospital.set("piscar_lampadas", false)
	_sem_emergencia()
	_luminarias_acesas()
	_ambiente_claro_e_lente()
	_sem_poeira()
	_sem_armas_no_balcao()


## A vermelha de emergência só faz sentido no prédio abandonado.
func _sem_emergencia() -> void:
	for luz in hospital.find_children("emergencia_*", "Light3D", true, false):
		var l := luz as Light3D
		if not l.visible:
			continue
		l.visible = false
		var acender := func() -> void:
			if is_instance_valid(l):
				l.visible = true
		_lembrar(l.global_position, acender, false)


## As luminárias de tubo morto ganham o material do tubo aceso.
func _luminarias_acesas() -> void:
	var aceso: Material = null
	var mortas: Array = []
	for m in hospital.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			if aceso == null and mat.resource_name == "lum_tubo_aceso":
				aceso = mat
			elif mat.resource_name == "lum_tubo_morto":
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
	var we := hospital.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env := we.environment
		_ambiente_escuro = _ler_ambiente(env)
		_ambiente_claro = {
			"ambient_light_color": Color(0.62, 0.64, 0.62),
			"ambient_light_energy": 2.9,
			"tonemap_exposure": 1.32,
			"fog_light_color": Color(0.42, 0.45, 0.44),
			"fog_density": 0.004,
			"fog_height_density": 0.0,
			"background_energy_multiplier": 1.0,
			"adjustment_saturation": 0.98,
			"adjustment_contrast": 1.04,
		}
		_aplicar_ambiente(env, _ambiente_claro)
	var vinheta := hospital.get_node_or_null("LenteHospital/Vinheta") as CanvasItem
	if vinheta:
		_vinheta_escura = vinheta.modulate.a
		vinheta.modulate.a = 0.3


static func _ler_ambiente(env: Environment) -> Dictionary:
	return {
		"ambient_light_color": env.ambient_light_color,
		"ambient_light_energy": env.ambient_light_energy,
		"tonemap_exposure": env.tonemap_exposure,
		"fog_light_color": env.fog_light_color,
		"fog_density": env.fog_density,
		"fog_height_density": env.fog_height_density,
		"background_energy_multiplier": env.background_energy_multiplier,
		"adjustment_saturation": env.adjustment_saturation,
		"adjustment_contrast": env.adjustment_contrast,
	}


static func _aplicar_ambiente(env: Environment, valores: Dictionary) -> void:
	for k in valores:
		if k in env:
			env.set(k, valores[k])


func _sem_poeira() -> void:
	for nome in ["poeira_1", "poeira_2"]:
		var p := hospital.get_node_or_null(nome) as GPUParticles3D
		if p:
			_esconder(p, false)


func _sem_armas_no_balcao() -> void:
	for filho in hospital.get_children():
		var nome := String(filho.name)
		if filho is Node3D and (nome.ends_with("_no_balcao") or nome.contains("_no_balcao_")):
			_esconder(filho as Node3D, false)


## Some com o nó (e para o processo dele), e marca a volta.
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


func _lembrar(pos: Vector3, fazer: Callable, nuvem: bool) -> void:
	_elementos.append({"pos": pos, "fazer": fazer, "nuvem": nuvem})


# ==============================================================================
# A ONDA QUE ESCURECE
# ==============================================================================

## Escurece o hospital a partir de `centro`, em `duracao` segundos. Quem quiser
## acompanhar lê `raio_onda`.
func transformar(centro: Vector3, duracao: float) -> void:
	if not clara:
		return
	clara = false
	_elementos.sort_custom(func(a, b) -> bool:
		return Vector2(a["pos"].x - centro.x, a["pos"].z - centro.z).length() \
			< Vector2(b["pos"].x - centro.x, b["pos"].z - centro.z).length())
	var muro := _montar_onda(centro)
	var mat := muro.material_override as ShaderMaterial
	var we := hospital.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env := we.environment if we else null
	var vinheta := hospital.get_node_or_null("LenteHospital/Vinheta") as CanvasItem
	# as lâmpadas voltam a falhar já no começo: é o primeiro sinal
	hospital.set("piscar_lampadas", true)

	var i := 0
	var t := 0.0
	var nuvens := 0
	while t < duracao:
		await hospital.get_tree().process_frame
		if not is_instance_valid(hospital) or not hospital.is_inside_tree():
			return
		if hospital.get_tree().paused:
			continue
		t += hospital.get_process_delta_time()
		var k := clampf(t / duracao, 0.0, 1.0)
		raio_onda = (1.0 - pow(1.0 - k, 1.6)) * RAIO_ONDA
		muro.scale = Vector3(maxf(raio_onda, 0.05), ALTURA_ONDA, maxf(raio_onda, 0.05))
		mat.set_shader_parameter("alpha", smoothstep(0.0, 0.04, k) * (1.0 - smoothstep(0.75, 1.0, k)))
		while i < _elementos.size():
			var e: Dictionary = _elementos[i]
			var d := Vector2(e["pos"].x - centro.x, e["pos"].z - centro.z).length()
			if d > raio_onda:
				break
			(e["fazer"] as Callable).call()
			if e["nuvem"] and nuvens < 40:
				nuvens += 1
				Realidade.nuvem(hospital, e["pos"], 1.4, false)
			i += 1
		var a := smoothstep(0.0, 0.85, k)
		if env:
			for chave in _ambiente_claro:
				env.set(chave, _misturar(_ambiente_claro[chave], _ambiente_escuro[chave], a))
		if vinheta:
			vinheta.modulate.a = lerpf(0.3, _vinheta_escura, a)
	while i < _elementos.size():
		(_elementos[i]["fazer"] as Callable).call()
		i += 1
	_elementos.clear()
	muro.queue_free()
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
	hospital.add_child(muro)
	muro.global_position = Vector3(centro.x, ALTURA_ONDA * 0.5 - 1.0, centro.z)
	return muro
