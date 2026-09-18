extends Node

## Confere as MAOS COM ARMA da primeira pessoa (o parasita), sem abrir o jogo.
##
##     Godot_v4.6.1 --headless --path red-valve \
##         res://tools/maos_fp/conferir_maos_armadas.tscn
##
## (tem de ser CENA e nao `-s script`: com `-s` o Godot nao carrega autoload
## nenhum, e quase tudo aqui pergunta ao SaveManager.)
##
## Irmao do `tools/shotgun/conferir_shotgun.gd`, e pelo mesmo motivo: nada do
## que esta' aqui QUEBRA quando da' errado. A arma sai da mao e fica boiando ao
## lado dela; o clipe some e a mao congela no descanso (que neste rig e' a mao
## atravessada na diagonal no meio da tela); a `mao_esq` fica visivel com a
## pistola e o jogador ve' uma mao fantasma agarrando o ar. Tudo isso passa
## calado pelo editor.
##
## A CHECAGEM QUE IMPORTA e' a do CABO NA MAO. As poses vem do Blender
## (`tools/blender/maos_fp/gerar_maos_fp.py`) e as constantes de enquadramento
## estao repetidas no `maos_fp_armas.gd`; se alguem mexer num lado so', a arma
## sai da mao e nada reclama. Aqui a distancia entre o cabo e o osso do dedo
## medio e' medida, e ela abre na hora.

const RIG := "res://assets/3d_model/player/hands/maos_fp/maos_fp.glb"
const CENA_MAO_ARMADA := "res://scenes/player/first_person_view/mao_armada.tscn"
const CENA_PLAYER := "res://scenes/player/player.tscn"

const CENAS := [
	"res://scenes/player/first_person_view/mao_armada.tscn",
	"res://scenes/player/first_person_view/mao_magica.tscn",
]

const SCRIPTS := [
	"res://scripts/player/maos_fp_armas.gd",
	"res://scripts/player/hand_with_pistol.gd",
	"res://scripts/player/hand_with_magic.gd",
	"res://scripts/player/player_combat.gd",
	"res://scripts/player/player.gd",
]

## Os clipes que a primeira pessoa estreou. Os dez antigos (idle, defesa,
## agarrado...) continuam existindo para as cutscenes e o agarrao.
const CLIPES := [
	"pistola_idle", "pistola_tiro", "pistola_guardar", "pistola_sacar",
	"shotgun_idle", "shotgun_tiro", "shotgun_recarga",
	"shotgun_guardar", "shotgun_sacar",
	"magic_holding_gun", "magic_holding_shoot", "magic_reload", "magic_thrown",
]

## Os caminhos que o resto do jogo procura POR NOME. Mexer em qualquer um
## destes quebra codigo que nao esta' nem perto daqui.
const CAMINHOS := [
	"Camera3D/hand_with_pistol",
	"Camera3D/hand_with_pistol/rig",
	"Camera3D/hand_with_pistol/faisca",
	"Camera3D/hand_with_pistol/fire",
	"Camera3D/hand_with_magic",
	"Camera3D/hand_with_magic/hand_magic",
	"Camera3D/hand_with_magic/hand_magic/AnimationPlayer",
	"Camera3D/hand_with_magic/hand_magic/AnimationTree",
]

## Onde o CABO da arma tem de cair em relacao ao osso do PULSO, em metros.
##
## E' um numero rigido e sabido: o gerador do Blender poe o punho a
## `RECUO_DO_PUNHO` (0,072) atras do ponto de pegada, ao longo dos dedos, e a
## `DESVIO_DA_PALMA` (0,036) pro lado dela — logo, hipotenusa 0,080.
##
## E' A CHECAGEM QUE IMPORTA neste arquivo. A distancia e' RIGIDA: a arma esta'
## pendurada num osso e o punho e' outro osso da mesma pose, entao ela tem de
## dar o mesmo numero em qualquer quadro de qualquer animacao. Se ela abrir, e'
## porque o Blender e o Godot se desencontraram — ou o enquadramento mudou de
## um lado so', ou alguem voltou a escalar osso e o glTF perdeu o
## cisalhamento de novo (foi assim que a mao chegou 1,8x maior no jogo).
## Onde moram os clipes que o editor deixa editar (ver `extrair_clipes.gd`).
const BIBLIOTECA := "maos_fp_clipes.tres"

