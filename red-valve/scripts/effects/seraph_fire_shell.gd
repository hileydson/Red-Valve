extends Node3D

## Defesa 1 do Shadow Seraph: a esfera de fogo.
##
## Ele pula, abre bracos e pernas em cruz e a casca se fecha em volta dele.
## Enquanto ela esta de pe o dano que ele leva cai 70%, e faiscas sobem dela
## sem parar. Dura 14 s e se apaga sozinha avisando pelo sinal `expired`.
##
## Parente proxima do `defense_shield.gd` (o escudo azul do Cobalt Husker), mas
## com shader proprio: aqui a casca e feita de LINGUAS DE FOGO subindo — o
## padrao hexagonal de tecnologia do outro nao combina com este inimigo.

const FX := preload("res://scripts/effects/seraph_fx.gd")

signal expired

var duration: float = 14.0
var radius: float = 1.9

const COR := Color(1.0, 0.45, 0.12)
const COR_FUNDO := Color(0.65, 0.1, 0.35)

# Fogo subindo pela casca: ruido em tres escalas rolando pra cima, mais o
# fresnel pra casca nao virar uma bola opaca tapando o inimigo.
const SHADER_CASCA := """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

uniform vec3 cor : source_color = vec3(1.0, 0.45, 0.12);
uniform vec3 cor_fundo : source_color = vec3(0.65, 0.1, 0.35);
uniform float tempo_local = 0.0;
uniform float impacto = 0.0;
uniform float opacidade = 1.0;

varying vec3 pos_local;
varying vec3 dir_vista;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1,0,0)), f.x),
			mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
			mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	pos_local = VERTEX;
	dir_vista = normalize((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(-dir_vista)));
	float borda = pow(clamp(f, 0.0, 1.0), 2.2);

	// tres escalas de ruido correndo pra cima em velocidades diferentes:
	// e o que faz a chama lamber a casca em vez de so piscar
	vec3 p = pos_local * 3.0;
	float t = tempo_local;
	float chama = vnoise(p + vec3(0.0, -t * 1.6, 0.0)) * 0.55
		+ vnoise(p * 2.3 + vec3(0.0, -t * 2.7, 0.0)) * 0.3
		+ vnoise(p * 5.1 + vec3(0.0, -t * 4.1, 0.0)) * 0.15;

	// lingua de fogo: corta o ruido e deixa so as cristas
	float lingua = smoothstep(0.42, 0.78, chama);
	float onda = impacto * smoothstep(0.2, 1.0, sin(pos_local.y * 11.0 - impacto * 16.0) * 0.5 + 0.5);

	float pulso = 0.88 + 0.12 * sin(t * 5.1);
	float intensidade = (0.05 + borda * 0.7 + lingua * 0.85 + onda * 1.3) * pulso * opacidade;

	ALBEDO = mix(cor_fundo, cor, clamp(lingua + borda * 0.5, 0.0, 1.0)) * intensidade;
	ALPHA = clamp(intensidade, 0.0, 1.0);
}
"""

var _casca: MeshInstance3D
var _nucleo: MeshInstance3D
var _luz: OmniLight3D
var _faiscas: GPUParticles3D
var _labaredas: GPUParticles3D
var _som: AudioStreamPlayer3D
var _tempo: float = 0.0
var _impacto: float = 0.0
var _morrendo: bool = false


func _ready() -> void:
	_monta_casca()
	_monta_nucleo()
	_monta_faiscas()
	_monta_labaredas()
	_monta_luz()
	_monta_som()

	scale = Vector3.ONE * 0.05
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 1.14, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_SINE)


func _monta_casca() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = radius
	esfera.height = radius * 2.0
	esfera.radial_segments = 40
	esfera.rings = 20

	var shader := Shader.new()
	shader.code = SHADER_CASCA
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("cor", Vector3(COR.r, COR.g, COR.b))
	mat.set_shader_parameter("cor_fundo", Vector3(COR_FUNDO.r, COR_FUNDO.g, COR_FUNDO.b))

	_casca = MeshInstance3D.new()
	_casca.mesh = esfera
	_casca.material_override = mat
	_casca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_casca)


func _monta_nucleo() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = radius * 0.9
	esfera.height = radius * 1.8
	esfera.radial_segments = 20
	esfera.rings = 10

	var mat := FX.emissivo(Color(COR.r, COR.g, COR.b, 0.06), 2.0)
	mat.albedo_texture = FX.ruido_plasma(0.035)
	mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_nucleo = MeshInstance3D.new()
	_nucleo.mesh = esfera
	_nucleo.material_override = mat
	_nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_nucleo)


