shader_type canvas_item;

// Em shader 2D, não precisamos de render_mode spatial
// A textura da tela é acessada via 'SCREEN_TEXTURE' automaticamente em canvas_item

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms Retro_Settings;
uniform float pixel_size : hint_range(0.001, 0.05) = 0.01;
uniform int color_depth : hint_range(1, 256) = 16;
uniform float jitter_intensity : hint_range(0.0, 0.005) = 0.001;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.1;
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
    vec2 screen_uv = SCREEN_UV;
    
    // 1. Redução de Resolução
    vec2 pixelated_uv = floor(screen_uv / pixel_size) * pixel_size;
    
    // 2. Efeito Jitter
    vec2 jitter_offset = vec2(
        fract(sin(dot(pixelated_uv, vec2(12.9898, 78.233))) * 43758.5453 + TIME * 10.0),
        fract(cos(dot(pixelated_uv, vec2(53.123, 23.456))) * 51234.7890 + TIME * 10.0)
    ) * jitter_intensity;
    
    screen_uv = pixelated_uv + jitter_offset;

    // 3. Amostragem da textura
    vec4 color = texture(SCREEN_TEXTURE, screen_uv);
    
    // 4. Quantização
    color.rgb = floor(color.rgb * float(color_depth)) / float(color_depth);
    
    // 5. Vinheta
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(screen_uv, center);
    float vignette = smoothstep(0.4, 0.8, dist);
    color.rgb = mix(color.rgb, color.rgb * (1.0 - vignette * vignette_strength), 0.3);
    
    // 6. Scanlines
    float scanline = sin(screen_uv.y * 800.0) * 0.5 + 0.5;
    color.rgb = mix(color.rgb, color.rgb * (1.0 - scanline * scanline_intensity), 0.1);
    
    // 7. Saída Final
    color.rgb *= tint_color;
    color.rgb *= 1.1;
    
    COLOR = vec4(color.rgb, 1.0);
}