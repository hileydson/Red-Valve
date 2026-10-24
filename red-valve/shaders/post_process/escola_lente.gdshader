// A lente da escola e do porao: o que a camera "e'" naqueles lugares.
//
// Aplicado num ColorRect de tela cheia, dentro de um CanvasLayer de layer -1
// na propria cena (ver `gerar_cena_escola.py`): assim ele pega so' o 3D, por
// baixo do HUD, e o filtro PS1 do jogador (layer 1) continua por cima dele.
//
// O renderer do projeto e' o mobile, sem SSAO, sem nevoa volumetrica e sem
// DOF de qualidade: boa parte do "clima de camera" tem de nascer aqui.
//
//   1. distorcao de barril leve — lente grande-angular barata
//   2. aberracao cromatica que cresce pra borda
//   3. grade de cor: sombra verde-azulada, luz amarelada de fluorescente velha
//   4. grao de filme, mais forte no escuro (e' onde o sensor sofre)
//   5. vinheta oval, que escurece e esfria o canto
//   6. respiracao de exposicao: um tremor lento, quase subliminar
//   7. linha de interferencia ocasional (o "soluco" da camera)
shader_type canvas_item;
render_mode unshaded;

// filter_linear, SEM mipmap: com `filter_linear_mipmap` o Godot gera a
// cadeia de mipmaps da copia da tela a cada quadro, e so' o nivel 0 e' lido
// aqui. Medido no harness: 10 quadros por segundo a menos na iGPU.
uniform sampler2D tela : hint_screen_texture, filter_linear;

group_uniforms lente;
uniform float barril : hint_range(-0.2, 0.3) = 0.045;
uniform float aberracao : hint_range(0.0, 6.0) = 1.4;

group_uniforms cor;
uniform float exposicao : hint_range(0.2, 3.0) = 1.0;
uniform float contraste : hint_range(0.5, 2.0) = 1.08;
// Curva de sombra. O filtro PS1 do jogador (layer 1, por cima desta lente)
// quantiza a tela em 32 degraus: tudo abaixo de ~8/255 vira preto puro. Numa
// escola a noite isso era a maior parte da imagem. O gama < 1 levanta o
// escuro MUITO mais que o claro e tira a forma das coisas do primeiro degrau,
// sem lavar a luz das lampadas.
uniform float gama : hint_range(0.3, 1.5) = 0.72;
uniform float saturacao : hint_range(0.0, 1.5) = 0.78;
uniform vec3 tom_sombra : source_color = vec3(0.10, 0.20, 0.20);
uniform vec3 tom_luz : source_color = vec3(1.0, 0.95, 0.80);
uniform float forca_tom : hint_range(0.0, 1.0) = 0.42;
// O preto nunca e' preto puro: levanta um fio, frio. E' o que deixa a forma
// das coisas no escuro sem precisar de luz nenhuma.
uniform vec3 piso_preto : source_color = vec3(0.010, 0.016, 0.018);

group_uniforms filme;
uniform float grao : hint_range(0.0, 0.3) = 0.065;
uniform float grao_sombra : hint_range(0.0, 3.0) = 1.6;
uniform float vinheta : hint_range(0.0, 2.0) = 0.85;
uniform float vinheta_raio : hint_range(0.2, 1.5) = 0.62;
uniform float respiracao : hint_range(0.0, 0.2) = 0.035;
uniform float interferencia : hint_range(0.0, 1.0) = 0.35;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec3 amostra(vec2 uv) {
	return textureLod(tela, clamp(uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float aspecto = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 ca = vec2(c.x * aspecto, c.y);
	float r2 = dot(ca, ca);

	// 1. barril. Corrige o zoom pra borda nao sair da imagem.
	float k = barril;
	vec2 uv_b = 0.5 + c * (1.0 + k * r2) / (1.0 + k * 0.35);

	// 7. interferencia: de tempos em tempos uma faixa horizontal desliza uns
	// pixels. Rara (sorteada por segundo) e curta, senao vira efeito de VHS.
	float seg = floor(TIME * 1.7);
	float dispara = step(1.0 - interferencia * 0.18, hash11(seg));
	float faixa_y = hash11(seg + 7.0);
	float na_faixa = smoothstep(0.035, 0.0, abs(uv.y - faixa_y)) * dispara;
	uv_b.x += na_faixa * (hash11(seg + 3.0) - 0.5) * 0.02;

	// 2. aberracao cromatica radial
	vec2 dir = c * aberracao * 0.0045 * (0.15 + r2 * 2.6);
	vec3 col;
	col.r = amostra(uv_b + dir).r;
	col.g = amostra(uv_b).g;
	col.b = amostra(uv_b - dir).b;

	// 6. respiracao: duas senoides lentas fora de fase, sem periodo obvio
	float resp = 1.0 + respiracao * (sin(TIME * 0.61) * 0.6 + sin(TIME * 1.37 + 1.3) * 0.4);
	col *= exposicao * resp;
	col = pow(max(col, vec3(0.0)), vec3(gama));

	// 3. grade. Contraste em torno de um cinza medio baixo (a cena e' escura,
	// o meio dela nao e' 0.5), split-tone e saturacao.
	col = max(col, vec3(0.0));
	col = (col - 0.18) * contraste + 0.18;
	col = max(col, vec3(0.0));
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	vec3 tom = mix(tom_sombra * 2.0, tom_luz, smoothstep(0.02, 0.6, luma));
	col = mix(col, col * tom, forca_tom);
	luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(luma), col, saturacao);

	// 5. vinheta oval, que tambem esfria
	float v = smoothstep(vinheta_raio + 0.55, vinheta_raio * 0.35, length(ca * vec2(0.92, 1.08)) * 1.25);
	col *= mix(1.0, v, clamp(vinheta, 0.0, 1.0));
	col = mix(col, col * vec3(0.86, 0.95, 1.04), (1.0 - v) * 0.5);

	col += piso_preto;

	// 4. grao: muda a cada quadro, mais forte onde a imagem e' escura. O
	// deslocamento por quadro e' DIFERENTE em x e y: somando o mesmo numero nos
	// dois, os pixels de uma mesma diagonal sorteavam igual e a tela ganhava
	// listras finas.
	float quadro = floor(TIME * 24.0);
	float g = hash12(floor(FRAGCOORD.xy) + vec2(quadro * 17.31, quadro * 9.73)) - 0.5;
	float peso = mix(1.0, grao_sombra, 1.0 - smoothstep(0.0, 0.35, luma));
	col += g * grao * peso;
	col += na_faixa * 0.03;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
