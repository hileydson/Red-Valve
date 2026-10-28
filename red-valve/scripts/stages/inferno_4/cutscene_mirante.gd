extends Node

## A CUTSCENE DO MIRANTE (inferno 4): o Maycow chega ao topo do morro e vê o
## GRANDE INFERNO.
##
##  1. o jogador perde o controle; o Maycow vira pra vista e anda alguns passos
##     na direção da beira, com a câmera de cinema atrás do ombro dele;
##  2. a câmera MERGULHA até os olhos dele (1ª pessoa) e fica olhando o
##     infinito — a catedral colossal, o vórtice, as torres saindo da névoa —
##     enquanto o sino da capela toca;
##  3. uma GÁRGULA passa rente por cima dele, de trás pra frente, gritando; a
##     câmera AGARRA nela e sai voando junto sobre a cratera, virada pra trás:
##     o Maycow cada vez menor lá no topo, entre as duas piras;
##  4. fade out bem devagar; no escuro a câmera volta pro jogo; fade in.
##
## A câmera é uma Camera3D própria. O player não é congelado: fica de pé, com
## a gravidade dele, e só a trava de cutscene (`GlobalEvents.in_cutscene` e os
## `cutscene_set_*`) segura o input. A gárgula é a de fogo da base, no modo
## teleguiado (`voo_dirigido_*`) — o mesmo do resgate da arena — com a posição
## escrita quadro a quadro junto com a câmera, no MESMO passo (ver `_fase`).
##
## Quem chama: `inferno_4.gd`, ao pisar na faixa `gatilho_mirante`.

const CENA_GARGULA := "res://scenes/effects/fire_gargoyle.tscn"

# --- tempos ---
## Teto da caminhada até a beira (ela para antes se chegar a `PARA_NA_BEIRA`).
const DUR_ANDAR := 3.4
## A câmera saindo do ombro e entrando nos olhos.
const DUR_MERGULHO := 1.4
## Olhando a vista, parado.
const DUR_OLHAR := 4.8
## Da gárgula entrar em quadro até passar por cima e sair na frente.
const DUR_PASSAGEM := 2.3
## A câmera largando o olho e indo se pendurar na gárgula.
const DUR_PEGAR := 1.6
## O voo virado pra trás, olhando o Maycow (o fade começa dentro dele).
const DUR_VOO := 9.5
## O fade out, bem devagar, no fim do voo.
const DUR_FADE := 4.0
const DUR_PRETO := 0.7
const DUR_FADE_IN := 2.2

# --- geometria ---
## Distância da beira em que o Maycow para de andar.
const PARA_NA_BEIRA := 4.0
## Onde a câmera fica, montada na gárgula: pra fora (longe do Maycow), pra
## cima e um pouco de lado — a gárgula fica no pé do quadro, o Maycow no meio.
## Mais perto que isto ela enche a tela de fogo e o Maycow some.
const MONTADA_FORA := 7.0
const MONTADA_CIMA := 4.4
const MONTADA_LADO := 1.8
## A volta da gárgula em torno do topo: o raio vai de onde a passagem
## termina até `RAIO_FINAL`, girando `GIRO_DO_VOO` radianos.
const RAIO_FINAL := 125.0
const GIRO_DO_VOO := 1.75
const SUBIDA_DO_VOO := 22.0
## O desfoque do voo: tudo borrado menos o Maycow. Na TELA (`SHADER_FOCO`), um
## círculo nítido em volta dele — a gárgula é fogo transparente e o desfoque
## por profundidade não a pega; e na CÂMERA, só o de longe, que borra a cratera
## logo atrás dele, dentro do círculo. O nítido da câmera vai até `FOCO_FRACAO`
## da distância além do Maycow (nunca menos que `FOCO_MIN` m).
const SHADER_FOCO := "res://shaders/cutscenes/foco_no_maycow.gdshader"
const FOCO_FRACAO := 0.1
const FOCO_MIN := 2.5
const DESFOQUE := 0.12

