extends Node
@onready var animation_intro: AnimationPlayer = $intro_camera/animation_intro
@onready var camera_intro_2: Camera3D = $intro_camera/camera_intro_2


var player: CharacterBody3D
var enemies: Array = []
var camera_intro: Camera3D
@export var hurricane_particle_size_multiplier: float = 1.0

var look_at_target: Node3D
var look_at_offset: Vector3 = Vector3.ZERO
var final_sequence_started: bool = false
var hurricane_node: Node3D

# Estado da câmera da intro pós-prólogo (segue o alvo com atraso, ver _process)
var _rise_cam: Camera3D
var _rise_cam_anchor: Node3D
var _rise_look_at: Vector3 = Vector3.ZERO
var _rise_cam_time: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_spawn_arena_hurricane()
	SaveManager.save_game()
	SaveManager.iron_rusks_pending = 0
	GlobalEvents.set_high_nevoa()
	GlobalEvents.is_maycow_normal = false
	
	var enemies_node = get_node_or_null("enemies")
	if not enemies_node:
		enemies_node = Node3D.new()
		enemies_node.name = "enemies"
		add_child(enemies_node)
		
	# Limpa inimigos do editor sem apagar os marcadores (Marker3D)
	for child in enemies_node.get_children():
		if child.is_in_group("enemies") or child.has_method("take_damage"):
			child.queue_free()

	if not SaveManager.prolog_finished:
		# Prólogo: Spawna o TheCobaltHusker no marker "enemy_2"
		var marker = enemies_node.get_node_or_null("enemy_2")
		if marker:
			var enemy_scene = load("res://scenes/enemies/the_cobalt_husker.tscn")
			if enemy_scene:
				var enemy_inst = enemy_scene.instantiate()
				enemies_node.add_child(enemy_inst)
				enemy_inst.global_position = marker.global_position
				enemy_inst.global_rotation = marker.global_rotation
				if not enemy_inst.is_in_group("enemies"):
					enemy_inst.add_to_group("enemies")
	else:
		# Pós-Prólogo: Transporta os inimigos capturados pelo amuleto
		if GlobalEvents.amulet_captured_enemies.size() > 0:
			for e in GlobalEvents.amulet_captured_enemies:
				if is_instance_valid(e):
					if e.get_parent():
						e.get_parent().remove_child(e)
					enemies_node.add_child(e)
					
					var angle = randf() * PI * 2
					var radius = randf_range(2.0, 8.0) # Distribui aleatoriamente na arena
					e.global_position = Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
					
					if not e.is_in_group("enemies"):
						e.add_to_group("enemies")
						
			GlobalEvents.amulet_captured_enemies.clear()

	player = get_tree().get_first_node_in_group("player")

	# Escopado aos filhos de "enemies" (em vez de get_tree().get_nodes_in_group,
	# que busca na árvore INTEIRA): a cena de origem (ex: stage_1) fica pausada
	# mas ainda dentro da árvore enquanto a batalha rola, e seus inimigos
	# continuam no grupo "enemies" mesmo parados — o que fazia a checagem de
	# "todos mortos" nunca bater, já que eles nunca morrem.
	enemies = []
	for c in enemies_node.get_children():
		if is_instance_valid(c) and c.is_in_group("enemies"):
			enemies.append(c)

	if player:
		# Trava a cena para modo cutscene
		for enemy in enemies:
			if is_instance_valid(enemy):
				# Reage no exato instante em que o inimigo morre (em vez de esperar o
				# próximo frame do polling em _process), pra câmera lenta e afins já
				# começarem ANTES da animação/som de morte do último inimigo tocar.
				if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
					enemy.died.connect(_on_enemy_died)
				var enemy_script = _get_enemy_script(enemy)
				if enemy_script:
					# Atualiza a referência do player para que os inimigos teleportados não persigam o player da cena pausada
					if "player" in enemy_script:
						enemy_script.player = player
					enemy_script.cutscene_mode = true
		GlobalEvents.in_cutscene = true

		# Esconde a mão em primeira pessoa (hand_with_magic) durante a cutscene de intro:
		# como ela é filha da Camera3D do player, continua visível no mundo mesmo com outra
		# câmera (a de intro) ativa, flutuando em cena. Restaura o estado original no final.
		var hand_magic_was_visible = false
		if "hand_with_magic" in player and is_instance_valid(player.hand_with_magic):
			hand_magic_was_visible = player.hand_with_magic.visible
			player.hand_with_magic.visible = false

		var is_first_time = not SaveManager.prolog_finished

		if is_first_time:
			# Prólogo: mantém a cutscene original de câmera
			var anim = animation_intro.get_animation("intro_first_time")
			for i in range(anim.get_track_count()):
				if str(anim.track_get_path(i)).ends_with(":current"):
					var key_idx = anim.track_get_key_count(i) - 1
					if key_idx >= 0 and anim.track_get_key_value(i, key_idx) == false:
						anim.track_set_key_value(i, key_idx, true)

			camera_intro_2.make_current()
			animation_intro.play("intro_first_time")
			SaveManager.battlefield_1_intro_played = true
			SaveManager.save_game()
			await animation_intro.animation_finished
		else:
			# Pós-prólogo: player e inimigos emergem do chão da arena
			await _play_rise_from_ground_intro()

		# Restaura os controles e física APÓS o fim de toda a cutscene de entrada
		if is_instance_valid(player):
			if "camera_third_person" in player and is_instance_valid(player.camera_third_person):
				player.camera_third_person.make_current()
			if "hand_with_magic" in player and is_instance_valid(player.hand_with_magic):
				player.hand_with_magic.visible = hand_magic_was_visible
				
		if is_instance_valid(player):
			player.process_mode = Node.PROCESS_MODE_INHERIT

		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.process_mode = Node.PROCESS_MODE_INHERIT
				var enemy_script = _get_enemy_script(enemy)
				if enemy_script:
					enemy_script.cutscene_mode = false
				
		GlobalEvents.in_cutscene = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# HACK EXCLUSIVO: Mantém a mão mágica invisível SOMENTE durante a cutscene do início (primeira vez no prólogo)
	if animation_intro.is_playing() and animation_intro.current_animation == "intro_first_time":
		if is_instance_valid(player) and player.get("hand_with_magic") and is_instance_valid(player.hand_with_magic):
			player.hand_with_magic.visible = false

	if is_instance_valid(camera_intro):
		camera_intro.make_current()
		
	if look_at_target and is_instance_valid(camera_intro) and camera_intro.current:
		camera_intro.look_at(look_at_target.global_position + look_at_offset, Vector3.UP)

	_update_rise_camera(delta)
		
	if is_instance_valid(hurricane_node):
		# Gira o furacão constantemente em torno do eixo Y
		hurricane_node.rotate_y(deg_to_rad(30.0) * delta)
		
				
	# --- VERIFICAÇÃO DO ÚLTIMO INIMIGO (fallback; o caminho normal é o sinal "died") ---
	_check_all_dead()

