// A lente da cena da Dona Nice: o `cutscene_post.gdshader` lendo a TELA (num
// ColorRect de tela cheia) em vez de uma SubViewport, mais o que esta cena
// pede: barras de cinema, tinta vermelha da possessao, gosma verde escorrendo
// na tela (quando ela agarra e baba no Maycow) e respingo de sangue.
//
// Todos os uniforms sao animados pelo AnimationPlayer do diretor atraves de
// propriedades do `cena_dona_nice.gd` (ver la').
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;

uniform float barras : hint_range(0.0, 1.0) = 0.0;       // 1 = 2,39:1
uniform float aberration : hint_range(0.0, 8.0) = 1.0;
uniform float radial_blur : hint_range(0.0, 1.0) = 0.0;
uniform float barrel : hint_range(-0.3, 0.3) = 0.02;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.6;
uniform float vignette_softness : hint_range(0.05, 1.5) = 0.55;
uniform float grain : hint_range(0.0, 0.3) = 0.05;
uniform float exposure : hint_range(0.0, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 0.85;
uniform vec4 grade_shadows : source_color = vec4(0.04, 0.03, 0.08, 1.0);
uniform vec4 grade_highlights : source_color = vec4(1.0, 0.92, 0.84, 1.0);
uniform float grade_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec4 flash_color : source_color = vec4(1.0, 0.85, 0.7, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float vermelho : hint_range(0.0, 1.0) = 0.0;       // possessao
uniform float gosma : hint_range(0.0, 1.0) = 0.0;          // baba na tela
uniform float sangue_tela : hint_range(0.0, 1.0) = 0.0;    // respingo

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
			   mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	uv = 0.5 + c * (1.0 + barrel * r2);

	// a gosma escorre: distorce o que esta' por tras, como vidro sujo
	float g_mask = 0.0;
	if (gosma > 0.001) {
		vec2 q = vec2(uv.x * 3.0, uv.y * 1.2 - TIME * 0.06);
		float escorre = fbm(q * 2.0 + vec2(0.0, fbm(q * 3.0)));
		float borda = smoothstep(0.0, 0.35, uv.y) * 0.4 + 0.6;
		g_mask = smoothstep(1.0 - gosma * 0.95, 1.0 - gosma * 0.75, escorre * borda + r2);
		uv += (vec2(fbm(q * 5.0), fbm(q * 5.0 + 7.0)) - 0.5) * 0.04 * g_mask;
	}

	vec3 col;
	if (radial_blur > 0.001) {
		vec3 acc = vec3(0.0);
		float total = 0.0;
		for (int i = 0; i < 8; i++) {
			float t = float(i) / 7.0;
			float k = 1.0 - radial_blur * 0.16 * t;
			vec2 suv = clamp(0.5 + (uv - 0.5) * k, vec2(0.001), vec2(0.999));
			float w = 1.0 - t * 0.55;
			acc += textureLod(tela, suv, 0.0).rgb * w;
			total += w;
		}
		col = acc / total;
	} else {
		col = textureLod(tela, clamp(uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
	}

	if (aberration > 0.001) {
		vec2 dir = c * (aberration * 0.0035) * (0.25 + r2 * 3.0);
		col.r = textureLod(tela, clamp(uv + dir, vec2(0.001), vec2(0.999)), 0.0).r;
		col.b = textureLod(tela, clamp(uv - dir, vec2(0.001), vec2(0.999)), 0.0).b;
	}

	col *= exposure;
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(grade_shadows.rgb * 2.0, grade_highlights.rgb, smoothstep(0.0, 0.85, luma));
	col = mix(col, col * graded, grade_amount);
	luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(luma), col, saturation);

	// possessao: as sombras puxam pro vermelho e a borda pulsa
	if (vermelho > 0.001) {
		float pulso = 0.7 + 0.3 * sin(TIME * 7.0);
		col = mix(col, col * vec3(1.35, 0.55, 0.5), vermelho * 0.7);
		col += vec3(0.35, 0.0, 0.02) * vermelho * pulso * smoothstep(0.15, 0.6, length(c));
	}

	// gosma verde por cima (mais densa embaixo, brilho molhado)
	if (g_mask > 0.0) {
		vec3 verde = vec3(0.22, 0.55, 0.08) * (0.6 + 0.6 * fbm(uv * 18.0));
		float brilho = pow(vnoise(uv * 60.0 + TIME), 8.0) * 1.5;
		col = mix(col, verde + brilho, g_mask * 0.82);
	}

	if (sangue_tela > 0.001) {
		float s = fbm(uv * vec2(4.0, 2.5) + 3.0);
		float m = smoothstep(1.0 - sangue_tela * 0.6, 1.0 - sangue_tela * 0.45, s + r2 * 0.8);
		col = mix(col, vec3(0.25, 0.0, 0.01) * (0.6 + s * 0.5), m * 0.9);
	}

	float vig = smoothstep(0.95, vignette_softness * 0.35, length(c) * 1.35);
	col *= mix(1.0, vig, clamp(vignette_strength, 0.0, 1.0));

	if (grain > 0.0001) {
		float n = hash12(FRAGCOORD.xy + fract(TIME * 14.0) * 431.71);
		col += (n - 0.5) * grain * (1.25 - luma * 0.6);
	}
	col = mix(col, flash_color.rgb, flash);

	// barras de cinema: 2,39:1 numa tela 16:9 = 12,8% em cima e embaixo
	float b = barras * 0.128;
	if (SCREEN_UV.y < b || SCREEN_UV.y > 1.0 - b) {
		col = vec3(0.0);
	}
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
