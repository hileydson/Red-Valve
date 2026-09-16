extends Node3D

## Maycow de CUTSCENE em primeira pessoa: uma camera com as duas maos.
##
## Nao e' o player. Nao anda, nao leva dano, nao tem colisao — e' so' um ponto
## de vista com maos animadas, feito para os momentos em que a camera precisa
## entrar no corpo do Maycow e as maos precisam FAZER alguma coisa (se
## defender, apoiar no chao, empurrar). O `player.tscn` continua intocado: quem
## chama esconde o modelo de 3a pessoa, liga esta camera, roda a cena e devolve.
##
## As duas maos vem prontas do mesmo `maos_fp.glb`, cada uma com o proprio
## esqueleto e as proprias curvas (o gerador em tools/blender/maos_fp/ espelha
## a malha de verdade e escreve uma animacao para cada lado). Um unico
## AnimationPlayer toca as duas: `tocar("defesa")` anima as duas maos, cada uma
## com o seu tempo e a sua altura.
##
## Nao tente espelhar a mao direita no Godot com `scale.x = -1`: o motor le'
## determinante negativo como escala uniforme negativa, perde a reflexao na
## matriz de normais e a mao sai escura. Esta' documentado no gerador.
##
## As animacoes sao autoradas no espaco da CAMERA (ver
## tools/blender/maos_fp/gerar_maos_fp.py), entao as maos sao filhas da
## Camera3D e nao precisam de nenhum acerto de posicao em tempo de jogo.
##
## COMO A CAMERA ANDA
## ------------------
## Nao por tween de transform: quem usa diz para ONDE olhar e ONDE estar
## (`mirar`), e o no' persegue esse alvo todo quadro. Um tween de Transform3D
## interpola a base linearmente e entorta a imagem no meio do caminho; e um
## alvo perseguido acompanha um inimigo que ainda esta se mexendo, coisa que
## um tween gravado no inicio da cena nao faz.

# ---------------------------------------------------------------- animacoes
## Quais tocam em laco. O resto toca uma vez e fica parado no ultimo quadro.
const ANIMS_EM_LACO := ["idle", "defesa", "agarrado", "queda"]

# ---------------------------------------------------------------- camera
## Quanto a camera "corre atras" do alvo. Maior = mais duro, menor = mais mole.
const VEL_POSICAO_PADRAO := 9.0
const VEL_GIRO_PADRAO := 9.0

@onready var suporte_tremor: Node3D = $Tremor
@onready var camera: Camera3D = $Tremor/Camera3D
@onready var maos: Node3D = $Tremor/Camera3D/Maos
@onready var animador: AnimationPlayer = $Tremor/Camera3D/Maos/maos_fp/AnimationPlayer
@onready var luz_maos: OmniLight3D = $Tremor/Camera3D/luz_maos
@onready var tela: CanvasLayer = $Tela
@onready var flash_tela: ColorRect = $Tela/flash
@onready var sangue_tela: ColorRect = $Tela/sangue
@onready var borrao_tela: ColorRect = $Tela/borrao

var _alvo_pos: Vector3 = Vector3.ZERO
var _alvo_olhar: Vector3 = Vector3.FORWARD
var _vel_pos: float = VEL_POSICAO_PADRAO
var _vel_giro: float = VEL_GIRO_PADRAO
var _rolagem: float = 0.0
var _rolagem_atual: float = 0.0

var _tremor_forca: float = 0.0
var _tremor_tempo: float = 0.0
var _tremor_relogio: float = 0.0

var _anim_atual: StringName = &""

## Campo de visao autorado na cena. Guardado no `_ready` para `lente_padrao()`
## saber para onde voltar sem ninguem repetir o numero por ai.
var _fov_padrao: float = 75.0
var _lente_tween: Tween

var _borrao_forca: float = 0.0
var _borrao_tween: Tween


func _ready() -> void:
	_fov_padrao = camera.fov
	for nome in animador.get_animation_list():
		var anim: Animation = animador.get_animation(nome)
		anim.loop_mode = Animation.LOOP_LINEAR if nome in ANIMS_EM_LACO else Animation.LOOP_NONE
	_preparar_tela()
	tocar(&"idle")
	_revelar_maos()


