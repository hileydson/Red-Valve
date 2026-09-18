extends CharacterBody3D

@onready var camera = $Camera3D # Certifique-se de que sua câmera se chama Camera3D
@onready var camera_third_person: Camera3D =$SpringArm3D/camera_third_person
@onready var camera_third_person_marker: Marker3D = $SpringArm3D/camera_third_person_marker
@onready var camera_first_person_marker: Marker3D = $camera_first_person_marker

@onready var gun_load: AudioStreamPlayer = $sounds/GunLoad
@onready var load_gun: AudioStreamPlayer = $sounds/LoadGun
@onready var gun_shot: AudioStreamPlayer = $sounds/GunShot
# Os quatro da cacadeira. Ela nao reaproveita os da pistola porque nenhum dos
# quatro momentos dela e' o mesmo: o tiro e' de cano duplo, o "reload" aqui e' o
# estalo da arma DOBRANDO, o "load" e' um cartucho entrando por vez, e o
# "close" e' ela batendo fechada no fim.
@onready var shotgun_shot: AudioStreamPlayer = $sounds/ShotgunShot
@onready var shotgun_break: AudioStreamPlayer = $sounds/ShotgunBreak
@onready var shotgun_load_shell: AudioStreamPlayer = $sounds/ShotgunLoadShell
@onready var shotgun_close: AudioStreamPlayer = $sounds/ShotgunClose
@onready var passos: AudioStreamPlayer3D = $sounds_3d/Passos
var _passo_pe_alternado: bool = false # alterna a cada passo p/ dar sensação de pé esq/dir
@onready var pistola: AnimatedSprite2D = $Camera3D/CanvasLayer/control_weapons/pistola
@onready var faisca: GPUParticles3D = $Camera3D/hand_with_pistol/faisca
@onready var fire: AnimatedSprite3D = $Camera3D/hand_with_pistol/fire
@onready var bullet_light: OmniLight3D = $Camera3D/Camera3D_Bullet_Time/bullet_light
@onready var flash_tela: ColorRect = $Camera3D/CanvasLayer/control_weapons/flash_tela
@onready var ray_cast_3d: RayCast3D = $Camera3D/RayCast3D
@onready var magic_hand: AnimatedSprite2D = $Camera3D/CanvasLayer/control_magic/magic_hand
@onready var hand_magic_3d: Node3D = $Camera3D/hand_with_magic/hand_magic
@onready var hand_magic_tree: AnimationTree = $Camera3D/hand_with_magic/hand_magic/AnimationTree
@onready var magic_hand_particles: GPUParticles3D = $Camera3D/magic_hand_particles
@onready var crescent_cogblade: Node3D = $"Camera3D/Crescent Cogblade"
@onready var blade_in: AudioStreamPlayer3D = $"Camera3D/Crescent Cogblade/blade_in"
@onready var blade_back: AudioStreamPlayer3D = $"Camera3D/Crescent Cogblade/blade_back"
@onready var blade_out: AudioStreamPlayer = $"Camera3D/Crescent Cogblade/BladeOut"
@onready var camera_3d_bullet_time: Camera3D = $Camera3D/Camera3D_Bullet_Time
@onready var control_weapons: Control = $Camera3D/CanvasLayer/control_weapons
@onready var control_magic: Control = $Camera3D/CanvasLayer/control_magic
@onready var bullet: Node3D = $Camera3D/Camera3D_Bullet_Time/bullet
@onready var camera_bullet_time_mark: Marker3D = $Camera3D/camera_bullet_time_mark
@onready var slay_it: AudioStreamPlayer = $sounds/SlayIt
@onready var blade_light: OmniLight3D = $"Camera3D/Crescent Cogblade/blade_light"
@onready var animation_tree: AnimationTree = $maycow_lopes/AnimationTree
@onready var animation_tree_normal: AnimationTree = $maycow_lopes_normal/AnimationTree
@onready var hand_animations: AnimationPlayer = $Camera3D/hand_animations
@onready var point: Label = $Camera3D/point
@onready var lanterna: SpotLight3D = $Camera3D/lanterna
@onready var camera_top_view: Camera3D = $camera_top_view
@onready var hand_with_pistol: Node3D = $Camera3D/hand_with_pistol
@onready var hand_with_magic: Node3D = $Camera3D/hand_with_magic
@onready var smoke_effect: AnimatedSprite2D = $Camera3D/CanvasLayer/smoke_effect
@onready var smoke_effect_back: AnimatedSprite2D = $Camera3D/CanvasLayer/smoke_effect_back
@onready var dash_effect: AudioStreamPlayer = $sounds/DashEffect
@onready var dash_effect_particles: GPUParticles3D = $dash_effect_particles
# @onready var screen_shader: MeshInstance3D = $camera_third_person/screen_shader

var blood_effect = preload("res://scenes/enemies/blood.tscn")
var capsula_scene = preload("res://scenes/effects/capsula.tscn")
var capsula_shotgun_scene = preload("res://scenes/effects/capsula_shotgun.tscn")

# --- PLAYER HEALTH & HUD ---
@export var max_health: int = 100
var current_health: int = 100
var heartbeat_hud: ColorRect
var blood_overlay: ColorRect
var blur_overlay: ColorRect
# Cel shading (filtro estilo Borderlands por cima do render 3D).
# O estado "de verdade" vem do menu de configurações (aba Vídeo); estes exports
# são override rápido pra testar no editor - mudar aqui reflete em tempo real.
@export_group("Cel Shading")
@export_range(0.55, 0.85, 0.01) var cel_shading_intensity: float = 0.65:
	set(value):
		cel_shading_intensity = value
		var overlay = get_node_or_null("CelShadingOverlay")
		if overlay: overlay.set_intensity(value)
@export var cel_shading_enabled: bool = false:
	set(value):
		cel_shading_enabled = value
		var overlay = get_node_or_null("CelShadingOverlay")
		if overlay: overlay.enabled = value

# STAMINA & MP
@export_group("Debug & Testing")
@export var infinite_stamina_test: bool = false
## Vida infinita pra testar ataques de inimigo sem morrer. O golpe continua
## CONECTANDO com todo o retorno de sempre (sangue na tela, tremor, vibracao,
## batimento) — so a vida nao desce. Isso e de proposito: num teste o que
## importa e ver se o ataque acertou, e uma barra parada sem nenhum sinal nao
## diz se o golpe pegou ou passou longe.
##
## Marcar em UMA instancia basta: vale pros dois Maycows e pra sessao inteira
## (ver `_vida_infinita_na_sessao`).
##
## Nao cobre a morte por queda (`_trigger_fall_death`): cair fora do mapa nao e
## dano, e a unica saida de quem furou o chao — sem ela o teste ficaria caindo
## pra sempre.
@export var infinite_health_test: bool = false

# --- Interruptor de sessao das flags de teste (aba DEBUG das configuracoes) ---
#
# Os dois Maycows sao instancias DIFERENTES do player.tscn, cada uma na sua cena
# (stage_1.tscn, battlefield_1.tscn, the_house.tscn...), e a arena ainda
# constroi um player novo a cada batalha. Por isso o interruptor e' `static`:
# vale pra todo player da sessao, inclusive os que nascerem depois.
#
# SOMENTE MEMORIA. Comecam sempre DESLIGADOS, nao vao pro save nem pro
# project.godot, e morrem com o processo — fechar e abrir o jogo volta ao
# padrao. Quem liga/desliga e' a aba DEBUG, em tempo real.
static var _vida_infinita_na_sessao: bool = false
static var _stamina_infinita_na_sessao: bool = false

## Liga/desliga a vida infinita para a sessao inteira, em tempo real — usado
## pela aba DEBUG do menu de configuracoes. Ao contrario da caixinha do
## editor (que so soma flags, nunca desliga), isto e o unico jeito de tirar a
## vida infinita sem reiniciar o jogo.
static func set_infinite_health_debug(ligado: bool) -> void:
	_vida_infinita_na_sessao = ligado


static func is_infinite_health_debug() -> bool:
	return _vida_infinita_na_sessao


## Mesma dupla para a stamina infinita.
static func set_infinite_stamina_debug(ligado: bool) -> void:
	_stamina_infinita_na_sessao = ligado


static func is_infinite_stamina_debug() -> bool:
	return _stamina_infinita_na_sessao


## A stamina esta infinita agora? Junta a caixinha do editor com o interruptor
## da aba DEBUG. E' consultada em vez de `infinite_stamina_test` direto porque a
## flag da instancia so e' sincronizada no _ready: lida assim, ligar/desligar no
## menu vale na hora, inclusive pra desligar.
func _stamina_infinita() -> bool:
	return infinite_stamina_test or _stamina_infinita_na_sessao


var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_bar: ProgressBar
var stamina_fade_timer: float = 0.0
var is_exhausted: bool = false

# --- ULTIMATE CINEMÁTICA (COGBLADE SLAIN) ---
@export_group("Ultimate Cinemática")
@export var ult_model_distance: float = 1.7
@export var ult_cogblade_rot_x: float = 110.0
@export var ult_cogblade_rot_y: float = -90.0
@export var ult_cogblade_rot_z: float = 0.0

# --- SEGUNDO PODER: COGBLADE CUT ---
@export_group("Cogblade Cut")
## Quanto tempo (em tempo de jogo, já em câmera lenta) a câmera leva para se
## ajeitar olhando para frente antes dos cortes começarem.
@export var cut_camera_settle_time: float = 0.22
## Distância da lâmina até a câmera durante os cortes.
@export var cut_blade_distance: float = 1.6
## Pausa depois que a lâmina aparece e antes do primeiro corte.
@export var cut_blade_hold_time: float = 0.12
## Quantos cortes a animação executa.
@export var cut_slash_count: int = 18
## Duração do PRIMEIRO corte (lento).
@export var cut_slash_first_duration: float = 0.05
## Duração do ÚLTIMO corte (velocidade altíssima).
@export var cut_slash_last_duration: float = 0.004
## Intervalo entre cortes, como fração da duração do corte.
@export var cut_slash_gap_ratio: float = 0.35
## Orientação base da lâmina (mesma convenção do arremesso: X, Y somado ao yaw, Z).
@export var cut_cogblade_rot_x: float = 90.0
@export var cut_cogblade_rot_y: float = 0.0
@export var cut_cogblade_rot_z: float = 45.0
## Dano em área no final (um pouco menor que o do Slain, que causa 30).
@export var cut_damage: int = 18
@export var cut_damage_radius: float = 15.0
## Quanto do acúmulo da cogblade sobra depois de usar o Cut (não zera).
@export var cut_leftover_power: float = 25.0
## Quantos inimigos sangram a cada passada da lâmina (menor = mais leve).
@export var cut_blood_targets_per_slash: int = 2
## O sangue do Cut roda mais rápido que o resto da cena para dar pra ver o
## jorro inteiro: 1.0 = tão lento quanto a cena, 3.5 = ~0.35x do normal.
@export var cut_blood_speed_scale: float = 3.5

# --- TERCEIRO PODER: COGBLADE FIRE CROSS ---
@export_group("Cogblade Fire Cross")
## Salto para trás e para cima antes do golpe.
@export var fire_jump_back: float = 7.0
@export var fire_jump_height: float = 12.0
@export var fire_jump_time: float = 0.22
## Duração de cada um dos dois cortes que formam o X.
@export var fire_slash_duration: float = 0.09
## Quanto tempo o X de fogo fica parado na tela antes de descer.
@export var fire_x_hold_time: float = 0.08
## Tempo de queda do X até a arena.
@export var fire_x_fall_time: float = 0.16
## Tempo assistindo o fogo se espalhar lá de cima.
@export var fire_watch_time: float = 0.28
## Volta rápida para o lugar de onde o poder começou.
@export var fire_return_time: float = 0.12
## Distância do X de fogo até a câmera enquanto ele se forma.
@export var fire_x_distance: float = 4.5
## Raio do incêndio na arena.
@export var fire_radius: float = 18.0
## Quantas manchas de fogo formam o incêndio (menor = mais leve).
@export var fire_patches: int = 24
## Quanto tempo o fogo queima, em segundos de jogo.
@export var fire_duration: float = 6.0
## Tempo (em segundos de jogo) que o incêndio leva para ir do centro à borda.
## Curto de propósito: com time_scale 0.1 durante a cinemática, isso vira ~2s
## reais, que é justamente o tempo em que o player assiste lá do alto.
@export var fire_spread_time: float = 0.22
## As partículas de fogo rodam com este speed_scale enquanto a cinemática está
## em câmera lenta, senão o fogo ficaria praticamente congelado na tela.
## Volta para 1.0 assim que o player recupera o controle.
@export var fire_slowmo_speed_scale: float = 4.0
## Dano no instante em que o fogo pega no inimigo.
@export var fire_impact_damage: int = 20
## Dano por tique de queimadura, e quantos tiques cada inimigo leva.
@export var fire_burn_damage: int = 5
@export var fire_burn_ticks: int = 4

# --- QUICK TIME EVENT DOS PODERES DA COGBLADE ---
# Os poderes rodam em câmera lenta (time_scale 0.1), mas a janela abaixo é
# medida no relógio de parede: 1.0 aqui é 1 segundo REAL para apertar.
@export_group("Cogblade Quick Time Event")
## Tempo real que o jogador tem para acertar CADA botão sorteado.
@export var qte_window: float = 1.0
## Quantos dos primeiros cortes do Cut pedem um botão (um botão por corte).
## Errar qualquer um interrompe os cortes e pula direto para o golpe final.
@export var cut_qte_count: int = 5
## Quanto do dano do Cut sobra quando o jogador erra logo no primeiro botão.
## Com todos os botões acertados o dano é o cheio (cut_damage).
@export var cut_qte_min_damage_ratio: float = 0.35
## Quantos botões cada um dos dois cortes do Fire Cross pede. Errar qualquer um
## faz o X de fogo se desfazer no ar: ninguém pega fogo e ninguém toma dano.
@export var fire_qte_per_slash: int = 2
## Quantos botões o Slain pede durante a descida da lâmina. Errar tira a
## explosão e o dano: a cogblade só desce e para.
@export var slain_qte_count: int = 5
## Quanto tempo (em tempo de jogo, já em câmera lenta) a descida lenta do Slain
## dura enquanto o QTE roda. Ela é interrompida assim que o QTE acaba.
@export var slain_qte_fall_time: float = 0.9
## Que fração do caminho até o chão essa descida lenta cobre (o resto é o
## mergulho rápido final).
@export var slain_qte_fall_ratio: float = 0.6

# --- GOLPE MELEE DA COGBLADE (toque rápido em C / L1) ---
@export_group("Cogblade Melee")
## Dano do golpe corpo a corpo da cogblade.
@export var melee_damage: int = 3
## Alcance do golpe: o player precisa estar perto do inimigo.
@export var melee_range: float = 3.0
## Duração da passada da lâmina de um lado para o outro.
@export var melee_duration: float = 0.18
## Estamina gasta por golpe.
@export var melee_stamina_cost: float = 12.0
## Espera, em milissegundos, entre o fim de um golpe e o próximo poder sair.
@export var melee_cooldown_ms: int = 120
## Altura e distância do CENTRO do golpe em relação ao player.
@export var melee_height: float = 0.95
@export var melee_distance: float = 1.75
## Amplitude vertical do golpe (fração do alcance). O corte vai do canto
## superior de um lado até o canto inferior do outro lado.
@export var melee_vertical_ratio: float = 0.3
## O quanto a mão esquerda acompanha o deslocamento da lâmina (0 = parada,
## 1 = acompanha o golpe inteiro, que sairia da tela).
@export var melee_hand_follow: float = 0.18
## Empurrão da mão para frente no meio do golpe.
@export var melee_hand_push: float = 0.12
## Tempo que a mão leva para voltar devagar ao lugar (igual ao fim do reload).
@export var melee_hand_return_time: float = 0.6
var mp_bar: ProgressBar

