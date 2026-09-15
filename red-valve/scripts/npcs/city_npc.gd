extends ShadowPerson
class_name CityNpc

const HumanoidPoser := preload("res://scripts/npcs/humanoid_poser.gd")

## Morador da cidade do PROLOGO. Por dentro e um ShadowPerson: herda o mesmo
## vaga-pela-rua, o mesmo para-e-conversa-com-quem-passa, a mesma catada de
## chao e o mesmo pool do ShadowCrowd. O que muda e a casca — em vez da
## silhueta de escuridao montada com capsulas, entra um dos modelos de
## `assets/3d_model/stages/npc_cidade/ranbom_npc_cidade`.
##
## No Capitulo 1 a cidade vira das sombras: quem povoa a rua volta a ser o
## ShadowPerson, e junto com ele os ShadowCar. Quem faz essa troca e o
## ShadowCrowd, olhando o estado do prologo — ver `shadow_crowd.gd`.
##
## Todos sao ADULTOS de proposito (`age_group = 1` no _ready): o pedido era que
## se comportassem como o shadow person adulto, entao nada de pega-pega nem de
## crianca andando atras de um adulto.
##
## Os modelos vem do Mixamo com o rig e NENHUMA animacao — o unico "clipe" do
## arquivo e a pose de bind, de um quadro so. A caminhada, a gesticulacao e a
## abaixada sao calculadas osso a osso pelo HumanoidPoser.

## Modelos disponiveis. E uma lista fixa, e nao uma varredura de pasta, porque
## num projeto exportado os .fbx nao existem mais: sobra o .scn reimportado,
## que o `load()` acha pelo caminho de origem mas que o DirAccess nao lista.
##
## A pasta tem 93 arquivos e aqui estao 92: o `Character_Female_01.fbx` nao
## referencia textura nenhuma (nao existe um .png com esse nome) e entraria na
## rua como um manequim branco.
const PASTA := "res://assets/3d_model/stages/npc_cidade/ranbom_npc_cidade/"
const MODELOS: Array[String] = [
	"Character_01", "Character_02", "Character_03", "Character_04", "Character_05",
	"Character_06", "Character_07", "Character_08", "Character_09", "Character_10",
	"Character_11", "Character_12", "Character_13", "Character_14", "Character_15",
	"Character_16", "Character_17_Female_Police", "Character_17_Police",
	"Character_18_Female_Police", "Character_18_Police", "Character_19_Female_Police",
	"Character_19_Police", "Character_20_Female_Police", "Character_20_Police",
	"Character_21_Female_Firefighter", "Character_21_Police",
	"Character_22_Female_Firefighter", "Character_22_Police", "Character_23_Female_Doctor",
	"Character_23_Firefighter", "Character_24_Female_Doctor", "Character_24_Firefighter",
	"Character_25_Doctor", "Character_25_Female_Police", "Character_26_Doctor",
	"Character_26_Female_Police", "Character_27_Female_HM", "Character_27_HM",
	"Character_28_Female_HM", "Character_28_HM", "Character_29", "Character_29_Female",
	"Character_30", "Character_30_Female", "Character_31", "Character_31_Female",
	"Character_32", "Character_32_Female", "Character_33_Female", "Character_34_Female",
	"Character_35_Female", "Character_36_Female", "Character_37_Female",
	"Character_38_Female", "Character_39_Female", "Character_40_Female",
	"Character_41_Female", "Character_42_Female", "Character_43_Female",
	"Character_44_Female", "Character_45_Female", "Character_46_Female",
	"Character_Female_02", "Character_Female_03", "Character_Female_04",
	"Character_Female_05", "Character_Female_06", "Character_Female_07",
	"Character_Female_08", "Character_Female_09", "Character_Female_10",
	"Character_Female_11", "Character_Female_12", "Character_Female_13",
	"Character_Female_14", "Character_Female_15", "Character_Female_16",
	"Character_Male_33", "Character_Male_34", "Character_Male_35", "Character_Male_36",
	"Character_Male_37", "Character_Male_38", "Character_Male_39", "Character_Male_40",
	"Character_Male_41", "Character_Male_42", "Character_Male_43", "Character_Male_44",
	"Character_Male_45", "Character_Sheriff_N", "Character_Sheriff_N_01",
]