func _on_enemy_died() -> void:
	_check_all_dead()

func _check_all_dead() -> void:
	if final_sequence_started or GlobalEvents.in_cutscene or enemies.is_empty():
		return
	for enemy in enemies:
		if is_instance_valid(enemy) and "dead" in enemy and not enemy.dead:
			return
	_start_final_sequence()

func _start_final_sequence() -> void:
	final_sequence_started = true
	GlobalEvents.in_cutscene = true
	
	if is_instance_valid(player):
		player.invulnerable = true
	
	# 1. Ultra Câmera Lenta
	Engine.time_scale = 0.15
	
	# 2. Esconde Interface
	var ui = get_tree().root.get_node_or_null("GlobalEnemyHealthUI")
	if ui: ui.queue_free()
	
	# 3. Faz o Fade Out super lento (ignorando time_scale)
	var fade = get_node_or_null("fade")
	if fade:
		fade.modulate.a = 0.0
		var tween = create_tween().set_ignore_time_scale(true)
		tween.tween_property(fade, "modulate:a", 1.0, 4.0) # 4 segundos de fade
		
	# 4. Espera a animação terminar em tempo real
	await get_tree().create_timer(5.0, true, false, true).timeout
	
	# 5. Restaura e vai para a Cutscene
	Engine.time_scale = 1.0
	GlobalEvents.in_cutscene = false
	if not SaveManager.prolog_finished:
		get_tree().change_scene_to_file("res://scenes/stages/prolog/fight_with_power/cutscene_fight_with_power.tscn")
	else:
		if is_instance_valid(GlobalEvents.paused_scene_for_amulet):
			var tree = get_tree()
			var root = tree.root
			var current = tree.current_scene
			
			root.remove_child(current)
			current.queue_free()

			# A cena pausada nunca saiu da árvore (ver player_amulet.gd), só
			# ficou escondida/sem processar. Aqui só a reativamos, o que evita
			# o bug do chão (Terrain3D) perdendo a textura ao ser readicionado.
			GlobalEvents.paused_scene_for_amulet.visible = true
			GlobalEvents.paused_scene_for_amulet.process_mode = Node.PROCESS_MODE_INHERIT
			GlobalUtils.set_canvas_layers_hidden(GlobalEvents.paused_scene_for_amulet, false)
			tree.current_scene = GlobalEvents.paused_scene_for_amulet

			# Toca o efeito de retorno na câmera da cena restaurada
			var p = _find_player_recursive(GlobalEvents.paused_scene_for_amulet)
			if p:
				if not p.is_in_group("player"):
					p.add_to_group("player")
				if p.has_method("play_return_from_arena_effect"):
					p.play_return_from_arena_effect()
			
			# Restaura o estado normal/combat do jogador
			GlobalEvents.is_maycow_normal = GlobalEvents.previous_is_maycow_normal
			
			GlobalEvents.paused_scene_for_amulet = null
		else:
			get_tree().change_scene_to_file("res://scenes/stages/stage_1.tscn")

