shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

uniform bool billboard = false;

uniform sampler2D shape_texture;
uniform sampler2D shape_atlas;
uniform bool use_atlas = false;

group_uniforms Colors;
uniform sampler2D noise_texture;
uniform sampler2D color_gradient;
uniform float random_variation : hint_range(0.0, 1.0, 0.001) = 0.002;

// --- NOVOS UNIFORMS PARA O EFEITO DE FOGO ---
group_uniforms Fire_Settings;
uniform vec3 fire_tint : source_color = vec3(1.0, 0.2, 0.0); // Vermelho alaranjado
uniform float fire_intensity : hint_range(0.0, 5.0) = 2.0;   // Força do brilho
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;     // Velocidade da cintilação
// --------------------------------------------

group_uniforms Wind;
uniform sampler2D wind_texture;
uniform vec2 wind_velocity;

group_uniforms Transparency;
uniform float alpha_cut_start : hint_range(0.0, 1.0, 0.05) = 0.1;
uniform float alpha_cut_end : hint_range(0.0, 1.0, 0.05) = 0.9;
uniform int alpha_mode : hint_enum("Smooth", "Dithered", "Cut") = 0;

varying flat int id;
varying vec3 world_pos;

// Nota: Certifique-se que o arquivo .gdshaderinc existe no seu projeto ou remova esta linha se der erro
// #include "util/dither.gdshaderinc" 

// Função auxiliar caso o dither inc não esteja disponível
float dither_simple(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 atlas_uv(vec2 uv, int index, int size){
	int tile_count = size * size;
	int i = index % tile_count;
	float x = float(i % size);
	float y = float(i / size);
	vec2 tile_size = 1.0 / vec2(float(size));
	return uv* tile_size + (vec2(x, y) * tile_size);
}

float randomf(int index, int seed){
	float value = sin(float(index + seed)) * 0.5 + 0.5;
	return value;
}

float wind_noise(){
	float value = texture(wind_texture, (world_pos.xz*0.03) - (vec2(TIME * 0.01) * wind_velocity)).r;
	return value;
}

vec3 wind(vec2 uv){
	float w_noise = wind_noise();
	float wind_affect = pow(1.0 - uv.y, 2.0);
	vec3 value = vec3(
		w_noise * (wind_velocity.x),
		0.0,
		w_noise * (wind_velocity.y)) * 0.25;
	value *= wind_affect;
	return value;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	id = INSTANCE_ID;

	if(billboard){
		mat4 billboard_matrix = mat4(
				MAIN_CAM_INV_VIEW_MATRIX[0],
				MAIN_CAM_INV_VIEW_MATRIX[1],
				MAIN_CAM_INV_VIEW_MATRIX[2],
				MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * billboard_matrix;

		VERTEX += (VIEW_MATRIX * vec4(wind(UV), 0.0)).xyz;
	} else {
		VERTEX += wind(UV);
	}
	NORMAL = vec3(0.0,1.0,0.0);
}

void fragment() {
	float shape_value = texture(shape_texture, UV).r;
	if(use_atlas){
		vec2 at_uv = atlas_uv(UV, id, 2);
		shape_value = texture(shape_atlas, at_uv).r;
	}

	float noise_value = texture(noise_texture, world_pos.xz * 0.1).r;
	if(randomf(id,1) < random_variation) noise_value += 0.4;
	
	// Aplicando a cor base do gradiente
	vec4 color = texture(color_gradient, vec2(noise_value, 0.0));
	
	// EFEITO DE FOGO: Multiplicamos a cor pelo tom de fogo e adicionamos uma variação no tempo
	float pulse = (sin(TIME * pulse_speed + float(id)) * 0.5 + 0.5);
	vec3 fire_final = color.rgb * fire_tint * (fire_intensity + pulse);

	ALBEDO = fire_final * 0.5; // Albedo base levemente escuro para o brilho destacar
	EMISSION = fire_final;      // O brilho (Glow) vem daqui

	float alpha = shape_value;
	if(alpha_mode == 0){
		ALPHA = alpha;
	} else {
		alpha = clamp((shape_value - alpha_cut_start) / (alpha_cut_end - alpha_cut_start), 0.0, 1.0);
		if(alpha_mode == 1){
			// Substituí por um dither simples caso você não tenha o include
			alpha = step(dither_simple(FRAGCOORD.xy) + 0.01, alpha);
		}
		if(alpha < 0.1) discard;
	}
}

void light(){
	// Como é fogo (emissivo), ele ignora um pouco as luzes externas para não ficar preto na sombra
	float ndotl = dot(LIGHT, NORMAL) * ATTENUATION;
	DIFFUSE_LIGHT += ndotl * 0.5;
}