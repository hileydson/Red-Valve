extends "res://scripts/player/player_gun_hold.gd"

## A PISTOLA (the_negotiator_V1) NA MAO DIREITA DO MAYCOW NORMAL.
##
## A pose de mira, o IK e a pegada sao os do `player_gun_hold.gd`. O que e' so'
## dela, e que antes nao existia — a mao esquerda ia ao cinto e voltava VAZIA,
## o tiro nao mexia nada e a arma era uma peca so':
##
## O TIRO (`coice`): o cano sobe, a mao recua uns centimetros e o ferrolho corre
## pra tras e volta, tudo em ~0,3 s. A mao esquerda vai junto (ela esta' por
## baixo da direita), entao as duas recebem o tranco.
##
## A RECARGA, em fracao do tempo dela:
##
##     0,10  o pente vazio desce do cabo e CAI (corpo fisico, quica no chao)
##     0,10  a mao esquerda vai ao cinto...
##     0,36  ...e ja' volta com o pente novo na mao
##     0,50  o pente chega embaixo do cabo, alinhado com o poco
##     0,62  e sobe pra dentro: a palma empurra a base, e ele volta a ser o da arma
##     0,68  a mao passa por cima da arma e pega o ferrolho por tras...
##     0,78  ...puxa (o ferrolho corre com ela)...
##     0,80  ...e solta: ele bate pra frente. E' o som do ferrolho.
##     0,86  a mao volta pro apoio por baixo da direita
##
## As poses da mao esquerda NAO sao chutadas: saem da arma. O ponto em que ela
## empurra o pente e' a base do pente NA ARMA; o ponto em que ela pega o
## ferrolho e' o fundo dele. Assim, com a arma rolada e levantada como estiver,
## a mao cai no lugar certo. (A conta usa a pose da arma do quadro anterior —
## a mao direita, que a segura, ainda nao foi posta quando a esquerda e' medida.)
##
## O modelo e' o `pistola_fp.tscn`: o mesmo .glb cortado em Corpo e Ferrolho
## por `tools/maos_fp/preparar_pistola_fp.gd`, nas MESMAS unidades — o cabo e o
## ajuste do F9 continuam valendo. Os M_* sao copiados no `player_combat.gd`
## (PISTOLA_MOMENTO_*), que toca os sons nos mesmos quadros.

const MODELO_ARTICULADO := "res://assets/3d_model/player/the_negotiator_V1/pistola_fp.tscn"
const PENTE := preload("res://assets/3d_model/player/the_negotiator_V1/pente_pistola_fp.tscn")
const SOM_PENTE_CAI := "res://assets/sounds/player/guns/mk3/mk3_pente_cai.ogg"

## O pente dentro da arma, no espaco do MODELO. Tirado da primeira pessoa
## (`mao_armada.tscn`: Modelo⁻¹ × Carregador), onde ele ja' foi encaixado no
## olho. O pente e' em metros (origem na base, alimentacao pro +Y), dai' a
## escala de ~6,9 aqui dentro.
const PENTE_NO_MODELO := Transform3D(
	Basis(Vector3(0.0, 0.0, -6.896553), Vector3(-2.131152, 6.559011, 0.0),
		Vector3(6.559011, 2.131152, 0.0)),
	Vector3(0.696552, -0.673104, 0.0))
## Onde a palma segura o pente: perto da base (metros, no espaco do pente).
const PEGA_NO_PENTE := Vector3(0.0, 0.025, 0.0)
## Quanto abaixo do poco o pente para antes de subir pra dentro (cm).
const PENTE_ANTES_DO_POCO := 7.0

## O fundo do ferrolho, por cima: onde a mao esquerda o pega (unidades do
## modelo; o ferrolho vai de x -0,96 a 0,95 e o alto dele fica em y 0,66).
const FERROLHO_PEGA := Vector3(0.72, 0.70, 0.0)
## Quanto o ferrolho corre pra tras, em unidades do modelo (+X e' pra tras):
## 0,24 sao os 3,5 cm da primeira pessoa.
const FERROLHO_CURSO := 0.24

## O punho fechado da mao esquerda, no espaco do osso dela (cm): e' esse ponto
## que vai em cima do ferrolho ou embaixo do pente. O mesmo pivo do punho da
## base, do lado da palma da esquerda.
const PUNHO_E := Vector3(-PUNHO_PIVO_PALMA, PUNHO_PIVO_DEDOS, 0.0)

## Pra onde a arma vai pra ser recarregada (cm). NAO e' o peito, como na MK3:
## a camera fica atras do ombro direito, e tudo o que acontece na frente do
## peito o proprio corpo tapa. Um pouco pra direita, pra baixo e menos recolhida,
## o gesto acontece na beira do tronco, onde a camera ve'.
const RECARGA_RECUA := 9.0
const RECARGA_BAIXA := 9.0
const RECARGA_PRO_LADO := 5.0

