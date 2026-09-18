extends Node3D

## A ARMA NAS MAOS DO PARASITA — PRIMEIRA PESSOA.
##
## Primo do `player_shotgun_hold.gd`, e o contrario dele em tudo o que importa.
##
## No Maycow normal nao existe clipe de mao: o rig tem 24 ossos, NENHUM dedo, e
## nao ha' .blend fonte — a pose e' recalculada todo quadro por um
## SkeletonModifier3D com IK. Aqui o rig e' o das cutscenes (17 ossos, cinco
## dedos com falange, `maos_fp.glb`) e as poses ja' vem PRONTAS do Blender.
## Entao aqui nao ha' IK, nao ha' pose por quadro: ha' um AnimationPlayer
## tocando clipe e uma arma pendurada num osso.
##
## ============================================================================
## 1. A ARMA E' FILHA DE UM OSSO SO' DELA — E NAO DO OSSO DA MAO
##
## Parece natural pendurar a arma no osso `mao`. NAO FUNCIONA, e o motivo vale
## saber porque nao aparece em lugar nenhum ate' ser medido.
##
## O antebraco deste rig e' um toco de 15 cm, esticado por ESCALA DE OSSO pra
## o cotovelo sair de quadro. Escala nao-uniforme num pai cisalha todos os
## filhos, e o glTF nao sabe guardar cisalhamento: o exportador decompoe a
## matriz em posicao/rotacao/escala e joga o cisalhamento fora. Medido no
## Godot, a pose global do `mao` chegava com escala (1,30 / 1,93 / 1,37) em
## vez de (1/1/1) — e com numeros DIFERENTES a cada pose. Uma arma presa ali
## escorrega da mao conforme o punho gira: no meio da troca de arma o cabo
## chegou a ficar a 21 cm do punho.
##
## Entao o gerador do Blender poe no rig um osso SOLTO chamado `arma`, sem
## pai e sem escala, cuja pose E' o quadro da arma em cada chave (ver
## `criar_osso_da_arma` la'). Um osso de raiz nao tem de quem herdar escala:
## ele chega no Godot rigido, e um BoneAttachment3D nele basta.
##
## Sobra pra ca' uma unica conta, e ela e' exata: levar o modelo das unidades
## dele pras do rig. O osso esta' em unidades do rig (1 m = 1/0,17) e o modelo
## da arma tem a propria escala, entao a transformacao local da arma dentro do
## osso e' escala pura, `ESCALA[arma] / <escala do no do rig>`.
##
## Quem confere que isso continua de pe' e'
## `tools/maos_fp/conferir_maos_armadas.tscn`: ele mede a distancia entre o
## cabo da arma e o punho fechado, e reclama se abrir.
##
## ============================================================================
## 2. AS DUAS MAOS SAO DUAS COPIAS DO MESMO RIG
##
## Esta e' a copia ARMADA. A outra e' `hand_with_magic`, a mao esquerda
## sozinha: ela soca, recarrega a pistola e faz a magia, e meio jogo mexe nela
## POR NOME (`hand_magic_3d`, `hand_magic_tree`). Por isso ela continua
## existindo em separado em vez de virar "a mao esquerda desta aqui".
##
##     com a PISTOLA    a esquerda que aparece e' a outra copia;
##                      a `mao_esq` desta fica escondida.
##     com a CACADEIRA  as duas maos tem de estar na MESMA arma, no mesmo
##                      esqueleto (senao nao ha' como garantir que a esquerda
##                      caia no fore-end); a outra copia se esconde.
##
## ============================================================================
## 3. A DOBRA DA ARMA NAO VEM DO .glb
##
## A cacadeira e' duas pecas (ver `player_shotgun_hold.gd`, item 4) e quem abre
## a dobra e' este script. Os `M_*` daqui sao copia dos de la' e dos
## `MOMENTO_*` do `player_combat.gd` — o gesto e' o mesmo, os sons sao os
## mesmos, e a animacao da mao foi autorada nessa mesma linha do tempo. Mexeu
## num, mexe nos tres.
##
## ============================================================================
## 4. A API E' A DO IRMAO DE TERCEIRA PESSOA
##
## `tem_arma_na_mao`, `boca_do_cano`, `direcao_do_cano`, `bocas_das_camaras`,
## `recarregar` e `mirar` tem aqui a MESMA assinatura que no
## `player_shotgun_hold.gd`. Nao e' coincidencia: e' o que deixa
## `player_combat.gd` disparar, soltar capsula, acender clarao e contar bala
## sem saber de que pessoa e' a camera. Quem escolhe entre os dois e'
## `player._shotgun_hold()`.
##
## ============================================================================
## 5. O ENQUADRAMENTO SE ACERTA EM JOGO, E FICA AQUI
##
## Onde a arma cai NA TELA e' decisao de olho, e olho nao se resolve por conta.
## Entao ha' o `AJUSTE`: um punhado de numeros por arma que desloca o conjunto,
## a arma dentro da mao e a mao esquerda, e um modo de ajuste (F9) que mexe
## nesses mesmos numeros com o jogo rodando e imprime o bloco pronto pra colar.
##
## A POSE continua vindo do Blender; isto aqui e' so' o enquadramento. E' de
## proposito: mexer na pose custa quatro minutos de gerador mais o reimport, e
## mexer no enquadramento tem de custar um toque de tecla.