const CABO_NO_PULSO := 0.080
const FOLGA_NA_MAO := 0.015

## Quanto tempo esperar pelo relogio, e nao por quadros.
##
## Em headless o jogo roda solto, muito mais rapido que 60 quadros por segundo.
## Contar quadros pra esperar uma recarga de 0,6 s media 0,1 s de relogio e a
## recarga nunca chegava ao fim.
func _esperar(segundos: float) -> void:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < ate:
		await get_tree().process_frame


var _falhas := 0
var _player: Node = null
var _rig: Node = null


func _ready() -> void:
	# O aviso de "item obtido" PAUSA a arvore, e este teste ganha item de
	# proposito. Com a arvore pausada o `_process` do rig para, o ajuste nao
	# e' aplicado e tudo o que se mede fica parado no lugar errado — e o teste
	# so' passava porque antes ele terminava antes de o aviso aparecer.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	var arvore := get_tree()

	_os_clipes_existem()
	_as_cenas_carregam()
	_os_caminhos_existem()
	# O do ajuste vem ANTES do jogo de verdade: o teste do jogo de verdade
	# acaba trocando de cena (morte/resgate na arena) e leva este no' junto,
	# e depois disso nao da' pra medir mais nada.
	await _o_ajuste_vai_pro_lado_certo()
	await _a_arma_fica_na_mao()

	print("")
	if _falhas == 0:
		print("== tudo certo ==")
	else:
		print("== %d PROBLEMA(S) ==" % _falhas)
	# A arvore guardada la' de cima: o ultimo teste roda o jogo de verdade, e
	# se ele trocar de cena este no' sai da arvore e `get_tree()` vira nulo.
	arvore.quit(1 if _falhas > 0 else 0)


## Mantem o jogo rodando (ver `_ready`).
func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false


func _ok(condicao: bool, texto: String) -> void:
	if not condicao:
		_falhas += 1
	print(("  ok   " if condicao else "  FALHA ") + texto)


func _os_clipes_existem() -> void:
	print("-- os clipes do rig --")
	var pacote: PackedScene = load(RIG)
	if pacote == null:
		_ok(false, "o maos_fp.glb nao carrega")
		return
	var cena: Node = pacote.instantiate()
	var animador: AnimationPlayer = cena.get_node_or_null("AnimationPlayer")
	if animador == null:
		_ok(false, "o maos_fp.glb tem AnimationPlayer")
		cena.queue_free()
		return
	for nome in CLIPES:
		_ok(animador.has_animation(nome), "clipe '%s'" % nome)
	if animador.has_animation("shotgun_recarga"):
		var dura: float = animador.get_animation("shotgun_recarga").length
		# 3,6 s e' o `TEMPO_RECARGA_SHOTGUN` do player_combat.gd. O clipe pode
		# tocar em outra velocidade, mas se o AUTORADO nao for esse numero e'
		# porque os dois arquivos se desencontraram.
		_ok(absf(dura - 3.6) < 0.05,
			"a recarga dura 3,6 s como o player_combat pede (%.2f)" % dura)
	cena.queue_free()


func _as_cenas_carregam() -> void:
	print("-- as cenas e os scripts --")
	for caminho in CENAS + SCRIPTS:
		_ok(load(caminho) != null, caminho)


func _os_caminhos_existem() -> void:
	print("-- os caminhos que o resto do jogo procura --")
	var pacote: PackedScene = load(CENA_PLAYER)
	if pacote == null:
		_ok(false, "o player.tscn nao carrega")
		return
	var cena: Node = pacote.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for caminho in CAMINHOS:
		_ok(cena.get_node_or_null(caminho) != null, caminho)
	cena.queue_free()


# ==========================================================================
# A ARMA NA MAO, DE VERDADE
#
# Aqui o jogador nasce parasita com a cacadeira equipada, e o que se mede e' o
# que o jogador veria: a arma no punho, o cano pra frente, as duas maos.
# ==========================================================================