var hud_layer: CanvasLayer
var amulet_counter_label: Label
var amulet_crosshair: Panel
## Mira da PISTOLA (Maycow normal, terceira pessoa). É outra da mira do amuleto
## de propósito: aquela é um círculo roxo de magia, esta é a cruz de um tiro.
var gun_crosshair: Control
## Mira da CACADEIRA. Também é outra, e pelo mesmo motivo que a da pistola é
## outra da do amuleto: a pistola acerta um ponto, e a cruz fina diz isso; a
## caçadeira cobre uma área, e o que diz isso é um círculo aberto.
var shotgun_crosshair: Control
var iron_rusks_value_label: Label

var is_teleporting_enemies: bool = false
var is_playing_return_effect: bool = false
var heartbeat_tween: Tween

@export_group("Damage Feedback")
@export var damage_camera_shake_duration: float = 0.20
@export var damage_camera_shake_strength: float = 0.25
# ---------------------------

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003 # Sensibilidade do mouse
@export var WALK_SPEED: float = 3.0
@export var WALK_SPEED_NORMAL: float = 2.8
@export var RUN_SPEED: float = 4.8 # Velocidade maior para a corrida
## DENTRO DE CASA NINGUEM ANDA IGUAL NA RUA.
##
## Corredor de hospital, de escola, nave de igreja, sala da casa do Jimmy: o
## espaco e' curto, a camera de 3a pessoa fica colada na parede e a corrida da
## cidade atravessa um comodo inteiro antes do jogador enxergar o que tem nele.
## Nos interiores andar e correr continuam existindo — so' que mais curtos.
##
@export var WALK_SPEED_INTERIOR: float = 2.2
@export var RUN_SPEED_INTERIOR: float = 3.5
## A animacao da CORRIDA (so' ela) roda um tiquinho mais devagar nos interiores.
## Isto e' tempero, nao correcao de patinacao: descer ate' a razao das
## velocidades (3.5/4.8 = 0.73) deixava o passo arrastado.
@export var ANIM_CORRIDA_INTERIOR: float = 0.9
## Os interiores, pelo nome do no' raiz da cena. A cidade e a stage_1 ficam de
## fora de proposito: la' a corrida e' a de sempre.
const CENAS_INTERIOR: PackedStringArray = [
	"hospital", "escola", "porao", "igreja_interior",
	"casa_jimmy_interior", "oficina_jimmy", "the_house",
]
## Onde mora o componente do braco que empurra porta. Ele PRECISA ser filho do
## Skeleton3D — SkeletonModifier3D so' funciona ali.
const CAMINHO_MAO_PORTA := "maycow_lopes_normal/Armature/Skeleton3D/PlayerDoorReach"
const CAMINHO_LANTERNA_CINTO := "maycow_lopes_normal/Armature/Skeleton3D/PlayerFlashlightHold"
## Quanto o movimento precisa estar alinhado com a frente do corpo para a
## corrida valer (produto escalar: 1 = direto para frente, 0 = totalmente de
## lado, -1 = de costas).
##
## 0.45 deixa correr para frente e na diagonal (45° dá 0.71), mas corta a
## corrida a partir de ~63° — de lado com a câmera para frente ele volta a
## andar, animação e velocidade, igual ao que já acontecia andando para trás.
@export_range(0.0, 1.0) var CORRIDA_ALINHAMENTO_MIN: float = 0.45

## --- ANDAR DE ARMA NA MAO (so' o Maycow normal) ---
## Mirando com a arma e andando, a animacao usada e' sempre a de andar PARA
## TRAS ("Walk_Backward_inplace"), em qualquer direcao. Ela e' a unica das
## quatro em que o tronco fica quieto e recolhido, que e' como ele tem de
## andar segurando a pistola — as de frente/corrida balancam o ombro e
## torcem o modelo por cima da pose da arma.
##
## PARADO nada muda: continua o "idle" de sempre. So' vale com a MIRA DE ARMA
## levantada; mirando com o amuleto o andar e' o normal.
@export var ANIM_MIRA_ANDANDO: float = 0.7

## --- Lentidao vinda de fora (anel de magia do Shadow Seraph) ---
## Multiplica a velocidade de caminhada/corrida nas DUAS variantes do Maycow.
## 1.0 = normal, 0.4 = 60% mais lento. O dash de proposito NAO passa por aqui:
## o impulso continua sendo a saida de quem esta preso no anel.
var speed_multiplier: float = 1.0
var _slow_timer: float = 0.0

#CHANGE LATER - DYNAMICLY
@export var damage_crescent_cogblade:int = 5
@export var damage_pistol:int = 10 #3 
## Dano de UM chumbo da caçadeira. O tiro solta `PELOTAS_SHOTGUN` deles de uma
## vez (ver player_combat), então colado no inimigo o estrago é a soma e de
## longe a carga se abre e só uma parte acerta — que é o que uma caçadeira faz.
@export var damage_shotgun_pelota:int = 9
@export var damage_headshoot:int = 100
var current_weapon #: AnimatedSprite2D
var can_shoot_again:bool = true
var is_falling_dead: bool = false
var invulnerable: bool = false
var fall_cam: Camera3D = null

var last_rotation_y: float = 0.0
var last_camera_rot_x: float = 0.0
## O CORPO NÃO ACOMPANHA A CÂMERA NA HORA.
##
## Parado, girar a câmera não vira o Maycow: ele fica plantado, de costas, e a
## câmera é que corre em volta dele. Só quando ela passa do limite (que é
## diferente de cada lado — ver `GIRO_LIMITE_DIREITA`) ele
## PIVOTA — dá os passinhos e se realinha, sempre para o lado a que a câmera
## foi, parando quando chega a `GIRO_SOLTA` do alvo. Se a câmera continuar
## girando enquanto ele pivota, ele persegue.
##
## É isto que impede a câmera de ficar de frente para ele.
##
## O que havia antes era o contrário: o corpo virava junto com a câmera e os
## passinhos existiam só para ele não girar deslizando feito um pião.
@export var GIRO_LIMITE: float = 24.0
## O MESMO LIMITE, MAS QUANDO A CÂMERA FOI PRA DIREITA.
##
## Menor que o da esquerda de propósito: com os 24 dos dois lados, girar pra
## direita fica exagerado — ele demora demais parado antes de começar a voltar.
## Pra esquerda o tempo está bom, então só este lado encolheu.
##
## Qual lado é qual sai do SINAL: a câmera gira por `rotate_y(-relative.x)`,
## então mouse pra direita DIMINUI o `rotation.y` e deixa o `falta` negativo.
##
## A folga contra o `GIRO_SOLTA` tem de existir, senão o pivô reacende no quadro
## seguinte ao que termina. Como este lado desceu abaixo dos 8 do
## `GIRO_SOLTA`, ele traz o próprio: ver `GIRO_SOLTA_DIREITA`.
@export var GIRO_LIMITE_DIREITA: float = 6.0
## Onde o pivô termina. Maior que zero de propósito: parar exatamente no alvo
## faria ele reacender o pivô a cada tremidinha de mouse.
@export var GIRO_SOLTA: float = 8.0
## Onde o pivô PRA DIREITA termina. Anda junto com `GIRO_LIMITE_DIREITA`, e
## tem de ficar abaixo dele: a diferença entre os dois é a folga.
##
## Sem este, o gatilho de 6 cairia dentro da zona de soltura de 8 e o pivô
## nasceria já terminado — ele andaria um quadro e pararia, todo quadro. O que
## se vê na tela até seria parecido, mas por acidente.
@export var GIRO_SOLTA_DIREITA: float = 3.0
## Quão rápido ele pivota (rad/s). Baixo de propósito: o pivô é um passo
## deliberado, e a qualquer coisa acima disso ele vira num estalo.
@export var GIRO_VEL_CORPO: float = 1.3
## O QUE IMPEDE O PASSO LENTO DE DEIXAR ELE PRA TRÁS.
##
## Com velocidade fixa e baixa, uma girada rápida de câmera deixa o corpo de
## lado pelo giro inteiro — ele nunca alcança. Então o que passa do limite
## entra como pressa extra (rad/s por radiano de atraso): correção pequena sai
## no passo lento, atraso grande ele apressa para alcançar.
@export var GIRO_ALCANCE: float = 8.0
## Velocidade da animação de passinho durante o pivô. Abaixo de 1 de propósito:
## o pivô é um ajuste de pé, não uma caminhada.
@export var GIRO_ANIM_ESCALA: float = 0.85
## Tempo MÍNIMO que a animação de passinho fica no ar depois que um pivô começa.
##
## Com o gatilho curto, o corpo alcança a câmera em três ou quatro quadros num
## giro lento — e a animação piscava por 0,07 s, o que lê como tique nervoso e
## não como passo. Este mínimo dá tempo do pé pousar. Vale só para a animação:
## o corpo continua parando de girar assim que alcança a câmera.
@export var GIRO_ANIM_MINIMO: float = 0.30

## Yaw do CORPO, em coordenadas de MUNDO. É ele que manda no modelo; o
## `rotation.y` do jogador continua sendo o da câmera e o do movimento.
var _yaw_corpo: float = 0.0
var _yaw_corpo_pronto: bool = false
var _pivotando: bool = false
## O quanto o corpo está atrasado em relação à câmera por causa do pivô. Zero
## em movimento. É ele que gira o deslocamento do modelo (ver seção 8).
var _atraso_pivo: float = 0.0
## A INCLINACAO DO STRAFE, SEPARADA DO PIVO.
##
## Andando de lado o corpo se vira um pouco pra dentro do movimento. Isso e'
## SO' VISUAL e mora aqui, fora do `_yaw_corpo`: e' somado ao `_atraso_pivo` na
## hora de girar o modelo, mas NAO entra na conta que gira o deslocamento de
## enquadramento (ver seção 8).
##
## Ficar junto era um bug: ao soltar o controle correndo de lado, o
## `_atraso_pivo` saltava de zero pra inclinacao inteira num quadro, e os 40 cm
## de enquadramento giravam junto — o Maycow pulava ~18 cm pro lado, do nada.
var _inclinacao_strafe: float = 0.0
## Quanto ainda falta do tempo mínimo da animação de passinho (ver GIRO_ANIM_MINIMO).
var _pivo_anim: float = 0.0
## RITMO DO ENQUADRAMENTO — O DESLOCAMENTO NÃO PODE DAR TRANCO.
##
## Parar de correr troca o alvo do deslocamento de 85 cm para 40 cm de uma vez
## só. Perseguir isso com um `lerp` simples põe a maior parte desses 45 cm nos
## primeiros quadros — a velocidade é MÁXIMA no instante da parada — e o Maycow
## é jogado para o meio da tela num puxão.
##
## Por isso a perseguição é em DOIS passos. Este é o primeiro: ele suaviza o
## próprio ALVO, e é o que faz o deslocamento começar parado em vez de sair
## correndo no primeiro quadro.
const ENQUADRAMENTO_ALVO := 3.0
## Segundo passo, em Z: o corpo perseguindo o alvo já suavizado. Mais lento que
## os 2.0 de antes de propósito — junto com o primeiro passo, o pico de
## velocidade cai para menos da metade e a volta ao enquadramento de parado
## vira um deslize de pouco mais de um segundo.
const ENQUADRAMENTO_CORPO := 2.4

## Deslocamento do modelo no espaço do CORPO (ver seção 8).
var _off_corpo_x: float = 0.0
var _off_corpo_z: float = 0.3995
## O alvo JÁ SUAVIZADO desse deslocamento (ver ENQUADRAMENTO_ALVO).
var _alvo_corpo_x: float = 0.0
var _alvo_corpo_z: float = 0.3995

var is_toggle_aim_active: bool = false

## Tamanho do pente: 8 tiros antes de precisar recarregar.
##
## Os dois andam juntos de proposito. `max_clip_pistol` e' ate' onde o reload
## enche (ver player_combat.reload), e `clip_pistol_ammo` e' com quanto o Maycow
## nasce — e a arena constroi um Maycow de combate NOVO a cada batalha, entao e'
## este valor inicial que decide com quantas balas ele entra em cada luta.
## Deixar um maior que o outro faria ele comecar com um pente que o reload nunca
## mais conseguiria repor.
var clip_pistol_ammo: int = 8
var max_clip_pistol: int = 8

## A caçadeira leva DOIS, e é por isso que ela existe como arma diferente e não
## como outro número na pistola: dois tiros mudam o jeito de jogar.
##
## Vale aqui a mesma regra do pente da pistola — `clip_shotgun_ammo` é com
## quantos ela nasce, e nascer cheia é o que faz a arma pega no balcão já vir
## com dois tiros, sem ninguém precisar carregá-la antes do primeiro uso.
var clip_shotgun_ammo: int = 2
var max_clip_shotgun: int = 2
var ammo_label: Label
var ammo_icon: TextureRect
var amulet_hud_icon: TextureRect

# CONFIGURACAO DO CONTROLE
@export var JOY_SENSITIVITY: float = 0.04 # Sensibilidade para o analógico

# --- Limites verticais da câmera, em graus (negativo = olhando para baixo) ---
#
# Ficavam repetidos como número solto em quatro lugares (mouse, analógico nos
# dois Maycows e o aim assist), o que fazia mexer num só sair pela culatra: a
# mira descia mais que a câmera, ou o controle mais que o mouse. Agora todos
# leem daqui, então mouse e controle são obrigatoriamente iguais.
@export var PITCH_MIN_3P: float = -32.0  # era -25: desce um pouco mais
@export var PITCH_MAX_3P: float = 20.0
@export var PITCH_MIN_1P: float = -70.0  # era -60: desce um pouco mais
@export var PITCH_MAX_1P: float = 60.0


## Velocidade da animação do Maycow normal, via o nó TimeScale da AnimationTree
## dele. Se a árvore não tiver esse nó, o `set` simplesmente não encontra o
## parâmetro e nada acontece — então isto é seguro mesmo antes/depois de mexer
## na montagem da árvore.
func _set_anim_time_scale(valor: float) -> void:
	if is_instance_valid(animation_tree_normal):
		animation_tree_normal.set("parameters/TimeScale/scale", valor)


## Estamos dentro de um dos interiores? Ver `CENAS_INTERIOR`.
func em_interior() -> bool:
	var arvore := get_tree()
	if arvore == null or arvore.current_scene == null:
		return false
	return CENAS_INTERIOR.has(String(arvore.current_scene.name))


## Velocidade AGORA: a de sempre na rua, a curta nos interiores.
func _velocidade_corrida() -> float:
	return RUN_SPEED_INTERIOR if em_interior() else RUN_SPEED


func _velocidade_caminhada() -> float:
	return WALK_SPEED_INTERIOR if em_interior() else WALK_SPEED_NORMAL


