// Acabamento de cinema aplicado na TELA (CanvasLayer + BackBufferCopy), para as
// cutscenes em 3D. E' a versao de tela do cutscene_post.gdshader (que trabalha
// na textura do SubViewport das cutscenes 2.5D) e do filtro que a abertura do
// Capitulo 1 ja usava: grade quente/fria, halacao, aberracao nas bordas,
// vinheta e grao — mais o que so' faz sentido na tela inteira:
//
//  - CAMERA NA MAO / TREMOR em espaco de tela (deslocamento + giro + zoom). Nao
//    briga com script nenhum que posicione a camera a cada quadro (look_at,
//    h_offset absoluto...), porque nao toca na camera;
//  - BORRAO RADIAL nos impactos e arrancadas;
//  - CALOR: o ar tremendo do inferno;
//  - CLARAO em modo "screen" (luz somando, nao tinta por cima);
//  - TARJAS com a borda macia.
//
// A halacao sai dos mipmaps da propria tela (textureLod): e' o borrao largo e
// barato que faz as luzes fortes vazarem como numa lente de verdade.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Mistura geral (0 = imagem crua). E' o que entra/sai suave.
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
// Altura das tarjas, em fracao da tela (0.11 ~ 2.35:1 em 16:9).
uniform float letterbox : hint_range(0.0, 0.25) = 0.0;

// --- camera em espaco de tela ---
uniform vec2 deslocamento = vec2(0.0);
uniform float giro = 0.0;
uniform float zoom = 1.0;
uniform float borrao_radial : hint_range(0.0, 1.0) = 0.0;
uniform float calor : hint_range(0.0, 1.0) = 0.0;

// --- lente ---
uniform float halation : hint_range(0.0, 2.0) = 0.30;
uniform float halation_limiar : hint_range(0.0, 1.5) = 0.62;
uniform vec3 halation_cor = vec3(1.0, 0.90, 0.78);
uniform float aberration : hint_range(0.0, 0.02) = 0.0018;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.38;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.030;

// --- cor ---
uniform float exposicao : hint_range(0.0, 3.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.10;
uniform float saturation : hint_range(0.0, 2.0) = 0.92;
uniform float haze : hint_range(0.0, 0.5) = 0.10;
uniform vec3 sombra_tint = vec3(0.42, 0.56, 0.78);
uniform vec3 luz_tint = vec3(1.00, 0.90, 0.74);

// Clarao: rgb = cor, a = forca.
uniform vec4 flash_cor = vec4(1.0, 1.0, 1.0, 0.0);

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 amostra(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

void fragment() {
	vec2 tela = SCREEN_UV;
	float aspecto = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	// --- CAMERA: giro com o aspecto corrigido (senao o giro achata), zoom pra
	// esconder a borda e o deslocamento por cima ---
	vec2 c = tela - vec2(0.5);
	c.x *= aspecto;
	float s = sin(giro);
	float co = cos(giro);
	c = vec2(c.x * co - c.y * s, c.x * s + c.y * co);
	c.x /= aspecto;
	vec2 uv = vec2(0.5) + c / max(zoom, 0.01) + deslocamento;

	// --- CALOR: ondulacao fina, mais forte embaixo (onde o chao queima) ---
	if (calor > 0.001) {
		float onda = sin(uv.y * 72.0 + TIME * 5.3) * sin(uv.x * 23.0 - TIME * 3.1);
		float peso = mix(0.45, 1.0, smoothstep(0.2, 1.0, uv.y));
		uv += vec2(onda, onda * 0.6) * calor * 0.0028 * peso;
	}

	// --- ABERRACAO CROMATICA RADIAL (cresce para as bordas) ---
	vec2 cuv = uv - vec2(0.5);
	float r = length(cuv);
	vec2 dir = r > 0.0001 ? cuv / r : vec2(0.0);
	float ab = aberration * r * r * 4.0;
	vec3 color;
	color.r = amostra(uv + dir * ab).r;
	color.g = amostra(uv).g;
	color.b = amostra(uv - dir * ab).b;

	// --- BORRAO RADIAL (impacto, arrancada) ---
	if (borrao_radial > 0.001) {
		vec3 acc = color;
		float total = 1.0;
		for (int i = 1; i < 8; i++) {
			float t = float(i) / 7.0;
			vec2 suv = vec2(0.5) + (uv - vec2(0.5)) * (1.0 - borrao_radial * 0.13 * t);
			float w = 1.0 - t * 0.5;
			acc += amostra(suv) * w;
			total += w;
		}
		color = acc / total;
	}

	// --- HALACAO: o que e' claro vaza luz pela lente ---
	if (halation > 0.001) {
		vec2 huv = clamp(uv, vec2(0.001), vec2(0.999));
		vec3 b1 = textureLod(screen_texture, huv, 2.5).rgb;
		vec3 b2 = textureLod(screen_texture, huv, 4.5).rgb;
		vec3 bl = b1 * 0.55 + b2 * 0.45;
		float brilho = smoothstep(halation_limiar, halation_limiar + 0.45, luma(bl));
		color += bl * brilho * halation * halation_cor;
	}

	color *= exposicao;

	// --- NEBLINA NOS PRETOS: pretos levantados no tom das sombras ---
	color = mix(color, color * (1.0 - haze) + sombra_tint * haze, 1.0 - smoothstep(0.0, 0.7, luma(color)));

	// --- CURVA FILMICA SUAVE + SATURACAO ---
	color = clamp((color - 0.5) * contrast + 0.5, vec3(0.0), vec3(2.0));
	color = mix(vec3(luma(color)), color, saturation);

	// --- SPLIT TONING: sombras num tom, altas em outro ---
	float l = clamp(luma(color), 0.0, 1.0);
	color *= mix(sombra_tint * 0.5 + vec3(0.5), luz_tint, smoothstep(0.15, 0.85, l));

	// --- VINHETA (no quadro, nao na imagem tremida) ---
	vec2 vc = tela - vec2(0.5);
	vc.x *= mix(1.0, aspecto, 0.35);
	float vig = smoothstep(0.82, 0.28, length(vc));
	color *= mix(1.0, vig, vignette_amount);

	// --- CLARAO em "screen": soma luz, nao pinta ---
	color = vec3(1.0) - (vec3(1.0) - clamp(color, vec3(0.0), vec3(1.0))) * (vec3(1.0) - flash_cor.rgb * flash_cor.a);

	// --- GRAO FINO, mais visivel nas sombras ---
	float g = rand(tela * vec2(1024.0, 768.0) + vec2(fract(TIME * 37.0), fract(TIME * 61.0)) * 97.0);
	color += (g - 0.5) * grain_amount * (1.2 - l * 0.6);

	vec3 cru = texture(screen_texture, tela).rgb;
	color = mix(cru, color, intensity);

	// --- TARJAS (borda de um pixel, sem serrilhado) ---
	if (letterbox > 0.0001) {
		float px = SCREEN_PIXEL_SIZE.y;
		float topo = 1.0 - smoothstep(letterbox - px, letterbox + px, tela.y);
		float baixo = smoothstep(1.0 - letterbox - px, 1.0 - letterbox + px, tela.y);
		color = mix(color, vec3(0.0), clamp(topo + baixo, 0.0, 1.0));
	}

	COLOR = vec4(max(color, vec3(0.0)), 1.0);
}