## O coice, em centimetros e graus, e quanto tempo ele leva pra assentar.
const COICE_RECUO := 3.5
const COICE_SOBE := 1.5
const COICE_CANO := 9.0
const COICE_SUBIDA := 0.03
const COICE_VOLTA := 0.08

const M_SAI := 0.10
const M_NA_MAO := 0.36
const M_EMBAIXO := 0.50
const M_ENCAIXA := 0.62
const M_FERROLHO_PEGA := 0.70
const M_FERROLHO_PUXA := 0.78
const M_FERROLHO := 0.80
const M_VOLTA := 0.86

var _ferrolho: Node3D = null
var _ferrolho_x := 0.0
var _pente_na_arma: Node3D = null
var _pente_na_mao: Node3D = null
var _jogou := false
## Segundos desde o ultimo tiro (grande = sem coice).
var _desde_tiro := 10.0


func _init() -> void:
	modelo = MODELO_ARTICULADO


## O tiro: o `player_combat.gd` chama no mesmo quadro do estampido.
func coice() -> void:
	_desde_tiro = 0.0


func recarregar(tempo: float) -> void:
	super.recarregar(tempo)
	_jogou = false


func _garantir_arma(equipada: bool) -> void:
	super._garantir_arma(equipada)
	if not is_instance_valid(_arma):
		return
	if _ferrolho == null:
		_ferrolho = _arma.get_node_or_null("Ferrolho") as Node3D
		if _ferrolho:
			_ferrolho_x = _ferrolho.position.x
	if _pente_na_arma == null:
		_pente_na_arma = PENTE.instantiate()
		_pente_na_arma.name = "Pente"
		_arma.add_child(_pente_na_arma)
		_pente_na_arma.transform = PENTE_NO_MODELO
	if not equipada:
		_pente_na_arma.visible = true
		if is_instance_valid(_pente_na_mao):
			_pente_na_mao.visible = false


## Quanto do coice esta' valendo agora (0 a 1): sobe num estalo e volta macio.
func _coice_agora() -> float:
	if _desde_tiro < COICE_SUBIDA:
		return _desde_tiro / COICE_SUBIDA
	return exp(-(_desde_tiro - COICE_SUBIDA) / COICE_VOLTA)


func _montar_contexto(sk: Skeleton3D, alvo: Vector3, peso: float,
		delta: float) -> Dictionary:
	_desde_tiro += delta
	var ctx := super._montar_contexto(sk, alvo, peso, delta)
	var c := _coice_agora() if _desde_tiro < 0.6 else 0.0
	if c > 0.001:
		var tranco: Vector3 = (-(ctx["dir"] as Vector3) * COICE_RECUO
			+ (ctx["cima"] as Vector3) * COICE_SOBE) * c
		for chave in ["mao_d", "mao_e", "polo_d", "polo_e"]:
			ctx[chave] = (ctx[chave] as Vector3) + tranco
		ctx["levanta"] = float(ctx["levanta"]) + COICE_CANO * c
	return ctx


func _gesto_da_recarga(ctx: Dictionary, r: float) -> void:
	var dir: Vector3 = ctx["dir"]
	var direita: Vector3 = ctx["direita"]
	var cima: Vector3 = ctx["cima"]
	var recolhe := smoothstep(0.0, 0.12, r) - smoothstep(M_VOLTA, 1.0, r)
	var mao_d: Vector3 = ctx["mao_d"] + (-dir * RECARGA_RECUA - cima * RECARGA_BAIXA
		+ direita * RECARGA_PRO_LADO) * recolhe
	ctx["mao_d"] = mao_d
	ctx["rolagem"] = RECARGA_ROLAGEM * recolhe
	ctx["levanta"] = RECARGA_LEVANTA * recolhe
	# fora da arma so' no caminho do cinto; embaixo do cabo e no ferrolho quem
	# manda na mao e' `_virar_mao_esquerda`
	ctx["solta"] = smoothstep(0.04, 0.16, r) - smoothstep(M_NA_MAO, M_EMBAIXO, r)

	var apoio := mao_d - direita * APOIO_LADO + cima * APOIO_ALTURA
	var cinto := apoio - direita * CINTO_LADO - cima * CINTO_ALTURA - dir * CINTO_FRENTE
	var no_poco := _pulso_e(_base_no_poco(), _mao_no_pente())
	var embaixo := no_poco - _eixo_do_pente() * PENTE_ANTES_DO_POCO
	var no_ferrolho := _pulso_e(_pose_arma * (FERROLHO_PEGA * escala_arma), _mao_no_ferrolho())
	var puxado := no_ferrolho + _pose_arma.basis.x.normalized() * FERROLHO_CURSO * escala_arma
	var trechos := [
		[0.04, M_NA_MAO - 0.04, apoio, cinto],
		[M_NA_MAO, M_EMBAIXO, cinto, embaixo],
		[M_EMBAIXO + 0.03, M_ENCAIXA, embaixo, no_poco],
		[M_ENCAIXA + 0.02, M_FERROLHO_PEGA, no_poco, no_ferrolho],
		[M_FERROLHO_PEGA + 0.02, M_FERROLHO_PUXA, no_ferrolho, puxado],
		[M_FERROLHO, M_VOLTA + 0.08, puxado, apoio],
	]
	var destino := apoio
	for t in trechos:
		if r < float(t[0]):
			break
		destino = (t[2] as Vector3).lerp(t[3] as Vector3, smoothstep(float(t[0]), float(t[1]), r))
	ctx["mao_e"] = destino


