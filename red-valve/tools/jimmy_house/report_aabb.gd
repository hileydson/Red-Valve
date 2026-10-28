extends Node

## Mede a caixa envolvente (em espaço local da raiz) de cada cena de móvel,
## para eu conseguir posicionar tudo sem abrir o editor no olho.

const ALVOS := [
	"res://assets/3d_model/mobilia/",
	"res://assets/3d_model/stages/prolog/armario.glb",
	"res://assets/3d_model/stages/prolog/mesa.glb",
	"res://assets/3d_model/stages/prolog/cozinha_armario.glb",
	"res://assets/3d_model/stages/prolog/gray_l-shaped_couch.glb",
	"res://assets/3d_model/stages/prolog/modern_entertainment_center_free.glb",
	"res://assets/3d_model/stages/prolog/quadro_3d.glb",
	"res://assets/3d_model/stages/prolog/mesa_telefone.glb",
]

func _ready() -> void:
	var saida := {}
	for alvo in ALVOS:
		if alvo.ends_with("/"):
			var dir := DirAccess.open(alvo)
			if dir == null: continue
			for f in dir.get_files():
				if f.ends_with(".tscn"):
					saida[alvo + f] = _medir(alvo + f)
		else:
			saida[alvo] = _medir(alvo)

	var arq := FileAccess.open("res://tools/jimmy_house/aabb.json", FileAccess.WRITE)
	arq.store_string(JSON.stringify(saida, "  "))
	arq.close()
	print("[aabb] escrito com %d entradas" % saida.size())
	get_tree().quit(0)


func _medir(caminho: String) -> Dictionary:
	var packed: PackedScene = load(caminho)
	if packed == null:
		return {"erro": "não carregou"}
	var no := packed.instantiate()
	add_child(no)
	var caixa := AABB()
	var primeiro := true
	for mi in _malhas(no):
		var b: AABB = (no as Node3D).global_transform.affine_inverse() * (mi.global_transform * mi.get_aabb())
		if primeiro:
			caixa = b
			primeiro = false
		else:
			caixa = caixa.merge(b)
	no.queue_free()
	return {
		"pos": [snappedf(caixa.position.x, 0.001), snappedf(caixa.position.y, 0.001), snappedf(caixa.position.z, 0.001)],
		"tam": [snappedf(caixa.size.x, 0.001), snappedf(caixa.size.y, 0.001), snappedf(caixa.size.z, 0.001)],
	}


func _malhas(no: Node) -> Array[MeshInstance3D]:
	var saida: Array[MeshInstance3D] = []
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		saida.append(no)
	for f in no.get_children():
		saida.append_array(_malhas(f))
	return saida
