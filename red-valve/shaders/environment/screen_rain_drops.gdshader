shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D noise_tex : repeat_enable;
uniform float distortion_strength : hint_range(0.0, 0.2) = 0.006;
uniform vec2 scroll_speed = vec2(0.04, 0.85);
uniform vec4 rain_tint : source_color = vec4(0.08, 0.11, 0.16, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.04;

// Efeitos cinematograficos de lente e atmosfera dark (1994)
uniform float lens_distortion : hint_range(0.0, 0.08) = 0.016;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.0016;
uniform float vignette_darkness : hint_range(0.0, 1.0) = 0.28;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.018;
uniform float droplet_intensity : hint_range(0.0, 1.0) = 0.68;

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Gotas d'agua escorrendo pela borda da objetiva
vec3 _gotas_lente(vec2 uv, float t) {
	vec2 asp = vec2(1.777, 1.0);
	vec2 p = uv * asp * 7.5;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = _hash(id);
	float vel = 0.35 + h * 0.65;
	float fase = fract(t * vel + h * 6.2831);
	float y_gota = (0.42 - fase * 0.84) + sin(t * 2.0 + h * 12.0) * 0.04;
	float x_gota = (h - 0.5) * 0.35;
	vec2 delta = f - vec2(x_gota, y_gota);
	delta.y *= 0.65;
	float d = length(delta);
	float gota = smoothstep(0.16, 0.03, d);
	// rastro fino acima da gota
	float rastro = smoothstep(0.05, 0.0, abs(f.x - x_gota))
		* smoothstep(y_gota, y_gota + 0.38, f.y)
		* smoothstep(0.45, y_gota, f.y) * 0.45;
	float mask = max(gota, rastro) * step(0.42, h);
	return vec3(delta * mask * 2.2, mask);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float r2 = dot(centered, centered);
	float rad = sqrt(r2);

	// 1. Leve curvatura optica de lente (barrel distortion)
	vec2 lens_uv = 0.5 + centered * (1.0 + lens_distortion * r2);

	// 2. Gotas e filetes de chuva mais concentrados na periferia da lente
	// (mantem a mira/centro limpo para gameplay)
	float borda_lente = smoothstep(0.14, 0.66, rad);
	vec3 g1 = _gotas_lente(lens_uv, TIME * 0.55);
	vec3 g2 = _gotas_lente(lens_uv * 1.45 + vec2(3.7, 1.9), TIME * 0.38);
	vec2 gota_norm = (g1.xy + g2.xy * 0.7) * droplet_intensity * borda_lente;

	vec2 noise_uv = lens_uv * vec2(1.4, 0.65) + vec2(TIME * scroll_speed.x, -TIME * scroll_speed.y);
	vec4 noise_val = texture(noise_tex, noise_uv);
	vec2 ripple = (noise_val.rg - 0.5) * distortion_strength * borda_lente;

	vec2 final_uv = clamp(lens_uv + ripple + gota_norm * 0.018, vec2(0.001), vec2(0.999));

	// 3. Aberracao cromatica radial nas bordas da lente
	vec2 ca_offset = centered * chromatic_aberration * (0.5 + r2 * 2.4);
	float col_r = texture(screen_texture, clamp(final_uv + ca_offset, vec2(0.001), vec2(0.999))).r;
	vec4 col_g = texture(screen_texture, final_uv);
	float col_b = texture(screen_texture, clamp(final_uv - ca_offset, vec2(0.001), vec2(0.999))).b;
	vec3 col = vec3(col_r, col_g.g, col_b);

	// Brilho especular discreto nas gotas quando ha luz de poste por tras
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float brilho_gota = (g1.z + g2.z * 0.6) * borda_lente * droplet_intensity;
	col += vec3(1.0, 0.82, 0.58) * brilho_gota * (0.06 + luma * 0.22);

	// 4. Split-toning noturno dark: sombras frias abissais, altas-luzes de sodio preservadas
	vec3 sombra_fria = mix(col, col * vec3(0.92, 0.96, 1.08) + rain_tint.rgb * 0.025, (1.0 - smoothstep(0.0, 0.35, luma)) * (0.30 + tint_strength));
	vec3 luz_quente = col * vec3(1.05, 0.99, 0.92);
	col = mix(sombra_fria, luz_quente, smoothstep(0.22, 0.72, luma));

	// 5. Grao de filme analogico 1994 (mais presente nos meios-tons escuros)
	float grao = (_hash(uv * vec2(1280.0, 720.0) + fract(TIME * 37.0)) - 0.5) * 2.0;
	col += grao * grain_strength * (0.35 + 0.65 * (1.0 - luma));

	// 6. Vinheta optica nas bordas
	float vig = smoothstep(0.36, 0.86, rad);
	col *= 1.0 - vig * vignette_darkness;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
