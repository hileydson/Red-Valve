extends SkeletonModifier3D

## A MAO QUE EMPURRA A PORTA.
##
## As portas do hospital e da escola nao tem mais prompt: o Maycow passa e
## EMPURRA. Este componente e' a metade visual disso — o braco esquerdo se
## estica na direcao da folha enquanto ela gira.
##
## ==========================================================================
## POR QUE UM SkeletonModifier3D, E NAO UMA ANIMACAO
##
## O rig do Maycow normal (maycow_normal_rigged.glb) tem 24 ossos e NENHUM
## dedo. As animacoes dele vem de dentro do proprio .glb — nao ha' clipe de
## "empurrar porta", e nao ha' .blend fonte no repo pra criar um sem
## reexportar o modelo inteiro.
##
## Um SkeletonModifier3D roda DEPOIS da AnimationTree, no mesmo quadro: as
## pernas continuam andando/correndo pela StateMachine normal e so' o braco
## esquerdo e' reescrito por cima. E' o mesmo efeito de um blend de meio corpo,
## sem mexer na arvore de animacao nem no .glb.
##
## ==========================================================================
## COMO O BRACO ACHA A PORTA
##
## Nada de angulo chutado por osso. Os ossos deste rig sao Mixamo (eixo do
## osso no Y local, e o corpo ainda vem girado 180 no `char1`), entao qualquer
## rotacao escrita "na mao" sairia pro lado errado.
##
## Em vez disso, o braco APONTA: para cada osso da cadeia calcula-se a direcao
## em que ele aponta hoje (da origem dele ate' a origem do filho) e gira-se ele
## pelo arco que leva essa direcao ate' o alvo. Isso e' independente de eixo
## local, de convencao de rig e do giro do modelo — funciona lendo a pose que a
## animacao acabou de escrever.
##
## O ombro fica de fora de proposito: girar o ombro junto levanta o tronco
## inteiro e estraga a passada. A MAO, ao contrario, nao aponta: ela e' posta
## numa pose fixa — ver `_palma_na_folha`.
##
## ==========================================================================
## O ESPACO DOS OSSOS NAO E' O ESPACO DO CORPO QUE SE VE
##
## Este e' o detalhe que faz ou quebra a coisa toda. No `player.tscn`, a malha
## `char1` (filha do Skeleton3D) leva uma transformacao propria: GIRADA 180
## GRAUS e descida cerca de 1 m (0, -101.43, 30.51 — em centimetros).
##
## Ou seja: o esqueleto olha pro +Z, e o corpo que aparece na tela olha pro -Z.
## Converter o alvo com `skeleton.global_transform` — o caminho obvio — manda o
## braco exatamente pro lado CONTRARIO da porta, e ainda torcido pra tras.
##
## Por isso a conversao usa a global da MALHA (`char1`), que e' a unica que
## bate com o que o jogador ve'. Ela ja' carrega a escala do Armature (o
## Skeleton3D esta' em CENTIMETROS: o Hips nasce em y ~94), o giro de 180 e o
## desloca junto, tudo numa conta so'.

## O BRACO E' O ESQUERDO DE PROPOSITO. A pistola fica na MAO DIREITA (ver
## `player_gun_hold.gd`), entao empurrar a porta com a direita era empurrar
## com a arma. A mao livre e' a esquerda.
const OSSO_BRACO := "LeftArm"
const OSSO_ANTEBRACO := "LeftForeArm"
const OSSO_MAO := "LeftHand"

## Tempo pro braco sair da animacao e chegar esticado, e pra voltar. A volta e'
## mais lenta que a ida: a mao sai da porta empurrando, nao dando um tapa.
const SUBIDA := 0.14
const DESCIDA := 0.50

## Abaixo disto o modificador nem escreve pose — deixa a animacao passar limpa.
const PESO_MINIMO := 0.002

