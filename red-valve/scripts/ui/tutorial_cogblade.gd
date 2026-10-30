extends CanvasLayer

## TUTORIAL DA COGBLADE (prólogo, primeira luta, contra o Cobalt Husker).
##
## Uns segundos depois de a luta começar o jogo PAUSA e a tela ensina: a
## cogblade é um item mágico, e para usá-la é preciso SACÁ-LA com o botão
## dela (`ui_cogblade_power`, LB / C). O tutorial só sai quando o jogador
## aperta esse botão — e o aperto já saca a cogblade de verdade
## (`player_cogblade_menu._empunhar_cogblade`).
##
## Quem cria: `battlefield.gd`, no fim da intro da arena do prólogo.

signal terminou

var player: Node

var _painel: PanelContainer
var _pode := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_painel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.03, 0.03, 0.92)
	estilo.border_color = Color(0.85, 0.12, 0.08, 0.9)
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(28)
	_painel.add_theme_stylebox_override("panel", estilo)
	_painel.custom_minimum_size = Vector2(640, 0)
	centro.add_child(_painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 16)
	_painel.add_child(coluna)

	var titulo := Label.new()
	titulo.text = tr("TUTORIAL_COGBLADE_TITULO")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18))
	coluna.add_child(titulo)

	var texto := Label.new()
	texto.text = tr("TUTORIAL_COGBLADE_PAD" if GlobalEvents.usando_controle else "TUTORIAL_COGBLADE_KEY")
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 22)
	coluna.add_child(texto)

	var acao := Label.new()
	acao.text = tr("TUTORIAL_COGBLADE_ACAO_PAD" if GlobalEvents.usando_controle else "TUTORIAL_COGBLADE_ACAO_KEY")
	acao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acao.add_theme_font_size_override("font_size", 24)
	acao.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	coluna.add_child(acao)
	var pulso := create_tween().set_loops()
	pulso.tween_property(acao, "modulate:a", 0.35, 0.6)
	pulso.tween_property(acao, "modulate:a", 1.0, 0.6)

	_painel.modulate.a = 0.0
	create_tween().tween_property(_painel, "modulate:a", 1.0, 0.35)
	# um respiro antes de aceitar: quem estava com o botão apertado não pula
	await get_tree().create_timer(0.6, true, false, true).timeout
	_pode = true


func _process(_delta: float) -> void:
	if not _pode:
		return
	if Input.is_action_just_pressed("ui_cogblade_power"):
		_pode = false
		_sacar()


func _sacar() -> void:
	get_tree().paused = false
	var menu: Node = null
	if is_instance_valid(player):
		for filho in player.get_children():
			if filho.has_method("_empunhar_cogblade"):
				menu = filho
				break
	if menu:
		menu._empunhar_cogblade()
	var t := create_tween()
	t.tween_property(_painel, "modulate:a", 0.0, 0.25)
	await t.finished
	terminou.emit()
	queue_free()