func _find_player_recursive(node: Node) -> Node:
	if node.is_in_group("player") or node.name.to_lower() == "player":
		return node
	for child in node.get_children():
		var found = _find_player_recursive(child)
		if found: return found
	return null

func _get_enemy_script(enemy: Node) -> Node:
	if "cutscene_mode" in enemy:
		return enemy
	for child in enemy.get_children():
		if "cutscene_mode" in child:
			return child
	return null


func iniciar_cutscene() -> void:
	if not player or not camera_intro: return
	
	camera_intro.make_current()
	
	var anim_player = get_node_or_null("intro_camera/animation_intro")
	if anim_player:
		if not SaveManager.battlefield_1_intro_played:
			anim_player.play("intro_first_time")
			SaveManager.battlefield_1_intro_played = true
			SaveManager.save_game()
		else:
			anim_player.play("intro_capitulo_1")
			
		await anim_player.animation_finished
	else:
		# Fallback se não encontrar a animação
		await get_tree().create_timer(1.0).timeout
	
	# Encerramento: Restaura física e controles
	if is_instance_valid(player):
		if "camera_third_person" in player and is_instance_valid(player.camera_third_person):
			player.camera_third_person.make_current()
			
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			var enemy_script = _get_enemy_script(enemy)
			if enemy_script:
				enemy_script.cutscene_mode = false
			
	GlobalEvents.in_cutscene = false
	# Opcional: deletar a câmera de intro apenas se nós a criamos por código
	if is_instance_valid(camera_intro) and not get_node_or_null("intro_camera/camera_intro_4"):
		camera_intro.queue_free()


func _on_animation_intro_animation_finished(anim_name: StringName) -> void:
	# O controle de câmera e física agora é feito no final da corrotina _ready()
	# Isso garante que a cutscene de entrada rode por completo antes do Player assumir.
	pass

