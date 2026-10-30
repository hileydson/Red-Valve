extends Node

## Peças com física que NASCEM no lugar errado: solta a física por uns
## segundos e lista os RigidBody3D que andaram (caíram de onde flutuavam,
## foram cuspidos de dentro de outra peça, atravessaram o piso). Uso:
##   godot --headless --path . res://tools/flutuantes/assentar.tscn -- <cena.tscn>

const SEGUNDOS := 3.0
const ANDOU := 0.05

func _ready() -> void:
	SaveManager.current_slot = 9
	var caminho: String = OS.get_cmdline_user_args()[0]
	var cena := (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(cena)
	await get_tree().process_frame
	var inicio := {}
	for c in cena.find_children("*", "RigidBody3D", true, false):
		inicio[c] = (c as Node3D).global_position
	print("CORPOS ", inicio.size())
	await get_tree().create_timer(SEGUNDOS, true, true).timeout
	var andaram: Array = []
	for c in inicio:
		if not is_instance_valid(c):
			continue
		var d: Vector3 = (c as Node3D).global_position - inicio[c]
		if d.length() > ANDOU:
			andaram.append([d.length(), str(cena.get_path_to(c)), inicio[c], d])
	andaram.sort_custom(func(a, b): return a[0] > b[0])
	print("ANDARAM ", andaram.size())
	for a in andaram:
		print("  %-55s de %s  andou %s" % [a[1], a[2].snappedf(0.01), a[3].snappedf(0.01)])
	get_tree().quit()