func _a_arma_fica_na_mao() -> void:
	print("-- a arma na mao (parasita, cacadeira) --")
	GlobalEvents.is_maycow_normal = false
	SaveManager.add_item("shotgun", 1)
	SaveManager.add_item("shotgun_ammo", 4)
	SaveManager.add_item("pistol", 1)
	SaveManager.equip_item("shotgun")

	# Um chao. Sem ele o jogador CAI pra sempre, e depois de uns segundos de
	# queda o jogo reage (dano, reposicionamento) e esconde as maos — o teste
	# passava so' porque era rapido demais pra queda importar.
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(40.0, 1.0, 40.0)
	forma.shape = caixa
	chao.add_child(forma)
	chao.position = Vector3(0.0, -0.5, 0.0)
	add_child(chao)

	_player = load(CENA_PLAYER).instantiate()
	add_child(_player)
	for i in 8:
		await get_tree().process_frame
	_player.global_position = Vector3(0.0, 1.0, 0.0)

	_rig = _player.get_node_or_null("Camera3D/hand_with_pistol/rig")
	if _rig == null:
		_ok(false, "o rig de primeira pessoa existe")
		return

	_ok(_player._shotgun_hold() == _rig,
		"o player._shotgun_hold() cai no rig de primeira pessoa")

	# Os clipes tem de vir do .tres, e nao de dentro do .glb: e' o .tres que o
	# editor deixa abrir e mexer. Se alguem reimportar o .glb e a biblioteca
	# sair da cena, tudo continua funcionando — e a animacao volta a ser
	# intocavel sem ninguem perceber. Por isso a checagem.
	var clipe: Animation = _rig.get_node("AnimationPlayer") \
		.get_animation("shotgun_recarga")
	_ok(clipe != null and clipe.resource_path.contains(BIBLIOTECA),
		"a recarga vem da biblioteca editavel (%s)"
		% ("nada" if clipe == null else clipe.resource_path.get_file()))

	# A troca de arma tem um gesto (guarda e saca), entao ela nao acontece no
	# mesmo quadro em que o item e' equipado.
	await _esperar_arma("shotgun")
	_conferir_arma("shotgun", true)

	print("-- a troca de arma --")
	SaveManager.equip_item("pistol")
	await _esperar_arma("pistol")
	_conferir_arma("pistol", false)

	print("-- a recarga abre e fecha a dobra --")
	SaveManager.equip_item("shotgun")
	await _esperar_arma("shotgun")
	var charneira: Node3D = _rig.get_node_or_null(
		"Armature_dir/Skeleton3D/NaMao/shotgun").find_child("charneira", true, false)
	_ok(charneira != null, "a charneira existe dentro da arma na mao")
	if charneira == null:
		return
	_ok(absf(charneira.rotation.z) < 0.01, "fechada antes de recarregar")
	_rig.recarregar(0.8)
	var maior := 0.0
	var ate := Time.get_ticks_msec() + 1100
	while Time.get_ticks_msec() < ate:
		# O jogo de verdade pode trocar de cena no meio (morte, resgate da
		# arena) e levar este no' junto. Antes isso fazia os dois ultimos
		# testes sumirem sem dizer nada.
		if not is_inside_tree():
			print("  (o jogo trocou de cena; a dobra nao pode ser medida)")
			return
		await get_tree().process_frame
		maior = maxf(maior, absf(rad_to_deg(charneira.rotation.z)))
	_ok(maior > 25.0, "abriu no meio da recarga (%.0f graus)" % maior)
	_ok(absf(charneira.rotation.z) < 0.01, "fechou no fim")


# ==========================================================================
# O MODO DE AJUSTE (F9) APONTA PRO LADO QUE DIZ QUE APONTA
#
# O texto de ajuda promete "I leva pra frente, U sobe, L vai pra direita". Um
# sinal trocado em qualquer um deles nao quebra nada — so' faz quem esta'
# ajustando perder meia hora achando que enlouqueceu. Entao aqui o ajuste e'
# mexido de verdade e o resultado e' medido NA TELA, que e' onde a promessa
# foi feita.
# ==========================================================================