## Tempero na velocidade da animacao. Vale so' pra corrida e so' em interior —
## andando, ou na rua, devolve 1.0 e nada muda.
func _fator_anim_corrida(correndo: bool) -> float:
	if not correndo or not em_interior():
		return 1.0
	return ANIM_CORRIDA_INTERIOR


## A MAO QUE EMPURRA A PORTA. Quem chama sao as portas do hospital e da escola
## (`porta_hospital.gd` / `porta_escola.gd`), passando um ponto na folha.
##
## Sem o componente (Maycow com poderes, que tem outro rig) isto simplesmente
## nao faz nada — a porta abre do mesmo jeito, so' sem o gesto.
func esticar_mao_para(ponto: Vector3, tempo: float) -> void:
	var mao = get_node_or_null(CAMINHO_MAO_PORTA)
	if mao and mao.has_method("estica"):
		mao.estica(ponto, tempo)


## Limites (baixo, cima) em graus para a câmera que estiver ativa.
func _limites_pitch(cam: Camera3D) -> Vector2:
	if cam == camera_third_person:
		return Vector2(PITCH_MIN_3P, PITCH_MAX_3P)
	return Vector2(PITCH_MIN_1P, PITCH_MAX_1P)
@export var DEADZONE: float = 0.1


# Configurações do balanço da tela (Bobbing)
@export var head_bob_ON: bool = true
var bob_freq = 2.0      # Frequência (quão rápido balança)
var bob_amp = 0.05      # Amplitude (quão longe a câmera vai)
var t_bob = 0.0         # Contador de tempo para o cálculo do Seno



# DASH
@export_group("Dash Settings")
@export var DASH_SPEED : float = 20.0    # Velocidade durante o dash
@export var DASH_DURATION : float = 0.2  # Quanto tempo dura (em segundos)
@export var DASH_COOLDOWN : float = 1.0  # Tempo de espera para usar de novo

var is_dashing : bool = false
var dash_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
var dash_direction : Vector3 = Vector3.ZERO
@onready var trail_particles: GPUParticles3D = $trail_particles # Nó de fumaça
var modelo_visual: MeshInstance3D # resolvido em _ready() conforme a variante ativa (normal/não-normal)
## Trava de cutscene sobre o modelo de 3ª pessoa. O fim do `_physics_process`
## reescreve `modelo_visual.visible` TODO quadro a partir da câmera de 1ª pessoa
## do próprio player — então uma cutscene que apenas escondesse o modelo o via
## reaparecer no quadro seguinte, e o Maycow ficava visível ao lado da câmera
## durante o agarrão. Quem esconde por cutscene liga isto (`cutscene_set_model_hidden`).
var _modelo_escondido_por_cena: bool = false


# HAND ADJUSTMENTS
@export_group("Left Hand Adjustments")
@export var left_hand_idle_offset: Vector3 = Vector3(0.1, -0.35, 0.0)

@export_group("Cogblade Adjustments")
@export var cogblade_tilt_x: float = 0.0 
@export var cogblade_tilt_y: float = 0.0 
@export var cogblade_tilt_z: float = 0.0 

@export_group("Normal Maycow Run Visuals")
@export var normal_run_offset_x: float = -0.1
@export var normal_run_offset_z: float = 0.85
@export var normal_walkback_offset_x: float = -0.05
@export var normal_walkback_offset_z: float = 0.5


#ORIGINAL POSITION FOR THE LEFT HAND
var magic_hand_pos_original
var hand_magic_3d_pos_original: Vector3
var hand_pistol_pos_original: Vector3
var pistol_2d_pos_original: Vector2
var hand_magic_3d_pos_hidden: Vector3
var is_magic_attacking: bool = false
var is_blade_returning: bool = false
var blade_return_speed: float = 15.0
var damage_blur_timer: float = 0.0
var damage_blur_tween: Tween
var is_reloading: bool = false
var magic_blade_pos_original
var camera_bullet_time_position
var camera_bullet_time_ON = false
var is_first_person = false

var transition_camera = false

var is_aiming = false
var _run_toggle_active: bool = false

var cogblade_hud: TextureProgressBar
var cogblade_hud_label: Label
var cogblade_power_value: float = 0.0
var cogblade_pulsing: bool = false
var cogblade_pulse_tween: Tween
var cogblade_particles: CPUParticles2D
var is_using_ultimate: bool = false
# True enquanto o menu radial de poderes da cogblade está aberto (o player
# perde o controle da câmera/movimento e o tempo fica ultra lento)
var cogblade_menu_open: bool = false
# True enquanto o golpe melee da cogblade está passando pela tela
var cogblade_melee_active: bool = false
var amuleto_node: Node3D
var amuleto_particles: CPUParticles3D
var amulet_hovered_enemy: Node3D = null
var amulet_selected_enemies: Array[Node3D] = []
var amulet_magic_active: bool = false
var max_amulet_targets: int = 3

var playback 

# --- CUTSCENE HELPER VARS ---
var _cutscene_inputs_disabled: bool = false
var _cutscene_auto_walk: bool = false
var _cutscene_auto_run: bool = false
var _cutscene_camera_shake_intensity: float = 0.0
var _cutscene_shake_h_base: float = 0.0
var _cutscene_shake_v_base: float = 0.0
var _is_cutscene_shaking: bool = false
var _cutscene_hud_hidden: bool = false
var _cutscene_camera_disabled: bool = false
var _was_cutscene_blocked: bool = false

# ==============================================================================
# LANTERNA
# ==============================================================================
## Item pego no chão da igreja. Antes desta mudança o `SpotLight3D` da câmera
## vivia aceso o tempo todo, com 1,4 de energia e 17 m de alcance: dava um
## borrãozinho claro a dois passos do Maycow e nada mais — parecia bug, não
## lanterna. Agora ele é uma lanterna de verdade (facho longo, miolo forte,
## borda suave, com sombra) e só existe depois que o jogador pega o objeto.
const LANTERNA_ITEM := "lanterna"
## Som de acender: é o "entrar_super" do menu, puxado para baixo no pitch. Fica
## com corpo de interruptor grande em vez de bipe de interface — e o jogador
## não reconhece o som do menu.
const LANTERNA_SOM := "res://assets/sounds/menu_itens/entrar_super.mp3"
const LANTERNA_SOM_PITCH := 0.62
## Quanto o facho aponta para BAIXO em relação à linha de visão. Lanterna
## apontada exatamente para o centro da tela ilumina o horizonte e deixa o chão
## à frente dos pés no escuro, que é justamente onde se anda.
const LANTERNA_INCLINACAO := 0.16
## Posição de repouso do facho (à frente e um palmo à direita do peito).
const LANTERNA_POS := Vector3(0.16, -0.05, -0.75)
## Inércia: quanto do giro da câmera a mão "não acompanha". A luz fica para
## trás da virada e chega depois — é o que tira o ar de lanterna parafusada na
## testa. Em radianos por radiano girado.
const LANTERNA_INERCIA := 3.2
## Passada: o facho sobe/desce e vai/volta junto com o andar, proporcional à
## velocidade. Parado, some.
const LANTERNA_BOB := 0.0075
## Mola que traz o facho de volta ao centro, e o atrito que a segura. Mola alta
## demais devolve rápido e vira tremida; atrito baixo demais deixa balançando.
const LANTERNA_MOLA := 34.0
const LANTERNA_AMORT := 7.0
## Teto do desvio, em radianos (~5°). Sem isto uma virada brusca joga o facho
## para fora da tela.
const LANTERNA_SWAY_MAX := 0.09

var lanterna_ligada: bool = false
var _lanterna_som: AudioStreamPlayer = null
## Halo: o segundo facho, largo e fraco, que envolve o miolo. Uma lanterna real
## não projeta um disco de luz e escuro absoluto em volta — tem o círculo forte
## no meio e um derrame suave bem maior ao redor. Com um SpotLight3D só, o que
## dava para fazer era a bola de luz.
var _lanterna_halo: SpotLight3D = null
var _lant_sway := Vector2.ZERO      # desvio atual (x = guinada, y = passo)
var _lant_sway_vel := Vector2.ZERO
var _lant_yaw_ant := 0.0
var _lant_pitch_ant := 0.0
var _lant_t := 0.0


func _configurar_lanterna() -> void:
	if not is_instance_valid(lanterna):
		return
	# À FRENTE do peito, não dentro dele. A luz nasceu dentro da malha do
	# Maycow: com sombra ligada, o próprio corpo tapava o facho e o que
	# chegava ao chão era um resto. Puxada 75 cm para a frente (e um palmo
	# para a direita, como quem segura a lanterna), o corpo fica atrás da
	# fonte e a sombra dele passa a cair para trás, que é o certo.
	lanterna.position = LANTERNA_POS
	lanterna.shadow_blur = 1.4
	lanterna.shadow_transmittance_bias = 0.05
	lanterna.light_color = Color(1.0, 0.96, 0.88)
	# MIOLO. Antes eram 14 de energia e 45 m de alcance: acendia o corredor
	# inteiro e estourava tudo que estivesse perto. Uma lanterna de mão alcança
	# um punhado de metros; o que vem depois disso ela só insinua.
	lanterna.light_energy = 4.6
	lanterna.light_indirect_energy = 0.55
	lanterna.light_volumetric_fog_energy = 1.1
	lanterna.spot_range = 14.0
	lanterna.spot_angle = 18.0
	lanterna.spot_angle_attenuation = 1.15   # miolo forte com borda que derrete
	lanterna.spot_attenuation = 1.5          # morre antes do fim do alcance
	lanterna.shadow_enabled = true
	lanterna.shadow_bias = 0.04
	lanterna.shadow_normal_bias = 1.4
	lanterna.distance_fade_enabled = false
	lanterna.visible = false
	lanterna_ligada = false

	# HALO. Filho do miolo de propósito: herda de graça a inclinação e todo o
	# balanço da mão, então os dois nunca se descolam. Sem sombra — sombra de
	# duas fontes quase juntas dá contorno duplo, e é luz fraca demais para
	# valer o custo num renderer mobile.
	if not is_instance_valid(_lanterna_halo):
		_lanterna_halo = SpotLight3D.new()
		_lanterna_halo.name = "lanterna_halo"
		lanterna.add_child(_lanterna_halo)
	_lanterna_halo.position = Vector3.ZERO
	_lanterna_halo.rotation = Vector3.ZERO
	_lanterna_halo.light_color = Color(0.92, 0.94, 1.0)
	_lanterna_halo.light_energy = 1.15
	_lanterna_halo.light_indirect_energy = 0.35
	_lanterna_halo.light_volumetric_fog_energy = 0.6
	_lanterna_halo.spot_range = 8.5
	_lanterna_halo.spot_angle = 44.0
	_lanterna_halo.spot_angle_attenuation = 0.35
	_lanterna_halo.spot_attenuation = 1.2
	_lanterna_halo.shadow_enabled = false
	_lanterna_halo.distance_fade_enabled = false

	_lanterna_som = AudioStreamPlayer.new()
	_lanterna_som.name = "lanterna_som"
	if ResourceLoader.exists(LANTERNA_SOM):
		_lanterna_som.stream = load(LANTERNA_SOM)
	_lanterna_som.pitch_scale = LANTERNA_SOM_PITCH
	_lanterna_som.volume_db = -4.0
	add_child(_lanterna_som)


## Liga/desliga. Sem o item no inventário não acontece nada — é o que impede o
## jogador de ter lanterna antes de achar a lanterna.
func alternar_lanterna() -> void:
	if not is_instance_valid(lanterna):
		return
	if not SaveManager.tem_item(LANTERNA_ITEM):
		return
	lanterna_ligada = not lanterna_ligada
	lanterna.visible = lanterna_ligada
	if is_instance_valid(_lanterna_som) and _lanterna_som.stream:
		# variação pequena no pitch a cada clique: dois cliques idênticos
		# seguidos soam gravados, e este é um som que o jogador vai ouvir muito
		_lanterna_som.pitch_scale = LANTERNA_SOM_PITCH + randf_range(-0.05, 0.05)
		_lanterna_som.play()


## Chamado quando o jogador acaba de pegar a lanterna: já entra acesa.
func acender_lanterna_agora() -> void:
	if not is_instance_valid(lanterna):
		return
	lanterna_ligada = true
	lanterna.visible = true


## O facho segue o pitch da câmera que estiver valendo. Em terceira pessoa quem
## sobe e desce é a `camera_third_person`; a `Camera3D` (1ª pessoa, mãe da luz)
## fica parada, e sem isto a lanterna apontaria sempre para o horizonte.
func _atualizar_mira_lanterna(delta: float) -> void:
	if not lanterna_ligada or not is_instance_valid(lanterna):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	# --- BALANÇO DA MÃO -------------------------------------------------
	# Duas forças empurram o facho para fora do centro e uma mola o traz de
	# volta: a INÉRCIA da virada (a mão chega depois da câmera) e a PASSADA
	# (o braço sobe e desce com o andar). Parado e sem girar, os dois zeram e
	# a mola devolve o facho ao lugar sozinha.
	var yaw: float = cam.global_rotation.y
	var pitch: float = cam.global_rotation.x
	var d_yaw: float = wrapf(yaw - _lant_yaw_ant, -PI, PI)
	var d_pitch: float = wrapf(pitch - _lant_pitch_ant, -PI, PI)
	_lant_yaw_ant = yaw
	_lant_pitch_ant = pitch
	_lant_sway_vel += Vector2(-d_yaw, -d_pitch) * LANTERNA_INERCIA

	var vel_plana: float = minf(Vector2(velocity.x, velocity.z).length(), 7.0)
	_lant_t += delta * (1.6 + vel_plana * 1.15)
	# Vertical no dobro da frequência da horizontal: é o oito deitado que o
	# braço faz andando. Mesma frequência nos dois eixos daria um círculo.
	var passo := Vector2(sin(_lant_t), sin(_lant_t * 2.0) * 0.6) \
		* vel_plana * LANTERNA_BOB

	_lant_sway_vel += (passo - _lant_sway) * LANTERNA_MOLA * delta
	_lant_sway_vel *= exp(-LANTERNA_AMORT * delta)
	_lant_sway += _lant_sway_vel * delta
	_lant_sway = _lant_sway.limit_length(LANTERNA_SWAY_MAX)

	# --- MIRA -----------------------------------------------------------
	# Em terceira pessoa quem sobe e desce é a `camera_third_person`; a
	# `Camera3D` (1ª pessoa, mãe da luz) fica parada, e sem isto a lanterna
	# apontaria sempre para o horizonte.
	var alvo_x: float = -LANTERNA_INCLINACAO
	if cam != camera:
		alvo_x = cam.rotation.x - LANTERNA_INCLINACAO
	lanterna.rotation.x = lerp_angle(lanterna.rotation.x,
		alvo_x + _lant_sway.y, 0.25)
	lanterna.rotation.y = lerp_angle(lanterna.rotation.y, _lant_sway.x, 0.25)

	# --- DE ONDE A LUZ SAI ----------------------------------------------
	# Em terceira pessoa o Maycow normal carrega a lanterna no cinto, e é de lá
	# que o facho tem de nascer: luz saindo do nada à frente do peito não tem
	# objeto na tela que a explique. A MIRA continua vindo da câmera (é com ela
	# que o jogador aponta) — só a ORIGEM muda de lugar.
	var cinto := _flashlight_hold()
	if cinto and cinto.tem_lanterna_na_cintura():
		lanterna.global_position = cinto.saida_da_luz()
		return

	# Sem lanterna no cinto (primeira pessoa, parasita): a fonte fica à frente
	# do peito, e um tiquinho de deslocamento junto do giro — só girar a fonte
	# move o disco de luz mas deixa a origem congelada, e o olho percebe isso.
	lanterna.position = lanterna.position.lerp(
		LANTERNA_POS + Vector3(_lant_sway.x * 0.35, _lant_sway.y * 0.35, 0.0),
		0.25)


