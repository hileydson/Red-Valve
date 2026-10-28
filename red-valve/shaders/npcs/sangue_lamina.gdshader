// O sangue na lamina da faca da Dona Nice.
//
// A casca de sangue do .glb termina num corte reto (a malha e' uma copia da
// lamina da metade pra ponta). Aqui a borda de baixo vira ESCORRIDO: o ruido
// empurra o limite pra cima e pra baixo, e alguns filetes descem mais. Sangue
// fresco: quase preto, avermelhado onde a luz bate, muito brilhante.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 cor : source_color = vec4(0.16, 0.0, 0.005, 1.0);
// altura (Y local da faca) onde a casca comeca e o tamanho do escorrido
uniform float base = 0.093;
uniform float escorrido = 0.05;
uniform float molhado : hint_range(0.0, 1.0) = 1.0;

varying vec3 p;

float hash(float n) { return fract(sin(n) * 43758.5453); }

float ruido1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	p = VERTEX;
}

void fragment() {
	// filetes ao longo da largura da lamina (eixo Z local)
	float filete = pow(ruido1(p.z * 260.0), 4.0);
	float limite = base + escorrido * (0.35 + 0.35 * ruido1(p.z * 70.0)) - filete * escorrido * 1.4;
	if (p.y < limite) {
		discard;
	}
	ALBEDO = cor.rgb;
	ROUGHNESS = mix(0.45, 0.06, molhado);
	SPECULAR = 0.7;
	CLEARCOAT = molhado;
	CLEARCOAT_ROUGHNESS = 0.05;
}
