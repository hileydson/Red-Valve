extends CharacterBody3D
class_name ShadowRock

## "The Shadow Rock": um humanoide feito de pedra solta. Nao e uma estatua nem
## um golem esculpido — e um monte de rochas grandes e pequenas se segurando na
## forma de um homem, com duas brasas no lugar dos olhos.
##
## O QUE ELE E, EM UMA FRASE: um inimigo que se DESMONTA em tela. Cada tiro
## arranca pedra dele de verdade — a pedra sobe, cai no chao e FICA la alguns
## segundos —, e de vez em quando o que se solta e um membro inteiro: a mao, o
## antebraco, o ombro com o braco junto, um pe, a cabeca. O membro cai girando e
## se espatifa no chao. Ele continua vivo e lutando sem ele.
##
## Por que ele NAO usa a `enemy.gd`/`enemy.tscn`: pelo mesmo motivo do Shadow
## Seraph, e com mais forca ainda. Aquela classe e construida em volta de um
## `.glb` com Skeleton3D e AnimationTree. Este corpo e um AMONTOADO DE PEDRAS
## INDIVIDUAIS penduradas num rig de pivos — tem de ser, porque a mecanica dele
## e justamente tirar essas pedras uma a uma. Num modelo com esqueleto e pele
## unica nao ha "uma pedra" pra arrancar: so um vertice de uma malha continua.
##
## O que ele mantem igual e o CONTRATO que o resto do jogo consulta: grupo
## "enemies", `dead`, sinal `died`, `cutscene_mode`, `player`, `take_damage()`,
## `remover_em_silencio()` e a barra de chefe. Assim o amuleto, a arena
## (`battlefield.gd`), o spawner da cidade e o tiro do jogador funcionam sem
## saber que ele e diferente. A cena (`shadow_rock.tscn`) e a mesma casca
## Node3D + filho "enemy" das outras.
##
## Poderes (a duracao de cada um foi pedida longa DE PROPOSITO — o golpe tem de
## ser visto se formando, e a pedra crescendo e metade do efeito):
##   1. pedregulho — 7 s. Cresce uma pedra gigante na mao, ele pega com as duas
##                   e arremessa no ponto onde o jogador estava. 45 de dano.
##   2. espada     — 8 s. Junta as maos, a lamina de pedra cresce entre elas, e
##                   o corte manda uma leva de lascas pra frente. 35 de dano.
##   defesa: parede — 10 s. Ergue as maos e uma parede sobe pedra por pedra
##                   entre os dois; enquanto ela esta la o TIRO DO JOGADOR BATE
##                   NELA, e depois ela avanca e esmaga. 30 de dano.
##
## Na cidade ele so usa o pedregulho — mesma regra do Seraph: na rua o encontro
## se anuncia, a luta completa e coisa da arena.

const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")
const FX := preload("res://scripts/effects/seraph_fx.gd")
const RockFX := preload("res://scripts/effects/rock_fx.gd")
const Pedregulho := preload("res://scripts/effects/rock_boulder.gd")
const Lascas := preload("res://scripts/effects/rock_shards.gd")
const Parede := preload("res://scripts/effects/rock_wall.gd")
const Membro := preload("res://scripts/effects/rock_limb.gd")

signal died

enum State { VAGANDO, PERSEGUINDO, ACAO, MORTO }
enum Act { NENHUMA, PEDREGULHO, ESPADA, PAREDE }

# ------------------------------------------------------------------ ajustes

@export_group("Identidade")
@export var enemy_name: String = "THE SHADOW ROCK"
@export var max_health: int = 300
@export var iron_rusks_value: int = 11
## Altura total, em metros. Ele e largo e pesado; a leitura e de bloco andando.
@export var altura: float = 2.9

@export_group("Movimento")
## Passo de quando esta so vagando pela cidade. Pedra nao tem pressa.
@export var walk_speed: float = 1.25
## Passo de quando esta em cima do jogador.
@export var chase_speed: float = 2.45
## Giro do corpo. Baixo: o peso dele esta todo na inercia.
@export var turn_speed: float = 2.1
## A partir daqui ele percebe o jogador e parte pra briga.
@export var distance_to_aproach: float = 30.0
## Distancia que ele tenta manter enquanto conjura.
@export var distancia_ideal: float = 9.0
@export var use_navigation: bool = true
## Raio em que ele fica vagando em volta de onde nasceu.
@export var wander_radius: float = 40.0
## So anda onde ha rua (mesmo grid das sombras).
@export var road_only: bool = true

@export_group("Dano dos poderes")
@export var dano_pedregulho: int = 45
@export var dano_lascas: int = 35
@export var dano_parede: int = 30

@export_group("Esperas entre poderes")
@export var espera_pedregulho_min: float = 7.0
@export var espera_pedregulho_max: float = 12.0
@export var espera_espada_min: float = 13.0
@export var espera_espada_max: float = 21.0
@export var espera_parede_min: float = 19.0
@export var espera_parede_max: float = 30.0
## Respiro obrigatorio entre o fim de um poder e o comeco do proximo.
@export var respiro_entre_poderes: float = 2.1

@export_group("Corpo que se desmonta")
## Chance, por dano recebido, de um membro INTEIRO se soltar.
@export_range(0.0, 1.0) var chance_perder_membro: float = 0.17
## Quantas pedras soltas saem voando a cada dano.
@export var pedras_por_dano_min: int = 1
@export var pedras_por_dano_max: int = 3
## Quanto tempo os cacos ficam no chao antes de afundar.
@export var permanencia_cacos: float = 8.0

@export_group("Desempenho")
## Acima desta distancia do jogador ele congela (nao processa fisica).
@export var activation_distance: float = 130.0

# ------------------------------------------------------------------- estado

var player: Node3D = null
var dead: bool = false
var cutscene_mode: bool = false
var current_health: int

var state: State = State.VAGANDO
var _act: int = Act.NENHUMA
var _fase: int = 0
var _fase_t: float = 0.0

var _t: float = 0.0
var _passo_fase: float = 0.0
var _respiro: float = 0.0
var _esperas: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _nav: NavigationAgent3D
var _nav_disponivel: bool = false
var _update_nav: float = 0.0
var _home: Vector3 = Vector3.ZERO
var _destino: Vector3 = Vector3.ZERO
var _troca_destino: float = 0.0
var _road_timer: float = 0.0
var _spawn_grace: float = 1.5
var _congelado: bool = false
var _timer_proximidade: Timer
var _ultimo_toque: float = 0.0

# rig
var _rig: Node3D
var _hips: Node3D
var _spine: Node3D
var _neck: Node3D
var _ombro_l: Node3D
var _ombro_r: Node3D
var _cotovelo_l: Node3D
var _cotovelo_r: Node3D
var _mao_l: Node3D
var _mao_r: Node3D
var _coxa_l: Node3D
var _coxa_r: Node3D
var _joelho_l: Node3D
var _joelho_r: Node3D
var _ancora_maos: Node3D
var _olho_l: MeshInstance3D
var _olho_r: MeshInstance3D
var _luz_olhos: OmniLight3D
var _fogo_olhos: GPUParticles3D
var _po_corpo: GPUParticles3D

## Cada membro: {"pivo": Node3D, "pedras": Array[MeshInstance3D],
##               "perdido": bool, "solta": bool, "minimo": int}
var _membros: Dictionary = {}
var _pedras_perdidas: int = 0
var _pedras_total: int = 0

# poderes em curso
var _pedregulho: Node3D = null
var _espada: Node3D = null
var _parede: Node3D = null

# audio
var _passos: AudioStreamPlayer3D
var _grunhido: AudioStreamPlayer3D
var _grunhido_atk: AudioStreamPlayer3D
var _grunhido_dano: AudioStreamPlayer3D
var _grunhido_morte: AudioStreamPlayer3D
var _tombo: AudioStreamPlayer3D

# ------------------------------------------------------- tempos dos poderes
# Cada poder e uma sequencia de fases, e as somas batem com o que foi pedido:
# pedregulho 7 s, espada 8 s, parede 10 s. As constantes sao lidas tanto pela
# corrotina que dispara os efeitos quanto pela funcao que poe o corpo na pose —
# e o que mantem o gesto colado no efeito sem nenhum AnimationPlayer.

## 1,0 + 3,0 + 1,1 + 0,55 + 1,35 = 7,0 s
const PED_ERGUE := 1.00
const PED_CRESCE := 3.00
const PED_PEGA := 1.10
const PED_ARREMESSA := 0.55
const PED_VOLTA := 1.35

## 1,2 + 3,4 + 1,1 + 0,9 + 1,4 = 8,0 s
const ESP_JUNTA := 1.20
const ESP_CRESCE := 3.40
const ESP_ERGUE := 1.10
const ESP_CORTA := 0.90
const ESP_VOLTA := 1.40

## 1,3 + 2,7 + 2,2 + 3,0 + 0,8 = 10,0 s
const PAR_ERGUE := 1.30
const PAR_CONSTROI := 2.70
const PAR_SEGURA := 2.20
const PAR_EMPURRA := 3.00
const PAR_VOLTA := 0.80

## A quantos metros na frente dele a parede sobe, e quanto ela anda depois.
const PAREDE_DISTANCIA := 3.2
const PAREDE_AVANCO := 7.5

const GRAVIDADE := 20.0
## Tolerancia horizontal ate o navmesh pra considerar que ele serve aqui. Na
## cidade da stage_1 o navmesh fica a ~200 m: ele persegue em linha reta.
const NAV_TOLERANCIA := 3.0


# =========================================================== ciclo de vida

func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	current_health = max_health
	_home = global_position
	_destino = _home

	_monta_corpo()
	_monta_colisoes()
	_monta_audio()
	_monta_nav()
	ShadowRoads.setup(get_tree())

	player = _acha_player()

	# Primeiros usos sorteados baixos: o repertorio dele tem so tres coisas e
	# cada uma leva quase dez segundos. Esperar um minuto pela primeira seria
	# uma briga inteira sem ver o inimigo fazer nada.
	_esperas = {
		Act.PEDREGULHO: _rng.randf_range(2.0, 4.0),
		Act.ESPADA: _rng.randf_range(6.0, 10.0),
		Act.PAREDE: _rng.randf_range(8.0, 14.0),
	}

	_timer_proximidade = Timer.new()
	_timer_proximidade.wait_time = 0.5
	_timer_proximidade.autostart = true
	add_child(_timer_proximidade)
	_timer_proximidade.timeout.connect(_checa_proximidade)
	_checa_proximidade()


func _checa_proximidade() -> void:
	if dead:
		if is_instance_valid(_timer_proximidade):
			_timer_proximidade.stop()
		return
	if not is_instance_valid(player):
		player = _acha_player()
		if not is_instance_valid(player):
			return

	var d := global_position.distance_to(player.global_position)
	# Histerese: so descongela dentro do raio e so congela bem depois dele.
	if d <= activation_distance and _congelado:
		_congelado = false
		velocity = Vector3.ZERO
		_spawn_grace = 1.5
		set_physics_process(true)
	elif d > activation_distance * 1.3 and not _congelado:
		_congelado = true
		velocity = Vector3.ZERO
		set_physics_process(false)


func _acha_player() -> Node3D:
	if not is_inside_tree():
		return null
	var p := get_tree().get_first_node_in_group("player")
	if p is Node3D:
		return p as Node3D
	return null


