@tool
extends Node3D

## A corrida pela cidade: o Maycow sai da igreja com o Jonny no colo e corre
## ate' o hospital.
##
## Como a igreja, tudo o que se ve' e' o AnimationPlayer `diretor` (animacao
## `corrida`) — camera, atores, lente, chuva de luz. Os planos acontecem em
## dois PALCOS, e as chaves sao relativas a eles:
##
##   palco_igreja    na praca, de costas pra igreja (o +Z do palco e' a
##                   direcao da corrida)
##   palco_hospital  no PE' DA ESCADA do hospital, +Z apontando pra porta.
##                   E' posto em cima do no' `hospital_exterior` da stage_1:
##                   arrastar o hospital no editor leva a cena junto.
##
## Entre a igreja e o hospital sao ~260 m de cidade: a cena nao mostra tudo,
## corta da praca pra chegada (e' isso que "correndo pela cidade" pede de
## camera, e nao uma caminhada inteira em tempo real).
##
## O chao: o terreno sobe e desce. Os atores marcados em `colados_no_chao`
## tem a altura corrigida a cada quadro pelo Terrain3D (a chave da animacao
## manda so' no X/Z). Montada uma vez por `tools/igreja/montar_corrida_jonny.gd`;
## a fonte e' este .tscn.

signal terminou

const IGREJA_SAIDA := Vector3(576.0, 0.0, -317.7)
## A praca fica a -X da igreja: o palco olha pra la'.
const IGREJA_GIRO := -PI * 0.5

## Nos que andam colados no chao (caminho a partir deste no').
@export var colados_no_chao: Array[NodePath] = []
@export_range(0.0, 1.0) var barras: float = 0.0:
	set(v):
		barras = v
		_lente("barras", v)
@export_range(0.0, 1.0) var preto: float = 0.0:
	set(v):
		preto = v
		var f := get_node_or_null("lente/preto") as ColorRect
		if f:
			f.color.a = v
@export var plano: String = "":
	set(v):
		plano = v
		if v.is_empty():
			return
		var c := get_node_or_null(v) as Camera3D
		if c:
			c.make_current()

var _terreno: Node = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var lente := get_node_or_null("lente") as CanvasLayer
	if lente:
		lente.visible = false


## Poe os palcos no lugar e roda. `cena` e' a stage_1.
func comecar(cena: Node) -> void:
	_terreno = cena.find_child("Terrenasso", true, false)
	var pi := get_node("palco_igreja") as Node3D
	pi.global_position = Vector3(IGREJA_SAIDA.x, _altura(IGREJA_SAIDA), IGREJA_SAIDA.z)
	pi.rotation.y = IGREJA_GIRO
	var hosp := cena.find_child("hospital_exterior", true, false) as Node3D
	var ph := get_node("palco_hospital") as Node3D
	if hosp:
		# o +X do hospital e' a porta; o +Z do palco tem de ser ele
		ph.global_transform = hosp.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	print("corrida_jonny: palco_igreja em ", pi.global_position, " palco_hospital em ",
		ph.global_position, " (hospital ", hosp.global_position if hosp else Vector3.ZERO, ")")
	var lente := get_node_or_null("lente") as CanvasLayer
	if lente:
		lente.visible = true
	($diretor as AnimationPlayer).play(&"corrida")
	await ($diretor as AnimationPlayer).animation_finished
	terminou.emit()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _terreno == null:
		return
	for c in colados_no_chao:
		var n := get_node_or_null(c) as Node3D
		if n and n.is_visible_in_tree():
			n.global_position.y = _altura(n.global_position)


func _altura(p: Vector3) -> float:
	# o que estiver por cima do terreno (calcada, adro) ganha: raio de cima
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0)
	q.collision_mask = 2
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var h := -INF
	if not r.is_empty():
		h = r["position"].y
	if _terreno and _terreno.get("data"):
		var t: float = _terreno.data.get_height(p)
		if not is_nan(t):
			h = maxf(h, t)
	return h if h > -INF else p.y


func _lente(param: String, valor) -> void:
	var tela := get_node_or_null("lente/tela") as ColorRect
	if tela and tela.material is ShaderMaterial:
		(tela.material as ShaderMaterial).set_shader_parameter(param, valor)
