extends Node3D

## A DEFESA do Unknown Neighbor — "A CASCA" / "The Husk".
##
## Ele desdobra a PROPRIA PELE pra fora. Dez placas de gente se abrem em volta
## do corpo e giram devagar, e enquanto elas estao de pe o dano quase nao passa.
##
## O que separa isto das outras duas defesas do jogo:
##
##   Cobalt Husker -> esfera de energia. Fecha, pisca quando levam, abre no
##                    fim do tempo. O jogador espera.
##   Shadow Seraph -> casca de fogo. Mesma ideia, outra cor.
##   ESTA          -> a casca se GASTA. Cada golpe arranca UMA placa, que voa e
##                    cai no chao. O jogador ve a defesa acabando e sabe
##                    exatamente quantos tiros faltam — ele nao espera, ele
##                    DESMONTA. E quando a ultima sai, a casca estoura e o
##                    empurra: insistir ate o fim cobra um preco.
##
## Contrato igual ao da `defense_shield.gd` (o inimigo trata as duas do mesmo
## jeito): `duration`, sinal `expired`, `flash()` a cada dano e `encerrar()`.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const NFX := preload("res://scripts/effects/neighbor_fx.gd")

signal expired

var duration: float = 11.0
var raio: float = 1.30
var cor: Color = Color(0.72, 1.0, 0.24)
var linhagem: int = 1
## Quantas placas — e portanto quantos golpes a casca aguenta.
var placas: int = 10
## Dano e empurrao do estouro final.
var dano_estouro: int = 8
var alvo: Node3D = null

var _placas: Array[Node3D] = []
var _luz: OmniLight3D
var _mat: Material
var _tempo: float = 0.0
var _morrendo: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_mat = NFX.material_parasita(linhagem)
	_monta()
	FX.som_no_mundo(self, global_position, NFX.SOM_CARNE, -2.0, 0.6)
	FX.som_no_mundo(self, global_position, NFX.SOM_DOR, -8.0, 0.8)


