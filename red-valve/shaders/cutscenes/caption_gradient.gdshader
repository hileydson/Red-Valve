// Faixa de legenda: degrade do transparente para o preto, sem a barra chapada.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 bottom_color : source_color = vec4(0.0, 0.0, 0.0, 0.92);
uniform float curve : hint_range(0.2, 4.0) = 1.6;

void fragment() {
	// COLOR ja chega como cor_do_rect * modulate; guarda o alpha para o fade.
	float m = COLOR.a;
	float t = pow(clamp(UV.y, 0.0, 1.0), curve);
	COLOR = mix(top_color, bottom_color, t);
	COLOR.a *= m;
}
