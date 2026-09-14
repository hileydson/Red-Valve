extends CanvasLayer
class_name CogbladeQTE

## Quick time event dos poderes da Cogblade.
##
## Os poderes rodam com `Engine.time_scale = 0.1` e o `AudioServer` a 0.5x, então
## NADA aqui pode depender do tempo de jogo: a contagem regressiva usa
## `Time.get_ticks_msec()` (relógio de parede) e as animações usam tweens com
## `ignore_time_scale`. Sem isso uma janela de 1s viraria 10s reais e o teste
## não teria graça nenhuma.
##
## Uso (sempre de dentro de uma corrotina):
##     var ok: bool = await qte.rodar(5)
## Devolve `true` só se TODOS os botões forem acertados dentro da janela.
## Errar o botão OU deixar o tempo acabar interrompe a sequência na hora.

## Acima das camadas de FX dos poderes (105) e abaixo do pause/inventário (150).
const CAMADA := 130

## Tradução controle -> teclado pedida no design do golpe:
## A→A, B→S, Y→D, X→W, LB→1, RB→2.
const BOTOES := [
	{"nome": "A",  "tecla": KEY_A, "tecla_nome": "A", "joy": JOY_BUTTON_A,              "cor": Color(0.33, 0.74, 0.31), "ombro": false},
	{"nome": "B",  "tecla": KEY_S, "tecla_nome": "S", "joy": JOY_BUTTON_B,              "cor": Color(0.85, 0.25, 0.22), "ombro": false},
	{"nome": "X",  "tecla": KEY_W, "tecla_nome": "W", "joy": JOY_BUTTON_X,              "cor": Color(0.20, 0.48, 0.90), "ombro": false},
	{"nome": "Y",  "tecla": KEY_D, "tecla_nome": "D", "joy": JOY_BUTTON_Y,              "cor": Color(0.95, 0.76, 0.18), "ombro": false},
	{"nome": "LB", "tecla": KEY_1, "tecla_nome": "1", "joy": JOY_BUTTON_LEFT_SHOULDER,  "cor": Color(0.74, 0.75, 0.80), "ombro": true},
	{"nome": "RB", "tecla": KEY_2, "tecla_nome": "2", "joy": JOY_BUTTON_RIGHT_SHOULDER, "cor": Color(0.74, 0.75, 0.80), "ombro": true},
]

const TAM_SLOT := 84.0        # lado do quadrado de cada botão
const ALTURA_RODAPE := 170.0  # distância da fileira até a base da tela
const COR_APAGADO := Color(0.55, 0.55, 0.60)
const COR_ACERTO := Color(0.45, 1.0, 0.55)
const COR_ERRO := Color(1.0, 0.30, 0.28)

## Retorno do acerto: um tranco curto de câmera + vibração leve. Tudo em tempo
## REAL (tween com ignore_time_scale), senão a câmera lenta do poder esticaria o
## tranco em quase dois segundos.
const TREMOR_FORCA := 0.045   # offset da câmera, em unidades de h_offset/v_offset
const TREMOR_DUR := 0.16      # segundos reais
const TREMOR_PASSOS := 5

const SOM_ACERTO := "res://assets/sounds/menu_itens/selecionar_item.mp3"
const SOM_ERRO := "res://assets/sounds/menu_itens/negacao.mp3"

## Emitido internamente quando o botão da vez é resolvido (acerto ou falha).
signal resolvido(acertou: bool)

var _raiz: Control = null
var _coluna: VBoxContainer = null
var _fileira: HBoxContainer = null
var _trilho: Control = null
var _barra: ColorRect = null
var _flash: TextureRect = null  # mancha vermelha do erro, cobre a tela inteira
var _slots: Array = []        # um Dictionary por botão: {raiz, painel, rotulo, legenda, estilo}

var _sequencia: Array = []    # índices em BOTOES, sorteados no começo da rodada
var _indice: int = -1
var _ativo: bool = false
var _janela: float = 1.0      # segundos REAIS para apertar o botão da vez
var _inicio_ms: int = 0
var _rodando: bool = false

var _tremor_tween: Tween = null
var _tremor_h_base: float = 0.0
var _tremor_v_base: float = 0.0


func _ready() -> void:
	layer = CAMADA
	# PROCESS_MODE_ALWAYS: se qualquer coisa pausar a árvore no meio da
	# cinemática, o QTE não pode congelar segurando a corrotina do poder.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_montar()


# =========================================================================
# API
# =========================================================================

