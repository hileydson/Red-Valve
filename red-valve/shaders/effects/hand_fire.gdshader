// Pele em chamas — usado como material_overlay sobre a malha da mão, então
// desenha por cima do modelo original sem substituir a textura dele.
//
// Duas camadas no mesmo passe: a pele carbonizada (mistura normal, escurece)
// e a chama lambendo por cima (cores bem acima de 1.0, para estourar no HDR).
// O ruído é triplanar em espaço de objeto e desliza na direção contrária à
// gravidade, de modo que a chama sempre SOBE, não importa como a câmera (e a
// mão presa nela) esteja girada.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;

/// Direção "para cima" do mundo, convertida para o espaço do objeto (o script
/// atualiza a cada quadro porque a mão acompanha a câmera).
uniform vec3 local_up = vec3(0.0, 1.0, 0.0);
uniform float h_min = -0.1;
uniform float h_max = 0.1;

/// 0 = mão intacta, 1 = totalmente em chamas. Serve para acender aos poucos.
uniform float ignite : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 22.0;
uniform float scroll_speed = 0.12;
uniform float inflate = 0.001;

uniform vec3 color_core : source_color = vec3(1.0, 0.96, 0.72);
uniform vec3 color_mid : source_color = vec3(1.0, 0.45, 0.07);
uniform vec3 color_low : source_color = vec3(0.9, 0.11, 0.01);
uniform vec3 color_char : source_color = vec3(0.045, 0.032, 0.028);
uniform float glow_energy = 3.0;

varying vec3 v_obj;
varying vec3 v_nrm;
varying float v_h;

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
	vec3 up = normalize(local_up);
	vec3 n3 = normalize(v_nrm);

	// Campo de ruído descendo no espaço do objeto = chama subindo na pele.
	vec3 p1 = v_obj - up * (TIME * scroll_speed);
	vec3 p2 = v_obj - up * (TIME * scroll_speed * 1.9) + vec3(3.1, 1.7, 5.3);
	float n = tri_noise(p1, n3, noise_scale) * 0.62
		+ tri_noise(p2, n3, noise_scale * 2.3) * 0.38;

	// Quanto mais alto, mais difícil a chama se sustentar: ela vai rareando
	// e se desfaz nas pontas dos dedos / no topo da mão. O limiar é alto de
	// propósito — a chama tem que ser um retalho sobre a pele queimada, senão
	// vira um borrão luminoso e a mão some.
	float thr = mix(0.52, 0.95, v_h);
	thr = mix(1.4, thr, ignite);

	float flame = smoothstep(thr, thr + 0.18, n);
	// A pele carboniza quase inteira; o ruído só decide onde ficam as brasas.
	float charred = mix(0.62, 0.97, smoothstep(0.22, 0.72, n)) * (0.75 + 0.25 * (1.0 - v_h));

	float fres = pow(1.0 - abs(dot(n3, normalize(VIEW))), 2.6);
	float heat = clamp(flame + fres * 0.18 * ignite, 0.0, 1.0);

	vec3 fire = mix(color_low, color_mid, smoothstep(0.12, 0.55, n));
	fire = mix(fire, color_core, smoothstep(0.62, 0.95, n));

	// Pele preta com brasas vivas nas fissuras.
	vec3 skin = mix(color_char, color_low * 1.8, smoothstep(0.5, 0.86, n) * 0.6);

	ALBEDO = mix(skin, fire * glow_energy, heat);
	ALPHA = clamp(max(charred * 0.92, heat), 0.0, 1.0) * ignite;
}
