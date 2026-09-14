extends RefCounted
class_name HumanoidPoser

## Anima um esqueleto humanoide (padrao Mixamo) por codigo, sem clipe de
## animacao nenhum. Os NPCs da cidade vieram de um pacote de modelos que traz
## so a malha e o rig — nenhum deles tem ciclo de caminhada — entao a passada,
## a conversa e o catar do chao sao calculados aqui, do mesmo jeito que o
## ShadowPerson calcula os dele.
##
## Como funciona
## -------------
## Cada "junta" recebe uma rotacao expressa no ESPACO DO CORPO (o do
## CharacterBody3D), e nao no espaco do osso. Os ossos do Mixamo nascem com
## orientacoes de repouso tortas — o femur tem o proprio Y apontando pra baixo,
## o braco vem girado pela pose em A — e escrever angulos direto neles viraria
## uma tabela de sinais impossivel de manter.
##
## A conversao e uma conjugacao:
##
##     pose_local = P⁻¹ · R · P · repouso_local
##
## onde P e a base GLOBAL DE REPOUSO DO PAI do osso. Ela leva a rotacao R do
## espaco do corpo para o espaco local do osso, preservando o repouso. Como o
## resultado e uma rotacao local, ela se propaga pela hierarquia sozinha: girar
## o ombro leva o cotovelo e a mao junto, sem nenhuma conta a mais.
##
## Pra que lado o corpo olha
## -------------------------
## Pro +Z. Quem manda nisso e o `_face()` do ShadowPerson:
##
##     rotation.y = atan2(to.x, to.z)
##
## esse angulo poe o +Z LOCAL em cima da direcao do movimento — e nao o -Z, que
## e a convencao do resto do Godot. O modelo do Mixamo ja nasce olhando pro +Z
## (o osso "Left" dele fica em +X, que e a esquerda de quem olha pra +Z), entao
## os dois batem e o modelo entra na cena SEM giro nenhum: `giro_y = 0`.
##
## Errar isto poe o NPC andando de costas — ele caminha certinho, so que na
## direcao contraria a que o rosto aponta.
##
## Sinais, conferidos osso a osso neste rig (corpo olhando pra +Z)
## --------------------------------------------------------------
##   quadril/ombro/cotovelo  x < 0  ->  membro vai pra FRENTE
##   joelho                  x > 0  ->  canela vai pra TRAS (o joelho real)
##   coluna/pescoco          x > 0  ->  tronco/cabeca inclinam pra FRENTE
##   ombro                   z      ->  esquerdo negativo e direito positivo
##                                      FECHAM o braco contra o corpo
##
## O joelho e a coluna invertem em relacao aos outros porque a cadeia deles
## aponta pro lado contrario: a canela pende do joelho, mas o tronco sobe do
## quadril.
##
## Os modelos vem numa pose em A — o braco ja nasce uns 12 graus aberto e uns
## 15 graus a frente. As poses daqui contam com isso e fecham o ombro de volta,
## senao o NPC anda com os bracos afastados do corpo.

## Nomes dos ossos por junta, com o peso de cada um. Repartir a coluna em tres
## e o pescoco em dois faz o tronco curvar num arco, em vez de quebrar num
## ponto so.
const JUNTAS := {
	"hips":       [["Hips", 1.0]],
	"spine":      [["Spine", 0.5], ["Spine1", 0.25], ["Spine2", 0.25]],
	"neck":       [["Neck", 0.45], ["Head", 0.55]],
	"shoulder_l": [["LeftArm", 1.0]],
	"elbow_l":    [["LeftForeArm", 1.0]],
	"shoulder_r": [["RightArm", 1.0]],
	"elbow_r":    [["RightForeArm", 1.0]],
	"hip_l":      [["LeftUpLeg", 1.0]],
	"knee_l":     [["LeftLeg", 1.0]],
	"foot_l":     [["LeftFoot", 1.0]],
	"hip_r":      [["RightUpLeg", 1.0]],
	"knee_r":     [["RightLeg", 1.0]],
	"foot_r":     [["RightFoot", 1.0]],
}

