extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func process_combat(delta: float) -> void:
	# GIRO DA COGBLADE (só durante o arremesso normal, não durante a cinemática do ultimate)
	if is_instance_valid(player.crescent_cogblade) and player.crescent_cogblade.top_level and not player.is_using_ultimate and not player.cogblade_melee_active:
		player.crescent_cogblade.global_rotate(Vector3.UP, -15.0 * delta)

	# LÓGICA DO BUMERANGUE (COGBLADE RETORNANDO)
	if player.is_blade_returning and is_instance_valid(player.crescent_cogblade):
		var target_pos = player.camera.global_transform.origin + player.camera.global_transform.basis * player.magic_blade_pos_original
		player.crescent_cogblade.global_transform.origin = player.crescent_cogblade.global_transform.origin.move_toward(target_pos, delta * player.blade_return_speed)
		
		if player.crescent_cogblade.global_transform.origin.distance_to(target_pos) < 0.8:
			player.is_blade_returning = false
			player.crescent_cogblade.top_level = false
			player.crescent_cogblade.position = player.magic_blade_pos_original
			player.crescent_cogblade.rotation = Vector3.ZERO
			player.crescent_cogblade.hide()
			
			var bb = player.crescent_cogblade.get_node_or_null("blade_back")
			if bb: bb.play()
			
			var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas")
			if faiscas: faiscas.emitting = false
			
			player.is_magic_attacking = false
			if player.hand_magic_tree:
				var pb = player.hand_magic_tree["parameters/playback"]
				if pb: pb.travel("idle")
				
			var tween_hand = create_tween()
			tween_hand.tween_interval(0.2)
			tween_hand.tween_property(player.hand_magic_3d, "position", player.hand_magic_3d_pos_hidden, 1.5).set_trans(Tween.TRANS_SINE)

func reload() -> void:
	if player.is_first_person and not player.is_reloading and not player.is_magic_attacking:
		var total = SaveManager.get_item_amount("pistol_ammo")
		if total <= 0 or player.clip_pistol_ammo >= player.max_clip_pistol:
			return
			
		player.is_reloading = true
		
		var needed = player.max_clip_pistol - player.clip_pistol_ammo
		var taken = mini(needed, total)
		SaveManager.remove_item_amount("pistol_ammo", taken)
		player.clip_pistol_ammo += taken
		player.update_ammo_ui()
		
		if not is_instance_valid(player.current_weapon): 
			player.is_reloading = false
			return

		player.gun_load.play()
		
		if is_instance_valid(player.hand_magic_3d): 
			player.hand_magic_3d.position = player.hand_magic_3d_pos_original
			player.hand_magic_3d.visible = true
			
		if player.hand_magic_tree:
			var pb = player.hand_magic_tree["parameters/playback"]
			if pb: pb.travel("magic_reload")
		
		if player.hand_animations:
			player.hand_animations.play("reload")
			await player.hand_animations.animation_finished
		else:
			await get_tree().create_timer(1.0).timeout
			
		await get_tree().create_timer(0.2).timeout
			
		if is_instance_valid(player.hand_magic_3d): 
			var tween_retorno = create_tween()
			tween_retorno.tween_property(player.hand_magic_3d, "position", player.hand_magic_3d_pos_hidden, 0.6).set_trans(Tween.TRANS_SINE)
			
		player.is_reloading = false

