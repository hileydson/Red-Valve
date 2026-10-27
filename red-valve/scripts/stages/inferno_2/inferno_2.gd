extends "res://scripts/stages/inferno/inferno.gd"

## O INFERNO 2 — O FUNIL — continuação do inferno.
##
## Modelo de `tools/blender/inferno_2/gerar_inferno_2.py`, cena de
## `tools/godot/inferno_2/gerar_cena_inferno_2.py`: luz, prop e navmesh mexidos
## no editor somem na próxima regeração. Este script é só comportamento.
##
## O caminho desce em espiral pelas paredes de um poço, do anel de chegada (o
## portal do fim do primeiro inferno traz o jogador pra cá) até a BOCA na base
## da agulha do meio do poço, que é a saída. Tudo do primeiro inferno vale aqui
## (gêiseres, fogo ao longe, sombras, gárgulas, relâmpago, as duas pontas), e
## mais:
##
##  - o fogo ao longe sobe do FUNDO DO POÇO (e às vezes do mar de fora);
##  - as MÃOS gigantes do poço tateiam o céu, subindo e afundando devagar;
##  - o CORAÇÃO preso na agulha bate: a luz dele pulsa no compasso;
##  - de vez em quando um GRITO sobe de algum ponto do poço.

@export_group("Poço")
## Chance de o fogo ao longe nascer no poço (o resto vai pro mar de fora).
@export_range(0.0, 1.0) var erupcao_no_poco: float = 0.65
## Raio da lava do fundo (fora disso o fogo nasceria dentro da rocha).
@export var raio_poco: float = 90.0
## Raio da agulha: o fogo não nasce colado nela.
@export var raio_agulha: float = 22.0
@export var grito_espera_min: float = 25.0
@export var grito_espera_max: float = 70.0

const LAVA_POCO := -64.0
## O mar de fora começa depois da encosta da cratera.
const R_MAR := 250.0

var _maos: Array[Dictionary] = []
var _luz_coracao: OmniLight3D
var _energia_coracao: float = 0.0
var _grito: AudioStreamPlayer3D
var _grito_prazo: float = 30.0


func _preparar() -> void:
	super._preparar()
	var modelo := get_node_or_null("modelo")
	if modelo:
		for no in modelo.find_children("MAO_*", "Node3D", true, false):
			var n3 := no as Node3D
			_maos.append({"no": n3, "base": n3.position, "fase": randf() * TAU,
				"giro": randf() * TAU, "vel": randf_range(0.6, 1.0)})
	_luz_coracao = get_node_or_null("luzes/luz_coracao") as OmniLight3D
	if _luz_coracao:
		_energia_coracao = _luz_coracao.light_energy
	_grito = get_node_or_null("grito") as AudioStreamPlayer3D
	_grito_prazo = randf_range(grito_espera_min * 0.5, grito_espera_max * 0.5)


func _passo(delta: float) -> void:
	super._passo(delta)
	_passo_maos()
	_passo_coracao()
	_passo_grito(delta)


## As sombras ficam no mar de fora, olhando pra dentro da cratera.
func _giro_sombra(p: Vector3) -> float:
	return atan2(-p.x, -p.z)


func _ponto_erupcao(_cam: Camera3D) -> Vector3:
	var a := randf() * TAU
	if randf() < erupcao_no_poco:
		var r_poco := randf_range(raio_agulha, raio_poco)
		return Vector3(sin(a) * r_poco, LAVA_POCO, cos(a) * r_poco)
	var r_mar := randf_range(R_MAR, R_MAR + 220.0)
	return Vector3(sin(a) * r_mar, LAVA, cos(a) * r_mar)


# ==============================================================================
# MÃOS
# ==============================================================================
func _passo_maos() -> void:
	for m in _maos:
		var no: Node3D = m["no"]
		if not is_instance_valid(no):
			continue
		var f: float = float(m["fase"]) + _tempo * 0.16 * float(m["vel"])
		# sobe e afunda uns metros, como quem procura apoio
		no.position.y = (m["base"] as Vector3).y + sin(f) * 4.5 - 2.0
		no.rotation.x = sin(f * 1.3 + 0.7) * 0.09
		no.rotation.z = sin(f * 0.9 + 2.1) * 0.11
		no.rotation.y = float(m["giro"]) + sin(f * 0.5) * 0.4


# ==============================================================================
# CORAÇÃO
# ==============================================================================
func _passo_coracao() -> void:
	if _luz_coracao == null:
		return
	# tum-tum, pausa: duas batidas em 1,15 s
	var t := fmod(_tempo, 1.15)
	var batida := exp(-pow((t - 0.08) / 0.07, 2.0)) + 0.7 * exp(-pow((t - 0.36) / 0.08, 2.0))
	_luz_coracao.light_energy = _energia_coracao * (0.35 + 0.9 * batida)


# ==============================================================================
# GRITO DO POÇO
# ==============================================================================
func _passo_grito(delta: float) -> void:
	if _grito == null:
		return
	_grito_prazo -= delta
	if _grito_prazo > 0.0:
		return
	_grito_prazo = randf_range(grito_espera_min, grito_espera_max)
	var a := randf() * TAU
	var r := randf_range(raio_agulha + 8.0, raio_poco)
	_grito.global_position = Vector3(sin(a) * r, LAVA_POCO + 20.0, cos(a) * r)
	_grito.pitch_scale = randf_range(0.55, 0.8)
	_grito.play()
