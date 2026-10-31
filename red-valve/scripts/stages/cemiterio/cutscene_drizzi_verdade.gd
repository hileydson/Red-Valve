extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A VERDADE (Capítulo 3, o fim da luta do cemitério).
##
## A Drizzi monstro caiu com 15% do sangue. O corpo do parasita queima e some,
## e no lugar dele fica ela, gente de novo, caída de costas. O Maycow se
## ajoelha e a segura no chão; conta que quem fez tudo foi a Dona Nice — a
## seita, o ritual. Ainda nos braços dele ela pede perdão e diz onde o Jimmy
## está (no mundo paralelo): ele tem de voltar ao portal da escola, onde há um
## artefato sagrado por aquele caminho, e depois à oficina, pela red valve de
## lá. Ela sente que ele está pronto pra atravessar, diz que vai deixar uma
## ajuda — e se desfaz no ar. Tela preta.
##
## Se ela caiu na ARENA (o amuleto a levou), a cena começa no preto, no
## cemitério, com ela já humana na frente dele (`monstro` = null).
## A câmera nunca fica no rosto dela enquanto ela fala: a boca não mexe.

const CorpoDoMaycow := preload("res://scripts/cutscenes/corpo_do_maycow.gd")
const AtorDrizzi := preload("res://scripts/npcs/drizzi/ator_drizzi.gd")
const DissolverCorpo := preload("res://scripts/effects/dissolver_corpo.gd")
const Teleporte := preload("res://scripts/effects/teleporte_dona_nice.gd")

const SOM_FUNDO := "res://assets/sounds/escola/atmosfera_fantasma.ogg"
const SOM_GRITO := "res://assets/sounds/igreja/grito_transformacao.ogg"
const SOM_OSSOS := "res://assets/sounds/igreja/transformacao_ossos.ogg"
const SOM_SOME := "res://assets/sounds/igreja/teleporte_some.ogg"
const SOM_ESPACO := "res://assets/sounds/player/espaco_travel.mp3"

## O instante do `pegar_jonny` (clipe da igreja) em que ele está ajoelhado,
## as mãos embaixo do corpo, perto do chão.
const AJOELHADO := 1.95
## Quanto as mãos dele ficam à frente do corpo nesse instante (medido no
## clipe: 0,62 m).
const ALCANCE := 0.62
## A conversa precisa de chão livre (ajoelhado entre lápides ele entra nelas):
## caída fora da praça, depois do corte ela fica na beira da praça, deste lado.
const RAIO_DA_PRACA := 18.0
const BEIRA_DA_PRACA := 12.0

## [quem fala ("m" Maycow / "d" Drizzi), chave, segundos]
const FALAS := [
	["m", "CAP3_FIM_MAYCOW_1", 3.0],
	["m", "CAP3_FIM_MAYCOW_2", 3.6],
	["m", "CAP3_FIM_MAYCOW_3", 5.2],
	["m", "CAP3_FIM_MAYCOW_4", 3.0],
	["d", "CAP3_FIM_DRIZZI_1", 3.2],
	["d", "CAP3_FIM_DRIZZI_2", 3.0],
	["d", "CAP3_FIM_DRIZZI_3", 4.2],
	["d", "CAP3_FIM_DRIZZI_4", 4.6],
	["d", "CAP3_FIM_DRIZZI_5", 4.4],
	["d", "CAP3_FIM_DRIZZI_6", 4.4],
	["d", "CAP3_FIM_DRIZZI_7", 3.8],
	["d", "CAP3_FIM_DRIZZI_8", 3.2],
]

## `corpo_do_maycow.gd` (sem tipo: os métodos são do script).
var corpo
var drizzi: Node3D
var _centro := Vector3.ZERO
## Da Drizzi pro Maycow, no chão; e o eixo do corpo dela (os pés pro +).
var _pro_maycow := Vector3.BACK
var _eixo := Vector3.RIGHT
var _sons: Array[AudioStreamPlayer] = []


