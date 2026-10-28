// O redemoinho dentro do portal de saída do inferno.
// Disco de braços em espiral girando pra dentro de um miolo preto; a borda some
// em alfa. Sem luz: é ele que acende o resto (com o glow do ambiente).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform vec3 cor_borda : source_color = vec3(1.0, 0.35, 0.08);
uniform vec3 cor_meio : source_color = vec3(0.55, 0.05, 0.12);
uniform float n_bracos = 4.0;
uniform float torcao = 5.5;
uniform float velocidade = 0.9;
uniform float brilho = 2.4;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float espiral = sin(a * n_bracos + log(max(r, 0.001)) * torcao + TIME * velocidade * 3.0);
	float n = texture(ruido, vec2(a / 6.2832 * 2.0 + TIME * 0.05, r * 0.9 - TIME * velocidade * 0.25)).r;
	float bracos_luz = smoothstep(0.1, 0.9, espiral * 0.5 + 0.5) * (0.55 + 0.6 * n);
	vec3 cor = mix(cor_meio, cor_borda, smoothstep(0.15, 0.95, r)) * bracos_luz * brilho;
	// o olho do meio é um poço preto que respira
	float poco = smoothstep(0.22 + 0.03 * sin(TIME * 1.7), 0.42, r);
	cor *= poco;
	ALBEDO = cor;
	ALPHA = smoothstep(1.0, 0.9, r) * mix(1.0, 0.85, n);
}
