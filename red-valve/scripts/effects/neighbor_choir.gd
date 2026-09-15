extends Node3D

## ATAQUE 1 do Unknown Neighbor — "O CORO" / "The Choir".
##
## Ele para, a flor da cabeca abre por inteiro e o que sai nao e um grito: sao
## VARIAS vozes ao mesmo tempo, de gente que nao esta ali. O ar se dobra em
## volta dele e sai correndo pelo chao como um anel.
##
## Por que este poder e diferente de tudo que o jogo ja tem: nenhum dos outros
## inimigos ataca por ONDA. O Seraph joga coisas (orbe, foguete, raio), o Rock
## joga pedra e levanta parede, o Cobalt joga bola de fogo. Tudo e um objeto que
## viaja e que da pra desviar OLHANDO. Isto aqui nao tem projetil pra olhar: e
## uma linha no chao que vem pra cima do jogador em 360 graus e que so se escapa
## saindo do alcance a tempo — ou ficando ATRAS de alguma coisa, porque a onda
## respeita parede (ver `_alcanca`).
##
## O que ela faz: dano uma vez so, no instante em que passa, mais uma surdez
## curta (lentidao) — o jogador cambaleia depois de levar.
##
## Vive solto no mundo, e nao pendurado no inimigo: ele pode se DOBRAR pra
## outro canto da arena no meio da propagacao, e a onda tem de continuar de onde
## saiu.

const FX := preload("res://scripts/effects/seraph_fx.gd")
const NFX := preload("res://scripts/effects/neighbor_fx.gd")

## Camada do chao/cenario. A onda para em parede: e o unico jeito de o jogador
## ter uma resposta pra ela alem de correr.
const CENARIO := 2

var dano: int = 16
var raio_max: float = 17.0
## Metros por segundo. Rapida o bastante pra assustar, lenta o bastante pra dar
## pra reagir se o jogador ja estava se mexendo.
var velocidade: float = 13.0
var cor: Color = Color(0.72, 1.0, 0.24)
## Fracao da velocidade do jogador enquanto dura a surdez (0.65 = 35% mais lento).
var lentidao: float = 0.65
var duracao_lentidao: float = 2.0
var alvo: Node3D = null

## ALTURA DA ONDA, em metros, no momento em que ela sai.
##
## E o numero que decide se o poder tem resposta ou nao. O jogador pula com
## `JUMP_VELOCITY = 4.5` numa gravidade de 9,8, ou seja pouco mais de 1 m de
## altura — entao uma onda de 0,55 m da pra saltar com folga de timing, e uma
## de 2,4 m (como era antes) nao dava pra nada: so restava correr pra fora do
## alcance, e a 13 m/s ela alcancava de qualquer jeito.
##
## A altura CAI conforme ela se espalha, entao quanto mais longe, mais facil de
## pular — que e' o certo: perto dele o poder tem de doer.
const ALTURA_INICIAL := 0.55
const ALTURA_MINIMA := 0.18

var _raio: float = 0.0
var _bateu: bool = false
var _anel: MeshInstance3D
var _parede: MeshInstance3D
var _luz: OmniLight3D
var _po: GPUParticles3D
var _mat_anel: StandardMaterial3D
var _mat_parede: StandardMaterial3D


func _ready() -> void:
	_monta()
	FX.som_no_mundo(self, global_position, NFX.SOM_GRITO, -1.0, 0.72)
	FX.som_no_mundo(self, global_position, NFX.SOM_GLITCH, -9.0, 0.55)
	GlobalUtils.shake_camera(0.55, 0.30)


func _monta() -> void:
	# O anel no chao: e ele que diz ONDE a onda esta agora. Deitado e bem fino,
	# porque a leitura tem de ser "linha correndo no chao", nao "bolha".
	#
	# As energias de emissao aqui sao BAIXAS de proposito. O material e'
	# aditivo: num chao claro, com a nevoa da arena por cima, energia 7
	# estourava a tela inteira de branco e a onda deixava de ter forma — o
	# jogador via um flash, nao uma linha vindo na direcao dele. O que precisa
	# ser visto e' o RECORTE do anel, e pra isso 3 basta.
	var t := TorusMesh.new()
	t.inner_radius = 0.86
	t.outer_radius = 1.0
	t.rings = 40
	t.ring_segments = 6
	_mat_anel = FX.emissivo(cor, 3.0)
	t.material = _mat_anel
	_anel = MeshInstance3D.new()
	_anel.mesh = t
	_anel.position.y = 0.06
	add_child(_anel)

	# A parede atras do anel: e ela que o jogador le como "isto tem altura, da
	# pra pular". A altura dela e' EXATAMENTE a altura que machuca (ver
	# `_altura_agora`), de proposito — um poder que pega mais alto do que
	# aparenta e' um poder que o jogador nao consegue aprender.
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 40
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	_mat_parede = FX.emissivo(Color(cor.r, cor.g, cor.b, 0.22), 1.1)
	_mat_parede.cull_mode = BaseMaterial3D.CULL_DISABLED
	c.material = _mat_parede
	_parede = MeshInstance3D.new()
	_parede.mesh = c
	_parede.position.y = 0.5
	add_child(_parede)

	_luz = OmniLight3D.new()
	_luz.light_color = cor
	_luz.light_energy = 3.2
	_luz.omni_range = 9.0
	_luz.position.y = 1.0
	add_child(_luz)

	_po = NFX.esporo(cor, 90, 1.2)
	_po.position.y = 0.4
	add_child(_po)


