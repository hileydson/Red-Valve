extends Area3D

## Ataque 1 do Shadow Rock: o pedregulho.
##
## Tres vidas no mesmo no, e as tres importam pro golpe ler como golpe:
##
##   1. NASCE na mao dele, do tamanho de um punho, e CRESCE por ~3 s enquanto
##      pedras soltas sao puxadas do chao em volta e grudam nele. Este e o
##      aviso: sao tres segundos em que o jogador ve exatamente o que vem;
##   2. PASSA PRAS DUAS MAOS — `segurar()` troca a ancora, e o corpo inteiro se
##      arma pra tras. Sem essa troca o arremesso vira um passe de basquete;
##   3. VOA ate o ponto onde o jogador estava no instante do arremesso. Em arco,
##      nao em linha reta: uma pedra de dois metros que viaja reta parece um
##      projetil de arma, nao um peso arremessado.
##
## Nao persegue o jogador. Sair da frente e a resposta certa pra este golpe, e
## o telegrafo de sete segundos existe justamente pra isso ser possivel.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const RockFX := preload("res://scripts/effects/rock_fx.gd")

## Dano de quem for pego pelo estouro.
var damage: int = 45
## Raio final da pedra, em metros.
var raio: float = 1.05
## Quem estiver a esta distancia do impacto leva o dano.
var blast_radius: float = 3.6
## Dono do golpe: nunca se acerta a si mesmo.
var dono: Node3D = null

var _voando: bool = false
var _vel: Vector3 = Vector3.ZERO
var _estourou: bool = false
var _tempo: float = 0.0
var _vida_voo: float = 0.0
var _alvo: Vector3 = Vector3.ZERO
var _giro: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _corpo: Node3D
var _col: CollisionShape3D
var _forma: SphereShape3D
## Pedras da massa: [{ "no": MeshInstance3D, "destino": Vector3 }].
var _slots: Array[Dictionary] = []
var _po: GPUParticles3D

const GRAVIDADE := 16.0


func _ready() -> void:
	_rng.randomize()
	collision_layer = 0
	collision_mask = 1  # so o corpo do jogador
	monitoring = true

	_forma = SphereShape3D.new()
	_forma.radius = raio * 0.85
	_col = CollisionShape3D.new()
	_col.shape = _forma
	add_child(_col)

	_monta()
	body_entered.connect(_no_corpo)


## O pedregulho comeca como UM seixo na mao. Todo o resto da massa chega
## voando em `crescer()` — nada aqui e pre-montado.
func _monta() -> void:
	_corpo = Node3D.new()
	add_child(_corpo)

	# o nucleo: a unica pedra que ja esta na mao quando o golpe comeca
	RockFX.bloco(_corpo, Vector3.ZERO, raio * 0.42, _rng, 0.2)

	_po = RockFX.po(18, raio * 0.9, 1.6)
	_po.one_shot = false
	_po.emitting = false
	add_child(_po)


## O golpe se MONTA: pedras chegam de todas as direcoes e grudam umas nas
## outras ate virar um bloco. Cada uma que chega e uma pedra de verdade que fica
## na massa e viaja com ela — nao um enfeite que some ao encostar.
##
## Por que nos de verdade e nao particulas: sao tres segundos com o jogador
## olhando direto pra isso, a um par de metros. Particula a essa escala fica
## chapada, e o ponto do golpe e justamente ver a coisa sendo montada — e o
## telegrafo que torna o arremesso justo.
##
## As direcoes de chegada sao sorteadas na esfera inteira, e a direcao de onde
## a pedra VEM nao tem relacao com o lugar onde ela vai parar. E isso que da a
## leitura de coisa sendo puxada de todo lado, em vez de uma casca inflando.
func crescer(duracao: float) -> void:
	var quantas := 18
	for i in quantas:
		var mi := MeshInstance3D.new()
		mi.mesh = RockFX.pedra(_rng.randi(), i % 3 != 0)
		mi.material_override = RockFX.material()
		# quatro pedras grandes dao a massa; o resto preenche e quebra a borda
		var grande := i < 4
		var base := raio * (_rng.randf_range(0.58, 0.80) if grande else _rng.randf_range(0.32, 0.54))
		mi.scale = Vector3(base * _rng.randf_range(0.8, 1.2),
			base * _rng.randf_range(0.75, 1.15),
			base * _rng.randf_range(0.8, 1.2))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_corpo.add_child(mi)

		# lugar final dentro da massa (raiz cubica = distribuicao uniforme na
		# esfera; sem ela tudo se amontoa na casca)
		var dir_slot := Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0))
		if dir_slot.length() < 0.001:
			dir_slot = Vector3.UP
		var slot: Vector3 = dir_slot.normalized() * raio * 0.50 * pow(_rng.randf(), 1.0 / 3.0)
		if grande:
			slot *= 0.45

		# de ONDE ela vem: outra direcao qualquer, longe
		var de := Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0))
		if de.length() < 0.001:
			de = Vector3.DOWN
		mi.position = slot + de.normalized() * _rng.randf_range(3.0, 5.5)
		mi.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		var atraso := duracao * 0.80 * (float(i) / float(quantas))
		var voo := duracao * _rng.randf_range(0.22, 0.34)
		var t := mi.create_tween().set_parallel(true)
		_slots.append({"no": mi, "destino": slot, "tween": t})
		t.tween_property(mi, "position", slot, voo)\
			.set_delay(atraso).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(mi, "rotation", mi.rotation + Vector3(
			_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0)),
			voo).set_delay(atraso)
		t.chain().tween_callback(_encaixou.bind(mi))

	FX.som_no_mundo(self, global_position, RockFX.SOM_PEDRA, -13.0, 0.36)


