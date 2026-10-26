extends "res://scripts/player/player_shotgun_hold.gd"

## A GRANOLA (the_negotiator_V4) NAS DUAS MAOS DO MAYCOW NORMAL.
##
## E' o componente da cacadeira (`player_shotgun_hold.gd`) — arma longa, as
## duas maos o tempo todo, mesmo porte e mesma mira — com outro modelo e outra
## recarga: a Granola nao dobra. Ela e' um lancador que carrega PELA BOCA, um
## mini-foguete por vez, com a cauda fina entrando primeiro e a ogiva ficando
## pra fora, encaixada (como um RPG). A mao esquerda
##
##     fore-end -> cinto (pega o foguete) -> frente da boca -> empurra pra
##              dentro -> corre de volta pelo cano -> fore-end
##
## O foguete carregado aparece na boca enquanto houver um no tubo
## (`carregada`, que o `player_combat.gd` liga e desliga), e o da mao so' existe
## durante o gesto.
##
## Os momentos M_GRANOLA_* sao fracao da recarga; o `player_combat.gd` toca os
## sons nos mesmos (GRANOLA_MOMENTO_*).

const MODELO_GRANOLA := "res://assets/3d_model/player/the_negotiator_V4/the_negotiator_V4.glb"
const FOGUETE := preload("res://assets/3d_model/player/the_negotiator_V4/cartridge/the_negotiator_V4_bullet.glb")

## Medidos nos vertices do .glb (cano no -X, alto no +Y): o tubo tem o centro
## em y 0,203 / z 0,025 de x -0,96 a -0,5; o punho da coronha em x 0,4-0,5; a
## mao da frente por baixo do tubo, em x -0,44 a 0.
const BOCA_GRANOLA := Vector3(-0.96, 0.203, 0.025)
const CULATRA_GRANOLA := Vector3(-0.50, 0.202, 0.025)
const CABO_GRANOLA := Vector3(0.47, -0.03, 0.026)
const APOIO_GRANOLA := Vector3(-0.25, 0.06, 0.025)
## O foguete no tubo, no espaco da ARMA: 0,64 da escala dela, a base da ogiva
## (x -0,45 no .glb do foguete) na boca do cano. Assim a cauda inteira fica
## dentro do tubo e a ogiva sai ~13 cm pra fora.
const FOGUETE_ESCALA := 0.64
const FOGUETE_NA_BOCA := Vector3(-0.672, 0.203, 0.026)
## Da palma ao pulso (cm): onde o foguete fica na mao. A mao segura a OGIVA.
const PALMA := 7.0
const OGIVA_NO_FOGUETE := Vector3(-0.55, 0.0, 0.0)

## Na recarga ela LEVANTA quase na vertical (a boca pra cima, na altura do
## peito) e vem pra perto do corpo: deitada no porte, a boca fica ~50 cm a
## frente do quadril, longe demais pro braco esquerdo (49 cm). E' o jeito de
## carregar um lancador pela boca. Graus a mais que o RECARGA_LEVANTA da
## cacadeira, e o quanto a mao direita recua e sobe (cm).
const EXTRA_LEVANTA := 58.0
const RECARGA_RECUA := 20.0
const RECARGA_SOBE_MAIS := 4.0

const M_GRANOLA_LARGA := 0.12
const M_GRANOLA_PEGA := 0.32
const M_GRANOLA_NA_BOCA := 0.52
const M_GRANOLA_ENTRA := 0.64
const M_GRANOLA_VOLTA := 0.86

## Tem foguete no tubo? Quem sabe e' o combate (o pente e' dele).
var carregada := true

var _foguete_na_boca: Node3D = null
var _foguete_na_mao: Node3D = null


func _init() -> void:
	item_id = "granola"
	modelo = MODELO_GRANOLA
	nome_do_no = "GranolaNaMao"
	boca_no_modelo = BOCA_GRANOLA
	culatra_no_modelo = CULATRA_GRANOLA
	abertura = 0.0
	_cabo = CABO_GRANOLA
	_apoio = APOIO_GRANOLA


## Sem cartucho pra cair: ela nao tem camara aberta.
func bocas_das_camaras() -> Array[Vector3]:
	return []


func _garantir_arma(equipada: bool) -> void:
	super._garantir_arma(equipada)
	if is_instance_valid(_arma) and _foguete_na_boca == null:
		_foguete_na_boca = FOGUETE.instantiate()
		_foguete_na_boca.name = "FogueteNaBoca"
		_arma.add_child(_foguete_na_boca)
		_foguete_na_boca.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * FOGUETE_ESCALA),
			FOGUETE_NA_BOCA)
	if not equipada and is_instance_valid(_foguete_na_mao):
		_foguete_na_mao.visible = false


