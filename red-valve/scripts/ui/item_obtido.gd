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

signal fechado

const GIRO_POR_SEGUNDO := 0.7
const ESPERA_ANTES_DE_ACEITAR := 0.45   # não engole o mesmo botão que abriu
const FADE := 0.45

@onready var pivot: Node3D = $SubViewportContainer/SubViewport/Pivot
@onready var rotulo: Label = $Texto
@onready var seta: Label = $Seta
@onready var dica: Label = $Dica
@onready var fade: ColorRect = $Fade

var model_path: String = ""
var texto: String = ""
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
	dica.text = tr("PICKUP_CONTINUE")
	_montar_modelo()

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
	tw.tween_property(fade, "color:a", 1.0, FADE)
	await tw.finished
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# O botão que fechou esta tela costuma ser o mesmo do dash; sem isto o
	# Maycow sai em disparada no quadro seguinte (ver GlobalEvents).
	GlobalEvents.bloquear_dash_por(300)
	fechado.emit()
	queue_free()
