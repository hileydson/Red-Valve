// Céu dos cenários a céu aberto gerados por script (arena 3, cemitério, inferno).
//
// Um shader só, três céus: o que muda é o material de cada cena.
//  - nuvens em duas camadas de fbm sobre o plano do céu, empurradas pelo vento;
//  - um VÓRTICE que torce as nuvens em volta de uma direção (o olho do céu
//    em cima do trono da arena 3);
//  - lua (ou sol negro) com halo, que acende a borda das nuvens perto dela;
//  - `relampago` (0..1) é escrito pelo `cenario_aberto.gd`;
//  - `brilho_baixo` acende a barriga das nuvens por baixo (mar de lava).
//
// Cuidado com o filtro PS1 do player (32 degraus): abaixo de ~8/255 tudo vira
// preto puro, então nem o zênite pode ser zero.
shader_type sky;
render_mode use_debanding;

uniform vec3 cor_zenite : source_color = vec3(0.03, 0.015, 0.025);
uniform vec3 cor_horizonte : source_color = vec3(0.24, 0.05, 0.04);
uniform vec3 cor_chao : source_color = vec3(0.03, 0.012, 0.012);
uniform vec3 cor_nuvem : source_color = vec3(0.10, 0.035, 0.04);
uniform vec3 cor_borda_nuvem : source_color = vec3(0.55, 0.12, 0.06);
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform float escala_nuvem = 1.0;
uniform float cobertura : hint_range(0.0, 1.0) = 0.58;
uniform float maciez : hint_range(0.05, 1.0) = 0.38;
uniform vec2 vento = vec2(0.012, 0.004);

uniform vec3 lua_dir = vec3(0.0, 0.42, -0.9);
uniform vec3 lua_cor : source_color = vec3(1.0, 0.2, 0.08);
uniform float lua_tamanho = 0.075;
uniform float lua_brilho = 5.0;
uniform float lua_halo = 1.1;
// 1 = sol negro: disco escuro com coroa acesa
uniform float lua_eclipse : hint_range(0.0, 1.0) = 0.0;

uniform vec3 vortice_dir = vec3(0.0, 0.8, -0.6);
uniform float vortice_forca = 0.0;
uniform float vortice_raio = 0.55;
uniform vec3 vortice_cor : source_color = vec3(0.9, 0.16, 0.05);
uniform float vortice_brilho = 1.2;

uniform float estrelas = 0.0;
uniform float relampago = 0.0;
uniform vec3 relampago_cor : source_color = vec3(0.78, 0.72, 1.0);
uniform float brilho_baixo = 0.0;

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * texture(ruido, p).r;
		p = p * 2.03 + vec2(0.17, 0.31);
		a *= 0.5;
	}
	return v;
}

vec2 plano(vec3 d) {
	return d.xz / (max(d.y, 0.0) + 0.14);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;

	vec3 col = mix(cor_horizonte, cor_zenite, pow(clamp(h, 0.0, 1.0), 0.5));
	if (h < 0.0) {
		col = mix(cor_horizonte, cor_chao, clamp(-h * 5.0, 0.0, 1.0));
	}

	// --- vórtice: torce o plano das nuvens em volta de vortice_dir
	vec3 vd = normalize(vortice_dir);
	float vang = acos(clamp(dot(d, vd), -1.0, 1.0));
	float vmask = 1.0 - smoothstep(0.0, vortice_raio, vang);
	vec2 uv = plano(d);
	vec2 vc = plano(vd);
	vec2 rel = uv - vc;
	float giro = vortice_forca * vmask * vmask * 3.0 + TIME * 0.06 * vortice_forca * vmask;
	rel = mat2(vec2(cos(giro), sin(giro)), vec2(-sin(giro), cos(giro))) * rel;
	uv = vc + rel * (1.0 + vmask * 0.4 * vortice_forca);

	vec2 p = uv * 0.045 * escala_nuvem + vento * TIME;
	float n1 = fbm(p);
	float n2 = fbm(p * 1.9 - vento * TIME * 0.7 + vec2(3.1, 1.7));
	float densidade = n1 * 0.68 + n2 * 0.42;
	float nuvem = smoothstep(1.0 - cobertura, 1.0 - cobertura + maciez, densidade);
	float fade_horizonte = smoothstep(-0.03, 0.22, h);

	// --- lua / sol negro
	vec3 ld = normalize(lua_dir);
	float lc = dot(d, ld);
	float disco = smoothstep(cos(lua_tamanho), cos(lua_tamanho * 0.94), lc);
	float halo = pow(max(lc, 0.0), 60.0) * lua_halo + pow(max(lc, 0.0), 7.0) * 0.22 * lua_halo;
	float coroa = smoothstep(cos(lua_tamanho * 1.45), cos(lua_tamanho * 1.02), lc) * (1.0 - disco);
	// manchas da superfície
	vec2 luv = (d - ld * lc).xy / lua_tamanho;
	float manchas = texture(ruido, luv * 0.35 + 0.5).r;

	vec3 ceu = col;
	ceu += lua_cor * halo * 0.4;
	vec3 disco_cor = lua_cor * lua_brilho * mix(0.62, 1.0, manchas);
	ceu = mix(ceu, mix(disco_cor, vec3(0.012, 0.004, 0.004), lua_eclipse), disco);
	ceu += lua_cor * coroa * lua_brilho * 0.9 * lua_eclipse;

	// núcleo do vórtice acende
	ceu += vortice_cor * pow(vmask, 2.5) * vortice_brilho * (0.55 + 0.45 * n2) * step(0.001, vortice_forca);

	// estrelas raras entre as nuvens: ponto por célula de uma grade fina
	// (amostrar o ruído aqui dava BOLHAS brancas do tamanho de flocos)
	if (estrelas > 0.0 && h > 0.0) {
		vec2 g = d.xz / (d.y + 0.6) * 260.0;
		vec2 cel = floor(g);
		float sorte = fract(sin(dot(cel, vec2(127.1, 311.7))) * 43758.5453);
		float ponto = smoothstep(0.16, 0.0, length(fract(g) - 0.5));
		ceu += vec3(0.9, 0.85, 1.0) * step(0.982, sorte) * ponto * estrelas * fade_horizonte;
	}

	// --- nuvens: barriga escura, borda acesa pela lua e pelo vórtice
	float acende = clamp(halo * 1.6 + vmask * 0.8 * step(0.001, vortice_forca), 0.0, 1.0);
	vec3 nc = mix(cor_nuvem, cor_borda_nuvem, acende * (1.0 - smoothstep(0.4, 1.0, densidade)));
	nc += cor_borda_nuvem * brilho_baixo * (1.0 - clamp(h * 2.5, 0.0, 1.0)) * (0.5 + n2 * 0.5);
	nc += relampago * relampago_cor * (0.35 + n2 * 0.9);

	col = mix(ceu, nc, nuvem * fade_horizonte);
	// a lua atravessa nuvem rala
	col += lua_cor * disco * lua_brilho * 0.25 * nuvem * (1.0 - lua_eclipse);
	col += relampago * relampago_cor * 0.18 * fade_horizonte;

	COLOR = max(col, vec3(0.0));
}
