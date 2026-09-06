extends Control
class_name ParallaxCutscene

## Motor de cutscene 2.5D no estilo "motion comic".
##
## Cada slide e montado com varias camadas de arte (background, personagens,
## objetos) posicionadas em profundidades DIFERENTES dentro de um mundo 3D real.
## A paralaxe nao e simulada com offsets 2D: existe uma Camera3D de verdade, entao
## o deslocamento relativo, a mudanca de escala e a oclusao entre camadas saem
## corretos de graca, e particulas e bruma podem ficar ENTRE as camadas.
##
## A subclasse so precisa fornecer os dados: veja `_build_slides()` e `_on_finished()`.

const LAYER_SHADER := "res://shaders/cutscenes/parallax_layer.gdshader"
const HAZE_SHADER := "res://shaders/cutscenes/cutscene_haze.gdshader"
const IMAGE_EXTENSIONS := ["png", "jpeg", "jpg", "webp"]

# --- ajuste global -----------------------------------------------------------
@export var base_fov: float = 45.0
## Folga extra sobre o calculo exato de enquadramento (evita mostrar a borda das camadas).
@export var safety_margin: float = 0.02
## Amplitude da camera "na mao", em unidades de mundo.
@export var handheld_pos: float = 0.04
## Amplitude da camera "na mao", em graus.
@export var handheld_rot: float = 0.12
## Altura final das tarjas cinematograficas, em pixels de um quadro de 1080p. 0 desliga.
@export var letterbox_height: float = 0.0
## Velocidade da maquina de escrever, em segundos por caractere.
@export var typewriter_speed: float = 0.032

# --- nos --------------------------------------------------------------------
@onready var stage: SubViewportContainer = $Stage
@onready var world: SubViewport = $Stage/World
@onready var caption: Control = $TextBackground
@onready var label: Label = $TextBackground/Label
@onready var arrow: Label = $TextBackground/Arrow
@onready var letterbox_top: ColorRect = $Letterbox/Top
@onready var letterbox_bottom: ColorRect = $Letterbox/Bottom
@onready var fade: ColorRect = $fade
@onready var audio_player: AudioStreamPlayer = $Begin

var camera: Camera3D
var layers_root: Node3D
var post_material: ShaderMaterial

var slides: Array = []
var current_slide_index: int = 0
var current_text_index: int = 0

var _layer_nodes: Array = []
var _live_layers: Array = []        # dicts { node, mat, base_pos, bob, sway, phase, flicker_gain }
var _slide_tweens: Array = []
var _text_tween: Tween

var _cam_t: float = 0.0
var _cam_from: Dictionary = {}
var _cam_to: Dictionary = {}

var _shake_amount: float = 0.0
var _exit_push: float = 0.0
var _fov_punch: float = 0.0
var _blur_punch: float = 0.0
var _flicker_gain: float = 1.0

var _noise: FastNoiseLite
var _time: float = 0.0

var is_transitioning: bool = true
var waiting_for_input: bool = false
var finished: bool = false

var _preloading: Array = []
var _using_fallback: bool = false
var _label_home: Vector2 = Vector2.ZERO


# =============================================================================
# Ganchos da subclasse
# =============================================================================

## Deve devolver o array de slides. Formato de cada slide:
##   {
##     "dir": "res://assets/.../",
##     "prefix": "with_power_1",
##     "fallback": "res://.../with_power_1.png",   # imagem unica, se as camadas faltarem
##     "layers": [ { "name": "background", "depth": 34.0, ... }, ... ],  # do fundo para a frente
##     "haze":   [ { "depth": 22.0, ... } ],
##     "embers": [ { "depth": 20.0, ... } ],
##     "cam": { "from": {...}, "to": {...}, "dur": 26.0 },
##     "texts": [ "CHAVE_1", ... ],
##   }
func _build_slides() -> Array:
	push_error("ParallaxCutscene: a subclasse precisa sobrescrever _build_slides().")
	return []


## Chamado quando a cutscene termina (ou e pulada). A subclasse faz a transicao.
func _on_finished() -> void:
	pass