func _spawn_arena_hurricane() -> void:
	hurricane_node = Node3D.new()
	hurricane_node.name = "ArenaHurricane"
	add_child.call_deferred(hurricane_node)
	hurricane_node.global_position = Vector3(0, -1.0, 0) # Pouco abaixo do chão
	
	# Curva de tamanho: começa grande e afina/encolhe lá no alto
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.1))
	
	# Sorteador de Tons de Vermelho iniciais (cada partícula nasce com uma cor dessas)
	var initial_color_grad = Gradient.new()
	initial_color_grad.offsets = [0.0, 0.3, 0.6, 1.0]
	initial_color_grad.colors = [
		Color(1.0, 0.0, 0.0, 1.0),   # Vermelho puro
		Color(1.0, 0.2, 0.0, 1.0),   # Laranja avermelhado
		Color(0.8, 0.0, 0.1, 1.0),   # Carmim brilhante
		Color(0.5, 0.0, 0.0, 1.0)    # Vermelho escuro/Vinho
	]
	
	# Curva de Alpha (Vida da partícula: nasce invisível, brilha, e morre invisível)
	var alpha_grad = Gradient.new()
	alpha_grad.offsets = [0.0, 0.2, 0.8, 1.0]
	alpha_grad.colors = [
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.0)
	]
	
	var particles = CPUParticles3D.new()
	particles.amount = 400
	particles.lifetime = 6.0
	particles.local_coords = true # Girar junto com o Node pai!
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = 16.0 # Fora da arena
	particles.emission_ring_inner_radius = 13.0
	particles.emission_ring_height = 2.0
	particles.emission_ring_axis = Vector3.UP
	
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.gravity = Vector3(0, 1.5, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.0
	
	particles.scale_amount_min = 0.5 * hurricane_particle_size_multiplier
	particles.scale_amount_max = 1.5 * hurricane_particle_size_multiplier
	particles.scale_amount_curve = scale_curve
	
	particles.color_initial_ramp = initial_color_grad
	particles.color_ramp = alpha_grad
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.material = mat
	particles.mesh = mesh
	
	hurricane_node.add_child(particles)
	
	# Fumaça do furacão
	var smoke = CPUParticles3D.new()
	smoke.amount = 250
	smoke.lifetime = 8.0
	smoke.local_coords = true
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	smoke.emission_ring_radius = 15.0
	smoke.emission_ring_inner_radius = 12.0
	smoke.emission_ring_height = 4.0
	smoke.emission_ring_axis = Vector3.UP
	
	smoke.direction = Vector3.UP
	smoke.spread = 20.0
	smoke.gravity = Vector3(0, 1.2, 0)
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 4.0
	
	smoke.scale_amount_min = 3.0 * hurricane_particle_size_multiplier
	smoke.scale_amount_max = 6.0 * hurricane_particle_size_multiplier
	smoke.scale_amount_curve = scale_curve
	
	# Fumaça também ganha variação de vermelhos e o mesmo comportamento de alpha
	smoke.color_initial_ramp = initial_color_grad
	smoke.color_ramp = alpha_grad
	
	var smoke_mat = StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4) # Fumaça mais translúcida
	var tex = load("res://assets/images/vfx/smoke.png")
	if tex:
		smoke_mat.albedo_texture = tex
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Novo Shape da fumaça: Usando SphereMesh de baixa resolução (fumaça mais volumétrica)
	var smoke_mesh = SphereMesh.new()
	smoke_mesh.radius = 1.0
	smoke_mesh.height = 2.0
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 6
	smoke_mesh.material = smoke_mat
	smoke.mesh = smoke_mesh
	
	hurricane_node.add_child(smoke)


# ============================================================
#  INTRO PÓS-PRÓLOGO: todos emergem de baixo da arena
# ============================================================
const RISE_DEPTH: float = 12.0        # quanto abaixo da arena todos começam
const RISE_TIME: float = 1.35         # duração da subida
const RISE_SETTLE: float = 0.5        # respiro depois de chegar em cima
const ROCK_COUNT: int = 80            # pedaços de pedra que sobem junto
const ROCK_LIFETIME: float = 15.0     # tempo que as pedras ficam na arena
const RISE_CAM_LAG: float = 4.2       # quanto MENOR, mais a câmera atrasa em relação ao alvo
const RISE_CAM_AIM_LAG: float = 5.5   # atraso da mira (um pouco mais rápido que a posição)