## As maos nascem ESCONDIDAS.
##
## O Skeleton3D so' manda a pose nova para a GPU num passo diferido: mesmo
## chamando `play` + `advance` na hora, o PRIMEIRO quadro desenhado ainda usa o
## esqueleto em DESCANSO — e a pose de descanso deste rig e' a mao atravessada
## na diagonal, enorme, no meio da tela. Como esse quadro e' exatamente aquele
## em que a camera acaba de virar a atual, o erro aparecia inteiro.
##
## Dois quadros sem mao nenhuma, escondidos atras do flash de entrada.
func _revelar_maos() -> void:
	maos.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(maos):
		maos.visible = true


# ============================================================== camera

## Diz onde a camera deve ficar e para onde deve olhar. Ela vai chegando la'.
## `rolagem` inclina a imagem (radianos) — e' o que vende tontura e queda.
func mirar(posicao: Vector3, olhar: Vector3, vel_pos: float = VEL_POSICAO_PADRAO,
		vel_giro: float = VEL_GIRO_PADRAO, rolagem: float = 0.0) -> void:
	_alvo_pos = posicao
	_alvo_olhar = olhar
	_vel_pos = vel_pos
	_vel_giro = vel_giro
	_rolagem = rolagem


## Mesma coisa, mas chega no mesmo quadro. Para o primeiro posicionamento,
## antes de a camera virar a atual — senao ela aparece viajando desde a origem
## do mundo.
func plantar(posicao: Vector3, olhar: Vector3, rolagem: float = 0.0) -> void:
	mirar(posicao, olhar, VEL_POSICAO_PADRAO, VEL_GIRO_PADRAO, rolagem)
	_rolagem_atual = rolagem
	global_position = posicao
	_encarar(olhar, rolagem, 1.0)


func assumir_camera() -> void:
	camera.make_current()


## Apaga tudo que e' 3D (camera, maos e luz) e deixa so' a TELA.
##
## E' o que deixa a camera do jogador voltar a mandar enquanto o borrao da
## troca ainda esta' subindo na tela: as maos ficam coladas na camera desta
## cena, que no fim da cinematica para' exatamente onde a de 3a pessoa esta' —
## sem apagar, elas apareceriam penduradas na frente do Maycow.
func apagar_3d() -> void:
	if is_instance_valid(suporte_tremor):
		suporte_tremor.visible = false


func _process(delta: float) -> void:
	var t_pos := 1.0 - exp(-delta * _vel_pos)
	global_position = global_position.lerp(_alvo_pos, t_pos)
	_rolagem_atual = lerp(_rolagem_atual, _rolagem, 1.0 - exp(-delta * _vel_giro))
	_encarar(_alvo_olhar, _rolagem_atual, 1.0 - exp(-delta * _vel_giro))
	_passo_do_tremor(delta)


func _encarar(olhar: Vector3, rolagem: float, peso: float) -> void:
	var frente := olhar - global_position
	if frente.length_squared() < 0.000001:
		return
	frente = frente.normalized()

	# `looking_at` quebra quando a frente fica paralela ao "cima" (a camera
	# olhando reto pro chao, que e' EXATAMENTE o caso do jogador caido). Nesse
	# caso o "cima" passa a ser o proprio eixo de trás da camera.
	var cima := Vector3.UP
	if absf(frente.dot(cima)) > 0.995:
		cima = -global_transform.basis.z
		if absf(frente.dot(cima)) > 0.995:
			cima = Vector3.RIGHT
	var destino := Basis.looking_at(frente, cima)
	if absf(rolagem) > 0.0001:
		destino = destino * Basis(Vector3.FORWARD, rolagem)
	global_transform.basis = Basis(global_transform.basis.get_rotation_quaternion().slerp(
			destino.get_rotation_quaternion(), clampf(peso, 0.0, 1.0)))


# ============================================================== lente

