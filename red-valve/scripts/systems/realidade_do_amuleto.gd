extends Node3D

## A TROCA DE REALIDADE pelo amuleto (R3 / H), do Capitulo 1 em diante e so'
## na cidade.
##
## Com o amuleto no pescoco (o normal do Capitulo 1) a cidade e' a das sombras:
## ShadowPerson e ShadowCar na rua, inimigos enxergando o Maycow, e a visao do
## amuleto funcionando (`ui_amuleto`, que leva os marcados pra arena). Tirando o
## amuleto a cidade volta a ser de gente: cada sombra vira um morador (CityNpc),
## cada carro sombra vira um carro de verdade, e os inimigos viram SOMBRAS
## cegas — continuam la, mas nao veem, nao atacam e nao agarram o Maycow.
##
## A troca nao e' instantanea: uma ONDA sai do Maycow e cresce pela cidade, e e'
## a passagem dela que transforma cada coisa, numa baforada de fumaca. Quem
## decide o que cada um vira sao os proprios objetos, perguntando aqui:
##
##   - `oculto()`: o Maycow esta escondido dos inimigos (amuleto fora)?
##   - `alcancou(pos)`: a onda ja passou por este ponto? (sem onda = sim)
##   - `atualizar_disfarce(no)`: pros inimigos — veste ou tira a sombra quando a
##     onda passa e devolve se ele esta cego agora.
##   - `em_outra_realidade(no)`: pras armas do Maycow — o inimigo (ou a area da
##     cabeca dele) esta de sombra? Bala e explosao atravessam, sem dano e sem
##     sangue.
##
## Sem `class_name` (ver [[project-class-name-travado]]): quem usa faz
## `const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")`.

const _EU := "res://scripts/systems/realidade_do_amuleto.gd"
const SOMBRA := preload("res://shaders/npcs/shadow_being.gdshader")
const TELA := preload("res://shaders/effects/troca_realidade.gdshader")
const ONDA := preload("res://shaders/effects/onda_realidade.gdshader")
const SOM_ONDA := "res://assets/sounds/player/espaco_travel.mp3"
const SOM_SOPRO := "res://assets/sounds/player/dash_effect.mp3"

## Ate onde a onda vai (o anel do ShadowCrowd e' 80 m; o resto ja troca sem ela).
const RAIO_MAX := 120.0
## Quanto ela leva pra chegar la.
const DURACAO := 2.6
## O tranco de camera lenta no instante em que o amuleto sai ou volta.
const LENTO := 0.45
const LENTO_SEGUNDOS := 0.3
## Altura do muro de luz da onda.
const ALTURA_ONDA := 14.0
## A cidade de gente e' a do fim de tarde: o relogio do Sky3D vai pras 19h
## (no relogio dele, o horizonte ainda alaranjado; as 20h da cena ja' sao
## noite fechada) e o ambiente clareia um pouco. Com o amuleto volta ao que a
## cena tinha.
const HORA_SEM_AMULETO := 19.0
const AMBIENTE_SEM_AMULETO := 1.25
## A troca cansa o amuleto: depois de uma, a proxima so' depois desta espera
## (segundos de relogio de parede, pra pausa e camera lenta nao mexerem nela).
const ESPERA_ENTRE_TROCAS := 15.0
## E cada troca gasta esta fracao da magia maxima — que nao volta sozinha.
const CUSTO_MAGIA := 0.15

## A onda de agora (lida pelos objetos da cidade).
static var onda_ativa: bool = false
static var onda_centro: Vector3 = Vector3.ZERO
static var onda_raio: float = 0.0
static var _em_curso: bool = false
static var _mat_sombra: ShaderMaterial
static var _cache_quadro: int = -1
static var _cache_oculto: bool = false
static var _proxima_troca_ms: int = 0