# =============================================================================
# Ciclo de vida
# =============================================================================

func _ready() -> void:
	slides = _build_slides()

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.35

	_setup_world()
	_setup_post()
	_setup_ui()
	_setup_skip()
	_setup_audio()

	caption.modulate.a = 0.0
	set_process(true)

	await get_tree().create_timer(0.9).timeout
	_animate_letterbox_in()
	load_slide()


func _setup_world() -> void:
	world.own_world_3d = true
	world.transparent_bg = false
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.msaa_3d = Viewport.MSAA_2X
	world.positional_shadow_atlas_size = 0

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	# Linear: as camadas sao arte finalizada, o tonemap nao deve mexer nas cores.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.20
	env.glow_bloom = 0.05
	env.glow_strength = 1.0
	env.glow_hdr_threshold = 1.28
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	world.add_child(we)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = base_fov
	camera.near = 0.05
	camera.far = 400.0
	world.add_child(camera)

	layers_root = Node3D.new()
	layers_root.name = "Layers"
	world.add_child(layers_root)


func _setup_post() -> void:
	post_material = stage.material as ShaderMaterial
	if post_material == null:
		push_warning("ParallaxCutscene: Stage sem ShaderMaterial de post-processing.")


func _setup_ui() -> void:
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.gui_disable_input = true
	_label_home = label.position
	label.visible_characters = 0
	arrow.modulate.a = 0.0
	letterbox_top.offset_bottom = 0.0
	letterbox_bottom.offset_top = 0.0


func _setup_skip() -> void:
	var skip_layer := CanvasLayer.new()
	skip_layer.layer = 128
	var skip_ui = load("res://scripts/ui/skip_cutscene_ui.gd").new()
	skip_layer.add_child(skip_ui)
	add_child(skip_layer)
	skip_ui.skipped.connect(finish_cutscene)


func _setup_audio() -> void:
	if audio_player == null:
		return
	var target_volume := audio_player.volume_db
	audio_player.volume_db = -80.0
	var t := create_tween()
	t.tween_property(audio_player, "volume_db", target_volume, 4.0)


# =============================================================================
# Montagem de um slide
# =============================================================================

