extends Node3D

@onready var navigation_region_3d: NavigationRegion3D = $NavigationRegion3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass #navigation_region_3d.bake_navigation_mesh(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	navigation_region_3d.bake_navigation_mesh(true)
