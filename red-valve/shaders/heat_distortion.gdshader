shader_type canvas_item;

// A textura da tela renderizada no Godot 4
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Controle do efeito de calor e cor
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.0015;
uniform float speed = 2.5;
uniform vec4 tint_color : source_color = vec4(1.0, 0.4, 0.1, 0.08);

void fragment() {
    // Pegar o UV atual da tela
    vec2 uv = SCREEN_UV;
    
    // Criar um movimento ondulado fake usando senos e cossenos combinados com tempo
    float time = TIME * speed;
    float wave_x = sin(uv.y * 15.0 + time) * cos(uv.x * 25.0 + time * 0.8);
    float wave_y = cos(uv.x * 12.0 + time * 1.2) * sin(uv.y * 20.0 + time * 0.9);
    
    // Calcular a distorção (offset)
    vec2 offset = vec2(wave_x, wave_y) * distortion_strength;
    
    // Amostrar a tela mas deslocada pela onda de calor
    vec4 screen_color = texture(screen_texture, uv + offset);
    
    // Adicionar um leve tom de "ar quente" alaranjado/avermelhado
    screen_color.rgb = mix(screen_color.rgb, tint_color.rgb, tint_color.a);
    
    // Saída final para a tela
    COLOR = screen_color;
}
