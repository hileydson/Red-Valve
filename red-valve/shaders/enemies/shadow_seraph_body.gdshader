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

group_uniforms veias;
uniform float veia_escala : hint_range(0.5, 20.0) = 4.6;
// quanto da greta sobrevive ao corte: alto = poucas veias grossas
uniform float veia_corte : hint_range(0.3, 0.99) = 0.70;
uniform float veia_brilho : hint_range(0.0, 6.0) = 2.6;
// velocidade com que a brasa escorre pra cima dentro do corpo
uniform float veia_fluxo : hint_range(0.0, 2.0) = 0.30;
// respiro das veias (acende e apaga junto, como um folego)
uniform float pulso_hz : hint_range(0.0, 3.0) = 0.55;
// estouro ocasional: todas as veias clareiam de uma vez por um instante
uniform float flare_hz : hint_range(0.0, 2.0) = 0.23;
uniform float flare_forca : hint_range(0.0, 3.0) = 1.1;

group_uniforms borda;
// a silhueta nao desaparece: ela queima. Isto e a largura da faixa acesa.
uniform float borda_potencia : hint_range(0.2, 8.0) = 2.0;
uniform float borda_brilho : hint_range(0.0, 6.0) = 1.5;
// erosao SO na borda (o miolo fica solido)
uniform float borda_dissolve : hint_range(0.0, 2.0) = 1.25;
uniform float corpo_dissolve : hint_range(0.0, 1.0) = 0.10;
uniform float morde_escala : hint_range(0.5, 12.0) = 2.6;
uniform float fiapo_escala : hint_range(1.0, 60.0) = 20.0;

group_uniforms volume;
// infla a malha: a borda geometrica fica longe de onde o corpo parece acabar
uniform float billow : hint_range(0.0, 0.4) = 0.12;
uniform float billow_bias : hint_range(0.0, 1.0) = 0.45;
uniform float billow_escala : hint_range(0.5, 20.0) = 2.6;
// lento de proposito: peso de bicho grande
uniform float billow_speed : hint_range(0.0, 3.0) = 0.25;
uniform float warp : hint_range(0.0, 1.0) = 0.30;
uniform float warp_escala : hint_range(0.5, 10.0) = 1.8;

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
	float veia_fina = smoothstep(0.74, 0.90, ridged(vp * 2.9 + 3.3));
	veia = clamp(veia + veia_fina * 0.45, 0.0, 1.0);

	// folego: todas as veias acendem e apagam juntas...
	float pulso = 0.72 + 0.28 * sin(t * TAU * pulso_hz + hash13(floor(v_mundo)) * 6.2831);
	// ...e de vez em quando estouram de uma vez
	float ciclo = fract(t * flare_hz);
	float flare = smoothstep(0.0, 0.04, ciclo) * smoothstep(0.22, 0.06, ciclo);
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

	ALPHA = clamp(a, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
