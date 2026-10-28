extends StaticBody3D

## Defesa do Shadow Rock: a parede de pedra.
##
## Ele ergue as maos e a parede sobe do chao PEDRA POR PEDRA entre ele e o
## jogador. Fica de pe alguns instantes — e nesses instantes o tiro do jogador
## bate NELA, nao nele — e depois anda pra frente ate esmagar quem estiver no
## caminho.
##
## Por que ela e um StaticBody3D na camada 3 (a dos inimigos):
##   o tiro do jogador e um RayCast3D com mascara 12 (camadas 3 e 4, corpo do
##   inimigo e area de acerto critico). Um raycast para no PRIMEIRO corpo que
##   encontra. Pondo a parede na camada 3, o bloqueio sai de graca e pela via
##   certa: a bala acerta a pedra porque a pedra esta na frente, e nao porque
##   alguem escreveu uma excecao. E como ela tem `take_damage`, o jogador pode
##   DERRUBAR a parede a tiros em vez de so esperar — que e o que transforma a
##   defesa em problema pra resolver.
##
##   `collision_mask = 0` de proposito: ela nao empurra nem e empurrada por
##   nada. O dano de encostao sai da Area3D filha, nao da fisica.
##
## O `protege()` existe pro resto do dano do jogo (lamina, ultimate, area) que
## nao passa por raycast nenhum: o inimigo pergunta a parede se ela esta na
## frente antes de aceitar o golpe.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const RockFX := preload("res://scripts/effects/rock_fx.gd")

signal caiu

## Largura, altura e espessura da parede, em metros.
var largura: float = 5.4
var altura: float = 3.1
var espessura: float = 0.75
## Quanto dano ela aguenta antes de desabar.
var vida: int = 120
## Dano em quem ela alcancar enquanto avanca.
var dano: int = 30
## Dono: a parede nunca machuca quem a levantou.
var dono: Node3D = null

var _blocos: Array[MeshInstance3D] = []
var _vida_atual: int = 0
var _rng := RandomNumberGenerator.new()
var _area: Area3D
var _avancando: bool = false
var _vel_avanco: float = 0.0
var _dir_avanco: Vector3 = Vector3.ZERO
var _bateu: bool = false
var _caindo: bool = false
var _pronta: bool = false


func _ready() -> void:
	_rng.randomize()
	collision_layer = 4     # camada 3: e nela que o tiro do jogador esbarra
	collision_mask = 0
	_vida_atual = vida
	_monta_colisao()
	_monta_area()


## Tres caixas no lugar de uma por bloco. O raycast do tiro so precisa de algo
## solido no caminho; vinte e quatro formas de colisao pra mesma parede seriam
## vinte e tres a mais do que o efeito pede.
func _monta_colisao() -> void:
	for i in 3:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(largura / 3.0 + 0.1, altura, espessura)
		cs.shape = box
		cs.position = Vector3((float(i) - 1.0) * (largura / 3.0), altura * 0.5, 0.0)
		add_child(cs)
	# Ate a parede ficar de pe, ela nao para bala nenhuma: a colisao so liga
	# quando ha pedra suficiente pra justificar (ver `construir`).
	_liga_colisao(false)


func _liga_colisao(ligada: bool) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = not ligada


func _monta_area() -> void:
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1  # so o corpo do jogador
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(largura + 0.6, altura + 1.0, espessura + 1.1)
	cs.shape = box
	cs.position = Vector3(0, altura * 0.5, 0)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_no_corpo)


# ============================================================= construcao

