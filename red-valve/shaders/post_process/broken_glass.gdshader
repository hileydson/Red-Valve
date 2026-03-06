shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float crack_scale = 10.0;

// Função de Voronoi simplificada para criar as "lascas"
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

void fragment() {
    vec2 uv = UV * crack_scale;
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);

    float min_dist = 1.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash(i_uv + neighbor);
            float dist = length(neighbor + point - f_uv);
            min_dist = min(min_dist, dist);
        }
    }

    // A lógica da trinca: quanto maior o min_dist, mais fina é a linha da trinca
    float crack = smoothstep(0.02, 0.05, min_dist * crack_intensity);
    
    // Distorção nas bordas das trincas
    vec2 distortion = vec2(min_dist) * (1.0 - crack) * 0.1;
    
    // Pega a textura da tela com distorção nas bordas das trincas
    vec3 color = texture(SCREEN_TEXTURE, SCREEN_UV + distortion).rgb;
    
    // Adiciona um reflexo branco nas bordas da trinca
    color = mix(color, vec3(1.0), (1.0 - crack) * crack_intensity);
    
    ALBEDO = color;
}