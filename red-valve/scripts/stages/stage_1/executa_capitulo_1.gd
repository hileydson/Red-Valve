extends AnimationPlayer

## Cutscene de abertura do Capitulo 1 (nó "cutscene_primeira_vez" da stage_1).
const ANIM_INTRO := "intro"

# Look cinematografico da intro. Nada de VHS: aqui o objetivo e a leitura de
# filme (letterbox, grade quente/fria, halacao nas nuvens, grao fino), sem os
# artefatos de fita.
const LETTERBOX_ALVO := 0.11
const FADE_IN_FILTRO := 1.2
const FADE_OUT_FILTRO := 0.8

var cine_layer: CanvasLayer = null
var cine_mat: ShaderMaterial = null


func _ready() -> void:
	# Nada de autoplay: a intro só existe para a entrada no Capitulo 1, ou seja,
	# quando a stage_1 é carregada vindo do fim do prólogo
	# (GlobalEvents.entering_chapter_1). Voltar da casa do Jimmy, voltar da arena
	# ou carregar um save que já está no capítulo não devem repetir a cutscene.
	if not GlobalEvents.entering_chapter_1:
		return
	if GlobalEvents.voltando_da_casa_jimmy:
		return
	if not has_animation(ANIM_INTRO):
		return

	_setup_filtro_cinematografico()
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)

	# stage_1.gd só roda o _ready dele depois dos filhos e zera GlobalEvents.in_cutscene
	# lá; adiar o play garante que a primeira key da animação (set_in_cutscene)
	# não seja apagada logo em seguida.
	play.call_deferred(ANIM_INTRO)


func set_in_cutscene()->void:
	GlobalEvents.set_in_cutscene()
func unset_in_cutscene()->void:
	GlobalEvents.unset_in_cutscene()


# ==============================================================================
# FILTRO CINEMATOGRAFICO
# ==============================================================================

func _setup_filtro_cinematografico() -> void:
	cine_layer = CanvasLayer.new()
	cine_layer.name = "CinematicFilter"
	# Mesmo esquema do trailer: abaixo da UI, mas por cima do render 3D.
	cine_layer.layer = -1
	add_child(cine_layer)

	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	cine_layer.add_child(back_buffer)

	var rect := ColorRect.new()
	rect.name = "CinematicOverlay"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader_code: String = """
	shader_type canvas_item;

	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

	// Mistura geral do filtro (0 = imagem crua). Usado para entrar/sair suave.
	uniform float intensity : hint_range(0.0, 1.0) = 1.0;
	// Altura das tarjas pretas, em fracao da tela (0.11 ~ 2.35:1 em 16:9).
	uniform float letterbox : hint_range(0.0, 0.25) = 0.0;
	// Sangramento de luz das nuvens/ceu, o que da o ar de lente de cinema.
	uniform float halation : hint_range(0.0, 1.0) = 0.30;
	// Aberracao cromatica so nas bordas do quadro.
	uniform float aberration : hint_range(0.0, 0.01) = 0.0018;
	// Neblina de altitude: levanta os pretos num azul frio.
	uniform float haze : hint_range(0.0, 0.5) = 0.10;
	uniform float vignette_amount : hint_range(0.0, 1.0) = 0.38;
	uniform float grain_amount : hint_range(0.0, 0.2) = 0.030;
	uniform float contrast : hint_range(0.5, 2.0) = 1.10;
	uniform float saturation : hint_range(0.0, 2.0) = 0.92;

	uniform vec3 sombra_tint = vec3(0.42, 0.56, 0.78);
	uniform vec3 luz_tint = vec3(1.00, 0.90, 0.74);

	float rand(vec2 co) {
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}

	float luma(vec3 c) {
		return dot(c, vec3(0.2126, 0.7152, 0.0722));
	}

	void fragment() {
		vec2 uv = SCREEN_UV;
		vec2 centro = uv - vec2(0.5);
		float dist = length(centro);

		// --- ABERRACAO CROMATICA RADIAL (cresce para as bordas) ---
		float ab = aberration * dist * dist * 4.0 * intensity;
		vec2 dir = dist > 0.0001 ? centro / dist : vec2(0.0);
		vec3 base;
		base.r = texture(screen_texture, uv + dir * ab).r;
		base.g = texture(screen_texture, uv).g;
		base.b = texture(screen_texture, uv - dir * ab).b;

		vec3 color = base;

		// --- HALACAO: as areas claras (nuvens, ceu) vazam luz quente ---
		float px = 0.004;
		vec3 blur = texture(screen_texture, uv + vec2(px, 0.0)).rgb;
		blur += texture(screen_texture, uv - vec2(px, 0.0)).rgb;
		blur += texture(screen_texture, uv + vec2(0.0, px)).rgb;
		blur += texture(screen_texture, uv - vec2(0.0, px)).rgb;
		blur *= 0.25;
		float brilho = smoothstep(0.62, 1.0, luma(blur));
		color += blur * brilho * halation * vec3(1.0, 0.94, 0.84);

		// --- NEBLINA DE ALTITUDE: pretos levantados e azulados ---
		color = mix(color, color * (1.0 - haze) + sombra_tint * haze, 1.0 - smoothstep(0.0, 0.7, luma(color)));

		// --- CURVA FILMICA SUAVE + SATURACAO ---
		color = clamp((color - 0.5) * contrast + 0.5, vec3(0.0), vec3(2.0));
		color = mix(vec3(luma(color)), color, saturation);

		// --- SPLIT TONING: sombras frias, altas quentes ---
		float l = clamp(luma(color), 0.0, 1.0);
		color *= mix(sombra_tint * 0.5 + vec3(0.5), luz_tint, smoothstep(0.15, 0.85, l));

		// --- VINHETA ---
		float vig = smoothstep(0.80, 0.30, dist);
		color *= mix(1.0, vig, vignette_amount);

		// --- GRAO FINO ---
		float g = rand(uv * vec2(1024.0, 768.0) + vec2(TIME * 37.0, TIME * 61.0));
		color += (g - 0.5) * grain_amount;

		color = mix(base, color, intensity);

		// --- TARJAS ---
		float barra = step(uv.y, letterbox) + step(1.0 - letterbox, uv.y);
		color = mix(color, vec3(0.0), clamp(barra, 0.0, 1.0));

		COLOR = vec4(color, 1.0);
	}
	"""

	var shader := Shader.new()
	shader.code = shader_code

	cine_mat = ShaderMaterial.new()
	cine_mat.shader = shader
	cine_mat.set_shader_parameter("intensity", 0.0)
	cine_mat.set_shader_parameter("letterbox", 0.0)
	rect.material = cine_mat
	cine_layer.add_child(rect)

	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_cine_param.bind("intensity"), 0.0, 1.0, FADE_IN_FILTRO)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_cine_param.bind("letterbox"), 0.0, LETTERBOX_ALVO, FADE_IN_FILTRO * 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_cine_param(valor: float, nome: String) -> void:
	if cine_mat:
		cine_mat.set_shader_parameter(nome, valor)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != ANIM_INTRO:
		return
	_remover_filtro_cinematografico()


func _remover_filtro_cinematografico() -> void:
	if not is_instance_valid(cine_layer):
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_cine_param.bind("intensity"), 1.0, 0.0, FADE_OUT_FILTRO)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_cine_param.bind("letterbox"), LETTERBOX_ALVO, 0.0, FADE_OUT_FILTRO)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(cine_layer):
		cine_layer.queue_free()
	cine_layer = null
	cine_mat = null
