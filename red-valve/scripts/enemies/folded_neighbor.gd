extends CharacterBody3D
class_name FoldedNeighbor

## "Unknown Neighbor" / "Vizinho Desconhecido" — o inimigo que era uma pessoa
## comum.
##
## O ARQUIVO e a classe continuam se chamando `folded_neighbor` / `FoldedNeighbor`
## de proposito: o nome de exibicao mora no CSV (`NEIGHBOR_NAME`), e renomear
## script, cena, uid e a entrada do spawner so pra acompanhar um nome de tela
## seria muito risco por nenhum ganho. Se algum dia valer a pena, o lugar de
## comecar e' este comentario.
##
## Na rua ele e' um morador: um dos mesmos 92 modelos que povoam a cidade no
## prologo, com a mesma roupa e a mesma caminhada. O unico sinal e' uma raiz
## fina correndo por baixo da pele do pescoco. Quem passar reto nunca vai saber.
## Quem parar pra olhar duas vezes — ou atirar — descobre que a pessoa estava
## DOBRADA, e que tem mais coisa dentro dela do que cabia.
##
## Referencia declarada: os aldeoes de Resident Evil 4. Nao o zumbi (que ja
## chega sendo monstro), mas o vizinho que vira monstro DEPOIS, na sua frente,
## abrindo a cabeca em petalas. O jogo ja tem tres inimigos que se anunciam de
## longe pela silhueta; este e' o que se disfarca.
##
## ==========================================================================
## AS CINCO FORMAS
##
## Ele nao troca de forma por tempo nem por roteiro: troca por DANO. Cada faixa
## de vida abre mais uma dobra, e a que abriu nunca fecha. O jogador que atira
## muito rapido no comeco chega no fim da briga contra uma coisa bem pior do
## que a que ele encontrou.
##
##   1. O VIZINHO      100%..80%  Pessoa. So o toque. Nada denuncia, alem da raiz.
##   2. A ABERTURA      80%..60%  A cabeca racha em petalas, a mandibula se
##                                parte, o nucleo aparece no pescoco.
##                                >>> libera O CORO
##   3. O CEIFADOR      60%..40%  O antebraco direito se desdobra numa foice de
##                                osso; a mao daquele lado e' absorvida.
##                                >>> libera A CEIFA CEGA
##   4. O RASTEJANTE    40%..20%  As costelas abrem, quatro patas saem das
##                                costas, o corpo se curva pra frente e acelera.
##                                >>> libera A SEMEADURA
##   5. O DESDOBRADO    20%..0%   O corpo humano amolece e passa a ser carregado
##                                pelo parasita, com o nucleo exposto no peito.
##                                Tudo mais rapido, e a dobra vira constante.
##
## ==========================================================================
## AS QUATRO LINHAGENS (as "variacoes")
##
## Mesmo corpo, mesma silhueta, mesmos poderes. O que muda e' a COR do parasita
## e o formato das PETALAS da coroa — os dois unicos canais que se leem a 20 m
## na nevoa. Ver `neighbor_fx.gd`: Palido, Biliar, Escarlate e Cinzento.
##
## ==========================================================================
## DESMEMBRAMENTO
##
## Braco, mao, perna e cabeca tem caixa de acerto propria (camada 4, a que o
## raycast da arma procura) e um contador de dano proprio. Enchendo o contador,
## a peca CAI — e cada peca que cai muda a briga:
##
##   braco direito  ->  vai junto a foice: acabou A CEIFA CEGA
##   mao esquerda   ->  acabou A SEMEADURA ate ela crescer de novo
##   perna          ->  ele passa a se arrastar, na metade da velocidade
##   CABECA         ->  o melhor e o pior golpe do jogo contra ele: mata a
##                      ABERTURA e o CORO junto, mas o parasita assume na hora
##                      (pula direto pra quinta forma) e ele fica CEGO — para
##                      de mirar no jogador e passa a atacar onde ele ESTAVA.
##                      Um bicho cego e' mais facil de enganar e muito mais
##                      dificil de prever.
##
## ==========================================================================
## A DOBRA (teletransporte) — SO NA ARENA
##
## Na cidade ele nunca se dobra: e' um morador andando na calcada, e some-e-
## aparece na rua estragaria o unico truque que ele tem. Dentro da arena, sim:
## ele se fecha num plano vertical, vira uma linha e reaparece do outro lado,
## de preferencia nas costas do jogador.
##
## ==========================================================================
## POR QUE ELE NAO USA A `enemy.gd` COMO O ZUMBI E O COBALT
##
## Pelo mesmo motivo do Shadow Seraph e do Shadow Rock: aquela classe e'
## construida em volta de um `.glb` com AnimationTree e os estados
## "idle"/"walk"/"attack"/"dead". Os modelos de morador NAO tem animacao
## nenhuma — o pacote traz so a malha e o rig. A caminhada, a pose de cada
## poder e o corpo amolecendo na quinta forma sao calculados osso a osso pelo
## `HumanoidPoser`, exatamente como nos NPCs da cidade.
##
## O que ele mantem igual e' o CONTRATO que o resto do jogo consulta: grupo
## "enemies", `dead`, sinal `died`, `cutscene_mode`, `player`, `take_damage()`,
## `remover_em_silencio()` e a barra de chefe no topo da tela. Assim o amuleto,
## a arena, o spawner da cidade e o tiro do jogador funcionam sem saber que ele
## e' diferente.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const NFX := preload("res://scripts/effects/neighbor_fx.gd")
const ShadowRoads := preload("res://scripts/npcs/shadow_roads.gd")

const Coro := preload("res://scripts/effects/neighbor_choir.gd")
const Semente := preload("res://scripts/effects/neighbor_stalk.gd")
const Casca := preload("res://scripts/effects/neighbor_husk.gd")
const Dobra := preload("res://scripts/effects/neighbor_fold.gd")
const Vulto := preload("res://scripts/effects/neighbor_decoy.gd")
const MembroCaido := preload("res://scripts/effects/neighbor_limb.gd")
const CaixaMembro := preload("res://scripts/enemies/folded_neighbor_limb.gd")

const SHADER_AURA := "res://shaders/enemies/neighbor_aura.gdshader"

signal died

enum Forma { VIZINHO, ABERTURA, CEIFADOR, RASTEJANTE, DESDOBRADO }
enum State { VAGANDO, PERSEGUINDO, ACAO, MORTO }
enum Act { NENHUMA, CORO, CEIFA, SEMEADURA, CASCA, MUDANDO, TOQUE }

# ------------------------------------------------------------------ ajustes

@export_group("Identidade")
## Chave de traducao, nao o texto: o nome dele esta no CSV
## (`assets/textos/red_valve_textos_gerais.csv`), como todo texto do jogo. A
## barra de chefe nao usa isto — ela mostra a FORMA e a LINHAGEM de agora, que
## mudam no meio da briga (ver `_nome_agora`). Fica aqui porque e' o campo que
## o resto do jogo procura quando quer saber "quem e' esse".
@export var enemy_name: String = "NEIGHBOR_NAME"
## Vida ANTES do multiplicador da linhagem.
@export var max_health: int = 170
@export var iron_rusks_value: int = 5

@export_group("Agarrao")
## O que este inimigo faz quando agarra o jogador na rua: "mordida" (chega no
## rosto, morde e solta) ou "arremesso" (levanta e joga longe). Quem monta a
## cena e' o player_grab.gd; aqui so' se escolhe qual das duas.
@export_enum("mordida", "arremesso") var tipo_agarrao: String = "mordida"
## Desliga o agarrao neste inimigo. Ele volta ao encostao comum (dano direto),
## igual ao de dentro da arena.
@export var permite_agarrao: bool = true
## -1 = sorteia a linhagem (o normal). 0..3 forca uma — ver NFX.Linhagem.
@export var linhagem_index: int = -1
## -1 = sorteia o morador. 0..N forca um modelo da lista do CityNpc.
@export var modelo_index: int = -1

@export_group("Movimento")
## Passo de morador, quando ele ainda esta so andando pela rua.
@export var walk_speed: float = 1.5
## Passo de quando ja percebeu o jogador.
@export var chase_speed: float = 3.0
## Corrida da investida da foice.
@export var rush_speed: float = 8.5
@export var turn_speed: float = 5.0
@export var distance_to_aproach: float = 22.0
@export var use_navigation: bool = true
## Raio em que ele fica vagando em volta de onde nasceu.
@export var wander_radius: float = 40.0
## So anda onde ha rua (mesmo grid das sombras e dos moradores).
@export var road_only: bool = true

@export_group("Dano dos poderes")
## Os numeros aqui sao a forca BASE; a linhagem ainda multiplica (a escarlate
## bate 25% mais forte, a palida 15% mais fraco). Foram todos baixados numa
## passada so depois do primeiro teste de jogo: ele e' um encontro COMUM, com
## ate tres deles na rua ao mesmo tempo, e nao um chefe — na forca antiga dois
## vizinhos juntos matavam o jogador antes de ele aprender o repertorio.
@export var dano_coro: int = 16
@export var dano_ceifa: int = 24
@export var dano_semeadura: int = 4
@export var dano_toque: int = 10

@export_group("Esperas entre poderes")
## Subidas depois do primeiro teste: ele encadeava poder atras de poder e a
## briga virava uma parede de efeito, sem o silencio entre um golpe e outro que
## e' onde o jogador pensa. O aumento e' de proposito pequeno (~30%) — o bicho
## continua insistente, so parou de ser frenetico.
@export var espera_coro_min: float = 12.0
@export var espera_coro_max: float = 19.0
@export var espera_ceifa_min: float = 14.0
@export var espera_ceifa_max: float = 23.0
@export var espera_semeadura_min: float = 17.0
@export var espera_semeadura_max: float = 27.0
@export var espera_casca_min: float = 25.0
@export var espera_casca_max: float = 38.0
## Respiro obrigatorio entre o fim de um poder e o comeco do proximo.
@export var respiro_entre_poderes: float = 2.4

@export_group("Defesa")
## Duracao baixada de 11 s: com a casca de pe ele quase nao leva dano, e onze
## segundos disso, varias vezes por briga, era tempo demais do jogador so
## esperando. Quem quiser encurtar mais ainda derruba as placas a tiro.
@export var duracao_casca: float = 7.5
## 0.72 = leva 72% menos dano enquanto a casca esta de pe.
@export_range(0.0, 1.0) var reducao_casca: float = 0.72

@export_group("A dobra")
## Faixa de espera entre um reposicionamento e o proximo, DENTRO da arena.
@export var espera_dobra_min: float = 7.0
@export var espera_dobra_max: float = 13.0
## Onde ele reaparece, medido a partir do jogador.
@export var dobra_perto: float = 4.5
@export var dobra_longe: float = 11.0

@export_group("Desmembramento")
## Dano acumulado em cada peca pra ela cair. Multiplicado pela linhagem.
@export var limite_cabeca: int = 58
@export var limite_braco: int = 46
@export var limite_mao: int = 26
@export var limite_perna: int = 52
## Quanto tempo ate a mao arremessada na semeadura crescer de novo.
@export var tempo_regenera_mao: float = 9.0

@export_group("Debug")
## Despeja no console o peso do passo lateral e os angulos dos dois quadris.
## So serve pra conferir a marcha na bancada de teste; fica desligado no jogo.
@export var debug_passo_lateral: bool = false

@export_group("Desempenho")
## Acima desta distancia do jogador ele congela (nao processa fisica).
@export var activation_distance: float = 120.0
## Ate esta distancia da camera a pose e' recalculada todo quadro de fisica.
@export var distancia_pose_cheia: float = 16.0

# ------------------------------------------------------------------- estado

var player: Node3D = null
var dead: bool = false
var cutscene_mode: bool = false
var current_health: int = 0

var forma: int = Forma.VIZINHO
var state: int = State.VAGANDO
var _act: int = Act.NENHUMA
var _fase: int = 0

var linhagem: int = 0
var _dados: Dictionary = {}
var _cor: Color = Color.WHITE
var _cor_veia: Color = Color.WHITE

var _t: float = 0.0
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
## Pra que lado ele esta rodeando o jogador, e quanto falta pra trocar.
var _lado_rodeio: float = 1.0
var _troca_rodeio: float = 0.0
var _pausa_rodeio: float = 0.0

## Lido UMA vez por quadro de fisica, no topo do `_physics_process`, e usado
## por todo o resto do quadro. Antes cada trecho chamava `_na_arena()` de novo:
## alem de repetir a busca, abria espaco pra dois trechos do MESMO quadro
## discordarem sobre onde ele esta.
var _em_arena: bool = false
## Trava do "acabei de chegar": a chegada na arena tem de acontecer uma vez so.
var _entrou_na_arena: bool = false

var escudo_ativo: bool = false
var _casca: Node3D = null
var _broto: Node = null
var _dobrando: bool = false
var _espera_dobra: float = 0.0
## Ele perdeu a cabeca: para de mirar e passa a atacar onde o jogador ESTAVA.
var _cego: bool = false
var _ponto_velho: Vector3 = Vector3.ZERO
var _relogio_memoria: float = 0.0
var _sem_mao_ate: float = 0.0

# corpo
var _rig: Node3D
var _modelo_raiz: Node3D
var _sk: Skeleton3D
var _poser: HumanoidPoser
var _escala_base: float = 1.0
var _altura: float = 1.78

# parasita
var _flor: Node3D
var _petalas: Array[Node3D] = []
var _mandibulas: Array[Node3D] = []
var _nucleo: MeshInstance3D
## Escala de REPOUSO da peca do nucleo. Sem guardar isto, abrir a flor escrevia
## `Vector3.ONE * 0.55` por cima da escala real da malha — e como a peca chega
## normalizada (1 unidade), o nucleo virava uma bola de meio metro na cabeca,
## tapando o rosto. Toda abertura daqui MULTIPLICA esta base.
var _nucleo_base: Vector3 = Vector3.ONE
var _nucleo_peito: MeshInstance3D
var _nucleo_peito_base: Vector3 = Vector3.ONE
var _caixa_nucleo: Area3D
var _foice: Node3D
var _costelas: Array[Node3D] = []
var _patas: Array[Node3D] = []
var _raizes: Array[Node3D] = []
var _luz_parasita: OmniLight3D
var _mat_parasita: Material
var _aura: Node3D
var _aura_po: GPUParticles3D
var _aura_luz: OmniLight3D
var _aura_anel: MeshInstance3D
var _aura_mat: StandardMaterial3D
## O contorno luminoso, pendurado como `material_overlay` nas malhas do corpo.
## Um por inimigo (e nao compartilhado): a forca dele pulsa por instancia.
var _aura_contorno: ShaderMaterial
var _aura_ligada: bool = false

# membros
var _membros: Dictionary = {}
var _cotos: Dictionary = {}

# animacao
var _passada: float = 0.0
var _gesto: float = 0.0
var _abertura: float = 0.0
var _planar: float = 0.0
var _pose_espera: int = 0
## O que a passada frontal escreveu neste quadro, pro passo lateral misturar.
var _juntas_frontais: Dictionary = {}
var _relogio_debug: float = 0.0
var _curva: float = 0.0
var _pose_forca: float = 0.0

# audio
var _passos: AudioStreamPlayer3D
var _resmungo: AudioStreamPlayer3D
var _grito: AudioStreamPlayer3D
var _dor: AudioStreamPlayer3D
var _morte: AudioStreamPlayer3D
var _tombo: AudioStreamPlayer3D

