extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "VortexMagico"
	
	var particles = GPUParticles3D.new()
	particles.name = "MagicParticles"
	particles.amount = 400
	particles.lifetime = 4.0
	particles.randomness = 0.5
	particles.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	particles.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 20, 20))
	
	# Material visual (Brilhante)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Aumentar energia da emissão no Godot 4 para causar Glow (no material Unshaded, a cor já age como emissão se > 1.0)
	
	var pass_mat = ParticleProcessMaterial.new()
	# Emissão em anel para formar a base do furacão
	pass_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pass_mat.emission_ring_axis = Vector3.UP
	pass_mat.emission_ring_height = 1.0
	pass_mat.emission_ring_radius = 8.0
	pass_mat.emission_ring_inner_radius = 4.0
	
	# Velocidade orbital (girar em volta do eixo Y)
	pass_mat.orbit_velocity_min = 0.2
	pass_mat.orbit_velocity_max = 0.8
	
	# Velocidade radial (puxar para o centro)
	pass_mat.radial_velocity_min = -4.0
	pass_mat.radial_velocity_max = -1.0
	
	# Subir como um tornado
	pass_mat.gravity = Vector3(0, 3.5, 0)
	
	# Tamanho
	pass_mat.scale_min = 0.05
	pass_mat.scale_max = 0.2
	
	var curve = CurveTexture.new()
	var c = Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.2, 1))
	c.add_point(Vector2(0.8, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pass_mat.scale_curve = curve
	
	# Cores Mágicas (Azul, Roxo, Rosa)
	var grad = GradientTexture1D.new()
	var g = Gradient.new()
	g.set_color(0, Color(0.1, 0.5, 2.0, 0.0)) # Azul brilhante transparente
	g.add_point(0.2, Color(0.2, 0.8, 2.5, 1.0)) # Azul Ciano
	g.add_point(0.5, Color(1.5, 0.2, 2.0, 1.0)) # Roxo/Rosa
	g.add_point(0.8, Color(2.5, 0.1, 0.5, 1.0)) # Vermelho/Rosa quente
	g.set_color(1, Color(1.0, 0.1, 0.1, 0.0))
	grad.gradient = g
	pass_mat.color_ramp = grad
	
	pass_mat.hue_variation_min = -0.05
	pass_mat.hue_variation_max = 0.05
	
	# Turbulência para movimento caótico
	pass_mat.turbulence_enabled = true
	pass_mat.turbulence_noise_strength = 2.5
	pass_mat.turbulence_noise_scale = 4.0
	
	particles.process_material = pass_mat
	
	var mesh = QuadMesh.new()
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	root.add_child(particles)
	particles.owner = root
	
	# Criar um Omnilight3D no centro para iluminar o ambiente de forma mística
	var light = OmniLight3D.new()
	light.name = "MagicLight"
	light.light_color = Color(0.6, 0.2, 1.0)
	light.light_energy = 5.0
	light.omni_range = 15.0
	light.shadow_enabled = true
	root.add_child(light)
	light.owner = root
	
	# Salvar a cena
	var packed = PackedScene.new()
	packed.pack(root)
	
	if not DirAccess.dir_exists_absolute("res://scenes/effects"):
		DirAccess.make_dir_recursive_absolute("res://scenes/effects")
	
	var err = ResourceSaver.save(packed, "res://scenes/effects/vortex_magico.tscn")
	if err == OK:
		print("SUCCESS")
	else:
		print("FAILED: ", err)
	
	quit()
