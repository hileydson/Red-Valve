@tool
extends Node3D
## Luz em cada poste, para a cidade à noite.
##
## SpotLight3D em vez de OmniLight3D: a luminária tipo cobra joga um cone no
## chão, e o cone é mais barato de descartar que uma esfera. Sombra desligada
## por padrão — 296 luzes com sombra derrubam o renderer mobile; a mancha de
## luz no chão é o que se vê, não a sombra do poste.
##
## `distance_fade` é o que torna 296 luzes viáveis: só as próximas ficam
## ligadas, o resto some antes de custar.

@export var luzes_json: String = "res://assets/3d_model/city/poles.json"

@export_group("Luz")
## Sódio: o laranja característico da iluminação pública brasileira.
@export var cor: Color = Color(1.0, 0.72, 0.42)
@export var energia: float = 16.0
@export var alcance: float = 17.0
## Meia-abertura do cone. 58° dava 116° de abertura total — a rua inteira
## acendia e o ambiente perdia o escuro.
@export var angulo: float = 30.0
@export var atenuacao_angulo: float = 1.1
@export var atenuacao: float = 0.9

@export_group("Lente acesa")
## Sem isto a luz aparece no chão mas a luminária fica apagada, e o poste
## não parece a fonte. Um MultiMesh de quadros emissivos: 1 draw call.
@export var lente: bool = true
@export var lente_tamanho: Vector2 = Vector2(0.62, 0.20)
@export var lente_brilho: float = 6.0
## Inclinação a partir da vertical, na direção do braço.
@export var inclinacao_graus: float = 12.0

@export_group("Custo")
@export var sombra: bool = false
@export var fade_inicio: float = 55.0
@export var fade_comprimento: float = 25.0

@export_multiline var last_result: String = ""

@export var construir: bool = false:
	set(v):
		construir = false
		if v and Engine.is_editor_hint():
			_construir()

@export var limpar: bool = false:
	set(v):
		limpar = false
		if v and Engine.is_editor_hint():
			_limpar()


func _limpar() -> int:
	var n := 0
	for c in get_children():
		remove_child(c)
		c.free()
		n += 1
	return n


func _construir() -> void:
	var txt := FileAccess.get_file_as_string(luzes_json)
	if txt.is_empty():
		last_result = "ERRO: não consegui ler %s" % luzes_json
		return
	var dados = JSON.parse_string(txt)
	if typeof(dados) != TYPE_DICTIONARY or not dados.has("luzes"):
		last_result = "ERRO: poles.json inválido"
		return

	var removidas := _limpar()
	var n := 0
	for L in dados["luzes"]:
		var luz := SpotLight3D.new()
		luz.name = "PoleLight_%03d" % n
		luz.light_color = cor
		luz.light_energy = energia
		luz.spot_range = alcance
		luz.spot_angle = angulo
		luz.spot_angle_attenuation = atenuacao_angulo
		luz.spot_attenuation = atenuacao
		luz.shadow_enabled = sombra
		luz.distance_fade_enabled = true
		luz.distance_fade_begin = fade_inicio
		luz.distance_fade_length = fade_comprimento
		luz.distance_fade_shadow = fade_inicio * 0.5

		# Cone para baixo, inclinado NA DIREÇÃO DO BRAÇO — ou seja, para
		# dentro da pista. A composição anterior (UP * RIGHT) inclinava numa
		# direção perpendicular ao braço, jogando a poça para a calçada.
		var r: float = float(L["rot"])
		# Verificado por cálculo: com este sinal o centro do cone cai sobre a
		# pista em 286 dos 296 postes; com o sinal trocado, em apenas 51.
		var braco := Vector3(cos(r), 0.0, sin(r))
		var t := deg_to_rad(inclinacao_graus)
		var dir := (braco * sin(t) + Vector3.DOWN * cos(t)).normalized()
		var b := Basis.looking_at(dir, braco)
		luz.transform = Transform3D(b, Vector3(
			float(L["x"]), float(L["y"]), float(L["z"])))
		add_child(luz)
		luz.owner = get_tree().edited_scene_root
		n += 1

	var nl := 0
	if lente:
		nl = _lentes(dados["luzes"])

	last_result = ("%d luzes + %d lentes | cone %.0f° | alcance %.0f m | "
		+ "sombra=%s | fade %.0f–%.0f m") % [
		n, nl, angulo * 2.0, alcance, str(sombra),
		fade_inicio, fade_inicio + fade_comprimento]


## Quadros emissivos na boca de cada luminária, num único MultiMesh.
func _lentes(luzes: Array) -> int:
	# BoxMesh e não QuadMesh: o quadro deitado tem AABB degenerado em Y, e o
	# MultiMesh inteiro acabava descartado. A caixa tem volume e aparece.
	var qm := BoxMesh.new()
	qm.size = Vector3(lente_tamanho.x, 0.06, lente_tamanho.y)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = lente_brilho
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = luzes.size()
	for i in luzes.size():
		var L: Dictionary = luzes[i]
		var b := Basis(Vector3.UP, float(L["rot"]))
		# -0.24: a caixa da luminária vai de tip-0.10 a tip+0.07. A lente
		# precisa ficar ABAIXO dela, senão fica coplanar e some.
		mm.set_instance_transform(i, Transform3D(b, Vector3(
			float(L["x"]), float(L["y"]) - 0.24, float(L["z"]))))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Lentes"
	mmi.multimesh = mm
	# material_override no nó, não no mesh: com MultiMesh o material da
	# superfície não estava sendo aplicado e a lente não renderizava.
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	mmi.owner = get_tree().edited_scene_root
	return luzes.size()
