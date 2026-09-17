extends SkeletonModifier3D

## A PISTOLA NA MAO DIREITA DO MAYCOW NORMAL — POSE DE MIRA E RECARGA.
##
## Irmao do `player_door_reach.gd`, e pelo mesmo motivo: o rig do Maycow normal
## (maycow_normal_rigged.glb) tem 24 ossos, NENHUM dedo, e nao ha' .blend fonte
## no repo. Nao existe clipe de "segurar arma", de "mirar" nem de "recarregar", e
## criar um exigiria reexportar o modelo inteiro. Um SkeletonModifier3D roda
## DEPOIS da AnimationTree, no mesmo quadro: as pernas continuam andando pela
## StateMachine de sempre e so' os bracos sao reescritos por cima.
##
## ==========================================================================
## A ARMA NAO E' FILHA DO ESQUELETO
##
## No `player.tscn` a malha `char1` leva transformacao propria: girada 180 graus
## e descida ~1 m (0, -101.43, 30.51 — em CENTIMETROS). O esqueleto olha pro +Z
## e o corpo que aparece na tela olha pro -Z. Pra malha skinada o Godot APLICA
## essa transformacao por cima das poses dos ossos.
##
## Consequencia: um `BoneAttachment3D` (que se posiciona pela global do
## ESQUELETO) poe a arma um metro fora e virada ao contrario. Por isso a arma
## nasce como filha da MALHA, e o transform LOCAL dela e' a pose do osso lida
## crua do esqueleto — que e' exatamente o espaco em que a pele e' desenhada.
## (Medido: bola vermelha na conversao pela malha cai na mao; pela do esqueleto
## fica boiando no ar.)
##
## Isso tambem responde a escala: o esqueleto esta' em centimetros, e TUDO aqui
## dentro e' centimetro. A arma de 22 cm vive com escala 11,5.
##
## ==========================================================================
## AS MAOS SAO POSTAS ONDE ELAS DEVEM FICAR, E O BRACO SE VIRA (IK)
##
## Duas versoes anteriores giravam a cadeia do braco ate' ela APONTAR pro alvo.
## Apontava certo, mas a mao ia parar onde o comprimento do braco quisesse — e
## isso explica os dois defeitos que sobraram: a esquerda nunca encontrava a
## arma de verdade, e as duas balancavam com o corpo.
##
## Agora e' o contrario: o destino de cada mao e' calculado primeiro, num ponto
## fixo em relacao ao TRONCO (a esquerda em cima da direita, as duas na linha da
## mira), e um IK de dois ossos dobra o cotovelo pra chegar la'. A raiz do braco
## fica exatamente onde a animacao a poe (nada descola do ombro, a manga nao
## estica) e o cotovelo absorve o balanco da passada — a mao nao se mexe.
##
## O ponto de onde os destinos sao medidos e' AMORTECIDO (`AMORTECE_TRONCO`), e
## isso agora sai de graca: com IK, amortecer o destino da mao nao arranca nada
## do lugar, so' faz o cotovelo dobrar um pouco mais ou menos.
##
## ==========================================================================
## A ARMA E' SEGURA PELO CABO, NAO PELO CENTRO
##
## O .glb tem a origem no meio da caixa envolvente. Pondo essa origem na mao, o
## cabo fica uns 7 cm atras dela — a arma aparece deitada no antebraco. O cabo
## esta' medido em CABO_NO_MODELO, e e' ELE que vai pra mao.
##
## O "alto" da arma vem do +Y do espaco dos ossos (o esqueleto esta' de pe', e o
## giro de 180 do char1 e' em torno do Y, entao Y continua sendo cima). Vinha do
## eixo do osso da mao, que apontava pra baixo: era isso que deixava a pistola de
## cabeca pra baixo.

const OSSO_BRACO_D := "RightArm"
const OSSO_ANTEBRACO_D := "RightForeArm"
const OSSO_MAO_D := "RightHand"
const OSSO_BRACO_E := "LeftArm"
const OSSO_ANTEBRACO_E := "LeftForeArm"
const OSSO_MAO_E := "LeftHand"

