extends CanvasLayer

# Filtro de cel shading (estilo Borderlands) aplicado por cima do render 3D.
# Fica num CanvasLayer abaixo da HUD (layer 100) pra não desenhar contorno em
# cima de textos e ícones da interface.
#
# Teste rápido: F7 liga/desliga em tempo real. Se não curtir o visual, basta
# apagar este arquivo, o shader em shaders/post_process/cel_shading.gdshader e
# a chamada em player_hud.gd.

const SHADER_PATH := "res://shaders/post_process/cel_shading.gdshader"
const TOGGLE_KEY := KEY_F7
const WEAKER_KEY := KEY_F8
const STRONGER_KEY := KEY_F9

var enabled: bool = true
var rect: ColorRect

func set_intensity(value: float) -> void:
	# Chamado pelo setter de "cel_shading_intensity" no player.gd.
	if not is_instance_valid(rect): return
	(rect.material as ShaderMaterial).set_shader_parameter("amount", clampf(value, 0.0, 1.0))

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Garante que o shader enxergue o frame já renderizado embaixo dele.
	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer)

	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	# Valores de partida - mexa aqui pra calibrar o look
	# A intensidade sai do @export "cel_shading_intensity" lá no player.gd
	mat.set_shader_parameter("amount", 0.65)
	mat.set_shader_parameter("outline_thickness", 1.1)
	mat.set_shader_parameter("outline_threshold", 0.28) # Bordas nítidas, sem pegar ruído de textura
	mat.set_shader_parameter("outline_softness", 0.18)
	mat.set_shader_parameter("outline_color", Color(0.03, 0.03, 0.04))
	mat.set_shader_parameter("outline_opacity", 0.72)   # Traço bem visível, mas não preto puro
	mat.set_shader_parameter("posterize_levels", 11.0)
	mat.set_shader_parameter("saturation", 1.17)
	mat.set_shader_parameter("contrast", 1.06)
	mat.set_shader_parameter("dark_boost", 0.14)
	rect.material = mat

	add_child(rect)

	# Aplica o que estiver configurado no inspector do player
	var owner_player := get_parent()
	if owner_player:
		if "cel_shading_intensity" in owner_player:
			set_intensity(owner_player.cel_shading_intensity)
		if "cel_shading_enabled" in owner_player:
			enabled = owner_player.cel_shading_enabled

func _process(_delta: float) -> void:
	# Mesma regra da HUD: quando a cena é "pausada" atrás da arena do amuleto,
	# os CanvasLayers dela recebem esta meta e devem sumir.
	if has_meta("_was_visible_before_pause"):
		visible = false
		return
	visible = enabled

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return

	match event.keycode:
		TOGGLE_KEY:
			enabled = not enabled
			print("[CelShading] ", "ligado" if enabled else "desligado")
		WEAKER_KEY:
			_nudge_amount(-0.1)
		STRONGER_KEY:
			_nudge_amount(0.1)

func _nudge_amount(delta_amount: float) -> void:
	# Calibragem em tempo real: F8 enfraquece, F9 fortalece. Quando achar o
	# ponto certo, copie o valor impresso para o "amount" lá no _ready().
	var mat := rect.material as ShaderMaterial
	var value: float = clampf(mat.get_shader_parameter("amount") + delta_amount, 0.0, 1.0)
	mat.set_shader_parameter("amount", value)
	var owner_player := get_parent()
	if owner_player and "cel_shading_intensity" in owner_player:
		owner_player.set("cel_shading_intensity", value)
	print("[CelShading] amount = %.2f" % value)
