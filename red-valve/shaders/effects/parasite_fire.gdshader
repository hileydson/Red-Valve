// Fogo do Maycow parasita (GAMEPLAY).
//
// Não confundir com hand_fire.gdshader, que é o take da mão no trailer e deve
// ficar como está. Aqui a leitura é outra: a pele vira CROSTA DE LAVA — rocha
// escura rachada com veios incandescentes correndo por baixo — e a chama em si
// fica por conta das partículas, de propósito suave e embaçada.
//
// O ruído é triplanar em espaço de objeto e escorre devagar na direção
// contrária à gravidade, então os veios sobem sem depender de UV nem da
// orientação da câmera.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;

/// "Para cima" do mundo convertido para o espaço do objeto (o script atualiza
/// a cada quadro, porque o membro se mexe).
uniform vec3 local_up = vec3(0.0, 1.0, 0.0);
uniform float h_min = -0.1;
uniform float h_max = 0.1;

/// 0 = pele normal, 1 = lava. Serve para acender aos poucos.
uniform float ignite : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 22.0;
uniform float scroll_speed = 0.04;
uniform float inflate = 0.001;

/// Máscara em cápsula, em espaço de objeto da malha: só queima o que estiver
/// perto do segmento mask_a -> mask_b. É assim que a lava fica presa a UM
/// braço de um corpo inteiro, acompanhando qualquer animação.
uniform float mask_enabled = 0.0;
uniform vec3 mask_a = vec3(0.0);
uniform vec3 mask_b = vec3(0.0);
uniform float mask_radius = 1.0;
uniform float mask_feather = 0.2;

uniform vec3 color_crust : source_color = vec3(0.035, 0.028, 0.026);
uniform vec3 color_lava : source_color = vec3(1.0, 0.26, 0.02);
uniform vec3 color_hot : source_color = vec3(1.0, 0.68, 0.2);
uniform float lava_energy = 1.5;
/// Espessura dos veios. Menor = rachaduras mais finas e mais "rocha".
uniform float vein_width = 0.062;
/// Quanto a crosta cobre a pele original. Abaixo de 1 a textura real da mão
/// aparece por baixo — é o que deixa o efeito discreto em vez de trocar a mão
/// por um bloco de pedra.
uniform float crust_opacity : hint_range(0.0, 1.0) = 0.7;

varying vec3 v_obj;
varying vec3 v_nrm;
varying float v_h;

float segment_dist(vec3 p, vec3 a, vec3 b) {
	vec3 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return length(p - (a + ab * t));
}

float tri_noise(vec3 p, vec3 n, float sc) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	return texture(noise_tex, p.yz * sc).r * w.x
		+ texture(noise_tex, p.zx * sc).r * w.y
		+ texture(noise_tex, p.xy * sc).r * w.z;
}

void vertex() {
	v_obj = VERTEX;
	v_nrm = NORMAL;
	// Descola um fio da pele: evita z-fighting com a malha original.
	VERTEX += NORMAL * inflate;
	float h = dot(v_obj, normalize(local_up));
	v_h = clamp((h - h_min) / max(h_max - h_min, 0.0001), 0.0, 1.0);
}

void fragment() {
	float ig = ignite;
	if (mask_enabled > 0.5) {
		float d = segment_dist(v_obj, mask_a, mask_b);
		ig *= 1.0 - smoothstep(mask_radius, mask_radius + mask_feather, d);
	}
	if (ig <= 0.002) {
		discard;
	}

	vec3 up = normalize(local_up);
	vec3 n3 = normalize(v_nrm);

	vec3 p1 = v_obj - up * (TIME * scroll_speed);
	vec3 p2 = v_obj - up * (TIME * scroll_speed * 1.7) + vec3(2.7, 4.1, 1.3);
	float n = tri_noise(p1, n3, noise_scale) * 0.6
		+ tri_noise(p2, n3, noise_scale * 2.1) * 0.4;

	// Veios: linhas finas onde o ruído cruza o meio. É isso que dá o desenho
	// de rocha rachada em vez de manchas.
	float vein = 1.0 - smoothstep(0.0, vein_width, abs(n - 0.5));
	// Poças abertas, onde a crosta cedeu de vez.
	float pool = smoothstep(0.63, 0.9, n);
	float glow = clamp(vein * 0.6 + pool * 0.6, 0.0, 1.0);

	// Magma respirando: pulsa devagar e fora de fase ponto a ponto.
	glow *= 0.68 + 0.26 * sin(TIME * 1.6 + n * 12.0);
	// Sobe um pouco mais quente no topo do membro.
	glow *= mix(0.85, 1.15, v_h);
	glow = clamp(glow, 0.0, 1.0);

	vec3 col = mix(color_crust, color_lava * lava_energy, glow);
	col = mix(col, color_hot * lava_energy * 1.7, pool * 0.85);

	// Contorno quente: destaca a silhueta sem precisar de chama grande.
	float fres = pow(1.0 - abs(dot(n3, normalize(VIEW))), 2.4);
	col += color_lava * (fres * 0.28 * lava_energy);

	ALBEDO = col;
	// A crosta cobre a pele inteira dentro da máscara; a borda some no feather.
	// Sem cobrir 100%: a crosta é uma camada por cima da pele, não um
	// substituto dela. Nos veios acesos fecha mais, para a lava não ficar
	// lavada pela textura de baixo.
	ALPHA = ig * clamp(crust_opacity * (0.85 + 0.35 * glow), 0.0, 1.0);
}
