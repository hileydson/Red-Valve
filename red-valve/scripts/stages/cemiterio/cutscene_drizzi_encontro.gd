extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A DRIZZI NA PORTA DA CAPELA (Capítulo 3, cemitério).
##
## Ela está de costas, na escadaria da capela, no meio da névoa. O Maycow
## chega perto e:
##
##   1. a câmera fecha na nuca dela (o rosto nunca em close: a boca dela não
##      mexe) e ela fala;
##   2. ela vira devagar; a câmera vai pra longe;
##   3. ela vem andando atrás dele enquanto fala — ela não acredita que o
##      Maycow faria mal ao Jonny — e ele recua de costas;
##   4. ela o acusa de maltratar o filho, abaixa, pega terra do chão e come;
##   5. de joelhos, come terra sem parar e grita; a poeira sobe e toma conta
##      de tudo, e ele se afasta;
##   6. o barulho para de uma vez e a poeira desce devagar: ela sumiu;
##   7. ele olha pra um lado e pro outro e dá uns passos;
##   8. o chão estoura na frente dele e a Drizzi MONSTRO sai cavando de baixo
##      pra cima, no meio da poeira; fica olhando pra ele, e grita.
##
## No preto do fim ela vira a chefe de verdade: `no_preto` entrega o lugar
## dela ao cemitério (`capitulo_3_cemiterio.gd`), que põe a luta ali.

signal no_preto(onde: Transform3D)

const CorpoDoMaycow := preload("res://scripts/cutscenes/corpo_do_maycow.gd")
const AtorDrizzi := preload("res://scripts/npcs/drizzi/ator_drizzi.gd")
const Poeira := preload("res://scripts/effects/poeira_drizzi.gd")

const SOM_FUNDO := "res://assets/sounds/escola/atmosfera_fantasma.ogg"
const SOM_VENTO := "res://assets/sounds/cenarios/vento_tempestade.ogg"
const SOM_GRITO := "res://assets/sounds/igreja/grito_monstro.ogg"
const SOM_GRITO_2 := "res://assets/sounds/igreja/grito_transformacao.ogg"
const SOM_RUGIDO := "res://assets/sounds/igreja/rugido_monstro.ogg"
const SOM_QUEDA := "res://assets/sounds/igreja/tapa_chao.ogg"
const SOM_OSSOS := "res://assets/sounds/igreja/transformacao_ossos.ogg"
const SOM_MORDIDAS := ["res://assets/sounds/igreja/mordida_1.ogg",
	"res://assets/sounds/igreja/mordida_2.ogg", "res://assets/sounds/igreja/mordida_3.ogg"]
const COR_POEIRA_TELA := Color(0.33, 0.29, 0.24)

## Andando: ela vem a isto, ele recua a isto (m/s).
const PASSO_DELA := 0.75
const PASSO_DELE := 0.7

var drizzi: Node3D
## `corpo_do_maycow.gd` (sem tipo: os métodos são do script).
var corpo
var _monstro: Node3D
## As nuvens da poeira que ela levanta (descem no silêncio).
var _nuvens_no_ar: Array = []
var _poeira_tela: ColorRect
var _sons: Array[AudioStreamPlayer] = []
var _vento: AudioStreamPlayer
## A direção dela até ele, no chão (fixa a cena toda).
var _rumo := Vector3.BACK
var _lado := Vector3.RIGHT


func rodar(dono: Node3D, jogador: CharacterBody3D, a_drizzi: Node3D) -> void:
	drizzi = a_drizzi
	travar(dono, jogador, 48.0)
	corpo = CorpoDoMaycow.assumir(player)
	corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.4)
	_montar_poeira_tela()
	_fundo()
	var d := _pes() - drizzi.global_position
	d.y = 0.0
	_rumo = d.normalized() if d.length() > 0.1 else Vector3.BACK
	_lado = _rumo.cross(Vector3.UP).normalized()
	_virar_maycow_para(drizzi.global_position)

	await _nuca()
	if vale():
		await _vira()
	if vale():
		await _vem_atras_dele()
	if vale():
		await _acusa_e_come()
	if vale():
		await _poeira()
	if vale():
		await _silencio()
	if vale():
		await _olha_em_volta()
	if vale():
		await _monstro_sai_do_chao()
	if not vale():
		_limpar()
		return
	await escurecer(1.0, 1.3)
	var onde := _monstro.global_transform if is_instance_valid(_monstro) else drizzi.global_transform
	if is_instance_valid(_monstro):
		_monstro.queue_free()
	_limpar()
	no_preto.emit(onde)
	await esperar(0.7)
	encerrar(1.4)


