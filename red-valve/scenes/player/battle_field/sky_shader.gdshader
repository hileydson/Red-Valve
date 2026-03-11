shader_type sky;

uniform vec4 base_color : source_color = vec4(0.01, 0.01, 0.02, 1.0);
uniform vec4 pulse_color : source_color = vec4(0.5, 0.0, 0.8, 1.0);
uniform float rotation_speed : hint_range(0.0, 2.0) = 0.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;

void sky() {
    // 1. Converter direção para coordenadas polares (Ângulo e Distância)
    vec3 dir = normalize(EYEDIR);
    float angle = atan(dir.z, dir.x);
    float dist = length(dir.xz);
    
    // 2. Criar um padrão de espiral distorcida pelo tempo
    float time_val = TIME * rotation_speed;
    float spiral = sin(angle * 3.0 + dist * 10.0 + time_val);
    
    // 3. Efeito de "respiração" (pulso)
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    
    // 4. Misturar base e a cor do pulso usando o padrão espiral
    float mask = smoothstep(0.2, 0.8, spiral * pulse);
    vec3 final_color = mix(base_color.rgb, pulse_color.rgb, mask * dir.y);
    
    // 5. Adicionar pequenas "faíscas" de estrelas fixas
    float stars = pow(fract(sin(dot(dir, vec3(12.9898, 78.233, 45.164))) * 43758.5453), 100.0);
    final_color += stars * vec3(1.0, 1.0, 0.9);
    
    COLOR = final_color;
}