func rodar(dono: Node3D, jogador: CharacterBody3D, monstro: Node3D, onde: Transform3D) -> void:
	travar(dono, jogador, 46.0)
	corpo = CorpoDoMaycow.assumir(player)
	corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.3)
	_som(SOM_FUNDO, 0.75, -14.0)
	var veio_da_arena := not is_instance_valid(monstro)
	if veio_da_arena:
		_tela.modulate.a = 1.0
	_centro = onde.origin
	var d := _pes() - _centro
	d.y = 0.0
	if veio_da_arena or d.length() < 0.5:
		# na frente dele
		var frente := -player.global_basis.z
		frente.y = 0.0
		frente = frente.normalized()
		_centro = _pes() + frente * 2.2
		d = -frente
	_centro.y = _chao(_centro)
	_pro_maycow = d.normalized()
	_eixo = _pro_maycow.cross(Vector3.UP).normalized()
	# ela deitada atravessada na frente dele: os pés pro +eixo, a cabeça pro -
	drizzi = AtorDrizzi.criar(cena, Transform3D(Basis(Vector3.UP, atan2(_eixo.x, _eixo.z)), _centro))
	drizzi.call("tocar", &"caida", 0.0)

	if not veio_da_arena:
		await _transformacao(monstro)
		if not vale():
			_limpar()
			return
		await escurecer(1.0, 0.6)
	_lugar_livre()
	await esperar(0.2)
	_ajoelhar()
	_plano_alto(0.0)
	await escurecer(0.0, 1.6 if veio_da_arena else 0.8)
	if not vale():
		_limpar()
		return
	await _conversa()
	if not vale():
		_limpar()
		return
	await _desfaz()
	if not vale():
		_limpar()
		return
	await escurecer(1.0, 1.5)
	_limpar()
	_levantar()
	Eventos.concluir(Eventos.CAP3_DRIZZI_DERROTADA)
	await esperar(0.8)
	encerrar(1.6)


# ============================================================ os planos

## O parasita queima e some; ela, gente, aparece no mesmo lugar.
func _transformacao(monstro: Node3D) -> void:
	drizzi.visible = false
	var lado := _centro + _eixo * 6.5 + _pro_maycow * 2.5 + Vector3.UP * 2.3
	plantar(lado, _centro + Vector3.UP * 0.8)
	await esperar(1.6)
	if not vale():
		return
	_som(SOM_OSSOS, 0.85, -2.0)
	_som(SOM_GRITO, 1.3, -3.0)
	GlobalUtils.shake_camera(0.6, 0.2)
	var visual := monstro.get_node_or_null("visual") as Node3D
	var queima = DissolverCorpo.vestir(visual if visual else monstro)
	queima.parametro("cor_borda", Color(0.75, 0.55, 1.0))
	Teleporte.criar(cena, _centro, 1.6, false)
	drizzi.call("surgir", 2.4)
	await fase(2.4, func(k: float) -> void:
		queima.parametro("dissolver", k)
		plantar(lado - _eixo * k * 0.8, _centro + Vector3.UP * lerpf(0.8, 0.4, k)))
	if is_instance_valid(monstro):
		monstro.visible = false
	await esperar(0.8)


## No preto: se ela caiu fora da praça (entre túmulos), a conversa vai pra
## beira da praça, do lado de onde ela estava, com ele do lado do centro.
func _lugar_livre() -> void:
	var plano := Vector2(_centro.x, _centro.z)
	if plano.length() <= RAIO_DA_PRACA:
		return
	var p := plano.normalized() * BEIRA_DA_PRACA
	_centro = Vector3(p.x, 0.0, p.y)
	_centro.y = _chao(_centro)
	_pro_maycow = -Vector3(p.x, 0.0, p.y).normalized()
	_eixo = _pro_maycow.cross(Vector3.UP).normalized()
	drizzi.global_transform = Transform3D(Basis(Vector3.UP, atan2(_eixo.x, _eixo.z)), _centro)


## Ele ajoelhado do lado dela, as mãos embaixo das costas.
func _ajoelhar() -> void:
	var peito: Vector3 = _centro - _eixo * 0.45
	var alvo := peito + _pro_maycow * ALCANCE
	player.velocity = Vector3.ZERO
	player.global_rotation.y = atan2(_pro_maycow.x, _pro_maycow.z)
	var desvio := _pes() - player.global_position
	player.global_position = Vector3(alvo.x - desvio.x, player.global_position.y, alvo.z - desvio.z)
	corpo.congelar(&"pegar_jonny", AJOELHADO, 0.0)


