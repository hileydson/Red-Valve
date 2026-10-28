extends SkeletonModifier3D

## A LANTERNA NA CINTURA DO MAYCOW NORMAL.
##
## Ate' aqui a lanterna era so' o `SpotLight3D` da Camera3D: em terceira pessoa
## a luz nascia no ar, na frente do peito, e nao havia objeto nenhum na tela
## explicando de onde ela saia. Agora o modelo (`lanterna.glb`) fica preso no
## quadril DIREITO — o lugar em que um sujeito pendura uma lanterna quando
## precisa das maos — e e' da LENTE dele que o facho passa a sair.
##
## ==========================================================================
## POR QUE UM SkeletonModifier3D, E NAO UM BoneAttachment3D
##
## Mesmo motivo do `player_gun_hold.gd`: no `player.tscn` a malha `char1` leva
## transformacao propria (girada 180 graus e descida ~1 m, em CENTIMETROS). Um
## BoneAttachment3D se posiciona pela global do ESQUELETO e cairia um metro fora
## e virado ao contrario. Entao a lanterna nasce filha da MALHA, e o transform
## LOCAL dela e' a pose do osso lida crua — que e' o espaco em que a pele e'
## desenhada. Tudo aqui dentro esta' em CENTIMETROS.
##
## ==========================================================================
## A LENTE E' O -X DO MODELO
##
## O `lanterna.glb` e' um cilindro deitado no X, com a lente (o disco) na ponta
## -X e a alca na ponta +X. E' `LENTE_NO_MODELO` que vai apontar pra CIMA: ela
## fica EM PE' no cinto, lente pro alto, como uma lanterna enfiada no coldre.

const ITEM_LANTERNA := "lanterna"
const MODELO_LANTERNA := "res://assets/3d_model/player/lanterna/lanterna.glb"
const OSSO_QUADRIL := "Hips"

## Escala do modelo DENTRO do esqueleto (que esta' em centimetros): 12 aqui sao
## os ~23 cm de lanterna que o mundo ve' — o cilindro do .glb tem 1,9 unidade de
## comprimento. Com 16 ela vinha do tamanho de um porrete no cinto.
const ESCALA := 12.0

## Ponta da lente, no modelo cru (antes da escala). O cilindro vai de -1 a +1.
const LENTE_NO_MODELO := -1.0

## Onde ela pendura, medido a partir do osso do quadril, em CENTIMETROS.
## Lado ESQUERDO (negativo), um palmo a' frente e um pouco abaixo da linha do
## Hips. A mao direita e' a da arma; a lanterna fica do outro lado.
const CINTO_LADO := -15.0
const CINTO_FRENTE := 11.0
const CINTO_ALTURA := -3.0

## Ela fica EM PE'. Estes dois sao so' o desaprumo: quanto a lente cai pra
## FRENTE e quanto ela cai pra FORA do corpo, em graus a partir da vertical.
## Zero nos dois deixa a lanterna perfeitamente a prumo, e a prumo parece peca
## de cenario — enfiada no cinto ela sempre pende um pouco.
const INCLINACAO := 10.0
const ABERTURA := 7.0

## De quanto a FONTE da luz sai a' FRENTE do corpo, em METROS. Sem isto o facho
## nasce colado no quadril e a sombra do proprio corpo come metade dele — foi o
## mesmo problema que tirou a luz de dentro do peito no `player.gd`. E' pra
## frente do CORPO, e nao pro eixo da lente: a lente aponta pra cima.
const SAIDA_DA_LUZ := 0.22

var _i_quadril := -1
var _malha: MeshInstance3D = null
## O corpo do jogador. E' DELE que saem os eixos "frente/direita/cima" — o
## Skeleton3D olha pro +Z e este no' e' filho dele, entao usar a global deste no'
## poria a lanterna pendurada de costas.
var _corpo: Node3D = null
var _lanterna: Node3D = null
## Pose da lanterna no ultimo quadro, no espaco da MALHA (centimetros). O
## `player.gd` pergunta por ela pra saber de onde o facho sai.
var _pose := Transform3D.IDENTITY
var _montada := false


# ==============================================================================
# O QUE O PLAYER CHAMA
# ==============================================================================
## A lanterna esta' na cintura e visivel?
func tem_lanterna_na_cintura() -> bool:
	return _montada


## Ponto do MUNDO de onde o facho deve sair: a lente, empurrada um palmo pra
## frente pra escapar do corpo.
func saida_da_luz() -> Vector3:
	if not _montada or not is_instance_valid(_malha):
		return Vector3.ZERO
	var lente: Vector3 = _malha.global_transform \
		* (_pose * Vector3(LENTE_NO_MODELO * ESCALA, 0.0, 0.0))
	var frente := -_corpo.global_transform.basis.z.normalized()
	return lente + frente * SAIDA_DA_LUZ


## Pra onde a lente olha, em coordenadas de MUNDO (vetor unitario).
func direcao_da_lente() -> Vector3:
	if not is_instance_valid(_malha):
		return Vector3.FORWARD
	var eixo := _malha.global_transform.basis * (_pose.basis * Vector3.LEFT)
	return eixo.normalized()