var cena: Node3D
var player: CharacterBody3D
var cam: Camera3D
var gargula: Node3D
## Luz de recorte no Maycow durante o voo: de 100 m, no escuro do topo, ele
## sumiria — e o plano inteiro é ele lá longe.
var _recorte: OmniLight3D
var _tela: ColorRect
var _camada: CanvasLayer
var _borrao: CanvasLayer
var _modelo_escondido := false
var _acabou := false


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	cena = dono
	player = jogador
	_travar()
	await _andar_ate_a_beira()
	if _vale():
		await _mergulhar_nos_olhos()
	if _vale():
		await _olhar_a_vista()
	if _vale():
		await _gargula_passa()
	if _vale():
		await _voar_na_gargula()
	_encerrar()


# ============================================================ 1) andar

func _andar_ate_a_beira() -> void:
	var de := cam.global_transform
	var olhar_de := de.origin - de.basis.z * 20.0
	player.cutscene_set_auto_walk(true)
	var t := 0.0
	while t < DUR_ANDAR:
		await get_tree().process_frame
		if not _vale():
			return
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		t += dt
		var dir := _dir_vista(player.global_position)
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), clampf(dt * 2.6, 0.0, 1.0))
		# a câmera sai de onde a do jogo estava e assenta atrás do ombro
		var lado := Vector3(-dir.z, 0.0, dir.x)
		var pos := player.global_position - dir * 3.3 + lado * 1.15 + Vector3.UP * 0.95
		var olhar := player.global_position + dir * 30.0 + Vector3.UP * 0.9
		var k := _suave(clampf(t / 1.3, 0.0, 1.0))
		_plantar(de.origin.lerp(pos, k), olhar_de.lerp(olhar, k))
		if t > 0.8 and _dist_beira(player.global_position) < PARA_NA_BEIRA:
			break
	player.cutscene_set_auto_walk(false)
	player.velocity = Vector3.ZERO


# ============================================================ 2) mergulho

func _mergulhar_nos_olhos() -> void:
	var p0 := cam.global_position
	var l0 := p0 - cam.global_basis.z * 30.0
	await _fase(DUR_MERGULHO, func(k: float) -> void:
		var e := _suave(k)
		var olho := _olho()
		_plantar(p0.lerp(olho, e), l0.lerp(olho + _dir_olhar(-0.1) * 40.0, e))
		# o corpo some quando a câmera já está entrando na cabeça
		if k > 0.72 and not _modelo_escondido:
			_esconder_modelo(true))


# ============================================================ 3) olhar

func _olhar_a_vista() -> void:
	if cena.has_method("_badalar"):
		cena.call("_badalar")
	await _fase(DUR_OLHAR, func(k: float) -> void:
		var t := k * DUR_OLHAR
		# levanta os olhos devagar, da beira pro alto das torres, e respira
		var incl := lerpf(-0.1, 0.07, _suave(k)) + sin(t * 1.25) * 0.006
		var giro := sin(t * 0.45) * 0.025
		var olho := _olho() + Vector3.UP * sin(t * 1.25) * 0.012
		_plantar(olho, olho + _dir_olhar(incl, giro) * 40.0))


# ============================================================ 4) a passagem

func _gargula_passa() -> void:
	var e := _olho()
	var d := _dir_vista(e)
	var lado := Vector3(-d.z, 0.0, d.x)
	var cima := Vector3.UP
	var g0 := e - d * 26.0 + lado * 10.0 + cima * 16.0
	var g1 := e - d * 7.0 + lado * 4.5 + cima * 7.5
	var g2 := e + d * 6.0 + lado * 1.5 + cima * 3.5
	var g3 := e + d * 28.0 - lado * 2.0 - cima * 3.0
	gargula = load(CENA_GARGULA).instantiate() as Node3D
	cena.add_child(gargula)
	gargula.voo_dirigido_iniciar(g0, g1)
	# lambda copia as variaveis locais: o que tem de durar entre quadros vai
	# num dicionario (referencia)
	var estado := {"gritou": false}
	var olhar_vista := e + _dir_olhar(0.07) * 40.0
	await _fase(DUR_PASSAGEM, func(k: float) -> void:
		if not is_instance_valid(gargula):
			return
		var pg := _bezier(g0, g1, g2, g3, k)
		gargula.voo_dirigido_ir(pg, lerpf(1.0, 0.6, k))
		if not estado.gritou and k > 0.28:
			estado.gritou = true
			_tocar("grito_gargula", randf_range(1.3, 1.5))
			GlobalUtils.vibrate_controller(null, 0.25, 0.4, 0.35)
		# o olho acompanha quando ela passa por cima e entra no quadro
		var segue := _suave(clampf((k - 0.4) / 0.45, 0.0, 1.0))
		var tremor := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.02 * sin(clampf((k - 0.3) / 0.4, 0.0, 1.0) * PI)
		_plantar(_olho() + tremor, olhar_vista.lerp(pg, segue * 0.85)))