## Sentinela de "nao ha chao aqui". Devolver `null` obrigaria a tipagem solta em
## todo o caminho da dobra; um Y impossivel resolve com o tipo intacto. Mesma
## solucao do `enemy_spawner.gd`.
const SEM_CHAO := Vector3(0.0, -99999.0, 0.0)

## Distancia sondada a frente pela cerca da arena. Um passo e meio: perto o
## bastante pra nao engessar o movimento em cima de qualquer irregularidade,
## longe o bastante pra ele frear antes de o pe sair da plataforma.
const SONDA_FRENTE := 1.4

const GRAVIDADE := 20.0
const NAV_TOLERANCIA := 3.0
## Fracao da vida em que cada forma abre.
const LIMIARES := [1.0, 0.80, 0.60, 0.40, 0.20]

static var _cam_pos := Vector3.ZERO
static var _cam_quadro := -1


# =========================================================== ciclo de vida

func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()

	linhagem = linhagem_index if linhagem_index >= 0 else _rng.randi_range(0, NFX.LINHAGENS.size() - 1)
	_dados = NFX.linhagem(linhagem)
	_cor = _dados["cor"]
	_cor_veia = _dados["cor_veia"]
	_mat_parasita = NFX.material_parasita(linhagem)

	max_health = maxi(1, int(round(float(max_health) * float(_dados["vida"]))))
	current_health = max_health
	_home = global_position
	_destino = _home
	_ponto_velho = global_position

	_monta_corpo()
	_monta_parasita()
	_monta_colisoes()
	_monta_membros()
	_monta_audio()
	_monta_nav()
	ShadowRoads.setup(get_tree())

	player = _acha_player()
	_em_arena = _na_arena()
	# `_entrou_na_arena` fica FALSO mesmo se ele ja nasceu dentro da arena: o
	# primeiro quadro de fisica dispara o `_chegou_na_arena()` de qualquer
	# jeito, e assim quem e' colocado direto la (um marcador na cena, um teste)
	# se abre igual a quem chegou arrastado pelo amuleto.
	_aplica_forma(Forma.VIZINHO, true)
	_liga_aura(not _em_arena)

	# Primeiros usos sorteados baixos: quando a briga comeca ele ja esta na
	# segunda ou terceira forma (chegou ali levando tiro), e o jogador precisa
	# ver o repertorio antes de o encontro acabar.
	_esperas = {
		Act.CORO: _rng.randf_range(2.0, 5.0),
		Act.CEIFA: _rng.randf_range(4.0, 8.0),
		Act.SEMEADURA: _rng.randf_range(6.0, 11.0),
		Act.CASCA: _rng.randf_range(8.0, 15.0),
	}
	_espera_dobra = _rng.randf_range(3.0, 7.0)

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


## Estamos na arena? Quase tudo que ele sabe fazer so existe la: a dobra, a
## ceifa, a semeadura e a casca. Na rua ele e' um morador que anda na sua
## direcao — e, se tiver aberto (segunda forma pra cima), grita.
func _na_arena() -> bool:
	if not is_inside_tree() or get_tree() == null:
		return false
	var cena := get_tree().current_scene
	return cena != null and cena.scene_file_path.contains("battlefield")


## Chamado UMA vez, no primeiro quadro em que ele percebe que foi parar na
## arena (o amuleto o arranca da cidade e o reparenta la).
##
## Sem isto ele levava um tempo pra "entender" onde estava: ele chegava na
## arena ainda na PRIMEIRA forma, e a primeira forma nao tem poder nenhum —
## entao o `_distancia_desejada()` mandava ele pra cima do jogador, que e' o
## certo na rua e errado aqui. Ele so parava de correr atras do jogador depois
## de levar dano suficiente pra abrir a segunda dobra. Agora a chegada e' o
## proprio gatilho: o disfarce nao serve mais pra nada dentro da arena, entao
## ele se abre na hora e passa a brigar de longe.
func _chegou_na_arena() -> void:
	_aborta_acao()
	_respiro = 0.0
	# Durante a cinematica de entrada da batalha o corpo nao processa acao
	# nenhuma, entao o gesto de transformacao nao teria como rodar: nesse caso
	# ele ja aparece aberto. Fora dela, abre em cena.
	if forma < Forma.ABERTURA:
		if cutscene_mode:
			_aplica_forma(Forma.ABERTURA, true)
		else:
			_muda_forma(Forma.ABERTURA)
	# Primeiros poderes logo: o jogador acabou de ser arrastado pra ca e nao
	# pode encarar dez segundos de bicho andando em circulo.
	_esperas[Act.CORO] = minf(float(_esperas[Act.CORO]), _rng.randf_range(1.5, 3.0))
	_esperas[Act.CEIFA] = minf(float(_esperas[Act.CEIFA]), _rng.randf_range(4.0, 7.0))
	_agenda_dobra()
	_liga_aura(false)


# ================================================================ o CORPO

## O corpo e' um morador de verdade: um dos modelos do pacote da cidade, o mesmo
## que o `city_npc.gd` usa. Nao ha versao "de inimigo" do modelo, e e' esse o
## ponto — ele tem de ser exatamente a mesma pessoa que o jogador ja viu
## andando na calcada.
func _monta_corpo() -> void:
	var cena := _sorteia_modelo()
	if cena == null:
		push_error("FoldedNeighbor: nenhum modelo de morador pode ser carregado.")
		return

	_escala_base = float(_dados["escala"])
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.scale = Vector3.ONE * _escala_base
	add_child(_rig)

	_modelo_raiz = cena.instantiate() as Node3D
	if _modelo_raiz == null:
		return
	_rig.add_child(_modelo_raiz)

	# O arquivo traz um AnimationPlayer com a pose de bind e nada mais. Se ele
	# ficar, qualquer play() acidental sobrescreve o que o poser escreveu nos
	# ossos.
	var ap := _modelo_raiz.find_child("AnimationPlayer", true, false)
	if ap != null:
		ap.queue_free()

	_sk = _acha_esqueleto(_modelo_raiz)
	if _sk == null:
		push_warning("FoldedNeighbor: modelo sem Skeleton3D; fica parado feito estatua.")
		return

	_veste_contorno()

	_poser = HumanoidPoser.new()
	# giro 0: o rig do Mixamo ja nasce olhando pro +Z, que e' pra onde o
	# `_encara()` daqui poe o corpo. Ver o cabecalho do humanoid_poser.gd.
	if not _poser.setup(_sk, 0.0):
		push_warning("FoldedNeighbor: rig nao reconhecido em " + String(_modelo_raiz.name))
		_poser = null
	else:
		_altura = _poser.altura_total * _escala_base


## Pendura o contorno da aura em TODA malha do corpo, como overlay.
##
## `material_overlay` e' um passe a mais por cima do material que ja esta la —
## nao substitui nada. E e' por isso que da pra fazer isto num modelo que nao e'
## nosso: a roupa e a pele do morador continuam intactas, e a unica coisa que
## muda e' um fio de luz na silhueta. Trocar o material do modelo, em vez de
## sobrepor, apagaria a textura e o disfarce junto com ela.
func _veste_contorno() -> void:
	var sh := load(SHADER_AURA) as Shader
	if sh == null:
		return
	_aura_contorno = ShaderMaterial.new()
	_aura_contorno.shader = sh
	_aura_contorno.set_shader_parameter("cor", _dados["cor_luz"])
	_aura_contorno.set_shader_parameter("forca", 0.0)
	_poe_overlay(_modelo_raiz)


func _poe_overlay(no: Node) -> void:
	if no is MeshInstance3D:
		(no as MeshInstance3D).material_overlay = _aura_contorno
	for f in no.get_children():
		_poe_overlay(f)


func _sorteia_modelo() -> PackedScene:
	var lista: Array = CityNpc.MODELOS
	if lista.is_empty():
		return null
	var i := modelo_index
	if i < 0 or i >= lista.size():
		i = _rng.randi_range(0, lista.size() - 1)
	return load(CityNpc.PASTA + String(lista[i]) + ".fbx") as PackedScene


func _acha_esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s := _acha_esqueleto(c)
		if s != null:
			return s
	return null


## Indice de um osso do rig, aceitando os varios prefixos que o Mixamo produz.
func _osso(nome: String) -> int:
	if _sk == null:
		return -1
	for p in HumanoidPoser.PREFIXOS:
		var i := _sk.find_bone(p + nome)
		if i >= 0:
			return i
	return -1


## Pendura um no num osso. Tudo o que e' parasita entra por aqui, e por isso
## acompanha a pose que o poser escreve — a flor balanca quando ele anda, a
## foice sobe quando ele levanta o braco, sem uma linha a mais de codigo.
func _no_osso(nome_osso: String, nome: String) -> Node3D:
	var idx := _osso(nome_osso)
	if idx < 0 or _sk == null:
		# Sem o osso, pendura no corpo mesmo: e' feio, mas nao some.
		var solto := Node3D.new()
		solto.name = nome
		add_child(solto)
		return solto
	var att := BoneAttachment3D.new()
	att.name = nome
	att.bone_idx = idx
	_sk.add_child(att)
	return att


# ============================================================== o PARASITA
#
# Tudo o que nao e' o morador nasce aqui, e nasce ESCONDIDO (escala zero). As
# formas nao criam peca nenhuma em tempo de execucao: elas so abrem o que ja
# estava dobrado dentro dele. E isso que permite a transicao ser um tween de
# 0,6 s no meio da briga, sem engasgo.
#
# As medidas sao todas fracoes da altura do rig, e nao numeros absolutos: o
# pacote tem modelos de tamanhos diferentes e o parasita tem de caber em todos.

func _monta_parasita() -> void:
	if _sk == null:
		return
	var h := _poser.altura_total if _poser != null else 1.75

	# --- a flor da cabeca. Pendurada no PESCOCO e nao na cabeca, de proposito:
	# quando a cabeca e' arrancada, a flor continua ali, saindo do toco. E
	# exatamente a imagem que o inimigo existe pra produzir.
	_flor = _no_osso("Neck", "flor")
	var n_petalas := int(_dados["petalas"])
	var nome_petala := String(_dados["coroa"])
	for i in n_petalas:
		var pivo := Node3D.new()
		pivo.position = Vector3(0, h * 0.075, 0)
		pivo.rotation.y = TAU * float(i) / float(n_petalas)
		_flor.add_child(pivo)
		var mi := _peca(pivo, nome_petala, Vector3.ZERO,
			Vector3(h * 0.13, h * 0.24, h * 0.13))
		mi.position.y = h * 0.02
		pivo.scale = Vector3.ZERO
		_petalas.append(pivo)

	for lado in [-1.0, 1.0]:
		var pivo := Node3D.new()
		pivo.position = Vector3(lado * h * 0.026, h * 0.085, h * 0.012)
		_flor.add_child(pivo)
		_peca(pivo, "mandibula", Vector3.ZERO, Vector3(h * 0.16, h * 0.16, h * 0.16))
		pivo.scale = Vector3.ZERO
		_mandibulas.append(pivo)

	_nucleo_base = Vector3(h * 0.13, h * 0.13, h * 0.13)
	_nucleo = _peca(_flor, "nucleo", Vector3(0, h * 0.05, -h * 0.01), _nucleo_base)
	_nucleo.scale = Vector3.ZERO

	_luz_parasita = OmniLight3D.new()
	_luz_parasita.light_color = _dados["cor_luz"]
	_luz_parasita.light_energy = 0.0
	_luz_parasita.omni_range = h * 1.2
	_luz_parasita.position.y = h * 0.06
	_flor.add_child(_luz_parasita)

	# --- a foice, no antebraco direito
	#
	# O `_foice` e' um PIVO Node3D dentro do BoneAttachment3D, e nao o
	# attachment em si. Isso nao e' organizacao: BoneAttachment3D REESCREVE o
	# proprio transform a cada quadro a partir da pose do osso, entao um
	# `scale = Vector3.ZERO` nele dura um quadro e some — na primeira rodada de
	# teste a foice, que so devia aparecer na terceira forma, nascia aberta em
	# tamanho real saindo do ombro de todo mundo. Todo parasita que precise
	# abrir e fechar por escala mora num pivo comum, nunca no attachment.
	var braco_r := _no_osso("RightForeArm", "foice")
	_foice = Node3D.new()
	_foice.name = "pivo_foice"
	braco_r.add_child(_foice)
	var lam := _peca(_foice, "foice", Vector3.ZERO,
		Vector3(h * 0.13, h * 0.62, h * 0.13))
	# A peca pende do pivo (y 0 -> -1) e o antebraco do Mixamo aponta pro
	# proprio -Y na pose de repouso: ela ja sai na direcao certa, so precisa
	# comecar um pouco depois do cotovelo.
	lam.position = Vector3(0, -h * 0.02, 0)
	_foice.scale = Vector3.ZERO

	# --- as costelas que abrem, no alto do tronco
	var peito := _no_osso("Spine2", "costelado")
	for i in 6:
		var f := float(i) / 5.0
		for lado in [-1.0, 1.0]:
			var pivo := Node3D.new()
			pivo.position = Vector3(lado * h * 0.02, h * (0.02 + f * 0.085), 0.0)
			pivo.rotation = Vector3(0.0, lado * (0.35 + f * 0.25), lado * (0.9 - f * 0.25))
			peito.add_child(pivo)
			_peca(pivo, "costela_aberta", Vector3.ZERO,
				Vector3(h * 0.05, h * (0.20 - f * 0.05), h * 0.05))
			pivo.scale = Vector3.ZERO
			_costelas.append(pivo)

	# --- o nucleo GRANDE, no peito. Ele nao mora na cabeca de proposito: na
	# quinta forma o que o jogador tem de ver e' o parasita saindo do TRONCO,
	# com o rosto da pessoa ainda ali em cima. Poe-lo na cabeca tapava o rosto
	# e matava a unica coisa que separa este inimigo de um monstro qualquer.
	_nucleo_peito_base = Vector3(h * 0.20, h * 0.20, h * 0.20)
	_nucleo_peito = _peca(peito, "nucleo", Vector3(0, h * 0.06, -h * 0.05), _nucleo_peito_base)
	_nucleo_peito.scale = Vector3.ZERO

	# E ele e' ALVO: na quinta forma, acertar o nucleo vale o dobro. E o convite
	# pra acabar com aquilo — e a resposta do jogo pra quem levou a briga ate o
	# fim em vez de fugir.
	_caixa_nucleo = Area3D.new()
	_caixa_nucleo.name = "nucleo"
	_caixa_nucleo.collision_layer = 0
	_caixa_nucleo.collision_mask = 0
	_caixa_nucleo.monitorable = false
	_caixa_nucleo.set_script(CaixaMembro)
	_caixa_nucleo.set("membro", "nucleo")
	_caixa_nucleo.set("multiplicador", 2.0)
	_caixa_nucleo.set("dono", self)
	var fn := CollisionShape3D.new()
	var en := SphereShape3D.new()
	en.radius = h * 0.13
	fn.shape = en
	_caixa_nucleo.add_child(fn)
	_caixa_nucleo.position = Vector3(0, h * 0.06, -h * 0.05)
	peito.add_child(_caixa_nucleo)

	# --- as quatro patas do rastejante, saindo das costas
	var costas := _no_osso("Spine1", "patas")
	for i in 4:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var atras := 0.0 if i < 2 else 1.0
		var pivo := Node3D.new()
		pivo.position = Vector3(lado * h * 0.055, h * (0.02 + atras * 0.05), h * 0.05)
		pivo.rotation = Vector3(-0.5 - atras * 0.3, lado * (1.1 + atras * 0.35), 0.0)
		costas.add_child(pivo)
		_peca(pivo, "perna_extra", Vector3.ZERO,
			Vector3(h * 0.05, h * (0.55 + atras * 0.1), h * 0.05))
		pivo.scale = Vector3.ZERO
		_patas.append(pivo)

	_monta_aura(h)

	# --- as raizes: o outro sinal da primeira forma. Pescoco e os dois punhos.
	for dados in [["Neck", 0.10, 0.0], ["LeftForeArm", 0.07, 0.0], ["RightForeArm", 0.07, 0.0]]:
		var pai := _no_osso(String(dados[0]), "raiz_" + String(dados[0]))
		for i in 2:
			var pivo := Node3D.new()
			pivo.position = Vector3(_rng.randf_range(-0.02, 0.02) * h, 0.0, 0.0)
			pivo.rotation = Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, TAU), 0.0)
			pai.add_child(pivo)
			var r := _peca(pivo, "raiz", Vector3.ZERO,
				Vector3(h * 0.05, h * float(dados[1]), h * 0.05))
			r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_raizes.append(pivo)


