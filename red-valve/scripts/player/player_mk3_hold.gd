extends "res://scripts/player/player_gun_hold.gd"

## A MK3 (the_negotiator_V2) NA MAO DIREITA DO MAYCOW NORMAL.
##
## E' o componente da pistola (`player_gun_hold.gd`) — mesma pose de mira,
## mesmo IK, mesma pegada e o MESMO gesto de recarga (a arma recolhe e rola, a
## mao esquerda desce ao cinto, volta e encaixa) — com outro modelo e o pente
## de verdade por cima do gesto:
##
##     0,08  o pente vazio sai do poco e e' arremessado pra esquerda: um corpo
##           fisico que cai e quica no chao;
##     0,36  a mao, no cinto, ja' esta' com o pente novo;
##     0,72  ela encaixa por baixo, e o pente volta a ser o da arma.
##
## Por que nao um caminho proprio da mao ate' o pente: a MK3 tem o pente na
## FRENTE do guarda-mato, e com a arma no lugar da pistola ele fica a ~63 cm
## do ombro esquerdo (o braco tem 49). Puxar a arma pro peito pra mao alcancar
## enfiava o antebraco direito no tronco. A primeira pessoa (clipe
## `mk3_recarga` da mao_armada) e' que mostra o gesto inteiro de pegar o pente,
## jogar fora e buscar outro.
##
## O modelo e' o `mk3_fp.tscn` (Corpo + Pente, cortados por
## `tools/maos_fp/preparar_armas_novas_fp.gd`): esconder o pente da arma e'
## esconder um no'. Os momentos M_* sao fracao da recarga, e o
## `player_combat.gd` toca os sons nos mesmos (MK3_MOMENTO_*).

const MODELO_MK3 := "res://assets/3d_model/player/the_negotiator_V2/mk3_fp.tscn"
const PENTE_MK3 := preload("res://assets/3d_model/player/the_negotiator_V2/pente_mk3.tscn")
const SOM_PENTE_CAI := "res://assets/sounds/player/guns/mk3/mk3_pente_cai.ogg"

## Arma de ~29 cm (o .glb tem 1,91 unidade de comprimento).
const ESCALA_MK3 := 15.0
## O ponto que vai no osso da mao. Nao e' o meio do cabo: e' o PULSO, que fica
## atras dele — o mesmo recuo, em centimetros, que a pistola tem entre o cabo
## dela e o `CABO_NO_MODELO + OFFSET_NA_MAO` afinado no F9. Cabo da MK3 medido
## no .glb em (0,63, -0,15).
const CABO_MK3 := Vector3(1.03, -0.02, 0.0)
## O furo: a boca e' o -X do modelo, na altura do cano.
const BOCA_MK3 := Vector3(-0.93, 0.47, 0.0)
## O topo do pente no .glb (a origem do `pente_mk3.tscn`) e o ponto, perto da
## base, em que a mao o segura.
const TOPO_DO_PENTE := Vector3(-0.358, 0.05, 0.0)
const PEGA_NO_PENTE := Vector3(-0.50, -0.50, 0.0)
## Da palma ao pulso, ao longo dos dedos (cm): onde o pente fica na mao.
const PALMA := 7.5

const M_SAI := 0.08
const M_NA_MAO := 0.36
const M_ENCAIXA := 0.72

var _pente_na_arma: Node3D = null
var _pente_na_mao: Node3D = null
var _jogou := false


func _init() -> void:
	item_id = "mk3"
	modelo = MODELO_MK3
	escala_arma = ESCALA_MK3
	nome_do_no = "Mk3NaMao"
	boca_no_modelo = BOCA_MK3
	abre_a_mao_guardada = false
	_cabo = CABO_MK3
	_offset = Vector3.ZERO


func recarregar(tempo: float) -> void:
	super.recarregar(tempo)
	_jogou = false


func _garantir_arma(equipada: bool) -> void:
	super._garantir_arma(equipada)
	if is_instance_valid(_arma) and _pente_na_arma == null:
		_pente_na_arma = _arma.get_node_or_null("Pente") as Node3D
	if not equipada:
		if is_instance_valid(_pente_na_mao):
			_pente_na_mao.visible = false
		if is_instance_valid(_pente_na_arma):
			_pente_na_arma.visible = true


