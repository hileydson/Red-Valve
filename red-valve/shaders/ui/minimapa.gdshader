shader_type canvas_item;
// Recorte circular e giratório do mapa da cidade.
//
// A rotação é feita na AMOSTRAGEM da textura, não girando o nó: girar um
// Control faria o recorte quadrado girar junto e aparecer canto vazio.
// Aqui o disco fica parado e o mapa é que roda por baixo dele.

uniform sampler2D mapa : filter_linear_mipmap, repeat_disable;
// posição do player dentro da textura, em UV
uniform vec2 centro_uv = vec2(0.5);
// giro em radianos; o script passa -rotation.y do player
uniform float giro = 0.0;
// metade da janela visível, em UV da textura
uniform float raio_uv = 0.088;

uniform vec4 cor_borda : source_color = vec4(0.78, 0.70, 0.55, 1.0);
uniform vec4 cor_fora : source_color = vec4(0.06, 0.07, 0.06, 1.0);
// espessura do anel, como fração do raio
uniform float espessura : hint_range(0.0, 0.2) = 0.035;
uniform float opacidade : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float aa = max(fwidth(d), 0.0008) * 1.5;

	float s = sin(giro);
	float c = cos(giro);
	vec2 r = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	vec2 uv = centro_uv + r * raio_uv;

	// fora da textura é mata, não borda preta: o mapa acaba, o mundo não
	vec3 cor = cor_fora.rgb;
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		cor = texture(mapa, uv).rgb;
	}

	float disco = 1.0 - smoothstep(1.0 - aa, 1.0, d);
	float miolo = 1.0 - smoothstep(1.0 - espessura - aa, 1.0 - espessura, d);
	float anel = clamp(disco - miolo, 0.0, 1.0);

	COLOR = vec4(mix(cor, cor_borda.rgb, anel), disco * opacidade);
}