# ---- a mao esquerda medida na arma -------------------------------------------
## A base do pente encaixado, no espaco dos ossos (cm).
func _base_no_poco() -> Vector3:
	return _pose_arma * (_pente_pose(PEGA_NO_PENTE))

func _pente_pose(ponto: Vector3) -> Vector3:
	return (PENTE_NO_MODELO * ponto) * escala_arma

## O eixo do pente (pra onde ele entra), no espaco dos ossos.
func _eixo_do_pente() -> Vector3:
	return (_pose_arma.basis * PENTE_NO_MODELO.basis.y).normalized()

## Embaixo do cabo: a palma pra cima, empurrando a base do pente, os dedos pra
## frente por baixo do guarda-mato. Lembrete do rig: +Y do osso sao os dedos e
## a palma da ESQUERDA olha pro -X dele.
func _mao_no_pente() -> Basis:
	var palma := _eixo_do_pente()
	var dedos := -_pose_arma.basis.x.normalized()
	dedos = (dedos - palma * dedos.dot(palma)).normalized()
	return _base_osso(-palma, dedos)

## Por cima do ferrolho: a palma pra baixo, os dedos atravessando ele da
## esquerda pra direita da arma.
func _mao_no_ferrolho() -> Basis:
	var cima := _pose_arma.basis.y.normalized()
	var dedos := -_pose_arma.basis.z.normalized()
	dedos = (dedos - cima * 0.35).normalized()
	return _base_osso(cima, dedos)

func _base_osso(x: Vector3, y: Vector3) -> Basis:
	var z := x.cross(y).normalized()
	return Basis(y.cross(z).normalized(), y, z)

## Onde o PULSO tem de estar pra o punho fechado cair em `ponto`.
func _pulso_e(ponto: Vector3, base: Basis) -> Vector3:
	return ponto - base * PUNHO_E


## Quanto a mao esquerda segue a pose de pente e a de ferrolho (0 a 1).
func _na_pose_de_pente(r: float) -> float:
	return smoothstep(M_NA_MAO - 0.06, M_EMBAIXO - 0.04, r) - smoothstep(M_ENCAIXA, M_FERROLHO_PEGA - 0.02, r)

func _na_pose_de_ferrolho(r: float) -> float:
	return smoothstep(M_ENCAIXA + 0.02, M_FERROLHO_PEGA, r) - smoothstep(M_FERROLHO, M_VOLTA + 0.04, r)


# ---- o quadro ------------------------------------------------------------------
func _depois_da_pose(sk: Skeleton3D, _ctx: Dictionary, _delta: float) -> void:
	if not is_instance_valid(_arma):
		return
	var r := _recarga if _recarregando else 1.0
	if _recarregando:
		_virar_mao_esquerda(sk, r)

	# o ferrolho: o tiro joga ele pra tras; na recarga a mao o puxa e solta
	var curso := 0.0
	if _desde_tiro < 0.3:
		curso = clampf(_desde_tiro / 0.02, 0.0, 1.0) * (1.0 - smoothstep(0.03, 0.09, _desde_tiro))
	if _recarregando:
		curso = maxf(curso, smoothstep(M_FERROLHO_PEGA + 0.02, M_FERROLHO_PUXA, r)
			* (1.0 - smoothstep(M_FERROLHO, M_FERROLHO + 0.015, r)))
	if is_instance_valid(_ferrolho):
		_ferrolho.position.x = _ferrolho_x + FERROLHO_CURSO * curso

	# o pente: na arma, caindo, na mao, entrando
	var na_mao := _recarregando and r >= M_NA_MAO and r < M_ENCAIXA
	if is_instance_valid(_pente_na_arma):
		_pente_na_arma.visible = not _recarregando or r < M_SAI or r >= M_ENCAIXA
	if na_mao and not is_instance_valid(_pente_na_mao):
		_pente_na_mao = PENTE.instantiate()
		_pente_na_mao.name = "PentePistolaNaMao"
		_malha.add_child(_pente_na_mao)
	if is_instance_valid(_pente_na_mao):
		_pente_na_mao.visible = na_mao
		if na_mao:
			_pente_na_mao.transform = _pose_do_pente_na_mao(sk, r)
	if _recarregando and r >= M_SAI and not _jogou:
		_jogou = true
		_largar_pente()


