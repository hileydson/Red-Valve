extends Node3D

## ARENA 2 — o Adro Partido.
##
## A segunda arena do jogo. Ao contrário da `battlefield_1`, que é uma
## plataforma de 20 m flutuando no vazio, esta é NO CHÃO: uma praça de catedral
## gótica de 80 m arrasada, aberta e cheia de cobertura, no desenho de arena de
## Doom — o cenário é o terceiro lutador.
##
## O modelo é gerado por `tools/blender/arena_2/gerar_arena_2.py` e a cena por
## `tools/godot/arena_2/gerar_cena_arena_2.py`. Este script cuida só do que é
## comportamento: colisão, fogo que treme e a Boca que respira.
##
## Os inimigos AINDA NÃO nascem aqui. Os marcadores do nó `enemies` já estão
## postos (doze, em volta do adro, fora do escombro e em cima do navmesh), mas
## quem spawna é assunto de outro dia — hoje isto é cenário.
##
## O único perigo que a arena tem por conta própria é o FOGARÉU: o meio do adro
## é uma grelha de ferro sobre a Boca, se anda por cima dela normalmente, e de
## tempos em tempos a coisa lá embaixo cospe fogo pelas barras.

## A layer em que o chão do jogo vive. O player é `CharacterBody3D` com
## `collision_mask = 2`: ele SÓ enxerga a layer 2. O importador de .glb cria o
## StaticBody3D do `-colonly` na layer 1, e o jogador atravessaria a arena
## inteira em queda livre. Corrigir aqui, e não na cena, porque a cena é
## regerada por script e o corpo importado nem aparece nela.
const LAYER_CHAO := 2

# ==============================================================================
# O FOGARÉU
#
# Espera longa e SORTEADA de propósito. O miolo do adro é o melhor lugar da
# arena — é alto, vê os quatro lados e é por onde todo mundo corta caminho — e
# o preço de usá-lo tem de ser um risco que não dá para agendar. Com intervalo
# fixo o jogador conta os segundos e o lugar deixa de ser perigoso; com intervalo
# curto ele simplesmente para de subir ali, e o miolo vira decoração.
#
# A janela de aviso é curta mas suficiente: 1,35 s dá para sair de cima correndo
# (o jogador faz 4,8 m/s e a grelha tem 5 m de raio), e não dá para atravessar
# no susto. Quem ignorar o aviso toma um tique a cada 0,7 s enquanto estiver
# lá dentro — três tiques (33 de 100) se ficar o jato inteiro, longe de matar
# de uma vez mas caro no meio de uma briga.
const FOGAREU_ESPERA_MIN := 26.0
const FOGAREU_ESPERA_MAX := 58.0
const FOGAREU_AVISO := 1.35
const FOGAREU_JATO := 1.9
const FOGAREU_DANO := 11
const FOGAREU_TIQUE := 0.7

enum { FOGAREU_ESPERA, FOGAREU_AVISANDO, FOGAREU_CUSPINDO }

## Luzes com metadata "piscar". Guarda a energia original de cada uma: o tremor
## oscila em torno dela, senão a fogueira e o clarão da Boca acabariam na mesma
## intensidade.
var _lampadas_piscando: Array[Dictionary] = []
var _tempo: float = 0.0

var _fogareu_fase: int = FOGAREU_ESPERA
var _fogareu_prazo: float = 0.0
var _fogareu_tique: float = 0.0
var _jato: GPUParticles3D
var _aviso: GPUParticles3D
var _area_fogareu: Area3D
var _estouro: AudioStreamPlayer3D
var _chiado: AudioStreamPlayer3D
## A luz da Boca é a MESMA que vira o clarão do jato: acender uma omni só para
## a erupção estouraria a cota de 8 por malha do renderer mobile.
var _luz_boca: OmniLight3D
var _luz_boca_energia: float = 0.0
var _luz_boca_alcance: float = 0.0
var _luz_boca_presa: bool = false


func _ready() -> void:
	GlobalEvents.in_cutscene = false
	# Arena = Maycow de batalha, igual à battlefield_1.
	GlobalEvents.is_maycow_normal = false
	# Névoa cheia: são 80 m de praça aberta, e é a névoa que dá profundidade
	# entre o jogador e a ruína do outro lado.
	GlobalEvents.set_high_nevoa()

	_corrigir_colisao()
	_preparar_lampadas()
	_preparar_fogareu()
	_soltar_gargulas()


