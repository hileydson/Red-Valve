@tool
extends Node3D

@export_group("Tamanho do Efeito")
@export var tamanho_das_particulas: float = 0.015:
	set(value):
		tamanho_das_particulas = value
		_update_vortex()

@export var raio_do_furacao: float = 1.5:
	set(value):
		raio_do_furacao = value
		_update_vortex()

@export var alcance_da_luz: float = 4.0:
	set(value):
		alcance_da_luz = value
		_update_vortex()

func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate_vortex()
	elif get_child_count() == 0:
		_generate_vortex()
	else:
		_update_vortex()

func _update_vortex() -> void:
	if not is_inside_tree():
		return
		
	var particles = get_node_or_null("MagicParticles")
	if particles and particles is GPUParticles3D:
		if particles.process_material is ParticleProcessMaterial:
			var pass_mat = particles.process_material as ParticleProcessMaterial
			pass_mat.emission_ring_radius = raio_do_furacao
			pass_mat.emission_ring_inner_radius = max(raio_do_furacao * 0.3, 0.1)
			
		if particles.draw_pass_1 is QuadMesh:
			var mesh = particles.draw_pass_1 as QuadMesh
			mesh.size = Vector2(tamanho_das_particulas, tamanho_das_particulas)
		
	var light = get_node_or_null("MagicLight")
	if light and light is OmniLight3D:
		light.omni_range = alcance_da_luz

func _generate_vortex() -> void:
	# Limpa filhos se houver algum
	for child in get_children():
		child.free()
		
	var particles = GPUParticles3D.new()
	particles.name = "MagicParticles"
	particles.amount = 400
	particles.lifetime = 3.5
	particles.randomness = 0.5
	particles.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	particles.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	
	# Material Visual
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	# Lógica do Furacão
	var pass_mat = ParticleProcessMaterial.new()
	pass_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pass_mat.emission_ring_axis = Vector3.UP
	pass_mat.emission_ring_height = 0.5
	pass_mat.emission_ring_radius = raio_do_furacao
	pass_mat.emission_ring_inner_radius = max(raio_do_furacao * 0.3, 0.1)
	
	pass_mat.orbit_velocity_min = 0.3
	pass_mat.orbit_velocity_max = 1.0
	pass_mat.radial_velocity_min = -1.5
	pass_mat.radial_velocity_max = -0.5
	pass_mat.gravity = Vector3(0, 1.5, 0)
	
	pass_mat.scale_min = 0.5
	pass_mat.scale_max = 1.5
	
	var curve = CurveTexture.new()
	var c = Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.2, 1))
	c.add_point(Vector2(0.8, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pass_mat.scale_curve = curve
	
	# Cores Mágicas
	var grad = GradientTexture1D.new()
	var g = Gradient.new()
	g.set_color(0, Color(0.1, 0.5, 2.0, 0.0))  
	g.add_point(0.1, Color(0.1, 0.8, 2.5, 1.2))  
	g.add_point(0.4, Color(1.5, 0.2, 2.0, 1.2))  
	g.add_point(0.7, Color(2.5, 0.1, 0.5, 1.2))  
	g.set_color(1, Color(1.0, 0.1, 0.1, 0.0))    
	grad.gradient = g
	pass_mat.color_ramp = grad
	
	pass_mat.turbulence_enabled = true
	pass_mat.turbulence_noise_strength = 1.0
	pass_mat.turbulence_noise_scale = 3.0
	
	particles.process_material = pass_mat
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(tamanho_das_particulas, tamanho_das_particulas)
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	add_child(particles)
	particles.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	
	var magic_light = OmniLight3D.new()
	magic_light.name = "MagicLight"
	magic_light.light_color = Color(0.8, 0.3, 1.0)
	magic_light.light_energy = 5.0
	magic_light.omni_range = alcance_da_luz
	magic_light.shadow_enabled = true
	add_child(magic_light)
	magic_light.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