# ==============================================================================
# O QUADRO
# ==============================================================================
## Roda dentro da fase de modificacao do esqueleto — o unico momento em que a
## pose lida e' a pose que vai pra tela. Fora dela o Skeleton3D RESTAURA as poses
## da animacao, e a lanterna andaria um quadro atrasada do proprio quadril.
func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	# -2 e' "ja' procurei e este rig nao tem o osso": nao adianta procurar de
	# novo todo quadro.
	if _i_quadril == -2:
		return
	if _i_quadril < 0 and not _procurar_osso(sk):
		return

	var tem: bool = SaveManager.tem_item(ITEM_LANTERNA)
	_garantir_modelo(tem)
	_montada = tem and is_instance_valid(_lanterna)
	if not _montada:
		return

	# `_pose` fica SEM escala (como a pose da arma no `player_gun_hold`): e' ela
	# que mede a ponta da lente em centimetros, e uma base ja' escalada mediria
	# a distancia duas vezes.
	_pose = _pose_no_cinto(sk)
	_lanterna.transform = Transform3D(
		_pose.basis.scaled(Vector3.ONE * ESCALA), _pose.origin)


## Monta a pose da lanterna no espaco dos ossos.
##
## Os eixos do CORPO sao lidos do mundo e trazidos pra ca' (em vez de chutar
## quais eixos do osso sao "frente" e "direita"): o esqueleto olha pro +Z e o
## corpo que aparece na tela olha pro -Z, e depender disso de cabeca e' o tipo de
## coisa que sai invertida sem avisar.
func _pose_no_cinto(sk: Skeleton3D) -> Transform3D:
	var g_quadril := sk.get_bone_global_pose(_i_quadril)
	var para_ossos := _malha.global_transform.basis.inverse()
	var base := _corpo.global_transform.basis
	var frente: Vector3 = (para_ossos * -base.z).normalized()
	var direita: Vector3 = (para_ossos * base.x).normalized()
	var cima: Vector3 = (para_ossos * base.y).normalized()

	var origem: Vector3 = g_quadril.origin \
		+ direita * CINTO_LADO + frente * CINTO_FRENTE + cima * CINTO_ALTURA

	# EM PE', LENTE PRA CIMA: a lente (-X do modelo) aponta pro alto, com um
	# desaprumo pra frente e pra fora do corpo.
	#
	# O eixo de referencia da base e' a FRENTE do corpo, e nao mais o "cima" —
	# com a lanterna em pe' o eixo dela E' o cima, e um produto vetorial de dois
	# vetores paralelos zera a base inteira.
	# Sinais: girar o "cima" em torno da DIREITA com angulo positivo joga a lente
	# pra TRAS, e em torno da FRENTE joga pra DIREITA — e ela esta' na esquerda.
	# Por isso os dois entram negativos.
	var mira := cima.rotated(direita, -deg_to_rad(INCLINACAO)) \
		.rotated(frente, -deg_to_rad(ABERTURA)).normalized()
	var eixo_x := -mira
	var eixo_z := eixo_x.cross(frente).normalized()
	var eixo_y := eixo_z.cross(eixo_x).normalized()
	return Transform3D(Basis(eixo_x, eixo_y, eixo_z), origem)


## Monta (uma vez) ou esconde o modelo.
##
## Ele e' filho da MALHA e nao deste no': este no' e' filho do Skeleton3D, e o
## espaco do esqueleto esta' 180 graus virado do corpo que se ve' (cabecalho).
func _garantir_modelo(tem: bool) -> void:
	if not is_instance_valid(_lanterna):
		if not tem or not is_instance_valid(_malha):
			return
		var pacote: PackedScene = load(MODELO_LANTERNA)
		if pacote == null:
			push_warning("player_flashlight_hold: nao achei %s" % MODELO_LANTERNA)
			_i_quadril = -2
			return
		_lanterna = pacote.instantiate()
		_lanterna.name = "LanternaNoCinto"
		# Nada de colisao vinda do .glb: ela anda colada no corpo e um corpo
		# fisico ali dentro brigaria com a capsula do jogador.
		for col in _lanterna.find_children("*", "CollisionObject3D", true, false):
			col.collision_layer = 0
			col.collision_mask = 0
		_malha.add_child(_lanterna)
	_lanterna.visible = tem


func _procurar_osso(sk: Skeleton3D) -> bool:
	for filho in sk.get_children():
		if filho is MeshInstance3D:
			_malha = filho
			break
	_corpo = sk
	while is_instance_valid(_corpo) and not (_corpo is CharacterBody3D):
		_corpo = _corpo.get_parent() as Node3D
	_i_quadril = sk.find_bone(OSSO_QUADRIL)
	if _i_quadril < 0 or not is_instance_valid(_malha) or not is_instance_valid(_corpo):
		push_warning("player_flashlight_hold: rig sem o osso %s (ou sem malha/corpo) "
			% OSSO_QUADRIL + "— a lanterna nao vai pra cintura")
		_i_quadril = -2
		return false
	return true
