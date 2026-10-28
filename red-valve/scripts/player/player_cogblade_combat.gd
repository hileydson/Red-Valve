extends Node

## Combate da cogblade. Poses, pegadas e clipes ficam na mao_armada;
## este componente cuida somente de entrada, estamina, dano e efeitos.
var player: CharacterBody3D
var _rig: Node3D
var _ativo := false
var _atacando := false
var _bloqueando := false
var _ultimo_ataque := -1
var _penultimo_ataque := -1
var _ready_ms := 0
var _rastro_ativo := false
var _rastro: MeshInstance3D
var _malha_rastro: ImmediateMesh
var _material_rastro: StandardMaterial3D
var _amostras: Array[Dictionary] = []

func _ready() -> void:
	process_priority = 20 # Depois do AnimationPlayer e das pegadas do rig.
	player = get_parent()
	_rig = player.get_node_or_null("Camera3D/hand_with_pistol/rig")
	if _rig != null:
		_rig.cogblade_evento.connect(_evento_animacao)

func _process(delta: float) -> void:
	var equipada := SaveManager.cogblade_como_arma() and not GlobalEvents.is_maycow_normal
	if equipada != _ativo:
		_ativo = equipada
		_cancelar()
	if not _ativo:
		return
	if not _pode_agir():
		_cancelar()
		_atualizar_rastro(delta)
		return
	_processar_bloqueio(delta)
	if not _atacando and not _bloqueando and Input.is_action_just_pressed("ui_shoot"):
		executar_ataque()
	_atualizar_rastro(delta)

func _pode_agir() -> bool:
	return is_instance_valid(_rig) and _rig.arma_na_mao() == "cogblade" \
		and not _rig.em_troca() and not player.is_using_ultimate \
		and not player.is_magic_attacking and not player.is_blade_returning \
		and not player.cogblade_menu_open and not player.transition_camera \
		and player.camera.current and not player.are_cutscene_inputs_blocked() \
		and not get_tree().paused

func _cancelar() -> void:
	if (_atacando or _bloqueando) and is_instance_valid(_rig):
		_rig.animar_cogblade("idle", 0.12)
	_atacando = false
	_bloqueando = false
	_rastro_ativo = false
	_amostras.clear()
	if is_instance_valid(_malha_rastro):
		_malha_rastro.clear_surfaces()
	player.cogblade_melee_active = false
	player.cogblade_blocking = false

func _processar_bloqueio(delta: float) -> void:
	var quer: bool = Input.is_action_pressed("ui_hold_first_person_view") \
		and not _atacando and (not player.is_exhausted or player._stamina_infinita())
	if quer and not _bloqueando:
		if _rig.animar_cogblade("defesa", 0.08):
			_bloqueando = true
			player.cogblade_blocking = true
	elif not quer and _bloqueando:
		_parar_bloqueio()
	if _bloqueando:
		if not player._stamina_infinita():
			player.current_stamina = maxf(0.0, player.current_stamina - player.cogblade_block_stamina_drain * delta)
		player.stamina_fade_timer = 2.0
		if player.current_stamina <= 0.5 and not player._stamina_infinita():
			player.is_exhausted = true
			_parar_bloqueio()

func _parar_bloqueio() -> void:
	_bloqueando = false
	player.cogblade_blocking = false
	_rig.animar_cogblade("idle", 0.14)

func executar_ataque() -> bool:
	if not _ativo or not _pode_agir() or _atacando or _bloqueando:
		return false
	if Time.get_ticks_msec() < _ready_ms:
		return false
	if not player._stamina_infinita() and (player.is_exhausted or player.current_stamina < player.cogblade_attack_stamina):
		return false
	var idx := _escolher_ataque()
	if not _rig.animar_cogblade("ataque_%d" % (idx + 1), 0.06, maxf(player.cogblade_attack_duration, 0.1)):
		return false
	_penultimo_ataque = _ultimo_ataque
	_ultimo_ataque = idx
	_atacando = true
	player.cogblade_melee_active = true
	if not player._stamina_infinita():
		player.current_stamina = maxf(0.0, player.current_stamina - player.cogblade_attack_stamina)
	player.stamina_fade_timer = 2.0
	return true

func _escolher_ataque() -> int:
	var opcoes: Array[int] = []
	for i in 4:
		if i != _ultimo_ataque and i != _penultimo_ataque:
			opcoes.append(i)
	return opcoes.pick_random()

