extends "res://scripts/npcs/escola/adulto_escola.gd"

## O ENFERMEIRO QUE VAI DO LADO DO MAYCOW (Capítulo 2, hospital claro).
##
## Quem leva é a enfermeira da frente (`enfermeira_guia.gd`); este vai junto,
## um pouco atrás e do lado do Maycow, de olho no Jonny, até o elevador do
## térreo. Lá ele fica (`ficar_em`): a cabine sobe com os outros dois.
##
## Segue o Maycow pelo navmesh do hospital — em linha reta ele ficava preso
## na quina do hall com o corredor.

## Atrás e à esquerda do Maycow, no espaço do corpo dele (que olha pro -Z).
const LADO := Vector3(-1.3, 0.0, 1.1)
const VEL_MAX := 2.7
const REFAZ_CAMINHO := 0.4

var jogador: CharacterBody3D

var _caminho := PackedVector3Array()
var _relogio := 0.0
var _ficar := Vector3.INF
var _olhar_ao_ficar := Vector3.INF


## Para de seguir e vai pra `onde`, virado pra `olhando`.
func ficar_em(onde: Vector3, olhando: Vector3) -> void:
	_ficar = onde
	_olhar_ao_ficar = olhando
	_relogio = 0.0


func _physics_process(delta: float) -> void:
	_gesto += delta
	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	var alvo := _ficar
	if alvo == Vector3.INF and is_instance_valid(jogador):
		alvo = jogador.global_position + jogador.global_basis * LADO
	if alvo != Vector3.INF:
		_relogio -= delta
		if _relogio <= 0.0:
			_relogio = REFAZ_CAMINHO
			_caminho = NavigationServer3D.map_get_path(get_world_3d().navigation_map,
				global_position, alvo, true, 0xFFFFFFFF)
		_seguir_ate_alvo(alvo, delta)
	# anda pelo caminho do navmesh sem a colisão empurrar no plano (ver a
	# enfermeira): a física fica só pro chão
	var passo := Vector3(velocity.x, 0.0, velocity.z) * delta
	velocity.x = 0.0
	velocity.z = 0.0
	global_position += passo
	move_and_slide()
	if delta > 0.0:
		velocity.x = passo.x / delta
		velocity.z = passo.z / delta
	_pose_dele(delta)


func _seguir_ate_alvo(alvo: Vector3, delta: float) -> void:
	var falta := Vector2(alvo.x - global_position.x, alvo.z - global_position.z).length()
	var limite := 0.4 if _ficar != Vector3.INF else 1.0
	if falta < limite:
		var olhar := _olhar_ao_ficar if _ficar != Vector3.INF else \
			(jogador.global_position if is_instance_valid(jogador) else Vector3.INF)
		if olhar != Vector3.INF:
			var o := olhar - global_position
			rotation.y = rotate_toward(rotation.y, atan2(o.x, o.z), GIRO * delta)
		return
	# o próximo ponto do caminho que ainda não ficou pra trás
	var prox := alvo
	for p in _caminho:
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() > 0.5:
			prox = p
			break
	var d := prox - global_position
	d.y = 0.0
	var giro := atan2(d.x, d.z)
	rotation.y = rotate_toward(rotation.y, giro, GIRO * 1.6 * delta)
	if absf(angle_difference(rotation.y, giro)) < 0.8:
		var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		var vel := clampf(falta * 1.4, 0.8, VEL_MAX)
		velocity.x = frente.x * vel
		velocity.z = frente.z * vel


func _pose_dele(delta: float) -> void:
	if _poser == null:
		return
	var plano := Vector2(velocity.x, velocity.z).length()
	var cadencia := 4.2 + plano * 1.6
	if plano > 0.15:
		_fase_passo += delta * cadencia
	_abertura = lerpf(_abertura, _poser.abertura_para(plano, cadencia), clampf(delta * 6.0, 0.0, 1.0))
	_poser.pose_locomocao(_fase_passo, _gesto + _semente, clampf(plano / 1.4, 0.0, 1.0), _abertura)
