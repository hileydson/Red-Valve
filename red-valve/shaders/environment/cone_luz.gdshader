// O cone de luz debaixo da luminaria, desenhado como geometria (o renderer
// mobile nao tem nevoa volumetrica).
//
// So' a casca de TRAS do cone e' desenhada (cull_front). Olhando um cone de
// fora, o meio da silhueta e' onde o olhar atravessa mais "ar iluminado", e e'
// tambem onde a normal da casca de tras encara a camera; na borda da silhueta
// a casca e' vista de raspao. Por isso o brilho segue |N . V|: cheio no meio,
// some na borda. Com material chapado (o StandardMaterial de antes) o cone
// era um triangulo de borda dura — e a curva de sombra da lente da escola o
// transformava numa cunha cinza solida.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded, shadows_disabled, fog_disabled;

uniform vec3 cor : source_color = vec3(0.74, 0.86, 0.78);
uniform float forca : hint_range(0.0, 0.2) = 0.02;
uniform float altura = 3.0;
uniform sampler2D profundidade : hint_depth_texture, filter_nearest;

varying float y_local;

void vertex() {
	y_local = VERTEX.y;
}

void fragment() {
	float t = clamp(0.5 - y_local / altura, 0.0, 1.0);   // 0 no teto, 1 no chao
	float miolo = pow(abs(dot(NORMAL, VIEW)), 2.2);
	float queda = mix(1.0, 0.25, t) * smoothstep(0.0, 0.12, t);

	float z_cena = texture(profundidade, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z_cena, 1.0);
	float encosto = clamp((-v.z / v.w + VERTEX.z) / 0.8, 0.0, 1.0);
	float perto = smoothstep(0.5, 2.5, -VERTEX.z);
	float longe = 1.0 - smoothstep(14.0, 22.0, -VERTEX.z);

	ALBEDO = cor * forca * miolo * queda * encosto * perto * longe;
}
