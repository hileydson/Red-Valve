extends Node3D

## O elevador do hospital: o unico jeito de chegar no segundo andar.
##
## A cena e' gerada por `tools/godot/hospital/gerar_cena_hospital.py`:
##
##     elevador (este no', no eixo do poco)
##       cabine                      <- e' ESTE no' que sobe e desce (position.y)
##         corpo, chao, painel, luz_cabine, area_dentro
##         portas_cabine/folha_n, folha_s
##       pavimento_1 / pavimento_2   <- as portas de pavimento, uma por andar
##         folha_n, folha_s, area_chamar
##
## ==========================================================================
## A SEQUENCIA
##
##   1. O jogador chega na porta do pavimento -> "Chamar o elevador".
##   2. Se a cabine estiver no outro andar, ela vem primeiro (devagar).
##      Chegando, as duas portas (a do pavimento e a da cabine) abrem juntas.
##   3. Ele entra. No painel acende o botao do OUTRO andar (no terreo o de
##      cima, la' em cima o de baixo), com o indicador de item: e' preciso ir
##      ate' o painel e apertar ("Subir para o 2o andar").
##   4. Aciona -> as portas fecham, o elevador da' um tranco e sobe DEVAGAR,
##      com o motor roncando e a tela tremendo nos solavancos.
##   5. Chegou: tranco, campainha, as portas abrem.
##
## ==========================================================================
## COMO O JOGADOR SOBE JUNTO
##
## O chao da cabine e' `AnimatableBody3D` com `sync_to_physics`, que ja' deveria
## carregar um CharacterBody3D em cima. "Deveria": esse acoplamento depende de o
## jogador estar com `is_on_floor()` no quadro certo, e num elevador lento, com
## a gravidade puxando, ele pisca entre apoiado e nao apoiado — e cada pisca e'
## um tranco, ou uma queda pra dentro da cabine.
##
## Entao aqui a subida do jogador e' EXPLICITA: enquanto ele estiver dentro da
## area da cabine, o mesmo delta de altura que a cabine andou e' somado a' posicao
## dele. Os dois mecanismos convivem — o corpo animado continua impedindo que
## ele atravesse o chao, e a soma garante que ele nunca fique pra tras.
##
## Duas armadilhas que custaram caro e estao resolvidas aqui:
##
## 1. TWEEN NO QUADRO DE FISICA. Tween nasce rodando no quadro de IDLE. Mexer a
##    cabine por ali faz o `AnimatableBody3D` do chao TELEPORTAR entre dois
##    passos de fisica em vez de se MOVER: ele nao gera velocidade nenhuma, nao
##    empurra ninguem, e o jogador fica parado vendo a cabine subir sem ele.
##    Por isso todo tween daqui e' TWEEN_PROCESS_PHYSICS.
##
## 2. A AREA SOBE JUNTO. `area_dentro` e' filha da cabine, entao ela sobe com a
##    cabine. Se o jogador ficar pra tras um unico quadro, ele sai da area,
##    `_player_dentro` vira falso e a elevacao dele para de vez — o erro se
##    consolida em vez de se corrigir. Durante a viagem o passageiro fica
##    TRAVADO: quem entrou, viajou.

enum { PARADO, CHAMANDO, ABRINDO, ABERTO, FECHANDO, VIAJANDO }

const TEMPO_PORTA := 1.9
## Metros por segundo. 4,2 m de percurso a 0,55 m/s da' uns 8 segundos de
## viagem — lento de proposito, que foi o pedido: e' o tempo em que o jogador
## fica trancado numa caixa de metal sem saber o que tem la' em cima.
const VELOCIDADE := 0.55
const TRANCO := 0.45
## Quanto a folha corre pra abrir (metade do vao de 2,20 m).
const CURSO_FOLHA := 1.10
const ESPERA_ABERTA := 9.0

## Sons sintetizados por `tools/audio/gerar_sons_elevador.py`.
const SOM_MOTOR := "res://assets/sounds/hospital/elevador_motor.ogg"
const SOM_PORTA := "res://assets/sounds/hospital/elevador_porta.ogg"
const SOM_TRANCO := "res://assets/sounds/hospital/elevador_tranco.ogg"
const SOM_DING := "res://assets/sounds/hospital/elevador_ding.ogg"
const SOM_BOTAO := "res://assets/sounds/hospital/elevador_botao.ogg"
## Tremor da câmera de quem está dentro: o solavanco e o trepidar da viagem.
const TREME_TRANCO := 0.045
const TREME_VIAGEM := 0.009

