extends "res://scripts/npcs/escola/adulto_escola.gd"

## A ENFERMEIRA QUE LEVA O MAYCOW ATÉ A CIRURGIA (Capítulo 2, hospital claro).
##
## Ela vai SEMPRE na frente: do hall até a porta do elevador do térreo, chama
## a cabine, entra, espera o Maycow entrar com o Jonny, aperta o botão, sobe
## junto e segue pelo segundo andar até a sala de cirurgia, onde os médicos
## esperam em volta da maca. Ficando ele pra trás (ou sem o Jonny no colo),
## ela para, vira pra ele e acena chamando, até ele chegar perto de novo.
##
## O "?" do mapa vai com ela (`ponto_no_mapa` com `segue_o_pai`).
##
## O corpo e a passada são os do adulto da escola (`adulto_escola.gd`: modelo
## Mixamo da cidade + `HumanoidPoser`); aqui só muda o que ela faz. O caminho
## sai do navmesh do hospital (camada 4 — a consulta passa a máscara toda).
##
## Quem cria e chama `conduzir()` é o `capitulo_2_hospital.gd`.

signal na_sala

const PontoNoMapa := preload("res://scripts/ui/ponto_no_mapa.gd")

## Mais rápida que o Maycow andando com o Jonny (1,7 m/s): ela abre
## vantagem, para e espera — é o que faz ela parecer estar levando ele.
const VEL_GUIA := 2.2
## Ficando ele mais longe que isto, ela para e chama; volta a andar com ele
## a menos de PERTO.
const LONGE := 5.5
const PERTO := 3.2
const RAIO_PONTO := 0.4

## As paradas, em coordenadas da planta (`tools/godot/hospital/planta.py`).
## Do lado da porta do elevador do térreo (o vão é z 30,5 a 32,7, no muro x 56),
## e o canto do fundo da cabine.
const DIANTE_DO_ELEVADOR := Vector3(54.7, 0.0, 29.7)
const CANTO_DA_CABINE := Vector3(60.6, 0.0, 29.9)
const PORTA_DO_ELEVADOR := Vector3(56.0, 0.0, 31.6)
## No segundo andar: saindo da cabine, diante da porta dupla da cirurgia (x
## 27,6, no muro z 53,825), já dentro da sala, e o lugar dela ao lado da maca.
const SAIDA_DO_ELEVADOR := Vector3(53.8, 4.2, 31.6)
const DIANTE_DA_CIRURGIA := Vector3(27.6, 4.2, 52.0)
const DENTRO_DA_CIRURGIA := Vector3(27.6, 4.2, 55.3)
const LUGAR_NA_SALA := Vector3(25.9, 4.2, 57.1)
const MESA := Vector3(27.675, 4.2, 59.025)
## A porta dupla da cirurgia (`portas/p_cirurgia2` do hospital gerado).
const PORTA_DA_CIRURGIA := "portas/p_cirurgia2"

var jogador: CharacterBody3D
var elevador: Node3D

var _destino := Vector3.ZERO
var _andando := false
var _olhar := Vector3.INF
## Os dois gestos do braço direito, em segundos restantes (> 0 = fazendo).
var _chamando := 0.0
var _apertando := 0.0
## Dentro da cabine viajando: a altura vem da cabine, não da física.
var _na_cabine := false
var _dy_cabine := 0.0
var _relogio_fala := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("enfermeira_guia")
	var ponto = PontoNoMapa.new()
	ponto.tipo = "interrogacao"
	ponto.sempre_visivel = true
	ponto.segue_o_pai = true
	add_child(ponto)


# ==============================================================================
# O ROTEIRO
# ==============================================================================

