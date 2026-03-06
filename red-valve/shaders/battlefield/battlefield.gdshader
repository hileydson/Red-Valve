shader_type spatial;
render_mode unshaded, skip_vertex_transform;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Parâmetros de Realismo e Tom
uniform float contrast : hint_range(0.0, 2.0) = 1.2;
uniform float saturation : hint_range(0.0, 2.0) = 0.85; // Lovecraft pede cores levemente lavadas
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.4;
uniform float aberration_amount : hint_range(0.0, 0.1) = 0.002; // Distorção nas bordas

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// 1. ABERRAÇÃO CROMÁTICA (Distorção de lente/insanidade)
	float r = texture(SCREEN_TEXTURE, uv + vec2(aberration_amount, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(aberration_amount, 0.0)).b;
	vec3 color = vec3(r, g, b);
	
	// 2. CONTRASTE (Filmic Tone Mapping simples)
	color = (color - 0.5) * contrast + 0.5;
	
	// 3. SATURAÇÃO (Desaturar para tom melancólico)
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(gray), color, saturation);
	
	// 4. VINHETA (Escurecer bordas para foco central e mistério)
	float d = distance(uv, vec2(0.5, 0.5));
	color *= smoothstep(0.8, 0.8 - vignette_intensity, d);
	
	// 5. COLOR TINT (Opcional: Tom levemente azulado ou esverdeado "Deep One")
	color *= vec3(0.95, 1.0, 0.98); 

	ALBEDO = color;
}