func load_slide() -> void:
	if current_slide_index >= slides.size():
		finish_cutscene()
		return

	is_transitioning = true
	waiting_for_input = false
	current_text_index = 0

	var slide: Dictionary = slides[current_slide_index]
	_clear_slide()
	_build_slide(slide)
	_preload_slide(current_slide_index + 1)

	# Entrada escalonada: o fundo chega primeiro, a frente por ultimo.
	# E o que da a sensacao de o quadro ser "montado" em profundidade.
	var total := _live_layers.size()
	for i in range(total):
		var entry: Dictionary = _live_layers[i]
		var mat: ShaderMaterial = entry["mat"]
		var node: Node3D = entry["node"]
		var delay: float = float(entry.get("enter_delay", 0.0)) + i * 0.22
		var dur: float = float(entry.get("enter_dur", 1.4))

		mat.set_shader_parameter("alpha", 0.0)
		# Comeca levemente mais perto da camera e assenta para tras: cresce o
		# recorte sem nunca expor a borda da camada.
		var settled_z: float = entry["base_pos"].z
		var overshoot: float = float(entry.get("enter_push", 0.06))
		node.position.z = settled_z + abs(settled_z) * overshoot

		var t := create_tween().set_parallel(true)
		t.tween_property(mat, "shader_parameter/alpha", 1.0, dur).set_delay(delay) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(node, "position:z", settled_z, dur * 1.6).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide_tweens.append(t)

	# Movimento principal da camera: um unico gesto longo que atravessa o slide
	# inteiro, para nunca "chegar" e congelar.
	var cam: Dictionary = slide.get("cam", {})
	_cam_from = cam.get("from", {"pos": Vector3.ZERO, "rot": Vector3.ZERO, "fov": base_fov})
	_cam_to = cam.get("to", {"pos": Vector3(0, 0, -2.5), "rot": Vector3.ZERO, "fov": base_fov})
	_cam_t = 0.0
	var cam_dur: float = float(cam.get("dur", 26.0))
	var cam_tween := create_tween()
	cam_tween.tween_property(self, "_cam_t", 1.0, cam_dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide_tweens.append(cam_tween)

	_flicker_gain = float(slide.get("flicker", 1.0))
	_update_camera(0.0)

	if post_material:
		post_material.set_shader_parameter("radial_blur", 0.0)
		var ab_tween := create_tween()
		ab_tween.tween_property(post_material, "shader_parameter/aberration",
			float(slide.get("aberration", 1.0)), 1.2)
		_slide_tweens.append(ab_tween)

	await get_tree().create_timer(0.75).timeout
	show_text()


func _build_slide(slide: Dictionary) -> void:
	var defs: Array = _resolve_layer_textures(slide)
	if defs.is_empty():
		push_warning("ParallaxCutscene: slide '%s' sem nenhuma imagem." % str(slide.get("prefix", "?")))
		return

	var scale_k := _common_scale(defs, slide)
	var t0 := tan(deg_to_rad(base_fov) * 0.5)
	var vp_aspect := float(world.size.x) / float(world.size.y)
	# Recentraliza o corte quando a arte nao e 16:9. O deslocamento e ANGULAR
	# (proporcional a profundidade), entao todas as camadas andam juntas e a
	# composicao continua batendo com a arte original.
	var frame_offset: Vector2 = slide.get("frame_offset", Vector2.ZERO)

	for layer_index in range(defs.size()):
		var def: Dictionary = defs[layer_index]
		var order := layer_index * 10
		var tex: Texture2D = def["texture"]
		var depth: float = def["depth"]
		var aspect := float(tex.get_width()) / float(tex.get_height())

		# Camada de quadro inteiro usa a escala comum (registro perfeito com as
		# outras). Um prop recortado — uma arma, um amuleto — nao tem quadro para
		# encaixar, entao declara `frame_size`: a altura dele em fracao da altura
		# do quadro naquela profundidade.
		var frame_size: float = float(def.get("frame_size", 0.0))
		var half_h: float = depth * t0 * (frame_size if frame_size > 0.0 else scale_k)
		var quad := QuadMesh.new()
		quad.size = Vector2(half_h * aspect * 2.0, half_h * 2.0)

		var mat := ShaderMaterial.new()
		mat.shader = load(LAYER_SHADER)
		mat.set_shader_parameter("tex", tex)
		mat.set_shader_parameter("alpha", 1.0)
		mat.set_shader_parameter("blur", float(def.get("blur", 0.0)))
		mat.set_shader_parameter("pinhole_fill", float(def.get("pinhole_fill", 1.0)))
		mat.set_shader_parameter("silhouette_lod", float(def.get("silhouette_lod", 2.0)))
		mat.set_shader_parameter("fill_low", float(def.get("fill_low", 0.72)))
		mat.set_shader_parameter("fill_high", float(def.get("fill_high", 0.96)))
		mat.set_shader_parameter("haze", float(def.get("haze", 0.0)))
		mat.set_shader_parameter("haze_color", def.get("haze_color", Color(0.42, 0.10, 0.08)))
		mat.set_shader_parameter("brightness", float(def.get("brightness", 1.0)))
		mat.set_shader_parameter("contrast", float(def.get("contrast", 1.0)))
		mat.set_shader_parameter("saturation", float(def.get("saturation", 1.0)))
		mat.set_shader_parameter("rim_color", def.get("rim_color", Color(1.0, 0.45, 0.16)))
		mat.set_shader_parameter("rim_strength", float(def.get("rim", 0.0)))
		mat.set_shader_parameter("rim_width", float(def.get("rim_width", 0.006)))
		mat.set_shader_parameter("rim_lod", float(def.get("rim_lod", 1.5)))
		mat.set_shader_parameter("rim_dir", def.get("rim_dir", Vector2(0.75, -0.66)))
		mat.set_shader_parameter("rim_directional", float(def.get("rim_directional", 0.8)))
		mat.set_shader_parameter("flicker_color", def.get("flicker_color", Color(1.0, 0.55, 0.22)))
		mat.set_shader_parameter("flicker", 0.0)
		mat.set_shader_parameter("bottom_shade", float(def.get("bottom_shade", 0.0)))
		mat.render_priority = clampi(order, -120, 120)

		var mi := MeshInstance3D.new()
		mi.name = "Layer_" + str(def.get("name", order))
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		# `offset` e `frame_offset` sao fracoes de quadro; convertidos aqui para
		# unidades de mundo na profundidade da camada.
		var offset: Vector2 = def.get("offset", Vector2.ZERO)
		mi.position = Vector3(
			(offset.x + frame_offset.x) * depth * t0 * vp_aspect,
			(offset.y + frame_offset.y) * depth * t0,
			-depth)
		var roll: float = float(def.get("roll", 0.0))
		mi.rotation_degrees.z = roll
		layers_root.add_child(mi)

		_layer_nodes.append(mi)
		_live_layers.append({
			"node": mi,
			"mat": mat,
			"base_pos": mi.position,
			"bob": float(def.get("bob", 0.0)),
			"sway": float(def.get("sway", 0.0)),
			"roll": roll,
			"phase": float(order) * 1.7 + randf() * 0.6,
			"flicker_gain": float(def.get("flicker_gain", 0.0)),
			"enter_delay": float(def.get("enter_delay", 0.0)),
			"enter_dur": float(def.get("enter_dur", 1.4)),
			"enter_push": float(def.get("enter_push", 0.06)),
		})

		# Bruma e brasas ancoradas logo a frente desta camada: e a peca que
		# realmente separa os planos, porque passa na frente de um e atras do outro.
		# Sem camadas nao ha planos para separar: bruma e brasas so sujam a imagem
		# unica em vez de dar profundidade. O slide roda so com a camera e o post.
		if _using_fallback:
			continue
		for haze_def in slide.get("haze", []):
			if int(haze_def.get("after", -1)) == layer_index:
				_build_haze(haze_def, scale_k, order + 5)
		for ember_def in slide.get("embers", []):
			if int(ember_def.get("after", -1)) == layer_index:
				_build_embers(ember_def, order + 6)


func _build_haze(def: Dictionary, scale_k: float, priority: int) -> void:
	var depth: float = float(def.get("depth", 20.0))
	var t0 := tan(deg_to_rad(base_fov) * 0.5)
	var half_h := depth * t0 * scale_k * float(def.get("size", 1.15))
	var aspect := float(world.size.x) / float(world.size.y)

	var quad := QuadMesh.new()
	quad.size = Vector2(half_h * aspect * 2.0, half_h * 2.0)

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Frequencia baixa demais vira mancha gigante em vez de fumaca: 0.035 num
	# ruido de 256px da uma dezena de mechas atravessando o quadro.
	noise.frequency = float(def.get("noise_frequency", 0.035))
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.45
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true

	var mat := ShaderMaterial.new()
	mat.shader = load(HAZE_SHADER)
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("tint", def.get("tint", Color(0.85, 0.28, 0.12)))
	mat.set_shader_parameter("intensity", float(def.get("intensity", 0.35)))
	mat.set_shader_parameter("scroll", def.get("scroll", Vector2(0.012, -0.004)))
	mat.set_shader_parameter("uv_scale", float(def.get("uv_scale", 2.0)))
	mat.set_shader_parameter("alpha", 1.0)
	mat.set_shader_parameter("edge_fade", float(def.get("edge_fade", 0.28)))
	mat.render_priority = clampi(priority, -120, 120)

	var mi := MeshInstance3D.new()
	mi.name = "Haze"
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.position = Vector3(0, float(def.get("y", 0.0)), -depth)
	layers_root.add_child(mi)
	_layer_nodes.append(mi)


func _build_embers(def: Dictionary, priority: int) -> void:
	var depth: float = float(def.get("depth", 18.0))
	var half := _frame_half_size(depth)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(half.x * 1.2, half.y * 1.1, depth * 0.06)
	process.direction = Vector3(float(def.get("drift", 0.15)), 1.0, 0.0)
	process.spread = float(def.get("spread", 24.0))
	process.initial_velocity_min = float(def.get("speed", 0.35)) * depth * 0.05
	process.initial_velocity_max = float(def.get("speed", 0.35)) * depth * 0.13
	process.gravity = Vector3(0, float(def.get("lift", 0.35)) * depth * 0.02, 0)
	process.damping_min = 0.0
	process.damping_max = 0.4
	process.scale_min = float(def.get("scale", 0.06)) * depth * 0.5
	process.scale_max = float(def.get("scale", 0.06)) * depth * 1.4
	process.turbulence_enabled = true
	process.turbulence_noise_strength = float(def.get("turbulence", 0.55))
	process.turbulence_noise_scale = 2.2
	process.turbulence_noise_speed = Vector3(0.12, 0.08, 0.0)

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.18, 0.7, 1.0])
	var base: Color = def.get("color", Color(1.7, 0.62, 0.18))
	grad.colors = PackedColorArray([
		Color(base.r, base.g, base.b, 0.0),
		base,
		Color(base.r * 0.8, base.g * 0.6, base.b * 0.5, 0.75),
		Color(base.r * 0.5, base.g * 0.3, base.b * 0.2, 0.0),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	process.color_ramp = grad_tex

	# Queda rapida: com uma cauda longa a brasa vira um halo enorme sobre arte
	# escura, mesmo com o quad pequeno.
	var dot_grad := Gradient.new()
	dot_grad.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	dot_grad.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0),
	])
	var dot := GradientTexture2D.new()
	dot.gradient = dot_grad
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 64
	dot.height = 64

	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.albedo_texture = dot
	draw_mat.disable_receive_shadows = true
	draw_mat.no_depth_test = false
	draw_mat.render_priority = clampi(priority, -120, 120)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = draw_mat

	var particles := GPUParticles3D.new()
	particles.name = "Embers"
	particles.amount = int(def.get("amount", 90))
	particles.lifetime = float(def.get("lifetime", 9.0))
	particles.preprocess = particles.lifetime          # ja entra com a tela povoada
	particles.explosiveness = 0.0
	particles.randomness = 0.6
	particles.fixed_fps = 30
	particles.local_coords = true
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.position = Vector3(0, float(def.get("y", -half.y * 0.35)), -depth)
	# A caixa de emissao e grande; sem isto o Godot corta as particulas cedo demais.
	particles.visibility_aabb = AABB(
		Vector3(-half.x * 2.0, -half.y * 2.0, -depth * 0.3),
		Vector3(half.x * 4.0, half.y * 4.0, depth * 0.6))
	layers_root.add_child(particles)
	_layer_nodes.append(particles)