func conduzir() -> void:
	_falar("ENF_CHEGADA", 3.6)
	await _seguir_ate(DIANTE_DO_ELEVADOR)
	if not is_inside_tree():
		return
	_falar("ENF_ELEVADOR", 3.4)
	await _virar_para(PORTA_DO_ELEVADOR)
	await _apertar_botao()
	elevador.guiado = true
	elevador.segurar_aberto = true
	await elevador.chamar_pelo_guia(1)

	await _ir_ate(PORTA_DO_ELEVADOR + Vector3(0.9, 0.0, -0.6))
	await _ir_ate(CANTO_DA_CABINE)
	await _virar_para(PORTA_DO_ELEVADOR)
	_falar("ENF_ENTRA", 3.0)
	# espera ele entrar, com o Jonny
	while is_inside_tree() and not (elevador.player_dentro() and jogador.carregando_jonny):
		_chamar_com_a_mao()
		_cobrar(not jogador.carregando_jonny)
		await get_tree().physics_frame
	await _virar_para(PORTA_DO_ELEVADOR + Vector3(0.0, 0.0, -1.3))
	await _apertar_botao()
	elevador.segurar_aberto = false

	_na_cabine = true
	var cabine := elevador.get_node("cabine") as Node3D
	_dy_cabine = global_position.y - cabine.global_position.y
	await elevador.viajar_pelo_guia(2)
	_na_cabine = false

	await _ir_ate(SAIDA_DO_ELEVADOR)
	elevador.guiado = false
	_falar("ENF_SEGUE", 2.6)
	await _seguir_ate(DIANTE_DA_CIRURGIA)
	await _abrir_a_porta(PORTA_DA_CIRURGIA)
	await _ir_ate(DENTRO_DA_CIRURGIA)
	await _ir_ate(LUGAR_NA_SALA)
	await _virar_para(MESA)
	_falar("ENF_SALA", 4.0)
	na_sala.emit()


## Anda pelo navmesh até `destino`, ponto a ponto, esperando o Maycow.
func _seguir_ate(destino: Vector3) -> void:
	var mapa := get_world_3d().navigation_map
	var caminho := NavigationServer3D.map_get_path(mapa, global_position, destino, true, 0xFFFFFFFF)
	if caminho.is_empty():
		caminho = PackedVector3Array([destino])
	for p in caminho:
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() < RAIO_PONTO:
			continue
		await _ir_ate(p)
		if not is_inside_tree():
			return
	await _ir_ate(destino)


## Anda em linha reta até `alvo`; se o Maycow ficar pra trás, espera ele.
func _ir_ate(alvo: Vector3) -> void:
	_destino = alvo
	while is_inside_tree():
		var d := Vector2(alvo.x - global_position.x, alvo.z - global_position.z)
		if d.length() < RAIO_PONTO:
			break
		if _deve_esperar():
			_andando = false
			await _esperar_o_maycow()
			continue
		_andando = true
		_olhar = Vector3.INF
		await get_tree().physics_frame
	_andando = false


## Longe dele (ou ele largou o Jonny): para, vira e chama até ele chegar.
func _deve_esperar() -> bool:
	if not is_instance_valid(jogador) or _na_cabine:
		return false
	return _distancia_do_maycow() > LONGE or not jogador.carregando_jonny


func _esperar_o_maycow() -> void:
	while is_inside_tree():
		if is_instance_valid(jogador) and _distancia_do_maycow() < PERTO and jogador.carregando_jonny:
			break
		_olhar = jogador.global_position if is_instance_valid(jogador) else Vector3.INF
		_chamar_com_a_mao()
		_cobrar(is_instance_valid(jogador) and not jogador.carregando_jonny)
		await get_tree().physics_frame
	_olhar = Vector3.INF


func _distancia_do_maycow() -> float:
	var d := jogador.global_position - global_position
	# outro andar conta como longe
	if absf(d.y) > 2.5:
		return INF
	return Vector2(d.x, d.z).length()


## Uma fala de quando em quando enquanto ela espera.
func _cobrar(sem_o_jonny: bool) -> void:
	if _relogio_fala > 0.0:
		return
	_falar("ENF_SEM_JONNY" if sem_o_jonny else "ENF_VENHA", 2.6)
	_relogio_fala = 7.0


func _falar(chave: String, segundos: float) -> void:
	GlobalUtils.show_center_message("fala_enfermeira", tr(chave), 18, segundos)
	_relogio_fala = maxf(_relogio_fala, segundos + 3.0)


