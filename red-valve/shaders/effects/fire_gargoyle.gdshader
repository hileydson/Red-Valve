// Corpo de fogo das gárgulas da arena.
// Usado em todas as partes (tronco, cabeça, chifres, cauda, membranas das asas):
// cada MeshInstance recebe uma cópia do material com "seed" e "part_offset_y"
// próprios, para que o fogo não fique repetido/sincronizado entre as partes.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;

uniform vec3 color_core : source_color = vec3(1.0, 0.94, 0.62);
uniform vec3 color_mid : source_color = vec3(1.0, 0.36, 0.05);
uniform vec3 color_edge : source_color = vec3(0.62, 0.03, 0.02);

uniform float energy = 3.2;
uniform float scroll_speed = 0.9;
uniform float noise_scale = 3.0;
uniform float turbulence = 0.05;   // ondulação do próprio volume de fogo
uniform float dissolve = 0.30;     // corte que abre os "buracos" da chama
uniform float alpha_gain = 1.0;
uniform float edge_heat = 0.0;     // realce da borda de ataque (só nas asas)
// 1 = quase só o contorno acende (volumes que se sobrepõem, como o tronco);
// 0 = a superfície inteira acende (folhas finas, como a membrana das asas).
uniform float rim_mix = 0.0;
uniform float seed = 0.0;

// Gradiente de calor no corpo inteiro (e não por peça): cada peça informa
// onde o seu próprio zero local cai dentro da gárgula.
uniform float part_offset_y = 0.0;
uniform float body_height = 1.6;

// Batida da asa: a membrana atrasa em relação ao ombro, criando a ondulação.
uniform float flap_phase = 0.0;
uniform float flap_amount = 0.0;   // 0 no corpo, > 0 nas asas
uniform float flap_span = 4.0;

varying float v_heat_pos;

void vertex() {
	float t = TIME * scroll_speed + seed;
	float n = textureLod(noise_tex, UV * noise_scale + vec2(seed, -t), 0.0).r - 0.5;
	VERTEX += NORMAL * n * turbulence;
	VERTEX.z += sin(flap_phase - UV.x * flap_span) * pow(UV.x, 1.6) * flap_amount;
	v_heat_pos = clamp((VERTEX.y + part_offset_y) / body_height, 0.0, 1.0);
}

void fragment() {
	float t = TIME * scroll_speed;
	vec2 uv1 = UV * noise_scale + vec2(seed * 0.37, -t);
	vec2 uv2 = UV * (noise_scale * 2.1) + vec2(seed - t * 0.6, -t * 1.7);
	float n = texture(noise_tex, uv1).r * 0.65 + texture(noise_tex, uv2).r * 0.35;

	// Fogo é mais branco/amarelo embaixo (núcleo) e vira brasa vermelha em cima.
	float heat = n * (1.2 - v_heat_pos * 0.55);
	heat += edge_heat * (1.0 - smoothstep(0.0, 0.18, UV.y));
	heat = clamp(heat, 0.0, 1.0);

	vec3 col = mix(color_edge, color_mid, smoothstep(0.15, 0.52, heat));
	col = mix(col, color_core, smoothstep(0.58, 0.95, heat));

	// Fresnel: garante que a silhueta continue legível contra o céu.
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);

	// O corpo é feito de primitivas que se sobrepõem e o blend é aditivo: sem
	// pesar o contorno, a soma estoura em branco no meio do peito.
	float fill = smoothstep(dissolve, dissolve + 0.32, heat);
	float a = fill * mix(1.0, 0.25 + 0.75 * fres, rim_mix);
	a *= mix(1.0, 0.5, v_heat_pos);
	a = clamp(a * alpha_gain, 0.0, 1.0);

	ALBEDO = col * energy;
	ALPHA = a;
}