## Quanto o braco deve ficar afastado do corpo depois de ajustado, em radianos
## (uns 15 graus). Nao e um valor fixo de correcao, e um ALVO: os modelos do
## pacote vem com poses em A muito diferentes — o espalhamento de repouso vai
## de 12 a 40 graus — e fechar a mesma quantidade em todos deixa o braco de
## quem ja nascia fechado enfiado no torso. O quanto fechar (ou abrir) sai da
## medida do proprio rig, no setup.
##
## O valor e a mediana do que o pacote dava antes, quando o fecho era fixo:
## e o afastamento que a maioria ja tinha e que ficou bom. O ajuste por modelo
## nao muda a maioria — leva os extremos pra perto dela.
const BRACO_ALVO := 0.27

## Limite do ajuste, pra um rig estranho nao virar uma pose esquisita.
const AJUSTE_BRACO_MIN := -0.12
const AJUSTE_BRACO_MAX := 0.40

## Quanto o joelho dobra no pico do balanco, em radianos. E o que levanta o
## calcanhar atras do corpo: alto demais e o NPC parece estar dando um coice a
## cada passo. O suficiente e a canela nao raspar no chao na volta.
const JOELHO_BALANCO := 0.70

## Quanto a perna abre mais pra frente do que pra tras. Simetrico, o pe sobra
## atras do corpo — gente de verdade estende pouco o quadril pra tras e
## bastante pra frente. A soma dos dois extremos nao muda (1+v e 1-v), entao a
## passada continua do mesmo tamanho e o pe continua sem patinar.
const VIES_PRA_FRENTE := 0.28

## Prefixos aceitos nos nomes dos ossos. O Godot troca o ":" do Mixamo por "_",
## mas arquivos reexportados por outras ferramentas chegam sem prefixo nenhum.
const PREFIXOS := ["mixamorig_", "mixamorig:", "mixamorig1_", ""]

var skeleton: Skeleton3D

var _idx := {}          # junta -> Array[[indice_do_osso, peso]]
var _pai_inv := {}      # indice -> base global de repouso do pai, invertida
var _pai := {}          # indice -> base global de repouso do pai
var _repouso := {}      # indice -> base local de repouso
var _hips_idx := -1
var _hips_repouso := Vector3.ZERO
var _giro := Basis.IDENTITY

## Quanto fechar cada ombro pra chegar no BRACO_ALVO. Medido por modelo no
## setup; positivo fecha, negativo abre.
var _ajuste_braco_l := 0.0
var _ajuste_braco_r := 0.0

## Altura do quadril em repouso, em metros. Serve de escala pra tudo que e
## medido em distancia (balanco vertical, abaixada).
var altura_quadril := 1.0
## Comprimento da perna (quadril ate o pe). A abertura da passada sai daqui.
var comprimento_perna := 0.9
## Altura do topo da cabeca, usada pra dimensionar o collider.
var altura_total := 1.75