## Sorteia `quantidade` botões, mostra na tela e espera os inputs, um de cada
## vez. `janela_seg` é o tempo REAL (não afetado pela câmera lenta) que o
## jogador tem para cada botão.
func rodar(quantidade: int, janela_seg: float = 1.0) -> bool:
	if quantidade <= 0:
		return true
	if _rodando: # segurança: nunca duas rodadas ao mesmo tempo
		return false
	_rodando = true
	_indice = -1

	_sequencia.clear()
	for i in range(quantidade):
		_sequencia.append(randi() % BOTOES.size())
	_construir_slots()
	await _entrar()

	var tudo_certo := true
	for i in range(quantidade):
		_indice = i
		_realcar()
		_janela = maxf(janela_seg, 0.15)
		_inicio_ms = Time.get_ticks_msec()
		_ativo = true
		set_process(true)

		var acertou: bool = await resolvido

		_ativo = false
		set_process(false)
		await _reagir(i, acertou)
		if not acertou:
			tudo_certo = false
			break

	_indice = -1
	await _sair()
	_rodando = false
	return tudo_certo


## Interrompe uma rodada em andamento (o poder foi cancelado por fora).
func cancelar() -> void:
	if _ativo:
		_resolver(false)
	_rodando = false
	_indice = -1
	set_process(false)
	_parar_tremor()
	if is_instance_valid(_raiz):
		_raiz.visible = false


# =========================================================================
# ENTRADA
# =========================================================================

func _input(event: InputEvent) -> void:
	if not _ativo:
		return

	var apertado := -1
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == 0:
			k = (event as InputEventKey).keycode
		apertado = _por_tecla(k)
	elif event is InputEventJoypadButton and event.pressed:
		apertado = _por_joy((event as InputEventJoypadButton).button_index)

	if apertado < 0:
		return

	# Qualquer um dos seis botões é consumido aqui: durante o QTE eles não
	# podem vazar para o resto do jogo (troca de arma, dash, recarregar...).
	get_viewport().set_input_as_handled()
	_resolver(apertado == _sequencia[_indice])


func _process(_delta: float) -> void:
	if not _ativo:
		return
	var passado := float(Time.get_ticks_msec() - _inicio_ms) / 1000.0
	var restante: float = clampf(1.0 - passado / _janela, 0.0, 1.0)
	if is_instance_valid(_barra) and is_instance_valid(_trilho):
		_barra.size.x = _trilho.size.x * restante
		_barra.color = Color(1.0, 0.72, 0.30) if restante > 0.35 else COR_ERRO
	# Pulsação do botão da vez, também no relógio de parede.
	if _indice >= 0 and _indice < _slots.size():
		var pulso: float = 1.0 + 0.07 * sin(passado * 12.0)
		var raiz: Control = _slots[_indice]["raiz"]
		if is_instance_valid(raiz):
			raiz.scale = Vector2(pulso, pulso) * 1.18
	# O jogador pode largar o teclado e pegar o controle no meio da rodada: a
	# legenda com a tecla equivalente some (e volta) junto.
	_atualizar_legendas()
	if restante <= 0.0:
		_resolver(false)


func _atualizar_legendas() -> void:
	var no_controle: bool = GlobalEvents.usando_controle
	for slot in _slots:
		var legenda: Label = slot["legenda"]
		if is_instance_valid(legenda):
			legenda.visible = not no_controle


func _resolver(acertou: bool) -> void:
	if not _ativo:
		return
	_ativo = false
	resolvido.emit(acertou)


func _por_tecla(codigo: int) -> int:
	for i in range(BOTOES.size()):
		if BOTOES[i]["tecla"] == codigo:
			return i
	return -1


func _por_joy(indice: int) -> int:
	for i in range(BOTOES.size()):
		if BOTOES[i]["joy"] == indice:
			return i
	return -1


# =========================================================================
# APRESENTAÇÃO
# =========================================================================

func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.visible = false
	add_child(_raiz)

	# Mancha vermelha do erro: fica ATRÁS da fileira de botões (adicionada antes
	# da coluna) para tingir a tela sem apagar o botão que acabou de falhar.
	_flash = TextureRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_flash.texture = _textura_mancha()
	_flash.modulate = Color(1, 1, 1, 0.0)
	_flash.visible = false
	_raiz.add_child(_flash)

	# Ocupa a tela inteira menos o rodapé e joga o conteúdo para baixo: assim a
	# fileira fica na parte de baixo sem tapar o meio da tela, que é justamente
	# onde a lâmina está trabalhando.
	_coluna = VBoxContainer.new()
	_coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coluna.offset_bottom = -ALTURA_RODAPE
	_coluna.alignment = BoxContainer.ALIGNMENT_END
	_coluna.add_theme_constant_override("separation", 16)
	_raiz.add_child(_coluna)

	_fileira = HBoxContainer.new()
	_fileira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fileira.alignment = BoxContainer.ALIGNMENT_CENTER
	_fileira.add_theme_constant_override("separation", 18)
	_coluna.add_child(_fileira)

	# Barra de tempo: some da direita para a esquerda enquanto a janela corre.
	_trilho = Control.new()
	_trilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trilho.custom_minimum_size = Vector2(260, 6)
	# SHRINK_CENTER senão a VBox esticaria o trilho de ponta a ponta da tela.
	_trilho.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_coluna.add_child(_trilho)

	var fundo := ColorRect.new()
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0, 0, 0, 0.45)
	_trilho.add_child(fundo)

	_barra = ColorRect.new()
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.color = Color(1.0, 0.72, 0.30)
	_barra.position = Vector2.ZERO
	_barra.size = Vector2(260, 6)
	_trilho.add_child(_barra)
	_trilho.resized.connect(func():
		if is_instance_valid(_barra): _barra.size.y = _trilho.size.y
	)


