
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

# --- Escudo de Defesa (a animacao "attack" do The Cobalt Husker) ---
## Liga o poder de defesa: de tempos em tempos o inimigo para, executa a
## animacao "attack" e se fecha numa esfera que absorve a maior parte do dano.
@export var has_defense_shield: bool = false
## Quanto tempo a esfera fica de pe.
@export var defense_shield_duration: float = 12.0
## Fracao do dano que a esfera corta enquanto esta ativa (0.8 = 80% mais fraco).
@export var defense_shield_reduction: float = 0.8
## Faixa de espera entre um uso do poder e o proximo.
@export var defense_shield_min_interval: float = 16.0
@export var defense_shield_max_interval: float = 30.0
var shield_active: bool = false
var _shield_node: Node3D = null
var _shield_cooldown: float = 0.0
var _ultimo_hit_melee: float = 0.0
# ------------------------------------------------------------------

@export var max_health = 100
@export var iron_rusks_value: int = 2
var current_health = max_health
var update_timer = 0.0

signal died

var playback
var dead:bool = false
var cutscene_mode:bool = false
var is_attacking:bool = false
# Período de carência logo após spawnar/carregar a cena: o terreno (Terrain3D) pode
# ainda não ter a colisão pronta nos primeiros instantes, fazendo o inimigo cair através
# do chão e disparar o "fall death" indevidamente. Ignora o check de queda até passar isso.
var _spawn_grace_time: float = 1.5

# --- Congelamento por distância (economiza processamento e evita cair antes do chão
# estar carregado/com colisão pronta perto de inimigos muito longe do player) ---
@export var activation_distance: float = 120.0
var _proximity_timer: Timer
var _is_frozen: bool = false

# --- Navegação ---
# O NavigationRegion3D da stage_1 não cobre a cidade onde se joga (a região fica
# a ~200 m dali), então um inimigo solto na rua recebe caminho vazio e
# `is_navigation_finished()` responde true já no primeiro frame: ele nasceria e
# ficaria plantado olhando o jogador. Quando o navmesh não alcança este ponto o
# inimigo persegue em linha reta; se um dia a cidade for rebakeada, o caminho do
# navmesh volta a valer sozinho, sem mexer neste código.
var _nav_disponivel: bool = false
## Distância horizontal máxima até o navmesh para considerá-lo utilizável aqui.
const NAV_TOLERANCIA := 3.0

func _ready() -> void:
	current_health = max_health
	playback = animation_tree["parameters/playback"]

	# Primeiro uso do escudo mais cedo que o intervalo normal, pra o jogador ver
	# o poder logo no comeco da luta.
	_shield_cooldown = randf_range(6.0, 14.0)

	# Limpa componentes da barra 3D antiga da cena herdada
	var old_sprite = get_node_or_null("HealthBarSprite")
	if old_sprite: old_sprite.queue_free()
	var old_viewport = get_node_or_null("HealthBarViewport")
	if old_viewport: old_viewport.queue_free()

	# Cria uma luz própria e forte exclusiva para o inimigo
	var self_light = OmniLight3D.new()
	self_light.light_color = Color(1.0, 0.9, 0.9) # Luz levemente quente
	self_light.light_energy = 3.5 # Aumentado bastante para que fique bem visível
	self_light.omni_range = 5.0
	self_light.position = Vector3(0, 1.5, 0.8) # Ilumina bem a frente do corpo
	add_child(self_light)

	# Checa a distância do player ANTES de deixar rodar qualquer física: se já nasce
	# longe, nunca chega a processar gravidade sobre um chão que pode nem estar
	# carregado ainda. Um Timer independente reativa quando o player se aproximar.
	_proximity_timer = Timer.new()
	_proximity_timer.wait_time = 0.5
	_proximity_timer.autostart = true
	add_child(_proximity_timer)
	_proximity_timer.timeout.connect(_check_proximity)
	_check_proximity()

func _check_proximity() -> void:
	if dead:
		if is_instance_valid(_proximity_timer): _proximity_timer.stop()
		return
	if not is_instance_valid(player):
		return

	var dist = global_position.distance_to(player.global_position)
	# Margem de histerese: some (congela) só bem além do raio de ativação,
	# pra não ficar ligando/desligando toda hora no limite.
	if dist <= activation_distance and _is_frozen:
		_is_frozen = false
		velocity = Vector3.ZERO
		_spawn_grace_time = 1.5 # Dá o mesmo respiro de novo ao "acordar"
		set_physics_process(true)
	elif dist > activation_distance * 1.3 and not _is_frozen:
		_is_frozen = true
		velocity = Vector3.ZERO
		set_physics_process(false)

