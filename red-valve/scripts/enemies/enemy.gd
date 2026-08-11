
## Classe generica pra qualquer inimigo
## Com sistema de HP e dano assim como projetar sangue e play nas animacoes
##
## Basta leva-la na cena do novo inimigo e editar somente os shapes e adicionar o animationtree com os nomes abaixo
## - attack
## - dead
## - idle
## - walk
##
## Configurar tambem as variaveis exportadas e especificas abaixo
## - SPEED
## - distance_to_aproach
## - health
##
## O novo inimigo devera estar dentro desse import e com o nome de "enemy_model"
##
## Mudar os growls 1 e 2 como quiser lembrando de antes passar para unique
##
 
extends CharacterBody3D

@onready var player = get_tree().get_first_node_in_group("player")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $"enemy_model/AnimationTree"
@onready var blood_out: AudioStreamPlayer3D = $blood_out
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var growl_attack: AudioStreamPlayer3D = $growl_attack
@onready var growl_timed: AudioStreamPlayer3D = $growl_timed
@onready var growl_death: AudioStreamPlayer3D = $growl_death
@onready var growl_damage_taken: AudioStreamPlayer3D = $growl_damage_taken
@onready var steps: AudioStreamPlayer3D = $steps
@onready var drop_dead: AudioStreamPlayer3D = $drop_dead

@export var SPEED = 2.0
const ACCEL = 4.0

@export var distance_to_aproach = 15
@export var attack_damage = 15
@export var enemy_name: String = "ZOMBIE"

# --- Sistema de Ataque Ranged ---
@export var is_ranged_attacker: bool = false
@export var ranged_attack_cooldown: float = 10.0
var projectile_source: Node3D = null
var ranged_attack_timer: float = 5.0 # O primeiro ataque é mais rápido
# --------------------------------

@export var shoots_fireball: bool = false

@export var max_health = 100
var current_health = max_health
var update_timer = 0.0

var playback 
var dead:bool = false

func _ready() -> void:
	playback = animation_tree["parameters/playback"]
	
	# Limpa componentes da barra 3D antiga da cena herdada
	var old_sprite = get_node_or_null("HealthBarSprite")
	if old_sprite: old_sprite.queue_free()
	var old_viewport = get_node_or_null("HealthBarViewport")
	if old_viewport: old_viewport.queue_free()

func _physics_process(delta: float) -> void:
	
	if global_position.y < -10.0 and not dead:
		take_damage(max_health)
		return
	if dead: 
		steps.stop()
		return
	
	# 1. Gravidade sempre ativa
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

	
	if player and nav_agent:
		var distancia_to_player = self.global_position.distance_to(player.global_position)
		
		# 2. Atualiza o destino apenas 5 vezes por segundo (Economiza CPU)
		update_timer += delta
		if update_timer >= 0.2:
			nav_agent.target_position = player.global_position
			update_timer = 0.0
		
		# 3. Calcula o movimento se ainda não chegou no alvo
		if not nav_agent.is_navigation_finished() and (distancia_to_player<distance_to_aproach):
			
			# Verifica se vai atacar corpo a corpo ou à distância
			var vai_atacar = false
			var disparou_agora = false
			
			if is_ranged_attacker or shoots_fireball:
				ranged_attack_timer -= delta
				if ranged_attack_timer <= 0.0:
					vai_atacar = true
					disparou_agora = true
					ranged_attack_timer = 6.0 if shoots_fireball else ranged_attack_cooldown
					
			if not vai_atacar and distancia_to_player < 2.5:
				vai_atacar = true
				
			if vai_atacar:
				steps.stop()
				if !growl_attack.playing: growl_attack.play()
				
				if disparou_agora:
					if shoots_fireball:
						playback.travel("attack")
						_throw_fireball()
					elif is_ranged_attacker:
						playback.travel("attack")
						_throw_random_projectile()
				else:
					playback.travel("attack_2")
					if shoots_fireball:
						ranged_attack_timer = 10.0
			else:
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
				
				if steps.playing == false and !dead: 
					steps.play()
					playback.travel("walk")
		else:
			steps.stop()			
			playback.travel("idle")
			# Para gradualmente ao chegar
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	# 5. Move o corpo físico
	move_and_slide()
	
	
