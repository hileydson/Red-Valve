shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// A ONDA da troca de realidade: um MURO de luz em anel que nasce no Maycow e
// cresce pela cidade (um cilindro sem tampa). Aceso no pé e sumindo pra cima,
// com faixas subindo — de dentro dele, que é de onde o jogador olha, ele varre
// ruas e fachadas. É a passagem dele que troca as sombras, os carros e os
// inimigos (`realidade_do_amuleto.gd`).

uniform vec4 cor : source_color = vec4(0.6, 0.25, 1.0, 1.0);
uniform float alpha = 1.0;

varying vec3 pos_mundo;
varying float altura;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	altura = VERTEX.y + 0.5;
}

void fragment() {
	float pe = pow(1.0 - clamp(altura, 0.0, 1.0), 2.2);
	float faixa = 0.6 + 0.4 * sin(pos_mundo.y * 2.2 - TIME * 9.0)
		* (0.6 + 0.4 * sin(atan(pos_mundo.x, pos_mundo.z) * 40.0 + TIME * 2.0));
	ALBEDO = cor.rgb * pe * faixa * alpha * 1.8;
	ALPHA = clamp(pe * alpha, 0.0, 1.0);
}
