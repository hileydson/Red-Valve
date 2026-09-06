shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_disabled, shadows_disabled;

// Sombra humanoide "de fumaca": a silhueta continua legivel, mas a superficie
// e uma mancha escura que ferve, com as bordas se desfazendo em particulas.
// Usa alpha scissor (nao alpha blend) de proposito: as partes do corpo se
// sobrepoem e blending causaria costuras e ordenacao errada.

uniform vec4 core_color : source_color = vec4(0.008, 0.008, 0.014, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.10, 0.09, 0.15, 1.0);
uniform vec4 glitch_color : source_color = vec4(0.35, 0.10, 0.22, 1.0);

uniform float smoke_scale : hint_range(0.5, 20.0) = 6.0;
uniform float smoke_speed : hint_range(0.0, 3.0) = 0.55;
uniform float smoke_strength : hint_range(0.0, 2.0) = 1.0;

// quanto da borda se desfaz em pontinhos (0 = silhueta solida)
uniform float edge_dissolve : hint_range(0.0, 1.0) = 0.55;
uniform float edge_power : hint_range(0.5, 8.0) = 3.0;

uniform float glitch_rate : hint_range(0.0, 20.0) = 7.0;
uniform float glitch_chance : hint_range(0.0, 1.0) = 0.10;
uniform float glitch_offset : hint_range(0.0, 0.5) = 0.06;
uniform float glitch_bands : hint_range(2.0, 80.0) = 26.0;

varying vec3 v_world;
varying float v_glitch;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	return fract(p * (p + p));
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.7 + 11.3) * 0.35;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// semente por NPC, pra que duas sombras nunca falhem no mesmo instante
	float seed = fract(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719)));
	float tick = floor(TIME * glitch_rate) + seed * 97.0;
	float band = floor(v_world.y * glitch_bands);
	float g = hash11(band * 3.7 + tick);

	v_glitch = step(1.0 - glitch_chance, g);
	// fatias horizontais do corpo escorregam de lado por 1 frame de glitch
	float dir = hash11(band + tick * 1.7) - 0.5;
	VERTEX.x += v_glitch * dir * glitch_offset * 2.0;
	VERTEX.z += v_glitch * (hash11(band + tick * 5.1) - 0.5) * glitch_offset;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), edge_power);

	// a fumaca sobe devagar pelo corpo
	vec3 sp = v_world * smoke_scale;
	sp.y -= TIME * smoke_speed;
	float n = fbm(sp);
	float n2 = fbm(v_world * smoke_scale * 0.45 + vec3(0.0, TIME * smoke_speed * 0.35, 0.0));

	// manchas: nucleo quase preto com nevoas mais claras rodando por cima
	vec3 col = mix(core_color.rgb, smoke_color.rgb, clamp(n * n2 * 2.2 * smoke_strength, 0.0, 1.0));
	col = mix(col, smoke_color.rgb * 1.6, fres * 0.55);
	col = mix(col, glitch_color.rgb, v_glitch * 0.8);

	ALBEDO = col;
	EMISSION = col * (0.25 + fres * 0.35) + glitch_color.rgb * v_glitch * 0.5;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;

	// as bordas se dissolvem em pontinhos: vira fumaca, nao uma bola de plastico
	float density = 1.0 - fres * edge_dissolve * (0.55 + n * 0.9);
	density -= v_glitch * 0.25 * hash13(v_world * 90.0);
	ALPHA = clamp(density, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