const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")
## Os botões do painel (`pecas_do_painel` do gerador): no espaço do painel, o
## de cima em y 1,52 e o de baixo em 1,22, a face em x 0,06.
const BOTOES := {2: Vector3(0.068, 1.52, 0.0), 1: Vector3(0.068, 1.22, 0.0)}
const COR_BOTAO_ACESO := Color(1.0, 0.72, 0.28)
const COR_BOTAO_APAGADO := Color(0.16, 0.15, 0.13)

@onready var cabine: Node3D = $cabine
@onready var area_dentro: Area3D = $cabine/area_dentro

var estado: int = PARADO
var andar_atual: int = 1
var _cotas := {1: 0.0, 2: 4.2}
var _player: Node3D = null
var _player_dentro: bool = false
## Passageiro travado durante a viagem (ver a armadilha 2 no cabecalho).
var _viajando_com_player: bool = false
var _player_no_pavimento: int = 0
var _y_anterior: float = 0.0
var _espera: float = 0.0

## Capítulo 2 (hospital claro): quem aperta os botões é a enfermeira que leva
## o Maycow até a cirurgia (`enfermeira_guia.gd`). Enquanto `guiado`, o botão
## do jogador não faz nada e o prompt não aparece; `segurar_aberto` não deixa
## a porta fechar sozinha enquanto ela espera ele entrar.
var guiado: bool = false
var segurar_aberto: bool = false

var _som_motor: AudioStreamPlayer3D
var _som_porta: AudioStreamPlayer3D
var _som_tranco: AudioStreamPlayer3D
var _som_ding: AudioStreamPlayer3D
var _som_botao: AudioStreamPlayer3D
## andar de destino -> o botão (malha) e a seleção dele
var _botoes := {}
var _selecoes := {}
var _mat_aceso: StandardMaterial3D
var _mat_apagado: StandardMaterial3D
var _treme_relogio := 0.0


func _ready() -> void:
	_cotas[1] = float(get_meta("andar_1", 0.0))
	_cotas[2] = float(get_meta("andar_2", 4.2))
	cabine.position.y = _cotas[1]
	_y_anterior = cabine.position.y

	area_dentro.body_entered.connect(_ao_entrar_na_cabine)
	area_dentro.body_exited.connect(_ao_sair_da_cabine)
	for andar in [1, 2]:
		var area: Area3D = get_node("pavimento_%d/area_chamar" % andar)
		area.body_entered.connect(_ao_chegar_no_pavimento.bind(andar))
		area.body_exited.connect(_ao_sair_do_pavimento.bind(andar))
	_portas_instantaneas(false)
	_montar_sons()
	_montar_painel()


func _physics_process(delta: float) -> void:
	# O jogador sobe junto com a cabine, quadro a quadro.
	var passo := cabine.position.y - _y_anterior
	var leva := _player_dentro or _viajando_com_player
	if absf(passo) > 0.0 and leva and is_instance_valid(_player):
		_player.global_position.y += passo
	_y_anterior = cabine.position.y
	_trepidar(delta)
	_atualizar_painel()

	if estado == ABERTO:
		_espera -= delta
		if _espera <= 0.0 and not _player_dentro and not segurar_aberto:
			_fechar_portas()

	if estado != ABERTO and estado != PARADO:
		return
	if guiado or GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	# dentro da cabine quem manda é o botão do painel (`_apertar_no_painel`)
	if _player_dentro:
		return
	if _player_no_pavimento != 0 and estado == PARADO:
		_chamar(_player_no_pavimento)


# ==============================================================================
# CHAMADA E VIAGEM
# ==============================================================================

func _chamar(andar: int) -> void:
	if andar == andar_atual:
		_abrir_portas()
		return
	estado = CHAMANDO
	_mensagem("PROMPT_HOSP_ELEVADOR_VINDO", 2.4)
	await _mover_ate(andar)
	_abrir_portas()


# ==============================================================================
# PELA ENFERMEIRA (guiado)
# ==============================================================================

## Chama a cabine pro andar e volta com as portas abertas.
func chamar_pelo_guia(andar: int) -> void:
	if estado == ABERTO and andar_atual == andar:
		_espera = ESPERA_ABERTA
		return
	while estado != PARADO and estado != ABERTO:
		await get_tree().physics_frame
	if estado == ABERTO:
		if andar_atual == andar:
			return
		await _fechar_portas()
	await _chamar(andar)
	while estado != ABERTO:
		await get_tree().physics_frame


## Fecha, viaja e volta com as portas abertas no destino.
func viajar_pelo_guia(destino: int) -> void:
	await _viajar(destino)
	while estado != ABERTO:
		await get_tree().physics_frame


func player_dentro() -> bool:
	return _player_dentro


## O jogador apertou o botão aceso do painel.
func _apertar_no_painel(destino: int) -> void:
	if guiado or estado != ABERTO or destino == andar_atual:
		return
	_tocar(_som_botao)
	_viajar(destino)


