// Acabamento de camera para as cutscenes: aberracao cromatica, borrao radial nos
// impactos, vinheta, grao e flash. Aplicado no SubViewportContainer, entao TEXTURE
// e a propria imagem renderizada da cena 3D.
shader_type canvas_item;
render_mode unshaded;

uniform float aberration : hint_range(0.0, 8.0) = 1.0;
uniform float radial_blur : hint_range(0.0, 1.0) = 0.0;
uniform float barrel : hint_range(-0.3, 0.3) = 0.02;

uniform float vignette_strength : hint_range(0.0, 2.0) = 0.55;
uniform float vignette_softness : hint_range(0.05, 1.5) = 0.55;

uniform float grain : hint_range(0.0, 0.3) = 0.045;
uniform float grain_speed = 14.0;

uniform float exposure : hint_range(0.0, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform vec4 grade_shadows : source_color = vec4(0.05, 0.02, 0.06, 1.0);
uniform vec4 grade_highlights : source_color = vec4(1.0, 0.93, 0.86, 1.0);
uniform float grade_amount : hint_range(0.0, 1.0) = 0.35;

uniform vec4 flash_color : source_color = vec4(1.0, 0.85, 0.7, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);

	// Distorcao de lente sutil.
	uv = 0.5 + c * (1.0 + barrel * r2);

	vec3 col;

	// Borrao radial: dispara nos impactos e nas transicoes.
	if (radial_blur > 0.001) {
		vec3 acc = vec3(0.0);
		float total = 0.0;
		for (int i = 0; i < 8; i++) {
			float t = float(i) / 7.0;
			float k = 1.0 - radial_blur * 0.16 * t;
			vec2 suv = clamp(0.5 + (uv - 0.5) * k, vec2(0.001), vec2(0.999));
			float w = 1.0 - t * 0.55;
			acc += texture(TEXTURE, suv).rgb * w;
			total += w;
		}
		col = acc / total;
	} else {
		col = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
	}

	// Aberracao cromatica radial (cresce para as bordas).
	if (aberration > 0.001) {
		vec2 dir = c * (aberration * 0.0035) * (0.25 + r2 * 3.0);
		col.r = texture(TEXTURE, clamp(uv + dir, vec2(0.001), vec2(0.999))).r;
		col.b = texture(TEXTURE, clamp(uv - dir, vec2(0.001), vec2(0.999))).b;
	}

	col *= exposure;

	// Grade split-tone: sombras frias/roxas, luzes quentes.
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(grade_shadows.rgb * 2.0, grade_highlights.rgb, smoothstep(0.0, 0.85, luma));
	col = mix(col, col * graded, grade_amount);

	luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(luma), col, saturation);

	// Vinheta.
	float vig = smoothstep(0.95, vignette_softness * 0.35, length(c) * 1.35);
	col *= mix(1.0, vig, clamp(vignette_strength, 0.0, 1.0));

	// Grao de filme.
	if (grain > 0.0001) {
		float n = hash12(FRAGCOORD.xy + fract(TIME * grain_speed) * 431.71);
		col += (n - 0.5) * grain * (1.25 - luma * 0.6);
	}

	col = mix(col, flash_color.rgb, flash);

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
