shader_type canvas_item;

// Transição do amuleto para a arena: sensação de ser puxado pra cima em
// velocidade absurda. Motion blur direcional (rastros verticais), streaks de
// energia, aberração cromática, distorção de túnel e pulso de flash.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;   // Mestre do efeito
uniform float streak : hint_range(0.0, 1.0) = 0.0;      // Rastros verticais (borrão)
uniform float aberration : hint_range(0.0, 0.05) = 0.0;
uniform float warp : hint_range(0.0, 1.0) = 0.0;        // Curvatura de túnel
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;
uniform vec3 energy_color : source_color = vec3(0.65, 0.25, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);
	vec2 d = uv - center;
	float r = length(d);
	float t = TIME + time_offset;

	// Túnel: as bordas são esticadas pra fora e puxadas pra baixo, como se a
	// tela inteira estivesse subindo por um poço.
	vec2 warped = uv + d * r * r * warp * 0.8;
	warped.y += r * warp * 0.12;

	// Motion blur direcional: amostras atrás no eixo vertical, mais longas nas
	// bordas do que no centro (o centro é o "ponto de fuga").
	float edge_weight = mix(0.35, 1.0, smoothstep(0.0, 0.7, r));
	vec2 dir = vec2(d.x * 0.25, 1.0) * streak * 0.35 * edge_weight;

	vec3 col = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < 10; i++) {
		float f = float(i) / 9.0;
		vec2 suv = warped + dir * f;
		vec2 ab = vec2(0.0, 1.0) * aberration * f * edge_weight;
		float w = 1.0 - f * 0.55;
		col.r += texture(screen_texture, suv + ab).r * w;
		col.g += texture(screen_texture, suv).g * w;
		col.b += texture(screen_texture, suv - ab).b * w;
		total += w;
	}
	col /= total;

	// Streaks de energia: faixas verticais finas correndo pra baixo, densas
	// nas laterais e ausentes bem no centro da tela.
	float lane = floor(uv.x * 90.0);
	float seed = hash(vec2(lane, 3.0));
	// Multiplicador alto porque a transição roda em slow motion (Engine.time_scale
	// baixo também desacelera TIME) e os rastros precisam continuar rápidos.
	float speed = (2.5 + seed * 6.0) * 5.0;
	float pos = fract(uv.y + t * speed + seed);
	float line = smoothstep(0.85, 1.0, pos) * smoothstep(1.0, 0.94, pos);
	float lane_mask = step(0.62, hash(vec2(lane, 11.0)));
	float side = smoothstep(0.06, 0.45, abs(uv.x - 0.5));
	float streaks = line * lane_mask * side * intensity;
	col += energy_color * streaks * 1.6;

	// Brilho radial fraco puxando o olho pro centro + vinheta nas bordas
	col += energy_color * pow(1.0 - clamp(r * 1.6, 0.0, 1.0), 4.0) * intensity * 0.35;
	col *= clamp(1.0 - r * intensity * 0.85, 0.0, 1.0);

	// Flash final estourando a tela
	col = mix(col, vec3(1.0), flash);

	float alpha = clamp(max(intensity, max(streak, flash)) * 3.0, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
