shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded, shadows_disabled;

// Corpo do Shadow Seraph. Mesma FAMILIA do `shadow_being.gdshader` (as sombras
// da cidade): massa de escuridao montada com capsulas, silhueta definida pelo
// recorte do ruido e nao pela borda da malha. O que muda e a leitura:
//
//   shadow_person -> fumaca fria, nervosa, que se desfaz quase toda na borda.
//                    Gente que mal esta ali.
//   shadow_seraph -> CARVAO ACESO. A massa e densa e pesada no meio (ele tem
//                    corpo, nao e um vapor), gretada por veias de brasa que
//                    pulsam de dentro pra fora, a silhueta QUEIMA em vez de
//                    sumir, e dela se desprendem cinzas subindo.
//
// As quatro coisas que fazem essa diferenca:
//
//  1. ruido RIDGED (1 - |2n-1|) em vez de fbm direto: fbm da manchas, ridged da
//     LINHAS. E o que vira greta de lava em vez de nuvem;
//  2. densidade com gradiente de corpo: o recorte de alpha e fraco no miolo e
//     forte so na faixa do fresnel, entao ele nao fica esfarelado por inteiro
//     como as pessoas — o volume se mantem e so a casca se desfaz;
//  3. billow lento e de amplitude maior: um bicho de 2,8 m tem de se mover com
//     peso. O das pessoas treme a 0,8 Hz; este respira a 0,25 Hz;
//  4. cinza subindo: pontinhos brilhantes de ruido de alta frequencia
//     escorrendo pra CIMA na superficie, o oposto da fumaca das sombras (que
//     escorre pra baixo).
//
// Nada de glitch em bandas aqui: aquilo e assinatura das sombras da cidade, que
// sao aparicoes falhando. Este e solido e aceso — quando ele "falha", o que
// acontece e as veias estourarem de luz (ver `flare`).
//
// ---------------------------------------------------------------------------
// O QUE VEM DA MALHA (COLOR), desde que o corpo dele deixou de ser capsula
//
// O corpo agora e MODELADO (`tools/blender/seraph/gerar_seraph.py`), e a malha
// traz dois canais de DADO na cor de vertice. Antes tudo aqui era sorteado por
// ruido, entao o fogo caia em qualquer lugar — inclusive no meio de uma placa
// lisa, onde nada deveria queimar. Com estes dois canais o desenho do fogo
// passa a ser DECIDIDO no modelo:
//
//   COLOR.r  BRASA: 1 onde tem de queimar (fundo da caixa de costelas, fenda
//            do elmo, juntas, fio das laminas, aurela), 0 no meio de uma
//            placa de armadura. O ruido continua desenhando a TEXTURA da
//            greta; este canal decide ONDE ela tem direito de acender.
//   COLOR.g  QUINA: 1 numa aresta viva. Carvao lascado clareia na quina, e e
//            isso que faz a peca ter volume mesmo sendo unshaded.
//
// Malha sem COLOR (as primitivas de reserva, se o `.glb` faltar) chega com
// COLOR = branco, ou seja brasa 1 e quina 1 — o `mistura_brasa` existe pra
// esse caso continuar parecido com o shader antigo em vez de virar tocha.
//
// Alpha scissor, nao blend, pelo mesmo motivo do shader das sombras: as partes
// do corpo se sobrepoem e blending traria costura e ordenacao errada.

group_uniforms cores;
// carvao: quase preto, mas com fundo quente — preto puro mataria a brasa
uniform vec4 carvao : source_color = vec4(0.022, 0.013, 0.012, 1.0);
// a massa um pouco mais clara, onde a cinza esta fria
uniform vec4 cinza : source_color = vec4(0.085, 0.070, 0.078, 1.0);
// brasa das veias
uniform vec4 brasa : source_color = vec4(1.0, 0.34, 0.06, 1.0);
// nucleo das veias mais fundas, onde chega a amarelar
uniform vec4 brasa_quente : source_color = vec4(1.0, 0.76, 0.30, 1.0);