## Faiscas subindo o tempo todo, como pediram: saem da superficie e sobem.
func _monta_faiscas() -> void:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	proc.emission_sphere_radius = radius * 0.95
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 25.0
	proc.initial_velocity_min = 1.8
	proc.initial_velocity_max = 5.0
	proc.gravity = Vector3(0, 1.6, 0)  # brasa sobe
	proc.damping_min = 0.4
	proc.damping_max = 1.2
	proc.turbulence_enabled = true
	proc.turbulence_noise_strength = 0.6
	proc.turbulence_noise_scale = 1.8
	proc.scale_min = 0.03
	proc.scale_max = 0.11
	proc.scale_curve = FX.curva_pico(0.15)
	proc.color_ramp = FX.rampa(
		[Color(1, 1, 0.9, 1), COR, Color(0.7, 0.12, 0.2, 0.4), Color(0.2, 0.03, 0.05, 0.0)],
		[0.0, 0.3, 0.7, 1.0])

	_faiscas = GPUParticles3D.new()
	_faiscas.amount = 90
	_faiscas.lifetime = 1.6
	_faiscas.process_material = proc
	_faiscas.draw_pass_1 = FX.quad_particula()
	_faiscas.local_coords = false
	_faiscas.visibility_aabb = AABB(Vector3.ONE * -radius * 4.0, Vector3.ONE * radius * 10.0)
	add_child(_faiscas)


## Labaredas grossas e lentas colando na casca, pra ela ter volume de fogo e
## nao so um contorno brilhante.
func _monta_labaredas() -> void:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	proc.emission_sphere_radius = radius * 0.8
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 50.0
	proc.initial_velocity_min = 0.3
	proc.initial_velocity_max = 1.2
	proc.gravity = Vector3(0, 1.0, 0)
	proc.damping_min = 1.2
	proc.damping_max = 2.5
	proc.scale_min = radius * 0.25
	proc.scale_max = radius * 0.6
	proc.scale_curve = FX.curva_pico(0.35)
	proc.color_ramp = FX.rampa(
		[Color(1.0, 0.6, 0.2, 0.5), Color(0.9, 0.25, 0.1, 0.3), Color(0.2, 0.03, 0.05, 0.0)],
		[0.0, 0.45, 1.0])

	_labaredas = GPUParticles3D.new()
	_labaredas.amount = 34
	_labaredas.lifetime = 1.1
	_labaredas.process_material = proc
	_labaredas.draw_pass_1 = FX.quad_particula()
	_labaredas.visibility_aabb = AABB(Vector3.ONE * -radius * 3.0, Vector3.ONE * radius * 6.0)
	add_child(_labaredas)


func _monta_luz() -> void:
	_luz = OmniLight3D.new()
	_luz.light_color = COR
	_luz.light_energy = 3.2
	_luz.omni_range = radius * 5.0
	_luz.shadow_enabled = false
	add_child(_luz)


func _monta_som() -> void:
	var stream := FX.som_em_laco(FX.SOM_FOGO)
	if stream == null:
		return
	_som = AudioStreamPlayer3D.new()
	_som.stream = stream
	_som.volume_db = -3.0
	_som.pitch_scale = 0.8
	_som.unit_size = 14.0
	_som.max_distance = 45.0
	add_child(_som)
	_som.play()


func _process(delta: float) -> void:
	_tempo += delta
	if _impacto > 0.0:
		_impacto = maxf(0.0, _impacto - delta * 2.2)

	var mat := _casca.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("tempo_local", _tempo)
		mat.set_shader_parameter("impacto", _impacto)

	_casca.rotate_y(delta * 0.22)
	_nucleo.rotate_y(-delta * 0.6)

	var pulso := 1.0 + sin(_tempo * 5.1) * 0.03
	_casca.scale = Vector3.ONE * pulso
	_luz.light_energy = 3.2 + sin(_tempo * 5.1) * 0.9 + _impacto * 4.0

	if not _morrendo and _tempo >= duration:
		_desliga()


## Tranco na casca quando o dono apanha.
func flash() -> void:
	_impacto = 1.0
	if is_instance_valid(_luz):
		_luz.light_energy = 8.0


func _desliga() -> void:
	if _morrendo:
		return
	_morrendo = true
	expired.emit()
	if is_instance_valid(_faiscas):
		_faiscas.emitting = false
	if is_instance_valid(_labaredas):
		_labaredas.emitting = false
	if is_instance_valid(_som):
		create_tween().tween_property(_som, "volume_db", -40.0, 0.5)

	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector3.ONE * 1.4, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(_luz, "light_energy", 0.0, 0.45)
	var mat := _casca.material_override as ShaderMaterial
	if mat:
		t.tween_method(func(v: float): mat.set_shader_parameter("opacidade", v), 1.0, 0.0, 0.45)
	await t.finished
	queue_free()


## Apaga antes da hora (o dono morreu).
func encerrar() -> void:
	_desliga()