## Quanto o modelo precisa girar dentro do NPC pra olhar pro mesmo lado que o
## corpo. Zero: os dois olham pro +Z — o `_face()` do ShadowPerson usa
## `atan2(to.x, to.z)`, que poe o +Z local em cima da direcao do movimento, e o
## rig do Mixamo ja nasce virado pra la. Ver o cabecalho do humanoid_poser.gd.
const GIRO_DO_MODELO := 0.0

@export_group("Desempenho")
## Ate esta distancia da camera a pose e recalculada todo quadro de fisica.
## Depois dela cai pra um quadro sim outro nao, e depois do dobro dela, pra um
## em cada quatro. Mexer no esqueleto e a parte cara deste NPC, e a 30 metros
## de distancia, na nevoa, ninguem conta os quadros da passada.
@export var distancia_pose_cheia: float = 14.0

@export_group("Parar num lugar")
## Liga a ida ate' banco e muro. Desligue pra os moradores so' vagarem, que e'
## o comportamento que o ShadowPerson ja' dava sozinho.
@export var usa_pontos_de_parada: bool = true
## Arquivo com os lugares, gravado pelo `tools/godot/citybuild/city_urbano.gd`.
@export var pontos_json: String = "res://assets/3d_model/city/pontos_de_parada.json"
## Ate' onde procurar um lugar livre.
@export var alcance_do_ponto: float = 26.0
## Intervalo entre uma tentativa de parar e a proxima.
@export var intervalo_de_parada := Vector2(22.0, 70.0)
## Quanto tempo se fica no lugar.
@export var duracao_da_parada := Vector2(14.0, 42.0)
## Desiste de chegar depois disto.
@export var paciencia_ate_chegar: float = 22.0

@export_group("Modelo")
## Cena a usar. Vazio = sorteia um da lista acima.
@export var modelo: PackedScene
## -1 = sorteia. 0..N = forca um indice da lista MODELOS.
@export var modelo_index: int = -1
## Variacao de tamanho, pra a rua nao ficar com 20 pessoas do mesmo tamanho.
@export var escala_min: float = 0.93
@export var escala_max: float = 1.07
## Sombra projetada. Desligada por padrao: sao dezenas de malhas com esqueleto
## e o sol da cidade ja vem com `shadow_opacity` em 0.
@export var projeta_sombra: bool = false

var _poser
var _modelo_raiz: Node3D

## Lugares de sentar/encostar, lidos UMA vez por jogo e compartilhados por
## todos os NPCs — sao centenas de pontos e dezenas de NPCs no pool.
static var _pontos: Array = []
static var _pontos_lidos := false
## indice do ponto -> NPC que o reservou. Dois moradores sentando no mesmo
## lugar do banco e' pior do que nenhum sentado.
static var _reservados: Dictionary = {}

enum Parada { NENHUMA, INDO, PARADO }
var _parada: int = Parada.NENHUMA
var _ponto_idx := -1
var _ponto_pos := Vector3.ZERO
var _ponto_giro := 0.0
var _ponto_altura := 0.0
var _ponto_tipo := ""
var _parada_relogio := 0.0
var _proxima_parada := 0.0
var _rig_y_base := 0.0
var _encosto_lado := 1.0
var _abertura := 0.0
var _planar := 0.0
var _pose_espera := 0

## Posicao da camera, lida UMA vez por quadro de fisica e nao uma vez por NPC:
## com o pool cheio seriam 26 buscas de camera por quadro pra achar o mesmo
## ponto.
static var _cam_pos := Vector3.ZERO
static var _cam_quadro := -1


func _ready() -> void:
	# a lista de modelos nao tem criancas, e o pedido era o comportamento do
	# shadow person ADULTO: nada de pega-pega nem de seguir um adulto
	age_group = 1
	super._ready()
	add_to_group("city_npc")
	_carregar_pontos()
	_proxima_parada = randf_range(intervalo_de_parada.x, intervalo_de_parada.y)