## Alto e de lado: os dois inteiros no chão.
func _plano_alto(k: float) -> void:
	var c := _centro + _pro_maycow * 0.4
	plantar(c + _eixo * 4.6 + _pro_maycow * 1.2 + Vector3.UP * (3.4 + k * 0.4), c + Vector3.UP * 0.3)


## De frente pra ele, um pouco de lado e por cima dela: o rosto dele; o dela
## fica embaixo, fora do quadro.
func _plano_dele(k: float) -> void:
	var dele := _cabeca_dele()
	# na altura dele, olhando um pouco pra cima: ela, deitada entre a câmera e
	# ele, fica abaixo do quadro
	plantar(dele - _pro_maycow * 1.0 + _eixo * (0.8 + k * 0.1) - Vector3.UP * 0.05,
		dele + Vector3.UP * 0.18)


## Baixo, dos pés dela: o corpo inteiro escorçado, o rosto longe.
func _plano_dos_pes(k: float) -> void:
	var c := _centro + _pro_maycow * 0.3
	plantar(c + _eixo * (4.8 - k * 0.4) - _pro_maycow * 1.4 + Vector3.UP * 1.0, c + Vector3.UP * 0.35)


func _conversa() -> void:
	var plano_d := 0
	for fala in FALAS:
		var quem: String = fala[0]
		var dur: float = fala[2]
		legenda(String(fala[1]), dur - 0.1)
		var qual := plano_d
		if quem == "d":
			plano_d += 1
		await fase(dur, func(k: float) -> void:
			if quem == "m":
				_plano_dele(k)
			elif qual % 2 == 0:
				_plano_alto(k)
			else:
				_plano_dos_pes(k))
		if not vale():
			return


## Ela se desfaz no ar; ele fica ajoelhado.
func _desfaz() -> void:
	_som(SOM_SOME, 0.8, -2.0)
	_som(SOM_ESPACO, 0.6, -10.0)
	drizzi.call("desfazer", 2.8, false)
	await fase(3.6, func(k: float) -> void: _plano_alto(1.0 - k * 0.5))
	if not vale():
		return
	var cab := _cabeca_dele()
	await plano(cab - _pro_maycow * 1.6 + _eixo * 1.1 + Vector3.UP * 0.3, cab,
		cab - _pro_maycow * 2.4 + _eixo * 1.5 + Vector3.UP * 0.7, cab, 2.6)


func _levantar() -> void:
	if corpo:
		corpo.call("soltar")
		corpo = null


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



## A cabeça dele, ajoelhado (pelo osso: o clipe dobra o corpo todo).
func _cabeca_dele() -> Vector3:
	var sk := player.get_node_or_null("maycow_lopes_normal/Armature/Skeleton3D") as Skeleton3D
	var malha = player.get("modelo_visual")
	if sk and is_instance_valid(malha):
		var i := sk.find_bone("Head")
		if i >= 0:
			# a pose do osso vale no espaço da malha `char1` (girada e descida
			# em relação ao esqueleto), não no do Skeleton3D
			return (malha as Node3D).global_transform * sk.get_bone_global_pose(i).origin
	return _pes() + Vector3.UP * 1.05


func _pes() -> Vector3:
	var modelo = player.get("modelo_visual")
	if is_instance_valid(modelo):
		return (modelo as Node3D).global_position
	return player.global_position - Vector3.UP * 0.9


func _chao(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 20.0, 2)
	q.exclude = [player.get_rid()]
	var r := cena.get_world_3d().direct_space_state.intersect_ray(q)
	return float(r["position"].y) if r else p.y


func _som(caminho: String, tom: float, volume: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.pitch_scale = tom
	s.volume_db = volume
	add_child(s)
	s.play()
	_sons.append(s)


func _limpar() -> void:
	if is_instance_valid(drizzi):
		drizzi.queue_free()
	for s in _sons:
		if is_instance_valid(s):
			s.queue_free()
	_sons.clear()
	_levantar()


func _exit_tree() -> void:
	super._exit_tree()
	_levantar()
