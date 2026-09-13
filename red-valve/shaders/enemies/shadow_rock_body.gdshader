shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Corpo do Shadow Rock e de tudo que ele cria (pedregulho, espada, parede,
// detritos no chao). E o contraponto exato do `shadow_seraph_body`:
//
//   shadow_seraph -> carvao aceso, unshaded, silhueta que queima e se desfaz.
//                    Ele mal esta aqui.
//   shadow_rock   -> PEDRA DE VERDADE. Malha solida, iluminada pela cena,
//                    textura de rocha de verdade colada em cada pedaco e um
//                    fio de brasa preso SO no fundo das gretas. Ele esta aqui
//                    mais do que qualquer coisa na tela.
//
// As tres escolhas que sustentam isso:
//
//  1. TRIPLANAR EM ESPACO DE MODELO. Os pedacos dele sao malhas geradas por
//     codigo (esfera deformada e facetada, ver `rock_fx.gd`): as UVs saem
//     esticadas nos polos e inuteis. Triplanar resolve, mas tem de ser no
//     espaco do MODELO, nao do mundo — em espaco de mundo a textura fica
//     parada enquanto o bicho anda e a pedra parece nadar por dentro da
//     propria casca. No espaco do modelo cada pedaco carrega a textura junto;
//  2. SEMENTE NA COR DO VERTICE. Dezoito malhas de pedra servem as dezenas de
//     pedacos em tela. Se as gretas fossem iguais em todas, a repeticao
//     apareceria. `COLOR.r` chega da malha com um numero fixo por pedra e
//     desloca o ruido das gretas — e uma varredura de graca, sem uniform por
//     instancia (que no renderer Mobile nem sempre acompanha material_override);
//  3. OCLUSAO ASSADA EM `COLOR.g`. O gerador marca cada vertice com o quanto
//     ele se projeta pra fora. As reentrancias escurecem e as quinas pegam po
//     claro: e o que da volume a uma malha de ~60 triangulos sem normal map.
//
// A brasa das gretas e SUTIL de proposito (e o mesmo laranja dos olhos dele,
// muito mais fraco). Ele nao e um golem de lava: e pedra com alguma coisa viva
// presa nas fendas.

group_uniforms rocha;
uniform sampler2D textura_rocha : source_color, filter_linear_mipmap, repeat_enable;
// Voltas de textura por pedra. As malhas do `rock_fx` tem raio 0,5 em espaco
// de modelo, entao este numero e lido como "quantas vezes a rocha se repete
// atravessando um pedaco" — e, porque o espaco e o do MODELO, um caco pequeno
// recebe a mesma quantidade de textura de um bloco grande. De proposito: grao
// mais fino nas pedras menores e exatamente o que se ve em pedra de verdade.
uniform float escala_tex : hint_range(0.1, 12.0) = 3.2;
uniform vec4 tinta : source_color = vec4(0.62, 0.60, 0.58, 1.0);
uniform vec4 tinta_funda : source_color = vec4(0.085, 0.080, 0.085, 1.0);
// Brilho MEDIO da textura ja em espaco linear. A `textura_rocha` entra com
// hint `source_color`, entao o que o arquivo mostra como cinza 0,45 chega aqui
// como ~0,17. Multiplicar `tinta` por esse valor cru pintaria o bicho de
// preto; dividir a amostra por esta media devolve um DETALHE em volta de 1,0 e
// devolve o controle da cor pra `tinta`. Se trocar a textura, e este numero
// que precisa acompanhar.
uniform float brilho_medio : hint_range(0.02, 1.0) = 0.17;
// Quanto da COR da textura sobrevive. Zero = o grao entra so como claro-escuro
// e quem pinta e `tinta`. Alto demais e o problema oposto do brilho: dividir a
// amostra pela media multiplica tambem a saturacao dela, e o cinza levemente
// quente do `rockwall` vira ferrugem no corpo inteiro.
uniform float cor_da_rocha : hint_range(0.0, 1.0) = 0.22;
// Quanto a oclusao assada escurece as reentrancias.
uniform float oclusao : hint_range(0.0, 1.5) = 0.55;
uniform float aspereza : hint_range(0.0, 1.0) = 0.88;
// Po claro acumulado nas faces viradas pra cima.
uniform vec4 poeira : source_color = vec4(0.62, 0.60, 0.56, 1.0);
uniform float poeira_forca : hint_range(0.0, 1.0) = 0.22;
// Peso da mistura triplanar. Alto = transicoes curtas entre os tres planos.
uniform float triplanar_nitidez : hint_range(1.0, 12.0) = 4.0;

group_uniforms gretas;
uniform vec4 brasa : source_color = vec4(1.0, 0.42, 0.10, 1.0);
uniform float greta_escala : hint_range(0.5, 20.0) = 7.0;
// Corte MUITO alto, e nao por capricho: `ridged` nasce de um ruido suavizado,
// entao `1 - |2n-1|` se concentra perto de 1 e a media dele fica la em cima
// (~0,8). Com um corte "normal" de 0,7 a greta cobre metade da pedra e o bicho
// vira lava. E aqui que se decide quanta fenda existe.
uniform float greta_corte : hint_range(0.3, 0.995) = 0.935;
uniform float greta_brilho : hint_range(0.0, 4.0) = 0.70;
// Respiro da brasa. Lento: e pedra, nao fogo.
uniform float pulso_hz : hint_range(0.0, 2.0) = 0.22;

group_uniforms dano;
// Sobe quando o pedaco e arrancado ou quando a parede apanha: a pedra racha
// mais, esbranquica na fratura e a brasa vaza.
uniform float fratura : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_modelo;
varying vec3 v_nrm_modelo;
varying float v_semente;
varying float v_expost;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Ruido ridged: o vale do ruido vira crista. E o que da LINHA (fenda) em vez
// de mancha — mesmo truque das veias do Seraph, so que aqui ele desenha a
// rachadura da pedra e nao a veia de brasa.
float ridged(vec3 p) {
	float a = 1.0 - abs(vnoise(p) * 2.0 - 1.0);
	float b = 1.0 - abs(vnoise(p * 2.4 + 5.7) * 2.0 - 1.0);
	return a * 0.7 + b * 0.3;
}

void vertex() {
	v_modelo = VERTEX;
	v_nrm_modelo = NORMAL;
	v_semente = COLOR.r * 37.0;   // fixo por malha de pedra
	v_expost = COLOR.g;           // 0 = fundo de reentrancia, 1 = quina exposta
}

// Amostra triplanar no espaco do modelo.
vec3 tri(vec3 p, vec3 n) {
	vec3 peso = pow(abs(n), vec3(triplanar_nitidez));
	peso /= max(peso.x + peso.y + peso.z, 0.0001);
	vec3 uv = p * escala_tex;
	vec3 x = texture(textura_rocha, uv.zy).rgb;
	vec3 y = texture(textura_rocha, uv.xz).rgb;
	vec3 z = texture(textura_rocha, uv.xy).rgb;
	return x * peso.x + y * peso.y + z * peso.z;
}

void fragment() {
	vec3 n = normalize(v_nrm_modelo);
	vec3 rocha = tri(v_modelo, n);

	// Detalhe da textura em volta de 1,0 (ver `brilho_medio`): e ele que da o
	// granulado, enquanto `tinta` da a cor. A propria textura serve de mapa de
	// altura — o que e escuro nela e fenda, e fenda escurece de vez.
	float inv_media = 1.0 / max(brilho_medio, 0.001);
	float relevo = clamp(dot(rocha, vec3(0.2126, 0.7152, 0.0722)) * inv_media, 0.0, 2.0);
	vec3 detalhe = mix(vec3(relevo), clamp(rocha * inv_media, 0.0, 2.0), cor_da_rocha);
	vec3 col = tinta.rgb * detalhe;
	col = mix(tinta_funda.rgb, col, smoothstep(0.16, 0.80, relevo));

	// oclusao assada pelo gerador da malha
	float ao = mix(1.0 - oclusao * 0.75, 1.0, clamp(v_expost, 0.0, 1.0));
	col *= ao;

	// po claro so no que olha pra cima (NORMAL de mundo, nao a do modelo)
	float pra_cima = clamp(NORMAL.y, 0.0, 1.0);
	col = mix(col, poeira.rgb * clamp(relevo, 0.0, 1.4), pra_cima * pra_cima * poeira_forca);

	// ---- gretas com brasa presa no fundo ----
	vec3 gp = v_modelo * greta_escala + vec3(v_semente, v_semente * 1.7, v_semente * 0.6);
	float crista = ridged(gp);
	float corte = greta_corte - fratura * 0.10;
	float greta = smoothstep(corte, corte + 0.035, crista);
	// a fenda e um sulco: escurece a pedra em volta antes de acender
	col *= 1.0 - greta * 0.55;
	float pulso = 0.65 + 0.35 * sin(TIME * TAU * pulso_hz + v_semente * 6.2831);
	float calor = greta * pulso * (greta_brilho + fratura * 1.6);

	ALBEDO = col;
	EMISSION = brasa.rgb * calor * 0.40;
	ROUGHNESS = clamp(aspereza - relevo * 0.10 + fratura * 0.08, 0.35, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.18;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
}