# ==============================================================================
# o rig
# ==============================================================================
## O osso SOLTO que carrega a arma. Nasce no gerador do Blender; ver o item 1
## do cabecalho pra saber por que nao e' o osso `mao`.
const OSSO_ARMA := "arma"
const NO_ESQ := "Armature/Skeleton3D"
const NO_DIR := "Armature_dir/Skeleton3D"
const MALHA_ESQ := "Armature/Skeleton3D/mao_esq"
const MALHA_DIR := "Armature_dir/Skeleton3D/mao_dir"

const ITEM_PISTOLA := "pistol"
const ITEM_SHOTGUN := "shotgun"

const MODELOS := {
	ITEM_PISTOLA: "res://assets/3d_model/player/the_negotiator_V1/the_negotiator_v1.glb",
	ITEM_SHOTGUN: "res://assets/3d_model/player/the_negotiator_V3/the_negotiator_V3_dobravel.glb",
}
## Nome do vazio que carrega os canos dentro do .glb da cacadeira.
const NO_CHARNEIRA := "charneira"

# ==============================================================================
# A GEOMETRIA DAS ARMAS — unidades do MODELO, cano no -X e topo no +Y
#
# Os mesmos pontos de `player_shotgun_hold.gd` (a cacadeira) e do gerador do
# Blender. No Blender o modelo chega com o topo no +Z e o lado no +-Y; aqui e'
# Y pra cima, entao os dois ultimos numeros aparecem trocados.
# ==============================================================================
const ESCALA := {ITEM_PISTOLA: 0.145, ITEM_SHOTGUN: 0.300}
## Onde o punho fecha.
const CABO_MODELO := {
	ITEM_PISTOLA: Vector3(0.60, -0.28, 0.0),
	ITEM_SHOTGUN: Vector3(0.50, -0.03, 0.0),
}
## O furo do cano. Na pistola ele fica ALTO no modelo, e nao na linha do cabo.
const BOCA_MODELO := {
	ITEM_PISTOLA: Vector3(-0.95, 0.50, 0.0),
	ITEM_SHOTGUN: Vector3(-0.93, -0.01, 0.0),
}
## Onde a dobra gira, e onde ficam as duas camaras.
const CHARNEIRA_MODELO := Vector3(-0.030, 0.057, 0.0)
const CULATRA_MODELO := Vector3(-0.030, 0.127, 0.0)
const CAMARA_LADO := 0.060
## Quanto a arma abre. O mesmo `ABERTURA` da terceira pessoa.
const ABERTURA := 32.0

## A TROCA DE EIXOS ENTRE O OSSO E O MODELO.
##
## O osso `arma` foi escrito no Blender, onde o modelo da arma tem o topo no
## +Z e o lado no +-Y. O MESMO .glb, importado pelo Godot, chega com o topo no
## +Y e o lado no +-Z — e' a conversao Y-up do gltf, e ela vale pra malha da
## arma mas nao pros eixos que o osso carrega.
##
## Sem esta troca a arma fica girada 90 graus em volta do PROPRIO CANO. Na
## cacadeira quase nao se ve' (o cabo dela esta' praticamente no eixo do cano,
## entao girar em volta dele quase nao move o cabo); na pistola, cujo cabo
## desce 0,28 no modelo, o punho ficava 2 cm fora da mao. Foi assim que
## apareceu: a mesma checagem passava numa arma e falhava na outra.
const EIXOS_DO_MODELO := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))

# ==============================================================================
# A RECARGA — a mesma linha do tempo dos outros dois arquivos
# ==============================================================================
const M_ABRE_INICIO := 0.08
const M_ABRE_FIM := 0.20
const M_FECHA_INICIO := 0.90
const M_FECHA_FIM := 0.97
## Quanto dura o clipe autorado, em segundos. Se `recarregar()` pedir outro
## tempo, a velocidade do clipe se ajusta pra caber.
const DURACAO_RECARGA := 3.6