## Nao dobra, nao vira: so' recolhe um pouco e a mao esquerda faz o caminho
## do foguete.
func _envelopes(r: float) -> Dictionary:
	return {
		"recolhe": smoothstep(0.0, 0.10, r) - smoothstep(0.90, 1.0, r),
		"dobra": 0.0,
		"vira": 0.0,
		"solta": smoothstep(0.02, M_GRANOLA_LARGA, r) - smoothstep(M_GRANOLA_ENTRA + 0.08, M_GRANOLA_VOLTA, r),
	}


func _montar_contexto(sk: Skeleton3D, alvo: Vector3, peso: float,
		apontando: float, delta: float) -> Dictionary:
	var ctx := super._montar_contexto(sk, alvo, peso, apontando, delta)
	var recolhe: float = ctx["recolhe"]
	if recolhe > 0.0:
		var dir: Vector3 = ctx["dir"]
		var cima: Vector3 = ctx["cima"]
		var direita: Vector3 = ctx["direita"]
		var mao_d: Vector3 = ctx["mao_d"] + (-dir * RECARGA_RECUA + cima * RECARGA_SOBE_MAIS) * recolhe
		ctx["mao_d"] = mao_d
		ctx["polo_d"] = mao_d - Vector3.UP * COTOVELO_BAIXO_D + direita * COTOVELO_FORA_D
	return ctx


func _base_da_arma(ctx: Dictionary) -> Basis:
	var base := super._base_da_arma(ctx)
	var recolhe: float = ctx["recolhe"]
	if recolhe > 0.0:
		var lado_da_arma := (base * Vector3(0.0, 0.0, 1.0)).normalized()
		# negativo: neste eixo, positivo abaixa a boca
		base = base.rotated(lado_da_arma, -deg_to_rad(EXTRA_LEVANTA * recolhe))
	return base


func _giro_do_punho(_r: float, solta: float) -> float:
	return RECARGA_GIRO_BASE * solta if _recarregando else 0.0


func _destino_da_esquerda(ctx: Dictionary) -> Vector3:
	var fore := _pose_arma * _ponto(_apoio, 0.0)
	if not _recarregando:
		return fore
	var r: float = ctx["r"]
	var dir: Vector3 = ctx["dir"]
	var direita: Vector3 = ctx["direita"]
	var cima: Vector3 = ctx["cima"]
	var cinto: Vector3 = (ctx["ancora"] as Vector3) - direita * CINTO_LADO \
		- cima * CINTO_ALTURA - dir * CINTO_FRENTE
	var cano := (_pose_arma.basis * (boca_no_modelo - culatra_no_modelo)).normalized()
	var boca := _pose_arma * _ponto(boca_no_modelo, 0.0)
	# o pulso fica um palmo abaixo e atras do ponto em que a mao segura a ogiva
	var pulso := -cima * 6.0 - cano * 5.0
	var na_frente := boca + cano * 22.0 + pulso
	var empurrado := boca + cano * 6.0 + pulso
	var trechos := [
		[M_GRANOLA_LARGA - 0.08, M_GRANOLA_LARGA + 0.08, fore, cinto],
		[M_GRANOLA_PEGA - 0.06, M_GRANOLA_NA_BOCA, cinto, na_frente],
		[M_GRANOLA_NA_BOCA, M_GRANOLA_ENTRA, na_frente, empurrado],
		[M_GRANOLA_ENTRA + 0.04, M_GRANOLA_VOLTA, empurrado, fore],
	]
	var destino := fore
	for t in trechos:
		if r < float(t[0]):
			break
		destino = (t[2] as Vector3).lerp(t[3] as Vector3, smoothstep(float(t[0]), float(t[1]), r))
	return destino


func _depois_da_pose(sk: Skeleton3D, _ctx: Dictionary, _delta: float) -> void:
	if not is_instance_valid(_arma):
		return
	var r := _recarga if _recarregando else 1.0
	var na_mao := _recarregando and r >= M_GRANOLA_PEGA and r < M_GRANOLA_ENTRA
	if is_instance_valid(_foguete_na_boca):
		_foguete_na_boca.visible = carregada and not (_recarregando and r < M_GRANOLA_ENTRA)
	if na_mao and not is_instance_valid(_foguete_na_mao):
		_foguete_na_mao = FOGUETE.instantiate()
		_foguete_na_mao.name = "FogueteNaMao"
		_malha.add_child(_foguete_na_mao)
	if is_instance_valid(_foguete_na_mao):
		_foguete_na_mao.visible = na_mao
		if na_mao:
			var g := sk.get_bone_global_pose(_i_mao_e)
			var palma := g.origin + g.basis.y.normalized() * PALMA
			var base := _pose_arma.basis.scaled(Vector3.ONE * _escala * FOGUETE_ESCALA)
			# a mao segura a ogiva; o foguete tem a orientacao do cano (a ponta
			# pra frente, a cauda pra dentro da boca)
			_foguete_na_mao.transform = Transform3D(base, palma - base * OGIVA_NO_FOGUETE)
