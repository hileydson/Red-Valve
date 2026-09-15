extends Node3D

## Os tres takes de rua da abertura do Capitulo 1, e a nevoa que toma a cidade.
##
## A animacao "intro" do `executa_capitulo_1` e um voo aereo continuo sobre a
## cidade. Do segundo 12 em diante ela passa a intercalar esse voo com tres
## takes de rua, todos na `camera_2`, na altura dos olhos:
##
##   12s -> 15s  a camera atravessa um pedaco da cidade em linha reta, com os
##               moradores andando;
##   15s -> 17s  volta pra camera principal (o voo continua sozinho);
##   17s -> 20s  a mesma coisa, em outro ponto do mapa;
##   20s -> 22s  volta pra camera principal;
##   22s -> 32s  o take grande: um MURO DE NEVOA desce a rua por cima da
##               camera e, ao passar por cada morador, o transforma em Shadow
##               Person;
##   32s -> 38s  de volta na camera principal, agora alta: a mesma nevoa,
##               do tamanho da cidade, atravessando tudo;
##   38s ->      o fim da intro, como era antes.
##
## Quem dispara cada take e a propria animacao, por uma faixa de METODO (o
## mesmo mecanismo que ja acionava `set_in_cutscene`, `fade_in` e os sons). O
## CORTE entre as cameras tambem continua na animacao, nas faixas
## `camera:current` e `camera_2:current` — mexer no tempo dos cortes e trabalho
## de editor, nao de codigo. O que este script faz e o resto: POSICIONAR a
## camera_2, povoar a rua, mover a nevoa e transformar os moradores.
##
## Por que os NPCs sao proprios, e nao os do ShadowCrowd
## -----------------------------------------------------
## O ShadowCrowd povoa a cidade ao redor do JOGADOR, e durante a abertura o
## jogador esta parado em outro canto do mapa, a centenas de metros da camera.
## Alem disso, no Capitulo 1 o pool dele ja e de Shadow Person — e aqui a rua
## ainda precisa estar cheia de gente de verdade, justamente pra virar sombra
## na frente da camera. Entao cada take tem o proprio punhado de CityNpc,
## montado uma vez no segundo 1 (durante o voo alto, onde um engasgo nao
## aparece) e guardado na garagem ate a hora de entrar.
##
## Tres coisas que o ShadowPerson faz no jogo e que NAO servem aqui
## ----------------------------------------------------------------
## 1. NAVEGACAO. O NavigationRegion3D da stage_1 fica a uns 200 m da area
##    jogavel, entao o agente nasce sem caminho nenhum: `get_next_path_position`
##    devolve a propria posicao do NPC, o `_move_towards` le isso como "ja
##    cheguei" e a rua inteira fica parada. Num take de tres segundos nao ha o
##    que desviar — todos entram com `use_navigation = false` e andam reto.
## 2. A COLEIRA DA RUA (`road_only`). Depois de 0,7 s fora do asfalto ela larga
##    o que o NPC estiver fazendo e o manda de volta pro meio-fio mais proximo,
##    o que no meio de um take significa o morador virando as costas pra camera
##    sem motivo. Aqui o caminho ja foi escolhido a mao.
## 3. O CHAO. A colisao do Terrain3D e dinamica e nao acompanha a camera da
##    cutscene, entao no lugar dos takes simplesmente NAO HA chao fisico: os
##    moradores caiam, e ficavam meio enterrados tremendo. Cada grupo leva o
##    proprio tablado invisivel — um StaticBody3D na camada do terreno, com o
##    topo na altura do asfalto lida do mapa de ruas.
##
## Onde cada take acontece
## -----------------------
## A ancora de cada take e so' um palpite: quando `busca_rua` for maior que
## zero, o grupo procura NAQUELE RAIO a melhor rua disponivel — a que tem o
## trecho reto mais longo e a pista mais larga. Foi o que consertou o primeiro
## take, que tinha caido numa viela. O take 2 vem com busca zero de proposito:
## a ancora dele ja esta num lugar bom e nao ha por que deixar o sorteio mexer.

const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")
const FX := preload("res://scripts/effects/seraph_fx.gd")
const RockFX := preload("res://scripts/effects/rock_fx.gd")

const CENA_NPC := "res://scenes/npcs/city_npc.tscn"
const CENA_SOMBRA := "res://scenes/npcs/shadow_person.tscn"

## Mesmo truque do rock_fx.gd: nao existe sample de sombra no acervo, e o
## estouro a um terco do pitch le como um bafo grave.
const SOM_SOMBRA := "res://assets/sounds/common/explosao.mp3"

## Ponto morto fora do mapa, igual ao do ShadowCrowd: e onde os NPCs de cada
## take esperam a vez, apagados e sem fisica.
const GARAGEM := Vector3(0.0, -900.0, 0.0)

## Camada fisica do chao da stage_1 (terreno e pisos). O tablado de cada take
## entra nela pra que o CharacterBody3D dos moradores o enxergue.
const CAMADA_CHAO := 2

@export_group("Onde")
## Troque para sortear outro conjunto de ruas, posicoes e modelos. Fixo de
## proposito — ver o `_ready`.
@export var semente: int = 20260914

## Como cada take escolhe a rua:
##   ANCORA   — fica exatamente na ancora, sem procurar nada.
##   CLASSICO — procura a melhor rua no raio, dando peso a largura da pista.
##   ABERTO   — procura dando peso ao ALCANCE DA VISTA, centra o grupo no meio
##              da pista e ainda empurra a partida pra frente ate a rua abrir.
## Nao existe um melhor: sao enquadramentos diferentes, e cada take ficou bom
## com um deles.
enum Perfil { ANCORA, CLASSICO, ABERTO }