# =============================================================================
# Enquadramento
# =============================================================================

func _frame_half_size(depth: float) -> Vector2:
	var t0 := tan(deg_to_rad(base_fov) * 0.5)
	var aspect := float(world.size.x) / float(world.size.y)
	return Vector2(depth * t0 * aspect, depth * t0)


## Escala UNICA aplicada a todas as camadas.
##
## Todas compartilham o mesmo tamanho angular, entao no repouso a composicao bate
## exatamente com a arte original; a paralaxe so aparece quando a camera anda.
## O valor e o menor que ainda garante que nenhuma camada mostre a propria borda
## em qualquer ponto do trajeto da camera — ou seja, o menor corte possivel.
func _common_scale(defs: Array, slide: Dictionary) -> float:
	var t0 := tan(deg_to_rad(base_fov) * 0.5)
	var aspect := float(world.size.x) / float(world.size.y)
	var cam: Dictionary = slide.get("cam", {})
	var keys := [
		cam.get("from", {"pos": Vector3.ZERO, "rot": Vector3.ZERO, "fov": base_fov}),
		cam.get("to", {"pos": Vector3(0, 0, -2.5), "rot": Vector3.ZERO, "fov": base_fov}),
	]
	# Reserva para tremor de impacto + camera na mao.
	var slack := handheld_pos * 1.5 + 0.07
	var frame_offset: Vector2 = slide.get("frame_offset", Vector2.ZERO)

	var k := 0.0
	for i in range(defs.size()):
		var def: Dictionary = defs[i]
		# Recortes de personagem tem fundo transparente: se a borda do quad entrar
		# no quadro ninguem ve. Só o fundo precisa cobrir.
		if float(def.get("frame_size", 0.0)) > 0.0:
			continue
		if not bool(def.get("cover", i == 0)):
			continue
		var tex: Texture2D = def["texture"]
		var depth: float = def["depth"]
		var tex_aspect := float(tex.get_width()) / float(tex.get_height())
		var offset: Vector2 = def.get("offset", Vector2.ZERO)
		var wobble: float = float(def.get("bob", 0.0)) + slack

		for key in keys:
			var t := tan(deg_to_rad(float(key.get("fov", base_fov))) * 0.5)
			var rot: Vector3 = key.get("rot", Vector3.ZERO)
			var pos: Vector3 = key.get("pos", Vector3.ZERO)
			var dist: float = maxf(depth + pos.z, 0.5)
			var off_x: float = absf(pos.x) + dist * absf(tan(deg_to_rad(rot.y))) + wobble \
				+ absf(frame_offset.x + offset.x) * depth * t0 * aspect
			var off_y: float = absf(pos.y) + dist * absf(tan(deg_to_rad(rot.x))) + wobble \
				+ absf(frame_offset.y + offset.y) * depth * t0
			var need_half_h := dist * t + off_y
			var need_half_w := dist * t * aspect + off_x
			k = maxf(k, need_half_h / (depth * t0))
			k = maxf(k, need_half_w / (depth * t0 * tex_aspect))

	return k * (1.0 + safety_margin)