## Estamos na arena? A espada e a parede so existem la.
func _na_arena() -> bool:
	if not is_inside_tree() or get_tree() == null:
		return false
	var cena := get_tree().current_scene
	return cena != null and cena.scene_file_path.contains("battlefield")


# ================================================================ construcao

## Um osso do rig: pivo + um AMONTOADO de pedras penduradas nele, descendo do
## pivo ate `-comp`. Cada pedra e um MeshInstance3D proprio porque cada uma
## delas pode ser arrancada depois — e essa a razao de existir deste inimigo.
##
## `raio` e a grossura do membro; `quantos` e quantas pedras formam o membro.
func _osso(pai: Node3D, nome: String, comp: float, raio: float, onde: Vector3,
		quantos: int, solta: bool, minimo: int = 1) -> Node3D:
	var pivo := Node3D.new()
	pivo.name = nome.capitalize()
	pivo.position = onde
	pai.add_child(pivo)
	_registra(nome, pivo, _pedras_no_osso(pivo, comp, raio, quantos), solta, minimo)
	return pivo


func _pedras_no_osso(pivo: Node3D, comp: float, raio: float, quantos: int) -> Array:
	var pedras: Array = []
	for i in quantos:
		# distribui ao longo do osso, com folga nas pontas
		var f := (float(i) + 0.5) / float(quantos)
		var onde := Vector3(
			_rng.randf_range(-raio, raio) * 0.55,
			-comp * f,
			_rng.randf_range(-raio, raio) * 0.55)
		# as pedras do meio do membro sao maiores; as das pontas afinam
		var mingua := 1.0 - absf(f - 0.5) * 0.55
		# 1,95 e nao 2,25: com as rochas do Blender (cortadas por planos, mais
		# volumosas que a esfera amassada de antes) o multiplicador antigo
		# engordava o membro ate ele encostar no tronco e a silhueta virar uma
		# pilha. O volume que faltou vem de MAIS pedras, nao de pedras maiores.
		var b := RockFX.bloco(pivo, onde, raio * 1.95 * mingua, _rng, 0.38)
		pedras.append(b)
	return pedras


func _registra(nome: String, pivo: Node3D, pedras: Array, solta: bool, minimo: int) -> void:
	_membros[nome] = {
		"pivo": pivo,
		"pedras": pedras,
		"perdido": false,
		"solta": solta,
		"minimo": minimo,
	}
	_pedras_total += pedras.size()


func _monta_corpo() -> void:
	var h := altura
	var perna := h * 0.40
	var coxa := perna * 0.52
	var canela := perna - coxa
	var torso := h * 0.34
	var cabeca_r := h * 0.095
	# Quadril e ombros LARGOS. Este e o numero que mais decide se ele le como
	# humanoide: com ombros estreitos, um corpo montado de pedras empilhadas
	# vira uma coluna de entulho e os bracos desaparecem dentro do torso.
	var quadril_w := h * 0.125
	var ombro_w := h * 0.215
	# Bracos longos e grossos: a silhueta dele e de gorila de pedra, nao de
	# pessoa. E o que faz o pedregulho de um metro caber na mao sem parecer
	# desenho fora de escala.
	var braco := h * 0.44
	var antebraco := braco * 0.46
	var superior := braco - antebraco

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0, perna, 0)
	_rig.add_child(_hips)
	var pedras_quadril: Array = []
	for i in 5:
		var ang := TAU * float(i) / 5.0
		pedras_quadril.append(RockFX.bloco(_hips,
			Vector3(cos(ang) * h * 0.105, _rng.randf_range(-0.02, 0.02) * h, sin(ang) * h * 0.058),
			h * 0.145, _rng, 0.3))
	_registra("quadril", _hips, pedras_quadril, false, 4)

	_spine = Node3D.new()
	_spine.name = "Spine"
	_hips.add_child(_spine)
	# Torax: trapezio de pedra, estreito na cintura e largo no peito. Montado em
	# tres fiadas em anel — e a irregularidade dos aneis que da o peito dele,
	# e a largura crescente que da a leitura de tronco e nao de pilha.
	var pedras_torso: Array = []
	for fiada in 3:
		var fy := torso * (0.20 + 0.33 * float(fiada))
		var largura := h * 0.135 * (0.62 + 0.30 * float(fiada))
		# Bloco no MIOLO antes do anel. So o anel deixa o tronco oco: de frente
		# da pra ver o ceu entre os ombros, e um corpo vazado por dentro nao le
		# como corpo. O anel continua sendo quem desenha o contorno irregular;
		# este bloco so garante que ha pedra atras dele.
		pedras_torso.append(RockFX.bloco(_spine, Vector3(0, fy, 0),
			h * (0.150 + 0.030 * float(fiada)), _rng, 0.22))
		var quantas := 5 + fiada
		for i in quantas:
			var ang2 := TAU * float(i) / float(quantas) + float(fiada) * 0.6
			pedras_torso.append(RockFX.bloco(_spine,
				Vector3(cos(ang2) * largura, fy, sin(ang2) * largura * 0.62),
				h * (0.105 + 0.022 * float(fiada)), _rng, 0.34))
	# trave dos ombros: duas pedras grandes ligando o peito aos dois bracos
	for i in 2:
		var lado := 1.0 if i == 0 else -1.0
		pedras_torso.append(RockFX.bloco(_spine,
			Vector3(lado * ombro_w * 0.55, torso * 0.90, 0), h * 0.135, _rng, 0.2))
	_registra("torso", _spine, pedras_torso, false, 12)

	# pescoco e cabeca
	_neck = Node3D.new()
	_neck.name = "Neck"
	_neck.position = Vector3(0, torso * 0.98, 0)
	_spine.add_child(_neck)
	# Pescoco CURTO e grosso, e a cabeca baixa, quase encaixada entre os ombros.
	# Com a cabeca alta sobra um vao entre ela e o tronco e ela parece flutuar —
	# num corpo feito de pedras soltas, um vao le como pedaco faltando.
	var pedras_cabeca: Array = []
	pedras_cabeca.append(RockFX.bloco(_neck, Vector3(0, h * 0.020, 0), h * 0.090, _rng, 0.2))
	pedras_cabeca.append(RockFX.bloco(_neck, Vector3(0, h * 0.030 + cabeca_r * 0.55, 0),
		cabeca_r * 1.9, _rng, 0.18))
	for i in 4:
		var ang3 := TAU * float(i) / 4.0 + 0.5
		pedras_cabeca.append(RockFX.bloco(_neck,
			Vector3(cos(ang3) * cabeca_r * 0.72, h * 0.030 + cabeca_r * (0.3 + _rng.randf() * 0.75),
				sin(ang3) * cabeca_r * 0.66),
			cabeca_r * _rng.randf_range(0.7, 1.1), _rng, 0.4))
	_registra("cabeca", _neck, pedras_cabeca, true, 0)

	_monta_olhos(cabeca_r, h)

	# bracos
	_ombro_l = _osso(_spine, "ombro_l", superior, h * 0.064, Vector3(ombro_w, torso * 0.86, 0), 6, true, 2)
	_cotovelo_l = _osso(_ombro_l, "antebraco_l", antebraco, h * 0.056, Vector3(0, -superior, 0), 5, true, 2)
	_mao_l = _monta_mao(_cotovelo_l, "mao_l", antebraco, h)

	_ombro_r = _osso(_spine, "ombro_r", superior, h * 0.064, Vector3(-ombro_w, torso * 0.86, 0), 6, true, 2)
	_cotovelo_r = _osso(_ombro_r, "antebraco_r", antebraco, h * 0.056, Vector3(0, -superior, 0), 5, true, 2)
	_mao_r = _monta_mao(_cotovelo_r, "mao_r", antebraco, h)

	# pernas: grossas e curtas. Nao se soltam — sem elas ele nao andaria, e o
	# proposito da mutilacao aqui e ele CONTINUAR lutando aos pedacos.
	_coxa_l = _osso(_hips, "coxa_l", coxa, h * 0.078, Vector3(quadril_w, 0, 0), 4, false, 2)
	_joelho_l = _osso(_coxa_l, "canela_l", canela, h * 0.066, Vector3(0, -coxa, 0), 4, false, 2)
	_monta_pe(_joelho_l, "pe_l", canela, h)
	_coxa_r = _osso(_hips, "coxa_r", coxa, h * 0.078, Vector3(-quadril_w, 0, 0), 4, false, 2)
	_joelho_r = _osso(_coxa_r, "canela_r", canela, h * 0.066, Vector3(0, -coxa, 0), 4, false, 2)
	_monta_pe(_joelho_r, "pe_r", canela, h)

	# Ancora entre as duas maos, na frente do peito: e onde o pedregulho passa a
	# ser segurado e onde a espada cresce.
	# Na altura do PEITO e bem a frente, que e onde as duas maos se encontram
	# nas poses de arremesso e de corte. Estava baixa e curta demais: a pedra e
	# a lamina nasciam coladas no corpo e, com o braco levantado, acabavam em
	# cima da cabeca dele.
	_ancora_maos = Node3D.new()
	_ancora_maos.name = "AncoraMaos"
	_ancora_maos.position = Vector3(0, torso * 0.80, -h * 0.40)
	_spine.add_child(_ancora_maos)

	_monta_po_do_corpo(h)
	set_meta("body_height", h)


func _monta_mao(cotovelo: Node3D, nome: String, antebraco: float, h: float) -> Node3D:
	var pivo := Node3D.new()
	pivo.name = nome.capitalize()
	pivo.position = Vector3(0, -antebraco - h * 0.020, 0)
	cotovelo.add_child(pivo)

	var pedras: Array = []
	# punho: uma pedra grande e tres dedos de pedra
	pedras.append(RockFX.bloco(pivo, Vector3.ZERO, h * 0.125, _rng, 0.25))
	for i in 3:
		pedras.append(RockFX.bloco(pivo,
			Vector3((float(i) - 1.0) * h * 0.038, -h * 0.058, -h * 0.026),
			h * 0.056, _rng, 0.3))
	_registra(nome, pivo, pedras, true, 0)
	return pivo


func _monta_pe(joelho: Node3D, nome: String, canela: float, h: float) -> Node3D:
	var pivo := Node3D.new()
	pivo.name = nome.capitalize()
	pivo.position = Vector3(0, -canela, 0)
	joelho.add_child(pivo)

	var pedras: Array = []
	pedras.append(RockFX.bloco(pivo, Vector3(0, -h * 0.020, -h * 0.034), h * 0.140, _rng, 0.22))
	pedras.append(RockFX.bloco(pivo, Vector3(0, -h * 0.012, -h * 0.098), h * 0.085, _rng, 0.3))
	_registra(nome, pivo, pedras, true, 0)
	return pivo