# ==============================================================================
# MIRA COM A ARMA (MAYCOW NORMAL, TERCEIRA PESSOA)
# ==============================================================================
## A outra metade do botão de mira. Com o AMULETO equipado, segurar a mira abre
## o poder que leva inimigos para a arena (player_amulet.gd); com a PISTOLA
## equipada, ela faz o que qualquer jogo de tiro em terceira pessoa faz: as duas
## mãos sobem para a arma, uma mira aparece no meio da tela e o gatilho atira.
##
## Os dois nunca convivem: `SaveManager.EQUIPAMENTO_EXCLUSIVO` garante que
## equipar um desequipa o outro, porque são usos diferentes do MESMO botão.
##
## A pose das mãos não é animação: é o `player_gun_hold.gd`, um
## SkeletonModifier3D que roda depois da AnimationTree e reescreve só os braços
## (o rig do Maycow normal não tem clipe de mira, e não há .blend fonte).

## FOV da câmera de terceira pessoa enquanto mira com a arma.
const FOV_MIRA_ARMA := 55.0


## Alcance do raio que procura o que está no centro da tela, em metros.
const ALCANCE_MIRA_ARMA := 90.0

## O braço nunca aponta para um alvo mais perto que isto. Inimigo colado no
## Maycow puxaria o braço para baixo e para trás, e a arma sairia da tela.
const DISTANCIA_MINIMA_ALVO := 6.0


func _processar_mira_de_arma() -> void:
	if point: point.visible = false
	if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
	# O poder do amuleto fica desligado o tempo todo aqui: sem isto, um resto de
	# estado dele (câmera em 1ª pessoa, mão mágica visível) sobreviveria à troca
	# de item feita no meio de uma mirada.
	_hide_amulet_magic()
	_clear_amulet_hover()

	# Duas armas passam por aqui, e a escolha é uma só: qual está equipada.
	# Tudo o que muda entre elas está nestas três linhas — a mira que acende, o
	# componente que levanta a arma, e o par atirar/recarregar.
	var com_shotgun: bool = SaveManager.is_equipped("shotgun")
	var arma_hold := _shotgun_hold() if com_shotgun else _gun_hold()
	var mira: Control = shotgun_crosshair if com_shotgun else gun_crosshair

	if is_instance_valid(gun_crosshair):
		gun_crosshair.visible = is_aiming and not com_shotgun
	if is_instance_valid(shotgun_crosshair):
		shotgun_crosshair.visible = is_aiming and com_shotgun
	if is_instance_valid(mira):
		mira.visible = is_aiming
	if arma_hold:
		arma_hold.mirar(is_aiming, _ponto_de_mira_da_arma() if is_aiming else Vector3.ZERO)

	if is_aiming and Input.is_action_just_pressed("ui_shoot"):
		if com_shotgun:
			atirar_shotgun()
		else:
			atirar_terceira_pessoa()

	# Recarregar NÃO exige estar mirando: ele guarda a arma, põe o pente e
	# levanta de novo. Exigir mira aqui seria só uma regra a mais para decorar.
	if Input.is_action_just_pressed("ui_reload"):
		if com_shotgun:
			recarregar_shotgun()
		else:
			recarregar_terceira_pessoa()


## Desliga tudo o que a mira de arma acende. Chamado quando a mira não pode
## existir (cutscene, prólogo) — e não só quando o jogador solta o botão.
func _encerrar_mira_de_arma() -> void:
	if is_instance_valid(gun_crosshair):
		gun_crosshair.visible = false
	if is_instance_valid(shotgun_crosshair):
		shotgun_crosshair.visible = false
	# As DUAS são avisadas, e não só a equipada: quem cai aqui muitas vezes caiu
	# porque o item MUDOU no meio de uma mirada, e nesse quadro a que precisa
	# baixar a arma é justamente a que não está mais equipada.
	var gun_hold := _gun_hold()
	if gun_hold:
		gun_hold.mirar(false)
	var shotgun_hold := _shotgun_hold()
	if shotgun_hold:
		shotgun_hold.mirar(false)


## O componente que segura a arma. Só existe no Maycow normal — no parasita o
## `maycow_lopes_normal` inteiro é liberado no `_ready`.
func _gun_hold() -> Node:
	return get_node_or_null("maycow_lopes_normal/Armature/Skeleton3D/PlayerGunHold")


## O componente que segura a caçadeira. Mesmas regras do `_gun_hold()` — mais
## uma: no PARASITA ele cai no rig de primeira pessoa.
##
## Lá o `maycow_lopes_normal` inteiro é liberado no `_ready`, então não existe
## `PlayerShotgunHold` nenhum. Quem segura a arma é o `maos_fp_armas.gd`, que
## tem de propósito a mesma API deste (`tem_arma_na_mao`, `boca_do_cano`,
## `direcao_do_cano`, `bocas_das_camaras`, `recarregar`, `mirar`) — é isso que
## deixa o `player_combat.gd` atirar e recarregar a caçadeira sem saber de que
## pessoa é a câmera.
func _shotgun_hold() -> Node:
	var na_terceira := get_node_or_null("maycow_lopes_normal/Armature/Skeleton3D/PlayerShotgunHold")
	if na_terceira != null:
		return na_terceira
	return _maos_fp()


## O rig de primeira pessoa (as duas mãos com arma do parasita).
func _maos_fp() -> Node:
	return get_node_or_null("Camera3D/hand_with_pistol/rig")


## O componente da arma que está equipada AGORA, ou null se for nenhuma.
##
## Existe porque quase todo mundo que pergunta pelo `_gun_hold()` na verdade
## quer "quem está segurando a arma" — a pose de mira, o gesto de recarga, de
## onde sai o clarão. Sem isto, cada um desses lugares precisaria de um `if`
## repetindo a mesma escolha.
func _arma_na_mao() -> Node:
	if SaveManager.is_equipped("shotgun"):
		return _shotgun_hold()
	if SaveManager.is_equipped("pistol"):
		return _gun_hold()
	return null


## A lanterna presa no cinto. So' existe no Maycow normal, e so' depois que ele
## pega o item na igreja.
func _flashlight_hold() -> Node:
	return get_node_or_null(CAMINHO_LANTERNA_CINTO)


## Para onde o braço aponta: o que estiver no centro da tela.
##
## Sai da câmera, e não da arma, de propósito — é o centro da tela que o jogador
## está usando para mirar. A arma fica um pouco à direita e abaixo disso, e é
## essa diferença que dá o jeito "por cima do ombro" da coisa.
func _ponto_de_mira_da_arma() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return global_position - global_transform.basis.z * ALCANCE_MIRA_ARMA

	var origem := cam.global_position
	var frente := -cam.global_transform.basis.z
	var consulta := PhysicsRayQueryParameters3D.create(origem,
		origem + frente * ALCANCE_MIRA_ARMA)
	# Mesma máscara do raycast da primeira pessoa (layers 3 e 4: inimigos e
	# cenário atirável) mais as áreas, que é onde vivem os hitboxes.
	consulta.collision_mask = 12
	consulta.collide_with_areas = true
	consulta.exclude = [get_rid()]

	var espaco := get_world_3d().direct_space_state
	var toque := espaco.intersect_ray(consulta)
	if toque.is_empty():
		return origem + frente * ALCANCE_MIRA_ARMA

	var alvo: Vector3 = toque["position"]
	var distancia := origem.distance_to(alvo)
	if distancia < DISTANCIA_MINIMA_ALVO:
		return origem + frente * DISTANCIA_MINIMA_ALVO
	return alvo


## Tiro do Maycow normal, em terceira pessoa. Mora no componente de combate,
## junto com o tiro da primeira pessoa.
func atirar_terceira_pessoa() -> void:
	var combat = get_node_or_null("PlayerCombat")
	if combat: combat.atirar_terceira_pessoa()


func atirar_shotgun() -> void:
	var combat = get_node_or_null("PlayerCombat")
	if combat: combat.atirar_shotgun()


func recarregar_shotgun() -> void:
	var combat = get_node_or_null("PlayerCombat")
	if combat: combat.recarregar_shotgun()


func recarregar_terceira_pessoa() -> void:
	var combat = get_node_or_null("PlayerCombat")
	if combat: combat.recarregar_terceira_pessoa()


func _ready():
	_sincroniza_flags_de_teste()
	_configurar_lanterna()

	$CollisionShape3D.scale = Vector3(1, 1, 1) # Corrigir colisão oval travando nas quinas
		
	hand_pistol_pos_original = hand_with_pistol.position
	pistol_2d_pos_original = pistola.position

	# Captura o mouse e o esconde ao iniciar o jogo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	playback = GlobalUtils.achar_playback(animation_tree)
	
	# a priori sera a pistola... mas precisa ter um change da arma para mudar 
	current_weapon = pistola
	
	magic_hand_pos_original = magic_hand.position
	magic_blade_pos_original = crescent_cogblade.position
	
	# Esconde o sprite 2D antigo
	magic_hand.visible = false
	# Salva a posição original e define a posição de idle deslocada
	hand_magic_3d_pos_original = hand_magic_3d.position
	hand_magic_3d_pos_hidden = hand_magic_3d_pos_original + left_hand_idle_offset
	hand_magic_3d.position = hand_magic_3d_pos_hidden
	#hand_magic_3d.visible = false
	
	# Garante que mãos e controles em 1ª pessoa comecem invisíveis desde o primeiro instante
	hand_with_pistol.visible = false
	if hand_with_magic: hand_with_magic.visible = false
	control_magic.visible = false
	control_weapons.visible = false
	
	# Desativa a física por um breve momento
	set_physics_process(false)
	
	# Espera 2 frames ou um pequeno timer para o terreno carregar
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Reativa a física
	set_physics_process(true)
	
	#setup camera
	camera.current = false
	control_magic.visible = false
	control_weapons.visible = false
	hand_with_pistol.visible = false
	if hand_with_magic: hand_with_magic.visible = false
	if not GlobalEvents.in_cutscene:
		camera_third_person.make_current()
	#camera_top_view.make_current()
	point.visible = false
	
	
	
	#check if esta no prologo para carregar modelo correto
	if GlobalEvents.is_maycow_normal:
		playback = GlobalUtils.achar_playback(animation_tree_normal)
		$maycow_lopes.queue_free()
		modelo_visual = $maycow_lopes_normal/Armature/Skeleton3D/char1
		# O braco que empurra porta. Vai embaixo do Skeleton3D (e nao ao lado
		# dos outros componentes) porque um SkeletonModifier3D so' roda como
		# filho direto do esqueleto.
		var esqueleto := $maycow_lopes_normal/Armature/Skeleton3D
		var mao_porta = load("res://scripts/player/player_door_reach.gd").new()
		mao_porta.name = "PlayerDoorReach"
		esqueleto.add_child(mao_porta)
		# A arma na mao direita e a pose de mira com ela. Mesmo lugar e mesmo
		# motivo do braco da porta: SkeletonModifier3D so' roda como filho
		# direto do esqueleto.
		var arma_na_mao = load("res://scripts/player/player_gun_hold.gd").new()
		arma_na_mao.name = "PlayerGunHold"
		esqueleto.add_child(arma_na_mao)
		# A cacadeira, no mesmo lugar e pelo mesmo motivo. Vai DEPOIS da
		# pistola de proposito: os dois mexem nos morphs de mao fechada, e um
		# SkeletonModifier3D roda na ordem da arvore — o ultimo e' quem fica
		# com a palavra final. Como so' uma das duas armas pode estar equipada
		# (SaveManager.EQUIPAMENTO_EXCLUSIVO), a que esta' guardada nao escreve
		# pose nenhuma; o que nao pode e' a guardada ABRIR a mao depois que a
		# outra ja' fechou, e a ordem resolve isso.
		var cacadeira_na_mao = load("res://scripts/player/player_shotgun_hold.gd").new()
		cacadeira_na_mao.name = "PlayerShotgunHold"
		esqueleto.add_child(cacadeira_na_mao)
		# A lanterna pendurada no cinto. Mesmo lugar e mesmo motivo dos dois de
		# cima — e e' dela que o facho passa a sair em terceira pessoa.
		var lanterna_cinto = load("res://scripts/player/player_flashlight_hold.gd").new()
		lanterna_cinto.name = "PlayerFlashlightHold"
		esqueleto.add_child(lanterna_cinto)
	else:
		$maycow_lopes_normal.queue_free()
		modelo_visual = $maycow_lopes/Armature/Skeleton3D/char1
		_acender_fogo_parasita()
		
	# Instancia Componente HUD
	var hud_component = load("res://scripts/player/player_hud.gd").new()
	hud_component.name = "PlayerHUD"
	add_child(hud_component)
	
	# Instancia Componente Cutscene
	var cutscene_component = load("res://scripts/player/player_cutscene.gd").new()
	cutscene_component.name = "PlayerCutscene"
	add_child(cutscene_component)
	
	# Instancia Componente Combat
	var combat_component = load("res://scripts/player/player_combat.gd").new()
	combat_component.name = "PlayerCombat"
	add_child(combat_component)

	# Instancia Componente Dash
	var dash_component = load("res://scripts/player/player_dash.gd").new()
	dash_component.name = "PlayerDash"
	add_child(dash_component)
	
	# Instancia Componente Ultimate
	var ult_component = load("res://scripts/player/player_ultimate.gd").new()
	ult_component.name = "PlayerUltimate"
	add_child(ult_component)
	
	# Instancia Componente Amulet
	var amulet_component = load("res://scripts/player/player_amulet.gd").new()
	amulet_component.name = "PlayerAmulet"
	add_child(amulet_component)
	
	# Instancia Componente do Agarrão (encostar num inimigo fora da arena)
	var grab_component = load("res://scripts/player/player_grab.gd").new()
	grab_component.name = "PlayerGrab"
	add_child(grab_component)

	# Instancia Componente do Assistente de Mira (aim assist)
	var aim_assist_component = load("res://scripts/player/player_aim_assist.gd").new()
	aim_assist_component.name = "PlayerAimAssist"
	add_child(aim_assist_component)

	# Instancia Componente do Menu Radial da Cogblade (segurar C / L1)
	var cogblade_menu_component = load("res://scripts/player/player_cogblade_menu.gd").new()
	cogblade_menu_component.name = "PlayerCogbladeMenu"
	add_child(cogblade_menu_component)

	# Instancia Componente dos Atalhos do direcional (trocar o item equipado
	# sem abrir o menu)
	var atalhos_component = load("res://scripts/player/player_atalhos.gd").new()
	atalhos_component.name = "PlayerAtalhos"
	add_child(atalhos_component)

func update_ammo_ui() -> void:
	var hud = get_node_or_null("PlayerHUD")
	if hud: hud.update_ammo_ui()

