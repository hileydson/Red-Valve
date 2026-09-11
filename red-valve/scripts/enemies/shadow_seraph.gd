extends CharacterBody3D
class_name ShadowSeraph

## "The Shadow Seraph": humanoide alto e com asas, feito da mesma materia das
## ShadowPerson e dos ShadowCar — escuridao montada por codigo — mas com shader
## proprio (`shadow_seraph_body.gdshader`): enquanto elas sao fumaca fria que se
## desfaz, ele e carvao aceso, gretado por veias de brasa. Fogo nos olhos e
## rastro de brasa por onde passa.
##
## Por que ele NAO usa a `enemy.gd`/`enemy.tscn` como os outros inimigos:
## aquela classe e construida em volta de um `.glb` com Skeleton3D e
## AnimationTree (estados "idle"/"walk"/"attack"/"dead"). Este inimigo nao tem
## modelo nem animacao importada — corpo e movimento sao montados por codigo,
## exatamente como as sombras da cidade, porque e assim que o material de
## fumaca fica convincente (primitivas baratas que o shader dissolve). Colocar
## um AnimationTree de mentira so pra herdar a enemy.gd seria pior.
##
## O que ele mantem igual e o CONTRATO que o resto do jogo consulta, e isso e o
## que importa: grupo "enemies", `dead`, sinal `died`, `cutscene_mode`,
## `player`, `take_damage()`, `remover_em_silencio()` e a barra de chefe no
## topo da tela. Assim o amuleto, a arena (`battlefield.gd`), o spawner da
## cidade e o tiro do jogador funcionam sem saber que ele e diferente.
##
## A cena (`shadow_seraph.tscn`) e so uma casca Node3D sem script com este
## corpo dentro, no filho "enemy" — a mesma forma das outras cenas de inimigo.
## O spawner da cidade conta com isso (guarda casca e corpo separados, e apaga a
## casca quando o amuleto reparenta o corpo pra arena) e o `battlefield.gd`
## resolve o corpo descendo a arvore. Todo o resto — esqueleto, asas, olhos de
## fogo, colisoes, audio — e montado aqui no `_ready`.
##
## Ataques (ver a secao "roteiro dos poderes" mais abaixo):
##   3. bola de magia      — 15 de dano. O UNICO poder que ele usa fora da
##                          arena: na cidade ele so vaga e joga magia.
## Dentro da arena (`battlefield_1`) o repertorio inteiro abre:
##   1. raio do ceu        — 30 de dano
##   2. foguete da bazuca  — 40 de dano, abativel a tiro
##   4. espada             — 40 de dano, corre ate o jogador e corta
##   defesa: esfera de fogo — 14 s levando 70% menos dano
##   magia:  anel          — deixa o jogador 60% mais lento por 12 s

const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")
const FX := preload("res://scripts/effects/seraph_fx.gd")
const Orbe := preload("res://scripts/effects/seraph_orb.gd")
const Foguete := preload("res://scripts/effects/seraph_rocket.gd")
const Raio := preload("res://scripts/effects/seraph_lightning.gd")
const EsferaFogo := preload("res://scripts/effects/seraph_fire_shell.gd")
const Anel := preload("res://scripts/effects/seraph_slow_ring.gd")

const SHADER_CORPO := "res://shaders/enemies/shadow_seraph_body.gdshader"

signal died

enum State { VAGANDO, PERSEGUINDO, ACAO, MORTO }
enum Act { NENHUMA, ORBE, RAIO, FOGUETE, ESPADA, ESFERA, ANEL }

# ------------------------------------------------------------------ ajustes

@export_group("Identidade")
@export var enemy_name: String = "THE SHADOW SERAPH"
@export var max_health: int = 250
@export var iron_rusks_value: int = 9
## Altura total do bicho, em metros. Ele e de proposito mais alto que o jogador.
@export var altura: float = 2.8

@export_group("Movimento")
## Passo de quando esta so vagando pela cidade.
@export var walk_speed: float = 1.6
## Passo de quando esta em cima do jogador.
@export var chase_speed: float = 3.1
## Corrida do ataque 4 (espada).
@export var rush_speed: float = 7.2
## Giro do corpo. Baixo de proposito: um bicho deste tamanho girando rapido no
## proprio eixo e o que mais denuncia boneco.
@export var turn_speed: float = 3.2
## A partir daqui ele percebe o jogador e parte pra briga.
@export var distance_to_aproach: float = 30.0
## Distancia que ele tenta manter enquanto conjura.
@export var distancia_ideal: float = 8.0
@export var use_navigation: bool = true
## Raio em que ele fica vagando em volta de onde nasceu.
@export var wander_radius: float = 45.0
## So anda onde ha rua (mesmo grid das sombras). Desligue pra ele andar por tudo.
@export var road_only: bool = true

@export_group("Dano dos poderes")
@export var dano_raio: int = 30
@export var dano_foguete: int = 40
@export var dano_orbe: int = 15
@export var dano_espada: int = 40

@export_group("Esperas entre poderes")
## Intervalo entre uma bola de magia e a proxima. E o poder mais frequente.
@export var espera_orbe_min: float = 4.0
@export var espera_orbe_max: float = 7.0
@export var espera_espada_min: float = 11.0
@export var espera_espada_max: float = 18.0
@export var espera_raio_min: float = 14.0
@export var espera_raio_max: float = 23.0
@export var espera_foguete_min: float = 13.0
@export var espera_foguete_max: float = 20.0
@export var espera_esfera_min: float = 22.0
@export var espera_esfera_max: float = 34.0
@export var espera_anel_min: float = 16.0
@export var espera_anel_max: float = 26.0
## Respiro obrigatorio entre o fim de um poder e o comeco do proximo.
@export var respiro_entre_poderes: float = 1.9

@export_group("Defesa")
@export var duracao_esfera: float = 14.0
## 0.7 = leva 70% menos dano enquanto a esfera esta de pe.
@export_range(0.0, 1.0) var reducao_esfera: float = 0.7

@export_group("Anel de lentidao")
@export var duracao_anel: float = 12.0
## 0.4 = o jogador fica 60% mais lento.
@export_range(0.1, 1.0) var fator_anel: float = 0.4

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
## Passo de dentro da acao atual; cada poder da um significado proprio a ele.
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

var escudo_ativo: bool = false
var _esfera: Node3D = null
var _raio_no: Node3D = null
var _anel_ativo: bool = false

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
var _asa_l: Node3D
var _asa_r: Node3D
var _asa_meio_l: Node3D
var _asa_meio_r: Node3D
var _costas: Node3D
var _ancora_magia: Node3D
var _espada: Node3D
var _bazuca: Node3D
var _olho_l: MeshInstance3D
var _olho_r: MeshInstance3D
var _luz_olhos: OmniLight3D
var _rastro: GPUParticles3D
var _brasa_espada: GPUParticles3D
var _fogo_olhos: GPUParticles3D

# audio
var _steps: AudioStreamPlayer3D
var _grunhido: AudioStreamPlayer3D
var _grunhido_atk: AudioStreamPlayer3D
var _grunhido_dano: AudioStreamPlayer3D
var _grunhido_morte: AudioStreamPlayer3D
var _tombo: AudioStreamPlayer3D
var _fogo_corpo: AudioStreamPlayer3D

static var _material_sombra: ShaderMaterial

# ------------------------------------------------------- tempos das animacoes
# Cada poder e uma sequencia de fases. As constantes abaixo sao lidas tanto
# pela corrotina que dispara os efeitos quanto pela funcao que poe o corpo na
# pose: e o que mantem o gesto colado no efeito sem nenhum AnimationPlayer.

## A bola de magia e de proposito a mais curta: e o golpe "barato" dele, o unico
## que sai fora da arena e o que ele repete. Mesmo assim tem as tres fases
## (abre, empurra, recompoe) pra nao virar um piscar.
const ORBE_ABRE := 0.70
const ORBE_EMPURRA := 0.34
const ORBE_VOLTA := 0.50

## O raio e o poder mais longo dele (~5,3 s). A espera vale a pena: um segundo e
## meio so de bracos subindo com o ceu se abrindo em cima, depois o salto, o
## instante suspenso no apice segurando o raio, e so ai o arremesso.
const RAIO_LEVANTA := 2.10
const RAIO_SOBE := 0.85
const RAIO_PEGA := 0.70
const RAIO_JOGA := 0.45
const RAIO_CAI := 1.15

const FOG_SACA := 1.50
const FOG_MIRA := 1.25
const FOG_ATIRA := 0.40
const FOG_VOLTA := 1.00

const ESP_SACA := 1.00
const ESP_CORRE_MAX := 5.5
const ESP_CORTA := 0.80
const ESP_VOLTA := 0.80
const ESP_GUARDA := 0.85

const ESF_AGACHA := 0.60
const ESF_SOBE := 0.85
const ESF_FORMA := 0.70
const ESF_CAI := 1.00

const ANEL_LEVANTA := 0.95
const ANEL_GIRA := 1.60
const ANEL_EMPURRA := 0.40
const ANEL_VOLTA := 0.60

## Altura dos dois saltos, em alturas de corpo. Ele tem asas de 2,8 m: um pulo
## raso o faz parecer pesado e preso no chao.
const SALTO_RAIO := 1.35
const SALTO_ESFERA := 1.05