func _resolve_layer_textures(slide: Dictionary) -> Array:
	var dir: String = slide.get("dir", "")
	var prefix: String = slide.get("prefix", "")
	var out: Array = []
	_using_fallback = false

	for def in slide.get("layers", []):
		var d: Dictionary = def.duplicate()
		var path := _find_texture(dir, prefix, str(d.get("name", "")))
		if path.is_empty():
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		d["texture"] = tex
		out.append(d)

	if not out.is_empty():
		return out

	# Fallback: a arte em camadas ainda nao existe, entao usa a imagem unica antiga
	# no plano mais fundo — a bruma e as brasas continuam aparecendo na frente dela.
	var fallback: String = slide.get("fallback", "")
	if not fallback.is_empty() and ResourceLoader.exists(fallback):
		var tex: Texture2D = load(fallback)
		if tex:
			var layer_defs: Array = slide.get("layers", [])
			var depth := 30.0
			for def in layer_defs:
				depth = maxf(depth, float(def.get("depth", 30.0)))
			_using_fallback = true
			return [{
				"name": "flat", "texture": tex, "depth": depth,
				"bob": 0.05, "sway": 0.06, "flicker_gain": 0.5,
			}]
	return []


func _find_texture(dir: String, prefix: String, layer_name: String) -> String:
	if dir.is_empty() or prefix.is_empty() or layer_name.is_empty():
		return ""
	for ext in IMAGE_EXTENSIONS:
		var path := "%s%s_%s.%s" % [dir, prefix, layer_name, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


func _preload_slide(index: int) -> void:
	# As camadas sao imagens grandes; carregar na troca causaria engasgo.
	if index >= slides.size():
		return
	var slide: Dictionary = slides[index]
	var dir: String = slide.get("dir", "")
	var prefix: String = slide.get("prefix", "")
	_preloading.clear()
	for def in slide.get("layers", []):
		var path := _find_texture(dir, prefix, str(def.get("name", "")))
		if not path.is_empty():
			ResourceLoader.load_threaded_request(path)
			_preloading.append(path)


func _clear_slide() -> void:
	for t in _slide_tweens:
		if t is Tween and t.is_valid():
			t.kill()
	_slide_tweens.clear()
	for node in _layer_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_layer_nodes.clear()
	_live_layers.clear()


# =============================================================================
# Movimento contínuo
# =============================================================================

func _process(delta: float) -> void:
	_time += delta
	_update_camera(delta)
	_update_layers(delta)
	_update_post(delta)
	_update_arrow()


func _update_camera(delta: float) -> void:
	if camera == null:
		return

	var from_pos: Vector3 = _cam_from.get("pos", Vector3.ZERO)
	var to_pos: Vector3 = _cam_to.get("pos", Vector3.ZERO)
	var from_rot: Vector3 = _cam_from.get("rot", Vector3.ZERO)
	var to_rot: Vector3 = _cam_to.get("rot", Vector3.ZERO)
	var from_fov: float = float(_cam_from.get("fov", base_fov))
	var to_fov: float = float(_cam_to.get("fov", base_fov))

	var pos := from_pos.lerp(to_pos, _cam_t)
	var rot := from_rot.lerp(to_rot, _cam_t)
	var fov: float = lerpf(from_fov, to_fov, _cam_t)

	# Camera na mao: ruido coerente, nao seno. Sem isto o quadro parece travado
	# mesmo com a paralaxe rodando.
	var nx := _noise.get_noise_2d(_time * 0.55, 0.0)
	var ny := _noise.get_noise_2d(0.0, _time * 0.47)
	var nr := _noise.get_noise_2d(_time * 0.31, 31.7)
	pos += Vector3(nx, ny, 0.0) * handheld_pos
	rot += Vector3(ny, nx, nr) * handheld_rot

	if _shake_amount > 0.0001:
		var s := _shake_amount
		pos += Vector3(randf_range(-s, s), randf_range(-s, s), 0.0)
		rot += Vector3(0, 0, randf_range(-s, s) * 6.0)
		_shake_amount = move_toward(_shake_amount, 0.0, delta * 0.9)

	pos.z += _exit_push
	camera.position = pos
	camera.rotation_degrees = rot
	camera.fov = fov + _fov_punch
	_fov_punch = move_toward(_fov_punch, 0.0, delta * 9.0)


func _update_layers(delta: float) -> void:
	# Flicker do incendio: uma unica fonte de luz "viva" empurrada para todas as
	# camadas, com ganho diferente em cada uma.
	var fire := _noise.get_noise_2d(_time * 2.3, 77.0) * 0.10 + _noise.get_noise_2d(_time * 7.1, 12.0) * 0.04
	fire = clampf(fire, -0.06, 0.10) * _flicker_gain

	for entry in _live_layers:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var phase: float = entry["phase"]
		var bob: float = entry["bob"]
		var sway: float = entry["sway"]
		if bob > 0.0:
			var base: Vector3 = entry["base_pos"]
			node.position.x = base.x + sin(_time * 0.43 + phase) * bob
			node.position.y = base.y + sin(_time * 0.31 + phase * 1.6) * bob * 0.7
		if sway > 0.0:
			node.rotation_degrees.z = float(entry["roll"]) + sin(_time * 0.27 + phase) * sway
		var gain: float = entry["flicker_gain"]
		if gain > 0.0:
			var mat: ShaderMaterial = entry["mat"]
			mat.set_shader_parameter("flicker", fire * gain)


func _update_post(delta: float) -> void:
	if post_material == null:
		return
	if _blur_punch > 0.0001:
		post_material.set_shader_parameter("radial_blur", _blur_punch)
		_blur_punch = move_toward(_blur_punch, 0.0, delta * 1.6)
		if _blur_punch <= 0.0001:
			post_material.set_shader_parameter("radial_blur", 0.0)


## Acento curto de camera: usado a cada nova linha de texto e nos impactos.
func punch(strength: float = 1.0) -> void:
	_shake_amount = maxf(_shake_amount, 0.10 * strength)
	_fov_punch = -1.8 * strength
	_blur_punch = maxf(_blur_punch, 0.28 * strength)


# =============================================================================
# Texto
# =============================================================================

func show_text() -> void:
	var slide: Dictionary = slides[current_slide_index]
	var texts: Array = slide.get("texts", [])
	if current_text_index >= texts.size():
		next_slide()
		return

	label.text = tr(str(texts[current_text_index]))
	label.visible_characters = 0

	if _text_tween and _text_tween.is_valid():
		_text_tween.kill()

	var length := label.text.length()
	_text_tween = create_tween()
	_text_tween.tween_property(label, "visible_characters", length, length * typewriter_speed)

	# Cada linha entra deslizando de baixo: mantem o rodape vivo junto com o quadro.
	label.position = _label_home + Vector2(0.0, 14.0)
	var slide_tween := create_tween().set_parallel(true)
	slide_tween.tween_property(label, "position", _label_home, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if caption.modulate.a < 1.0:
		slide_tween.tween_property(caption, "modulate:a", 1.0, 0.5)

	arrow.modulate.a = 0.0
	punch(1.0 if current_text_index > 0 else 0.4)

	is_transitioning = false
	waiting_for_input = true


func next_slide() -> void:
	is_transitioning = true
	waiting_for_input = false

	# Saida "atravessando" o quadro: a camera acelera para frente enquanto as
	# camadas somem da frente para o fundo, e o post borra. Bem mais forte que um
	# cross-fade seco.
	var out := create_tween().set_parallel(true)
	out.tween_property(caption, "modulate:a", 0.0, 0.4)
	var total := _live_layers.size()
	for i in range(total):
		var entry: Dictionary = _live_layers[total - 1 - i]
		var mat: ShaderMaterial = entry["mat"]
		out.tween_property(mat, "shader_parameter/alpha", 0.0, 0.75).set_delay(i * 0.09)
	out.tween_property(self, "_exit_push", -2.2, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if post_material:
		out.tween_property(post_material, "shader_parameter/radial_blur", 0.55, 0.9)
		out.tween_property(post_material, "shader_parameter/aberration", 4.5, 0.9)
	_blur_punch = 0.0

	await out.finished
	if finished:
		return

	if post_material:
		post_material.set_shader_parameter("radial_blur", 0.0)
	_exit_push = 0.0
	current_slide_index += 1
	load_slide()


func _update_arrow() -> void:
	if finished or is_transitioning or not waiting_for_input:
		return
	if _typing():
		arrow.modulate.a = 0.0
		return
	# Linha completa: pisca o indicador de continuar.
	arrow.modulate.a = 0.35 + 0.45 * (sin(_time * 4.2) * 0.5 + 0.5)


func _typing() -> bool:
	return label.visible_characters >= 0 and label.visible_characters < label.text.length()


func _unhandled_input(event: InputEvent) -> void:
	if finished or is_transitioning or not waiting_for_input:
		return
	if not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	if _typing():
		# Primeiro toque completa a linha, o segundo avanca.
		if _text_tween and _text_tween.is_valid():
			_text_tween.kill()
		label.visible_characters = -1
	else:
		current_text_index += 1
		show_text()


# =============================================================================
# Tarjas e encerramento
# =============================================================================

func _animate_letterbox_in() -> void:
	if letterbox_height <= 0.0:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(letterbox_top, "offset_bottom", letterbox_height, 1.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(letterbox_bottom, "offset_top", -letterbox_height, 1.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func finish_cutscene() -> void:
	if finished:
		return
	finished = true
	is_transitioning = true
	waiting_for_input = false

	for t in _slide_tweens:
		if t is Tween and t.is_valid():
			t.kill()
	_slide_tweens.clear()
	if _text_tween and _text_tween.is_valid():
		_text_tween.kill()

	var t := create_tween().set_parallel(true)
	t.tween_property(caption, "modulate:a", 0.0, 0.5)
	if audio_player:
		t.tween_property(audio_player, "volume_db", -80.0, 2.0)

	fade.fade_out()
	await get_tree().create_timer(2.0).timeout
	_on_finished()