## `giro_y` e o quanto o modelo foi girado DENTRO do NPC. Com o pacote do
## Mixamo e 0: modelo e corpo ja olham pro mesmo lado (ver o cabecalho). O
## parametro fica aqui pra um modelo futuro que venha torto.
func setup(sk: Skeleton3D, giro_y: float = 0.0) -> bool:
	skeleton = sk
	if skeleton == null:
		return false
	_giro = Basis.from_euler(Vector3(0.0, giro_y, 0.0))

	for junta in JUNTAS.keys():
		var lista: Array = []
		for par in JUNTAS[junta]:
			var i := _acha_osso(par[0])
			if i >= 0:
				lista.append([i, float(par[1])])
		if not lista.is_empty():
			_idx[junta] = lista

	if not _idx.has("hip_l") or not _idx.has("spine"):
		return false   # nao e um rig humanoide reconhecivel

	for b in skeleton.get_bone_count():
		var p := skeleton.get_bone_parent(b)
		var base: Basis = skeleton.get_bone_global_rest(p).basis if p >= 0 else Basis.IDENTITY
		_pai[b] = base
		_pai_inv[b] = base.inverse()
		_repouso[b] = skeleton.get_bone_rest(b).basis

	_hips_idx = _idx["hips"][0][0] if _idx.has("hips") else -1
	if _hips_idx >= 0:
		_hips_repouso = skeleton.get_bone_rest(_hips_idx).origin
		altura_quadril = maxf(skeleton.get_bone_global_rest(_hips_idx).origin.y, 0.1)

	var pe := _acha_osso("LeftFoot")
	if pe >= 0 and _hips_idx >= 0:
		comprimento_perna = maxf(altura_quadril - skeleton.get_bone_global_rest(pe).origin.y, 0.1)
	var topo := _acha_osso("HeadTop_End")
	if topo < 0:
		topo = _acha_osso("Head")
	if topo >= 0:
		altura_total = maxf(skeleton.get_bone_global_rest(topo).origin.y * 1.06, 0.5)

	_ajuste_braco_l = clampf(_espalhamento("LeftArm", "LeftHand", 1.0) - BRACO_ALVO,
		AJUSTE_BRACO_MIN, AJUSTE_BRACO_MAX)
	_ajuste_braco_r = clampf(_espalhamento("RightArm", "RightHand", -1.0) - BRACO_ALVO,
		AJUSTE_BRACO_MIN, AJUSTE_BRACO_MAX)
	return true


## Quanto o braco ja esta aberto na pose de repouso do arquivo, em radianos.
## `lado` e +1 pro braco que fica em +X e -1 pro outro, pra os dois devolverem
## um numero positivo quando estao abertos.
func _espalhamento(osso: String, ponta: String, lado: float) -> float:
	var a := _acha_osso(osso)
	var b := _acha_osso(ponta)
	if a < 0 or b < 0:
		return BRACO_ALVO   # sem medida, nao mexe
	var d: Vector3 = skeleton.get_bone_global_rest(b).origin - skeleton.get_bone_global_rest(a).origin
	if d.y >= -0.001:
		return BRACO_ALVO   # braco nao pende pra baixo; melhor nao inventar
	return atan2(d.x * lado, -d.y)


func _acha_osso(nome: String) -> int:
	for p in PREFIXOS:
		var i := skeleton.find_bone(p + nome)
		if i >= 0:
			return i
	return -1


## Rotacao da junta, em radianos, no espaco do corpo.
func junta(chave: String, rot: Vector3) -> void:
	if not _idx.has(chave):
		return
	var r := _giro * Basis.from_euler(rot) * _giro
	var q := r.get_rotation_quaternion()
	for par in _idx[chave]:
		var i: int = par[0]
		var peso: float = par[1]
		var rp := r if peso >= 0.999 else Basis(Quaternion.IDENTITY.slerp(q, peso))
		var local: Basis = _pai_inv[i] * rp * _pai[i] * _repouso[i]
		skeleton.set_bone_pose_rotation(i, local.orthonormalized().get_rotation_quaternion())


## Sobe ou desce o quadril (e com ele o corpo todo) em metros.
func desloca_quadril(dy: float) -> void:
	if _hips_idx >= 0:
		skeleton.set_bone_pose_position(_hips_idx, _hips_repouso + Vector3(0.0, dy, 0.0))


func repouso() -> void:
	for chave in _idx.keys():
		junta(chave, Vector3.ZERO)
	desloca_quadril(0.0)


# ------------------------------------------------------------------ passada

## Abertura da perna que faz a passada casar com a velocidade, em vez de o pe
## patinar no chao. A passada de um passo e `velocidade * meio ciclo`; a perna
## so precisa abrir o arco que cobre essa distancia.
func abertura_para(velocidade: float, cadencia: float) -> float:
	if velocidade <= 0.01 or cadencia <= 0.01:
		return 0.0
	var passada := velocidade * PI / cadencia
	return asin(clampf(passada / (2.0 * comprimento_perna), 0.0, 0.85))