## Os sufixos dos clipes. O prefixo e' a arma (ver `_nome_do_clipe`).
const CLIPE_GUARDAR := "_guardar"
const CLIPE_SACAR := "_sacar"
const CLIPE_IDLE := "_idle"
const CLIPE_TIRO := "_tiro"
const CLIPE_RECARGA := "_recarga"

## Quais clipes tocam em laco. O resto para no ultimo quadro.
const EM_LACO := ["idle", "pistola_idle", "shotgun_idle", "defesa", "agarrado",
	"queda", "magic_holding_gun"]

# ==============================================================================
# O ENQUADRAMENTO — os numeros que o modo de ajuste (F9) escreve
#
# Tudo em CENTIMETROS e GRAUS, no espaco da TELA:
#
#     tela / arma / mao_e        x = pra direita, y = pra cima, z = pra frente
#     giro / arma_giro / ...     x = levanta a ponta, y = gira pra esquerda,
#                                z = inclina o lado direito pra cima
#
#     "tela"       o conjunto inteiro (as duas maos + a arma) diante do olho
#     "arma"       so' a arma, girando em volta do proprio cabo; as maos ficam
#     "mao_e"      so' a mao esquerda, girando em volta do proprio punho
#     "tamanho"    por cento do conjunto (100 = o tamanho desenhado)
#
# Nao ha' nada de sagrado nestes numeros: sao o resultado do F9.
# ==============================================================================
const AJUSTE := {
	ITEM_PISTOLA: {
		"tela": Vector3(0.0, 0.0, 0.0),
		"giro": Vector3(0.0, 0.0, 0.0),
		"arma": Vector3(0.0, 0.0, 0.0),
		"arma_giro": Vector3(0.0, 0.0, 0.0),
		"mao_e": Vector3(0.0, 0.0, 0.0),
		"mao_e_giro": Vector3(0.0, 0.0, 0.0),
		"tamanho": 100.0,
	},
	ITEM_SHOTGUN: {
		"tela": Vector3(1.6, -10.0, -2.0),
		"giro": Vector3(-8.0, -18.0, -6.0),
		"arma": Vector3(5.4, -12.2, -0.2),
		"arma_giro": Vector3(8.0, -2.0, 0.0),
		"mao_e": Vector3(3.0, -2.6, 25.6),
		"mao_e_giro": Vector3(-308.0, 250.0, 8.0),
		"tamanho": 206.0,
	},
}

var _animador: AnimationPlayer
var _esq: Skeleton3D
var _dir: Skeleton3D
var _malha_esq: MeshInstance3D
var _malha_dir: MeshInstance3D
var _suporte: BoneAttachment3D

## Uma instancia por arma, criada no `_ready` e escondida. Trocar de arma e'
## trocar qual esta' visivel — instanciar na hora custaria um engasgo bem no
## quadro em que a arma tem de aparecer.
var _armas := {}
var _charneira: Node3D = null

## Qual arma esta' NA MAO agora (nao a equipada: durante a troca as duas
## coisas sao diferentes, e e' essa diferenca que faz o gesto existir).
var _na_mao := ""
var _trocando := false

## So' depois do `_ready` terminar de montar as armas. Ate' la' o `_process`
## fica quieto: ele mostra e esconde arma, e faria isso antes de haver arma.
var _pronto := false

var _recarregando := false
var _recarga_inicio := 0.0
var _recarga_dura := DURACAO_RECARGA

## Os `AJUSTE` copiados pra memoria: const e' so' leitura, e o F9 escreve.
var _ajuste := {}
## As transformacoes que a CENA deu a cada no', guardadas antes de o ajuste
## mexer nelas: o `_aplicar_ajuste` parte sempre destas, senao o deslocamento
## se somaria a si mesmo todo quadro.
var _base_rig := Transform3D.IDENTITY
var _base_esq := Transform3D.IDENTITY
var _base_arma := {}
## O `Armature` esquerdo (o pai do esqueleto), que e' quem se desloca quando o
## ajuste mexe so' na mao esquerda.
var _no_esq: Node3D
var _i_mao_esq := -1
## A OUTRA copia do rig (`hand_with_magic`), que nao e' desta cena.
var _mao_magica: Node3D