func magic_hand_attack() -> void:
	SaveManager.current_mp -= 10.0
	if SaveManager.current_mp < 0: SaveManager.current_mp = 0
	if player.is_reloading: return
	
	player.is_magic_attacking = true
	player.slay_it.play()
	player.blade_out.play()
	
	if player.hand_magic_tree:
		var pb = player.hand_magic_tree["parameters/playback"]
		if pb: pb.travel("attack")
		
	var tween_magic = create_tween().set_parallel(true)
	
	var pos_alvo = player.hand_magic_3d_pos_original + Vector3(0, 0, 0.1)
	player.hand_magic_3d.visible = true
	tween_magic.tween_property(player.hand_magic_3d, "position", pos_alvo, 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	player.crescent_cogblade.show()
	player.crescent_cogblade.top_level = true
	
	var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas") 
	if faiscas: faiscas.emitting = true
	
	player.crescent_cogblade.global_rotation_degrees = Vector3(player.cogblade_tilt_x, player.camera.global_rotation_degrees.y + player.cogblade_tilt_y, player.cogblade_tilt_z)
	
	var dir = -player.camera.global_transform.basis.z
	var pos_final_global = player.crescent_cogblade.global_transform.origin + (dir * 11.0)
	
	tween_magic.tween_property(player.crescent_cogblade, "global_transform:origin", pos_final_global, 1.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	await tween_magic.finished
	
	player.is_blade_returning = true
	
	var tween_hand = create_tween()
	var pos_recuo = player.hand_magic_3d_pos_original + Vector3(0.0, -0.4, 0.6)
	tween_hand.tween_property(player.hand_magic_3d, "position", pos_recuo, 0.5)\
		.set_trans(Tween.TRANS_QUAD)

func cast_spell() -> void:
	player.magic_hand_particles.emitting = true
	player.blade_light.visible = true
	
	var tween = create_tween()
	player.magic_hand_particles.amount = 50
	
	tween.tween_property(player.magic_hand_particles.process_material, "scale_min", 2.0, 0.5)
	await get_tree().create_timer(3.0).timeout
	player.magic_hand_particles.emitting = false
	player.blade_light.visible = false

func shoot(input: Variant) -> void:
	if not SaveManager.is_equipped("pistol"): return
	if player.is_reloading: return
	
	if player.can_shoot_again and player.camera.current:
		if player.clip_pistol_ammo <= 0:
			return
			
		player.clip_pistol_ammo -= 1
		player.update_ammo_ui()
		
		if not is_instance_valid(player.current_weapon): return

		player.current_weapon = player.hand_with_pistol
		var rotation_default = player.current_weapon.rotation

		var tween = create_tween()
		player.fire.play("shoot")
		GlobalUtils.shake_camera(0.03, 0.05)
		GlobalUtils.vibrate_controller(input, 0.5, 0.0, 0.1)
		player.faisca.restart()
		player.faisca.emitting = true
		player.gun_shot.play()
		player.can_shoot_again = false
		
		if player.capsula_scene:
			var capsula = player.capsula_scene.instantiate()
			get_tree().current_scene.add_child(capsula)
			capsula.add_collision_exception_with(player)
			var spawn_pos = player.camera.global_position + player.camera.global_transform.basis * Vector3(0.4, -0.1, -0.75)
			capsula.global_position = spawn_pos
			capsula.global_rotation = player.camera.global_rotation
			
			var eject_dir = player.camera.global_transform.basis * Vector3(1.0, 1.0, 0.0) 
			capsula.apply_central_impulse(eject_dir * randf_range(1.5, 2.0))
			capsula.apply_torque(Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))
		
		var flash_tween = create_tween()
		player.flash_tela.color.a = 0.1 
		flash_tween.tween_property(player.flash_tela, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		
		tween.parallel().tween_property(player.current_weapon, "position:x", player.current_weapon.position.x + 0.01, 0.05).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(player.current_weapon, "position:y", player.current_weapon.position.y - 0.01, 0.05).set_trans(Tween.TRANS_SINE)

		tween.tween_interval(0.1)

		player.current_weapon.rotation = rotation_default
		tween.parallel().tween_property(player.current_weapon, "position:x", player.current_weapon.position.x, 0.1).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(player.current_weapon, "position:y", player.current_weapon.position.y, 0.1).set_trans(Tween.TRANS_BACK)
		
		raycast_process_shoot()		
				
		await get_tree().create_timer(0.56).timeout
		player.can_shoot_again = true

func raycast_process_shoot() -> void:
	if player.ray_cast_3d.is_colliding():
		var target = player.ray_cast_3d.get_collider()
		
		if target and target.has_method("take_damage"):
			target.take_damage(player.damage_pistol)
			
			if target.is_in_group("enemies"):
				spawn_blood_raycast(player.ray_cast_3d.get_collision_point(), player.ray_cast_3d.get_collision_normal())
				add_cogblade_power(10.0, player.ray_cast_3d.get_collision_point())
		
			var ponto_colisao = player.ray_cast_3d.get_collision_point()
			var distancia = player.ray_cast_3d.global_position.distance_to(ponto_colisao)
			
			if target.name == "heart" and distancia > 7:
				player.bullet.visible = true
				target.take_damage(player.damage_pistol+player.damage_headshoot)
					
				var offset_altura = Vector3(0.25, -0.3, 0) 
				var alvo_ajustado = target.global_position + offset_altura

				var tween_bullet = create_tween()
				var voltas = deg_to_rad(1800) 
				tween_bullet.tween_property(player.bullet, "rotation:z", player.bullet.rotation.z + voltas, 2.5)\
					.set_trans(Tween.TRANS_LINEAR)
					
				player.control_weapons.visible = false
				player.hand_with_pistol.visible = false
				if player.hand_with_magic: player.hand_with_magic.visible = false
				player.control_magic.visible = false
				player.bullet_light.visible = true
				player.bullet.visible = true
				player.camera_bullet_time_ON = true
				GlobalUtils.ativar_camera_lenta(0.1, 60.0, true)
				
				var tween_cam = create_tween()
				
				player.camera_3d_bullet_time.global_position = player.camera.global_position
				player.camera_3d_bullet_time.make_current()
				
				tween_cam.tween_property(player.camera_3d_bullet_time, "global_position", alvo_ajustado + (player.ray_cast_3d.global_transform.basis.z * 2.0), 0.9)\
					.set_trans(Tween.TRANS_QUINT)\
					.set_ease(Tween.EASE_OUT)

				tween_cam.parallel().tween_method(
				func(_pos): player.camera_3d_bullet_time.look_at(alvo_ajustado),
					0.0, 1.0, 0.9
				)

				tween_cam.tween_interval(0.05)

				tween_cam.tween_property(player.camera_3d_bullet_time, "global_position", player.camera.global_position, 0.4)\
					.set_trans(Tween.TRANS_SINE)
				
				await get_tree().create_timer(0.65).timeout
				if player.camera_bullet_time_ON: bullet_time_back()

func bullet_time_back() -> void:	
	player.camera_bullet_time_ON = false
	player.bullet.visible = false
	GlobalUtils.remover_camera_lenta()
	
	if player.is_first_person:
		player.camera.make_current()
		player.control_weapons.visible = true
		player.hand_with_pistol.visible = SaveManager.is_equipped("pistol")
		if player.hand_with_magic: player.hand_with_magic.visible = true
		player.control_magic.visible = true
	else:
		player.camera_third_person.make_current()
	
	await get_tree().create_timer(0.16).timeout
	player.bullet_light.visible = false

func spawn_blood_raycast(pos: Vector3, normal: Vector3) -> void:
	if not is_inside_tree(): return
	var blood = player.blood_effect.instantiate()
	get_tree().root.add_child(blood)
	blood.global_position = pos

	if normal != Vector3.ZERO:
		blood.look_at(pos + normal, Vector3.UP)

func spawn_blood_effect(body: Node3D) -> void:
	if not is_inside_tree(): return
	var blood = player.blood_effect.instantiate()
	get_tree().root.add_child(blood)
	blood.global_position = body.global_position
	blood.global_position.y += 2
		
# =========================================================================
# SIFÃO DE SANGUE -> MEDIDOR DA COGBLADE
# =========================================================================
# O medidor não enche mais no instante do dano. Uma pequena porção do sangue
# do inimigo vira uma gota 2D que viaja até o player (centro da tela), vagueia
# um instante por pontos aleatórios ali por perto, sobe para o canto superior
# esquerdo (onde fica a HUD do medidor), respinga no medidor e só então o
# preenchimento acontece.

## Tempo da gota do inimigo até o centro da tela (o player).
const SIPHON_TO_PLAYER_TIME: float = 0.30
## Tempo do centro da tela até o medidor no canto superior esquerdo.
const SIPHON_TO_HUD_TIME: float = 0.26
## Quantas voltas a gota dá vagando perto do centro antes de subir pro medidor.
const SIPHON_WANDER_STEPS: int = 3
## Tempo de cada trecho do vaguear.
const SIPHON_WANDER_STEP_TIME: float = 0.22
## Raio (em pixels) da área em volta do centro onde a gota fica vagando.
const SIPHON_WANDER_RADIUS: Vector2 = Vector2(230.0, 150.0)
## Quantas gotas de sangue cada dano manda para o medidor.
const SIPHON_DROPS_PER_HIT: int = 4
## Atraso entre uma gota e a seguinte do mesmo golpe.
const SIPHON_DROP_STAGGER: float = 0.07
## Máximo de gotas simultâneas: acima disso o poder entra direto (sem FX),
## pra não virar chuva de sangue em rajadas rápidas de dano.
const SIPHON_MAX_ACTIVE: int = 24

var _siphons: Array[Node2D] = []
var _cogblade_fill_tween: Tween

func add_cogblade_power(amount: float, source_pos = null) -> void:
	if GlobalEvents.is_maycow_normal or not player.cogblade_hud or player.is_using_ultimate: return
	if amount <= 0.0: return

	var vivos: Array[Node2D] = []
	for s in _siphons:
		if is_instance_valid(s): vivos.append(s)
	_siphons = vivos

	var start = _siphon_screen_start(source_pos)
	if start == null or _siphons.size() >= SIPHON_MAX_ACTIVE:
		# Sem posição de origem visível na tela (ou FX demais): aplica direto.
		_apply_cogblade_power(amount)
		return

	_spawn_blood_siphon(start, amount, source_pos)

# Converte a posição 3D do golpe em coordenadas de tela. Retorna null quando
# não dá pra desenhar o trajeto (sem câmera, ou o alvo está atrás dela).
func _siphon_screen_start(source_pos):
	if not (source_pos is Vector3): return null
	if not is_inside_tree(): return null
	var vp := player.get_viewport()
	if not vp: return null
	var cam := vp.get_camera_3d()
	if not is_instance_valid(cam) or cam.is_position_behind(source_pos): return null

	var screen: Vector2 = cam.unproject_position(source_pos)
	var size: Vector2 = vp.get_visible_rect().size
	# Inimigo fora do enquadramento: puxa a gota pra borda mais próxima.
	screen.x = clamp(screen.x, 8.0, size.x - 8.0)
	screen.y = clamp(screen.y, 8.0, size.y - 8.0)
	return screen

func _spawn_blood_siphon(start: Vector2, amount: float, source_pos = null) -> void:
	if not is_instance_valid(player.hud_layer) or not is_instance_valid(player.cogblade_hud):
		_apply_cogblade_power(amount)
		return

	# O sangue sai do inimigo em várias gotas, não em uma só: elas partem de
	# pontos ligeiramente diferentes e escalonadas no tempo, então chegam no
	# medidor em sequência (várias respingadas em vez de uma).
	var total := SIPHON_DROPS_PER_HIT
	var share := amount / float(total)
	for i in total:
		var jitter := Vector2(randf_range(-26.0, 26.0), randf_range(-22.0, 22.0))
		_spawn_blood_drop(start + jitter, share, float(i) * SIPHON_DROP_STAGGER, source_pos)

# --- Ancoragem no mundo -----------------------------------------------------
# As gotas são nós 2D (HUD), mas ficam presas a pontos do MUNDO: a cada frame a
# posição na tela é recalculada projetando o ponto 3D pela câmera atual. Assim,
# girar a câmera faz o sangue deslizar pela tela como qualquer coisa parada no
# cenário, em vez de ficar colado no visor.

## Profundidade (em metros) dos pontos onde a gota vagueia à frente do jogador.
const SIPHON_WANDER_DEPTH: Vector2 = Vector2(3.0, 6.0)

func _cam() -> Camera3D:
	var vp := player.get_viewport() if is_instance_valid(player) else null
	if not vp: return null
	return vp.get_camera_3d()

## Ponto do mundo que hoje aparece em `screen`, à distância `dist` da câmera.
func _screen_to_world(screen: Vector2, dist: float) -> Vector3:
	var cam := _cam()
	if not is_instance_valid(cam): return Vector3.ZERO
	return cam.project_position(screen, dist)

## Onde um ponto do mundo cai na tela agora. Se ficou atrás da câmera, devolve
## `fallback` (a última posição válida), pra gota não pular pro outro lado.
func _world_to_screen(world: Vector3, fallback: Vector2) -> Vector2:
	var cam := _cam()
	if not is_instance_valid(cam) or cam.is_position_behind(world): return fallback
	return cam.unproject_position(world)

func _spawn_blood_drop(start: Vector2, amount: float, delay: float, source_pos = null) -> void:
	var vp_size: Vector2 = player.get_viewport().get_visible_rect().size
	var center: Vector2 = vp_size * 0.5
	var hud_target: Vector2 = _cogblade_hud_center()

	# Profundidade desta gota: quanto mais perto da câmera, mais ela desliza
	# quando o jogador vira - é o mesmo paralaxe de qualquer objeto do cenário.
	var depth := randf_range(SIPHON_WANDER_DEPTH.x, SIPHON_WANDER_DEPTH.y)
	var cam := _cam()
	# A origem fica presa ao ponto exato do golpe no inimigo (quando temos ele).
	var start_depth: float = depth
	if source_pos is Vector3 and is_instance_valid(cam):
		start_depth = maxf(cam.global_position.distance_to(source_pos), 0.5)
	var start_world: Vector3 = _screen_to_world(start, start_depth)

	# Cada gota tem tamanho e velocidade um pouco diferentes.
	var raio := randf_range(4.5, 7.5)
	var vel := randf_range(0.88, 1.15)

	var container := Node2D.new()
	container.name = "CogbladeBloodSiphon"
	container.position = start
	container.visible = delay <= 0.0
	player.hud_layer.add_child(container)
	_siphons.append(container)

	# Halo suave por trás da gota (dá o "brilho" molhado)
	var halo := Polygon2D.new()
	halo.polygon = _circle_points(raio * 2.0)
	halo.color = Color(0.55, 0.0, 0.0, 0.35)
	container.add_child(halo)

	var drop := Polygon2D.new()
	drop.polygon = _circle_points(raio)
	drop.color = Color(0.72, 0.02, 0.02, 1.0)
	container.add_child(drop)

	# Rastro: as partículas ficam no espaço da tela (local_coords = false),
	# então elas "sobram" no caminho enquanto a gota avança.
	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 40
	trail.lifetime = 0.5
	trail.speed_scale = 1.0
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 5.0
	trail.direction = Vector2(0, 1)
	trail.spread = 45.0
	trail.gravity = Vector2(0, 160)
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 55.0
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 4.5
	trail.color = Color(0.65, 0.0, 0.0, 0.85)
	var trail_ramp := Gradient.new()
	trail_ramp.offsets = [0.0, 1.0]
	trail_ramp.colors = [Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)]
	trail.color_ramp = trail_ramp
	trail.emitting = delay <= 0.0
	container.add_child(trail)

	# Curvas: a gota faz um arco em vez de linha reta. O lado e a altura do
	# arco variam, então gotas do mesmo golpe não viajam empilhadas.
	var arco := randf_range(35.0, 95.0) * (1.0 if randf() < 0.5 else -1.0)

	# Depois de chegar ao centro, a gota vagueia por pontos aleatórios ali por
	# perto antes de decidir subir - cada gota faz um caminho diferente.
	# Tanto o "centro" quanto os pontos do vaguear viram pontos do MUNDO à
	# frente do jogador - eles não são posições fixas de tela.
	var center_world: Vector3 = _screen_to_world(center, depth)
	var wander_world: Array[Vector3] = []
	for _i in SIPHON_WANDER_STEPS:
		var ang := randf() * TAU
		var raio_norm := sqrt(randf()) # Distribui sem amontoar no miolo
		var ponto := center + Vector2(
			cos(ang) * SIPHON_WANDER_RADIUS.x * raio_norm,
			sin(ang) * SIPHON_WANDER_RADIUS.y * raio_norm
		)
		wander_world.append(_screen_to_world(ponto, depth))

	# A subida pro medidor sai do último ponto do vaguear (também no mundo).
	var last_world: Vector3 = wander_world[wander_world.size() - 1] if wander_world.size() > 0 else center_world
	# Curvatura da subida, guardada como número: o traçado em si é recalculado
	# a cada frame com a projeção atualizada dos pontos.
	var hud_arco := randf_range(-70.0, 70.0)

	# Tween do próprio container: se ele for liberado (poder consumiu o medidor),
	# o trajeto morre junto e o preenchimento não acontece.
	var tw := container.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			if is_instance_valid(container):
				container.visible = true
				trail.emitting = true
		)

	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		# Reprojeta origem e destino todo frame: se o jogador girar a câmera no
		# meio do trajeto, a gota acompanha o cenário em vez da tela.
		var a := _world_to_screen(start_world, container.position)
		var b := _world_to_screen(center_world, container.position)
		var ctrl: Vector2 = a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * arco
		container.position = _bezier2(a, ctrl, b, t)
	, 0.0, 1.0, SIPHON_TO_PLAYER_TIME * vel).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Chegou ao centro: pequena "absorvida" (a gota infla e comprime). A posição
	# continua sendo reprojetada aqui também, senão a gota "congelaria" na tela
	# por um instante justo enquanto o jogador gira a câmera.
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		container.position = _world_to_screen(center_world, container.position)
		container.scale = Vector2.ONE.lerp(Vector2(1.5, 1.5), t)
	, 0.0, 1.0, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		container.position = _world_to_screen(center_world, container.position)
		container.scale = Vector2(1.5, 1.5).lerp(Vector2(0.85, 0.85), t)
	, 0.0, 1.0, 0.06).set_trans(Tween.TRANS_SINE)

	# Vagueia sem pressa entre os pontos sorteados, com uma curva em cada trecho.
	var anterior := center_world
	for destino in wander_world:
		var origem := anterior
		var curva := randf_range(-60.0, 60.0)
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(container): return
			var a := _world_to_screen(origem, container.position)
			var b := _world_to_screen(destino, container.position)
			var ctrl: Vector2 = a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * curva
			container.position = _bezier2(a, ctrl, b, t)
		, 0.0, 1.0, SIPHON_WANDER_STEP_TIME * randf_range(0.8, 1.3) * vel).set_trans(Tween.TRANS_SINE)
		anterior = destino

	# Só então sobe para o medidor. Aqui a gota "descola" do mundo e passa a
	# ser HUD: a origem ainda acompanha a câmera, o destino é o canto da tela.
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		var a := _world_to_screen(last_world, container.position)
		var ctrl: Vector2 = a.lerp(hud_target, 0.5) + (hud_target - a).orthogonal().normalized() * hud_arco
		container.position = _bezier2(a, ctrl, hud_target, t)
	, 0.0, 1.0, SIPHON_TO_HUD_TIME * vel).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.tween_callback(func() -> void:
		_siphons.erase(container)
		if is_instance_valid(container):
			trail.emitting = false
			halo.visible = false
			drop.visible = false
			# Deixa o rastro terminar de cair antes de sumir com o nó.
			container.create_tween().tween_callback(container.queue_free).set_delay(0.6)
		_cogblade_blood_splash()
		_apply_cogblade_power(amount)
	)