func _start_heartbeat_pulse() -> void:
	var hud = get_node_or_null("PlayerHUD")
	if hud: hud._start_heartbeat_pulse()

func are_cutscene_inputs_blocked() -> bool:
	return GlobalEvents.in_cutscene or _cutscene_inputs_disabled or GlobalEvents.telefone_cutscene_active or GlobalUtils.in_cinematic_cutscene

func _input(event):
	if are_cutscene_inputs_blocked():
		return

	# Lanterna antes de qualquer outra trava: acender não é ação de combate, e
	# ficar sem luz porque se está mirando ou no bullet time seria absurdo.
	if event.is_action_pressed("ui_lanterna"):
		alternar_lanterna()
		return
		
	# A ação "ui_cogblade_power" (C / L1) agora é tratada pelo componente
	# PlayerCogbladeMenu: precisa ser SEGURADA para abrir o menu radial de
	# escolha entre Cogblade Slain e Cogblade Cut.

	if is_using_ultimate or cogblade_menu_open:
		return
	if camera_bullet_time_ON:
		return
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens_mult = SaveManager.config.get("sensitivity_aim", 0.4) if is_aiming else SaveManager.config.get("sensitivity_look", 1.0)
		
		# Aplica a rotação horizontal no corpo (Maycow)
		rotate_y(-event.relative.x * SENSITIVITY * sens_mult)
		
		# Aplica a rotação vertical na câmera atual
		var camera_atual = get_viewport().get_camera_3d()
		
		# Trava o ângulo vertical (modifica rotation.x diretamente para evitar 'flip' do Euler)
		var _lim := _limites_pitch(camera_atual)
		var v_down = _lim.x
		var v_up = _lim.y
		
		var target_pitch = camera_atual.rotation.x - (event.relative.y * SENSITIVITY * sens_mult)
		camera_atual.rotation.x = clamp(target_pitch, deg_to_rad(v_down), deg_to_rad(v_up))