func _construir_slots() -> void:
	for s in _slots:
		var r = s["raiz"]
		if is_instance_valid(r):
			r.queue_free()
	_slots.clear()

	var no_controle: bool = GlobalEvents.usando_controle
	for indice in _sequencia:
		var dados: Dictionary = BOTOES[indice]

		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = Vector2(TAM_SLOT, TAM_SLOT + 22.0)
		slot.pivot_offset = Vector2(TAM_SLOT, TAM_SLOT + 22.0) * 0.5
		_fileira.add_child(slot)

		# O "botão": círculo para A/B/X/Y, retângulo achatado para LB/RB.
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.05, 0.05, 0.07, 0.85)
		estilo.border_color = dados["cor"]
		estilo.set_border_width_all(5)
		var raio: int = 12 if dados["ombro"] else int(TAM_SLOT * 0.5)
		estilo.set_corner_radius_all(raio)

		var painel := Panel.new()
		painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painel.add_theme_stylebox_override("panel", estilo)
		painel.position = Vector2(0, TAM_SLOT * 0.2) if dados["ombro"] else Vector2.ZERO
		painel.size = Vector2(TAM_SLOT, TAM_SLOT * 0.6) if dados["ombro"] else Vector2(TAM_SLOT, TAM_SLOT)
		slot.add_child(painel)

		var rotulo := Label.new()
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rotulo.text = dados["nome"]
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rotulo.set_anchors_preset(Control.PRESET_FULL_RECT)
		rotulo.add_theme_font_size_override("font_size", 30 if dados["ombro"] else 38)
		rotulo.add_theme_color_override("font_color", dados["cor"])
		var fonte := load("res://assets/fonts/Montserrat-ExtraBold.ttf")
		if fonte:
			rotulo.add_theme_font_override("font", fonte)
		painel.add_child(rotulo)

		# No teclado o glifo do controle sozinho não diz nada: a tecla
		# equivalente vai logo abaixo, e some quando há controle na mão.
		var legenda := Label.new()
		legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legenda.text = dados["tecla_nome"]
		legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legenda.position = Vector2(0, TAM_SLOT + 1.0)
		legenda.size = Vector2(TAM_SLOT, 20)
		legenda.add_theme_font_size_override("font_size", 17)
		legenda.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		if fonte:
			legenda.add_theme_font_override("font", fonte)
		legenda.visible = not no_controle
		slot.add_child(legenda)

		_slots.append({"raiz": slot, "painel": painel, "rotulo": rotulo, "legenda": legenda, "estilo": estilo, "cor": dados["cor"]})

	_realcar()


## Quem já passou fica apagado, o da vez fica grande e aceso, os próximos ficam
## pequenos e discretos.
func _realcar() -> void:
	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		var raiz: Control = slot["raiz"]
		if not is_instance_valid(raiz):
			continue
		if i == _indice:
			raiz.scale = Vector2(1.18, 1.18)
			raiz.modulate = Color(1, 1, 1, 1.0)
		elif i < _indice:
			raiz.scale = Vector2(0.78, 0.78)
			raiz.modulate = Color(1, 1, 1, 0.35)
		else:
			raiz.scale = Vector2(0.86, 0.86)
			raiz.modulate = Color(1, 1, 1, 0.55)