func _o_ajuste_vai_pro_lado_certo() -> void:
	print("-- o modo de ajuste --")

	# Um rig SOZINHO, com uma camera e mais nada.
	#
	# A primeira versao media isto no jogo de verdade, depois dos outros
	# testes, e nao dava: passados uns segundos o jogo pausa (o aviso de
	# "item obtido") e depois TROCA DE CENA (morte/resgate), levando o no' do
	# teste junto — `get_tree()` virava nulo e todas as medidas davam zero,
	# acusando o ajuste de nao funcionar. O que se quer conferir aqui e' uma
	# conta de transformacao; ela nao precisa de jogador, de arena nem de
	# inventario.
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var mao: Node3D = load(CENA_MAO_ARMADA).instantiate()
	camera.add_child(mao)
	await _quadros(3)

	var rig: Node = mao.get_node_or_null("rig")
	_ok(rig != null, "o rig sozinho carrega")
	if rig == null:
		return
	# A arma e' posta na mao na marra: o gesto de sacar leva um segundo e
	# depende do inventario, e nada disso interessa pra medir a conta.
	rig._na_mao = "shotgun"
	rig._mostrar_arma("shotgun")
	# E o clipe de PARADO a tocar. Sem ele o rig fica na pose de descanso, em
	# que a arma cai a 22 cm do olho em vez de 1,2 m — e um giro de 10 graus
	# quase nao move a boca do cano. O `seek(0, true)` atualiza o esqueleto na
	# hora, que e' o que deixa medir sem esperar quadro.
	var animador: AnimationPlayer = rig.get_node("AnimationPlayer")
	animador.play("shotgun_idle")
	animador.seek(0.0, true)

	var a: Dictionary = rig._ajuste["shotgun"]
	# O ajuste de verdade nao e' zero: cada teste soma em cima do que estiver
	# configurado e devolve depois, entao o teste continua valendo quando o
	# enquadramento mudar.
	var antes := a.duplicate(true)

	rig._aplicar_ajuste()
	var cabo0: Vector3 = camera.to_local(rig.ponto_do_cabo())
	var virado_antes: Basis = (rig as Node3D).global_transform.basis.orthonormalized()
	var esq0 := _punho_esquerdo(rig, camera)

	a["tela"] = (antes["tela"] as Vector3) + Vector3(10.0, 5.0, 4.0)
	rig._aplicar_ajuste()
	var d: Vector3 = camera.to_local(rig.ponto_do_cabo()) - cabo0
	# O +Z da camera aponta pra tras, entao "4 cm pra frente" e' -0,04 em z.
	_ok(absf(d.x - 0.10) < 0.01 and absf(d.y - 0.05) < 0.01
		and absf(d.z + 0.04) < 0.01,
		"o conjunto vai pra onde o texto diz (%.2f, %.2f, %.2f)"
		% [d.x, d.y, d.z])

	a["tela"] = antes["tela"]
	a["giro"] = (antes["giro"] as Vector3) + Vector3(10.0, 0.0, 0.0)
	rig._aplicar_ajuste()
	# Pela DIRECAO do cano, e nao pela posicao da boca: a posicao depende de
	# onde a pose do quadro poe a arma, e o que a tecla promete e' "levanta a
	# ponta". Dez graus de nariz pra cima sao 0,17 no seno.
	# Pela ROTACAO do conjunto, e nao por onde a boca do cano foi parar: aqui
	# o rig esta' sozinho, e na pose em que ele fica o cano aponta pro LADO —
	# inclinar pra cima nao levanta boca nenhuma. O que a tecla promete, e o
	# que este arquivo controla, e' inclinar o conjunto 10 graus em volta do
	# eixo X da camera; que isso levante a ponta e' geometria da pose, e quem
	# confere a pose e' o teste do jogo de verdade, logo abaixo.
	# Pelo ANGULO e pelo EIXO, e nao pelos tres numeros de Euler: o giro entra
	# por cima de um que ja' existe (-7, -18, -6) e os dois nao comutam, entao
	# Euler espalha os mesmos 10 graus entre x e z. O que se quer saber e' se
	# o conjunto virou 10 graus em volta do eixo X DA CAMERA — e' isso que a
	# tecla promete.
	var virado: Basis = (rig as Node3D).global_transform.basis.orthonormalized()
	var giro_feito := Quaternion(virado * virado_antes.inverse()).normalized()
	var angulo := rad_to_deg(2.0 * acos(clampf(absf(giro_feito.w), 0.0, 1.0)))
	var eixo := Vector3(giro_feito.x, giro_feito.y, giro_feito.z).normalized()
	if giro_feito.w < 0.0:
		eixo = -eixo
	_ok(absf(angulo - 10.0) < 1.0 and eixo.x > 0.9,
		"o R inclina o conjunto 10 graus em volta do eixo da camera "
		+ "(%.1f graus, eixo %.2f)" % [angulo, eixo.x])

	a["giro"] = antes["giro"]
	a["arma"] = (antes["arma"] as Vector3) + Vector3(0.0, 0.0, 5.0)
	rig._aplicar_ajuste()
	var dc: Vector3 = camera.to_local(rig.ponto_do_cabo()) - cabo0
	# Centimetro de ajuste e' centimetro NA TELA, nos tres alvos: o
	# deslocamento e' somado em MUNDO, depois da escala do rig. Um `tamanho`
	# de 206% nao faz o ajuste da arma andar o dobro.
	_ok(absf(dc.z + 0.05) < 0.012,
		"a arma sozinha anda 5 cm pra frente (%.2f m)" % -dc.z)
	_ok(_punho_esquerdo(rig, camera).distance_to(esq0) < 0.01,
		"e a mao esquerda NAO vai junto")

	a["arma"] = antes["arma"]
	a["mao_e"] = (antes["mao_e"] as Vector3) + Vector3(0.0, 0.0, 6.0)
	rig._aplicar_ajuste()
	var de := _punho_esquerdo(rig, camera).distance_to(esq0)
	_ok(absf(de - 0.06) < 0.012, "a mao esquerda sozinha anda 6 cm (%.2f m)" % de)
	_ok(camera.to_local(rig.ponto_do_cabo()).distance_to(cabo0) < 0.01,
		"e a arma NAO vai junto")

	for chave in antes:
		a[chave] = antes[chave]
	rig._aplicar_ajuste()
	_ok(camera.to_local(rig.ponto_do_cabo()).distance_to(cabo0) < 0.005,
		"desfeito o ajuste, tudo volta pro lugar")
	camera.queue_free()