const ITEM_PISTOLA := "pistol"
const MODELO_PISTOLA := "res://assets/3d_model/player/the_negotiator_V1/the_negotiator_v1.glb"

## Escala da arma DENTRO do esqueleto (que esta' em centimetros): 11,5 aqui sao
## os 22 cm de cano que o modelo tem quando o mundo o ve'.
const ESCALA_ARMA := 11.5

# ==============================================================================
# OS NUMEROS QUE PRECISAM DE OLHO HUMANO
#
# Da' pra acertar todos SEM recompilar: F9 dentro do jogo liga o modo de ajuste
# (ver o fim do arquivo). Tudo em CENTIMETROS e GRAUS.
# ==============================================================================

## Onde a mao fecha na arma, em unidades do MODELO (antes da escala). Medido nos
## vertices do cabo: o terco de cima dele, logo abaixo do guarda-mato.
const CABO_NO_MODELO := Vector3(0.61, -0.33, 0.0)

## Retoque fino por cima do cabo, no espaco da arma: X ao longo do cano,
## Y altura, Z lateral.
const OFFSET_NA_MAO := Vector3(0.0, 0.0, 0.0)

## Quebra do punho, em graus, com a arma BAIXADA (mirando vale zero — la' quem
## manda e' o alvo).
const INCLINACAO_PUNHO := 12.0

# ---- onde as maos param quando ele mira ---------------------------------------
## Distancia das maos a' frente do meio dos ombros. O braco tem ~49 cm do ombro
## ao punho; 40 deixa o cotovelo com dobra de tiro, nem esticado nem colado.
const MAOS_FRENTE := 40.0
## Desvio lateral das maos (+ = pro lado da arma, a direita dele).
const MAOS_LADO := 4.0
## Altura das maos em relacao a' linha dos ombros (- = na altura do peito).
const MAOS_ALTURA := -5.0
## Onde a mao ESQUERDA fica em relacao a' direita: por baixo e um pouco pro lado
## dela, que e' como a mao de apoio fecha por cima da mao de tiro.
const APOIO_LADO := 5.0
const APOIO_ALTURA := -2.0

## Pra onde o cotovelo aponta: pra baixo e um tanto pra fora.
const COTOVELO_BAIXO := 40.0
const COTOVELO_FORA := 16.0

# ---- quanto do sobe-e-desce do tronco chega nas maos --------------------------
# Com IK isto sai barato: amortecer o DESTINO da mao nao descola nada do corpo,
# so' muda o quanto o cotovelo dobra. 0 = a mao acompanha o tronco exatamente;
# 1 = a mao fica parada no ar enquanto o corpo bamboleia.
const AMORTECE_TRONCO := 0.85
## Quao rapido a ancora amortecida persegue a de verdade (1/s).
const AMORTECE_VELOCIDADE := 6.0
## Coleira: o maximo que o ponto de medida pode se afastar do corpo, em cm.
const AMORTECE_MAX := 6.0

## Tempo pra pose entrar e sair.
const SUBIDA := 0.12
const DESCIDA := 0.28

## Abaixo disto o modificador nao escreve pose nenhuma: deixa a animacao passar.
const PESO_MINIMO := 0.002

## Quao rapido o alvo perseguido alcanca o alvo pedido (1/s). O ponto de mira vem
## de um raio na tela e PULA quando o raio troca de superficie; sem amortecer,
## esse pulo vira um tranco no braco.
const SUAVIZA_ALVO := 14.0

# ---- a recarga ----------------------------------------------------------------
## Quanto a arma recolhe pro peito pra ser recarregada.
const RECARGA_RECOLHE := 16.0
const RECARGA_DESCE := 10.0
## Quanto ela gira em torno do cano, pra mostrar o poco do carregador.
const RECARGA_ROLAGEM := 42.0
## E quanto o cano sobe (a arma fica olhando pra cima enquanto ele encaixa).
const RECARGA_LEVANTA := 30.0
## Onde a mao esquerda vai buscar o pente: cintura, do lado dela.
const CINTO_LADO := 16.0
const CINTO_ALTURA := 34.0
const CINTO_FRENTE := 6.0

var _mirando: bool = false
var _alvo := Vector3.ZERO
var _alvo_suave := Vector3.ZERO
var _tem_alvo := false
var _peso := 0.0

