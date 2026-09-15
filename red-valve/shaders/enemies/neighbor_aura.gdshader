shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

// A AURA do Unknown Neighbor — o contorno que denuncia ele na rua.
//
// Entra como `material_overlay` no proprio corpo do morador, ou seja: um
// SEGUNDO passe por cima da malha com pele, sem tocar no material original. A
// roupa, a pele e a textura do modelo continuam exatamente as mesmas — o que
// este shader faz e' acender a BORDA da silhueta, e so ela.
//
// Por que borda e nao um brilho no corpo inteiro: o inimigo se passa por
// morador, e um corpo inteiro brilhando entregaria o disfarce de trinta metros
// como se ele fosse um item de coleta. A borda so aparece de verdade quando a
// superficie vira de lado em relacao a quem olha — ou seja, no contorno. De
// longe e no meio de outros NPCs ela le como "tem alguma coisa errada com
// aquele ali"; de perto, como uma casca de luz em volta do corpo.
//
// O fresnel e' calculado em espaco de VISTA, com a normal ja deformada pelo
// esqueleto, entao o contorno acompanha a caminhada em vez de ficar chapado
// num lado do corpo.

uniform vec4 cor : source_color = vec4(0.55, 0.95, 0.25, 1.0);
// 0 apaga a aura por inteiro. O script escreve aqui a cada quadro: a batida do
// coracao do parasita, e a forma em que ele esta.
uniform float forca : hint_range(0.0, 4.0) = 1.0;
// Quanto a borda e' apertada. Alto = so o fio do contorno; baixo = o corpo
// todo lava de luz, que e' justamente o que nao pode acontecer.
uniform float aperto : hint_range(1.0, 8.0) = 3.6;

varying vec3 normal_vista;
varying vec3 olhar;

void vertex() {
	normal_vista = NORMAL;
	olhar = normalize((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	if (forca <= 0.001) {
		ALPHA = 0.0;
	} else {
		float face = clamp(dot(normalize(normal_vista), -olhar), 0.0, 1.0);
		float borda = pow(1.0 - face, aperto);
		ALBEDO = cor.rgb;
		ALPHA = clamp(borda * forca, 0.0, 1.0);
	}
}