## Passada e parado numa funcao so, e nao duas empilhadas, porque `junta()`
## SOBRESCREVE: chamar uma depois da outra apagaria a primeira. Cada junta e
## calculada uma vez, misturando o termo de andar (peso `blend`) com o de
## descansar (peso `1 - blend`).
##
## `t` e a fase da passada, `tg` o relogio solto dos gestos (respiracao, olhar
## em volta) — este ultimo corre mesmo com a pessoa parada.
func pose_locomocao(t: float, tg: float, blend: float, abertura: float) -> void:
	var parado := 1.0 - blend
	var s := sin(t)
	# x negativo = perna pra frente. O `s*s` e o vies: cresce igual nos dois
	# extremos, entao soma no arco da frente e desconta no de tras, sem criar
	# quina nenhuma na passagem pelo meio (em s = 0 ele vale zero e a
	# derivada continua 1).
	var perna_l := -(s + VIES_PRA_FRENTE * s * s) * abertura
	var perna_r := (s - VIES_PRA_FRENTE * s * s) * abertura

	# o joelho dobra logo depois de o pe deixar o chao, pra a canela passar sem
	# raspar; no apoio ele fica quase reto
	var flex_l := 0.05 + 0.03 * parado + maxf(0.0, -sin(t - 0.6)) * JOELHO_BALANCO * blend
	var flex_r := 0.05 + 0.03 * parado + maxf(0.0, -sin(t - 0.6 + PI)) * JOELHO_BALANCO * blend

	junta("hip_l", Vector3(perna_l, 0.0, 0.0))
	junta("hip_r", Vector3(perna_r, 0.0, 0.0))
	junta("knee_l", Vector3(flex_l, 0.0, 0.0))
	junta("knee_r", Vector3(flex_r, 0.0, 0.0))
	# tornozelo desfazendo coxa + joelho: a sola fica paralela ao chao em vez
	# de acompanhar a perna e apontar pro ceu. Desfaz so uma parte, de
	# proposito — desfazer tudo deixa o pe rigido, feito prancha.
	junta("foot_l", Vector3(-(perna_l + flex_l) * 0.70, 0.0, 0.0))
	junta("foot_r", Vector3(-(perna_r + flex_r) * 0.70, 0.0, 0.0))

	# braco contrario a perna. O z fecha o ombro contra o corpo: sem ele o
	# modelo anda com os bracos abertos, por causa da pose em A do arquivo.
	# balanca contra a perna, mas a partir do seno cru: o vies pra frente e
	# coisa de quadril, e no braco so deixaria os dois pendurados pra tras
	var extra := 0.03 * blend
	junta("shoulder_l", Vector3(s * abertura * 0.72, 0.0, -_ajuste_braco_l - extra))
	junta("shoulder_r", Vector3(-s * abertura * 0.72, 0.0, _ajuste_braco_r + extra))
	junta("elbow_l", Vector3(-(0.14 + 0.26 * blend * maxf(0.0, -s)), 0.0, 0.0))
	junta("elbow_r", Vector3(-(0.14 + 0.26 * blend * maxf(0.0, s)), 0.0, 0.0))

	# andando: o tronco contra-gira o quadril. Parado: respira e olha em volta.
	junta("hips", Vector3(0.0, s * 0.09 * blend, 0.0))
	junta("spine", Vector3(
		0.03 * blend + 0.02 * parado,
		-s * 0.11 * blend,
		s * 0.035 * blend + sin(tg * 0.7) * 0.022 * parado))
	junta("neck", Vector3(
		-0.02 * blend - sin(tg * 0.9) * 0.05 * parado,
		sin(tg * 0.35) * 0.40 * parado,
		0.0))
	# o corpo afunda um tico no meio da passada, quando as pernas estao mais
	# abertas; parado, so o sobe-desce da respiracao
	desloca_quadril(-(1.0 - absf(cos(t))) * 0.035 * blend * comprimento_perna
		+ sin(tg * 1.1) * 0.006 * parado)


# ------------------------------------------------------------------ conversa

