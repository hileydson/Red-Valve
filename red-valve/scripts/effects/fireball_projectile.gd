extends Area3D

var target_player: Node3D
var speed: float = 7.0
var damage: int = 20
var time_alive: float = 0.0
var max_life: float = 4.0
var direction: Vector3 = Vector3.ZERO

var core_mesh: MeshInstance3D
var omni_light: OmniLight3D
var fire_particles: GPUParticles3D
var sparks_particles: GPUParticles3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 # Acerta o player (camada 1 e 2)
	
	# Colisão
	var col = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.8 # Área generosa
	col.shape = sphere_shape
	add_child(col)
	
	_create_visuals()
	
	body_entered.connect(_on_body_entered)

func _create_visuals() -> void:
	# 1. Luz Pulsante
	omni_light = OmniLight3D.new()
	omni_light.light_color = Color(1.0, 0.4, 0.0)
	omni_light.light_energy = 8.0
	omni_light.omni_range = 15.0
	add_child(omni_light)
	
	# 2. Núcleo Magmático
	core_mesh = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	core_mesh.mesh = sm
	
	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.8, 0.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.5, 0.0)
	core_mat.emission_energy_multiplier = 5.0
	
	# Textura procedural de ruído para dar aspecto de plasma
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.05
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	core_mat.albedo_texture = noise_tex
	core_mesh.material_override = core_mat
	add_child(core_mesh)
	
	# Textura suave para as partículas
	var grad2d = GradientTexture2D.new()
	grad2d.fill = GradientTexture2D.FILL_RADIAL
	grad2d.fill_from = Vector2(0.5, 0.5)
	grad2d.fill_to = Vector2(1, 0.5)
	var g = Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color.TRANSPARENT])
	g.offsets = PackedFloat32Array([0.0, 0.5])
	grad2d.gradient = g
	
	# 3. Rastro de Fogo (Partículas Principais)
	fire_particles = GPUParticles3D.new()
	fire_particles.amount = 60
	fire_particles.lifetime = 0.8
	
	var part_mat = ParticleProcessMaterial.new()
	part_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	part_mat.emission_sphere_radius = 0.4
	part_mat.direction = Vector3(0, 0, 1) # Para trás do projétil
	part_mat.spread = 15.0
	part_mat.initial_velocity_min = 2.0
	part_mat.initial_velocity_max = 5.0
	part_mat.gravity = Vector3(0, 3, 0) # Fogo sobe
	
	# Degradê de cores: Amarelo -> Laranja -> Vermelho Escuro -> Transparente
	var color_grad = Gradient.new()
	color_grad.colors = PackedColorArray([Color(1, 1, 0.2, 1), Color(1, 0.3, 0, 1), Color(0.1, 0, 0, 0)])
	color_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var color_grad_tex = GradientTexture1D.new()
	color_grad_tex.gradient = color_grad
	part_mat.color_ramp = color_grad_tex
	
	# Curva de escala (Diminui)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.5))
	scale_curve.add_point(Vector2(1, 0.0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	part_mat.scale_curve = scale_tex
	
	fire_particles.process_material = part_mat
	
	# Malha da partícula
	var quad_mesh = QuadMesh.new()
	var quad_mat = StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.albedo_texture = grad2d
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_mat.vertex_color_use_as_albedo = true
	quad_mesh.material = quad_mat
	fire_particles.draw_pass_1 = quad_mesh
	add_child(fire_particles)

func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive > max_life:
		queue_free()
		return
		
	# Pulsação da Luz
	omni_light.light_energy = 5.0 + sin(time_alive * 20.0) * 3.0
	
	# Efeito visual de giro do núcleo
	if is_instance_valid(core_mesh):
		core_mesh.rotate_y(delta * 10.0)
		core_mesh.rotate_x(delta * 5.0)

	if direction == Vector3.ZERO and is_instance_valid(target_player):
		# Trava a mira no ponto exato onde o player estava no momento que a bola nasceu
		var aim_target = target_player.global_position + Vector3(0, 0.5, 0)
		direction = (aim_target - global_position).normalized()

	if direction != Vector3.ZERO:
		# Move suavemente em linha reta
		global_position += direction * speed * delta
		
		# Olha na direção do voo (para alinhar as partículas de fumaça que vão para trás -Z)
		if direction.length_squared() > 0.001:
			look_at(global_position + direction, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if body == target_player:
		if body.get("invulnerable") == true:
			return
		# Aplica o Dano
		if body.has_method("take_damage"):
			body.take_damage(damage)
			GlobalUtils.shake_camera(0.4, 0.4)
			
		_explode_and_die()

func _explode_and_die() -> void:
	# Para simular uma explosão de impacto sem criar outra cena,
	# vamos explodir o núcleo, acelerar partículas, e morrer logo depois.
	set_physics_process(false)
	collision_mask = 0
	
	core_mesh.visible = false
	omni_light.light_energy = 15.0 # Clarão
	
	# Partículas explodem pra todo lado
	if fire_particles.process_material is ParticleProcessMaterial:
		fire_particles.process_material.direction = Vector3.ZERO
		fire_particles.process_material.spread = 180.0
		fire_particles.process_material.initial_velocity_min = 10.0
		fire_particles.process_material.initial_velocity_max = 20.0
		fire_particles.emitting = false # Para de emitir, mas deixa as velhas morrerem
		
	var tw = create_tween()
	tw.tween_property(omni_light, "light_energy", 0.0, 0.4)
	await tw.finished
	queue_free()
