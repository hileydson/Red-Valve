extends RefCounted

## A MATEMATICA DE BRACO QUE AS ARMAS DO MAYCOW NORMAL COMPARTILHAM.
##
## So' funcao estatica: nada aqui guarda estado, nada aqui sabe de arma. Sao as
## contas que `player_gun_hold.gd` (pistola) escreveu primeiro e que
## `player_shotgun_hold.gd` (cacadeira) precisa identicas — IK de dois ossos,
## raiz estavel do braco, apontar um transform, dividir a torcao do pulso.
##
## Todas trabalham no ESPACO DOS OSSOS: centimetros, corpo olhando pro +Z, Y pra
## cima. Quem converte de mundo pra ca' e' quem chama.
##
## ==========================================================================
## POR QUE UM ARQUIVO SO' PRA ISTO
##
## O projeto ja' pagou esse preco uma vez: `_tenta_agarrao` existe copiado em
## quatro scripts de inimigo, e mexer no agarrao virou mexer em quatro lugares.
## Braco de arma e' pior, porque o erro nao aparece como bug — aparece como mao
## fora do cabo, e ai' alguem "conserta" so' a copia que estava vendo.
##
## NAO tem `class_name` de proposito: nomear classe por fora do editor derruba o
## Godot com erro 43 sem linha (ver a nota do projeto). Quem usa faz
## `const IK := preload("res://scripts/player/arma_ik.gd")`.
##
## ==========================================================================
## A PISTOLA AINDA TEM A COPIA DELA
##
## `player_gun_hold.gd` continua com estas mesmas contas escritas dentro dele.
## Nao foram tiradas de la' nesta passada de proposito: a pose da pistola esta'
## afinada na mao, numero por numero, e trocar o motor dela junto com a entrada
## de uma arma nova seria arriscar o que ja' funciona por arrumacao. Quando for
## mexer naquele arquivo por outro motivo, e' aqui que as funcoes moram.


## IK DE DOIS OSSOS: dobra o cotovelo pra mao cair EXATAMENTE em `alvo_mao`.
##
## Lei dos cossenos pro angulo do ombro, e o `polo` decide de que lado o cotovelo
## sai. A raiz nao se move — quem absorve o bamboleio do corpo e' a dobra.
##
## `peso` mistura com a pose da animacao: 0 nao muda nada, 1 e' o IK puro.
static func braco(sk: Skeleton3D, i_braco: int, i_ante: int, i_mao: int,
		alvo_mao: Vector3, polo: Vector3, peso: float) -> void:
	var g_raiz := raiz_estavel(sk, i_braco)
	var rest_ante := sk.get_bone_rest(i_ante)
	var rest_mao := sk.get_bone_rest(i_mao)
	var l1 := rest_ante.origin.length()
	var l2 := rest_mao.origin.length()
	if l1 < 0.001 or l2 < 0.001:
		return

	var p := g_raiz.origin
	var v := alvo_mao - p
	if v.length_squared() < 0.0001:
		return
	# Alvo fora de alcance nao estica o braco alem do osso: ele para esticado.
	var dist := clampf(v.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
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

	var g_braco_ik := apontar(g_raiz, (g_raiz * rest_ante).origin, cotovelo)
	var g_ante_ik := g_braco_ik * rest_ante
	g_ante_ik = apontar(g_ante_ik, (g_ante_ik * rest_mao).origin, destino)

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


## A raiz do braco com ORIENTACAO de repouso e POSICAO da animacao.
##
## A posicao tem de ser a animada: e' onde o ombro esta' de verdade, e mexer nela
## descola o braco do corpo. A orientacao e' a de repouso porque o IK vai girar
## tudo de qualquer jeito, e partir da pose animada traria o giro da passada pra
## dentro da conta.
static func raiz_estavel(sk: Skeleton3D, i_braco: int) -> Transform3D:
	var i_ombro := sk.get_bone_parent(i_braco)
	var i_peito := sk.get_bone_parent(i_ombro) if i_ombro >= 0 else -1
	var base := sk.get_bone_global_pose(i_braco)
	if i_peito < 0 or i_ombro < 0:
		return base
	var estavel := sk.get_bone_global_pose(i_peito) * sk.get_bone_rest(i_ombro) \
		* sk.get_bone_rest(i_braco)
	return Transform3D(estavel.basis, base.origin)


## Gira `g` pelo arco que leva a direcao "origem -> ponta" ate' "origem -> alvo".
static func apontar(g: Transform3D, ponta: Vector3, alvo: Vector3) -> Transform3D:
	var atual := ponta - g.origin
	var desejado := alvo - g.origin
	if atual.length_squared() < 0.0001 or desejado.length_squared() < 0.0001:
		return g
	var giro := Quaternion(atual.normalized(), desejado.normalized())
	return Transform3D(Basis(giro) * g.basis, g.origin)


## Gira um ponto em volta da ancora, no eixo de pe', pro lado DIREITO dele.
##
## O `cross` com o Y e' o mesmo que da' o `direita` de quem chama, entao o sinal
## e' o mesmo dos dois lados: positivo = pra direita dele.
static func para_a_direita(ancora: Vector3, ponto: Vector3, graus: float) -> Vector3:
	if absf(graus) < 0.01:
		return ponto
	var fora := ponto - ancora
	var dist := fora.length()
	if dist < 0.001:
		return ponto
	var frente := fora / dist
	var lado := frente.cross(Vector3.UP)
	if lado.length_squared() < 0.0001:
		return ponto
	lado = lado.normalized()
	var a := deg_to_rad(graus)
	return ancora + (frente * cos(a) + lado * sin(a)) * dist


## Passa pro antebraco parte da torcao que a mao ganhou.
##
## A mao e' virada pra arma, mas o antebraco nao sabe disso: o IK so' APONTA ele
## pra mao, sem dizer nada sobre rolagem. Toda a diferenca entre os dois sobra no
## pulso — e a pele de la', presa aos dois ossos, colapsa num ponto.
##
## A conta e' "quanto a mao girou em volta do proprio antebraco, em relacao ao
## DESCANSO" — o descanso entra porque mao e antebraco nao nascem alinhados, e
## sem ele o osso rolaria sozinho com a arma na bainha.
static func dividir_torcao(sk: Skeleton3D, i_mao: int, mao_basis: Basis,
		fracao: float) -> void:
	if fracao <= 0.001:
		return
	var i_ante := sk.get_bone_parent(i_mao)
	if i_ante < 0:
		return
	var g_ante := sk.get_bone_global_pose(i_ante)
	var g_mao := sk.get_bone_global_pose(i_mao)
	var eixo := g_mao.origin - g_ante.origin
	if eixo.length_squared() < 0.0001:
		return
	eixo = eixo.normalized()

	var descanso := (g_ante.basis * sk.get_bone_rest(i_mao).basis) * Vector3.RIGHT
	var agora := mao_basis * Vector3.RIGHT
	descanso = descanso - eixo * descanso.dot(eixo)
	agora = agora - eixo * agora.dot(eixo)
	if descanso.length_squared() < 0.0001 or agora.length_squared() < 0.0001:
		return
	var torcao := descanso.normalized().signed_angle_to(agora.normalized(), eixo)
	sk.set_bone_global_pose(i_ante, Transform3D(
		Basis(eixo, torcao * fracao) * g_ante.basis, g_ante.origin))