## O punho esquerdo NO ESPACO DA CAMERA — o que o ajuste da mao esquerda tem
## de mover.
##
## Na camera e nao em mundo: neste teste nao ha' chao, o jogador cai o tempo
## todo, e medir em mundo dava metros de "deslocamento" que eram so' a queda.
func _punho_esquerdo(rig: Node, camera: Camera3D) -> Vector3:
	var sk: Skeleton3D = rig.get_node_or_null("Armature/Skeleton3D")
	if sk == null:
		return Vector3.ZERO
	return camera.to_local(sk.global_transform
		* sk.get_bone_global_pose(sk.find_bone("mao")).origin)


func _quadros(quantos: int) -> void:
	for i in quantos:
		await get_tree().process_frame


## Espera a arma chegar E o gesto de sacar acabar.
##
## A primeira versao esperava so' a arma chegar, e media no meio do gesto —
## com a mao la' embaixo, fora de quadro. Os numeros saiam todos errados e o
## erro parecia ser da pose.
func _esperar_arma(qual: String) -> void:
	# Ate' a arma chegar, o gesto acabar E o clipe de parado assumir. Medir no
	# ultimo quadro do `_sacar` nao serve: la' a interpolacao do Godot ainda
	# esta' entre duas chaves e o punho nao caiu no lugar definitivo.
	var parado := ("pistola" if qual == "pistol" else "shotgun") + "_idle"
	var animador: AnimationPlayer = _rig.get_node("AnimationPlayer")
	for i in 600:
		if _rig.arma_na_mao() == qual and not _rig.em_troca() \
				and animador.current_animation == parado:
			await _assentar()
			return
		await get_tree().process_frame