## Take 1 (12s). Fica do outro lado do centro da cidade (que e o `City` em
## 640, 0, -280), longe dos outros dois: o ponto antigo, em 687/-217, caia num
## quarteirao esquisito e ainda por cima colado no take 3.
@export var ancora_take_1 := Vector3(672.0, 0.0, -300.0)
@export var perfil_take_1: Perfil = Perfil.ABERTO
@export var busca_take_1: float = 35.0
## Quantos metros a camera deste take comeca A FRENTE do ponto calculado.
@export var partida_take_1: float = 9.0

## Take 2 (17s) — o que ja esta bom: nada de busca, nada de empurrao.
@export var ancora_take_2 := Vector3(607.0, 0.0, -241.0)
@export var perfil_take_2: Perfil = Perfil.ANCORA
@export var busca_take_2: float = 0.0
@export var partida_take_2: float = 0.0

## Take 3 (22s), o da transformacao. (O primeiro lugar tentado foi
## 719, 0, -195; este aqui ficou melhor.)
@export var ancora_take_3 := Vector3(566.0, 0.0, -318.0)
@export var perfil_take_3: Perfil = Perfil.CLASSICO
@export var busca_take_3: float = 30.0
@export var partida_take_3: float = 28.0

@export_group("Quanta gente")
@export var qtd_take_1: int = 8
@export var qtd_take_2: int = 8
@export var qtd_take_3: int = 12
## Comprimento do trecho de rua ocupado pelo grupo, a frente da camera.
@export var comprimento_grupo: float = 20.0
## O mesmo pro grupo do take 3, que e mais longo porque a camera anda mais.
@export var comprimento_grupo_3: float = 26.0
## A que distancia da camera o grupo do take 3 comeca. Zero = o grupo comeca no
## proprio ponto de referencia, e quem abre o espaco a frente da lente e o
## recuo do `dolly_longo`.
@export var avanco_grupo_3: float = 0.0

@export_group("Camera 2")
## Altura do olho da camera em relacao ao asfalto.
@export var altura_camera: float = 1.65
## Quanto a camera anda, do inicio ao fim, nos takes curtos.
@export var dolly_curto := Vector2(-6.0, 5.0)
## O mesmo pro take da transformacao, que dura mais que o triplo. O recuo de
## 10 m e o que estava bom; o empurrao pra frente vem do `partida_take_3`, que
## desloca as DUAS pontas e por isso nao encurta o percurso.
@export var dolly_longo := Vector2(-10.0, 14.0)
## Desvio lateral da camera em relacao ao eixo da rua, pra os moradores
## passarem AO LADO da lente e nao serem atropelados por ela.
@export var desvio_camera: float = 1.5
## Ate onde a camera pode ser empurrada PRA FRENTE, a procura de um ponto de
## partida com a rua aberta. So' vale no perfil ABERTO.
@export var busca_partida: float = 18.0

@export_group("Duracao")
@export var dur_take_curto: float = 3.0
@export var dur_take_longo: float = 10.0
## Quanto tempo a nevoa do tamanho da cidade fica cruzando a tela.
@export var dur_nevoa_cidade: float = 6.0

@export_group("Muro de nevoa")
## Onde o muro nasce e onde ele para, medidos ao longo da rua a partir do
## centro do grupo. Ele comeca ATRAS da camera, a ultrapassa e vai engolindo
## os moradores um por um, sempre a frente da lente.
## Medidos ao longo da rua, a partir do ponto de referencia do grupo.
@export var muro_de: float = -14.0
@export var muro_ate: float = 36.0
@export var muro_largura: float = 30.0
@export var muro_altura: float = 14.0
## Quanto antes do centro do muro o morador ja comeca a escurecer — e a frente
## da fumaca, que chega primeiro.
@export var muro_alcance: float = 5.0

@export_group("Transformacao")
## Quanto tempo a escuridao leva pra subir do pe a cabeca de um morador.
@export var dur_escurecer: float = 0.9
## Fracao do escurecimento em que o morador da lugar ao Shadow Person. Fica no
## meio da fumaca mais fechada, que e onde a troca nao aparece.
@export var troca_em: float = 0.62

@export_group("Debug")
@export var debug_log: bool = false

var _preparado := false
var _grupo_1: Dictionary = {}
var _grupo_2: Dictionary = {}
var _grupo_3: Dictionary = {}
var _ativos: Array[Node3D] = []
var _efeitos: Array[Node] = []
var _cena_npc: PackedScene
var _cena_sombra: PackedScene
var _tween_camera: Tween
var _muro: Node3D = null
var _rng := RandomNumberGenerator.new()

## O modelo de cada morador vem de um .fbx carregado na hora. Sortear entre os
## 92 da lista significaria carregar 28 arquivos diferentes so pra estes takes;
## fixar uma paleta curta faz os mesmos rostos se repetirem entre grupos que
## nunca aparecem juntos na tela, por um punhado de carregamentos.
const PALETA_MODELOS: Array[int] = [0, 3, 7, 12, 19, 26, 33, 41, 48, 55, 62, 70]


func _ready() -> void:
	# Semente FIXA, e nao randomize(): a rua de cada take, a posicao de cada
	# morador e o modelo de cada um saem daqui. Com sorteio livre, o mesmo
	# codigo dava um enquadramento diferente a cada execucao — o take que
	# ficou bom numa rodada abria contra uma fachada na seguinte, e nao havia
	# como julgar mudanca nenhuma. Trocar este numero e trocar de sorteio.
	_rng.seed = semente
	set_physics_process(false)


