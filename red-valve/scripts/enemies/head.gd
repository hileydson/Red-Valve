extends Area3D
@onready var enemy: CharacterBody3D = $".."

var _critical_light: OmniLight3D

func _ready() -> void:
	_critical_light = OmniLight3D.new()
	_critical_light.light_color = Color(1.0, 0.0, 0.0)
	_critical_light.light_energy = 0.5
	_critical_light.omni_range = 1.0
	add_child(_critical_light)
	
	var tween = create_tween().set_loops()
	tween.tween_property(_critical_light, "light_energy", 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_critical_light, "light_energy", 0.5, 0.6).set_trans(Tween.TRANS_SINE)

func take_damage(damage:int)->void:
	var final_damage = int(damage * 1.2)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(final_damage)