## O pool do ShadowCrowd reaproveita o mesmo NPC em outro canto da cidade. A
## base ja zera estado, destino e conversa; aqui so se apaga o resto da passada
## anterior, pra ele nao reaparecer com as pernas abertas no meio de um passo
## que nao esta mais dando.
func relocate(pos: Vector3) -> void:
	_soltar_ponto()
	super.relocate(pos)
	_abertura = 0.0
	_planar = 0.0
	_pose_espera = 0
	_proxima_parada = randf_range(intervalo_de_parada.x, intervalo_de_parada.y)


## O pool do ShadowCrowd recolhe o NPC sem avisar, e o `_exit_tree` da base nao
## sabe do ponto reservado. Sem soltar aqui, um assento some do mapa pro resto
## da partida cada vez que alguem e' recolhido enquanto estava sentado.
func _exit_tree() -> void:
	_soltar_ponto()
	super._exit_tree()


## Entra no lugar do `_build_body` do ShadowPerson, que montava a silhueta com
## capsulas. Aqui a silhueta e um modelo pronto; o que se monta e o mapa de
## ossos que o HumanoidPoser vai mexer.
func _build_body() -> void:
	var cena := modelo
	if cena == null:
		cena = _sorteia_modelo()
	if cena == null:
		push_error("CityNpc: nenhum modelo pode ser carregado; o NPC fica invisivel.")
		set_meta("body_height", BASE_HEIGHT)
		return

	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.rotation.y = GIRO_DO_MODELO
	_rig.scale = Vector3.ONE * _rng.randf_range(escala_min, escala_max)
	add_child(_rig)

	_modelo_raiz = cena.instantiate() as Node3D
	if _modelo_raiz == null:
		set_meta("body_height", BASE_HEIGHT)
		return
	_rig.add_child(_modelo_raiz)

	# o arquivo traz um AnimationPlayer com a pose de bind e nada mais. Se ele
	# ficar, qualquer play() acidental sobrescreve o que o poser escreveu nos
	# ossos — e ele nao serve pra nada aqui.
	var ap := _modelo_raiz.find_child("AnimationPlayer", true, false)
	if ap != null:
		ap.queue_free()

	var sk := _acha_esqueleto(_modelo_raiz)
	if sk == null:
		push_warning("CityNpc: modelo sem Skeleton3D; fica parado feito estatua.")
		set_meta("body_height", BASE_HEIGHT)
		return

	if not projeta_sombra:
		for m in sk.get_children():
			if m is MeshInstance3D:
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_poser = HumanoidPoser.new()
	if not _poser.setup(sk, GIRO_DO_MODELO):
		push_warning("CityNpc: rig nao reconhecido em " + String(_modelo_raiz.name))
		_poser = null

	var altura: float = (_poser.altura_total if _poser != null else BASE_HEIGHT) * _rig.scale.y
	set_meta("body_height", altura)
	set_meta("variant", String(_modelo_raiz.name))
	set_meta("is_child", false)


func _sorteia_modelo() -> PackedScene:
	if MODELOS.is_empty():
		return null
	var i := modelo_index
	if i < 0 or i >= MODELOS.size():
		i = _rng.randi_range(0, MODELOS.size() - 1)
	return load(PASTA + MODELOS[i] + ".fbx") as PackedScene


func _acha_esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s := _acha_esqueleto(c)
		if s != null:
			return s
	return null


# ------------------------------------------------------------------ animacao