## Uma pedra acabou de grudar na massa: baque seco e um sopro de po. E o que faz
## a montagem SOAR como pedra batendo em pedra em vez de um tween silencioso.
func _encaixou(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi) or not is_inside_tree():
		return
	# Po proprio, curto, e nao o `_po` do no: aquele e o rastro CONTINUO do voo
	# (one_shot desligado) e reiniciar ele aqui acenderia o rastro antes da hora.
	var puff := RockFX.po(4, maxf(mi.scale.y, 0.05) * 1.6, 0.7)
	_corpo.add_child(puff)
	puff.position = mi.position
	var tl := puff.create_tween()
	tl.tween_interval(1.0)
	tl.tween_callback(puff.queue_free)
	if _rng.randf() < 0.5:
		FX.som_no_mundo(self, mi.global_position, RockFX.SOM_PEDRA, -22.0,
			_rng.randf_range(0.55, 0.8))


## Passa da mao que conjurou pro par de maos. `ancora` e o no que vai segura-la.
func segurar(ancora: Node3D) -> void:
	if ancora == null or not is_instance_valid(ancora) or get_parent() == ancora:
		return
	var mundo := global_transform
	get_parent().remove_child(self)
	ancora.add_child(self)
	global_transform = mundo
	# desliza da mao pro meio das duas maos em vez de pular pra la
	create_tween().tween_property(self, "position", Vector3.ZERO, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Solta a pedra no mundo, mirada no ponto passado. A partir daqui ela deixa de
## ser filha do inimigo: se ele morrer no meio do voo, a pedra ainda chega.
func lancar(destino: Vector3) -> void:
	if _voando:
		return
	var cena := FX.mundo(self)
	if cena != null and get_parent() != cena:
		var mundo := global_transform
		get_parent().remove_child(self)
		cena.add_child(self)
		global_transform = mundo

	# Quem ainda estava voando encaixa AGORA, no lugar que era o seu. Deixar as
	# retardatarias perseguindo a massa depois do arremesso faria pedra
	# atravessando a tela atras do projetil.
	for item in _slots:
		var tw = item.get("tween")
		# `create_tween()` novo nao mata o antigo — tem de ser a referencia que
		# ficou guardada no slot, senao a pedra continua correndo pro destino
		# enquanto a massa ja atravessa a tela.
		if tw is Tween and tw.is_valid():
			tw.kill()
		var mi = item["no"]
		if is_instance_valid(mi):
			mi.position = item["destino"]

	_alvo = destino
	_voando = true
	_vida_voo = 0.0

	# Arco: resolve a velocidade inicial que poe a pedra no alvo em `t_voo`
	# segundos sob gravidade. E o que da peso ao arremesso.
	var para := destino - global_position
	var t_voo: float = clampf(Vector2(para.x, para.z).length() / 17.0, 0.55, 1.7)
	_vel = para / t_voo
	_vel.y += 0.5 * GRAVIDADE * t_voo
	_giro = Vector3(_rng.randf_range(-3.5, 3.5), _rng.randf_range(-2.0, 2.0), _rng.randf_range(-3.5, 3.5))

	if _po != null:
		_po.emitting = true
	FX.som_no_mundo(self, global_position, RockFX.SOM_PEDRA, -6.0, 0.42)


func _physics_process(delta: float) -> void:
	_tempo += delta
	if not _voando or _estourou:
		return

	_vida_voo += delta
	_vel.y -= GRAVIDADE * delta
	var proximo := global_position + _vel * delta
	if is_instance_valid(_corpo):
		_corpo.rotation += _giro * delta

	# Bateu no chao (ou em qualquer cenario) antes de chegar ao alvo: estoura
	# ali mesmo. Sem esta checagem a pedra atravessa o asfalto quando o jogador
	# sai da frente.
	if is_inside_tree():
		var espaco := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position, proximo, 2)
		var acerto := espaco.intersect_ray(q)
		if acerto.has("position"):
			global_position = acerto["position"]
			_estourar()
			return

	global_position = proximo

	if _vida_voo > 6.0 or global_position.y < _alvo.y - 30.0:
		_estourar()


func _no_corpo(corpo: Node3D) -> void:
	if _estourou or not _voando or corpo == dono:
		return
	if corpo.is_in_group("player") or corpo.has_method("take_damage"):
		_estourar(corpo)


func _estourar(acertado: Node3D = null) -> void:
	if _estourou:
		return
	_estourou = true
	var pos := global_position

	RockFX.quebra(self, pos, 1.8)
	RockFX.detritos(self, pos, 12, 6.0, 0.30, 9.0)
	GlobalUtils.shake_camera(0.45, 0.55)

	var vitima := acertado
	if vitima == null and is_inside_tree():
		var p := get_tree().get_first_node_in_group("player")
		if p is Node3D and pos.distance_to((p as Node3D).global_position + Vector3.UP) <= blast_radius:
			vitima = p as Node3D
	if vitima != null and vitima != dono and vitima.has_method("take_damage"):
		vitima.take_damage(damage)
		GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.4)

	queue_free()