## A AURA — o que denuncia ele na rua.
##
## Existe por um problema de leitura: o corpo dele e' literalmente um dos
## moradores da cidade, com a mesma roupa e a mesma caminhada, e a raiz do
## pescoco tem 17 cm. Isso e' otimo pro susto da primeira vez e pessimo da
## segunda em diante — o jogador passa a atirar em todo mundo pra descobrir
## quem e' quem, e ai a cidade inteira vira um campo de tiro.
##
## A aura resolve dando um tell HONESTO: ela nao grita, mas quem parar pra
## olhar acha. Sao tres coisas de baixo custo somadas, e nenhuma delas sozinha
## chamaria atencao:
##
##   1. um ANEL no chao, fraco, na cor da linhagem — a marca de que o chao
##      debaixo dele nao esta certo;
##   2. POEIRA subindo devagar em volta do corpo, que numa rua parada e' a
##      unica coisa em movimento ali;
##   3. uma LUZ fraquissima pulsando no ritmo do coracao do parasita — a mesma
##      batida que as veias dele seguem.
##
## Some inteira dentro da arena: la ele ja e' obvio, e a aura so atrapalharia a
## silhueta.
func _monta_aura(h: float) -> void:
	_aura = Node3D.new()
	_aura.name = "aura"
	add_child(_aura)

	# Anel FINO e fraco. A primeira versao usava um toro grosso e aceso, e o
	# resultado nao era aura nenhuma: era o circulo de selecao de um jogo de
	# estrategia debaixo do sujeito. Quem faz o trabalho de verdade e' o
	# contorno na silhueta (`_veste_contorno`); este anel so ancora a coisa no
	# chao e aparece quando o corpo esta escondido atras de outro NPC.
	var anel := TorusMesh.new()
	anel.inner_radius = h * 0.24
	anel.outer_radius = h * 0.27
	anel.rings = 20
	anel.ring_segments = 4
	var cor_aura: Color = _dados["cor_luz"]
	_aura_mat = FX.emissivo(cor_aura, 0.22)
	anel.material = _aura_mat
	_aura_anel = MeshInstance3D.new()
	_aura_anel.mesh = anel
	_aura_anel.position.y = 0.04
	_aura_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura.add_child(_aura_anel)

	_aura_po = NFX.esporo(cor_aura, 16, h * 0.28)
	_aura_po.position.y = h * 0.35
	_aura.add_child(_aura_po)

	_aura_luz = OmniLight3D.new()
	_aura_luz.light_color = cor_aura
	_aura_luz.light_energy = 0.45
	_aura_luz.omni_range = h * 0.9
	_aura_luz.position.y = h * 0.5
	_aura.add_child(_aura_luz)


## Liga/desliga a aura inteira. Chamada na chegada e na saida da arena.
func _liga_aura(ligada: bool) -> void:
	_aura_ligada = ligada
	if is_instance_valid(_aura):
		_aura.visible = ligada
	if is_instance_valid(_aura_po):
		_aura_po.emitting = ligada
	if _aura_contorno != null and not ligada:
		_aura_contorno.set_shader_parameter("forca", 0.0)


## Pulsacao da aura, no mesmo ritmo do coracao do parasita. Chamada do `_anima`
## — e so quando ela esta ligada, pra nao custar nada dentro da arena.
func _anima_aura() -> void:
	if not _aura_ligada or not is_instance_valid(_aura_anel):
		return
	# A mesma batida seca do shader: sobe rapido e cai. Um seno puro leria como
	# luz de video game piscando.
	var batidas: Array[float] = [0.7, 0.95, 1.2, 1.6, 2.3]
	var fase := _t * batidas[clampi(forma, 0, 4)]
	var batida := pow(maxf(0.0, sin(fase * TAU)), 12.0)
	# Conforme as dobras abrem, a aura deixa de ser discreta: na quinta forma
	# nao ha mais disfarce nenhum pra proteger.
	var base := 0.30 + float(forma) * 0.40
	_aura_mat.emission_energy_multiplier = base * (0.35 + batida * 0.9)
	if is_instance_valid(_aura_luz):
		_aura_luz.light_energy = base * (0.35 + batida * 0.8)
	_aura_anel.scale = Vector3.ONE * (1.0 + batida * 0.08)
	if _aura_contorno != null:
		# O contorno e' o que o jogador realmente ve. Ele respira: quase
		# apagado entre as batidas, nitido no pulso.
		_aura_contorno.set_shader_parameter("forca",
			(0.34 + float(forma) * 0.22) * (0.45 + batida * 1.35))


## Uma peca da biblioteca do parasita, com a reserva de sempre: sem o `.glb`
## importado ela vira capsula, e o inimigo fica feio em vez de sumir.
func _peca(pai: Node3D, nome: String, onde: Vector3, escala: Vector3) -> MeshInstance3D:
	var malha := NFX.peca(nome)
	var mi := MeshInstance3D.new()
	if malha != null:
		mi.mesh = malha
		mi.scale = escala
	else:
		var c := CapsuleMesh.new()
		c.radius = maxf(escala.x, 0.01) * 0.5
		c.height = maxf(escala.y, c.radius * 2.05)
		c.radial_segments = 8
		c.rings = 3
		mi.mesh = c
		mi.position.y = -escala.y * 0.5
	mi.position += onde
	mi.material_override = _mat_parasita
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


# ============================================================== COLISOES

func _monta_colisoes() -> void:
	var h := _altura
	var corpo := CollisionShape3D.new()
	corpo.name = "body_shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = maxf(h * 0.94, 1.2)
	corpo.shape = cap
	corpo.position = Vector3(0, h * 0.47, 0)
	add_child(corpo)

	# Toque: fora da arena, encostar nele faz ele agarrar o jogador (mesma regra dos
	# outros inimigos). Na arena e' um golpe corpo a corpo comum.
	var toque := Area3D.new()
	toque.name = "toque"
	toque.collision_layer = 0
	toque.collision_mask = 1
	var tc := CollisionShape3D.new()
	var ts := CapsuleShape3D.new()
	ts.radius = 0.72
	ts.height = maxf(h * 0.95, 1.4)
	tc.shape = ts
	toque.add_child(tc)
	toque.position = Vector3(0, h * 0.47, 0)
	add_child(toque)
	toque.body_entered.connect(_no_toque)


# ============================================================= DESMEMBRAMENTO
#
# Cada peca que pode cair tem uma caixa de acerto propria, presa no osso dela, e
# um contador de dano proprio. O tiro que entra numa dessas caixas tira vida
# NORMALMENTE (nao existe golpe "de raspao" aqui) e, alem disso, enche o
# contador daquela peca. Cheio, a peca cai.
#
# Isso e' de proposito uma escolha do jogador e nao um sorteio: quem quiser
# tirar a foice do bicho tem de gastar cinco tiros no braco direito em vez de
# no peito, e vai chegar no fim da briga com ele mais inteiro de vida. O Shadow
# Rock sorteia os membros dele; este NAO — porque no Rock a mutilacao e'
# espetaculo e aqui ela e' tatica.

func _monta_membros() -> void:
	if _sk == null:
		return
	var m := float(_dados["vida"])   # linhagem mais dura tambem segura as pecas
	_caixa("cabeca", "Head", "HeadTop_End", 0.62, 1.6, int(limite_cabeca * m))
	_caixa("braco_r", "RightArm", "RightForeArm", 0.24, 0.95, int(limite_braco * m))
	_caixa("braco_l", "LeftArm", "LeftForeArm", 0.24, 0.95, int(limite_braco * m))
	_caixa("mao_r", "RightHand", "RightHandMiddle1", 0.55, 0.85, int(limite_mao * m))
	_caixa("mao_l", "LeftHand", "LeftHandMiddle1", 0.55, 0.85, int(limite_mao * m))
	_caixa("perna_r", "RightLeg", "RightFoot", 0.22, 0.9, int(limite_perna * m))
	_caixa("perna_l", "LeftLeg", "LeftFoot", 0.22, 0.9, int(limite_perna * m))


## Monta a caixa de UM membro, medindo o osso no proprio rig.
##
## Medir em vez de chutar numeros e' o que faz isto funcionar nos 92 modelos do
## pacote: eles tem proporcoes diferentes, e o eixo local de cada osso do Mixamo
## aponta pra um lado que nao da pra adivinhar de fora. O vetor ate o osso FILHO,
## expresso no espaco do osso pai, da ao mesmo tempo o comprimento e a direcao
## da capsula — e com isso a caixa cobre o membro inteiro, em qualquer rig.
func _caixa(nome: String, osso: String, filho: String, grossura: float,
		mult: float, limite: int) -> void:
	var i_pai := _osso(osso)
	if i_pai < 0:
		return
	var base := _sk.get_bone_global_rest(i_pai)
	var i_filho := _osso(filho)
	var local := Vector3(0, 0.12, 0)
	if i_filho >= 0:
		local = base.affine_inverse() * _sk.get_bone_global_rest(i_filho).origin
	var comp := maxf(local.length(), 0.05)

	var att := BoneAttachment3D.new()
	att.name = "osso_" + nome
	att.bone_idx = i_pai
	_sk.add_child(att)

	var area := Area3D.new()
	area.name = "heart" if nome == "cabeca" else ("membro_" + nome)
	area.collision_layer = 8
	area.collision_mask = 0
	area.set_script(CaixaMembro)
	area.set("membro", nome)
	area.set("multiplicador", mult)
	area.set("dono", self)
	att.add_child(area)

	var forma := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(comp * grossura, 0.03)
	cap.height = maxf(comp, cap.radius * 2.05)
	forma.shape = cap
	forma.position = local * 0.5
	# Alinha o Y da capsula com o osso. Sem isto a caixa do braco fica de pe
	# dentro do ombro e so acerta quem atira de cima.
	if local.length() > 0.001:
		var eixo := local.normalized()
		var giro := Vector3.UP.cross(eixo)
		if giro.length() > 0.0001:
			forma.rotate(giro.normalized(), Vector3.UP.angle_to(eixo))
		elif eixo.y < 0.0:
			forma.rotate(Vector3.RIGHT, PI)
	area.add_child(forma)

	_membros[nome] = {
		"osso": osso, "idx": i_pai, "att": att, "area": area,
		"dano": 0, "limite": maxi(limite, 6), "perdido": false,
		"comp": comp, "grossura": maxf(comp * grossura, 0.03),
		"pai": _sk.get_bone_parent(i_pai),
	}


## O tiro entrou numa caixa de membro. Chamado pela `folded_neighbor_limb.gd`.
func dano_no_membro(nome: String, quanto: int) -> void:
	if dead:
		return
	take_damage(quanto)
	if dead:
		return

	var m: Dictionary = _membros.get(nome, {})
	if m.is_empty() or bool(m["perdido"]):
		return

	m["dano"] = int(m["dano"]) + quanto
	_sangra_em(nome, 10, 2.2)
	if int(m["dano"]) >= int(m["limite"]):
		_arranca_membro(nome)


## Arranca a peca. Devolve false se ela ja tinha caido.
func _arranca_membro(nome: String) -> bool:
	var m: Dictionary = _membros.get(nome, {})
	if m.is_empty() or bool(m["perdido"]):
		return false
	m["perdido"] = true

	var idx := int(m["idx"])
	var pos := _ponto_do_osso(idx)
	var comp := float(m["comp"])

	# Esconde a peca ENCOLHENDO o osso: os vertices pesados nele desabam pro
	# ponto da junta e o membro some da malha. E o unico jeito de mutilar uma
	# malha com esqueleto sem cortar geometria em tempo de execucao — e o toco
	# que entra logo abaixo cobre exatamente esse ponto.
	if _sk != null:
		_sk.set_bone_pose_scale(idx, Vector3(0.02, 0.02, 0.02))

	if is_instance_valid(m["area"]):
		(m["area"] as Node).queue_free()
	if is_instance_valid(m["att"]):
		(m["att"] as Node).queue_free()

	_poe_coto(nome, int(m["pai"]), comp)
	_solta_membro(nome, pos, comp, float(m["grossura"]))
	_sangra_em(nome, 40, 4.2)

	if _grito != null:
		_grito.play()
	GlobalUtils.shake_camera(0.35, 0.22)
	_consequencia(nome)
	return true


