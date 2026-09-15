extends Node3D

## A DOBRA — o teletransporte do Unknown Neighbor, so dentro da arena.
##
## Este no e' so o RASGO que fica no lugar: uma fresta vertical de luz, da
## altura de uma pessoa, que se abre, pisca e se fecha numa linha. O corpo dele
## some (e reaparece) por conta do proprio inimigo — ver
## `folded_neighbor.gd::_dobra_para`.
##
## Por que uma FRESTA e nao uma nuvem de fumaca ou um clarao: o bicho inteiro e'
## a ideia de uma pessoa DOBRADA. Ele nao se desmaterializa, ele se fecha como
## uma folha de papel — o corpo achata num plano, vira uma linha, e a linha
## some. A fresta e o rastro dessa linha. E a mesma leitura na ida e na volta,
## so que ao contrario, e e o que faz os dois lados do teleporte parecerem a
## mesma coisa acontecendo duas vezes.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const NFX := preload("res://scripts/effects/neighbor_fx.gd")

## true = ele esta SUMINDO aqui (a fresta abre e fecha); false = esta CHEGANDO
## (a fresta abre e se rasga, deixando ele passar).
var saindo: bool = true
var cor: Color = Color(0.72, 1.0, 0.24)
var altura: float = 1.85
var com_som: bool = true

var _fresta: MeshInstance3D
var _mat: StandardMaterial3D
var _luz: OmniLight3D


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, altura)
	_mat = FX.emissivo(Color(1, 1, 1), 9.0)
	# Gradiente vertical: a fenda e' forte no meio (na altura do peito, onde o
	# corpo tem mais massa pra dobrar) e se apaga nas duas pontas. Sem ele o
	# quad le como uma PORTA branca retangular — foi exatamente assim que ela
	# saiu na primeira rodada de teste.
	var faixa := _gradiente_da_fenda()
	_mat.albedo_texture = faixa
	# A EMISSAO tambem, senao o gradiente so aparava a metade do efeito: num
	# material unshaded o que vai pra tela e' albedo + emissao, e a emissao e'
	# chapada na peca inteira. Multiplicando ela pela mesma faixa, a fenda
	# apaga nas pontas de verdade.
	_mat.emission_texture = faixa
	_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	# Branco na fresta e cor da linhagem so na luz: a dobra e' um buraco, e
	# buraco nao tem cor. Pintar a fresta de verde fazia ela parecer um portal
	# de fantasia em vez de uma falha.
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	q.material = _mat
	_fresta = MeshInstance3D.new()
	_fresta.mesh = q
	_fresta.position.y = altura * 0.5
	_fresta.scale = Vector3(0.02, 1.0, 1.0)
	add_child(_fresta)

	_luz = OmniLight3D.new()
	_luz.light_color = cor
	_luz.light_energy = 0.0
	_luz.omni_range = 5.0
	_luz.position.y = altura * 0.5
	add_child(_luz)

	var po := NFX.esporo(cor, 30, 0.25)
	po.position.y = altura * 0.45
	po.one_shot = true
	po.explosiveness = 0.85
	add_child(po)

	if com_som:
		FX.som_no_mundo(self, global_position, NFX.SOM_DOBRA, -5.0,
			0.85 if saindo else 1.15)

	_anima()


## Faixa clara no meio, transparente nas bordas. Serve de albedo e de alfa ao
## mesmo tempo (o material e' aditivo, entao preto = invisivel).
static var _faixa_cache: GradientTexture2D = null


static func _gradiente_da_fenda() -> GradientTexture2D:
	# Uma textura so pro jogo inteiro: ele se dobra dezenas de vezes por
	# batalha, e cada fenda criando a propria seria lixo na VRAM.
	if _faixa_cache != null:
		return _faixa_cache
	var t := GradientTexture2D.new()
	t.width = 4
	t.height = 64
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(1, 1, 1, 1),
		Color(1, 1, 1, 1), Color(0, 0, 0, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	t.gradient = g
	_faixa_cache = t
	return t


## A fresta larga UM quadro e depois some: e o bastante pra o olho registrar o
## corte sem o efeito virar cenografia. O que faz o teleporte ser bonito e' o
## corpo dele achatando junto, nao este quad.
func _anima() -> void:
	var t := create_tween().set_parallel(true)
	if saindo:
		# abre rapido, fecha na linha
		t.tween_property(_fresta, "scale:x", 0.16, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(_luz, "light_energy", 7.0, 0.09)
		t.chain().tween_property(_fresta, "scale:x", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(_luz, "light_energy", 0.0, 0.25)
	else:
		# nasce como linha e se RASGA pra fora: e por ali que ele sai
		_fresta.scale.x = 0.0
		t.tween_property(_fresta, "scale:x", 0.22, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(_luz, "light_energy", 8.0, 0.10)
		t.chain().tween_property(_fresta, "scale:x", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(_luz, "light_energy", 0.0, 0.30)
	t.chain().tween_interval(1.8)   # deixa o esporo terminar antes de liberar
	t.chain().tween_callback(queue_free)