## Espera a arma PARAR DE SE MEXER.
##
## Nao basta o clipe de parado comecar: o `AJUSTE` e' aplicado no `_process`
## do rig, a pose global do esqueleto so' sai no passo diferido seguinte, e o
## balanco da mao ainda esta' voltando ao centro. Medido, o idle assentado
## varia 4 cm; no primeiro quadro a boca do cano chegou a aparecer um metro
## fora do lugar, e o teste reprovava um dia sim outro nao.
##
## Entao aqui se espera a medida ficar PARADA — que e' a condicao que
## interessa de verdade — em vez de contar quadros no escuro.
func _assentar() -> void:
	var antes: Vector3 = _rig.boca_do_cano()
	var quietos := 0
	var ate := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < ate:
		await get_tree().process_frame
		var agora: Vector3 = _rig.boca_do_cano()
		quietos = quietos + 1 if agora.distance_to(antes) < 0.002 else 0
		antes = agora
		if quietos >= 10:
			return


## Mede o que o jogador veria: a arma esta' no punho? o cano aponta pra
## frente? as maos certas estao na tela?
func _conferir_arma(qual: String, duas_maos: bool) -> void:
	_ok(_rig.arma_na_mao() == qual, "'%s' chegou na mao" % qual)
	_ok(_rig.tem_arma_na_mao(), "'%s' esta' visivel" % qual)

	var esqueleto: Skeleton3D = _rig.get_node_or_null("Armature_dir/Skeleton3D")
	var pulso: Vector3 = (esqueleto.global_transform
		* esqueleto.get_bone_global_pose(esqueleto.find_bone("mao"))).origin
	var cabo: Vector3 = _rig.ponto_do_cabo()
	var longe := pulso.distance_to(cabo)
	# O enquadramento (o `AJUSTE` do componente) pode ter tirado a arma da
	# palma DE PROPOSITO, e pode ter mudado o tamanho do conjunto — as duas
	# coisas entram na conta, senao um ajuste de meio centimetro reprovaria
	# aqui. O que a checagem continua pegando e' a arma que SAI da mao sozinha.
	var ajuste: Dictionary = _rig.AJUSTE.get(qual, {})
	var esperado: float = CABO_NO_PULSO \
		* float(ajuste.get("tamanho", 100.0)) / 100.0
	var mexido: float = (ajuste.get("arma", Vector3.ZERO) as Vector3).length() / 100.0
	_ok(absf(longe - esperado) < FOLGA_NA_MAO + mexido,
		"o cabo cai na palma (%.3f m, esperado %.3f +- %.3f)"
		% [longe, esperado, FOLGA_NA_MAO + mexido])

	var camera: Camera3D = _player.get_node_or_null("Camera3D")
	var boca: Vector3 = camera.to_local(_rig.boca_do_cano())
	# No espaco da camera o -Z entra na tela. Uma boca de cano atras do olho ou
	# a dois metros dele e' erro de escala ou de eixo, nao de gosto.
	_ok(boca.z < -0.15 and boca.z > -1.5,
		"a boca do cano esta' na frente do olho (z = %.2f)" % boca.z)
	_ok(absf(boca.x) < 0.6 and absf(boca.y) < 0.6,
		"a boca do cano esta' dentro do quadro (x %.2f, y %.2f)" % [boca.x, boca.y])

	var frente: Vector3 = camera.to_local(_rig.boca_do_cano()
		+ _rig.direcao_do_cano()) - boca
	_ok(frente.z < -0.3, "o cano aponta pra frente (z = %.2f)" % frente.z)

	var malha_esq: MeshInstance3D = _rig.get_node_or_null(
		"Armature/Skeleton3D/mao_esq")
	_ok(malha_esq.visible == duas_maos,
		"a mao esquerda do rig armado %s" % ("aparece" if duas_maos else "some"))

	if qual == "shotgun":
		_ok(_rig.bocas_das_camaras().size() == 2, "as duas camaras existem")
