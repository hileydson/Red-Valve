extends CharacterBody3D

## LEKROSO — o primeiro dos lekrosos.
##
## Um morto que anda. Nao tem poder, nao tem forma escondida: tem fome, e
## um corpo que vai se desmanchando enquanto o jogador atira nele.
##
## ==========================================================================
## O QUE ELE FAZ
##
##   longe do Maycow   PERAMBULA em volta de onde foi posto: anda torto ate'
##                     um ponto, para, balanca, olha pro nada, escolhe outro.
##   perto             (`distancia_perseguir`) vira e vem, devagar, de braco
##                     esticado. Desiste se o Maycow abrir distancia
##                     (`distancia_desistir`) e volta a perambular dali.
##   encostou          (`distancia_agarrar`) AGARRA: a cena de primeira
##                     pessoa do `player_grab.gd` (ramo "mordida"), com os
##                     clipes dele — agarra, segura, morde no pescoco e
##                     empurra o Maycow pra tras. Na arena (onde nao existe
##                     agarrao) e' o encostao comum: empurrao + dano.
##
## O andar e' DESORDENADO de proposito: o rumo balanca em volta do alvo, a
## velocidade pulsa fora de compasso, de vez em quando ele tropeca sozinho e
## o `lekroso_ossos.gd` poe tiques de nervo morto por cima de qualquer
## clipe. Dois lekrosos nunca andam igual.
##
## ==========================================================================
## SANGUE
##
## Ele deixa RASTRO: a cada meio metro uma mancha arrastada no chao (mais
## perto uma da outra quanto mais ferido ele estiver). Os dedos, o queixo e
## toda ferida aberta PINGAM, e cada gota mancha onde cai.
##
## ==========================================================================
## DANO LOCAL E DESMEMBRAMENTO
##
## O corpo tem caixas de acerto por REGIAO (camada 4, a que o raio das armas
## procura; mesmo script das do Unknown Neighbor). Cada regiao enche um
## contador proprio; cheio, a regiao perde uma peca e o contador zera:
##
##   mao, antebraco, braco   o membro CAI inteiro (o braco leva o antebraco e
##                           a mao junto). Fica no chao, esguichando sangue
##                           pelo corte; o coto tambem jorra.
##   cabeca, tronco, cintura, coxas, canelas
##                           cai um PEDACO (a lasca mais perto de onde o tiro
##                           entrou) e fica a cratera de carne. Ele continua
##                           andando — mais devagar e mancando, se forem as
##                           pernas.
##
## As pecas e o que aparece no lugar delas sao feitos no Blender
## (`tools/blender/lekrosos/`); a tabela que liga regiao -> peca e' gerada
## (`lekroso_1_dados.gd`). Aqui so' se decide QUANDO.
##
## ==========================================================================
## O CONTRATO
##
## O mesmo dos outros inimigos de script proprio (Folded Neighbor, Shadow
## Rock): grupo "enemies", `dead`, sinal `died`, `cutscene_mode`,
## `take_damage()`, `remover_em_silencio()`, barra de chefe, e o encaixe do
## amuleto (`Realidade.atualizar_disfarce` no comeco do passo de fisica; de
## sombra ele nao ve' o Maycow e so' perambula).

const Realidade := preload("res://scripts/systems/realidade_do_amuleto.gd")
const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")
const Dados := preload("res://scripts/enemies/lekrosos/lekroso_1_dados.gd")
const CaixaMembro := preload("res://scripts/enemies/folded_neighbor_limb.gd")
const Ossos := preload("res://scripts/enemies/lekrosos/lekroso_ossos.gd")
const Sangue := preload("res://scripts/enemies/lekrosos/lekroso_sangue.gd")
const Peca := preload("res://scripts/enemies/lekrosos/lekroso_peca.gd")
const SANGUE_TIRO := preload("res://scenes/effects/sangue_tiro.tscn")

const SOM_OSSO := "res://assets/sounds/igreja/transformacao_ossos.ogg"
const SOM_CARNE := "res://assets/sounds/player/blood_out.mp3"
const SOM_GOTA := "res://assets/sounds/igreja/gota_sangue.ogg"
const MORDIDAS := [
	"res://assets/sounds/igreja/mordida_1.ogg",
	"res://assets/sounds/igreja/mordida_2.ogg",
	"res://assets/sounds/igreja/mordida_3.ogg",
]
const GEMIDOS := [
	"res://assets/sounds/enemies/zombies/zombie_1_timed_sound.mp3",
	"res://assets/sounds/enemies/zombies/zombie_2_timed_sound.mp3",
	"res://assets/sounds/enemies/zombies/zombie_3_timed_sound.mp3",
]

## Velocidade do pe' de apoio de cada clipe de andar (m/s), medida no
## Blender (`animar.py` imprime): o clipe toca na razao da velocidade de
## verdade, senao o pe' patina.
const PASSADA := {"andar": 0.333, "vagar": 0.659}
## Clipes em laco (o .glb nao guarda isso).
const LACOS := ["parado", "parado_2", "vagar", "andar", "segurar"]

## Os tempos do ramo "mordida" do `player_grab.gd`, contados de quando ele
## chama `agarrao_atacar()`: a mordida fecha em 0,70 + 0,26 s e ele solta
## 0,45 s depois. A `morder` fecha a boca em 0,30 s do clipe.
const MORDIDA_NO_AGARRAO := 0.96
const SOLTA_NO_AGARRAO := 1.41
const MORDIDA_FECHA := 0.30

## Chao e paredes.
const MASCARA_CENARIO := 3

signal died

enum Estado { VAGANDO, PARADO, CACANDO, TRANCO, AGARRANDO, MORTO }

@export_group("Identidade")
## Chave de traducao (o nome mora no CSV, como todo texto do jogo).
@export var enemy_name: String = "LEKROSO_NOME"
@export var max_health: int = 200
@export var iron_rusks_value: int = 3

@export_group("Perambular e cacar")
## Ate' onde ele se afasta de onde foi posto, perambulando.
@export var raio_perambular: float = 8.0
@export var velocidade_vagar: float = 0.42
@export var velocidade_caca: float = 0.62
## Mais perto que isto do Maycow, ele larga o perambular e vem.
@export var distancia_perseguir: float = 10.0
## Mais longe que isto, desiste e volta a perambular (de onde estiver).
@export var distancia_desistir: float = 17.0
## Encostou: agarra. Vale em QUALQUER estado (cambaleando de tiro, parado,
## perambulando): perto assim, a pegada passa na frente de tudo.
@export var distancia_agarrar: float = 1.3
## Daqui pra dentro ele da' o BOTE: acelera e vira rapido pra cima do Maycow,
## pra que um passo pra tras nao desfaca a pegada.
@export var distancia_bote: float = 2.0
@export var velocidade_bote: float = 1.6
## Longe disso do jogador ele congela (economiza processamento).
@export var activation_distance: float = 120.0
## Quanto ele vira por segundo (rad). Zumbi vira devagar.
@export var giro_max: float = 1.9

@export_group("Agarrao")
@export_enum("mordida", "arremesso") var tipo_agarrao: String = "mordida"
## Desliga a cena de primeira pessoa (encontro roteirizado): volta ao
## encostao comum.
@export var permite_agarrao: bool = true
## O encostao dentro da arena.
@export var attack_damage: int = 15

