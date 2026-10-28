extends Node3D

## Esfera de defesa do The Cobalt Husker.
##
## Monta tudo por codigo (nao precisa de cena nem de asset de audio):
##  - casca semitransparente com fresnel + padrao hexagonal em movimento
##  - nucleo interno aditivo girando ao contrario
##  - faiscas orbitando a superficie
##  - luz azul pulsante
##  - zumbido esquisito e intermitente gerado em tempo real (AudioStreamGenerator)
##
## Some sozinha quando `duration` acaba. Quem cria so precisa ler `duration` e,
## a cada dano levado, chamar `flash()` pra dar o impacto na casca.

## Quanto tempo a esfera fica de pe.
var duration: float = 12.0
## Raio da casca externa.
var radius: float = 1.75

signal expired

var _casca: MeshInstance3D
var _nucleo: MeshInstance3D
var _luz: OmniLight3D
var _faiscas: GPUParticles3D
var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _tempo: float = 0.0
var _fase_audio: float = 0.0
var _tempo_audio: float = 0.0
var _impacto: float = 0.0
var _morrendo: bool = false

const COR := Color(0.35, 0.72, 1.0)

# Fresnel na borda + hexagonos rolando na superficie + a onda de impacto que o
# `flash()` dispara. `alpha_scissor` nao serve aqui: a casca precisa ser
# realmente translucida pra dar pra ver o inimigo dentro dela.
const SHADER_CASCA := """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

uniform vec3 cor : source_color = vec3(0.35, 0.72, 1.0);
uniform float tempo_local = 0.0;
uniform float impacto = 0.0;
uniform float opacidade = 1.0;

varying vec3 normal_local;
varying vec3 view_dir;

void vertex() {
	normal_local = NORMAL;
	view_dir = normalize((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

// Distancia do ponto ao centro da celula hexagonal, em "raios de hexagono".
float dist_hex(vec2 p) {
	p = abs(p);
	return max(dot(p, vec2(0.8660254, 0.5)), p.x);
}

// 1 em cima da borda da celula, 0 no meio dela.
float grade_hex(vec2 uv) {
	vec2 r = vec2(1.7320508, 1.0);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	return smoothstep(0.06, 0.0, 0.5 - dist_hex(g));
}

void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(-view_dir)));
	float borda = pow(clamp(f, 0.0, 1.0), 2.5);

	vec2 uv = UV * vec2(22.0, 11.0) + vec2(tempo_local * 0.35, tempo_local * 0.1);
	float grade = grade_hex(uv) * 0.22;

	// Faixa horizontal varrendo de baixo pra cima.
	float varredura = smoothstep(0.93, 1.0, sin(normal_local.y * 9.0 - tempo_local * 2.4)) * 0.35;

	// Onda que sai do centro quando o escudo apanha.
	float onda = impacto * smoothstep(0.2, 1.0, sin(normal_local.y * 14.0 - impacto * 18.0) * 0.5 + 0.5);

	float pulso = 0.85 + 0.15 * sin(tempo_local * 3.7);
	// Fundo bem fraco: a esfera precisa deixar o inimigo visivel la dentro.
	float intensidade = (0.04 + borda * 0.75 + grade + varredura + onda * 1.2) * pulso * opacidade;

	ALBEDO = cor * intensidade;
	ALPHA = clamp(intensidade, 0.0, 1.0);
}
"""

func _ready() -> void:
	_monta_casca()
	_monta_nucleo()
	_monta_faiscas()
	_monta_luz()
	_monta_som()

	# Entrada: estoura do nada ate o tamanho normal.
	scale = Vector3.ONE * 0.05
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 1.12, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_SINE)


func _monta_casca() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = radius
	esfera.height = radius * 2.0
	esfera.radial_segments = 48
	esfera.rings = 24

	var shader := Shader.new()
	shader.code = SHADER_CASCA
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("cor", Vector3(COR.r, COR.g, COR.b))

	_casca = MeshInstance3D.new()
	_casca.mesh = esfera
	_casca.material_override = mat
	_casca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_casca)


func _monta_nucleo() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = radius * 0.92
	esfera.height = radius * 1.84

	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_CELLULAR
	ruido.frequency = 0.03
	var tex := NoiseTexture2D.new()
	tex.noise = ruido
	tex.seamless = true

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.albedo_color = Color(COR.r, COR.g, COR.b, 0.07)
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(3.0, 3.0, 1.0)

	_nucleo = MeshInstance3D.new()
	_nucleo.mesh = esfera
	_nucleo.material_override = mat
	_nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_nucleo)


