extends Node

# Assistente de mira (aim assist) por magnetismo suave: quando há um inimigo
# perto do centro da tela, a câmera é puxada de leve na direção dele.
#
# Quando fica ativo:
#   - Maycow NÃO normal (parasita): sempre, já que o combate é mais frenético.
#   - Maycow normal: só enquanto está mirando (is_aiming).
#
# Liga/desliga e intensidade em Configurações > Gameplay:
# SaveManager.config["aim_assist"] e ["aim_assist_strength"] (0.5 a 2.0).
# A intensidade escala as duas coisas ao mesmo tempo: o tamanho do cone que
# procura alvos E a força do puxão - por isso a diferença é bem perceptível.

const MAX_DISTANCE := 45.0          # Alcance máximo pra considerar um alvo
const BASE_ANGLE_DEG := 7.0         # Cone ao redor do centro da tela (x intensidade)
const MAX_PULL_DEG_PER_SEC := 110.0 # Teto da correção (x intensidade)
const TARGET_HEIGHT_OFFSET := 1.1   # Mira no tronco, não no chão do inimigo

var player: CharacterBody3D
var _target: Node3D = null

func _ready() -> void:
	player = get_parent()

func _physics_process(delta: float) -> void:
	_target = null

	if not _is_active(): return

	var cam := player.get_viewport().get_camera_3d() if player.get_viewport() else null
	if not is_instance_valid(cam): return

	_target = _find_best_target(cam)
	if not _target: return

	_pull_towards(cam, _target, delta)

func get_current_target() -> Node3D:
	return _target

func _strength() -> float:
	return clampf(float(SaveManager.config.get("aim_assist_strength", 1.0)), 0.5, 2.0)

func _cone_deg() -> float:
	return BASE_ANGLE_DEG * _strength()

func _is_active() -> bool:
	if not SaveManager.config.get("aim_assist", true): return false
	if not is_instance_valid(player): return false
	if GlobalEvents.in_cutscene: return false
	if player.is_using_ultimate or player.camera_bullet_time_ON: return false
	if player.is_reloading: return false
	# Durante a seleção do amuleto quem manda é a mira do poder, não o aim assist
	if player.amulet_magic_active: return false

	if GlobalEvents.is_maycow_normal:
		return player.is_aiming
	return true

func _find_best_target(cam: Camera3D) -> Node3D:
	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z
	var max_angle := deg_to_rad(_cone_deg())

	var best: Node3D = null
	var best_angle := max_angle

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not is_instance_valid(enemy): continue
		# Inimigos da cena pausada atrás da arena continuam no grupo, mas com o
		# processamento desligado - eles não podem virar alvo.
		if not enemy.is_inside_tree() or not enemy.can_process(): continue
		if not enemy.is_visible_in_tree(): continue
		# Inimigos usam a flag "dead" (ver zombie.gd); mortos não atraem a mira.
		if "dead" in enemy and enemy.dead: continue

		var aim_point: Vector3 = enemy.global_position + Vector3.UP * TARGET_HEIGHT_OFFSET
		var to_target := aim_point - origin
		var dist := to_target.length()
		if dist < 1.0 or dist > MAX_DISTANCE: continue

		var angle := forward.angle_to(to_target / dist)
		if angle >= best_angle: continue
		if not _has_line_of_sight(origin, aim_point, enemy): continue

		best_angle = angle
		best = enemy

	return best

func _has_line_of_sight(from: Vector3, to: Vector3, enemy: Node3D) -> bool:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return true
	var collider = hit.get("collider")
	if collider == null: return true
	# Bateu no próprio inimigo (ou num filho dele): caminho livre.
	return collider == enemy or (collider is Node and enemy.is_ancestor_of(collider))

func _pull_towards(cam: Camera3D, target: Node3D, delta: float) -> void:
	var origin := cam.global_position
	var aim_point: Vector3 = target.global_position + Vector3.UP * TARGET_HEIGHT_OFFSET
	var to_target := (aim_point - origin).normalized()
	var forward := -cam.global_transform.basis.z

	var angle := forward.angle_to(to_target)
	if angle < deg_to_rad(0.15): return # Já está em cima do alvo

	# Quanto mais perto do centro, mais forte o magnetismo - o efeito "gruda" a
	# mira sem impedir o jogador de varrer a tela procurando outro inimigo.
	var closeness: float = 1.0 - clampf(angle / deg_to_rad(_cone_deg()), 0.0, 1.0)
	# Curva mais suave que a quadrática de antes: o puxão já é sentido mesmo
	# com o alvo longe do centro do cone.
	var falloff: float = closeness * (0.35 + 0.65 * closeness)
	var max_step: float = deg_to_rad(MAX_PULL_DEG_PER_SEC) * _strength() * delta * falloff

	# --- Horizontal: gira o corpo do player (mesma convenção do olhar manual) ---
	var flat_forward := Vector2(forward.x, forward.z)
	var flat_target := Vector2(to_target.x, to_target.z)
	if flat_forward.length() > 0.001 and flat_target.length() > 0.001:
		var yaw_delta := flat_forward.angle_to(flat_target)
		player.rotate_y(-clampf(yaw_delta, -max_step, max_step))

	# --- Vertical: inclina a câmera ativa, respeitando os mesmos limites do olhar ---
	var pitch_current := asin(clampf(forward.y, -1.0, 1.0))
	var pitch_target := asin(clampf(to_target.y, -1.0, 1.0))
	var pitch_delta := clampf(pitch_target - pitch_current, -max_step, max_step)
	var is_third_person: bool = cam == player.camera_third_person
	var v_down := -25.0 if is_third_person else -60.0
	var v_up := 20.0 if is_third_person else 60.0
	cam.rotation.x = clampf(cam.rotation.x + pitch_delta, deg_to_rad(v_down), deg_to_rad(v_up))