@export_group("Desmembramento")
## Chance de CADA acerto arrancar uma peca da regiao onde pegou (0..1). E' o
## que faz quase todo tiro levar alguma coisa embora.
@export_range(0.0, 1.0) var chance_desmembrar: float = 0.8
## Dano que cada regiao aguenta antes de perder uma peca com certeza (o
## acerto que nao saiu no sorteio ainda conta pra isto).
@export var limite_mao: int = 10
@export var limite_antebraco: int = 14
@export var limite_braco: int = 18
@export var limite_cabeca: int = 14
@export var limite_tronco: int = 12
@export var limite_cintura: int = 12
@export var limite_coxa: int = 10
@export var limite_canela: int = 9

# --- contrato com o resto do jogo ---
var dead: bool = false
var cutscene_mode: bool = false
var current_health: int = 200
## Altura da cabeca pro `player_grab._cabeca()` (e pra barra/mira).
var altura: float = 1.88
var player: Node3D

@onready var modelo: Node3D = $modelo
@onready var growl_attack: AudioStreamPlayer3D = $growl_attack
@onready var som_passos: AudioStreamPlayer3D = $sons/passos
@onready var som_gemido: AudioStreamPlayer3D = $sons/gemido
@onready var som_dor: AudioStreamPlayer3D = $sons/dor
@onready var som_morte: AudioStreamPlayer3D = $sons/morte
@onready var som_mordida: AudioStreamPlayer3D = $sons/mordida

var _sk: Skeleton3D
var _anim: AnimationPlayer
var _ossos: SkeletonModifier3D
var _clipe: StringName = &""

var _estado: Estado = Estado.VAGANDO
var _rng := RandomNumberGenerator.new()
var _spawn_grace: float = 1.5
var _is_frozen: bool = false
var _proximity_timer: Timer

# perambular
var _home: Vector3
var _destino: Vector3
var _troca_destino: float = 0.0
var _pausa: float = 0.0
var _empacado: float = 0.0
# o desordenado
var _fase: float = 0.0
var _fase_vel: float = 0.0
var _proximo_tropeco: float = 10.0
var _tranco_ate: float = 0.0
var _tranco_avanco: float = 0.0
var _proximo_gemido: float = 4.0
# cacar / agarrar
var _viu_em: float = -10.0
var _ultimo_toque: float = -10.0
var _agarrao_serie: int = 0
var _solto_ate: float = 0.0

# sangue
var _rastro_falta: float = 0.5
var _rastro_lado: float = 1.0
var _pingos: Array = []          # {no, parte, gota}

# desmembramento
var _zonas := {}                 # zona -> {area, dano, limite, osso}
var _perdidas := {}              # peca -> true
var _malhas := {}                # "peca_x"/"corte_x" -> Mesh
var _mat_carne: StandardMaterial3D
var _mat_corte: StandardMaterial3D
var _feridas_perna: int = 0
var _janela_arranque: float = -1.0
var _arranques_na_janela: int = 0


# ======================================================================= vida

func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	current_health = max_health
	player = get_tree().get_first_node_in_group("player") as Node3D
	_fase = _rng.randf() * 100.0
	_fase_vel = _rng.randf() * 100.0
	_proximo_tropeco = _rng.randf_range(6.0, 14.0)
	_proximo_gemido = _rng.randf_range(2.0, 6.0)

	_sk = modelo.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for c in LACOS:
			if _anim.has_animation(c):
				_anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
	_guardar_pecas()
	_materiais()
	if _sk:
		_ossos = Ossos.new()
		_ossos.name = "nervo_morto"
		_sk.add_child(_ossos)
		_monta_zonas()
		_monta_pingos()

	_home = global_position
	_sorteia_destino()
	_tocar(&"parado", 0.0)

	_proximity_timer = Timer.new()
	_proximity_timer.wait_time = 0.5
	_proximity_timer.autostart = true
	add_child(_proximity_timer)
	_proximity_timer.timeout.connect(_check_proximity)
	_check_proximity()


## Mesmo congelamento por distancia do `enemy.gd`: longe do jogador nao roda
## fisica (e nao cai num chao que ainda nem tem colisao).
func _check_proximity() -> void:
	if dead:
		_proximity_timer.stop()
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(player):
			return
	var dist := global_position.distance_to(player.global_position)
	if dist <= activation_distance and _is_frozen:
		_is_frozen = false
		velocity = Vector3.ZERO
		_spawn_grace = 1.5
		set_physics_process(true)
	elif dist > activation_distance * 1.3 and not _is_frozen:
		_is_frozen = true
		velocity = Vector3.ZERO
		set_physics_process(false)


# ================================================================== a fisica

func _physics_process(delta: float) -> void:
	if _spawn_grace > 0.0:
		_spawn_grace -= delta
	if _spawn_grace <= 0.0 and global_position.y < -10.0 and not dead:
		remover_em_silencio()
		return
	if dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	var agora := Time.get_ticks_msec() / 1000.0
	_fase += delta
	_gemer(delta)

	# Sem o amuleto no pescoco do Maycow ele vira sombra e nao o ve': so'
	# perambula (o lekroso sempre perambula, entao nao ha' o que guardar).
	var sombra := not cutscene_mode and Realidade.atualizar_disfarce(self)

	if cutscene_mode:
		if is_instance_valid(player):
			_virar_para(player.global_position - global_position, delta, 3.0)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Na HORIZONTAL: a origem do Maycow e' o meio da capsula, 1 m acima do
	# chao, e a deste aqui sao os pes. Em 3D o "encostou" pedia 0,4 m.
	var dist := INF
	if is_instance_valid(player):
		dist = _dist_h(player.global_position)

	# Encostou: agarra, venha de onde vier (ate' do meio de um cambaleio). So'
	# nao pega quem esta' de sombra, recem-solto ou numa cena.
	if _estado != Estado.AGARRANDO and dist <= distancia_agarrar and not sombra \
			and agora > _solto_ate and agora - _ultimo_toque > 1.6 \
			and not GlobalEvents.in_cutscene:
		if _estado != Estado.CACANDO:
			_comecar_caca(agora)
		_ultimo_toque = agora
		_pegar(agora)

	match _estado:
		Estado.TRANCO:
			_passo_tranco(delta, agora)
		Estado.AGARRANDO:
			velocity.x = move_toward(velocity.x, 0.0, 4.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 4.0 * delta)
		_:
			var ve := not sombra and dist < distancia_perseguir and agora > _solto_ate \
				and not GlobalEvents.in_cutscene
			if _estado == Estado.CACANDO and (sombra or dist > distancia_desistir):
				_parar_de_cacar()
			elif _estado != Estado.CACANDO and ve:
				_comecar_caca(agora)
			if _estado == Estado.CACANDO:
				_cacar(delta, dist, agora)
			else:
				_vagar(delta)
			_talvez_tropecar(delta)

	move_and_slide()
	_rastro(delta)
	_pingar(delta)


# ------------------------------------------------------------ perambular

