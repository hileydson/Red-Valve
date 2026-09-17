extends AnimationPlayer

## Cutscene de abertura do Capitulo 1 (nó "cutscene_primeira_vez" da stage_1).
const ANIM_INTRO := "intro"

# --- A entrega do amuleto ----------------------------------------------------
# O Capitulo 1 comeca com o Maycow ja' de posse do amuleto (o prologo termina
# com ele esquentando no bolso), mas ate' agora isso so' existia na ficcao: o
# item nao estava no menu. Aqui ele entra de verdade, com a mesma tela de
# "voce pegou" da lanterna.
const ITEM_AMULETO := "amuleto"
const MODELO_AMULETO := "res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb"
const CENA_ITEM_OBTIDO := "res://scenes/ui/item_obtido.tscn"
## Respiro entre o fim da cutscene e a tela. O filtro cinematografico leva
## FADE_OUT_FILTRO para sumir; entrar por cima dele emendaria uma coisa na
## outra e o jogador nao entenderia que a cutscene acabou.
const ESPERA_ANTES_DO_AMULETO := 1.8

# Look cinematografico da intro. Nada de VHS: aqui o objetivo e a leitura de
# filme (letterbox, grade quente/fria, halacao nas nuvens, grao fino), sem os
# artefatos de fita.
const LETTERBOX_ALVO := 0.11
const FADE_IN_FILTRO := 1.2
const FADE_OUT_FILTRO := 0.8

# --- As poças dos postes ------------------------------------------------------
# Cada poste tem, além do SpotLight3D, um quad aceso deitado no chão (city_lights.gd,
# nó "Pocas"): é o que faz a luz aparecer na pista, já que o Forward Mobile limita as
# fontes por objeto e a pista é um mesh só.
#
# O quad usa T_lightpool.png, uma elipse suave em fundo preto — e é aí que a câmera
# aérea da abertura estraga tudo. A poça tem ~6 m e a câmera está a centenas de
# metros: o sampler cai num mipmap alto, onde a elipse já virou um cinza quase
# uniforme. O quad inteiro acende por igual e o que se vê é o RETÂNGULO do mesh.
#
# A troca abaixo desenha a mesma mancha por cálculo, a partir da UV, em vez de
# amostrar a textura. Sem textura não há mipmap para achatar, e a poça continua
# sendo uma mancha macia em qualquer distância — a cidade segue com as luzes acesas
# vista de cima, sem os quadrados.
const CAMINHO_POCAS := "../../City/PoleLights/Pocas"
## Sódio, como em city_lights.gd (cor * poca_forca do material original).
const POCA_COR := Color(0.75, 0.54, 0.315)
## De cima a poça é vista de chapa (no chão ela é sempre rasante), então ela lê
## mais forte do que no jogo; daí o valor abaixo de 1.
const POCA_FORCA := 0.75
## A luminária tipo cobra joga um oval ao longo da rua, não um círculo. >1 aperta
## a mancha no eixo V, que é o transversal à pista.
const POCA_OVAL := 1.35

var pocas: GeometryInstance3D = null
var pocas_material_original: Material = null

var cine_layer: CanvasLayer = null
var cine_mat: ShaderMaterial = null


func _ready() -> void:
	# Nada de autoplay: a intro só existe para a entrada no Capitulo 1, ou seja,
	# quando a stage_1 é carregada vindo do fim do prólogo
	# (GlobalEvents.entering_chapter_1). Voltar da casa do Jimmy, voltar da arena
	# ou carregar um save que já está no capítulo não devem repetir a cutscene.
	if not GlobalEvents.entering_chapter_1:
		return
	if GlobalEvents.voltando_da_casa_jimmy:
		return
	if GlobalEvents.voltando_da_casa_maycow:
		return
	# A igreja é um caminho de volta como os outros: sem esta guarda, sair de
	# lá com `entering_chapter_1` ainda ligado repetia a cutscene de abertura
	# do capítulo no meio da cidade.
	if GlobalEvents.voltando_da_igreja:
		return
	if not has_animation(ANIM_INTRO):
		return

	_poca_modo_aereo()
	_setup_filtro_cinematografico()
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)

	# stage_1.gd só roda o _ready dele depois dos filhos e zera GlobalEvents.in_cutscene
	# lá; adiar o play garante que a primeira key da animação (set_in_cutscene)
	# não seja apagada logo em seguida.
	play.call_deferred(ANIM_INTRO)


func set_in_cutscene()->void:
	GlobalEvents.set_in_cutscene()
func unset_in_cutscene()->void:
	GlobalEvents.unset_in_cutscene()