var para_normal: bool = false
## Onde o Maycow estava no aperto: a onda nasce aqui. Vem antes do add_child —
## o _ready roda dentro dele, antes de qualquer global_position.
var centro: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _muro: MeshInstance3D
var _mat_onda: ShaderMaterial
var _camada: CanvasLayer
var _mat_tela: ShaderMaterial
var _env: Environment
var _sat0: float = 1.0
var _bri0: float = 1.0
var _contraste0: float = 1.0
var _ceu: Node
var _hora0: float = 20.0
var _ambiente0: float = 1.0


# ============================================================ perguntas

## O Maycow esta escondido dos inimigos agora? Guardado por quadro: todo
## inimigo pergunta isto todo quadro, e a resposta passa pelo inventario.
static func oculto() -> bool:
	var q := Engine.get_process_frames()
	if q != _cache_quadro:
		_cache_quadro = q
		_cache_oculto = SaveManager.maycow_oculto()
	return _cache_oculto


## A onda ja passou por aqui? Sem onda correndo, tudo ja esta trocado.
static func alcancou(pos: Vector3) -> bool:
	return not onda_ativa or pos.distance_to(onda_centro) <= onda_raio


## Pros inimigos, chamado no comeco do passo de fisica: se o mundo mudou e a
## onda ja passou por ele, veste (ou tira) a sombra. Devolve se ele esta de
## sombra — e de sombra ele nao enxerga o Maycow.
static func atualizar_disfarce(no: Node3D) -> bool:
	var quer := oculto()
	var esta: bool = no.get_meta("_sombra_da_realidade", false)
	if quer != esta and alcancou(no.global_position):
		disfarcar(no, quer)
		# fora da onda (inimigo que nasce ou acorda ja no mundo de agora) nao
		# ha troca pra encobrir
		if onda_ativa:
			nuvem(no, no.global_position + Vector3.UP * 1.0, 1.4, not quer)
		esta = quer
	return esta


## O no (ou o inimigo de quem ele e' parte: a area da cabeca, o corpo) esta
## na outra realidade agora? E' a marca que o `disfarcar` deixa, entao vale
## so' depois que a onda passou por ele.
static func em_outra_realidade(no: Object) -> bool:
	var n := no as Node
	var subidas := 0
	while n != null and subidas < 6:
		if n.get_meta("_sombra_da_realidade", false):
			return true
		n = n.get_parent()
		subidas += 1
	return false


# ============================================================ a troca

## Quantos segundos faltam pra poder trocar de novo (0 = ja' pode).
static func segundos_para_trocar() -> int:
	return maxi(ceili((_proxima_troca_ms - Time.get_ticks_msec()) / 1000.0), 0)


## Tem magia pra pagar uma troca?
static func magia_para_trocar() -> bool:
	return SaveManager.current_mp + 0.001 >= SaveManager.max_mp * CUSTO_MAGIA


## Aperto do R3 / H. Tira ou poe o amuleto e solta a onda. Devolve false se
## nao deu (prologo, fora da cidade, sem o amuleto, troca em andamento, ainda
## na espera, sem magia).
static func alternar(arvore: SceneTree) -> bool:
	if _em_curso or not SaveManager.pode_alternar_realidade():
		return false
	if segundos_para_trocar() > 0 or not magia_para_trocar():
		return false
	var player := arvore.get_first_node_in_group("player") as Node3D
	var cena := arvore.current_scene
	if player == null or cena == null:
		return false
	SaveManager.amuleto_equipado = not SaveManager.amuleto_equipado
	SaveManager.current_mp = maxf(SaveManager.current_mp - SaveManager.max_mp * CUSTO_MAGIA, 0.0)
	_proxima_troca_ms = Time.get_ticks_msec() + int(ESPERA_ENTRE_TROCAS * 1000.0)
	_cache_quadro = -1
	var n = (load(_EU) as GDScript).new()
	n.name = "troca_de_realidade"
	n.para_normal = not SaveManager.amuleto_equipado
	n.centro = player.global_position
	cena.add_child(n)
	return true


