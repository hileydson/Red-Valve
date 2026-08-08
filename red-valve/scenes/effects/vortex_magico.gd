@tool
extends Node3D

@export_group("Tamanho do Efeito")
@export var raio_do_furacao: float = 4.0:
	set(value):
		raio_do_furacao = value
		_update_vortex()

@export var raio_interno: float = 1.0:
	set(value):
		raio_interno = value
		_update_vortex()

@export var gravidade_vertical: float = 2.0:
	set(value):
		gravidade_vertical = value
		_update_vortex()

@export var alcance_da_luz: float = 8.0:
	set(value):
		alcance_da_luz = value
		_update_vortex()

@export var tamanho_das_particulas: float = 0.05:
	set(value):
		tamanho_das_particulas = value
		_update_vortex()

func _ready() -> void:
	if get_child_count() == 0:
		_generate_vortex()
	_update_vortex()

func _update_vortex() -> void:
	if not is_inside_tree():
		return
		
	var particles = get_node_or_null("MagicParticles")
	if particles and particles is GPUParticles3D and particles.process_material is ParticleProcessMaterial:
		var pass_mat = particles.process_material as ParticleProcessMaterial
		pass_mat.emission_ring_radius = raio_do_furacao
		pass_mat.emission_ring_inner_radius = raio_interno
		pass_mat.gravity = Vector3(0, gravidade_vertical, 0)
		pass_mat.scale_min = tamanho_das_particulas * 0.5
		pass_mat.scale_max = tamanho_das_particulas * 1.5
		
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
	particles.visibility_aabb = AABB(Vector3(-15, -5, -15), Vector3(30, 30, 30))
	
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
	pass_mat.emission_ring_inner_radius = raio_interno
	
	pass_mat.orbit_velocity_min = 0.3
	pass_mat.orbit_velocity_max = 1.0
	pass_mat.radial_velocity_min = -3.0
	pass_mat.radial_velocity_max = -1.0
	pass_mat.gravity = Vector3(0, gravidade_vertical, 0)
	
	pass_mat.scale_min = tamanho_das_particulas * 0.5
	pass_mat.scale_max = tamanho_das_particulas * 1.5
	
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
	pass_mat.turbulence_noise_strength = 1.5
	pass_mat.turbulence_noise_scale = 3.0
	
	particles.process_material = pass_mat
	
	var mesh = QuadMesh.new()
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	add_child(particles)
	particles.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	
	var light = OmniLight3D.new()
	light.name = "MagicLight"
	light.light_color = Color(0.8, 0.3, 1.0)
	light.light_energy = 5.0
	light.omni_range = alcance_da_luz
	light.shadow_enabled = true
	add_child(light)
	light.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