func _ready() -> void:
	_animador = get_node_or_null("AnimationPlayer")
	_esq = get_node_or_null(NO_ESQ)
	_dir = get_node_or_null(NO_DIR)
	_malha_esq = get_node_or_null(MALHA_ESQ)
	_malha_dir = get_node_or_null(MALHA_DIR)
	if _animador == null or _dir == null:
		push_error("maos_fp_armas: rig incompleto em %s" % get_path())
		set_process(false)
		return

	for nome in _animador.get_animation_list():
		var anim: Animation = _animador.get_animation(nome)
		anim.loop_mode = Animation.LOOP_LINEAR if nome in EM_LACO \
			else Animation.LOOP_NONE

	_suporte = BoneAttachment3D.new()
	_suporte.name = "NaMao"
	_dir.add_child(_suporte)
	_suporte.bone_name = OSSO_ARMA
	_suporte.bone_idx = _dir.find_bone(OSSO_ARMA)
	if _suporte.bone_idx < 0:
		push_error("maos_fp_armas: o rig veio sem o osso '%s' — refaca o .glb"
			% OSSO_ARMA)

	for item in MODELOS:
		var pacote = load(MODELOS[item])
		if pacote == null:
			push_warning("maos_fp_armas: nao achei %s" % MODELOS[item])
			continue
		var no: Node3D = pacote.instantiate()
		no.name = item
		no.visible = false
		# As duas unicas contas deste arquivo: trazer o modelo das unidades
		# dele pras do rig, e casar os eixos (ver EIXOS_DO_MODELO). O resto —
		# onde a arma esta' e pra onde ela aponta — ja' vem no osso.
		no.transform = Transform3D(
			EIXOS_DO_MODELO.scaled(Vector3.ONE * ESCALA[item] / _escala_do_rig()),
			Vector3.ZERO)
		_suporte.add_child(no)
		_armas[item] = no
	# `find_child` e nao caminho fixo: o importador do Godot embrulha o .glb
	# num no' a mais (`the_negotiator_V3_dobravel2` por cima do
	# `the_negotiator_V3_dobravel`), e esse embrulho e' coisa do importador,
	# nao do gerador do Blender — nao da' pra confiar nele.
	var cacadeira: Node = _armas.get(ITEM_SHOTGUN)
	if cacadeira != null:
		_charneira = cacadeira.find_child(NO_CHARNEIRA, true, false)
		if _charneira == null:
			push_warning("maos_fp_armas: a cacadeira veio sem o no' '%s'"
				% NO_CHARNEIRA)

	_no_esq = get_node_or_null("Armature")
	var camera := get_parent().get_parent() if get_parent() != null else null
	if camera != null:
		_mao_magica = camera.get_node_or_null("hand_with_magic")
	if _esq != null:
		_i_mao_esq = _esq.find_bone("mao")
	_base_rig = transform
	if _no_esq != null:
		_base_esq = _no_esq.transform
	for item in _armas:
		_base_arma[item] = _armas[item].transform
	for item in AJUSTE:
		_ajuste[item] = AJUSTE[item].duplicate(true)

	# A copia da arma que existe so' pra dar o que ver no editor (sem ela o
	# AnimationPlayer mostra as maos apertando o ar). Em jogo ela sobra: quem
	# poe arma na mao e' o laco ali de cima.
	var previa := get_node_or_null("Armature_dir/Skeleton3D/PreviaNoEditor")
	if previa != null:
		previa.queue_free()

	# E a camera irma', que existe pelo mesmo motivo: no editor ela mostra o
	# enquadramento do jogo. Em jogo ela roubaria a cena do jogador.
	var olho_previa := get_parent().get_node_or_null("PreviaDaTela")
	if olho_previa != null:
		olho_previa.queue_free()

	_mostrar_arma("")
	_pronto = true


## A escala do no' que segura o rig (0,17 na cena). As poses foram escritas em
## METROS e o rig vive em unidades de 1/0,17 — e' essa a conversao.
func _escala_do_rig() -> float:
	var e := scale.x
	return e if absf(e) > 0.0001 else 1.0


## `pistol` + `_idle` -> `pistola_idle`. O item do inventario chama `pistol` e
## o clipe chama `pistola` — o inventario e' ingles e o rig e' portugues, e
## nenhum dos dois vai mudar de nome por causa do outro.
func _nome_do_clipe(item: String, sufixo: String) -> String:
	var raiz := "pistola" if item == ITEM_PISTOLA else "shotgun"
	return raiz + sufixo


# ==============================================================================
# quem esta' na mao
# ==============================================================================

