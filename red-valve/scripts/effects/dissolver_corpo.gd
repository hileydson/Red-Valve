extends RefCounted

## O CORPO QUE QUEIMA E SOME — o dissolver da Dona Nice emprestado a qualquer
## modelo (o Maycow atravessando um portal).
##
## A Dona Nice já nasce com a pele `carne_igreja.gdshader` (`ator_igreja.gd`).
## O Maycow não: aqui cada superfície do modelo ganha, só durante o efeito, um
## material desse shader com a cor, a textura e a normal do material de antes;
## `restaurar()` devolve os originais.
##
##     var corpo = DissolverCorpo.vestir(raiz_do_modelo)
##     corpo.parametro("dissolver", 0.7)
##     corpo.restaurar()
##
## Sem `class_name` (ver [[project-class-name-travado]]): preload deste script.

const SHADER := preload("res://shaders/npcs/carne_igreja.gdshader")
const ESTE := "res://scripts/effects/dissolver_corpo.gd"
## As manchas da Dona Nice (escala_ruido 5 num modelo em metros).
const RUIDO_POR_METRO := 5.0

## [MeshInstance3D, superfície, material de override de antes (ou null)]
var _superficies: Array = []
## [MeshInstance3D, material_override de antes]
var _overrides: Array = []
var _materiais: Array[ShaderMaterial] = []


static func vestir(raiz: Node) -> RefCounted:
	var c = (load(ESTE) as GDScript).new()
	c._trocar(raiz)
	return c


func _trocar(raiz: Node) -> void:
	var malhas: Array = []
	if raiz is MeshInstance3D:
		malhas.append(raiz)
	malhas.append_array(raiz.find_children("*", "MeshInstance3D", true, false))
	for m in malhas:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		# o modelo do Maycow está em centímetros: a mancha se mede em metros
		var metros: float = mi.global_basis.get_scale().x
		var ruido := RUIDO_POR_METRO * (metros if metros > 0.0001 else 1.0)
		for s in mi.mesh.get_surface_count():
			var original := mi.get_active_material(s)
			var novo := ShaderMaterial.new()
			novo.shader = SHADER
			if original is BaseMaterial3D:
				var b := original as BaseMaterial3D
				novo.set_shader_parameter("albedo_cor", b.albedo_color)
				if b.albedo_texture:
					novo.set_shader_parameter("albedo_tex", b.albedo_texture)
				if b.normal_enabled and b.normal_texture:
					novo.set_shader_parameter("tem_normal", true)
					novo.set_shader_parameter("normal_tex", b.normal_texture)
					novo.set_shader_parameter("normal_forca", b.normal_scale)
				if b.roughness_texture:
					novo.set_shader_parameter("tem_orm", true)
					novo.set_shader_parameter("orm_tex", b.roughness_texture)
				novo.set_shader_parameter("rugosidade", b.roughness)
				novo.set_shader_parameter("metalico", b.metallic)
			novo.set_shader_parameter("escala_ruido", ruido)
			_superficies.append([mi, s, mi.get_surface_override_material(s)])
			mi.set_surface_override_material(s, novo)
			_materiais.append(novo)
		# material_override passa por cima do override por superfície
		if mi.material_override:
			_overrides.append([mi, mi.material_override])
			mi.material_override = null


func parametro(nome: String, valor) -> void:
	for m in _materiais:
		m.set_shader_parameter(nome, valor)


func restaurar() -> void:
	for s in _superficies:
		if is_instance_valid(s[0]):
			(s[0] as MeshInstance3D).set_surface_override_material(s[1], s[2])
	for o in _overrides:
		if is_instance_valid(o[0]):
			(o[0] as MeshInstance3D).material_override = o[1]
	_superficies.clear()
	_overrides.clear()
	_materiais.clear()