## A mao esquerda gira pra pose de pente (palma pra cima, embaixo do cabo) ou
## de ferrolho (palma pra baixo, por cima). O pulso fica onde o IK o pos — o
## destino dele ja' foi calculado com ESTA base (`_pulso_e`), entao o punho
## fechado cai no lugar.
func _virar_mao_esquerda(sk: Skeleton3D, r: float) -> void:
	var w_pente := _na_pose_de_pente(r)
	var w_ferrolho := _na_pose_de_ferrolho(r)
	if w_pente + w_ferrolho <= 0.001:
		return
	var g := sk.get_bone_global_pose(_i_mao_e)
	var alvo := _mao_no_pente() if w_pente >= w_ferrolho else _mao_no_ferrolho()
	var peso := maxf(w_pente, w_ferrolho)
	var base := g.basis.orthonormalized().slerp(alvo, peso)
	sk.set_bone_global_pose(_i_mao_e, Transform3D(base, g.origin))
	# a mao fecha no pente / no ferrolho (o `_fechar_maos` ja' rodou neste
	# quadro, entao o morph e' escrito direto)
	if _morfo_e >= 0 and is_instance_valid(_malha):
		_malha.set_blend_shape_value(_morfo_e, maxf(_fechada_e, 0.8 * peso))


## O pente segue a palma; nos ultimos quadros antes do encaixe ele e' puxado
## pra linha do poco e sobe por ela — o encaixe nao pula.
func _pose_do_pente_na_mao(sk: Skeleton3D, r: float) -> Transform3D:
	var na_arma := _pose_arma * Transform3D(PENTE_NO_MODELO.basis * escala_arma,
		PENTE_NO_MODELO.origin * escala_arma)
	var g := sk.get_bone_global_pose(_i_mao_e)
	var punho := g.origin + g.basis.orthonormalized() * PUNHO_E
	var da_mao := Transform3D(na_arma.basis, punho - na_arma.basis * PEGA_NO_PENTE)
	var sobe := smoothstep(M_EMBAIXO + 0.03, M_ENCAIXA, r)
	var no_poco := Transform3D(na_arma.basis,
		na_arma.origin - _eixo_do_pente() * PENTE_ANTES_DO_POCO * (1.0 - sobe))
	var cola := smoothstep(M_EMBAIXO - 0.06, M_EMBAIXO + 0.02, r)
	return Transform3D(na_arma.basis, da_mao.origin.lerp(no_poco.origin, cola))


## O pente vazio desce do cabo pelo proprio peso: um corpo fisico que quica e
## some depois de um tempo, como o da MK3 (que e' arremessado; este so' cai).
func _largar_pente() -> void:
	var cena := get_tree().current_scene if is_inside_tree() else null
	if cena == null or not is_instance_valid(_malha) or not is_instance_valid(_pente_na_arma):
		return
	var mundo := _pente_na_arma.global_transform
	var escala_mundo := mundo.basis.get_scale().x
	var corpo := RigidBody3D.new()
	corpo.name = "PentePistolaCaido"
	corpo.collision_layer = 0
	corpo.collision_mask = 3
	corpo.mass = 0.15
	var malha := PENTE.instantiate() as Node3D
	malha.scale = Vector3.ONE * escala_mundo
	corpo.add_child(malha)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.03, 0.127, 0.045) * escala_mundo
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.0635, 0.0) * escala_mundo
	corpo.add_child(forma)
	cena.add_child(corpo)
	corpo.global_transform = Transform3D(mundo.basis.orthonormalized(), mundo.origin)
	var desce := -(mundo.basis.y.normalized())
	var esquerda := (_malha.global_basis * Vector3(1, 0, 0)).normalized()
	corpo.linear_velocity = desce * 1.4 + esquerda * 0.3
	corpo.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4))
	var som := AudioStreamPlayer3D.new()
	som.stream = load(SOM_PENTE_CAI)
	som.pitch_scale = 1.25
	som.volume_db = -4.0
	som.unit_size = 6.0
	corpo.add_child(som)
	_tocar_ao_cair(corpo, som)


static func _tocar_ao_cair(corpo: RigidBody3D, som: AudioStreamPlayer3D) -> void:
	await corpo.get_tree().create_timer(0.38).timeout
	if is_instance_valid(som):
		som.play()
	await corpo.get_tree().create_timer(18.0).timeout
	if is_instance_valid(corpo):
		corpo.queue_free()
