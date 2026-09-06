shader_type canvas_item;

// Cel shading estilo Borderlands, feito 100% em pós-processamento (nada de
// mexer nos materiais do jogo): contorno de tinta por detecção de bordas +
// posterização das cores + realce de saturação/contraste.
//
// Roda no renderer Mobile porque não depende de depth/normal texture: as
// bordas saem de um Sobel sobre a luminância da tela.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float amount : hint_range(0.0, 1.0) = 0.65;          // Mistura geral (0 = desligado)
uniform float outline_thickness : hint_range(0.5, 4.0) = 1.1;
uniform float outline_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float outline_softness : hint_range(0.01, 0.5) = 0.18;
uniform vec3 outline_color : source_color = vec3(0.03, 0.03, 0.04);
uniform float posterize_levels : hint_range(2.0, 24.0) = 11.0;
uniform float saturation : hint_range(0.0, 2.5) = 1.17;
uniform float contrast : hint_range(0.5, 2.0) = 1.06;
uniform float outline_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float dark_boost : hint_range(0.0, 1.0) = 0.14; // Engrossa a borda em áreas escuras

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = SCREEN_PIXEL_SIZE * outline_thickness;

	vec3 base = texture(screen_texture, uv).rgb;

	// --- Contorno: Sobel 3x3 sobre a luminância ---
	float l00 = luma(texture(screen_texture, uv + texel * vec2(-1.0, -1.0)).rgb);
	float l10 = luma(texture(screen_texture, uv + texel * vec2( 0.0, -1.0)).rgb);
	float l20 = luma(texture(screen_texture, uv + texel * vec2( 1.0, -1.0)).rgb);
	float l01 = luma(texture(screen_texture, uv + texel * vec2(-1.0,  0.0)).rgb);
	float l21 = luma(texture(screen_texture, uv + texel * vec2( 1.0,  0.0)).rgb);
	float l02 = luma(texture(screen_texture, uv + texel * vec2(-1.0,  1.0)).rgb);
	float l12 = luma(texture(screen_texture, uv + texel * vec2( 0.0,  1.0)).rgb);
	float l22 = luma(texture(screen_texture, uv + texel * vec2( 1.0,  1.0)).rgb);

	float gx = (l00 + 2.0 * l01 + l02) - (l20 + 2.0 * l21 + l22);
	float gy = (l00 + 2.0 * l10 + l20) - (l02 + 2.0 * l12 + l22);
	float grad = sqrt(gx * gx + gy * gy);

	// Diferença de croma ajuda a pegar bordas entre cores de brilho parecido
	vec3 cl = texture(screen_texture, uv + texel * vec2(-1.0, 0.0)).rgb;
	vec3 cr = texture(screen_texture, uv + texel * vec2( 1.0, 0.0)).rgb;
	vec3 cu = texture(screen_texture, uv + texel * vec2( 0.0, -1.0)).rgb;
	vec3 cd = texture(screen_texture, uv + texel * vec2( 0.0,  1.0)).rgb;
	float chroma = length(cl - cr) + length(cu - cd);
	grad = max(grad, chroma * 0.8);

	// Em regiões escuras a borda precisa de menos gradiente pra aparecer
	float thr = mix(outline_threshold, outline_threshold * 0.45, (1.0 - luma(base)) * dark_boost);
	float edge = smoothstep(thr, thr + outline_softness, grad);

	// --- Posterização (bandas de cor tipo desenho) ---
	// Feita na luminância pra manter o matiz original: só a "iluminação" vira degraus.
	float l = max(luma(base), 0.0001);
	float banded = floor(l * posterize_levels + 0.5) / posterize_levels;
	vec3 col = base * (banded / l);

	// --- Punch de cor: saturação + contraste ---
	float gray = luma(col);
	col = mix(vec3(gray), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col = clamp(col, vec3(0.0), vec3(1.0));

	// --- Tinta por cima ---
	// outline_opacity segura a força máxima da linha: mesmo numa borda forte a
	// tinta não fecha em preto sólido, fica só um traço sutil.
	col = mix(col, outline_color, edge * outline_opacity);

	COLOR = vec4(mix(base, col, amount), 1.0);
}