func _ready() -> void:
	global_position = centro
	_em_curso = true
	onda_ativa = true
	onda_centro = centro
	onda_raio = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_onda()
	_montar_tela()
	_som(SOM_ONDA, 1.5 if para_normal else 0.75, -2.0)
	_som(SOM_SOPRO, 0.45, 2.0)
	GlobalUtils.vibrate_controller(null, 0.6, 0.5, 0.35)
	_prepara_cor_da_cidade()
	# o tranco: um instante lento no aperto, devolvido no relogio de parede
	Engine.time_scale = LENTO
	get_tree().create_timer(LENTO_SEGUNDOS, true, false, true).timeout.connect(func() -> void:
		if is_equal_approx(Engine.time_scale, LENTO):
			Engine.time_scale = 1.0)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_ammo_ui"):
		player.update_ammo_ui()
		# o simbolo no canto acende forte quando o amuleto volta pro pescoco
		var icone = player.get("amulet_hud_icon")
		if not para_normal and is_instance_valid(icone):
			icone.modulate = Color(1.6, 1.3, 1.9, 1.0)
			icone.create_tween().set_ignore_time_scale(true) \
				.tween_property(icone, "modulate", Color(1, 1, 1, 0.5), 0.9)


func _process(delta: float) -> void:
	# relogio de parede: a camera lenta do comeco nao pode esticar a onda
	_t += delta / maxf(Engine.time_scale, 0.01)
	var k := clampf(_t / DURACAO, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 2.2)
	onda_raio = e * RAIO_MAX
	var r := maxf(onda_raio, 0.05)
	_muro.scale = Vector3(r, ALTURA_ONDA, r)
	_mat_onda.set_shader_parameter("alpha", (1.0 - smoothstep(0.6, 1.0, k)) * smoothstep(0.0, 0.03, k))
	var forca := smoothstep(0.0, 0.06, k) * (1.0 - smoothstep(0.45, 1.0, k))
	_mat_tela.set_shader_parameter("progresso", smoothstep(0.0, 0.5, k))
	_mat_tela.set_shader_parameter("forca", forca)
	_cor_da_cidade(smoothstep(0.0, 0.7, k))
	if k >= 1.0:
		_terminar()


func _terminar() -> void:
	onda_ativa = false
	_em_curso = false
	_cor_da_cidade(1.0)
	queue_free()


func _exit_tree() -> void:
	# a cena pode trocar no meio (entrou numa porta, morreu): nada fica preso
	onda_ativa = false
	_em_curso = false
	if is_equal_approx(Engine.time_scale, LENTO):
		Engine.time_scale = 1.0


## O muro de luz: cilindro de raio 1 e altura 1, sem tampa, escalado pela onda.
func _montar_onda() -> void:
	_muro = MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 1.0
	m.bottom_radius = 1.0
	m.height = 1.0
	m.radial_segments = 96
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	_muro.mesh = m
	_mat_onda = ShaderMaterial.new()
	_mat_onda.shader = ONDA
	_mat_onda.set_shader_parameter("cor", Color(1.0, 0.78, 0.42) if para_normal else Color(0.6, 0.22, 1.0))
	_mat_onda.set_shader_parameter("alpha", 0.0)
	_muro.material_override = _mat_onda
	_muro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_muro)
	# o pe um pouco abaixo do chao: nos desniveis da rua ele nao descola
	_muro.position = Vector3.UP * (ALTURA_ONDA * 0.5 - 2.0)


func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 95
	add_child(_camada)
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat_tela = ShaderMaterial.new()
	_mat_tela.shader = TELA
	_mat_tela.set_shader_parameter("para_normal", 1.0 if para_normal else 0.0)
	r.material = _mat_tela
	_camada.add_child(r)


## A cidade de gente tem mais cor que a das sombras. Mexe so' no ajuste de cor
## do ambiente (o Sky3D cuida do resto e nao encosta nele), partindo do que a
## cena tinha — guardado no proprio Environment, pra voltar exato.
func _prepara_cor_da_cidade() -> void:
	var vp := get_viewport()
	_env = vp.world_3d.environment if vp and vp.world_3d else null
	if _env == null:
		var we := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		_env = we.environment if we else null
	_ceu = _ceu_da_cidade(get_tree().current_scene)
	if _ceu != null:
		_guardar_ceu_das_sombras(_ceu)
		_hora0 = _ceu.current_time
		_ambiente0 = _ceu.ambient_energy
	if _env == null:
		return
	if not _env.has_meta("_cor_das_sombras"):
		_env.set_meta("_cor_das_sombras", [_env.adjustment_saturation, _env.adjustment_brightness, _env.adjustment_contrast])
	_env.adjustment_enabled = true
	_sat0 = _env.adjustment_saturation
	_bri0 = _env.adjustment_brightness
	_contraste0 = _env.adjustment_contrast