group_uniforms malha;
// Quanto a mascara de brasa da MALHA manda. 0 = so ruido (comportamento
// antigo); 1 = so a mascara. No meio, o ruido desenha a greta e a mascara diz
// onde ela pode acender, que e o que se quer.
uniform float mistura_brasa : hint_range(0.0, 1.0) = 0.78;
// Piso de brasa fora da mascara: nem a placa mais lisa fica completamente
// morta, senao o corpo racha em duas leituras (fogo e pedra) sem transicao.
uniform float brasa_minima : hint_range(0.0, 1.0) = 0.09;
// Clareado das quinas. E o unico "sombreamento" que um shader unshaded tem.
uniform float quina_brilho : hint_range(0.0, 2.0) = 0.55;

group_uniforms veias;
uniform float veia_escala : hint_range(0.5, 20.0) = 4.6;
// Quanto da greta sobrevive ao corte: alto = poucas veias grossas.
//
// 0,90 e nao 0,70. O `ridged()` nao devolve valores espalhados por [0,1]: ele
// e `1 - |2n-1|`, que AMONTOA tudo perto de 1. Cortar em 0,70 deixava passar a
// superficie quase inteira e o bicho lia como LAVA — laranja continuo com
// manchas escuras — em vez de carvao com veia. E a mesma armadilha que ja
// tinha mordido o Shadow Rock, onde o corte teve de ir a 0,935.
uniform float veia_corte : hint_range(0.3, 0.99) = 0.90;
uniform float veia_brilho : hint_range(0.0, 6.0) = 1.9;
// velocidade com que a brasa escorre pra cima dentro do corpo
uniform float veia_fluxo : hint_range(0.0, 2.0) = 0.30;
// respiro das veias (acende e apaga junto, como um folego)
uniform float pulso_hz : hint_range(0.0, 3.0) = 0.55;
// estouro ocasional: todas as veias clareiam de uma vez por um instante
uniform float flare_hz : hint_range(0.0, 2.0) = 0.23;
uniform float flare_forca : hint_range(0.0, 3.0) = 1.1;

group_uniforms borda;
// A silhueta nao desaparece: ela queima. Isto e a largura da faixa acesa.
//
// Os dois numeros mudaram quando o corpo virou malha MODELADA, e a razao e
// geometrica: numa capsula lisa a normal so fica de raspao pro olho bem perto
// do contorno, entao um fresnel largo (potencia 2, brilho 1,5) desenhava um
// aro. Numa malha facetada de sombreamento plano ha faces inteiras de raspao
// no meio do corpo — com os valores antigos o bicho inteiro acendia laranja e
// nao sobrava nem placa nem quina pra ver. Faixa mais estreita e mais fraca
// devolve a silhueta acesa sem incendiar a superficie.
uniform float borda_potencia : hint_range(0.2, 8.0) = 3.6;
uniform float borda_brilho : hint_range(0.0, 6.0) = 0.55;
// erosao SO na borda (o miolo fica solido)
uniform float borda_dissolve : hint_range(0.0, 2.0) = 1.25;
uniform float corpo_dissolve : hint_range(0.0, 1.0) = 0.10;
uniform float morde_escala : hint_range(0.5, 12.0) = 2.6;
uniform float fiapo_escala : hint_range(1.0, 60.0) = 20.0;

group_uniforms volume;
// infla a malha: a borda geometrica fica longe de onde o corpo parece acabar
// Baixo agora: 0,12 inflava a malha em ate 23 cm ao longo da normal, o que
// fazia sentido quando o corpo era um monte de capsulas que precisavam se
// encostar. Numa malha modelada isso engole quina, placa e silhueta — que sao
// justamente as tres coisas que o modelo novo existe pra ter.
uniform float billow : hint_range(0.0, 0.4) = 0.035;
uniform float billow_bias : hint_range(0.0, 1.0) = 0.45;
uniform float billow_escala : hint_range(0.5, 20.0) = 2.6;
// lento de proposito: peso de bicho grande
uniform float billow_speed : hint_range(0.0, 3.0) = 0.25;
uniform float warp : hint_range(0.0, 1.0) = 0.30;
uniform float warp_escala : hint_range(0.5, 10.0) = 1.8;

