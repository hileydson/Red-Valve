shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable; // Use uma textura de Noise simples aqui
uniform vec3 fog_color : source_color = vec3(0.9, 0.9, 0.9); // Cor clara e neutra
uniform float density : hint_range(0.0, 1.0) = 0.15; // Mantenha baixo (0.1 a 0.2)
uniform float speed : hint_range(0.0, 0.5) = 0.02;

void fragment() {
    // Deslocamento lento para a fumaça parecer "viva"
    vec2 uv = SCREEN_UV + (TIME * speed * vec2(0.5, 0.2));
    
    // Leitura do ruído
    float noise = texture(noise_texture, uv * 0.8).r;
    
    // Captura a cena original
    vec4 scene = texture(screen_texture, SCREEN_UV);
    
    // O SEGREDO: Mistura a fumaça com a cena usando a densidade como força
    // Isso garante que você nunca perca a visibilidade do jogo
    vec3 final_color = mix(scene.rgb, fog_color, noise * density);
    
    COLOR = vec4(final_color, scene.a);
}