var _alvo := Vector3.ZERO
var _segurando := 0.0
var _peso := 0.0
## O ALVO CONGELADO NO CORPO DELE.
##
## O ponto chega em MUNDO, mas so' e' lido assim UMA VEZ, no primeiro quadro do
## gesto: dali em diante vale esta copia, que mora no espaco dos ossos e portanto
## GIRA JUNTO com o Maycow. E' o que faz a mao ficar "pra frente" em vez de
## continuar perseguindo a porta — perto dela, girando, o braco se enrolava
## atras do alvo parado no mundo e torcia o modelo todo.
##
## Solta sozinho quando o braco termina de descer (`_peso` no chao), entao o
## proximo empurrao trava um alvo novo.
var _alvo_no_corpo := Vector3.ZERO
var _alvo_preso := false

var _i_braco := -1
var _i_ante := -1
var _i_mao := -1
## A malha skinada. E' a global DELA que traduz mundo <-> espaco dos ossos.
var _malha: MeshInstance3D = null


## Estica o braco esquerdo na direcao de `ponto` (coordenadas de MUNDO) e
## segura ali por `tempo` segundos. Chamar de novo enquanto ainda esta' esticado
## so' renova o TEMPO: a direcao ja' foi travada no corpo dele no comeco do
## gesto (ver `_alvo_no_corpo`) e nao muda mais ate' o braco descer.
func estica(ponto: Vector3, tempo: float) -> void:
	_alvo = ponto
	_segurando = maxf(_segurando, tempo)


## Roda depois da AnimationTree, no mesmo quadro em que o esqueleto atualiza.
func _process_modification_with_delta(delta: float) -> void:
	if _segurando > 0.0:
		_segurando -= delta
		_peso = minf(1.0, _peso + delta / SUBIDA)
	else:
		_peso = maxf(0.0, _peso - delta / DESCIDA)
	if _peso <= PESO_MINIMO:
		_alvo_preso = false
		return

	var sk := get_skeleton()
	if sk == null:
		return
	# -2 e' "ja' procurei e este rig nao tem os ossos": nao adianta procurar de
	# novo todo quadro.
	if _i_braco == -2:
		return
	if _i_braco < 0 and not _procurar_ossos(sk):
		return

	# Suaviza as pontas: sem isto a mao arranca e para em seco.
	var peso := smoothstep(0.0, 1.0, _peso)
	var espaco := _malha.global_transform if is_instance_valid(_malha) else sk.global_transform
	if not _alvo_preso:
		_alvo_no_corpo = espaco.affine_inverse() * _alvo
		_alvo_preso = true
	var alvo_local := _alvo_no_corpo

	var g_braco := sk.get_bone_global_pose(_i_braco)
	var l_ante := sk.get_bone_pose(_i_ante)
	var l_mao := sk.get_bone_pose(_i_mao)

	var g_braco_novo := _apontar(g_braco, (g_braco * l_ante).origin, alvo_local, peso)
	# O antebraco tem de ser recalculado a partir do braco JA' girado: lendo a
	# pose global dele direto do esqueleto viria a de antes do giro, e o
	# cotovelo dobraria pro lado contrario.
	var g_ante := g_braco_novo * l_ante
	var g_ante_novo := _apontar(g_ante, (g_ante * l_mao).origin, alvo_local, peso)

	sk.set_bone_global_pose(_i_braco, g_braco_novo)
	sk.set_bone_pose(_i_ante, g_braco_novo.affine_inverse() * g_ante_novo)

	# E a MAO, por ultimo: aberta, dedos pra cima e palma na folha. O braco
	# aponta, mas sem isto a mao chega na porta do jeito que a animacao de andar
	# a deixou — de lado, encostando o dorso.
	var g_mao := g_ante_novo * l_mao
	# A direcao do ANTEBRACO e' a referencia de pulso reto: os dedos saem dali
	# e so' sobem o tanto de `DEDOS_PRA_CIMA` (ver abaixo).
	var reto := g_mao.origin - g_ante_novo.origin
	sk.set_bone_global_pose(_i_mao, Transform3D(
		_palma_na_folha(g_mao, alvo_local, reto, peso), g_mao.origin))


