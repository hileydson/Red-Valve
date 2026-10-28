extends Node3D

## O VULTO — a falsa imagem do Unknown Neighbor, usada no ataque 2
## ("A Ceifa Cega").
##
## Quando ele se dobra pra atacar, nao sai UM: saem tres silhuetas em volta do
## jogador, identicas, todas na mesma pose de golpe. Duas sao imagem; uma e'
## ele. O jogador tem pouco mais de um segundo pra decidir de qual lado sair —
## e essa e a graca do poder, porque errar o lado nao e' levar dano por nao ter
## desviado, e' levar dano por ter desviado PRA DENTRO.
##
## O vulto e' montado com primitivas de proposito: ele nao pode ter detalhe
## nenhum. Se desse pra distinguir a copia do original olhando, o ataque
## deixaria de existir. Ele e' uma silhueta preta com as veias da linhagem, do
## mesmo tamanho e na mesma pose — o que chega pro jogador e' exatamente o que
## chegaria do verdadeiro visto contra a nevoa.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const NFX := preload("res://scripts/effects/neighbor_fx.gd")

var cor: Color = Color(0.72, 1.0, 0.24)
var altura: float = 1.80
## Falso = se desfaz sozinho. Verdadeiro = quem criou vai chamar `desfaz()`
## depois que o golpe de verdade sair de outro lugar.
var vida: float = 1.6

var _pecas: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _tempo: float = 0.0


func _ready() -> void:
	_monta()
	FX.som_no_mundo(self, global_position, NFX.SOM_SORRISO, -12.0, 1.25)


func _monta() -> void:
	# Preto quase puro com um resto de emissao da cor: contra a nevoa da arena
	# o que se ve e' o RECORTE, e e isso que tem de ser igual ao do verdadeiro.
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.015, 0.012, 0.016)
	_mat.emission_enabled = true
	_mat.emission = cor
	_mat.emission_energy_multiplier = 0.55
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color.a = 0.93

	var h := altura
	# tronco, cabeca, dois bracos e duas pernas — a pose de golpe: um braco
	# levantado bem alto (o da foice) e o corpo torcido pra frente
	_capsula(Vector3(0, h * 0.62, 0), 0.19, h * 0.52, Vector3(0.22, 0, 0))
	_capsula(Vector3(0, h * 0.94, 0.04), 0.13, 0.26, Vector3.ZERO)
	_capsula(Vector3(-0.26, h * 0.72, -0.12), 0.075, h * 0.46, Vector3(-1.9, 0, -0.2))
	_capsula(Vector3(0.24, h * 0.60, 0.10), 0.075, h * 0.44, Vector3(0.5, 0, 0.2))
	_capsula(Vector3(-0.13, h * 0.24, -0.10), 0.095, h * 0.48, Vector3(-0.30, 0, 0))
	_capsula(Vector3(0.13, h * 0.26, 0.10), 0.095, h * 0.48, Vector3(0.24, 0, 0))
	# a foice levantada, que e' o que o jogador realmente ve vindo
	_capsula(Vector3(-0.40, h * 1.06, -0.36), 0.05, h * 0.50, Vector3(-2.5, 0, -0.35))

	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.4
	luz.omni_range = 3.2
	luz.position.y = h * 0.9
	add_child(luz)


func _capsula(onde: Vector3, raio: float, comp: float, giro: Vector3) -> void:
	var m := CapsuleMesh.new()
	m.radius = raio
	m.height = maxf(comp, raio * 2.05)
	m.radial_segments = 8
	m.rings = 3
	m.material = _mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = onde
	mi.rotation = giro
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_pecas.append(mi)


func _process(delta: float) -> void:
	_tempo += delta
	# treme: imagem de uma coisa que nao esta bem ali
	var tremor := sin(_tempo * 41.0) * 0.012 + sin(_tempo * 17.0) * 0.008
	for mi in _pecas:
		mi.position.x += tremor * delta * 60.0 * 0.02
	_mat.emission_energy_multiplier = 0.55 + absf(sin(_tempo * 9.0)) * 0.5

	vida -= delta
	if vida <= 0.0:
		desfaz()


## Some. O vulto nao explode nem cai: ele se DOBRA, do mesmo jeito que ele
## chegou — achata num plano e apaga.
func desfaz() -> void:
	set_process(false)
	var dobra := preload("res://scripts/effects/neighbor_fold.gd").new()
	dobra.saindo = true
	dobra.cor = cor
	dobra.altura = altura
	dobra.com_som = false
	var mundo := FX.mundo(self)
	if mundo != null:
		mundo.add_child(dobra)
		dobra.global_position = global_position

	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.02, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