## Os olhos: duas brasas pequenas. SUTIS de proposito — ele e pedra com alguma
## coisa viva presa dentro, nao uma fornalha. Uma luz so pros dois (o renderer
## Mobile aceita 8 omnis por malha; gastar duas aqui seria desperdicio) e um
## fiapo de chama saindo de cada orbita.
func _monta_olhos(cabeca_r: float, h: float) -> void:
	# Acompanha a altura em que `_monta_corpo` assentou o bloco do cranio.
	var y := h * 0.030 + cabeca_r * 0.70
	var z := -cabeca_r * 0.95
	# Energia BAIXA (0,7 contra os 9,0 do Seraph). O material do `FX.emissivo` e
	# aditivo e unshaded, entao a cor final e albedo + emissao*energia: qualquer
	# valor acima de ~1 estoura pra branco e as duas brasas viram uma bola de luz
	# do tamanho da cabeca. O pedido era o oposto — duas bolinhas de fogo sutis.
	var mat := FX.emissivo(Color(1.0, 0.44, 0.10), 0.7)

	var malha := SphereMesh.new()
	malha.radius = cabeca_r * 0.15
	malha.height = cabeca_r * 0.30
	malha.radial_segments = 10
	malha.rings = 6

	_olho_l = MeshInstance3D.new()
	_olho_l.mesh = malha
	_olho_l.material_override = mat
	_olho_l.position = Vector3(cabeca_r * 0.38, y, z)
	_olho_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_neck.add_child(_olho_l)

	_olho_r = MeshInstance3D.new()
	_olho_r.mesh = malha
	_olho_r.material_override = mat
	_olho_r.position = Vector3(-cabeca_r * 0.38, y, z)
	_olho_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_neck.add_child(_olho_r)

	# Alcance CURTO (1,5 m). Com os 3,4 m de antes a luz laranja das orbitas
	# alcancava os pes dele e pintava o corpo inteiro de ferrugem — um golem de
	# pedra cinza lido como criatura de lava por causa de uma luz de enfeite.
	# Ela existe pra acender a testa e as pedras em volta dos olhos, so isso.
	_luz_olhos = OmniLight3D.new()
	_luz_olhos.light_color = Color(1.0, 0.42, 0.12)
	_luz_olhos.light_energy = 0.22
	_luz_olhos.omni_range = 0.45
	_luz_olhos.omni_attenuation = 2.6
	_luz_olhos.shadow_enabled = false
	# Bem NA FRENTE do rosto, nao encostada nele: colada na pedra, uma luz
	# fraca ainda estoura as faces a cinco centimetros dela e a cabeca inteira
	# acende. Afastada, ela ilumina o ar em volta das orbitas — que e o que o
	# jogador deve ver.
	_luz_olhos.position = Vector3(0, y, z - cabeca_r * 0.55)
	_neck.add_child(_luz_olhos)

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(cabeca_r * 0.46, cabeca_r * 0.06, 0.01)
	proc.direction = Vector3(0, 1, -0.2)
	proc.spread = 12.0
	proc.initial_velocity_min = 0.12
	proc.initial_velocity_max = 0.45
	proc.gravity = Vector3(0, 0.5, 0)
	proc.damping_min = 0.8
	proc.damping_max = 2.0
	proc.scale_min = 0.012
	proc.scale_max = 0.038
	proc.scale_curve = FX.curva_pico(0.2)
	# Nada de branco no inicio da rampa: a particula e ADITIVA, e um branco de
	# alpha alto colado na pedra estoura a cabeca inteira. A brasa comeca ambar.
	proc.color_ramp = FX.rampa(
		[Color(1.0, 0.62, 0.22, 0.38), Color(1.0, 0.32, 0.05, 0.22), Color(0.2, 0.03, 0.01, 0.0)],
		[0.0, 0.45, 1.0])

	_fogo_olhos = GPUParticles3D.new()
	_fogo_olhos.amount = 10
	_fogo_olhos.lifetime = 0.6
	_fogo_olhos.process_material = proc
	# Quad do `rock_fx`, nao o do Seraph: e o unico que respeita `scale_min` /
	# `scale_max` (ver `RockFX._quad`). Com o do Seraph estas brasinhas de 3 cm
	# saiam do tamanho cheio do quad e viravam uma bola branca na cabeca.
	_fogo_olhos.draw_pass_1 = RockFX.quad_brasa()
	_fogo_olhos.position = Vector3(0, y, z)
	_fogo_olhos.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
	_neck.add_child(_fogo_olhos)


## Po e pedrinha caindo do corpo o tempo todo. E o detalhe que diz "isto esta
## se desmanchando enquanto anda" sem custar nada: uma particula so, presa no
## torso, emitindo devagar.
func _monta_po_do_corpo(h: float) -> void:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(h * 0.16, h * 0.30, h * 0.12)
	proc.direction = Vector3(0, -1, 0)
	proc.spread = 25.0
	proc.initial_velocity_min = 0.1
	proc.initial_velocity_max = 0.5
	proc.gravity = Vector3(0, -7.0, 0)
	proc.damping_min = 0.2
	proc.damping_max = 1.0
	proc.scale_min = 0.015
	proc.scale_max = 0.055
	proc.color_ramp = FX.rampa(
		[Color(0.55, 0.52, 0.49, 0.7), Color(0.4, 0.38, 0.36, 0.4), Color(0.3, 0.29, 0.28, 0.0)],
		[0.0, 0.5, 1.0])

	_po_corpo = GPUParticles3D.new()
	_po_corpo.amount = 16
	_po_corpo.lifetime = 1.1
	_po_corpo.process_material = proc
	_po_corpo.draw_pass_1 = RockFX.quad_po()
	_po_corpo.local_coords = false
	_po_corpo.position = Vector3(0, h * 0.55, 0)
	_po_corpo.visibility_aabb = AABB(Vector3.ONE * -4.0, Vector3.ONE * 8.0)
	add_child(_po_corpo)


func _monta_colisoes() -> void:
	var h := altura
	var corpo := CollisionShape3D.new()
	corpo.name = "body_shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = maxf(h * 0.92, 1.2)
	corpo.shape = cap
	corpo.position = Vector3(0, h * 0.46, 0)
	add_child(corpo)

	# "heart": area de acerto critico, igual a dos outros inimigos (camada 8, a
	# que o raycast da arma procura).
	var heart := Area3D.new()
	heart.name = "heart"
	heart.collision_layer = 8
	heart.collision_mask = 0
	heart.add_to_group("enemies")
	heart.set_script(load("res://scripts/enemies/head.gd"))
	var hc := CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = h * 0.11
	hc.shape = hs
	heart.add_child(hc)
	# No MEIO DO PEITO (0,66 h), nao la em cima como nos outros inimigos. O
	# torso dele vai de 1,16 m a 2,13 m: a altura de 0,80 h que o Seraph usa
	# cairia na cabeca, e alem de premiar o tiro errado deixava a luz vermelha
	# do acerto critico acesa dentro do cranio.
	heart.position = Vector3(0, h * 0.66, 0)
	add_child(heart)
	_abafa_luz_do_heart(heart)

	# Toque: na cidade, encostar nele leva o jogador pra arena.
	var toque := Area3D.new()
	toque.name = "toque"
	toque.collision_layer = 0
	toque.collision_mask = 1
	var tc := CollisionShape3D.new()
	var ts := CapsuleShape3D.new()
	ts.radius = 0.95
	ts.height = maxf(h, 1.4)
	tc.shape = ts
	toque.add_child(tc)
	toque.position = Vector3(0, h * 0.46, 0)
	add_child(toque)
	toque.body_entered.connect(_no_toque)


## A `head.gd` acende uma luz vermelha pulsante dentro da area de acerto
## critico — o aviso de "mire aqui" que todo inimigo do jogo tem. Nos outros
## ela mal aparece: o corpo deles e um `.glb` escuro, e o do Seraph nem e
## iluminado (shader unshaded ignora luz). Aqui o corpo e pedra clara e
## ILUMINADA, e com o alcance padrao de 1 m o torso inteiro ficava vermelho.
##
## Abafa-la SO neste inimigo (e nao na `head.gd`, que e de todo mundo) deixa o
## aviso onde ele funciona melhor: uma brasa vermelha pulsando entre as pedras
## do peito, que e o buraco pra onde o jogador deve atirar.
##
## Mexe no ALCANCE e na atenuacao, nunca na energia: a energia esta sendo
## animada por um tween em laco que a `head.gd` deixou rodando, e escrever nela
## aqui so criaria dois donos brigando pela mesma propriedade. Encurtar o
## alcance contem o mesmo pulso, com o mesmo ritmo, dentro do peito.
func _abafa_luz_do_heart(heart: Area3D) -> void:
	for c in heart.get_children():
		if not (c is OmniLight3D):
			continue
		var luz: OmniLight3D = c
		luz.omni_range = 0.34
		luz.omni_attenuation = 3.0
		luz.light_indirect_energy = 0.0


func _monta_audio() -> void:
	_passos = _som("res://assets/sounds/enemies/the_cobalt_husker/steps.mp3", -6.0, 0.48)
	_grunhido = _som("res://assets/sounds/enemies/growl_1.mp3", -7.0, 0.52)
	_grunhido_atk = _som("res://assets/sounds/enemies/inimigo_1_voice_attack.mp3", -4.0, 0.55)
	_grunhido_dano = _som("res://assets/sounds/enemies/growl_3.mp3", -6.0, 0.58)
	_grunhido_morte = _som("res://assets/sounds/enemies/growl_2.mp3", -1.0, 0.44)
	_tombo = _som("res://assets/sounds/enemies/the_cobalt_husker/drop_dead.mp3", 0.0, 0.6)

	var t := Timer.new()
	t.wait_time = _rng.randf_range(8.0, 15.0)
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		t.wait_time = _rng.randf_range(8.0, 16.0)
		if not dead and _grunhido != null and not _grunhido.playing:
			_grunhido.play())


## Todas as vozes dele saem com pitch bem abaixo do original: e o que faz um
## rosnado de zumbi virar o ronco de uma coisa de tres toneladas.
func _som(caminho: String, db: float, pitch: float) -> AudioStreamPlayer3D:
	var stream := load(caminho) as AudioStream
	if stream == null:
		return null
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.volume_db = db
	a.pitch_scale = pitch
	a.unit_size = 16.0
	a.max_distance = 60.0
	add_child(a)
	return a


func _monta_nav() -> void:
	if not use_navigation:
		return
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.7
	_nav.target_desired_distance = 0.9
	_nav.avoidance_enabled = false
	add_child(_nav)


# =================================================================== loop

