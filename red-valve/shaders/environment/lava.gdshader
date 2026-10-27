// Lava do inferno: crosta escura rachada por cima de brasa viva, que ANDA.
//
// Dois jeitos de mapear, escolhidos pelo material:
//  - `usar_mundo`: XZ do mundo (o mar de lava, um disco enorme sem UV útil);
//  - UV da malha: o rio e as cachoeiras saem do Blender com V ao longo do
//    fluxo, então `fluxo` faz a lava escorrer pro lado certo.
// Duas camadas de ruído em velocidades diferentes: a crosta racha e fecha em
// vez de só deslizar como um papel de parede.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform bool usar_mundo = false;
uniform float escala_mundo = 0.03;
uniform vec2 escala_uv = vec2(1.0, 1.0);
uniform vec2 fluxo = vec2(0.0, 0.05);
uniform vec3 cor_crosta : source_color = vec3(0.045, 0.012, 0.008);
uniform vec3 cor_quente : source_color = vec3(1.0, 0.3, 0.04);
uniform vec3 cor_branca : source_color = vec3(1.0, 0.82, 0.38);
uniform float energia = 3.2;
uniform float crosta : hint_range(0.0, 1.0) = 0.52;
uniform float pulso = 0.18;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 base = usar_mundo ? mundo.xz * escala_mundo : UV * escala_uv;
	vec2 p1 = base + fluxo * TIME;
	vec2 p2 = base * 2.3 + fluxo * TIME * 1.7 + vec2(0.37, 0.11);
	float n1 = texture(ruido, p1).r;
	float n2 = texture(ruido, p2).r;
	float n = n1 * 0.75 + n2 * 0.25;
	// a brasa respira devagar, com fase diferente em cada canto
	float resp = 1.0 + pulso * sin(TIME * 1.3 + n1 * 9.0);
	// faixa larga: a crosta vira placa e a brasa vira veio, sem pontilhado
	float quente = smoothstep(crosta - 0.08, crosta + 0.3, n) * resp;
	float branco = smoothstep(crosta + 0.22, crosta + 0.4, n);
	vec3 cor = mix(cor_quente, cor_branca, branco);
	ALBEDO = cor_crosta;
	ROUGHNESS = 0.92;
	EMISSION = cor * quente * energia + cor_quente * 0.06;
}
