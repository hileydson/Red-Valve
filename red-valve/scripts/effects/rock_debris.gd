extends Node3D

## O monte de cacos de pedra que sobe, cai e FICA no chao.
##
## E o efeito que define o Shadow Rock: cada dano que ele leva arranca pedra do
## corpo dele, e essa pedra tem de subir, bater no chao e continuar la por
## alguns segundos, marcando o lugar da briga. Um inimigo que so pisca de
## vermelho ao levar tiro nao conta essa historia.
##
## Por que fisica na mao em vez de RigidBody3D:
##   - sao ate 8 cacos por TIRO. Cada RigidBody3D e um corpo no servidor de
##     fisica, com broadphase, colisao par a par e ilha de sono. Um punhado de
##     balas vira dezenas deles, e no renderer Mobile isso derruba o frame;
##   - caco de pedra nao precisa colidir com nada alem do chao — e a altura do
##     chao sai de UM raycast no nascimento, compartilhado pelo monte inteiro
##     (o monte cabe em um metro quadrado; amostrar por caco seria pagar 8
##     raycasts pra achar o mesmo numero);
##   - sem corpo fisico nenhum, os cacos tambem nao empurram o jogador nem
##     entram no caminho do tiro dele.
##
## Todos os cacos de um monte vivem neste UNICO no, com um `_process` so.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const RockFX := preload("res://scripts/effects/rock_fx.gd")

## Camada fisica do chao (terreno da stage_1 e piso da arena).
const CHAO := 2
const GRAVIDADE := 22.0
## Quanto da velocidade sobra depois de quicar. Pedra quica mal: e isso que
## faz o caco parar quase onde caiu em vez de rolar como uma bola.
const QUIQUE := 0.24

## Quantos cacos o monte tem.
var quantidade: int = 5
## Velocidade inicial, em m/s. Alto = explosao; baixo = pedaco que se soltou.
var forca: float = 4.0
## Tamanho medio do caco, em metros.
var escala: float = 0.16
## Segundos parado no chao antes de comecar a afundar.
var permanencia: float = 7.0
## Direcao preferida do arremesso (ZERO = pra cima e pra todo lado).
var direcao: Vector3 = Vector3.ZERO
## Cacos prontos, pra reaproveitar a MALHA EXATA do pedaco arrancado do corpo:
## [{ "mesh": Mesh, "escala": Vector3, "pos": Vector3, "rot": Vector3 }], com
## `pos` e `rot` em coordenadas de MUNDO — o monte nasce sem rotacao propria,
## entao quem entrega uma rotacao local de um no girado (a parede, o membro
## caindo) faz o caco dar um pulo de orientacao no frame do impacto.
## Assim a pedra que estava no ombro dele e a mesma que fica no chao.
var modelos: Array = []

var _pecas: Array[Dictionary] = []
var _chao_y: float = -99999.0
var _rng := RandomNumberGenerator.new()
var _tempo: float = 0.0
var _todos_parados: bool = false
var _t_parado: float = 0.0
var _afundando: bool = false
var _iniciado: bool = false


## Monta o monte. NAO e `_ready`: o no so sabe onde esta depois que quem o criou
## ajusta o `global_position`, e tanto o raycast do chao quanto a posicao dos
## cacos prontos dependem disso. Montar no `_ready` procuraria o chao na origem
## do mundo. Quem cria chama isto — o `rock_fx.detritos()` faz por todo mundo.
func iniciar() -> void:
	if _iniciado:
		return
	_iniciado = true
	_rng.randomize()
	_acha_chao()
	_monta()
	if _pecas.is_empty():
		queue_free()
		return
	add_child(RockFX.po(int(6 + quantidade * 2), escala * 3.0, 1.4))


## Um raycast pro monte inteiro. Sem chao embaixo (buraco, borda do mapa), os
## cacos caem ate sumir e o no se libera pelo tempo de vida.
func _acha_chao() -> void:
	if not is_inside_tree():
		return
	var espaco := get_world_3d().direct_space_state
	var de := global_position + Vector3.UP * 2.5
	var ate := global_position + Vector3.DOWN * 25.0
	var q := PhysicsRayQueryParameters3D.create(de, ate, CHAO)
	var acerto := espaco.intersect_ray(q)
	if acerto.has("position"):
		_chao_y = (acerto["position"] as Vector3).y