## `falando` levanta os bracos e gesticula; quem escuta faz pouco e concorda
## com a cabeca.
func pose_conversando(t: float, falando: bool) -> void:
	var amp := 1.0 if falando else 0.30
	var tt := t * (2.1 if falando else 1.1)

	# maos na altura do peito, cotovelo fechado e ombro colado: e assim que uma
	# pessoa gesticula de pe. Braco esticado pra frente vira zumbi.
	var alto_l := -(0.24 + sin(tt * 1.3) * 0.22) * amp
	var alto_r := -(0.20 + sin(tt * 1.1 + 1.7) * 0.22) * amp
	junta("shoulder_l", Vector3(alto_l, 0.0, -_ajuste_braco_l - sin(tt * 0.8) * 0.10 * amp))
	junta("shoulder_r", Vector3(alto_r, 0.0, _ajuste_braco_r + sin(tt * 0.9 + 0.6) * 0.10 * amp))
	junta("elbow_l", Vector3(-(1.05 + sin(tt * 1.7 + 0.4) * 0.35) * amp - 0.14, 0.0, 0.0))
	junta("elbow_r", Vector3(-(1.00 + sin(tt * 1.5 + 2.2) * 0.35) * amp - 0.14, 0.0, 0.0))

	var aceno := sin(tt * (1.6 if falando else 2.4)) * (0.07 if falando else 0.13)
	junta("neck", Vector3(aceno, sin(tt * 0.9) * 0.10 * amp, 0.0))
	junta("spine", Vector3(0.03, sin(tt * 0.6) * 0.07 * amp, 0.0))
	junta("hips", Vector3(0.0, sin(tt * 0.6) * 0.03 * amp, 0.0))
	junta("hip_l", Vector3(0.0, 0.0, 0.0))
	junta("hip_r", Vector3(0.0, 0.0, 0.0))
	junta("knee_l", Vector3(0.06, 0.0, 0.0))
	junta("knee_r", Vector3(0.06, 0.0, 0.0))
	junta("foot_l", Vector3(-0.05, 0.0, 0.0))
	junta("foot_r", Vector3(-0.05, 0.0, 0.0))
	desloca_quadril(sin(tt * 1.4) * 0.008)


# ------------------------------------------------------------ catar do chao

## `p` vai de 0 (em pe) a 1 (agachado, mao no chao).
func pose_catando(p: float) -> void:
	# agacha: coxa sobe (x negativo), canela dobra pra tras, tronco pra frente
	var coxa := -0.72 * p
	var joelho := 1.25 * p
	junta("hip_l", Vector3(coxa, 0.0, 0.06 * p))
	junta("hip_r", Vector3(coxa * 0.94, 0.0, -0.06 * p))
	junta("knee_l", Vector3(joelho, 0.0, 0.0))
	junta("knee_r", Vector3(joelho * 0.96, 0.0, 0.0))
	junta("foot_l", Vector3(-(coxa + joelho) * 0.9, 0.0, 0.0))
	junta("foot_r", Vector3(-(coxa * 0.94 + joelho * 0.96) * 0.9, 0.0, 0.0))
	junta("hips", Vector3(0.0, 0.0, 0.0))
	junta("spine", Vector3(0.78 * p, 0.10 * p, 0.0))
	# o tronco ja jogou a cabeca pra baixo; o pescoco levanta um pouco pra ele
	# olhar o que esta pegando, e nao o proprio joelho
	junta("neck", Vector3(-0.22 * p, 0.0, 0.0))

	# braco direito desce ate o chao e fecha a mao no fim; o esquerdo vai pra
	# tras fazendo contrapeso
	var pega := smoothstep(0.55, 1.0, p)
	junta("shoulder_r", Vector3(-0.75 * p, 0.0, _ajuste_braco_r * (1.0 - p) + 0.10 * p))
	junta("elbow_r", Vector3(-(0.20 * p + 0.55 * (1.0 - pega) * p) - 0.14 * (1.0 - p), 0.0, 0.0))
	junta("shoulder_l", Vector3(0.35 * p, 0.0, -_ajuste_braco_l - 0.12 * p))
	junta("elbow_l", Vector3(-0.45 * p - 0.14 * (1.0 - p), 0.0, 0.0))

	# o quadril desce o que as pernas dobradas encurtaram
	desloca_quadril(-comprimento_perna * (1.0 - cos(coxa)) * 1.0)
