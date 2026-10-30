extends CanvasLayer

## Tela de "você pegou X": o jogo para, o objeto aparece girando no meio da
## tela, com o texto embaixo, e qualquer botão continua.
##
## É prima do `item_inspector.gd` — mesmo truque de SubViewport com mundo
## próprio, para o modelo 3D aparecer por cima da cena sem sofrer a iluminação
## dela — mas com outro papel: o inspector é do menu e o jogador gira o objeto;
## aqui ele só olha. Por isso a rotação é automática e o único input aceito é
## "continuar".
##
## Quem abre passa `model_path` e `texto` ANTES de adicionar à árvore:
##
##     var tela = load("res://scenes/ui/item_obtido.tscn").instantiate()
##     tela.model_path = "res://.../lanterna.glb"
##     tela.texto = tr("PICKUP_FLASHLIGHT_L3")
##     get_tree().root.add_child(tela)
##     await tela.fechado
##
## O poder novo da cogblade usa a mesma tela, com o amuleto vestido da aura
## (`aura`), o nome do poder entrando depois do texto (`destaque`) e como usar
## embaixo dele (`detalhe`). Sem os três ela é a tela de sempre.

signal fechado

const AuraDoAmuleto := preload("res://scripts/systems/aura_do_amuleto.gd")
const COR_DESTAQUE := Color(0.78, 0.5, 1.0)
## O nome do poder entra um pouco depois do texto (que entra no fade).
const ESPERA_DESTAQUE := 0.7

const GIRO_POR_SEGUNDO := 0.7
## Só aceita "continuar" depois disto, contado a partir do fim do fade in. Sem
## essa folga a tela engolia o mesmo botão que a abriu e piscava.
const ESPERA_ANTES_DE_ACEITAR := 0.35
const FADE_ENTRADA := 0.55
const FADE_SAIDA := 0.45

@onready var pivot: Node3D = $SubViewportContainer/SubViewport/Pivot
@onready var rotulo: Label = $Texto
@onready var seta: Label = $Seta
@onready var dica: Label = $Dica
@onready var fade: ColorRect = $Fade

var model_path: String = ""
var texto: String = ""
var destaque: String = ""
var detalhe: String = ""
var aura: bool = false
var _aceita_input: bool = false
var _fechando: bool = false
var _piscar: float = 0.0


func _ready() -> void:
	# PROCESS_MODE_ALWAYS: a tela precisa continuar animando com a árvore
	# pausada — é ela que pausa o jogo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	rotulo.text = texto
	_atualizar_dica()
	_montar_modelo()
	if destaque != "":
		_montar_destaque()

	# Entra por fade: a tela nasce preta por cima de tudo e abre. Aparecer de
	# estalo no meio da ação é o que fazia isto parecer erro de cena em vez de
	# momento de jogo — e é a mesma cortina que fecha no fim.
	fade.color.a = 1.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade, "color:a", 0.0, FADE_ENTRADA)
	await tw.finished

	await get_tree().create_timer(ESPERA_ANTES_DE_ACEITAR, true, false, true).timeout
	_aceita_input = true


func _montar_modelo() -> void:
	if model_path == "" or not ResourceLoader.exists(model_path):
		return
	var packed: PackedScene = load(model_path)
	if packed == null:
		return
	var modelo: Node3D = packed.instantiate()
	pivot.add_child(modelo)
	# Centraliza e normaliza o tamanho: os modelos do jogo vêm em escalas bem
	# diferentes (o relógio é minúsculo, a lanterna tem 30 cm), e a tela tem de
	# mostrar os dois do mesmo jeito.
	var caixa := _aabb(modelo)
	modelo.position = -caixa.get_center()
	var maior: float = max(caixa.size.x, max(caixa.size.y, caixa.size.z))
	if maior > 0.0:
		var fator := 0.42 / maior
		pivot.scale = Vector3(fator, fator, fator)
	pivot.rotation = Vector3(0.25, 0.6, 0.0)
	if aura:
		AuraDoAmuleto.vestir(modelo, true, true)


## O texto sobe e o nome do poder entra embaixo dele, grande e roxo, com o
## "como usar" menor por baixo. Os dois aparecem depois do fade.
func _montar_destaque() -> void:
	rotulo.offset_top -= 90.0
	rotulo.offset_bottom -= 90.0
	var nome := Label.new()
	nome.name = "Destaque"
	nome.text = destaque
	nome.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nome.offset_top = -235.0
	nome.offset_bottom = -170.0
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 46)
	nome.add_theme_constant_override("outline_size", 8)
	nome.add_theme_color_override("font_color", COR_DESTAQUE)
	nome.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.14))
	add_child(nome)
	move_child(nome, fade.get_index())
	var linhas: Array[Control] = [nome]
	if detalhe != "":
		var uso := Label.new()
		uso.name = "Detalhe"
		uso.text = detalhe
		uso.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		uso.offset_top = -168.0
		uso.offset_bottom = -132.0
		uso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		uso.add_theme_font_size_override("font_size", 20)
		uso.add_theme_constant_override("outline_size", 5)
		uso.add_theme_color_override("font_color", Color(0.82, 0.8, 0.86))
		add_child(uso)
		move_child(uso, fade.get_index())
		linhas.append(uso)
	for l in linhas:
		l.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(FADE_ENTRADA + ESPERA_DESTAQUE)
	tw.tween_property(nome, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(nome, "scale", Vector2.ONE, 0.5).from(Vector2.ONE * 1.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if linhas.size() > 1:
		tw.tween_property(linhas[1], "modulate:a", 1.0, 0.4)
	nome.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 32.0)


func _aabb(no: Node3D) -> AABB:
	var caixa := AABB()
	var tem := false
	if no is VisualInstance3D:
		caixa = (no as VisualInstance3D).get_aabb()
		tem = true
	for filho in no.get_children():
		if not (filho is Node3D):
			continue
		var c := _aabb(filho)
		if not c.has_volume():
			continue
		var t := AABB(filho.transform * c.position,
			filho.transform.basis.get_scale() * c.size)
		if tem:
			caixa = caixa.merge(t)
		else:
			caixa = t
			tem = true
	return caixa


func _process(delta: float) -> void:
	pivot.rotate_y(GIRO_POR_SEGUNDO * delta)
	_piscar += delta
	seta.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_piscar * 4.0))
	_atualizar_dica()


## "Qualquer botão" no controle, "qualquer tecla" no teclado.
func _atualizar_dica() -> void:
	dica.text = tr("PICKUP_CONTINUE" if GlobalEvents.usando_controle else "PICKUP_CONTINUE_KEY")


func _input(event: InputEvent) -> void:
	if _fechando or not _aceita_input:
		return
	var vale: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if vale:
		get_viewport().set_input_as_handled()
		fechar()


func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade, "color:a", 1.0, FADE_SAIDA)
	await tw.finished
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# O botão que fechou esta tela costuma ser o mesmo do dash; sem isto o
	# Maycow sai em disparada no quadro seguinte (ver GlobalEvents).
	GlobalEvents.bloquear_dash_por(300)
	fechado.emit()
	queue_free()