# Adicione estas variáveis no topo do script (fora do _process) se ainda não tiver
var hold_timer: float = 0.0
var hold_threshold: float = 0.15 # 200 milisegundos para confirmar o "segurar"
var limite_rotacao_lateral = deg_to_rad(15) # O máximo que ele pode "virar" (ex: 35 graus)
var velocidade_giro = 4.0
## O TRONCO QUASE NÃO ACOMPANHA O STRAFE ENQUANTO ELE MIRA COM A ARMA.
##
## Andando de lado o corpo vira até 27° para acompanhar o passo. Mirando isso é
## demais: os braços estão presos a um alvo no MUNDO (IK), então o tronco gira
## por baixo deles, o ombro fica torcido contra o braço e a malha entorta.
##
## Sobra este tanto do desvio — o bastante para ele não andar de pedra — e sai
## na metade do ritmo, que é o que tira o "rebolado" do movimento.
var giro_strafe_mirando = 0.22
var ritmo_strafe_mirando = 0.5
## Antes esta funcao espalhava as flags nos DOIS sentidos, e o sentido
## "estatica -> instancia" era um caminho sem volta: bastava a sessao estar
## ligada uma vez pra `infinite_health_test` ficar `true` PARA SEMPRE naquela
## instancia. Como a checagem le `instancia OR sessao`, desligar pela aba DEBUG
## nao surtia efeito nenhum — o botao parecia morto.
##
## Agora os dois mecanismos sao independentes:
##   - a caixinha do editor liga a flag SO naquela instancia (uso manual);
##   - a aba DEBUG liga/desliga a sessao inteira, em RAM, e manda de verdade.
## Nenhum dos dois vai para o save: fechar o jogo zera os dois.
func _sincroniza_flags_de_teste() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null: return

	_atualizar_mira_lanterna(delta)
	
	if damage_blur_timer > 0.0:
		damage_blur_timer -= delta

	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			speed_multiplier = 1.0
	
	# --- CUTSCENE CAMERA SHAKE ---
	if _cutscene_camera_shake_intensity > 0.0 and is_instance_valid(camera_third_person):
		if not _is_cutscene_shaking:
			_cutscene_shake_h_base = camera_third_person.h_offset
			_cutscene_shake_v_base = camera_third_person.v_offset
			_is_cutscene_shaking = true
		
		var forca = _cutscene_camera_shake_intensity * 0.1
		camera_third_person.h_offset = _cutscene_shake_h_base + randf_range(-forca, forca)
		camera_third_person.v_offset = _cutscene_shake_v_base + randf_range(-forca, forca)
	elif _is_cutscene_shaking and is_instance_valid(camera_third_person):
		_is_cutscene_shaking = false
		camera_third_person.h_offset = _cutscene_shake_h_base
		camera_third_person.v_offset = _cutscene_shake_v_base
		
	if is_using_ultimate or cogblade_menu_open:
		# Processa a gravidade caso ele estivesse caindo no momento, 
		# e processa o combate para que a cogblade possa girar e voar.
		if not is_on_floor():
			velocity += get_gravity() * delta
		var vel_pre := velocity
		move_and_slide()
		_empurrar_corpos_fisicos(vel_pre)

		var combat_comp = get_node_or_null("PlayerCombat")
		if combat_comp: combat_comp.process_combat(delta)

		return

	var is_in_house = get_tree().current_scene.name == "the_house" if get_tree() and get_tree().current_scene else false
	var can_run_normal = GlobalEvents.is_maycow_normal and not is_in_house
	var stamina_active = not GlobalEvents.is_maycow_normal or can_run_normal
	# O Maycow normal tem estamina infinita (não cansa correndo pela cidade):
	# a barra nunca faz sentido pra ele, prólogo incluso.
	var show_stamina_bar = stamina_active and not GlobalEvents.is_maycow_normal
	
	var camera_atual_check = get_viewport().get_camera_3d()
	var current_camera_rot_x = camera_atual_check.rotation.x if camera_atual_check else 0.0
	var giro_do_corpo = abs(rotation.y - last_rotation_y)
	var is_turning_camera = giro_do_corpo > 0.001 or abs(current_camera_rot_x - last_camera_rot_x) > 0.001
	last_rotation_y = rotation.y
	last_camera_rot_x = current_camera_rot_x
	
	if not are_cutscene_inputs_blocked():
		if SaveManager.config.get("run_mode", "hold") == "toggle":
			if Input.is_action_just_pressed("ui_run"):
				_run_toggle_active = not _run_toggle_active
			if velocity.length() < 0.1 or is_aiming or is_exhausted or current_stamina <= 0:
				_run_toggle_active = false
		else:
			_run_toggle_active = Input.is_action_pressed("ui_run")
	else:
		if not _cutscene_auto_run:
			_run_toggle_active = false

	
	# --- STAMINA EXHAUSTION LOGIC ---
	if current_stamina <= 0.5:
		is_exhausted = true
	elif current_stamina >= 25.0:
		is_exhausted = false
		
	# --- STAMINA LOGIC ---
	var is_running_stam = _run_toggle_active and velocity.length() > 0.1 and (current_stamina > 0 or _stamina_infinita() or GlobalEvents.is_maycow_normal) and stamina_active and not is_exhausted and not is_aiming
	if is_running_stam:
		if not _stamina_infinita() and not GlobalEvents.is_maycow_normal:
			current_stamina -= 20.0 * delta
		if current_stamina < 0: current_stamina = 0
		stamina_fade_timer = 2.0
		if is_instance_valid(stamina_bar): stamina_bar.modulate.a = 1.0
	else:
		if current_stamina < max_stamina:
			current_stamina += 15.0 * delta
			if current_stamina > max_stamina: current_stamina = max_stamina
			stamina_fade_timer = 2.0
			if is_instance_valid(stamina_bar): stamina_bar.modulate.a = 1.0
		else:
			if stamina_fade_timer > 0:
				stamina_fade_timer -= delta
			else:
				if is_instance_valid(stamina_bar):
					stamina_bar.modulate.a = move_toward(stamina_bar.modulate.a, 0.0, delta)
	
	if is_instance_valid(stamina_bar):
		stamina_bar.visible = show_stamina_bar
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
		
	if is_instance_valid(mp_bar):
		mp_bar.visible = not GlobalEvents.is_maycow_normal
		mp_bar.max_value = SaveManager.max_mp
		mp_bar.value = SaveManager.current_mp
	# ---------------------

	if is_instance_valid(blood_overlay):
		blood_overlay.visible = not GlobalEvents.in_cutscene
	if is_instance_valid(heartbeat_hud):
		heartbeat_hud.visible = not GlobalEvents.in_cutscene
	
	if is_instance_valid(fall_cam):
		fall_cam.look_at(global_position, Vector3.UP)
		
	if global_position.y < -10.0 and current_health > 0 and not is_falling_dead:
		# Na ARENA cair nao mata mais: uma gargula pega o jogador no ar e o
		# devolve num ponto sorteado do chao (ver
		# scripts/stages/battlefield/resgate_gargula.gd). Em todo o resto do
		# jogo sair do mapa continua sendo morte por queda.
		if not _pedir_resgate_da_arena():
			_trigger_fall_death()

	if are_cutscene_inputs_blocked():
		if is_instance_valid(hand_with_pistol) and hand_with_pistol.visible:
			hand_with_pistol.visible = false
		if is_instance_valid(hand_with_magic) and hand_with_magic.visible:
			hand_with_magic.visible = false
		
	# PARASITE MAYCOW (1ª Pessoa)
	if !GlobalEvents.is_maycow_normal:
	
		# 1. LÓGICA DE MIRA (AIM/ZOOM EM PRIMEIRA PESSOA)
		is_first_person = true # Sempre em primeira pessoa
		
		var cutscene_blocked = are_cutscene_inputs_blocked()
		
		# Força a câmera de 1ª pessoa a ser a atual se não for (ex: ao entrar na cena)
		if not cutscene_blocked and not _cutscene_camera_disabled and not camera.current and not transition_camera and not camera_bullet_time_ON:
			camera.make_current()
			if camera_third_person:
				camera_third_person.current = false
			control_weapons.visible = true
			hand_with_pistol.visible = SaveManager.arma_de_fogo_equipada()
			if hand_with_magic: hand_with_magic.visible = true
			control_magic.visible = true
			
		var wants_to_aim = not cutscene_blocked and Input.is_action_pressed("ui_hold_first_person_view")
		var has_mp = SaveManager.current_mp > 0
		
		if not cutscene_blocked and (Input.is_action_just_released("ui_hold_first_person_view") or (is_aiming and wants_to_aim and not has_mp)):
			if amulet_selected_enemies.size() == 0:
				AudioServer.playback_speed_scale = 1.0
			_on_amulet_magic_released()

		if not cutscene_blocked and wants_to_aim and not has_mp and Input.is_action_just_pressed("ui_hold_first_person_view"):
			if is_instance_valid(gun_load): gun_load.play()

		if cutscene_blocked:
			if hand_with_pistol and hand_with_pistol.visible:
				hand_with_pistol.visible = false
			if hand_with_magic and hand_with_magic.visible:
				hand_with_magic.visible = false
			if control_weapons and control_weapons.visible:
				control_weapons.visible = false
			if control_magic and control_magic.visible:
				control_magic.visible = false
			if is_aiming:
				is_aiming = false
				if amulet_selected_enemies.size() == 0:
					AudioServer.playback_speed_scale = 1.0
				_on_amulet_magic_released()
			elif AudioServer.playback_speed_scale != 1.0 and amulet_selected_enemies.size() == 0:
				AudioServer.playback_speed_scale = 1.0
		elif _was_cutscene_blocked:
			# Acabou de sair de cutscene: restaura mãos e controles para o gameplay
			if not transition_camera and not camera_bullet_time_ON and not is_using_ultimate:
				control_weapons.visible = true
				hand_with_pistol.visible = SaveManager.arma_de_fogo_equipada() and not is_reloading
				if hand_with_magic: hand_with_magic.visible = true
				control_magic.visible = true

		_was_cutscene_blocked = cutscene_blocked

		is_aiming = wants_to_aim and has_mp
		
		if is_aiming:
			SaveManager.current_mp -= 1.5 * delta
			if SaveManager.current_mp < 0: SaveManager.current_mp = 0
			
			if Input.is_action_just_pressed("ui_hold_first_person_view"):
				AudioServer.playback_speed_scale = 0.5
				
			if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
			if point: point.visible = not GlobalEvents.in_cutscene and not _cutscene_hud_hidden
			
			# Ativa o Motion Blur forte
			if is_instance_valid(hud_layer):
				var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
				if motion_blur:
					motion_blur.visible = true
					motion_blur.material.set_shader_parameter("blur_strength", 0.08)
					
			_process_amulet_magic(delta)
			_process_amulet_targeting()
		else:
			if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
			if point: point.visible = not GlobalEvents.in_cutscene and not _cutscene_hud_hidden
			
			# Desativa o Motion Blur
			if is_instance_valid(hud_layer) and not is_playing_return_effect and not is_dashing and damage_blur_timer <= 0.0:
				var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
				if motion_blur:
					motion_blur.material.set_shader_parameter("blur_strength", 0.0)
					motion_blur.visible = false
					
			_hide_amulet_magic()
			_clear_amulet_hover()
		
		# 3. GRAVIDADE
		if not is_on_floor():
			velocity += get_gravity() * delta

		# 4. PULO E RECARGA
		if not are_cutscene_inputs_blocked():
			if Input.is_action_just_pressed("ui_accept") and is_on_floor():
				velocity.y = JUMP_VELOCITY
				playback.travel("jump")
				
			if Input.is_action_just_pressed("ui_reload") and !transition_camera and !is_magic_attacking:
				reload()
			
			if Input.is_action_just_pressed("ui_shoot") and !transition_camera and !is_using_ultimate and !cogblade_melee_active:
				shoot(Input)
			
			# O Cogblade Thrown saiu do botão Y: agora ele é uma das opções da
			# roda de poderes da cogblade (segurar L1 / C, ver
			# player_cogblade_menu.gd). O botão Y fica livre para outra ação.
			
		if camera_bullet_time_ON:
			return
			
		# 5. ROTAÇÃO DA CÂMERA (ANALÓGICO DIREITO)
		if !camera_bullet_time_ON and not are_cutscene_inputs_blocked():
			var joy_dir = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
			if joy_dir.length() > DEADZONE:
				var camera_atual = get_viewport().get_camera_3d()
				
				# Girar o corpo (Horizontal) - multiplicado por delta para suavidade
				var sens_mult = SaveManager.config.get("sensitivity_aim", 0.4) if is_aiming else SaveManager.config.get("sensitivity_look", 1.0)
				rotate_y(-joy_dir.x * JOY_SENSITIVITY * sens_mult * delta * 100)
				
				# Girar a câmera (Vertical) evitando flip
				var _lim := _limites_pitch(camera_atual)
				var v_down = _lim.x
				var v_up = _lim.y
				
				var target_pitch = camera_atual.rotation.x - (joy_dir.y * JOY_SENSITIVITY * sens_mult * delta * 100)
				camera_atual.rotation.x = clamp(target_pitch, deg_to_rad(v_down), deg_to_rad(v_up))
	
		# 6. GESTÃO DO DASH (COOLDOWN E EXECUÇÃO)
		if dash_cooldown_timer > 0:
			dash_cooldown_timer -= delta

		if not are_cutscene_inputs_blocked() and Input.is_action_just_pressed("ui_dash") and not GlobalEvents.dash_bloqueado() and not is_dashing and dash_cooldown_timer <= 0 and (current_stamina >= 30.0 or _stamina_infinita()):
			if not _stamina_infinita():
				current_stamina -= 30.0
			stamina_fade_timer = 2.0
			stamina_bar.modulate.a = 1.0
			dash()
			

		# 7. MOVIMENTAÇÃO (DASH VS CAMINHADA)
		# ANDAR NÃO LÊ `ui_left`/`ui_right` — LÊ `ui_mover_*`.
		#
		# O direcional do controle (D-pad) continua em `ui_left` e companhia,
		# porque é ele que navega nos menus. O que ele não faz mais é ANDAR: o
		# D-pad agora é dos atalhos de equipamento (`player_atalhos.gd`), e
		# trocar de item não pode dar um passo para o lado junto.
		#
		# `ui_mover_*` é a mesma coisa sem o D-pad: analógico esquerdo, WASD e
		# as setas do teclado.
		var input_dir := Input.get_vector("ui_mover_esquerda", "ui_mover_direita", "ui_mover_cima", "ui_mover_baixo")
		
		# --- CUTSCENE INPUT OVERRIDES ---
		if are_cutscene_inputs_blocked():
			input_dir = Vector2.ZERO
		if _cutscene_auto_walk:
			input_dir.y = -1.0
			_run_toggle_active = false
		if _cutscene_auto_run:
			input_dir.y = -1.0
			_run_toggle_active = true
		
		# No seu item 7 do _physics_process:
		if is_dashing:
			# MOVIMENTO DE DASH
			velocity.x = dash_direction.x * DASH_SPEED
			velocity.z = dash_direction.z * DASH_SPEED
			
			dash_timer -= delta
			if dash_timer <= 0:
				is_dashing = false
		else:
			# MOVIMENTO NORMAL (WALK/RUN)
			var velocidade_atual = WALK_SPEED
			if GlobalEvents.in_cutscene and _cutscene_auto_walk:
				velocidade_atual = WALK_SPEED * 0.45
			elif is_aiming:
				velocidade_atual = WALK_SPEED * 0.4
			elif _run_toggle_active and (current_stamina > 0 or _stamina_infinita()) and not is_exhausted:
				velocidade_atual = RUN_SPEED
			
			# Mais lento ao andar para trás
			if input_dir.y > 0.1:
				velocidade_atual *= 0.65
			velocidade_atual *= speed_multiplier
				
			var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var velocity_Y_zero: bool = velocity.y <= 0

			if direction and !transition_camera:
				var is_actually_running = _run_toggle_active and (current_stamina > 0 or _stamina_infinita()) and not is_exhausted and not is_aiming

				# Animações e Sons
				if is_actually_running:
					if pistola.animation not in ["reload", "run"]: pistola.play("run")
					if is_on_floor() and velocity_Y_zero: playback.travel("run")
				else:
					if pistola.animation not in ["reload", "walk"]: pistola.play("walk")
					if is_on_floor() and velocity_Y_zero: playback.travel("walk")
				
				if !passos.playing and is_on_floor():
					var cutscene_boost = 8.0 if GlobalEvents.in_cutscene else 0.0
					if is_actually_running:
						passos.pitch_scale = randf_range(1.15, 1.3)
						passos.volume_db = randf_range(-12.0, -9.0) + cutscene_boost
					else:
						passos.pitch_scale = randf_range(0.65, 0.75)
						passos.volume_db = randf_range(-15.0, -12.0) + (cutscene_boost * 0.5)
					_passo_pe_alternado = !_passo_pe_alternado
					if _passo_pe_alternado:
						passos.volume_db -= 4.0
						passos.pitch_scale -= 0.08
					passos.play()
				
				velocity.x = direction.x * velocidade_atual
				velocity.z = direction.z * velocidade_atual
			else:
				# IDLE / PARADA
				if is_on_floor() and velocity_Y_zero: playback.travel("idle")
				velocity.x = move_toward(velocity.x, 0, velocidade_atual)
				velocity.z = move_toward(velocity.z, 0, velocidade_atual)
				if passos.playing: passos.stop()
		
		# FX DURANTE CORRIDA (FOV e Blur leve - Diferenciado para 1ª Pessoa e 3ª Pessoa)
		var camera = get_viewport().get_camera_3d()
		if camera and not is_dashing:
			var is_running = _run_toggle_active and velocity.length() > 0.1 and (current_stamina > 0 or _stamina_infinita()) and not is_exhausted and not is_aiming
			var direction_check := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var visao_frente = -global_transform.basis.z
			var alinhamento = direction_check.dot(visao_frente) if direction_check else 0.0
			
			var target_run_fov = 75.0
			if is_aiming:
				target_run_fov = 50.0
			elif direction_check and alinhamento < -0.2:
				target_run_fov = 73.0 if is_first_person else 70.0
			elif is_running:
				target_run_fov = 80.0 if is_first_person else 88.0
				
			if not is_first_person and input_dir.length() < 0.1 and not is_aiming:
				target_run_fov -= 12.0
				
			var cur_fov_speed = 5.0
			if is_aiming:
				cur_fov_speed = 8.0
			elif not is_running and not is_first_person:
				cur_fov_speed = 0.8
				
			if not are_cutscene_inputs_blocked() and not _cutscene_camera_disabled and camera and camera.current:
				camera.fov = lerp(camera.fov, target_run_fov, cur_fov_speed * delta)
			


		# 8. ROTAÇÃO VISUAL DO MODELO (MAYCOW LOPES)
		if input_dir.y <= 0.1: 
			var alvo_y = PI 
			var alvo_pos_x = 0.0
			var speed_y = 0.6
			var speed_x = 5.0
			if input_dir.x > 0: 
				alvo_y = PI - (limite_rotacao_lateral * 1.5) 
			elif input_dir.x < -0.1: 
				alvo_y = PI + (limite_rotacao_lateral * 1.8) 
				speed_y = 0.6
				speed_x = 1.5
				var current_is_running = _run_toggle_active and velocity.length() > 0.1 and (current_stamina > 0 or _stamina_infinita()) and not is_exhausted and not is_aiming
				if not current_is_running:
					alvo_pos_x = -0.15

			var modelo = get_node_or_null("maycow_lopes")
			if modelo:
				modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_y, delta * velocidade_giro * speed_y)
				modelo.position.x = lerp(modelo.position.x, alvo_pos_x, speed_x * delta)
		
	# DAQUI PRA FRENTE É O MAYCOW SEM PODERES (E NORMAL APOS PROLOGO)
	else:
		var cutscene_blocked = are_cutscene_inputs_blocked()
		var normal_can_aim = SaveManager.prolog_finished and not cutscene_blocked
		if cutscene_blocked:
			if is_aiming:
				is_aiming = false
				if amulet_selected_enemies.size() == 0:
					AudioServer.playback_speed_scale = 1.0
				_on_amulet_magic_released()
			elif AudioServer.playback_speed_scale != 1.0 and amulet_selected_enemies.size() == 0:
				AudioServer.playback_speed_scale = 1.0

		is_aiming = normal_can_aim and Input.is_action_pressed("ui_hold_first_person_view")

		# A troca de câmera para 1ª pessoa é controlada pelo poder do amuleto
		# (player_amulet.gd), que faz o zoom gradual da 3ª pessoa antes de trocar.
		if not are_cutscene_inputs_blocked() and not _cutscene_camera_disabled and not is_first_person:
			if camera_third_person and not camera_third_person.current:
				camera_third_person.make_current()

		# O MESMO botao de mira, duas mecanicas. Quem escolhe e' o item equipado:
		# com o AMULETO a mira marca inimigos e os leva pra arena; com a PISTOLA
		# ela levanta a arma em terceira pessoa e o gatilho vira tiro. Os dois
		# nunca estao equipados juntos (SaveManager.EQUIPAMENTO_EXCLUSIVO), entao
		# a escolha feita no menu chega aqui como um `if`.
		var mira_de_arma: bool = SaveManager.is_equipped("pistol") \
			or SaveManager.is_equipped("shotgun")

		if normal_can_aim and mira_de_arma:
			_processar_mira_de_arma()
		elif normal_can_aim:
			# Trocar de item NO MEIO de uma mirada cai aqui: sem isto, a mira da
			# arma ficaria acesa na tela enquanto o poder do amuleto abre por
			# baixo dela.
			_encerrar_mira_de_arma()

			if Input.is_action_just_released("ui_hold_first_person_view"):
				if amulet_selected_enemies.size() == 0:
					AudioServer.playback_speed_scale = 1.0
				_on_amulet_magic_released()

			if is_aiming:
				if Input.is_action_just_pressed("ui_hold_first_person_view"):
					AudioServer.playback_speed_scale = 0.5

				if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = true
				if point: point.visible = false

				if is_instance_valid(hud_layer):
					var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
					if motion_blur:
						motion_blur.visible = true
						motion_blur.material.set_shader_parameter("blur_strength", 0.08)

				_process_amulet_magic(delta)
			else:
				if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
				if point: point.visible = not GlobalEvents.in_cutscene and not _cutscene_hud_hidden
				
				if is_instance_valid(hud_layer) and not is_playing_return_effect and not is_dashing and damage_blur_timer <= 0.0:
					var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
					if motion_blur:
						motion_blur.material.set_shader_parameter("blur_strength", 0.0)
						motion_blur.visible = false
						
				_hide_amulet_magic()
				_clear_amulet_hover()
				
			# "ui_magic_attack" (Q / Y) ainda não tem função no Maycow normal.
			# O ataque da cogblade é exclusivo do Maycow parasita.
		else:
			if is_instance_valid(amulet_crosshair): amulet_crosshair.visible = false
			_encerrar_mira_de_arma()
			if is_instance_valid(hud_layer) and not is_playing_return_effect and not is_dashing and damage_blur_timer <= 0.0:
				var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
				if motion_blur:
					motion_blur.material.set_shader_parameter("blur_strength", 0.0)
					motion_blur.visible = false
			_hide_amulet_magic()
			_clear_amulet_hover()
		
		# 3. GRAVIDADE
		if not is_on_floor():
			velocity += get_gravity() * delta

		# 5. ROTAÇÃO DA CÂMERA (ANALÓGICO DIREITO)
		if !camera_bullet_time_ON and not are_cutscene_inputs_blocked():
			var joy_dir = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
			if joy_dir.length() > DEADZONE:
				var camera_atual = get_viewport().get_camera_3d()
				var sens_mult = SaveManager.config.get("sensitivity_look", 1.0)
				
				# Girar o corpo (Horizontal) - multiplicado por delta para suavidade
				rotate_y(-joy_dir.x * JOY_SENSITIVITY * sens_mult * delta * 100)
				
				# Girar a câmera (Vertical) evitando flip
				var _lim := _limites_pitch(camera_atual)
				var v_down = _lim.x
				var v_up = _lim.y
				
				var target_pitch = camera_atual.rotation.x - (joy_dir.y * JOY_SENSITIVITY * sens_mult * delta * 100)
				camera_atual.rotation.x = clamp(target_pitch, deg_to_rad(v_down), deg_to_rad(v_up))
			

		# 7. MOVIMENTAÇÃO (DASH VS CAMINHADA)
		# Mesma leitura de movimento do Maycow parasita, acima: `ui_mover_*` é
		# `ui_left` e companhia SEM o D-pad, que agora só troca de equipamento.
		var input_dir := Input.get_vector("ui_mover_esquerda", "ui_mover_direita", "ui_mover_cima", "ui_mover_baixo")
		
		# --- CUTSCENE INPUT OVERRIDES ---
		if are_cutscene_inputs_blocked():
			input_dir = Vector2.ZERO
		if _cutscene_auto_walk:
			input_dir.y = -1.0
			_run_toggle_active = false
		if _cutscene_auto_run:
			input_dir.y = -1.0
			_run_toggle_active = true
		# MOVIMENTO NORMAL (WALK/RUN)
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		# O quanto o movimento aponta para a frente do corpo. É o mesmo número
		# que decide o "walk_back" mais abaixo; aqui ele também decide se a
		# corrida vale. Parado (sem direção), 1.0 para não atrapalhar nada.
		var visao_frente := -global_transform.basis.z
		var alinhamento := direction.dot(visao_frente) if direction else 1.0

		var is_running = _run_toggle_active and velocity.length() > 0.1 and (current_stamina > 0 or _stamina_infinita()) and can_run_normal and not is_exhausted and not is_aiming
		# Correr só para frente (e na diagonal). Indo totalmente de lado com a
		# câmera apontada para frente, a corrida é cortada e ele volta a andar —
		# animação E velocidade — do mesmo jeito que já acontecia de costas.
		if alinhamento < CORRIDA_ALINHAMENTO_MIN:
			is_running = false

		# A caçadeira recolhe a ponta do cano quando ele corre. Quem sabe que
		# ele está correndo é aqui, então é daqui que o componente fica sabendo
		# — mesmo caminho do `mirar`, que também é empurrado, não lido.
		var correndo_hold := _shotgun_hold()
		if correndo_hold:
			correndo_hold.correr(is_running)

		var velocidade_atual = _velocidade_corrida() if is_running else _velocidade_caminhada()
		if input_dir.y > 0.1:
			velocidade_atual *= 0.65
		velocidade_atual *= speed_multiplier
		var velocity_Y_zero: bool = velocity.y <= 0
		var target_fov: float = 75.0
		if is_aiming:
			if is_first_person:
				target_fov = 75.0 # Primeira pessoa fica com FOV normal
			elif mira_de_arma:
				# A mira de ARMA fecha menos. O 40 abaixo é do amuleto, e é
				# fechado de propósito: lá a câmera acaba entrando em 1ª pessoa,
				# então o zoom é o começo dessa viagem. Aqui ela FICA em 3ª
				# pessoa — o jogador precisa continuar vendo o Maycow levantar a
				# arma e o que está em volta dele.
				target_fov = FOV_MIRA_ARMA
			else:
				target_fov = 40.0 # Zoom IN pesado na terceira pessoa (alvo)

		if direction:
			# Andando de verdade a animação roda na velocidade dela — só a
			# corrida em interior fica um tiquinho abaixo (`_fator_anim_corrida`).
			_set_anim_time_scale(_fator_anim_corrida(is_running))
			if is_on_floor():
				# De arma na mao ele anda com a animacao de costas, mais
				# lenta — ver `ANIM_MIRA_ANDANDO`. Vale para qualquer
				# direcao, entao este ramo come todos os de baixo.
				if is_aiming and mira_de_arma:
					_set_anim_time_scale(ANIM_MIRA_ANDANDO)
					playback.travel("walk_back")
				# Calcula se a direção do movimento é paralela ou oposta à frente do personagem
				elif alinhamento < -0.2:
					# Movimento para trás
					playback.travel("walk_back")
					if not is_aiming:
						target_fov = 73.0 if is_first_person else 70.0
				else:
					# Movimento para frente ou corrida
					if is_running:
						playback.travel("run")
						if not is_aiming:
							target_fov = 80.0 if is_first_person else 88.0
					else:
						playback.travel("walk")
			
			if !passos.playing and is_on_floor(): 
				if alinhamento < -0.2:
					passos.pitch_scale = randf_range(0.95, 1.05)
					passos.volume_db = randf_range(-15.0, -12.0)
				elif is_running:
					passos.pitch_scale = randf_range(1.15, 1.3)
					passos.volume_db = randf_range(-12.0, -9.0)
				else:
					passos.pitch_scale = randf_range(0.85, 0.95)
					passos.volume_db = randf_range(-15.0, -12.0)
				_passo_pe_alternado = !_passo_pe_alternado
				if _passo_pe_alternado:
					passos.volume_db -= 4.0
					passos.pitch_scale -= 0.08
				passos.play()
			
			velocity.x = direction.x * velocidade_atual
			velocity.z = direction.z * velocidade_atual
		else:
			# IDLE / PARADA
			if is_on_floor():
				# Parado, ele só dá passos quando está PIVOTANDO (seção 8).
				# Girar a câmera dentro do limite não mexe com ele: fica de
				# costas, plantado, e é a câmera que anda em volta.
				if _pivo_anim > 0.0:
					_pivo_anim = maxf(_pivo_anim - delta, 0.0)
				var dando_passo := _pivotando or _pivo_anim > 0.0
				_set_anim_time_scale(GIRO_ANIM_ESCALA if dando_passo else 1.0)
				if dando_passo:
					playback.travel("walk")
				else:
					playback.travel("idle")
			velocity.x = move_toward(velocity.x, 0, velocidade_atual)
			velocity.z = move_toward(velocity.z, 0, velocidade_atual)
			if passos.playing:
				passos.stop()

		var fov_lerp_speed = 5.0
		if is_aiming:
			fov_lerp_speed = 12.0
		elif not is_running and not is_first_person:
			fov_lerp_speed = 0.8
			
		if not are_cutscene_inputs_blocked() and not _cutscene_camera_disabled:
			var cam_target: Camera3D = null
			if is_first_person and camera and camera.current:
				cam_target = camera
			elif not is_first_person and camera_third_person and camera_third_person.current:
				cam_target = camera_third_person
			if cam_target:
				if not is_first_person and input_dir.length() < 0.1 and not is_aiming:
					target_fov -= 12.0
				cam_target.fov = lerp(cam_target.fov, target_fov, fov_lerp_speed * delta)


		# 8. ROTAÇÃO VISUAL E POSIÇÃO DO MODELO (MAYCOW LOPES NORMAL)
		var modelo = get_node_or_null("maycow_lopes_normal")
		if modelo:
			var alvo_y = 0.0
			var speed_y = 0.6
			if input_dir.y <= 0.1: 
				if input_dir.x > 0: 
					alvo_y = -(limite_rotacao_lateral * 1.5) 
				elif input_dir.x < -0.1: 
					alvo_y = (limite_rotacao_lateral * 1.8) 
					speed_y = 0.6
			# COM A CAÇADEIRA, O TRONCO NÃO VIRA PRA ESQUERDA.
			#
			# `alvo_y` positivo gira o modelo pro lado esquerdo DELE, e é esse
			# giro que traz a omoplata esquerda pra frente da câmera — que é
			# justamente onde a malha deforma (ver o README da caçadeira: o
			# braço esquerdo fica travado no limite de alcance e não há conserto
			# de ombro que não mexa na pose afinada à mão).
			#
			# Só o lado esquerdo é cortado. O `minf` deixa o giro pra direita
			# (negativo) intacto, e o pivô do corpo parado também: aquele não é
			# o modelo girando, é o modelo ficando PLANTADO enquanto a câmera
			# orbita — quem revela as costas lá é a câmera, não isto.
			if SaveManager.is_equipped("shotgun"):
				alvo_y = minf(alvo_y, 0.0)
			# Mirando com a arma, o tronco quase não acompanha (ver
			# `giro_strafe_mirando`). Só com a arma: na mira do amuleto não há
			# braço preso a alvo nenhum pra brigar com o tronco.
			if is_aiming and mira_de_arma:
				alvo_y *= giro_strafe_mirando
				speed_y *= ritmo_strafe_mirando
			# ANDANDO, CORRENDO, MIRANDO OU EM CUTSCENE: exatamente como
			# sempre foi. O corpo é o do jogador, com o desvio lateral do
			# strafe, e vira junto com a câmera no mesmo quadro. O pivô não
			# tem vez aqui — foi o que deixou a câmera estranha em movimento.
			# A inclinacao do strafe e' perseguida FORA do if/else: parado o
			# `alvo_y` ja' e' zero, entao ela se desfaz sozinha, no mesmo
			# ritmo, em vez de sumir de um quadro pro outro.
			_inclinacao_strafe = lerp_angle(_inclinacao_strafe, alvo_y, delta * velocidade_giro * speed_y)
			if direction or is_aiming or are_cutscene_inputs_blocked():
				_pivotando = false
				_pivo_anim = 0.0
				# O corpo acompanha a camera: o que ele guarda aqui e' o yaw do
				# JOGADOR, sem a inclinacao do strafe. Com ela dentro, soltar o
				# controle fazia o pivo comecar ja' torto.
				_yaw_corpo = rotation.y
				_yaw_corpo_pronto = true
				# O deslocamento volta ao normal no mesmo ritmo em que o corpo
				# se realinha — assim sair do pivô andando não dá tranco.
				_atraso_pivo = lerp_angle(_atraso_pivo, 0.0, delta * velocidade_giro * speed_y)
			else:
				# PARADO: o corpo fica plantado até a câmera passar do limite.
				if not _yaw_corpo_pronto:
					_yaw_corpo = rotation.y
					_yaw_corpo_pronto = true
				var falta := wrapf(rotation.y - _yaw_corpo, -PI, PI)
				# `falta` negativo = a câmera foi pra DIREITA dele, e esse lado
				# tem gatilho mais curto (ver GIRO_LIMITE_DIREITA).
				var limite := deg_to_rad(GIRO_LIMITE_DIREITA if falta < 0.0 \
					else GIRO_LIMITE)
				var soltura := deg_to_rad(GIRO_SOLTA_DIREITA if falta < 0.0 \
					else GIRO_SOLTA)
				if not _pivotando and absf(falta) >= limite:
					_pivotando = true
					_pivo_anim = maxf(_pivo_anim, GIRO_ANIM_MINIMO)
				if _pivotando:
					var vel := GIRO_VEL_CORPO
					var excesso := absf(falta) - limite
					if excesso > 0.0:
						vel += excesso * GIRO_ALCANCE
					# O `minf` é o que impede ele de passar do alvo e ficar
					# indo e voltando em cima dele.
					_yaw_corpo += signf(falta) * minf(vel * delta, absf(falta))
					if absf(wrapf(rotation.y - _yaw_corpo, -PI, PI)) <= soltura:
						_pivotando = false
				_atraso_pivo = wrapf(_yaw_corpo - rotation.y, -PI, PI)

			# O que se ve' e' o pivo MAIS a inclinacao do strafe; o que gira o
			# deslocamento, la' embaixo, e' so' o pivo.
			modelo.rotation.y = _atraso_pivo + _inclinacao_strafe
			
			var is_walking_back = direction and direction.dot(-global_transform.basis.z) < -0.2
			var target_pos_x = 0.0
			var target_pos_z = 0.3995
			if is_running:
				target_pos_x = normal_run_offset_x
				target_pos_z = normal_run_offset_z
			elif is_walking_back:
				target_pos_x = normal_walkback_offset_x
				target_pos_z = normal_walkback_offset_z
				
			var speed_x = 2.0
			if input_dir.x < -0.1:
				speed_x = 1.0
				if not is_running:
					target_pos_x -= 0.15

			# O alvo é perseguido em dois passos (ver ENQUADRAMENTO_ALVO): o de
			# cima suaviza o alvo, o de baixo persegue o alvo já suavizado. É o
			# que tira o tranco de quando a corrida acaba.
			_alvo_corpo_x = lerp(_alvo_corpo_x, target_pos_x, ENQUADRAMENTO_ALVO * delta)
			_alvo_corpo_z = lerp(_alvo_corpo_z, target_pos_z, ENQUADRAMENTO_ALVO * delta)
			_off_corpo_x = lerp(_off_corpo_x, _alvo_corpo_x, speed_x * delta)
			_off_corpo_z = lerp(_off_corpo_z, _alvo_corpo_z, ENQUADRAMENTO_CORPO * delta)
			# O DESLOCAMENTO TEM DE GIRAR JUNTO COM O ATRASO DO PIVÔ.
			#
			# Os ~40 cm de enquadramento vivem no espaço do JOGADOR, que gira
			# com a câmera. Parado, o corpo não gira mais junto — então, sem
			# esta conta, o Maycow desliza num círculo de 40 cm enquanto a
			# câmera orbita, em vez de ficar plantado com a câmera correndo em
			# volta dele.
			#
			# Em movimento `_atraso_pivo` é zero e isto vira a conta de antes.
			modelo.position = Basis(Vector3.UP, _atraso_pivo) * Vector3(_off_corpo_x, modelo.position.y, _off_corpo_z)

		# Inclinação e Encolhimento da arma 2D ao correr (bloqueado ao mirar)
		if is_instance_valid(pistola) and typeof(pistol_2d_pos_original) == TYPE_VECTOR2:
			is_running = _run_toggle_active and velocity.length() > 0.1 and current_stamina > 0 and not is_exhausted and not is_aiming
			# Rotação 2D (positivo = horário = descer ponta da arma) e empurrar para baixo/fora da tela
			var target_tilt = deg_to_rad(35.0) if is_running else 0.0
			var target_pos = pistol_2d_pos_original + (Vector2(50.0, 150.0) if is_running else Vector2.ZERO)
			
			pistola.rotation = lerp(pistola.rotation, target_tilt, 12.0 * delta)
			pistola.position = pistola.position.lerp(target_pos, 12.0 * delta)

	# 9. FINALIZAÇÃO
	var vel_antes := velocity
	move_and_slide()
	_empurrar_corpos_fisicos(vel_antes)

	if head_bob_ON:
		head_bob(delta)


	var combat_comp = get_node_or_null("PlayerCombat")
	if combat_comp: combat_comp.process_combat(delta)

	# Esconde o corpo/braços do Maycow (normal ou não-normal) só quando a câmera
	# de 1ª pessoa está realmente ativa — em qualquer outra câmera (3ª pessoa,
	# cutscenes, bullet time) ele continua visível normalmente.
	if is_instance_valid(modelo_visual):
		modelo_visual.visible = (not camera.current) and not _modelo_escondido_por_cena