func _viajar(destino: int) -> void:
	estado = FECHANDO
	GlobalUtils.hide_center_message(_id_prompt())
	await _animar_portas(false)
	await get_tree().create_timer(0.6).timeout
	await _mover_ate(destino)
	_abrir_portas()


## Leva a cabine ate' o andar, com o tranco de partida e o de chegada.
func _mover_ate(andar: int) -> void:
	estado = VIAJANDO
	_viajando_com_player = _player_dentro
	var alvo: float = _cotas[andar]
	var distancia := absf(alvo - cabine.position.y)
	if distancia < 0.01:
		andar_atual = andar
		return
	var tempo := distancia / VELOCIDADE
	_solavanco()
	_som_motor.volume_db = -30.0
	_som_motor.play()
	create_tween().tween_property(_som_motor, "volume_db", -6.0, 1.2)

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	# Um solavanco curto antes de sair do lugar e outro na chegada. E' o que
	# faz a caixa parecer velha em vez de parecer um plano de camera.
	tween.tween_property(cabine, "position:y",
		cabine.position.y - signf(alvo - cabine.position.y) * 0.04, TRANCO * 0.4)
	tween.tween_property(cabine, "position:y", alvo, tempo)
	await tween.finished
	var some := create_tween()
	some.tween_property(_som_motor, "volume_db", -40.0, 0.5)
	some.tween_callback(_som_motor.stop)
	_solavanco()
	andar_atual = andar
	_viajando_com_player = false


# ==============================================================================
# PORTAS
# ==============================================================================

func _abrir_portas() -> void:
	estado = ABRINDO
	_tocar(_som_ding)
	await _animar_portas(true)
	estado = ABERTO
	_espera = ESPERA_ABERTA
	_atualizar_prompt()


func _fechar_portas() -> void:
	estado = FECHANDO
	await _animar_portas(false)
	estado = PARADO
	_atualizar_prompt()


## Move as quatro folhas de uma vez: as duas da cabine e as duas do pavimento em
## que ela esta'. As do outro andar nao se mexem — a porta de pavimento sem
## cabine atras tem de continuar solida, senao o jogador cai no poco.
func _animar_portas(abrir: bool) -> void:
	_tocar(_som_porta)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	for folha in _folhas_ativas():
		var lado := signf(folha.position.z)
		if is_zero_approx(lado):
			lado = 1.0
		var fechado: float = lado * CURSO_FOLHA * 0.5
		var destino: float = fechado + (lado * CURSO_FOLHA if abrir else 0.0)
		tween.tween_property(folha, "position:z", destino, TEMPO_PORTA)
	await tween.finished


func _portas_instantaneas(abertas: bool) -> void:
	for folha in _folhas_ativas():
		var lado := signf(folha.position.z)
		if is_zero_approx(lado):
			lado = 1.0
		folha.position.z = lado * CURSO_FOLHA * 0.5 \
			+ (lado * CURSO_FOLHA if abertas else 0.0)


func _folhas_ativas() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for nome in ["folha_n", "folha_s"]:
		lista.append(get_node("cabine/portas_cabine/" + nome))
		lista.append(get_node("pavimento_%d/%s" % [andar_atual, nome]))
	return lista


# ==============================================================================
# PROMPTS
# ==============================================================================

func _id_prompt() -> String:
	return "hosp_elevador"


func _mensagem(chave: String, duracao: float = 0.0) -> void:
	GlobalUtils.show_center_message(_id_prompt(), tr(chave), 16, duracao)


func _atualizar_prompt() -> void:
	if guiado:
		GlobalUtils.hide_center_message(_id_prompt())
		return
	if _player_dentro:
		# o prompt de dentro é o do botão aceso do painel (seleção de item)
		GlobalUtils.hide_center_message(_id_prompt())
		return
	if _player_no_pavimento != 0 and estado == PARADO:
		_mensagem("PROMPT_HOSP_ELEVADOR_CHAMAR")
		return
	GlobalUtils.hide_center_message(_id_prompt())


