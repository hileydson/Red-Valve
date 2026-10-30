extends Node3D

## O PORTAL QUE SUGA: o vento entrando num vórtice, o jogador puxado pra dentro
## quando chega perto, e o mesmo jogador CUSPIDO pra fora quando é aqui que ele
## chega.
##
## Não desenha o vórtice (o redemoinho de cada cena é dela: anel, boca, porta);
## fica no CENTRO dele e põe em volta:
##
##  - o VENTO: faíscas e poeira nascendo numa casca em volta e sendo puxadas,
##    girando, até o centro — o redemoinho respirando pra dentro — e o som de
##    vendaval, que cresce quando se chega perto;
##  - a SUCÇÃO: o jogador que entra no `raio_captura` perde o controle e vai
##    andando pro portal enquanto o corpo QUEIMA E SOME — o teleporte da Dona
##    Nice (`dissolver_corpo.gd` + `teleporte_dona_nice.gd`) —, com a câmera
##    olhando; no meio do caminho começa a viagem (`viagem_portal.gd`: as
##    linhas roxas). Sem rodopio: era o que fazia o Maycow girar na entrada;
##  - a CHEGADA (`ejetar`): o jogador SURGE no marcador de chegada com o mesmo
##    efeito, ao contrário. O portal fica DESARMADO até ele se afastar, senão o
##    sugaria de volta no mesmo instante.
##
## Quem monta: a cena (`inferno.gd`, a porta red valve), com `montar(...)`.

const ViagemPortal := preload("res://scripts/systems/viagem_portal.gd")
const DissolverCorpo := preload("res://scripts/effects/dissolver_corpo.gd")
const TELEPORTE := preload("res://scripts/effects/teleporte_dona_nice.gd")
## Andando pro portal enquanto some; e surgindo na chegada.
const DUR_SUMINDO := 2.2
const DUR_SURGINDO := 0.9
const SOM_VENTO := "res://assets/sounds/cenarios/vento_tempestade.ogg"

## O jogador entrou no portal (a viagem já começou).
signal sugou

## Metade do lado da malha do vórtice.
var raio: float = 11.5
## Direção (horizontal) pra onde o vórtice olha: o lado de onde se chega e por
## onde se é cuspido.
var frente: Vector3 = Vector3.BACK
## Distância HORIZONTAL do centro em que o jogador é pego (sai do raio do
## vórtice, a menos que `captura_fixa` > 0).
var raio_captura: float = 7.0
var captura_fixa: float = -1.0
var destino: String = ""
var ponto_destino: String = ""
var cor: Color = Color(1.0, 0.45, 0.2)
## Falso logo depois de cuspir alguém, até ele se afastar.
var armado: bool = true
## Raio da casca de onde o vento nasce (<= 0: o do vórtice + 9 m). A porta red
## valve, pequena, usa uma casca curta.
var casca_vento: float = -1.0
## Quem é dono do portal desliga ele inteiro (a porta red valve fechada).
var bloqueado: bool = false
## Com prompt: chegar perto não suga — pergunta (`chave_prompt`), e o aceitar
## entra. É o portal do COMEÇO de um mapa, por onde se volta: ser sugado de
## volta só por passar perto dele seria castigo.
var com_prompt: bool = false
var chave_prompt: String = "PROMPT_VOLTAR_PORTAL"
var _perguntando := false

var _vento: AudioStreamPlayer3D
var _faiscas: GPUParticles3D
var _poeira: GPUParticles3D
var _ocupado: bool = false
var _cam: Camera3D


## `vortice`: o nó do redemoinho (o centro dele é o deste portal).
func montar(vortice: Node3D, raio_vortice: float, frente_v: Vector3, cena: String, ponto: String) -> void:
	global_position = vortice.global_position
	raio = raio_vortice
	frente = Vector3(frente_v.x, 0.0, frente_v.z).normalized()
	if frente.length() < 0.5:
		frente = Vector3.BACK
	raio_captura = captura_fixa if captura_fixa > 0.0 else clampf(raio * 0.75, 4.5, 9.0)
	destino = cena
	ponto_destino = ponto
	_criar_vento()