func _monta() -> void:
	for i in quantidade:
		var mi := MeshInstance3D.new()
		var pos_local := Vector3.ZERO
		var giro := Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)

		if i < modelos.size():
			var m: Dictionary = modelos[i]
			mi.mesh = m.get("mesh", RockFX.pedra(_rng.randi(), true))
			mi.scale = m.get("escala", Vector3.ONE * escala)
			if m.has("pos"):
				pos_local = to_local(m["pos"])
			if m.has("rot"):
				giro = m["rot"]
		else:
			mi.mesh = RockFX.pedra(_rng.randi(), true)
			var s := escala * _rng.randf_range(0.45, 1.35)
			mi.scale = Vector3(s, s * _rng.randf_range(0.6, 1.0), s * _rng.randf_range(0.8, 1.2))
			pos_local = Vector3(
				_rng.randf_range(-0.2, 0.2),
				_rng.randf_range(-0.1, 0.2),
				_rng.randf_range(-0.2, 0.2))

		mi.material_override = RockFX.material_quebrado()
		mi.position = pos_local
		mi.rotation = giro
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)

		# Sai pra cima e pra fora. Quando ha `direcao`, ela domina — e o caso
		# do tiro, que joga a pedra na direcao contraria ao impacto.
		var espalha := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		if espalha.length() < 0.01:
			espalha = Vector3(1, 0, 0)
		espalha = espalha.normalized()
		var v := (espalha * _rng.randf_range(0.4, 1.0) + Vector3.UP * _rng.randf_range(0.9, 1.6))
		if direcao != Vector3.ZERO:
			v = (v * 0.45 + direcao.normalized() * 1.1).normalized() * v.length()
		v *= forca * _rng.randf_range(0.6, 1.25)

		_pecas.append({
			"no": mi,
			"vel": v,
			"giro": Vector3(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-9.0, 9.0), _rng.randf_range(-9.0, 9.0)),
			"parado": false,
			# meia altura do caco: e onde ele encosta no chao
			"raio": maxf(mi.scale.y, 0.02) * 0.5,
		})


func _process(delta: float) -> void:
	if not _iniciado:
		return
	_tempo += delta

	if _afundando:
		position.y -= delta * 0.35
		return

	if _todos_parados:
		_t_parado += delta
		if _t_parado >= permanencia:
			_afunda()
		return

	var parados := 0
	for p in _pecas:
		var mi: MeshInstance3D = p["no"]
		if not is_instance_valid(mi):
			parados += 1
			continue
		if p["parado"]:
			parados += 1
			continue

		var v: Vector3 = p["vel"]
		v.y -= GRAVIDADE * delta
		var pos := mi.global_position + v * delta
		var piso: float = _chao_y + float(p["raio"])

		if _chao_y > -99998.0 and pos.y <= piso:
			pos.y = piso
			if absf(v.y) < 1.6:
				# perdeu o embalo: assenta, deita e para de vez
				p["parado"] = true
				v = Vector3.ZERO
				_assenta(mi)
				_baque(mi.global_position)
			else:
				v.y = -v.y * QUIQUE
				v.x *= 0.55
				v.z *= 0.55
				p["giro"] = (p["giro"] as Vector3) * 0.5
				_baque(pos)

		mi.global_position = pos
		p["vel"] = v
		if not p["parado"]:
			mi.rotation += (p["giro"] as Vector3) * delta

	# 12 s no ar sem achar chao (caiu num buraco): some.
	if _tempo > 12.0:
		_afunda()
		return

	if parados >= _pecas.size():
		_todos_parados = true
		_t_parado = 0.0


## Deita o caco: um pedaco de pedra no chao nao fica em pe na quina. Gira so em
## Y (a direcao em que ele parou) e zera a inclinacao.
func _assenta(mi: MeshInstance3D) -> void:
	mi.rotation = Vector3(_rng.randf_range(-0.25, 0.25), mi.rotation.y, _rng.randf_range(-0.25, 0.25))


## Baque de pedra no chao. Um a cada tantos cacos: oito estalos no mesmo frame
## viram ruido branco.
func _baque(pos: Vector3) -> void:
	if _rng.randf() > 0.34:
		return
	FX.som_no_mundo(self, pos, RockFX.SOM_PEDRA, -20.0, _rng.randf_range(0.55, 0.85))


func _afunda() -> void:
	if _afundando:
		return
	_afundando = true
	var t := create_tween()
	t.tween_interval(1.4)
	t.tween_callback(queue_free)
