extends Node


var current_time_tween: Tween = null

# --- SISTEMA DE MENSAGENS CENTRAIS GLOBAIS ---
var message_canvas_layer: CanvasLayer
var message_vbox: VBoxContainer
var active_messages: Dictionary = {}

# --- SISTEMA GLOBAL DE TEXTOS CINEMÁTICOS ---
var in_cinematic_cutscene: bool = false
var _cutscene_overlay: ColorRect
var _cutscene_label: Label
var _cutscene_audio: AudioStreamPlayer
var _cutscene_texts: Array = []
var _current_cutscene_idx: int = 0
var _cutscene_text_transitioning: bool = false
var _cutscene_text_gen: int = 0
var _cutscene_bars_node: Node = null
var _cutscene_skip_ui: Control = null
var _cutscene_skip_layer: CanvasLayer = null

signal cinematic_cutscene_finished

# ---------------------------------------------------------------------------
# Troca de estado de AnimationTree à prova de estado inexistente
# ---------------------------------------------------------------------------
## UM ÚNICO `playback.travel()` para um estado que a máquina não tem deixa a
## AnimationTree tentando resolver aquele estado PARA SEMPRE: o próprio motor
## reimprime o erro todo quadro dali em diante, mesmo que ninguém chame
## `travel()` de novo. Num PC rápido o spam passa batido; num aparelho mais
## lento (foi relatado num Steam Deck rodando o build via Proton) só o custo de
## imprimir isso 60x por segundo já trava o jogo de vez.
##
## Por isso NINGUÉM deve chamar `playback.travel()` direto — use isto.
## Devolve true se o travel realmente aconteceu.
var _travels_ja_avisados: Dictionary = {}

## Onde mora o `playback` depende de COMO a arvore esta montada: com a maquina
## de estados na raiz o caminho e' "parameters/playback"; aninhada dentro de um
## BlendTree (caso do Maycow normal, que ganhou um TimeScale pra rampa de
## velocidade do giro) vira "parameters/<no>/playback". Procurar em vez de
## assumir deixa os dois formatos funcionando — inclusive se a montagem de
## alguma arvore mudar de novo la' na frente.
func achar_playback(tree: AnimationTree):
	if not is_instance_valid(tree):
		return null
	var pb = tree.get("parameters/playback")
	if pb != null:
		return pb
	var blend := tree.tree_root as AnimationNodeBlendTree
	if blend != null:
		for nome in blend.get_node_list():
			pb = tree.get("parameters/%s/playback" % nome)
			if pb != null:
				return pb
	return null


func safe_travel(tree: AnimationTree, estado: StringName) -> bool:
	if not is_instance_valid(tree):
		return false
	var playback = achar_playback(tree)
	if playback == null:
		return false

	var maquina := _achar_state_machine(tree.tree_root)
	if maquina == null or not maquina.has_node(estado):
		# Avisa UMA vez por (árvore, estado): o objetivo é aparecer no log sem
		# virar o mesmo spam que estamos evitando.
		var caminho := str(tree.get_path()) if tree.is_inside_tree() else str(tree)
		var chave := "%s|%s" % [caminho, estado]
		if not _travels_ja_avisados.has(chave):
			_travels_ja_avisados[chave] = true
			push_warning("safe_travel: estado '%s' nao existe na AnimationTree '%s' — travel ignorado." % [estado, caminho])
		return false

	playback.travel(estado)
	return true


## O `tree_root` nem sempre É a máquina de estados: pode ser um
## AnimationNodeBlendTree com a máquina pendurada dentro. Nesse caso um
## `as AnimationNodeStateMachine` seco devolve null e a checagem seria pulada.
func _achar_state_machine(no: AnimationNode) -> AnimationNodeStateMachine:
	if no == null:
		return null
	var direto := no as AnimationNodeStateMachine
	if direto != null:
		return direto
	var blend := no as AnimationNodeBlendTree
	if blend != null:
		for nome in blend.get_node_list():
			var achado := _achar_state_machine(blend.get_node(nome))
			if achado != null:
				return achado
	return null