# ============================================================ os planos

## 1. A nuca dela, bem de perto; ela fala sem virar.
func _nuca() -> void:
	var cab: Vector3 = drizzi.call("cabeca")
	var costas := -drizzi.global_basis.z
	costas.y = 0.0
	costas = costas.normalized()
	var de := cab + costas * 0.95 + _lado * 0.18 + Vector3.UP * 0.06
	var ate := cab + costas * 0.6 + _lado * 0.1 + Vector3.UP * 0.03
	legenda("CAP3_DRIZZI_1", 3.2)
	await plano(de, cab, ate, cab, 4.2)


## 2. Ela vira devagar, de frente pra ele; a câmera vai pra longe, do lado
## dela: ela de perfil (o rosto pequeno) e ele lá atrás.
func _vira() -> void:
	var meio := drizzi.global_position + _rumo * 2.5
	var longe := drizzi.global_position + _lado * 5.5 + _rumo * 1.2 + Vector3.UP * 1.7
	plantar(longe, meio + Vector3.UP * 1.0)
	var g0: float = drizzi.global_rotation.y
	var g1: float = drizzi.call("giro_para", _pes())
	var delta := wrapf(g1 - g0, -PI, PI)
	legenda("CAP3_DRIZZI_2", 3.4)
	await fase(4.0, func(k: float) -> void:
		drizzi.global_rotation.y = g0 + delta * suave(k)
		plantar(longe + _lado * k * 0.6, meio + Vector3.UP * 1.0))


## 3. Ela vem andando atrás dele e fala; ele recua de costas. A câmera fica
## atrás dela, por cima do ombro: o rosto dele, as costas dela.
func _vem_atras_dele() -> void:
	drizzi.call("tocar", &"andar", 0.4)
	corpo.tocar(&"normal/Walk_Backward_inplace", 0.4)
	var falas := [[0.2, "CAP3_DRIZZI_3", 3.6], [4.0, "CAP3_DRIZZI_4", 3.9], [8.1, "CAP3_DRIZZI_5", 3.9]]
	var ditas := {}
	var dur := 11.5
	await fase(dur, func(k: float) -> void:
		var dt := get_process_delta_time()
		_andar_drizzi(_rumo * PASSO_DELA * dt)
		_andar_maycow(_rumo * PASSO_DELE * dt)
		_virar_maycow_para(drizzi.global_position)
		var costas := -_rumo
		var ombro: Vector3 = drizzi.global_position + costas * 2.1 + _lado * 0.75 + Vector3.UP * 2.05
		plantar(ombro, _pes() + Vector3.UP * 1.35)
		var t := k * dur
		for f in falas:
			if t >= float(f[0]) and not ditas.has(f[1]):
				ditas[f[1]] = true
				legenda(String(f[1]), float(f[2])))


