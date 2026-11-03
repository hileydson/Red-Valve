// O "UNIVERSO PARALELO" dos flashes da conversa na oficina (Capítulo 5).
// Uma esfera em volta dos atores, vista por dentro: nebulosa roxa, vermelha e
// azul torcendo devagar em redemoinho, e estrelas que piscam. As estrelas são
// uma por CÉLULA da direção (hash): amostrar ruído pra elas vira bolha.
// Sem luz e sem névoa — a névoa da oficina apagaria o fundo.
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

uniform vec3 cor_a : source_color = vec3(0.36, 0.09, 0.58);
uniform vec3 cor_b : source_color = vec3(0.62, 0.07, 0.16);
uniform vec3 cor_c : source_color = vec3(0.09, 0.26, 0.66);
uniform float giro = 0.06;
uniform float torcao = 2.6;
uniform float brilho = 1.25;
uniform float densidade_estrelas = 150.0;

varying vec3 dir_local;

void vertex() {
	dir_local = normalize(VERTEX);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * ruido(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 girar_y(vec3 v, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	return vec3(c * v.x - s * v.z, v.y, s * v.x + c * v.z);
}

void fragment() {
	vec3 d = normalize(dir_local);
	// o céu inteiro gira, e torce mais quanto mais longe do horizonte
	vec3 q = girar_y(d, TIME * giro);
	vec3 r = girar_y(q, q.y * torcao + TIME * giro * 2.0);
	float n = fbm(r * 2.2 + vec3(0.0, TIME * 0.02, 0.0));
	float n2 = fbm(r * 4.6 - vec3(TIME * 0.03));
	vec3 cor = mix(cor_a, cor_b, smoothstep(0.38, 0.78, n));
	cor = mix(cor, cor_c, smoothstep(0.55, 0.85, n2) * 0.65);
	cor *= (smoothstep(0.28, 0.8, n) * 0.85 + 0.2) * brilho;
	vec3 cel = floor(d * densidade_estrelas);
	float h = hash(cel);
	float estrela = step(0.984, h) * (0.55 + 0.45 * sin(TIME * (2.0 + h * 5.0) + h * 40.0));
	cor += vec3(estrela) * 1.6;
	ALBEDO = cor;
}