# ==============================================================================
# CHAMADO PELA ANIMACAO "intro"
# ==============================================================================

## 1s — monta os tres grupos e os manda pra garagem. Roda espalhado por varios
## quadros: instanciar 28 modelos com esqueleto de uma vez daria um engasgo bem
## no comeco da cutscene.
func preparar_takes() -> void:
	if _preparado:
		return
	_preparado = true

	_cena_npc = load(CENA_NPC) as PackedScene
	_cena_sombra = load(CENA_SOMBRA) as PackedScene
	if _cena_npc == null:
		push_error("intro_takes_cidade: city_npc.tscn nao encontrada; os takes de rua ficam vazios.")
		return
	ShadowRoads.setup(get_tree())

	_grupo_1 = await _monta_grupo(ancora_take_1, perfil_take_1, busca_take_1,
		partida_take_1, qtd_take_1, comprimento_grupo, 0.0, dolly_curto, false)
	_grupo_2 = await _monta_grupo(ancora_take_2, perfil_take_2, busca_take_2,
		partida_take_2, qtd_take_2, comprimento_grupo, 0.0, dolly_curto, false)
	_grupo_3 = await _monta_grupo(ancora_take_3, perfil_take_3, busca_take_3,
		partida_take_3, qtd_take_3, comprimento_grupo_3, avanco_grupo_3,
		dolly_longo, true)


## 12s — a camera entra na rua e atravessa em linha reta o grupo que anda.
func take_1() -> void:
	_liga_grupo(_grupo_1)
	_atravessa(_grupo_1, dolly_curto, dur_take_curto)


## 17s — a mesma coisa, em outro ponto da cidade.
func take_2() -> void:
	_liga_grupo(_grupo_2)
	_atravessa(_grupo_2, dolly_curto, dur_take_curto)


## 22s — o take grande. A camera atravessa devagar; por tras dela desce um muro
## de nevoa que a ultrapassa e vai engolindo a rua morador por morador.
func take_3() -> void:
	_liga_grupo(_grupo_3)
	_atravessa(_grupo_3, dolly_longo, dur_take_longo)
	_solta_o_muro(_grupo_3)


## 32s — de volta na camera principal, la em cima: a mesma nevoa, agora do
## tamanho da cidade, avancando por cima dos telhados.
func take_cidade_tomada() -> void:
	voltar_camera_principal()
	_nevoa_pela_cidade()


## 15s e 20s — a camera principal reassume. O corte em si e da animacao; o que
## se faz aqui e recolher quem estava em cena, pra nao sobrar meia duzia de
## pessoas andando num pedaco da cidade que a camera ainda vai sobrevoar.
func voltar_camera_principal() -> void:
	if is_instance_valid(_tween_camera):
		_tween_camera.kill()
	_recolhe_tudo()


## 38s — fim de tudo. A cidade volta a ser so' o voo.
func encerrar_takes() -> void:
	voltar_camera_principal()
	_limpa_efeitos()


# ==============================================================================
# MONTAGEM DOS GRUPOS
# ==============================================================================

## Um grupo e um dicionario com o centro ja assentado no asfalto, o rumo da rua
## naquele ponto, o tablado, os moradores e (so' no take 3) as sombras que vao
## tomar o lugar deles.
func _monta_grupo(ancora: Vector3, perfil: Perfil, busca: float,
		partida: float, quantos: int, comprimento: float, avanco: float,
		trecho: Vector2, com_sombras: bool) -> Dictionary:
	var centro := _melhor_rua(ancora, perfil, busca)
	var eixo := _eixo_da_rua(centro, perfil)
	var rumo: Vector3 = eixo["rumo"]
	var lateral := Vector3.UP.cross(rumo).normalized()

	# De quanto o take inteiro anda PRA FRENTE. Vem de duas parcelas: o
	# empurrao pedido a mao (`partida`) e, so' no perfil ABERTO, a procura
	# automatica por um ponto de onde a rua esteja aberta. NUNCA e negativo —
	# recuar e justamente o que poe a lente contra a fachada de tras.
	#
	# O deslocamento vale pro take INTEIRO: camera, moradores e muro de nevoa
	# andam junto. Empurrar so' a camera a afastaria do grupo e o muro passaria
	# fora do quadro.
	var deslocamento := maxf(partida, 0.0)
	if perfil == Perfil.ABERTO:
		var linha := centro + lateral * desvio_camera
		deslocamento += _melhor_partida(linha, rumo, trecho.x,
			trecho.x + busca_partida) - trecho.x

	var pontos: Array[Vector3] = []
	var alturas: Array[float] = []
	var avancos: Array[float] = []

	for i in quantos:
		# espalhados A FRENTE da camera, ao longo do trecho que ela percorre
		var ao_longo := deslocamento + avanco \
			+ comprimento * (float(i) + 0.5) / float(quantos)
		# alternando as duas maos da rua, longe do eixo por onde a lente passa
		var lado := 1.0 if i % 2 == 0 else -1.0
		var ao_lado := lado * _rng.randf_range(1.3, 3.2)
		var p := _no_asfalto(centro + rumo * ao_longo + lateral * ao_lado)
		pontos.append(p)
		alturas.append(p.y)
		avancos.append(ao_longo)

	# o tablado e um plano so': o topo fica na altura MEDIA do asfalto sob o
	# grupo. Uma rua de 20 m e praticamente plana, e um degrau entre duas
	# placas faria o morador tropecar bem na frente da camera.
	var piso_y := centro.y
	if not alturas.is_empty():
		piso_y = 0.0
		for y in alturas:
			piso_y += y
		piso_y /= float(alturas.size())
	var tablado := _monta_tablado(centro, rumo, lateral,
		deslocamento + avanco, comprimento, piso_y)

	var npcs: Array[Node3D] = []
	var sombras: Array[Node3D] = []
	for i in pontos.size():
		var pos := Vector3(pontos[i].x, piso_y + 0.05, pontos[i].z)
		# a maioria vem ANDANDO PRA CAMERA, que e quem se ve de frente; o resto
		# segue no mesmo sentido dela e e ultrapassado no caminho
		var sentido := -1.0 if i % 3 != 2 else 1.0

		var npc := _nasce_npc(pos, i)
		if npc == null:
			continue
		npc.set_meta("pos_take", pos)
		npc.set_meta("sentido", sentido)
		# posicao ao longo da rua: e por ela que o muro de nevoa sabe de quem
		# ja passou
		npc.set_meta("avanco_na_rua", avancos[i])
		npcs.append(npc)

		if com_sombras:
			var sombra := _nasce_sombra(pos)
			if sombra != null:
				sombras.append(sombra)
		# um por quadro: o custo de instanciar o modelo fica diluido
		await get_tree().process_frame

	if debug_log:
		print("intro_takes_cidade: grupo em ", centro, " rumo ", rumo,
			" | reto ", eixo["reto"], " m, largura ", eixo["largura"],
			" m | perfil ", perfil, " | partida deslocada ", deslocamento, " m | piso ", piso_y,
			" (variacao ", _variacao(alturas), " m) | ", npcs.size(), " moradores.")

	return {"centro": centro, "rumo": rumo, "lateral": lateral, "piso_y": piso_y,
		"deslocamento": deslocamento, "tablado": tablado,
		"npcs": npcs, "sombras": sombras}


