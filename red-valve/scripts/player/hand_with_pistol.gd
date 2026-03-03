extends Node3D

@export_group("Sway (Mouse/Control)")
@export var sway_amount : float = 0.003
@export var sway_rotation : float = 0.003
@export var smoothness : float = 5.0
@export var stick_sensitivity : float = 20.0 # Sensibilidade específica para o analógico

@export_group("Bobbing (Caminhada)")
@export var bob_freq : float = 2.0
@export var bob_amp : float = 0.04
@export var bob_slant : float = 0.02

var mouse_input : Vector2
var initial_position : Vector3
var initial_rotation : Vector3
var bob_time : float = 0.0

func _ready():
	initial_position = transform.origin
	initial_rotation = rotation

func _input(event):
	if event is InputEventMouseMotion:
		mouse_input = event.relative

func _process(delta):
	# --- 1. CAPTURA DO ANALÓGICO (Look Actions) ---
	var joy_input = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
	
	# Se houver input do analógico, somamos ao mouse_input simulando um movimento relativo
	if joy_input.length() > 0.1:
		mouse_input += joy_input * stick_sensitivity

	# --- 2. LÓGICA DO BOBBING (Passos) ---
	var player = owner 
	var speed = player.velocity.length() if player and "velocity" in player else 0.0
	var is_on_floor = player.is_on_floor() if player and "is_on_floor" in player else false
	
	var bob_offset = Vector3.ZERO
	
	if is_on_floor and speed > 0.1:
		var pace = speed * 0.8 
		bob_time += delta * pace * bob_freq
		bob_offset.y = abs(sin(bob_time)) * bob_amp
		bob_offset.x = cos(bob_time * 0.5) * bob_slant
	else:
		bob_time = lerp(bob_time, 0.0, delta * 10.0) # Reseta suavemente
	
	# --- 3. LÓGICA DO SWAY (Cálculo) ---
	var sway_pos = Vector3(-mouse_input.x * sway_amount, mouse_input.y * sway_amount, 0)
	var sway_rot = Vector3(mouse_input.y * sway_rotation, -mouse_input.x * sway_rotation, 0)
	
	# --- 4. APLICAÇÃO FINAL ---
	var target_pos = initial_position + sway_pos + bob_offset
	var target_rot = initial_rotation + sway_rot
	
	transform.origin = transform.origin.lerp(target_pos, delta * smoothness)
	
	rotation.x = lerp_angle(rotation.x, target_rot.x, delta * smoothness)
	rotation.y = lerp_angle(rotation.y, target_rot.y, delta * smoothness)
	rotation.z = lerp_angle(rotation.z, target_rot.z, delta * smoothness)
	
	# Resetamos o input (importante para o efeito de mola voltar ao centro)
	mouse_input = Vector2.ZERO
