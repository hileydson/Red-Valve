extends MeshInstance3D

## A BOLINHA DEBAIXO DO ITEM DE CENARIO.
##
## De perto o item ja' se anuncia (realce e prompt do `item_de_balcao.gd`), mas
## de longe uma caixa de bala ou uma seringa numa mesa escura some no cenario.
## Esta marca e' um circulo com um ponto no meio, deitado no apoio do item, que
## brilha sem luz e CRESCE com a distancia pra continuar legivel do outro lado
## da sala.
##
## Quem usa: `item_de_balcao.gd` e `item_selecionavel.gd` — os dois caminhos por
## onde passa todo item que se pega do cenario.
##
##     var marca := MarcaDeItem.new()
##     marca.dono = objeto
##     marca.malhas = malhas_do_realce
##     objeto.add_child(marca)

const SHADER := preload("res://shaders/effects/marca_de_item.gdshader")

## Raio (m) de perto, quanto cresce por metro de distancia da camera e o teto.
const RAIO_MIN := 0.07
const RAIO_POR_METRO := 0.04
const RAIO_MAX := 0.5

static var _material: ShaderMaterial = null

## O item: a marca fica debaixo das malhas dele e some junto.
var dono: Node3D = null
## As malhas do item (as mesmas do realce), pra achar onde ele apoia.
var malhas: Array = []
## Falso enquanto nao ha' o que pegar (municao esperando reaparecer).
var ativa: bool = true

var _base_local := Vector3.ZERO
var _raio_proprio := RAIO_MIN


func _ready() -> void:
	if dono == null:
		dono = get_parent() as Node3D
	# A posicao e o tamanho sao refeitos a cada quadro a partir do dono.
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plano := PlaneMesh.new()
	plano.size = Vector2(2.0, 2.0)
	mesh = plano
	material_override = _material_compartilhado()
	_medir_o_apoio()


func _process(_delta: float) -> void:
	if not is_instance_valid(dono):
		queue_free()
		return
	visible = ativa and not (GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene)
	if not visible:
		return
	var base := dono.global_transform * _base_local
	var raio := _raio_proprio
	var cam := get_viewport().get_camera_3d()
	if cam:
		raio = maxf(raio, cam.global_position.distance_to(base) * RAIO_POR_METRO)
	raio = clampf(raio, RAIO_MIN, RAIO_MAX)
	global_transform = Transform3D(Basis.from_scale(Vector3(raio, 1.0, raio)), base)


## O apoio e' o fundo da caixa das malhas, no meio dela, no espaco do dono: se
## o item for movido depois (a seringa da igreja desce por raycast), a marca vai
## junto.
func _medir_o_apoio() -> void:
	if not is_instance_valid(dono):
		return
	var inv := dono.global_transform.affine_inverse()
	var caixa := AABB()
	var tem := false
	for m in malhas:
		if not (m is MeshInstance3D) or not is_instance_valid(m) or m.mesh == null:
			continue
		var a: AABB = (inv * m.global_transform) * m.get_aabb()
		caixa = a if not tem else caixa.merge(a)
		tem = true
	if not tem:
		return
	var centro := caixa.get_center()
	_base_local = Vector3(centro.x, caixa.position.y, centro.z)
	var escala := dono.global_transform.basis.get_scale().x
	_raio_proprio = maxf(caixa.size.x, caixa.size.z) * 0.6 * escala


static func _material_compartilhado() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material