# Respingo rápido de sangue no medidor, no momento em que a gota chega.
func _cogblade_blood_splash() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.cogblade_hud): return
	if not is_instance_valid(player.hud_layer): return

	var splash := CPUParticles2D.new()
	splash.position = _cogblade_hud_center()
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 34
	splash.lifetime = 0.5
	splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	splash.emission_sphere_radius = 10.0
	splash.direction = Vector2(0, -1)
	splash.spread = 180.0
	splash.gravity = Vector2(0, 520)
	splash.initial_velocity_min = 70.0
	splash.initial_velocity_max = 230.0
	splash.scale_amount_min = 2.0
	splash.scale_amount_max = 5.5
	splash.color = Color(0.8, 0.0, 0.0, 0.9)
	var ramp := Gradient.new()
	ramp.offsets = [0.0, 0.7, 1.0]
	ramp.colors = [Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)]
	splash.color_ramp = ramp
	splash.emitting = true
	player.hud_layer.add_child(splash)
	splash.create_tween().tween_callback(splash.queue_free).set_delay(1.2)

	# Flash vermelho + "soco" de escala no próprio medidor. Usa modulate/scale
	# porque o pulso de medidor cheio já ocupa o tint_progress.
	var hud: TextureProgressBar = player.cogblade_hud
	var base_scale := Vector2(0.4, 0.4)
	var punch := create_tween()
	punch.tween_property(hud, "modulate", Color(1.8, 0.35, 0.35, 1.0), 0.05)
	punch.parallel().tween_property(hud, "scale", base_scale * 1.12, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(hud, "modulate", Color(1, 1, 1, 1), 0.22)
	punch.parallel().tween_property(hud, "scale", base_scale, 0.22).set_trans(Tween.TRANS_SINE)

# Preenchimento propriamente dito (só depois do sangue chegar no medidor).
func _apply_cogblade_power(amount: float) -> void:
	if not is_instance_valid(player) or not player.cogblade_hud: return
	if GlobalEvents.is_maycow_normal or player.is_using_ultimate: return

	player.cogblade_power_value = clamp(player.cogblade_power_value + amount, 0.0, 100.0)

	if _cogblade_fill_tween and _cogblade_fill_tween.is_valid(): _cogblade_fill_tween.kill()
	_cogblade_fill_tween = create_tween()
	_cogblade_fill_tween.tween_property(player.cogblade_hud, "value", player.cogblade_power_value, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if player.cogblade_power_value >= 100.0 and not player.cogblade_pulsing:
		player.cogblade_pulsing = true
		_start_cogblade_pulse()

# Cancela gotas em trânsito e o tween de preenchimento (usado quando um poder
# consome o medidor: o sangue que ainda estava vindo não pode encher de novo).
func cancel_cogblade_siphons() -> void:
	if _cogblade_fill_tween and _cogblade_fill_tween.is_valid(): _cogblade_fill_tween.kill()
	_cogblade_fill_tween = null
	for s in _siphons:
		if is_instance_valid(s): s.queue_free()
	_siphons.clear()

# Centro do medidor da cogblade em coordenadas da HUD.
func _cogblade_hud_center() -> Vector2:
	var hud: TextureProgressBar = player.cogblade_hud
	if not is_instance_valid(hud): return Vector2(60, 60)
	var tam: Vector2 = hud.size
	if tam == Vector2.ZERO and hud.texture_progress:
		tam = hud.texture_progress.get_size()
	return hud.position + (tam * hud.scale) * 0.5

func _bezier2(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

func _circle_points(radius: float, segments: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

func _start_cogblade_pulse() -> void:
	if not player.cogblade_hud: return
	
	if player.cogblade_pulse_tween: player.cogblade_pulse_tween.kill()
	player.cogblade_pulse_tween = create_tween().set_loops()
	
	player.cogblade_pulse_tween.tween_property(player.cogblade_hud, "tint_progress", Color(1.0, 0.2, 0.2, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	player.cogblade_pulse_tween.tween_property(player.cogblade_hud, "tint_progress", Color(1.0, 1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	if not player.cogblade_particles:
		player.cogblade_particles = CPUParticles2D.new()
		player.cogblade_particles.emitting = true
		player.cogblade_particles.amount = 50
		player.cogblade_particles.lifetime = 1.0
		player.cogblade_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		
		var w = player.cogblade_hud.texture_progress.get_width()
		var h = player.cogblade_hud.texture_progress.get_height()
		player.cogblade_particles.emission_rect_extents = Vector2(w / 2.0, h / 2.0)
		
		player.cogblade_particles.gravity = Vector2(0, 300)
		player.cogblade_particles.color = Color(0.8, 0.0, 0.0, 0.8)
		player.cogblade_particles.scale_amount_min = 3.0
		player.cogblade_particles.scale_amount_max = 6.0
		
		player.cogblade_hud.add_child(player.cogblade_particles)
		player.cogblade_particles.position = Vector2(w / 2.0, h / 2.0)
	else:
		player.cogblade_particles.emitting = true

func update_equipment_visuals() -> void:
	if player.is_first_person and not player.is_reloading and player.control_weapons.visible:
		player.hand_with_pistol.visible = SaveManager.is_equipped("pistol")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if player.is_magic_attacking:
		player.blade_in.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true)
		if body.has_method("take_damage"): body.take_damage(player.damage_crescent_cogblade)
	
func _on_area_3d_body_exited(body: Node3D) -> void:
	if player.is_magic_attacking:
		player.blade_back.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true)
		if body.has_method("take_damage"): body.take_damage(player.damage_crescent_cogblade)

func _on_bullet_touch_body_entered(body: Node3D) -> void:
	player.bullet.visible = false
	spawn_blood_effect(body)
