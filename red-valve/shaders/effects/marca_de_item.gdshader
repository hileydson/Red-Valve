shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A marca debaixo de todo item de cenario (`marca_de_item.gd`): um circulo com
// um ponto no meio, deitado no apoio do item. Brilha sem luz e sem nevoa pra
// ser vista do outro lado da sala, e pulsa devagar.

uniform vec4 cor : source_color = vec4(1.0, 0.78, 0.32, 1.0);
uniform float forca = 1.0;

void vertex() {
	// Deitada no tampo da mesa ela brigaria com ele pela profundidade (e de
	// longe, de raspao, sumiria): empurra 3 cm na direcao da camera.
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.z += 0.03;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float anel = smoothstep(0.74, 0.84, r) * smoothstep(1.0, 0.9, r);
	float ponto = smoothstep(0.3, 0.16, r);
	float halo = (1.0 - smoothstep(0.0, 1.0, r)) * 0.16;
	float pulso = 0.78 + 0.22 * sin(TIME * 2.6);
	float a = (anel + ponto * 0.9 + halo) * pulso * forca;
	ALBEDO = cor.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
