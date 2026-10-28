shader_type spatial; // Pode ser 'canvas_item' se for um filtro 2D

// Ajustes de renderização para um filtro de tela
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms Retro_Settings;
uniform float pixel_size : hint_range(0.001, 0.05) = 0.01; // Tamanho do pixel (0.01 = 1% da tela)
uniform int color_depth : hint_range(1, 256) = 16; // Número de cores por canal (ex: 16 para PS1, 64 para PS2)
uniform float jitter_intensity : hint_range(0.0, 0.005) = 0.001; // Intensidade do "jitter" (tremedeira) do PS1
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3; // Força da vinheta (borda escura)
uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.1; // Força das scanlines (linhas horizontais)
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0); // Cor de tinta geral (para dar um tom mais antigo)

void fragment() {
    vec2 screen_uv = SCREEN_UV;
    
    // 1. Redução de Resolução (Pixelização)
    // Arredonda as coordenadas UV para criar blocos de pixels
    vec2 pixelated_uv = floor(screen_uv / pixel_size) * pixel_size;
    
    // 2. Efeito Jitter (Tremedeira de PS1/PSX)
    // Adiciona um pequeno offset randômico por pixel para simular a falta de precisão
    // Isso cria a sensação de "pixels dançando"
	// O comando correto é 'dot', tudo em minúsculo
    vec2 jitter_offset = vec2(
        fract(sin(dot(pixelated_uv, vec2(12.9898, 78.233))) * 43758.5453 + TIME * 10.0),
        fract(cos(dot(pixelated_uv, vec2(53.123, 23.456))) * 51234.7890 + TIME * 10.0)
    ) * jitter_intensity;
    
    screen_uv = pixelated_uv + jitter_offset; // Aplica o jitter na UV pixelizada

    // Pega a cor da tela original, mas nas coordenadas pixelizadas/jitter
    vec4 color = texture(SCREEN_TEXTURE, screen_uv);
    
    // 3. Quantização de Cor (Redução da Paleta)
    // Reduz o número de cores por canal (R, G, B) para simular paletas limitadas
    color.rgb = floor(color.rgb * float(color_depth)) / float(color_depth);
    
    // 4. Vinheta (Vignette)
    // Escurece as bordas da tela
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(screen_uv, center);
    float vignette = smoothstep(0.4, 0.8, dist); // Começa em 40% do centro, escurece até 80%
    color.rgb *= (1.0 - vignette * vignette_strength); // Aplica a vinheta
    
    // 5. Scanlines (Linhas Horizontais de TV Antiga)
    // Adiciona linhas escuras horizontais sutis
    float scanline = sin(screen_uv.y * 800.0) * 0.5 + 0.5; // Multiplicar por um número grande cria mais linhas
    color.rgb *= (1.0 - scanline * scanline_intensity);
    
    // 6. Tonalidade Geral
    // Aplica uma cor de tinta para um aspecto mais vintage
    color.rgb *= tint_color;
	color.rgb *= 1.1;
    
	ALBEDO = color.rgb;
    ALPHA = 1.0;
}