# ==============================================================================
# POÇAS DE LUZ DOS POSTES NA VISTA AEREA
# ==============================================================================

func _poca_modo_aereo() -> void:
	pocas = get_node_or_null(CAMINHO_POCAS) as GeometryInstance3D
	if not pocas:
		return
	pocas_material_original = pocas.material_override
	pocas.material_override = _material_poca_aerea()


func _poca_modo_normal() -> void:
	if is_instance_valid(pocas):
		pocas.material_override = pocas_material_original
	pocas = null
	pocas_material_original = null


## Sair da stage_1 no meio da abertura (pular para a casa do Jimmy, um load) não
## pode deixar a cidade com o material da cutscene na próxima vez que ela aparecer.
func _exit_tree() -> void:
	_poca_modo_normal()


## Mesma mancha, desenhada pela UV. `blend_add` e `unshaded` como no material
## original: a poça soma luz ao asfalto, não é uma decalcomania opaca.
func _material_poca_aerea() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode unshaded, blend_add, cull_disabled, depth_draw_never,
		shadows_disabled, fog_disabled;

	uniform vec3 cor : source_color = vec3(0.75, 0.54, 0.315);
	uniform float forca = 0.75;
	uniform float oval = 1.35;

	void fragment() {
		// UV do PlaneMesh vai de 0 a 1; centra e normaliza para raio 1 na borda.
		vec2 d = (UV - vec2(0.5)) * 2.0;
		d.y *= oval;
		float r = length(d);
		// Expoente alto concentra o brilho no centro e deixa a borda morrer
		// dentro do quad — se ela chegasse acesa na aresta, o quadrado voltava.
		float queda = pow(clamp(1.0 - r, 0.0, 1.0), 2.4);
		// Núcleo mais quente, como o miolo claro da textura.
		queda += 0.35 * pow(clamp(1.0 - r * 1.8, 0.0, 1.0), 3.0);

		ALBEDO = cor * forca;
		ALPHA = clamp(queda, 0.0, 1.0);
	}
	"""

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("cor", POCA_COR)
	mat.set_shader_parameter("forca", POCA_FORCA)
	mat.set_shader_parameter("oval", POCA_OVAL)
	mat.render_priority = 1
	return mat


# ==============================================================================
# FILTRO CINEMATOGRAFICO
# ==============================================================================

func _setup_filtro_cinematografico() -> void:
	cine_layer = CanvasLayer.new()
	cine_layer.name = "CinematicFilter"
	# Mesmo esquema do trailer: abaixo da UI, mas por cima do render 3D.
	cine_layer.layer = -1
	add_child(cine_layer)

	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	cine_layer.add_child(back_buffer)

	var rect := ColorRect.new()
	rect.name = "CinematicOverlay"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader_code: String = """
	shader_type canvas_item;

	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

	// Mistura geral do filtro (0 = imagem crua). Usado para entrar/sair suave.
	uniform float intensity : hint_range(0.0, 1.0) = 1.0;
	// Altura das tarjas pretas, em fracao da tela (0.11 ~ 2.35:1 em 16:9).
	uniform float letterbox : hint_range(0.0, 0.25) = 0.0;
	// Sangramento de luz das nuvens/ceu, o que da o ar de lente de cinema.
	uniform float halation : hint_range(0.0, 1.0) = 0.30;
	// Aberracao cromatica so nas bordas do quadro.
	uniform float aberration : hint_range(0.0, 0.01) = 0.0018;
	// Neblina de altitude: levanta os pretos num azul frio.
	uniform float haze : hint_range(0.0, 0.5) = 0.10;
	uniform float vignette_amount : hint_range(0.0, 1.0) = 0.38;
	uniform float grain_amount : hint_range(0.0, 0.2) = 0.030;
	uniform float contrast : hint_range(0.5, 2.0) = 1.10;
	uniform float saturation : hint_range(0.0, 2.0) = 0.92;

	uniform vec3 sombra_tint = vec3(0.42, 0.56, 0.78);
	uniform vec3 luz_tint = vec3(1.00, 0.90, 0.74);

	float rand(vec2 co) {
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}

	float luma(vec3 c) {
		return dot(c, vec3(0.2126, 0.7152, 0.0722));
	}

	void fragment() {
		vec2 uv = SCREEN_UV;
		vec2 centro = uv - vec2(0.5);
		float dist = length(centro);

		// --- ABERRACAO CROMATICA RADIAL (cresce para as bordas) ---
		float ab = aberration * dist * dist * 4.0 * intensity;
		vec2 dir = dist > 0.0001 ? centro / dist : vec2(0.0);
		vec3 base;
		base.r = texture(screen_texture, uv + dir * ab).r;
		base.g = texture(screen_texture, uv).g;
		base.b = texture(screen_texture, uv - dir * ab).b;

		vec3 color = base;

		// --- HALACAO: as areas claras (nuvens, ceu) vazam luz quente ---
		float px = 0.004;
		vec3 blur = texture(screen_texture, uv + vec2(px, 0.0)).rgb;
		blur += texture(screen_texture, uv - vec2(px, 0.0)).rgb;
		blur += texture(screen_texture, uv + vec2(0.0, px)).rgb;
		blur += texture(screen_texture, uv - vec2(0.0, px)).rgb;
		blur *= 0.25;
		float brilho = smoothstep(0.62, 1.0, luma(blur));
		color += blur * brilho * halation * vec3(1.0, 0.94, 0.84);

		// --- NEBLINA DE ALTITUDE: pretos levantados e azulados ---
		color = mix(color, color * (1.0 - haze) + sombra_tint * haze, 1.0 - smoothstep(0.0, 0.7, luma(color)));

		// --- CURVA FILMICA SUAVE + SATURACAO ---
		color = clamp((color - 0.5) * contrast + 0.5, vec3(0.0), vec3(2.0));
		color = mix(vec3(luma(color)), color, saturation);

		// --- SPLIT TONING: sombras frias, altas quentes ---
		float l = clamp(luma(color), 0.0, 1.0);
		color *= mix(sombra_tint * 0.5 + vec3(0.5), luz_tint, smoothstep(0.15, 0.85, l));

		// --- VINHETA ---
		float vig = smoothstep(0.80, 0.30, dist);
		color *= mix(1.0, vig, vignette_amount);

		// --- GRAO FINO ---
		float g = rand(uv * vec2(1024.0, 768.0) + vec2(TIME * 37.0, TIME * 61.0));
		color += (g - 0.5) * grain_amount;

		color = mix(base, color, intensity);

		// --- TARJAS ---
		float barra = step(uv.y, letterbox) + step(1.0 - letterbox, uv.y);
		color = mix(color, vec3(0.0), clamp(barra, 0.0, 1.0));

		COLOR = vec4(color, 1.0);
	}
	"""

	var shader := Shader.new()
	shader.code = shader_code

	cine_mat = ShaderMaterial.new()
	cine_mat.shader = shader
	cine_mat.set_shader_parameter("intensity", 0.0)
	cine_mat.set_shader_parameter("letterbox", 0.0)
	rect.material = cine_mat
	cine_layer.add_child(rect)

	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_cine_param.bind("intensity"), 0.0, 1.0, FADE_IN_FILTRO)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_cine_param.bind("letterbox"), 0.0, LETTERBOX_ALVO, FADE_IN_FILTRO * 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_cine_param(valor: float, nome: String) -> void:
	if cine_mat:
		cine_mat.set_shader_parameter(nome, valor)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != ANIM_INTRO:
		return
	unset_in_cutscene()
	_poca_modo_normal()
	_remover_filtro_cinematografico()
	_entregar_amuleto()


## Põe o amuleto no inventário e mostra a tela do objeto.
##
## Uma vez só: a checagem é no inventário, então quem já recebeu (inclusive em
## outra partida, pelo save) não vê a tela de novo ao rever a abertura.
func _entregar_amuleto() -> void:
	if SaveManager.tem_item(ITEM_AMULETO):
		return
	await get_tree().create_timer(ESPERA_ANTES_DO_AMULETO).timeout
	if not is_inside_tree():
		return

	SaveManager.add_item(ITEM_AMULETO, 1)
	# Ja' equipado: o amuleto e' o unico equipavel que ele tem nesta altura, e a
	# mira dele e' a mecanica que o Capitulo 1 acabou de ensinar.
	SaveManager.equip_item(ITEM_AMULETO)
	SaveManager.save_game()

	var tela: CanvasLayer = load(CENA_ITEM_OBTIDO).instantiate()
	tela.model_path = MODELO_AMULETO
	tela.texto = tr("PICKUP_AMULETO")
	get_tree().root.add_child(tela)


func _remover_filtro_cinematografico() -> void:
	if not is_instance_valid(cine_layer):
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_cine_param.bind("intensity"), 1.0, 0.0, FADE_OUT_FILTRO)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_cine_param.bind("letterbox"), LETTERBOX_ALVO, 0.0, FADE_OUT_FILTRO)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(cine_layer):
		cine_layer.queue_free()
	cine_layer = null
	cine_mat = null