## Levanta a parede em `duracao` segundos, uma pedra de cada vez. As pedras
## sobem do chao com um atraso crescente: o jogador ve a parede FECHANDO e tem
## tempo de decidir se corre pro lado ou se comeca a atirar nela.
func construir(duracao: float) -> void:
	var colunas := 7
	var linhas := 4
	var passo_x := largura / float(colunas)
	var passo_y := altura / float(linhas)
	var total := colunas * linhas
	var i := 0

	for ly in linhas:
		for cx in colunas:
			# Bloco maior que a celula da fiada: uma parede erguida as pressas
			# com pedras avulsas nao tem junta perfeita, mas tambem nao pode
			# ficar VAZADA — com o bloco do tamanho exato da celula a parede
			# nasce cheia de buracos e deixa de ler como parede.
			var bloco := RockFX.bloco(self, Vector3.ZERO,
				maxf(passo_x, passo_y) * 1.45, _rng, 0.22)
			bloco.scale = Vector3(
				bloco.scale.x,
				bloco.scale.y,
				espessura * _rng.randf_range(0.85, 1.25))
			# fiada com junta desencontrada, como parede de pedra de verdade
			var desloc := 0.0 if ly % 2 == 0 else passo_x * 0.5
			var destino := Vector3(
				(float(cx) - float(colunas - 1) * 0.5) * passo_x + desloc + _rng.randf_range(-0.06, 0.06),
				passo_y * (float(ly) + 0.5) + _rng.randf_range(-0.05, 0.05),
				_rng.randf_range(-0.08, 0.08))
			# giro so em Z e Y: pedra de parede assenta deitada
			bloco.rotation = Vector3(
				_rng.randf_range(-0.12, 0.12),
				_rng.randf_range(-0.35, 0.35),
				_rng.randf_range(-0.25, 0.25))

			# nasce enterrada, sobe pro lugar
			bloco.position = destino - Vector3(0, altura + 0.8, 0)
			bloco.visible = false
			_blocos.append(bloco)

			var atraso := duracao * 0.88 * (float(i) / float(total))
			var t := bloco.create_tween()
			t.tween_interval(atraso)
			t.tween_callback(func() -> void:
				if is_instance_valid(bloco):
					bloco.visible = true
					_po_no_bloco(bloco))
			t.tween_property(bloco, "position", destino, 0.26)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			i += 1

	# a colisao entra quando a parede ja tem corpo (metade das pedras no lugar)
	var t2 := create_tween()
	t2.tween_interval(duracao * 0.5)
	t2.tween_callback(func() -> void:
		_liga_colisao(true)
		_pronta = true)

	FX.som_no_mundo(self, global_position, RockFX.SOM_PEDRA, -4.0, 0.30)


