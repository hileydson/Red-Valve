shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable; // Use um NoiseTexture2D com FastNoiseLite

uniform float distortion_strength : hint_range(0.0, 0.05) = 0.01;
uniform float speed : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	
	// Dentro do fragment do seu shader de sonho
	if (distortion_strength < 0.001) {
	    ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV).rgb; // Desenha a imagem pura se a força for quase zero
	} else {
	    // 1. Criamos dois pontos de ruído que se movem em direções opostas
	    // Isso cria um efeito "líquido" mais orgânico do que um ruído simples
	    vec2 uv_move = SCREEN_UV + (TIME * speed);
	    float noise1 = texture(noise_texture, uv_move * 0.5).r;
	    float noise2 = texture(noise_texture, -uv_move * 0.3).r;
	    
	    // 2. Combinamos os ruídos e calculamos o deslocamento (offset)
	    vec2 offset = vec2(noise1, noise2) * distortion_strength;
	    
	    // 3. Aplicamos o offset nas coordenadas da tela
	    vec3 color = texture(SCREEN_TEXTURE, SCREEN_UV + offset).rgb;
	    
	    // 4. Tint de sonho (um tom levemente azulado ou violeta)
	    color *= vec3(0.95, 0.98, 1.0);
	    
	    ALBEDO = color;
	}
    
}