## 4. Ela para e acusa; ele tenta falar; ela pega terra do chão e come.
func _acusa_e_come() -> void:
	drizzi.call("tocar", &"acusando", 0.4)
	corpo.tocar(&"normal/Talk_with_Right_Hand_Open", 0.4)
	_virar_maycow_para(drizzi.global_position)
	var meio := drizzi.global_position.lerp(_pes(), 0.5)
	# ele fala: por cima do ombro dela, o rosto dele
	plantar(drizzi.global_position - _rumo * 2.1 + _lado * 0.75 + Vector3.UP * 2.05, _pes() + Vector3.UP * 1.35)
	legenda("CAP3_MAYCOW_1", 2.8)
	await esperar(3.0)
	if not vale():
		return
	corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.5)
	# ela fala: do alto, os dois inteiros e pequenos (o rosto dela não ocupa a tela)
	var alto := meio + _lado * 3.5 + Vector3.UP * 6.5
	legenda("CAP3_DRIZZI_6", 3.2)
	await plano(alto, meio, alto - _rumo * 0.8 + Vector3.UP * 0.4, meio, 3.3)
	if not vale():
		return
	legenda("CAP3_DRIZZI_7", 3.4)
	await esperar(3.5)
	if not vale():
		return
	# abaixa e pega um punhado de terra: três-quartos pelas costas dela
	var cab: Vector3 = drizzi.call("cabeca")
	var tres := drizzi.global_position - _rumo * 2.6 - _lado * 1.6 + Vector3.UP * 1.9
	drizzi.call("tocar", &"pegar_areia", 0.3)
	await plano(tres, cab, tres - _lado * 0.3, cab - Vector3.UP * 0.6, 2.2)
	if not vale():
		return
	Poeira.nuvem(cena, drizzi.global_position + _rumo * 0.5, 0.8, 0.5, 12).call("assentar", 2.0)
	drizzi.call("tocar", &"comer", 0.25)
	_som(SOM_MORDIDAS.pick_random(), 0.8, -2.0)
	legenda("CAP3_MAYCOW_2", 2.6)
	await plano(tres - _lado * 0.3, cab - Vector3.UP * 0.4, tres - _lado * 0.5 + _rumo * 0.3, cab, 2.4)


## 5. De joelhos, comendo terra sem parar e gritando; a poeira sobe e toma
## conta. Ele recua.
func _poeira() -> void:
	drizzi.call("tocar", &"ajoelhar", 0.25)
	await esperar(0.9)
	if not vale():
		return
	drizzi.call("tocar", &"comendo_terra", 0.3)
	var chao := Vector3(drizzi.global_position.x, _chao(drizzi.global_position), drizzi.global_position.z)
	var nuvens := [Poeira.nuvem(cena, chao, 2.2, 2.2, 70)]
	_vento = _som(SOM_VENTO, 0.85, -26.0, true)
	if _vento:
		create_tween().tween_property(_vento, "volume_db", -4.0, 6.0)
	corpo.tocar(&"normal/Walk_Backward_inplace", 0.4)
	var estado := {"mordida": 0.0, "grito": 1.2, "gritando": false, "troca": 2.2, "nuvem2": false}
	var dur := 9.0
	await fase(dur, func(k: float) -> void:
		var dt := get_process_delta_time()
		var t := k * dur
		if t < 4.5:
			_andar_maycow(_rumo * PASSO_DELE * 0.9 * dt)
			_virar_maycow_para(drizzi.global_position)
		elif t - dt < 4.5:
			corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.5)
		estado["mordida"] -= dt
		if estado["mordida"] <= 0.0:
			estado["mordida"] = randf_range(0.22, 0.4)
			_som(SOM_MORDIDAS.pick_random(), randf_range(0.7, 0.95), -4.0)
		estado["grito"] -= dt
		if estado["grito"] <= 0.0:
			estado["grito"] = randf_range(1.6, 2.6)
			_som(SOM_GRITO if randf() < 0.6 else SOM_GRITO_2, randf_range(1.15, 1.35), -1.0)
		estado["troca"] -= dt
		if estado["troca"] <= 0.0:
			estado["gritando"] = not estado["gritando"]
			estado["troca"] = 1.4 if estado["gritando"] else 2.4
			drizzi.call("tocar", &"gritando" if estado["gritando"] else &"comendo_terra", 0.25)
		if t > 2.5 and not estado["nuvem2"]:
			estado["nuvem2"] = true
			nuvens.append(Poeira.nuvem(cena, chao, 5.0, 3.5, 110))
			nuvens.append(Poeira.nuvem(cena, chao.lerp(_pes(), 0.5), 4.0, 2.8, 80))
		_poeira_tela.color.a = lerpf(0.0, 0.82, suave(clampf((t - 1.5) / 7.0, 0.0, 1.0)))
		GlobalUtils.shake_camera(0.05, 0.08 * k)
		# atrás dele, que recua pra câmera: ele na frente, ela e a poeira atrás
		plantar(_pes() + _rumo * (3.2 + k * 0.8) + _lado * 1.4 + Vector3.UP * (2.2 + k * 0.6),
			chao + Vector3.UP * 1.0))
	if not vale():
		return
	# ela já se enterrou: o corpo some atrás da poeira
	drizzi.visible = false
	for n in nuvens:
		if is_instance_valid(n):
			n.call("parar")
	_nuvens_no_ar = nuvens