## Onde comecar o travelling. Varre o trecho de um em um metro, sempre PRA
## FRENTE do ponto pedido, e fica com a primeira posicao de onde se enxerga
## mais rua. O `+ 0.5` e uma exigencia de melhora de verdade: sem ele a camera
## escorregaria metro a metro atras de qualquer variacao da rasterizacao.
func _melhor_partida(linha: Vector3, rumo: Vector3, de: float, ate: float) -> float:
	var melhor_s := de
	var melhor_vista := -1.0
	var s := de
	while s <= ate:
		var vista := _alcance(linha + rumo * s, rumo)
		if vista > melhor_vista + 0.5:
			melhor_vista = vista
			melhor_s = s
		s += 1.0
	return melhor_s


func _variacao(alturas: Array[float]) -> float:
	if alturas.is_empty():
		return 0.0
	var lo: float = alturas[0]
	var hi: float = alturas[0]
	for y in alturas:
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo


## O chao do take. Existe porque a colisao do Terrain3D e dinamica e nao chega
## ate aqui durante a cutscene — sem ele os moradores caem, e o que aparece na
## tela e meia duzia de gente enterrada ate a cintura, tremendo.
func _monta_tablado(centro: Vector3, rumo: Vector3, lateral: Vector3,
		avanco: float, comprimento: float, piso_y: float) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = "TabladoDoTake"
	corpo.collision_layer = CAMADA_CHAO
	corpo.collision_mask = 0

	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	# x atravessa a rua, z corre com ela — a base montada abaixo poe `rumo` no z.
	# A sobra de 30 m cobre quem anda NA DIRECAO da camera e passa por tras
	# dela durante o take.
	caixa.size = Vector3(26.0, 1.0, avanco + comprimento + 30.0)
	forma.shape = caixa
	corpo.add_child(forma)
	add_child(corpo)

	# deitado ao longo da rua, com o TOPO no nivel do asfalto
	var meio := centro + rumo * (avanco + comprimento * 0.5)
	corpo.global_transform = Transform3D(
		Basis(lateral, Vector3.UP, rumo),
		Vector3(meio.x, piso_y - 0.5, meio.z))
	_desliga_tablado(corpo)
	return corpo


func _liga_tablado(corpo: StaticBody3D) -> void:
	if is_instance_valid(corpo):
		corpo.process_mode = Node.PROCESS_MODE_INHERIT
		corpo.collision_layer = CAMADA_CHAO


func _desliga_tablado(corpo: StaticBody3D) -> void:
	if is_instance_valid(corpo):
		corpo.collision_layer = 0
		corpo.process_mode = Node.PROCESS_MODE_DISABLED


func _nasce_npc(pos: Vector3, i: int) -> CityNpc:
	var npc := _cena_npc.instantiate() as CityNpc
	if npc == null:
		return null
	# tudo antes do add_child: o _ready do CityNpc le estas tres coisas
	npc.modelo_index = PALETA_MODELOS[i % PALETA_MODELOS.size()]
	npc.use_navigation = false
	npc.road_only = false
	npc.position = pos
	add_child(npc)
	_guarda(npc)
	return npc


func _nasce_sombra(pos: Vector3) -> ShadowPerson:
	if _cena_sombra == null:
		return null
	var sombra := _cena_sombra.instantiate() as ShadowPerson
	if sombra == null:
		return null
	# adulto: a rua que vira sombra e a mesma rua de adultos do take
	sombra.age_group = 1
	sombra.use_navigation = false
	sombra.road_only = false
	sombra.position = pos
	add_child(sombra)
	_guarda(sombra)
	return sombra