func _play_rise_from_ground_intro() -> void:
	# Guarda a posição final de todo mundo e joga todos pra debaixo da arena.
	var risers: Array = []
	if is_instance_valid(player):
		risers.append({"node": player, "pos": player.global_position})
	for e in enemies:
		if is_instance_valid(e):
			risers.append({"node": e, "pos": e.global_position})

	for r in risers:
		var n: Node3D = r["node"]
		# Congela a física: sem isso o player/inimigo cairia ou atravessaria o chão
		# enquanto o tween controla a posição na mão.
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.global_position = r["pos"] - Vector3(0, RISE_DEPTH, 0)

	var player_final: Vector3 = risers[0]["pos"] if risers.size() > 0 else Vector3(0, 1.0, 0)
	var cam_final: Vector3 = player_final + Vector3(0, 2.6, 5.5)

	# A subida da câmera é feita num "anchor" invisível; a câmera persegue esse
	# anchor com amortecimento (ver _update_rise_camera), então ela chega atrasada,
	# passa um pouco do ponto e se acomoda — em vez de andar colada no trilho.
	var anchor := Node3D.new()
	add_child(anchor)
	anchor.global_position = cam_final - Vector3(0, RISE_DEPTH, 0)

	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = anchor.global_position - Vector3(0, 1.5, 0)
	cam.fov = 82.0

	# Motion blur durante a subida (DOF distante, some no final).
	var blur := CameraAttributesPractical.new()
	blur.dof_blur_far_enabled = true
	blur.dof_blur_far_distance = 4.0
	blur.dof_blur_far_transition = 8.0
	blur.dof_blur_amount = 0.12
	cam.attributes = blur

	_rise_cam = cam
	_rise_cam_anchor = anchor
	_rise_cam_time = 0.0
	_rise_look_at = player_final + Vector3(0, 1.0, 0) - Vector3(0, RISE_DEPTH, 0)
	# _process() mantém esta câmera ativa; a mira/posição são suavizadas à parte.
	camera_intro = cam

	# Sobe todo mundo (leve overshoot pra dar o "estouro" ao furar o chão).
	var tween := create_tween().set_parallel(true)
	for r in risers:
		var n: Node3D = r["node"]
		tween.tween_property(n, "global_position", r["pos"], RISE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(anchor, "global_position", cam_final, RISE_TIME) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "fov", 70.0, RISE_TIME + 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# No instante em que atravessamos o chão: pedras, poeira e tremor.
	var punch_delay: float = RISE_TIME * 0.55
	get_tree().create_timer(punch_delay).timeout.connect(func():
		for r in risers:
			var n: Node3D = r["node"]
			if is_instance_valid(n):
				_spawn_ground_burst(Vector3(n.global_position.x, 0.0, n.global_position.z))
		GlobalUtils.vibrate_controller(Input, 0.8, 0.8, 0.5)
		if is_instance_valid(cam):
			var shake := create_tween()
			shake.tween_property(cam, "v_offset", 0.25, 0.05)
			shake.tween_property(cam, "v_offset", -0.18, 0.05)
			shake.tween_property(cam, "v_offset", 0.09, 0.05)
			shake.tween_property(cam, "v_offset", 0.0, 0.05)
	)

	await tween.finished

	# Tira o blur enquanto a câmera termina de se acomodar no alvo.
	var blur_out := create_tween()
	blur_out.tween_property(blur, "dof_blur_amount", 0.0, RISE_SETTLE)

	await get_tree().create_timer(RISE_SETTLE).timeout

	# Devolve a câmera pro player (o _process para de forçar a câmera de intro).
	camera_intro = null
	_rise_cam = null
	if is_instance_valid(anchor):
		anchor.queue_free()
	if is_instance_valid(cam):
		cam.attributes = null
		cam.queue_free()
	_rise_cam_anchor = null


func _update_rise_camera(delta: float) -> void:
	if not is_instance_valid(_rise_cam) or not is_instance_valid(_rise_cam_anchor):
		return

	_rise_cam_time += delta

	# Balanço mínimo de câmera na mão, só pra tirar o aspecto de trilho.
	var sway := Vector3(
		sin(_rise_cam_time * 1.7) * 0.07 + sin(_rise_cam_time * 0.61) * 0.05,
		sin(_rise_cam_time * 2.3 + 1.3) * 0.05,
		sin(_rise_cam_time * 1.1 + 0.7) * 0.04
	)

	# Suavização exponencial: independe do framerate e nunca gruda no alvo.
	var f: float = 1.0 - exp(-delta * RISE_CAM_LAG)
	_rise_cam.global_position = _rise_cam.global_position.lerp(
		_rise_cam_anchor.global_position + sway, f
	)

	var aim_goal: Vector3 = _rise_look_at
	if is_instance_valid(player):
		aim_goal = player.global_position + Vector3(0, 1.0, 0)
	var af: float = 1.0 - exp(-delta * RISE_CAM_AIM_LAG)
	_rise_look_at = _rise_look_at.lerp(aim_goal, af)

	if _rise_cam.global_position.distance_to(_rise_look_at) > 0.1:
		_rise_cam.look_at(_rise_look_at, Vector3.UP)


func _spawn_ground_burst(pos: Vector3) -> void:
	# Poeira/terra saindo do ponto onde alguém furou o chão
	var dust := CPUParticles3D.new()
	add_child(dust)
	dust.global_position = pos
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 40
	dust.lifetime = 1.4
	dust.explosiveness = 0.9
	dust.spread = 55.0
	dust.direction = Vector3.UP
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 9.0
	dust.gravity = Vector3(0, -3.0, 0)
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	var dust_mat := StandardMaterial3D.new()
	var tex = load("res://assets/images/vfx/smoke.png")
	if tex:
		dust_mat.albedo_texture = tex
	dust_mat.albedo_color = Color(0.42, 0.31, 0.26, 0.85)
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(2.5, 2.5)
	dust_mesh.material = dust_mat
	dust.mesh = dust_mesh
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(dust):
			dust.queue_free()
	)

	# Pedaços de pedra subindo junto e quicando na arena
	var n := int(round(float(ROCK_COUNT) / max(1.0, float(enemies.size() + 1))))
	for i in range(max(10, n)):
		_spawn_rock_chunk(pos)