func _process(_delta: float) -> void:
	if _animador == null or not _pronto:
		return
	var quer := _arma_equipada()
	if quer != _na_mao and not _trocando:
		_trocar_para(quer)
	if not _trocando:
		_manter_clipe()
	_mover_a_dobra()
	_aplicar_ajuste()
	_esconder_a_mao_magica()


func _arma_equipada() -> String:
	if SaveManager.is_equipped(ITEM_SHOTGUN):
		return ITEM_SHOTGUN
	if SaveManager.is_equipped(ITEM_PISTOLA):
		return ITEM_PISTOLA
	return ""


## Esconde tudo e mostra so' o que esta' na mao.
##
## A `mao_esq` daqui so' aparece com a cacadeira: com a pistola quem faz o
## papel da esquerda e' a outra copia do rig (item 2 do cabecalho).
func _mostrar_arma(item: String) -> void:
	for chave in _armas:
		_armas[chave].visible = (chave == item)
	if _malha_dir:
		_malha_dir.visible = item != ""
	if _malha_esq:
		_malha_esq.visible = item == ITEM_SHOTGUN


## A TROCA DE ARMA.
##
## Baixa a que esta' na mao ate' sair de quadro, troca o modelo la' embaixo —
## onde ninguem ve' — e sobe a nova. E' so' isso, e e' por isso que funciona:
## o clipe `_guardar` termina com a arma fora do quadro, entao o instante da
## troca e' um quadro qualquer de tela vazia.
func _trocar_para(nova: String) -> void:
	_trocando = true
	_recarregando = false
	if _na_mao != "" and _tem(_na_mao, CLIPE_GUARDAR):
		_animador.play(_nome_do_clipe(_na_mao, CLIPE_GUARDAR))
		await _fim_do_clipe()
	_na_mao = nova
	_mostrar_arma(nova)
	if nova != "" and _tem(nova, CLIPE_SACAR):
		_animador.play(_nome_do_clipe(nova, CLIPE_SACAR))
		await _fim_do_clipe()
	_trocando = false


func _tem(item: String, sufixo: String) -> bool:
	return _animador.has_animation(_nome_do_clipe(item, sufixo))


func _fim_do_clipe() -> void:
	# `animation_finished` nao dispara se alguem trocar o clipe no meio; o
	# timer garante que a troca nunca fica pendurada.
	var quanto := _animador.current_animation_length
	await get_tree().create_timer(maxf(quanto, 0.05)).timeout


## Mantem o clipe certo tocando. Clipe de uma vez so' (tiro, recarga) tem
## prioridade enquanto nao acaba; fora isso, o `idle` da arma.
func _manter_clipe() -> void:
	if _na_mao == "":
		if _animador.is_playing():
			_animador.stop()
		return
	var idle := _nome_do_clipe(_na_mao, CLIPE_IDLE)
	if _animador.is_playing() and _animador.current_animation != idle:
		return
	if _animador.current_animation != idle:
		_animador.play(idle)


## Com a CACADEIRA as duas maos sao desta copia, e a copia magica nao tem o que
## fazer — ela estava sobrando no canto esquerdo da tela.
##
## Isto mora aqui, e todo quadro, porque quem LIGA a mao magica sao varios
## lugares do `player.gd` (saida de cutscene, amuleto, ultimate) e nenhum deles
## sabe que existe uma cacadeira. Este e' o unico lugar que sabe.
func _esconder_a_mao_magica() -> void:
	if _mao_magica == null or _na_mao != ITEM_SHOTGUN:
		return
	if _mao_magica.visible:
		_mao_magica.visible = false


# ==============================================================================
# a dobra
# ==============================================================================

## Abre e fecha a cacadeira ao longo da recarga. A mesma conta esta' no
## gerador do Blender (`abertura_da_recarga`), que e' onde a previa a usa.
func _mover_a_dobra() -> void:
	if _charneira == null:
		return
	_charneira.rotation.z = deg_to_rad(_abertura_agora())


func _abertura_agora() -> float:
	if not _recarregando or _na_mao != ITEM_SHOTGUN:
		return 0.0
	var r := (_agora() - _recarga_inicio) / maxf(_recarga_dura, 0.01)
	if r <= M_ABRE_INICIO or r >= M_FECHA_FIM:
		if r >= 1.0:
			_recarregando = false
		return 0.0
	if r < M_ABRE_FIM:
		return ABERTURA * smoothstep(M_ABRE_INICIO, M_ABRE_FIM, r)
	if r <= M_FECHA_INICIO:
		return ABERTURA
	return ABERTURA * (1.0 - smoothstep(M_FECHA_INICIO, M_FECHA_FIM, r))