var _recarregando := false
var _recarga := 0.0
var _recarga_total := 1.0

var _i_braco_d := -1
var _i_ante_d := -1
var _i_mao_d := -1
var _i_braco_e := -1
var _i_ante_e := -1
var _i_mao_e := -1

var _malha: MeshInstance3D = null
var _arma: Node3D = null
## Pose da arma no ultimo quadro, no espaco da MALHA (centimetros). O tiro
## pergunta por ela pra saber de onde sai o clarao e a capsula.
var _pose_arma := Transform3D.IDENTITY
## Ancora amortecida (meio dos ombros), de onde as maos sao medidas.
var _ancora_suave := Vector3.ZERO
var _tem_ancora := false

## Valores em uso. Nascem das constantes e so' mudam no modo de ajuste.
var _cabo := CABO_NO_MODELO
var _offset := OFFSET_NA_MAO
var _inclinacao := INCLINACAO_PUNHO


# ==============================================================================
# O QUE O PLAYER CHAMA
# ==============================================================================
## Liga/desliga a pose de mira e diz pra onde o cano aponta (mundo).
func mirar(ativo: bool, ponto: Vector3 = Vector3.ZERO) -> void:
	_mirando = ativo
	if ativo:
		_alvo = ponto
		if not _tem_alvo:
			# Primeiro quadro da mirada: comeca ja' no alvo, senao a mao sobe
			# perseguindo um ponto que ficou pra tras.
			_alvo_suave = ponto
			_tem_alvo = true
	else:
		_tem_alvo = false


## Toca a recarga. Vale mesmo sem estar mirando — quem recarrega a arma levanta
## ela pra fazer isso, esteja de mira aberta ou nao.
func recarregar(tempo: float) -> void:
	_recarga_total = maxf(0.3, tempo)
	_recarga = 0.0
	_recarregando = true


func esta_recarregando() -> bool:
	return _recarregando


## A arma esta' montada e visivel?
func tem_arma_na_mao() -> bool:
	return is_instance_valid(_arma) and _arma.visible


## Onde fica a boca do cano, em coordenadas de MUNDO.
func boca_do_cano() -> Vector3:
	if not is_instance_valid(_malha) or not is_instance_valid(_arma):
		return Vector3.ZERO
	# O modelo tem 0,96 unidade da origem ate' a boca, e o cano e' o -X dele.
	return _malha.global_transform * (_pose_arma * Vector3(-0.96 * ESCALA_ARMA, 0.0, 0.0))


## Pra onde o cano aponta, em coordenadas de MUNDO (vetor unitario).
func direcao_do_cano() -> Vector3:
	if not is_instance_valid(_malha):
		return Vector3.FORWARD
	var eixo := _malha.global_transform.basis * (_pose_arma.basis * Vector3.LEFT)
	return eixo.normalized()


# ==============================================================================
# O QUADRO
# ==============================================================================
## Roda dentro da fase de modificacao do esqueleto — o unico momento em que a
## pose lida e' a pose que vai pra tela. Fora dela o Skeleton3D RESTAURA as
## poses da animacao, e a arma andaria um quadro atrasada do proprio braco.
func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	# -2 e' "ja' procurei e este rig nao tem os ossos": nao adianta procurar de
	# novo todo quadro.
	if _i_braco_d == -2:
		return
	if _i_braco_d < 0 and not _procurar_ossos(sk):
		return

	var equipada: bool = SaveManager.is_equipped(ITEM_PISTOLA)
	_garantir_arma(equipada)
	if not equipada:
		_peso = 0.0
		_recarregando = false
		return

	if _recarregando:
		_recarga += delta / _recarga_total
		if _recarga >= 1.0:
			_recarregando = false
			_recarga = 0.0

	# Recarregar levanta a arma mesmo sem mira: a pose e' a mesma, o destino das
	# maos e' que muda.
	if _mirando or _recarregando:
		_peso = minf(1.0, _peso + delta / SUBIDA)
	else:
		_peso = maxf(0.0, _peso - delta / DESCIDA)
	if _mirando:
		_alvo_suave = _alvo_suave.lerp(_alvo, minf(1.0, delta * SUAVIZA_ALVO))

	# Suaviza as pontas: sem isto o braco arranca e para em seco.
	var peso := smoothstep(0.0, 1.0, _peso)
	# O alvo chega em MUNDO e tudo aqui dentro e' espaco de OSSO (centimetros, e
	# 180 graus virado). Converter aqui, uma vez, e' o que mantem as duas contas
	# no mesmo mundo — misturar os dois manda a mao pro chao sem avisar.
	var ctx := _montar_contexto(sk, _para_ossos(sk, _alvo_suave), peso, delta)

	if _peso > PESO_MINIMO:
		_ik_braco(sk, _i_braco_d, _i_ante_d, _i_mao_d,
			ctx["mao_d"], ctx["polo_d"], peso)
		_ik_braco(sk, _i_braco_e, _i_ante_e, _i_mao_e,
			ctx["mao_e"], ctx["polo_e"], peso)

	_pousar_arma(sk, ctx, peso)


