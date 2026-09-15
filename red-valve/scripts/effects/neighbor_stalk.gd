extends Area3D

## ATAQUE 3 do Unknown Neighbor — "A SEMEADURA" / "The Sowing".
##
## Ele arranca a PROPRIA MAO e joga. Onde ela cai, ela se planta, e do chao
## sobe um broto que abre e AGARRA quem estiver por perto — o jogador fica preso
## no lugar enquanto o broto puxa.
##
## Tres coisas fazem este poder ser diferente de tudo que o jogo tem:
##
##  1. NAO E UM PROJETIL DE DANO. A mao voando nao machuca. O que machuca e o
##     lugar onde ela caiu, meio segundo depois. Todos os outros ataques do jogo
##     pedem "desvie AGORA"; este pede "nao fique ai".
##  2. PRENDE EM VEZ DE EMPURRAR. Ficar preso e' pior que levar 30 de dano numa
##     briga onde tudo mais depende de se mexer — e e' o unico poder do jogo que
##     tira o movimento do jogador.
##  3. TEM RESPOSTA. O broto leva dano e morre a tiro. Quem esta preso se
##     solta atirando nele; quem esta livre pode estourar o broto antes de ele
##     abrir. Um poder que so se aguenta seria castigo; este e' uma pergunta.
##
## E ele fica sem a mao depois — a mesma mao volta a crescer sozinha em alguns
## segundos (ver `folded_neighbor.gd::_regenera_mao`).
##
## O no e' uma Area3D e nao um Node3D porque e' ELE o alvo do tiro: o raycast da
## arma do jogador procura areas na camada 4 (mask 12) e chama `take_damage` no
## proprio colisor. Mesma montagem do "heart" dos outros inimigos.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const NFX := preload("res://scripts/effects/neighbor_fx.gd")

const CHAO := 2

signal encerrado

## Cor da linhagem.
var cor: Color = Color(0.72, 1.0, 0.24)
var cor_veia: Color = Color(0.72, 1.0, 0.24)
var linhagem: int = 1
var alvo: Node3D = null
## De onde a mao sai (a mao dele) e onde ela vai cair.
var origem: Vector3 = Vector3.ZERO
var destino: Vector3 = Vector3.ZERO
## Raio em que o broto agarra.
var raio: float = 3.2
## Quanto tempo o jogador fica preso, se nao matar o broto antes.
var duracao_agarrao: float = 2.0
## Dano por segundo enquanto esta preso.
var dano_por_tique: int = 4
var vida: int = 34

var _mao: Node3D
var _broto: Node3D
var _labios: Array[Node3D] = []
var _hastes: Array[Node3D] = []
var _dedos: Array[Node3D] = []
var _forma: CollisionShape3D
var _voo_a: Vector3 = Vector3.ZERO
var _voo_m: Vector3 = Vector3.ZERO
var _voo_b: Vector3 = Vector3.ZERO
var _luz: OmniLight3D
var _mat: Material
var _preso: bool = false
var _tempo_preso: float = 0.0
var _tique: float = 0.0
var _morto: bool = false
var _aberto: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_mat = NFX.material_parasita(linhagem)
	# Camada 4 e mask 0: e' alvo, nao detecta nada por conta propria.
	collision_layer = 8
	collision_mask = 0
	add_to_group("enemies")
	global_position = origem
	_monta_mao()
	_voa()


# ------------------------------------------------------------------- a mao

func _monta_mao() -> void:
	_mao = Node3D.new()
	add_child(_mao)
	# a palma
	_peca(_mao, "coto", Vector3.ZERO, Vector3(0.22, 0.22, 0.22), null)
	# os dedos, ainda abrindo e fechando no ar
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var d := Node3D.new()
		d.position = Vector3(cos(a) * 0.05, -0.02, sin(a) * 0.05)
		d.rotation = Vector3(-0.5, a, 0.0)
		_mao.add_child(d)
		_peca(d, "garra", Vector3.ZERO, Vector3(0.05, 0.13, 0.05), null)
		_dedos.append(d)