func take_damage(amount):
	if growl_damage_taken.playing == false: growl_damage_taken.play()
	blood_out.play()
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	
	# Aciona a UI Global de Chefe
	var root = get_tree().root
	var global_health_ui = root.get_node_or_null("GlobalEnemyHealthUI")
	if not global_health_ui:
		global_health_ui = load("res://scripts/ui/global_enemy_health.gd").new()
		global_health_ui.name = "GlobalEnemyHealthUI"
		root.add_child(global_health_ui)
		
	global_health_ui.show_health(self, tr(enemy_name), current_health, max_health)
	
	if current_health <= 0 and !dead:
		die()

func die():
	growl_death.play()
	
	dead = true
	# Seu código de morte aqui
	playback.travel("dead")
	
	await get_tree().create_timer(3.7).timeout
	drop_dead.play()
	
	await get_tree().create_timer(1.0).timeout
	self.set_collision_layer_value(3,false)
	
	await get_tree().create_timer(15.0).timeout
	queue_free()


func _on_timer_timeout() -> void:
	if !dead:
		if !growl_timed.playing: growl_timed.play()


func _on_attack_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and !dead:
		
		# 1. Calcula a direção oposta ao impacto
		var direcao = (body.global_position - global_position).normalized()
		direcao.y = 0 # Mantém no chão
		
		# 2. Define o ponto de destino (ex: 3 metros para trás)
		var destino = body.global_position + (direcao * 3.0)
		
		# 3. Cria o movimento suave
		var tween = create_tween()
		tween.tween_property(body, "global_position", destino, 0.2).set_trans(Tween.TRANS_QUAD)
		
		# 4. Chama o tremor de tela
		GlobalUtils.shake_camera(0.2, 0.2)
		
		#lanca damage no player
		body.take_damage(attack_damage)

func _throw_random_projectile() -> void:
	if not projectile_source or projectile_source.get_child_count() == 0:
		return
		
	# Espera o inimigo bater os braços no chão (aproximadamente 2.2 segundos depois do início da animação)
	await get_tree().create_timer(2.2).timeout
	
	if dead or not player:
		return
		
	var children = projectile_source.get_children()
	var random_piece = children[randi() % children.size()]
	
	if not random_piece is Node3D:
		return
		
	# Cria uma cópia da peça
	var clone = random_piece.duplicate()
	
	# Cria o corpo do projétil
	var projectile = Area3D.new()
	projectile.name = "EnemyProjectile"
	
	# Adiciona colisões
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.8 # Tamanho aproximado de colisão
	col.shape = sphere
	projectile.add_child(col)
	
	# Adiciona a malha clonada
	projectile.add_child(clone)
	clone.position = Vector3.ZERO # Reseta a posição local do clone para ficar centralizado na colisão
	
	# Adiciona à cena principal
	get_tree().current_scene.add_child(projectile)
	
	# Posição de disparo (um pouco acima e à frente do chefe)
	var forward_dir = global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 1.5, 0) + (forward_dir * 1.5)
	projectile.global_position = spawn_pos
	
	# Posição do alvo (onde o player está AGORA)
	var target_pos = player.global_position + Vector3(0, 1.0, 0) # Mira no peito
	
	# Gira aleatoriamente o projétil enquanto viaja e move ele até o jogador
	var tween = create_tween().set_parallel(true)
	# 0.9s de tempo de voo (velocidade média/equilibrada)
	tween.tween_property(projectile, "global_position", target_pos, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(clone, "rotation", Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI)), 0.9)
	
	# Conecta o sinal de hit para causar dano
	projectile.body_entered.connect(func(body):
		if body == player:
			player.take_damage(attack_damage)
			# Tremor de câmera
			GlobalUtils.shake_camera(0.2, 0.2)
			projectile.queue_free()
	)
	
	# Destrói automaticamente se não bater no player (depois de dar o tempo do tween + folga)
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(projectile):
			projectile.queue_free()
	)

func _throw_fireball() -> void:
	# O inimigo costuma bater, então vamos esperar 2.4s para sincronizar com o soco/animação
	await get_tree().create_timer(2.4).timeout
	
	if dead or not is_instance_valid(player):
		return
		
	# Instancia o novo script cheio de efeitos avançados
	var fireball_script = load("res://scripts/effects/fireball_projectile.gd")
	if not fireball_script: return
	
	var projectile = fireball_script.new()
	projectile.target_player = player
	
	# Posição Inicial: Bem acima, para vir de cima para baixo
	get_tree().current_scene.add_child(projectile)
	
	var forward_dir = global_transform.basis.z.normalized()
	projectile.global_position = global_position + Vector3(0, 2.8, 0) + (forward_dir * 1.0)