## Troca de estado da AnimationTree sem explodir quando o inimigo nao tem aquele
## estado. O The Cobalt Husker, por exemplo, nao tem "idle" na maquina de
## estados: sem esta guarda, cada frame parado dele despeja tres erros no
## console (foram 6 mil em um teste de 3 minutos) e o log fica ilegivel.
func _travel(estado: StringName) -> void:
	if playback == null:
		return
	var maquina := animation_tree.tree_root as AnimationNodeStateMachine
	if maquina != null and not maquina.has_node(estado):
		return
	playback.travel(estado)


## O navmesh cobre o chão debaixo deste inimigo? Consultado 5 vezes por segundo,
## junto com a atualização do destino.
func _atualiza_navegacao_disponivel() -> void:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(map).is_empty():
		_nav_disponivel = false
		return
	var perto := NavigationServer3D.map_get_closest_point(map, global_position)
	_nav_disponivel = Vector2(perto.x - global_position.x, perto.z - global_position.z).length() <= NAV_TOLERANCIA


func _physics_process(delta: float) -> void:
	if _spawn_grace_time > 0.0:
		_spawn_grace_time -= delta

	if _spawn_grace_time <= 0.0 and global_position.y < -10.0 and not dead:
		# Caiu para fora do mapa (chão sem colisão pronta, buraco na cidade).
		# Isso não é uma morte do jogador: anunciar no HUD o fim de um inimigo
		# que ele nunca viu — e ainda pagar iron rusks por isso — é ruído puro.
		remover_em_silencio()
		return
	if dead: 
		steps.stop()
		return
	
	# 1. Gravidade sempre ativa
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

	# Modo cutscene: só olha para o player, sem movimento/ataque
	if cutscene_mode:
		if player:
			var look_pos = player.global_position
			look_pos.y = global_position.y
			if global_position.distance_to(look_pos) > 0.5:
				look_at(look_pos, Vector3.UP)
		move_and_slide()
		return

	if has_defense_shield and not shield_active and not is_attacking and _shield_cooldown > 0.0:
		_shield_cooldown -= delta

	if is_attacking:
		if is_ranged_attacker or shoots_fireball or shield_active:
			steps.stop()
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			if is_instance_valid(player):
				var look_pos = player.global_position
				look_pos.y = global_position.y
				if global_position.distance_to(look_pos) > 0.5:
					look_at(look_pos, Vector3.UP)
			move_and_slide()
			return
		else:
			# Durante o ataque corpo a corpo, continua avançando na direção do player até encostar
			if is_instance_valid(player):
				var dist_p = global_position.distance_to(player.global_position)
				if dist_p > 0.6:
					var dir = (player.global_position - global_position)
					dir.y = 0
					dir = dir.normalized()
					velocity.x = lerp(velocity.x, dir.x * SPEED, delta * ACCEL)
					velocity.z = lerp(velocity.z, dir.z * SPEED, delta * ACCEL)
				else:
					velocity.x = move_toward(velocity.x, 0, SPEED)
					velocity.z = move_toward(velocity.z, 0, SPEED)
				var look_pos = player.global_position
				look_pos.y = global_position.y
				if global_position.distance_to(look_pos) > 0.5:
					look_at(look_pos, Vector3.UP)
			move_and_slide()
			return

	if player and nav_agent:
		var distancia_to_player = self.global_position.distance_to(player.global_position)
		
		# 2. Atualiza o destino apenas 5 vezes por segundo (Economiza CPU)
		update_timer += delta
		if update_timer >= 0.2:
			nav_agent.target_position = player.global_position
			update_timer = 0.0
			_atualiza_navegacao_disponivel()

		# 3. Persegue o jogador enquanto estiver no alcance de aproximação.
		# Não para a 1m nem quando a navegação avisa que chegou perto: continua
		# andando direto para o jogador até encostar de verdade (distancia <= 0.6).
		var em_alcance_perseguicao: bool = distancia_to_player < distance_to_aproach
		var precisa_andar: bool = distancia_to_player > 0.6
		if em_alcance_perseguicao and precisa_andar:
			
			# O poder de defesa tem prioridade: quando o tempo dele vence, o
			# inimigo levanta a esfera em vez de atacar naquele momento.
			var vai_defender = false
			if has_defense_shield and not shield_active and _shield_cooldown <= 0.0:
				if randf() < 0.7:
					vai_defender = true
					_shield_cooldown = randf_range(defense_shield_min_interval, defense_shield_max_interval)
				else:
					# Nao saiu desta vez: tenta de novo daqui a pouco (e o que
					# deixa o poder "eventual" em vez de cronometrado).
					_shield_cooldown = 3.0

			# Verifica se vai atacar corpo a corpo ou à distância
			var vai_atacar = false
			var disparou_agora = false
			
			if not vai_defender and (is_ranged_attacker or shoots_fireball):
				ranged_attack_timer -= delta
				if ranged_attack_timer <= 0.0:
					vai_atacar = true
					disparou_agora = true
					ranged_attack_timer = 6.0 if shoots_fireball else ranged_attack_cooldown
					
			if not vai_defender and not vai_atacar and distancia_to_player < 1.5:
				vai_atacar = true

			if vai_defender:
				steps.stop()
				if !growl_attack.playing: growl_attack.play()
				_exec_defense_attack()
			elif vai_atacar:
				steps.stop()
				if !growl_attack.playing: growl_attack.play()
				
				if disparou_agora:
					if shoots_fireball:
						_exec_fireball_attack()
					elif is_ranged_attacker:
						_exec_ranged_attack()
				else:
					_exec_melee_attack()
			else:
				var next_p = nav_agent.get_next_path_position() if (_nav_disponivel and not nav_agent.is_navigation_finished()) \
					else player.global_position
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
					_travel("walk")
		else:
			steps.stop()			
			_travel("idle")
			# Para gradualmente ao chegar ou se o player estiver longe
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	# 5. Move o corpo físico
	move_and_slide()
	
	