func _chamar_com_a_mao() -> void:
	_chamando = maxf(_chamando, 0.3)


## Empurra a porta (o mesmo gesto do botão) e espera a folha sair da frente.
func _abrir_a_porta(caminho: String) -> void:
	var porta := get_tree().current_scene.get_node_or_null(caminho)
	if porta == null or not porta.has_method("abrir_por"):
		return
	await _virar_para(porta.global_position)
	_apertando = 0.8
	porta.abrir_por(self)
	await get_tree().create_timer(1.2, false).timeout


func _apertar_botao() -> void:
	_apertando = 0.8
	await get_tree().create_timer(0.8, false).timeout


func _virar_para(p: Vector3) -> void:
	_olhar = p
	var t := 0.0
	while is_inside_tree() and t < 1.2:
		var d := p - global_position
		if absf(angle_difference(rotation.y, atan2(d.x, d.z))) < 0.08:
			break
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


# ==============================================================================
# CORPO
# ==============================================================================

func _physics_process(delta: float) -> void:
	_gesto += delta
	_chamando = maxf(0.0, _chamando - delta)
	_apertando = maxf(0.0, _apertando - delta)
	_relogio_fala -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	if _na_cabine and is_instance_valid(elevador):
		# a cabine leva: a altura acompanha, sem física (ver o elevador)
		var cabine := elevador.get_node("cabine") as Node3D
		global_position.y = cabine.global_position.y + _dy_cabine
		velocity.y = 0.0
		_pose(delta)
		return
	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	else:
		velocity.y = 0.0
	var passo := Vector3.ZERO
	if _andando:
		var d := _destino - global_position
		d.y = 0.0
		var giro := atan2(d.x, d.z)
		rotation.y = rotate_toward(rotation.y, giro, GIRO * 1.6 * delta)
		if absf(angle_difference(rotation.y, giro)) < 0.7:
			var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
			passo = frente * minf(VEL_GUIA * delta, d.length())
	elif _olhar != Vector3.INF:
		var o := _olhar - global_position
		rotation.y = rotate_toward(rotation.y, atan2(o.x, o.z), GIRO * 1.6 * delta)
	# No plano ela anda pelo CAMINHO do navmesh, sem a colisão empurrar: a
	# grade de 1 m dele passa rente às cadeiras do hall, e a cápsula dela
	# encalhava numa quina. A física fica só pro chão.
	global_position += passo
	move_and_slide()
	if delta > 0.0:
		velocity.x = passo.x / delta
		velocity.z = passo.z / delta
	_pose(delta)


## A passada (ou o parado) do adulto, e o braço direito por cima: chamando
## ("venha cá", o antebraço vindo pro peito) ou apertando o botão.
func _pose(delta: float) -> void:
	if _poser == null:
		return
	var plano := Vector2(velocity.x, velocity.z).length()
	var cadencia := 4.2 + plano * 1.6
	if plano > 0.15:
		_fase_passo += delta * cadencia
	_abertura = lerpf(_abertura, _poser.abertura_para(plano, cadencia), clampf(delta * 6.0, 0.0, 1.0))
	_poser.pose_locomocao(_fase_passo, _gesto + _semente, clampf(plano / VEL_GUIA, 0.0, 1.0), _abertura)
	if _apertando > 0.0:
		var k := sin(clampf(1.0 - _apertando / 0.8, 0.0, 1.0) * PI)
		_poser.junta("shoulder_r", Vector3(-1.25 * k, 0.0, 0.15))
		_poser.junta("elbow_r", Vector3(-0.35 * k - 0.14, 0.0, 0.0))
	elif _chamando > 0.0:
		var aceno := 0.5 + 0.5 * sin(_gesto * 7.5)
		_poser.junta("shoulder_r", Vector3(-1.05, 0.0, 0.25))
		_poser.junta("elbow_r", Vector3(-0.35 - 1.05 * aceno, 0.0, 0.0))
