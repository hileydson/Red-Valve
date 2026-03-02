extends Node3D

@onready var battle_field: Node3D = $MeshInstance3D
@export var MAX_BATTLE_RADIUS = 10.0 # Tamanho máximo do campo
@onready var open_battle_sound: AudioStreamPlayer = $OpenBattleSound
@onready var open_battle_sound_back: AudioStreamPlayer = $OpenBattleSoundBack

func _ready():
	battle_field.visible = false
	battle_field.scale = Vector3.ZERO # Começa minúsculo

func _physics_process(delta):
	# ... seu código anterior ...
	
	if Input.is_action_just_pressed("ui_open_battle_field"):
		toggle_battle_field(true)
	
	if Input.is_action_just_released("ui_open_battle_field"):
		toggle_battle_field(false)

var tween_pulse: Tween # No topo do seu script
func toggle_battle_field(open: bool):
	# Tenta encontrar qualquer nó de Mesh que seja filho deste Node3D
	var mesh = find_child("*MeshInstance3D*", true, false)
	
	if not mesh:
		print("AVISO: Nenhum MeshInstance3D encontrado dentro de ", name)
		return

	var material = mesh.get_active_material(0)
	
	if not material:
		print("AVISO: O Mesh não possui um material no Slot 0")
		return

	if open:
		# --- ABRIR ---
		open_battle_sound.play()
		battle_field.visible = true
		var tween_open = create_tween().set_parallel(true)
		
		# Expande a escala (Seu código original)
		tween_open.tween_property(battle_field, "scale", Vector3(MAX_BATTLE_RADIUS, 1, MAX_BATTLE_RADIUS), 0.4)\
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
		# --- PISCAR (PULSAR) ---
		if tween_pulse: tween_pulse.kill()
		tween_pulse = create_tween().set_loops()
		
		# Oscila o Alpha (transparência)
		tween_pulse.tween_property(material, "albedo_color:a", 0.5, 0.8)
		tween_pulse.tween_property(material, "albedo_color:a", 0.1, 0.8)
		
	else:
		# --- FECHAR ---
		open_battle_sound_back.play()
		if tween_pulse: tween_pulse.kill()
		
		var tween_close = create_tween()
		
		# Primeiro diminui (Seu código original)
		tween_close.tween_property(battle_field, "scale", Vector3.ZERO, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# Garante que o Alpha volte ao normal para a próxima vez que abrir
		tween_close.parallel().tween_property(material, "albedo_color:a", 0.0, 0.2)
		
		# SÓ DEPOIS desativa o visible
		tween_close.tween_callback(func(): battle_field.visible = false)



func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and battle_field.visible:
		print("Inimigo detectado no alcance: ", body.name)
		# Aqui você pode ativar um contorno (outline) no inimigo ou marcá-lo como alvo
