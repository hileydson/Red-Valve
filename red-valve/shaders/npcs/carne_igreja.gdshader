// A pele dos personagens da cena da igreja (Dona Nice, a monstro, o Jonny).
//
// Faz o que o StandardMaterial3D do .glb faz (cor, normal, rugosidade/metal)
// e mais tres coisas que a cena pede e que material padrao nao da':
//
//   dissolver  0..1 — a carne some em manchas de ruido 3D com uma borda em
//              brasa. E' assim que a Dona Nice vira monstro: as duas tocam o
//              MESMO clipe, uma dissolve e a outra aparece por baixo.
//   sangue     0..1 — sangue procedural por cima da textura, mais denso na
//              FRENTE e nas MAOS (quem segurou a faca), escuro e brilhante.
//   veias      0..1 — veias escuras pulsando sob a pele (a possessao).
//
// O ruido e' amostrado na posicao do vertice no espaco do MODELO (ja' com a
// pose aplicada): a mancha anda com o corpo e nao escorrega quando ele mexe.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_cor : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool tem_normal = false;
uniform sampler2D normal_tex : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_forca = 1.0;
uniform bool tem_orm = false;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.85;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;

uniform float dissolver : hint_range(0.0, 1.0) = 0.0;
uniform float escala_ruido = 5.0;
uniform float borda = 0.07;
uniform vec4 cor_borda : source_color = vec4(1.0, 0.28, 0.06, 1.0);
uniform float brilho_borda = 7.0;

uniform float sangue : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cor_sangue : source_color = vec4(0.23, 0.0, 0.01, 1.0);
// de onde o sangue vem: a frente do corpo (-Z no Godot e' as costas destes
// modelos; a frente deles e' o +Z) e a altura das maos
uniform vec3 frente = vec3(0.0, 0.0, 1.0);

uniform float veias : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cor_veias : source_color = vec4(0.25, 0.02, 0.05, 1.0);

varying vec3 p_obj;
varying vec3 n_obj;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo_cor;

	// --- dissolver
	float n = fbm(p_obj * escala_ruido);
	float limite = dissolver * 1.12 - 0.06;
	if (dissolver > 0.0 && n < limite) {
		discard;
	}
	float brasa = dissolver > 0.0 ? 1.0 - smoothstep(limite, limite + borda, n) : 0.0;

	vec3 cor = a.rgb;
	float rug = rugosidade;
	float met = metalico;
	if (tem_orm) {
		vec4 orm = texture(orm_tex, UV);
		rug *= orm.g;
		met *= orm.b;
	}

	// --- sangue: manchas grandes + respingos, puxados pra frente do corpo
	if (sangue > 0.0) {
		float lado = clamp(dot(normalize(n_obj), frente) * 0.6 + 0.55, 0.0, 1.0);
		float manchas = fbm(p_obj * 6.5 + vec3(4.0));
		float respingo = ruido(p_obj * 38.0);
		float m = smoothstep(0.68 - 0.22 * sangue * lado, 0.74 - 0.22 * sangue * lado, manchas);
		m = max(m, step(0.965 - 0.07 * sangue * lado, respingo) * sangue);
		cor = mix(cor, cor_sangue.rgb * (0.7 + 0.5 * ruido(p_obj * 60.0)), m * 0.9);
		rug = mix(rug, 0.22, m * 0.8);      // sangue fresco brilha
	}

	// --- veias
	float v = 0.0;
	if (veias > 0.0) {
		float r = abs(fbm(p_obj * 9.0) - 0.5);
		v = (1.0 - smoothstep(0.0, 0.035, r)) * veias;
		cor = mix(cor, cor_veias.rgb, v * 0.85);
	}

	ALBEDO = cor;
	ROUGHNESS = rug;
	METALLIC = met;
	if (tem_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_forca;
	}
	float pulso = 0.5 + 0.5 * sin(TIME * 5.0);
	EMISSION = cor_borda.rgb * brilho_borda * brasa + cor_veias.rgb * v * pulso * 0.6;
}