func _vagar(delta: float) -> void:
	if _estado == Estado.PARADO:
		_pausa -= delta
		velocity.x = move_toward(velocity.x, 0.0, 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 3.0 * delta)
		if _pausa <= 0.0:
			_estado = Estado.VAGANDO
			_sorteia_destino()
		return

	_troca_destino -= delta
	var para := _destino - global_position
	para.y = 0.0
	if para.length() < 0.8 or _troca_destino <= 0.0:
		# chegou (ou cansou do ponto): para um pouco, balancando no lugar
		_estado = Estado.PARADO
		_pausa = _rng.randf_range(1.8, 5.5)
		_tocar(&"parado" if _rng.randf() < 0.65 else &"parado_2", 0.5)
		return
	_andar(para, velocidade_vagar, &"vagar", delta, 0.45)
	_vigiar_empacado(delta)


func _sorteia_destino() -> void:
	_troca_destino = _rng.randf_range(9.0, 18.0)
	_empacado = 0.0
	for i in 14:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(raio_perambular * 0.3, raio_perambular)
		var cand := _home + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		# na cidade, prefere a rua (o grid das sombras); fora dela, qualquer chao
		if i < 8 and not ShadowRoads.is_road(cand):
			continue
		if _caminho_livre(cand):
			_destino = cand
			return
	_destino = _home


## Tem chao la' (na mesma altura, mais ou menos) e nada no meio do caminho?
func _caminho_livre(cand: Vector3) -> bool:
	var espaco := get_world_3d().direct_space_state
	var c := PhysicsRayQueryParameters3D.create(cand + Vector3.UP * 1.5, cand + Vector3.DOWN * 3.0,
		MASCARA_CENARIO, [get_rid()])
	var piso := espaco.intersect_ray(c)
	if piso.is_empty() or absf((piso["position"] as Vector3).y - global_position.y) > 1.0:
		return false
	var de := global_position + Vector3.UP * 0.6
	var ate := Vector3(cand.x, (piso["position"] as Vector3).y + 0.6, cand.z)
	var q := PhysicsRayQueryParameters3D.create(de, ate, MASCARA_CENARIO, [get_rid()])
	return espaco.intersect_ray(q).is_empty()


## Andando contra a parede: desiste do ponto e escolhe outro do lado de la'.
func _vigiar_empacado(delta: float) -> void:
	var real := get_real_velocity()
	if Vector2(real.x, real.z).length() < 0.08:
		_empacado += delta
		if _empacado > 1.2:
			if is_on_wall():
				_home = global_position + get_wall_normal() * 2.0
			_sorteia_destino()
	else:
		_empacado = 0.0


# ------------------------------------------------------------ cacar

func _comecar_caca(agora: float) -> void:
	_estado = Estado.CACANDO
	if agora - _viu_em > 6.0:
		# notou agora: rosna
		if not growl_attack.playing:
			growl_attack.pitch_scale = _rng.randf_range(0.85, 1.05)
			growl_attack.play()
	_viu_em = agora


func _parar_de_cacar() -> void:
	_estado = Estado.VAGANDO
	_home = global_position
	_sorteia_destino()


func _cacar(delta: float, dist: float, agora: float) -> void:
	if not is_instance_valid(player):
		_parar_de_cacar()
		return
	var para := player.global_position - global_position
	para.y = 0.0
	if dist <= distancia_bote and agora - _ultimo_toque > 1.6:
		_bote(para, delta)
		return
	_andar(para, velocidade_caca, &"andar", delta, 0.22)


