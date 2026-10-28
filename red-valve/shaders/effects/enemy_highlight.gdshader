shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled, depth_draw_never, cull_back;

// Realce aplicado como material_overlay nos inimigos enquanto o jogador está
// escolhendo alvos com o amuleto. Não substitui o material original: só soma
// um brilho de borda (fresnel) por cima, pra silhueta aparecer em ambiente
// escuro sem descaracterizar o inimigo.

uniform vec3 rim_color : source_color = vec3(0.45, 0.75, 1.0);
uniform float rim_power : hint_range(0.5, 6.0) = 2.2;
uniform float rim_intensity : hint_range(0.0, 3.0) = 1.1;
uniform float fill_intensity : hint_range(0.0, 1.0) = 0.12; // Brilho fraco no corpo todo
uniform float pulse_speed : hint_range(0.0, 6.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	ALBEDO = rim_color;
	ALPHA = clamp((fresnel * rim_intensity + fill_intensity) * pulse, 0.0, 1.0);
}
