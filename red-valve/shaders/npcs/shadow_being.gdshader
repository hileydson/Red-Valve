shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded, shadows_disabled;

// Sombra humanoide "de fumaca". A silhueta humana continua legivel, mas as
// capsulas/esferas por baixo precisam ficar CAMUFLADAS.
//
// O que ainda entregava o primitivo era o CONTORNO: mesmo sem sombreado e com
// a borda esfarelada, o limite da malha ainda era o arco limpo da capsula.
// A solucao aqui e parar de deixar a malha definir a silhueta:
//
//  1. domain warping -> o ruido e amostrado numa posicao distorcida por outro
//     ruido. Isso destroi qualquer regularidade e e o que faz o padrao "fluir"
//     como fumaca de verdade, em vez de manchas grudadas na superficie;
//  2. billow forte -> a malha e inflada bem alem do raio original, entao a
//     borda geometrica fica longe de onde a sombra parece terminar, e as
//     partes vizinhas se fundem numa massa so;
//  3. erosao em tres escalas -> o contorno visivel e o corte do ruido
//     (mordidas grandes + medias + granulado), nao a borda da capsula. E ele
//     muda com o tempo, entao nem parado da pra ler a forma.
//
// Alpha scissor em vez de alpha blend de proposito: as partes do corpo se
// sobrepoem e blending causaria costuras e ordenacao errada.

uniform vec4 core_color : source_color = vec4(0.010, 0.010, 0.017, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.11, 0.10, 0.16, 1.0);
uniform vec4 glitch_color : source_color = vec4(0.35, 0.10, 0.22, 1.0);

uniform float smoke_scale : hint_range(0.5, 20.0) = 7.0;
uniform float smoke_speed : hint_range(0.0, 3.0) = 0.55;
uniform float smoke_strength : hint_range(0.0, 2.0) = 1.0;

// distorce as coordenadas do ruido: e o que apaga a "cara de primitivo"
uniform float warp : hint_range(0.0, 1.0) = 0.35;
uniform float warp_scale : hint_range(0.5, 10.0) = 2.2;

// inflar a malha alem do raio real, pra borda geometrica nao ser a silhueta
uniform float billow : hint_range(0.0, 0.3) = 0.09;
uniform float billow_scale : hint_range(0.5, 20.0) = 4.0;
uniform float billow_speed : hint_range(0.0, 3.0) = 0.8;

// erosao: o contorno visivel sai daqui
uniform float body_dissolve : hint_range(0.0, 1.0) = 0.28;
uniform float edge_dissolve : hint_range(0.0, 2.0) = 1.35;
uniform float edge_power : hint_range(0.2, 8.0) = 1.1;
uniform float bite_scale : hint_range(0.5, 12.0) = 3.2;
uniform float wisp_scale : hint_range(1.0, 60.0) = 24.0;

uniform float glitch_rate : hint_range(0.0, 20.0) = 7.0;
uniform float glitch_chance : hint_range(0.0, 1.0) = 0.10;
uniform float glitch_offset : hint_range(0.0, 0.5) = 0.06;
uniform float glitch_bands : hint_range(2.0, 80.0) = 26.0;

varying vec3 v_world;
varying float v_glitch;
varying float v_billow;

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
	return vnoise(p) * 0.62 + vnoise(p * 2.7 + 11.3) * 0.26 + vnoise(p * 6.1 + 31.7) * 0.12;
}

// desloca a posicao de amostragem com ruido (domain warping)
vec3 warp_pos(vec3 p, float t) {
	vec3 s = p * warp_scale + vec3(0.0, -t, 0.0);
	vec3 q = vec3(vnoise(s), vnoise(s + 5.2), vnoise(s + 9.1)) - 0.5;
	return p + q * warp;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec3 bp = warp_pos(world, TIME * billow_speed * 0.5) * billow_scale;
	bp.y -= TIME * billow_speed;
	float b = fbm(bp) - 0.5;
	float b2 = vnoise(world * billow_scale * 3.1 + vec3(0.0, TIME * billow_speed * 1.7, 0.0)) - 0.5;
	v_billow = b + b2 * 0.5;
	// infla bem mais pra fora do que pra dentro: a massa cresce e as partes
	// vizinhas encostam, em vez de afundar e abrir buraco
	VERTEX += NORMAL * (v_billow + 0.35) * billow * 2.0;

	// glitch: fatias horizontais escorregam por um instante.
	// Semente por NPC pra que duas sombras nunca falhem juntas.
	float seed = fract(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719)));
	float tick = floor(TIME * glitch_rate) + seed * 97.0;
	float band = floor(world.y * glitch_bands);
	v_glitch = step(1.0 - glitch_chance, hash11(band * 3.7 + tick));
	VERTEX.x += v_glitch * (hash11(band + tick * 1.7) - 0.5) * glitch_offset * 2.0;
	VERTEX.z += v_glitch * (hash11(band + tick * 5.1) - 0.5) * glitch_offset;

	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * smoke_speed;

	// tudo e amostrado no espaco distorcido
	vec3 wp = warp_pos(v_world, t * 0.6);

	// fresnel largo: marca uma FAIXA grossa como "borda mordivel",
	// nao um fiapo fino colado no contorno da malha
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), edge_power);

	vec3 sp = wp * smoke_scale;
	sp.y -= t;
	float n = fbm(sp);
	float n2 = vnoise(wp * smoke_scale * 0.4 + vec3(0.0, t * 0.3, 0.0));

	// cor so do ruido (unshaded): nenhum gradiente denuncia o cilindro
	float dens = clamp(n * n2 * 2.8 * smoke_strength, 0.0, 1.0);
	vec3 col = mix(core_color.rgb, smoke_color.rgb, dens);
	col = mix(col, smoke_color.rgb * 1.5, clamp(v_billow + 0.5, 0.0, 1.0) * 0.35);
	col = mix(col, glitch_color.rgb, v_glitch * 0.8);
	ALBEDO = col;

	// erosao em tres escalas: mordidas grandes definem o contorno,
	// as medias e o granulado quebram o que sobrou
	float bite = fbm(wp * bite_scale + vec3(0.0, -t * 0.8, 0.0));
	float mid = vnoise(wp * bite_scale * 3.4 + vec3(0.0, -t * 1.2, 0.0));
	float fine = vnoise(wp * wisp_scale + vec3(0.0, -t * 1.6, 0.0));
	float erosion = bite * 0.55 + mid * 0.28 + fine * 0.17;

	float a = 1.0;
	a -= edge_dissolve * fres * smoothstep(0.18, 0.78, erosion);
	a -= body_dissolve * smoothstep(0.42, 0.88, fine * 0.6 + bite * 0.4);
	a -= v_glitch * 0.25 * hash13(v_world * 90.0);

	ALPHA = clamp(a, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