func _evento_animacao(evento: String) -> void:
	if not _atacando or not _ativo or not _pode_agir():
		return
	match evento:
		"rastro_inicio":
			_rastro_ativo = true
			_play_blade_sound("res://assets/sounds/player/blade_out.mp3", randf_range(0.95, 1.12), -6.0)
		"impacto":
			_aplicar_dano()
		"rastro_fim":
			_rastro_ativo = false
		"fim":
			_atacando = false
			player.cogblade_melee_active = false
			_ready_ms = Time.get_ticks_msec() + player.cogblade_attack_cooldown_ms

func _aplicar_dano() -> void:
	if not is_instance_valid(player):
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3
	if is_instance_valid(cam):
		forward = -cam.global_transform.basis.z
	else:
		forward = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return
	forward = forward.normalized()

	var origin: Vector3 = player.global_position
	var acertou := false
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(inimigo) or not inimigo.has_method("take_damage"):
			continue
		var to: Vector3 = inimigo.global_position - origin
		if to.length() > player.cogblade_attack_range:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > 0.01 and flat.normalized().dot(forward) < 0.15:
			continue
		inimigo.take_damage(player.cogblade_attack_damage)
		acertou = true
		if player.has_method("spawn_blood_effect"):
			player.spawn_blood_effect(inimigo)

	if acertou:
		if is_instance_valid(player.blade_in):
			player.blade_in.play()
		GlobalUtils.shake_camera(0.15, 0.18)
		GlobalUtils.vibrate_controller(Input, 0.35, 0.35, 0.12)
		_play_blade_sound("res://assets/sounds/player/blade_out.mp3",
			randf_range(0.7, 0.9), -1.0)


# Rastro em espaco 3D, preso a dois marcadores do fio; nao desenha riscos na HUD.
func _atualizar_rastro(delta: float) -> void:
	for amostra in _amostras:
		amostra.tempo += delta
	while not _amostras.is_empty() and _amostras[0].tempo > 0.065:
		_amostras.pop_front()
	if _rastro_ativo:
		var movimento: Node3D = _rig.get_node("Armas/Cogblade/Movimento")
		_amostras.append({"base": movimento.get_node("RastroBase").global_position,
			"ponta": movimento.get_node("RastroPonta").global_position, "tempo": 0.0})
	if _amostras.size() < 2:
		if is_instance_valid(_malha_rastro): _malha_rastro.clear_surfaces()
		return
	if not is_instance_valid(_rastro):
		_rastro = MeshInstance3D.new()
		_rastro.name = "RastroCogblade"
		_rastro.top_level = true
		_rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_rastro)
		_malha_rastro = ImmediateMesh.new()
		_rastro.mesh = _malha_rastro
		_material_rastro = StandardMaterial3D.new()
		_material_rastro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_rastro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_rastro.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_rastro.vertex_color_use_as_albedo = true
	_malha_rastro.clear_surfaces()
	_malha_rastro.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material_rastro)
	for amostra in _amostras:
		var alpha := (1.0 - float(amostra.tempo) / 0.065) * 0.14
		_malha_rastro.surface_set_color(Color(0.55, 0.8, 0.85, alpha))
		_malha_rastro.surface_add_vertex(amostra.base)
		_malha_rastro.surface_add_vertex(amostra.ponta)
	_malha_rastro.surface_end()

func _play_blade_sound(path: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.pitch_scale = clampf(pitch, 0.05, 4.0)
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## A defesa reduz 40% do dano e recebe um recuo curto ao absorver o impacto.
func processar_dano_bloqueio(dano: int) -> int:
	if dano <= 0 or not _ativo or not _bloqueando or not _pode_agir():
		return dano
	if not player._stamina_infinita() and player.current_stamina <= 0.5:
		_parar_bloqueio()
		return dano
	var reduzido := maxi(1, int(float(dano) * (1.0 - clampf(player.cogblade_block_damage_reduction, 0.0, 1.0))))
	if not player._stamina_infinita():
		player.current_stamina = maxf(0.0, player.current_stamina - player.cogblade_block_hit_stamina)
	player.stamina_fade_timer = 2.0
	_rig.animar_cogblade("impacto_defesa", 0.035)
	GlobalUtils.shake_camera(0.08, 0.10)
	GlobalUtils.vibrate_controller(Input, 0.25, 0.25, 0.08)
	_play_blade_sound("res://assets/sounds/player/blade_in.mp3", randf_range(0.8, 0.95), -4.0)
	if player.current_stamina <= 0.5 and not player._stamina_infinita():
		player.is_exhausted = true
		_parar_bloqueio()
	return reduzido