# ============================================================ 5) o voo

## A gárgula dá uma volta larga em torno do topo, subindo e se afastando; a
## câmera vai montada nela, virada pro Maycow. O fade começa no fim do voo.
func _voar_na_gargula() -> void:
	var centro := player.global_position
	var g_ini := gargula.global_position if is_instance_valid(gargula) else _olho()
	var rel := g_ini - centro
	var r0 := Vector2(rel.x, rel.z).length()
	var a0 := atan2(rel.z, rel.x)
	var y0 := rel.y
	# gira pro lado em que ela já vinha (a passagem termina um pouco à esquerda)
	var d := _dir_vista(centro)
	var sentido := 1.0 if (Vector3(-d.z, 0.0, d.x)).dot(rel) < 0.0 else -1.0
	var olho_ini := cam.global_position
	var dir_ini := -cam.global_basis.z
	var vento := cena.get_node_or_null("vento_som") as AudioStreamPlayer
	var vento_vol := vento.volume_db if vento else 0.0
	var estado := {"fade": false}
	var foco := CameraAttributesPractical.new()
	foco.dof_blur_far_enabled = true
	foco.dof_blur_amount = 0.0
	cam.attributes = foco
	# embaixo da lente da cena (-1) e do filtro PS1 do player: os dois passam
	# por cima do borrão, como no resto do jogo
	_borrao = CanvasLayer.new()
	_borrao.layer = -2
	add_child(_borrao)
	var borrao_mat := ShaderMaterial.new()
	borrao_mat.shader = load(SHADER_FOCO)
	var borrao_tela := ColorRect.new()
	borrao_tela.material = borrao_mat
	borrao_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	borrao_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_borrao.add_child(borrao_tela)
	_recorte = OmniLight3D.new()
	_recorte.light_color = Color(1.0, 0.72, 0.5)
	_recorte.light_energy = 0.0
	_recorte.omni_range = 9.0
	cena.add_child(_recorte)
	_recorte.global_position = centro + Vector3.UP * 2.4 - d * 1.5
	var total := DUR_PEGAR + DUR_VOO
	await _fase(total, func(k: float) -> void:
		var t := k * total
		var u := t / total
		# o raio cresce rápido no começo (ela sai em linha) e o giro entra devagar
		var r := lerpf(r0, RAIO_FINAL, 1.0 - pow(1.0 - u, 1.6))
		var a := a0 + sentido * GIRO_DO_VOO * _suave(u)
		var h := y0 + SUBIDA_DO_VOO * _suave(u) + sin(t * 0.7) * 1.5
		var pg := centro + Vector3(cos(a) * r, h, sin(a) * r)
		if is_instance_valid(gargula):
			gargula.voo_dirigido_ir(pg, 0.55 + 0.35 * sin(t * 1.3))
		var fora := Vector3(pg.x - centro.x, 0.0, pg.z - centro.z).normalized()
		var lado := Vector3(-fora.z, 0.0, fora.x) * sentido
		var montada := pg + fora * MONTADA_FORA + Vector3.UP * MONTADA_CIMA + lado * MONTADA_LADO
		montada += Vector3.UP * sin(t * 7.5) * 0.06
		# a pegada: do olho do Maycow pro lombo da gárgula. Primeiro o olho
		# SEGUE a gárgula; já longe do topo, vira pra trás, pro Maycow. Gira a
		# DIREÇÃO (guinada e arfagem), não o ponto mirado: na meia volta o
		# ponto passaria por dentro da câmera e a imagem capotaria
		var p := _suave(clampf(t / DUR_PEGAR, 0.0, 1.0))
		# em arco por cima: em linha reta ela atravessava o fogo da pira
		var pos := olho_ini.lerp(montada, p) + Vector3.UP * sin(p * PI) * 5.0
		var dir_g := (pg - pos).normalized() if pos.distance_to(pg) > 0.5 else dir_ini
		var dir_a := dir_ini.slerp(dir_g, _suave(clampf(p / 0.45, 0.0, 1.0)))
		var dir_fim := (centro + Vector3.UP * 0.4 - pos).normalized()
		var vira := _suave(clampf((p - 0.45) / 0.55, 0.0, 1.0))
		var guinada := lerp_angle(atan2(dir_a.x, dir_a.z), atan2(dir_fim.x, dir_fim.z), vira)
		var arfagem := lerpf(asin(clampf(dir_a.y, -1.0, 1.0)), asin(clampf(dir_fim.y, -1.0, 1.0)), vira)
		var dir := Vector3(sin(guinada) * cos(arfagem), sin(arfagem), cos(guinada) * cos(arfagem))
		_plantar(pos, pos + dir * 10.0, sin(t * 0.8) * 0.06 * p)
		# o foco fica no Maycow; o borrão entra enquanto a câmera vira pra ele
		var maycow := player.global_position + Vector3.UP * 0.9
		var dist := pos.distance_to(maycow)
		var faixa := maxf(dist * FOCO_FRACAO, FOCO_MIN)
		var borra := _suave(clampf((p - 0.2) / 0.6, 0.0, 1.0))
		foco.dof_blur_far_distance = dist + faixa
		foco.dof_blur_far_transition = faixa * 1.5
		foco.dof_blur_amount = DESFOQUE * borra
		if cam.is_position_behind(maycow):
			borra = 0.0
		var tam := get_viewport().get_visible_rect().size
		borrao_mat.set_shader_parameter("foco", cam.unproject_position(maycow) / tam)
		# o círculo acompanha o tamanho dele na tela (1,8 m a `dist`, fov 70)
		borrao_mat.set_shader_parameter("raio", 0.05 + 2.6 / maxf(dist, 1.0))
		borrao_mat.set_shader_parameter("forca", borra)
		if is_instance_valid(_recorte):
			_recorte.light_energy = 4.0 * p
		if p > 0.25 and _modelo_escondido:
			_esconder_modelo(false)
		if vento:
			vento.volume_db = vento_vol + 9.0 * sin(clampf(u * 1.4, 0.0, 1.0) * PI * 0.5)
		if not estado.fade and t > total - DUR_FADE:
			estado.fade = true
			_escurecer(1.0, DUR_FADE))
	if vento:
		vento.volume_db = vento_vol
	await _esperar(DUR_PRETO)