# ==============================================================================
# AS GÁRGULAS DE FOGO
#
# As mesmas duas da `battlefield_1`. Lá elas pousam nos quatro rochedos de
# canto; aqui o poleiro é o coroamento do anel de ruína — dez pontos em volta
# da praça inteira, de 10 a 38 m de altura. A gárgula fica uns segundos no
# topo batendo asa e então cruza o céu até OUTRO topo sorteado, e o voo arqueia
# para dentro: passa por cima da briga em vez de contornar a borda.
#
# Os pontos NÃO são postos à mão nem podem ser mexidos no editor: quem os
# escolhe é o `pousos()` do gerador do Blender, varrendo o topo de cada módulo
# do anel num heightmap e ficando com a célula mais alta que ainda tem 1,8 m
# de laje firme em volta. Aqui só se lê o nó `pousos` da cena.
#
# ALCANCE DA LUZ: 10 e não os 14 de fábrica. Cada gárgula carrega uma omni, e
# esta arena já gasta 8 (sete fogueiras + a Boca) contra o teto de 8 POR MALHA
# do renderer mobile. Com 14 as duas entravam na AABB do piso e do escombro de
# meio mapa e chutavam fogueira para fora; com 10 nenhuma malha da praça passa
# de cinco. As três que ainda somam dez — o terreiro de cinza, a silhueta do
# horizonte e o arco de carne — têm AABB do tamanho da arena inteira, então
# qualquer luz em qualquer lugar conta para elas; as três vivem da luz
# direcional e não muda nada visível ali.
const GARGULA := preload("res://scenes/effects/fire_gargoyle.tscn")
const GARGULAS := 2
const GARGULA_ALCANCE := 10.0


func _soltar_gargulas() -> void:
	var raiz := get_node_or_null("pousos")
	if raiz == null:
		return
	var poleiros: Array[Node3D] = []
	for p in raiz.get_children():
		if p is Node3D:
			poleiros.append(p as Node3D)
	if poleiros.size() < 2:
		push_warning("arena 2: menos de dois poleiros — cena regerada sem `pousos`?")
		return

	var ninho := Node3D.new()
	ninho.name = "gargulas"
	add_child(ninho)
	# Começam em poleiros OPOSTOS. Nascendo lado a lado, as duas fazem a
	# primeira viagem juntas e metade do céu fica vazia até elas se desgarrarem.
	var passo: int = maxi(1, poleiros.size() / GARGULAS)
	for i in range(GARGULAS):
		var g = GARGULA.instantiate()
		# antes do add_child: o corpo e a luz são montados no `_ready` dela
		g.light_range = GARGULA_ALCANCE
		ninho.add_child(g)
		g.setup(poleiros, (i * passo) % poleiros.size())


## Põe todo corpo estático vindo do .glb na layer do chão.
func _corrigir_colisao() -> void:
	var modelo := get_node_or_null("modelo")
	if modelo == null:
		return
	var achou := false
	for corpo in modelo.find_children("*", "StaticBody3D", true, false):
		corpo.collision_layer = LAYER_CHAO
		corpo.collision_mask = 0
		achou = true
	if not achou:
		push_warning("arena 2: nenhum StaticBody3D no modelo — .glb reimportado "
			+ "sem o objeto CL_arena_2-colonly?")


func _preparar_lampadas() -> void:
	var luzes := get_node_or_null("luzes")
	if luzes == null:
		return
	for luz in luzes.get_children():
		if not (luz is Light3D) or not luz.has_meta("piscar"):
			continue
		_lampadas_piscando.append({
			"luz": luz,
			"tipo": String(luz.get_meta("piscar")),
			"base": (luz as Light3D).light_energy,
			"proximo": 0.0,
			"fase": randf() * TAU,
		})


func _process(delta: float) -> void:
	_tempo += delta
	_fogareu_passo(delta)
	for lamp in _lampadas_piscando:
		var luz: Light3D = lamp["luz"]
		if not is_instance_valid(luz):
			continue
		# enquanto o fogaréu manda na luz da Boca, o pulso fica fora
		if _luz_boca_presa and luz == _luz_boca:
			continue
		if lamp["tipo"] == "pulso":
			# A Boca respira: onda lenta, sem sorteio. É o único ritmo regular
			# da arena, e é de propósito — dá para contar o tempo por ele.
			var t: float = _tempo * 0.7 + float(lamp["fase"])
			luz.light_energy = lamp["base"] * (0.72 + 0.28 * sin(t) + 0.08 * sin(t * 3.1))
			continue
		lamp["proximo"] -= delta
		if lamp["proximo"] > 0.0:
			continue
		# fogueira: tremor curto e irregular
		luz.light_energy = lamp["base"] * randf_range(0.7, 1.22)
		lamp["proximo"] = randf_range(0.05, 0.18)


