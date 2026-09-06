extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func _process_amulet_magic(delta: float) -> void:
	if not GlobalEvents.is_maycow_normal or not SaveManager.prolog_finished or player.is_reloading or player.is_using_ultimate:
		_hide_amulet_magic()
		return

	if SaveManager.current_mp > 0:
		if not player.amulet_magic_active:
			player.amulet_magic_active = true
			if player.amulet_crosshair:
				player.amulet_crosshair.visible = true
			if player.amulet_counter_label:
				player.amulet_counter_label.visible = true
				player.amulet_counter_label.text = "0"
			player.hand_with_pistol.visible = false
			player.control_weapons.visible = false
			player.control_magic.visible = false

		# Transição de câmera do poder do amuleto: espera o zoom da 3ª pessoa
		# (feito pelo lerp de FOV normal em player.gd) avançar o bastante antes
		# de trocar para a câmera em 1ª pessoa - dá a sensação de "zoom pra dentro".
		if not player.is_first_person:
			if is_instance_valid(player.camera_third_person) and player.camera_third_person.fov <= 55.0:
				player.is_first_person = true
				if is_instance_valid(player.camera) and not player.camera.current:
					player.camera.fov = 75.0
					player.camera.rotation.x = 0.0 # Centraliza a câmera ao entrar em 1ª pessoa com o poder do amuleto
					player.camera.make_current()
					if player.camera_third_person:
						player.camera_third_person.current = false

				if player.hand_with_magic: player.hand_with_magic.visible = true

				_ensure_amuleto_visual()
				_set_aim_beam_active(true)
				if player.amuleto_node:
					player.amuleto_node.visible = true
					if player.amuleto_particles:
						player.amuleto_particles.emitting = true

		if is_instance_valid(player.amuleto_node):
			player.amuleto_node.rotate_y(delta * 8.0) # Amuleto girando rapidamente

		_update_enemy_highlights()
		_process_amulet_targeting()
	else:
		if player.amulet_magic_active:
			_hide_amulet_magic()