## O toco que fica no corpo. Sem ele o membro some e a silhueta fica com um
## buraco limpo, que le como falha de malha em vez de mutilacao.
func _poe_coto(nome: String, osso_pai: int, comp: float) -> void:
	if _sk == null or osso_pai < 0 or _cotos.has(nome):
		return
	var att := BoneAttachment3D.new()
	att.name = "coto_" + nome
	att.bone_idx = osso_pai
	_sk.add_child(att)
	# Onde o membro estava: o ponto do osso perdido, em coordenadas do pai.
	var i_perdido := int((_membros[nome] as Dictionary)["idx"])
	var local := _sk.get_bone_global_rest(osso_pai).affine_inverse() \
		* _sk.get_bone_global_rest(i_perdido).origin
	var mi := _peca(att, "coto", local, Vector3.ONE * comp * 0.9)
	mi.scale = Vector3.ZERO
	_cotos[nome] = att
	var t := create_tween()
	t.tween_property(mi, "scale", Vector3.ONE * comp * 0.9, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _solta_membro(nome: String, pos: Vector3, comp: float, grossura: float) -> void:
	var mundo := FX.mundo(self)
	if mundo == null:
		return
	var caido := MembroCaido.new()
	caido.tipo = nome
	caido.comprimento = maxf(comp, 0.12)
	caido.grossura = maxf(grossura, 0.04)
	caido.cor_pele = _tom_de_pele()
	caido.cor_roupa = _tom_de_roupa()
	caido.cor_veia = _cor_veia
	caido.linhagem = linhagem
	var fora := (pos - (global_position + Vector3(0, _altura * 0.5, 0)))
	if fora.length() < 0.1:
		fora = -global_transform.basis.z
	caido.impulso = fora.normalized() * _rng.randf_range(1.4, 2.8) \
		+ Vector3.UP * _rng.randf_range(2.0, 3.4)
	mundo.add_child(caido)
	caido.global_position = pos


## O que a perda de cada peca muda na briga. E aqui que o desmembramento deixa
## de ser enfeite.
func _consequencia(nome: String) -> void:
	match nome:
		"cabeca":
			# O parasita perde o disfarce e assume o corpo na hora. Ele fica
			# CEGO: continua atacando, so que no lugar onde o jogador estava um
			# segundo atras. Mais facil de enganar, muito mais dificil de ler.
			_cego = true
			_esconde_flor()
			if forma < Forma.DESDOBRADO:
				_aplica_forma(Forma.DESDOBRADO, false)
			_mostra_nucleo_grande()
		"braco_r":
			# A mao e a foice iam presas nele.
			_leva_junto("mao_r")
			if is_instance_valid(_foice):
				_foice.visible = false
			if _act == Act.CEIFA:
				_aborta_acao()
		"braco_l":
			_leva_junto("mao_l")
		"perna_l", "perna_r":
			pass   # a velocidade sai de `_velocidade_atual()`, que le isto
		_:
			pass


## Peca que cai junto com outra (a mao vai com o braco). Passa pelo `has`
## porque nem todo rig do pacote tem todos os ossos: se o `_caixa` daquela peca
## nao encontrou o osso, ela simplesmente nao existe no dicionario, e indexar
## direto estouraria em tempo de execucao.
func _leva_junto(nome: String) -> void:
	if not _membros.has(nome):
		return
	var m: Dictionary = _membros[nome]
	if bool(m["perdido"]):
		return
	m["perdido"] = true
	if _sk != null:
		_sk.set_bone_pose_scale(int(m["idx"]), Vector3(0.02, 0.02, 0.02))
	if is_instance_valid(m["area"]):
		(m["area"] as Node).queue_free()
	if is_instance_valid(m["att"]):
		(m["att"] as Node).queue_free()


func _perdeu(nome: String) -> bool:
	var m: Dictionary = _membros.get(nome, {})
	return not m.is_empty() and bool(m["perdido"])


func _ponto_do_osso(idx: int) -> Vector3:
	if _sk == null or idx < 0:
		return global_position + Vector3(0, _altura * 0.5, 0)
	return _sk.global_transform * _sk.get_bone_global_pose(idx).origin


func _sangra_em(nome: String, quantos: int, forca: float) -> void:
	var m: Dictionary = _membros.get(nome, {})
	var pos := global_position + Vector3(0, _altura * 0.6, 0)
	if not m.is_empty():
		pos = _ponto_do_osso(int(m["idx"]))
	var mundo := FX.mundo(self)
	if mundo == null:
		return
	# Sangue humano com um resto da cor da linhagem: ele ainda e' gente por
	# dentro, so que nao so.
	var p := NFX.respingo(Color(0.42, 0.03, 0.05).lerp(_cor_veia, 0.28), quantos, forca)
	mundo.add_child(p)
	p.global_position = pos
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_callback(p.queue_free)


## Tons plausiveis pro membro que cai. Saem do INDICE do modelo, e nao de um
## sorteio na hora: assim o mesmo vizinho perde sempre o mesmo braco de sempre,
## e dois deles lado a lado nao ficam com a mesma cor por acaso.
func _tom_de_pele() -> Color:
	var paleta: Array[Color] = [Color(0.80, 0.63, 0.50), Color(0.66, 0.48, 0.36),
		Color(0.46, 0.31, 0.22), Color(0.88, 0.74, 0.63), Color(0.33, 0.21, 0.15)]
	return paleta[absi(int(get_instance_id())) % paleta.size()]


func _tom_de_roupa() -> Color:
	var paleta: Array[Color] = [Color(0.16, 0.18, 0.22), Color(0.28, 0.22, 0.18),
		Color(0.12, 0.20, 0.17), Color(0.34, 0.31, 0.27), Color(0.20, 0.13, 0.15)]
	return paleta[absi(int(get_instance_id() / 7)) % paleta.size()]


# ================================================================ AS FORMAS

## Quantas formas a vida atual ja autoriza. Ele nunca pula duas de uma vez,
## mesmo levando um golpe enorme: cada dobra tem de ABRIR em cena, senao a
## melhor coisa do inimigo acontece fora da tela.
func _avalia_forma() -> void:
	if dead or forma >= Forma.DESDOBRADO:
		return
	var frac := float(current_health) / float(maxi(max_health, 1))
	var alvo := 0
	for i in LIMIARES.size():
		if frac <= float(LIMIARES[i]):
			alvo = i
	if alvo > forma:
		_muda_forma(forma + 1)


## A transicao. Ele PARA pra se abrir — e isso e' meio segundo de graca pro
## jogador, de proposito: a recompensa por ter acertado bastante e' poder ver o
## que vem agora antes de ele voltar a se mexer.
func _muda_forma(n: int) -> void:
	if dead or n <= forma:
		return
	_aborta_acao()
	_act = Act.MUDANDO
	_pose_forca = 1.0
	if _grito != null:
		_grito.play()
	FX.som_no_mundo(self, global_position + Vector3(0, _altura * 0.8, 0),
		NFX.SOM_CARNE, -2.0, 0.55)
	GlobalUtils.shake_camera(0.45, 0.25)
	_aplica_forma(n, false)
	_solta_depois_da_mudanca()


func _solta_depois_da_mudanca() -> void:
	if not is_inside_tree() or get_tree() == null:
		_act = Act.NENHUMA
		return
	await get_tree().create_timer(0.85, false).timeout
	if dead:
		return
	if _act == Act.MUDANDO:
		_act = Act.NENHUMA
		_respiro = 0.6


## Abre tudo o que a forma `n` tem direito. `instantaneo` e' o caminho do
## `_ready` (o inimigo que ja nasce adiantado) e da cabeca arrancada.
func _aplica_forma(n: int, instantaneo: bool) -> void:
	forma = n
	var t := 0.0 if instantaneo else 0.55

	# a raiz no pescoco existe desde sempre — e' o unico sinal da primeira forma
	for pivo in _raizes:
		if is_instance_valid(pivo):
			pivo.scale = Vector3.ONE

	if n >= Forma.ABERTURA:
		_abre_flor(t)
	if n >= Forma.CEIFADOR:
		_abre_foice(t)
	if n >= Forma.RASTEJANTE:
		_abre_costelado(t)
	if n >= Forma.DESDOBRADO:
		_mostra_nucleo_grande()

	# O corpo vai se curvando pra frente conforme o parasita toma conta: em pe
	# na primeira, corcunda na quarta, quase de quatro na quinta.
	var curvas: Array[float] = [0.0, 0.05, 0.14, 0.52, 0.78]
	_curva = curvas[clampi(n, 0, 4)]

	if _luz_parasita != null:
		var energia := _energia_da_forma(n)
		if instantaneo:
			_luz_parasita.light_energy = energia
		else:
			create_tween().tween_property(_luz_parasita, "light_energy", energia, t)

	# O coracao bate mais rapido a cada dobra. Da pra VER o panico dele nas
	# veias antes de olhar a barra de vida.
	if _mat_parasita is ShaderMaterial:
		var batidas: Array[float] = [0.7, 0.95, 1.2, 1.6, 2.3]
		(_mat_parasita as ShaderMaterial).set_shader_parameter(
			"bpm", batidas[clampi(n, 0, 4)])


## Estouro das veias: `flare` do shader indo de um valor a outro.
##
## O material do parasita e' COMPARTILHADO entre todos os vizinhos da mesma
## linhagem (ver `neighbor_fx.material_parasita`), entao este pulso acende as
## veias de todos eles ao mesmo tempo. Isso e' de proposito: quando um grita, o
## bairro inteiro responde.
func _pulsa_veias(de: float, para: float, tempo: float) -> void:
	var sh := _mat_parasita as ShaderMaterial
	if sh == null:
		return
	var t := create_tween()
	t.tween_method(_escreve_flare, de, para, tempo)


func _escreve_flare(v: float) -> void:
	var sh := _mat_parasita as ShaderMaterial
	if sh != null:
		sh.set_shader_parameter("flare", v)


## Forca da luz que o parasita solta em cada forma. Tabela unica porque dois
## lugares precisam dela: a transicao e a volta do clarao do coro.
func _energia_da_forma(n: int = -1) -> float:
	var tabela: Array[float] = [0.25, 1.1, 1.5, 2.2, 3.4]
	return tabela[clampi(n if n >= 0 else forma, 0, 4)]


func _abre_flor(t: float) -> void:
	# A cabeca RACHA: as petalas saem de dentro dela e se deitam pra tras, e as
	# duas metades da mandibula caem pros lados. A cara continua ali, partida ao
	# meio — e por isso que ele ainda le como "alguem".
	for i in _petalas.size():
		var pivo: Node3D = _petalas[i]
		if not is_instance_valid(pivo):
			continue
		var aberto := 0.85 + _rng.randf_range(-0.12, 0.12)
		if t <= 0.0:
			pivo.scale = Vector3.ONE
			pivo.rotation.x = aberto
			continue
		var tw := create_tween().set_parallel(true)
		tw.tween_interval(float(i) * 0.05)
		tw.chain().tween_property(pivo, "scale", Vector3.ONE, t * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(pivo, "rotation:x", aberto, t).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	for i in _mandibulas.size():
		var pivo: Node3D = _mandibulas[i]
		if not is_instance_valid(pivo):
			continue
		var lado := -1.0 if i == 0 else 1.0
		if t <= 0.0:
			pivo.scale = Vector3.ONE
			pivo.rotation = Vector3(-0.5, 0.0, lado * 0.8)
			continue
		var tw := create_tween().set_parallel(true)
		tw.tween_property(pivo, "scale", Vector3.ONE, t * 0.4)
		tw.tween_property(pivo, "rotation", Vector3(-0.5, 0.0, lado * 0.8), t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if is_instance_valid(_nucleo):
		var alvo := _nucleo_base * 0.55
		if t <= 0.0:
			_nucleo.scale = alvo
		else:
			create_tween().tween_property(_nucleo, "scale", alvo, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _abre_foice(t: float) -> void:
	if not is_instance_valid(_foice) or _perdeu("braco_r"):
		return
	_foice.visible = true
	# A mao daquele lado e' ABSORVIDA pela lamina: some da malha e deixa de ser
	# alvo. E o preco que ele paga pela foice, e e' o que explica a peca.
	_leva_junto("mao_r")
	if t <= 0.0:
		_foice.scale = Vector3.ONE
		return
	var tw := create_tween()
	tw.tween_property(_foice, "scale", Vector3.ONE, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _abre_costelado(t: float) -> void:
	for i in _costelas.size():
		var pivo: Node3D = _costelas[i]
		if not is_instance_valid(pivo):
			continue
		if t <= 0.0:
			pivo.scale = Vector3.ONE
			continue
		var tw := create_tween()
		tw.tween_interval(float(i) * 0.03)
		tw.tween_property(pivo, "scale", Vector3.ONE, t * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _patas.size():
		var pivo: Node3D = _patas[i]
		if not is_instance_valid(pivo):
			continue
		if t <= 0.0:
			pivo.scale = Vector3.ONE
			continue
		var tw := create_tween()
		tw.tween_interval(0.12 + float(i) * 0.06)
		tw.tween_property(pivo, "scale", Vector3.ONE, t * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mostra_nucleo_grande() -> void:
	# Na quinta forma o parasita sai de vez: o nucleo do PEITO se abre entre as
	# costelas, e o da cabeca cresce um pouco junto. O corpo humano continua
	# inteiro em volta, so que agora ele e' a casca de outra coisa.
	if is_instance_valid(_nucleo_peito):
		var tp := create_tween()
		tp.tween_property(_nucleo_peito, "scale", _nucleo_peito_base, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_caixa_nucleo):
		_caixa_nucleo.monitorable = true
		_caixa_nucleo.set_collision_layer_value(4, true)
	if is_instance_valid(_nucleo):
		var tw := create_tween()
		tw.tween_property(_nucleo, "scale", _nucleo_base * 0.85, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _luz_parasita != null:
		create_tween().tween_property(_luz_parasita, "light_energy", 3.8, 0.6)


## A cabeca caiu: a flor foi junto? Nao — ela sai do PESCOCO. O que some sao as
## mandibulas, que eram osso da cara.
func _esconde_flor() -> void:
	for pivo in _mandibulas:
		if is_instance_valid(pivo):
			pivo.visible = false


# ================================================================== AUDIO

func _monta_audio() -> void:
	_passos = _som("res://assets/sounds/enemies/zombies/zombie_steps.mp3", -14.0, 1.0)
	_resmungo = _som("res://assets/sounds/enemies/growl_1.mp3", -12.0, 1.25)
	_grito = _som(NFX.SOM_GRITO, -4.0, _rng.randf_range(0.85, 1.15))
	_dor = _som(NFX.SOM_DOR, -7.0, _rng.randf_range(0.9, 1.2))
	_morte = _som("res://assets/sounds/enemies/growl_2.mp3", -2.0, 0.9)
	_tombo = _som("res://assets/sounds/enemies/the_cobalt_husker/drop_dead.mp3", -3.0, 1.0)

	var t := Timer.new()
	t.wait_time = _rng.randf_range(6.0, 12.0)
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		t.wait_time = _rng.randf_range(6.0, 13.0)
		if dead or _resmungo == null or _resmungo.playing:
			return
		# Na primeira forma ele ainda faz som de gente: um resmungo baixinho,
		# agudo, quase um pigarro. A partir da segunda o mesmo som desce de tom
		# e fica alto — e o bicho que esta resmungando agora.
		_resmungo.volume_db = -14.0 + float(forma) * 3.0
		_resmungo.pitch_scale = 1.3 - float(forma) * 0.16
		_resmungo.play())


func _som(caminho: String, db: float, pitch: float) -> AudioStreamPlayer3D:
	var stream := load(caminho) as AudioStream
	if stream == null:
		return null
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.volume_db = db
	a.pitch_scale = pitch
	a.unit_size = 14.0
	a.max_distance = 55.0
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


# =================================================================== LOOP

func _physics_process(delta: float) -> void:
	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	_t += delta
	_gesto += delta

	# Onde ele esta, decidido uma vez por quadro e ANTES de qualquer outra
	# coisa — inclusive antes do retorno do cutscene_mode, senao a chegada na
	# arena so seria notada depois da cinematica de entrada da batalha, e antes
	# da checagem de queda, que depende de saber onde ele esta pra escolher
	# entre resgatar e sumir.
	var estava := _em_arena
	_em_arena = _na_arena()
	if _em_arena and not _entrou_na_arena:
		_entrou_na_arena = true
		_chegou_na_arena()
	elif estava and not _em_arena:
		# Voltou pra cidade (a batalha acabou e ele sobreviveu, ou foi
		# reaproveitado): volta a ser um vizinho na calcada.
		_entrou_na_arena = false
		_liga_aura(true)

	if not dead and _spawn_grace <= 0.0 and _caiu_do_mundo():
		# Dentro da arena, cair NAO pode acabar a briga: some o ultimo inimigo
		# vivo e a batalha se encerra sozinha, com o jogador sem entender o que
		# houve. Ele se dobra de volta — o que, sendo ele, nem parece remendo.
		if _em_arena:
			_resgata_da_queda()
		else:
			# Na cidade e' outra historia: caiu num buraco a cinquenta metros
			# do jogador, que nunca o viu. Sai de cena sem barra de chefe e sem
			# iron rusks — pra ele, aquele vizinho nunca existiu.
			remover_em_silencio()
			return

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

	# A memoria do cego: onde o jogador estava um segundo atras. Ele mira AQUI
	# depois de perder a cabeca, e e' isso que da pro jogador uma janela de
	# engano que nenhum outro inimigo do jogo oferece.
	_relogio_memoria -= delta
	if _relogio_memoria <= 0.0:
		_relogio_memoria = 0.9
		if is_instance_valid(player):
			_ponto_velho = player.global_position

	if cutscene_mode:
		velocity.x = move_toward(velocity.x, 0.0, chase_speed)
		velocity.z = move_toward(velocity.z, 0.0, chase_speed)
		if is_instance_valid(player):
			_encara(player.global_position, delta)
		_anima(delta)
		move_and_slide()
		return

	if _dobrando:
		velocity.x = 0.0
		velocity.z = 0.0
		_anima(delta)
		move_and_slide()
		return

	_respiro = maxf(0.0, _respiro - delta)
	_sem_mao_ate = maxf(0.0, _sem_mao_ate - delta)
	if _sem_mao_ate <= 0.0:
		_regenera_mao()
	for k in _esperas.keys():
		_esperas[k] = float(_esperas[k]) - delta
	if _em_arena:
		_espera_dobra -= delta

	if _act != Act.NENHUMA:
		_anda_acao(delta)
	else:
		_pensa(delta)

	_anima(delta)
	move_and_slide()


## Caiu pra fora do mundo? Na cidade o criterio e' o absoluto de sempre. Na
## arena e' RELATIVO ao jogador: a plataforma flutua, e um inimigo cinco metros
## abaixo dos pes de quem esta brigando ja saiu do chao, mesmo que o Y dele
## ainda seja positivo.
func _caiu_do_mundo() -> bool:
	if global_position.y < -10.0:
		return true
	if _em_arena and is_instance_valid(player):
		# 2,5 m abaixo dos pes de quem esta brigando ja e' queda, e nao
		# desnivel. O valor antigo (5 m) so disparava quase um segundo depois,
		# tempo suficiente pra ele sumir de quadro antes de ser resgatado.
		return global_position.y < player.global_position.y - 2.5
	return false


## Traz ele de volta pro chao da arena. Nao e' um `set_position` seco: passa
## pela mesma dobra dos poderes, entao o jogador ve a fresta abrir e ele sair
## dela. O acidente vira encenacao.
func _resgata_da_queda() -> void:
	velocity = Vector3.ZERO
	var destino := _ponto_de_dobra()
	if destino == SEM_CHAO and is_instance_valid(player):
		# Ultimo recurso: o chao debaixo do proprio jogador. Se nem ele tem
		# chao, a arena inteira sumiu e nao ha nada a salvar.
		var sob_o_jogador := _no_chao(player.global_position)
		if sob_o_jogador != SEM_CHAO:
			destino = sob_o_jogador + (global_position - player.global_position).normalized() * 3.0
			destino.y = sob_o_jogador.y
	if destino == SEM_CHAO:
		return
	_aborta_acao()
	var mundo := FX.mundo(self)
	global_position = destino
	_endireita_rig()
	_fresta(mundo, destino, false)
	_spawn_grace = 0.5
	_agenda_dobra()


## Decide o que fazer quando nao esta no meio de um poder.
func _pensa(delta: float) -> void:
	var d := INF
	if is_instance_valid(player):
		d = global_position.distance_to(player.global_position)

	# Na arena ele nunca "vaga": o jogador esta ali, a briga e' agora.
	var arena := _em_arena
	var briga := arena or d <= distance_to_aproach
	state = State.PERSEGUINDO if briga else State.VAGANDO

	if not briga or not is_instance_valid(player):
		_vaga(delta)
		return

	_encara(_ponto_de_mira(), delta)

	# A dobra de reposicionamento: de tempos em tempos ele simplesmente NAO
	# esta mais onde estava. Vem antes dos poderes porque o reposicionamento e'
	# o que faz a briga na arena ser dele e nao do jogador.
	if arena and _espera_dobra <= 0.0 and _respiro <= 0.0:
		var destino := _ponto_de_dobra()
		if destino != SEM_CHAO:
			_agenda_dobra()
			_dobra_para(destino)
			return
		# Nao ha lugar bom agora (o jogador esta na beirada da arena, ou numa
		# quina): tenta de novo daqui a pouco em vez de se jogar no vazio.
		_espera_dobra = 1.5

	if _respiro <= 0.0:
		var escolha := _escolhe_poder(d)
		if escolha != Act.NENHUMA:
			_comeca(escolha)
			return

	# Sem poder pronto: procura a distancia que ele quer. Na primeira forma ele
	# nao tem poder nenhum — entao ele vai PRA CIMA, que e' tudo o que uma
	# pessoa com as maos vazias pode fazer.
	var alvo_d := _distancia_desejada()
	var dir := (_ponto_de_mira() - global_position)
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var v := _velocidade_atual()
	if d > alvo_d + 1.0:
		_caminha(dir, v, delta)
	elif d < alvo_d - 2.0:
		_caminha(-dir, v * 0.55, delta)
	else:
		# Rodeia em vez de ficar plantado — e sempre pro mesmo lado por um bom
		# tempo. A versao antiga trocava de direcao com `int(_t*0.3) % 2`, o que
		# invertia o sentido num quadro so: com o passo lateral no lugar do
		# antigo deslizar, essa inversao seca virava um tranco no quadril. Agora
		# ele fica um tempo indo pra um lado, PARA, e so entao vai pro outro.
		_troca_rodeio -= delta
		if _troca_rodeio <= 0.0:
			_troca_rodeio = _rng.randf_range(2.5, 5.5)
			_lado_rodeio = -_lado_rodeio if _rng.randf() < 0.7 else _lado_rodeio
			_pausa_rodeio = _rng.randf_range(0.35, 0.8)
		if _pausa_rodeio > 0.0:
			_pausa_rodeio -= delta
			velocity.x = move_toward(velocity.x, 0.0, v * 2.0)
			velocity.z = move_toward(velocity.z, 0.0, v * 2.0)
			return
		var lado := Vector3(-dir.z, 0.0, dir.x) * _lado_rodeio
		_caminha(lado, v * 0.42, delta)


## A que distancia ele quer ficar.
##
## Na CIDADE ele vem pra cima, sempre: um vizinho que anda na sua direcao e nao
## para e' o encontro inteiro dele na rua, e encostar leva pra arena.
##
## Na ARENA, nunca. La ele briga de longe, mesmo sem poder pronto — porque a
## briga dele e' feita de dobra, onda e bote, e nenhuma dessas tres funciona
## colado no jogador. A versao antiga desta funcao tinha uma segunda linha que
## devolvia 0.7 pra primeira forma mesmo dentro da arena, e era ela que fazia
## ele continuar correndo atras do jogador la dentro.
func _distancia_desejada() -> float:
	if _em_arena:
		return 7.0
	return 0.7


## Velocidade de agora. E aqui que perder uma perna aparece: sem ela ele se
## arrasta, e a briga inteira muda de ritmo.
func _velocidade_atual() -> float:
	var v := chase_speed * float(_dados["velocidade"])
	if forma >= Forma.RASTEJANTE:
		v *= 1.22 + 0.12 * float(forma - Forma.RASTEJANTE)
	if _perdeu("perna_l") or _perdeu("perna_r"):
		v *= 0.45
	if _perdeu("perna_l") and _perdeu("perna_r"):
		v *= 0.55
	return v


## Onde ele acha que o jogador esta. Depois de perder a cabeca, isto para de
## ser a verdade.
func _ponto_de_mira() -> Vector3:
	if not is_instance_valid(player):
		return global_position - global_transform.basis.z * 5.0
	return _ponto_velho if _cego else player.global_position


# ---------------------------------------------------------- pela cidade

## Passeio de morador: escolhe um ponto de rua e vai ate la, sem pressa. E o
## mesmo vaga-pela-rua do `city_npc.gd`, e tem de ser: quem olhar de longe nao
## pode ter como saber.
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
	_troca_destino = _rng.randf_range(8.0, 18.0)
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


## Saiu do asfalto (empurrao, esquina cortada): volta pra rua mais proxima em
## vez de subir na calcada. Mesma regra das sombras e dos moradores.
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


## O navmesh da stage_1 nao cobre a cidade onde se joga (fica a ~200 m dali).
## Quando ele nao alcanca este ponto, o caminho e' a linha reta — igual aos
## outros inimigos.
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
	var seguro := _direcao_segura(dir)
	velocity.x = lerp(velocity.x, seguro.x * vel, delta * 5.5)
	velocity.z = lerp(velocity.z, seguro.z * vel, delta * 5.5)


## A CERCA DA ARENA.
##
## A arena e' uma plataforma com beirada e vazio em volta. Ele mantem distancia
## do jogador rodeando-o, e rodear um jogador que esta perto da borda leva a
## andar PRA FORA dela — foi assim que ele caiu no vazio num teste, e nao pela
## dobra (essa ja escolhe destino com chao conferido). Cair encerrava a briga
## sozinha, com o jogador sem entender o que houve.
##
## Aqui ele sonda o chao logo a frente antes de ir. Sem chao, tenta se desviar
## em leque — 40, 75 e 110 graus pros dois lados — e fica DESLIZANDO pela
## beirada em vez de despencar. Se nenhuma direcao servir, ele simplesmente
## nao anda: melhor um bicho parado na quina que um bicho no fundo do poco.
##
## Fora da arena isto nem roda: a cidade tem chao em todo lugar que interessa,
## e um raycast por quadro por vizinho, com varios deles na rua, seria pagar
## caro por nada.
func _direcao_segura(dir: Vector3) -> Vector3:
	if not _em_arena or dir.length_squared() < 0.0001:
		return dir
	if _tem_chao_a_frente(dir):
		return dir
	for graus in [40.0, -40.0, 75.0, -75.0, 110.0, -110.0]:
		var desvio := dir.rotated(Vector3.UP, deg_to_rad(float(graus)))
		if _tem_chao_a_frente(desvio):
			return desvio
	return Vector3.ZERO


func _tem_chao_a_frente(dir: Vector3) -> bool:
	var a_frente := global_position + dir.normalized() * SONDA_FRENTE
	var p := _no_chao(a_frente)
	if p == SEM_CHAO:
		return false
	# Degrau ou buraco fundo tambem contam como "nao da pra ir".
	return absf(p.y - global_position.y) <= 1.6


func _encara(alvo: Vector3, delta: float) -> void:
	var plano := Vector3(alvo.x, global_position.y, alvo.z)
	if global_position.distance_to(plano) < 0.3:
		return
	# O rig do Mixamo olha pro +Z (ver o cabecalho do humanoid_poser.gd), entao
	# o angulo e' `atan2(dx, dz)` e NAO o `atan2(-dx, -dz)` do resto do Godot.
	# Errar isto poe o vizinho andando de costas.
	var desejado := atan2(alvo.x - global_position.x, alvo.z - global_position.z)
	rotation.y = lerp_angle(rotation.y, desejado, clampf(delta * turn_speed, 0.0, 1.0))


# ====================================================== ROTEIRO DOS PODERES
#
# Cada poder e' uma sequencia de fases, e cada fase tem um tempo declarado nas
# constantes abaixo. Os mesmos numeros sao lidos pela corrotina (que dispara os
# efeitos) e pela funcao que poe o corpo na pose — e e' isso que mantem o gesto
# colado no efeito sem nenhum AnimationPlayer no meio.

const CORO_INSPIRA := 1.25
const CORO_GRITO := 0.45
const CORO_VOLTA := 0.80

const CEIFA_ARMA := 0.55
const CEIFA_SOME := 0.18
const CEIFA_ESPERA := 0.90
const CEIFA_INVESTE := 0.40
const CEIFA_VOLTA := 0.70

const SEM_AGARRA := 0.60
const SEM_ARRANCA := 0.25
const SEM_VOLTA := 0.80

const CASCA_RACHA := 0.55
const CASCA_ABRE := 0.30
const CASCA_VOLTA := 0.60


## Qual poder esta pronto agora.
##
## Fora da arena ele so tem UM: o coro. Na rua o encontro tem de ser uma ameaca
## que se anuncia, nao uma briga de chefe no meio do transito — e quem decide
## quando a briga comeca e' o jogador, encostando nele ou mirando com o amuleto.
## Mesma regra dos outros inimigos do jogo.
func _escolhe_poder(d: float) -> int:
	var arena := _em_arena

	if not arena:
		if forma >= Forma.ABERTURA and float(_esperas[Act.CORO]) <= 0.0 and d < 26.0:
			return Act.CORO
		return Act.NENHUMA

	# A defesa tem prioridade: se a hora dela chegou, e' ela que sai.
	if forma >= Forma.ABERTURA and not escudo_ativo and float(_esperas[Act.CASCA]) <= 0.0:
		return Act.CASCA

	var prontos: Array[int] = []
	var pesos: Array[float] = []

	if forma >= Forma.ABERTURA and float(_esperas[Act.CORO]) <= 0.0 and d < 26.0:
		prontos.append(Act.CORO)
		# Sem cabeca a flor grita mais solta: nao ha mais mandibula segurando a
		# abertura. Perder a cabeca dele nao apaga este poder — deixa ele PIOR.
		pesos.append(2.3 if _perdeu("cabeca") else 1.6)
	if forma >= Forma.CEIFADOR and not _perdeu("braco_r") \
		and float(_esperas[Act.CEIFA]) <= 0.0 and d < 24.0:
		prontos.append(Act.CEIFA)
		pesos.append(1.5)
	if forma >= Forma.RASTEJANTE and _tem_mao_esquerda() \
		and float(_esperas[Act.SEMEADURA]) <= 0.0 and d > 3.0 and d < 22.0:
		prontos.append(Act.SEMEADURA)
		pesos.append(1.2)

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


func _tem_mao_esquerda() -> bool:
	return not _perdeu("mao_l") and not _perdeu("braco_l") and _sem_mao_ate <= 0.0


func _comeca(a: int) -> void:
	if _act != Act.NENHUMA or dead:
		return
	_act = a
	state = State.ACAO
	_set_fase(0)

	match a:
		Act.CORO:
			_esperas[Act.CORO] = _rng.randf_range(espera_coro_min, espera_coro_max)
			_roteiro_coro()
		Act.CEIFA:
			_esperas[Act.CEIFA] = _rng.randf_range(espera_ceifa_min, espera_ceifa_max)
			_roteiro_ceifa()
		Act.SEMEADURA:
			_esperas[Act.SEMEADURA] = _rng.randf_range(espera_semeadura_min, espera_semeadura_max)
			_roteiro_semeadura()
		Act.CASCA:
			_esperas[Act.CASCA] = _rng.randf_range(espera_casca_min, espera_casca_max)
			_roteiro_casca()


func _set_fase(f: int) -> void:
	_fase = f
	_pose_forca = 0.0


## Espera de verdade (em segundos de jogo). Devolve false se no meio dela o
## inimigo morreu, saiu da arvore, foi congelado ou entrou em cutscene — e nesse
## caso quem chamou tem de abortar o poder na hora.
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


func _aborta_acao() -> void:
	_act = Act.NENHUMA
	_set_fase(0)
	_respiro = 0.4


## Ponto do chao onde o jogador esta AGORA — ou onde ele ESTAVA, se este aqui
## ja perdeu a cabeca.
func _ponto_alvo() -> Vector3:
	return _ponto_de_mira()


# ---------------------------------------------------------- 1. O CORO

func _roteiro_coro() -> void:
	_set_fase(0)
	_inspira()
	if not await _espera(CORO_INSPIRA):
		_aborta_acao()
		return

	_set_fase(1)
	_solta_o_coro()
	if not await _espera(CORO_GRITO):
		_aborta_acao()
		return

	_set_fase(2)
	if not await _espera(CORO_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


## A inspiracao: um anel que ENCOLHE pra dentro dele. E o aviso do poder, e a
## unica coisa que da pro jogador tempo de sair do alcance.
func _inspira() -> void:
	var mundo := FX.mundo(self)
	if mundo == null:
		return
	var t := TorusMesh.new()
	t.inner_radius = 0.92
	t.outer_radius = 1.0
	t.rings = 28
	t.ring_segments = 5
	t.material = FX.emissivo(_cor_veia, 3.4)
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mundo.add_child(mi)
	mi.global_position = global_position + Vector3(0, 0.08, 0)
	mi.scale = Vector3(9.0, 1.0, 9.0)

	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(0.4, 1.0, 0.4), CORO_INSPIRA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)

	if _luz_parasita != null:
		create_tween().tween_property(_luz_parasita, "light_energy", 7.0, CORO_INSPIRA)
	_pulsa_veias(0.0, 0.85, CORO_INSPIRA)


func _solta_o_coro() -> void:
	var mundo := FX.mundo(self)
	if mundo == null:
		return
	var onda := Coro.new()
	onda.dano = int(round(float(dano_coro) * float(_dados["dano"])))
	onda.cor = _cor_veia
	onda.alvo = player
	# Aberto ate o osso, sem mandibula segurando: o grito sai mais longe.
	if _perdeu("cabeca"):
		onda.raio_max = 21.0
		onda.velocidade = 15.0
	mundo.add_child(onda)
	onda.global_position = global_position

	if _grito != null:
		_grito.play()
	if _luz_parasita != null:
		var t := create_tween()
		t.tween_property(_luz_parasita, "light_energy", 14.0, 0.06)
		t.tween_property(_luz_parasita, "light_energy",
			_energia_da_forma(), 0.9)
	_pulsa_veias(1.0, 0.0, 0.9)

	# O engasgo de tempo. So na arena, e so uma vez por grito: e' a assinatura
	# do poder e o que o faz parecer um evento e nao um ataque a mais.
	if _em_arena:
		GlobalUtils.ativar_camera_lenta(0.45, 0.30, true)


# ------------------------------------------------------ 2. A CEIFA CEGA

func _roteiro_ceifa() -> void:
	_set_fase(0)
	if _dor != null:
		_dor.play()
	if not await _espera(CEIFA_ARMA):
		_aborta_acao()
		return

	# Tres pontos em volta do jogador. Ele vai pra UM deles; nos outros dois
	# fica a imagem. Qual e' qual e' sorteio — nem o proprio codigo sabe antes.
	var pontos := _tres_pontos_em_volta()
	var verdadeiro := _rng.randi_range(0, pontos.size() - 1)
	var vultos: Array[Node3D] = []

	_set_fase(1)
	await _dobra_para(pontos[verdadeiro])
	if not _pode_continuar():
		_aborta_acao()
		return

	var mundo := FX.mundo(self)
	if mundo != null:
		for i in pontos.size():
			if i == verdadeiro:
				continue
			var v := Vulto.new()
			v.cor = _cor_veia
			v.altura = _altura
			v.vida = CEIFA_ESPERA + CEIFA_INVESTE + 0.25
			mundo.add_child(v)
			v.global_position = pontos[i]
			if is_instance_valid(player):
				v.look_at(Vector3(player.global_position.x, v.global_position.y,
					player.global_position.z), Vector3.UP)
			vultos.append(v)

	_set_fase(2)
	if not await _espera(CEIFA_ESPERA):
		_desfaz_vultos(vultos)
		_aborta_acao()
		return

	_set_fase(3)
	if not await _espera(CEIFA_INVESTE):
		_desfaz_vultos(vultos)
		_aborta_acao()
		return
	_corte_da_foice()
	_desfaz_vultos(vultos)

	_set_fase(4)
	if not await _espera(CEIFA_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


## Tres pontos a distancia de bote em volta do jogador, um deles nas costas
## dele. Nas costas de proposito: o jogador tem de girar a camera pra conferir
## os tres, e girar a camera custa tempo.
func _tres_pontos_em_volta() -> Array[Vector3]:
	var centro := _ponto_alvo()
	var base := _rng.randf() * TAU
	if is_instance_valid(player):
		# `basis.z` do jogador aponta pra TRAS dele (convencao do Godot), entao
		# este angulo poe o primeiro vulto exatamente atras da nuca.
		var atras: Vector3 = player.global_transform.basis.z
		base = atan2(atras.x, atras.z)
	var saida: Array[Vector3] = []
	for i in 3:
		var a := base + TAU * float(i) / 3.0 + _rng.randf_range(-0.25, 0.25)
		var p := SEM_CHAO
		# Vai encostando no jogador ate achar chao: os tres pontos do bote tem
		# de existir de verdade, senao um vulto nasce boiando ou o verdadeiro
		# cai da arena no meio do ataque.
		for r in [3.4, 2.8, 2.2, 1.6, 1.1]:
			var cand := _no_chao(centro + Vector3(cos(a) * float(r), 0.0, sin(a) * float(r)))
			if cand != SEM_CHAO and _piso_firme(cand, 0.7):
				p = cand
				break
		saida.append(p if p != SEM_CHAO else centro)
	return saida


func _desfaz_vultos(vultos: Array[Node3D]) -> void:
	for v in vultos:
		if is_instance_valid(v) and v.has_method("desfaz"):
			v.desfaz()


## O corte. Cone na frente dele, na altura do peito: quem estava do lado certo
## nao leva nada, quem tentou sair pelo lado do verdadeiro leva inteiro.
func _corte_da_foice() -> void:
	if _grito != null:
		_grito.play()
	GlobalUtils.shake_camera(0.3, 0.22)
	FX.som_no_mundo(self, global_position + Vector3(0, _altura * 0.6, 0),
		NFX.SOM_CARNE, -4.0, 1.35)

	if not is_instance_valid(player):
		return
	var para := player.global_position - global_position
	para.y = 0.0
	if para.length() > 3.4:
		return
	# `basis.z` e' a FRENTE deste corpo (o rig do Mixamo olha pro +Z).
	var frente: Vector3 = global_transform.basis.z
	frente.y = 0.0
	if frente.normalized().dot(para.normalized()) < 0.25:
		return   # passou de raspao pelas costas: nao pega

	if player.has_method("take_damage"):
		player.take_damage(int(round(float(dano_ceifa) * float(_dados["dano"]))))
	GlobalUtils.shake_camera(0.5, 0.35)
	GlobalUtils.vibrate_controller(null, 0.9, 0.9, 0.35)


# ------------------------------------------------------ 3. A SEMEADURA

func _roteiro_semeadura() -> void:
	_set_fase(0)
	if _dor != null:
		_dor.play()
	if not await _espera(SEM_AGARRA):
		_aborta_acao()
		return

	_set_fase(1)
	_arremessa_a_mao()
	if not await _espera(SEM_ARRANCA):
		_aborta_acao()
		return

	_set_fase(2)
	if not await _espera(SEM_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


## Ele arranca a propria mao esquerda e joga. A mao volta a crescer sozinha
## depois de `tempo_regenera_mao` — e enquanto nao cresce, o poder nao existe.
func _arremessa_a_mao() -> void:
	var m: Dictionary = _membros.get("mao_l", {})
	var de := global_position + Vector3(0, _altura * 0.6, 0)
	if not m.is_empty():
		de = _ponto_do_osso(int(m["idx"]))
		if _sk != null:
			_sk.set_bone_pose_scale(int(m["idx"]), Vector3(0.02, 0.02, 0.02))
		if is_instance_valid(m["area"]):
			(m["area"] as Node3D).visible = false
			(m["area"] as Area3D).monitorable = false
			(m["area"] as CollisionObject3D).set_collision_layer_value(4, false)
	_sem_mao_ate = tempo_regenera_mao

	_sangra_em("mao_l", 26, 3.0)
	if _grito != null:
		_grito.play()

	var mundo := FX.mundo(self)
	if mundo == null:
		return
	var s := Semente.new()
	s.cor = _cor
	s.cor_veia = _cor_veia
	s.linhagem = linhagem
	s.alvo = player
	s.origem = de
	s.destino = _ponto_alvo()
	s.dano_por_tique = int(round(float(dano_semeadura) * float(_dados["dano"])))
	mundo.add_child(s)
	_broto = s


## A mao cresce de novo. E a assinatura do bicho: nada nele e' permanente,
## menos o que o JOGADOR arranca (esse nao volta).
func _regenera_mao() -> void:
	var m: Dictionary = _membros.get("mao_l", {})
	if m.is_empty() or bool(m["perdido"]):
		return
	if _sk == null:
		return
	var idx := int(m["idx"])
	if _sk.get_bone_pose_scale(idx).x > 0.5:
		return
	_sk.set_bone_pose_scale(idx, Vector3.ONE)
	if is_instance_valid(m["area"]):
		(m["area"] as Node3D).visible = true
		(m["area"] as Area3D).monitorable = true
		(m["area"] as CollisionObject3D).set_collision_layer_value(4, true)
	_sangra_em("mao_l", 12, 1.6)


# --------------------------------------------------------- DEFESA: A CASCA

func _roteiro_casca() -> void:
	_set_fase(0)
	if _dor != null:
		_dor.play()
	if not await _espera(CASCA_RACHA):
		_aborta_acao()
		return

	_set_fase(1)
	_levanta_casca()
	if not await _espera(CASCA_ABRE):
		_aborta_acao()
		return

	_set_fase(2)
	if not await _espera(CASCA_VOLTA):
		_aborta_acao()
		return
	_fim_acao()


func _levanta_casca() -> void:
	if escudo_ativo or dead:
		return
	var c := Casca.new()
	c.duration = duracao_casca
	# Raio COLADO no corpo. Na primeira rodada era 0.72 da altura (1,3 m) e a
	# casca virava uma gaiola de dois metros e meio de diametro em volta de uma
	# pessoa — parecia cenario, nao pele arrancada de alguem.
	c.raio = maxf(_altura * 0.42, 0.62)
	c.cor = _cor_veia
	c.linhagem = linhagem
	c.alvo = player
	# A linhagem cinzenta poe mais placa: a casca dela aguenta mais tiro.
	c.placas = 13 if linhagem == NFX.Linhagem.CINZENTO else 10
	add_child(c)
	c.position = Vector3(0, _altura * 0.55, 0)
	_casca = c
	escudo_ativo = true
	c.expired.connect(_on_casca_expirada)


func _on_casca_expirada() -> void:
	escudo_ativo = false
	_casca = null


func _derruba_casca() -> void:
	escudo_ativo = false
	if is_instance_valid(_casca) and _casca.has_method("encerrar"):
		_casca.encerrar()
	_casca = null
	if is_instance_valid(_broto) and _broto.has_method("encerrar"):
		_broto.encerrar()
	_broto = null


# ==================================================================== A DOBRA
#
# So dentro da arena. Na cidade ele e' um morador andando na calcada, e
# sumir-e-aparecer na rua estragaria o unico truque que ele tem: parecer gente.

func _agenda_dobra() -> void:
	var base := _rng.randf_range(espera_dobra_min, espera_dobra_max)
	# A linhagem cinzenta se dobra quase o dobro; a escarlate, menos.
	base /= maxf(float(_dados["dobra"]), 0.1)
	# Na quinta forma o parasita ja nao respeita mais lugar nenhum.
	if forma >= Forma.DESDOBRADO:
		base *= 0.55
	_espera_dobra = maxf(base, 2.5)


## Onde reaparecer: em volta do jogador, de preferencia FORA do campo de visao
## dele. Ele nao aparece na sua frente — aparece onde voce nao estava olhando.
## Onde reaparecer: em volta do jogador, de preferencia FORA do campo de visao
## dele. Ele nao aparece na sua frente — aparece onde voce nao estava olhando.
##
## Devolve SEM_CHAO quando nao existe lugar bom agora. Nesse caso ele
## simplesmente NAO se dobra neste ciclo, que e' muito melhor que se dobrar pra
## fora da arena: a plataforma tem beirada, e cair dela encerrava a batalha.
##
## O anel de busca encolhe a cada tentativa (`aperta`): se longe do jogador so
## ha vazio, ele acaba procurando colado nele, onde e' garantido haver chao —
## o proprio jogador esta em pe ali.
func _ponto_de_dobra() -> Vector3:
	if not is_instance_valid(player):
		return SEM_CHAO
	var atras: Vector3 = player.global_transform.basis.z
	var base := atan2(atras.x, atras.z)
	for i in 14:
		var aperta := 1.0 - float(i) / 14.0
		var a := base + _rng.randf_range(-1.5, 1.5)
		var r := _rng.randf_range(dobra_perto, lerpf(dobra_perto + 0.5, dobra_longe, aperta))
		var cand := player.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var p := _no_chao(cand)
		if p == SEM_CHAO:
			continue
		# Alto demais (subiu numa quina da arena) ou baixo demais (achou o
		# fundo de alguma coisa): nos dois casos nao serve.
		if absf(p.y - player.global_position.y) > 3.0:
			continue
		if not _piso_firme(p):
			continue
		return p
	return SEM_CHAO


## Onde esta o chao debaixo de `p` — ou SEM_CHAO, se nao houver nenhum.
##
## A versao antiga desta funcao INVENTAVA um ponto quando o raio nao acertava
## nada (devolvia a altura atual do corpo). Como e' ela que escolhe onde o
## teletransporte termina, e como a arena e' uma plataforma com beirada, isso
## significava que de vez em quando ele se dobrava pra fora do mundo, caia no
## vazio e a batalha acabava sozinha. Agora ela admite que nao achou, e quem
## chamou trata.
func _no_chao(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return SEM_CHAO
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 14.0, 2)
	var hit := espaco.intersect_ray(q)
	if hit.is_empty():
		return SEM_CHAO
	return (hit["position"] as Vector3) + Vector3.UP * 0.05


## O chao aqui aguenta um corpo inteiro, ou este ponto esta na beirada?
##
## Um raio so no centro nao basta: acertando o ultimo palmo da plataforma ele
## reaparece com meio corpo pra fora e escorrega. Quatro sondas em volta, a um
## corpo de distancia, resolvem — e de quebra rejeitam degrau alto, que faria o
## reaparecimento parecer um salto.
func _piso_firme(p: Vector3, raio: float = 1.1) -> bool:
	if p == SEM_CHAO:
		return false
	for i in 4:
		var a := TAU * float(i) / 4.0
		var volta := _no_chao(p + Vector3(cos(a) * raio, 0.0, sin(a) * raio))
		if volta == SEM_CHAO or absf(volta.y - p.y) > 1.2:
			return false
	return true


## O corpo se FECHA num plano vertical, vira uma linha e some; do outro lado a
## linha se rasga e ele sai dela. Os dois lados sao a mesma animacao ao
## contrario, e e' por isso que a ida e a volta parecem a mesma coisa.
func _dobra_para(destino: Vector3) -> void:
	if _dobrando or dead or not _em_arena:
		return
	# Ultima conferencia antes de sumir daqui: se o destino nao presta, e'
	# melhor nao se dobrar. Quem chama ja filtra, mas esta funcao tambem e'
	# usada pela ceifa cega, e um destino ruim la levaria o bote inteiro pra
	# fora do mapa.
	if destino == SEM_CHAO:
		return
	_dobrando = true
	velocity = Vector3.ZERO
	var mundo := FX.mundo(self)
	_fresta(mundo, global_position, true)

	if _rig != null:
		var t := create_tween()
		t.tween_property(_rig, "scale",
			Vector3(_escala_base * 0.02, _escala_base * 1.06, _escala_base * 0.02),
			0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	if not await _espera(0.17):
		_dobrando = false
		_endireita_rig()
		return

	if _rig != null:
		_rig.visible = false
	global_position = destino
	velocity = Vector3.ZERO
	if is_instance_valid(player):
		var olhar := Vector3(player.global_position.x, destino.y, player.global_position.z)
		if destino.distance_to(olhar) > 0.3:
			rotation.y = atan2(olhar.x - destino.x, olhar.z - destino.z)

	# O respiro entre sumir e aparecer. Curto, mas existe: sem ele o
	# teletransporte vira um corte de video e o jogador nao registra o
	# deslocamento.
	if not await _espera(0.14):
		_dobrando = false
		_endireita_rig()
		return

	if _rig != null:
		_rig.visible = true
	_fresta(mundo, destino, false)
	_endireita_rig(0.20)

	if not await _espera(0.22):
		_dobrando = false
		return
	_dobrando = false


func _endireita_rig(t: float = 0.0) -> void:
	if _rig == null:
		return
	_rig.visible = true
	var cheio := Vector3.ONE * _escala_base
	if t <= 0.0:
		_rig.scale = cheio
		return
	_rig.scale = Vector3(_escala_base * 0.02, _escala_base * 1.06, _escala_base * 0.02)
	create_tween().tween_property(_rig, "scale", cheio, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fresta(mundo: Node, onde: Vector3, saindo: bool) -> void:
	if mundo == null:
		return
	var d := Dobra.new()
	d.saindo = saindo
	d.cor = _cor_veia
	d.altura = _altura
	mundo.add_child(d)
	d.global_position = onde


# ------------------------------------------- movimento durante os poderes

func _anda_acao(delta: float) -> void:
	_pose_forca = minf(1.0, _pose_forca + delta * 6.0)

	# A investida da ceifa e' o UNICO momento em que ele corre de verdade.
	if _act == Act.CEIFA and _fase == 3:
		var dir := (_ponto_alvo() - global_position)
		dir.y = 0.0
		if dir.length() > 0.8:
			_caminha(dir.normalized(), rush_speed, delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, rush_speed)
			velocity.z = move_toward(velocity.z, 0.0, rush_speed)
		_encara(_ponto_alvo(), delta)
		return

	velocity.x = move_toward(velocity.x, 0.0, chase_speed * 2.0)
	velocity.z = move_toward(velocity.z, 0.0, chase_speed * 2.0)
	# No coro ele encara pra frente mas o poder e' em 360: nao precisa mirar.
	if _act != Act.MUDANDO and is_instance_valid(player):
		_encara(_ponto_alvo(), delta * 0.6)


# ================================================================ ANIMACAO
#
# Nao ha clipe de animacao nenhum: o corpo e' posto osso a osso pelo
# `HumanoidPoser`, o mesmo que anima os moradores da cidade. A caminhada sai de
# la inteira; as poses dos poderes e a curvatura das formas entram DEPOIS,
# sobrescrevendo junta por junta — `junta()` escreve, nao soma, entao quem
# escreve por ultimo manda.

func _anima(delta: float) -> void:
	_anima_aura()
	if _poser == null:
		return

	_planar = Vector2(velocity.x, velocity.z).length()
	var cadencia := 4.0 + _planar * 1.5
	if _planar > 0.15 and not dead:
		var antes := _passada
		_passada += delta * cadencia
		# cada meio ciclo do balanco e' um pe batendo no chao
		if int(floor(_passada / PI)) != int(floor(antes / PI)) and is_on_floor():
			_toca_passo()

	_abertura = lerpf(_abertura, _poser.abertura_para(_planar, cadencia),
		clampf(delta * 6.0, 0.0, 1.0))

	# LOD: a maquina de estados e o som continuam a 60 Hz; o que se espaca e'
	# so a ESCRITA no esqueleto, que e' a parte cara. Mesma conta do city_npc.
	_pose_espera -= 1
	if _pose_espera > 0:
		return
	_pose_espera = _passo_da_pose()

	if dead:
		_pose_morte(delta)
		return

	var blend := clampf(_planar / maxf(walk_speed, 0.01), 0.0, 1.0)
	_poser.pose_locomocao(_passada, _gesto, blend, _abertura)
	_guarda_juntas_frontais(blend)
	_pose_lateral(blend)
	_pose_da_forma()

	if _act != Act.NENHUMA:
		_pose_acao()


## PASSO LATERAL — abrir e fechar as pernas, como gente anda de lado.
##
## Por que isto existe: dentro da arena ele rodeia o jogador sem deixar de
## encara-lo, entao o corpo anda pra UM LADO enquanto o rosto aponta pra
## frente. O `pose_locomocao` do HumanoidPoser so sabe passada frontal — ele
## abre as pernas no plano de quem caminha pra frente —, e o resultado era um
## boneco dando passadas pra frente enquanto DESLIZAVA de lado, patinando.
##
## Aqui as pernas passam a se abrir e fechar no plano FRONTAL, que e' o que uma
## pessoa faz de verdade: a perna do lado pra onde se vai abre e pisa, a outra
## vem atras e junta. Passo-junta-passo.
##
## A pose antiga nao e' jogada fora: as duas sao MISTURADAS pelo quanto do
## movimento e' lateral. Andando na diagonal sai um meio-termo, que e'
## exatamente o que uma pessoa faz.
##
## Sinais, conferidos contra a tabela do humanoid_poser.gd (corpo olha pro +Z,
## perna esquerda em +X): girar o quadril em torno do Z por um angulo POSITIVO
## leva a perna pro +X. Entao z positivo ABRE a esquerda e FECHA (cruza) a
## direita — e as duas pernas indo pro +X ao mesmo tempo, em contrafase, e' o
## passo lateral pra esquerda.
func _pose_lateral(blend: float) -> void:
	if _planar <= 0.15:
		return
	# Quanto do movimento e' de lado, no referencial do corpo. `basis.x` e' a
	# esquerda dele (o rig olha pro +Z, ver o cabecalho do humanoid_poser).
	var esquerda: Vector3 = global_transform.basis.x
	var andando := Vector3(velocity.x, 0.0, velocity.z)
	var lateral := andando.dot(Vector3(esquerda.x, 0.0, esquerda.z).normalized())
	var w := clampf(absf(lateral) / maxf(_planar, 0.01), 0.0, 1.0)
	# Abaixo de um terco lateral nao vale a pena: a passada frontal ja da conta
	# e misturar pouco so faz o quadril tremer.
	w = smoothstep(0.35, 0.85, w) * blend
	if w <= 0.01:
		return

	var lado := signf(lateral)
	var s := sin(_passada)
	var abre := clampf(_abertura * 1.35, 0.12, 0.72)

	# As duas pernas caminham pro mesmo lado, em contrafase: quando uma esta
	# aberta no maximo a outra esta recolhida, e no quadro seguinte trocam.
	var z_l := lado * abre * (0.5 + 0.5 * s)
	var z_r := lado * abre * (0.5 - 0.5 * s)
	# O joelho dobra na perna que esta NO AR — a que esta aumentando o proprio
	# afastamento —, senao ela raspa no chao na volta.
	var no_ar_l := maxf(0.0, cos(_passada))
	var no_ar_r := maxf(0.0, -cos(_passada))
	var flex_l := 0.06 + no_ar_l * 0.42
	var flex_r := 0.06 + no_ar_r * 0.42

	if debug_passo_lateral:
		_relogio_debug -= get_physics_process_delta_time()
		if _relogio_debug <= 0.0:
			_relogio_debug = 0.4
			print("[lateral] w=%.2f lado=%+.0f abre=%.2f  z_l=%+.2f z_r=%+.2f  planar=%.2f"
				% [w, lado, abre, z_l, z_r, _planar])

	_mistura("hip_l", Vector3(0.0, 0.0, z_l), w)
	_mistura("hip_r", Vector3(0.0, 0.0, z_r), w)
	_mistura("knee_l", Vector3(flex_l, 0.0, 0.0), w)
	_mistura("knee_r", Vector3(flex_r, 0.0, 0.0), w)
	# Tornozelo desfazendo a abertura do quadril: a sola fica plana no chao em
	# vez de apoiar so na borda externa do pe.
	_mistura("foot_l", Vector3(-flex_l * 0.6, 0.0, -z_l * 0.75), w)
	_mistura("foot_r", Vector3(-flex_r * 0.6, 0.0, -z_r * 0.75), w)
	# Contrapeso: o tronco se joga um pouco CONTRA o lado pra onde ele vai, e a
	# cabeca fica onde estava. E o que tira a impressao de trilho.
	_mistura("spine", Vector3(0.0, 0.0, -lado * 0.10 - lado * 0.05 * s), w)
	_mistura("hips", Vector3(0.0, 0.0, lado * 0.06 * s), w)


## Refaz a conta da passada FRONTAL que o `pose_locomocao` acabou de escrever,
## pra o passo lateral ter com o que se misturar.
##
## Refazer a conta em vez de ler de volta e' o unico caminho: o poser escreve
## direto no esqueleto, em espaco de OSSO, e desfazer aquela conjugacao pra
## voltar ao espaco do corpo seria bem mais caro e mais fragil do que repetir
## quatro linhas. As constantes vem do proprio poser, entao mexer nele mexe
## aqui junto.
func _guarda_juntas_frontais(blend: float) -> void:
	var s := sin(_passada)
	var vies := HumanoidPoser.VIES_PRA_FRENTE
	var perna_l := -(s + vies * s * s) * _abertura
	var perna_r := (s - vies * s * s) * _abertura
	var parado := 1.0 - blend
	var flex_l := 0.05 + 0.03 * parado + maxf(0.0, -sin(_passada - 0.6)) * HumanoidPoser.JOELHO_BALANCO * blend
	var flex_r := 0.05 + 0.03 * parado + maxf(0.0, -sin(_passada - 0.6 + PI)) * HumanoidPoser.JOELHO_BALANCO * blend
	_juntas_frontais["hip_l"] = Vector3(perna_l, 0.0, 0.0)
	_juntas_frontais["hip_r"] = Vector3(perna_r, 0.0, 0.0)
	_juntas_frontais["knee_l"] = Vector3(flex_l, 0.0, 0.0)
	_juntas_frontais["knee_r"] = Vector3(flex_r, 0.0, 0.0)
	_juntas_frontais["foot_l"] = Vector3(-(perna_l + flex_l) * 0.70, 0.0, 0.0)
	_juntas_frontais["foot_r"] = Vector3(-(perna_r + flex_r) * 0.70, 0.0, 0.0)
	_juntas_frontais["spine"] = Vector3(
		0.03 * blend + 0.02 * parado, -s * 0.11 * blend, s * 0.035 * blend)
	_juntas_frontais["hips"] = Vector3(0.0, s * 0.09 * blend, 0.0)


## Escreve numa junta misturando com o que ja estava la.
##
## `junta()` do poser SOBRESCREVE, entao nao da pra somar duas poses chamando
## as duas: a segunda apaga a primeira. Como o poser nao devolve o que
## escreveu, esta funcao guarda o valor frontal que a locomocao usou e
## interpola. Os valores guardados sao os que o `pose_locomocao` acabou de
## produzir neste mesmo quadro.
func _mistura(chave: String, alvo: Vector3, w: float) -> void:
	var antes: Vector3 = _juntas_frontais.get(chave, Vector3.ZERO)
	_poser.junta(chave, antes.lerp(alvo, w))


## A curvatura que cada forma imprime no corpo. E ela que faz a silhueta mudar
## de longe, antes de dar pra ver qualquer peca de parasita.
func _pose_da_forma() -> void:
	if _curva <= 0.001:
		return
	# tronco pra frente (x positivo inclina pra FRENTE, ver o poser), pescoco
	# desfazendo um pouco pra cabeca nao ficar olhando pro chao
	_poser.junta("spine", Vector3(_curva * 0.85, 0.0, sin(_gesto * 1.6) * 0.05 * _curva))
	_poser.junta("neck", Vector3(-_curva * 0.55, 0.0, 0.0))
	# os bracos pendem: quem carrega o corpo agora sao as patas das costas
	var pend := _curva * 0.5
	if not _perdeu("braco_l"):
		_poser.junta("shoulder_l", Vector3(-pend, 0.0, -0.12))
	if not _perdeu("braco_r"):
		_poser.junta("shoulder_r", Vector3(-pend, 0.0, 0.12))
	# joelho mais dobrado: ele anda agachado
	_poser.junta("knee_l", Vector3(0.18 + _curva * 0.45, 0.0, 0.0))
	_poser.junta("knee_r", Vector3(0.18 + _curva * 0.45, 0.0, 0.0))
	_poser.desloca_quadril(-_curva * 0.18 * _poser.comprimento_perna)


## A perna que caiu nao pode continuar dando passo: ela e' um toco. Chamada
## pelas poses que mexem em perna.
func _trava_perna_perdida() -> void:
	if _perdeu("perna_l"):
		_poser.junta("knee_l", Vector3(1.25, 0.0, 0.0))
	if _perdeu("perna_r"):
		_poser.junta("knee_r", Vector3(1.25, 0.0, 0.0))


func _pose_acao() -> void:
	var w := _pose_forca
	match _act:
		Act.CORO:
			_pose_coro(w)
		Act.CEIFA:
			_pose_ceifa(w)
		Act.SEMEADURA:
			_pose_semeadura(w)
		Act.CASCA:
			_pose_casca(w)
		Act.MUDANDO:
			_pose_mudanca(w)
	_trava_perna_perdida()


## O coro: ele se ABRE. Peito pra fora, bracos escancarados pra tras, cabeca
## jogada pro ceu — a pose de quem esta sendo aberto, nao de quem esta gritando.
func _pose_coro(w: float) -> void:
	var escancara := w if _fase == 0 else (1.0 if _fase == 1 else 1.0 - w)
	_poser.junta("spine", Vector3(-0.42 * escancara + _curva * 0.5, 0.0, 0.0))
	_poser.junta("neck", Vector3(-0.80 * escancara, 0.0, 0.0))
	if not _perdeu("braco_l"):
		_poser.junta("shoulder_l", Vector3(0.55 * escancara, 0.0, -1.15 * escancara))
		_poser.junta("elbow_l", Vector3(-0.30 * escancara, 0.0, 0.0))
	if not _perdeu("braco_r"):
		_poser.junta("shoulder_r", Vector3(0.55 * escancara, 0.0, 1.15 * escancara))
		_poser.junta("elbow_r", Vector3(-0.30 * escancara, 0.0, 0.0))
	_poser.junta("knee_l", Vector3(0.22, 0.0, 0.0))
	_poser.junta("knee_r", Vector3(0.22, 0.0, 0.0))

	# as petalas deitam de vez na inspiracao e batem pra frente no grito
	var deita := 1.35 if _fase == 0 else (0.15 if _fase == 1 else 0.85)
	for pivo in _petalas:
		if is_instance_valid(pivo):
			pivo.rotation.x = lerpf(pivo.rotation.x, deita, 0.25)


## A ceifa: o braco da foice vai LA PRA CIMA e fica. A pose tem de ser a mesma
## nos tres vultos, senao o truque acaba.
func _pose_ceifa(w: float) -> void:
	var arma := 1.0
	if _fase == 0:
		arma = w
	elif _fase == 3:
		arma = 1.0 - w   # desce no corte
	elif _fase == 4:
		arma = maxf(0.0, 1.0 - w)

	_poser.junta("spine", Vector3(0.10 + _curva * 0.6, -0.25 * arma, 0.0))
	if not _perdeu("braco_r"):
		# x negativo leva o braco pra FRENTE; passando de -PI/2 ele sobe acima
		# do ombro, que e' onde a foice tem de estar pra o bote valer.
		_poser.junta("shoulder_r", Vector3(-2.35 * arma + 0.35, 0.0, 0.55 * arma))
		_poser.junta("elbow_r", Vector3(-0.55 - 0.35 * arma, 0.0, 0.0))
	if not _perdeu("braco_l"):
		_poser.junta("shoulder_l", Vector3(-0.55 * arma, 0.0, -0.35))
		_poser.junta("elbow_l", Vector3(-0.85 * arma - 0.14, 0.0, 0.0))
	if _fase == 3:
		# investida: corpo inteiro pra frente
		_poser.junta("spine", Vector3(0.55 + _curva * 0.4, 0.0, 0.0))
		_poser.junta("neck", Vector3(-0.30, 0.0, 0.0))


## A semeadura: a mao direita agarra o proprio antebraco esquerdo e ARRANCA.
func _pose_semeadura(w: float) -> void:
	var puxa := w if _fase == 0 else 1.0
	_poser.junta("spine", Vector3(0.28 * puxa + _curva * 0.6, 0.0, 0.0))
	_poser.junta("neck", Vector3(0.35 * puxa, 0.0, 0.0))   # olhando pro proprio braco
	if not _perdeu("braco_l"):
		_poser.junta("shoulder_l", Vector3(-1.15 * puxa, 0.0, -0.45 * puxa))
		_poser.junta("elbow_l", Vector3(-1.30 * puxa - 0.14, 0.0, 0.0))
	if not _perdeu("braco_r"):
		if _fase >= 1:
			# o arranco: o braco direito sai voando pro lado com a mao nele
			_poser.junta("shoulder_r", Vector3(-0.30, 0.0, 1.55 * w))
			_poser.junta("elbow_r", Vector3(-0.35, 0.0, 0.0))
		else:
			_poser.junta("shoulder_r", Vector3(-1.25 * puxa, 0.0, 0.55 * puxa))
			_poser.junta("elbow_r", Vector3(-1.45 * puxa - 0.14, 0.0, 0.0))


## A casca: ele se encolhe e depois se ABRE de uma vez, e e' nesse gesto que a
## pele sai do corpo.
func _pose_casca(w: float) -> void:
	if _fase == 0:
		_poser.junta("spine", Vector3(0.75 * w + _curva * 0.3, 0.0, 0.0))
		_poser.junta("neck", Vector3(0.55 * w, 0.0, 0.0))
		if not _perdeu("braco_l"):
			_poser.junta("shoulder_l", Vector3(-1.5 * w, 0.0, -0.65 * w))
			_poser.junta("elbow_l", Vector3(-2.0 * w - 0.14, 0.0, 0.0))
		if not _perdeu("braco_r"):
			_poser.junta("shoulder_r", Vector3(-1.5 * w, 0.0, 0.65 * w))
			_poser.junta("elbow_r", Vector3(-2.0 * w - 0.14, 0.0, 0.0))
		_poser.junta("knee_l", Vector3(0.75 * w, 0.0, 0.0))
		_poser.junta("knee_r", Vector3(0.75 * w, 0.0, 0.0))
		_poser.desloca_quadril(-0.22 * w * _poser.comprimento_perna)
	else:
		var abre := w if _fase == 1 else 1.0 - w
		_poser.junta("spine", Vector3(-0.35 * abre + _curva * 0.5, 0.0, 0.0))
		_poser.junta("neck", Vector3(-0.55 * abre, 0.0, 0.0))
		if not _perdeu("braco_l"):
			_poser.junta("shoulder_l", Vector3(0.35 * abre, 0.0, -1.35 * abre))
		if not _perdeu("braco_r"):
			_poser.junta("shoulder_r", Vector3(0.35 * abre, 0.0, 1.35 * abre))


## A troca de forma: o corpo se ARQUEIA pra tras, como se algo estivesse
## empurrando de dentro. E o gesto mais importante do inimigo inteiro — e o
## unico momento em que o jogador ve a pessoa deixar de ser pessoa.
func _pose_mudanca(w: float) -> void:
	var arco := sin(clampf(w, 0.0, 1.0) * PI) * 0.85 + w * 0.15
	_poser.junta("spine", Vector3(-0.95 * arco, 0.0, sin(_t * 22.0) * 0.06))
	_poser.junta("neck", Vector3(-1.05 * arco, sin(_t * 14.0) * 0.12, 0.0))
	if not _perdeu("braco_l"):
		_poser.junta("shoulder_l", Vector3(0.75 * arco, 0.0, -1.35 * arco))
		_poser.junta("elbow_l", Vector3(-0.85 * arco - 0.14, 0.0, 0.0))
	if not _perdeu("braco_r"):
		_poser.junta("shoulder_r", Vector3(0.75 * arco, 0.0, 1.35 * arco))
		_poser.junta("elbow_r", Vector3(-0.85 * arco - 0.14, 0.0, 0.0))
	_poser.junta("knee_l", Vector3(0.45 * arco, 0.0, 0.0))
	_poser.junta("knee_r", Vector3(0.45 * arco, 0.0, 0.0))
	_poser.desloca_quadril(-0.12 * arco * _poser.comprimento_perna)


## Morte. Ele nao "cai": ele AMOLECE. O parasita larga o corpo, e o corpo
## desce como roupa saindo do varal — que e' a ultima coisa que o jogador ve
## dele, e tem de doer um pouco.
func _pose_morte(delta: float) -> void:
	_pose_forca = minf(1.0, _pose_forca + delta * 0.9)
	var w := _pose_forca
	_poser.junta("spine", Vector3(1.15 * w, 0.0, 0.25 * w))
	_poser.junta("neck", Vector3(0.95 * w, 0.35 * w, 0.0))
	_poser.junta("shoulder_l", Vector3(-0.15 * w, 0.0, -0.55 * w))
	_poser.junta("shoulder_r", Vector3(-0.15 * w, 0.0, 0.55 * w))
	_poser.junta("elbow_l", Vector3(-0.35 * w - 0.14, 0.0, 0.0))
	_poser.junta("elbow_r", Vector3(-0.35 * w - 0.14, 0.0, 0.0))
	_poser.junta("hip_l", Vector3(-0.75 * w, 0.0, 0.0))
	_poser.junta("hip_r", Vector3(-0.70 * w, 0.0, 0.0))
	_poser.junta("knee_l", Vector3(1.55 * w, 0.0, 0.0))
	_poser.junta("knee_r", Vector3(1.45 * w, 0.0, 0.0))
	_poser.desloca_quadril(-w * 0.62 * _poser.comprimento_perna)


func _toca_passo() -> void:
	if _passos == null:
		return
	# Na primeira forma e' passo de gente, de sapato. Nas ultimas sao muitas
	# patas ao mesmo tempo: o som desce de tom e fica mais seco.
	_passos.pitch_scale = _rng.randf_range(0.92, 1.08) - float(forma) * 0.09
	_passos.volume_db = -14.0 + float(forma) * 2.0
	_passos.play()


## De quantos em quantos quadros de fisica vale a pena repor a pose. O resto
## por instancia espalha os vizinhos por quadros diferentes, senao varios deles
## na tela recalculariam tudo no mesmo quadro.
func _passo_da_pose() -> int:
	var d := global_position.distance_to(_camera_agora())
	if d <= distancia_pose_cheia:
		return 1
	if d <= distancia_pose_cheia * 2.0:
		return 2 + int(get_instance_id() % 2)
	return 4 + int(get_instance_id() % 3)


func _camera_agora() -> Vector3:
	var quadro := Engine.get_physics_frames()
	if quadro != _cam_quadro:
		_cam_quadro = quadro
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_cam_pos = cam.global_position
	return _cam_pos


# ============================================================ DANO E MORTE

func take_damage(amount) -> void:
	if dead:
		return
	var dano := int(amount)

	# A casca de pele de pe: o golpe chega bem mais fraco, e ARRANCA uma placa.
	if escudo_ativo:
		dano = maxi(1, int(round(float(dano) * (1.0 - reducao_casca))))
		if is_instance_valid(_casca) and _casca.has_method("flash"):
			_casca.flash()

	if _dor != null and not _dor.playing:
		_dor.play()

	current_health = clampi(current_health - dano, 0, max_health)

	if is_instance_valid(player) and player.has_method("add_cogblade_power"):
		player.add_cogblade_power(float(dano), global_position + Vector3(0, _altura * 0.6, 0))

	# Pulsada nas veias a cada golpe: o corpo inteiro pisca na cor da linhagem.
	_pulsa_veias(0.75, 0.0, 0.35)

	_mostra_barra()

	if current_health <= 0:
		die()
		return

	_avalia_forma()

	# Levou um golpe pesado na arena: boa chance de ele simplesmente NAO estar
	# mais ali no proximo instante. Nao dispara a dobra daqui (estamos no meio
	# do dano) — so adianta o relogio, e o `_pensa` do proximo quadro resolve.
	if dano >= 18 and _em_arena and _act == Act.NENHUMA and _rng.randf() < 0.40:
		_espera_dobra = 0.0


func _mostra_barra() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var root := get_tree().root
	var ui = root.get_node_or_null("GlobalEnemyHealthUI")
	if ui == null:
		ui = load("res://scripts/ui/global_enemy_health.gd").new()
		ui.name = "GlobalEnemyHealthUI"
		root.add_child(ui)
	# O nome na barra ACOMPANHA a forma: quem o jogador esta enfrentando muda
	# de verdade no meio da briga, e a barra tem de contar isso.
	ui.show_health(self, _nome_agora(), current_health, max_health)


## Nome de agora: a linhagem mais a forma. Fica, por exemplo,
## "O VIZINHO — LINHAGEM BILIAR" e depois "O CEIFADOR — LINHAGEM BILIAR".
func _nome_agora() -> String:
	var formas: Array[String] = ["NEIGHBOR_FORM_1", "NEIGHBOR_FORM_2", "NEIGHBOR_FORM_3",
		"NEIGHBOR_FORM_4", "NEIGHBOR_FORM_5"]
	var f := tr(formas[clampi(forma, 0, 4)])
	var l := tr(String(_dados["nome"]))
	if _perdeu("cabeca"):
		return "%s — %s" % [tr("NEIGHBOR_HEADLESS"), l]
	return "%s — %s" % [f, l]


func die() -> void:
	if dead:
		return
	dead = true
	_act = Act.NENHUMA
	_pose_forca = 0.0
	_derruba_casca()
	died.emit()
	if _morte != null:
		_morte.play()
	if _grito != null:
		_grito.play()
	SaveManager.add_iron_rusks(iron_rusks_value)

	# O parasita larga o corpo: a flor murcha, a luz apaga, as patas encolhem.
	var t := create_tween().set_parallel(true)
	for pivo in _petalas:
		if is_instance_valid(pivo):
			t.tween_property(pivo, "rotation:x", 2.7, 1.6).set_trans(Tween.TRANS_SINE)
	for pivo in _patas:
		if is_instance_valid(pivo):
			t.tween_property(pivo, "scale", Vector3(0.1, 0.1, 0.1), 1.8)
	if _luz_parasita != null:
		t.tween_property(_luz_parasita, "light_energy", 0.0, 2.2)
	if is_instance_valid(_nucleo):
		t.tween_property(_nucleo, "scale", _nucleo_base * 0.05, 2.0)
	if is_instance_valid(_nucleo_peito):
		t.tween_property(_nucleo_peito, "scale", _nucleo_peito_base * 0.05, 2.0)

	_sangra_em("cabeca", 30, 2.6)

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


## Tira o inimigo do jogo sem nada na tela: sem barra de chefe, sem iron rusks,
## sem morte. E o caminho de quem some longe do jogador (o spawner liberando
## quem ficou pra tras) e de quem cai do mapa.
func remover_em_silencio() -> void:
	dead = true
	_act = Act.NENHUMA
	_derruba_casca()
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


# ========================================================= TOQUE / CIDADE

func _no_toque(corpo: Node3D) -> void:
	if dead or _dobrando or not is_instance_valid(corpo):
		return
	if not (corpo == player or corpo.is_in_group("player")):
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_toque < 0.8:
		return
	_ultimo_toque = agora

	# Fora da arena o toque nao e' uma pancada: ele agarra o jogador e a
	# cinematica cobra o dano. Se isso valeu, acabou aqui.
	if _tenta_agarrao(corpo):
		return

	# Na arena e' corpo a corpo comum. E a unica coisa que a PRIMEIRA forma
	# sabe fazer — um vizinho de maos vazias vindo pra cima.
	if corpo.get("invulnerable") == true:
		return
	if corpo.has_method("take_damage"):
		corpo.take_damage(int(round(float(dano_toque) * float(_dados["dano"]))))
	GlobalUtils.shake_camera(0.2, 0.2)
	if _grito != null and not _grito.playing:
		_grito.play()


## Encostao no Maycow FORA da arena: em vez do dano de sempre, o inimigo agarra
## o jogador, a camera entra em primeira pessoa e a cinematica decide o que
## acontece (morder e soltar, ou levantar e arremessar). O dano sai de la'.
## Quem monta tudo e' o `player_grab.gd`.
##
## DENTRO da arena isto nao vale: la' o encostao continua sendo a pancada de
## sempre. `is_maycow_normal` e' exatamente essa pergunta — a arena e' a unica
## coisa no jogo que liga o Maycow de combate.
##
## true = o toque foi consumido; quem chamou nao aplica mais dano nenhum.
func _tenta_agarrao(corpo: Node3D) -> bool:
	if not permite_agarrao:
		return false
	if not GlobalEvents.is_maycow_normal:
		return false
	if not corpo.has_method("grab_from_touch"):
		return false
	if not is_inside_tree() or get_tree() == null:
		return false
	return corpo.grab_from_touch(self)