group_uniforms forma;
// LUZ DE MENTIRA. O shader e `unshaded` de proposito (ele e sombra, nao pode
// receber a iluminacao da cidade e virar um boneco cinza no meio da rua), mas
// unshaded puro sobre um carvao de albedo 0,02 significa que a unica coisa
// visivel do corpo e onde a veia acende. Enquanto ele foi um monte de capsula
// isso nao custou nada: nao havia forma pra mostrar. Agora ha — placa, quina,
// costela, elmo, ombreira — e sem um termo de forma tudo isso fica invisivel.
//
// Entao entra uma unica direcao fixa, em espaco de MUNDO (nao de camera:
// presa na camera, o corpo gira e a luz nao, e ele parece de plastico), com
// meia-lambert bem fraca e tinta fria. E a diferenca entre ver um modelo e ver
// uma silhueta com fogo dentro. A brasa apaga este termo onde ela e forte, pra
// nao lavar a veia.
uniform vec3 luz_dir = vec3(-0.45, 0.78, -0.44);
uniform float luz_forca : hint_range(0.0, 2.0) = 0.60;
uniform vec4 luz_cor : source_color = vec4(0.44, 0.40, 0.46, 1.0);

group_uniforms cinzas;
uniform float cinza_escala : hint_range(4.0, 80.0) = 34.0;
uniform float cinza_subida : hint_range(0.0, 3.0) = 1.10;
uniform float cinza_quantidade : hint_range(0.0, 1.0) = 0.055;

varying vec3 v_mundo;
varying float v_billow;

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

float fbm(vec3 p) {
	return vnoise(p) * 0.60 + vnoise(p * 2.6 + 11.3) * 0.27 + vnoise(p * 5.9 + 31.7) * 0.13;
}

// Ruido ridged: o vale do ruido vira CRISTA. Duas oitavas bastam pra dar a
// ramificacao de greta sem virar espaguete.
float ridged(vec3 p) {
	float a = 1.0 - abs(vnoise(p) * 2.0 - 1.0);
	float b = 1.0 - abs(vnoise(p * 2.3 + 7.1) * 2.0 - 1.0);
	return a * 0.68 + b * 0.32;
}

vec3 warp_pos(vec3 p, float t) {
	vec3 s = p * warp_escala + vec3(0.0, -t, 0.0);
	vec3 q = vec3(vnoise(s), vnoise(s + 5.2), vnoise(s + 9.1)) - 0.5;
	return p + q * warp;
}

