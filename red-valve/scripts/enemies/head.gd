extends Area3D
@onready var enemy: CharacterBody3D = $".."


func take_damage(damage:int)->void:
	enemy.take_damage(damage)