## Apagado, invisivel e sem fisica, fora do mapa — do mesmo jeito que o
## ShadowCrowd estaciona o pool dele.
func _guarda(no: Node3D) -> void:
	no.visible = false
	no.process_mode = Node.PROCESS_MODE_DISABLED
	no.global_position = GARAGEM
	if no is CharacterBody3D:
		(no as CharacterBody3D).velocity = Vector3.ZERO


# ==============================================================================
# LIGAR E DESLIGAR UM TAKE
# ==============================================================================

func _liga_grupo(grupo: Dictionary) -> void:
	if grupo.is_empty():
		return
	_liga_tablado(grupo["tablado"])
	var rumo: Vector3 = grupo["rumo"]
	var npcs: Array = grupo["npcs"]

	for npc: ShadowPerson in npcs:
		if not is_instance_valid(npc):
			continue
		var pos: Vector3 = npc.get_meta("pos_take", grupo["centro"])
		npc.set_meta("virando", false)
		npc.process_mode = Node.PROCESS_MODE_INHERIT
		npc.visible = true
		npc.relocate(pos)
		_manda_andar(npc, rumo * float(npc.get_meta("sentido", 1.0)))
		_ativos.append(npc)


## Tira o morador do vaivem do ShadowPerson e o poe andando reto rua abaixo: em
## tres segundos de take nao ha tempo pra ele escolher um destino, chegar nele
## e escolher outro. LEAVE e o estado certo pra isso — anda ate o alvo e nao
## para pra puxar assunto com quem cruza no caminho.
func _manda_andar(npc: ShadowPerson, direcao: Vector3) -> void:
	npc.state = ShadowPerson.State.LEAVE
	npc._target = npc.global_position + direcao * 60.0
	npc._state_timer = 120.0
	npc._repath = 0.0
	npc.rotation.y = atan2(direcao.x, direcao.z)


func _recolhe_tudo() -> void:
	set_physics_process(false)
	_muro = null
	for no in _ativos:
		if not is_instance_valid(no):
			continue
		_limpa_escuridao(no)
		_guarda(no)
	_ativos.clear()
	for g in [_grupo_1, _grupo_2, _grupo_3]:
		if not g.is_empty():
			_desliga_tablado(g["tablado"])


# ==============================================================================
# CAMERA 2
# ==============================================================================

func _camera_2() -> Camera3D:
	return get_parent().get_node_or_null("camera_2") as Camera3D


func _camera_principal() -> Camera3D:
	return get_parent().get_node_or_null("camera") as Camera3D


## A camera atravessa a rua EM LINHA RETA: o rumo e escolhido uma vez, no
## comeco, e depois ela so' translada. Refazer o `look_at` a cada quadro faria
## a lente girar atras do grupo, que nao e o que estes takes pedem.
func _atravessa(grupo: Dictionary, trecho: Vector2, duracao: float) -> void:
	if grupo.is_empty():
		return
	var cam := _camera_2()
	if cam == null:
		push_warning("intro_takes_cidade: camera_2 nao encontrada; o take fica na camera principal.")
		return

	var centro: Vector3 = grupo["centro"]
	var rumo: Vector3 = grupo["rumo"]
	var lateral: Vector3 = grupo["lateral"]
	var olho := Vector3.UP * altura_camera
	var base := Vector3(centro.x, grupo["piso_y"], centro.z) + lateral * desvio_camera

	# O trecho pedido e um desejo, nao uma ordem: recuar 6 m onde a rua so'
	# continua 3 m poe a camera DENTRO da fachada de tras, e o take abre com
	# uma parede na tela. Aqui o percurso e cortado pelo asfalto que existe de
	# fato sobre a linha por onde a lente passa.
	var folga := 3.0
	var deslocamento: float = grupo.get("deslocamento", 0.0)
	var ini: float = maxf(trecho.x + deslocamento, -(_alcance(base, -rumo) - folga))
	var fim: float = minf(trecho.y + deslocamento,
		ini + _alcance(base + rumo * ini, rumo) - folga)
	# rua curta demais pros dois lados: melhor andar pouco do que ficar parada
	if fim - ini < 5.0:
		fim = ini + 5.0

	if is_instance_valid(_tween_camera):
		_tween_camera.kill()
	cam.global_position = base + rumo * ini + olho
	# olha rua abaixo, na altura do peito de quem vem andando
	cam.look_at(base + rumo * 45.0 + Vector3.UP * 1.3, Vector3.UP)
	_tween_camera = create_tween()
	_tween_camera.tween_property(cam, "global_position",
		base + rumo * fim + olho, duracao).set_trans(Tween.TRANS_LINEAR)
	if debug_log:
		print("intro_takes_cidade: travelling de ", ini, " a ", fim,
			" (pedido ", trecho, ")")


# ==============================================================================
# O MURO DE NEVOA
# ==============================================================================

## Solta o muro atras da camera e o manda descer a rua. Ele ultrapassa a lente
## logo no comeco e, dali pra frente, tudo o que acontece acontece NA FRENTE da
## camera: a nevoa alcanca um morador, o morador escurece e sai de dentro dela
## como sombra.
func _solta_o_muro(grupo: Dictionary) -> void:
	if grupo.is_empty():
		return
	var centro: Vector3 = grupo["centro"]
	var rumo: Vector3 = grupo["rumo"]
	var lateral: Vector3 = grupo["lateral"]
	var piso: float = grupo["piso_y"]

	var deslocamento: float = grupo.get("deslocamento", 0.0)
	var pe := Vector3(centro.x, piso, centro.z) + Vector3.UP * (muro_altura * 0.35)

	var muro := _monta_muro(muro_largura, muro_altura, 9.0, 80, 3.0, 8.0, 5.0,
		0.38, Color(0.12, 0.115, 0.15))
	muro.global_transform = Transform3D(
		Basis(lateral, Vector3.UP, rumo),
		pe + rumo * (muro_de + deslocamento))
	_muro = muro
	_acrescenta_efeito(muro, dur_take_longo + 3.0)

	var destino := pe + rumo * (muro_ate + deslocamento)
	var t := create_tween()
	t.tween_property(muro, "global_position", destino, dur_take_longo)\
		.set_trans(Tween.TRANS_LINEAR)

	_baque()
	set_physics_process(true)