## Onde tudo e' medido neste quadro: a ancora no tronco, os eixos da mira e o
## destino de cada mao. Tudo no espaco dos OSSOS (centimetros).
func _montar_contexto(sk: Skeleton3D, alvo: Vector3, peso: float,
		delta: float) -> Dictionary:
	# Raiz de cada braco, em repouso, pendurada no peito animado: estavel, e e'
	# o meio delas que serve de regua pras duas maos.
	var raiz_d := _raiz_estavel(sk, _i_braco_d).origin
	var raiz_e := _raiz_estavel(sk, _i_braco_e).origin
	var ancora := _amortecer((raiz_d + raiz_e) * 0.5, peso, delta)

	# Eixos da mira. No espaco dos ossos o corpo olha pro +Z e o Y e' cima; o
	# `cross` com o Y da' o lado DIREITO dele.
	var mira := alvo if _tem_alvo else ancora + Vector3(0, 0, 500.0)
	var dir := (mira - ancora)
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3(0, 0, 1)
	var direita := dir.cross(Vector3.UP)
	if direita.length_squared() < 0.0001:
		direita = Vector3(1, 0, 0)
	direita = direita.normalized()
	var cima := direita.cross(dir).normalized()

	# Destino das maos com a arma levantada.
	var mao_d := ancora + dir * MAOS_FRENTE + direita * MAOS_LADO + cima * MAOS_ALTURA
	var mao_e := mao_d - direita * APOIO_LADO + cima * APOIO_ALTURA

	var rolagem := 0.0
	var levanta := 0.0
	if _recarregando:
		var r := _recarga
		# Quanto a arma esta' recolhida (sobe no comeco, desce no fim).
		var recolhe := smoothstep(0.0, 0.18, r) - smoothstep(0.80, 1.0, r)
		# A mao esquerda larga a arma, desce ao cinto e volta com o pente.
		var solta := smoothstep(0.04, 0.28, r) - smoothstep(0.44, 0.68, r)
		# Empurrao curto do pente pra dentro.
		var encaixa := smoothstep(0.66, 0.74, r) - smoothstep(0.78, 0.90, r)

		mao_d += (-dir * RECARGA_RECOLHE - cima * RECARGA_DESCE) * recolhe
		mao_e = mao_d - direita * APOIO_LADO + cima * APOIO_ALTURA
		mao_e += (-direita * CINTO_LADO - cima * CINTO_ALTURA
			- dir * CINTO_FRENTE) * solta
		mao_e += cima * 3.5 * encaixa
		rolagem = RECARGA_ROLAGEM * recolhe
		levanta = RECARGA_LEVANTA * recolhe

	return {
		"dir": dir, "direita": direita, "cima": cima,
		"mao_d": mao_d, "mao_e": mao_e,
		"polo_d": mao_d - Vector3.UP * COTOVELO_BAIXO + direita * COTOVELO_FORA,
		"polo_e": mao_e - Vector3.UP * COTOVELO_BAIXO - direita * COTOVELO_FORA,
		"rolagem": rolagem, "levanta": levanta, "alvo": mira,
	}