const GRAVIDADE := 20.0
## Tolerancia horizontal ate o navmesh pra considerar que ele serve aqui. Na
## cidade da stage_1 o navmesh fica a ~200 m: este inimigo, como os outros,
## persegue em linha reta quando isso acontece.
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

	# Primeiros usos sorteados baixos: o jogador precisa ver o repertorio dele
	# logo, em vez de encarar tres minutos de bola de magia.
	_esperas = {
		Act.ORBE: _rng.randf_range(1.5, 3.5),
		Act.ESPADA: _rng.randf_range(5.0, 9.0),
		Act.RAIO: _rng.randf_range(6.0, 11.0),
		Act.FOGUETE: _rng.randf_range(8.0, 13.0),
		Act.ESFERA: _rng.randf_range(7.0, 14.0),
		Act.ANEL: _rng.randf_range(9.0, 15.0),
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
	# Histerese: so descongela dentro do raio e so congela bem depois dele,
	# senao fica ligando/desligando no limite.
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


## Estamos na arena? Os ataques 1 e 2 so existem la.
func _na_arena() -> bool:
	if not is_inside_tree() or get_tree() == null:
		return false
	var cena := get_tree().current_scene
	return cena != null and cena.scene_file_path.contains("battlefield")


# ================================================================ construcao

## Shader PROPRIO dele (`shadow_seraph_body.gdshader`), da mesma familia do
## `shadow_being` das sombras da cidade mas com leitura diferente: em vez de
## fumaca fria que se desfaz quase toda, ele e carvao aceso — massa densa no
## miolo, gretada por veias de brasa que pulsam, silhueta que QUEIMA em vez de
## sumir, cinza se desprendendo pra cima. O arquivo do shader explica as quatro
## escolhas que produzem essa diferenca.
##
## Um material para todos os Seraph em tela (`static`): sao dezenas de malhas
## por bicho e o shader nao tem nada por instancia.
func _material() -> ShaderMaterial:
	if _material_sombra == null:
		_material_sombra = ShaderMaterial.new()
		_material_sombra.shader = load(SHADER_CORPO)
	return _material_sombra


func _parte(pai: Node3D, malha: Mesh, onde: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.position = onde
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


func _capsula(raio: float, comp: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = raio
	m.height = maxf(comp, raio * 2.05)
	m.radial_segments = 10
	m.rings = 4
	return m


func _esfera_malha(raio: float, achata := 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = raio * 2.0 * achata
	m.radial_segments = 12
	m.rings = 8
	return m


## Osso: pivo + membro pendurado pra baixo a partir dele (mesma receita do
## rig das ShadowPerson).
func _osso(pai: Node3D, nome: String, comp: float, raio: float, onde: Vector3) -> Node3D:
	var pivo := Node3D.new()
	pivo.name = nome
	pivo.position = onde
	pai.add_child(pivo)
	_parte(pivo, _capsula(raio, comp), Vector3(0, -comp * 0.5, 0))
	return pivo


func _monta_corpo() -> void:
	var h := altura
	var perna := h * 0.46
	var coxa := perna * 0.54
	var canela := perna - coxa
	var torso := h * 0.30
	var cabeca_r := h * 0.068
	var quadril_w := h * 0.052
	var ombro_w := h * 0.118
	var braco := h * 0.37          # bracos longos: leitura de criatura, nao de gente
	var antebraco := braco * 0.47
	var superior := braco - antebraco

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0, perna, 0)
	_rig.add_child(_hips)
	_parte(_hips, _capsula(h * 0.058, h * 0.10), Vector3.ZERO)

	_spine = Node3D.new()
	_spine.name = "Spine"
	_hips.add_child(_spine)
	# torax comprido e afunilado pra baixo
	_parte(_spine, _capsula(h * 0.066, torso), Vector3(0, torso * 0.45, 0))
	_parte(_spine, _esfera_malha(h * 0.072, 0.8), Vector3(0, torso * 0.70, 0)).scale = Vector3(1.1, 1.0, 0.85)
	_parte(_spine, _capsula(h * 0.040, ombro_w * 2.0), Vector3(0, torso * 0.93, 0)).rotation.z = PI * 0.5

	# pescoco, cranio alongado e dois chifres pra tras
	_neck = Node3D.new()
	_neck.name = "Neck"
	_neck.position = Vector3(0, torso * 1.0, 0)
	_spine.add_child(_neck)
	_parte(_neck, _capsula(h * 0.024, h * 0.060), Vector3(0, h * 0.026, 0))
	var cranio := _parte(_neck, _esfera_malha(cabeca_r), Vector3(0, h * 0.056 + cabeca_r * 0.9, 0))
	cranio.scale = Vector3(0.86, 1.18, 1.05)
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		var chifre := _parte(_neck, _capsula(cabeca_r * 0.16, cabeca_r * 1.7),
			Vector3(lado * cabeca_r * 0.52, h * 0.056 + cabeca_r * 1.75, -cabeca_r * 0.35))
		chifre.rotation = Vector3(deg_to_rad(-38.0), 0.0, deg_to_rad(-lado * 16.0))

	_monta_olhos(_neck, cabeca_r, h)

	# bracos
	_ombro_l = _osso(_spine, "OmbroL", superior, h * 0.028, Vector3(ombro_w, torso * 0.90, 0))
	_cotovelo_l = _osso(_ombro_l, "CotoveloL", antebraco, h * 0.023, Vector3(0, -superior, 0))
	_mao_l = _mao(_cotovelo_l, "MaoL", antebraco, h)

	_ombro_r = _osso(_spine, "OmbroR", superior, h * 0.028, Vector3(-ombro_w, torso * 0.90, 0))
	_cotovelo_r = _osso(_ombro_r, "CotoveloR", antebraco, h * 0.023, Vector3(0, -superior, 0))
	_mao_r = _mao(_cotovelo_r, "MaoR", antebraco, h)

	# pernas: digitigrada (joelho pra tras), pra nao andar como uma pessoa
	_coxa_l = _osso(_hips, "CoxaL", coxa, h * 0.038, Vector3(quadril_w, 0, 0))
	_joelho_l = _osso(_coxa_l, "JoelhoL", canela, h * 0.030, Vector3(0, -coxa, 0))
	_pe(_joelho_l, canela, h)
	_coxa_r = _osso(_hips, "CoxaR", coxa, h * 0.038, Vector3(-quadril_w, 0, 0))
	_joelho_r = _osso(_coxa_r, "JoelhoR", canela, h * 0.030, Vector3(0, -coxa, 0))
	_pe(_joelho_r, canela, h)

	# ancora onde a magia se forma (na frente do peito)
	_ancora_magia = Node3D.new()
	_ancora_magia.name = "AncoraMagia"
	_ancora_magia.position = Vector3(0, torso * 0.62, -h * 0.30)
	_spine.add_child(_ancora_magia)

	# costas: de onde saem asas, espada e bazuca
	_costas = Node3D.new()
	_costas.name = "Costas"
	_costas.position = Vector3(0, torso * 0.72, h * 0.045)
	_spine.add_child(_costas)

	_asa_l = _monta_asa(1.0, h)
	_asa_r = _monta_asa(-1.0, h)
	_espada = _monta_espada(h)
	_bazuca = _monta_bazuca(h)

	_monta_rastro(h)

	set_meta("body_height", h)


func _mao(cotovelo: Node3D, nome: String, antebraco: float, h: float) -> Node3D:
	var pivo := Node3D.new()
	pivo.name = nome
	pivo.position = Vector3(0, -antebraco - h * 0.012, 0)
	cotovelo.add_child(pivo)
	_parte(pivo, _esfera_malha(h * 0.030, 0.7), Vector3.ZERO)
	# tres garras compridas: o que faz a mao ler como garra e nao como punho
	for i in 3:
		var g := _parte(pivo, _capsula(h * 0.007, h * 0.055),
			Vector3((float(i) - 1.0) * h * 0.018, -h * 0.035, -h * 0.008))
		g.rotation.x = deg_to_rad(-12.0)
	return pivo


func _pe(joelho: Node3D, canela: float, h: float) -> void:
	var tornozelo := Node3D.new()
	tornozelo.name = "Pe"
	tornozelo.position = Vector3(0, -canela, 0)
	joelho.add_child(tornozelo)
	var box := BoxMesh.new()
	box.size = Vector3(h * 0.050, h * 0.028, h * 0.125)
	_parte(tornozelo, box, Vector3(0, -h * 0.012, -h * 0.028))
	# garra dianteira
	var garra := _parte(tornozelo, _capsula(h * 0.008, h * 0.045), Vector3(0, -h * 0.014, -h * 0.085))
	garra.rotation.x = deg_to_rad(-75.0)


## Olhos de fogo: duas brasas no cranio, uma luz só pros dois (o renderer
## Mobile aceita 8 omnis por malha — gastar duas aqui seria desperdicio) e um
## fiozinho de chama subindo deles.
func _monta_olhos(neck: Node3D, cabeca_r: float, h: float) -> void:
	var y := h * 0.056 + cabeca_r * 1.0
	var z := -cabeca_r * 0.72
	var mat := FX.emissivo(Color(1.0, 0.48, 0.10), 9.0)

	_olho_l = MeshInstance3D.new()
	_olho_l.mesh = _esfera_malha(cabeca_r * 0.22)
	_olho_l.material_override = mat
	_olho_l.position = Vector3(cabeca_r * 0.40, y, z)
	_olho_l.scale = Vector3(1.5, 0.8, 1.0)
	_olho_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	neck.add_child(_olho_l)

	_olho_r = MeshInstance3D.new()
	_olho_r.mesh = _olho_l.mesh
	_olho_r.material_override = mat
	_olho_r.position = Vector3(-cabeca_r * 0.40, y, z)
	_olho_r.scale = _olho_l.scale
	_olho_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	neck.add_child(_olho_r)

	_luz_olhos = OmniLight3D.new()
	_luz_olhos.light_color = Color(1.0, 0.45, 0.12)
	_luz_olhos.light_energy = 3.0
	_luz_olhos.omni_range = 6.0
	_luz_olhos.shadow_enabled = false
	_luz_olhos.position = Vector3(0, y, z - cabeca_r * 0.2)
	neck.add_child(_luz_olhos)

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(cabeca_r * 0.55, cabeca_r * 0.08, 0.01)
	proc.direction = Vector3(0, 1, -0.25)
	proc.spread = 18.0
	proc.initial_velocity_min = 0.25
	proc.initial_velocity_max = 0.9
	proc.gravity = Vector3(0, 0.7, 0)
	proc.damping_min = 0.5
	proc.damping_max = 1.5
	proc.scale_min = 0.02
	proc.scale_max = 0.07
	proc.scale_curve = FX.curva_pico(0.18)
	proc.color_ramp = FX.rampa(
		[Color(1, 0.95, 0.8, 1), Color(1, 0.45, 0.1, 0.8), Color(0.3, 0.05, 0.02, 0.0)],
		[0.0, 0.4, 1.0])

	_fogo_olhos = GPUParticles3D.new()
	_fogo_olhos.amount = 26
	_fogo_olhos.lifetime = 0.7
	_fogo_olhos.process_material = proc
	_fogo_olhos.draw_pass_1 = FX.quad_particula()
	_fogo_olhos.position = Vector3(0, y, z)
	_fogo_olhos.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
	neck.add_child(_fogo_olhos)


## Asa: dois ossos + penas de tamanho decrescente. Tudo com o material de
## sombra, entao a asa tambem se desfaz nas pontas.
func _monta_asa(lado: float, h: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "AsaL" if lado > 0.0 else "AsaR"
	raiz.position = Vector3(lado * h * 0.045, 0, 0)
	_costas.add_child(raiz)

	var osso1 := h * 0.40
	var osso2 := h * 0.38

	# o osso aponta pra fora (eixo X), entao o membro entra rotacionado
	var braco := Node3D.new()
	braco.name = "Braco"
	raiz.add_child(braco)
	_parte(braco, _capsula(h * 0.022, osso1), Vector3(lado * osso1 * 0.5, 0, 0)).rotation.z = PI * 0.5

	var meio := Node3D.new()
	meio.name = "Meio"
	meio.position = Vector3(lado * osso1, 0, 0)
	braco.add_child(meio)
	_parte(meio, _capsula(h * 0.017, osso2), Vector3(lado * osso2 * 0.5, 0, 0)).rotation.z = PI * 0.5

	# penas do antebraco (as longas) e do braco (as curtas, mais pra dentro)
	var penas := [0.95, 0.88, 0.76, 0.62, 0.46]
	for i in penas.size():
		var f: float = penas[i]
		var comp := h * 0.46 * f
		var pena := _parte(meio, _capsula(h * 0.013 * f, comp),
			Vector3(lado * osso2 * (0.25 + 0.18 * float(i)), -comp * 0.42, h * 0.012 * float(i)))
		pena.scale = Vector3(1.0, 1.0, 0.35)
		pena.rotation = Vector3(deg_to_rad(4.0 * float(i)), 0.0, deg_to_rad(lado * (14.0 + 9.0 * float(i))))
	for i in 3:
		var comp2 := h * 0.26 * (1.0 - 0.2 * float(i))
		var pena2 := _parte(braco, _capsula(h * 0.012, comp2),
			Vector3(lado * osso1 * (0.30 + 0.22 * float(i)), -comp2 * 0.45, h * 0.010))
		pena2.scale = Vector3(1.0, 1.0, 0.35)
		pena2.rotation.z = deg_to_rad(lado * (10.0 + 6.0 * float(i)))

	if lado > 0.0:
		_asa_meio_l = meio
	else:
		_asa_meio_r = meio

	# pose fechada: colada nas costas
	raiz.rotation = Vector3(deg_to_rad(12.0), deg_to_rad(-lado * 62.0), deg_to_rad(lado * 22.0))
	meio.rotation.y = -lado * deg_to_rad(58.0)
	return raiz


## Espada: lamina de sombra com fio de brasa. Nasce guardada nas costas e
## troca de pai pra mao direita no ataque 4 (ver `_segura_espada`).
func _monta_espada(h: float) -> Node3D:
	var arma := Node3D.new()
	arma.name = "Espada"
	_costas.add_child(arma)

	var lamina_len := h * 0.62
	var lamina := _parte(arma, _capsula(h * 0.028, lamina_len), Vector3(0, lamina_len * 0.5, 0))
	lamina.scale = Vector3(1.0, 1.0, 0.26)

	# fio: faixa fina e emissiva correndo pela lamina
	var fio := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(h * 0.004, lamina_len * 0.92, h * 0.018)
	fio.mesh = box
	fio.material_override = FX.emissivo(Color(1.0, 0.42, 0.08), 6.0)
	fio.position = Vector3(h * 0.026, lamina_len * 0.5, 0)
	fio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arma.add_child(fio)

	# guarda e cabo
	_parte(arma, _capsula(h * 0.012, h * 0.16), Vector3.ZERO).rotation.z = PI * 0.5
	_parte(arma, _capsula(h * 0.013, h * 0.13), Vector3(0, -h * 0.065, 0))
	_parte(arma, _esfera_malha(h * 0.020), Vector3(0, -h * 0.135, 0))

	_brasa_espada = _particulas_brasa(h * 0.03, 40, 0.8)
	_brasa_espada.position = Vector3(0, lamina_len * 0.55, 0)
	_brasa_espada.emitting = false
	arma.add_child(_brasa_espada)

	arma.visible = false
	arma.position = Vector3(h * 0.055, -h * 0.02, h * 0.03)
	arma.rotation = Vector3(deg_to_rad(-8.0), 0.0, deg_to_rad(-28.0))
	return arma


## Bazuca: tubo de sombra com bocal de brasa. Tambem fica nas costas.
func _monta_bazuca(h: float) -> Node3D:
	var arma := Node3D.new()
	arma.name = "Bazuca"
	_costas.add_child(arma)

	var tubo_len := h * 0.66
	var tubo := _parte(arma, _capsula(h * 0.050, tubo_len), Vector3.ZERO)
	tubo.rotation.x = PI * 0.5
	# bocal
	var bocal := _parte(arma, _capsula(h * 0.062, h * 0.10), Vector3(0, 0, tubo_len * 0.52))
	bocal.rotation.x = PI * 0.5
	# mira e empunhadura
	_parte(arma, _capsula(h * 0.012, h * 0.07), Vector3(0, h * 0.055, -tubo_len * 0.15))
	_parte(arma, _capsula(h * 0.016, h * 0.10), Vector3(0, -h * 0.055, tubo_len * 0.05)).rotation.x = deg_to_rad(18.0)

	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = h * 0.050
	toro.outer_radius = h * 0.060
	toro.rings = 14
	anel.mesh = toro
	anel.material_override = FX.emissivo(Color(1.0, 0.40, 0.08), 5.0)
	anel.rotation.x = PI * 0.5
	anel.position = Vector3(0, 0, -tubo_len * 0.46)
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arma.add_child(anel)

	arma.visible = false
	arma.position = Vector3(-h * 0.060, -h * 0.03, h * 0.05)
	arma.rotation = Vector3(0.0, deg_to_rad(14.0), deg_to_rad(24.0))
	return arma


## Brasa generica (lamina, rastro dos pes). `raio` e o tamanho da fonte.
func _particulas_brasa(raio: float, quantos: int, vida: float) -> GPUParticles3D:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = raio
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 40.0
	proc.initial_velocity_min = 0.3
	proc.initial_velocity_max = 1.4
	proc.gravity = Vector3(0, 0.9, 0)
	proc.damping_min = 0.6
	proc.damping_max = 1.8
	proc.turbulence_enabled = true
	proc.turbulence_noise_strength = 0.5
	proc.turbulence_noise_scale = 2.0
	proc.scale_min = 0.02
	proc.scale_max = 0.09
	proc.scale_curve = FX.curva_pico(0.18)
	proc.color_ramp = FX.rampa(
		[Color(1, 0.95, 0.8, 1), Color(1, 0.45, 0.1, 0.9), Color(0.8, 0.15, 0.05, 0.35), Color(0.15, 0.02, 0.02, 0.0)],
		[0.0, 0.3, 0.65, 1.0])

	var p := GPUParticles3D.new()
	p.amount = quantos
	p.lifetime = vida
	p.process_material = proc
	p.draw_pass_1 = FX.quad_particula()
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3.ONE * -8.0, Vector3.ONE * 16.0)
	return p


## Rastro de fogo no chao: brasa que fica PARADA onde ele pisou (local_coords
## desligado) e se apaga devagar. E o que deixa o caminho dele marcado.
func _monta_rastro(h: float) -> void:
	_rastro = _particulas_brasa(h * 0.13, 64, 2.6)
	var proc := _rastro.process_material as ParticleProcessMaterial
	proc.initial_velocity_min = 0.05
	proc.initial_velocity_max = 0.6
	proc.gravity = Vector3(0, 0.35, 0)
	proc.damping_min = 1.5
	proc.damping_max = 3.0
	proc.scale_min = 0.05
	proc.scale_max = 0.20
	_rastro.position = Vector3(0, 0.12, 0)
	_rastro.emitting = false
	add_child(_rastro)


func _monta_colisoes() -> void:
	var h := altura
	var corpo := CollisionShape3D.new()
	corpo.name = "body_shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.46
	cap.height = maxf(h * 0.92, 1.2)
	corpo.shape = cap
	corpo.position = Vector3(0, h * 0.46, 0)
	add_child(corpo)

	# "heart": area de acerto critico, igual a dos outros inimigos (layer 8, a
	# que o raycast da arma procura). Sem ela o tiro na cabeca dele nao valeria
	# mais que um tiro na perna.
	var heart := Area3D.new()
	heart.name = "heart"
	heart.collision_layer = 8
	heart.collision_mask = 0
	heart.add_to_group("enemies")
	heart.set_script(load("res://scripts/enemies/head.gd"))
	var hc := CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = h * 0.10
	hc.shape = hs
	heart.add_child(hc)
	heart.position = Vector3(0, h * 0.82, 0)
	add_child(heart)

	# Toque: na cidade, encostar nele leva o jogador pra arena (mesma regra dos
	# outros inimigos, ver `_tenta_batalha_forcada`).
	var toque := Area3D.new()
	toque.name = "toque"
	toque.collision_layer = 0
	toque.collision_mask = 1
	var tc := CollisionShape3D.new()
	var ts := CapsuleShape3D.new()
	ts.radius = 0.85
	ts.height = maxf(h, 1.4)
	tc.shape = ts
	toque.add_child(tc)
	toque.position = Vector3(0, h * 0.46, 0)
	add_child(toque)
	toque.body_entered.connect(_no_toque)


func _monta_audio() -> void:
	_steps = _som("res://assets/sounds/enemies/the_cobalt_husker/steps.mp3", -8.0, 0.62)
	_grunhido = _som("res://assets/sounds/enemies/growl_1.mp3", -6.0, 0.72)
	_grunhido_atk = _som("res://assets/sounds/enemies/inimigo_1_voice_attack.mp3", -3.0, 0.78)
	_grunhido_dano = _som("res://assets/sounds/enemies/growl_3.mp3", -5.0, 0.82)
	_grunhido_morte = _som("res://assets/sounds/enemies/growl_2.mp3", 0.0, 0.62)
	_tombo = _som("res://assets/sounds/enemies/the_cobalt_husker/drop_dead.mp3", 0.0, 0.8)

	# corpo queimando: ronco baixo e continuo, e o que faz o fogo dele existir
	# mesmo quando as particulas estao fora da tela
	_fogo_corpo = _som(FX.SOM_FOGO, -14.0, 0.7, true)
	if _fogo_corpo != null:
		_fogo_corpo.play()

	var t := Timer.new()
	t.wait_time = _rng.randf_range(7.0, 13.0)
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		t.wait_time = _rng.randf_range(7.0, 14.0)
		if not dead and _grunhido != null and not _grunhido.playing:
			_grunhido.play())


func _som(caminho: String, db: float, pitch: float, laco := false) -> AudioStreamPlayer3D:
	var stream: AudioStream = null
	if laco:
		stream = FX.som_em_laco(caminho)
	else:
		stream = load(caminho) as AudioStream
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
	_nav.path_desired_distance = 0.6
	_nav.target_desired_distance = 0.8
	_nav.avoidance_enabled = false
	add_child(_nav)


# =================================================================== loop

func _physics_process(delta: float) -> void:
	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	if not dead and _spawn_grace <= 0.0 and global_position.y < -10.0:
		# Caiu fora do mapa (chao sem colisao pronta, buraco na cidade). Isso
		# nao e uma morte: nao rende iron rusks nem barra de chefe.
		remover_em_silencio()
		return

	_t += delta
	_fase_t += delta

	if dead:
		if _steps != null:
			_steps.stop()
		if _rastro != null:
			_rastro.emitting = false
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


## Decide o que fazer quando nao esta no meio de um poder.
func _pensa(delta: float) -> void:
	var d := INF
	if is_instance_valid(player):
		d = global_position.distance_to(player.global_position)

	# Na arena ele nunca "vaga": o jogador esta ali, a luta e agora.
	var briga := _na_arena() or d <= distance_to_aproach
	state = State.PERSEGUINDO if briga else State.VAGANDO

	if not briga:
		_vaga(delta)
		return

	if not is_instance_valid(player):
		_vaga(delta)
		return

	_encara(player.global_position, delta)

	if _respiro <= 0.0:
		var escolha: int = _escolhe_poder(d)
		if escolha != Act.NENHUMA:
			_comeca(escolha)
			return

	# Sem poder pronto: mantem a distancia de conjuracao. Chegar colado no
	# jogador nao interessa a ele — o toque dele na cidade ja leva pra arena, e
	# na arena quem encosta e a espada.
	var alvo_d := distancia_ideal
	var dir := (player.global_position - global_position)
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var v := chase_speed
	if d > alvo_d + 1.5:
		_caminha(dir, v, delta)
	elif d < alvo_d - 2.5:
		_caminha(-dir, v * 0.6, delta)
	else:
		# rodeia o jogador devagar, em vez de ficar plantado
		var lado := Vector3(-dir.z, 0.0, dir.x) * (1.0 if int(_t * 0.25) % 2 == 0 else -1.0)
		_caminha(lado, v * 0.45, delta)


## Passeio pela cidade: escolhe um ponto de rua e vai ate la, sem pressa.
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
	_troca_destino = _rng.randf_range(9.0, 20.0)
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


## Se saiu do asfalto (empurrao, esquina cortada), volta pra rua mais proxima em
## vez de subir na calcada ou no telhado. Mesma regra das sombras.
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


## Direcao horizontal ate um ponto, passando pelo navmesh quando ele existe
## aqui. Na cidade da stage_1 o navmesh nao cobre a area jogavel, entao o
## caminho normal e a linha reta.
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
	velocity.x = lerp(velocity.x, dir.x * vel, delta * 5.0)
	velocity.z = lerp(velocity.z, dir.z * vel, delta * 5.0)


func _encara(alvo: Vector3, delta: float) -> void:
	var plano := Vector3(alvo.x, global_position.y, alvo.z)
	if global_position.distance_to(plano) < 0.3:
		return
	# giro suave: o `look_at` seco dos outros inimigos faz o corpo estalar de
	# um lado pro outro, e este aqui tem de se mover como bicho.
	var desejado := atan2(global_position.x - alvo.x, global_position.z - alvo.z)
	rotation.y = lerp_angle(rotation.y, desejado, clampf(delta * turn_speed, 0.0, 1.0))


# ==================================================== roteiro dos poderes

## Qual poder esta pronto agora. A bola de magia tem peso maior: e o golpe
## "barato" dele, e e o unico que tambem acontece fora da arena junto do anel.
func _escolhe_poder(d: float) -> int:
	var arena := _na_arena()
	var prontos: Array[int] = []
	var pesos: Array[float] = []

	# Fora da arena ele tem UM poder so: a bola de magia. Tudo o mais (raio,
	# bazuca, espada, esfera, anel) e coisa de batalha. Na rua o encontro tem de
	# ser uma ameaca que se anuncia, nao uma luta completa com um chefe no meio
	# do transito — e quem decide quando a luta comeca e o jogador, encostando
	# nele ou mirando com o amuleto.
	if not arena:
		if float(_esperas[Act.ORBE]) <= 0.0 and d < 38.0:
			return Act.ORBE
		return Act.NENHUMA

	if float(_esperas[Act.ESFERA]) <= 0.0 and not escudo_ativo:
		# Defesa tem prioridade: se a hora dela chegou, e ela que sai.
		return Act.ESFERA

	if float(_esperas[Act.ORBE]) <= 0.0 and d < 38.0:
		prontos.append(Act.ORBE)
		pesos.append(3.0)
	if float(_esperas[Act.ANEL]) <= 0.0 and not _anel_ativo and d < 28.0:
		prontos.append(Act.ANEL)
		pesos.append(1.2)
	if float(_esperas[Act.ESPADA]) <= 0.0 and d < 26.0:
		prontos.append(Act.ESPADA)
		pesos.append(1.4)
	if float(_esperas[Act.RAIO]) <= 0.0:
		prontos.append(Act.RAIO)
		pesos.append(1.3)
	if float(_esperas[Act.FOGUETE]) <= 0.0 and d > 4.0:
		prontos.append(Act.FOGUETE)
		pesos.append(1.3)

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
		Act.ORBE:
			_esperas[Act.ORBE] = _rng.randf_range(espera_orbe_min, espera_orbe_max)
			_roteiro_orbe()
		Act.RAIO:
			_esperas[Act.RAIO] = _rng.randf_range(espera_raio_min, espera_raio_max)
			_roteiro_raio()
		Act.FOGUETE:
			_esperas[Act.FOGUETE] = _rng.randf_range(espera_foguete_min, espera_foguete_max)
			_roteiro_foguete()
		Act.ESPADA:
			_esperas[Act.ESPADA] = _rng.randf_range(espera_espada_min, espera_espada_max)
			_roteiro_espada()
		Act.ESFERA:
			_esperas[Act.ESFERA] = _rng.randf_range(espera_esfera_min, espera_esfera_max)
			_roteiro_esfera()
		Act.ANEL:
			_esperas[Act.ANEL] = _rng.randf_range(espera_anel_min, espera_anel_max)
			_roteiro_anel()


func _set_fase(f: int) -> void:
	_fase = f
	_fase_t = 0.0


## Espera de verdade (em segundos de jogo). Devolve false se no meio dela o
## inimigo morreu, saiu da arvore, foi congelado ou entrou em cutscene — e
## nesse caso quem chamou tem de abortar o poder na hora.
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
	_guarda_armas()


## Aborta o poder no meio: guarda as armas, apaga o raio pendurado no ar e
## solta o corpo. Chamado quando `_espera` avisa que a cena mudou debaixo dele.
func _aborta_acao() -> void:
	if is_instance_valid(_raio_no):
		_raio_no.queue_free()
	_raio_no = null
	_fim_acao()


## Ponto do chao onde o jogador esta AGORA. Os poderes mirados (raio e orbe)
## congelam isto no instante do arremesso: eles nao perseguem.
func _ponto_do_player() -> Vector3:
	if not is_instance_valid(player):
		return global_position - global_transform.basis.z * 6.0
	return player.global_position


# --------------------------------------------------------- 3. bola de magia

func _roteiro_orbe() -> void:
	var orbe = Orbe.new()
	orbe.damage = dano_orbe
	orbe.dono = self
	_ancora_magia.add_child(orbe)
	orbe.position = Vector3.ZERO

	if not await _espera(ORBE_ABRE):
		if is_instance_valid(orbe):
			orbe.queue_free()
		_aborta_acao()
		return

	_set_fase(1)  # estica os bracos pra frente
	if not await _espera(ORBE_EMPURRA * 0.55):
		if is_instance_valid(orbe):
			orbe.queue_free()
		_aborta_acao()
		return

	if is_instance_valid(orbe):
		var alvo := _ponto_do_player()
		orbe.lancar(alvo + Vector3.UP * 0.9)

	if not await _espera(ORBE_EMPURRA * 0.45):
		_aborta_acao()
		return
	_set_fase(2)
	if not await _espera(ORBE_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


# ------------------------------------------------------------ 1. raio do ceu

func _roteiro_raio() -> void:
	var raio = Raio.new()
	raio.dano = dano_raio
	raio.dono = self
	raio.ancora = _mao_r
	var cena := FX.mundo(self)
	if cena == null:
		_aborta_acao()
		return
	cena.add_child(raio)
	_raio_no = raio
	raio.invocar(global_position + Vector3.UP * (altura + 1.4))

	# 1. bracos pro alto, raio descendo
	if not await _espera(RAIO_LEVANTA):
		_aborta_acao()
		return

	# 2. pulo: o corpo sobe (offset no rig, nao na fisica — subir de verdade
	#    arrancaria ele do navmesh e do chao por um instante)
	_set_fase(1)
	if not await _espera(RAIO_SOBE):
		_aborta_acao()
		return

	# 3. pega o raio no ar
	_set_fase(2)
	if is_instance_valid(raio):
		raio.pegar()
	if not await _espera(RAIO_PEGA):
		_aborta_acao()
		return

	# 4. arremessa no ponto onde o jogador esta neste instante
	_set_fase(3)
	var destino := _ponto_do_player()
	if is_instance_valid(raio):
		raio.arremessar(destino)
	_raio_no = null
	if not await _espera(RAIO_JOGA):
		_aborta_acao()
		return

	# 5. cai e se recompoe
	_set_fase(4)
	if not await _espera(RAIO_CAI):
		_aborta_acao()
		return
	_fim_acao()


# -------------------------------------------------------------- 2. bazuca

func _roteiro_foguete() -> void:
	_set_fase(0)  # leva a mao as costas
	_segura_bazuca(true)
	if not await _espera(FOG_SACA):
		_aborta_acao()
		return

	_set_fase(1)  # mira
	if not await _espera(FOG_MIRA):
		_aborta_acao()
		return

	_set_fase(2)  # tiro
	_dispara_foguete()
	if not await _espera(FOG_ATIRA):
		_aborta_acao()
		return

	_set_fase(3)
	if not await _espera(FOG_VOLTA):
		_aborta_acao()
		return
	_segura_bazuca(false)
	_fim_acao()


func _dispara_foguete() -> void:
	if not is_instance_valid(player) or not is_inside_tree():
		return
	var cena := FX.mundo(self)
	if cena == null:
		return
	var f = Foguete.new()
	f.damage = dano_foguete
	f.alvo = player
	f.dono = self
	cena.add_child(f)
	# Sai na frente do ombro, na altura do tubo. Tirar o ponto do transform da
	# propria bazuca daria um lugar instavel: a arma e filha do pivo do ombro,
	# que a pose do braco esta girando justamente neste instante.
	var frente := -global_transform.basis.z
	var boca := global_position + Vector3.UP * (altura * 0.72) + frente * 1.1
	f.global_position = boca

	FX.som_no_mundo(self, boca, FX.SOM_EXPLOSAO, -6.0, 1.35)
	GlobalUtils.shake_camera(0.2, 0.18)
	# recuo: o corpo inteiro e empurrado pra tras
	# recuo: +Z e as costas dele (o corpo olha pra -Z)
	velocity += global_transform.basis.z * 3.0


# -------------------------------------------------------------- 4. espada

func _roteiro_espada() -> void:
	_set_fase(0)  # saca
	_segura_espada(true)
	if not await _espera(ESP_SACA):
		_aborta_acao()
		return

	_set_fase(1)  # corrida (tratada no `_anda_acao`)
	var corrida := 0.0
	while corrida < ESP_CORRE_MAX:
		if not await _espera(0.1):
			_aborta_acao()
			return
		corrida += 0.1
		if not is_instance_valid(player):
			break
		if global_position.distance_to(player.global_position) <= 2.9:
			break

	_set_fase(2)  # corte
	_corte_da_espada()
	if not await _espera(ESP_CORTA):
		_aborta_acao()
		return

	_set_fase(3)
	if not await _espera(ESP_VOLTA):
		_aborta_acao()
		return

	_set_fase(4)  # guarda a espada
	if not await _espera(ESP_GUARDA):
		_aborta_acao()
		return
	_segura_espada(false)
	_fim_acao()


## O golpe em si: o arco de fogo aparece e quem estiver na frente apanha.
func _corte_da_espada() -> void:
	if not is_inside_tree():
		return
	# Espera a lamina descer antes de qualquer coisa aparecer. Com o corte agora
	# durando 0,8 s, soltar o arco no frame zero punha o efeito no ar enquanto a
	# espada ainda estava erguida atras da cabeca.
	await get_tree().create_timer(ESP_CORTA * 0.32, false).timeout
	if dead or not is_inside_tree():
		return

	var frente := -global_transform.basis.z
	var centro := global_position + frente * 1.6 + Vector3.UP * (altura * 0.45)
	_arco_de_corte(centro, frente)
	FX.som_no_mundo(self, centro, FX.SOM_EXPLOSAO, -9.0, 1.8)
	GlobalUtils.shake_camera(0.25, 0.3)

	# O dano sai logo depois do arco, no ponto mais baixo da lamina.
	await get_tree().create_timer(ESP_CORTA * 0.16, false).timeout
	if dead or not is_inside_tree() or not is_instance_valid(player):
		return
	var para := player.global_position - global_position
	para.y = 0.0
	if para.length() > 3.4:
		return
	if para.normalized().dot(Vector3(frente.x, 0.0, frente.z).normalized()) < 0.15:
		return  # passou longe / pelas costas

	# Na cidade, acertar o jogador nao tira vida: arrasta pra arena (mesma
	# regra do encostao dos outros inimigos).
	if _tenta_batalha_forcada(player):
		return
	if player.has_method("take_damage"):
		player.take_damage(dano_espada)
	GlobalUtils.shake_camera(0.35, 0.45)
	GlobalUtils.vibrate_controller(null, 0.9, 0.9, 0.35)


## Meia-lua de fogo varrendo na frente dele.
func _arco_de_corte(centro: Vector3, frente: Vector3) -> void:
	var cena := FX.mundo(self)
	if cena == null:
		return
	var no := Node3D.new()
	cena.add_child(no)
	no.global_position = centro
	if absf(frente.y) < 0.95:
		no.look_at(centro + frente, Vector3.UP)

	var toro := TorusMesh.new()
	toro.inner_radius = 1.5
	toro.outer_radius = 2.0
	toro.rings = 24
	toro.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = toro
	var mat := FX.emissivo(Color(1.0, 0.5, 0.15), 7.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# o anel entra de lado e inclinado: leitura de corte diagonal
	mi.rotation = Vector3(deg_to_rad(90.0), 0.0, deg_to_rad(38.0))
	mi.scale = Vector3(0.2, 1.0, 1.0)
	no.add_child(mi)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.5, 0.15)
	luz.light_energy = 9.0
	luz.omni_range = 9.0
	luz.shadow_enabled = false
	no.add_child(luz)

	var faiscas := _particulas_brasa(0.9, 90, 0.8)
	faiscas.one_shot = true
	faiscas.explosiveness = 0.85
	var proc := faiscas.process_material as ParticleProcessMaterial
	proc.initial_velocity_min = 3.0
	proc.initial_velocity_max = 9.0
	proc.spread = 70.0
	faiscas.emitting = true
	no.add_child(faiscas)

	var t := no.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3(1.6, 1.3, 1.3), 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float): mat.albedo_color = Color(1.0, 0.5, 0.15, v), 1.0, 0.0, 0.52)
	t.tween_property(luz, "light_energy", 0.0, 0.52)
	t.chain().tween_interval(1.2)
	t.chain().tween_callback(no.queue_free)


# ------------------------------------------------------ defesa: esfera de fogo

func _roteiro_esfera() -> void:
	_set_fase(0)  # agacha pra saltar
	if not await _espera(ESF_AGACHA):
		_aborta_acao()
		return

	_set_fase(1)  # salta e abre bracos e pernas em cruz
	if not await _espera(ESF_SOBE):
		_aborta_acao()
		return

	_set_fase(2)  # a casca se fecha
	_levanta_esfera()
	if not await _espera(ESF_FORMA):
		_aborta_acao()
		return

	_set_fase(3)  # desce
	if not await _espera(ESF_CAI):
		_aborta_acao()
		return
	_fim_acao()


func _levanta_esfera() -> void:
	if escudo_ativo or dead:
		return
	var e = EsferaFogo.new()
	e.duration = duracao_esfera
	e.radius = altura * 0.70
	# Filha do RIG, nao do corpo: a esfera se fecha com ele suspenso no ar (o
	# salto e um deslocamento do rig, a capsula de colisao fica no chao). Presa
	# ao corpo, ela apareceria la embaixo, nos pes dele.
	_rig.add_child(e)
	e.position = Vector3(0, altura * 0.50, 0)
	_esfera = e
	escudo_ativo = true
	e.expired.connect(_on_esfera_expirada)


func _on_esfera_expirada() -> void:
	escudo_ativo = false
	_esfera = null
	# Sem isto a espera da esfera (que continuou correndo durante os 14 s) ja
	# estaria vencida e ele levantaria outra no frame seguinte.
	_esperas[Act.ESFERA] = _rng.randf_range(espera_esfera_min, espera_esfera_max)


func _derruba_esfera() -> void:
	escudo_ativo = false
	if is_instance_valid(_esfera):
		if _esfera.has_method("encerrar"):
			_esfera.encerrar()
		else:
			_esfera.queue_free()
	_esfera = null


# -------------------------------------------------------------- magia: anel

func _roteiro_anel() -> void:
	_set_fase(0)  # braco pro alto
	if not await _espera(ANEL_LEVANTA):
		_aborta_acao()
		return

	_set_fase(1)  # gira a mao: o anel se fecha acima dela
	var anel = Anel.new()
	anel.duracao = duracao_anel
	anel.fator = fator_anel
	anel.dono = self
	_mao_l.add_child(anel)
	anel.position = Vector3(0, -altura * 0.16, 0)
	anel.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)

	if not await _espera(ANEL_GIRA):
		if is_instance_valid(anel):
			anel.queue_free()
		_aborta_acao()
		return

	_set_fase(2)  # aponta pra frente e solta
	if not await _espera(ANEL_EMPURRA * 0.5):
		if is_instance_valid(anel):
			anel.queue_free()
		_aborta_acao()
		return
	if is_instance_valid(anel) and is_instance_valid(player):
		anel.lancar(player)
		_marca_anel_ativo()

	if not await _espera(ANEL_EMPURRA * 0.5):
		_aborta_acao()
		return
	_set_fase(3)
	if not await _espera(ANEL_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


## Segura um segundo anel enquanto o primeiro ainda pode estar grudado no
## jogador: dois efeitos de lentidao empilhados deixariam ele quase parado.
func _marca_anel_ativo() -> void:
	_anel_ativo = true
	if not is_inside_tree():
		return
	await get_tree().create_timer(duracao_anel + 3.0).timeout
	_anel_ativo = false


# ---------------------------------------------- movimento durante os poderes

## Fisica enquanto um poder roda. Quase todos travam o inimigo no lugar; a
## excecao e a corrida do ataque 4.
func _anda_acao(delta: float) -> void:
	if is_instance_valid(player):
		# Na corrida ele encara com mais vontade, pra curva ficar limpa.
		_encara(player.global_position, delta)

	if _act == Act.ESPADA and _fase == 1 and is_instance_valid(player):
		var dir := _direcao_para(player.global_position)
		if dir == Vector3.ZERO:
			velocity.x = move_toward(velocity.x, 0.0, rush_speed)
			velocity.z = move_toward(velocity.z, 0.0, rush_speed)
		else:
			_caminha(dir, rush_speed, delta)
		return

	velocity.x = move_toward(velocity.x, 0.0, chase_speed * 2.0)
	velocity.z = move_toward(velocity.z, 0.0, chase_speed * 2.0)


# ---------------------------------------------------- armas (troca de pai)

## Tira a espada das costas e poe na mao direita — e vice-versa. Trocar de pai
## e mais simples (e mais barato) que animar um braco indo buscar a arma, e com
## a pose do `_fase 0` do roteiro dando cobertura o jogador le o gesto certo.
func _segura_espada(na_mao: bool) -> void:
	if not is_instance_valid(_espada):
		return
	var destino: Node3D = _mao_r if na_mao else _costas
	if _espada.get_parent() != destino:
		_espada.get_parent().remove_child(_espada)
		destino.add_child(_espada)
	if na_mao:
		_espada.position = Vector3(0, -altura * 0.045, 0)
		_espada.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	else:
		_espada.position = Vector3(altura * 0.055, -altura * 0.02, altura * 0.03)
		_espada.rotation = Vector3(deg_to_rad(-8.0), 0.0, deg_to_rad(-28.0))
	_espada.visible = na_mao
	if _brasa_espada != null:
		_brasa_espada.emitting = na_mao


func _segura_bazuca(nas_maos: bool) -> void:
	if not is_instance_valid(_bazuca):
		return
	var destino: Node3D = _ombro_r if nas_maos else _costas
	if _bazuca.get_parent() != destino:
		_bazuca.get_parent().remove_child(_bazuca)
		destino.add_child(_bazuca)
	if nas_maos:
		# apoiada no ombro, apontando pra frente do corpo
		_bazuca.position = Vector3(-altura * 0.02, -altura * 0.05, 0)
		_bazuca.rotation = Vector3(0.0, 0.0, 0.0)
	else:
		_bazuca.position = Vector3(-altura * 0.060, -altura * 0.03, altura * 0.05)
		_bazuca.rotation = Vector3(0.0, deg_to_rad(14.0), deg_to_rad(24.0))
	_bazuca.visible = nas_maos


func _guarda_armas() -> void:
	_segura_espada(false)
	_segura_bazuca(false)


# ============================================================= animacao

func _anima(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var blend: float = clampf(planar / maxf(chase_speed, 0.01), 0.0, 1.0)

	if planar > 0.2 and is_on_floor():
		var antes := _passo_fase
		# Cadencia baixa = passada longa. Com 2,8 m de altura, a frequencia de
		# passo de uma pessoa o fazia parecer patinando no chao.
		_passo_fase += delta * (2.1 + planar * 0.7)
		var metade := int(floor(_passo_fase / PI))
		if metade != int(floor(antes / PI)):
			_pisa(planar)

	# rastro de brasa: so sai quando ele esta de fato andando
	if _rastro != null:
		_rastro.emitting = not dead and planar > 0.35
		var proc := _rastro.process_material as ParticleProcessMaterial
		if proc != null:
			proc.scale_max = 0.20 + blend * 0.16

	if is_instance_valid(_luz_olhos):
		var brilho := 3.0 + sin(_t * 2.3) * 0.5 + blend * 1.2
		if _act != Act.NENHUMA:
			brilho += 2.2
		_luz_olhos.light_energy = brilho

	if dead:
		_pose_morte(delta)
		_pose_asas(delta, 0.0, true)
		return

	if _act != Act.NENHUMA:
		_pose_acao(delta)
	else:
		_pose_andando(delta, blend)
	_pose_asas(delta, blend, false)


func _pisa(planar: float) -> void:
	if _steps == null or dead:
		return
	_steps.pitch_scale = clampf(0.5 + planar * 0.08, 0.45, 0.95) + _rng.randf_range(-0.04, 0.04)
	_steps.play()
	# cada pisada cospe brasa, mesmo parado girando
	if _rastro != null and not _rastro.emitting:
		_rastro.restart()


## Giro suave de um pivo ate a pose desejada. Tudo na animacao dele passa por
## aqui: e o que separa "bicho se movendo" de "boneco trocando de pose".
func _para(n: Node3D, alvo: Vector3, w: float) -> void:
	if n == null:
		return
	n.rotation = n.rotation.lerp(alvo, clampf(w, 0.0, 1.0))


func _altura_rig(alvo: float, w: float) -> void:
	_rig.position.y = lerpf(_rig.position.y, alvo, clampf(w, 0.0, 1.0))


## Caminhada/corrida + respiro parado. Perna digitigrada: o joelho dobra pra
## tras e o quadril sobe e desce a cada passo.
func _pose_andando(delta: float, blend: float) -> void:
	var w: float = clampf(delta * 6.0, 0.0, 1.0)
	var t := _passo_fase
	var balanco := 0.58 * blend
	var s := sin(t)
	var s2 := sin(t + PI)

	_altura_rig(0.0, w)
	_para(_coxa_l, Vector3(s * balanco, 0.0, 0.0), w)
	_para(_coxa_r, Vector3(s2 * balanco, 0.0, 0.0), w)
	_para(_joelho_l, Vector3(-0.22 - maxf(0.0, -sin(t + 1.4)) * 1.15 * blend, 0.0, 0.0), w)
	_para(_joelho_r, Vector3(-0.22 - maxf(0.0, -sin(t + PI + 1.4)) * 1.15 * blend, 0.0, 0.0), w)

	_hips.position.y = _descanso_hips() + absf(sin(t)) * 0.05 * blend
	_para(_hips, Vector3(0.0, sin(t) * 0.09 * blend, 0.0), w)
	# tronco levemente pra frente quando corre: peso no ataque
	_para(_spine, Vector3(0.06 + 0.12 * blend, -sin(t) * 0.10 * blend, sin(t) * 0.03 * blend), w)

	var bracos := 0.5 * blend
	_para(_ombro_l, Vector3(s2 * bracos, 0.0, -0.16 - 0.06 * blend), w)
	_para(_ombro_r, Vector3(s * bracos, 0.0, 0.16 + 0.06 * blend), w)
	_para(_cotovelo_l, Vector3(-0.35 - 0.40 * blend * maxf(0.0, s2), 0.0, 0.0), w)
	_para(_cotovelo_r, Vector3(-0.35 - 0.40 * blend * maxf(0.0, s), 0.0, 0.0), w)

	# parado: respira e olha em volta
	var p := 1.0 - blend
	if p > 0.01:
		_para(_neck, Vector3(sin(_t * 0.8) * 0.05 * p, sin(_t * 0.31) * 0.38 * p, 0.0), delta * 1.2)
		_hips.position.y += sin(_t * 1.2) * 0.012 * p
	else:
		_para(_neck, Vector3.ZERO, w)


func _descanso_hips() -> float:
	if _hips.has_meta("rest_y"):
		return float(_hips.get_meta("rest_y"))
	_hips.set_meta("rest_y", _hips.position.y)
	return _hips.position.y


## Asas. Fechadas quando ele esta so andando, abertas e batendo nos saltos e
## nos poderes — e escancaradas durante a esfera de fogo.
func _pose_asas(delta: float, blend: float, morto: bool) -> void:
	var w: float = clampf(delta * 3.6, 0.0, 1.0)
	var abertura := 0.0       # 0 = colada nas costas, 1 = escancarada
	var freq := 1.1
	var amplitude := 0.10

	# Asa de 2,8 m bate devagar e com curso longo. As frequencias abaixo sao
	# deliberadamente baixas (e as amplitudes altas pra compensar): asa rapida e
	# de passarinho, nao de bicho desse tamanho.
	if morto:
		abertura = 0.25
		amplitude = 0.0
	elif _act == Act.ESFERA and _fase >= 1:
		abertura = 1.0
		freq = 1.9
		amplitude = 0.22
	elif _act == Act.RAIO and _fase >= 1 and _fase <= 3:
		abertura = 0.95
		freq = 2.4
		amplitude = 0.38
	elif _act == Act.ESPADA and _fase == 1:
		abertura = 0.75
		freq = 1.8
		amplitude = 0.28
	elif _act != Act.NENHUMA:
		abertura = 0.55
		freq = 1.0
		amplitude = 0.16
	else:
		abertura = 0.20 + blend * 0.45
		freq = 0.7 + blend * 0.7
		amplitude = 0.11 + blend * 0.13

	var bate := sin(_t * TAU * freq) * amplitude
	for i in 2:
		var lado := 1.0 if i == 0 else -1.0
		var raiz: Node3D = _asa_l if i == 0 else _asa_r
		var meio: Node3D = _asa_meio_l if i == 0 else _asa_meio_r
		if raiz == null:
			continue
		# fechada: girada pra dentro e deitada nas costas.
		# aberta: varrida pra fora, subindo e descendo no ritmo do bater.
		var y := deg_to_rad(-lado * lerpf(62.0, 8.0, abertura))
		var z := deg_to_rad(lado * lerpf(22.0, -14.0, abertura)) + bate * lado
		var x := deg_to_rad(lerpf(12.0, -6.0, abertura)) + bate * 0.5
		_para(raiz, Vector3(x, y, z), w)
		if meio != null:
			_para(meio, Vector3(0.0, -lado * deg_to_rad(lerpf(58.0, 6.0, abertura)), bate * lado * 0.8), w)


# --------------------------------------------------------- poses dos poderes

func _pose_acao(delta: float) -> void:
	# Peso baixo = o pivo demora mais pra chegar na pose, e a chegada e macia.
	# Era aqui que estava a maior parte do "robotico": com delta*10 o braco
	# praticamente teleportava pra pose nova a cada troca de fase.
	var w: float = clampf(delta * 5.0, 0.0, 1.0)
	match _act:
		Act.ORBE: _pose_orbe(w)
		Act.RAIO: _pose_raio(w, delta)
		Act.FOGUETE: _pose_foguete(w)
		Act.ESPADA: _pose_espada(w)
		Act.ESFERA: _pose_esfera(w, delta)
		Act.ANEL: _pose_anel(w)
		_: pass


## Pernas plantadas e levemente flexionadas: base de quem esta conjurando.
func _pernas_firmes(w: float, flexao := 0.16) -> void:
	_para(_coxa_l, Vector3(-flexao * 0.5, 0.0, 0.0), w)
	_para(_coxa_r, Vector3(-flexao * 0.5, 0.0, 0.0), w)
	_para(_joelho_l, Vector3(-flexao, 0.0, 0.0), w)
	_para(_joelho_r, Vector3(-flexao, 0.0, 0.0), w)
	_hips.position.y = lerpf(_hips.position.y, _descanso_hips() - flexao * 0.12, w)


func _pose_orbe(w: float) -> void:
	_altura_rig(0.0, w)
	_pernas_firmes(w, 0.20)
	match _fase:
		0:
			# abre os bracos: as maos se afastam enquanto a bola cresce no meio
			var f: float = clampf(_fase_t / ORBE_ABRE, 0.0, 1.0)
			_para(_ombro_l, Vector3(-1.05 * f, 0.0, -0.55 - 0.45 * f), w)
			_para(_ombro_r, Vector3(-1.05 * f, 0.0, 0.55 + 0.45 * f), w)
			_para(_cotovelo_l, Vector3(-0.85 - 0.25 * f, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(-0.85 - 0.25 * f, 0.0, 0.0), w)
			_para(_spine, Vector3(-0.10 * f, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.12 * f, 0.0, 0.0), w)
		1:
			# estica tudo pra frente: e o empurrao que manda a magia embora
			_para(_ombro_l, Vector3(-1.55, 0.0, -0.22), w * 1.15)
			_para(_ombro_r, Vector3(-1.55, 0.0, 0.22), w * 1.15)
			_para(_cotovelo_l, Vector3(-0.05, 0.0, 0.0), w * 1.15)
			_para(_cotovelo_r, Vector3(-0.05, 0.0, 0.0), w * 1.15)
			_para(_spine, Vector3(0.16, 0.0, 0.0), w * 1.2)
		_:
			_para(_ombro_l, Vector3(-0.25, 0.0, -0.20), w * 0.7)
			_para(_ombro_r, Vector3(-0.25, 0.0, 0.20), w * 0.7)
			_para(_cotovelo_l, Vector3(-0.45, 0.0, 0.0), w * 0.7)
			_para(_cotovelo_r, Vector3(-0.45, 0.0, 0.0), w * 0.7)
			_para(_spine, Vector3(0.04, 0.0, 0.0), w * 0.7)
			_para(_neck, Vector3.ZERO, w * 0.7)


func _pose_raio(w: float, delta: float) -> void:
	match _fase:
		0:
			# os dois bracos sobem ate apontar pro ceu, tronco arqueando pra tras
			var f: float = clampf(_fase_t / RAIO_LEVANTA, 0.0, 1.0)
			var e := f * f * (3.0 - 2.0 * f)  # suaviza as duas pontas
			_altura_rig(0.0, w)
			_pernas_firmes(w, 0.22 * e)
			_para(_ombro_l, Vector3(-3.00 * e, 0.0, -0.30 * e), w)
			_para(_ombro_r, Vector3(-3.00 * e, 0.0, 0.30 * e), w)
			_para(_cotovelo_l, Vector3(-0.18 * e, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(-0.18 * e, 0.0, 0.0), w)
			_para(_spine, Vector3(-0.26 * e, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.40 * e, 0.0, 0.0), w)
		1:
			# Salto. A subida desacelera (`sin` de 0 a PI/2), como corpo que sai
			# do chao e perde forca — uma subida linear e o que faz um pulo
			# parecer elevador.
			var f1: float = clampf(_fase_t / RAIO_SOBE, 0.0, 1.0)
			_altura_rig(altura * SALTO_RAIO * sin(f1 * PI * 0.5), clampf(delta * 11.0, 0.0, 1.0))
			# os primeiros 18% da fase ainda sao o impulso: pernas esticando
			var impulso: float = clampf(f1 / 0.18, 0.0, 1.0)
			_para(_coxa_l, Vector3(0.80 * impulso, 0.0, 0.18 * impulso), w * 1.3)
			_para(_coxa_r, Vector3(0.80 * impulso, 0.0, -0.18 * impulso), w * 1.3)
			_para(_joelho_l, Vector3(-1.50 * impulso, 0.0, 0.0), w * 1.3)
			_para(_joelho_r, Vector3(-1.50 * impulso, 0.0, 0.0), w * 1.3)
			_para(_ombro_l, Vector3(-3.05, 0.0, -0.22), w)
			_para(_ombro_r, Vector3(-3.05, 0.0, 0.22), w)
		2:
			# Apice suspenso: agarra o raio com as duas maos acima da cabeca.
			# Ele flutua de leve aqui — parar completamente no ar nao le como
			# "segurando um raio", le como pausa de jogo.
			_altura_rig(altura * SALTO_RAIO + sin(_fase_t * 2.2) * 0.10, w)
			_para(_ombro_l, Vector3(-2.85, 0.0, -0.10), w)
			_para(_ombro_r, Vector3(-2.85, 0.0, 0.10), w)
			_para(_cotovelo_l, Vector3(-0.55, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(-0.55, 0.0, 0.0), w)
			_para(_spine, Vector3(-0.18, 0.0, 0.0), w)
		3:
			# arremesso: os bracos desabam pra frente e o tronco vem com eles
			var f3: float = clampf(_fase_t / RAIO_JOGA, 0.0, 1.0)
			# comeca a ceder no fim do arremesso, sem ainda cair de verdade
			_altura_rig(altura * SALTO_RAIO * (1.0 - f3 * 0.20), w)
			_para(_ombro_l, Vector3(lerpf(-2.85, -1.30, f3), 0.0, -0.18), w * 1.25)
			_para(_ombro_r, Vector3(lerpf(-2.85, -1.30, f3), 0.0, 0.18), w * 1.25)
			_para(_cotovelo_l, Vector3(lerpf(-0.55, -0.05, f3), 0.0, 0.0), w * 1.25)
			_para(_cotovelo_r, Vector3(lerpf(-0.55, -0.05, f3), 0.0, 0.0), w * 1.25)
			_para(_spine, Vector3(lerpf(-0.18, 0.34, f3), 0.0, 0.0), w * 1.2)
			_para(_neck, Vector3(0.22 * f3, 0.0, 0.0), w)
		_:
			# Queda ACELERADA (o quadrado faz o papel da gravidade) nos primeiros
			# 55% da fase, e so depois o amortecimento nos joelhos. O lerp
			# anterior descia rapido no comeco e lento no fim — exatamente o
			# contrario de um corpo caindo, e era o que mais chamava atencao.
			var f4: float = clampf(_fase_t / RAIO_CAI, 0.0, 1.0)
			var queda: float = clampf(f4 / 0.55, 0.0, 1.0)
			var alto := altura * SALTO_RAIO * 0.80
			_altura_rig(alto * (1.0 - queda * queda), clampf(delta * 20.0, 0.0, 1.0))
			# o amortecimento so existe DEPOIS de encostar no chao
			var aterrou: float = clampf((f4 - 0.5) / 0.5, 0.0, 1.0)
			var amort := sin(aterrou * PI) * 0.60
			_pernas_firmes(w * 1.4, 0.18 + amort)
			# no ar os bracos ficam soltos atras; ao aterrar vem pra frente
			_para(_ombro_l, Vector3(lerpf(-1.10, -0.30, aterrou), 0.0, -0.26), w)
			_para(_ombro_r, Vector3(lerpf(-1.10, -0.30, aterrou), 0.0, 0.26), w)
			_para(_cotovelo_l, Vector3(-0.50, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(-0.50, 0.0, 0.0), w)
			_para(_spine, Vector3(lerpf(0.34, 0.10, aterrou) * (1.0 - f4 * 0.5), 0.0, 0.0), w)
			_para(_neck, Vector3.ZERO, w)


func _pose_foguete(w: float) -> void:
	_altura_rig(0.0, w)
	match _fase:
		0:
			# mao direita vai as costas buscar o tubo, ombro esquerdo sobe pra apoiar
			var f: float = clampf(_fase_t / FOG_SACA, 0.0, 1.0)
			_pernas_firmes(w, 0.20)
			_para(_ombro_r, Vector3(lerpf(0.0, -1.15, f), 0.0, lerpf(0.16, 0.95, f)), w)
			_para(_cotovelo_r, Vector3(lerpf(-0.35, -1.85, f), 0.0, 0.0), w)
			_para(_ombro_l, Vector3(-0.75 * f, 0.0, -0.45 * f), w)
			_para(_cotovelo_l, Vector3(-1.30 * f, 0.0, 0.0), w)
			_para(_spine, Vector3(0.0, -0.22 * f, 0.0), w)
			_para(_neck, Vector3(0.0, 0.22 * f, 0.0), w)
		1:
			# mira: os dois bracos seguram o tubo e o corpo se firma de lado
			_pernas_firmes(w, 0.26)
			_para(_ombro_r, Vector3(-1.05, 0.0, 0.62), w)
			_para(_cotovelo_r, Vector3(-1.55, 0.0, 0.0), w)
			_para(_ombro_l, Vector3(-1.35, 0.0, -0.30), w)
			_para(_cotovelo_l, Vector3(-1.10, 0.0, 0.0), w)
			_para(_spine, Vector3(0.04, -0.16, 0.0), w)
			_para(_neck, Vector3(0.0, 0.16, 0.0), w)
		2:
			# recuo do tiro: tronco joga pra tras
			var f2: float = clampf(_fase_t / FOG_ATIRA, 0.0, 1.0)
			var kick := sin(f2 * PI)
			_pernas_firmes(w, 0.26 + kick * 0.18)
			_para(_ombro_r, Vector3(-1.05 + kick * 0.30, 0.0, 0.62), w * 1.2)
			_para(_ombro_l, Vector3(-1.35 + kick * 0.30, 0.0, -0.30), w * 1.2)
			_para(_spine, Vector3(-0.22 * kick, -0.16, 0.0), w * 1.2)
		_:
			_pernas_firmes(w, 0.18)
			_para(_ombro_l, Vector3(-0.28, 0.0, -0.24), w * 0.8)
			_para(_ombro_r, Vector3(-0.28, 0.0, 0.24), w * 0.8)
			_para(_cotovelo_l, Vector3(-0.45, 0.0, 0.0), w * 0.8)
			_para(_cotovelo_r, Vector3(-0.45, 0.0, 0.0), w * 0.8)
			_para(_spine, Vector3(0.04, 0.0, 0.0), w * 0.8)
			_para(_neck, Vector3.ZERO, w * 0.8)


func _pose_espada(w: float) -> void:
	_altura_rig(0.0, w)
	match _fase:
		0:
			# saca por cima do ombro
			var f: float = clampf(_fase_t / ESP_SACA, 0.0, 1.0)
			_pernas_firmes(w, 0.18)
			_para(_ombro_r, Vector3(lerpf(0.0, -2.10, f), 0.0, lerpf(0.16, 0.70, f)), w * 1.2)
			_para(_cotovelo_r, Vector3(lerpf(-0.35, -1.20, f), 0.0, 0.0), w * 1.2)
			_para(_ombro_l, Vector3(-0.40 * f, 0.0, -0.40), w)
			_para(_cotovelo_l, Vector3(-0.60 * f, 0.0, 0.0), w)
			_para(_spine, Vector3(0.0, -0.26 * f, 0.0), w)
		1:
			# corrida com a espada puxada pra tras, pronta pro golpe
			var planar := Vector2(velocity.x, velocity.z).length()
			var blend: float = clampf(planar / maxf(rush_speed, 0.01), 0.0, 1.0)
			var t := _passo_fase
			var s := sin(t)
			var s2 := sin(t + PI)
			_para(_coxa_l, Vector3(s * 0.78 * blend, 0.0, 0.0), w)
			_para(_coxa_r, Vector3(s2 * 0.78 * blend, 0.0, 0.0), w)
			_para(_joelho_l, Vector3(-0.28 - maxf(0.0, -sin(t + 1.4)) * 1.35 * blend, 0.0, 0.0), w)
			_para(_joelho_r, Vector3(-0.28 - maxf(0.0, -sin(t + PI + 1.4)) * 1.35 * blend, 0.0, 0.0), w)
			_hips.position.y = _descanso_hips() + absf(sin(t)) * 0.07 * blend
			_para(_spine, Vector3(0.30, -sin(t) * 0.12 * blend, 0.0), w)
			_para(_neck, Vector3(-0.22, 0.0, 0.0), w)
			# braco armado alto e atras; o esquerdo acompanha o passo
			_para(_ombro_r, Vector3(-2.25, 0.0, 0.85), w)
			_para(_cotovelo_r, Vector3(-1.05, 0.0, 0.0), w)
			_para(_ombro_l, Vector3(s2 * 0.55 * blend - 0.20, 0.0, -0.50), w)
			_para(_cotovelo_l, Vector3(-0.75, 0.0, 0.0), w)
		2:
			# o corte: diagonal de cima pra baixo, o corpo inteiro gira com ele
			var f2: float = clampf(_fase_t / ESP_CORTA, 0.0, 1.0)
			var e := f2 * f2
			_pernas_firmes(w, 0.30 * f2)
			_para(_ombro_r, Vector3(lerpf(-2.25, 0.55, e), 0.0, lerpf(0.85, -0.35, e)), w * 1.7)
			_para(_cotovelo_r, Vector3(lerpf(-1.05, -0.12, e), 0.0, 0.0), w * 1.7)
			_para(_ombro_l, Vector3(lerpf(-0.20, -0.90, e), 0.0, lerpf(-0.50, 0.30, e)), w * 1.15)
			_para(_spine, Vector3(lerpf(0.30, 0.40, e), lerpf(-0.45, 0.50, e), lerpf(-0.10, 0.18, e)), w * 1.15)
			_para(_neck, Vector3(0.30 * e, 0.25 * e, 0.0), w * 1.15)
		3:
			# recuperacao: a lamina desce e ele se endireita
			_pernas_firmes(w, 0.20)
			_para(_ombro_r, Vector3(0.25, 0.0, -0.10), w)
			_para(_cotovelo_r, Vector3(-0.50, 0.0, 0.0), w)
			_para(_ombro_l, Vector3(-0.45, 0.0, -0.25), w)
			_para(_spine, Vector3(0.12, 0.18, 0.0), w)
			_para(_neck, Vector3.ZERO, w)
		_:
			# guarda a espada por cima do ombro
			var f4: float = clampf(_fase_t / ESP_GUARDA, 0.0, 1.0)
			_pernas_firmes(w, 0.16)
			_para(_ombro_r, Vector3(lerpf(0.25, -1.90, f4), 0.0, lerpf(-0.10, 0.65, f4)), w)
			_para(_cotovelo_r, Vector3(lerpf(-0.50, -1.25, f4), 0.0, 0.0), w)
			_para(_spine, Vector3(0.06, -0.18 * f4, 0.0), w)


func _pose_esfera(w: float, delta: float) -> void:
	match _fase:
		0:
			# agacha carregando o salto
			var f: float = clampf(_fase_t / ESF_AGACHA, 0.0, 1.0)
			_altura_rig(0.0, w)
			_pernas_firmes(w, 0.20 + 0.55 * f)
			_para(_ombro_l, Vector3(0.35 * f, 0.0, -0.20), w)
			_para(_ombro_r, Vector3(0.35 * f, 0.0, 0.20), w)
			_para(_spine, Vector3(0.22 * f, 0.0, 0.0), w)
		1:
			# salta e se abre em cruz: bracos e pernas escancarados
			var f1: float = clampf(_fase_t / ESF_SOBE, 0.0, 1.0)
			var e := sin(f1 * PI * 0.5)
			_altura_rig(altura * SALTO_ESFERA * e, clampf(delta * 10.0, 0.0, 1.0))
			_para(_ombro_l, Vector3(-1.10 * e, 0.0, -1.35 * e), w * 1.25)
			_para(_ombro_r, Vector3(-1.10 * e, 0.0, 1.35 * e), w * 1.25)
			_para(_cotovelo_l, Vector3(-0.12, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(-0.12, 0.0, 0.0), w)
			_para(_coxa_l, Vector3(0.20 * e, 0.0, 0.70 * e), w)
			_para(_coxa_r, Vector3(0.20 * e, 0.0, -0.70 * e), w)
			_para(_joelho_l, Vector3(-0.20, 0.0, 0.0), w)
			_para(_joelho_r, Vector3(-0.20, 0.0, 0.0), w)
			_para(_spine, Vector3(-0.30 * e, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.35 * e, 0.0, 0.0), w)
		2:
			# Segura a pose de cruz, flutuando, enquanto a casca se fecha. E o
			# momento da imagem: ele parado no ar com o fogo nascendo em volta.
			_altura_rig(altura * SALTO_ESFERA + sin(_fase_t * 1.9) * 0.09, w)
			_para(_ombro_l, Vector3(-1.15, 0.0, -1.45), w)
			_para(_ombro_r, Vector3(-1.15, 0.0, 1.45), w)
			_para(_coxa_l, Vector3(0.22, 0.0, 0.75), w)
			_para(_coxa_r, Vector3(0.22, 0.0, -0.75), w)
			_para(_spine, Vector3(-0.32, 0.0, 0.0), w)
		_:
			# Desce (queda acelerada, como no raio) e volta a guarda, agora
			# dentro da esfera.
			var f3: float = clampf(_fase_t / ESF_CAI, 0.0, 1.0)
			var queda: float = clampf(f3 / 0.55, 0.0, 1.0)
			_altura_rig(altura * SALTO_ESFERA * (1.0 - queda * queda), clampf(delta * 18.0, 0.0, 1.0))
			var aterrou: float = clampf((f3 - 0.5) / 0.5, 0.0, 1.0)
			_pernas_firmes(w * 1.4, 0.20 + sin(aterrou * PI) * 0.45)
			_para(_ombro_l, Vector3(lerpf(-1.15, -0.40, aterrou), 0.0, lerpf(-1.45, -0.42, aterrou)), w)
			_para(_ombro_r, Vector3(lerpf(-1.15, -0.40, aterrou), 0.0, lerpf(1.45, 0.42, aterrou)), w)
			_para(_cotovelo_l, Vector3(-0.70 * aterrou - 0.12, 0.0, 0.0), w)
			_para(_cotovelo_r, Vector3(-0.70 * aterrou - 0.12, 0.0, 0.0), w)
			_para(_coxa_l, Vector3(0.22 * (1.0 - aterrou), 0.0, 0.75 * (1.0 - aterrou)), w)
			_para(_coxa_r, Vector3(0.22 * (1.0 - aterrou), 0.0, -0.75 * (1.0 - aterrou)), w)
			_para(_spine, Vector3(lerpf(-0.32, 0.08, aterrou), 0.0, 0.0), w)
			_para(_neck, Vector3.ZERO, w)


func _pose_anel(w: float) -> void:
	_altura_rig(0.0, w)
	_pernas_firmes(w, 0.18)
	match _fase:
		0:
			# braco esquerdo sobe esticado
			var f: float = clampf(_fase_t / ANEL_LEVANTA, 0.0, 1.0)
			var e := f * f * (3.0 - 2.0 * f)
			_para(_ombro_l, Vector3(-2.95 * e, 0.0, -0.22 * e), w)
			_para(_cotovelo_l, Vector3(-0.10 * e, 0.0, 0.0), w)
			_para(_ombro_r, Vector3(-0.30 * e, 0.0, 0.35 * e), w)
			_para(_cotovelo_r, Vector3(-0.55 * e, 0.0, 0.0), w)
			_para(_spine, Vector3(-0.14 * e, 0.0, 0.0), w)
			_para(_neck, Vector3(-0.30 * e, 0.0, 0.0), w)
		1:
			# a mao desenha circulos no ar: e o giro que fecha o anel
			var giro := _fase_t * TAU * 1.6
			_para(_ombro_l, Vector3(-2.95 + sin(giro) * 0.16, cos(giro) * 0.22, -0.22 + cos(giro) * 0.16), w * 1.2)
			_para(_cotovelo_l, Vector3(-0.10 - absf(sin(giro)) * 0.18, 0.0, 0.0), w * 1.2)
			_para(_spine, Vector3(-0.14, sin(giro) * 0.06, 0.0), w)
		2:
			# derruba o braco pra frente: o anel sai
			var f2: float = clampf(_fase_t / ANEL_EMPURRA, 0.0, 1.0)
			_para(_ombro_l, Vector3(lerpf(-2.95, -1.45, f2), 0.0, lerpf(-0.22, -0.10, f2)), w * 1.15)
			_para(_cotovelo_l, Vector3(-0.05, 0.0, 0.0), w * 1.15)
			_para(_spine, Vector3(lerpf(-0.14, 0.22, f2), 0.0, 0.0), w * 1.2)
			_para(_neck, Vector3(0.16 * f2, 0.0, 0.0), w)
		_:
			_para(_ombro_l, Vector3(-0.28, 0.0, -0.22), w * 0.8)
			_para(_ombro_r, Vector3(-0.28, 0.0, 0.22), w * 0.8)
			_para(_cotovelo_l, Vector3(-0.45, 0.0, 0.0), w * 0.8)
			_para(_cotovelo_r, Vector3(-0.45, 0.0, 0.0), w * 0.8)
			_para(_spine, Vector3(0.04, 0.0, 0.0), w * 0.8)
			_para(_neck, Vector3.ZERO, w * 0.8)


## Morte: ele se dobra, as asas caem e o corpo tomba pra frente. A rotacao
## acontece no rig (nao no corpo fisico), senao a capsula de colisao viraria
## junto e ele afundaria no chao.
func _pose_morte(delta: float) -> void:
	var w: float = clampf(delta * 3.0, 0.0, 1.0)
	_altura_rig(0.0, w)
	_para(_spine, Vector3(0.95, 0.0, 0.25), w)
	_para(_neck, Vector3(0.55, 0.0, 0.0), w)
	_para(_ombro_l, Vector3(0.85, 0.0, -0.70), w)
	_para(_ombro_r, Vector3(0.85, 0.0, 0.70), w)
	_para(_cotovelo_l, Vector3(-0.30, 0.0, 0.0), w)
	_para(_cotovelo_r, Vector3(-0.30, 0.0, 0.0), w)
	_pernas_firmes(w, 0.95)
	_rig.rotation.x = lerpf(_rig.rotation.x, deg_to_rad(-72.0), clampf(delta * 1.6, 0.0, 1.0))
	_rig.position.y = lerpf(_rig.position.y, altura * 0.18, clampf(delta * 1.6, 0.0, 1.0))


# ============================================================ dano e morte

func take_damage(amount) -> void:
	if dead:
		return
	var dano := int(amount)

	# Esfera de fogo de pe: o golpe chega bem mais fraco e a casca reage.
	if escudo_ativo:
		dano = maxi(1, int(round(float(dano) * (1.0 - reducao_esfera))))
		if is_instance_valid(_esfera) and _esfera.has_method("flash"):
			_esfera.flash()

	if _grunhido_dano != null and not _grunhido_dano.playing:
		_grunhido_dano.play()

	current_health = clampi(current_health - dano, 0, max_health)

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
	_derruba_esfera()
	if is_instance_valid(_raio_no):
		_raio_no.queue_free()
	_raio_no = null
	_guarda_armas()
	if _rastro != null:
		_rastro.emitting = false
	if _fogo_olhos != null:
		_fogo_olhos.emitting = false
	if _fogo_corpo != null:
		create_tween().tween_property(_fogo_corpo, "volume_db", -40.0, 2.0)
	if _luz_olhos != null:
		create_tween().tween_property(_luz_olhos, "light_energy", 0.0, 2.2)
	died.emit()
	if _grunhido_morte != null:
		_grunhido_morte.play()
	SaveManager.add_iron_rusks(iron_rusks_value)

	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(2.4).timeout
	if _tombo != null and is_inside_tree():
		_tombo.play()

	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(1.0).timeout
	set_collision_layer_value(3, false)

	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(15.0).timeout
	queue_free()


## Tira o inimigo do jogo sem nada na tela: sem barra de chefe, sem iron rusks,
## sem morte. E o caminho de quem some longe do jogador (o spawner liberando
## quem ficou pra tras) e de quem cai do mapa.
func remover_em_silencio() -> void:
	dead = true
	_act = Act.NENHUMA
	_derruba_esfera()
	if is_instance_valid(_raio_no):
		_raio_no.queue_free()
	_raio_no = null
	set_physics_process(false)
	if _steps != null:
		_steps.stop()
	if _fogo_corpo != null:
		_fogo_corpo.stop()
	_esconde_barra()
	queue_free()


## A barra de chefe pode estar mostrando justamente este inimigo. Ela sumiria
## sozinha em 2 s, mas com o nome de alguem que deixou de existir.
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
	# Fora da cidade o toque nao faz nada: na arena quem encosta e a espada.
	_tenta_batalha_forcada(corpo)


## Toque no Maycow normal enquanto ele anda pela cidade: em vez de dano, ele
## perde metade do sangue e a batalha na arena comeca a forca. Quem cuida da
## sequencia e o `player_amulet.gd`. Vale SO na stage_1 e depois do prologo.
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
	# CONSUMIDO: cair no dano normal seria tirar vida por cima da cinematica.
	# Antes de descartar, oferece este inimigo a sequencia — se ela ainda nao
	# viajou, ele embarca junto (ver player_amulet._juntar_na_batalha_forcada).
	if GlobalEvents.forced_battle_running:
		corpo.force_battle_from_touch(self)
		return true

	return corpo.force_battle_from_touch(self)