## Quem o muro ja alcancou, vira. E o proprio avanco da nevoa que dispara a
## transformacao — nao um relogio — pra que o que se ve na tela seja causa e
## efeito: a fumaca chega, a pessoa escurece.
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_muro) or _grupo_3.is_empty():
		return
	var centro: Vector3 = _grupo_3["centro"]
	var rumo: Vector3 = _grupo_3["rumo"]
	var frente := (_muro.global_position - centro).dot(rumo) + muro_alcance

	var npcs: Array = _grupo_3["npcs"]
	var sombras: Array = _grupo_3["sombras"]
	for i in npcs.size():
		var npc: ShadowPerson = npcs[i]
		if not is_instance_valid(npc) or not npc.visible:
			continue
		if bool(npc.get_meta("virando", false)):
			continue
		if float(npc.get_meta("avanco_na_rua", 0.0)) > frente:
			continue
		npc.set_meta("virando", true)
		_vira_sombra(npc, sombras[i] if i < sombras.size() else null)


## 32s — a mesma nevoa, na escala da cidade, vista do alto. Nasce longe, na
## direcao pra onde a camera principal esta olhando, e vem avancando por cima
## dos telhados ate encher o quadro.
func _nevoa_pela_cidade() -> void:
	var cam := _camera_principal()
	if cam == null:
		return
	var frente := -cam.global_transform.basis.z
	var plano := Vector3(frente.x, 0.0, frente.z)
	if plano.length() < 0.01:
		plano = Vector3.FORWARD
	plano = plano.normalized()
	var lateral := Vector3.UP.cross(plano).normalized()

	var longe := cam.global_position + plano * 260.0
	var chao := _no_asfalto(longe).y
	var perto := cam.global_position + plano * 50.0

	var muro := _monta_muro(420.0, 70.0, 60.0, 150, 30.0, 75.0, 9.0)
	muro.global_transform = Transform3D(
		Basis(lateral, Vector3.UP, plano),
		Vector3(longe.x, chao + 18.0, longe.z))
	_acrescenta_efeito(muro, dur_nevoa_cidade + 4.0)

	var t := create_tween()
	t.tween_property(muro, "global_position",
		Vector3(perto.x, chao + 18.0, perto.z), dur_nevoa_cidade)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_baque()


## Uma parede de fumaca escura, deitada no eixo X (largura) e fina no Z
## (profundidade), que anda inteira quando o no anda — daí `local_coords`: as
## particulas acompanham o muro em vez de ficarem para tras formando um rastro.
func _monta_muro(largura: float, altura: float, fundura: float, quantas: int,
		escala_min: float, escala_max: float, vida: float,
		opacidade := 0.85, cor := Color(0.035, 0.033, 0.05)) -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(largura * 0.5, altura * 0.5, fundura * 0.5)
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 70.0
	proc.initial_velocity_min = altura * 0.05
	proc.initial_velocity_max = altura * 0.22
	proc.gravity = Vector3(0, altura * 0.02, 0)
	proc.damping_min = 0.3
	proc.damping_max = 1.0
	proc.angular_velocity_min = -25.0
	proc.angular_velocity_max = 25.0
	proc.scale_min = escala_min
	proc.scale_max = escala_max
	proc.scale_curve = FX.curva_pico(0.3)
	# azul frio no miolo: e a mesma paleta das sombras. A opacidade importa
	# mais do que parece — sao dezenas de quads sobrepostos, e o que numa
	# particula so' e um veu translucido, somado, vira uma mancha opaca.
	proc.color_ramp = FX.rampa(
		[Color(cor.r, cor.g, cor.b, 0.0),
		Color(cor.r, cor.g, cor.b, opacidade),
		Color(cor.r * 0.45, cor.g * 0.45, cor.b * 0.5, opacidade * 0.7),
		Color(0.0, 0.0, 0.0, 0.0)],
		[0.0, 0.12, 0.7, 1.0])

	var p := GPUParticles3D.new()
	p.amount = quantas
	p.lifetime = vida
	p.one_shot = false
	p.explosiveness = 0.0
	p.preprocess = vida * 0.5  # ja nasce como parede, e nao se formando
	p.process_material = proc
	# quad do rock_fx e nao o do seraph: este tem billboard_keep_scale, sem o
	# qual scale_min/scale_max nao valem nada e toda particula sai de 1 m
	p.draw_pass_1 = RockFX.quad_po()
	p.local_coords = true
	var alcance := maxf(largura, altura) * 1.5
	p.visibility_aabb = AABB(Vector3.ONE * -alcance, Vector3.ONE * alcance * 2.0)
	add_child(p)
	p.emitting = true
	return p


# ==============================================================================
# A TRANSFORMACAO
# ==============================================================================