## A raiz do braco com ORIENTACAO de repouso e POSICAO da animacao.
##
## A posicao tem de ser a animada: e' onde o ombro esta' de verdade, e mexer nela
## descola o braco do corpo. A orientacao e' a de repouso porque o IK vai girar
## tudo de qualquer jeito, e partir da pose animada traria o giro da passada pra
## dentro da conta.
func _raiz_estavel(sk: Skeleton3D, i_braco: int) -> Transform3D:
	var i_ombro := sk.get_bone_parent(i_braco)
	var i_peito := sk.get_bone_parent(i_ombro) if i_ombro >= 0 else -1
	var base := sk.get_bone_global_pose(i_braco)
	if i_peito < 0 or i_ombro < 0:
		return base
	var estavel := sk.get_bone_global_pose(i_peito) * sk.get_bone_rest(i_ombro) \
		* sk.get_bone_rest(i_braco)
	return Transform3D(estavel.basis, base.origin)


## IK de dois ossos: dobra o cotovelo pra mao cair EXATAMENTE em `alvo_mao`.
##
## Lei dos cossenos pro angulo do ombro, e o `polo` decide de que lado o cotovelo
## sai. A raiz nao se move — quem absorve o bamboleio do corpo e' a dobra.
func _ik_braco(sk: Skeleton3D, i_braco: int, i_ante: int, i_mao: int,
		alvo_mao: Vector3, polo: Vector3, peso: float) -> void:
	var g_raiz := _raiz_estavel(sk, i_braco)
	var rest_ante := sk.get_bone_rest(i_ante)
	var rest_mao := sk.get_bone_rest(i_mao)
	var l1 := rest_ante.origin.length()
	var l2 := rest_mao.origin.length()
	if l1 < 0.001 or l2 < 0.001:
		return

	var p := g_raiz.origin
	var v := alvo_mao - p
	var dist := clampf(v.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	if v.length_squared() < 0.0001:
		return
	var eixo := v.normalized()

	var cosseno := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist),
		-1.0, 1.0)
	var angulo := acos(cosseno)

	var perp := polo - p
	perp = perp - eixo * perp.dot(eixo)
	if perp.length_squared() < 0.0001:
		perp = eixo.cross(Vector3.UP)
		if perp.length_squared() < 0.0001:
			perp = eixo.cross(Vector3.RIGHT)
	perp = perp.normalized()

	var cotovelo := p + eixo * (cos(angulo) * l1) + perp * (sin(angulo) * l1)
	var destino := p + eixo * dist

	var g_braco_ik := _apontar(g_raiz, (g_raiz * rest_ante).origin, cotovelo)
	var g_ante_ik := g_braco_ik * rest_ante
	g_ante_ik = _apontar(g_ante_ik, (g_ante_ik * rest_mao).origin, destino)

	# A pose da animacao e' o outro extremo da mistura: com peso 0 nada muda.
	var g_braco_anim := sk.get_bone_global_pose(i_braco)
	var g_ante_anim := g_braco_anim * sk.get_bone_pose(i_ante)

	var g_braco := g_braco_anim.interpolate_with(g_braco_ik, peso)
	var g_ante := g_ante_anim.interpolate_with(g_ante_ik, peso)

	sk.set_bone_global_pose(i_braco, g_braco)
	sk.set_bone_pose(i_ante, g_braco.affine_inverse() * g_ante)
	# O punho tambem para de girar com a passada: sem isto a arma treme na mao
	# mesmo com o braco firme.
	sk.set_bone_pose(i_mao, sk.get_bone_pose(i_mao).interpolate_with(rest_mao, peso))


## Ponto do MUNDO no espaco dos ossos (centimetros, e girado com o char1).
func _para_ossos(sk: Skeleton3D, ponto: Vector3) -> Vector3:
	var espaco := _malha.global_transform if is_instance_valid(_malha) \
		else sk.global_transform
	return espaco.affine_inverse() * ponto


## Gira `g` pelo arco que leva a direcao "origem -> ponta" ate' "origem -> alvo".
func _apontar(g: Transform3D, ponta: Vector3, alvo: Vector3) -> Transform3D:
	var atual := ponta - g.origin
	var desejado := alvo - g.origin
	if atual.length_squared() < 0.0001 or desejado.length_squared() < 0.0001:
		return g
	var giro := Quaternion(atual.normalized(), desejado.normalized())
	return Transform3D(Basis(giro) * g.basis, g.origin)