func _agora() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


# ==============================================================================
# A API QUE O player_combat.gd USA — a mesma do player_shotgun_hold.gd
# ==============================================================================

func tem_arma_na_mao() -> bool:
	return _na_mao != "" and _armas.has(_na_mao) and _armas[_na_mao].visible


## O tiro: coice na arma e na mao.
func atirar() -> void:
	if _na_mao == "" or _trocando:
		return
	if _tem(_na_mao, CLIPE_TIRO):
		_animador.play(_nome_do_clipe(_na_mao, CLIPE_TIRO))


func recarregar(tempo: float) -> void:
	if _na_mao != ITEM_SHOTGUN or _trocando:
		return
	var clipe := _nome_do_clipe(ITEM_SHOTGUN, CLIPE_RECARGA)
	if not _animador.has_animation(clipe):
		return
	_recarregando = true
	_recarga_inicio = _agora()
	_recarga_dura = maxf(tempo, 0.2)
	_animador.play(clipe, -1.0, DURACAO_RECARGA / _recarga_dura)


## Em primeira pessoa nao ha' pose de mira: a camera JA' e' a mira. Existe
## porque o irmao de terceira pessoa tem, e `player.gd` chama nos dois sem
## perguntar.
func mirar(_quer: bool, _alvo: Vector3 = Vector3.ZERO) -> void:
	pass


## A boca do cano, em coordenadas de mundo.
##
## Sai da CHARNEIRA e nao da raiz da arma: com a cacadeira aberta, a boca ja'
## girou em volta do pino, e ler da raiz devolveria o lugar onde ela estaria
## se a arma estivesse fechada.
func boca_do_cano() -> Vector3:
	if not tem_arma_na_mao():
		return global_position
	return _ponto_da_arma(BOCA_MODELO[_na_mao])


## Onde o punho fecha na arma, em coordenadas de mundo.
##
## Nao e' usado pelo jogo: e' o que `conferir_maos_armadas` mede contra o osso
## do dedo medio pra saber se a arma continua DENTRO da mao. E' a checagem que
## pega a desconexao entre as constantes daqui e as do gerador do Blender.
func ponto_do_cabo() -> Vector3:
	if not tem_arma_na_mao():
		return global_position
	return _ponto_da_arma(CABO_MODELO[_na_mao])


## Qual arma esta' na mao agora ("" se nenhuma).
func arma_na_mao() -> String:
	return _na_mao


## Esta' no meio do gesto de guardar/sacar? Durante ele a mao esta' fora de
## quadro e nao adianta medir nada.
func em_troca() -> bool:
	return _trocando


func direcao_do_cano() -> Vector3:
	if not tem_arma_na_mao():
		return -global_transform.basis.z
	if _na_mao != ITEM_SHOTGUN:
		return (_ponto_da_arma(BOCA_MODELO[_na_mao])
			- _ponto_da_arma(CABO_MODELO[_na_mao])).normalized()
	return (_ponto_da_arma(BOCA_MODELO[_na_mao])
		- _ponto_da_arma(CULATRA_MODELO)).normalized()


## As duas bocas de camara, de onde as capsulas caem.
func bocas_das_camaras() -> Array:
	if _na_mao != ITEM_SHOTGUN or not tem_arma_na_mao():
		return []
	return [
		_ponto_da_arma(CULATRA_MODELO + Vector3(0.0, 0.0, CAMARA_LADO)),
		_ponto_da_arma(CULATRA_MODELO - Vector3(0.0, 0.0, CAMARA_LADO)),
	]


## Ponto do MODELO -> ponto do mundo, ja' girado pela dobra quando for o caso.
func _ponto_da_arma(p: Vector3) -> Vector3:
	var no: Node3D = _armas.get(_na_mao)
	if no == null:
		return global_position
	# Tudo o que esta' na frente do corte se move quando ela abre; o que esta'
	# atras nao. O unico ponto atras do corte que interessa aqui e' o cabo.
	if _charneira != null and _na_mao == ITEM_SHOTGUN and p.x <= CHARNEIRA_MODELO.x:
		return _charneira.global_transform * (p - CHARNEIRA_MODELO)
	return no.global_transform * p


