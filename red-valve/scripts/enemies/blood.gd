extends GPUParticles3D
@onready var mancha: Sprite3D = $mancha

func _ready() -> void:
	# ==========================================
	# SANGUE COMBINADO (LINHAS + QUADRADINHOS ORIGINAIS)
	# ==========================================
	amount = 60 # Aumentei um pouco para ter volume pros quadradinhos
	explosiveness = 0.95
	one_shot = true
	lifetime = 1.0
	randomness = 0.5
	
	trail_enabled = true
	trail_lifetime = 0.15
	
	# Física do impacto
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.4, -1.0)
	mat.spread = 40.0 # Um pouco mais de spread pros quadradinhos espalharem
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -6.0, 0)
	
	mat.color = Color(0.8, 0.01, 0.01, 1.0)
	
	var scale_curve = CurveTexture.new()
	var s_curve = Curve.new()
	s_curve.add_point(Vector2(0.0, 1.0))
	s_curve.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = s_curve
	mat.scale_curve = scale_curve
	
	process_material = mat
	
	# Precisamos de 2 passes para mesclar as duas geometrias no mesmo efeito
	draw_passes = 2
	
	# ==========================================
	# PASS 1: RASTRO (LINHAS DE SANGUE)
	# ==========================================
	var tmesh = RibbonTrailMesh.new()
	tmesh.size = 0.012
	tmesh.sections = 4
	
	var qmat = StandardMaterial3D.new()
	qmat.use_particle_trails = true
	qmat.albedo_color = Color(0.8, 0.0, 0.0, 0.9)
	# CORREÇÃO DA LUZ: Unshaded faz o sangue ignorar sombras e brilhar forte sempre!
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	tmesh.material = qmat
	draw_pass_1 = tmesh
	
	# ==========================================
	# PASS 2: QUADRADINHOS ORIGINAIS
	# ==========================================
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.012, 0.04) # Tamanho exato de como era originalmente
	
	var quad_mat = StandardMaterial3D.new()
	quad_mat.albedo_color = Color(0.75, 0.0, 0.06, 0.8)
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# CORREÇÃO DA LUZ: Também Unshaded para combinar com as linhas e iluminar
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	quad_mesh.material = quad_mat
	draw_pass_2 = quad_mesh
	
	# ==========================================
	# IMPACT FRAME (MANCHA)
	# ==========================================
	mancha.modulate.a = 0.5
	mancha.scale = Vector3(0.1, 0.1, 0.1) # Começa bem pequenina
	
	# Fazemos a mancha de chão também ignorar luz ambiente, se desejar:
	var mancha_mat = StandardMaterial3D.new()
	if mancha.texture:
		mancha_mat.albedo_texture = mancha.texture
		mancha_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mancha_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Para usar material no Sprite3D
		mancha.material_override = mancha_mat
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mancha, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_OUT) # Sumindo mais rápido
	tween.tween_property(mancha, "scale", Vector3(0.25, 0.25, 0.25), 0.1).set_ease(Tween.EASE_OUT) # Tamanho bem pequeno
	
	emitting = true
	
	if not is_inside_tree() or get_tree() == null: return
	await get_tree().create_timer(lifetime + 0.2).timeout
	queue_free()

func _process(delta: float) -> void:
	pass