func _physics_process(_delta: float) -> void:
	if _ocupado or bloqueado:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if not armado:
		if d > raio_captura + 5.0:
			armado = true
		return
	if destino == "" or GlobalEvents.in_cutscene:
		_perguntar(false)
		return
	var dy := player.global_position.y - global_position.y
	var dentro := d < raio_captura and dy > -raio - 4.0 and dy < raio
	if com_prompt:
		_perguntar(dentro)
		if dentro and Input.is_action_just_pressed("ui_accept"):
			_perguntar(false)
			sugar(player)
	elif dentro:
		sugar(player)
	# o vendaval sobe chegando perto
	if _vento:
		_vento.volume_db = lerpf(-4.0, 4.0, clampf(1.0 - (d - raio_captura) / 30.0, 0.0, 1.0))


## Também chamado pela área de entrada da cena, se o jogador entrar nela antes.
func tentar_sugar(corpo: Node3D) -> void:
	if bloqueado or com_prompt:
		return
	if armado and not _ocupado and destino != "" and not GlobalEvents.in_cutscene and corpo is CharacterBody3D:
		sugar(corpo as CharacterBody3D)


func _perguntar(sim: bool) -> void:
	if sim == _perguntando:
		return
	_perguntando = sim
	if sim:
		GlobalUtils.show_center_message("portal_" + name, tr(chave_prompt), 16)
	else:
		GlobalUtils.hide_center_message("portal_" + name)


# ==============================================================================
# SUCÇÃO
# ==============================================================================
func sugar(player: CharacterBody3D) -> void:
	_ocupado = true
	armado = false
	_travar(player)
	var centro := global_position
	var fov0 := _cam.fov
	var corpo = _vestir_dissolver(player)
	var rastro := TELEPORTE.criar(get_tree().current_scene, _pe(player), 1.0, false)
	_soprar(2.4)
	GlobalUtils.vibrate_controller(null, 0.6, 0.8, 1.4)
	var estado := {"pediu": false, "viajou": false}
	if player.has_method("cutscene_set_auto_walk"):
		player.cutscene_set_auto_walk(true)
	await _fase(DUR_SUMINDO, func(k: float) -> void:
		if not is_instance_valid(player):
			return
		# de frente pro portal, andando pra ele (a caminhada é a da cutscene)
		var d := Vector3(centro.x - player.global_position.x, 0.0, centro.z - player.global_position.z)
		if d.length() > 0.3:
			player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 0.2)
		if corpo:
			# o corpo queima quase todo ANTES da viagem tomar a tela
			corpo.parametro("dissolver", smoothstep(0.05, 0.62, k))
			corpo.parametro("veias", clampf(k * 3.0, 0.0, 1.0))
		if is_instance_valid(rastro):
			rastro.global_position = _pe(player)
		if is_instance_valid(_cam):
			_cam.look_at(player.global_position + Vector3.UP * 0.4)
			_cam.fov = lerpf(fov0, fov0 - 10.0, smoothstep(0.0, 1.0, k))
		if not estado.pediu and k > 0.6:
			estado.pediu = true
			estado.viajou = ViagemPortal.viajar(get_tree(), destino, ponto_destino, 1.6, 2.0) != null
			if estado.viajou:
				sugou.emit())
	if not is_instance_valid(player):
		return
	if player.has_method("cutscene_set_auto_walk"):
		player.cutscene_set_auto_walk(false)
	player.velocity = Vector3.ZERO
	_esconder(player, true)
	if not estado.viajou:
		# outra viagem já estava em curso (ou destino ruim): devolve tudo
		if corpo:
			corpo.restaurar()
		_esconder(player, false)
		_soltar(player)