# ==============================================================================
# MODO DE AJUSTE — acertar o ENQUADRAMENTO com o jogo rodando
# ==============================================================================
## As MESMAS teclas do modo de ajuste da terceira pessoa
## (`player_shotgun_hold.gd`), de proposito: e' a mesma tarefa, e a mao ja'
## sabe onde fica. O que muda e' o que esta' sendo acertado — la' e' a pose do
## braco, aqui e' onde a coisa cai na tela.
##
##     G       troca entre CONJUNTO, ARMA e MAO ESQUERDA
##
##     I / K   pra frente / pra tras
##     U / O   sobe / desce
##     J / L   pra esquerda / pra direita
##     R / F   levanta / abaixa a ponta
##     V / B   gira pra esquerda / pra direita
##     N / M   inclina pra esquerda / pra direita
##     T / Y   (so' no CONJUNTO) encolhe / aumenta tudo
##
##     P       imprime o bloco pronto pra colar no `AJUSTE`
##     F9      sai do modo
##
## Cada arma tem os proprios numeros: o que se ajusta e' sempre a que esta' na
## mao. A MAO ESQUERDA so' entra na roda com a cacadeira — com a pistola quem
## aparece do lado esquerdo e' a outra copia do rig (`hand_with_magic`), que
## tem dono proprio e nao se mexe daqui.
const AJUSTE_PASSO := 0.2       # centimetros por toque
const AJUSTE_PASSO_ANG := 1.0   # graus por toque
const AJUSTE_PASSO_TAM := 1.0   # por cento por toque

var _ajustando := false
## 0 = conjunto, 1 = arma, 2 = mao esquerda.
var _ajustando_o_que := 0


## Poe o `AJUSTE` de pe' todo quadro, com arma ou sem modo de ajuste ligado:
## sao estes numeros que o jogo usa, o F9 so' escreve neles.
func _aplicar_ajuste() -> void:
	var a: Dictionary = _ajuste.get(_na_mao, {})
	var tam: float = maxf(float(a.get("tamanho", 100.0)), 10.0) / 100.0
	_pousar(self, Transform3D(_base_rig.basis * tam, _base_rig.origin),
		a.get("tela", Vector3.ZERO), a.get("giro", Vector3.ZERO), Vector3.ZERO)

	var arma: Node3D = _armas.get(_na_mao)
	if arma != null:
		_pousar(arma, _base_arma[_na_mao], a.get("arma", Vector3.ZERO),
			a.get("arma_giro", Vector3.ZERO), CABO_MODELO[_na_mao])

	if _no_esq != null:
		_pousar(_no_esq, _base_esq, a.get("mao_e", Vector3.ZERO),
			a.get("mao_e_giro", Vector3.ZERO), _punho_esquerdo())


## Onde esta' o punho esquerdo, em coordenadas do `Armature`. E' o pivo do
## giro da mao esquerda: girar em volta da origem do rig a arrancaria do cano.
func _punho_esquerdo() -> Vector3:
	if _esq == null or _i_mao_esq < 0:
		return Vector3.ZERO
	return _esq.transform * _esq.get_bone_global_pose(_i_mao_esq).origin


## Desloca e gira `alvo` NO ESPACO DA TELA, sem tirar do lugar o que a
## animacao faz: o giro acontece em volta de `pivo_local` (nas coordenadas do
## proprio alvo) e o deslocamento e' lido em centimetros de tela.
##
## Ida e volta pelo espaco de MUNDO porque os tres alvos vivem em espacos
## diferentes (o rig pendura na camera, a arma num osso, a mao num esqueleto) e
## so' o mundo e' comum aos tres. Sem giro nem deslocamento nao ha' conta
## nenhuma: o alvo volta pro que a cena diz.
func _pousar(alvo: Node3D, base: Transform3D, desloc_cm: Vector3,
		giro_gr: Vector3, pivo_local: Vector3) -> void:
	var pai := alvo.get_parent() as Node3D
	if pai == null:
		return
	if desloc_cm == Vector3.ZERO and giro_gr == Vector3.ZERO:
		if alvo.transform != base:
			alvo.transform = base
		return
	var pg := pai.global_transform
	var no_mundo := pg * base
	var olho := _olho()
	var g: Basis = olho * Basis.from_euler(Vector3(deg_to_rad(giro_gr.x),
		deg_to_rad(giro_gr.y), deg_to_rad(giro_gr.z))) * olho.inverse()
	var pivo: Vector3 = no_mundo * pivo_local
	var m := Transform3D(g, pivo - g * pivo)
	# O +Z da camera aponta pra TRAS; "pra frente" na tela e' o -Z dela.
	m.origin += olho * (Vector3(desloc_cm.x, desloc_cm.y, -desloc_cm.z) * 0.01)
	alvo.transform = pg.affine_inverse() * (m * no_mundo)