func _voa() -> void:
	var alto := maxf(origem.distance_to(destino) * 0.35, 1.4)
	var meio := (origem + destino) * 0.5 + Vector3.UP * alto
	var tempo := 0.62

	FX.som_no_mundo(self, origem, NFX.SOM_CARNE, -6.0, 1.2)
	_voo_a = origem
	_voo_m = meio
	_voo_b = destino
	var t := create_tween()
	t.tween_method(_passo_do_voo, 0.0, 1.0, tempo).set_trans(Tween.TRANS_LINEAR)
	# gira no ar
	t.parallel().tween_property(_mao, "rotation",
		Vector3(_rng.randf_range(6.0, 10.0), _rng.randf_range(-4.0, 4.0), _rng.randf_range(-3.0, 3.0)),
		tempo)
	t.tween_callback(_planta)


# ---------------------------------------------------------------- o broto

## Bezier quadratica: a mao descreve um ARCO de arremesso, nao uma reta. Reta
## le como tiro; arco le como coisa atirada por um braco.
func _passo_do_voo(f: float) -> void:
	var a := _voo_a.lerp(_voo_m, f)
	var b := _voo_m.lerp(_voo_b, f)
	global_position = a.lerp(b, f)


func _planta() -> void:
	if _morto:
		return
	global_position = _no_chao(destino)
	_mao.rotation = Vector3.ZERO
	_mao.position = Vector3.ZERO
	FX.som_no_mundo(self, global_position, NFX.SOM_CARNE, -3.0, 0.7)
	add_child(NFX.respingo(cor_veia, 22, 2.4))

	_luz = OmniLight3D.new()
	_luz.light_color = cor_veia
	_luz.light_energy = 0.0
	_luz.omni_range = raio * 1.4
	_luz.position.y = 0.6
	add_child(_luz)

	# Meio segundo de NADA antes de abrir. E este silencio que transforma o
	# poder num aviso em vez de numa armadilha invisivel: da tempo de sair.
	var t := create_tween()
	t.tween_property(_luz, "light_energy", 2.2, 0.55)
	t.tween_callback(_floresce)


