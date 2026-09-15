shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Roupa de varal e bandeirinha de festa da cidade da stage_1.
//
// Cada peca e' UM quad preso pela borda DE CIMA, e todas dividem o mesmo atlas
// (`assets/images/textures/varal/`). Qual recorte cada instancia usa vem no
// custom data do MultiMesh; a cor e o quanto ela balanca vem na cor da
// instancia. Assim o varal inteiro de um bloco e' uma chamada de desenho.
//
// POR QUE AQUI O ALFA E' CORTADO, E NA PICHACAO NAO
// -------------------------------------------------
// Sao problemas diferentes. Pichacao e' traco de 3 px que o mipmap dilui ate'
// sumir — la' o corte apagava o desenho, e por isso aquele shader mistura.
// Roupa e' MANCHA CHEIA com borda dura: o corte nao tem o que apagar, e em
// troca devolve duas coisas que a mistura nao da' de graca — escrita de
// profundidade (uma camisa na frente da outra fica certa de qualquer angulo) e
// ordem nenhuma pra resolver, com dezenas de pecas penduradas perto umas das
// outras.
//
// O BALANCO
// ---------
// O pano e' preso na corda, entao o pivo NAO e' o centro do quad: e' a borda
// de cima (y = +0,5 no quad unitario). A peca gira em torno do eixo X local —
// que e' a propria corda — e o angulo cresce com a distancia ate' o pivo, ao
// quadrado. E' esse expoente que faz o pano CURVAR em vez de girar inteiro
// feito placa.
//
// A fase sai da posicao da instancia no mundo (MODEL_MATRIX[3]), e nao de um
// contador comum: sem isso o varal inteiro oscila junto, feito cortina de
// teatro. Sai de graca porque a matriz ja' esta' ali.
//
// O quad tem subdivisao no eixo vertical (ver `city_varais.gd`); sem ela
// sobram duas linhas de vertice e a curva vira uma inclinacao reta.

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float corte : hint_range(0.0, 1.0) = 0.5;
uniform float ganho : hint_range(0.0, 2.0) = 1.0;
// Angulo maximo do balanco, em radianos, na ponta de baixo da peca.
uniform float balanco : hint_range(0.0, 1.5) = 0.32;
// Ciclos por segundo do vento.
uniform float velocidade : hint_range(0.0, 4.0) = 0.8;
// Uma segunda onda mais rapida e mais fraca, pra nao virar metronomo.
uniform float tremida : hint_range(0.0, 1.0) = 0.35;

varying flat vec4 recorte;
varying flat vec4 tinta;

void vertex() {
	recorte = INSTANCE_CUSTOM;
	tinta = COLOR;

	vec3 origem = MODEL_MATRIX[3].xyz;
	float fase = origem.x * 0.73 + origem.z * 0.51;
	float onda = sin(TIME * velocidade + fase)
		+ sin(TIME * velocidade * 2.7 + fase * 1.9) * tremida;

	// 0 no pivo (topo), 1 na ponta de baixo
	float t = clamp(0.5 - VERTEX.y, 0.0, 1.0);
	float ang = onda * balanco * tinta.a * t * t;
	float c = cos(ang);
	float s = sin(ang);

	float y = VERTEX.y - 0.5;
	VERTEX.y = 0.5 + y * c - VERTEX.z * s;
	VERTEX.z = y * s + VERTEX.z * c;

	float ny = NORMAL.y;
	NORMAL.y = ny * c - NORMAL.z * s;
	NORMAL.z = ny * s + NORMAL.z * c;
}

void fragment() {
	vec4 cor = texture(atlas, recorte.xy + UV * recorte.zw);
	if (cor.a < corte) {
		discard;
	}
	ALBEDO = cor.rgb * tinta.rgb * ganho;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