# ==============================================================================
# O FOGARÉU
# ==============================================================================
func _preparar_fogareu() -> void:
	var raiz := get_node_or_null("fogareu")
	if raiz == null:
		return
	_jato = raiz.get_node_or_null("jato") as GPUParticles3D
	_aviso = raiz.get_node_or_null("aviso") as GPUParticles3D
	_area_fogareu = raiz.get_node_or_null("area") as Area3D
	_estouro = raiz.get_node_or_null("estouro") as AudioStreamPlayer3D
	_chiado = raiz.get_node_or_null("chiado") as AudioStreamPlayer3D
	_luz_boca = get_node_or_null("luzes/clarao_da_boca") as OmniLight3D
	if _luz_boca:
		_luz_boca_energia = _luz_boca.light_energy
		_luz_boca_alcance = _luz_boca.omni_range
	if _jato:
		_jato.emitting = false
	if _aviso:
		_aviso.emitting = false
	# a primeira erupção não sai logo na chegada: o jogador tem de ter tempo de
	# subir no adro e se acostumar com o lugar antes de o chão cuspir nele
	_fogareu_prazo = randf_range(FOGAREU_ESPERA_MIN, FOGAREU_ESPERA_MAX)


func _fogareu_passo(delta: float) -> void:
	if _jato == null:
		return
	_fogareu_prazo -= delta
	match _fogareu_fase:
		FOGAREU_ESPERA:
			if _fogareu_prazo <= 0.0:
				_fogareu_fase = FOGAREU_AVISANDO
				_fogareu_prazo = FOGAREU_AVISO
				_luz_boca_presa = true
				if _aviso:
					_aviso.emitting = true
				if _chiado and not _chiado.playing:
					_chiado.play()
		FOGAREU_AVISANDO:
			# a brasa da Boca sobe e começa a tremer: é todo o aviso que existe
			var t: float = 1.0 - clampf(_fogareu_prazo / FOGAREU_AVISO, 0.0, 1.0)
			_acender_boca(1.0 + 4.0 * t * t + 1.2 * t * sin(_tempo * 34.0),
				1.0 + 0.45 * t)
			if _fogareu_prazo <= 0.0:
				_fogareu_fase = FOGAREU_CUSPINDO
				_fogareu_prazo = FOGAREU_JATO
				_fogareu_tique = 0.0
				_jato.emitting = true
				if _estouro:
					_estouro.play()
		FOGAREU_CUSPINDO:
			var q: float = clampf(_fogareu_prazo / FOGAREU_JATO, 0.0, 1.0)
			_acender_boca(2.5 + 4.5 * q + randf_range(-0.6, 0.6), 1.45 + q * 0.35)
			_fogareu_tique -= delta
			if _fogareu_tique <= 0.0:
				_fogareu_tique = FOGAREU_TIQUE
				_queimar()
			if _fogareu_prazo <= 0.0:
				_apagar_fogareu()


func _apagar_fogareu() -> void:
	_fogareu_fase = FOGAREU_ESPERA
	_fogareu_prazo = randf_range(FOGAREU_ESPERA_MIN, FOGAREU_ESPERA_MAX)
	if _jato:
		_jato.emitting = false
	if _aviso:
		_aviso.emitting = false
	if _chiado:
		_chiado.stop()
	_luz_boca_presa = false
	if _luz_boca:
		_luz_boca.light_energy = _luz_boca_energia
		_luz_boca.omni_range = _luz_boca_alcance


## O clarão da erupção não pode crescer sem limite: alcance grande faz a luz
## entrar na AABB de meia arena, e no renderer mobile (8 omni por malha) isso
## chuta uma fogueira para fora durante os dois segundos do jato. Daí o teto
## baixo no multiplicador de alcance.
func _acender_boca(mult_energia: float, mult_alcance: float) -> void:
	if _luz_boca == null:
		return
	_luz_boca.light_energy = _luz_boca_energia * mult_energia
	_luz_boca.omni_range = _luz_boca_alcance * mult_alcance


## Cobra o dano de quem estiver na coluna de fogo. Vale para o jogador e para os
## inimigos: a Area3D escuta as duas layers, e quem tiver `take_damage` queima.
func _queimar() -> void:
	if _area_fogareu == null:
		return
	for corpo in _area_fogareu.get_overlapping_bodies():
		if corpo.has_method("take_damage"):
			corpo.take_damage(FOGAREU_DANO)