## A POSE DA MAO QUE EMPURRA: mao levantada, palma virada pra folha.
##
## Os eixos do osso da mao neste rig (medidos no repouso do .glb): o Y corre do
## pulso pros dedos, e o X e' o DORSO da mao esquerda — a palma e' o -X. Na mao
## direita e' o contrario, por isso o `PALMA_NO_X` aqui embaixo e' do lado
## esquerdo e teria de trocar de sinal se um dia o braco voltar a ser o direito.
##
## O alvo e' achatado no plano do chao antes de virar a palma: a folha da porta
## e' vertical, entao o que manda e' so' a direcao horizontal ate' ela — deixar
## a altura entrar torceria o pulso pra baixo quando o ponto da porta ficasse
## mais alto ou mais baixo que a mao.
const PALMA_NO_X := -1.0

## O MEIO TERMO DO PULSO. Dedos retos pra cima e' 90 graus de dobra no pulso —
## mais do que uma mao faz, e a pele acompanha afinando o punho (o rig nao tem
## correcao nenhuma nessa juntura). Entao os dedos nao vao ate' o alto: saem da
## direcao do ANTEBRACO — pulso reto, dobra nenhuma — e sobem so' uma parte do
## caminho.
##
## 0 = a mao segue o antebraco, 1 = dedos no prumo. 0.55 e' a mao levantada que
## se ve' num empurrao de verdade, sem o pulso quebrar.
const DEDOS_PRA_CIMA := 0.55
## E nem essa pose chega inteira: o resto fica sendo a pose da animacao, que e'
## o que sobra de carne no pulso. Baixar isto alivia mais o punho e deixa a
## palma menos colada na folha.
const FORCA_DA_POSE := 0.85

func _palma_na_folha(g: Transform3D, alvo: Vector3, reto: Vector3,
		peso: float) -> Basis:
	var frente := alvo - g.origin
	frente.y = 0.0
	if frente.length_squared() < 0.0001 or reto.length_squared() < 0.0001:
		return g.basis
	frente = frente.normalized()
	var dedos := reto.normalized().slerp(Vector3.UP, DEDOS_PRA_CIMA)
	if dedos.length_squared() < 0.0001:
		return g.basis
	dedos = dedos.normalized()
	# A palma tem de ser perpendicular aos dedos: tira-se dela o tanto que
	# aponta na direcao deles. Sem isto a base sai torta e a mao entra na folha
	# de esguelha.
	var eixo_x := frente * PALMA_NO_X
	eixo_x -= dedos * eixo_x.dot(dedos)
	if eixo_x.length_squared() < 0.0001:
		return g.basis
	eixo_x = eixo_x.normalized()
	var desejada := Basis(eixo_x, dedos, eixo_x.cross(dedos)).orthonormalized()
	return g.basis.orthonormalized().slerp(desejada, peso * FORCA_DA_POSE)


## Gira `g` pelo arco que leva a direcao "origem -> ponta" ate' a direcao
## "origem -> alvo", com `peso` 0 (nada) a 1 (apontando de vez).
func _apontar(g: Transform3D, ponta: Vector3, alvo: Vector3, peso: float) -> Transform3D:
	var atual := ponta - g.origin
	var desejado := alvo - g.origin
	if atual.length_squared() < 0.0001 or desejado.length_squared() < 0.0001:
		return g
	var giro := Quaternion(atual.normalized(), desejado.normalized())
	giro = Quaternion.IDENTITY.slerp(giro, peso)
	return Transform3D(Basis(giro) * g.basis, g.origin)


func _procurar_ossos(sk: Skeleton3D) -> bool:
	for filho in sk.get_children():
		if filho is MeshInstance3D:
			_malha = filho
			break
	_i_braco = sk.find_bone(OSSO_BRACO)
	_i_ante = sk.find_bone(OSSO_ANTEBRACO)
	_i_mao = sk.find_bone(OSSO_MAO)
	if _i_braco < 0 or _i_ante < 0 or _i_mao < 0:
		push_warning("player_door_reach: rig sem %s/%s/%s — a mao nao vai esticar"
			% [OSSO_BRACO, OSSO_ANTEBRACO, OSSO_MAO])
		_i_braco = -2
		return false
	return true