## `move_and_slide()` so' faz o player deslizar contra um RigidBody3D como se
## fosse parede — CharacterBody3D nao empurra corpo fisico sozinho. Sem isto,
## cadeira e caixa do cenario ficam duras mesmo tendo RigidBody3D de verdade.
##
## `vel_antes` TEM de ser a velocidade de ANTES do `move_and_slide()`: ele
## desconta da `velocity` tudo que bateu no obstaculo, entao quem anda de frente
## numa cadeira chega aqui com velocidade zero — lendo a `velocity` de depois, a
## forca nunca sai e a cadeira parece pregada no chao.
## Tem de VENCER O ATRITO: cadeira de 5 kg parada no chao so' desliza acima de
## ~50 N (atrito 1.0 x massa x gravidade). Forca = esta constante x velocidade
## do player, entao andando (2,2 m/s) da' ~100 N e correndo bate mais forte.
const FORCA_EMPURRAO := 45.0

func _empurrar_corpos_fisicos(vel_antes: Vector3) -> void:
	var vel_horizontal := Vector2(vel_antes.x, vel_antes.z).length()
	if vel_horizontal < 0.05:
		return
	# Teto na velocidade: correndo, a conta passaria de 150 N e a cadeira sairia
	# voando pela sala em vez de ser empurrada.
	vel_horizontal = minf(vel_horizontal, 2.6)
	var passo := get_physics_process_delta_time()
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		var corpo := colisao.get_collider()
		if not (corpo is RigidBody3D):
			continue
		var direcao := -colisao.get_normal()
		direcao.y = 0.0
		if direcao.length() < 0.01:
			continue
		# Cadeira assentada DORME, e corpo dormindo descarta forca calada —
		# `apply_force` nao acorda ninguem. Sem este `sleeping = false` o
		# empurrao existe no papel e nao acontece nada na tela.
		corpo.sleeping = false
		# No ponto de CONTATO, nao no centro de massa: e' o que faz a cadeira
		# girar ao ser esbarrada de lado, em vez de deslizar reta e de pe'. O
		# teto na altura segura o tombo: o contato vem na altura do peito do
		# player, e la' em cima o empurrao capota a cadeira em vez de arrastar.
		var ponto: Vector3 = colisao.get_position() - corpo.global_position
		ponto.y = minf(ponto.y, 0.6)
		corpo.apply_impulse(direcao.normalized() * FORCA_EMPURRAO * vel_horizontal * passo, ponto)


func dash():
	var comp = get_node_or_null("PlayerDash")
	if comp: comp.dash()

func head_bob(delta: float):
	t_bob += delta * velocity.length() * float(is_on_floor())
	
	var cam_atual: Camera3D
	var marker_referencia: Marker3D # Precisamos saber onde a câmera DEVERIA estar
	
	if is_first_person:
		cam_atual = camera
		marker_referencia = camera_first_person_marker
	else:
		cam_atual = camera_third_person
		marker_referencia = camera_third_person_marker
	
	var ajuste_intensidade = 0.3 # Bem suave para caminhada padrão
	if _run_toggle_active and not is_aiming:
		bob_freq = 2.1
		
		if is_first_person:
			ajuste_intensidade = 0.7 # Corrida mais suave, menos violenta
			bob_freq = 3.0           # Frequência reduzida para balançar mais lentamente
	else:
		bob_freq = 2.0
		
	var pos_bob = Vector3.ZERO
	if is_on_floor() and velocity.length() > 0.1:
		pos_bob.y = sin(t_bob * bob_freq) * bob_amp * ajuste_intensidade
		pos_bob.x = cos(t_bob * bob_freq * 0.5) * bob_amp * 0.5 * ajuste_intensidade
	
	# Mantém a câmera colada no marker com o balanço
	if !transition_camera:
		cam_atual.global_transform.origin = marker_referencia.global_transform.origin + pos_bob
	

# Função auxiliar para não repetir código
func transicao_camera(origem: Camera3D, camera_destino: Camera3D, destino: Marker3D, show_ui: bool):
	transition_camera = true
	#COLOCA CADA CAMERA NO SEU LUGAR ANTES DE PROCESSAR
	camera.global_transform = camera_first_person_marker.global_transform
	camera_third_person.global_transform = camera_third_person_marker.global_transform
	
	# Mostra/Esconde a UI rapido pra nao ficar estranho se for pra esconder a arma
	if camera_destino == camera_third_person:
		control_magic.visible = show_ui
		control_weapons.visible = show_ui
		hand_with_pistol.visible = show_ui and SaveManager.arma_de_fogo_equipada()
		if hand_with_magic: hand_with_magic.visible = show_ui
		await get_tree().create_timer(0.1).timeout
		GlobalUtils.remover_camera_lenta()
	else:
		load_gun.play()
		

	# IMPORTANTE: Garante que a câmera que vai "viajar" seja a atual
	origem.make_current()

	var tween = create_tween()
	# Fazemos a câmera que está ativa (origem) viajar até o lugar da outra (destino)
	tween.tween_property(origem, "global_transform", destino.global_transform, 0.15)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)

	# Quando o movimento acabar, garantimos que o foco mude oficialmente para a câmera de destino
	tween.finished.connect(func(): 
		if !camera_bullet_time_ON:
			camera_destino.make_current()
		
		transition_camera = false
		# FAZER A ARMA VIM SURGINDO DE BAIXO PRA CIMA DEPOIS
		# TODO: FAZER
		# Mostra/Esconde a UI com delay pra nao ficar estranho
		control_magic.visible = show_ui
		control_weapons.visible = show_ui
		hand_with_pistol.visible = show_ui and SaveManager.arma_de_fogo_equipada()
		if hand_with_magic: hand_with_magic.visible = show_ui
		)
	
	
	
	