## Substitui o `_animate` do ShadowPerson inteiro. A contagem de passos e o
## avanco das fases sao os mesmos — eles alimentam o som dos passos e sao lidos
## pelos estados; o que muda e quem recebe a pose no fim: o esqueleto, e nao
## uma arvore de capsulas.
func _animate(delta: float) -> void:
	_planar = Vector2(velocity.x, velocity.z).length()
	var andando := _planar > 0.15
	var cadencia := 4.2 + _planar * 1.6

	if andando:
		var antes := _walk_phase
		_walk_phase += delta * cadencia
		# cada meio ciclo do balanco e um pe batendo no chao
		var meio := int(floor(_walk_phase / PI))
		if meio != int(floor(antes / PI)) and is_on_floor() and state != State.PICKUP:
			_play_step(_planar / maxf(walk_speed, 0.01))
		_step_half = meio
	_gesture_phase += delta

	if _poser == null:
		return

	# a abertura da perna persegue a velocidade em vez de saltar junto com ela:
	# assim uma freada nao vira uma passada gigante num quadro so
	_abertura = lerpf(_abertura, _poser.abertura_para(_planar, cadencia),
		clampf(delta * 6.0, 0.0, 1.0))

	# a maquina de estados e o som dos passos acima continuam a 60 Hz; o que o
	# LOD espaca e so a escrita no esqueleto
	_pose_espera -= 1
	if _pose_espera > 0:
		return
	_pose_espera = _passo_da_pose()

	var blend := clampf(_planar / maxf(walk_speed, 0.01), 0.0, 1.0)

	# parado num ponto tem prioridade sobre a maquina de estados da base: o
	# `state` continua WANDER o tempo todo (e e' de proposito — assim a base
	# nao precisa saber que existe banco de praca), entao e' aqui que a pose
	# sentada ou encostada entra na frente.
	if _parada == Parada.PARADO:
		var tg := _gesture_phase + _gesture_seed
		if _ponto_tipo == "sentar":
			_poser.pose_sentado(tg, _ponto_altura)
		else:
			_poser.pose_encostado(tg, _encosto_lado)
		return

	match state:
		State.PICKUP:
			var passado := _pickup_dur - _state_timer
			var desce := smoothstep(0.0, 1.0, clampf(passado / maxf(_pickup_dur * 0.35, 0.01), 0.0, 1.0))
			var sobe := smoothstep(0.0, 1.0, clampf((passado - _pickup_dur * 0.62) / maxf(_pickup_dur * 0.38, 0.01), 0.0, 1.0))
			_poser.pose_catando(desce * (1.0 - sobe))
		State.TALK:
			_poser.pose_conversando(_gesture_phase + _gesture_seed, _speaking)
		_:
			_poser.pose_locomocao(_walk_phase, _gesture_phase + _gesture_seed, blend, _abertura)


## De quantos em quantos quadros de fisica vale a pena repor a pose. O resto
## aleatorio espalha os NPCs por quadros diferentes, senao o pool inteiro
## recalcularia tudo no mesmo quadro e o custo voltaria concentrado.
func _passo_da_pose() -> int:
	var d := global_position.distance_to(_camera_agora())
	if d <= distancia_pose_cheia:
		return 1
	if d <= distancia_pose_cheia * 2.0:
		return 2 + (get_instance_id() % 2)
	return 4 + (get_instance_id() % 3)


func _camera_agora() -> Vector3:
	var quadro := Engine.get_physics_frames()
	if quadro != _cam_quadro:
		_cam_quadro = quadro
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_cam_pos = cam.global_position
	return _cam_pos


# ------------------------------------------------------ parar num lugar

## Vagar o dia inteiro e conversar de dois em dois e' o que o ShadowPerson ja
## fazia. Uma cidade viva tem gente PARADA fazendo alguma coisa: sentada no
## banco da praca olhando o obelisco, encostada no muro vendo a rua passar.
##
## Estes pontos NAO sao decididos aqui — eles saem do `city_urbano.gd`, que e
## quem sabe onde ele mesmo poe os bancos e onde tem muro virado pra rua. A
## lista vem por arquivo, num `static`: sao centenas de pontos, e ler um JSON
## por NPC do pool seria ler o mesmo arquivo dezenas de vezes.
##
## Por que isto vive no CityNpc e nao no ShadowPerson: o ShadowPerson tambem e
## a sombra do Capitulo 1, e sombra nao senta em banco de praca. Alem disso a
## maquina de estados dele e usada pelo prologo E pelo capitulo; mexer na base
## pra um comportamento que so o morador tem seria arriscar os dois.
##
## O `_physics_process` abaixo INTERCEPTA o da base em vez de estende-lo: com o
## NPC sentado, nada do que a base faz num quadro (vagar, procurar parceiro de
## conversa, voltar pra rua) e desejavel. Enquanto ele nao esta parado, o
## comportamento e o de sempre, e a unica coisa a mais e a chance de decidir ir
## pra um ponto.
func _physics_process(delta: float) -> void:
	if not usa_pontos_de_parada or _parada == Parada.NENHUMA:
		super._physics_process(delta)
		_pensar_em_parar(delta)
		return

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	_parada_relogio -= delta
	match _parada:
		Parada.INDO:
			_move_towards(_ponto_pos, delta)
			var d := Vector2(_ponto_pos.x - global_position.x,
				_ponto_pos.z - global_position.z).length()
			if d < 0.45:
				_chegou_no_ponto()
			elif _parada_relogio <= 0.0:
				_soltar_ponto()          # nao achou caminho; volta a vagar
		Parada.PARADO:
			velocity.x = move_toward(velocity.x, 0.0, walk_speed * 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, walk_speed * 8.0 * delta)
			rotation.y = rotate_toward(rotation.y, _ponto_giro, turn_speed * delta)
			if _parada_relogio <= 0.0:
				_soltar_ponto()

	move_and_slide()
	_animate(delta)