## Filtra o sobe-e-desce do tronco do ponto de onde as maos sao medidas.
##
## Em ESPACO DE OSSO, que e' espaco do corpo: andar, girar e virar a camera nao
## passam por aqui, so' o bambolear da passada.
func _amortecer(ancora: Vector3, peso: float, delta: float) -> Vector3:
	if AMORTECE_TRONCO <= 0.0:
		return ancora
	if not _tem_ancora:
		_ancora_suave = ancora
		_tem_ancora = true
	_ancora_suave = _ancora_suave.lerp(ancora, minf(1.0, delta * AMORTECE_VELOCIDADE))

	var desejada := ancora.lerp(_ancora_suave, AMORTECE_TRONCO * peso)
	var desvio := desejada - ancora
	if desvio.length() > AMORTECE_MAX:
		desejada = ancora + desvio.normalized() * AMORTECE_MAX
	return desejada


# ==============================================================================
# A ARMA
# ==============================================================================
## Poe a arma na mao direita, segurada PELO CABO.
func _pousar_arma(sk: Skeleton3D, ctx: Dictionary, peso: float) -> void:
	if not is_instance_valid(_arma) or not _arma.visible:
		return

	var g_ante := sk.get_bone_global_pose(_i_ante_d)
	var g_mao := sk.get_bone_global_pose(_i_mao_d)

	# Baixada, a arma segue o ANTEBRACO (braco caido, arma pro chao). Levantada,
	# o cano vai pro ALVO — e' a diferenca entre "a arma esta' na direcao do
	# braco" e "a bala sai onde a mira da tela esta'".
	var cano := g_mao.origin - g_ante.origin
	if cano.length_squared() < 0.0001:
		return
	cano = cano.normalized()
	if peso > 0.0:
		var pro_alvo: Vector3 = ctx["dir"]
		if _tem_alvo:
			var v: Vector3 = ctx["alvo"] - g_mao.origin
			if v.length_squared() > 0.0001:
				pro_alvo = v.normalized()
		cano = cano.slerp(pro_alvo, peso).normalized()

	# O ALTO da arma vem do espaco dos ossos, que esta' de pe'. Vinha do eixo do
	# osso da mao — e era isso que deixava a pistola de cabeca pra baixo.
	var cima := Vector3.UP
	if absf(cima.dot(cano)) > 0.98:
		cima = ctx["cima"]
	cima = (cima - cano * cima.dot(cano)).normalized()

	# Modelo: X e' o cano com a boca no -X, Y e' o alto, Z e' a espessura.
	var eixo_x := -cano
	var eixo_z := eixo_x.cross(cima).normalized()
	var eixo_y := eixo_z.cross(eixo_x).normalized()
	var base := Basis(eixo_x, eixo_y, eixo_z)

	# Quebra do punho: pose de arma BAIXADA. Levantada ela some, senao jogaria o
	# cano acima do alvo justo quando ele tem de estar certo.
	base = base.rotated(eixo_z, deg_to_rad(_inclinacao * (1.0 - peso)))
	# Recarga: a arma rola pro lado (mostrando o poco do carregador) e levanta.
	if _recarregando:
		base = base.rotated(eixo_x, deg_to_rad(float(ctx["rolagem"])))
		base = base.rotated(eixo_z, deg_to_rad(float(ctx["levanta"])))

	# O CABO e' que vai pra mao, nao a origem do modelo.
	var cabo := base * ((_cabo + _offset) * ESCALA_ARMA)
	var pose := Transform3D(base, g_mao.origin - cabo)
	_pose_arma = pose
	_arma.transform = Transform3D(pose.basis.scaled(Vector3.ONE * ESCALA_ARMA),
		pose.origin)