func _monta_faiscas() -> void:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	proc.emission_sphere_radius = radius * 0.95
	proc.gravity = Vector3.ZERO
	proc.initial_velocity_min = 0.1
	proc.initial_velocity_max = 0.45
	proc.orbit_velocity_min = 0.35
	proc.orbit_velocity_max = 0.9
	proc.damping_min = 0.2
	proc.damping_max = 0.6

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.8, 0.95, 1.0, 1.0), COR, Color(0.1, 0.3, 0.8, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	proc.color_ramp = grad_tex

	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.0))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var curva_tex := CurveTexture.new()
	curva_tex.curve = curva
	proc.scale_curve = curva_tex
	proc.scale_min = 0.02
	proc.scale_max = 0.05

	# Ponto suave (mesma receita da bola de fogo) pra faisca nao virar quadrado.
	var ponto := GradientTexture2D.new()
	ponto.fill = GradientTexture2D.FILL_RADIAL
	ponto.fill_from = Vector2(0.5, 0.5)
	ponto.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color.TRANSPARENT])
	g.offsets = PackedFloat32Array([0.0, 0.5])
	ponto.gradient = g

	var quad := QuadMesh.new()
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.albedo_texture = ponto
	quad.material = quad_mat

	_faiscas = GPUParticles3D.new()
	_faiscas.amount = 45
	_faiscas.lifetime = 1.3
	_faiscas.process_material = proc
	_faiscas.draw_pass_1 = quad
	_faiscas.visibility_aabb = AABB(Vector3.ONE * -radius * 2.0, Vector3.ONE * radius * 4.0)
	add_child(_faiscas)


func _monta_luz() -> void:
	_luz = OmniLight3D.new()
	_luz.light_color = COR
	_luz.light_energy = 1.6
	_luz.omni_range = radius * 4.0
	_luz.shadow_enabled = false
	add_child(_luz)


func _monta_som() -> void:
	var gerador := AudioStreamGenerator.new()
	gerador.mix_rate = 22050.0
	gerador.buffer_length = 0.25

	_audio = AudioStreamPlayer3D.new()
	_audio.stream = gerador
	_audio.unit_size = 14.0
	_audio.max_distance = 40.0
	_audio.volume_db = -4.0
	add_child(_audio)
	_audio.play()
	_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	_tempo += delta
	if _impacto > 0.0:
		_impacto = max(0.0, _impacto - delta * 2.0)

	var mat := _casca.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("tempo_local", _tempo)
		mat.set_shader_parameter("impacto", _impacto)

	# Casca e nucleo giram em sentidos opostos.
	_casca.rotate_y(delta * 0.5)
	_nucleo.rotate_y(-delta * 0.85)
	_nucleo.rotate_x(delta * 0.2)

	# Respiro da esfera + luz acompanhando o mesmo pulso.
	var pulso := 1.0 + sin(_tempo * 3.7) * 0.025
	_casca.scale = Vector3.ONE * pulso
	_luz.light_energy = 1.6 + sin(_tempo * 3.7) * 0.6 + _impacto * 3.5

	_alimenta_som()

	if not _morrendo and _tempo >= duration:
		_desliga()


## Zumbido esquisito: duas ondas desafinadas com vibrato, cortadas por um gate
## que abre e fecha em ritmo irregular (por isso o "intermitente"), mais um
## chiado curto no ataque de cada pulso.
func _alimenta_som() -> void:
	if _playback == null:
		return
	var quadros := _playback.get_frames_available()
	if quadros <= 0:
		return
	var passo := 1.0 / 22050.0
	for i in range(quadros):
		_tempo_audio += passo

		var vibrato := sin(TAU * 5.3 * _tempo_audio) * 24.0
		var deriva := sin(TAU * 0.37 * _tempo_audio) * 18.0
		var freq := 96.0 + vibrato + deriva
		_fase_audio += TAU * freq * passo
		if _fase_audio > TAU:
			_fase_audio -= TAU

		var onda := sin(_fase_audio)
		onda += sin(_fase_audio * 1.503 + 0.7) * 0.6   # desafinada = batimento
		onda *= 0.5 + 0.5 * sin(TAU * 7.1 * _tempo_audio) # ring mod: da o timbre metalico

		# Gate: dois ciclos de duracoes diferentes se sobrepondo, pra nao soar
		# como um metronomo.
		var ciclo_a: float = fmod(_tempo_audio, 0.83) / 0.83
		var ciclo_b: float = fmod(_tempo_audio, 0.31) / 0.31
		var porta := smoothstep(0.0, 0.06, ciclo_a) * smoothstep(0.55, 0.34, ciclo_a)
		porta *= 0.55 + 0.45 * smoothstep(0.0, 0.1, ciclo_b) * smoothstep(0.9, 0.45, ciclo_b)

		var chiado := (randf() * 2.0 - 1.0) * 0.12 * smoothstep(0.12, 0.0, ciclo_a)
		var amostra: float = clamp((onda * 0.32 + chiado) * porta, -1.0, 1.0)
		_playback.push_frame(Vector2(amostra, amostra))


## Impacto na casca quando o dono do escudo leva dano.
func flash() -> void:
	_impacto = 1.0
	if is_instance_valid(_luz):
		_luz.light_energy = 5.0


func _desliga() -> void:
	if _morrendo:
		return
	_morrendo = true
	expired.emit()
	if is_instance_valid(_faiscas):
		_faiscas.emitting = false
	if is_instance_valid(_audio):
		var t_audio := create_tween()
		t_audio.tween_property(_audio, "volume_db", -40.0, 0.5)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector3.ONE * 1.35, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(_luz, "light_energy", 0.0, 0.45)
	var mat := _casca.material_override as ShaderMaterial
	if mat:
		t.tween_method(func(v: float): mat.set_shader_parameter("opacidade", v), 1.0, 0.0, 0.45)
	await t.finished
	queue_free()


## Encerra antes da hora (o dono morreu, por exemplo).
func encerrar() -> void:
	_desliga()