static func _carregar_pontos() -> void:
	if _pontos_lidos:
		return
	_pontos_lidos = true
	var txt := FileAccess.get_file_as_string(
		"res://assets/3d_model/city/pontos_de_parada.json")
	if txt.is_empty():
		return
	var d = JSON.parse_string(txt)
	if typeof(d) == TYPE_DICTIONARY:
		_pontos = d.get("pontos", [])


func _pensar_em_parar(delta: float) -> void:
	# so interrompe quem esta vagando sozinho: quem esta no meio de uma
	# conversa ou de uma catada termina o que comecou
	if _pontos.is_empty() or state != State.WANDER or partner != null:
		return
	_proxima_parada -= delta
	if _proxima_parada > 0.0:
		return
	_proxima_parada = randf_range(intervalo_de_parada.x, intervalo_de_parada.y)
	_procurar_ponto()


func _procurar_ponto() -> void:
	"""Pega o ponto livre mais perto, com um pouco de aleatorio pra dois NPCs
	que saem juntos nao irem sempre pro mesmo lugar."""
	var melhor := -1
	var melhor_d := alcance_do_ponto * alcance_do_ponto
	var passo := maxi(1, _pontos.size() / 90)   # amostra: a lista e grande
	var inicio := _rng.randi_range(0, passo - 1) if passo > 1 else 0
	for i in range(inicio, _pontos.size(), passo):
		if _reservados.has(i):
			continue
		var pt: Dictionary = _pontos[i]
		var dx := float(pt["x"]) - global_position.x
		var dz := float(pt["z"]) - global_position.z
		var d := dx * dx + dz * dz
		if d < melhor_d:
			melhor_d = d
			melhor = i
	if melhor < 0:
		return
	var pt: Dictionary = _pontos[melhor]
	_ponto_idx = melhor
	_reservados[melhor] = get_instance_id()
	_ponto_pos = Vector3(float(pt["x"]), float(pt["y"]), float(pt["z"]))
	_ponto_giro = float(pt["g"])
	_ponto_altura = float(pt.get("h", 0.0))
	_ponto_tipo = String(pt.get("t", "encostar"))
	_encosto_lado = 1.0 if _rng.randf() < 0.5 else -1.0
	_parada = Parada.INDO
	_parada_relogio = paciencia_ate_chegar
	# `road_only` arrastaria o NPC de volta pro asfalto no meio do caminho: o
	# banco da praca e o pe do muro estao, por definicao, FORA da rua
	road_only = false
	_repath = 0.0


func _chegou_no_ponto() -> void:
	_parada = Parada.PARADO
	_parada_relogio = randf_range(duracao_da_parada.x, duracao_da_parada.y)
	velocity.x = 0.0
	velocity.z = 0.0
	# encaixa no lugar: sentado torto no banco denuncia mais do que ninguem
	# sentado. O y NAO e forcado — quem levanta o corpo ate o assento e o
	# `desloca_quadril` da pose, pra o colisor continuar pisando no chao.
	global_position.x = _ponto_pos.x
	global_position.z = _ponto_pos.z


func _soltar_ponto() -> void:
	if _ponto_idx >= 0 and _reservados.get(_ponto_idx, 0) == get_instance_id():
		_reservados.erase(_ponto_idx)
	_ponto_idx = -1
	if _parada != Parada.NENHUMA:
		_parada = Parada.NENHUMA
		road_only = true
		state = State.WANDER
		_pick_wander_target()


func esta_parado() -> bool:
	return _parada == Parada.PARADO
