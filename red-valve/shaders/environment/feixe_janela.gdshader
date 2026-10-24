// O feixe de luar que entra pela janela — em GEOMETRIA, porque o renderer do
// projeto e' o mobile e nele nao existe nevoa volumetrica.
//
// A malha e' uma BoxMesh 1 x 1 x 1 que o gerador CISALHA no transform do no':
// X = a largura da janela, Y = a altura dela, Z = a direcao da luz vezes o
// comprimento do feixe. Uma caixa cisalhada assim e' exatamente o prisma que
// a luz recorta passando por um vao retangular, entao o feixe nasce com a
// forma da janela sem malha nenhuma feita a mao.
//
// No espaco LOCAL da caixa (antes do transform), z = -0.5 e' o plano da janela
// e z = +0.5 e' a ponta do feixe. O shader le isso pra decidir o quanto cada
// ponto brilha.
//
// Tres coisas o impedem de virar um bloco de vidro aceso:
//   - a queda ao longo do feixe e o esmaecer nas quatro bordas;
//   - o esmaecer onde ele encosta em parede e chao (profundidade da cena);
//   - o esmaecer perto da camera: quem atravessa o feixe nao fica cego.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform vec3 cor : source_color = vec3(0.50, 0.60, 0.86);
uniform float forca : hint_range(0.0, 1.0) = 0.05;
uniform float queda : hint_range(0.2, 4.0) = 1.5;
uniform float poeira : hint_range(0.0, 1.0) = 0.55;
uniform sampler2D profundidade : hint_depth_texture, filter_nearest;

varying vec3 local;
varying vec3 mundo;

void vertex() {
	local = VERTEX;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	float t = clamp(local.z + 0.5, 0.0, 1.0);
	float bx = smoothstep(0.5, 0.22, abs(local.x));
	float by = smoothstep(0.5, 0.18, abs(local.y));
	float ao_longo = pow(1.0 - t, queda) * smoothstep(0.0, 0.06, t);

	// poeira suspensa: duas oitavas de ruido andando devagar
	float n = ruido(mundo * 2.3 + vec3(0.0, TIME * 0.05, TIME * 0.03)) * 0.65
		+ ruido(mundo * 6.1 - vec3(TIME * 0.07, 0.0, 0.0)) * 0.35;
	float grao = mix(1.0, 0.45 + n * 1.1, poeira);

	// encosto em parede e chao
	float z_cena = texture(profundidade, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z_cena, 1.0);
	float dist_cena = -v.z / v.w;
	float dist_aqui = -VERTEX.z;
	float encosto = clamp((dist_cena - dist_aqui) / 0.6, 0.0, 1.0);

	// perto da camera: some
	float perto = smoothstep(0.4, 2.2, dist_aqui);
	// face vista de raspao desenha a aresta da caixa: suaviza
	float raspao = smoothstep(0.0, 0.35, abs(dot(NORMAL, VIEW)));

	ALBEDO = cor * forca * bx * by * ao_longo * grao * encosto * perto * mix(0.4, 1.0, raspao);
}