# ============================================================ entra/sai

func _travar() -> void:
	GlobalEvents.in_cutscene = true
	player.velocity = Vector3.ZERO
	# a câmera de cinema nasce onde a do jogo está, e só então a do player sai
	cam = Camera3D.new()
	cam.name = "camera_mirante"
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 4000.0
	cena.add_child(cam)
	var atual := get_viewport().get_camera_3d()
	if atual:
		cam.global_transform = atual.global_transform
		cam.fov = atual.fov
	else:
		cam.global_transform = player.global_transform.translated_local(Vector3(0, 1, 3))
	cam.make_current()
	create_tween().tween_property(cam, "fov", 70.0, 1.2)
	player.cutscene_set_hud_enabled(false)
	player.cutscene_set_player_control(false)
	player.cutscene_set_camera_current(false)
	# a tela preta do fim, própria: o fade da cena tem duração fixa de 2 s
	_camada = CanvasLayer.new()
	_camada.layer = 90
	add_child(_camada)
	_tela = ColorRect.new()
	_tela.color = Color.BLACK
	_tela.modulate.a = 0.0
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(_tela)


## Devolve tudo, na tela preta, e abre devagar. Vale também se a cena morrer
## no meio (jogador morto, troca de cena): o input nunca fica travado.
func _encerrar() -> void:
	if _acabou:
		return
	_acabou = true
	if is_instance_valid(_tela) and _tela.modulate.a < 0.99:
		_tela.modulate.a = 1.0
	if is_instance_valid(gargula):
		gargula.queue_free()
	if is_instance_valid(_recorte):
		_recorte.queue_free()
	if is_instance_valid(_borrao):
		_borrao.queue_free()
	if is_instance_valid(player):
		player.cutscene_set_auto_walk(false)
		if _modelo_escondido:
			_esconder_modelo(false)
		player.cutscene_set_camera_current(true)
		player.cutscene_set_player_control(true)
		player.cutscene_set_hud_enabled(true)
	if is_instance_valid(cam):
		cam.queue_free()
	GlobalEvents.in_cutscene = false
	if is_inside_tree() and is_instance_valid(_tela):
		await _esperar(0.25)
		await _escurecer(0.0, DUR_FADE_IN)
	queue_free()


