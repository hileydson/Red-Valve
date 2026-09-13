extends Node3D

## Ataque 2 do Shadow Rock: as fagulhas de pedra que a espada cospe no corte.
##
## E uma LEVA de lascas saindo em leque na direcao onde o jogador estava no
## instante do golpe — nao um projetil so. O corte de uma espada de pedra de
## dois metros nao dispara uma bala: ele arranca a propria lamina e manda os
## cacos pra frente.
##
## Um no SO pra leva inteira, com uma checagem de dano por frame contra o
## jogador, em vez de vinte Area3D voando. Vinte areas monitorando colisao,
## cada uma com o proprio corpo no servidor de fisica, e justamente o tipo de
## coisa que o renderer Mobile nao perdoa — e o resultado em tela seria o
## mesmo.
##
## O dano sai UMA vez: quem for pego pela leva leva o golpe, e as lascas que
## vierem atras nao cobram de novo.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const RockFX := preload("res://scripts/effects/rock_fx.gd")

const CHAO := 2

## Dano de quem for pego pela leva.
var damage: int = 35
## Quantas lascas saem.
var quantidade: int = 18
## Velocidade das lascas, em m/s.
var velocidade: float = 26.0
## Ate onde elas viajam antes de se desfazer.
var alcance: float = 22.0
## Abertura do leque, em graus.
var abertura: float = 26.0
## Direcao do corte (horizontal, normalizada por quem cria).
var direcao: Vector3 = Vector3.FORWARD
## Dono do golpe: nunca se acerta a si mesmo.
var dono: Node3D = null
## Raio em que a lasca pega o jogador.
var raio_acerto: float = 1.25

var _lascas: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _acertou: bool = false
var _tempo: float = 0.0
var _iniciado: bool = false


## Como no `rock_debris`, a leva so e montada DEPOIS de posicionada: o som do
## corte sai no ponto da lamina, e no `_ready` o no ainda esta na origem do
## mundo. Quem cria posiciona e chama isto.
func iniciar() -> void:
	if _iniciado:
		return
	_iniciado = true
	_rng.randomize()
	if direcao.length() < 0.01:
		direcao = Vector3.FORWARD
	direcao = Vector3(direcao.x, 0.0, direcao.z).normalized()

	for i in quantidade:
		var mi := MeshInstance3D.new()
		# faixa simples: sao 18 lascas voando e some tudo em dois segundos
		mi.mesh = RockFX.pedra(_rng.randi(), true)
		mi.material_override = RockFX.material_quebrado()
		# lasca: comprida num eixo e fina nos outros. E o que le como estilhaco
		# de pedra em vez de pedrinha.
		var s := _rng.randf_range(0.16, 0.34)
		mi.scale = Vector3(s * 0.45, s * 0.45, s * _rng.randf_range(1.6, 2.8))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

		# leque horizontal com um pouco de espalhamento vertical
		var giro := deg_to_rad(_rng.randf_range(-abertura, abertura))
		var dir := direcao.rotated(Vector3.UP, giro)
		dir.y = _rng.randf_range(-0.10, 0.22)
		dir = dir.normalized()

		mi.position = Vector3(
			_rng.randf_range(-0.5, 0.5),
			_rng.randf_range(-0.35, 0.35),
			_rng.randf_range(-0.3, 0.3))
		mi.look_at(mi.global_position + dir, Vector3.UP)

		_lascas.append({
			"no": mi,
			"dir": dir,
			"vel": velocidade * _rng.randf_range(0.75, 1.25),
			"giro": Vector3(_rng.randf_range(-14.0, 14.0), 0.0, _rng.randf_range(-14.0, 14.0)),
			"andou": 0.0,
			"morta": false,
		})

	add_child(RockFX.po(16, 0.7, 1.3))
	add_child(RockFX.lascas(26, 7.0))
	FX.som_no_mundo(self, global_position, RockFX.SOM_PEDRA, -7.0, 0.62)


func _physics_process(delta: float) -> void:
	if not _iniciado:
		return
	_tempo += delta
	var vivas := 0
	var jogador := _player()

	for l in _lascas:
		if l["morta"]:
			continue
		var mi: MeshInstance3D = l["no"]
		if not is_instance_valid(mi):
			l["morta"] = true
			continue
		vivas += 1

		var passo: float = float(l["vel"]) * delta
		var antes := mi.global_position
		mi.global_position = antes + (l["dir"] as Vector3) * passo
		mi.rotation += (l["giro"] as Vector3) * delta
		l["andou"] = float(l["andou"]) + passo

		if not _acertou and jogador != null:
			# Mede contra o peito do jogador: no chao a lasca passaria por baixo
			# dele em metade dos casos.
			if mi.global_position.distance_to(jogador.global_position + Vector3.UP) <= raio_acerto:
				_acerta(jogador)

		if float(l["andou"]) >= alcance:
			_apaga(l, mi.global_position, false)
			continue

		# bateu no chao ou numa parede: vira po ali
		if is_inside_tree():
			var espaco := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(antes, mi.global_position, CHAO)
			if not espaco.intersect_ray(q).is_empty():
				_apaga(l, mi.global_position, true)

	if vivas == 0 or _tempo > 4.0:
		queue_free()


func _apaga(l: Dictionary, pos: Vector3, com_po: bool) -> void:
	l["morta"] = true
	var mi = l["no"]
	# So uma em cada tres deixa caco no chao. Dezoito montes de uma pedra so,
	# um por lasca, seria um no de detrito por lasca — o custo de tudo o que
	# este arquivo evitou ate aqui, cobrado no fim do voo.
	if com_po and is_inside_tree() and _rng.randf() < 0.34:
		RockFX.detritos(self, pos, 1, 1.6, 0.12, 5.0)
	if is_instance_valid(mi):
		mi.queue_free()


func _acerta(jogador: Node3D) -> void:
	if _acertou:
		return
	_acertou = true
	if jogador == dono or not jogador.has_method("take_damage"):
		return
	jogador.take_damage(damage)
	GlobalUtils.shake_camera(0.3, 0.4)
	GlobalUtils.vibrate_controller(null, 0.8, 0.8, 0.3)


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	var p := get_tree().get_first_node_in_group("player")
	return p as Node3D if p is Node3D else null
