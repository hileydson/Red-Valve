extends Node

## A MIRA DA GRANOLA: dois circulos vermelhos, um dentro do outro.
##
## Com a Granola na mao ela substitui a mira de sempre (o ponto da primeira
## pessoa, a cruz da terceira). Parada, fica fixa no meio da tela. Quando um
## inimigo passa pelo MIOLO (CAMPO_TRAVA) ela trava nele: sai do centro e o
## acompanha enquanto ele ficar dentro do campo maior (CAMPO_SEGUE), piscando
## e bipando — e' o alvo que o foguete vai perseguir (`alvo_travado()`, lido
## pelo `player_combat.gd` no disparo). Saiu do campo, sumiu atras de uma
## parede ou morreu: solta, e ela volta pro meio.
##
## Os campos sao fracao da ALTURA da tela, pra valer igual em qualquer
## resolucao. As outras miras sao apagadas daqui, depois do player acende-las
## no quadro (este no' e' filho dele, entao processa depois).

const SOM_BIP := preload("res://assets/sounds/player/guns/granola/granola_mira_bip.ogg")
const SOM_TRAVA := preload("res://assets/sounds/player/guns/granola/granola_mira_trava.ogg")

const COR := Color(1.0, 0.12, 0.08)
## Raios dos circulos, em pixels numa tela de 1080 de altura.
const RAIO_FORA := 24.0
const RAIO_DENTRO := 10.0
const ESPESSURA := 2.5
## Entrar neste raio do centro marca o inimigo; sair do outro solta.
const CAMPO_TRAVA := 0.07
const CAMPO_SEGUE := 0.17
const ALCANCE := 70.0
## Piscadas (e bipes) por segundo com um alvo marcado.
const PISCADAS := 6.0
## Quao rapido o circulo corre ate' o alvo (e volta pro meio).
const SEGUE := 16.0

var player: CharacterBody3D
## A mira esta' na tela agora.
var ativa := false

var _alvo: Node3D = null
var _desenho: Control
var _pos := Vector2.ZERO
var _piscar := 0.0
var _pulso := 0.0
var _bip: AudioStreamPlayer
var _trava: AudioStreamPlayer


func _ready() -> void:
	player = get_parent()
	_bip = AudioStreamPlayer.new()
	_bip.stream = SOM_BIP
	_bip.volume_db = -16.0
	add_child(_bip)
	_trava = AudioStreamPlayer.new()
	_trava.stream = SOM_TRAVA
	_trava.volume_db = -10.0
	add_child(_trava)


## O inimigo que o foguete deve perseguir, ou null.
func alvo_travado() -> Node3D:
	return _alvo if ativa and _vivo(_alvo) else null


## Onde o foguete mira no alvo: o meio do corpo (o mesmo ponto do aim assist).
func ponto_no_alvo(alvo: Node3D) -> Vector3:
	var assist = player.get_node_or_null("PlayerAimAssist")
	if assist:
		return assist._aim_point(alvo)
	return alvo.global_position + Vector3.UP * 0.9


func _process(delta: float) -> void:
	var antes := ativa
	ativa = _deve_aparecer()
	if not _garantir_desenho():
		return
	if not ativa:
		_desenho.visible = false
		_alvo = null
		return
	# as outras miras: o player acende neste quadro, aqui apaga
	if is_instance_valid(player.point): player.point.visible = false
	if is_instance_valid(player.gun_crosshair): player.gun_crosshair.visible = false

	var tela := _desenho.get_viewport_rect().size
	var centro := tela * 0.5
	if not antes:
		_pos = centro
	var cam := player.get_viewport().get_camera_3d()
	var na_tela := centro
	if cam:
		var anterior := _alvo
		_alvo = _seguir(cam, centro, tela.y)
		if _alvo == null:
			_alvo = _procurar(cam, centro, tela.y)
		if _alvo != null and _alvo != anterior:
			_trava.play()
			_piscar = 0.0
			_pulso = 1.0
		if _alvo != null:
			na_tela = cam.unproject_position(ponto_no_alvo(_alvo))

	_pos = _pos.lerp(na_tela, 1.0 - exp(-SEGUE * delta))
	_pulso = maxf(_pulso - delta * 5.0, 0.0)
	if _alvo != null:
		var fase_antes := floorf(_piscar * PISCADAS)
		_piscar += delta
		if floorf(_piscar * PISCADAS) != fase_antes:
			_bip.play()
	_desenho.visible = true
	_desenho.queue_redraw()