## Tira o inimigo do jogo sem nada na tela: sem barra de chefe, sem iron rusks,
## sem animação nem som de morte. É o caminho de quem some longe do jogador —
## o spawner da cidade usa isto ao liberar quem ficou para trás, e o inimigo
## que cai do mapa também. Morte de verdade (a que o jogador causou) continua
## em `die()`, com HUD e recompensa.
func remover_em_silencio() -> void:
	dead = true
	is_attacking = false
	_derruba_escudo()
	set_physics_process(false)
	if is_instance_valid(steps):
		steps.stop()
	_esconde_hud_de_chefe()
	queue_free()


## A barra de chefe no topo da tela pode estar mostrando justamente este
## inimigo (o jogador bateu nele e seguiu andando). Ela sumiria sozinha em 2 s,
## mas com o nome de alguém que acabou de deixar de existir.
func _esconde_hud_de_chefe() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var hud := get_tree().root.get_node_or_null("GlobalEnemyHealthUI")
	if hud != null and hud.has_method("hide_if_showing"):
		hud.hide_if_showing(self)


func take_damage(amount):
	# Esfera de defesa de pe: o golpe chega bem mais fraco, e a casca reage.
	if shield_active:
		amount = max(1, int(round(float(amount) * (1.0 - defense_shield_reduction))))
		if is_instance_valid(_shield_node) and _shield_node.has_method("flash"):
			_shield_node.flash()

	if growl_damage_taken.playing == false: growl_damage_taken.play()
	blood_out.play()
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	
	if is_instance_valid(player) and player.has_method("add_cogblade_power"):
		# Passa o ponto do corpo (altura do peito) pra gota de sangue sair de lá.
		player.add_cogblade_power(float(amount), global_position + Vector3(0, 1.4, 0))
	
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
	dead = true
	is_attacking = false
	_derruba_escudo()
	died.emit()
	growl_death.play()
	SaveManager.add_iron_rusks(iron_rusks_value)
	# Seu código de morte aqui
	_travel("dead")
	
	if not is_inside_tree() or get_tree() == null: return
	await get_tree().create_timer(3.7).timeout
	drop_dead.play()
	
	if not is_inside_tree() or get_tree() == null: return
	await get_tree().create_timer(1.0).timeout
	self.set_collision_layer_value(3,false)
	
	if not is_inside_tree() or get_tree() == null: return
	await get_tree().create_timer(15.0).timeout
	queue_free()