## 6. O barulho para de uma vez. A poeira desce devagar; ela não está mais lá.
func _silencio() -> void:
	for s in _sons:
		if is_instance_valid(s):
			s.stop()
	if is_instance_valid(_vento):
		_vento.stop()
	var cab := _pes() + Vector3.UP * 1.55
	var frente := cab - _rumo * 2.2 + _lado * 0.9 - Vector3.UP * 0.1
	plantar(frente, cab)
	await esperar(1.2)
	if not vale():
		return
	for n in _nuvens_no_ar:
		if is_instance_valid(n):
			n.call("assentar", 5.5)
	var t := create_tween()
	t.tween_property(_poeira_tela, "color:a", 0.0, 5.5).set_trans(Tween.TRANS_SINE)
	await plano(frente, cab, frente - _rumo * 0.8 + Vector3.UP * 0.3, cab, 5.8)


## 7. Ele olha pra um lado e pro outro e dá uns passos pra onde ela estava.
func _olha_em_volta() -> void:
	corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.3)
	corpo.ap.seek(0.0, true)
	var cab := _pes() + Vector3.UP * 1.55
	var atras := cab + _rumo * 2.6 + _lado * 1.1 + Vector3.UP * 0.4
	legenda("CAP3_MAYCOW_3", 2.4)
	await plano(atras, cab - _rumo * 4.0, atras + _lado * 0.4, cab - _rumo * 4.0, 3.6)
	if not vale():
		return
	corpo.tocar(&"normal/Walking", 0.3)
	await fase(2.2, func(k: float) -> void:
		_andar_maycow(-_rumo * 1.05 * get_process_delta_time())
		var c := _pes() + Vector3.UP * 1.55
		plantar(c + _rumo * 2.6 + _lado * 1.1 + Vector3.UP * 0.4, c - _rumo * 4.0))
	corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.4)


## 8. O chão estoura na frente dele e ela sai cavando, monstro, no meio da
## poeira; fica olhando pra ele, e grita.
func _monstro_sai_do_chao() -> void:
	var pe := _pes()
	var onde := pe - _rumo * 5.2
	onde.y = _chao(onde)
	var giro := atan2(pe.x - onde.x, pe.z - onde.z)
	_monstro = AtorDrizzi.criar(cena, Transform3D(Basis(Vector3.UP, giro), onde - Vector3.UP * 3.2), true)
	_monstro.call("tocar", &"surgir", 0.0)
	_som(SOM_QUEDA, 0.55, 2.0)
	_som(SOM_OSSOS, 0.7, -2.0)
	GlobalUtils.shake_camera(1.0, 0.45)
	GlobalUtils.vibrate_controller(null, 0.8, 0.8, 0.6)
	Poeira.estouro(cena, onde, 1.8)
	var sobe_poeira := Poeira.nuvem(cena, onde, 3.2, 3.0, 70)
	# baixo, de lado: os dois no quadro
	var baixo := pe.lerp(onde, 0.5) + _lado * 4.8 + Vector3.UP * 0.7
	plantar(baixo, onde + Vector3.UP * 1.6)
	await esperar(0.35)
	_som(SOM_RUGIDO, 0.85, 0.0)
	corpo.tocar(&"normal/Walk_Backward_inplace", 0.2)
	var alto := onde + Vector3.UP * 0.55
	await fase(2.4, func(k: float) -> void:
		_monstro.global_position = (onde - Vector3.UP * 3.2).lerp(alto, ease(k, 0.4))
		if k < 0.45:
			_andar_maycow(_rumo * 0.9 * get_process_delta_time())
		plantar(baixo, onde + Vector3.UP * lerpf(0.6, 1.9, k)))
	if not vale():
		return
	corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.4)
	_monstro.call("tocar", &"flutuar", 0.4)
	sobe_poeira.call("assentar", 4.0)
	# ela olha pra ele um instante: por cima do ombro dele
	var c := _pes() + Vector3.UP * 1.5
	var ombro := c + _rumo * 1.9 + _lado * 0.7 + Vector3.UP * 0.35
	await fase(2.6, func(k: float) -> void:
		_monstro.global_position = alto + Vector3.UP * sin(k * TAU * 0.5) * 0.1
		plantar(ombro.lerp(ombro - _rumo * 0.5, k), onde + Vector3.UP * 1.7))
	if not vale():
		return
	_monstro.call("tocar", &"gritar", 0.15)
	_som(SOM_GRITO, 0.8, 2.0)
	GlobalUtils.shake_camera(1.2, 0.35)
	await esperar(1.6)