func _ao_entrar_na_cabine(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player = body
	_player_dentro = true
	_atualizar_prompt()


func _ao_sair_da_cabine(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_dentro = false
	_atualizar_prompt()


func _ao_chegar_no_pavimento(body: Node3D, andar: int) -> void:
	if not _eh_player(body):
		return
	_player = body
	_player_no_pavimento = andar
	_atualizar_prompt()


func _ao_sair_do_pavimento(body: Node3D, andar: int) -> void:
	if not _eh_player(body) or _player_no_pavimento != andar:
		return
	_player_no_pavimento = 0
	_atualizar_prompt()


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"


# ==============================================================================
# PAINEL (os dois botões da cabine)
# ==============================================================================

## Cada botão é uma malha acesa por cima do botão modelado, com a seleção de
## item (realce, indicador, prompt). Só o do OUTRO andar acende, e só ele
## aceita o aperto — e só com a porta aberta e o jogador dentro.
func _montar_painel() -> void:
	var painel := cabine.get_node_or_null("painel") as Node3D
	if painel == null:
		return
	_mat_aceso = StandardMaterial3D.new()
	_mat_aceso.albedo_color = COR_BOTAO_ACESO
	_mat_aceso.emission_enabled = true
	_mat_aceso.emission = COR_BOTAO_ACESO
	_mat_aceso.emission_energy_multiplier = 2.2
	_mat_apagado = StandardMaterial3D.new()
	_mat_apagado.albedo_color = COR_BOTAO_APAGADO
	_mat_apagado.roughness = 0.6

	# área generosa: a cápsula do jogador tem 1,35 m e para longe da parede
	var area := Area3D.new()
	area.name = "area_painel"
	area.collision_layer = 0
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(2.6, 2.4, 2.6)
	forma.shape = caixa
	forma.position = Vector3(1.1, 1.2, 0.0)
	area.add_child(forma)
	painel.add_child(area)

	for destino in BOTOES:
		var botao := MeshInstance3D.new()
		botao.name = "botao_%d" % destino
		var caixa_botao := BoxMesh.new()
		caixa_botao.size = Vector3(0.016, 0.1, 0.1)
		botao.mesh = caixa_botao
		botao.position = BOTOES[destino]
		botao.material_override = _mat_apagado
		painel.add_child(botao)
		_botoes[destino] = botao
		var sel = ItemSelecionavel.new()
		sel.som_de_pegar = false
		sel.disponivel = false
		add_child(sel)
		sel.configurar(botao, area, "PROMPT_HOSP_ELEVADOR_SUBIR" if destino == 2
			else "PROMPT_HOSP_ELEVADOR_DESCER")
		sel.pegar.connect(_apertar_no_painel.bind(destino))
		_selecoes[destino] = sel


func _atualizar_painel() -> void:
	if _botoes.is_empty():
		return
	var destino := 2 if andar_atual == 1 else 1
	for d in _botoes:
		(_botoes[d] as MeshInstance3D).material_override = \
			_mat_aceso if d == destino or (estado == VIAJANDO and d == andar_atual) \
			else _mat_apagado
		_selecoes[d].disponivel = d == destino and estado == ABERTO and _player_dentro \
			and not guiado and not GlobalEvents.in_cutscene


# ==============================================================================
# SOM E TREMOR
# ==============================================================================

func _montar_sons() -> void:
	var motor := load(SOM_MOTOR) as AudioStreamOggVorbis
	if motor:
		motor.loop = true
	_som_motor = _fonte("som_motor", motor, -6.0, Vector3(0.0, -0.4, 0.0))
	_som_porta = _fonte("som_porta", load(SOM_PORTA), -4.0, Vector3(-CURSO_FOLHA * 2.0, 1.2, 0.0))
	_som_tranco = _fonte("som_tranco", load(SOM_TRANCO), -2.0, Vector3(0.0, -0.2, 0.0))
	_som_ding = _fonte("som_ding", load(SOM_DING), -8.0, Vector3(-1.8, 2.4, 1.6))
	_som_botao = _fonte("som_botao", load(SOM_BOTAO), -6.0, Vector3(-2.2, 1.4, 1.65))


## Fonte presa à cabine: o som sobe e desce junto com ela.
func _fonte(nome: String, stream: AudioStream, volume: float, onde: Vector3) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = nome
	p.stream = stream
	p.volume_db = volume
	p.unit_size = 6.0
	p.max_distance = 30.0
	p.position = onde
	cabine.add_child(p)
	return p


func _tocar(p: AudioStreamPlayer3D) -> void:
	if p and p.stream:
		p.play()


## Partida e chegada: o tranco, e a câmera treme se o jogador está dentro.
func _solavanco() -> void:
	_tocar(_som_tranco)
	if _player_dentro or _viajando_com_player:
		_treme_relogio = 0.5   # o trepidar da viagem não atropela o tranco
		GlobalUtils.shake_camera(0.35, TREME_TRANCO)
		GlobalUtils.vibrate_controller(null, 0.5, 0.2, 0.25)


## Durante a viagem, um trepidar miúdo de cabo velho na câmera de quem vai dentro.
func _trepidar(delta: float) -> void:
	if estado != VIAJANDO or not _viajando_com_player:
		return
	_treme_relogio -= delta
	if _treme_relogio <= 0.0:
		_treme_relogio = 0.45
		GlobalUtils.shake_camera(0.4, TREME_VIAGEM)