func _ensure_amuleto_visual() -> void:
	if is_instance_valid(player.amuleto_node): return
	if not player.camera: return

	var amuleto_scene = load("res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb")
	if not amuleto_scene: return

	var amuleto = amuleto_scene.instantiate()
	# Preso na câmera (não na mão) para garantir posição e escala previsíveis na tela
	player.camera.add_child(amuleto)
	amuleto.scale = Vector3(0.24, 0.24, 0.24)
	amuleto.visible = true

	# Posição e giro vêm do Marker3D "amuleto_position" (filho da câmera),
	# ajustável direto na cena sem precisar mexer no código.
	var amuleto_marker = player.camera.get_node_or_null("amuleto_position")
	if amuleto_marker:
		amuleto.position = amuleto_marker.position
		amuleto.rotation = amuleto_marker.rotation
	else:
		amuleto.position = Vector3(0.05, -0.22, -0.55)
		amuleto.rotation.z = deg_to_rad(90)

	# Sem material override: mantém a cor/textura originais do modelo.
	for mesh in amuleto.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = true

	# Desliga colisão de qualquer corpo físico vindo do .glb: o amuleto fica
	# bem na frente da câmera e não pode bloquear o raycast de mira/seleção de inimigos.
	for col in amuleto.find_children("*", "CollisionObject3D", true, false):
		col.collision_layer = 0
		col.collision_mask = 0

	var particles = CPUParticles3D.new()
	particles.amount = 120
	particles.lifetime = 1.0
	particles.local_coords = false # Partículas se espalham no ar independente do giro do amuleto
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3(0, 0.5, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 2.0

	# Variação de tons: roxos, brancos e vermelhos
	var initial_grad = Gradient.new()
	initial_grad.offsets = [0.0, 0.25, 0.5, 0.75, 1.0]
	initial_grad.colors = [
		Color(0.5, 0.0, 1.0, 1.0), # Roxo puro brilhante
		Color(1.0, 1.0, 1.0, 1.0), # Branco mágico
		Color(0.8, 0.2, 1.0, 1.0), # Lilás/Rosa
		Color(1.0, 0.0, 0.0, 1.0), # Vermelho sangue
		Color(0.3, 0.0, 0.6, 1.0)  # Roxo escuro
	]
	particles.color_initial_ramp = initial_grad

	# Fade in e fade out no ciclo de vida
	var alpha_grad = Gradient.new()
	alpha_grad.offsets = [0.0, 0.2, 0.8, 1.0]
	alpha_grad.colors = [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	particles.color_ramp = alpha_grad

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve

	var pmat = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.vertex_color_use_as_albedo = true # OBRIGATÓRIO para a cor do Gradient funcionar!
	var pmesh = SphereMesh.new()
	pmesh.radius = 0.04
	pmesh.height = 0.08
	pmesh.material = pmat
	particles.mesh = pmesh

	amuleto.add_child(particles)

	player.amuleto_node = amuleto
	player.amuleto_particles = particles

func _hide_amulet_magic() -> void:
	player.amulet_magic_active = false
	if player.amulet_crosshair:
		player.amulet_crosshair.visible = false
	if player.amulet_counter_label:
		player.amulet_counter_label.visible = false
	
	if GlobalEvents.is_maycow_normal:
		# Volta da 1ª pessoa (amuleto) pra 3ª pessoa com zoom-out gradual:
		# começa o FOV da 3ª pessoa já "fechado" e deixa o lerp normal abrir até 75.
		if player.is_first_person:
			player.is_first_person = false
			if is_instance_valid(player.camera_third_person):
				player.camera_third_person.fov = 40.0
				player.camera_third_person.make_current()
			if player.hand_with_magic:
				player.hand_with_magic.visible = false
			player.control_weapons.visible = false
			player.control_magic.visible = false
	elif player.is_first_person and not player.is_reloading:
		if SaveManager.is_equipped("pistol"):
			player.hand_with_pistol.visible = true
		if player.hand_with_magic:
			player.hand_with_magic.visible = true
		player.control_weapons.visible = true
		player.control_magic.visible = true

	if player.amuleto_node:
		player.amuleto_node.visible = false
		if player.amuleto_particles:
			player.amuleto_particles.emitting = false

	_set_aim_beam_active(false)
	_clear_enemy_highlights()

	_clear_amulet_hover()

	for enemy in player.amulet_selected_enemies:
		if is_instance_valid(enemy):
			_remove_silhouette(enemy)
			_remove_magic_aura(enemy)
	player.amulet_selected_enemies.clear()

func _process_amulet_targeting() -> void:
	if not GlobalEvents.is_maycow_normal:
		_clear_amulet_hover()
		return

	var cam = player.get_viewport().get_camera_3d()
	if not cam: return

	var space_state = player.get_world_3d().direct_space_state
	var center = player.get_viewport().size / 2
	var from = cam.project_ray_origin(center)
	var to = from + cam.project_ray_normal(center) * 30.0
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	var target = null
	if result and result.collider:
		if result.collider.is_in_group("enemies") or (result.collider.get_parent() and result.collider.get_parent().is_in_group("enemies")):
			target = result.collider
			if not target.is_in_group("enemies"):
				target = target.get_parent()
				
	if target != player.amulet_hovered_enemy:
		_clear_amulet_hover()
		if target:
			player.amulet_hovered_enemy = target
			if player.amulet_selected_enemies.has(target):
				_apply_silhouette(target, Color(1.0, 0.0, 0.0, 0.8)) # Já selecionado (vermelho forte)
			else:
				_apply_silhouette(target, Color(1.0, 1.0, 1.0, 0.5)) # Branco fraco (Hover)

	if Input.is_action_just_pressed("ui_shoot") and player.amulet_hovered_enemy:
		var enemy = player.amulet_hovered_enemy
		if player.amulet_selected_enemies.has(enemy):
			# Já estava selecionado: remove a seleção
			player.amulet_selected_enemies.erase(enemy)
			_apply_silhouette(enemy, Color(1.0, 1.0, 1.0, 0.5)) # Volta para hover fraco
			_remove_magic_aura(enemy)
		elif player.amulet_selected_enemies.size() < player.max_amulet_targets:
			player.amulet_selected_enemies.append(enemy)
			_apply_silhouette(enemy, Color(1.0, 0.0, 0.0, 0.8)) # Vermelho forte (Selecionado)
			_remove_enemy_highlight(enemy)
			_play_selection_burst(enemy)
			_apply_magic_aura(enemy)

		if player.amulet_counter_label:
			player.amulet_counter_label.text = str(player.amulet_selected_enemies.size())

func _clear_amulet_hover() -> void:
	if player.amulet_hovered_enemy and is_instance_valid(player.amulet_hovered_enemy):
		if not player.amulet_selected_enemies.has(player.amulet_hovered_enemy):
			_remove_silhouette(player.amulet_hovered_enemy)
	player.amulet_hovered_enemy = null

func _apply_silhouette(enemy: Node, cor: Color) -> void:
	if not enemy.has_meta("original_materials"):
		var meshes = _get_all_meshes(enemy)
		var mat_dict = {}
		for m in meshes:
			mat_dict[m] = m.material_override
		enemy.set_meta("original_materials", mat_dict)
		
	var all_meshes = _get_all_meshes(enemy)
	var sil_mat = StandardMaterial3D.new()
	sil_mat.albedo_color = cor
	sil_mat.emission_enabled = true
	sil_mat.emission = cor
	sil_mat.emission_energy_multiplier = 2.0
	sil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	for m in all_meshes:
		m.material_override = sil_mat

func _remove_silhouette(enemy: Node) -> void:
	if enemy.has_meta("original_materials"):
		var mat_dict = enemy.get_meta("original_materials")
		for m in mat_dict.keys():
			if is_instance_valid(m):
				m.material_override = mat_dict[m]
		enemy.remove_meta("original_materials")

func _get_all_meshes(node: Node) -> Array:
	var result = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_meshes(child))
	return result

# ---------------------------------------------------------------------------
# Realce dos inimigos ainda NÃO selecionados: enquanto a mira do amuleto está
# ativa, todo inimigo dentro do alcance ganha um contorno brilhante por cima do
# material original (material_overlay). Sem isso, em cenário escuro o jogador
# só enxergava o inimigo quando a mira encostava nele.
# ---------------------------------------------------------------------------
const HIGHLIGHT_RANGE := 45.0
const HIGHLIGHT_META := "amulet_highlight_meshes"

var _highlighted: Array = []
var _highlight_material: ShaderMaterial

func _get_highlight_material() -> ShaderMaterial:
	if is_instance_valid(_highlight_material): return _highlight_material

	var shader = load("res://shaders/effects/enemy_highlight.gdshader")
	if not shader: return null

	# Um único material compartilhado por todos os inimigos realçados.
	_highlight_material = ShaderMaterial.new()
	_highlight_material.shader = shader
	_highlight_material.set_shader_parameter("rim_color", Color(0.5, 0.8, 1.0))
	_highlight_material.set_shader_parameter("rim_power", 2.2)
	_highlight_material.set_shader_parameter("rim_intensity", 1.2)
	_highlight_material.set_shader_parameter("fill_intensity", 0.14)
	_highlight_material.set_shader_parameter("pulse_speed", 2.0)
	_highlight_material.set_shader_parameter("pulse_amount", 0.25)
	return _highlight_material

func _update_enemy_highlights() -> void:
	var origin: Vector3 = player.global_position
	var ativos := {}

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not is_instance_valid(enemy): continue
		# Inimigos da cena pausada atrás da arena continuam no grupo.
		if not enemy.is_inside_tree() or not enemy.can_process(): continue
		if not enemy.is_visible_in_tree(): continue
		if "dead" in enemy and enemy.dead: continue
		if origin.distance_to(enemy.global_position) > HIGHLIGHT_RANGE: continue
		# Selecionado já tem silhueta vermelha + aura própria: não precisa do realce.
		if player.amulet_selected_enemies.has(enemy): continue

		ativos[enemy] = true
		_apply_enemy_highlight(enemy)

	# Tira o realce de quem saiu do alcance, morreu ou acabou de ser escolhido.
	for enemy in _highlighted.duplicate():
		if not ativos.has(enemy):
			_remove_enemy_highlight(enemy)

func _apply_enemy_highlight(enemy: Node) -> void:
	if enemy.has_meta(HIGHLIGHT_META): return

	var mat := _get_highlight_material()
	if not mat: return

	var alterados := []
	for m in _get_all_meshes(enemy):
		# Respeita quem já tinha overlay próprio (não sobrescreve nem perde).
		if m.material_overlay != null: continue
		m.material_overlay = mat
		alterados.append(m)

	enemy.set_meta(HIGHLIGHT_META, alterados)
	if not _highlighted.has(enemy):
		_highlighted.append(enemy)

func _remove_enemy_highlight(enemy) -> void:
	_highlighted.erase(enemy)
	if not is_instance_valid(enemy): return
	if not enemy.has_meta(HIGHLIGHT_META): return

	for m in enemy.get_meta(HIGHLIGHT_META):
		if is_instance_valid(m):
			m.material_overlay = null
	enemy.remove_meta(HIGHLIGHT_META)

func _clear_enemy_highlights() -> void:
	for enemy in _highlighted.duplicate():
		_remove_enemy_highlight(enemy)
	_highlighted.clear()

# ---------------------------------------------------------------------------
# Feixe de mira: luz reta saindo da câmera, iluminando o caminho até onde o
# jogador está mirando. Só existe enquanto o poder do amuleto está ativo.
# ---------------------------------------------------------------------------
const AIM_BEAM_RANGE := 30.0

func _set_aim_beam_active(active: bool) -> void:
	if not active:
		var existing = _get_aim_beam()
		if existing: existing.visible = false
		return

	var beam = _get_aim_beam()
	if not beam: beam = _create_aim_beam()
	if beam: beam.visible = true

func _get_aim_beam() -> Node3D:
	if not is_instance_valid(player.camera): return null
	return player.camera.get_node_or_null("AmuletAimBeam")

func _create_aim_beam() -> Node3D:
	if not is_instance_valid(player.camera): return null

	var root := Node3D.new()
	root.name = "AmuletAimBeam"
	player.camera.add_child(root)

	# Luz de verdade: ilumina o cenário e os inimigos ao longo da mira.
	var light := SpotLight3D.new()
	light.spot_range = AIM_BEAM_RANGE
	light.spot_angle = 7.0
	light.spot_angle_attenuation = 0.6
	light.spot_attenuation = 0.8
	light.light_energy = 4.0
	light.light_color = Color(0.75, 0.55, 1.0)
	light.shadow_enabled = false # Barato: o feixe é sempre reto e curto
	light.position = Vector3(0, 0, -0.3)
	root.add_child(light)

	# Cone visível do feixe (aditivo, some conforme se afasta da câmera).
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.85
	mesh.height = AIM_BEAM_RANGE
	mesh.radial_segments = 16
	mesh.rings = 1
	cone.mesh = mesh
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.6, 0.4, 1.0, 0.06)
	mat.disable_receive_shadows = true
	cone.material_override = mat

	# Deitado no eixo -Z (frente da câmera), começando logo à frente dela.
	cone.rotation.x = deg_to_rad(-90)
	cone.position = Vector3(0, 0, -AIM_BEAM_RANGE * 0.5)
	root.add_child(cone)

	return root

