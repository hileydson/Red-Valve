extends CharacterBody3D

const SPEED = 2.0
const ACCEL = 4.0

@onready var player = get_tree().get_first_node_in_group("player")
@onready var nav_agent: NavigationAgent3D = $"../NavigationAgent3D"
@onready var health_bar_sprite: Sprite3D = $HealthBarSprite
@onready var animation_tree: AnimationTree = $"the-cobalt-husker/AnimationTree"
@onready var health_bar: ProgressBar = $HealthBarViewport/HealthBar

var max_health = 150
var current_health = 150
var update_timer = 0.0

var playback 
var dead:bool = false

func _ready() -> void:
	playback = animation_tree["parameters/playback"]
	# Configura os valores iniciais da barra
	health_bar.max_value = max_health
	health_bar.value = current_health
	# Opcional: esconder a barra se estiver com vida cheia
	health_bar_sprite.hide()

func _physics_process(delta: float) -> void:
	if dead: return
	
	# 1. Gravidade sempre ativa
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

	if player and nav_agent:
		# 2. Atualiza o destino apenas 5 vezes por segundo (Economiza CPU)
		update_timer += delta
		if update_timer >= 0.2:
			nav_agent.target_position = player.global_position
			update_timer = 0.0
		
		# 3. Calcula o movimento se ainda não chegou no alvo
		if not nav_agent.is_navigation_finished():
			var next_p = nav_agent.get_next_path_position()
			var direction = (next_p - global_position)
			
			direction.y = 0 # FORÇA o inimigo a não subir
			direction = direction.normalized()
			
			# Aplica a velocidade suavemente
			velocity.x = lerp(velocity.x, direction.x * SPEED, delta * ACCEL)
			velocity.z = lerp(velocity.z, direction.z * SPEED, delta * ACCEL)
			
			# 4. Rotação (Olha para o player, mas mantém o corpo reto)
			var look_pos = player.global_position
			look_pos.y = global_position.y
			if global_position.distance_to(look_pos) > 0.5:
				look_at(look_pos, Vector3.UP)
		else:
			# Para gradualmente ao chegar
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	# 5. Move o corpo físico
	move_and_slide()
	
	
func take_damage(amount):
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	
	health_bar_sprite.show()
	
	# Animação suave da barra diminuindo
	var tween = create_tween()
	tween.tween_property(health_bar, "value", current_health, 0.2).set_trans(Tween.TRANS_SINE)
	
	if current_health <= 0:
		die()

func die():
	dead = true
	health_bar_sprite.hide()
	# Seu código de morte aqui
	playback.travel("dead")
	await get_tree().create_timer(20.0).timeout
	queue_free()