func _monta() -> void:
	# As placas se distribuem numa espiral de Fibonacci sobre a esfera: e o
	# jeito barato de cobrir o corpo por igual sem elas se alinharem em faixas
	# (faixa le como gaiola de video game).
	var dourado := PI * (3.0 - sqrt(5.0))
	for i in placas:
		var f := (float(i) + 0.5) / float(placas)
		var y := 1.0 - 2.0 * f
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var a := dourado * float(i)
		var dir := Vector3(cos(a) * r, y, sin(a) * r)

		var pivo := Node3D.new()
		pivo.position = dir * raio
		# a placa olha pra FORA (a peca e' autorada olhando pro -Z)
		if absf(dir.y) < 0.98:
			pivo.look_at_from_position(pivo.position, pivo.position + dir, Vector3.UP)
		add_child(pivo)

		var mi := MeshInstance3D.new()
		var malha := NFX.peca("placa_casca")
		mi.mesh = malha if malha != null else _reserva()
		# Cada placa cobre mais ou menos um decimo da esfera: com 10 delas o
		# corpo fica coberto sem elas se empilharem. Maior que isto e' o que
		# fazia a casca parecer um leque de laminas em vez de pele.
		mi.scale = Vector3.ONE * (raio * _rng.randf_range(0.95, 1.25))
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivo.add_child(mi)
		_placas.append(pivo)

		# entra "abrindo": nasce colada no corpo e vai pro lugar
		pivo.scale = Vector3(0.05, 0.05, 0.05)
		var t := create_tween()
		t.tween_interval(float(i) * 0.035)
		t.tween_property(pivo, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_luz = OmniLight3D.new()
	_luz.light_color = cor
	_luz.light_energy = 2.6
	_luz.omni_range = raio * 3.2
	add_child(_luz)

	add_child(NFX.esporo(cor, 40, raio * 0.9))


func _reserva() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(0.9, 1.0, 0.08)
	return m


func _process(delta: float) -> void:
	if _morrendo:
		return
	_tempo += delta
	# giro lento e desencontrado: a casca respira em volta dele
	rotation.y += delta * 0.55
	rotation.x = sin(_tempo * 0.7) * 0.10
	_luz.light_energy = 2.6 + sin(_tempo * 2.3) * 0.8

	if _tempo >= duration:
		_estoura()


## Chamado pelo inimigo a cada dano levado. Aqui ele nao "pisca": ele PERDE uma
## placa, e e por isso que o jogador consegue contar quanto falta.
func flash() -> void:
	if _morrendo:
		return
	GlobalUtils.shake_camera(0.15, 0.10)
	if _placas.is_empty():
		_estoura()
		return
	var i := _rng.randi_range(0, _placas.size() - 1)
	var pivo: Node3D = _placas[i]
	_placas.remove_at(i)
	_arranca(pivo)
	if _placas.is_empty():
		_estoura()


## A placa se solta e cai. Ela fica no chao o tempo de ser vista e some — sao
## ate treze por casca, e varias cascas por briga: deixa-las por muito tempo
## entulhava a arena de pele.
func _arranca(pivo: Node3D) -> void:
	if not is_instance_valid(pivo):
		return
	var mundo := FX.mundo(self)
	var pos := pivo.global_position
	var fora := (pos - global_position).normalized()
	remove_child(pivo)
	if mundo == null:
		pivo.queue_free()
		return
	mundo.add_child(pivo)
	pivo.global_position = pos

	FX.som_no_mundo(self, pos, NFX.SOM_CARNE, -10.0, _rng.randf_range(1.1, 1.4))
	var chao := _chao_abaixo(pos)
	var longe := pos + fora * _rng.randf_range(1.2, 2.4)
	longe.y = chao + 0.05

	var t := create_tween().set_parallel(true)
	t.tween_property(pivo, "global_position", longe, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(pivo, "rotation", pivo.rotation + Vector3(
		_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0)), 0.65)
	t.chain().tween_interval(2.5)
	t.chain().tween_property(pivo, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
	t.chain().tween_callback(pivo.queue_free)


func _chao_abaixo(p: Vector3) -> float:
	if not is_inside_tree():
		return p.y
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 12.0, 2)
	var hit := espaco.intersect_ray(q)
	if hit.is_empty():
		return p.y - 1.0
	return (hit["position"] as Vector3).y


## O fim da casca, dos dois jeitos (tempo esgotado ou ultima placa arrancada):
## o que sobra dela arrebenta pra fora e empurra quem estiver colado.
func _estoura() -> void:
	if _morrendo:
		return
	_morrendo = true
	set_process(false)
	expired.emit()

	var pos := global_position
	FX.explosao(self, pos + Vector3.UP * 0.9, cor, raio * 1.8, false)
	FX.som_no_mundo(self, pos, NFX.SOM_GRITO, -5.0, 0.62)
	GlobalUtils.shake_camera(0.5, 0.3)

	for pivo in _placas:
		if is_instance_valid(pivo):
			_arranca(pivo)
	_placas.clear()

	if is_instance_valid(alvo):
		var d := pos.distance_to(alvo.global_position)
		if d <= raio * 3.0:
			if alvo.has_method("take_damage"):
				alvo.take_damage(dano_estouro)
			_empurra(alvo, pos)

	var t := create_tween()
	if is_instance_valid(_luz):
		t.tween_property(_luz, "light_energy", 0.0, 0.3)
	t.tween_callback(queue_free)


## Empurrao curto, com raycast na frente: o mesmo cuidado do `enemy.gd` —
## mover `global_position` por tween ignora parede, e numa sala pequena isso
## jogava o jogador pra fora do cenario.
func _empurra(quem: Node3D, de: Vector3) -> void:
	var dir := (quem.global_position - de)
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	var destino := quem.global_position + dir * 3.2
	if quem is PhysicsBody3D and is_inside_tree():
		var espaco := get_world_3d().direct_space_state
		var altura := Vector3(0, 1.0, 0)
		var q := PhysicsRayQueryParameters3D.create(
			quem.global_position + altura, destino + altura, (quem as PhysicsBody3D).collision_mask)
		q.exclude = [(quem as PhysicsBody3D).get_rid()]
		var hit := espaco.intersect_ray(q)
		if hit:
			var livre := maxf((quem.global_position + altura).distance_to(hit["position"]) - 0.4, 0.0)
			destino = quem.global_position + dir * livre
	var t := create_tween()
	t.tween_property(quem, "global_position", destino, 0.22).set_trans(Tween.TRANS_QUAD)


## Tira a casca na hora (morte do inimigo, fim da batalha).
func encerrar() -> void:
	_morrendo = true
	set_process(false)
	for pivo in _placas:
		if is_instance_valid(pivo):
			pivo.queue_free()
	_placas.clear()
	queue_free()