func _spawn_rock_chunk(origin: Vector3) -> void:
	var rock := RigidBody3D.new()
	# Só colide com o chão da arena (layer 2): não empurra player nem inimigos.
	rock.collision_layer = 0
	# Ligada só depois que a pedra sai de baixo da arena (ver timer no fim).
	rock.collision_mask = 0
	rock.gravity_scale = 2.4
	rock.continuous_cd = true
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.45
	phys.friction = 0.85
	rock.physics_material_override = phys
	add_child(rock)

	var size := randf_range(0.14, 0.62)

	# Formato angular de pedra (esfera de baixíssima resolução, achatada aleatoriamente)
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 5
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	var tone := randf_range(0.16, 0.32)
	mat.albedo_color = Color(tone * 1.15, tone * 0.9, tone * 0.85)
	mat.roughness = 1.0
	mat.metallic = 0.0
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3(randf_range(0.7, 1.4), randf_range(0.6, 1.2), randf_range(0.7, 1.4))
	rock.add_child(mi)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = size * 0.45
	shape.shape = sphere
	rock.add_child(shape)

	# Nasce escondida embaixo da arena e sobe furando o chão junto com o pessoal.
	var ang := randf() * TAU
	var rad := randf_range(0.3, 3.0)
	rock.global_position = origin + Vector3(cos(ang) * rad, -1.4, sin(ang) * rad)
	rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	rock.linear_velocity = Vector3(
		cos(ang) * randf_range(1.0, 5.0),
		randf_range(9.0, 17.0),
		sin(ang) * randf_range(1.0, 5.0)
	)
	rock.angular_velocity = Vector3(
		randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0)
	)

	# A colisão com o chão só liga depois que a pedra já saiu de baixo dele,
	# senão ela bateria na face inferior da arena e nunca apareceria.
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(rock):
			rock.collision_mask = 2
	)

	# Some suavemente depois de ficar um tempão quicando/parada na arena.
	get_tree().create_timer(ROCK_LIFETIME).timeout.connect(func():
		if not is_instance_valid(rock):
			return
		var t := create_tween()
		t.tween_property(mi, "scale", Vector3.ZERO, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(func():
			if is_instance_valid(rock):
				rock.queue_free()
		)
	)