func _physics_process(delta: float) -> void:
	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	if not dead and _spawn_grace <= 0.0 and global_position.y < -10.0:
		# Caiu fora do mapa: nao e morte, nao rende iron rusks nem barra.
		remover_em_silencio()
		return

	_t += delta
	_fase_t += delta

	if dead:
		if _passos != null:
			_passos.stop()
		_anima(delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	else:
		velocity.y = 0.0

	if not is_instance_valid(player):
		player = _acha_player()

	if cutscene_mode:
		velocity.x = move_toward(velocity.x, 0.0, chase_speed)
		velocity.z = move_toward(velocity.z, 0.0, chase_speed)
		if is_instance_valid(player):
			_encara(player.global_position, delta)
		_anima(delta)
		move_and_slide()
		return

	_respiro = maxf(0.0, _respiro - delta)
	for k in _esperas.keys():
		_esperas[k] = float(_esperas[k]) - delta

	if _act != Act.NENHUMA:
		_anda_acao(delta)
	else:
		_pensa(delta)

	_anima(delta)
	move_and_slide()


func _pensa(delta: float) -> void:
	var d := INF
	if is_instance_valid(player):
		d = global_position.distance_to(player.global_position)

	# Na arena ele nunca "vaga": o jogador esta ali, a luta e agora.
	var briga := _na_arena() or d <= distance_to_aproach
	state = State.PERSEGUINDO if briga else State.VAGANDO

	if not briga or not is_instance_valid(player):
		_vaga(delta)
		return

	_encara(player.global_position, delta)

	if _respiro <= 0.0:
		var escolha: int = _escolhe_poder(d)
		if escolha != Act.NENHUMA:
			_comeca(escolha)
			return

	# Sem poder pronto: mantem a distancia de conjuracao.
	var dir := (player.global_position - global_position)
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	if d > distancia_ideal + 1.5:
		_caminha(dir, chase_speed, delta)
	elif d < distancia_ideal - 2.5:
		_caminha(-dir, chase_speed * 0.55, delta)
	else:
		var lado := Vector3(-dir.z, 0.0, dir.x) * (1.0 if int(_t * 0.22) % 2 == 0 else -1.0)
		_caminha(lado, chase_speed * 0.4, delta)


func _vaga(delta: float) -> void:
	_troca_destino -= delta
	if _troca_destino <= 0.0 or global_position.distance_to(_destino) < 1.5:
		_sorteia_destino()

	if road_only:
		_segura_na_rua(delta)

	var dir := _direcao_para(_destino)
	if dir == Vector3.ZERO:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)
		return
	_caminha(dir, walk_speed, delta)
	_encara(global_position + dir, delta)


func _sorteia_destino() -> void:
	_troca_destino = _rng.randf_range(10.0, 22.0)
	for _i in 10:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(wander_radius * 0.25, wander_radius)
		var cand := _home + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if not road_only or ShadowRoads.is_road(cand):
			_destino = cand
			if _nav != null:
				_nav.target_position = _destino
			return
	_destino = _home


func _segura_na_rua(delta: float) -> void:
	_road_timer -= delta
	if _road_timer > 0.0:
		return
	_road_timer = 0.4
	if ShadowRoads.is_road(global_position):
		return
	var p := ShadowRoads.nearest(global_position, 25.0)
	if p != global_position:
		_destino = p
		_troca_destino = 8.0
		if _nav != null:
			_nav.target_position = _destino


func _direcao_para(ponto: Vector3) -> Vector3:
	_update_nav -= get_physics_process_delta_time()
	if _update_nav <= 0.0:
		_update_nav = 0.25
		_atualiza_nav_disponivel()
		if _nav != null:
			_nav.target_position = ponto

	var destino := ponto
	if _nav != null and _nav_disponivel and not _nav.is_navigation_finished():
		destino = _nav.get_next_path_position()

	var dir := destino - global_position
	dir.y = 0.0
	if dir.length() < 0.2:
		return Vector3.ZERO
	return dir.normalized()


func _atualiza_nav_disponivel() -> void:
	if not is_inside_tree():
		_nav_disponivel = false
		return
	var mapa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(mapa).is_empty():
		_nav_disponivel = false
		return
	var perto := NavigationServer3D.map_get_closest_point(mapa, global_position)
	_nav_disponivel = Vector2(perto.x - global_position.x, perto.z - global_position.z).length() <= NAV_TOLERANCIA


func _caminha(dir: Vector3, vel: float, delta: float) -> void:
	# Aceleracao baixa (3.0 contra os 5.0 do Seraph): ele tem inercia de pedra.
	velocity.x = lerp(velocity.x, dir.x * vel, delta * 3.0)
	velocity.z = lerp(velocity.z, dir.z * vel, delta * 3.0)


func _encara(alvo: Vector3, delta: float) -> void:
	var plano := Vector3(alvo.x, global_position.y, alvo.z)
	if global_position.distance_to(plano) < 0.3:
		return
	var desejado := atan2(global_position.x - alvo.x, global_position.z - alvo.z)
	rotation.y = lerp_angle(rotation.y, desejado, clampf(delta * turn_speed, 0.0, 1.0))


# ==================================================== roteiro dos poderes

func _escolhe_poder(d: float) -> int:
	# Fora da arena ele tem UM poder: o pedregulho. Na rua o encontro tem de ser
	# uma ameaca que se anuncia, nao uma luta completa no meio do transito.
	if not _na_arena():
		if float(_esperas[Act.PEDREGULHO]) <= 0.0 and d < 34.0:
			return Act.PEDREGULHO
		return Act.NENHUMA

	# A parede tem prioridade: ela e a resposta dele a levar dano, e se a hora
	# dela chegou no meio da briga e ela que sai.
	if float(_esperas[Act.PAREDE]) <= 0.0 and not is_instance_valid(_parede) and d < 26.0:
		return Act.PAREDE

	var prontos: Array[int] = []
	var pesos: Array[float] = []
	if float(_esperas[Act.PEDREGULHO]) <= 0.0 and d < 34.0:
		prontos.append(Act.PEDREGULHO)
		pesos.append(2.2)
	if float(_esperas[Act.ESPADA]) <= 0.0 and d < 22.0:
		prontos.append(Act.ESPADA)
		pesos.append(1.6)

	if prontos.is_empty():
		return Act.NENHUMA

	var total := 0.0
	for p in pesos:
		total += p
	var sorte := _rng.randf() * total
	for i in prontos.size():
		sorte -= pesos[i]
		if sorte <= 0.0:
			return prontos[i]
	return prontos[prontos.size() - 1]


func _comeca(a: int) -> void:
	if _act != Act.NENHUMA or dead:
		return
	_act = a
	state = State.ACAO
	_set_fase(0)
	if _grunhido_atk != null and not _grunhido_atk.playing:
		_grunhido_atk.play()

	match a:
		Act.PEDREGULHO:
			_esperas[Act.PEDREGULHO] = _rng.randf_range(espera_pedregulho_min, espera_pedregulho_max)
			_roteiro_pedregulho()
		Act.ESPADA:
			_esperas[Act.ESPADA] = _rng.randf_range(espera_espada_min, espera_espada_max)
			_roteiro_espada()
		Act.PAREDE:
			_esperas[Act.PAREDE] = _rng.randf_range(espera_parede_min, espera_parede_max)
			_roteiro_parede()


func _set_fase(f: int) -> void:
	_fase = f
	_fase_t = 0.0


## Espera de verdade (em segundos de jogo). Devolve false se no meio dela ele
## morreu, saiu da arvore, congelou ou entrou em cutscene — e nesse caso quem
## chamou tem de abortar o poder na hora.
func _espera(t: float) -> bool:
	if not _pode_continuar():
		return false
	# process_always = false: com o jogo pausado (menu aberto) o relogio do
	# poder tambem para, em vez de vencer sozinho e abortar a sequencia.
	await get_tree().create_timer(t, false).timeout
	return _pode_continuar()


func _pode_continuar() -> bool:
	if dead or not is_inside_tree() or get_tree() == null:
		return false
	if cutscene_mode or _congelado or not can_process():
		return false
	return true


func _fim_acao() -> void:
	_act = Act.NENHUMA
	_set_fase(0)
	_respiro = respiro_entre_poderes
	# O `_pose_espada` gira a ancora das maos pra balancar a lamina. Se o golpe
	# foi abortado no meio, ela fica torta — e o pedregulho do proximo ataque,
	# que tambem pendura nela, nasceria inclinado.
	if is_instance_valid(_ancora_maos):
		_ancora_maos.rotation = Vector3.ZERO


## Aborta o poder no meio: desfaz o que estava na mao e derruba a parede.
func _aborta_acao() -> void:
	_desfaz_pedregulho()
	_desfaz_espada()
	_derruba_parede()
	_fim_acao()


## Ponto do chao onde o jogador esta AGORA. Os golpes mirados congelam isto no
## instante do arremesso: eles nao perseguem.
func _ponto_do_player() -> Vector3:
	if not is_instance_valid(player):
		return global_position - global_transform.basis.z * 8.0
	return player.global_position


# ------------------------------------------------------- 1. o pedregulho

