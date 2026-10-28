shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded, shadows_disabled;

// Casca de fumaca. Roda como `next_pass` por cima do shadow_being: desenha a
// MESMA geometria um pouco inflada, mas quase toda recortada fora — o que
// sobra sao trapos de fumaca flutuando em volta do corpo.
//
// Pra que serve: o que denuncia um carro feito de caixas e o CONTORNO reto e
// os cantos vivos. Engordar o corpo pra disfarcar so deixava o carro maior.
// A casca quebra esse contorno sem tocar no tamanho do veiculo: o corpo
// continua do tamanho certo, e por fora dele flutua fumaca solta.
//
// Alpha scissor (nao blend) pelo mesmo motivo do shader base: as partes se
// sobrepoem e blending traria costura e ordenacao errada.

uniform vec4 smoke_color : source_color = vec4(0.09, 0.08, 0.13, 1.0);
uniform vec4 wisp_color : source_color = vec4(0.16, 0.14, 0.22, 1.0);

// distancia que a casca fica pra fora da lataria
uniform float expand : hint_range(0.0, 0.6) = 0.20;
// quanto da casca sobrevive ao recorte (1 = capa solida, 0 = nada)
uniform float coverage : hint_range(0.0, 1.0) = 0.40;
// concentra a fumaca na silhueta, que e onde a caixa se denuncia
uniform float edge_bias : hint_range(0.0, 1.0) = 0.55;

uniform float noise_scale : hint_range(0.5, 20.0) = 5.5;
uniform float drift : hint_range(0.0, 3.0) = 0.6;
uniform float warp : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_world;

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
	return vnoise(p) * 0.62 + vnoise(p * 2.6 + 7.3) * 0.26 + vnoise(p * 5.9 + 21.1) * 0.12;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// a casca nao e uniforme: infla mais em uns pontos que em outros, entao
	// nem o contorno dela tem cara de caixa
	float n = fbm(w * noise_scale * 0.7 + vec3(0.0, -TIME * drift * 0.5, 0.0));
	VERTEX += NORMAL * expand * (0.45 + n * 1.1);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);

	// domain warp, igual ao shader base: sem isso o padrao gruda na face plana
	vec3 s = v_world * warp * 2.0 + vec3(0.0, -TIME * drift * 0.4, 0.0);
	vec3 q = vec3(vnoise(s), vnoise(s + 5.2), vnoise(s + 9.1)) - 0.5;
	vec3 wp = v_world + q * warp;

	vec3 sp = wp * noise_scale;
	sp.y -= TIME * drift;
	float n = fbm(sp);
	float fine = vnoise(wp * noise_scale * 3.7 - vec3(0.0, TIME * drift * 1.7, 0.0));

	vec3 col = mix(smoke_color.rgb, wisp_color.rgb, clamp(n * 1.6, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = col * 0.35;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	// densidade: mais fumaca na borda (onde a caixa aparece), menos no meio
	float d = n * 0.7 + fine * 0.3 + fres * edge_bias;
	ALPHA = smoothstep(1.0 - coverage - 0.12, 1.0 - coverage + 0.12, d);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
