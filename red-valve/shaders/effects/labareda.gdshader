shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Uma CORTINA de labaredas (quad aditivo): línguas de fogo subindo do pé do
// quad e apagando pro alto. Várias em fila, uma atrás da outra, fazem o vão da
// porta red valve ter fundura — e quem anda por dentro delas sai do fogo.

uniform sampler2D ruido : repeat_enable, filter_linear;
uniform float velocidade = 1.2;
uniform vec2 escala = vec2(1.6, 1.0);
// Até onde (0..1 da altura do quad) a chama chega.
uniform float altura = 0.85;
uniform float intensidade = 1.0;
uniform float semente = 0.0;

vec3 rampa(float t) {
	vec3 c = mix(vec3(0.0), vec3(0.6, 0.04, 0.0), smoothstep(0.0, 0.25, t));
	c = mix(c, vec3(1.0, 0.32, 0.03), smoothstep(0.25, 0.55, t));
	c = mix(c, vec3(1.0, 0.75, 0.25), smoothstep(0.55, 0.8, t));
	return mix(c, vec3(1.0, 0.95, 0.8), smoothstep(0.8, 1.0, t));
}

void fragment() {
	float y = 1.0 - UV.y;
	float t = TIME * velocidade;
	vec2 p = vec2(UV.x * escala.x + semente, y * escala.y);
	// as línguas ondulam enquanto sobem
	float w = texture(ruido, p * 0.7 + vec2(semente, -t * 0.6)).r;
	float n = texture(ruido, p + vec2((w - 0.5) * 0.35, -t)).r * 0.7
		+ texture(ruido, p * 2.1 + vec2(0.3, -t * 1.7)).r * 0.3;
	float base = 1.0 - y / altura;
	float borda = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float f = smoothstep(0.05, 0.9, clamp(n * 1.25 + base * 0.9 - 0.55, 0.0, 1.0) * borda);
	ALBEDO = rampa(f) * intensidade;
	ALPHA = clamp(f * 2.0, 0.0, 1.0);
}