## O pente: na arma, na mao ou voando. Roda depois da pose deste quadro.
func _depois_da_pose(sk: Skeleton3D, _ctx: Dictionary, _delta: float) -> void:
	if not is_instance_valid(_arma):
		return
	var r := _recarga if _recarregando else 1.0
	var na_mao := _recarregando and r >= M_NA_MAO and r < M_ENCAIXA
	if is_instance_valid(_pente_na_arma):
		_pente_na_arma.visible = not _recarregando or r < M_SAI or r >= M_ENCAIXA
	if na_mao and not is_instance_valid(_pente_na_mao):
		_pente_na_mao = PENTE_MK3.instantiate()
		_pente_na_mao.name = "PenteMk3NaMao"
		_malha.add_child(_pente_na_mao)
	if is_instance_valid(_pente_na_mao):
		_pente_na_mao.visible = na_mao
		if na_mao:
			_pente_na_mao.transform = _pose_do_pente_na_mao(sk)
	if _recarregando and r >= M_SAI and not _jogou:
		_jogou = true
		_jogar_pente()


## O pente segue a mao esquerda: a pegada dele fica na palma, e ele tem a
## orientacao da arma (e' o pente que vai entrar nela).
func _pose_do_pente_na_mao(sk: Skeleton3D) -> Transform3D:
	var g := sk.get_bone_global_pose(_i_mao_e)
	var palma := g.origin + g.basis.y.normalized() * PALMA
	var base := _pose_arma.basis
	var origem := palma - base * ((PEGA_NO_PENTE - TOPO_DO_PENTE) * escala_arma)
	return Transform3D(base.scaled(Vector3.ONE * escala_arma), origem)


## O pente vazio sai do poco e e' arremessado: um corpo fisico de verdade, que
## quica e some depois de um tempo (como as capsulas).
func _jogar_pente() -> void:
	var cena := get_tree().current_scene if is_inside_tree() else null
	if cena == null or not is_instance_valid(_malha) or not is_instance_valid(_pente_na_arma):
		return
	var mundo := _pente_na_arma.global_transform
	var escala_mundo := mundo.basis.get_scale().x
	var corpo := RigidBody3D.new()
	corpo.name = "PenteMk3Caido"
	corpo.collision_layer = 0
	corpo.collision_mask = 3
	corpo.mass = 0.25
	var malha := PENTE_MK3.instantiate() as Node3D
	malha.scale = Vector3.ONE * escala_mundo
	corpo.add_child(malha)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.41, 0.67, 0.14) * escala_mundo
	forma.shape = caixa
	forma.position = Vector3(-0.1, -0.33, 0.0) * escala_mundo
	corpo.add_child(forma)
	cena.add_child(corpo)
	corpo.global_transform = Transform3D(mundo.basis.orthonormalized(), mundo.origin)
	# pra ESQUERDA do Maycow (+X no espaco dos ossos), pra baixo e um pouco
	# pra frente: o tranco da mao que tira o pente
	var esquerda := (_malha.global_basis * Vector3(1, 0, 0)).normalized()
	var frente := (_malha.global_basis * Vector3(0, 0, 1)).normalized()
	corpo.linear_velocity = esquerda * randf_range(2.0, 2.6) + frente * 0.5 + Vector3.UP * 0.8
	corpo.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9))
	var som := AudioStreamPlayer3D.new()
	som.stream = load(SOM_PENTE_CAI)
	som.unit_size = 6.0
	corpo.add_child(som)
	_tocar_ao_cair(corpo, som)


static func _tocar_ao_cair(corpo: RigidBody3D, som: AudioStreamPlayer3D) -> void:
	await corpo.get_tree().create_timer(0.42).timeout
	if is_instance_valid(som):
		som.play()
	await corpo.get_tree().create_timer(18.0).timeout
	if is_instance_valid(corpo):
		corpo.queue_free()