func _physics_process(delta: float) -> void:
	_raio += velocidade * delta
	var f := clampf(_raio / raio_max, 0.0, 1.0)

	_anel.scale = Vector3(_raio, 1.0, _raio)
	# A parede cresce em raio mas ENCOLHE em altura: a onda se espalha e se
	# gasta. Uma parede de altura fixa parece um cilindro de video game.
	var alt := _altura_agora()
	_parede.scale = Vector3(_raio, alt, _raio)
	_parede.position.y = alt * 0.5

	var apaga := 1.0 - f * f
	_mat_anel.emission_energy_multiplier = 3.0 * apaga
	_mat_parede.emission_energy_multiplier = 1.1 * apaga
	_luz.light_energy = 3.2 * apaga
	_luz.omni_range = maxf(2.0, _raio * 0.9)

	if not _bateu and is_instance_valid(alvo):
		var d := Vector2(alvo.global_position.x - global_position.x,
			alvo.global_position.z - global_position.z).length()
		# Janela generosa: a onda anda ~0,22 m por quadro, e ela tem de acertar
		# quem esta parado em cima da linha, nao so quem esta no pixel exato.
		if d <= _raio and d >= _raio - velocidade * delta - 0.6:
			# PULOU? A onda corre pelo chao: quem estiver com os pes acima dela
			# no instante em que ela passa nao leva nada. E a unica saida alem
			# de sair do alcance, e a que faz este poder virar uma pergunta em
			# vez de um imposto.
			#
			# O `_bateu` e' marcado NOS DOIS CASOS: a onda passa uma vez so por
			# cada ponto, e quem saltou na hora certa nao pode ser cobrado de
			# novo no quadro seguinte.
			_bateu = true
			if alvo.global_position.y - global_position.y <= _altura_agora():
				_acerta()
			else:
				_passou_por_baixo()

	if _raio >= raio_max:
		_encerra()


## A onda so pega quem ela ALCANCA. Um raio do centro ate o jogador diz se
## havia parede no meio — e o que transforma "corre" na unica resposta em "corre
## ou se esconde", que e bem melhor.
## Altura da onda agora, em metros. Serve pro desenho e pro dano — sao a mesma
## coisa.
func _altura_agora() -> float:
	var f := clampf(_raio / raio_max, 0.0, 1.0)
	return maxf(ALTURA_MINIMA, ALTURA_INICIAL * (1.0 - f * 0.6))


func _alcanca(quem: Node3D) -> bool:
	if not is_inside_tree():
		return false
	var espaco := get_world_3d().direct_space_state
	var altura := Vector3(0, 0.9, 0)
	var q := PhysicsRayQueryParameters3D.create(
		global_position + altura, quem.global_position + altura, CENARIO)
	return espaco.intersect_ray(q).is_empty()


func _acerta() -> void:
	if not is_instance_valid(alvo) or not _alcanca(alvo):
		return
	if alvo.has_method("take_damage"):
		alvo.take_damage(dano)
	# A surdez: o jogador sai cambaleando do grito. E o que faz a onda valer
	# mais que os pontos de dano — ela custa o proximo desvio tambem.
	if alvo.has_method("apply_slow"):
		alvo.apply_slow(lentidao, duracao_lentidao)
	GlobalUtils.shake_camera(0.45, 0.35)
	GlobalUtils.vibrate_controller(null, 0.7, 0.9, 0.35)


## Recompensa de quem pulou: um sopro passando por baixo, sem dano e sem
## lentidao. Precisa existir alguma resposta, senao o jogador que acertou o
## salto nao tem como saber que acertou.
func _passou_por_baixo() -> void:
	if not is_instance_valid(alvo):
		return
	FX.som_no_mundo(self, alvo.global_position, NFX.SOM_DOBRA, -16.0, 1.6)
	GlobalUtils.shake_camera(0.18, 0.06)


func _encerra() -> void:
	set_physics_process(false)
	if is_instance_valid(_po):
		_po.emitting = false
	var t := create_tween().set_parallel(true)
	t.tween_property(_anel, "transparency", 1.0, 0.35)
	t.tween_property(_parede, "transparency", 1.0, 0.35)
	t.tween_property(_luz, "light_energy", 0.0, 0.35)
	t.chain().tween_interval(1.6)
	t.chain().tween_callback(queue_free)