## Rede de segurança da volta da arena.
##
## A sequência final da batalha liga `GlobalEvents.in_cutscene` (que bloqueia
## TODO o input do jogador) e só desliga depois de uma espera longa + troca de
## cena. Essa corrotina vive no nó da arena — justamente o nó que a troca
## destrói. Se ela morrer no meio, `in_cutscene` fica ligado para sempre: sem
## input, câmera parada na arena, e o áudio da stage_1 (que nunca parou, porque
## AudioStreamPlayer tocando ignora process_mode) continuando por cima. Era
## exatamente esse o travamento relatado.
##
## Este watchdog roda num autoload, então sobrevive à troca de cena.
func watchdog_volta_da_arena(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout
	if not GlobalEvents.arena_retorno_pendente:
		return # a volta terminou direitinho

	GlobalEvents.arena_retorno_pendente = false
	push_warning("Volta da arena nao terminou em %.0fs — destravando input e time_scale." % segundos)
	GlobalEvents.in_cutscene = false
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0


# ---------------------------------------------------------------------------
# OBJETIVOS / PISTAS — aviso discreto no canto superior esquerdo
# ---------------------------------------------------------------------------
## Diferente do `show_center_message`, que planta o texto no meio da tela e
## interrompe, este e' periferico e informativo: entra devagar, fica um tempo e
## sai sozinho, sem pedir atencao. E' a pista do que o jogador deve fazer agora.
##
## Uso: GlobalUtils.mostrar_objetivo(tr("OBJ_X"))  -> 30s por padrao
##      GlobalUtils.mostrar_objetivo(tr("OBJ_X"), 0.0)  -> fica ate' mandarem sair
##      GlobalUtils.esconder_objetivo()
##
## Entra e sai sempre em fade (OBJETIVO_FADE), nos dois sentidos.
##
## So aparece para o Maycow NORMAL. Na arena (Maycow de combate) e durante
## cutscene ele some sozinho e volta depois — inclusive um objetivo de duracao
## longa sobrevive a ida e volta da batalha sem precisar ser remontado.
const OBJETIVO_MARGEM_ESQ := 30.0
## Abaixo do minimapa, que ocupa y 26..216 nesse mesmo canto — sem isto o texto
## cairia em cima dele.
const OBJETIVO_MARGEM_TOPO := 232.0
const OBJETIVO_FADE := 0.6
const OBJETIVO_DURACAO_PADRAO := 30.0

var _objetivo_layer: CanvasLayer
var _objetivo_label: Label
## Cada chamada recebe um numero. Se outro objetivo entrar antes de o tempo do
## anterior acabar, o timer do antigo percebe que ficou pra tras e nao apaga o
## texto novo.
var _objetivo_geracao: int = 0


func mostrar_objetivo(texto: String, duracao: float = OBJETIVO_DURACAO_PADRAO) -> void:
	_montar_objetivo()
	_objetivo_geracao += 1
	var geracao := _objetivo_geracao

	_objetivo_label.text = texto
	var entrada := create_tween()
	entrada.bind_node(_objetivo_label)
	entrada.tween_property(_objetivo_label, "modulate:a", 1.0, OBJETIVO_FADE)

	if duracao <= 0.0:
		return

	# `false` no process_always: o relogio para junto com o jogo, entao abrir o
	# menu no meio nao come o tempo do aviso.
	await get_tree().create_timer(duracao, false).timeout
	if geracao != _objetivo_geracao:
		return # outro objetivo tomou o lugar deste
	esconder_objetivo()


func esconder_objetivo() -> void:
	if not is_instance_valid(_objetivo_label):
		return
	# Invalida qualquer timer pendente, senao ele apagaria um objetivo futuro.
	_objetivo_geracao += 1
	var saida := create_tween()
	saida.bind_node(_objetivo_label)
	saida.tween_property(_objetivo_label, "modulate:a", 0.0, OBJETIVO_FADE)


func _montar_objetivo() -> void:
	if is_instance_valid(_objetivo_label):
		return

	# Camada propria (118, logo abaixo das mensagens centrais em 120): assim o
	# `clear_all_messages` nao leva o objetivo junto, e uma mensagem central
	# importante ainda aparece por cima dele.
	_objetivo_layer = CanvasLayer.new()
	_objetivo_layer.layer = 118
	add_child(_objetivo_layer)

	_objetivo_label = Label.new()
	_objetivo_label.position = Vector2(OBJETIVO_MARGEM_ESQ, OBJETIVO_MARGEM_TOPO)
	_objetivo_label.add_theme_font_size_override("font_size", 16)
	# Cinza claro, nao branco puro: informativo, nao um alerta.
	_objetivo_label.add_theme_color_override("font_color", Color(0.82, 0.80, 0.76))
	_objetivo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_objetivo_label.add_theme_constant_override("outline_size", 4)
	_objetivo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objetivo_label.modulate.a = 0.0
	_objetivo_layer.add_child(_objetivo_label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	message_canvas_layer = CanvasLayer.new()
	message_canvas_layer.layer = 120
	add_child(message_canvas_layer)
	
	message_vbox = VBoxContainer.new()
	message_vbox.set_anchors_preset(Control.PRESET_CENTER)
	message_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	message_vbox.add_theme_constant_override("separation", 20)
	message_vbox.process_mode = Node.PROCESS_MODE_PAUSABLE
	message_canvas_layer.add_child(message_vbox)

func play_ui_sound(sound_path: String) -> void:
	if ResourceLoader.exists(sound_path):
		var p = AudioStreamPlayer.new()
		p.stream = load(sound_path)
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func show_center_message(message_id: String, text: String, font_size: int = 18, duration: float = 0.0) -> void:
	var label: Label
	if active_messages.has(message_id):
		label = active_messages[message_id]
	else:
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(800, 0)
		label.add_theme_constant_override("outline_size", 5)
		label.modulate.a = 0.0
		message_vbox.add_child(label)
		active_messages[message_id] = label
		
		# Animação de entrada
		var tween = create_tween()
		tween.bind_node(label)
		tween.tween_property(label, "modulate:a", 1.0, 0.5)

	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	
	if duration > 0.0:
		# Verifica se a label ainda existe e se o ID não foi sobrescrito ou apagado nesse meio tempo
		await get_tree().create_timer(duration, false).timeout
		hide_center_message(message_id)

func hide_center_message(message_id: String) -> void:
	if active_messages.has(message_id):
		var label = active_messages[message_id]
		active_messages.erase(message_id)
		
		if is_instance_valid(label):
			var tween = create_tween()
			tween.bind_node(label)
			tween.tween_property(label, "modulate:a", 0.0, 0.5)
			await tween.finished
			if is_instance_valid(label):
				label.queue_free()

## Aviso de "novo arquivo desbloqueado", o unico aviso do jogo que nao nasce de
## uma acao do jogador — ele cai no meio do que estiver acontecendo. Por isso
## NUNCA entra durante cutscene: fica esperando a cutscene acabar e so entao
## aparece. Sem isso o aviso brigava com a cena (ex: a intro do Capitulo 1) e o
## setter de in_cutscene ainda podia apaga-lo no meio, via clear_all_messages().
func show_new_file_message(id: String) -> void:
	var cena := get_tree().current_scene
	while _em_cutscene():
		await get_tree().process_frame
		# Trocou de cena enquanto esperava: o aviso perdeu o contexto, desiste.
		if get_tree().current_scene != cena:
			return
		# Respiro depois da cutscene, pra nao emendar no ultimo quadro dela.
		if not _em_cutscene():
			await get_tree().create_timer(1.0, false).timeout
			if get_tree().current_scene != cena:
				return

	show_center_message("novo_arquivo",
		tr("FILES_NEW") % ArquivosDados.titulo(id), 18, 5.0)


func _em_cutscene() -> bool:
	return GlobalEvents.in_cutscene or in_cinematic_cutscene


func clear_all_messages() -> void:
	for id in active_messages.keys():
		var label = active_messages[id]
		if is_instance_valid(label):
			label.queue_free()
	active_messages.clear()

# Limpa IMEDIATAMENTE (sem tween/await) qualquer mensagem central ou texto cinemático
# que esteja na tela. Usado ao sair pro menu principal, já que essas mensagens vivem
# neste autoload e não são destruídas junto com a cena do jogo.
func force_clear_all_screen_messages() -> void:
	clear_all_messages()

	# O objetivo mora neste autoload, entao sobrevive a troca de cena: sem isto
	# ele ficaria flutuando por cima do menu principal.
	_objetivo_geracao += 1
	if is_instance_valid(_objetivo_label):
		_objetivo_label.modulate.a = 0.0

	if is_instance_valid(_cutscene_skip_ui):
		_cutscene_skip_ui.queue_free()
	_cutscene_skip_ui = null

	if is_instance_valid(_cutscene_label):
		_cutscene_label.queue_free()
	_cutscene_label = null

	if is_instance_valid(_cutscene_overlay):
		_cutscene_overlay.queue_free()
	_cutscene_overlay = null

	_cutscene_text_transitioning = false
	in_cinematic_cutscene = false

func ativar_camera_lenta(escala: float, duracao: float, sound:bool):
	Engine.time_scale = escala
	
	if sound:
		AudioServer.set_playback_speed_scale(escala)
	
	await get_tree().create_timer(duracao * escala, true, false, true).timeout
	
	if current_time_tween and current_time_tween.is_valid():
		current_time_tween.kill()
		
	current_time_tween = create_tween()
	current_time_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_time_tween.tween_property(Engine, "time_scale", 1.0, 0.2)
	
	if sound:
		current_time_tween.finished.connect(func():
			AudioServer.set_playback_speed_scale(1.0)
		)


func ativar_camera_lenta_com_fim(escala: float, duracao: float, sound:bool):
	Engine.time_scale = escala
	
	if sound:
		AudioServer.set_playback_speed_scale(escala)
	
	await get_tree().create_timer(duracao * escala, true, false, true).timeout
	
	if current_time_tween and current_time_tween.is_valid():
		current_time_tween.kill()
		
	current_time_tween = create_tween()
	current_time_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_time_tween.tween_property(Engine, "time_scale", 1.0, 0.2)
	current_time_tween.finished.connect(func(): 
		remover_camera_lenta()
	)
	
func remover_camera_lenta():
	# 1. Volta a velocidade do motor ao normal imediatamente
	Engine.time_scale = 1.0
	
	# 2. Volta o áudio ao normal (usando o AudioServer que configuraste antes)
	AudioServer.set_playback_speed_scale(1.0)
	
	# 3. Se estiveres a usar Tweens para suavizar o tempo, é bom matá-los 
	# para evitar que eles tentem continuar a mudar o time_scale
	# Exemplo: se guardaste o tween numa variável 'tween_tempo'
	# if tween_tempo and tween_tempo.is_valid():
	#    tween_tempo.kill()
	

# --- LIMPEZA AO VOLTAR PARA O MENU PRINCIPAL ---
# Ao entrar na arena do amuleto, a cena anterior NÃO sai da árvore: ela vira
# irmã da current_scene, só escondida e sem processar (ver player_amulet.gd).
# Como change_scene_to_file() só destrói a current_scene, sair do jogo dali
# (morrendo na arena ou pelo menu de pausa) deixava aquela cena inteira viva
# por trás do menu principal. Sintomas:
#   - a HUD daquela cena continuava na tela (o CanvasLayer dela é
#     PROCESS_MODE_ALWAYS e se remarca visível todo frame, mesmo com a cena
#     desligada);
#   - o sangue dos inimigos, que é adicionado direto na root, também ficava;
#   - ao dar load, existiam dois Terrain3D na árvore ao mesmo tempo e o chão
#     perdia a textura.
# Esta função precisa ser chamada ANTES de trocar para o menu principal.
func cleanup_gameplay_leftovers() -> void:
	var tree := get_tree()
	if tree == null: return

	if is_instance_valid(GlobalEvents.paused_scene_for_amulet):
		var cena: Node = GlobalEvents.paused_scene_for_amulet
		# Tira da árvore na hora (não só queue_free) para o Terrain3D dela sair
		# de cena antes de qualquer outra ser carregada.
		if cena.get_parent():
			cena.get_parent().remove_child(cena)
		cena.queue_free()
	GlobalEvents.paused_scene_for_amulet = null
	GlobalEvents.amulet_captured_enemies.clear()

	# Nós soltos pendurados direto na root sobrevivem à troca de cena
	for child in tree.root.get_children():
		if child == tree.current_scene: continue
		if child.scene_file_path == "res://scenes/enemies/blood.tscn":
			child.queue_free()

	force_clear_all_screen_messages()

	# Nenhum poder/cinemática pode deixar o tempo travado no menu
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0

# --- ESCONDER/RESTAURAR CANVASLAYERS DE UMA CENA PAUSADA ---
# Node3D.visible = false NÃO esconde CanvasLayers (ex: HUD, textos de
# capítulo), pois eles não fazem parte da árvore de visibilidade 3D. Isso é
# usado ao pausar uma cena (ex: entrando na arena de batalha via amuleto) para
# que textos/UI daquela cena não fiquem "grudados" na tela por cima da nova
# cena. Guarda o estado de visibilidade original em cada CanvasLayer via meta,
# para restaurar exatamente como estava (em vez de forçar tudo para visível).
func set_canvas_layers_hidden(node: Node, hide: bool) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			if hide:
				child.set_meta("_was_visible_before_pause", child.visible)
				child.visible = false
			else:
				if child.has_meta("_was_visible_before_pause"):
					child.visible = child.get_meta("_was_visible_before_pause")
					child.remove_meta("_was_visible_before_pause")
				else:
					child.visible = true
		set_canvas_layers_hidden(child, hide)

func vibrate_controller(_input_obj:Variant, low_strengh:float, high_strengh:float, time:float):
	if Input:
		Input.start_joy_vibration(0,low_strengh, high_strengh, time)
	
var current_shake_tween: Tween = null
var base_h_offset: float = 0.0
var base_v_offset: float = 0.0

# No script da sua Camera3D
func shake_camera(duracao: float, forca: float):
	var camera = get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	
	if current_shake_tween and current_shake_tween.is_valid():
		# Se já está tremendo, nós matamos o tween antigo para prolongar com o novo,
		# mas NÃO pegamos a posição atual como original, usamos a que já tínhamos gravado!
		current_shake_tween.kill()
	else:
		# Se não estava tremendo, a posição atual é a original verdadeira
		base_h_offset = camera.h_offset
		base_v_offset = camera.v_offset
	
	current_shake_tween = create_tween()
	
	# Cria várias posições aleatórias rápidas
	for i in range(10):
		var offset_random = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
		current_shake_tween.tween_property(camera, "h_offset", base_h_offset + offset_random.x, duracao / 10)
		current_shake_tween.tween_property(camera, "v_offset", base_v_offset + offset_random.y, duracao / 10)
	
	# Volta para a posição original no final
	current_shake_tween.tween_property(camera, "h_offset", base_h_offset, 0.1)
	current_shake_tween.tween_property(camera, "v_offset", base_v_offset, 0.1)


# =========================================================================
# SISTEMA GLOBAL DE TEXTOS CINEMÁTICOS
# =========================================================================

func show_cutscene_bars() -> void:
	if get_tree().current_scene:
		_cutscene_bars_node = get_tree().current_scene.find_child("cutscene", true, false)
		if _cutscene_bars_node:
			_cutscene_bars_node.visible = true
			var t = create_tween().set_parallel(true)
			for child in _cutscene_bars_node.get_children():
				if child is ColorRect and child.name != "fade":
					child.modulate.a = 0.0
					t.tween_property(child, "modulate:a", 1.0, 1.0)

func hide_cutscene_bars() -> void:
	if _cutscene_bars_node:
		var t = create_tween().set_parallel(true)
		for child in _cutscene_bars_node.get_children():
			if child is ColorRect and child.name != "fade":
				t.tween_property(child, "modulate:a", 0.0, 1.0)
		t.chain().tween_callback(func():
			if is_instance_valid(_cutscene_bars_node):
				_cutscene_bars_node.visible = false
				_cutscene_bars_node = null
		)

func start_cinematic_text_cutscene(texts: Array) -> void:
	in_cinematic_cutscene = true
	_cutscene_texts = texts
	_current_cutscene_idx = 0
	_cutscene_text_transitioning = true
	
	if not message_canvas_layer:
		_ready()
		
	if not _cutscene_skip_ui:
		# Camada própria, acima da barra preta do "cutscene" (CanvasLayer, layer 150),
		# pra garantir que o aparato de segurar-pra-skip fique sempre por CIMA das barras.
		if not is_instance_valid(_cutscene_skip_layer):
			_cutscene_skip_layer = CanvasLayer.new()
			_cutscene_skip_layer.layer = 155
			add_child(_cutscene_skip_layer)
		_cutscene_skip_ui = load("res://scripts/ui/skip_cutscene_ui.gd").new()
		_cutscene_skip_layer.add_child(_cutscene_skip_ui)
		_cutscene_skip_ui.skipped.connect(_on_cinematic_skipped)
			
	if not _cutscene_audio:
		_cutscene_audio = AudioStreamPlayer.new()
		var typing_sound_path = "res://assets/sounds/episodios/prologo/typing.mp3"
		if ResourceLoader.exists(typing_sound_path):
			_cutscene_audio.stream = load(typing_sound_path)
		add_child(_cutscene_audio)
		
	if not _cutscene_overlay:
		_cutscene_overlay = ColorRect.new()
		_cutscene_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cutscene_overlay.color = Color(0.05, 0.05, 0.05, 0.85)
		_cutscene_overlay.modulate.a = 0.0
		message_canvas_layer.add_child(_cutscene_overlay)
		
		_cutscene_label = Label.new()
		_cutscene_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_cutscene_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_cutscene_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_cutscene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cutscene_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cutscene_label.add_theme_font_override("font", load("res://assets/fonts/Montserrat-ExtraBold.ttf"))
		_cutscene_label.add_theme_font_size_override("font_size", 28)
		
		_cutscene_label.add_theme_color_override("font_color", Color.WHITE)
		_cutscene_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		_cutscene_label.add_theme_constant_override("shadow_outline_size", 4)
		_cutscene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_cutscene_label.custom_minimum_size = Vector2(800, 0)
		_cutscene_label.modulate.a = 0.0
		message_canvas_layer.add_child(_cutscene_label)
		
	# Adjust overlay to not cover the black cinematic bars if they are active
	if _cutscene_bars_node and _cutscene_bars_node.visible:
		_cutscene_overlay.offset_top = 157
		_cutscene_overlay.offset_bottom = -142
	else:
		_cutscene_overlay.offset_top = 0
		_cutscene_overlay.offset_bottom = 0
		
	var t = create_tween()
	t.tween_property(_cutscene_overlay, "modulate:a", 1.0, 1.0)
	await get_tree().create_timer(1.0).timeout
	
	_show_next_cinematic_text()

func _show_next_cinematic_text() -> void:
	if _current_cutscene_idx < _cutscene_texts.size():
		var full_text = tr(_cutscene_texts[_current_cutscene_idx])
		_cutscene_label.text = full_text
		_cutscene_label.visible_characters = 0
		_cutscene_label.modulate.a = 1.0
		
		_cutscene_text_transitioning = true
		_cutscene_text_gen += 1
		var my_gen = _cutscene_text_gen
		
		for i in range(full_text.length()):
			if my_gen != _cutscene_text_gen: return
			if _cutscene_label.visible_characters >= full_text.length(): break
			
			_cutscene_label.visible_characters += 1
			if full_text[i] != " " and is_instance_valid(_cutscene_audio) and _cutscene_audio.stream != null:
				# Variação sutil no som para aumentar a imersão
				_cutscene_audio.pitch_scale = randf_range(0.85, 1.15)
				_cutscene_audio.volume_db = randf_range(-22.0, -16.0)
				_cutscene_audio.play()
				
			await get_tree().create_timer(0.05).timeout
			
		_cutscene_text_transitioning = false
	else:
		_end_cinematic_text()

func _on_cinematic_skipped() -> void:
	_current_cutscene_idx = _cutscene_texts.size()
	_cutscene_text_gen += 1
	_end_cinematic_text()

func _process(delta: float) -> void:
	# O objetivo e' informacao do Maycow NORMAL: some na arena (Maycow de
	# combate) e durante cutscene, em vez de ficar pendurado por cima delas.
	# Some, nao apaga — um objetivo permanente continua la' quando ele voltar.
	if is_instance_valid(_objetivo_layer):
		_objetivo_layer.visible = GlobalEvents.is_maycow_normal and not _em_cutscene()

	if in_cinematic_cutscene:
		if Input.is_action_just_pressed("ui_accept"):
			if _cutscene_text_transitioning and _cutscene_label and _cutscene_label.visible_characters < _cutscene_label.text.length():
				_cutscene_label.visible_characters = _cutscene_label.text.length()
				_cutscene_text_transitioning = false
			elif not _cutscene_text_transitioning:
				_cutscene_text_transitioning = true
				var t = create_tween()
				if _cutscene_label:
					t.tween_property(_cutscene_label, "modulate:a", 0.0, 0.3)
				await t.finished
				_current_cutscene_idx += 1
				_show_next_cinematic_text()

func _end_cinematic_text() -> void:
	_cutscene_text_transitioning = true
	var t = create_tween()
	if _cutscene_overlay is CanvasItem: t.tween_property(_cutscene_overlay, "modulate:a", 0.0, 1.0)
	if _cutscene_label is CanvasItem: t.parallel().tween_property(_cutscene_label, "modulate:a", 0.0, 1.0)
	
	if _cutscene_skip_ui:
		if _cutscene_skip_ui is CanvasItem:
			var skip_t = create_tween()
			skip_t.tween_property(_cutscene_skip_ui, "modulate:a", 0.0, 0.5)
	
	# Start song immediately if skipped and we need to play battle song? 
	# Wait, user said: "quando acontece o skipe... o som que nao foi iniciado antes deve se iniciar já que nao houve a cutscene para iniciar ele... o nome é SongFirstBattle do som"
	# That logic should probably be in the stage script, or we emit a signal and pass skipped state.
	
	await t.finished
	
	if _cutscene_skip_ui:
		_cutscene_skip_ui.queue_free()
		_cutscene_skip_ui = null
		
	if _cutscene_label:
		_cutscene_label.queue_free()
		_cutscene_label = null
		
	if _cutscene_overlay:
		_cutscene_overlay.queue_free()
		_cutscene_overlay = null
	
	in_cinematic_cutscene = false

	cinematic_cutscene_finished.emit()