func _on_timer_timeout() -> void:
	if !dead:
		if !growl_timed.playing: growl_timed.play()


func _on_attack_body_entered(body: Node3D) -> void:
	if (body == player or body.is_in_group("player")) and !dead:
		_acertar_player(body)

func _acertar_player(body: Node3D) -> void:
	if dead or not is_inside_tree() or not is_instance_valid(body):
		return
	var agora = Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_hit_melee < 0.6:
		return
	_ultimo_hit_melee = agora
	
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
	
	# 5. Na cidade o toque não é uma pancada comum: leva metade do sangue e
	# arrasta o jogador para a arena (ver _tenta_batalha_forcada).
	if _tenta_batalha_forcada(body):
		return
	
	# Lança dano no player
	body.take_damage(attack_damage)


## Toque no Maycow normal enquanto ele anda pela cidade: em vez do dano de
## sempre, ele perde metade do sangue que ainda tem e a batalha na arena começa
## à força, sem passar pela mira do amuleto. Quem cuida da sequência (dano em
## câmera lenta e depois a viagem) é o player_amulet.gd.
##
## Vale SÓ na stage_1 e depois do prólogo: no prólogo e nos interiores o
## encontro tem de continuar sendo um encostão comum, e o Maycow de combate
## (dentro da própria arena) nunca entra aqui.
##
## true = o toque foi consumido; quem chamou não aplica mais dano nenhum.
func _tenta_batalha_forcada(body: Node3D) -> bool:
	if not GlobalEvents.is_maycow_normal:
		return false
	if not SaveManager.prolog_finished:
		return false
	if not body.has_method("force_battle_from_touch"):
		return false
	var cena := get_tree().current_scene
	if cena == null or not cena.scene_file_path.contains("stage_1"):
		return false

	# Sequência já em andamento (outro inimigo encostou primeiro, ou este mesmo
	# no frame anterior): o toque não faz nada. Deixar cair no dano normal seria
	# tirar vida por cima da cinemática — e poderia matar o jogador no meio dela.
	if GlobalEvents.forced_battle_running:
		return true

	return body.force_battle_from_touch(self)

func _exec_fireball_attack() -> void:
	is_attacking = true
	_travel("attack_2")
	_throw_fireball()

func _exec_ranged_attack() -> void:
	is_attacking = true
	_travel("attack_2")
	_throw_random_projectile()

## Poder de defesa: a mesma animacao "attack", mas o que sai dela e a esfera.
func _exec_defense_attack() -> void:
	is_attacking = true
	_travel("attack")
	_levanta_escudo()

func _levanta_escudo() -> void:
	if not is_inside_tree() or get_tree() == null:
		is_attacking = false
		return
	# Espera o inimigo abrir os bracos na animacao antes da esfera aparecer.
	await get_tree().create_timer(0.8).timeout
	if dead or not is_inside_tree():
		is_attacking = false
		return

	var shield_script = load("res://scripts/effects/defense_shield.gd")
	if shield_script:
		var shield = shield_script.new()
		shield.duration = defense_shield_duration
		add_child(shield)
		shield.position = Vector3(0, 1.1, 0)
		_shield_node = shield
		shield_active = true
		# A esfera se apaga sozinha no fim da duracao; e ela quem avisa.
		shield.expired.connect(_on_escudo_expirado)

	await get_tree().create_timer(0.8).timeout
	is_attacking = false

func _on_escudo_expirado() -> void:
	shield_active = false
	_shield_node = null

## Tira a esfera na hora (morte do inimigo).
func _derruba_escudo() -> void:
	shield_active = false
	if is_instance_valid(_shield_node):
		if _shield_node.has_method("encerrar"):
			_shield_node.encerrar()
		else:
			_shield_node.queue_free()
	_shield_node = null

func _exec_melee_attack() -> void:
	is_attacking = true
	if shoots_fireball:
		_travel("attack_2")
		ranged_attack_timer = 10.0
	else:
		_travel("attack")
	_verificar_impacto_melee()
	_finish_melee_attack()

func _verificar_impacto_melee() -> void:
	if not is_inside_tree() or get_tree() == null: return
	# No meio do golpe (0.35s), se o jogador estiver encostado/na área, conecta o dano
	await get_tree().create_timer(0.35).timeout
	if dead or not is_inside_tree() or not is_instance_valid(player): return
	var area = get_node_or_null("attack") as Area3D
	if area and area.has_overlapping_body(player):
		_acertar_player(player)