func _cor_da_cidade(k: float) -> void:
	if is_instance_valid(_ceu):
		var ceu0: Array = _ceu.get_meta("_ceu_das_sombras")
		_ceu.current_time = lerpf(_hora0, HORA_SEM_AMULETO if para_normal else ceu0[0], k)
		_ceu.ambient_energy = lerpf(_ambiente0, ceu0[1] * (AMBIENTE_SEM_AMULETO if para_normal else 1.0), k)
	if _env == null:
		return
	var base: Array = _env.get_meta("_cor_das_sombras")
	var sat: float = base[0] * (1.3 if para_normal else 1.0)
	var bri: float = base[1] * (1.06 if para_normal else 1.0)
	var con: float = base[2] * (0.97 if para_normal else 1.0)
	_env.adjustment_saturation = lerpf(_sat0, sat, k)
	_env.adjustment_brightness = lerpf(_bri0, bri, k)
	_env.adjustment_contrast = lerpf(_contraste0, con, k)


## A cidade que acabou de carregar ja nasce na cor da realidade gravada.
static func ajustar_cor_ao_entrar(cena: Node) -> void:
	var ceu := _ceu_da_cidade(cena)
	if ceu != null:
		_guardar_ceu_das_sombras(ceu)
		var ceu0: Array = ceu.get_meta("_ceu_das_sombras")
		var sem_amuleto := SaveManager.realidade_normal()
		ceu.current_time = HORA_SEM_AMULETO if sem_amuleto else ceu0[0]
		ceu.ambient_energy = ceu0[1] * (AMBIENTE_SEM_AMULETO if sem_amuleto else 1.0)
	var vp := cena.get_viewport()
	var env: Environment = vp.world_3d.environment if vp and vp.world_3d else null
	if env == null:
		var we := cena.find_child("WorldEnvironment", true, false) as WorldEnvironment
		env = we.environment if we else null
	if env == null:
		return
	if not env.has_meta("_cor_das_sombras"):
		env.set_meta("_cor_das_sombras", [env.adjustment_saturation, env.adjustment_brightness, env.adjustment_contrast])
	var base: Array = env.get_meta("_cor_das_sombras")
	var normal := SaveManager.realidade_normal()
	env.adjustment_enabled = true
	env.adjustment_saturation = base[0] * (1.3 if normal else 1.0)
	env.adjustment_brightness = base[1] * (1.06 if normal else 1.0)
	env.adjustment_contrast = base[2] * (0.97 if normal else 1.0)


## O Sky3D da cidade (o relogio e a luz ambiente dela).
static func _ceu_da_cidade(cena: Node) -> Node:
	if cena == null:
		return null
	var ceu := cena.get_node_or_null("WorldEnvironment/Sky3D")
	return ceu if ceu != null and "current_time" in ceu and "ambient_energy" in ceu else null


## Hora e luz ambiente com que a cena foi feita (a cidade das sombras),
## guardadas no proprio Sky3D na primeira vez — e' pra la' que o amuleto volta.
static func _guardar_ceu_das_sombras(ceu: Node) -> void:
	if not ceu.has_meta("_ceu_das_sombras"):
		ceu.set_meta("_ceu_das_sombras", [ceu.current_time, ceu.ambient_energy])


func _som(caminho: String, tom: float, volume: float) -> void:
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.pitch_scale = tom
	s.volume_db = volume
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(s)
	s.play()


# ============================================================ sombra e fumaca

