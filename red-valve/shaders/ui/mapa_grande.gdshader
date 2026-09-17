shader_type canvas_item;
// Mapa da cidade em tela cheia, com zoom e arrasto.
//
// O zoom é feito na AMOSTRAGEM, não escalando o nó: um TextureRect de 2048²
// com scale grande custa a mesma banda de textura em qualquer nível e ainda
// obriga a recortar por fora. Aqui a janela visível é um uniform.
//
// Ao contrário do minimapa, este NÃO gira: os rótulos dos pontos ficariam
// de cabeça para baixo. Aqui o norte é sempre para cima e quem gira é a
// seta do player.

uniform sampler2D mapa : filter_linear_mipmap, repeat_disable;
uniform vec2 centro_uv = vec2(0.5);
// metade da janela visível na VERTICAL, em UV
uniform float meia_janela = 0.09;
// largura/altura do retângulo, para o zoom não deformar
uniform float aspecto = 1.0;

uniform vec4 cor_fora : source_color = vec4(0.055, 0.065, 0.058, 1.0);
uniform vec4 cor_grade : source_color = vec4(1.0, 1.0, 1.0, 0.045);
// espaçamento da grade, em UV (o script põe 100 m aqui)
uniform float grade_uv = 0.147;
uniform bool grade_ligada = true;

// --- nevoa: o que o jogador ja descobriu ---------------------------------
// Mascara R8 pequena (256 px) esticada por cima da planta de 2048. Vermelho
// em 1 = descoberto, 0 = nunca visto. Quem a escreve e o mapa_nevoa.gd.
//
// Interpolada de proposito: e a interpolacao que faz a borda do que foi
// descoberto CLAREAR em vez de aparecer aos quadrados.
uniform sampler2D nevoa : filter_linear, repeat_disable;
uniform bool nevoa_ligada = false;
// O nao-descoberto nao e preto: e um cinza de papel queimado, um degrau
// acima do lado de fora do mapa. Preto chapado leria como "aqui nao tem
// predio", e o que se quer dizer e "aqui tem predio e voce nao viu".
uniform vec4 cor_nevoa : source_color = vec4(0.085, 0.080, 0.074, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.x *= aspecto;
	vec2 uv = centro_uv + p * meia_janela;

	vec3 cor = cor_fora.rgb;
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		cor = texture(mapa, uv).rgb;
		if (nevoa_ligada) {
			float visto = smoothstep(0.0, 1.0, texture(nevoa, uv).r);
			cor = mix(cor_nevoa.rgb, cor, visto);
		}
	}

	// A grade fica POR CIMA da nevoa: ela nao e desenho do predio, e a regua
	// do papel. Apagada junto, o jogador perderia a nocao de distancia justo
	// onde ele ainda nao esteve.
	if (grade_ligada) {
		// linha de 1 px na tela, não no mundo: some quando dá zoom out
		vec2 g = abs(fract(uv / grade_uv) - 0.5) / fwidth(uv / grade_uv);
		float linha = 1.0 - min(min(g.x, g.y), 1.0);
		cor = mix(cor, cor_grade.rgb, linha * cor_grade.a);
	}

	COLOR = vec4(cor, 1.0);
}
