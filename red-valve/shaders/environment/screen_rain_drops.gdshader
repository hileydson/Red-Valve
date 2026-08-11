shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D noise_tex : repeat_enable;
uniform float distortion_strength : hint_range(0.0, 0.2) = 0.03;
uniform vec2 scroll_speed = vec2(0.1, 1.2);
uniform vec4 rain_tint : source_color = vec4(0.8, 0.85, 0.9, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // UV scrolling para o noise (água escorrendo para baixo -> Y positivo ou negativo dependendo da Engine)
    vec2 noise_uv = uv + TIME * scroll_speed;
    
    // Ler o noise
    vec4 noise_val = texture(noise_tex, noise_uv);
    
    // Centralizar o offset do noise (-0.5 a 0.5)
    vec2 offset = (noise_val.rg - 0.5) * distortion_strength;
    
    // Aplicar a distorção na textura da tela original
    vec4 screen_color = texture(screen_texture, uv + offset);
    
    // Mistura com uma coloração fria de tempestade
    COLOR = mix(screen_color, rain_tint, tint_strength);
}