# ============================================================ peças
## A câmera nunca fica atrás de túmulo, anjo ou parede: se algo fica entre ela e
## o que ela olha, ela chega pra frente disso.
func plantar(pos: Vector3, alvo: Vector3, rolagem: float = 0.0) -> void:
	super.plantar(_sem_obstaculo(alvo, pos), alvo, rolagem)


func _sem_obstaculo(alvo: Vector3, pos: Vector3) -> Vector3:
	if not is_instance_valid(cena) or not cena.is_inside_tree():
		return pos
	var q := PhysicsRayQueryParameters3D.create(alvo, pos, 2)
	if is_instance_valid(player):
		q.exclude = [player.get_rid()]
	var r := cena.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return pos
	return (r["position"] as Vector3) + (alvo - pos).normalized() * 0.35



func _pes() -> Vector3:
	var modelo = player.get("modelo_visual")
	if is_instance_valid(modelo):
		return (modelo as Node3D).global_position
	return player.global_position - Vector3.UP * 0.9


func _andar_maycow(passo: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position += Vector3(passo.x, 0.0, passo.z)


func _andar_drizzi(passo: Vector3) -> void:
	var p: Vector3 = drizzi.global_position + Vector3(passo.x, 0.0, passo.z)
	p.y = _chao(p)
	drizzi.global_position = p


func _virar_maycow_para(alvo: Vector3) -> void:
	var d := alvo - player.global_position
	if Vector2(d.x, d.z).length() > 0.05:
		player.global_rotation.y = atan2(-d.x, -d.z)


func _chao(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 20.0, 2)
	q.exclude = [player.get_rid()]
	var r := cena.get_world_3d().direct_space_state.intersect_ray(q)
	return float(r["position"].y) if r else p.y


func _montar_poeira_tela() -> void:
	_poeira_tela = ColorRect.new()
	_poeira_tela.color = Color(COR_POEIRA_TELA, 0.0)
	_poeira_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poeira_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(_poeira_tela)
	_camada.move_child(_poeira_tela, 0)


func _fundo() -> void:
	var s := _som(SOM_FUNDO, 0.8, -30.0, true)
	if s:
		create_tween().tween_property(s, "volume_db", -12.0, 3.0)


func _som(caminho: String, tom: float, volume: float, laco: bool = false) -> AudioStreamPlayer:
	if not ResourceLoader.exists(caminho):
		return null
	var s := AudioStreamPlayer.new()
	var stream = load(caminho)
	if laco and stream is AudioStreamOggVorbis:
		stream = (stream as AudioStreamOggVorbis).duplicate()
		stream.loop = true
	s.stream = stream
	s.pitch_scale = tom
	s.volume_db = volume
	add_child(s)
	s.play()
	if not laco:
		s.finished.connect(s.queue_free)
	_sons.append(s)
	return s


func _limpar() -> void:
	if corpo:
		corpo.call("soltar")
		corpo = null
	if is_instance_valid(drizzi):
		drizzi.queue_free()
	for s in _sons:
		if is_instance_valid(s):
			s.queue_free()
	_sons.clear()


func _exit_tree() -> void:
	super._exit_tree()
	if corpo:
		corpo.call("soltar")
		corpo = null
