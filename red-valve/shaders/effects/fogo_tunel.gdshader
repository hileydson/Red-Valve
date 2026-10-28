shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// O FUNDO da porta red valve aberta: parede, chão e teto de fogo, opacos. O
// vão nunca mostra o que há atrás da porta — o pior tom aqui é um vermelho
// escuro, nunca preto. As coordenadas são do MUNDO (escolhidas pela face), então
// a chama sobe em todas as paredes sem depender do UV da caixa.

uniform sampler2D ruido : repeat_enable, filter_linear;
uniform float velocidade = 0.9;
uniform float escala = 0.55;
uniform float brilho = 1.0;

varying vec3 pos_mundo;
varying vec3 normal_mundo;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(normal_mundo);
	vec2 c = n.x > 0.5 ? pos_mundo.zy : (n.y > 0.5 ? pos_mundo.xz : pos_mundo.xy);
	float t = TIME * velocidade;
	float w = texture(ruido, c * escala * 0.6 + vec2(0.0, -t * 0.4)).r;
	float f1 = texture(ruido, c * escala + vec2((w - 0.5) * 0.5, -t)).r;
	float f2 = texture(ruido, c * escala * 2.3 + vec2(0.0, -t * 1.6)).r;
	float f = smoothstep(0.35, 0.95, f1 * 0.65 + f2 * 0.35);
	vec3 cor = mix(vec3(0.5, 0.03, 0.0), vec3(1.0, 0.35, 0.04), smoothstep(0.0, 0.5, f));
	cor = mix(cor, vec3(1.0, 0.82, 0.35), smoothstep(0.55, 1.0, f));
	ALBEDO = cor * brilho;
}