## O morador e engolido de baixo pra cima por uma casca preta com uma brasa
## vermelha na frente dela, dentro de uma coluna de fumaca; no meio do caminho,
## escondido pela fumaca, ele sai de cena e o Shadow Person assume o passo dele.
func _vira_sombra(npc: ShadowPerson, sombra: ShadowPerson) -> void:
	var altura: float = npc.get_meta("body_height", 1.8)
	var mat := _material_escuridao(npc.global_position.y, altura)
	_veste_escuridao(npc, mat)
	_acrescenta_efeito(_coluna_de_fumaca(npc.global_position, altura), 3.5)

	var t := create_tween()
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter("avanco", v),
		0.0, 1.0, dur_escurecer).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(dur_escurecer * troca_em).timeout
	if not is_instance_valid(npc):
		return

	if is_instance_valid(sombra):
		var direcao := Vector3(sin(npc.rotation.y), 0.0, cos(npc.rotation.y))
		sombra.process_mode = Node.PROCESS_MODE_INHERIT
		sombra.visible = true
		sombra.relocate(npc.global_position)
		sombra.set_meta("pos_take", npc.global_position)
		_manda_andar(sombra, direcao)
		_ativos.append(sombra)

	_limpa_escuridao(npc)
	npc.visible = false
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	_ativos.erase(npc)


## Casca preta aplicada POR CIMA do material do modelo (`material_overlay`), e
## nao no lugar dele: o morador continua o mesmo, com a mesma textura, e o que
## muda e uma camada de escuridao que sobe pelo corpo. Trocar o material de
## verdade significaria mexer em cada surface de cada modelo e nao ter mais
## como voltar atras.
##
## A brasa vermelha na linha de frente nao e enfeite: sem ela a transformacao e
## preto virando preto num plano ja escuro, e nao se entende o que aconteceu.
func _material_escuridao(pe_y: float, altura: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode blend_mix, unshaded, shadows_disabled, fog_disabled,
		depth_draw_never;

	// 0 = morador intacto, 1 = silhueta preta inteira.
	uniform float avanco : hint_range(0.0, 1.0) = 0.0;
	uniform float pe_y = 0.0;
	uniform float altura = 1.8;
	uniform vec3 brasa_cor = vec3(1.7, 0.22, 0.12);

	varying float y_mundo;
	varying vec3 p_mundo;

	void vertex() {
		vec3 m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		y_mundo = m.y;
		p_mundo = m;
	}

	float ruido(vec3 p) {
		return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	}

	void fragment() {
		float f = clamp((y_mundo - pe_y) / max(altura, 0.01), 0.0, 1.0);
		// a frente passa um pouco de 1 pra a cabeca tambem fechar no fim
		float frente = avanco * 1.3;
		// borda irregular: sem isso a escuridao sobe como uma regua
		float irregular = (ruido(floor(p_mundo * 26.0)) - 0.5) * 0.09;
		float d = f - (frente + irregular);

		// escuridao: tudo o que ja ficou ABAIXO da frente
		float escuro = 1.0 - smoothstep(0.0, 0.26, d);
		// brasa: uma faixa fina em cima da propria frente, que se apaga no fim
		float faixa = smoothstep(0.16, 0.0, abs(d));
		float brasa = faixa * (1.0 - smoothstep(0.85, 1.0, avanco));

		ALBEDO = mix(vec3(0.0), brasa_cor, brasa);
		ALPHA = clamp(max(escuro, brasa), 0.0, 1.0);
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("avanco", 0.0)
	mat.set_shader_parameter("pe_y", pe_y)
	mat.set_shader_parameter("altura", altura)
	return mat


func _veste_escuridao(npc: ShadowPerson, mat: ShaderMaterial) -> void:
	for m in _malhas(npc):
		m.material_overlay = mat


func _limpa_escuridao(no: Node3D) -> void:
	for m in _malhas(no):
		m.material_overlay = null


func _malhas(raiz: Node) -> Array[MeshInstance3D]:
	var saida: Array[MeshInstance3D] = []
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		for c in n.get_children():
			pilha.append(c)
		if n is MeshInstance3D:
			saida.append(n as MeshInstance3D)
	return saida


## Coluna que sobe do chao e envolve o morador. A camera esta a poucos metros,
## entao ela e fechada e rapida: o que precisa esconder e a troca de corpo.
func _coluna_de_fumaca(pos: Vector3, altura: float) -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(0.4, 0.15, 0.4)
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 25.0
	proc.initial_velocity_min = 1.4
	proc.initial_velocity_max = 3.2
	proc.gravity = Vector3(0, 0.45, 0)
	proc.damping_min = 1.0
	proc.damping_max = 2.2
	proc.angular_velocity_min = -50.0
	proc.angular_velocity_max = 50.0
	proc.scale_min = altura * 0.4
	proc.scale_max = altura * 0.95
	proc.scale_curve = FX.curva_pico(0.28)
	proc.color_ramp = FX.rampa(
		[Color(0.05, 0.04, 0.07, 0.0), Color(0.03, 0.03, 0.045, 0.9),
		Color(0.02, 0.02, 0.03, 0.55), Color(0.0, 0.0, 0.0, 0.0)],
		[0.0, 0.14, 0.6, 1.0])

	var p := GPUParticles3D.new()
	p.amount = 32
	p.lifetime = 2.0
	p.one_shot = true
	p.explosiveness = 0.5
	p.process_material = proc
	p.draw_pass_1 = RockFX.quad_po()
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 10, 10))
	p.position = pos
	add_child(p)
	p.emitting = true
	return p