## Os ultimos dois metros: sem o andar torto, virando rapido e acelerando
## pra cima do Maycow, de braco esticado.
func _bote(para: Vector3, delta: float) -> void:
	var rumo := para.normalized()
	_virar_para(rumo, delta, giro_max * 3.0)
	var alvo := rumo * velocidade_bote * maxf(_mancando(), 0.7)
	velocity.x = lerpf(velocity.x, alvo.x, clampf(delta * 6.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, alvo.z, clampf(delta * 6.0, 0.0, 1.0))
	var real := Vector2(velocity.x, velocity.z).length()
	_tocar(&"andar", 0.25, clampf(real / float(PASSADA["andar"]), 0.8, 2.2))


# ------------------------------------------------------------ o passo

## Anda torto na direcao `para`: o rumo balanca em volta do alvo, a
## velocidade pulsa, e o corpo so' vira o que um zumbi consegue virar.
func _andar(para: Vector3, vel_base: float, clipe: StringName, delta: float,
		balanco: float) -> void:
	if para.length() < 0.01:
		return
	var torto := sin(_fase * 0.83) * balanco + sin(_fase * 2.1 + 1.7) * balanco * 0.35
	var rumo := para.normalized().rotated(Vector3.UP, torto)
	_virar_para(rumo, delta, giro_max)

	var pulso := 0.72 + 0.5 * (0.5 + 0.5 * sin(_fase_vel + _fase * 1.37)) \
		+ 0.12 * sin(_fase * 3.3)
	var vel := vel_base * pulso * _mancando()
	# anda pra onde o corpo aponta, nao pra onde quer ir: faz a curva larga
	var frente := global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var alinhado := clampf(frente.dot(rumo), 0.0, 1.0)
	var lado := global_basis.x * sin(_fase * 1.9) * 0.06
	var alvo := frente * vel * (0.35 + 0.65 * alinhado) + lado
	velocity.x = lerpf(velocity.x, alvo.x, clampf(delta * 3.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, alvo.z, clampf(delta * 3.0, 0.0, 1.0))

	var real := Vector2(velocity.x, velocity.z).length()
	_tocar(clipe, 0.4, clampf(real / float(PASSADA[String(clipe)]), 0.55, 1.9))
	if not som_passos.playing:
		som_passos.pitch_scale = _rng.randf_range(0.75, 0.9)
		som_passos.play()


## Cacando e a menos de `distancia_bote` do Maycow: nada de tropeco nem de
## pancada leve que desfaca a pegada.
func _no_bote() -> bool:
	return _estado == Estado.CACANDO and is_instance_valid(player) \
		and _dist_h(player.global_position) <= distancia_bote


func _dist_h(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _virar_para(dir: Vector3, delta: float, taxa: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	# a frente do modelo e' o +Z
	var alvo := atan2(dir.x, dir.z)
	var dif := wrapf(alvo - rotation.y, -PI, PI)
	rotation.y += clampf(dif, -taxa * delta, taxa * delta)


## Perna machucada: cada pedaco perdido das pernas tira um pouco da
## velocidade, e o passo passa a mancar (pulsando no ritmo da passada).
func _mancando() -> float:
	if _feridas_perna == 0:
		return 1.0
	var base := maxf(1.0 - 0.09 * _feridas_perna, 0.55)
	return base * (0.75 + 0.25 * absf(sin(_fase * 2.6)))


func _talvez_tropecar(delta: float) -> void:
	if _estado != Estado.VAGANDO and _estado != Estado.CACANDO:
		return
	if _no_bote():
		return
	_proximo_tropeco -= delta * (1.0 + 0.25 * _feridas_perna)
	if _proximo_tropeco > 0.0:
		return
	_proximo_tropeco = _rng.randf_range(7.0, 16.0)
	_tranco(&"tropeco", 0.6, 0.55)


## Um clipe que toma conta do corpo por um instante (tropeco, pancada, perder
## um membro). `avanco` e' quanto ele ainda escorrega pra frente no comeco.
func _tranco(clipe: StringName, avanco: float = 0.0, mistura: float = 0.15) -> void:
	if not _anim or not _anim.has_animation(clipe):
		return
	if _estado == Estado.AGARRANDO or dead:
		return
	var volta := _estado
	if volta == Estado.TRANCO or volta == Estado.PARADO:
		volta = Estado.VAGANDO
	_estado = Estado.TRANCO
	set_meta("_volta", volta)
	_tocar(clipe, mistura)
	_tranco_ate = Time.get_ticks_msec() / 1000.0 + _anim.get_animation(clipe).length * 0.92
	_tranco_avanco = avanco
	som_passos.stop()


func _passo_tranco(delta: float, agora: float) -> void:
	var frente := global_basis.z * _tranco_avanco
	_tranco_avanco = move_toward(_tranco_avanco, 0.0, delta * 1.2)
	velocity.x = lerpf(velocity.x, frente.x, clampf(delta * 5.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, frente.z, clampf(delta * 5.0, 0.0, 1.0))
	if agora >= _tranco_ate:
		_estado = get_meta("_volta", Estado.VAGANDO)
		if _estado == Estado.VAGANDO:
			_sorteia_destino()


# ============================================================== o agarrao

## Encostou no Maycow: fora da arena, AGARRA (a cena e' do player_grab.gd);
## dentro dela, o encostao comum.
func _pegar(_agora: float) -> void:
	if _tenta_agarrao(player):
		_estado = Estado.AGARRANDO
		som_passos.stop()
		return
	# sem agarrao: o bote vira um tapa com empurrao
	_tranco(&"agarrar", 0.3, 0.1)
	get_tree().create_timer(0.35, false).timeout.connect(func():
		if dead or not is_instance_valid(player):
			return
		if _dist_h(player.global_position) < distancia_agarrar + 0.5:
			_encostao(player))


## Copia do `_tenta_agarrao` dos outros inimigos (nenhum herda de um tronco
## comum). true = o toque foi consumido.
func _tenta_agarrao(body: Node3D) -> bool:
	if not permite_agarrao:
		return false
	if Realidade.oculto():
		return false
	if not GlobalEvents.is_maycow_normal:
		return false
	if not is_instance_valid(body) or not body.has_method("grab_from_touch"):
		return false
	if not is_inside_tree() or get_tree() == null:
		return false
	return body.grab_from_touch(self)


## O empurrao + dano de dentro da arena (o mesmo do `enemy.gd`, curto: com
## raio pra nao atravessar parede).
func _encostao(body: Node3D) -> void:
	if Realidade.oculto() or body.get("invulnerable") == true:
		return
	var direcao := body.global_position - global_position
	direcao.y = 0.0
	direcao = direcao.normalized()
	var destino := body.global_position + direcao * 2.5
	if body is PhysicsBody3D:
		var alto := Vector3.UP
		var q := PhysicsRayQueryParameters3D.create(body.global_position + alto, destino + alto,
			(body as PhysicsBody3D).collision_mask, [(body as PhysicsBody3D).get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			var livre := maxf(body.global_position.distance_to(hit["position"] - alto) - 0.4, 0.0)
			destino = body.global_position + direcao * livre
	create_tween().tween_property(body, "global_position", destino, 0.2).set_trans(Tween.TRANS_QUAD)
	GlobalUtils.shake_camera(0.2, 0.2)
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)


## Chamado pelo `player_grab.gd` quando as maos fecham no Maycow. Os clipes
## seguem os tempos do ramo "mordida" dele: agarra, segura, morde no
## pescoco, empurra.
func agarrao_atacar() -> void:
	_estado = Estado.AGARRANDO
	_agarrao_serie += 1
	var serie := _agarrao_serie
	_tocar(&"agarrar", 0.1)
	_recuar_modelo(true)
	await _espera(0.53)
	if serie != _agarrao_serie or dead:
		return
	_tocar(&"segurar", 0.12)
	await _espera(MORDIDA_NO_AGARRAO - MORDIDA_FECHA - 0.53)
	if serie != _agarrao_serie or dead:
		return
	_tocar(&"morder", 0.08)
	await _espera(MORDIDA_FECHA)
	if serie != _agarrao_serie or dead:
		return
	som_mordida.stream = load(MORDIDAS[_rng.randi() % MORDIDAS.size()])
	som_mordida.pitch_scale = _rng.randf_range(0.85, 1.0)
	som_mordida.play()
	if not growl_attack.playing:
		growl_attack.play()
	# o sangue do Maycow na boca dele: escorre do queixo dali pra frente
	_reforca_pingo_do_queixo()
	await _espera(SOLTA_NO_AGARRAO - MORDIDA_NO_AGARRAO - 0.04)
	if serie != _agarrao_serie or dead:
		return
	_tocar(&"empurrar", 0.08)
	_recuar_modelo(false)


## O agarrao poe este corpo a 1,05 m e depois a MEIO METRO do Maycow; com
## os bracos e a cabeca indo pra cima dele, a camera de primeira pessoa
## ficava dentro da cabeca. So' o modelo recua (o no' fica onde o
## player_grab mandou), do bote ate' o empurrao.
func _recuar_modelo(recuar: bool) -> void:
	if not is_instance_valid(modelo):
		return
	var tw := create_tween()
	tw.tween_property(modelo, "position:z", -0.24 if recuar else 0.0, 0.12 if recuar else 0.3) \
		.set_trans(Tween.TRANS_SINE)


## O `player_grab.gd` soltou (fim da cena, ou ela morreu no meio).
func agarrao_soltou() -> void:
	_agarrao_serie += 1
	_recuar_modelo(false)
	if dead:
		return
	_estado = Estado.PARADO
	_pausa = 1.4
	_solto_ate = Time.get_ticks_msec() / 1000.0 + 1.6
	_tocar(&"parado", 0.4)


func _espera(s: float) -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(maxf(s, 0.0), true, false, true).timeout


# =============================================================== o dano

## Dano sem regiao: corpo (a capsula fina da espinha), cogblade, fogo,
## ultimate. A regiao sai do raio da camera, que e' pra onde o jogador mirou.
func take_damage(amount) -> void:
	if dead:
		return
	_dano_na_zona(_zona_pelo_golpe(), int(amount), false)


## O tiro entrou numa caixa de regiao (`folded_neighbor_limb.gd`), ja' com o
## multiplicador dela.
func dano_no_membro(zona: String, quanto: int) -> void:
	if dead:
		return
	_dano_na_zona(zona, quanto, true)


func _dano_na_zona(zona: String, quanto: int, por_caixa: bool) -> void:
	current_health = clampi(current_health - quanto, 0, max_health)
	if is_instance_valid(player) and player.has_method("add_cogblade_power"):
		player.add_cogblade_power(float(quanto), _centro_da_zona(zona))
	_mostra_barra()
	if not som_dor.playing:
		som_dor.pitch_scale = _rng.randf_range(0.8, 1.05)
		som_dor.play()
	# a caixa nao esta' no grupo "enemies" (a cogblade bateria em cada uma),
	# entao o sangue do tiro sai daqui
	if por_caixa:
		_sangue_do_tiro(_centro_da_zona(zona))

	if current_health <= 0:
		die()
		return

	var z: Dictionary = _zonas.get(zona, {})
	if not z.is_empty():
		z["dano"] = int(z["dano"]) + quanto
		var sorteou := _rng.randf() < chance_desmembrar
		if (sorteou or int(z["dano"]) >= int(z["limite"])) and _pode_arrancar_agora():
			z["dano"] = 0
			if _arrancar(zona):
				return
	# a pancada: nem todo tiro derruba o passo (e no bote, nenhum)
	if _estado != Estado.TRANCO and _estado != Estado.AGARRANDO and not _no_bote() \
			and _rng.randf() < 0.45:
		_tranco(&"dano", 0.0, 0.1)


## No maximo duas pecas a cada 0,15 s: os 7 chumbos de um tiro de cacadeira
## chegam no mesmo quadro, e cada um arrancaria uma.
func _pode_arrancar_agora() -> bool:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _janela_arranque > 0.15:
		_janela_arranque = agora
		_arranques_na_janela = 0
	if _arranques_na_janela >= 2:
		return false
	_arranques_na_janela += 1
	return true


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


func _sangue_do_tiro(onde: Vector3) -> void:
	var cena := get_tree().current_scene
	if cena == null:
		return
	var s := SANGUE_TIRO.instantiate()
	cena.add_child(s)
	s.global_position = onde
	var cam := get_viewport().get_camera_3d()
	if cam:
		var para := (cam.global_position - onde)
		if para.length() > 0.05:
			s.look_at(onde + para.normalized(), Vector3.UP)


## Pra onde o jogador mirou: a regiao (ainda inteira) mais perto do raio que
## sai do centro da camera. Longe de todas, uma do lado de quem bateu.
func _zona_pelo_golpe() -> String:
	var cam := get_viewport().get_camera_3d()
	var melhor := ""
	var menor := 0.55
	if cam:
		var o := cam.global_position
		var d := -cam.global_basis.z
		for zona in _zonas:
			var z: Dictionary = _zonas[zona]
			if not is_instance_valid(z["area"]):
				continue
			var c := _centro_da_zona(zona)
			var rel := c - o
			var ao_longo := rel.dot(d)
			if ao_longo < 0.0:
				continue
			var fora := (rel - d * ao_longo).length()
			if fora < menor:
				menor = fora
				melhor = zona
	if melhor != "":
		return melhor
	var vivas := []
	for zona in ["tronco", "tronco", "cintura", "braco_l", "braco_r", "cabeca", "coxa_l", "coxa_r"]:
		if _zonas.has(zona) and is_instance_valid(_zonas[zona]["area"]):
			vivas.append(zona)
	return "tronco" if vivas.is_empty() else String(vivas[_rng.randi() % vivas.size()])


func _centro_da_zona(zona: String) -> Vector3:
	var z: Dictionary = _zonas.get(zona, {})
	if not z.is_empty() and is_instance_valid(z["forma"]):
		return (z["forma"] as Node3D).global_position
	return global_position + Vector3.UP * 1.3


func die() -> void:
	if dead:
		return
	dead = true
	_estado = Estado.MORTO
	_agarrao_serie += 1
	died.emit()
	SaveManager.add_iron_rusks(iron_rusks_value)
	som_passos.stop()
	som_morte.play()
	velocity = Vector3.ZERO
	_tocar(&"morrer", 0.2)
	if _ossos:
		_ossos.intensidade = 0.25
	for zona in _zonas:
		var a = _zonas[zona]["area"]
		if is_instance_valid(a):
			(a as Area3D).set_deferred("monitorable", false)
			(a as CollisionObject3D).collision_layer = 0
	# a poca embaixo quando o corpo bate no chao
	get_tree().create_timer(2.6, false).timeout.connect(func():
		if is_inside_tree():
			Sangue.poca(get_tree(), get_world_3d(), global_position + global_basis.z * 0.7,
				1.6, 7.0, 70.0))
	get_tree().create_timer(1.0, false).timeout.connect(func():
		if is_inside_tree():
			set_collision_layer_value(3, false))
	get_tree().create_timer(30.0, false).timeout.connect(_afundar_corpo)


func _afundar_corpo() -> void:
	if not is_inside_tree():
		return
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3.DOWN * 0.5, 4.0)
	tw.tween_callback(queue_free)


## Some sem nada na tela: sem barra, sem iron rusks, sem morte (o spawner da
## cidade usa isto ao liberar quem ficou longe; quem cai do mapa tambem).
func remover_em_silencio() -> void:
	dead = true
	_agarrao_serie += 1
	set_physics_process(false)
	if is_instance_valid(som_passos):
		som_passos.stop()
	if is_inside_tree() and get_tree() != null:
		var hud := get_tree().root.get_node_or_null("GlobalEnemyHealthUI")
		if hud != null and hud.has_method("hide_if_showing"):
			hud.hide_if_showing(self)
	queue_free()


# ========================================================= desmembramento

## As regioes e o que cada uma tem. [osso, ate' onde vai, raio, multiplicador]
## O "ate'" e' outro osso, ou um ponto em METROS a partir do osso no espaco
## do esqueleto (frente = +Z), medido no repouso.
func _tabela_zonas() -> Dictionary:
	var t := {
		"cabeca": ["head", Vector3(0.0, 0.21, 0.05), 0.115, 1.5, limite_cabeca],
		"tronco": ["chest", "neck", 0.20, 1.0, limite_tronco],
		"cintura": ["hips", "chest", 0.19, 0.9, limite_cintura],
	}
	for l: String in ["l", "r"]:
		var L := l.to_upper()
		t["braco_" + l] = ["upper_arm." + L, "forearm." + L, 0.066, 0.7, limite_braco]
		t["antebraco_" + l] = ["forearm." + L, "hand." + L, 0.056, 0.6, limite_antebraco]
		t["mao_" + l] = ["hand." + L, "@mao", 0.058, 0.5, limite_mao]
		t["coxa_" + l] = ["thigh." + L, "shin." + L, 0.092, 0.75, limite_coxa]
		t["canela_" + l] = ["shin." + L, "foot." + L, 0.072, 0.65, limite_canela]
	return t


func _monta_zonas() -> void:
	var t := _tabela_zonas()
	for zona in t:
		var d: Array = t[zona]
		var i := _sk.find_bone(d[0])
		if i < 0:
			continue
		var base := _sk.get_bone_global_rest(i)
		var fim_sk: Vector3
		if d[1] is Vector3:
			fim_sk = base.origin + d[1]
		elif d[1] == "@mao":
			# a mao vai do pulso ate' a ponta dos dedos, na linha do antebraco
			var p := _sk.get_bone_parent(i)
			var dir := (base.origin - _sk.get_bone_global_rest(p).origin).normalized()
			fim_sk = base.origin + dir * 0.17
		else:
			fim_sk = _sk.get_bone_global_rest(_sk.find_bone(d[1])).origin
		var local := base.affine_inverse() * fim_sk

		var att := BoneAttachment3D.new()
		att.name = "zona_" + zona
		att.bone_name = d[0]
		_sk.add_child(att)
		var area := Area3D.new()
		area.name = "heart" if zona == "cabeca" else ("membro_" + zona)
		area.collision_layer = 8
		area.collision_mask = 0
		area.monitoring = false
		area.set_script(CaixaMembro)
		area.set("membro", zona)
		area.set("multiplicador", float(d[3]))
		area.set("dono", self)
		att.add_child(area)
		var forma := _capsula(local, float(d[2]))
		area.add_child(forma)
		# o pe' entra na canela: tiro no sapato tambem conta
		if zona.begins_with("canela"):
			var pe := _sk.find_bone("foot." + zona.right(1).to_upper())
			var ponta := _sk.find_bone("toe." + zona.right(1).to_upper())
			if pe >= 0 and ponta >= 0:
				var de_pe := base.affine_inverse() * _sk.get_bone_global_rest(pe).origin
				var ate_ponta := base.affine_inverse() * _sk.get_bone_global_rest(ponta).origin
				var f2 := _capsula(ate_ponta - de_pe, 0.06)
				f2.position += de_pe
				area.add_child(f2)
		_zonas[zona] = {"area": area, "att": att, "forma": forma, "dano": 0,
			"limite": maxi(int(d[4]), 6), "osso": d[0]}


## Capsula do ponto 0 ate' `local` (no espaco do osso).
func _capsula(local: Vector3, raio: float) -> CollisionShape3D:
	var forma := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var comp := maxf(local.length(), 0.02)
	cap.radius = raio
	cap.height = maxf(comp + raio * 2.0, raio * 2.05)
	forma.shape = cap
	forma.position = local * 0.5
	if local.length() > 0.001:
		var eixo := local.normalized()
		var giro := Vector3.UP.cross(eixo)
		if giro.length() > 0.0001:
			forma.rotate(giro.normalized(), Vector3.UP.angle_to(eixo))
		elif eixo.y < 0.0:
			forma.rotate(Vector3.RIGHT, PI)
	return forma


## Arranca a proxima peca da regiao. true = alguma peca saiu.
func _arrancar(zona: String) -> bool:
	if Dados.PECAS.has(zona) and Dados.PECAS[zona]["tipo"] == "membro":
		return _arrancar_membro(zona)
	return _arrancar_pedaco(zona)


func _arrancar_membro(membro: String) -> bool:
	if _perdidas.has(membro):
		return false
	# o membro leva junto tudo o que esta' pendurado nele
	var grupo: Array[String] = [membro]
	var cortes: Array[String] = []
	for filho in Dados.PECAS:
		var f: Dictionary = Dados.PECAS[filho]
		if f["tipo"] == "membro" and _pendurado_em(filho, membro):
			if _perdidas.has(filho):
				# ja' tinha caido: a ponta do membro e' o coto dele
				if not _perdidas.has(String(f["pai"])):
					cortes.append(filho)
			else:
				grupo.append(filho)
	var info: Dictionary = Dados.PECAS[membro]
	var junta: Vector3 = info.get("junta", info["centro"])
	var normal: Vector3 = info["normal"]
	var pai_osso := _osso_acima(membro)
	# tudo o que cai some pra dentro do coto (3 cm aquem da junta), preso no
	# osso de cima — o membro de baixo continua animado, invisivel
	var sumidouro := junta - normal * 0.03
	for p in grupo:
		_perdidas[p] = true
		if _ossos:
			_ossos.sumir(p, pai_osso, sumidouro)
			_ossos.perdeu_osso(String(Dados.PECAS[p]["osso"]))
			if p.begins_with("mao"):
				_ossos.perdeu_osso("fingers." + p.right(1).to_upper())
				_ossos.perdeu_osso("thumb." + p.right(1).to_upper())
		_apaga_zona(p)
		_desliga_pingos_de(p)

	_soltar(grupo, cortes, junta, -normal, true)

	# o coto: jorra em golfadas e depois pinga, preso no osso de cima
	if pai_osso != "":
		var pivo := _pivo_no_osso(pai_osso, junta, normal)
		if pivo:
			var j := Sangue.jorro(1.0 if membro.begins_with("braco") else 0.8)
			pivo.add_child(j)
			Sangue.pulsar(j, 6.5, 0.55)
			var pg := Sangue.pingos(0.9)
			pivo.add_child(pg)
			pg.emitting = true
			_pingos.append({"no": pivo, "parte": _parte_acima(membro), "gota": 0.3, "forte": true})

	Sangue.som(self, _sk.global_transform * junta, SOM_OSSO, 2.0, _rng.randf_range(0.9, 1.1))
	Sangue.som(self, _sk.global_transform * junta, SOM_CARNE, 0.0, _rng.randf_range(0.7, 0.85))
	if is_instance_valid(som_dor):
		som_dor.pitch_scale = 0.75
		som_dor.play()
	GlobalUtils.shake_camera(0.3, 0.22)
	if _ossos:
		_ossos.intensidade = minf(_ossos.intensidade + 0.25, 2.0)
	# no bote ele nem sente: o braco cai e ele continua vindo
	if not _no_bote():
		_tranco(&"dano_forte", 0.0, 0.08)
	return true


func _arrancar_pedaco(zona: String) -> bool:
	var vivos: Array[String] = []
	for p in Dados.PECAS:
		var d: Dictionary = Dados.PECAS[p]
		if d["tipo"] == "pedaco" and d["zona"] == zona and not _perdidas.has(p):
			vivos.append(p)
	if vivos.is_empty():
		# a regiao ja' esta' em carne viva: so' espirra
		var z: Dictionary = _zonas.get(zona, {})
		if not z.is_empty():
			Sangue.estouro(get_tree().current_scene, _centro_da_zona(zona),
				_para_quem_bateu(_centro_da_zona(zona)), 0.6)
		return false

	# a lasca mais perto de onde o tiro entrou (o raio da camera)
	var escolha := vivos[0]
	var cam := get_viewport().get_camera_3d()
	if cam:
		var o := cam.global_position
		var dcam := -cam.global_basis.z
		var menor := INF
		for p in vivos:
			var c := _no_mundo(p, Dados.PECAS[p]["centro"])
			var rel := c - o
			var fora := (rel - dcam * rel.dot(dcam)).length()
			# lasca do outro lado do corpo nao conta (o tiro nao atravessa)
			var n := _normal_no_mundo(p, Dados.PECAS[p]["normal"])
			if n.dot(-dcam) < -0.2:
				fora += 0.5
			if fora < menor:
				menor = fora
				escolha = p
	else:
		escolha = vivos[_rng.randi() % vivos.size()]

	_perdidas[escolha] = true
	var info: Dictionary = Dados.PECAS[escolha]
	var centro: Vector3 = info["centro"]
	var normal: Vector3 = info["normal"]
	if _ossos:
		# some pro fundo da cratera
		_ossos.sumir(escolha, String(info["osso"]), centro - normal * 0.045)
		_ossos.intensidade = minf(_ossos.intensidade + 0.08, 2.0)
	var so_ela: Array[String] = [escolha]
	var nenhum: Array[String] = []
	_soltar(so_ela, nenhum, centro, -normal, false)
	Sangue.estouro(get_tree().current_scene, _sk.global_transform * centro,
		_normal_no_mundo(escolha, normal), 0.9)
	Sangue.som(self, _sk.global_transform * centro, SOM_CARNE, 1.0, _rng.randf_range(0.8, 1.0))

	# a cratera fica pingando
	var pivo := _pivo_no_osso(String(info["osso"]), centro, normal)
	if pivo:
		var j := Sangue.jorro(0.45)
		pivo.add_child(j)
		Sangue.pulsar(j, 1.6, 0.4)
		var pg := Sangue.pingos(0.5)
		pivo.add_child(pg)
		pg.emitting = true
		_pingos.append({"no": pivo, "parte": "", "gota": 0.5, "forte": false})
	if zona.begins_with("coxa") or zona.begins_with("canela"):
		_feridas_perna += 1
	return true


func _pendurado_em(filho: String, membro: String) -> bool:
	var p := String(Dados.PECAS[filho].get("pai", ""))
	var voltas := 0
	while p != "" and voltas < 4:
		if p == membro:
			return true
		p = String(Dados.PECAS[p].get("pai", ""))
		voltas += 1
	return false


## O osso em que o coto fica: o principal do membro de cima, ou o ombro.
func _osso_acima(membro: String) -> String:
	var pai := String(Dados.PECAS[membro].get("pai", ""))
	if pai != "":
		return String(Dados.PECAS[pai]["osso"])
	var i := _sk.find_bone(String(Dados.PECAS[membro]["osso"]))
	return _sk.get_bone_name(_sk.get_bone_parent(i)) if i >= 0 else ""


func _parte_acima(membro: String) -> String:
	return String(Dados.PECAS[membro].get("pai", ""))


func _apaga_zona(zona: String) -> void:
	var z: Dictionary = _zonas.get(zona, {})
	if z.is_empty():
		return
	if is_instance_valid(z["att"]):
		(z["att"] as Node).queue_free()
	_zonas.erase(zona)


## A peca (ou o membro com o que esta' pendurado nele) cai, na pose de agora.
func _soltar(nomes: Array[String], cortes: Array[String], ponto_corte: Vector3,
		normal_corte: Vector3, membro: bool) -> void:
	var cena := get_tree().current_scene
	if cena == null or _sk == null:
		return
	var principal := nomes[0]
	var malha_p: Mesh = _malhas.get("peca_" + principal)
	if malha_p == null:
		return
	var x_p := _pose_do_osso(String(Dados.PECAS[principal]["osso"]))
	var centro_rest := malha_p.get_aabb().get_center()
	var corpo_x := x_p * Transform3D(Basis(), centro_rest)

	var peca := Peca.new()
	peca.e_membro = membro
	peca.tempo_jorro = 4.5 if membro else 1.2
	peca.forca_jorro = 0.85 if membro else 0.4
	peca.tam_poca = 0.75 if membro else 0.3
	peca.permanencia = 120.0 if membro else 70.0
	peca.mass = clampf(float(Dados.PECAS[principal]["massa"]) / 600.0, 0.3, 4.0)
	peca.corte_local = ponto_corte - centro_rest
	peca.corte_normal = normal_corte
	var caixa := malha_p.get_aabb().size
	if nomes.size() > 1:
		# o membro inteiro: o mais fino e' a grossura, o mais longo o braco
		peca.eixo_fino = Vector3.RIGHT if caixa.x <= caixa.z else Vector3.BACK
	elif caixa.x <= caixa.y and caixa.x <= caixa.z:
		peca.eixo_fino = Vector3.RIGHT
	elif caixa.y <= caixa.z:
		peca.eixo_fino = Vector3.UP
	else:
		peca.eixo_fino = Vector3.BACK
	var inv := corpo_x.affine_inverse()

	var partes: Array = []
	for n in nomes:
		partes.append(["peca_" + n, String(Dados.PECAS[n]["osso"])])
	for c in cortes:
		partes.append(["corte_" + c, _osso_acima(c)])
	for par in partes:
		var m: Mesh = _malhas.get(par[0])
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.transform = inv * _pose_do_osso(par[1])
		_materiais_da_peca(mi)
		peca.add_child(mi)
		var f := CollisionShape3D.new()
		f.shape = m.create_convex_shape(true, true)
		f.transform = mi.transform
		peca.add_child(f)

	cena.add_child(peca)
	peca.global_transform = corpo_x
	# sai com a velocidade do corpo, pra fora dele e pra longe de quem bateu
	var mundo := peca.global_position
	var fora := mundo - (global_position + Vector3.UP * 1.1)
	fora.y = 0.0
	var tiro := _para_quem_bateu(mundo) * -1.0
	tiro.y = 0.0
	var dir := (fora.normalized() * 0.6 + tiro.normalized() * 0.4).normalized()
	peca.linear_velocity = velocity * 0.6 + dir * _rng.randf_range(1.0, 2.2) \
		+ Vector3.UP * _rng.randf_range(0.8, 2.0)
	peca.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-4, 4),
		_rng.randf_range(-6, 6)) * (0.6 if membro else 1.0)


## Onde o osso esta' AGORA, como transformacao que leva o repouso (o espaco
## das pecas) pra pose — no mundo.
func _pose_do_osso(nome: String) -> Transform3D:
	var i := _sk.find_bone(nome)
	if i < 0:
		return _sk.global_transform
	return _sk.global_transform * _sk.get_bone_global_pose(i) * _sk.get_bone_global_rest(i).affine_inverse()


func _no_mundo(peca: String, p_rest: Vector3) -> Vector3:
	return _pose_do_osso(String(Dados.PECAS[peca]["osso"])) * p_rest


func _normal_no_mundo(peca: String, n_rest: Vector3) -> Vector3:
	return (_pose_do_osso(String(Dados.PECAS[peca]["osso"])).basis * n_rest).normalized()


func _para_quem_bateu(de: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var alvo := cam.global_position if cam else (player.global_position if is_instance_valid(player) else de + Vector3.BACK)
	var d := alvo - de
	return d.normalized() if d.length() > 0.01 else Vector3.UP


## Um pivo preso num osso, no ponto `p_rest` (espaco do esqueleto), com o -Z
## apontando pra `n_rest`. E' onde mora jorro e pingo de uma ferida.
func _pivo_no_osso(osso: String, p_rest: Vector3, n_rest: Vector3) -> Node3D:
	var i := _sk.find_bone(osso)
	if i < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = osso
	_sk.add_child(att)
	var pivo := Node3D.new()
	att.add_child(pivo)
	var base := _sk.get_bone_global_rest(i).affine_inverse()
	var local := base * p_rest
	var n_local := (base.basis * n_rest).normalized()
	var cima := Vector3.UP if absf(n_local.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	pivo.transform = Transform3D(Basis.looking_at(n_local, cima), local)
	return pivo


# ================================================================ sangue

## Os pingos de sempre: as pontas dos dedos e o queixo.
func _monta_pingos() -> void:
	for l in ["L", "R"]:
		var i := _sk.find_bone("fingers." + l)
		if i >= 0:
			var p := _sk.get_bone_global_rest(i).origin
			var d := (p - _sk.get_bone_global_rest(_sk.get_bone_parent(i)).origin).normalized()
			var pivo := _pivo_no_osso("fingers." + l, p + d * 0.07, Vector3.DOWN)
			if pivo:
				var pg := Sangue.pingos(0.35)
				pivo.add_child(pg)
				pg.emitting = true
				_pingos.append({"no": pivo, "parte": "mao_" + l.to_lower(), "gota": _rng.randf(),
					"forte": false})
	var h := _sk.find_bone("head")
	if h >= 0:
		var queixo := _sk.get_bone_global_rest(h).origin + Vector3(0.0, -0.02, 0.13)
		var pivo := _pivo_no_osso("head", queixo, Vector3.DOWN)
		if pivo:
			var pg := Sangue.pingos(0.25)
			pg.name = "pingos_queixo"
			pivo.add_child(pg)
			pg.emitting = true
			_pingos.append({"no": pivo, "parte": "", "gota": _rng.randf(), "forte": false,
				"queixo": true})


func _reforca_pingo_do_queixo() -> void:
	for p in _pingos:
		if p.get("queixo", false) and is_instance_valid(p["no"]):
			var pg := (p["no"] as Node).get_node_or_null("pingos_queixo") as GPUParticles3D
			if pg:
				pg.amount = 12
			p["forte"] = true


func _desliga_pingos_de(parte: String) -> void:
	for p in _pingos:
		if p["parte"] == parte and is_instance_valid(p["no"]):
			for f in (p["no"] as Node).get_children():
				if f is GPUParticles3D:
					(f as GPUParticles3D).emitting = false
			p["parte"] = "@perdido"


## Cada pingo mancha o chao embaixo dele de vez em quando (o GPUParticles
## nao colide com nada; a mancha e' que diz onde a gota caiu).
func _pingar(delta: float) -> void:
	if get_meta("_sombra_da_realidade", false):
		return
	for p in _pingos:
		if p["parte"] == "@perdido" or not is_instance_valid(p["no"]):
			continue
		p["gota"] = float(p["gota"]) - delta
		if float(p["gota"]) > 0.0:
			continue
		var forte: bool = p["forte"]
		p["gota"] = _rng.randf_range(0.25, 0.6) if forte else _rng.randf_range(0.7, 1.8)
		var de := (p["no"] as Node3D).global_position
		var c := Sangue.chao(get_world_3d(), de, 3.0, [get_rid()])
		if c.is_empty():
			continue
		var tam := _rng.randf_range(0.06, 0.13) * (1.5 if forte else 1.0)
		Sangue.mancha(get_tree(), c["position"], c["normal"], tam, "gota", 45.0, INF,
			clampf((de.y - (c["position"] as Vector3).y) * 0.4, 0.05, 0.6))
		if forte and is_instance_valid(player) and global_position.distance_to(player.global_position) < 6.0 \
				and _rng.randf() < 0.25:
			Sangue.som(self, c["position"], SOM_GOTA, -16.0, _rng.randf_range(0.9, 1.15), 8.0)


## O rastro: uma mancha arrastada no chao a cada meio metro andado,
## alternando os pes e alinhada com o passo. Ferido, pinga mais junto.
func _rastro(delta: float) -> void:
	if get_meta("_sombra_da_realidade", false) or not is_on_floor():
		return
	var v := get_real_velocity()
	v.y = 0.0
	var andou := v.length() * delta
	if andou <= 0.0001:
		return
	_rastro_falta -= andou
	if _rastro_falta > 0.0:
		return
	var feridas := _perdidas.size()
	_rastro_falta = _rng.randf_range(0.45, 0.85) / (1.0 + 0.12 * feridas)
	_rastro_lado = -_rastro_lado
	var dir := v.normalized()
	var lado := Vector3(dir.z, 0.0, -dir.x) * 0.11 * _rastro_lado
	var de := global_position + lado + Vector3.UP * 0.4
	var c := Sangue.chao(get_world_3d(), de, 1.5, [get_rid()])
	if c.is_empty():
		return
	var tam := _rng.randf_range(0.22, 0.38) * (1.0 + 0.05 * feridas)
	Sangue.mancha(get_tree(), c["position"], c["normal"], tam,
		"rastro" if _rng.randf() < 0.7 else "gota", 45.0, atan2(-dir.x, -dir.z))


# ============================================================== recursos

## Guarda as malhas das pecas soltas (o vazio "pecas" do .glb) e tira o vazio
## da arvore: ninguem precisa ver um braco de repouso no meio do corpo.
func _guardar_pecas() -> void:
	var vazio := modelo.find_child("pecas", true, false)
	if vazio == null:
		return
	for f in vazio.get_children():
		if f is MeshInstance3D:
			_malhas[String(f.name)] = (f as MeshInstance3D).mesh
	vazio.get_parent().remove_child(vazio)
	vazio.queue_free()


## A carne e o corte saem do .glb com material de Blender; aqui viram
## molhados, dos dois lados, com um fio de emissao pras ruas escuras.
func _materiais() -> void:
	# Carne viva: escura, com o coagulo da textura bem marcado e brilho de
	# molhado. Mais clara que isto ela vira papel vermelho recortado.
	_mat_carne = StandardMaterial3D.new()
	_mat_carne.albedo_color = Color(0.62, 0.48, 0.48)
	_mat_carne.roughness = 0.2
	_mat_carne.metallic_specular = 0.85
	_mat_carne.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_carne.uv1_triplanar = true
	_mat_carne.uv1_scale = Vector3(9, 9, 9)
	_mat_carne.emission_enabled = true
	_mat_carne.emission = Color(0.035, 0.0, 0.002)
	_mat_corte = StandardMaterial3D.new()
	# a gordura do corte saia amarelo-gema; escurecida, le como carne
	_mat_corte.albedo_color = Color(0.72, 0.6, 0.58)
	_mat_corte.roughness = 0.3
	_mat_corte.metallic_specular = 0.6
	_mat_corte.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_corte.emission_enabled = true
	_mat_corte.emission = Color(0.035, 0.004, 0.004)
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		_materiais_da_peca(mi as MeshInstance3D)


func _materiais_da_peca(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		if m == null:
			continue
		var nome := m.resource_name
		if nome.contains("carne"):
			if _mat_carne.albedo_texture == null and m is BaseMaterial3D:
				_mat_carne.albedo_texture = (m as BaseMaterial3D).albedo_texture
			mi.set_surface_override_material(s, _mat_carne)
		elif nome.contains("corte"):
			if _mat_corte.albedo_texture == null and m is BaseMaterial3D:
				_mat_corte.albedo_texture = (m as BaseMaterial3D).albedo_texture
			mi.set_surface_override_material(s, _mat_corte)


# ============================================================== animacao

func _tocar(clipe: StringName, mistura: float = 0.25, vel: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(clipe):
		return
	if _clipe != clipe or not _anim.is_playing():
		_clipe = clipe
		_anim.play(clipe, mistura)
	_anim.speed_scale = vel


func _gemer(delta: float) -> void:
	_proximo_gemido -= delta
	if _proximo_gemido > 0.0:
		return
	_proximo_gemido = _rng.randf_range(4.0, 10.0)
	if get_meta("_sombra_da_realidade", false) or som_gemido.playing:
		return
	som_gemido.stream = load(GEMIDOS[_rng.randi() % GEMIDOS.size()])
	som_gemido.pitch_scale = _rng.randf_range(0.7, 0.95)
	som_gemido.play()