## Os eixos da TELA, em mundo. A camera de verdade quando ha' uma; senao o pai
## do rig, que e' filho dela e so' difere pelo balanco.
func _olho() -> Basis:
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_3d()
		if cam != null:
			return cam.global_transform.basis.orthonormalized()
	var pai := get_parent() as Node3D
	if pai != null:
		return pai.global_transform.basis.orthonormalized()
	return Basis.IDENTITY


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey):
		return
	# So' quem esta' com arma na tela ouve o teclado: o irmao de terceira
	# pessoa tem o mesmo F9, e sem isto um toque ligaria os dois.
	if _na_mao == "" or not _pronto:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed:
		return

	if tecla.keycode == KEY_F9 and not tecla.echo:
		_ajustando = not _ajustando
		if _ajustando:
			print("ajuste das MAOS DE 1a PESSOA ligado — G troca alvo, "
				+ "P imprime, F9 sai")
			_imprimir_ajuste()
		else:
			print("ajuste das maos de 1a pessoa desligado")
		get_viewport().set_input_as_handled()
		return

	if not _ajustando:
		return

	var a: Dictionary = _ajuste[_na_mao]

	if tecla.keycode == KEY_G and not tecla.echo:
		# Com a pistola a mao esquerda nao e' desta copia; a roda tem dois.
		var quantos := 3 if _na_mao == ITEM_SHOTGUN else 2
		_ajustando_o_que = (_ajustando_o_que + 1) % quantos
		get_viewport().set_input_as_handled()
		_imprimir_ajuste()
		return

	var campo: String = ["tela", "arma", "mao_e"][_ajustando_o_que]
	var campo_giro: String = ["giro", "arma_giro", "mao_e_giro"][_ajustando_o_que]
	var pos: Vector3 = a[campo]
	var giro: Vector3 = a[campo_giro]

	match tecla.keycode:
		KEY_I: pos.z += AJUSTE_PASSO
		KEY_K: pos.z -= AJUSTE_PASSO
		KEY_U: pos.y += AJUSTE_PASSO
		KEY_O: pos.y -= AJUSTE_PASSO
		KEY_J: pos.x -= AJUSTE_PASSO
		KEY_L: pos.x += AJUSTE_PASSO
		KEY_R: giro.x += AJUSTE_PASSO_ANG
		KEY_F: giro.x -= AJUSTE_PASSO_ANG
		KEY_V: giro.y += AJUSTE_PASSO_ANG
		KEY_B: giro.y -= AJUSTE_PASSO_ANG
		KEY_N: giro.z += AJUSTE_PASSO_ANG
		KEY_M: giro.z -= AJUSTE_PASSO_ANG
		KEY_T:
			if _ajustando_o_que == 0:
				a["tamanho"] = maxf(20.0, float(a["tamanho"]) - AJUSTE_PASSO_TAM)
		KEY_Y:
			if _ajustando_o_que == 0:
				a["tamanho"] = float(a["tamanho"]) + AJUSTE_PASSO_TAM
		KEY_P: _imprimir_ajuste()
		_: return

	a[campo] = pos
	a[campo_giro] = giro
	get_viewport().set_input_as_handled()
	if tecla.keycode != KEY_P:
		_imprimir_ajuste()


## Imprime o bloco da arma que esta' na mao, do jeito que ele tem de ficar no
## `AJUSTE` — e' pra copiar da saida e colar por cima, sem digitar numero.
func _imprimir_ajuste() -> void:
	var a: Dictionary = _ajuste[_na_mao]
	var alvos := ["CONJUNTO (as duas maos + a arma)", "ARMA (so' ela, na mao)",
		"MAO ESQUERDA (so' ela)"]
	print("-- mexendo em: %s --" % alvos[_ajustando_o_que])
	print("\t%s: {" % ("ITEM_SHOTGUN" if _na_mao == ITEM_SHOTGUN
		else "ITEM_PISTOLA"))
	print("\t\t\"tela\": %s," % _v(a["tela"]))
	print("\t\t\"giro\": %s," % _v(a["giro"]))
	print("\t\t\"arma\": %s," % _v(a["arma"]))
	print("\t\t\"arma_giro\": %s," % _v(a["arma_giro"]))
	print("\t\t\"mao_e\": %s," % _v(a["mao_e"]))
	print("\t\t\"mao_e_giro\": %s," % _v(a["mao_e_giro"]))
	print("\t\t\"tamanho\": %.1f," % float(a["tamanho"]))
	print("\t},")


func _v(v: Vector3) -> String:
	return "Vector3(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
