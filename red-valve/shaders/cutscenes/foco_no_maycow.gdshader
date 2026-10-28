shader_type canvas_item;

// O desfoque do voo da cutscene do mirante (inferno 4): a tela inteira borrada,
// menos um círculo em volta do Maycow. O desfoque por profundidade da câmera
// não pega a gárgula (o fogo dela é transparente, não grava profundidade): por
// isso é na tela. `foco` e `raio` vêm de `cutscene_mirante.gd` a cada quadro.

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
// centro nítido, em UV da tela
uniform vec2 foco = vec2(0.5);
// raio nítido e largura da borda, em fração da ALTURA da tela
uniform float raio = 0.08;
uniform float borda = 0.16;
// 0 = sem desfoque, 1 = desfoque inteiro
uniform float forca : hint_range(0.0, 1.0) = 0.0;
// nível de mipmap no desfoque inteiro
uniform float lod_max = 3.2;

void fragment() {
	vec2 d = SCREEN_UV - foco;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float m = smoothstep(raio, raio + borda, length(d));
	COLOR = vec4(textureLod(tela, SCREEN_UV, m * forca * lod_max).rgb, 1.0);
}