# ---------------------------------------------------------------------------
# Seleção do inimigo: estouro mágico no momento do clique + aura permanente
# girando em volta de quem está marcado.
# ---------------------------------------------------------------------------
const AURA_NAME := "AmuletMagicAura"

func _play_selection_burst(enemy: Node3D) -> void:
	if not is_instance_valid(enemy): return

	var burst := Node3D.new()
	burst.name = "AmuletSelectionBurst"
	enemy.get_parent().add_child(burst)
	burst.global_position = enemy.global_position + Vector3.UP * 1.0

	# Anel de choque que abre e some
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.9
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(0.9, 0.3, 1.0, 1.0)
	ring.material_override = ring_mat
	ring.scale = Vector3(0.2, 0.2, 0.2)
	burst.add_child(ring)

	# Faíscas saindo pra fora
	var sparks := CPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 60
	sparks.lifetime = 0.7
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.5
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.gravity = Vector3(0, -1.5, 0)
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var grad := Gradient.new()
	grad.offsets = [0.0, 0.5, 1.0]
	grad.colors = [Color(1.0, 0.9, 1.0, 1.0), Color(0.8, 0.2, 1.0, 1.0), Color(1.0, 0.1, 0.2, 0.0)]
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	sparks.color_ramp = grad
	sparks.mesh = _make_spark_mesh()
	burst.add_child(sparks)

	# Clarão curto pra "vender" o impacto da escolha
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.85, 0.4, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = 6.0
	flash.shadow_enabled = false
	burst.add_child(flash)

	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = load("res://assets/sounds/player/blade_in.mp3")
	sfx.pitch_scale = 1.6
	sfx.unit_size = 8.0
	sfx.volume_db = -4.0
	burst.add_child(sfx)
	sfx.play()

	GlobalUtils.vibrate_controller(null, 0.25, 0.4, 0.15)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.4, 2.4, 2.4), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flash, "light_energy", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.8)
	tw.chain().tween_callback(burst.queue_free)

