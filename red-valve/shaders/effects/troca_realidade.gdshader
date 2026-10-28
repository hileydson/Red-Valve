shader_type canvas_item;

// A TELA na troca de realidade do amuleto (R3 / H): um anel de choque sai do
// meio da tela entortando a imagem, com aberração cromática na frente dele, e
// o que o anel já varreu ganha a cor da realidade nova por um instante — roxo
// apagado indo pras sombras, dourado quente voltando pra gente.

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
// 0..1: onde o anel está (do centro até além dos cantos).
uniform float progresso = 0.0;
// 0..1: quanto o efeito todo pesa (sobe rápido, desce devagar).
uniform float forca = 0.0;
// 1 = indo pra realidade de gente (amuleto fora); 0 = indo pras sombras.
uniform float para_normal = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 aspecto = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 d = (uv - 0.5) * aspecto;
	float dist = length(d);
	vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);
	float raio = progresso * 1.25;
	float anel = exp(-pow((dist - raio) / 0.07, 2.0)) * forca;
	vec2 empurra = dir / aspecto * anel * 0.035;
	float ab = anel * 0.012 + forca * 0.002;
	vec3 cor;
	cor.r = texture(tela, uv - empurra + dir / aspecto * ab).r;
	cor.g = texture(tela, uv - empurra).g;
	cor.b = texture(tela, uv - empurra - dir / aspecto * ab).b;
	// o que o anel já passou
	float varrido = smoothstep(raio + 0.05, raio - 0.1, dist) * forca;
	float cinza = dot(cor, vec3(0.299, 0.587, 0.114));
	vec3 sombras = mix(vec3(cinza), cor, 0.35) * vec3(0.72, 0.6, 0.95);
	vec3 gente = cor * vec3(1.12, 1.04, 0.9) + vec3(0.04, 0.03, 0.0);
	vec3 alvo = mix(sombras, gente, para_normal);
	cor = mix(cor, alvo, varrido * 0.55);
	// a borda do anel brilha na cor da realidade nova
	vec3 brilho = mix(vec3(0.55, 0.2, 0.9), vec3(1.0, 0.8, 0.45), para_normal);
	cor += brilho * anel * 0.35;
	// clarão no começo
	cor += brilho * pow(max(1.0 - progresso * 3.0, 0.0), 2.0) * forca * 0.45;
	COLOR = vec4(cor, 1.0);
}