func reload():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.reload()

func magic_hand_attack():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.magic_hand_attack()

func cast_spell():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.cast_spell()

func shoot(input:Variant):
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.shoot(input)

func raycast_process_shoot():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.raycast_process_shoot()

func bullet_time_back():
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.bullet_time_back()

func spawn_blood_raycast(pos, normal):
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.spawn_blood_raycast(pos, normal)

func spawn_blood_effect(body: Node3D):
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.spawn_blood_effect(body)

## Deixa o jogador mais lento por um tempo. Chamado pelo anel de magia do
## Shadow Seraph (`seraph_slow_ring.gd`) quando ele encosta.
##
## Nao empilha: um segundo anel chegando no meio do primeiro vale o efeito mais
## forte e o prazo mais longo dos dois, em vez de multiplicar um pelo outro e
## deixar o jogador praticamente parado.
func apply_slow(multiplier: float, duration: float) -> void:
	speed_multiplier = minf(speed_multiplier, clampf(multiplier, 0.05, 1.0))
	_slow_timer = maxf(_slow_timer, duration)


## Tira a lentidao na hora (fim de batalha, respawn, cutscene).
func clear_slow() -> void:
	speed_multiplier = 1.0
	_slow_timer = 0.0


func take_damage(number:int):
	if invulnerable:
		return
	if GlobalEvents.in_cutscene:
		return
	if is_using_ultimate:
		return
	if current_health <= 0:
		return

	# Teste de vida infinita: zera o valor aqui em vez de sair da funcao, pra
	# todo o retorno do golpe (sangue, tremor, vibracao, blur) continuar
	# rodando logo abaixo.
	if infinite_health_test or _vida_infinita_na_sessao:
		number = 0

	current_health -= number
	if current_health <= 0:
		current_health = 0
		_play_death_sound()
		_trigger_game_over()
		
	GlobalUtils.vibrate_controller(Input, 0.5, 0.5, 0.2)
	GlobalUtils.shake_camera(damage_camera_shake_duration, damage_camera_shake_strength)
	
	if is_instance_valid(blood_overlay):
		var mat = blood_overlay.material as ShaderMaterial
		mat.set_shader_parameter("multiplier", 0.4)
		var t = create_tween()
		t.tween_method(func(val): mat.set_shader_parameter("multiplier", val), 0.4, 0.0, 1.5).set_trans(Tween.TRANS_CUBIC)
	
	if is_instance_valid(hud_layer):
		var motion_blur = hud_layer.get_node_or_null("MotionBlurOverlay")
		if motion_blur:
			if damage_blur_tween and damage_blur_tween.is_valid():
				damage_blur_tween.kill()
			motion_blur.visible = true
			motion_blur.material.set_shader_parameter("blur_strength", 0.8)
			damage_blur_timer = 0.35
			damage_blur_tween = create_tween()
			damage_blur_tween.tween_property(motion_blur.material, "shader_parameter/blur_strength", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			damage_blur_tween.tween_callback(func(): 
				if is_instance_valid(motion_blur) and not is_aiming and not is_dashing:
					motion_blur.visible = false
			)
	
	print("Damage taken by the player: "+str(number) + " | HP: " + str(current_health))
	
	_start_heartbeat_pulse()

## Pergunta a cena atual se ELA assume o jogador que caiu do mapa. true = a
## cena tomou conta e ninguem mais deve mata-lo.
##
## Hoje so' a arena responde (`battlefield.resgatar_do_abismo`); qualquer outra
## cena nem tem o metodo, devolve false e a morte por queda segue igual.
func _pedir_resgate_da_arena() -> bool:
	if get_tree() == null:
		return false
	var cena := get_tree().current_scene
	if cena != null and cena.has_method("resgatar_do_abismo"):
		return cena.resgatar_do_abismo(self)
	return false


func _trigger_fall_death() -> void:
	if is_falling_dead: return
	is_falling_dead = true
	current_health = 0
	_play_death_sound()
	
	fall_cam = Camera3D.new()
	get_tree().current_scene.add_child(fall_cam)
	fall_cam.global_position = Vector3(global_position.x, 20.0, global_position.z + 12.0)
	fall_cam.make_current()
	
	if is_instance_valid(camera_third_person):
		camera_third_person.current = false
		
	await get_tree().create_timer(3.0).timeout
	_trigger_game_over()

func _play_death_sound() -> void:
	var death_audio = AudioStreamPlayer.new()
	var sound_path = "res://assets/sounds/player/player_death_groan.wav"
	if ResourceLoader.exists(sound_path):
		death_audio.stream = load(sound_path)
		death_audio.volume_db = 2.0
		death_audio.process_mode = Node.PROCESS_MODE_ALWAYS 
		get_tree().root.add_child(death_audio)
		death_audio.play()
		death_audio.finished.connect(func(): death_audio.queue_free())

func _trigger_game_over() -> void:
	if SaveManager.current_stage.contains("oficina_jimmy") or (get_tree().current_scene and get_tree().current_scene.scene_file_path.contains("oficina_jimmy")):
		var fade = get_tree().current_scene.get_node_or_null("fade")
		if fade:
			fade.fade_out()
			await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/stages/prolog/cutscene_end_first_fight.tscn")
		return
		
	var game_over_script = load("res://scripts/ui/game_over.gd")
	if game_over_script:
		var game_over_node = CanvasLayer.new()
		game_over_node.set_script(game_over_script)
		get_tree().root.add_child(game_over_node)

func _on_pistola_animation_finished() -> void:
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._on_area_3d_body_entered(body)

func _on_area_3d_body_exited(body: Node3D) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._on_area_3d_body_exited(body)

func _on_bullet_touch_body_entered(body: Node3D) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._on_bullet_touch_body_entered(body)

func add_cogblade_power(amount: float, source_pos = null) -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.add_cogblade_power(amount, source_pos)

func _start_cogblade_pulse() -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp._start_cogblade_pulse()

func update_equipment_visuals() -> void:
	var comp = get_node_or_null("PlayerCombat")
	if comp: comp.update_equipment_visuals()



func _activate_cogblade_slain() -> void:
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._activate_cogblade_slain()

func _activate_cogblade_cut() -> void:
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._activate_cogblade_cut()

func _activate_cogblade_fire_cross() -> void:
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._activate_cogblade_fire_cross()

func cogblade_melee_slash() -> bool:
	var comp = get_node_or_null("PlayerUltimate")
	if comp: return comp.cogblade_melee_slash()
	return false

func _apply_aoe_damage_slowly(pos: Vector3, damage: int = 30, radius: float = 15.0):
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._apply_aoe_damage_slowly(pos, damage, radius)

func _spawn_explosion_vfx(pos: Vector3):
	var comp = get_node_or_null("PlayerUltimate")
	if comp: comp._spawn_explosion_vfx(pos)

func _process_amulet_magic(delta: float) -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._process_amulet_magic(delta)

func _hide_amulet_magic() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._hide_amulet_magic()

func _process_amulet_targeting() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._process_amulet_targeting()

func _clear_amulet_hover() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._clear_amulet_hover()

func _apply_silhouette(enemy: Node, cor: Color) -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._apply_silhouette(enemy, cor)

func _remove_silhouette(enemy: Node) -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._remove_silhouette(enemy)

func _get_all_meshes(node: Node) -> Array:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: return comp._get_all_meshes(node)
	return []

func _on_amulet_magic_released() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp._on_amulet_magic_released()

## Chamado pelo inimigo que encostou no Maycow FORA da arena (ver enemy.gd e os
## outros scripts de inimigo). O inimigo agarra o jogador e a cinemática de
## primeira pessoa roda a partir daí. true = o toque foi consumido e o inimigo
## não deve aplicar o dano normal dele.
func grab_from_touch(enemy: Node3D) -> bool:
	var comp = get_node_or_null("PlayerGrab")
	if comp: return comp.grab_from_touch(enemy)
	return false

## Batalha forçada pelo toque: o comportamento ANTIGO do encostão na cidade,
## que arrastava o jogador direto para a arena. Nenhum inimigo chama mais isto
## — quem responde ao encostão agora é o `grab_from_touch` acima. Fica de pé,
## inteiro, para o caso de esse encontro voltar a ser desejado em algum ponto
## do jogo: é só chamar daqui.
func force_battle_from_touch(enemy: Node3D) -> bool:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: return comp.force_battle_from_touch(enemy)
	return false

func play_return_from_arena_effect() -> void:
	var comp = get_node_or_null("PlayerAmulet")
	if comp: comp.play_return_from_arena_effect()
func cutscene_set_hud_enabled(enabled: bool) -> void:
	_cutscene_hud_hidden = not enabled
	if is_instance_valid(hud_layer):
		hud_layer.visible = enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_hud_enabled(enabled)

func cutscene_set_player_control(enabled: bool) -> void:
	_cutscene_inputs_disabled = not enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_player_control(enabled)

func cutscene_set_auto_walk(enabled: bool) -> void:
	_cutscene_auto_walk = enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_auto_walk(enabled)

func cutscene_set_auto_run(enabled: bool) -> void:
	_cutscene_auto_run = enabled
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_auto_run(enabled)

func cutscene_set_motion_blur(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_motion_blur(intensity_percent)

func cutscene_set_slow_motion(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_slow_motion(intensity_percent)

func cutscene_set_slow_motion_no_audio(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_slow_motion_no_audio(intensity_percent)

func cutscene_set_camera_shake(intensity_percent: int) -> void:
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_camera_shake(intensity_percent)

func cutscene_set_camera_current(is_current: bool) -> void:
	_cutscene_camera_disabled = not is_current
	var comp = get_node_or_null("PlayerCutscene")
	if comp: comp.cutscene_set_camera_current(is_current)

## Some com o corpo de 3ª pessoa enquanto a cutscene roda (o agarrão troca a
## câmera por uma de 1ª pessoa própria, e o Maycow ficaria de pé dentro dela).
## Tem de ser aqui e não no chamador: `_physics_process` reescreve essa
## visibilidade todo quadro.
func cutscene_set_model_hidden(hidden: bool) -> void:
	_modelo_escondido_por_cena = hidden
	if is_instance_valid(modelo_visual) and hidden:
		modelo_visual.visible = false


# ============================================================
# FOGO DO MAYCOW PARASITA
# ============================================================

# Efeito PRÓPRIO da gameplay (crosta de lava + chama borrada que deixa rastro).
# Não é o hand_fire.tscn do trailer, que tem outra pegada e fica como está.
const PARASITE_FIRE_SCENE := preload("res://scenes/effects/parasite_fire.tscn")

## Só o Maycow NÃO normal pega fogo. A checagem mora aqui na folha, e não só em
## quem chama, para não voltar a acender por engano na variante normal.
@export_group("Fogo do Parasita")
@export var fogo_parasita_ativo: bool = true
## Ossos que delimitam o membro em chamas no corpo de 3ª pessoa (lado ESQUERDO).
@export var fogo_osso_inicio: String = "LeftArm"
@export var fogo_osso_fim: String = "LeftHand"
## Raio da cápsula de fogo em torno do braço (0 = calcula pelo comprimento).
@export var fogo_raio_braco: float = 0.0
## Também põe fogo na mão esquerda de 1ª pessoa (vale para todas as animações
## dela, porque o efeito segue a malha, não a animação).
@export var fogo_na_mao_primeira_pessoa: bool = true
@export var fogo_tamanho_chama: float = 1.0
@export_range(0.0, 1.0) var fogo_opacidade_chama: float = 0.3


func _acender_fogo_parasita() -> void:
	if not fogo_parasita_ativo or GlobalEvents.is_maycow_normal:
		return

	# 1) Braço ESQUERDO do corpo (3ª pessoa / sombra / cutscenes).
	var skel := get_node_or_null("maycow_lopes/Armature/Skeleton3D") as Skeleton3D
	if skel and is_instance_valid(modelo_visual):
		var fogo_braco = PARASITE_FIRE_SCENE.instantiate()
		fogo_braco.name = "fogo_braco_esquerdo"
		fogo_braco.mask_skeleton = skel
		fogo_braco.mask_bone_from = fogo_osso_inicio
		fogo_braco.mask_bone_to = fogo_osso_fim
		fogo_braco.mask_radius = fogo_raio_braco
		fogo_braco.flame_scale = fogo_tamanho_chama
		fogo_braco.flame_opacity = fogo_opacidade_chama
		fogo_braco.fade_in = 1.6
		modelo_visual.add_child(fogo_braco)
		fogo_braco.ignite(modelo_visual)

	# 2) Mão ESQUERDA de 1ª pessoa. São DUAS: a cópia mágica (que é a que
	#    aparece de mãos vazias e com a pistola) e a esquerda da cópia armada
	#    (que é a que segura o fore-end da caçadeira). As duas são a mesma mão
	#    do parasita, então as duas pegam fogo. A direita fica de fora de
	#    propósito.
	if fogo_na_mao_primeira_pessoa:
		_acender_mao_esquerda("Camera3D/hand_with_magic/hand_magic/Armature/Skeleton3D/mao_esq")
		_acender_mao_esquerda("Camera3D/hand_with_pistol/rig/Armature/Skeleton3D/mao_esq")


## Põe fogo em UMA malha de mão esquerda.
##
## O efeito entra como filho da PRÓPRIA MALHA, e não do nó da mão: a malha
## esquerda da cópia armada só aparece com a caçadeira, e visibilidade desce
## pros filhos — assim o fogo some junto com ela sem ninguém ter de lembrar.
##
## E a chama é presa aos OSSOS do antebraço, com a máscara que o efeito já
## tinha para o braço de 3ª pessoa. Sem isso ela se posiciona pela caixa da
## malha, que numa malha com pele é a do DESCANSO — o fogo ficava parado num
## canto da tela enquanto a mão estava em outro lugar.
func _acender_mao_esquerda(caminho: String) -> void:
	var malha := get_node_or_null(caminho) as MeshInstance3D
	if malha == null:
		return
	var fogo = PARASITE_FIRE_SCENE.instantiate()
	fogo.name = "fogo_mao_esquerda"
	fogo.flame_scale = fogo_tamanho_chama
	fogo.flame_opacity = fogo_opacidade_chama
	fogo.fade_in = 1.2
	fogo.mask_skeleton = malha.get_parent() as Skeleton3D
	fogo.mask_bone_from = "antebraco"
	fogo.mask_bone_to = "mao"
	# Em metros, e fixo: o automático é 18% do membro, e estas mãos aparecem
	# a 206% do tamanho — daria uma bola de fogo do tamanho da tela.
	fogo.mask_radius = 0.10
	malha.add_child(fogo)
	fogo.ignite(malha)