## Piscada de acerto (verde) ou de erro (vermelho) no botão que acabou de ser
## resolvido. O tween ignora o time_scale para não arrastar na câmera lenta.
func _reagir(i: int, acertou: bool) -> void:
	if i < 0 or i >= _slots.size():
		return
	var slot: Dictionary = _slots[i]
	var raiz: Control = slot["raiz"]
	var estilo: StyleBoxFlat = slot["estilo"]
	var rotulo: Label = slot["rotulo"]
	if not is_instance_valid(raiz):
		return

	var cor: Color = COR_ACERTO if acertou else COR_ERRO
	estilo.border_color = cor
	estilo.bg_color = Color(cor.r, cor.g, cor.b, 0.28)
	rotulo.add_theme_color_override("font_color", Color(1, 1, 1))
	_som(SOM_ACERTO if acertou else SOM_ERRO, 1.0 if acertou else 0.9)
	if acertou:
		# Tranco de confirmação: sutil de propósito, são até 5 ou 6 seguidos.
		_tremor()
		GlobalUtils.vibrate_controller(Input, 0.12, 0.28, 0.10)
	else:
		_mancha_vermelha()
		GlobalUtils.vibrate_controller(Input, 0.25, 0.6, 0.25)

	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(raiz, "scale", Vector2(1.42, 1.42), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(raiz, "scale", Vector2(0.9, 0.9), 0.10).set_trans(Tween.TRANS_SINE)
	if not acertou:
		# No erro a fileira inteira treme e some: o golpe morre aqui.
		t.parallel().tween_property(_coluna, "modulate", Color(1, 0.6, 0.6, 1.0), 0.10)
		t.tween_interval(0.18)
	await t.finished


## Tranco curto na câmera 3D ativa. Guarda o offset de origem uma vez só (como
## o `shake_camera` do GlobalUtils) para que trancos encadeados não acumulem
## deriva na câmera.
func _tremor() -> void:
	var cam := get_viewport().get_camera_3d()
	if not is_instance_valid(cam):
		return
	if _tremor_tween and _tremor_tween.is_valid():
		_tremor_tween.kill()
	else:
		_tremor_h_base = cam.h_offset
		_tremor_v_base = cam.v_offset

	_tremor_tween = create_tween()
	_tremor_tween.set_ignore_time_scale(true)
	var passo := TREMOR_DUR / float(TREMOR_PASSOS)
	for i in range(TREMOR_PASSOS):
		# Amortece: o primeiro solavanco é o mais forte, o resto vai morrendo.
		var queda: float = 1.0 - float(i) / float(TREMOR_PASSOS)
		var forca: float = TREMOR_FORCA * queda
		_tremor_tween.tween_property(cam, "h_offset", _tremor_h_base + randf_range(-forca, forca), passo)
		_tremor_tween.parallel().tween_property(cam, "v_offset", _tremor_v_base + randf_range(-forca, forca), passo)
	_tremor_tween.tween_property(cam, "h_offset", _tremor_h_base, 0.05)
	_tremor_tween.parallel().tween_property(cam, "v_offset", _tremor_v_base, 0.05)


## Corta um tremor pela metade e devolve a câmera ao lugar (poder cancelado).
func _parar_tremor() -> void:
	if _tremor_tween and _tremor_tween.is_valid():
		_tremor_tween.kill()
		var cam := get_viewport().get_camera_3d()
		if is_instance_valid(cam):
			cam.h_offset = _tremor_h_base
			cam.v_offset = _tremor_v_base
	_tremor_tween = null


## Piscada vermelha na tela toda quando o botão erra (ou o tempo acaba). Entra
## quase instantânea e sai em fade; dura menos que o `_reagir` do erro, então
## termina antes do painel sumir.
func _mancha_vermelha() -> void:
	if not is_instance_valid(_flash):
		return
	_flash.visible = true
	_flash.modulate = Color(1, 1, 1, 0.0)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_flash, "modulate:a", 1.0, 0.04)
	t.tween_property(_flash, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if is_instance_valid(_flash): _flash.visible = false
	)


## Vermelho mais aberto no meio e fechando nas bordas: tinge a tela inteira sem
## virar um retângulo chapado por cima da ação.
func _textura_mancha() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.78, 0.02, 0.03, 0.34),
		Color(0.60, 0.01, 0.02, 0.58),
		Color(0.32, 0.0, 0.0, 0.92),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _entrar() -> void:
	if not is_instance_valid(_raiz):
		return
	_raiz.visible = true
	_coluna.modulate = Color(1, 1, 1, 0.0)
	if is_instance_valid(_barra) and is_instance_valid(_trilho):
		_barra.size.x = _trilho.size.x
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_coluna, "modulate", Color(1, 1, 1, 1.0), 0.12)
	await t.finished


func _sair() -> void:
	if not is_instance_valid(_raiz):
		return
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_coluna, "modulate", Color(1, 1, 1, 0.0), 0.14)
	await t.finished
	if is_instance_valid(_raiz):
		_raiz.visible = false


## O AudioServer fica a 0.5x durante a cinemática; sem compensar o pitch o bip
## do QTE sairia arrastado e grave, parecendo erro de som.
func _som(caminho: String, pitch: float = 1.0) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(caminho)
	p.pitch_scale = clampf(pitch / maxf(AudioServer.playback_speed_scale, 0.05), 0.05, 4.0)
	add_child(p)
	p.play()
	p.finished.connect(func():
		if is_instance_valid(p): p.queue_free()
	)