func _roteiro_pedregulho() -> void:
	# fase 0: ergue a mao direita, vazia
	if not await _espera(PED_ERGUE):
		_aborta_acao()
		return

	# fase 1: a pedra cresce na mao, puxando pedras do chao em volta
	_set_fase(1)
	var pedra = Pedregulho.new()
	pedra.damage = dano_pedregulho
	pedra.raio = altura * 0.26
	pedra.dono = self
	_mao_r.add_child(pedra)
	pedra.position = Vector3(0, -altura * 0.14, 0)
	_pedregulho = pedra
	pedra.crescer(PED_CRESCE)
	if not await _espera(PED_CRESCE):
		_aborta_acao()
		return

	# fase 2: as duas maos vao pra pedra e o corpo se arma pra tras
	_set_fase(2)
	if is_instance_valid(pedra):
		pedra.segurar(_ancora_maos)
	if not await _espera(PED_PEGA):
		_aborta_acao()
		return

	# fase 3: arremesso no ponto onde o jogador esta NESTE instante
	_set_fase(3)
	var destino := _ponto_do_player() + Vector3.UP * 0.9
	if not await _espera(PED_ARREMESSA * 0.45):
		_aborta_acao()
		return
	if is_instance_valid(pedra):
		pedra.lancar(destino)
	_pedregulho = null
	GlobalUtils.shake_camera(0.18, 0.2)
	if not await _espera(PED_ARREMESSA * 0.55):
		_aborta_acao()
		return

	# fase 4: recupera
	_set_fase(4)
	if not await _espera(PED_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


func _desfaz_pedregulho() -> void:
	if is_instance_valid(_pedregulho):
		_pedregulho.queue_free()
	_pedregulho = null


# ---------------------------------------------------------- 2. a espada

func _roteiro_espada() -> void:
	# fase 0: junta as duas maos na frente do peito
	if not await _espera(ESP_JUNTA):
		_aborta_acao()
		return

	# fase 1: a lamina cresce entre as maos
	_set_fase(1)
	_cria_espada()
	if not await _espera(ESP_CRESCE):
		_aborta_acao()
		return

	# fase 2: ergue pro alto (a lamina nao troca de pai — ver `_cria_espada`)
	_set_fase(2)
	if not await _espera(ESP_ERGUE):
		_aborta_acao()
		return

	# fase 3: o corte. As lascas saem no meio do arco, nao no comeco.
	_set_fase(3)
	_corte()
	if not await _espera(ESP_CORTA):
		_aborta_acao()
		return

	# fase 4: a lamina se desfaz e ele se endireita
	_set_fase(4)
	_desfaz_espada()
	if not await _espera(ESP_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


## A espada de pedra: uma CUNHA, larga na guarda e afinando ate a ponta, com as
## fatias se sobrepondo pra ler como lamina inteira. Nasce com escala quase zero
## entre as maos e cresce pelos 3,4 s da fase 1.
##
## Duas correcoes em cima da primeira versao, que saiu "esquisita":
##
##  1. era um EMPILHAMENTO de pedras de mesma largura, cada uma com giro
##     sorteado nos tres eixos. Pedra girada livre nao le como gume — le como
##     cascalho espetado num cabo. Agora o giro e so um tiquinho em torno do
##     eixo da lamina (ver `_fatia_da_lamina`) e a largura afunila;
##  2. tinha 2,76 m saindo de uma ancora baixa, entao a ponta passava DOIS
##     metros acima da cabeca dele e a tela virava um totem. Agora tem 1,74 m,
##     saindo do peito: continua enorme pra um corpo de 2,9 m, mas cabe no
##     enquadramento junto com o dono.
##
## A lamina fica presa na `_ancora_maos` — filha do `_spine` — do comeco ao fim,
## e quem a balanca e a rotacao dessa ancora no `_pose_espada`. A versao
## anterior trocava a espada pra `_mao_r` no golpe, e ali o eixo local da mao
## aponta de volta pro cotovelo: a lamina nascia apontando pro proprio braco
## dele. Balancar pela ancora, alem de resolver isso, e o gesto certo — um bicho
## de pedra gira uma espada destas com o TRONCO, nao com o pulso.
func _cria_espada() -> void:
	if is_instance_valid(_espada):
		return
	var h := altura
	var arma := Node3D.new()
	arma.name = "EspadaDePedra"
	_ancora_maos.add_child(arma)

	var lamina := h * 0.60
	var fatias := 7
	for i in fatias:
		var f := (float(i) + 0.5) / float(fatias)
		_fatia_da_lamina(arma, Vector3(0, lamina * f, 0),
			h * 0.175 * (1.0 - f * 0.55),          # larga na base, fina na ponta
			lamina / float(fatias) * 1.35,          # sobrepoe MESMO a fatia vizinha
			h * 0.052 * (1.0 - f * 0.35))
	# guarda: tres pedras atravessadas
	for i in 3:
		_fatia_da_lamina(arma, Vector3((float(i) - 1.0) * h * 0.080, 0.0, 0.0),
			h * 0.070, h * 0.075, h * 0.062)
	# cabo e contrapeso
	_fatia_da_lamina(arma, Vector3(0, -h * 0.080, 0), h * 0.048, h * 0.105, h * 0.048)
	_fatia_da_lamina(arma, Vector3(0, -h * 0.165, 0), h * 0.078, h * 0.080, h * 0.072)

	arma.scale = Vector3.ONE * 0.06
	arma.position = Vector3(0, -h * 0.05, 0)
	arma.rotation = Vector3.ZERO
	_espada = arma

	var t := arma.create_tween()
	t.tween_property(arma, "scale", Vector3.ONE * 1.04, ESP_CRESCE * 0.86)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(arma, "scale", Vector3.ONE, ESP_CRESCE * 0.14)

	arma.add_child(RockFX.po(20, 0.6, 1.8))
	FX.som_no_mundo(self, arma.global_position, RockFX.SOM_PEDRA, -8.0, 0.32)


## Uma fatia da lamina. Diferente do `RockFX.bloco`, o giro aqui e CONTROLADO:
## so em torno do eixo da propria lamina, e de pouco. A largura (X) e a
## espessura (Z) entram separadas, que e o que da secao de gume — chata num
## eixo, larga no outro — em vez de pedregulho.
func _fatia_da_lamina(pai: Node3D, onde: Vector3, largura: float,
		comprimento: float, espessura: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RockFX.pedra(_rng.randi())
	mi.material_override = RockFX.material()
	mi.position = onde + Vector3(
		_rng.randf_range(-0.012, 0.012) * altura, 0.0,
		_rng.randf_range(-0.010, 0.010) * altura)
	mi.rotation = Vector3(0.0, _rng.randf_range(-0.40, 0.40), _rng.randf_range(-0.10, 0.10))
	mi.scale = Vector3(largura, comprimento, espessura)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pai.add_child(mi)
	return mi


func _corte() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(ESP_CORTA * 0.38, false).timeout
	if dead or not is_inside_tree():
		return

	var frente := -global_transform.basis.z
	if is_instance_valid(player):
		var para := player.global_position - global_position
		para.y = 0.0
		if para.length() > 0.5:
			frente = para.normalized()

	var cena := FX.mundo(self)
	if cena == null:
		return
	var leva = Lascas.new()
	leva.damage = dano_lascas
	leva.direcao = frente
	leva.dono = self
	cena.add_child(leva)
	leva.global_position = global_position + frente * 1.9 + Vector3.UP * (altura * 0.50)
	leva.iniciar()

	# Sem `RockFX.quebra` aqui: ela acende uma omni laranja de 4,7 m de alcance,
	# e a dois metros do corpo isso banha o golem INTEIRO de laranja — parece
	# que ele pegou fogo, nao que a lamina lascou. A leva de lascas ja traz o
	# proprio po e as proprias faiscas.
	GlobalUtils.shake_camera(0.28, 0.35)


func _desfaz_espada() -> void:
	if not is_instance_valid(_espada):
		_espada = null
		return
	var arma := _espada
	_espada = null
	# A lamina desaba: as pedras dela viram cacos no chao, como todo o resto.
	var modelos: Array = []
	for c in arma.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			modelos.append({
				"mesh": mi.mesh, "escala": mi.scale * arma.scale,
				"pos": mi.global_position, "rot": mi.global_rotation,
			})
	var pos := arma.global_position
	if not modelos.is_empty():
		var quantas: int = mini(modelos.size(), 10)
		RockFX.detritos(self, pos, quantas, 3.0, 0.28, permanencia_cacos, modelos.slice(0, quantas))
	RockFX.quebra(self, pos, 1.0)
	arma.queue_free()


# ------------------------------------------------------ defesa: a parede

func _roteiro_parede() -> void:
	# fase 0: ergue as duas maos
	if not await _espera(PAR_ERGUE):
		_aborta_acao()
		return

	# fase 1: a parede sobe pedra por pedra entre ele e o jogador
	_set_fase(1)
	_levanta_parede()
	if not await _espera(PAR_CONSTROI):
		_aborta_acao()
		return

	# fase 2: ela fica de pe. E AQUI que o tiro do jogador bate nela e nao nele.
	_set_fase(2)
	if not await _espera(PAR_SEGURA):
		_aborta_acao()
		return

	# fase 3: ele empurra, e a parede anda
	_set_fase(3)
	if is_instance_valid(_parede):
		var frente := -global_transform.basis.z
		if is_instance_valid(player):
			var para := player.global_position - global_position
			para.y = 0.0
			if para.length() > 0.5:
				frente = para.normalized()
		_parede.avancar(frente, PAR_EMPURRA, PAREDE_AVANCO)
		GlobalUtils.shake_camera(0.25, 0.25)
	if not await _espera(PAR_EMPURRA):
		_aborta_acao()
		return

	# fase 4: a parede desaba e ele baixa os bracos
	_set_fase(4)
	_derruba_parede()
	if not await _espera(PAR_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


func _levanta_parede() -> void:
	if is_instance_valid(_parede) or dead or not is_inside_tree():
		return
	var cena := FX.mundo(self)
	if cena == null:
		return

	var frente := -global_transform.basis.z
	if is_instance_valid(player):
		var para := player.global_position - global_position
		para.y = 0.0
		if para.length() > 0.5:
			frente = para.normalized()

	var p = Parede.new()
	p.dano = dano_parede
	p.dono = self
	p.altura = altura * 1.08
	p.largura = altura * 1.9
	cena.add_child(p)
	# Nasce na altura dos PES dele, nao no centro do corpo: a parede sobe do
	# chao, e o chao e onde ele esta pisando.
	p.global_position = global_position + frente * PAREDE_DISTANCIA
	# olhando pro jogador: o Z local dela e a espessura
	p.global_rotation = Vector3(0.0, atan2(frente.x, frente.z), 0.0)
	p.construir(PAR_CONSTROI)
	_parede = p


func _derruba_parede() -> void:
	if is_instance_valid(_parede):
		_parede.encerrar()
	_parede = null


# ---------------------------------------------- movimento durante os poderes

## Ele fica PLANTADO durante os tres poderes. Nenhum deles tem corrida: todos
## sao conjurados de pe, com o corpo inteiro carregando a pedra.
func _anda_acao(delta: float) -> void:
	if is_instance_valid(player):
		# Na parede ele para de girar depois que ela sobe: a parede ja esta
		# posicionada, e um giro continuo a deixaria de lado.
		if not (_act == Act.PAREDE and _fase >= 2):
			_encara(player.global_position, delta)

	velocity.x = move_toward(velocity.x, 0.0, chase_speed * 2.0)
	velocity.z = move_toward(velocity.z, 0.0, chase_speed * 2.0)


# ============================================================= animacao

func _anima(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var blend: float = clampf(planar / maxf(chase_speed, 0.01), 0.0, 1.0)

	if planar > 0.2 and is_on_floor():
		var antes := _passo_fase
		# Cadencia baixissima: passada longa e pesada. Um corpo de pedra de
		# 2,9 m com frequencia de passo de gente parece patinar.
		_passo_fase += delta * (1.6 + planar * 0.55)
		var metade := int(floor(_passo_fase / PI))
		if metade != int(floor(antes / PI)):
			_pisa(planar)

	if is_instance_valid(_luz_olhos) and not _membros["cabeca"]["perdido"]:
		var brilho := 0.22 + sin(_t * 1.7) * 0.06 + blend * 0.10
		if _act != Act.NENHUMA:
			brilho += 0.20
		_luz_olhos.light_energy = brilho

	if _po_corpo != null:
		# po saindo mais quando ele se move: as juntas de pedra raspando
		_po_corpo.amount_ratio = clampf(0.30 + blend * 0.7, 0.0, 1.0)

	if dead:
		_pose_morte(delta)
		return

	if _act != Act.NENHUMA:
		_pose_acao(delta)
	else:
		_pose_andando(delta, blend)


## Cada pisada: som grave, po levantando no pe e um tranco de camera quando o
## jogador esta perto. E o peso dele contado por tres canais ao mesmo tempo.
func _pisa(planar: float) -> void:
	if dead:
		return
	if _passos != null:
		_passos.pitch_scale = clampf(0.38 + planar * 0.05, 0.34, 0.62) + _rng.randf_range(-0.03, 0.03)
		_passos.play()

	var pe: Node3D = _membros["pe_l"]["pivo"] if int(_passo_fase / PI) % 2 == 0 else _membros["pe_r"]["pivo"]
	if is_instance_valid(pe) and is_inside_tree():
		var po := RockFX.po(6, 0.45, 1.0)
		var cena := FX.mundo(self)
		if cena != null:
			cena.add_child(po)
			po.global_position = pe.global_position
			var t := po.create_tween()
			t.tween_interval(1.6)
			t.tween_callback(po.queue_free)

	if is_instance_valid(player) and global_position.distance_to(player.global_position) < 12.0:
		GlobalUtils.shake_camera(0.10, 0.05)


## ============================================================================
## CONVENCAO DE SINAL DOS PIVOS — leia antes de mexer em qualquer pose.
##
## O corpo olha pro -Z. Os ossos de MEMBRO pendem pro -Y a partir do pivo; o
## tronco e o pescoco APONTAM pro +Y. Como os dois grupos apontam pra lados
## opostos, o mesmo sinal de `rotation.x` quer dizer coisas contrarias neles:
##
##   BRACO / ANTEBRACO / COXA (pendem pra baixo):
##       0.00  pendurado
##      +1.57  apontando PRA FRENTE, na horizontal
##      +3.14  apontando pra CIMA
##      -1.57  apontando PRA TRAS
##     => levantar pra frente e SEMPRE positivo.
##
##   TRONCO / PESCOCO (apontam pra cima):
##      +  inclina pra TRAS   (armar o golpe)
##      -  inclina pra FRENTE (descarregar)
##
##   JOELHO: negativo sempre — a canela dobra pra tras.
##
##   `rotation.z` do ombro: positivo abre o braco ESQUERDO (o do +X) pra fora;
##   no direito e o espelho, negativo.
##
## Estas poses nasceram copiadas do Shadow Seraph, que usa os valores
## NEGATIVOS. Nele isso passava porque os poderes dele sao quase todos "bracos
## pro ceu" (~-3,1 rad, que e praticamente vertical e nao denuncia o lado). Aqui
## nao passou: o inimigo estendia os bracos pra TRAS, e o pedregulho — que
## cresce na mao — nascia em cima da cabeca dele em vez de na frente do peito.
##
## Nenhum alvo pode passar de +-PI. O `_para` le `rotation` de volta a cada
## frame e o Godot devolve o angulo ja normalizado: um alvo em 3,35 rad voltaria
## como -2,93 e o braco desceria pela frente em vez de passar por cima.
## ============================================================================


## Giro suave de um pivo ate a pose desejada. Tudo na animacao passa por aqui.
func _para(n: Node3D, alvo: Vector3, w: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	n.rotation = n.rotation.lerp(alvo, clampf(w, 0.0, 1.0))


func _descanso_hips() -> float:
	if _hips.has_meta("rest_y"):
		return float(_hips.get_meta("rest_y"))
	_hips.set_meta("rest_y", _hips.position.y)
	return _hips.position.y


## Caminhada. Passada curta e larga, tronco balancando de um lado pro outro:
## o andar de um peso que se joga de uma perna pra outra.
func _pose_andando(delta: float, blend: float) -> void:
	var w: float = clampf(delta * 5.0, 0.0, 1.0)
	var t := _passo_fase
	var balanco := 0.44 * blend
	var s := sin(t)
	var s2 := sin(t + PI)

	_para(_coxa_l, Vector3(s * balanco, 0.0, 0.0), w)
	_para(_coxa_r, Vector3(s2 * balanco, 0.0, 0.0), w)
	_para(_joelho_l, Vector3(-0.18 - maxf(0.0, -sin(t + 1.3)) * 0.85 * blend, 0.0, 0.0), w)
	_para(_joelho_r, Vector3(-0.18 - maxf(0.0, -sin(t + PI + 1.3)) * 0.85 * blend, 0.0, 0.0), w)

	_hips.position.y = _descanso_hips() + absf(sin(t)) * 0.06 * blend
	# gingado lateral: o Z do quadril e o que faz o peso passar de um pe pro outro
	_para(_hips, Vector3(0.0, sin(t) * 0.07 * blend, sin(t) * 0.10 * blend), w)
	# tronco pra FRENTE quando anda (negativo): peso indo na direcao do passo
	_para(_spine, Vector3(-0.06 - 0.10 * blend, -sin(t) * 0.09 * blend, -sin(t) * 0.07 * blend), w)

	# Bracos pesados, pendurados e ABERTOS pra fora. O sinal do Z importa: pro
	# ombro esquerdo (que fica no +X) um Z positivo joga o braco pra FORA. Com
	# os bracos fechados pra dentro — que e a pose do Seraph, um bicho magro —
	# eles desapareciam dentro deste torso de um metro de largura e a silhueta
	# virava uma pilha de pedra sem forma humana.
	var bracos := 0.34 * blend
	_para(_ombro_l, Vector3(s2 * bracos, 0.0, 0.17 + 0.05 * blend), w)
	_para(_ombro_r, Vector3(s * bracos, 0.0, -0.17 - 0.05 * blend), w)
	_para(_cotovelo_l, Vector3(0.28 + 0.22 * blend * maxf(0.0, s2), 0.0, -0.10), w)
	_para(_cotovelo_r, Vector3(0.28 + 0.22 * blend * maxf(0.0, s), 0.0, 0.10), w)

	var p := 1.0 - blend
	if p > 0.01:
		_para(_neck, Vector3(sin(_t * 0.6) * 0.04 * p, sin(_t * 0.24) * 0.30 * p, 0.0), delta * 1.0)
		_hips.position.y += sin(_t * 0.9) * 0.010 * p
	else:
		_para(_neck, Vector3.ZERO, w)


## Pernas plantadas e flexionadas: base de quem esta segurando muito peso.
func _pernas_firmes(w: float, flexao := 0.20) -> void:
	# coxa pra FRENTE (positivo) e canela pra tras: e assim que um joelho
	# humano dobra. Com a coxa negativa ele agachava como passaro.
	_para(_coxa_l, Vector3(flexao * 0.5, 0.0, 0.22), w)
	_para(_coxa_r, Vector3(flexao * 0.5, 0.0, -0.22), w)
	_para(_joelho_l, Vector3(-flexao, 0.0, 0.0), w)
	_para(_joelho_r, Vector3(-flexao, 0.0, 0.0), w)
	_hips.position.y = lerpf(_hips.position.y, _descanso_hips() - flexao * 0.16, w)


func _pose_acao(delta: float) -> void:
	# Peso baixo: o pivo demora a chegar na pose e a chegada e macia. Com peso
	# alto o braco teleporta pra pose nova a cada troca de fase, que e o que
	# faz um rig de codigo parecer boneco.
	var w: float = clampf(delta * 4.5, 0.0, 1.0)
	match _act:
		Act.PEDREGULHO: _pose_pedregulho(w)
		Act.ESPADA: _pose_espada(w)
		Act.PAREDE: _pose_parede(w)
		_: pass


func _pose_pedregulho(w: float) -> void:
	match _fase:
		0:
			# Ergue a mao direita aberta NA FRENTE do peito, na altura do ombro
			# — nao acima da cabeca. E ali que a massa de pedra vai se juntar, e
			# ela tem de ficar onde o jogador ve o que esta sendo montado.
			var f: float = clampf(_fase_t / PED_ERGUE, 0.0, 1.0)
			var e := f * f * (3.0 - 2.0 * f)
			_pernas_firmes(w, 0.20)
			_para(_ombro_r, Vector3(1.55 * e, 0.0, -0.45 * e), w)
			_para(_cotovelo_r, Vector3(0.45 * e, 0.0, 0.0), w)
			_para(_ombro_l, Vector3(0.40 * e, 0.0, 0.32 * e), w)
			_para(_cotovelo_l, Vector3(0.50 * e, 0.0, 0.0), w)
			_para(_spine, Vector3(0.06 * e, -0.14 * e, 0.0), w)
			_para(_neck, Vector3(-0.16 * e, -0.16 * e, 0.0), w)
		1:
			# A massa cresce e PESA: o braco vai cedendo, a mao esquerda sobe pra
			# ajudar, o tronco compensa pra tras e as pernas afundam. Sao tres
			# segundos de esforco visivel — sem isso a pedra parece de isopor.
			var f1: float = clampf(_fase_t / PED_CRESCE, 0.0, 1.0)
			var treme := sin(_fase_t * 17.0) * 0.02 * f1
			_pernas_firmes(w, 0.20 + 0.30 * f1)
			_para(_ombro_r, Vector3(1.55 - 0.28 * f1 + treme, 0.0, -0.45 - 0.12 * f1), w)
			_para(_cotovelo_r, Vector3(0.45 + 0.35 * f1, 0.0, 0.0), w)
			_para(_ombro_l, Vector3(0.40 + 0.82 * f1, 0.0, 0.32 - 0.10 * f1), w)
			_para(_cotovelo_l, Vector3(0.50 + 0.30 * f1, 0.0, 0.0), w)
			_para(_spine, Vector3(0.06 + 0.20 * f1 + treme, -0.14 + 0.10 * f1, 0.12 * f1), w)
			_para(_neck, Vector3(-0.16, -0.08, 0.0), w)
		2:
			# As duas maos fecham sobre a massa, na altura do peito, e o corpo se
			# arma pra tras. O arremesso dele e um HEAVE de peso morto, nao um
			# saque por cima da cabeca: e o que cabe num bloco de um metro e meio.
			var f2: float = clampf(_fase_t / PED_PEGA, 0.0, 1.0)
			var e2 := f2 * f2 * (3.0 - 2.0 * f2)
			_pernas_firmes(w, 0.50 - 0.08 * e2)
			_para(_ombro_l, Vector3(lerpf(1.22, 1.30, e2), 0.0, lerpf(0.22, 0.30, e2)), w * 1.1)
			_para(_ombro_r, Vector3(lerpf(1.27, 1.30, e2), 0.0, lerpf(-0.57, -0.30, e2)), w * 1.1)
			_para(_cotovelo_l, Vector3(lerpf(0.80, 0.60, e2), 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(lerpf(0.80, 0.60, e2), 0.0, 0.0), w)
			_para(_spine, Vector3(0.26 + 0.16 * e2, 0.0, 0.0), w)
			_para(_neck, Vector3(0.14 * e2, 0.0, 0.0), w)
		3:
			# Arremesso: os bracos ESTICAM pra frente e o tronco desaba com eles.
			var f3: float = clampf(_fase_t / PED_ARREMESSA, 0.0, 1.0)
			_pernas_firmes(w * 1.3, 0.42 - 0.18 * f3)
			_para(_ombro_l, Vector3(lerpf(1.30, 1.66, f3), 0.0, 0.24), w * 1.8)
			_para(_ombro_r, Vector3(lerpf(1.30, 1.66, f3), 0.0, -0.24), w * 1.8)
			_para(_cotovelo_l, Vector3(lerpf(0.60, 0.05, f3), 0.0, 0.0), w * 1.8)
			_para(_cotovelo_r, Vector3(lerpf(0.60, 0.05, f3), 0.0, 0.0), w * 1.8)
			_para(_spine, Vector3(lerpf(0.42, -0.30, f3), 0.0, 0.0), w * 1.6)
			_para(_neck, Vector3(-0.20 * f3, 0.0, 0.0), w)
		_:
			# recompoe, ainda respirando fundo
			var f4: float = clampf(_fase_t / PED_VOLTA, 0.0, 1.0)
			_pernas_firmes(w, 0.24 - 0.06 * f4)
			_para(_ombro_l, Vector3(0.30, 0.0, 0.20), w * 0.8)
			_para(_ombro_r, Vector3(0.30, 0.0, -0.20), w * 0.8)
			_para(_cotovelo_l, Vector3(0.40, 0.0, 0.0), w * 0.8)
			_para(_cotovelo_r, Vector3(0.40, 0.0, 0.0), w * 0.8)
			_para(_spine, Vector3(-0.20 * (1.0 - f4) - 0.04, 0.0, 0.0), w * 0.8)
			_para(_neck, Vector3.ZERO, w * 0.8)


func _pose_espada(w: float) -> void:
	# A lamina fica presa na `_ancora_maos` o golpe inteiro, e quem a balanca e
	# esta rotacao aqui — nao o braco. Ver `_cria_espada` pro porque.
	var arco := 0.0
	match _fase:
		0:
			# junta as duas maos na frente do peito
			var f: float = clampf(_fase_t / ESP_JUNTA, 0.0, 1.0)
			var e := f * f * (3.0 - 2.0 * f)
			arco = -0.30 * e
			_pernas_firmes(w, 0.22)
			_para(_ombro_l, Vector3(1.05 * e, 0.0, 0.18 * e), w)
			_para(_ombro_r, Vector3(1.05 * e, 0.0, -0.18 * e), w)
			_para(_cotovelo_l, Vector3(0.72 * e, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(0.72 * e, 0.0, 0.0), w)
			_para(_spine, Vector3(-0.10 * e, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.16 * e, 0.0, 0.0), w)
		1:
			# a lamina cresce entre as maos: elas se abrem devagar pra caber no
			# cabo e o corpo se joga pra tras pra aguentar o comprimento
			var f1: float = clampf(_fase_t / ESP_CRESCE, 0.0, 1.0)
			var treme := sin(_fase_t * 14.0) * 0.018 * f1
			arco = -0.30 + 0.12 * f1
			_pernas_firmes(w, 0.22 + 0.22 * f1)
			_para(_ombro_l, Vector3(1.05 + 0.22 * f1 + treme, 0.0, 0.14 + 0.06 * f1), w)
			_para(_ombro_r, Vector3(1.05 + 0.22 * f1 + treme, 0.0, -0.14 - 0.06 * f1), w)
			_para(_cotovelo_l, Vector3(0.72 - 0.30 * f1, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(0.72 - 0.30 * f1, 0.0, 0.0), w)
			_para(_spine, Vector3(-0.10 + 0.34 * f1, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.16 + 0.26 * f1, 0.0, 0.0), w)
		2:
			# ergue a lamina pro alto e torce o tronco: e o embalo
			var f2: float = clampf(_fase_t / ESP_ERGUE, 0.0, 1.0)
			var e2 := f2 * f2 * (3.0 - 2.0 * f2)
			arco = lerpf(-0.18, 0.80, e2)
			_pernas_firmes(w, 0.28)
			_para(_ombro_r, Vector3(lerpf(1.27, 2.45, e2), 0.0, lerpf(-0.20, -0.14, e2)), w * 1.2)
			_para(_cotovelo_r, Vector3(lerpf(0.42, 0.28, e2), 0.0, 0.0), w * 1.2)
			_para(_ombro_l, Vector3(lerpf(1.27, 2.20, e2), 0.0, lerpf(0.20, 0.12, e2)), w * 1.1)
			_para(_cotovelo_l, Vector3(0.40, 0.0, 0.0), w)
			_para(_spine, Vector3(0.24, -0.34 * e2, -0.10 * e2), w)
			_para(_neck, Vector3(0.14, 0.24 * e2, 0.0), w)
		3:
			# O corte: a lamina desaba PRA FRENTE e o corpo inteiro gira com ela.
			# `e3` ao quadrado — a lamina acelera na descida, como peso caindo.
			var f3: float = clampf(_fase_t / ESP_CORTA, 0.0, 1.0)
			var e3 := f3 * f3
			arco = lerpf(0.80, -1.55, e3)
			_pernas_firmes(w, 0.28 + 0.18 * f3)
			_para(_ombro_r, Vector3(lerpf(2.45, 0.78, e3), 0.0, lerpf(-0.14, -0.30, e3)), w * 2.0)
			_para(_cotovelo_r, Vector3(lerpf(0.28, 0.10, e3), 0.0, 0.0), w * 2.0)
			_para(_ombro_l, Vector3(lerpf(2.20, 0.88, e3), 0.0, lerpf(0.12, 0.26, e3)), w * 1.6)
			_para(_cotovelo_l, Vector3(lerpf(0.40, 0.10, e3), 0.0, 0.0), w * 1.6)
			_para(_spine, Vector3(lerpf(0.24, -0.42, e3), lerpf(-0.34, 0.38, e3), lerpf(-0.10, 0.16, e3)), w * 1.3)
			_para(_neck, Vector3(lerpf(0.14, -0.26, e3), 0.20 * e3, 0.0), w * 1.2)
		_:
			var f4: float = clampf(_fase_t / ESP_VOLTA, 0.0, 1.0)
			arco = lerpf(-1.55, 0.0, f4)
			_pernas_firmes(w, 0.24 - 0.06 * f4)
			_para(_ombro_r, Vector3(0.60 * (1.0 - f4) + 0.30, 0.0, -0.24), w * 0.9)
			_para(_cotovelo_r, Vector3(0.40, 0.0, 0.0), w * 0.9)
			_para(_ombro_l, Vector3(0.60 * (1.0 - f4) + 0.30, 0.0, 0.24), w * 0.9)
			_para(_cotovelo_l, Vector3(0.40, 0.0, 0.0), w * 0.9)
			_para(_spine, Vector3(-0.26 * (1.0 - f4) - 0.04, 0.22 * (1.0 - f4), 0.0), w * 0.9)
			_para(_neck, Vector3.ZERO, w * 0.9)

	if is_instance_valid(_ancora_maos):
		_ancora_maos.rotation.x = lerpf(_ancora_maos.rotation.x, arco, clampf(w * 1.4, 0.0, 1.0))


func _pose_parede(w: float) -> void:
	match _fase:
		0:
			# as duas maos sobem ABERTAS PRA FRENTE, palmas viradas pro jogador
			var f: float = clampf(_fase_t / PAR_ERGUE, 0.0, 1.0)
			var e := f * f * (3.0 - 2.0 * f)
			_pernas_firmes(w, 0.22 + 0.14 * e)
			_para(_ombro_l, Vector3(1.40 * e, 0.0, 0.55 * e), w)
			_para(_ombro_r, Vector3(1.40 * e, 0.0, -0.55 * e), w)
			_para(_cotovelo_l, Vector3(0.42 * e, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(0.42 * e, 0.0, 0.0), w)
			_para(_spine, Vector3(0.10 * e, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.14 * e, 0.0, 0.0), w)
		1:
			# ele PUXA a parede do chao: as maos sobem junto com as pedras e o
			# corpo treme com o esforco
			var f1: float = clampf(_fase_t / PAR_CONSTROI, 0.0, 1.0)
			var treme := sin(_fase_t * 19.0) * 0.03
			_pernas_firmes(w, 0.36)
			_para(_ombro_l, Vector3(1.40 + 0.78 * f1 + treme, 0.0, 0.55 + 0.10 * f1), w)
			_para(_ombro_r, Vector3(1.40 + 0.78 * f1 + treme, 0.0, -0.55 - 0.10 * f1), w)
			_para(_cotovelo_l, Vector3(0.42 - 0.20 * f1, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(0.42 - 0.20 * f1, 0.0, 0.0), w)
			_para(_spine, Vector3(0.10 + 0.14 * f1 + treme * 0.5, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.06, 0.0, 0.0), w)
		2:
			# segura a parede de pe: bracos travados pra frente, quase imoveis
			var respira := sin(_fase_t * 2.2) * 0.025
			_pernas_firmes(w, 0.30)
			_para(_ombro_l, Vector3(2.20 + respira, 0.0, 0.62), w * 0.8)
			_para(_ombro_r, Vector3(2.20 + respira, 0.0, -0.62), w * 0.8)
			_para(_cotovelo_l, Vector3(0.20, 0.0, 0.0), w * 0.8)
			_para(_cotovelo_r, Vector3(0.20, 0.0, 0.0), w * 0.8)
			_para(_spine, Vector3(0.24, 0.0, 0.0), w * 0.8)
			_para(_neck, Vector3(0.12, 0.0, 0.0), w * 0.8)
		3:
			# EMPURRA: os bracos descem ate a horizontal esticados pra frente e o
			# tronco vai junto, como quem enfia o ombro num armario
			var f3: float = clampf(_fase_t / PAR_EMPURRA, 0.0, 1.0)
			var e3: float = clampf(f3 / 0.35, 0.0, 1.0)
			_pernas_firmes(w, 0.34 - 0.10 * e3)
			_para(_ombro_l, Vector3(lerpf(2.20, 1.52, e3), 0.0, lerpf(0.62, 0.26, e3)), w * 1.2)
			_para(_ombro_r, Vector3(lerpf(2.20, 1.52, e3), 0.0, lerpf(-0.62, -0.26, e3)), w * 1.2)
			_para(_cotovelo_l, Vector3(lerpf(0.20, 0.04, e3), 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(lerpf(0.20, 0.04, e3), 0.0, 0.0), w)
			_para(_spine, Vector3(lerpf(0.24, -0.32, e3), 0.0, 0.0), w * 1.2)
			_para(_neck, Vector3(-0.16 * e3, 0.0, 0.0), w)
		_:
			_pernas_firmes(w, 0.20)
			_para(_ombro_l, Vector3(0.30, 0.0, 0.20), w * 0.9)
			_para(_ombro_r, Vector3(0.30, 0.0, -0.20), w * 0.9)
			_para(_cotovelo_l, Vector3(0.40, 0.0, 0.0), w * 0.9)
			_para(_cotovelo_r, Vector3(0.40, 0.0, 0.0), w * 0.9)
			_para(_spine, Vector3(-0.04, 0.0, 0.0), w * 0.9)
			_para(_neck, Vector3.ZERO, w * 0.9)


## Morte: ele nao tomba como um corpo — ele DESABA. Os joelhos cedem, o tronco
## despenca e o rig afunda. As pedras se soltando ficam por conta do `die()`.
func _pose_morte(delta: float) -> void:
	var w: float = clampf(delta * 2.2, 0.0, 1.0)
	_para(_spine, Vector3(-0.75, 0.0, 0.30), w)
	_para(_neck, Vector3(-0.40, 0.0, 0.0), w)
	_para(_ombro_l, Vector3(0.55, 0.0, 0.80), w)
	_para(_ombro_r, Vector3(0.55, 0.0, -0.80), w)
	_para(_cotovelo_l, Vector3(0.25, 0.0, 0.0), w)
	_para(_cotovelo_r, Vector3(0.25, 0.0, 0.0), w)
	_pernas_firmes(w, 1.05)
	_hips.position.y = lerpf(_hips.position.y, _descanso_hips() * 0.35, clampf(delta * 1.4, 0.0, 1.0))
	_rig.rotation.x = lerpf(_rig.rotation.x, deg_to_rad(-26.0), clampf(delta * 1.2, 0.0, 1.0))


# ==================================================== o corpo se desmonta

## Pedras que ainda podem ser arrancadas sem deixar um membro oco. Cada membro
## guarda um minimo: sem isso, tiro suficiente deixaria o inimigo invisivel
## muito antes de a vida acabar.
func _pedras_soltaveis() -> Array:
	var lista: Array = []
	for nome in _membros.keys():
		var m: Dictionary = _membros[nome]
		if m["perdido"]:
			continue
		var pedras: Array = m["pedras"]
		if pedras.size() <= int(m["minimo"]):
			continue
		for p in pedras:
			if is_instance_valid(p) and p.visible:
				lista.append({"nome": nome, "pedra": p})
	return lista


## Arranca `quantas` pedras do corpo e manda pro chao. Chamado a CADA dano: e
## a promessa central deste inimigo, e por isso nao ha condicao nenhuma aqui
## alem de haver pedra sobrando.
func _arranca_pedras(quantas: int, de_onde: Vector3) -> void:
	var soltaveis := _pedras_soltaveis()
	if soltaveis.is_empty():
		return
	soltaveis.shuffle()

	var modelos: Array = []
	var centro := Vector3.ZERO
	var n: int = mini(quantas, soltaveis.size())
	for i in n:
		var item: Dictionary = soltaveis[i]
		var p: MeshInstance3D = item["pedra"]
		var nome: String = item["nome"]
		modelos.append({
			"mesh": p.mesh,
			"escala": p.scale,
			"pos": p.global_position,
			"rot": p.global_rotation,
		})
		centro += p.global_position
		var m: Dictionary = _membros[nome]
		(m["pedras"] as Array).erase(p)
		p.queue_free()
		_pedras_perdidas += 1

	if modelos.is_empty():
		return
	centro /= float(modelos.size())

	# As pedras saem PRA LONGE do jogador: o tiro veio de la, e a pedra tem de
	# voar pro outro lado. Sem isso elas caem nos pes dele e o impacto some.
	var fuga := Vector3.UP
	if is_instance_valid(player):
		fuga = (centro - player.global_position)
		fuga.y = 0.0
		if fuga.length() < 0.1:
			fuga = Vector3.UP
		else:
			fuga = fuga.normalized() * 0.7 + Vector3.UP * 0.8

	RockFX.detritos(self, centro, modelos.size(), 5.0, 0.2,
		permanencia_cacos, modelos, fuga)
	RockFX.quebra(self, de_onde, 0.5, false)
	FX.som_no_mundo(self, centro, RockFX.SOM_PEDRA, -14.0, _rng.randf_range(0.5, 0.72))


## Arranca um MEMBRO inteiro: mao, antebraco (com a mao junto), ombro (com o
## braco todo), pe ou cabeca. Ele continua vivo e lutando sem ele.
##
## Tudo o que estiver PENDURADO no membro vai junto — e por isso a checagem e
## por ancestralidade de no e nao por uma lista escrita a mao: perder o ombro
## tem de levar o antebraco e a mao, e essa relacao ja esta na arvore.
func _arranca_membro() -> String:
	var candidatos: Array = []
	for nome in _membros.keys():
		var m: Dictionary = _membros[nome]
		if m["perdido"] or not m["solta"]:
			continue
		if not is_instance_valid(m["pivo"]):
			continue
		candidatos.append(nome)
	if candidatos.is_empty():
		return ""

	var escolhido: String = candidatos[_rng.randi() % candidatos.size()]
	var pivo: Node3D = _membros[escolhido]["pivo"]

	# junta as pedras deste membro e de tudo que esta pendurado nele
	var pecas: Array = []
	for nome in _membros.keys():
		var m: Dictionary = _membros[nome]
		if m["perdido"]:
			continue
		var p2: Node3D = m["pivo"]
		if not is_instance_valid(p2):
			continue
		if p2 != pivo and not pivo.is_ancestor_of(p2):
			continue
		for pedra in (m["pedras"] as Array):
			if not is_instance_valid(pedra) or not pedra.visible:
				continue
			pecas.append({
				"mesh": pedra.mesh,
				"escala": pedra.scale,
				"pos": pedra.global_position,
				"rot": pedra.global_rotation,
			})
			pedra.queue_free()
			_pedras_perdidas += 1
		(m["pedras"] as Array).clear()
		m["perdido"] = true

	if pecas.is_empty():
		return ""

	if escolhido == "cabeca":
		_apaga_olhos()

	var cena := FX.mundo(self)
	if cena != null:
		var membro = Membro.new()
		membro.pecas = pecas
		membro.permanencia = permanencia_cacos
		# empurrao pra fora e pra cima: o membro e ARRANCADO, nao larga sozinho
		var fora := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		if fora.length() < 0.1:
			fora = Vector3.FORWARD
		membro.impulso = fora.normalized() * _rng.randf_range(1.6, 3.2) + Vector3.UP * _rng.randf_range(2.2, 3.8)
		cena.add_child(membro)

	RockFX.quebra(self, pivo.global_position, 1.2)
	GlobalUtils.shake_camera(0.18, 0.22)
	return escolhido


## A cabeca se foi: as duas brasas se apagam. Ele continua de pe e continua
## lutando — que e justamente o que torna a imagem desconfortavel.
func _apaga_olhos() -> void:
	if _fogo_olhos != null:
		_fogo_olhos.emitting = false
	if is_instance_valid(_luz_olhos):
		create_tween().tween_property(_luz_olhos, "light_energy", 0.0, 0.5)
	for olho in [_olho_l, _olho_r]:
		if is_instance_valid(olho):
			var o: MeshInstance3D = olho
			var t := o.create_tween()
			t.tween_property(o, "scale", Vector3.ONE * 0.01, 0.35)
			t.tween_callback(o.queue_free)


# ============================================================ dano e morte

func take_damage(amount) -> void:
	if dead:
		return
	var dano := int(amount)

	# A parede na frente come o golpe. O tiro ja bate nela pelo raycast (ela e
	# um corpo na camada 3); isto aqui cobre o RESTO do dano do jogo — lamina,
	# ultimate, dano em area — que chega direto no metodo, sem raycast nenhum.
	if is_instance_valid(_parede) and is_instance_valid(player):
		var de := global_position + Vector3.UP * (altura * 0.5)
		var ate := player.global_position + Vector3.UP
		if _parede.protege(de, ate):
			_parede.take_damage(dano)
			return

	if _grunhido_dano != null and not _grunhido_dano.playing:
		_grunhido_dano.play()

	current_health = clampi(current_health - dano, 0, max_health)

	# O efeito que define ele: TODO dano arranca pedra.
	var alvo := global_position + Vector3.UP * (altura * _rng.randf_range(0.35, 0.85))
	_arranca_pedras(_rng.randi_range(pedras_por_dano_min, pedras_por_dano_max), alvo)

	# ...e as vezes o que se solta e um membro inteiro.
	if current_health > 0 and _rng.randf() < chance_perder_membro:
		_arranca_membro()

	if is_instance_valid(player) and player.has_method("add_cogblade_power"):
		player.add_cogblade_power(float(dano), global_position + Vector3(0, altura * 0.6, 0))

	_mostra_barra()

	if current_health <= 0:
		die()


func _mostra_barra() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var root := get_tree().root
	var ui = root.get_node_or_null("GlobalEnemyHealthUI")
	if ui == null:
		ui = load("res://scripts/ui/global_enemy_health.gd").new()
		ui.name = "GlobalEnemyHealthUI"
		root.add_child(ui)
	ui.show_health(self, tr(enemy_name), current_health, max_health)


func die() -> void:
	if dead:
		return
	dead = true
	_act = Act.NENHUMA
	_desfaz_pedregulho()
	_desfaz_espada()
	_derruba_parede()
	died.emit()
	if _grunhido_morte != null:
		_grunhido_morte.play()
	SaveManager.add_iron_rusks(iron_rusks_value)
	_desaba()

	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(1.6).timeout
	if _tombo != null and is_inside_tree():
		_tombo.play()

	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(1.2).timeout
	set_collision_layer_value(3, false)

	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(15.0).timeout
	queue_free()


## O desabamento: o corpo inteiro vira entulho, em levas, ao longo de ~1,4 s.
## Em levas e nao de uma vez porque um monte com setenta pedras estoura o teto
## do `rock_fx` e some metade; em tres tempos, cada leva cabe e o olho le uma
## coisa DESMORONANDO em vez de explodindo.
func _desaba() -> void:
	_apaga_olhos()
	if _po_corpo != null:
		_po_corpo.emitting = false
	RockFX.quebra(self, global_position + Vector3.UP * (altura * 0.5), 1.7)

	for leva in 3:
		if not is_inside_tree():
			return
		# No desabamento nao ha minimo a respeitar (por isso a lista e montada
		# aqui em vez de sair do `_pedras_soltaveis`): cai tudo.
		var soltaveis: Array = []
		for nome in _membros.keys():
			var m: Dictionary = _membros[nome]
			if m["perdido"]:
				continue
			for p in (m["pedras"] as Array):
				if is_instance_valid(p) and p.visible:
					soltaveis.append({"nome": nome, "pedra": p})
		if soltaveis.is_empty():
			return
		soltaveis.shuffle()

		# ultima leva leva o que sobrou; as duas primeiras, quase metade cada
		var quantas: int = soltaveis.size() if leva == 2 else int(soltaveis.size() * 0.45)
		quantas = maxi(1, mini(quantas, soltaveis.size()))
		var modelos: Array = []
		var centro := Vector3.ZERO
		for i in quantas:
			var p2: MeshInstance3D = soltaveis[i]["pedra"]
			modelos.append({
				"mesh": p2.mesh, "escala": p2.scale,
				"pos": p2.global_position, "rot": p2.global_rotation,
			})
			centro += p2.global_position
			(_membros[soltaveis[i]["nome"]]["pedras"] as Array).erase(p2)
			p2.queue_free()
		centro /= float(quantas)
		RockFX.detritos(self, centro, modelos.size(), 3.2, 0.22, 14.0, modelos)
		FX.som_no_mundo(self, centro, RockFX.SOM_PEDRA, -8.0, _rng.randf_range(0.3, 0.42))
		GlobalUtils.shake_camera(0.2, 0.18)

		if not is_inside_tree() or get_tree() == null:
			return
		await get_tree().create_timer(0.45).timeout


## Tira o inimigo do jogo sem nada na tela: sem barra de chefe, sem iron rusks,
## sem morte. E o caminho de quem some longe do jogador e de quem cai do mapa.
func remover_em_silencio() -> void:
	dead = true
	_act = Act.NENHUMA
	_desfaz_pedregulho()
	_desfaz_espada()
	_derruba_parede()
	set_physics_process(false)
	if _passos != null:
		_passos.stop()
	_esconde_barra()
	queue_free()


func _esconde_barra() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var ui := get_tree().root.get_node_or_null("GlobalEnemyHealthUI")
	if ui != null and ui.has_method("hide_if_showing"):
		ui.hide_if_showing(self)


# ========================================================= toque na cidade

func _no_toque(corpo: Node3D) -> void:
	if dead or not is_instance_valid(corpo):
		return
	if not (corpo == player or corpo.is_in_group("player")):
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_toque < 0.8:
		return
	_ultimo_toque = agora
	_tenta_batalha_forcada(corpo)


## Toque no Maycow normal enquanto ele anda pela cidade: em vez de dano, a
## batalha na arena comeca a forca. Quem cuida da sequencia e o
## `player_amulet.gd`. Vale SO na stage_1 e depois do prologo.
##
## true = o toque foi consumido; quem chamou nao aplica mais dano nenhum.
func _tenta_batalha_forcada(corpo: Node3D) -> bool:
	if not GlobalEvents.is_maycow_normal:
		return false
	if not SaveManager.prolog_finished:
		return false
	if not corpo.has_method("force_battle_from_touch"):
		return false
	if not is_inside_tree() or get_tree() == null:
		return false
	var cena := get_tree().current_scene
	if cena == null or not cena.scene_file_path.contains("stage_1"):
		return false

	# Sequencia ja em andamento (outro inimigo encostou primeiro). O toque segue
	# CONSUMIDO, mas antes de descartar oferece este inimigo a sequencia — se
	# ela ainda nao viajou, ele embarca junto.
	if GlobalEvents.forced_battle_running:
		corpo.force_battle_from_touch(self)
		return true

	return corpo.force_battle_from_touch(self)
