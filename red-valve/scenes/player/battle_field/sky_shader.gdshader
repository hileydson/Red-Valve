shader_type sky;

uniform vec4 dark_color : source_color = vec4(0.02, 0.0, 0.05, 1.0);
uniform vec4 nebula_color : source_color = vec4(0.4, 0.0, 0.2, 1.0);
uniform float speed : hint_range(0.0, 1.0) = 0.1;
uniform float distortion : hint_range(0.0, 2.0) = 0.5;

// Função de hash simples para criar aleatoriedade
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Função de ruído para o efeito "orgânico"
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void sky() {
    // Pegamos a direção do pixel no céu
    vec2 uv = EYEDIR.xz / (EYEDIR.y + 1.0); // Projeção esférica simplificada
    
    // Distorção rotacional e temporal
    float t = TIME * speed;
    vec2 rot_uv = uv;
    rot_uv.x += sin(t + uv.y * 2.0) * distortion;
    rot_uv.y += cos(t + uv.x * 2.0) * distortion;
    
    // Criando o "vórtice" lovecraftiano
    float n = noise(rot_uv * 3.0 + t);
    n += noise(rot_uv * 6.0 - t) * 0.5;
    
    // Mix de cores para dar o tom sinistro
    vec3 final_color = mix(dark_color.rgb, nebula_color.rgb, n * EYEDIR.y * 0.5);
    
    // Escurece conforme chega na linha do horizonte
    final_color *= smoothstep(0.0, 0.2, EYEDIR.y + 0.1);
    
    COLOR = final_color;
}