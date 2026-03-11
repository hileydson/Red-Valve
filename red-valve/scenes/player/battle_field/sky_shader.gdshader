shader_type sky;

uniform vec4 deep_space_color : source_color = vec4(0.0, 0.005, 0.01, 1.0); // Quase preto, levemente azulado
uniform vec4 rift_color : source_color = vec4(0.3, 0.0, 0.1, 1.0);       // Vermelho escuro/magenta doentio
uniform float fracture_scale : hint_range(1.0, 20.0) = 8.0;              // Tamanho das divisões geométricas
uniform float speed : hint_range(0.0, 2.0) = 0.3;                         // Velocidade do "deslizamento" das placas

void sky() {
    // Usamos a direção do olho, focando mais na parte superior (Y positivo)
    vec3 dir = normalize(EYEDIR);
    
    // Projeção UV baseada na direção para cobrir o domo celeste
    vec2 uv = dir.xz / (max(0.0, dir.y) + 1.0) * fracture_scale;
    
    float t = TIME * speed;
    float geometric_fracture = 0.0;
    
    // --- Loop Fractal Geométrico ---
    // Criamos iterações que quebram o espaço em padrões retangulares/angulares
    for (float i = 1.0; i < 4.0; i++) {
        // Multiplicamos as UVs para criar sub-divisões menores a cada iteração
        uv *= 1.8 + i * 0.1;
        
        // Deslocamos as sub-divisões com o tempo para criar o movimento de "placas tectônicas"
        vec2 motion = vec2(t * (1.0 + i * 0.2), t * (0.5 - i * 0.1));
        
        // A mágica acontece aqui: usamos 'fract' e 'min' para criar linhas retas e quinas
        // O padrão imita a quebra de cristais ou fendas em concreto, mas em escala colossal
        vec2 g = fract(uv + motion) - 0.5;
        geometric_fracture += min(abs(g.x), abs(g.y)) * pow(0.6, i);
    }
    
    // Invertemos e intensificamos para que as "fendas" fiquem brilhantes contra o fundo escuro
    geometric_fracture = pow(1.0 - geometric_fracture, 15.0);
    
    // --- Máscara de Horizonte ---
    // Garante que o efeito seja forte no topo do céu e suave perto do horizonte
    float horizon_mask = smoothstep(0.0, 0.4, dir.y);
    
    // --- Composição Final ---
    // Misturamos a cor do espaço profundo com a cor das fendas geométricas
    vec3 final_color = mix(deep_space_color.rgb, rift_color.rgb, geometric_fracture * horizon_mask);
    
    // Adicionamos um Glow (Brilho) sutil nas fendas mais intensas
    final_color += smoothstep(0.0, 1.0, geometric_fracture) * rift_color.rgb * 0.2;
    
    COLOR = final_color;
}