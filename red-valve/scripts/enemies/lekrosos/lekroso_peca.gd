extends RigidBody3D

## Uma parte do lekroso que caiu: um braco inteiro, uma mao, uma lasca de
## carne do peito, um naco da cabeca.
##
## E' a MALHA DE VERDADE da parte (a mesma casca do corpo, fechada com carne
## por baixo — ver `tools/blender/lekrosos/cortar.py`), posta exatamente na
## pose em que ela estava quando saiu. Quem monta e' o `lekroso.gd`; aqui
## so' a vida dela no chao:
##
##   cai, quica, deita e FICA — o chao conta a briga
##   o corte espirra sangue em golfadas por `tempo_jorro` segundos (o braco
##   bem mais que uma lasca), depois so' pinga
##   a poca cresce embaixo dela
##   depois de `permanencia` segundos ela afunda devagar e some
##
## Fisica: so' colide com o cenario (camadas 1 e 2). Ninguem colide com ela —
## o jogador passa por cima de um braco sem tropecar, e o tiro nao "acerta"
## um pedaco morto.

const Sangue := preload("res://scripts/enemies/lekrosos/lekroso_sangue.gd")

const MAX_PECAS := 26

## Onde fica o corte, no espaco DESTE corpo, e pra onde a carne aberta olha.
var corte_local: Vector3 = Vector3.ZERO
var corte_normal: Vector3 = Vector3.UP
var tempo_jorro: float = 4.0
var forca_jorro: float = 0.8
var permanencia: float = 90.0
var tam_poca: float = 0.5
var e_membro: bool = false
## O eixo mais FINO da peca, no espaco deste corpo: deitada, ele aponta pra
## cima. (Quem monta mede pela caixa da malha.)
var eixo_fino: Vector3 = Vector3.UP

static var _vivas: Array = []

var _jato: GPUParticles3D
var _pingos: GPUParticles3D
var _pivo_corte: Node3D
var _pousou: bool = false
var _tempo: float = 0.0
var _proxima_gota: float = 0.4
var _tombos: int = 0
var _proximo_tombo: float = 1.2


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	linear_damp = 0.15
	angular_damp = 0.8
	var fis := PhysicsMaterial.new()
	fis.bounce = 0.12
	fis.friction = 1.0
	fis.rough = true
	physics_material_override = fis
	body_entered.connect(_bateu)

	_vivas = _vivas.filter(func(p): return is_instance_valid(p))
	_vivas.append(self)
	while _vivas.size() > MAX_PECAS:
		var velha = _vivas.pop_front()
		if is_instance_valid(velha):
			velha.afundar(1.5)

	_pivo_corte = Node3D.new()
	add_child(_pivo_corte)
	_pivo_corte.position = corte_local
	_mira_pivo()

	_jato = Sangue.jorro(forca_jorro)
	_pivo_corte.add_child(_jato)
	Sangue.pulsar(_jato, tempo_jorro, 0.5 if e_membro else 0.4)
	_pingos = Sangue.pingos(0.8 if e_membro else 0.45)
	_pivo_corte.add_child(_pingos)
	_pingos.emitting = true

	var t := get_tree().create_timer(tempo_jorro + (40.0 if e_membro else 14.0), false)
	t.timeout.connect(func():
		if is_instance_valid(_pingos):
			_pingos.emitting = false)
	get_tree().create_timer(permanencia, false).timeout.connect(afundar.bind(4.0))


func _mira_pivo() -> void:
	var n := corte_normal.normalized()
	if n.length() < 0.01:
		n = Vector3.UP
	var cima := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	# o -Z do jorro aponta pra fora do corte
	_pivo_corte.basis = Basis.looking_at(n, cima)


func _physics_process(delta: float) -> void:
	_tempo += delta
	# o sangue que cai do corte mancha o chao embaixo, uma gota de cada vez
	if is_instance_valid(_pingos) and _pingos.emitting:
		_proxima_gota -= delta
		if _proxima_gota <= 0.0:
			_proxima_gota = randf_range(0.25, 0.7) if _tempo < tempo_jorro else randf_range(0.6, 1.6)
			var de := _pivo_corte.global_position
			var c := Sangue.chao(get_world_3d(), de + Vector3.UP * 0.05, 2.5)
			if not c.is_empty():
				var tam := randf_range(0.05, 0.12) if _tempo > tempo_jorro else randf_range(0.10, 0.22)
				Sangue.mancha(get_tree(), c["position"], c["normal"], tam, "gota", 50.0)
	if not _pousou and _tempo > 1.6 and linear_velocity.length() < 0.3:
		_pousar()
	_tombar_se_em_pe()


## Peca que parou EM PE (o antebraco espetado no chao, a lasca de quina como
## barbatana) le como erro, nao como membro caido. Assentou assim: um tranco
## de lado ate' ela deitar (tres tentativas).
func _tombar_se_em_pe() -> void:
	if _tombos >= 3 or _tempo < _proximo_tombo:
		return
	if linear_velocity.length() > 0.25 or angular_velocity.length() > 0.6:
		return
	var fino := (global_basis * eixo_fino).normalized()
	if absf(fino.dot(Vector3.UP)) > 0.55:
		_tombos = 3
		return
	_tombos += 1
	_proximo_tombo = _tempo + 0.9
	sleeping = false
	var giro := fino.cross(Vector3.UP).normalized()
	apply_torque_impulse(giro * mass * 0.35)
	apply_central_impulse(Vector3.UP * mass * 0.6)


func _bateu(_corpo: Node) -> void:
	if _tempo < 0.05:
		return
	var v := linear_velocity.length()
	if v > 1.2:
		Sangue.som(self, global_position, "res://assets/sounds/player/blood_out.mp3",
			clampf(-14.0 + v * 2.5, -14.0, -2.0), randf_range(0.55, 0.75), 16.0)
		var c := Sangue.chao(get_world_3d(), global_position + Vector3.UP * 0.3, 1.5)
		if not c.is_empty():
			Sangue.mancha(get_tree(), c["position"], c["normal"],
				randf_range(0.18, 0.32) * (1.4 if e_membro else 1.0), "respingo", 60.0)
	if not _pousou and _tempo > 0.4 and v < 0.8:
		_pousar()


func _pousar() -> void:
	_pousou = true
	Sangue.poca(get_tree(), get_world_3d(), global_position, tam_poca,
		6.0 if e_membro else 3.5, permanencia)


## Some devagar, afundando no chao (sem ninguem ver um braco sumir no ar).
func afundar(duracao: float = 4.0) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_vivas.erase(self)
	freeze = true
	collision_mask = 0
	if is_instance_valid(_jato):
		_jato.emitting = false
	if is_instance_valid(_pingos):
		_pingos.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3.DOWN * 0.35, duracao) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