func _po_no_bloco(bloco: MeshInstance3D) -> void:
	var p := RockFX.po(5, 0.4, 0.9)
	bloco.add_child(p)
	var t := bloco.create_tween()
	t.tween_interval(1.2)
	t.tween_callback(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


# ================================================================ avanco

## Empurra a parede pra frente por `duracao` segundos. `dir` e horizontal.
func avancar(dir: Vector3, duracao: float, distancia: float) -> void:
	if _caindo:
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_dir_avanco = dir.normalized()
	_vel_avanco = distancia / maxf(duracao, 0.1)
	_avancando = true
	FX.som_no_mundo(self, global_position, RockFX.SOM_PEDRA, -8.0, 0.26)


func _physics_process(delta: float) -> void:
	if not _avancando or _caindo:
		return
	global_position += _dir_avanco * _vel_avanco * delta
	# tremor: uma parede de pedra arrastando nao desliza lisa
	for b in _blocos:
		if is_instance_valid(b):
			b.position.x += _rng.randf_range(-0.004, 0.004)
			b.position.y += _rng.randf_range(-0.004, 0.004)

	if _bateu:
		return
	# Alem da Area3D (que so dispara quando o jogador ENTRA nela), mede a
	# distancia: se ele ja estava dentro quando a parede subiu, o sinal de
	# entrada nunca vem.
	var p := _player()
	if p != null and _dentro(p.global_position):
		_esmaga(p)


func _no_corpo(corpo: Node3D) -> void:
	if _bateu or _caindo or corpo == dono:
		return
	if corpo.is_in_group("player") or corpo.has_method("take_damage"):
		_esmaga(corpo)


func _dentro(pos: Vector3) -> bool:
	var local := to_local(pos)
	return absf(local.x) <= largura * 0.5 + 0.4 \
		and absf(local.z) <= espessura * 0.5 + 0.7 \
		and local.y >= -0.6 and local.y <= altura + 0.8


func _esmaga(vitima: Node3D) -> void:
	if _bateu or vitima == dono:
		return
	_bateu = true
	if vitima.has_method("take_damage"):
		vitima.take_damage(dano)
	GlobalUtils.shake_camera(0.4, 0.5)
	GlobalUtils.vibrate_controller(null, 1.0, 1.0, 0.4)
	RockFX.quebra(self, vitima.global_position, 1.2)
	# Um encontrao so. A parede segue andando, mas nao cobra pedagio por frame.


# ================================================================= dano

## O tiro do jogador chega aqui porque a parede esta na camada dos inimigos.
## Cada golpe arranca uma pedra de verdade dela — e como ha 28 pedras e a vida
## da conta de umas dez balas, da pra VER a parede se abrindo antes de cair.
func take_damage(amount) -> void:
	if _caindo:
		return
	_vida_atual -= int(amount)
	_arranca_bloco()
	if _vida_atual <= 0:
		desabar()


func _arranca_bloco() -> void:
	var vivos: Array[MeshInstance3D] = []
	for b in _blocos:
		if is_instance_valid(b) and b.visible:
			vivos.append(b)
	if vivos.is_empty():
		return
	var b: MeshInstance3D = vivos[_rng.randi() % vivos.size()]
	var pos := b.global_position
	RockFX.detritos(self, pos, 2, 3.2, maxf(b.scale.y, 0.1) * 0.55, 6.0,
		[{"mesh": b.mesh, "escala": b.scale, "pos": pos, "rot": b.global_rotation}])
	RockFX.quebra(self, pos, 0.4, false)
	FX.som_no_mundo(self, pos, RockFX.SOM_PEDRA, -16.0, _rng.randf_range(0.5, 0.7))
	_blocos.erase(b)
	b.queue_free()


## Esta parede esta no caminho entre `de` e `ate`? E o que o inimigo pergunta
## antes de aceitar um dano que nao veio por raycast (lamina, ultimate, area).
func protege(de: Vector3, ate: Vector3) -> bool:
	if _caindo or not _pronta or _blocos.size() < 6:
		return false
	var a := to_local(de)
	var b := to_local(ate)
	# Lados opostos da parede (o Z local e a espessura dela).
	if signf(a.z) == signf(b.z):
		return false
	var t := absf(a.z) / maxf(absf(a.z) + absf(b.z), 0.0001)
	var cruzou_x := lerpf(a.x, b.x, t)
	var cruzou_y := lerpf(a.y, b.y, t)
	return absf(cruzou_x) <= largura * 0.5 and cruzou_y >= -0.2 and cruzou_y <= altura


# =============================================================== fim

## Derruba tudo: cada pedra da parede vira caco no chao.
func desabar() -> void:
	if _caindo:
		return
	_caindo = true
	_avancando = false
	_liga_colisao(false)
	if is_instance_valid(_area):
		_area.monitoring = false

	var modelos: Array = []
	for b in _blocos:
		if is_instance_valid(b) and b.visible:
			modelos.append({
				"mesh": b.mesh, "escala": b.scale,
				"pos": b.global_position, "rot": b.global_rotation,
			})
			b.visible = false

	var pos := global_position + Vector3.UP * (altura * 0.4)
	# So parte das pedras vira caco: 28 montes de detrito de uma vez estouram o
	# teto do `rock_fx` e nao acrescentam nada que o po nao conte melhor.
	if not modelos.is_empty():
		var quantas: int = mini(modelos.size(), 14)
		RockFX.detritos(self, pos, quantas, 4.2, 0.3, 8.0, modelos.slice(0, quantas))
	RockFX.quebra(self, pos, 1.6)
	GlobalUtils.shake_camera(0.3, 0.35)
	caiu.emit()

	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_callback(queue_free)


## Fim programado (o golpe acabou): a parede desaba igual, sem drama.
func encerrar() -> void:
	desabar()


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	var p := get_tree().get_first_node_in_group("player")
	return p as Node3D if p is Node3D else null