# ==============================================================================
# CHEGADA
# ==============================================================================
## O jogador SURGE em `marcador` (os pés na posição dele, virado pra onde ele
## olha): o corpo aparece queimando, ao contrário de quando entrou.
func ejetar(player: CharacterBody3D, marcador: Node3D) -> void:
	_ocupado = true
	armado = false
	_travar(player)
	var giro_fim := marcador.global_rotation.y
	var fim := marcador.global_position + Vector3.UP
	player.global_transform = Transform3D(Basis(Vector3.UP, giro_fim), fim)
	player.velocity = Vector3.ZERO
	# o corpo olha pro -Z: a câmera fica na frente dele, um pouco de lado
	var olha := Vector3(-sin(giro_fim), 0.0, -cos(giro_fim))
	var lado := Vector3(-olha.z, 0.0, olha.x)
	_cam.global_position = fim + olha * 3.6 + lado * 1.3 + Vector3.UP * 0.5
	_cam.look_at(fim + Vector3.UP * 0.1)
	var corpo = _vestir_dissolver(player)
	if corpo:
		corpo.parametro("dissolver", 1.0)
		corpo.parametro("veias", 1.0)
	_esconder(player, true)
	_soprar(1.6)
	# a tela ainda está saindo do preto: o primeiro instante é o lugar sozinho
	await _esperar(0.55)
	if not is_instance_valid(player):
		return
	TELEPORTE.criar(get_tree().current_scene, marcador.global_position, 1.0, true)
	await _esperar(0.2)
	if not is_instance_valid(player):
		return
	_esconder(player, false)
	await _fase(DUR_SURGINDO, func(k: float) -> void:
		if corpo:
			corpo.parametro("dissolver", 1.0 - smoothstep(0.0, 1.0, k))
			corpo.parametro("veias", 1.0 - k * 0.8))
	if not is_instance_valid(player):
		return
	if corpo:
		corpo.restaurar()
	GlobalUtils.vibrate_controller(null, 0.7, 0.5, 0.35)
	_tremer_camera(0.35)
	await _esperar(0.45)
	_soltar(player)


# ==============================================================================
# PEÇAS
# ==============================================================================
func _travar(player: CharacterBody3D) -> void:
	GlobalEvents.in_cutscene = true
	var atual := get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.name = "camera_portal"
	_cam.far = 4000.0
	get_tree().current_scene.add_child(_cam)
	if atual:
		_cam.global_transform = atual.global_transform
		_cam.fov = atual.fov
	_cam.make_current()
	if player.has_method("cutscene_set_player_control"):
		player.cutscene_set_player_control(false)
		player.cutscene_set_hud_enabled(false)
		player.cutscene_set_camera_current(false)
	player.velocity = Vector3.ZERO


func _soltar(player: CharacterBody3D) -> void:
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
		_esconder(player, false)
		if player.has_method("cutscene_set_player_control"):
			player.cutscene_set_camera_current(true)
			player.cutscene_set_player_control(true)
			player.cutscene_set_hud_enabled(true)
	if is_instance_valid(_cam):
		_cam.queue_free()
	GlobalEvents.in_cutscene = false
	_ocupado = false


func _modelo(player: Node) -> Node3D:
	var m = player.get("modelo_visual")
	return m as Node3D if m is Node3D else null


## O modelo inteiro do jogador (o nó filho dele que tem a malha): a arma na
## mão e a lanterna no cinto queimam junto com o corpo.
func _raiz_do_modelo(player: Node) -> Node:
	var m: Node = _modelo(player)
	while m and m.get_parent() and m.get_parent() != player:
		m = m.get_parent()
	return m


func _vestir_dissolver(player: Node) -> RefCounted:
	var raiz := _raiz_do_modelo(player)
	return DissolverCorpo.vestir(raiz) if raiz else null


## Esconde pela trava de cutscene: o player reescreve a visibilidade do modelo
## todo quadro, e só ela segura.
func _esconder(player: Node, sim: bool) -> void:
	if player.has_method("cutscene_set_model_hidden"):
		player.cutscene_set_model_hidden(sim)
	var modelo := _modelo(player)
	if modelo:
		modelo.visible = not sim


## Os pés dele (a origem é o meio da cápsula).
func _pe(player: Node3D) -> Vector3:
	var de := player.global_position
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 3.0)
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3) if not h.is_empty() else de - Vector3.UP * 0.9


## O vento acelera um tempo (quem entra ou sai leva a ventania junto).
func _soprar(segundos: float) -> void:
	for p in [_faiscas, _poeira]:
		if p:
			var t := create_tween()
			t.tween_property(p, "speed_scale", 2.2, 0.3)
			t.tween_interval(segundos)
			t.tween_property(p, "speed_scale", 1.0, 1.0)


func _tremer_camera(segundos: float) -> void:
	if not is_instance_valid(_cam):
		return
	var t := 0.0
	while t < segundos and is_instance_valid(_cam) and is_inside_tree():
		await get_tree().process_frame
		if not is_instance_valid(_cam):
			return
		t += get_process_delta_time()
		var f := 1.0 - t / segundos
		_cam.h_offset = randf_range(-1.0, 1.0) * 0.12 * f
		_cam.v_offset = randf_range(-1.0, 1.0) * 0.12 * f
	if is_instance_valid(_cam):
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0


