extends Node3D

## O TIRO DA CACADEIRA VISTO DE FORA: clarao, faisca e fumaca.
##
## A pistola do jogo resolve o tiro com uma luz de tres quadros
## (`player_combat._piscar_clarao`) e pronto. Numa cacadeira isso nao chega: o
## tiro dela e' o evento, sao dois na arma inteira, e o jogador precisa VER que
## gastou um. Entao aqui sao tres coisas em cima da mesma boca de cano:
##
##     clarao   a labareda. Dura 9 centesimos — e' quase um quadro, e e' assim
##              mesmo que polvora queima
##     faiscas  os graos que saem acesos e caem. Duram meio segundo
##     fumaca   o que fica. Sai empurrada, desacelera e sobe por quase 2 s
##
## ==========================================================================
## POR QUE A FUMACA NAO E' FILHA DA ARMA
##
## Ela e' emitida em espaco de MUNDO (`local_coords = false`, que e' o padrao):
## cada baforada nasce onde a boca do cano estava naquele instante e fica la',
## como fumaca de verdade. Se fosse filha da arma, girar a camera arrastaria a
## nuvem inteira junto, e o efeito viraria um adesivo colado no cano.
##
## Mas a EMISSAO segue a arma pelos primeiros 3 decimos (`SEGUE_A_ARMA`), que e'
## o tempo em que o cano ainda esta' cuspindo. Por isso o no' se reposiciona
## todo quadro nesse comeco: e' o rastro saindo do cano enquanto ele se move.
##
## ==========================================================================
## COMO SE USA
##
##     var fx := load("res://scenes/effects/fogo_shotgun.tscn").instantiate()
##     fx.arma = gun_hold          # quem sabe onde esta' a boca do cano
##     get_tree().current_scene.add_child(fx)
##     fx.global_position = gun_hold.boca_do_cano()
##
## Ele se apaga sozinho. Nao precisa guardar referencia.

## Por quanto tempo a boca ainda cospe fumaca nova.
const SEGUE_A_ARMA := 0.30
## Quando o no' se apaga. Tem de ser maior que a vida da fumaca.
const VIDA_TOTAL := 2.4

## Quem responde `boca_do_cano()` e `direcao_do_cano()` — o
## `player_shotgun_hold.gd`. Pode ser nulo: sem ele o efeito fica parado onde
## nasceu, que e' o certo se a arma sumiu no meio do caminho.
var arma: Node = null

var _tempo := 0.0
var _fumaca: GPUParticles3D = null


func _ready() -> void:
	_fumaca = _montar_fumaca()
	add_child(_fumaca)
	add_child(_montar_clarao())
	add_child(_montar_faiscas())
	_mirar_no_cano()


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo < SEGUE_A_ARMA:
		_mirar_no_cano()
	elif _fumaca != null and _fumaca.emitting:
		_fumaca.emitting = false
	if _tempo >= VIDA_TOTAL:
		queue_free()


## Poe o no' na boca do cano, olhando pra onde o cano olha.
##
## `look_at` deixa o -Z do no' apontado pro alvo, e e' por isso que todas as
## direcoes das particulas aqui sao -Z: elas saem PELO cano.
func _mirar_no_cano() -> void:
	if arma == null or not is_instance_valid(arma):
		return
	if not arma.tem_arma_na_mao():
		return
	var boca: Vector3 = arma.boca_do_cano()
	var dir: Vector3 = arma.direcao_do_cano()
	global_position = boca
	if dir.length_squared() < 0.0001:
		return
	# Com o cano na vertical o `look_at` nao tem como escolher o "cima": um
	# segundo eixo resolve, e a fumaca nao liga pra qual dos dois e'.
	var cima := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	look_at(boca + dir, cima)


## A LABAREDA. Poucas particulas, grandes, muito rapidas e muito curtas.
func _montar_clarao() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.09
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.4
	# Sem isto a labareda some quando a boca do cano sai da tela por um quadro —
	# e ela dura tao pouco que nao voltaria mais.
	p.visibility_aabb = AABB(Vector3(-1.5, -1.5, -3.0), Vector3(3.0, 3.0, 4.0))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 22.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 9.0
	mat.scale_min = 0.5
	mat.scale_max = 1.1
	mat.scale_curve = _curva([Vector2(0.0, 1.0), Vector2(0.45, 0.85), Vector2(1.0, 0.0)])
	mat.color_ramp = _degrade([
		[0.0, Color(1.0, 0.95, 0.72, 1.0)],
		[0.35, Color(1.0, 0.72, 0.25, 0.9)],
		[1.0, Color(0.85, 0.32, 0.06, 0.0)],
	])
	p.process_material = mat

	var malha := QuadMesh.new()
	malha.size = Vector2(0.26, 0.26)
	malha.material = _material_aceso(Color(1.0, 0.88, 0.55), 0.30)
	p.draw_pass_1 = malha
	p.emitting = true
	return p


## OS GRAOS ACESOS. Saem com a labareda, pesam e caem.
func _montar_faiscas() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.34
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.7
	p.visibility_aabb = AABB(Vector3(-2.0, -2.5, -4.0), Vector3(4.0, 4.0, 5.0))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 30.0
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -7.0, 0)
	# Freia forte: grao de polvora nao atravessa o corredor, apaga logo ali.
	mat.damping_min = 6.0
	mat.damping_max = 11.0
	mat.scale_min = 0.25
	mat.scale_max = 0.6
	mat.color_ramp = _degrade([
		[0.0, Color(1.0, 0.90, 0.55, 1.0)],
		[0.6, Color(1.0, 0.52, 0.12, 0.9)],
		[1.0, Color(0.55, 0.12, 0.02, 0.0)],
	])
	p.process_material = mat

	var malha := QuadMesh.new()
	malha.size = Vector2(0.04, 0.04)
	malha.material = _material_aceso(Color(1.0, 0.80, 0.45), 0.55)
	p.draw_pass_1 = malha
	p.emitting = true
	return p


