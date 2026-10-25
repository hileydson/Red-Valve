extends Node3D

## Os bancos da nave da igreja, soltos do modelo pra poderem ser ARRASTADOS:
## no fim da chegada da Dona Nice, quando ela vira monstro, todos voam pras
## naves laterais e o meio da igreja fica livre pra luta. Dali em diante
## (estado >= 1 do evento) eles ja' nascem la', empilhados e com colisao.
##
## O gerador do Blender (`tools/blender/igreja/gerar_igreja.py`) exporta cada
## banco como objeto proprio, `SM_igr_bancoNN_madeira`. Aqui cada um ganha um
## pivo no chao, no meio dele, e uma vaga nas naves laterais.
##
## As vagas sairam de uma sondagem da colisao da igreja: ao norte (-X) a
## escada ocupa z 2-14 e o entulho do buraco z 10-21; ao sul (+X), o entulho e
## o confessionario z 14-21 e o caracol z 29-31. Os pilares das arcadas ficam
## em z 5, 12, 19 e 26 (~1 m pra cada lado), entao o voo cruza a arcada no z
## da vaga, que cai no meio de um vao livre.
##
## Quem cria este no' e' o `cena_dona_nice.gd`; quem manda afastar e' o
## diretor (`afastar_bancos`) ou o evento (`no_canto`, ao recomecar a luta).

const LAYER_CHAO := 2
## z do meio de cada vao livre, por lado. O banco deita ao longo do z.
const VAOS := {-1: [23.3, 29.5], 1: [8.5, 23.3]}
## |x| de cada fileira na nave lateral (a arcada fica em 7, a parede em 12,6).
const COLUNAS := [8.9, 9.8, 10.7, 11.6]
## O voo cruza a arcada a esta altura, e entra na nave lateral por aqui.
const ALTURA_DO_VOO := 2.4
const ENTRADA_X := [5.3, 6.4]
const SOM_BATIDA := "res://assets/sounds/igreja/tapa_chao.ogg"

var modelo: Node

var _bancos: Array[Dictionary] = []
var _estado := ""   # "" | "voando" | "no_canto"
var _tween: Tween
var _som: AudioStreamPlayer


func _ready() -> void:
	_som = AudioStreamPlayer.new()
	_som.stream = load(SOM_BATIDA)
	_som.volume_db = -9.0
	_som.max_polyphony = 4
	add_child(_som)
	if modelo:
		_preparar()


func _preparar() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1983
	var malhas := modelo.find_children("SM_igr_banco*", "MeshInstance3D", true, false)
	malhas.sort_custom(func(a, b): return String(a.name) < String(b.name))
	var por_lado := {-1: [], 1: []}
	for mi in malhas:
		var caixa: AABB = mi.global_transform * mi.get_aabb()
		var c := caixa.get_center()
		var pivo := Node3D.new()
		pivo.name = String(mi.name).replace("SM_igr_", "").replace("_madeira", "")
		add_child(pivo)
		pivo.global_position = Vector3(c.x, caixa.position.y, c.z)
		mi.owner = null
		mi.reparent(pivo, true)
		var b := {
			"pivo": pivo,
			"inicio": pivo.global_transform,
			"lado": -1 if c.x < 0.0 else 1,
			"altura": caixa.size.y,
			"giro": _giro_do_banco(mi),
		}
		por_lado[b["lado"]].append(b)
		_bancos.append(b)
	for lado in por_lado:
		_vagas(por_lado[lado], lado, rnd)


## O angulo (no plano XZ) do comprimento do banco: o eixo dos dois vertices
## mais distantes, vistos de cima.
func _giro_do_banco(mi: MeshInstance3D) -> float:
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var melhor := 0.0
	var eixo := Vector2.RIGHT
	for i in range(0, v.size(), 3):
		for j in range(i + 1, v.size(), 3):
			var d := Vector2(v[j].x - v[i].x, v[j].z - v[i].z)
			if d.length_squared() > melhor:
				melhor = d.length_squared()
				eixo = d
	return atan2(eixo.y, eixo.x)