## Bafo grave da virada. Nao e som posicional: a cutscene ja tem a trilha
## tocando e o que se quer aqui e um peso por baixo dela, nao um ponto no mapa.
func _baque() -> void:
	var stream := load(SOM_SOMBRA) as AudioStream
	if stream == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = stream
	a.volume_db = -10.0
	a.pitch_scale = 0.3
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
	_efeitos.append(a)


## Liga o `queue_free` DO PROPRIO no ao relogio, em vez de uma lambda que o
## captura: se o efeito ja tiver sido liberado antes da hora (fim da cutscene,
## troca de cena), a conexao morre junto com ele — com a lambda, o motor
## reclamava de "Lambda capture was freed" toda vez. A lista e varrida depois,
## no `_limpa_efeitos`, que ja confere validade.
func _acrescenta_efeito(no: Node, vida: float) -> void:
	_efeitos.append(no)
	get_tree().create_timer(vida).timeout.connect(no.queue_free)


func _limpa_efeitos() -> void:
	for e in _efeitos:
		if is_instance_valid(e):
			e.queue_free()
	_efeitos.clear()


# ==============================================================================
# RUA
# ==============================================================================

## Puxa o ponto pro asfalto mais proximo e o assenta na altura da rua. O mapa de
## ruas do ShadowRoads e rasterizado da malha do no "Roads", entao isso funciona
## mesmo onde nao ha colisao nenhuma — que e o caso das ruas da cidade.
func _no_asfalto(p: Vector3) -> Vector3:
	var plano := Vector3(p.x, 0.0, p.z)
	var achado := ShadowRoads.nearest(plano, 60.0, 12, 24)
	var y := ShadowRoads.road_y(achado)
	if is_nan(y):
		y = ShadowRoads.ground_y(get_world_3d(), achado, CAMADA_CHAO)
	if is_nan(y):
		y = p.y
	return Vector3(achado.x, y, achado.z)


## Procura, no raio dado, a melhor rua pra plantar um take: a que tem o trecho
## reto mais longo e a pista mais larga. Raio 0 = fica na ancora.
##
## Existe porque o primeiro take caiu numa viela curta e o plano nao tinha para
## onde olhar; com esta busca a ancora vira um palpite, e nao uma coordenada
## que precisa estar exata.
func _melhor_rua(ancora: Vector3, perfil: Perfil, raio: float) -> Vector3:
	var base := _no_asfalto(ancora)
	if perfil == Perfil.ANCORA or raio <= 0.0 or not ShadowRoads.has_map():
		return base
	var melhor := base
	var melhor_nota: float = _eixo_da_rua(base, perfil)["nota"]
	for _i in 48:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * raio
		var cand := _no_asfalto(ancora + Vector3(cos(a) * d, 0.0, sin(a) * d))
		if not ShadowRoads.is_road(cand):
			continue
		var nota: float = _eixo_da_rua(cand, perfil)["nota"]
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = cand
	if perfil == Perfil.ABERTO:
		return _centraliza_na_pista(melhor)
	return melhor


## O ponto sorteado cai em qualquer celula de asfalto, inclusive na ultima
## junto ao meio-fio — e ali o desvio lateral da camera ja a joga na calcada.
## Isto desliza o ponto ate o meio da pista.
func _centraliza_na_pista(p: Vector3) -> Vector3:
	var eixo := _eixo_da_rua(p, Perfil.ABERTO)
	var lado := Vector3.UP.cross(eixo["rumo"]).normalized()
	var a := _alcance(p, lado)
	var b := _alcance(p, -lado)
	return _no_asfalto(p + lado * ((a - b) * 0.5))


## Pra que lado corre a rua neste ponto, e o quanto ela presta? Mede quanto o
## asfalto continua em 16 direcoes e fica com a que tem o trecho mais longo NOS
## DOIS SENTIDOS — assim a camera anda pelo eixo da pista, e nao atravessando-a
## de calcada a calcada. A largura entra na nota com peso: uma rua larga cabe
## gente dos dois lados, uma viela nao.
func _eixo_da_rua(centro: Vector3, perfil: Perfil) -> Dictionary:
	if not ShadowRoads.has_map():
		return {"rumo": Vector3.FORWARD, "reto": 0.0, "largura": 0.0, "nota": 0.0}
	# ABERTO enxerga mais longe e cobra vista; CLASSICO para em 40 m e valoriza
	# a pista larga. Sao os dois criterios que renderam bons takes, e cada um
	# escolhe uma rua diferente — por isso continuam os dois aqui.
	var teto := 70.0 if perfil == Perfil.ABERTO else 40.0
	var peso_largura := 1.5 if perfil == Perfil.ABERTO else 3.0
	var melhor := Vector3.FORWARD
	var melhor_reto := -1.0
	for k in 16:
		var a := PI * float(k) / 16.0
		var d := Vector3(sin(a), 0.0, cos(a))
		var reto: float = minf(_alcance(centro, d, teto), _alcance(centro, -d, teto))
		if reto > melhor_reto:
			melhor_reto = reto
			melhor = d
	var lado := Vector3.UP.cross(melhor).normalized()
	var largura: float = minf(_alcance(centro, lado, teto), _alcance(centro, -lado, teto))
	return {"rumo": melhor, "reto": melhor_reto, "largura": largura,
		"nota": melhor_reto + largura * peso_largura}


func _alcance(de: Vector3, d: Vector3, teto := 70.0) -> float:
	var passo := 2.0
	var andado := 0.0
	while andado < teto:
		andado += passo
		if not ShadowRoads.is_road(de + d * andado):
			return andado - passo
	return andado


func _exit_tree() -> void:
	_limpa_efeitos()





