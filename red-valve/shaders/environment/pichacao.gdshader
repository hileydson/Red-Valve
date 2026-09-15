shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled, diffuse_lambert;

// Pichacao, cartaz e mancha da cidade da stage_1.
//
// Cada rabisco e' UM quad de dois triangulos colado na parede. Se cada desenho
// tivesse a textura propria, cada desenho seria um material proprio e uma
// chamada de desenho propria: 30 desenhos x 25 blocos da cidade = 750 chamadas
// so' de rabisco. Aqui os 30 desenhos dividem um atlas, entao o bloco inteiro
// cabe num MultiMesh de UMA chamada.
//
// Qual pedaco do atlas cada instancia usa vem no custom data do MultiMesh, e o
// quanto ela ja' desbotou vem na cor da instancia. INSTANCE_CUSTOM e COLOR so'
// existem no vertex(), por isso os dois varyings — sem eles o fragment() nao
// tem como saber que desenho esta' pintando.
//
// POR QUE `cull_disabled`
// -----------------------
// O `QuadMesh` com `orientation = FACE_Z` NAO encara o +Z local. Com
// `cull_back`, a cidade inteira ficava sem um rabisco sequer — e sem erro em
// log nenhum, porque descartar face nao e' erro. Fica registrado aqui pra nao
// se perder de novo: neste shader nao se usa cull_back. Tambem nao se perde
// nada com isso: cada rabisco esta' colado numa parede opaca, entao o outro
// lado dele nunca chega a ser desenhado.
//
// POR QUE MISTURA, E NAO ALPHA SCISSOR
// ------------------------------------
// O traco do spray tem 3-4 px no atlas. A 30 m de distancia o mipmap ja'
// diluiu esses 3 px com o vazio ao redor, e o alfa medio cai pra baixo de
// qualquer limiar util: o corte engoliria o desenho inteiro. Com mistura, esse
// mesmo traco diluido vira um traco mais fraco — que e' exatamente o que um
// rabisco velho parece de longe.
//
// O motivo classico pra fugir de transparencia — ordenacao — nao existe aqui:
// o espacador do `city_pichacao.gd` nunca deixa dois rabiscos se sobreporem, e
// cada um esta' colado numa parede opaca. `depth_draw_never` sela isso: o quad
// nao escreve profundidade, entao tambem nao tem como brigar com a fachada
// atras dele.

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Piso de alfa: abaixo disto o pixel e' vazio do atlas e sai fora. Serve so'
// pra economizar mistura, NAO pra desenhar a borda — ver o bloco acima.
uniform float corte : hint_range(0.0, 0.5) = 0.02;
// Multiplica o albedo. A cidade roda com LUT sepia; tinta saindo clara demais
// da' cara de adesivo novo em parede velha.
uniform float ganho : hint_range(0.0, 2.0) = 0.95;
// Some com a distancia, pra pichacao nao brigar com a neblina no fundo.
uniform float dist_some_inicio = 70.0;
uniform float dist_some_fim = 110.0;

varying flat vec4 recorte;   // xy = canto do desenho no atlas, zw = tamanho
varying flat vec4 desgaste;  // rgb = sujeira da tinta, a = quanto ja' desbotou

void vertex() {
	recorte = INSTANCE_CUSTOM;
	desgaste = COLOR;
}

void fragment() {
	vec4 c = texture(atlas, recorte.xy + UV * recorte.zw);

	// Tinta desbotada perde primeiro o respingo da borda, que e' o alfa baixo:
	// multiplicar o alfa aqui e' o que faz o rabisco velho ficar esburacado em
	// vez de so' mais claro.
	float a = c.a * desgaste.a;
	a *= 1.0 - smoothstep(dist_some_inicio, dist_some_fim, length(VERTEX));

	if (a < corte) {
		discard;
	}

	ALBEDO = c.rgb * desgaste.rgb * ganho;
	ALPHA = a;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
}