func _floresce() -> void:
	if _morto:
		return
	_aberto = true
	# So agora ela vira alvo: a mao no ar nao e' pra ser abatida, o poder e'
	# sobre o LUGAR onde ela cai.
	_forma = CollisionShape3D.new()
	var esf := SphereShape3D.new()
	esf.radius = 0.75
	_forma.shape = esf
	_forma.position.y = 0.7
	add_child(_forma)

	_broto = Node3D.new()
	add_child(_broto)
	_peca(_broto, "broto", Vector3.ZERO, Vector3(0.55, 1.15, 0.55), null)

	# quatro labios que abrem
	for i in 4:
		var a := TAU * i / 4.0 + 0.7
		var pivo := Node3D.new()
		pivo.position = Vector3(0, 0.85, 0)
		pivo.rotation.y = a
		_broto.add_child(pivo)
		_peca(pivo, "petala_lisa", Vector3.ZERO, Vector3(0.26, 0.45, 0.26), null)
		_labios.append(pivo)
		var ab := create_tween()
		ab.tween_property(pivo, "rotation:x", 2.1, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# as hastes que saem do chao em volta e procuram o jogador
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf_range(-0.2, 0.2)
		var r := raio * _rng.randf_range(0.35, 0.92)
		var pivo := Node3D.new()
		pivo.position = Vector3(cos(a) * r, 0.05, sin(a) * r)
		pivo.rotation = Vector3(PI, a, 0.0)   # a haste pende: vira ela pra CIMA
		_broto.add_child(pivo)
		_peca(pivo, "haste", Vector3.ZERO, Vector3(0.14, _rng.randf_range(0.9, 1.7), 0.14), null)
		pivo.scale = Vector3(0.1, 0.1, 0.1)
		_hastes.append(pivo)
		var sobe := create_tween()
		sobe.tween_interval(_rng.randf_range(0.0, 0.18))
		sobe.tween_property(pivo, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	add_child(NFX.esporo(cor_veia, 60, raio * 0.6))
	FX.som_no_mundo(self, global_position, NFX.SOM_GRITO, -10.0, 1.45)
	create_tween().tween_property(_luz, "light_energy", 5.0, 0.2)
	_tenta_agarrar()


func _tenta_agarrar() -> void:
	if _morto or not is_instance_valid(alvo):
		return
	var d := Vector2(alvo.global_position.x - global_position.x,
		alvo.global_position.z - global_position.z).length()
	if d > raio:
		return
	_preso = true
	_tempo_preso = duracao_agarrao
	# 0.06: o jogador ainda cambaleia, mas nao sai do lugar. Zerar de vez
	# deixaria a tela travada, e tela travada le como bug, nao como agarrao.
	if alvo.has_method("apply_slow"):
		alvo.apply_slow(0.06, duracao_agarrao)
	GlobalUtils.shake_camera(0.6, 0.25)
	GlobalUtils.vibrate_controller(null, 0.9, 0.6, 0.6)


func _physics_process(delta: float) -> void:
	if _morto:
		return

	# as hastes se viram pro jogador enquanto ele estiver por perto
	if _aberto and is_instance_valid(alvo):
		var para := alvo.global_position - global_position
		para.y = 0.0
		if para.length() > 0.1:
			var ang := atan2(para.x, para.z)
			for h in _hastes:
				if is_instance_valid(h):
					h.rotation.y = lerp_angle(h.rotation.y, ang, delta * 3.0)

	if not _preso:
		return

	_tempo_preso -= delta
	_tique -= delta
	if _tique <= 0.0:
		_tique = 1.0
		if is_instance_valid(alvo) and alvo.has_method("take_damage"):
			alvo.take_damage(dano_por_tique)
		GlobalUtils.shake_camera(0.2, 0.12)
	if _tempo_preso <= 0.0:
		_solta()
		_murcha()


func _solta() -> void:
	_preso = false
	if is_instance_valid(alvo) and alvo.has_method("clear_slow"):
		alvo.clear_slow()


## O broto e' um alvo: o raycast da arma acha esta area e chama isto. E o que
## transforma o agarrao numa pergunta em vez de numa espera.
func take_damage(quanto) -> void:
	if _morto:
		return
	vida -= int(quanto)
	add_child(NFX.respingo(cor_veia, 8, 2.0))
	if vida <= 0:
		_solta()
		_murcha()


func _murcha() -> void:
	if _morto:
		return
	_morto = true
	set_physics_process(false)
	if is_instance_valid(_forma):
		_forma.queue_free()
	_solta()
	FX.som_no_mundo(self, global_position, NFX.SOM_CARNE, -5.0, 0.55)
	add_child(NFX.respingo(cor_veia, 26, 3.2))
	encerrado.emit()

	var t := create_tween().set_parallel(true)
	if is_instance_valid(_broto):
		t.tween_property(_broto, "scale", Vector3(0.9, 0.05, 0.9), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if is_instance_valid(_luz):
		t.tween_property(_luz, "light_energy", 0.0, 0.45)
	t.chain().tween_interval(1.0)
	t.chain().tween_callback(queue_free)


## Tira o broto de cena na hora (o inimigo morreu, a batalha acabou).
func encerrar() -> void:
	_solta()
	_morto = true
	queue_free()


# --------------------------------------------------------------- utilidades

func _no_chao(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 8.0, CHAO)
	var hit := espaco.intersect_ray(q)
	if hit.is_empty():
		return p
	return hit["position"]


func _peca(pai: Node3D, nome: String, onde: Vector3, escala: Vector3, reserva: Mesh) -> MeshInstance3D:
	var malha := NFX.peca(nome)
	var mi := MeshInstance3D.new()
	mi.mesh = malha if malha != null else (reserva if reserva != null else _capsula())
	mi.position = onde
	mi.scale = escala if malha != null else escala * 0.5
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


func _capsula() -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = 0.5
	m.height = 1.4
	m.radial_segments = 8
	m.rings = 3
	return m