func _make_spark_mesh() -> Mesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.material = mat
	return mesh

func _apply_magic_aura(enemy: Node3D) -> void:
	if not is_instance_valid(enemy): return
	if enemy.has_node(AURA_NAME): return

	var aura := Node3D.new()
	aura.name = AURA_NAME
	enemy.add_child(aura)
	aura.position = Vector3(0, 1.0, 0)

	# Dois anéis rúnicos girando em sentidos opostos
	for i in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.85 if i == 0 else 0.6
		torus.outer_radius = 0.92 if i == 0 else 0.66
		torus.rings = 24
		ring.mesh = torus
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.25, 0.35, 0.9) if i == 0 else Color(0.7, 0.35, 1.0, 0.9)
		ring.material_override = mat

		ring.rotation = Vector3(deg_to_rad(15.0 if i == 0 else -25.0), 0, deg_to_rad(10.0 * float(i)))
		ring.position.y = -0.15 if i == 0 else 0.35
		aura.add_child(ring)

		# Giro infinito (sentidos opostos) e pulsar de escala
		var spin := create_tween().set_loops()
		var dir := 1.0 if i == 0 else -1.0
		spin.tween_property(ring, "rotation:y", ring.rotation.y + dir * TAU, 2.4 + float(i)).from_current()

		var pulse := create_tween().set_loops()
		pulse.tween_property(ring, "scale", Vector3(1.08, 1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(ring, "scale", Vector3(0.94, 0.94, 0.94), 0.6).set_trans(Tween.TRANS_SINE)

	# Chamas mágicas subindo em volta do corpo
	var flames := CPUParticles3D.new()
	flames.amount = 90
	flames.lifetime = 1.1
	flames.local_coords = false
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	flames.emission_ring_radius = 0.65
	flames.emission_ring_inner_radius = 0.45
	flames.emission_ring_height = 0.1
	flames.emission_ring_axis = Vector3.UP
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.gravity = Vector3(0, 1.2, 0)
	flames.initial_velocity_min = 0.6
	flames.initial_velocity_max = 1.6
	flames.position.y = -0.9
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.2

	var fgrad := Gradient.new()
	fgrad.offsets = [0.0, 0.35, 0.7, 1.0]
	fgrad.colors = [
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 0.2, 0.3, 0.9),
		Color(0.7, 0.2, 1.0, 0.7),
		Color(0.3, 0.0, 0.5, 0.0)
	]
	flames.color_ramp = fgrad
	flames.mesh = _make_spark_mesh()
	flames.emitting = true
	aura.add_child(flames)

	# Luz de apoio pra aura "vazar" no cenário
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.9, 0.35, 0.9)
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	glow.shadow_enabled = false
	aura.add_child(glow)

	# Entrada: a aura nasce do chão e cresce
	aura.scale = Vector3(0.1, 0.1, 0.1)
	var grow := create_tween()
	grow.tween_property(aura, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _remove_magic_aura(enemy: Node) -> void:
	if not is_instance_valid(enemy): return
	var aura = enemy.get_node_or_null(AURA_NAME)
	if aura: aura.queue_free()

func _on_amulet_magic_released() -> void:
	if player.amulet_selected_enemies.size() == 0:
		return

	# Guardamos os inimigos para transferir
	_clear_enemy_highlights()

	GlobalEvents.amulet_captured_enemies.clear()
	for e in player.amulet_selected_enemies:
		if is_instance_valid(e):
			_remove_silhouette(e)
			_remove_magic_aura(e)
			GlobalEvents.amulet_captured_enemies.append(e)

	player.amulet_selected_enemies.clear()
	_clear_amulet_hover()

	# Limpa os estados do Player para quando voltar da Arena
	player.is_aiming = false
	player.is_first_person = false
	if is_instance_valid(player.camera_third_person):
		player.camera_third_person.make_current()
		player.camera_third_person.fov = 75.0
	if is_instance_valid(player.hand_with_magic):
		player.hand_with_magic.visible = false
	if is_instance_valid(player.amulet_crosshair): player.amulet_crosshair.visible = false
	if player.point: player.point.visible = false
	if is_instance_valid(player.amulet_counter_label): player.amulet_counter_label.visible = false

	# Desativa o Motion Blur ao sair
	if is_instance_valid(player.hud_layer):
		var motion_blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
		if motion_blur:
			motion_blur.material.set_shader_parameter("blur_strength", 0.0)
			motion_blur.visible = false

	_hide_amulet_magic()

	GlobalEvents.previous_is_maycow_normal = GlobalEvents.is_maycow_normal

	player.is_teleporting_enemies = true

	SaveManager.current_mp = SaveManager.max_mp

	var tree = get_tree()
	var root = tree.root
	var current = tree.current_scene

	# ---- TRANSIÇÃO CINEMÁTICA DIMENSIONAL ----
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 0.2 # Slow motion global

	var cine_cam = Camera3D.new()
	var cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 1.0
	cam_attr.dof_blur_far_transition = 10.0 # Motion blur pesado artificial
	cine_cam.attributes = cam_attr
	cine_cam.fov = 95.0

	var center_pos = Vector3.ZERO
	for e in GlobalEvents.amulet_captured_enemies:
		center_pos += e.global_position
	center_pos /= GlobalEvents.amulet_captured_enemies.size()

	cine_cam.global_position = center_pos + Vector3(0, 1.5, 4.5)
	current.add_child(cine_cam)
	cine_cam.look_at(center_pos + Vector3(0, 1.0, 0), Vector3.UP)
	cine_cam.make_current()

	# Overlay de "velocidade absurda pra cima": motion blur direcional + streaks
	var warp_rect := _create_warp_overlay()

	var travel_audio = AudioStreamPlayer.new()
	travel_audio.stream = load("res://assets/sounds/player/espaco_travel.mp3")
	travel_audio.pitch_scale = 0.55 # Bem mais grave
	travel_audio.volume_db = 8.0    # E mais alto
	travel_audio.bus = _ensure_warp_audio_bus() # Bus com distorção + grave
	travel_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	current.add_child(travel_audio)
	travel_audio.play()
	travel_audio.finished.connect(travel_audio.queue_free)

	GlobalUtils.vibrate_controller(null, 0.9, 0.9, 0.6)

	var tween = tree.create_tween().set_parallel(true).set_ignore_time_scale(true)
	var anim_time = 1.2
	for e in GlobalEvents.amulet_captured_enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED
			var target_y = e.global_position.y + 35.0
			tween.tween_property(e, "global_position:y", target_y, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tween.tween_property(e, "rotation:y", e.rotation.y + deg_to_rad(1080), anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tween.tween_property(e, "scale", Vector3(0.05, 5.0, 0.05), anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	tween.tween_property(cine_cam, "global_position:y", cine_cam.global_position.y + 35.0, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(cine_cam, "fov", 130.0, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	if is_instance_valid(warp_rect):
		var mat := warp_rect.material as ShaderMaterial
		# Sobe rápido: o borrão vertical e a curvatura de túnel abrem primeiro,
		# os streaks de energia entram logo em seguida.
		tween.tween_property(mat, "shader_parameter/streak", 1.0, anim_time * 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_property(mat, "shader_parameter/intensity", 1.0, anim_time * 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "shader_parameter/warp", 1.0, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(mat, "shader_parameter/aberration", 0.018, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Estouro branco só no finalzinho, escondendo a troca de cena
		tween.tween_property(mat, "shader_parameter/flash", 1.0, anim_time * 0.22).set_delay(anim_time * 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished

	if is_instance_valid(warp_rect):
		warp_rect.queue_free()

	for e in GlobalEvents.amulet_captured_enemies:
		if is_instance_valid(e):
			e.scale = Vector3.ONE
			e.rotation.x = 0
			e.rotation.z = 0

	if is_instance_valid(cine_cam):
		cine_cam.queue_free()

	player.process_mode = Node.PROCESS_MODE_INHERIT
	Engine.time_scale = 1.0 # Retorna ao normal
	AudioServer.playback_speed_scale = 1.0 # Garante que o áudio não fique em câmera lenta

	player.is_teleporting_enemies = false

	# Instancia o campo de batalha antes de pausarmos a cena atual
	var battlefield_scene = load("res://scenes/stages/battlefield/battlefield_1.tscn").instantiate()

	# Pausa a cena atual escondendo e desligando o processamento, SEM tirá-la
	# da árvore (root.remove_child). Removê-la fazia o chão (Terrain3D) perder
	# a textura quando a cena era readicionada depois da batalha.
	current.visible = false
	current.process_mode = Node.PROCESS_MODE_DISABLED
	GlobalUtils.set_canvas_layers_hidden(current, true)
	if is_instance_valid(player):
		player.remove_from_group("player")
	GlobalEvents.paused_scene_for_amulet = current

	root.add_child(battlefield_scene)
	tree.current_scene = battlefield_scene

func play_return_from_arena_effect() -> void:
	# O combate na arena (Maycow não normal) consome o mesmo SaveManager.current_mp
	# usado pelo poder do amuleto. Sem isso, o jogador podia voltar da arena sem mana
	# e o amuleto (mão, giro, mira) simplesmente não aparecia mais no mundo normal.
	SaveManager.current_mp = SaveManager.max_mp

	player.is_playing_return_effect = true
	GlobalUtils.vibrate_controller(null, 0.8, 0.8, 1.0)
	GlobalUtils.shake_camera(0.6, 1.0)

	# Câmera lenta momentânea ao voltar da arena
	Engine.time_scale = 0.3
	var time_tween = create_tween().set_ignore_time_scale(true)
	time_tween.tween_interval(0.5)
	time_tween.tween_callback(func(): Engine.time_scale = 1.0)

	# Flash branco de transição
	var flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 1.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if player.hud_layer: player.hud_layer.add_child(flash)

	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 1.5)
	tw.tween_callback(flash.queue_free)

	# Motion blur momentâneo
	if is_instance_valid(player.hud_layer):
		player.hud_layer.visible = true
		var motion_blur = player.hud_layer.get_node_or_null("MotionBlurOverlay")
		if motion_blur:
			motion_blur.visible = true
			motion_blur.material.set_shader_parameter("blur_strength", 1.8)
			var blur_tween = create_tween()
			blur_tween.tween_property(motion_blur.material, "shader_parameter/blur_strength", 0.0, 2.5).set_trans(Tween.TRANS_SINE)
			blur_tween.finished.connect(func():
				motion_blur.visible = false
				player.is_playing_return_effect = false
			)
		else:
			player.is_playing_return_effect = false
	else:
		player.is_playing_return_effect = false

	await _play_iron_rusks_tally()

	SaveManager.save_game()

func _play_iron_rusks_tally() -> void:
	var earned = SaveManager.iron_rusks_pending
	if earned <= 0: return
	if not is_instance_valid(player.iron_rusks_value_label): return

	var target_layer = player.iron_rusks_value_label.get_parent()
	if not target_layer: return

	var tally_label = Label.new()
	tally_label.add_theme_font_size_override("font_size", 80)
	tally_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	tally_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	tally_label.add_theme_constant_override("outline_size", 10)
	tally_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally_label.pivot_offset = Vector2(60, 40)
	tally_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally_label.text = "+0"
	target_layer.add_child(tally_label)

	var count_tween = create_tween().set_ignore_time_scale(true)
	count_tween.tween_method(func(v): tally_label.text = "+" + str(int(v)), 0.0, float(earned), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await count_tween.finished

	# Voa até o contador do canto e soma
	var start_pos = tally_label.global_position
	var end_pos = player.iron_rusks_value_label.global_position + Vector2(20, 15)

	var fly_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	fly_tween.tween_property(tally_label, "global_position", end_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(tally_label, "scale", Vector2(0.3, 0.3), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(tally_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await fly_tween.finished

	tally_label.queue_free()

	SaveManager.iron_rusks_display += earned
	SaveManager.iron_rusks_pending -= earned

	# Efeito de "pop" no número do canto ao receber a soma
	var pop_tween = create_tween().set_ignore_time_scale(true)
	pop_tween.tween_property(player.iron_rusks_value_label, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(player.iron_rusks_value_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _create_warp_overlay() -> ColorRect:
	# ColorRect em tela cheia que roda o shader de velocidade extrema. Fica num
	# CanvasLayer próprio (bem acima do HUD) e roda mesmo com a cena pausada.
	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var rect := ColorRect.new()
	rect.name = "AmuletWarpOverlay"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/effects/warp_speed.gdshader")
	mat.set_shader_parameter("intensity", 0.0)
	mat.set_shader_parameter("streak", 0.0)
	mat.set_shader_parameter("aberration", 0.0)
	mat.set_shader_parameter("warp", 0.0)
	mat.set_shader_parameter("flash", 0.0)
	# Cada transição começa os streaks numa fase diferente
	mat.set_shader_parameter("time_offset", randf() * 10.0)
	rect.material = mat

	layer.add_child(rect)
	get_tree().root.add_child(layer)

	# Liberar o rect (fim do efeito) leva junto o CanvasLayer criado aqui.
	rect.tree_exited.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)
	return rect


func _ensure_warp_audio_bus() -> StringName:
	# Bus dedicado com distorção pesada + corte de agudos, deixando o som da
	# transição sujo e grave. Criado uma única vez por sessão.
	var bus_name := "AmuletWarp"
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return bus_name

	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.85
	dist.pre_gain = 6.0
	dist.post_gain = -2.0
	AudioServer.add_bus_effect(idx, dist)

	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = 2200.0
	low.resonance = 0.6
	AudioServer.add_bus_effect(idx, low)

	var amp := AudioEffectAmplify.new()
	amp.volume_db = 4.0
	AudioServer.add_bus_effect(idx, amp)

	return bus_name
