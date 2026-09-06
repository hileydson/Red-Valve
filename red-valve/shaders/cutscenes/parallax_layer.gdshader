// Camada de arte de uma cutscene 2.5D.
// O quad vive no espaco 3D, entao a paralaxe vem da camera; este shader cuida
// so da aparencia: profundidade atmosferica, desfoque de campo, luz de contorno
// e o pulso de luz do cenario.
//
// Os recortes de personagem costumam vir com micro-furos no canal alpha (sobra de
// remocao de fundo). Tudo aqui que depende de silhueta le o alpha de um mip mais
// alto, onde os furos ja sumiram, e o preenchimento opcional tapa os furos.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;

uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// Desfoque em niveis de mipmap: 0 = nitido, ~2 = fundo bem macio.
uniform float blur : hint_range(0.0, 6.0) = 0.0;

// Tapa buracos do recorte. 0 desliga.
uniform float pinhole_fill : hint_range(0.0, 1.0) = 1.0;
uniform float silhouette_lod : hint_range(0.0, 6.0) = 2.0;
uniform float fill_low : hint_range(0.0, 1.0) = 0.72;
uniform float fill_high : hint_range(0.0, 1.0) = 0.96;

// Perspectiva atmosferica: quanto mais longe, mais a camada se dissolve na bruma.
uniform vec4 haze_color : source_color = vec4(0.42, 0.10, 0.08, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.0;

uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;

// Luz de contorno: separa o recorte do fundo.
uniform vec4 rim_color : source_color = vec4(1.0, 0.45, 0.16, 1.0);
uniform float rim_strength : hint_range(0.0, 3.0) = 0.0;
uniform float rim_width : hint_range(0.0, 0.06) = 0.006;
// Silhueta usada pelo rim: mais baixa que a do preenchimento, para a faixa de luz
// ficar colada na borda em vez de virar um halo.
uniform float rim_lod : hint_range(0.0, 6.0) = 1.5;
// Direcao da luz em UV (y para baixo). O rim so acende no lado virado para ela:
// e o que faz parecer luz de cena e nao contorno de adesivo.
uniform vec2 rim_dir = vec2(0.75, -0.66);
uniform float rim_directional : hint_range(0.0, 1.0) = 0.8;

// Pulso de luz do cenario, dirigido pelo script.
uniform vec4 flicker_color : source_color = vec4(1.0, 0.55, 0.22, 1.0);
uniform float flicker : hint_range(-0.5, 0.5) = 0.0;

// Escurece a base da camada para dar contato com o chao / fumaca.
uniform float bottom_shade : hint_range(0.0, 1.0) = 0.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

float silhouette(vec2 uv, float lod) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return textureLod(tex, uv, lod).a;
}

void fragment() {
	vec4 sharp = textureLod(tex, v_uv, blur);
	vec4 soft = textureLod(tex, v_uv, silhouette_lod);
	float a = sharp.a;
	vec3 rgb = sharp.rgb;

	// --- tapa os furos do recorte ---------------------------------------
	if (pinhole_fill > 0.001) {
		// Um furo de poucos pixels some no mip: ali `soft.a` continua quase 1 e o
		// pixel volta a ser opaco. Um vao de verdade (entre o braco e o corpo)
		// derruba `soft.a` e nao passa pelo smoothstep — sem isso vazam manchas.
		float filled = smoothstep(fill_low, fill_high, soft.a);
		// So mexe onde REALMENTE preencheu; o resto da imagem fica intacto.
		float fill_w = clamp(filled - a, 0.0, 1.0) * pinhole_fill;
		rgb = mix(rgb, soft.rgb, fill_w);
		a = clamp(a + fill_w, 0.0, 1.0);
	}

	// --- luz de contorno -------------------------------------------------
	if (rim_strength > 0.001) {
		float w = rim_width;
		float d = w * 0.7071;
		float sr = silhouette(v_uv + vec2( w, 0.0), rim_lod);
		float sl = silhouette(v_uv + vec2(-w, 0.0), rim_lod);
		float sd = silhouette(v_uv + vec2(0.0,  w), rim_lod);
		float su = silhouette(v_uv + vec2(0.0, -w), rim_lod);
		float ring = min(min(sr, sl), min(sd, su));
		ring = min(ring, silhouette(v_uv + vec2( d,  d), rim_lod));
		ring = min(ring, silhouette(v_uv + vec2(-d,  d), rim_lod));
		ring = min(ring, silhouette(v_uv + vec2( d, -d), rim_lod));
		ring = min(ring, silhouette(v_uv + vec2(-d, -d), rim_lod));

		// So acende quando a vizinhanca e mesmo vazia. Um furo do recorte deixa
		// `ring` la pelos 0.5 e nao passa por aqui.
		float band = smoothstep(0.40, 0.02, ring) * smoothstep(0.55, 0.90, a);

		// Lado virado para a luz.
		vec2 grad = vec2(sr - sl, sd - su);   // cresce para DENTRO da silhueta
		float facing = 1.0;
		if (length(grad) > 0.0001) {
			facing = clamp(dot(normalize(-grad), normalize(rim_dir)), 0.0, 1.0);
			facing = mix(1.0, facing, rim_directional);
		}
		rgb += rim_color.rgb * band * facing * rim_strength;
	}

	// --- correcao de cor -------------------------------------------------
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = mix(vec3(luma), rgb, saturation);
	rgb = (rgb - 0.5) * contrast + 0.5;
	rgb *= brightness;

	// --- profundidade atmosferica ---------------------------------------
	rgb = mix(rgb, haze_color.rgb, haze);

	// --- pulso de luz ----------------------------------------------------
	rgb += flicker_color.rgb * flicker;

	// --- sombra de base --------------------------------------------------
	if (bottom_shade > 0.001) {
		float s = smoothstep(1.0, 0.58, v_uv.y);
		rgb *= mix(1.0 - bottom_shade, 1.0, s);
	}

	ALBEDO = max(rgb, vec3(0.0));
	ALPHA = clamp(a, 0.0, 1.0) * alpha;
}