# ============================================================ peças

func _vale() -> bool:
	return is_instance_valid(player) and player.is_inside_tree() and is_instance_valid(cam) \
			and is_inside_tree()


func _esconder_modelo(sim: bool) -> void:
	_modelo_escondido = sim
	if not is_instance_valid(player):
		return
	player.cutscene_set_model_hidden(sim)
	if not sim:
		var modelo = player.get("modelo_visual")
		if is_instance_valid(modelo):
			modelo.visible = true


## Onde ficam os olhos do Maycow: o marcador de 1ª pessoa do próprio player,
## um palmo à frente (senão a câmera nasce dentro da cabeça).
func _olho() -> Vector3:
	var marcador = player.get("camera_first_person_marker")
	var base: Vector3 = (marcador as Node3D).global_position if is_instance_valid(marcador) \
			else player.global_position + Vector3.UP * 0.5
	return base + _dir_vista(base) * 0.15


## Direção (no chão) de `de` até o alvo da vista (a rosácea da catedral).
func _dir_vista(de: Vector3) -> Vector3:
	var alvo := _alvo()
	var d := Vector3(alvo.x - de.x, 0.0, alvo.z - de.z)
	return d.normalized() if d.length() > 0.01 else -player.global_basis.z


## Pra onde o olho aponta: a vista, inclinada `incl` rad pra cima e girada
## `giro` rad pro lado.
func _dir_olhar(incl: float, giro: float = 0.0) -> Vector3:
	var d := _dir_vista(player.global_position).rotated(Vector3.UP, giro)
	return (d * cos(incl) + Vector3.UP * sin(incl)).normalized()


func _alvo() -> Vector3:
	var m := cena.get_node_or_null("mirante/vista_alvo") as Node3D
	return m.global_position if m else player.global_position - player.global_basis.z * 100.0


## Distância (no chão) do ponto até a beira do mirante (os dois marcadores).
func _dist_beira(p: Vector3) -> float:
	var a := cena.get_node_or_null("mirante/beira_0") as Node3D
	var b := cena.get_node_or_null("mirante/beira_1") as Node3D
	if a == null or b == null:
		return INF
	var a2 := Vector2(a.global_position.x, a.global_position.z)
	var b2 := Vector2(b.global_position.x, b.global_position.z)
	var p2 := Vector2(p.x, p.z)
	var ab := b2 - a2
	var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


## Posiciona a câmera olhando `alvo`, com `rolagem` rad em torno do próprio eixo.
func _plantar(pos: Vector3, alvo: Vector3, rolagem: float = 0.0) -> void:
	if not is_instance_valid(cam) or pos.distance_squared_to(alvo) < 0.0001:
		return
	cam.look_at_from_position(pos, alvo, Vector3.UP)
	if rolagem != 0.0:
		cam.rotate_object_local(Vector3.FORWARD, rolagem)


func _tocar(no: String, tom: float) -> void:
	var som := cena.get_node_or_null(no) as AudioStreamPlayer
	if som:
		som.pitch_scale = tom
		som.play()


func _escurecer(alvo: float, duracao: float) -> void:
	if not is_instance_valid(_tela):
		return
	var tw := create_tween()
	tw.tween_property(_tela, "modulate:a", alvo, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Roda `passo` quadro a quadro por `duracao` segundos, com o andamento (0..1).
## A câmera e a gárgula são escritas no MESMO passo (a câmera pendura nela).
## Com o jogo pausado o relógio da cena para junto.
func _fase(duracao: float, passo: Callable) -> void:
	var t := 0.0
	while t < duracao:
		await get_tree().process_frame
		if not _vale():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		passo.call(clampf(t / duracao, 0.0, 1.0))


func _esperar(segundos: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(segundos, false).timeout


static func _suave(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)