static func material_de_sombra() -> ShaderMaterial:
	if _mat_sombra == null:
		_mat_sombra = ShaderMaterial.new()
		_mat_sombra.shader = SOMBRA
	return _mat_sombra


## Veste (ou tira) a casca de sombra num inimigo: toda malha dele passa pro
## material das ShadowPerson, e luz, particula e barra de vida apagam. O que
## havia antes fica guardado em cada no, pra voltar exato.
static func disfarcar(no: Node, sombra: bool) -> void:
	no.set_meta("_sombra_da_realidade", sombra)
	_disfarcar_galho(no, sombra)


static func _disfarcar_galho(no: Node, sombra: bool) -> void:
	for f in no.get_children():
		if f is GeometryInstance3D and not (f is GPUParticles3D or f is CPUParticles3D or f is SpriteBase3D or f is Label3D):
			var g := f as GeometryInstance3D
			if sombra:
				if not g.has_meta("_mat_real"):
					g.set_meta("_mat_real", g.material_override)
					g.set_meta("_overlay_real", g.material_overlay)
				g.material_override = material_de_sombra()
				g.material_overlay = null
			elif g.has_meta("_mat_real"):
				g.material_override = g.get_meta("_mat_real")
				g.material_overlay = g.get_meta("_overlay_real")
				g.remove_meta("_mat_real")
				g.remove_meta("_overlay_real")
		elif f is Light3D or f is GPUParticles3D or f is CPUParticles3D or f is SpriteBase3D or f is Label3D:
			var v := f as Node3D
			if sombra:
				if not v.has_meta("_visivel_real"):
					v.set_meta("_visivel_real", v.visible)
				v.visible = false
			elif v.has_meta("_visivel_real"):
				v.visible = v.get_meta("_visivel_real")
				v.remove_meta("_visivel_real")
		_disfarcar_galho(f, sombra)


## A baforada de fumaca que cobre a troca de uma coisa: escura e espessa, com
## faiscas da cor da realidade nova (roxas pras sombras, douradas pra gente).
static func nuvem(pai: Node, pos: Vector3, tamanho: float, para_gente: bool) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var mundo := pai.get_tree().current_scene
	if mundo == null:
		return
	var fumaca := _particulas(int(26 * tamanho), 0.9, tamanho,
		Color(0.06, 0.05, 0.08, 0.95), Color(0.02, 0.02, 0.03, 0.0), false)
	mundo.add_child(fumaca)
	fumaca.global_position = pos
	fumaca.emitting = true
	var cor := Color(1.0, 0.8, 0.45, 1.0) if para_gente else Color(0.7, 0.3, 1.0, 1.0)
	var faisca := _particulas(int(16 * tamanho), 0.6, tamanho * 0.35, cor, Color(cor.r, cor.g, cor.b, 0.0), true)
	mundo.add_child(faisca)
	faisca.global_position = pos
	faisca.emitting = true


static func _particulas(quantas: int, vida: float, tamanho: float, cor0: Color, cor1: Color, brilha: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(quantas, 4)
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6 * tamanho
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.6 * tamanho
	p.initial_velocity_max = (4.0 if brilha else 1.8) * tamanho
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.gravity = Vector3(0.0, 0.8 if not brilha else -1.5, 0.0)
	p.scale_amount_min = (0.08 if brilha else 0.5) * tamanho
	p.scale_amount_max = (0.18 if brilha else 1.2) * tamanho
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.5))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, 0.7 if not brilha else 0.0))
	p.scale_amount_curve = curva
	var g := Gradient.new()
	g.colors = PackedColorArray([cor0, cor1])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if brilha:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	var bolha := GradientTexture2D.new()
	var gb := Gradient.new()
	gb.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	bolha.gradient = gb
	bolha.fill = GradientTexture2D.FILL_RADIAL
	bolha.fill_from = Vector2(0.5, 0.5)
	bolha.fill_to = Vector2(1.0, 0.5)
	bolha.width = 64
	bolha.height = 64
	mat.albedo_texture = bolha
	q.material = mat
	p.mesh = q
	p.finished.connect(p.queue_free)
	return p
