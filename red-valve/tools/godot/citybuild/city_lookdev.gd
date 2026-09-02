@tool
extends Node
## Etapa 08 — calibra a atmosfera direto no Environment ativo.
##
## O Sky3D não expõe as propriedades de névoa (elas vivem no recurso
## Environment), e editar o .tscn de 14 MB a cada tentativa é inviável.
## Este nó edita o recurso vivo: mexer numa propriedade e ligar `aplicar`
## atualiza a cena na hora.
##
## Ver docs/plano-cidade-blender.md §4.3 e §7 Etapa 08.

@export var world_env_path: NodePath = NodePath("../WorldEnvironment/Sky3D")

@export_group("Névoa de profundidade")
## Densidade baixa: a 700 m, 0.006 apaga tudo. 0.0012 dá bruma sem apagar.
@export var fog_density: float = 0.0012
@export var fog_light_color: Color = Color(0.5775, 0.3917, 0.1621)
@export var fog_light_energy: float = 1.0
@export var fog_sun_scatter: float = 0.35
@export var fog_aerial_perspective: float = 0.35
@export var fog_sky_affect: float = 0.40

@export_group("Tonemap e ajuste")
## 0 Linear · 1 Reinhard · 2 Filmic · 3 ACES · 4 AgX
@export var tonemap_mode: int = 4
@export var tonemap_white: float = 4.5
@export var tonemap_exposure: float = 1.0
@export var brilho: float = 1.0
@export var contraste: float = 1.06
@export var saturacao: float = 0.86

@export_group("LUT sépia")
@export var lut_tamanho: int = 17
@export var lut_forca: float = 0.75
@export var lut_ganho_r: float = 1.06
@export var lut_ganho_g: float = 1.00
@export var lut_ganho_b: float = 0.90
@export var lut_lift_r: float = 0.020
@export var lut_lift_g: float = 0.014
@export var lut_lift_b: float = 0.008
@export var lut_caminho: String = "res://assets/3d_model/city/lut_sepia.tres"

@export_multiline var last_result: String = ""

@export var aplicar: bool = false:
	set(v):
		aplicar = false
		if v and Engine.is_editor_hint():
			_aplicar()

@export var construir_lut: bool = false:
	set(v):
		construir_lut = false
		if v and Engine.is_editor_hint():
			_construir_lut()

@export var remover_lut: bool = false:
	set(v):
		remover_lut = false
		if v and Engine.is_editor_hint():
			var e := _env()
			if e:
				e.adjustment_color_correction = null
				last_result = "LUT removida"


func _env() -> Environment:
	var n := get_node_or_null(world_env_path)
	if n == null or not ("environment" in n):
		return null
	return n.environment


func _aplicar() -> void:
	var e := _env()
	if e == null:
		last_result = "ERRO: Environment não encontrado em %s" % world_env_path
		return
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_density = fog_density
	e.fog_light_color = fog_light_color
	e.fog_light_energy = fog_light_energy
	e.fog_sun_scatter = fog_sun_scatter
	e.fog_aerial_perspective = fog_aerial_perspective
	e.fog_sky_affect = fog_sky_affect
	e.volumetric_fog_enabled = false          # inerte no renderer mobile

	e.tonemap_mode = tonemap_mode
	e.tonemap_white = tonemap_white
	e.tonemap_exposure = tonemap_exposure

	e.adjustment_enabled = true
	e.adjustment_brightness = brilho
	e.adjustment_contrast = contraste
	e.adjustment_saturation = saturacao

	var fmt := "aplicado | fog d=%.4f aer=%.2f | tonemap=%d white=%.1f"
	fmt += " | contraste=%.2f sat=%.2f | LUT=%s"
	last_result = fmt % [
		fog_density, fog_aerial_perspective, tonemap_mode, tonemap_white,
		contraste, saturacao,
		"sim" if e.adjustment_color_correction != null else "não"]


func _scurve(x: float) -> float:
	return x * x * (3.0 - 2.0 * x) * 0.5 + x * 0.5


func _construir_lut() -> void:
	var n := maxi(2, lut_tamanho)
	var fatias: Array[Image] = []
	for b in n:
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for g in n:
			for r in n:
				var c := Color(float(r) / (n - 1), float(g) / (n - 1),
					float(b) / (n - 1))
				var l: float = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
				var o := Color(
					lerpf(l, c.r, saturacao),
					lerpf(l, c.g, saturacao),
					lerpf(l, c.b, saturacao))
				o = Color(_scurve(o.r), _scurve(o.g), _scurve(o.b))
				o = Color(
					clampf(o.r * lut_ganho_r + lut_lift_r, 0.0, 1.0),
					clampf(o.g * lut_ganho_g + lut_lift_g, 0.0, 1.0),
					clampf(o.b * lut_ganho_b + lut_lift_b, 0.0, 1.0))
				o = c.lerp(o, lut_forca)
				img.set_pixel(r, g, o)
		fatias.append(img)

	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, n, n, n, false, fatias)
	var err := ResourceSaver.save(tex, lut_caminho)
	if err != OK:
		last_result = "ERRO ao salvar LUT: %d" % err
		return
	var e := _env()
	if e:
		e.adjustment_enabled = true
		e.adjustment_color_correction = load(lut_caminho)
	last_result = "LUT %d³ construída e aplicada (força %.2f)" % [n, lut_forca]
