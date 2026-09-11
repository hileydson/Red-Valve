extends CanvasLayer
class_name TutorialOverlay

## Cartao de tutorial: um veu por cima do jogo, uma imagem no centro e as frases
## de explicacao aparecendo uma de cada vez debaixo dela. Enquanto ele esta na
## tela o jogo fica pausado — por isso todo o no roda em PROCESS_MODE_ALWAYS.
##
## Quem decide QUANDO isto aparece (e se ja apareceu antes) e quem chama
## `mostrar()`; aqui so mora a apresentacao. Ver stage_1.gd, que dispara o
## tutorial do amuleto uma unica vez no comeco do Capitulo 1.

## Camada: acima da UI das fases (128) e abaixo do inventario/pause (150), que
## de qualquer forma nao abrem com o jogo ja pausado.
const CAMADA := 140
const FADE := 0.6           # entrada e saida do veu + imagem
const FADE_FRASE := 0.4     # entrada e saida de cada frase
## A imagem do tutorial e cinza clara e so ganha contorno contra um fundo bem
## escuro (a cidade na chuva e cinza tambem). Nao e preto chapado: o alpha
## deixa a cena aparecendo por tras, so bem apagada.
const VEU_COR := Color(0.04, 0.04, 0.06, 0.80)
## A setinha de "aperte pra continuar" e a mesma das cutscenes de imagem
## (parallax_cutscene_base.tscn): laranja, piscando no mesmo ritmo.
const SETA_COR := Color(1, 0.72, 0.42)
const SETA_PISCA := 4.2
## Respiro antes de cada frase aceitar o botao. Sem isso um toque so (ou o botao
## segurado) atravessava as tres frases de uma vez.
const ARMAR_INPUT := 0.35

signal finalizado

var _veu: ColorRect
var _imagem: TextureRect
var _frase: Label
var _seta: Label
var _avancar: bool = false
var _rodando: bool = false
var _esperando_input: bool = false
var _tempo: float = 0.0


## Monta e exibe o tutorial. `textos` sao as frases ja traduzidas, na ordem.
## Devolve quando tudo saiu da tela (o no se destroi sozinho em seguida).
func mostrar(textura: Texture2D, textos: Array) -> void:
	if _rodando:
		return
	_rodando = true
	_montar(textura)
	get_tree().paused = true

	# Entrada: veu e imagem juntos.
	var entrada := create_tween()
	entrada.set_parallel(true)
	entrada.tween_property(_veu, "modulate:a", 1.0, FADE)
	entrada.tween_property(_imagem, "modulate:a", 1.0, FADE)
	await entrada.finished

	for texto in textos:
		await _mostrar_frase(str(texto))

	# Saida: a ultima frase ja saiu junto com ela; agora vai o resto.
	var saida := create_tween()
	saida.set_parallel(true)
	saida.tween_property(_veu, "modulate:a", 0.0, FADE)
	saida.tween_property(_imagem, "modulate:a", 0.0, FADE)
	await saida.finished

	get_tree().paused = false
	# A última frase é confirmada com ui_accept OU ui_dash — e o ui_dash é o
	# mesmo botão do dash. Sem isto, fechar o tutorial fazia o Maycow disparar.
	GlobalEvents.bloquear_dash_por()
	finalizado.emit()
	queue_free()


func _montar(textura: Texture2D) -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS

	_veu = ColorRect.new()
	# Cobre a tela inteira, mesmo com a imagem so no centro.
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu.color = VEU_COR
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu.modulate.a = 0.0
	add_child(_veu)

	var coluna := VBoxContainer.new()
	coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 28)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coluna)

	_imagem = TextureRect.new()
	_imagem.texture = textura
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# A imagem vem em 2400x1639, alta demais pra ser usada crua; a caixa fixa
	# (mesma proporcao) deixa sempre sobrar tela pras frases embaixo.
	_imagem.custom_minimum_size = Vector2(820, 560)
	_imagem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagem.modulate.a = 0.0
	coluna.add_child(_imagem)

	var fonte := load("res://assets/fonts/Montserrat-ExtraBold.ttf")

	_frase = Label.new()
	_frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_frase.autowrap_mode = TextServer.AUTOWRAP_WORD
	_frase.custom_minimum_size = Vector2(1100, 110)
	_frase.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_frase.add_theme_font_size_override("font_size", 26)
	# Letra clara com contorno preto, como o resto dos avisos do jogo: sobre o
	# veu escuro e o que continua legivel mesmo se a frase cair numa parte clara
	# da cidade.
	_frase.add_theme_constant_override("outline_size", 6)
	_frase.add_theme_color_override("font_color", Color(0.96, 0.94, 0.92))
	_frase.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	if fonte:
		_frase.add_theme_font_override("font", fonte)
	_frase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frase.modulate.a = 0.0
	coluna.add_child(_frase)

	_seta = Label.new()
	_seta.text = "\u25BC"
	_seta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_seta.add_theme_font_size_override("font_size", 24)
	_seta.add_theme_color_override("font_color", SETA_COR)
	# Sem isto a seta ficava no fallback do tema padrao: no editor o fallback
	# tem o glifo \u25BC, mas no jogo exportado (outra maquina, sem as fontes do
	# sistema do editor) o glifo sumia/quebrava. A Montserrat-ExtraBold e a
	# mesma fonte ja embutida no projeto pra `_frase`, e tem o glifo.
	if fonte:
		_seta.add_theme_font_override("font", fonte)
	_seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seta.modulate.a = 0.0
	coluna.add_child(_seta)


func _mostrar_frase(texto: String) -> void:
	_frase.text = texto

	var entrada := create_tween()
	entrada.tween_property(_frase, "modulate:a", 1.0, FADE_FRASE)
	await entrada.finished

	await _esperar_input()

	var saida := create_tween()
	saida.tween_property(_frase, "modulate:a", 0.0, FADE_FRASE)
	await saida.finished


## Segura a frase ate o jogador apertar o botao — o tutorial nao anda sozinho,
## quem le decide a hora de virar a pagina.
func _esperar_input() -> void:
	# Arvore pausada: `delta` do processo comum nao anda, entao o relogio aqui e
	# o tempo real mesmo.
	var armando := ARMAR_INPUT
	while armando > 0.0:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		armando -= get_process_delta_time()

	_avancar = false
	_esperando_input = true
	while not _avancar:
		await get_tree().process_frame
		if not is_inside_tree():
			_esperando_input = false
			return
	_esperando_input = false


## Piscar da seta. Mesma conta da cutscene de imagens: nunca apaga de todo, so
## respira entre 0.35 e 0.8 de opacidade.
func _process(delta: float) -> void:
	if not is_instance_valid(_seta):
		return
	if not _esperando_input:
		_seta.modulate.a = 0.0
		return
	_tempo += delta
	_seta.modulate.a = 0.35 + 0.45 * (sin(_tempo * SETA_PISCA) * 0.5 + 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if not _rodando:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_dash"):
		_avancar = true
		get_viewport().set_input_as_handled()
