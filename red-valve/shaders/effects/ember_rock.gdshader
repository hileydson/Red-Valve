shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded, shadows_disabled;

// Pedras da intro da arena (ver `battlefield.gd::_spawn_rock_chunk`), com a
// MESMA leitura visual do Shadow Seraph: carvao aceso. Massa quase preta,
// gretada por veias de brasa que pulsam de dentro pra fora, silhueta que QUEIMA
// em vez de terminar numa aresta, e cinza se soltando pra cima.
//
// E uma versao reduzida do `shaders/enemies/shadow_seraph_body.gdshader`. As
// diferencas existem porque uma pedra de 30 cm nao e um bicho de 2,8 m:
//
//  1. o padrao e amostrado em ESPACO DE OBJETO, nao de mundo. As pedras voam e
//     giram; em espaco de mundo as veias ficariam paradas no ar e a pedra
//     pareceria atravessar uma nevoa em vez de ser feita de brasa;
//  2. `raio` normaliza esse espaco pro tamanho de cada pedaco, entao uma pedra
//     grande e uma pequena tem greta do mesmo calibre em vez de a pequena virar
//     uma mancha unica;
//  3. a erosao do corpo e quase zero: pedra e solida. So a casca na faixa do
//     fresnel se desmancha — senao os pedacos piscariam furados no ar;
//  4. billow bem menor: da so um leve inchaco irregular pra tirar a cara de
//     esfera de baixa resolucao que a malha realmente e.
//
// `semente` e `raio` sao instance uniforms: um unico material serve as ~80
// pedras (ver `_material_pedra()`), e cada uma recebe seu proprio desfase de
// pulso e sua escala pelo `set_instance_shader_parameter`.

// desfase do pulso/flare: sem isto as 80 pedras respiram em uniss
instance uniform float semente = 0.0;
// raio aproximado do pedaco, em metros: normaliza o padrao pro tamanho dele
instance uniform float raio = 0.25;

group_uniforms cores;
uniform vec4 carvao : source_color = vec4(0.022, 0.013, 0.012, 1.0);
uniform vec4 cinza : source_color = vec4(0.085, 0.070, 0.078, 1.0);
uniform vec4 brasa : source_color = vec4(1.0, 0.34, 0.06, 1.0);
uniform vec4 brasa_quente : source_color = vec4(1.0, 0.76, 0.30, 1.0);

group_uniforms veias;
uniform float veia_escala : hint_range(0.5, 20.0) = 3.2;
uniform float veia_corte : hint_range(0.3, 0.99) = 0.68;
uniform float veia_brilho : hint_range(0.0, 6.0) = 2.6;
uniform float veia_fluxo : hint_range(0.0, 2.0) = 0.22;
uniform float pulso_hz : hint_range(0.0, 3.0) = 0.70;
uniform float flare_hz : hint_range(0.0, 2.0) = 0.30;
uniform float flare_forca : hint_range(0.0, 3.0) = 1.1;

group_uniforms borda;
uniform float borda_potencia : hint_range(0.2, 8.0) = 2.0;
uniform float borda_brilho : hint_range(0.0, 6.0) = 1.5;
uniform float borda_dissolve : hint_range(0.0, 2.0) = 0.55;
uniform float corpo_dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float morde_escala : hint_range(0.5, 12.0) = 2.2;
uniform float fiapo_escala : hint_range(1.0, 60.0) = 14.0;

group_uniforms volume;
uniform float billow : hint_range(0.0, 0.4) = 0.05;
uniform float billow_bias : hint_range(0.0, 1.0) = 0.45;
uniform float billow_escala : hint_range(0.5, 20.0) = 2.2;
uniform float billow_speed : hint_range(0.0, 3.0) = 0.35;

group_uniforms cinzas;
uniform float cinza_escala : hint_range(4.0, 80.0) = 22.0;
uniform float cinza_subida : hint_range(0.0, 3.0) = 1.10;
uniform float cinza_quantidade : hint_range(0.0, 1.0) = 0.055;

varying vec3 v_obj;

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
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.60 + vnoise(p * 2.6 + 11.3) * 0.27 + vnoise(p * 5.9 + 31.7) * 0.13;
}

// Ruido ridged: o vale do ruido vira CRISTA — e o que da greta de lava em vez
// de mancha de nuvem.
float ridged(vec3 p) {
	float a = 1.0 - abs(vnoise(p) * 2.0 - 1.0);
	float b = 1.0 - abs(vnoise(p * 2.3 + 7.1) * 2.0 - 1.0);
	return a * 0.68 + b * 0.32;
}

void vertex() {
	// Espaco de objeto normalizado pelo tamanho da pedra: ~1.0 na superficie.
	v_obj = VERTEX / max(raio, 0.001) + vec3(semente * 17.3, semente * 9.7, semente * 5.1);

	vec3 bp = v_obj * billow_escala;
	bp.y -= TIME * billow_speed;
	// so pra fora, como no corpo do Seraph: incha, nao afunda
	VERTEX += NORMAL * ((fbm(bp) - 0.5) + billow_bias) * billow * raio * 2.0;
}

void fragment() {
	float t = TIME;
	vec3 wp = v_obj;

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), borda_potencia);

	// ---- veias de brasa ----
	vec3 vp = wp * veia_escala;
	vp.y -= t * veia_fluxo;
	float greta = ridged(vp);
	float veia = smoothstep(veia_corte, veia_corte + 0.09, greta);
	float veia_fina = smoothstep(0.74, 0.90, ridged(vp * 2.9 + 3.3));
	veia = clamp(veia + veia_fina * 0.45, 0.0, 1.0);

	// folego proprio de cada pedra (dai a semente no desfase) + estouro ocasional
	float pulso = 0.72 + 0.28 * sin(t * TAU * pulso_hz + semente * TAU);
	float ciclo = fract(t * flare_hz + semente);
	float flare = smoothstep(0.0, 0.04, ciclo) * smoothstep(0.22, 0.06, ciclo);
	float calor = veia * pulso * (1.0 + flare * flare_forca);

	// ---- cinza subindo ----
	vec3 cp = wp * cinza_escala;
	cp.y -= t * cinza_subida;
	float faisca = step(1.0 - cinza_quantidade, vnoise(cp));

	// ---- cor ----
	float massa = clamp(fbm(wp * 4.0 + vec3(0.0, -t * 0.18, 0.0)) * 1.6, 0.0, 1.0);
	vec3 col = mix(carvao.rgb, cinza.rgb, massa * 0.8);
	vec3 cor_veia = mix(brasa.rgb, brasa_quente.rgb, clamp(calor - 0.6, 0.0, 1.0) * 1.6);
	col += cor_veia * calor * veia_brilho;
	col += brasa.rgb * fres * borda_brilho * (0.55 + 0.45 * massa);
	col += brasa_quente.rgb * faisca * 2.2;
	ALBEDO = col;

	// ---- recorte ----
	// Pedra e solida: a erosao vale praticamente so na faixa do fresnel.
	float morde = fbm(wp * morde_escala + vec3(0.0, -t * 0.35, 0.0));
	float fino = vnoise(wp * fiapo_escala + vec3(0.0, -t * 0.9, 0.0));
	float erosao = morde * 0.62 + fino * 0.38;

	float a = 1.0;
	a -= borda_dissolve * fres * smoothstep(0.22, 0.80, erosao);
	a -= corpo_dissolve * smoothstep(0.55, 0.95, fino * 0.6 + morde * 0.4);
	a += calor * 0.45;

	ALPHA = clamp(a, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
