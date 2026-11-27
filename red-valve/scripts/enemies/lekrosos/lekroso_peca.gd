extends RigidBody3D

## Uma parte do lekroso que caiu: um braco inteiro, uma mao, uma lasca de
## carne do peito, um naco da cabeca.
##
## E' a MALHA DE VERDADE da parte (a mesma casca do corpo, fechada com carne
## por baixo — ver `tools/blender/lekrosos/cortar.py`), posta exatamente na
## pose em que ela estava quando saiu. Quem monta e' o `lekroso.gd`; aqui
## so' a vida dela no chao:
##
##   cai, quica, deita e FICA — o chao conta a briga. Parou torta (em pe',
##   espetada, de quina)? `_assentar` tomba ela ate' a face mais larga
##   encostar no chao, e dali ela nao sai mais
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
## cima. Quem monta da' um palpite pela caixa; no `_ready` ele e' refeito
## pelos vertices de verdade (um braco dobrado no cotovelo nao cabe numa
## caixa de repouso).
var eixo_fino: Vector3 = Vector3.UP

## Quanto tempo parada antes de assentar, e o teto (quem fica tremendo).
const PARADA_PRA_ASSENTAR := 0.3
const TETO_PRA_ASSENTAR := 4.0
const DURACAO_ASSENTAR := 0.45

static var _vivas: Array = []

var _jato: GPUParticles3D
var _pingos: GPUParticles3D
var _pivo_corte: Node3D
var _pousou: bool = false
var _tempo: float = 0.0
var _proxima_gota: float = 0.4
## Os vertices da peca (amostra), no espaco deste corpo: e' por eles que se
## sabe a grossura e onde fica o ponto mais baixo.
var _pontos: PackedVector3Array = PackedVector3Array()
var _parada: float = 0.0
var _assentada: bool = false


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
	_le_pontos()

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
	if not _assentada and not freeze:
		var parada := linear_velocity.length() < 0.25 and angular_velocity.length() < 0.8
		_parada = _parada + delta if parada else 0.0
		if (_tempo > 0.6 and _parada > PARADA_PRA_ASSENTAR) or _tempo > TETO_PRA_ASSENTAR:
			_assentar()


# ------------------------------------------------------------ deitar

## Amostra dos vertices de todas as malhas da peca (o braco leva antebraco e
## mao junto, cada um na pose em que saiu), no espaco deste corpo. Dela sai o
## eixo fino de verdade: o de MENOR espalhamento dos pontos.
func _le_pontos() -> void:
	var todos := PackedVector3Array()
	for filho in get_children():
		var mi := filho as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for sup in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(sup)
			if arr.is_empty():
				continue
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var passo := maxi(1, vs.size() / 400)
			for i in range(0, vs.size(), passo):
				todos.append(mi.transform * vs[i])
	if todos.size() < 4:
		return
	_pontos = todos
	var fino := _menor_espalhamento(todos)
	if fino.length() > 0.5:
		eixo_fino = fino


## Autovetor de MENOR autovalor da covariancia dos pontos (a normal do plano
## que melhor passa por eles). Iteracao de potencia em (λmax·I − C).
static func _menor_espalhamento(pts: PackedVector3Array) -> Vector3:
	var media := Vector3.ZERO
	for q in pts:
		media += q
	media /= float(pts.size())
	var xx := 0.0
	var xy := 0.0
	var xz := 0.0
	var yy := 0.0
	var yz := 0.0
	var zz := 0.0
	for q in pts:
		var d := q - media
		xx += d.x * d.x
		xy += d.x * d.y
		xz += d.x * d.z
		yy += d.y * d.y
		yz += d.y * d.z
		zz += d.z * d.z
	var c := Basis(Vector3(xx, xy, xz), Vector3(xy, yy, yz), Vector3(xz, yz, zz))
	var teto := xx + yy + zz  # >= maior autovalor
	var m := Basis(Vector3(teto, 0, 0), Vector3(0, teto, 0), Vector3(0, 0, teto))
	m.x -= c.x; m.y -= c.y; m.z -= c.z
	var v := Vector3(0.31, 0.83, 0.47).normalized()
	for _i in 40:
		var w := m * v
		if w.length() < 1e-9:
			break
		v = w.normalized()
	return v


## Tomba a peca ate' o eixo fino ficar de pe' (a face mais larga no chao) e
## a poe encostada no chao. Dali em diante ela e' cenario: congelada.
func _assentar() -> void:
	_assentada = true
	var chao := Sangue.chao(get_world_3d(), global_position + Vector3.UP * 0.4, 3.0)
	var normal := Vector3.UP
	if not chao.is_empty():
		normal = (chao["normal"] as Vector3).normalized()
	var fino := (global_basis * eixo_fino).normalized()
	if fino.dot(normal) < 0.0:
		fino = -fino
	var de := global_basis.get_rotation_quaternion()
	var giro := Quaternion(fino, normal) if fino.dot(normal) < 0.9999 else Quaternion.IDENTITY
	var ate := giro * de
	var escala := global_basis.get_scale()
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var xz := global_position
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var q := de.slerp(ate, t)
		global_basis = Basis(q).scaled(escala)
		_encostar(xz, chao), 0.0, 1.0, DURACAO_ASSENTAR) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Poe o ponto mais baixo da peca rente ao chao, sem mexer no x/z.
func _encostar(xz: Vector3, chao: Dictionary) -> void:
	if _pontos.is_empty():
		return
	var y_chao := global_position.y - 0.3
	if not chao.is_empty():
		y_chao = (chao["position"] as Vector3).y
	var base := global_basis
	var menor := INF
	for q in _pontos:
		menor = minf(menor, (base * q).y)
	global_position = Vector3(xz.x, y_chao + 0.004 - menor, xz.z)


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