## A FUMACA. E' ela que dura, e e' o pedido: sai da ponta, fica um tempo e some.
##
## O `explosiveness` baixo e' de proposito e faz o trabalho que um temporizador
## faria: com 0,82 numa vida de 1,8 s, as 22 baforadas saem espalhadas pelos
## primeiros 3 decimos em vez de todas de uma vez. E' o sopro saindo do cano, e
## nao um balao aparecendo.
func _montar_fumaca() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 20
	p.lifetime = 1.8
	p.one_shot = true
	p.explosiveness = 0.82
	p.randomness = 0.6
	p.visibility_aabb = AABB(Vector3(-2.5, -2.0, -4.0), Vector3(5.0, 6.0, 5.0))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 24.0
	# Devagar de proposito: rapido demais e as baforadas se separam e cada uma
	# vira uma bolha solta em vez de uma nuvem so'.
	mat.initial_velocity_min = 0.9
	mat.initial_velocity_max = 2.2
	# Freia forte e depois sobe: e' o que separa fumaca de poeira jogada.
	mat.damping_min = 3.0
	mat.damping_max = 5.0
	mat.gravity = Vector3(0, 0.75, 0)
	mat.angular_velocity_min = -35.0
	mat.angular_velocity_max = 35.0
	mat.scale_min = 0.8
	mat.scale_max = 1.5
	# Cresce enquanto esfria — nuvem que nao incha le' como cuspe.
	mat.scale_curve = _curva([Vector2(0.0, 0.35), Vector2(0.5, 1.0),
		Vector2(1.0, 1.45)])
	# Translucida do comeco ao fim: fumaca que tapa o que esta' atras vira
	# algodao. O pico e' 0,30 e ja' e' o bastante porque elas se somam.
	# A nuvem tem de estar SUMINDO enquanto ainda esta' crescendo, senao ela vira
	# uma bola branca parada em frente ao cano. Por isso o pico e' cedo (um
	# decimo de vida) e a queda comeca logo depois.
	mat.color_ramp = _degrade([
		[0.0, Color(0.72, 0.70, 0.67, 0.0)],
		[0.10, Color(0.66, 0.64, 0.62, 0.32)],
		[0.35, Color(0.56, 0.55, 0.54, 0.20)],
		[0.70, Color(0.46, 0.46, 0.45, 0.08)],
		[1.0, Color(0.42, 0.42, 0.42, 0.0)],
	])
	p.process_material = mat

	var malha := QuadMesh.new()
	malha.size = Vector2(0.44, 0.44)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.58, 0.57, 0.56)
	m.albedo_texture = _disco(0.0)
	# SEM ISTO A RAMPA DE COR NAO VALE NADA. A `color_ramp` do
	# ParticleProcessMaterial chega no material como cor de vertice, e o
	# StandardMaterial3D ignora cor de vertice por padrao — inclusive o ALFA.
	# O sintoma: a fumaca nasce e morre com a mesma opacidade, e a nuvem fica
	# uma bola branca parada. Custou duas rodadas de foto pra aparecer.
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Sem isto o `scale_min/max` e a `scale_curve` acima nao valem nada: o
	# billboard reescreve a escala do quad. Ja' custou tempo neste projeto.
	m.billboard_keep_scale = true
	# Sem sombreamento: iluminada, ela pega o ambiente inteiro e fica BRANCA,
	# que foi como saiu na primeira tentativa. A cor dela ja' esta' na rampa.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	malha.material = m
	p.draw_pass_1 = malha
	p.emitting = true
	return p


## Material de coisa que BRILHA: ignora luz e soma em cima do que esta' atras.
func _material_aceso(cor: Color, nucleo: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.albedo_texture = _disco(nucleo)
	# Ver a nota na fumaca: e' isto que faz a `color_ramp` chegar ate' aqui.
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## UM BORRAO REDONDO, feito por codigo — sem arquivo de imagem.
##
## Sem isto cada particula e' o quadrilatero que ela literalmente e': a primeira
## versao deste efeito saiu com a fumaca em blocos de Tetris e a labareda num
## quadrado branco. E' `GradientTexture2D` no modo radial, que e' o jeito de ter
## um ponto suave sem depender de textura em disco.
##
## `nucleo` e' ate' onde ele fica cheio antes de comecar a apagar: 0 e' uma bola
## de algodao (fumaca), 0,5 e' um ponto de luz com halo (faisca).
func _disco(nucleo: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, clampf(nucleo, 0.0, 0.9), 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.92), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	# Do centro ate' a borda: o `fill_to` e' o raio, nao um canto.
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	return t


func _curva(pontos: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in pontos:
		c.add_point(pt)
	var t := CurveTexture.new()
	t.curve = c
	return t


## Um degrade a partir de uma lista de [posicao, cor].
##
## Escreve os dois vetores de uma vez em vez de `add_point`/`remove_point`: o
## Gradient nasce com duas paradas e SE RECUSA a ficar com menos de duas, entao
## limpar as de fabrica antes de por as nossas derruba um erro.
func _degrade(paradas: Array) -> GradientTexture1D:
	var lugares := PackedFloat32Array()
	var cores := PackedColorArray()
	for parada in paradas:
		lugares.append(float(parada[0]))
		cores.append(parada[1] as Color)
	var g := Gradient.new()
	g.offsets = lugares
	g.colors = cores
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