func _finish_melee_attack() -> void:
	if not is_inside_tree() or get_tree() == null: return
	await get_tree().create_timer(1.2).timeout
	is_attacking = false

func _throw_random_projectile() -> void:
	if not projectile_source or projectile_source.get_child_count() == 0:
		is_attacking = false
		return
		
	# Espera o inimigo bater os braços no chão (aproximadamente 2.2 segundos depois do início da animação)
	if not is_inside_tree() or get_tree() == null:
		is_attacking = false
		return
	await get_tree().create_timer(2.2).timeout
	
	if dead or not player:
		is_attacking = false
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
	
	if not is_inside_tree() or get_tree() == null or get_tree().current_scene == null: return
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
		if body == player and is_instance_valid(projectile):
			player.take_damage(attack_damage)
			# Tremor de câmera
			GlobalUtils.shake_camera(0.2, 0.2)
			_shatter_projectile(projectile)
	)
	
	# Destrói automaticamente se não bater no player (depois de dar o tempo do tween + folga)
	if not is_inside_tree() or get_tree() == null:
		is_attacking = false
		return
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(projectile):
			_shatter_projectile(projectile)
	)
	
	await get_tree().create_timer(0.8).timeout
	is_attacking = false

func _shatter_projectile(projectile: Node3D) -> void:
	if not is_instance_valid(projectile) or not is_inside_tree() or get_tree() == null:
		return
		
	var impact_pos = projectile.global_position
	# Hide original mesh (if any)
	for child in projectile.get_children():
		if child is MeshInstance3D:
			child.visible = false

	# Explosion particles (dust)
	var particles = CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = 80
	particles.lifetime = 40.0
	particles.explosiveness = 0.9
	particles.gravity = Vector3(0, -9.8, 0)
	# Simple white texture could be set later;	if not is_inside_tree() or get_tree() == null or get_tree().current_scene == null: return
	get_tree().current_scene.add_child(particles)
	particles.global_position = impact_pos
	particles.emitting = true
	# Keep particles visible for ~35 seconds before cleanup
	get_tree().create_timer(35.0).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free())

	# Fragment shatter
	var fragments = 30
	for i in range(fragments):
		var fragment = RigidBody3D.new()
		# Random size
		var size = randf_range(0.05, 0.12)
		var box = BoxMesh.new()
		box.size = Vector3(size, size, size)
		# Material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.38, 0.3)
		mat.roughness = 0.9
		box.material = mat
		# MeshInstance
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = box
		fragment.add_child(mesh_inst)
		# Collision shape
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(size, size, size)
		col.shape = shape
		fragment.add_child(col)
		# Position
		fragment.global_position = impact_pos
		# Random impulse
		var dir = Vector3(randf_range(-1,1), randf_range(0.5,1.5), randf_range(-1,1)).normalized()
		var strength = randf_range(2.5, 6.0)
		fragment.apply_impulse(Vector3.ZERO, dir * strength)
		# Add to scene
		if not is_inside_tree() or get_tree() == null or get_tree().current_scene == null: return
		get_tree().current_scene.add_child(fragment)
		# Auto‑remove after short time
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_instance_valid(fragment):
				fragment.queue_free())

	# Clean up original projectile after short delay to allow particles to play
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_instance_valid(projectile):
			projectile.queue_free())

func _throw_fireball() -> void:
	# Sincroniza com o momento de arremesso da animação (2.2s)
	if not is_inside_tree() or get_tree() == null:
		is_attacking = false
		return
	await get_tree().create_timer(2.2).timeout
	
	if dead or not is_instance_valid(player):
		is_attacking = false
		return
		
	# Instancia o novo script cheio de efeitos avançados
	var fireball_script = load("res://scripts/effects/fireball_projectile.gd")
	if fireball_script:
		var projectile = fireball_script.new()
		projectile.target_player = player
		if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
			get_tree().current_scene.add_child(projectile)
			# Posição Inicial: Bem acima, para vir de cima para baixo
			var forward_dir = global_transform.basis.z.normalized()
			projectile.global_position = global_position + Vector3(0, 2.8, 0) + (forward_dir * 1.0)

	await get_tree().create_timer(0.8).timeout
	is_attacking = false
