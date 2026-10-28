shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Carne do parasita do "Unknown Neighbor".
//
// Este shader NAO e da familia dos outros dois inimigos de codigo, e a
// diferenca e proposital:
//
//   shadow_seraph -> carvao aceso, unshaded, silhueta que queima.
//   shadow_rock   -> pedra seca, fosca, quina dura.
//   parasita      -> CARNE MOLHADA. Tem volume de verdade (e ILUMINADO, nao
//                    unshaded), brilha na luz como coisa umida, e por dentro
//                    dela corre uma rede de veias que pulsa no ritmo de um
//                    coracao. E o contrario dos outros dois: eles sao
//                    materia morta acesa; este e materia VIVA.
//
// Por que iluminado e nao unshaded: o corpo dele e uma pessoa comum, com
// textura de roupa e pele recebendo a luz da cena. Um parasita unshaded
// grudado nela desmonta a leitura na hora — a flor da cabeca flutuaria como
// adesivo em cima do ombro. Ele tem de pegar a MESMA luz do corpo que ocupa.
//
// ---------------------------------------------------------------------------
// O QUE VEM DA MALHA (COLOR)
//
// As pecas sao modeladas em `tools/blender/vizinho/gerar_vizinho.py`, na mesma
// convencao de dado de vertice das do Seraph:
//
//   COLOR.r  VEIA: 1 onde a rede tem direito de aparecer (fundo da flor,
//            garganta, juntas, dorso da foice, raiz dos brotos), 0 no meio de
//            uma superficie lisa. O ruido desenha a TEXTURA da veia; este
//            canal decide ONDE ela existe.
//   COLOR.g  QUINA: 1 numa aresta viva. Carne esticada clareia e fica seca na
//            dobra; e o que da volume pra peca mesmo de longe.
//
// Malha sem COLOR (as primitivas de reserva, quando o .glb nao esta
// importado) chega branca — ou seja veia 1 e quina 1 — e por isso existe o
// `mistura_veia`: nesse caso a peca fica veiada por inteiro em vez de virar
// uma bola de luz.

group_uniforms cores;
// carne base da linhagem (a cor que separa palido de biliar de escarlate)
uniform vec4 carne : source_color = vec4(0.47, 0.58, 0.16, 1.0);
// as veias, a MESMA cor da luz que o bicho carrega
uniform vec4 veia : source_color = vec4(0.72, 1.0, 0.24, 1.0);
// carne no fundo das pregas, onde a luz nao chega
uniform vec4 fundo : source_color = vec4(0.06, 0.05, 0.05, 1.0);

group_uniforms rede;
// Grossura da rede. Ridged (1 - |2n-1|) amontoa valor perto de 1, entao o
// corte TEM de ser alto: abaixo de 0.90 a peca inteira acende e o parasita
// vira lava. Mesma armadilha que ja mordeu o Shadow Seraph.
uniform float corte : hint_range(0.85, 0.995) = 0.935;
uniform float escala_rede = 5.5;
// Quanto da veia sobrevive numa malha sem COLOR (primitiva de reserva).
uniform float mistura_veia : hint_range(0.0, 1.0) = 0.55;

group_uniforms pulso;
// Batidas por segundo do coracao. O script sobe isto conforme a vida cai: nas
// ultimas formas ele esta em panico, e da pra VER isso antes de olhar a barra.
uniform float bpm = 1.1;
uniform float forca_pulso : hint_range(0.0, 3.0) = 1.0;
// Estouro instantaneo das veias (dano levado, poder disparando).
uniform float flare : hint_range(0.0, 1.0) = 0.0;

group_uniforms superficie;
uniform float umidade : hint_range(0.0, 1.0) = 0.72;
// Fica 1 quando a peca esta morta (membro arrancado): a veia apaga e a carne
// seca. Usado pelo membro que caiu no chao.
uniform float morto : hint_range(0.0, 1.0) = 0.0;

varying vec3 pos_local;
varying vec4 dados;

// Ruido de valor barato — sem textura, sem sampler, roda em qualquer aparelho.
float aleatorio(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = aleatorio(i + vec3(0.0, 0.0, 0.0));
	float n100 = aleatorio(i + vec3(1.0, 0.0, 0.0));
	float n010 = aleatorio(i + vec3(0.0, 1.0, 0.0));
	float n110 = aleatorio(i + vec3(1.0, 1.0, 0.0));
	float n001 = aleatorio(i + vec3(0.0, 0.0, 1.0));
	float n101 = aleatorio(i + vec3(1.0, 0.0, 1.0));
	float n011 = aleatorio(i + vec3(0.0, 1.0, 1.0));
	float n111 = aleatorio(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// Ridged: transforma mancha em LINHA. E o que faz a rede parecer veia e nao
// nuvem — mesma escolha do corpo do Seraph.
float rede_de_veias(vec3 p) {
	float a = 1.0 - abs(2.0 * ruido(p) - 1.0);
	float b = 1.0 - abs(2.0 * ruido(p * 2.13 + 7.3) - 1.0);
	return a * 0.65 + b * 0.35;
}

void vertex() {
	pos_local = VERTEX;
	dados = COLOR;
}

void fragment() {
	// ---- mascara: onde a veia TEM DIREITO de existir
	// COLOR.r == 1 em TODA a peca so acontece com primitiva de reserva (malha
	// sem cor de vertice chega branca): nesse caso a rede e' aparada pelo
	// `mistura_veia`, senao a capsula inteira acenderia.
	float mascara = dados.r * mix(1.0, mistura_veia, step(0.999, dados.r));

	// ---- o pulso. Batida curta e seca, com uma segunda batida menor logo
	// atras: coracao, nao seno. E o detalhe que faz a coisa parecer viva.
	float fase = TIME * bpm;
	float batida = pow(max(0.0, sin(fase * 6.2831)), 12.0)
		+ 0.45 * pow(max(0.0, sin((fase - 0.13) * 6.2831)), 14.0);
	float pulsa = 1.0 + batida * forca_pulso;

	// ---- a rede, empurrada pelo pulso: ela ENGROSSA na batida
	float n = rede_de_veias(pos_local * escala_rede + vec3(0.0, TIME * 0.05, 0.0));
	float corte_vivo = corte - batida * 0.045 * forca_pulso;
	float linha = smoothstep(corte_vivo, corte_vivo + 0.055, n) * mascara;
	linha = max(linha, flare * mascara);
	linha *= 1.0 - morto;

	// ---- carne: escura no fundo das pregas, clara na quina esticada
	float quina = dados.g;
	vec3 base = mix(fundo.rgb, carne.rgb, 0.35 + 0.65 * quina);
	// carne morta perde a cor e vira couro
	base = mix(base, vec3(dot(base, vec3(0.33)) * 0.7), morto);

	ALBEDO = mix(base, veia.rgb * 0.5, linha * 0.7);
	EMISSION = veia.rgb * linha * (1.6 + 2.4 * batida * forca_pulso) * pulsa;

	// ---- umidade: carne molhada tem brilho apertado e escorrega na borda.
	// A quina fica mais SECA que a prega (o contrario da pedra), porque o que
	// brilha numa coisa umida e o fundo da dobra, onde o liquido junta.
	float seca = mix(0.0, 0.55, quina);
	ROUGHNESS = clamp(mix(0.85, 0.16, umidade) + seca * 0.3 + morto * 0.5, 0.05, 1.0);
	SPECULAR = mix(0.25, 0.75, umidade) * (1.0 - morto);
	METALLIC = 0.0;
}