void vertex() {
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec3 bp = warp_pos(mundo, TIME * billow_speed * 0.5) * billow_escala;
	bp.y -= TIME * billow_speed;
	v_billow = fbm(bp) - 0.5;
	// so pra fora: a massa cresce e as partes vizinhas encostam, em vez de
	// afundar e abrir buraco no corpo
	VERTEX += NORMAL * (v_billow + billow_bias) * billow * 2.0;

	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec3 wp = warp_pos(v_mundo, t * 0.25);

	// faixa de borda larga (nao um fiapo colado no contorno da capsula)
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), borda_potencia);

	// ---- veias de brasa ----
	vec3 vp = wp * veia_escala;
	vp.y -= t * veia_fluxo;               // a brasa escorre pra cima dentro dele
	float greta = ridged(vp);
	// corte alto deixa so as cristas: e isso que separa greta de mancha
	float veia = smoothstep(veia_corte, veia_corte + 0.09, greta);
	// uma segunda escala, mais fina, quebra a veia em pedacos como carvao real
	float veia_fina = smoothstep(0.88, 0.97, ridged(vp * 2.9 + 3.3));
	veia = clamp(veia + veia_fina * 0.45, 0.0, 1.0);

	// folego: todas as veias acendem e apagam juntas...
	float pulso = 0.72 + 0.28 * sin(t * TAU * pulso_hz + hash13(floor(v_mundo)) * 6.2831);
	// ...e de vez em quando estouram de uma vez
	float ciclo = fract(t * flare_hz);
	float flare = smoothstep(0.0, 0.04, ciclo) * smoothstep(0.22, 0.06, ciclo);
	// A MASCARA DA MALHA entra aqui: o ruido ja desenhou a greta, e agora a
	// malha diz onde essa greta tem direito de acender.
	float mascara = mix(1.0, max(COLOR.r, brasa_minima), mistura_brasa);
	veia *= mascara;
	// Onde a mascara e forte a brasa nao depende so do ruido: a fenda do elmo
	// e o fundo das costelas queimam mesmo que nenhuma crista caia ali.
	veia = max(veia, smoothstep(0.55, 1.0, COLOR.r) * 0.85);

	float calor = veia * pulso * (1.0 + flare * flare_forca);

	// ---- cinza subindo ----
	vec3 cp = wp * cinza_escala;
	cp.y -= t * cinza_subida;
	float faisca = step(1.0 - cinza_quantidade, vnoise(cp));

	// ---- cor ----
	// base: carvao no miolo, cinza fria onde o ruido grosso sobe
	float massa = clamp(fbm(wp * 5.0 + vec3(0.0, -t * 0.18, 0.0)) * 1.6, 0.0, 1.0);
	vec3 col = mix(carvao.rgb, cinza.rgb, massa * 0.8);
	// veias: brasa, amarelando nas mais fundas
	vec3 cor_veia = mix(brasa.rgb, brasa_quente.rgb, clamp(calor - 0.6, 0.0, 1.0) * 1.6);
	col += cor_veia * calor * veia_brilho;
	// a silhueta queima: aro aceso em vez de desaparecer
	col += brasa.rgb * fres * borda_brilho * (0.55 + 0.45 * massa);
	col += brasa_quente.rgb * faisca * 2.2;
	// FORMA: meia-lambert contra uma direcao de mundo. `NORMAL` no fragment do
	// Godot esta em espaco de CAMERA, entao volta pra mundo pelo
	// INV_VIEW_MATRIX — sem isso a luz acompanha o giro da camera e o corpo
	// perde volume justo quando o jogador circula em volta dele.
	vec3 n_mundo = normalize((INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).xyz);
	float lam = clamp(dot(n_mundo, normalize(luz_dir)) * 0.5 + 0.5, 0.0, 1.0);
	col += luz_cor.rgb * pow(lam, 1.7) * luz_forca * (1.0 - clamp(calor, 0.0, 1.0) * 0.75);
	// quina: carvao lascado pega luz na aresta. Cinza clara, nao brasa — se a
	// quina acendesse laranja o corpo inteiro viraria arame de neon.
	col += luz_cor.rgb * COLOR.g * quina_brilho * (0.4 + 0.6 * massa);
	ALBEDO = col;

	// ---- recorte ----
	// Erosao em tres escalas, mas pesada SO na faixa da borda: o miolo fica
	// solido (ele tem corpo), a casca e que se desmancha em cinza.
	float morde = fbm(wp * morde_escala + vec3(0.0, -t * 0.35, 0.0));
	float medio = vnoise(wp * morde_escala * 3.2 + vec3(0.0, -t * 0.6, 0.0));
	float fino = vnoise(wp * fiapo_escala + vec3(0.0, -t * 0.9, 0.0));
	float erosao = morde * 0.55 + medio * 0.28 + fino * 0.17;

	float a = 1.0;
	a -= borda_dissolve * fres * smoothstep(0.22, 0.80, erosao);
	a -= corpo_dissolve * smoothstep(0.55, 0.95, fino * 0.6 + morde * 0.4);
	// onde a veia esta acesa a massa NAO se apaga: brasa segura o corpo
	a += calor * 0.45;
	// A placa de armadura nao se desmancha: so a casca sem mascara e que vira
	// cinza. Sem isto o modelo novo ficaria esburacado justo onde ele tem
	// forma pra mostrar.
	a += smoothstep(0.10, 0.55, 1.0 - COLOR.r) * 0.18;

	ALPHA = clamp(a, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
