shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

group_uniforms Colors;
uniform sampler2D noise_texture;
uniform sampler2D color_gradient;

// --- NOVOS UNIFORMS PARA O EFEITO DE FOGO ---
group_uniforms Fire_Effect;
uniform vec3 fire_color : source_color = vec3(1.0, 0.1, 0.0); // Vermelho fogo
uniform float fire_intensity : hint_range(0.0, 10.0) = 3.0;   // Intensidade do brilho
uniform float flicker_speed : hint_range(0.0, 10.0) = 2.0;    // Velocidade da oscilação
// --------------------------------------------

varying flat int id;
varying vec3 world_pos;

// Remova a linha abaixo se o arquivo dither não existir no seu projeto
#include "util/dither.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Pega o valor do ruído baseado na posição do mundo
	float noise_value = texture(noise_texture, world_pos.xz * 0.1).r;
	
	// Pega a cor base do seu gradiente
	vec4 color = texture(color_gradient, vec2(noise_value, 0.0));

	// Cria uma oscilação (flicker) para simular o movimento do fogo
	float flicker = sin(TIME * flicker_speed + (world_pos.x + world_pos.z)) * 0.5 + 0.5;
	
	// Mistura a cor do gradiente com o tom de fogo e a intensidade
	vec3 fire_glow = color.rgb * fire_color * (fire_intensity + flicker);

	// ALBEDO: Define a cor "corpo" do objeto
	ALBEDO = color.rgb * fire_color * 0.2; 
	
	// EMISSION: Faz o objeto brilhar (Glow)
	EMISSION = fire_glow;
}

void light(){
	// Faz com que a luz externa afete menos o objeto para ele não "apagar" em sombras
	float ndotl = dot(LIGHT, NORMAL) * ATTENUATION;
	DIFFUSE_LIGHT += ndotl * 0.3;
}