## Abre ou fecha o campo de visao da camera.
##
## E' a metade "zoom" da troca de camera. Com a camera ANDANDO ao mesmo tempo
## (o mergulho da entrada, o recuo da saida), abrir e fechar o FOV e' o que faz
## a passagem ler como zoom in / zoom out em vez de corte seco: a imagem
## estica pelas bordas enquanto o centro fica parado.
##
## `duracao` zero escreve na hora — para plantar antes de a camera virar a
## atual, senao o primeiro quadro sai com o FOV errado.
func lente(graus: float, duracao: float = 0.0) -> void:
	if not is_instance_valid(camera):
		return
	if _lente_tween != null and _lente_tween.is_valid():
		_lente_tween.kill()
	if duracao <= 0.0:
		camera.fov = graus
		return
	_lente_tween = create_tween()
	_lente_tween.tween_property(camera, "fov", graus, duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Volta para o campo de visao autorado na cena.
func lente_padrao(duracao: float = 0.0) -> void:
	lente(_fov_padrao, duracao)


# ============================================================== tremor

## Tremor proprio, num no' INTERMEDIARIO entre o caminho da camera e a
## Camera3D. Assim ele soma ao movimento em vez de brigar com ele — e nao usa
## `GlobalUtils.shake_camera`, que mexe em `h_offset`/`v_offset` da camera atual
## e deixaria esses valores sujos na camera do jogador depois.
func tremer(forca: float, duracao: float) -> void:
	_tremor_forca = maxf(_tremor_forca, forca)
	_tremor_tempo = maxf(_tremor_tempo, duracao)


func _passo_do_tremor(delta: float) -> void:
	if _tremor_tempo <= 0.0:
		if suporte_tremor.position != Vector3.ZERO:
			suporte_tremor.position = Vector3.ZERO
			suporte_tremor.rotation = Vector3.ZERO
		return
	_tremor_tempo -= delta
	_tremor_relogio += delta
	var f := _tremor_forca * clampf(_tremor_tempo * 3.0, 0.0, 1.0)
	suporte_tremor.position = Vector3(
		sin(_tremor_relogio * 61.0) * f,
		sin(_tremor_relogio * 47.0 + 1.3) * f,
		sin(_tremor_relogio * 53.0 + 2.1) * f * 0.5)
	suporte_tremor.rotation = Vector3(
		sin(_tremor_relogio * 43.0) * f * 1.4,
		sin(_tremor_relogio * 37.0 + 0.7) * f * 1.4,
		sin(_tremor_relogio * 29.0 + 2.6) * f * 2.2)
	if _tremor_tempo <= 0.0:
		_tremor_forca = 0.0
		suporte_tremor.position = Vector3.ZERO
		suporte_tremor.rotation = Vector3.ZERO


# ============================================================== maos

func tocar(nome: StringName, velocidade: float = 1.0) -> void:
	if animador == null or not animador.has_animation(nome):
		return
	_anim_atual = nome
	animador.play(nome, 0.18, velocidade)
	# `play` so' escreve a pose no proximo quadro processado. Um quadro parece
	# pouco, mas e' o quadro em que a camera ACABOU de virar a atual: sem isto,
	# a primeira imagem da cutscene e' a pose de descanso do esqueleto — duas
	# maos gigantes e tortas atravessando a tela.
	animador.advance(0.0)


## Quanto falta da animacao de uma vez que esta tocando. Zero para as de laco,
## que nunca terminam.
func duracao_restante() -> float:
	if animador == null or _anim_atual == &"" or _anim_atual in ANIMS_EM_LACO:
		return 0.0
	return maxf(animador.current_animation_length - animador.current_animation_position, 0.0)


func maos_visiveis(visivel: bool) -> void:
	maos.visible = visivel


# ============================================================== tela

func _preparar_tela() -> void:
	# Mesmo desenho da vinheta de sangue do HUD (player_hud.gd). Repetido aqui
	# de proposito: durante a cena o HUD do jogador esta DESLIGADO, e esta
	# camera precisa dos proprios efeitos para nao ficar muda no impacto.
	var vinheta := Shader.new()
	vinheta.code = """
shader_type canvas_item;
uniform vec4 color : source_color = vec4(0.75, 0.0, 0.0, 1.0);
uniform float multiplier = 0.0;
uniform float softness = 0.5;

void fragment() {
	float value = distance(UV, vec2(0.5));
	value = smoothstep(0.5 - softness, 0.5, value);
	COLOR = vec4(color.rgb, value * multiplier);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = vinheta
	sangue_tela.material = mat
	sangue_tela.color = Color(1, 1, 1, 1)
	flash_tela.modulate.a = 0.0

	# Borrao RADIAL (puxa a tela para o centro). Mesmo desenho do
	# "MotionBlurOverlay" do HUD (player_hud.gd), repetido aqui pelo mesmo motivo
	# da vinheta: durante a cena o HUD do jogador esta' desligado, e a troca de
	# camera precisa do borrao justamente nesse intervalo.
	#
	# O BackBufferCopy ao lado dele na cena e' obrigatorio: sem uma copia do
	# quadro feita ANTES deste ColorRect, o `hint_screen_texture` le' lixo.
	var radial := Shader.new()
	radial.code = """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength = 0.0;

void fragment() {
	vec2 dir = vec2(0.5) - SCREEN_UV;
	vec4 c = texture(tela, SCREEN_UV);
	for (int i = 1; i < 8; i++) {
		c += texture(tela, SCREEN_UV + dir * blur_strength * 0.05 * float(i));
	}
	COLOR = c / 8.0;
}
"""
	var mat_borrao := ShaderMaterial.new()
	mat_borrao.shader = radial
	borrao_tela.material = mat_borrao
	borrao_tela.color = Color(1, 1, 1, 1)
	borrao_tela.visible = false


func piscar(cor: Color, forca: float = 0.7, subida: float = 0.04, descida: float = 0.35) -> void:
	if not is_instance_valid(flash_tela):
		return
	flash_tela.color = Color(cor.r, cor.g, cor.b, 1.0)
	var t := create_tween()
	t.tween_property(flash_tela, "modulate:a", forca, subida)
	t.tween_property(flash_tela, "modulate:a", 0.0, descida).set_trans(Tween.TRANS_CUBIC)


## Vinheta de sangue. A `softness` e' menor que a do HUD de proposito: a do HUD
## tinge a tela inteira (no centro ela ja' entra com ~0,26 de alfa), e aqui,
## somada ao flash vermelho do golpe, isso apagava a cena no momento em que ela
## e' mais importante. Esta fica presa nas bordas.
func sangrar(forca: float = 0.55, duracao: float = 1.4) -> void:
	if not is_instance_valid(sangue_tela) or sangue_tela.material == null:
		return
	var mat := sangue_tela.material as ShaderMaterial
	mat.set_shader_parameter("multiplier", forca)
	var t := create_tween()
	t.tween_method(func(v): mat.set_shader_parameter("multiplier", v), forca, 0.0, duracao) \
		.set_trans(Tween.TRANS_CUBIC)


## Borrao radial da troca de camera. `duracao` zero escreve na hora; maior que
## zero caminha ate la'. Chamar com forca 0 apaga o no' sozinho ao chegar.
func borrar(forca: float, duracao: float = 0.0) -> void:
	if not is_instance_valid(borrao_tela) or borrao_tela.material == null:
		return
	if _borrao_tween != null and _borrao_tween.is_valid():
		_borrao_tween.kill()
	if duracao <= 0.0:
		_escrever_borrao(forca)
		return
	_borrao_tween = create_tween()
	_borrao_tween.tween_method(_escrever_borrao, _borrao_forca, forca, duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _escrever_borrao(valor: float) -> void:
	_borrao_forca = valor
	if not is_instance_valid(borrao_tela) or borrao_tela.material == null:
		return
	(borrao_tela.material as ShaderMaterial).set_shader_parameter("blur_strength", valor)
	# Um ColorRect de tela cheia que le' o backbuffer custa caro para nao fazer
	# nada: com forca zero ele sai do desenho.
	borrao_tela.visible = valor > 0.002


func limpar_tela() -> void:
	if is_instance_valid(flash_tela):
		flash_tela.modulate.a = 0.0
	if is_instance_valid(sangue_tela) and sangue_tela.material != null:
		(sangue_tela.material as ShaderMaterial).set_shader_parameter("multiplier", 0.0)
	borrar(0.0)
