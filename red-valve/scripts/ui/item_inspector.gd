extends CanvasLayer

@onready var pivot: Node3D = $SubViewportContainer/SubViewport/Pivot
var model_path: String = ""
var is_dragging: bool = false
var drag_sensitivity: float = 0.01
var joy_sensitivity: float = 3.0
var can_close: bool = false

signal inspector_closed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if model_path != "":
		var packed_model = load(model_path)
		if packed_model:
			var model_instance = packed_model.instantiate()
			pivot.add_child(model_instance)
			
			# Opcional: Centralizar o objeto
			var aabb = _calculate_aabb(model_instance)
			var center_offset = -aabb.get_center()
			model_instance.position = center_offset
			
			# Ajusta a escala para não ficar gigante ou minúsculo
			var max_size = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
			if max_size > 0.0:
				# Queremos que o objeto ocupe cerca de 0.5 unidades
				var scale_factor = 0.4 / max_size
				pivot.scale = Vector3(scale_factor, scale_factor, scale_factor)
				
	# Previne fechamento no mesmo frame que abriu
	await get_tree().create_timer(0.1).timeout
	can_close = true

func _calculate_aabb(node: Node3D) -> AABB:
	var aabb = AABB()
	var has_bounds = false
	
	if node is VisualInstance3D:
		aabb = node.get_aabb()
		has_bounds = true
		
	for child in node.get_children():
		if child is Node3D:
			var child_aabb = _calculate_aabb(child)
			if child_aabb.has_volume():
				var transformed_aabb = AABB(child.transform * child_aabb.position, child.transform.basis.get_scale() * child_aabb.size)
				if has_bounds:
					aabb = aabb.merge(transformed_aabb)
				else:
					aabb = transformed_aabb
					has_bounds = true
	return aabb

func _process(delta: float) -> void:
	var joy_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if joy_dir.length() > 0:
		pivot.rotate_y(joy_dir.x * joy_sensitivity * delta)
		pivot.rotate_x(joy_dir.y * joy_sensitivity * delta)

func _input(event: InputEvent) -> void:
	if not can_close: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
		elif event.pressed:
			close()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if is_dragging:
			pivot.rotate_y(event.relative.x * drag_sensitivity)
			pivot.rotate_x(event.relative.y * drag_sensitivity)
	elif event is InputEventKey and event.pressed:
		# Bloqueia o input e fecha se não for direcional de rotação
		if not event.is_action("ui_left") and not event.is_action("ui_right") and not event.is_action("ui_up") and not event.is_action("ui_down"):
			close()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		# Qualquer botão do controle fecha
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_dash") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		# Catch-all para acoes mapeadas que possam vazar
		close()
		get_viewport().set_input_as_handled()

func close():
	inspector_closed.emit()
	queue_free()