## Cada banco ganha uma vaga: os da frente no vao da frente, empilhando quando
## o chao acaba. Um pouco torto de proposito — foram jogados, nao arrumados.
func _vagas(lista: Array, lado: int, rnd: RandomNumberGenerator) -> void:
	lista.sort_custom(func(a, b): return a["inicio"].origin.z < b["inicio"].origin.z)
	var pilhas := {}
	var vaos: Array = VAOS[lado]
	var i := 0
	for b in lista:
		var vao: float = vaos[(i / COLUNAS.size()) % vaos.size()]
		var col: float = COLUNAS[i % COLUNAS.size()]
		i += 1
		var chave := "%s_%s" % [vao, col]
		var y: float = pilhas.get(chave, 0.0)
		pilhas[chave] = y + b["altura"] * 0.82
		# o comprimento do banco vai pro eixo Z (ver `_giro_do_banco`)
		var giro: float = b["giro"] - PI * 0.5 + rnd.randf_range(-0.07, 0.07)
		if rnd.randf() < 0.5:
			giro += PI
		var basis := Basis(Vector3.UP, giro)
		if y > 0.0:
			basis = Basis(Vector3(0, 0, 1), rnd.randf_range(-0.18, 0.18)) * basis
		b["alvo"] = Transform3D(basis, Vector3(lado * (col + rnd.randf_range(-0.08, 0.08)),
			y, vao + rnd.randf_range(-0.15, 0.15)))
		b["vao"] = vao
		b["tombo"] = Vector3(rnd.randf_range(-1, 1), 0.0, rnd.randf_range(-1, 1)).normalized()
		b["tombo_ang"] = rnd.randf_range(0.5, 1.3)
		b["atraso"] = 0.12 + rnd.randf_range(0.0, 0.3)
		b["duracao"] = rnd.randf_range(1.0, 1.4)


## Ela os joga: cada banco sai num voo curto, cruza a arcada e cai na vaga.
func afastar() -> void:
	if _estado != "":
		return
	_estado = "voando"
	var centro := Vector3(0.0, 0.0, 18.0)
	_tween = create_tween().set_parallel(true)
	for b in _bancos:
		var longe := clampf(b["inicio"].origin.distance_to(centro) / 16.0, 0.0, 1.0)
		var atraso: float = b["atraso"] + 0.45 * longe
		_tween.tween_method(_voo.bind(b), 0.0, 1.0, b["duracao"]).set_delay(atraso) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_callback(_pousou.bind(b)).set_delay(atraso + b["duracao"])
	_tween.chain().tween_callback(func(): _estado = "no_canto")


## Ja' no lugar, sem voo (o recomeco da luta, e quem pulou a cutscene).
func no_canto() -> void:
	if _estado == "no_canto":
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	for b in _bancos:
		if not b.has("alvo"):
			continue
		(b["pivo"] as Node3D).global_transform = b["alvo"]
		_colisao(b)
	_estado = "no_canto"


func _voo(k: float, b: Dictionary) -> void:
	var p0: Vector3 = b["inicio"].origin
	var p3: Vector3 = b["alvo"].origin
	var lado: float = b["lado"]
	var vao: float = b["vao"]
	# cubica: as duas alcas ficam no z da vaga, entao quando o banco cruza a
	# arcada ele ja' esta' no vao livre, longe dos pilares
	var p1 := Vector3(lado * ENTRADA_X[0], ALTURA_DO_VOO, vao)
	var p2 := Vector3(lado * ENTRADA_X[1], ALTURA_DO_VOO, vao)
	var u := 1.0 - k
	var p := u * u * u * p0 + 3.0 * u * u * k * p1 + 3.0 * u * k * k * p2 + k * k * k * p3
	var q0: Quaternion = b["inicio"].basis.get_rotation_quaternion()
	var q1: Quaternion = b["alvo"].basis.get_rotation_quaternion()
	var q := q0.slerp(q1, k)
	# rodopia no ar e chega reto
	q = Quaternion(b["tombo"], b["tombo_ang"] * sin(PI * k)) * q
	(b["pivo"] as Node3D).global_transform = Transform3D(Basis(q), p)


func _pousou(b: Dictionary) -> void:
	(b["pivo"] as Node3D).global_transform = b["alvo"]
	_colisao(b)
	_som.pitch_scale = randf_range(0.8, 1.15)
	_som.play()


## Empilhado na nave lateral ele vira obstaculo de verdade (na nave, no
## lugar de antes, nunca teve colisao).
func _colisao(b: Dictionary) -> void:
	var pivo := b["pivo"] as Node3D
	if pivo.has_node("corpo"):
		return
	var mi := pivo.get_child(0) as MeshInstance3D
	var caixa: AABB = mi.transform * mi.get_aabb()
	var corpo := StaticBody3D.new()
	corpo.name = "corpo"
	corpo.collision_layer = LAYER_CHAO
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = caixa.size
	forma.shape = box
	forma.position = caixa.get_center()
	corpo.add_child(forma)
	pivo.add_child(corpo)
