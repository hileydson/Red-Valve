shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// O indicador de todo item de cenario (`marca_de_item.gd`), no estilo do RE2
// Remake: circulo branco com miolo escuro translucido e uma seta pra baixo,
// virado pra camera e do MESMO tamanho na tela a qualquer distancia. A
// profundidade normal esconde atras de parede e movel o que de fato tapa a vista
// (raio de fisica nao serve: a colisao dos moveis e' mais alta que eles).

uniform vec4 cor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Raio em fracao da altura da tela (0.026 ~ 28 px num 1080p).
uniform float tamanho = 0.026;
// Fade de entrada/saida e de distancia, por instancia.
instance uniform float alfa = 1.0;

void vertex() {
	// Billboard em espaco de tela: o centro vai pro clip e o quad abre em
	// pixels a partir dele. Antes, chega 12 cm pra camera, pra nao entrar no
	// proprio item nem no tampo onde ele esta'.
	vec4 vista = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vista.z = min(vista.z + 0.12, -0.05);
	vec4 centro = PROJECTION_MATRIX * vista;
	vec2 abre = VERTEX.xy * tamanho * 2.0 * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
	POSITION = centro + vec4(abre * centro.w, 0.0, 0.0);
}

float _segmento(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	// y pra cima: o billboard ja' sai do clip com o UV de ponta-cabeca.
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = fwidth(r) * 1.2;

	float dentro = 1.0 - smoothstep(0.9 - aa, 0.9 + aa, r);
	float anel = smoothstep(0.76 - aa, 0.76 + aa, r) * dentro;
	float seta_d = min(_segmento(p, vec2(-0.34, 0.12), vec2(0.0, -0.2)),
		_segmento(p, vec2(0.34, 0.12), vec2(0.0, -0.2)));
	float seta = 1.0 - smoothstep(0.085 - aa, 0.085 + aa, seta_d);
	float branco = max(anel, seta);

	// Miolo escuro pra destacar em parede clara; branco por cima.
	ALBEDO = mix(vec3(0.0), cor.rgb, branco);
	ALPHA = max(branco, dentro * 0.42) * cor.a * alfa;
}