## `passo(k)` com k de 0 a 1 ao longo de `duracao` segundos; para com o jogo
## pausado.
func _fase(duracao: float, passo: Callable) -> void:
	var t := 0.0
	while t < duracao:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		passo.call(clampf(t / duracao, 0.0, 1.0))


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, false).timeout


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


# ==============================================================================
# O VENTO
# ==============================================================================
## Liga/desliga o vento (a porta red valve só venta aberta).
func ventar(sim: bool) -> void:
	for p in [_faiscas, _poeira]:
		if p:
			p.emitting = sim
	if _vento:
		if sim and not _vento.playing:
			_vento.play()
		elif not sim:
			_vento.stop()


func _criar_vento() -> void:
	var casca := casca_vento if casca_vento > 0.0 else raio + 9.0
	# todas chegam ao centro juntas: aceleração proporcional à distância,
	# t = sqrt(2 / k) com a = k * casca
	var k := 1.1
	var vida := sqrt(2.0 / k)
	# casca pequena (porta), risco curto e menos dele
	var f := clampf(casca / 20.5, 0.25, 1.0)
	# casca pequena: a câmera fica DENTRO do vento, e o risco passa rente a ela
	var a := lerpf(0.35, 0.9, f)
	_faiscas = _emissor(int(320 * f), vida, casca, k, _malha_faisca(f), Vector2(0.9, 1.3), a)
	_poeira = _emissor(int(70 * f) + 6, vida, casca, k, _malha_poeira(f), Vector2(0.7, 1.4), a)
	var p := _poeira.process_material as ParticleProcessMaterial
	p.particle_flag_align_y = false
	_vento = AudioStreamPlayer3D.new()
	var som := load(SOM_VENTO)
	if som:
		som = som.duplicate()
		if "loop" in som:
			som.loop = true
		_vento.stream = som
	_vento.unit_size = maxf(raio, 6.0)
	_vento.max_distance = raio * 7.0 + 30.0
	_vento.volume_db = -4.0
	_vento.autoplay = true
	add_child(_vento)


func _emissor(quantas: int, vida: float, casca: float, k: float, malha: Mesh, escala: Vector2, alfa: float) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = quantas
	g.lifetime = vida
	g.preprocess = vida
	g.visibility_aabb = AABB(Vector3.ONE * -(casca + 4.0), Vector3.ONE * (casca + 4.0) * 2.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	m.emission_sphere_radius = casca
	m.gravity = Vector3.ZERO
	m.radial_accel_min = -casca * k * 0.9
	m.radial_accel_max = -casca * k * 1.1
	m.tangential_accel_min = 3.0
	m.tangential_accel_max = 7.0
	m.scale_min = escala.x
	m.scale_max = escala.y
	m.particle_flag_align_y = true
	var rampa := Gradient.new()
	rampa.set_color(0, Color(cor, 0.0))
	rampa.set_color(1, Color(cor, 0.0))
	rampa.add_point(0.25, Color(cor, alfa))
	rampa.add_point(0.8, Color(cor.lerp(Color.WHITE, 0.3 * alfa), alfa * 0.9))
	var tex := GradientTexture1D.new()
	tex.gradient = rampa
	m.color_ramp = tex
	g.process_material = m
	g.draw_pass_1 = malha
	add_child(g)
	return g


## Risco fino, alinhado com a velocidade e virado pra câmera em volta do
## próprio eixo (billboard Y): lê como rajada, não como ponto.
func _malha_faisca(f: float) -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 1.5) * maxf(f, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_some_perto_da_camera(mat)
	q.material = mat
	return q


func _malha_poeira(f: float) -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 1.8) * maxf(f, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 0.06)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	mat.albedo_texture = ImageTexture.create_from_image(img)
	_some_perto_da_camera(mat)
	q.material = mat
	return q


## Risco que passa rente à lente vira barra branca atravessando a tela: perto
## da câmera ele some.
static func _some_perto_da_camera(mat: StandardMaterial3D) -> void:
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.8
	mat.distance_fade_max_distance = 3.2