func _deve_aparecer() -> bool:
	if not is_instance_valid(player) or not SaveManager.is_equipped("granola"):
		return false
	if GlobalEvents.in_cutscene or player._cutscene_hud_hidden:
		return false
	if player.is_using_ultimate or player.camera_bullet_time_ON:
		return false
	if player.has_method("are_cutscene_inputs_blocked") and player.are_cutscene_inputs_blocked():
		return false
	if player.is_first_person:
		var maos = player._maos_fp()
		return maos != null and maos.is_visible_in_tree() and maos.tem_arma_na_mao() \
			and maos.arma_na_mao() == "granola"
	return GlobalEvents.is_maycow_normal and player.is_aiming


## O alvo atual continua marcado? So' enquanto estiver vivo, visivel, no
## campo maior e sem parede no caminho.
func _seguir(cam: Camera3D, centro: Vector2, altura: float) -> Node3D:
	if not _vivo(_alvo):
		return null
	var ponto := ponto_no_alvo(_alvo)
	if cam.is_position_behind(ponto) or cam.global_position.distance_to(ponto) > ALCANCE:
		return null
	if cam.unproject_position(ponto).distance_to(centro) > CAMPO_SEGUE * altura:
		return null
	if not _a_vista(cam, ponto, _alvo):
		return null
	return _alvo


## O inimigo mais perto do centro, dentro do miolo.
func _procurar(cam: Camera3D, centro: Vector2, altura: float) -> Node3D:
	var melhor: Node3D = null
	var melhor_d := CAMPO_TRAVA * altura
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if not _vivo(inimigo):
			continue
		var ponto := ponto_no_alvo(inimigo)
		if cam.is_position_behind(ponto):
			continue
		var dist := cam.global_position.distance_to(ponto)
		if dist < 1.5 or dist > ALCANCE:
			continue
		var d := cam.unproject_position(ponto).distance_to(centro)
		if d >= melhor_d or not _a_vista(cam, ponto, inimigo):
			continue
		melhor_d = d
		melhor = inimigo
	return melhor


func _vivo(no) -> bool:
	if not (no is Node3D) or not is_instance_valid(no) or no is Area3D:
		return false
	# inimigos da cena pausada atras da arena continuam no grupo
	if not no.is_inside_tree() or not no.can_process() or not no.is_visible_in_tree():
		return false
	return not ("dead" in no and no.dead)


func _a_vista(cam: Camera3D, ponto: Vector3, inimigo: Node3D) -> bool:
	var assist = player.get_node_or_null("PlayerAimAssist")
	if assist:
		return assist._has_line_of_sight(cam.global_position, ponto, inimigo)
	return true


func _garantir_desenho() -> bool:
	if is_instance_valid(_desenho):
		return true
	if not is_instance_valid(player.hud_layer):
		return false
	_desenho = Control.new()
	_desenho.name = "GranolaCrosshair"
	_desenho.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.visible = false
	_desenho.draw.connect(_desenhar)
	player.hud_layer.add_child(_desenho)
	return true


func _desenhar() -> void:
	var k := _desenho.get_viewport_rect().size.y / 1080.0
	var cor := COR
	var fora := RAIO_FORA
	if _alvo != null:
		# marcado: pisca, e o circulo de fora aperta em volta dele
		cor.a = 1.0 if fmod(_piscar * PISCADAS, 1.0) < 0.55 else 0.25
		fora = RAIO_FORA * (0.8 + _pulso * 0.8)
	else:
		cor.a = 0.85
	_desenho.draw_arc(_pos, fora * k, 0.0, TAU, 48, cor, ESPESSURA * k, true)
	_desenho.draw_arc(_pos, RAIO_DENTRO * k, 0.0, TAU, 32, cor, ESPESSURA * k, true)