## Monta (uma vez) ou esconde o modelo da arma.
##
## Ela e' filha da MALHA e nao deste no': este no' e' filho do Skeleton3D, e o
## espaco do esqueleto esta' 180 graus virado do corpo que se ve' (cabecalho).
func _garantir_arma(equipada: bool) -> void:
	if not is_instance_valid(_arma):
		if not equipada or not is_instance_valid(_malha):
			return
		var pacote: PackedScene = load(MODELO_PISTOLA)
		if pacote == null:
			push_warning("player_gun_hold: nao achei %s" % MODELO_PISTOLA)
			_i_braco_d = -2
			return
		_arma = pacote.instantiate()
		_arma.name = "PistolaNaMao"
		# Nada de colisao vinda do .glb: a arma anda colada no corpo e um corpo
		# fisico ali dentro brigaria com a capsula do jogador.
		for col in _arma.find_children("*", "CollisionObject3D", true, false):
			col.collision_layer = 0
			col.collision_mask = 0
		_malha.add_child(_arma)
	_arma.visible = equipada


func _procurar_ossos(sk: Skeleton3D) -> bool:
	for filho in sk.get_children():
		if filho is MeshInstance3D:
			_malha = filho
			break
	_i_braco_d = sk.find_bone(OSSO_BRACO_D)
	_i_ante_d = sk.find_bone(OSSO_ANTEBRACO_D)
	_i_mao_d = sk.find_bone(OSSO_MAO_D)
	_i_braco_e = sk.find_bone(OSSO_BRACO_E)
	_i_ante_e = sk.find_bone(OSSO_ANTEBRACO_E)
	_i_mao_e = sk.find_bone(OSSO_MAO_E)
	if mini(mini(_i_braco_d, _i_ante_d), mini(_i_mao_d, _i_braco_e)) < 0 \
			or mini(_i_ante_e, _i_mao_e) < 0:
		push_warning("player_gun_hold: rig sem os ossos de braco — a arma nao "
			+ "vai pra mao")
		_i_braco_d = -2
		return false
	return true


# ==============================================================================
# MODO DE AJUSTE — acertar a arma na mao sem recompilar
# ==============================================================================
## So' em build de debug (rodando pelo editor). Aperte F9 dentro do jogo:
##
##     I / K   arma pra frente / pra tras (ao longo do cano)
##     U / O   sobe / desce na mao
##     J / L   pra dentro / pra fora (lateral)
##     N / M   inclina o punho (so' com a arma baixada)
##     P       imprime os valores prontos pra colar nas constantes
##     F9      sai do modo
##
## Segurar a tecla repete. Um toque = 2 mm. Mire e solte a mira enquanto ajusta:
## a inclinacao do punho so' aparece com a arma baixada.
const AJUSTE_PASSO := 0.2       # centimetros por toque
const AJUSTE_PASSO_ANG := 1.0   # graus por toque

var _ajustando := false


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey):
		return
	var tecla := event as InputEventKey
	if not tecla.pressed:
		return

	if tecla.keycode == KEY_F9 and not tecla.echo:
		_ajustando = not _ajustando
		if _ajustando:
			print("[arma] ajuste LIGADO — I/K frente-tras, U/O cima-baixo, "
				+ "J/L lateral, N/M punho, P imprime")
			_imprimir_ajuste()
		else:
			print("[arma] ajuste desligado")
		return

	if not _ajustando:
		return

	# O passo entra no OFFSET, que e' o retoque por cima do cabo medido.
	var passo := AJUSTE_PASSO / ESCALA_ARMA
	match tecla.keycode:
		KEY_I: _offset.x -= passo
		KEY_K: _offset.x += passo
		KEY_U: _offset.y -= passo
		KEY_O: _offset.y += passo
		KEY_J: _offset.z += passo
		KEY_L: _offset.z -= passo
		KEY_N: _inclinacao -= AJUSTE_PASSO_ANG
		KEY_M: _inclinacao += AJUSTE_PASSO_ANG
		KEY_P: _imprimir_ajuste()
		_: return
	get_viewport().set_input_as_handled()
	if tecla.keycode != KEY_P:
		_imprimir_ajuste()


func _imprimir_ajuste() -> void:
	print("const OFFSET_NA_MAO := Vector3(%.3f, %.3f, %.3f)   |   "
		% [_offset.x, _offset.y, _offset.z]
		+ "const INCLINACAO_PUNHO := %.1f" % _inclinacao)
