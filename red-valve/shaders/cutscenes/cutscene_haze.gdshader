// Cartao de bruma que fica ENTRE as camadas. E o que mais vende a profundidade:
// a fumaca passa na frente do fundo e atras dos personagens.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.85, 0.28, 0.12, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 0.35;
uniform vec2 scroll = vec2(0.012, -0.004);
uniform float uv_scale = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// Recorta as bordas do quad para a bruma nao ter contorno reto.
uniform float edge_fade : hint_range(0.0, 0.5) = 0.28;

void fragment() {
	vec2 uv = UV * uv_scale;
	float a = texture(noise_tex, uv + TIME * scroll).r;
	float b = texture(noise_tex, uv * 1.9 - TIME * scroll * 1.7).r;
	float n = a * 0.65 + b * 0.35;
	// Bruma real tem contraste baixo. Um smoothstep agressivo aqui vira mancha
	// e cobre a arte em vez de separar os planos.
	n = smoothstep(0.25, 1.0, n);
	n *= n;

	vec2 e = smoothstep(vec2(0.0), vec2(edge_fade), UV)
	       * smoothstep(vec2(0.0), vec2(edge_fade), vec2(1.0) - UV);
	float mask = e.x * e.y;

	ALBEDO = tint.rgb * intensity * n * mask * alpha;
	ALPHA = 1.0;
}
