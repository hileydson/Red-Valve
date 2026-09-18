extends Node

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func process_combat(delta: float) -> void:
	# GIRO DA COGBLADE (só durante o arremesso normal, não durante a cinemática do ultimate)
	if is_instance_valid(player.crescent_cogblade) and player.crescent_cogblade.top_level and not player.is_using_ultimate and not player.cogblade_melee_active:
		player.crescent_cogblade.global_rotate(Vector3.UP, -15.0 * delta)

	# LÓGICA DO BUMERANGUE (COGBLADE RETORNANDO)
	if player.is_blade_returning and is_instance_valid(player.crescent_cogblade):
		var target_pos = player.camera.global_transform.origin + player.camera.global_transform.basis * player.magic_blade_pos_original
		player.crescent_cogblade.global_transform.origin = player.crescent_cogblade.global_transform.origin.move_toward(target_pos, delta * player.blade_return_speed)
		
		if player.crescent_cogblade.global_transform.origin.distance_to(target_pos) < 0.8:
			player.is_blade_returning = false
			player.crescent_cogblade.top_level = false
			player.crescent_cogblade.position = player.magic_blade_pos_original
			player.crescent_cogblade.rotation = Vector3.ZERO
			player.crescent_cogblade.hide()
			
			var bb = player.crescent_cogblade.get_node_or_null("blade_back")
			if bb: bb.play()
			
			var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas")
			if faiscas: faiscas.emitting = false
			
			player.is_magic_attacking = false
			# Aqui havia um `travel("idle")`, mas "idle" NAO existe nesta arvore
			# (ela so tem magic_holding_gun, magic_holding_shoot, magic_reload e
			# magic_thrown). O travel falhava e ainda deixava a AnimationTree
			# reclamando todo quadro pra sempre. A mao ja' fica na pose certa sem
			# trocar de estado nenhum aqui — que e' como sempre se comportou na
			# pratica, ja' que o travel nunca funcionou.

			var tween_hand = create_tween()
			tween_hand.tween_interval(0.2)
			tween_hand.tween_property(player.hand_magic_3d, "position", player.hand_magic_3d_pos_hidden, 1.5).set_trans(Tween.TRANS_SINE)

func reload() -> void:
	# A CAÇADEIRA É OUTRO CAMINHO, EM QUALQUER PESSOA.
	#
	# Ela não tem pente: abre, despeja as duas cápsulas e recebe um cartucho
	# por vez. O gesto, os sons e a contagem são os mesmos do Maycow normal —
	# muda só quem segura a arma, e disso cuida o `player._shotgun_hold()`.
	if SaveManager.is_equipped("shotgun"):
		recarregar_shotgun()
		return
	if player.is_first_person and not player.is_reloading and not player.is_magic_attacking:
		var total = SaveManager.get_item_amount("pistol_ammo")
		if total <= 0 or player.clip_pistol_ammo >= player.max_clip_pistol:
			return
			
		player.is_reloading = true
		
		var needed = player.max_clip_pistol - player.clip_pistol_ammo
		var taken = mini(needed, total)
		SaveManager.remove_item_amount("pistol_ammo", taken)
		player.clip_pistol_ammo += taken
		player.update_ammo_ui()
		
		if not is_instance_valid(player.current_weapon): 
			player.is_reloading = false
			return

		player.gun_load.play()
		
		if is_instance_valid(player.hand_magic_3d): 
			player.hand_magic_3d.position = player.hand_magic_3d_pos_original
			player.hand_magic_3d.visible = true
			
		GlobalUtils.safe_travel(player.hand_magic_tree, "magic_reload")
		
		if player.hand_animations:
			player.hand_animations.play("reload")
			await player.hand_animations.animation_finished
		else:
			await get_tree().create_timer(1.0).timeout
			
		await get_tree().create_timer(0.2).timeout
			
		if is_instance_valid(player.hand_magic_3d): 
			var tween_retorno = create_tween()
			tween_retorno.tween_property(player.hand_magic_3d, "position", player.hand_magic_3d_pos_hidden, 0.6).set_trans(Tween.TRANS_SINE)
			
		player.is_reloading = false

func _resolve_enemy_target(node: Node) -> Node3D:
	if not is_instance_valid(node):
		return null
	if node is Area3D and is_instance_valid(node.get_parent()) and node.get_parent() is CharacterBody3D:
		return node.get_parent() as Node3D
	if "dead" in node or node.has_method("take_damage"):
		if node is Node3D:
			return node as Node3D
	for child in node.get_children():
		if "dead" in child or child.has_method("take_damage"):
			if child is Node3D:
				return child as Node3D
	return node as Node3D if node is Node3D else null


func _get_nearest_enemy() -> Node3D:
	if not is_inside_tree() or get_tree() == null:
		return null

	var origin: Vector3 = player.global_position
	var nearest_enemy: Node3D = null
	var nearest_dist_sq: float = INF
	var seen: Dictionary = {}

	var candidate_nodes: Array = get_tree().get_nodes_in_group("enemies")
	if candidate_nodes.is_empty():
		var scene_enemies = get_tree().current_scene.find_child("enemies", true, false)
		if scene_enemies:
			for child in scene_enemies.get_children():
				if child is Node3D:
					candidate_nodes.append(child)

	for node in candidate_nodes:
		if not is_instance_valid(node):
			continue
		var enemy: Node3D = _resolve_enemy_target(node)
		if not is_instance_valid(enemy) or enemy in seen:
			continue
		seen[enemy] = true

		if enemy == player or enemy.is_in_group("player"):
			continue
		if not enemy.is_inside_tree() or not enemy.can_process():
			continue
		if not enemy.is_visible_in_tree():
			continue
		if "dead" in enemy and bool(enemy.dead):
			continue
		if "current_health" in enemy and float(enemy.current_health) <= 0.0:
			continue
		if "health" in enemy and float(enemy.health) <= 0.0:
			continue

		var d_sq: float = origin.distance_squared_to(enemy.global_position)
		if d_sq < nearest_dist_sq:
			nearest_dist_sq = d_sq
			nearest_enemy = enemy

	return nearest_enemy


func magic_hand_attack() -> void:
	# A cogblade pertence só ao Maycow parasita.
	if GlobalEvents.is_maycow_normal: return
	SaveManager.current_mp -= 10.0
	if SaveManager.current_mp < 0: SaveManager.current_mp = 0
	if player.is_reloading: return
	
	player.is_magic_attacking = true
	player.slay_it.play()
	player.blade_out.play()
	
	# Aqui havia um `travel("attack")` — estado que NAO existe nesta arvore. Como
	# acima, o travel nunca funcionou (so' corrompia a AnimationTree), entao a
	# animacao do golpe sempre veio do tween/`hand_animations` abaixo. Nao trocar
	# de estado mantem a mao exatamente como sempre foi.

	var tween_magic = create_tween().set_parallel(true)
	
	var pos_alvo = player.hand_magic_3d_pos_original + Vector3(0, 0, 0.1)
	player.hand_magic_3d.visible = true
	tween_magic.tween_property(player.hand_magic_3d, "position", pos_alvo, 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	player.crescent_cogblade.show()
	player.crescent_cogblade.top_level = true
	
	var faiscas = player.crescent_cogblade.get_node_or_null("Faiscas") 
	if faiscas: faiscas.emitting = true
	
	var nearest_enemy: Node3D = _get_nearest_enemy()
	var start_pos: Vector3 = player.crescent_cogblade.global_transform.origin
	var dir: Vector3
	var travel_dist: float = 11.0
	var pos_final_global: Vector3
	
	if nearest_enemy:
		var to_enemy_h: Vector3 = Vector3(nearest_enemy.global_position.x - start_pos.x, 0.0, nearest_enemy.global_position.z - start_pos.z)
		var dist: float = to_enemy_h.length()
		dir = to_enemy_h.normalized() if dist > 0.001 else -player.camera.global_transform.basis.z
		dir.y = 0.0
		dir = dir.normalized()
		travel_dist = clampf(dist + 2.0, 5.0, 30.0)
		pos_final_global = start_pos + (dir * travel_dist)
		pos_final_global.y = start_pos.y - 0.05
	else:
		dir = -player.camera.global_transform.basis.z
		dir.y = 0.0
		dir = dir.normalized() if dir.length_squared() > 0.001 else -player.camera.global_transform.basis.z
		pos_final_global = start_pos + (dir * travel_dist)
		pos_final_global.y = start_pos.y - 0.05
	
	var yaw_deg: float = rad_to_deg(atan2(-dir.x, -dir.z)) if (absf(dir.x) > 0.001 or absf(dir.z) > 0.001) else player.camera.global_rotation_degrees.y
	player.crescent_cogblade.global_rotation_degrees = Vector3(player.cogblade_tilt_x, yaw_deg + player.cogblade_tilt_y, player.cogblade_tilt_z)
	
	var travel_time: float = clampf((travel_dist / 11.0) * 1.2, 0.5, 2.0)
	tween_magic.tween_property(player.crescent_cogblade, "global_transform:origin", pos_final_global, travel_time)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	await tween_magic.finished
	
	player.is_blade_returning = true
	
	var tween_hand = create_tween()
	var pos_recuo = player.hand_magic_3d_pos_original + Vector3(0.0, -0.4, 0.6)
	tween_hand.tween_property(player.hand_magic_3d, "position", pos_recuo, 0.5)\
		.set_trans(Tween.TRANS_QUAD)

func cast_spell() -> void:
	player.magic_hand_particles.emitting = true
	player.blade_light.visible = true
	
	var tween = create_tween()
	player.magic_hand_particles.amount = 50
	
	tween.tween_property(player.magic_hand_particles.process_material, "scale_min", 2.0, 0.5)
	await get_tree().create_timer(3.0).timeout
	player.magic_hand_particles.emitting = false
	player.blade_light.visible = false

func shoot(input: Variant) -> void:
	# Mesma bifurcação da `reload()`: com a caçadeira equipada o tiro é
	# chumbo, e o caminho dele já existe (é o do Maycow normal).
	if SaveManager.is_equipped("shotgun"):
		atirar_shotgun()
		return
	if not SaveManager.is_equipped("pistol"): return
	if player.is_reloading: return
	if player.is_using_ultimate or player.cogblade_melee_active: return
	
	if player.can_shoot_again and player.camera.current:
		if player.clip_pistol_ammo <= 0:
			return
			
		player.clip_pistol_ammo -= 1
		player.update_ammo_ui()
		
		if not is_instance_valid(player.current_weapon): return

		player.current_weapon = player.hand_with_pistol
		var rotation_default = player.current_weapon.rotation
		# O coice nos dedos e na arma. O resto deste bloco continua sendo o
		# tranco do NÓ inteiro, que é o que sacode a tela.
		var maos_fp = player._maos_fp()
		if maos_fp and maos_fp.has_method("atirar"):
			maos_fp.atirar()

		var tween = create_tween()
		player.fire.play("shoot")
		GlobalUtils.shake_camera(0.03, 0.05)
		GlobalUtils.vibrate_controller(input, 0.5, 0.0, 0.1)
		player.faisca.restart()
		player.faisca.emitting = true
		player.gun_shot.play()
		player.can_shoot_again = false
		
		if player.capsula_scene:
			var capsula = player.capsula_scene.instantiate()
			get_tree().current_scene.add_child(capsula)
			capsula.add_collision_exception_with(player)
			var spawn_pos = player.camera.global_position + player.camera.global_transform.basis * Vector3(0.4, -0.1, -0.75)
			capsula.global_position = spawn_pos
			capsula.global_rotation = player.camera.global_rotation
			
			var eject_dir = player.camera.global_transform.basis * Vector3(1.0, 1.0, 0.0) 
			capsula.apply_central_impulse(eject_dir * randf_range(1.5, 2.0))
			capsula.apply_torque(Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))
		
		var flash_tween = create_tween()
		player.flash_tela.color.a = 0.1 
		flash_tween.tween_property(player.flash_tela, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		
		tween.parallel().tween_property(player.current_weapon, "position:x", player.current_weapon.position.x + 0.01, 0.05).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(player.current_weapon, "position:y", player.current_weapon.position.y - 0.01, 0.05).set_trans(Tween.TRANS_SINE)

		tween.tween_interval(0.1)

		player.current_weapon.rotation = rotation_default
		tween.parallel().tween_property(player.current_weapon, "position:x", player.current_weapon.position.x, 0.1).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(player.current_weapon, "position:y", player.current_weapon.position.y, 0.1).set_trans(Tween.TRANS_BACK)
		
		raycast_process_shoot()		
				
		await get_tree().create_timer(0.56).timeout
		player.can_shoot_again = true

# =========================================================================
# TIRO EM TERCEIRA PESSOA (MAYCOW NORMAL)
# =========================================================================
# O `shoot()` acima é da primeira pessoa e depende dela inteira: a mão 3D na
# câmera, o sprite 2D da pistola, o `ray_cast_3d` filho da `Camera3D` e o bullet
# time do tiro no coração. Nada disso existe no Maycow normal, que segura a arma
# na mão de verdade (ver `player_gun_hold.gd`) e mira por cima do ombro.
#
# Então é um caminho próprio, e curto: gasta bala, clarão na boca do cano, som,
# tranco na câmera, cápsula no chão, raio no centro da tela.

## Cadência. Um pouco mais lenta que a da primeira pessoa: aqui ele está de pé
## no meio da rua, sem o embalo do combate da arena.
const TEMPO_ENTRE_TIROS := 0.62

## Quanto tempo o clarão da boca do cano fica aceso.
const TEMPO_CLARAO := 0.06

## Recarga em terceira pessoa. O gesto é do `player_gun_hold.gd` (a arma recolhe
## pro peito, a mão esquerda desce ao cinto, busca o pente e encaixa), e este é
## o tempo que ele tem pra acontecer.
const TEMPO_RECARGA_3P := 1.5
## Em que ponto do gesto o pente entra — é onde o som de encaixe toca.
const RECARGA_MOMENTO_ENCAIXE := 0.72

## Até onde a bala vai, em metros. É irmão do `ALCANCE_MIRA_ARMA` do player.gd,
## mas não é o mesmo número por acaso: lá é a distância em que o BRAÇO aponta,
## aqui é o alcance do tiro. Um pode mudar sem o outro.
const ALCANCE_TIRO_3P := 90.0

var _clarao: OmniLight3D = null
var _recarregando_3p: bool = false


func atirar_terceira_pessoa() -> void:
	if not SaveManager.is_equipped("pistol"): return
	if not player.can_shoot_again or player.is_reloading: return
	if player.clip_pistol_ammo <= 0:
		# Pente vazio: quem avisa é o próprio silêncio mais o contador zerado no
		# canto da tela. Recarregar é do jogador.
		return

	var gun_hold = player._gun_hold()

	player.clip_pistol_ammo -= 1
	player.update_ammo_ui()
	player.can_shoot_again = false

	player.gun_shot.play()
	GlobalUtils.shake_camera(0.05, 0.08)
	GlobalUtils.vibrate_controller(Input, 0.5, 0.0, 0.1)

	if gun_hold and gun_hold.tem_arma_na_mao():
		_piscar_clarao(gun_hold.boca_do_cano())
		_soltar_capsula(gun_hold.boca_do_cano())

	_raio_do_tiro_3p()

	await get_tree().create_timer(TEMPO_ENTRE_TIROS).timeout
	player.can_shoot_again = true


## Recarga do Maycow normal.
##
## A `reload()` acima exige `is_first_person` e toca a animação da mão em frente
## à câmera — coisas que aqui não existem. O efeito no inventário é o mesmo: o
## que falta no pente sai da caixa de balas, e a caixa é a mesma dos dois Maycows
## (SaveManager.ITENS_COMPARTILHADOS).
func recarregar_terceira_pessoa() -> void:
	if _recarregando_3p or player.is_reloading: return
	if not SaveManager.is_equipped("pistol"): return

	var total = SaveManager.get_item_amount("pistol_ammo")
	if total <= 0 or player.clip_pistol_ammo >= player.max_clip_pistol:
		return

	_recarregando_3p = true
	player.is_reloading = true

	# O gesto. Roda mesmo sem estar mirando: quem recarrega levanta a arma pra
	# fazer isso, de mira aberta ou não.
	var gun_hold = player._gun_hold()
	if gun_hold:
		gun_hold.recarregar(TEMPO_RECARGA_3P)

	player.load_gun.play()   # o pente saindo
	await get_tree().create_timer(TEMPO_RECARGA_3P * RECARGA_MOMENTO_ENCAIXE).timeout
	player.gun_load.play()   # o pente entrando, no quadro em que a mão encaixa
	await get_tree().create_timer(
		TEMPO_RECARGA_3P * (1.0 - RECARGA_MOMENTO_ENCAIXE)).timeout

	# O pente só enche no FIM: interromper a cena no meio (morte, cutscene) não
	# pode devolver balas que a animação ainda não tinha terminado de pôr.
	var faltam = player.max_clip_pistol - player.clip_pistol_ammo
	var tiradas = mini(faltam, SaveManager.get_item_amount("pistol_ammo"))
	if tiradas > 0:
		SaveManager.remove_item_amount("pistol_ammo", tiradas)
		player.clip_pistol_ammo += tiradas
		player.update_ammo_ui()

	player.is_reloading = false
	_recarregando_3p = false


# =========================================================================
# A CAÇADEIRA (MAYCOW NORMAL)
# =========================================================================
# Irmã do bloco de cima, e separada dele pelas duas coisas que não dão para
# resolver com um `if`: o tiro é um punhado de chumbo em vez de uma bala, e a
# recarga é um gesto com peças móveis — a arma DOBRA, despeja as cápsulas e é
# alimentada um cartucho por vez.
#
# O gesto em si é do `player_shotgun_hold.gd`. Daqui saem os sons, as cápsulas
# e o efeito no inventário, e os MOMENTO_* abaixo são cópias das constantes
# M_* de lá. Eles TÊM de bater: som de encaixe fora do quadro em que a mão
# encaixa é o que mais denuncia uma animação falsa.

## Cadência. Mais lenta que a da pistola: é uma arma pesada, e com dois tiros
## no total o ritmo dela é "escolhe a hora", não "despeja".
const TEMPO_ENTRE_TIROS_SHOTGUN := 0.85

## O gesto inteiro de recarga. Longo de propósito — abrir, virar, pôr dois
## cartuchos na mão e fechar não cabe em um segundo e meio, e encurtar isso
## transformaria a única fraqueza da arma em nada.
##
## Eram 2,8 s, e o problema não era o total: era que os dois cartuchos entravam
## com meio segundo de intervalo, e meio segundo não lê como "um, depois o
## outro" — lê como um borrão só. Agora a mão VOLTA ao cinto no meio, e entre
## um encaixe e o outro passam 0,86 s.
const TEMPO_RECARGA_SHOTGUN := 3.6

## Os momentos do gesto, em fração dele. Espelham os M_* do
## `player_shotgun_hold.gd` — mexeu lá, muda aqui.
const MOMENTO_ABRE := 0.08
const MOMENTO_EJETA := 0.31
const MOMENTO_BALA1 := 0.60
const MOMENTO_BALA2 := 0.84
const MOMENTO_FECHA := 0.90

## Quantos chumbos saem por tiro, e quanto a carga se abre (graus de meio-ângulo
## do cone). 2,5 graus dá ~9 cm de espalhamento a 2 m e ~90 cm a 20 m: mata de
## perto e só arranha de longe, que é o contrato de uma caçadeira.
## O clarão da caçadeira dura o dobro do da pistola. Ainda é quase nada — dois
## quadros — mas a diferença aparece, e é ela que separa os dois tiros.
const TEMPO_CLARAO_SHOTGUN := 0.12
## O fogo, as fagulhas e a fumaça. Montados em `fogo_shotgun.gd`.
const FOGO_SHOTGUN := preload("res://scenes/effects/fogo_shotgun.tscn")

const PELOTAS_SHOTGUN := 7
const ESPALHAMENTO_SHOTGUN := 2.5

var _recarregando_shotgun: bool = false


func atirar_shotgun() -> void:
	if not SaveManager.is_equipped("shotgun"): return
	if not player.can_shoot_again or player.is_reloading: return
	if player.clip_shotgun_ammo <= 0:
		# Os dois canos vazios: quem avisa é o silêncio mais o contador zerado.
		# Recarregar é do jogador — e aqui ele NÃO tem escolha, porque a arma
		# só aceita recarga com os dois vazios.
		return

	var gun_hold = player._shotgun_hold()

	player.clip_shotgun_ammo -= 1
	player.update_ammo_ui()
	player.can_shoot_again = false

	player.shotgun_shot.play()
	# Tranco maior que o da pistola nos dois canais. É o coice: numa arma de
	# dois tiros ele é parte do que faz cada tiro pesar.
	GlobalUtils.shake_camera(0.11, 0.16)
	GlobalUtils.vibrate_controller(Input, 0.9, 0.35, 0.18)

	if gun_hold and gun_hold.tem_arma_na_mao():
		# Mais forte e mais longo que o da pistola: são 12 gramas de chumbo
		# saindo de uma vez, e o tiro da caçadeira tem de PESAR na tela.
		_piscar_clarao(gun_hold.boca_do_cano(), 11.0, 6.0, TEMPO_CLARAO_SHOTGUN)
		_fumaca_do_cano(gun_hold)
		# O coice na MÃO só existe em primeira pessoa: lá a arma é um clipe de
		# animação e tem quadro de recuo. Em terceira pessoa o coice é o tranco
		# da câmera, e o componente nem tem esse método.
		if gun_hold.has_method("atirar"):
			gun_hold.atirar()

	_raio_do_tiro_shotgun()

	await get_tree().create_timer(TEMPO_ENTRE_TIROS_SHOTGUN).timeout
	player.can_shoot_again = true


## Recarga da caçadeira.
##
## SÓ com os dois canos vazios, e isso é regra da arma, não economia de código:
## uma break-action não tem como repor um cano só sem abrir e despejar o outro,
## e é essa espera obrigatória que equilibra dois tiros que derrubam qualquer
## coisa. Apertar recarregar com um tiro na agulha não faz nada.
func recarregar_shotgun() -> void:
	if _recarregando_shotgun or player.is_reloading: return
	if not SaveManager.is_equipped("shotgun"): return
	if player.clip_shotgun_ammo > 0: return
	if SaveManager.get_item_amount("shotgun_ammo") <= 0: return

	_recarregando_shotgun = true
	player.is_reloading = true

	var gun_hold = player._shotgun_hold()
	if gun_hold:
		gun_hold.recarregar(TEMPO_RECARGA_SHOTGUN)

	# O gesto é contado do começo, e não somando esperas: assim atrasar um
	# momento não empurra todos os seguintes junto.
	var decorrido := 0.0

	# ATENÇÃO AO NOME DOS ARQUIVOS: o `ShotgunBreak` toca o
	# `shotgun_final_reload_sound.mp3` e o `ShotgunClose` toca o
	# `shotgun_reload.mp3` — trocados em relação ao que o nome do arquivo
	# sugere, e de propósito: ouvindo em jogo é esse o par que encaixa (o que
	# "abre" tem o estalo da trava, o que "fecha" tem o baque). Se alguém
	# reimportar os áudios e "consertar" os nomes, o reload volta a soar ao
	# contrário.
	decorrido = await _esperar_ate(MOMENTO_ABRE, decorrido)
	player.shotgun_break.play()

	decorrido = await _esperar_ate(MOMENTO_EJETA, decorrido)
	_soltar_capsulas_shotgun(gun_hold)

	for momento in [MOMENTO_BALA1, MOMENTO_BALA2]:
		decorrido = await _esperar_ate(momento, decorrido)
		# Cada cartucho entra NO QUADRO em que a mão encaixa, e não todos no
		# fim: aqui a mão vai buscar um por vez, e o contador subindo de um em
		# um é o que faz o gesto e o HUD contarem a mesma história.
		if SaveManager.get_item_amount("shotgun_ammo") <= 0:
			continue
		if player.clip_shotgun_ammo >= player.max_clip_shotgun:
			continue
		SaveManager.remove_item_amount("shotgun_ammo", 1)
		player.clip_shotgun_ammo += 1
		player.update_ammo_ui()
		player.shotgun_load_shell.play()

	decorrido = await _esperar_ate(MOMENTO_FECHA, decorrido)
	player.shotgun_close.play()

	await _esperar_ate(1.0, decorrido)
	player.is_reloading = false
	_recarregando_shotgun = false


## Espera até o instante `fracao` do gesto, sabendo que já se passou
## `decorrido`. Devolve o novo `decorrido` para a próxima chamada.
func _esperar_ate(fracao: float, decorrido: float) -> float:
	var falta := (fracao - decorrido) * TEMPO_RECARGA_SHOTGUN
	if falta > 0.0:
		await get_tree().create_timer(falta).timeout
	return fracao


## As duas cápsulas caindo da culatra quando a arma vira.
##
## Saem das BOCAS DAS CÂMARAS de verdade — o componente da arma sabe onde elas
## estão neste quadro, inclusive já giradas pela dobra. Por isso o cálculo mora
## lá e não aqui: aqui não há como saber o quanto a arma está aberta.
##
## E caem, não voam: o extrator de uma break-action empurra o cartucho um dedo
## para fora e a gravidade faz o resto. Um impulso de pistola aqui mandaria as
## duas para longe, que é justamente o que não acontece.
func _soltar_capsulas_shotgun(gun_hold) -> void:
	if not player.capsula_shotgun_scene or not is_inside_tree(): return
	if gun_hold == null or not gun_hold.tem_arma_na_mao(): return

	var direcao_saida: Vector3 = gun_hold.direcao_do_cano()
	for ponto in gun_hold.bocas_das_camaras():
		var capsula = player.capsula_shotgun_scene.instantiate()
		get_tree().current_scene.add_child(capsula)
		capsula.add_collision_exception_with(player)
		capsula.global_position = ponto
		capsula.look_at_from_position(ponto, ponto + direcao_saida, Vector3.UP)
		# Para TRÁS do cano (é por onde o cartucho sai) e um empurrãozinho.
		capsula.apply_central_impulse(-direcao_saida * randf_range(0.25, 0.45)
			+ Vector3.UP * randf_range(0.05, 0.15))
		capsula.apply_torque(Vector3(randf_range(-2, 2), randf_range(-2, 2),
			randf_range(-2, 2)))


## O punhado de chumbo.
##
## Um raio por chumbo, todos saindo do MESMO ponto da câmera (pelo motivo do
## `_raio_do_tiro_3p`: é o centro da tela que o jogador usou para mirar) e cada
## um desviado dentro de um cone. Um raio só com dano triplicado seria mais
## barato e mentiria: a graça da arma é acertar metade da carga a meia
## distância, e isso só existe se os chumbos forem contados separados.
func _raio_do_tiro_shotgun() -> void:
	var cam = player.get_viewport().get_camera_3d()
	if cam == null: return

	var origem: Vector3 = cam.global_position
	var frente: Vector3 = -cam.global_transform.basis.z
	var direita: Vector3 = cam.global_transform.basis.x
	var cima: Vector3 = cam.global_transform.basis.y
	var espaco := player.get_world_3d().direct_space_state
	var abertura := deg_to_rad(ESPALHAMENTO_SHOTGUN)

	# Um alvo levar sete vezes o efeito colateral de um tiro (sangue, pulo do
	# inimigo) por um disparo só ficaria exagerado; o dano soma, o resto não.
	var ja_sangrou: Array = []

	for i in PELOTAS_SHOTGUN:
		# Ponto aleatório DENTRO do disco, e não na borda: sqrt() é o que
		# espalha parejo por área em vez de amontoar tudo na circunferência.
		var angulo := randf() * TAU
		var raio := sqrt(randf()) * abertura
		var desvio := (direita * cos(angulo) + cima * sin(angulo)) * tan(raio)
		var dir := (frente + desvio).normalized()

		var consulta := PhysicsRayQueryParameters3D.create(origem,
			origem + dir * ALCANCE_TIRO_3P)
		consulta.collision_mask = 12
		consulta.collide_with_areas = true
		consulta.exclude = [player.get_rid()]

		var toque := espaco.intersect_ray(consulta)
		if toque.is_empty(): continue

		var alvo = toque.get("collider")
		if alvo == null or not alvo.has_method("take_damage"): continue

		alvo.take_damage(player.damage_shotgun_pelota)
		if alvo.is_in_group("enemies") and not alvo in ja_sangrou:
			ja_sangrou.append(alvo)
			spawn_blood_raycast(toque["position"], toque["normal"])


## O raio sai da CÂMERA, não do cano: é o centro da tela que o jogador usou para
## mirar. O cano aponta para o mesmo ponto (o braço inteiro aponta para ele), só
## que de um palmo ao lado — usar o cano como origem faria o tiro passar raspando
## em quinas que na tela estavam livres.
func _raio_do_tiro_3p() -> void:
	var cam = player.get_viewport().get_camera_3d()
	if cam == null: return

	var origem: Vector3 = cam.global_position
	var frente: Vector3 = -cam.global_transform.basis.z
	var consulta := PhysicsRayQueryParameters3D.create(origem,
		origem + frente * ALCANCE_TIRO_3P)
	consulta.collision_mask = 12
	consulta.collide_with_areas = true
	consulta.exclude = [player.get_rid()]

	var toque := player.get_world_3d().direct_space_state.intersect_ray(consulta)
	if toque.is_empty(): return

	var alvo = toque.get("collider")
	if alvo == null or not alvo.has_method("take_damage"): return

	alvo.take_damage(player.damage_pistol)
	if alvo.is_in_group("enemies"):
		spawn_blood_raycast(toque["position"], toque["normal"])


## Clarão curto na boca do cano. É uma luz só, com alcance pequeno e vida de
## três quadros: o renderer do projeto é o mobile, que tem teto de 8 luzes por
## malha, e uma luz grande aqui apagaria outra do cenário sem avisar.
##
## Os parâmetros existem pela caçadeira, que acende mais e por mais tempo que a
## pistola. Os valores padrão são os da pistola, que assim não mudou em nada.
func _piscar_clarao(ponto: Vector3, energia: float = 6.0, alcance: float = 4.0,
		duracao: float = TEMPO_CLARAO) -> void:
	if not is_instance_valid(_clarao):
		_clarao = OmniLight3D.new()
		_clarao.light_color = Color(1.0, 0.82, 0.45)
		_clarao.shadow_enabled = false
		_clarao.visible = false
		_clarao.top_level = true
		player.add_child(_clarao)

	_clarao.light_energy = energia
	_clarao.omni_range = alcance
	_clarao.global_position = ponto
	_clarao.visible = true
	await get_tree().create_timer(duracao).timeout
	if is_instance_valid(_clarao):
		_clarao.visible = false


## Solta o clarão/fumaça na boca do cano da caçadeira.
##
## O efeito NÃO é filho da arma: ele nasce na cena e a acompanha só enquanto o
## cano ainda cospe (ver o cabeçalho do `fogo_shotgun.gd`). Pendurar na arma
## faria a nuvem inteira girar junto com a câmera.
func _fumaca_do_cano(gun_hold) -> void:
	if not is_inside_tree(): return
	var onde := get_tree().current_scene
	if onde == null: return
	var fx = FOGO_SHOTGUN.instantiate()
	fx.arma = gun_hold
	onde.add_child(fx)
	fx.global_position = gun_hold.boca_do_cano()


func _soltar_capsula(ponto: Vector3) -> void:
	if not player.capsula_scene or not is_inside_tree(): return
	var cam = player.get_viewport().get_camera_3d()
	if cam == null: return

	var capsula = player.capsula_scene.instantiate()
	get_tree().current_scene.add_child(capsula)
	capsula.add_collision_exception_with(player)
	capsula.global_position = ponto
	capsula.global_rotation = cam.global_rotation
	# Sai para a direita e para cima, como em toda pistola de ferrolho.
	var direcao = cam.global_transform.basis * Vector3(1.0, 1.0, 0.0)
	capsula.apply_central_impulse(direcao * randf_range(1.5, 2.2))
	capsula.apply_torque(Vector3(randf_range(-5, 5), randf_range(-5, 5),
		randf_range(-5, 5)))


func raycast_process_shoot() -> void:
	if player.ray_cast_3d.is_colliding():
		var target = player.ray_cast_3d.get_collider()
		
		if target and target.has_method("take_damage"):
			target.take_damage(player.damage_pistol)
			
			if target.is_in_group("enemies"):
				spawn_blood_raycast(player.ray_cast_3d.get_collision_point(), player.ray_cast_3d.get_collision_normal())
				add_cogblade_power(10.0, player.ray_cast_3d.get_collision_point())
		
			var ponto_colisao = player.ray_cast_3d.get_collision_point()
			var distancia = player.ray_cast_3d.global_position.distance_to(ponto_colisao)
			
			if target.name == "heart" and distancia > 7:
				player.bullet.visible = true
				target.take_damage(player.damage_pistol+player.damage_headshoot)
					
				var offset_altura = Vector3(0.25, -0.3, 0) 
				var alvo_ajustado = target.global_position + offset_altura

				var tween_bullet = create_tween()
				var voltas = deg_to_rad(1800) 
				tween_bullet.tween_property(player.bullet, "rotation:z", player.bullet.rotation.z + voltas, 2.5)\
					.set_trans(Tween.TRANS_LINEAR)
					
				player.control_weapons.visible = false
				player.hand_with_pistol.visible = false
				if player.hand_with_magic: player.hand_with_magic.visible = false
				player.control_magic.visible = false
				player.bullet_light.visible = true
				player.bullet.visible = true
				player.camera_bullet_time_ON = true
				GlobalUtils.ativar_camera_lenta(0.1, 60.0, true)
				
				var tween_cam = create_tween()
				
				player.camera_3d_bullet_time.global_position = player.camera.global_position
				player.camera_3d_bullet_time.make_current()
				
				tween_cam.tween_property(player.camera_3d_bullet_time, "global_position", alvo_ajustado + (player.ray_cast_3d.global_transform.basis.z * 2.0), 0.9)\
					.set_trans(Tween.TRANS_QUINT)\
					.set_ease(Tween.EASE_OUT)

				tween_cam.parallel().tween_method(
				func(_pos): player.camera_3d_bullet_time.look_at(alvo_ajustado),
					0.0, 1.0, 0.9
				)

				tween_cam.tween_interval(0.05)

				tween_cam.tween_property(player.camera_3d_bullet_time, "global_position", player.camera.global_position, 0.4)\
					.set_trans(Tween.TRANS_SINE)
				
				await get_tree().create_timer(0.65).timeout
				if player.camera_bullet_time_ON: bullet_time_back()

func bullet_time_back() -> void:	
	player.camera_bullet_time_ON = false
	player.bullet.visible = false
	GlobalUtils.remover_camera_lenta()
	
	if player.is_first_person:
		player.camera.make_current()
		player.control_weapons.visible = true
		player.hand_with_pistol.visible = SaveManager.arma_de_fogo_equipada()
		if player.hand_with_magic: player.hand_with_magic.visible = true
		player.control_magic.visible = true
	else:
		player.camera_third_person.make_current()
	
	await get_tree().create_timer(0.16).timeout
	player.bullet_light.visible = false

func spawn_blood_raycast(pos: Vector3, normal: Vector3) -> void:
	if not is_inside_tree(): return
	var blood = player.blood_effect.instantiate()
	get_tree().root.add_child(blood)
	blood.global_position = pos

	if normal != Vector3.ZERO:
		blood.look_at(pos + normal, Vector3.UP)

func spawn_blood_effect(body: Node3D) -> void:
	if not is_inside_tree(): return
	var blood = player.blood_effect.instantiate()
	get_tree().root.add_child(blood)
	blood.global_position = body.global_position
	blood.global_position.y += 2
		
# =========================================================================
# SIFÃO DE SANGUE -> MEDIDOR DA COGBLADE
# =========================================================================
# O medidor não enche mais no instante do dano. Uma pequena porção do sangue
# do inimigo vira uma gota 2D que voa até a frente do player, espirra pra cima,
# cai no chão por gravidade, descansa um instante ali e só então é sugada para
# o canto superior esquerdo (onde fica a HUD do medidor), respinga no medidor e
# o preenchimento acontece.

## Tempo da gota do inimigo até o centro da tela (o player).
const SIPHON_TO_PLAYER_TIME: float = 0.30
## Tempo do centro da tela até o medidor no canto superior esquerdo.
const SIPHON_TO_HUD_TIME: float = 0.26
## Velocidade vertical do espirro (m/s) ao chegar na frente do jogador.
const SIPHON_SPLASH_UP: Vector2 = Vector2(3.4, 5.2)
## Espalhamento horizontal do espirro (m/s).
const SIPHON_SPLASH_SIDE: float = 1.8
## Gravidade do voo da gota (m/s²) - mais forte que a real, fica mais "peso".
const SIPHON_GRAVITY: float = 16.0
## Tempo que a gota fica parada no chão antes de ser sugada pro medidor.
const SIPHON_GROUND_REST: float = 0.18
## Quantas gotas de sangue cada dano manda para o medidor.
const SIPHON_DROPS_PER_HIT: int = 4
## Atraso entre uma gota e a seguinte do mesmo golpe.
const SIPHON_DROP_STAGGER: float = 0.07
## Máximo de gotas simultâneas: acima disso o poder entra direto (sem FX),
## pra não virar chuva de sangue em rajadas rápidas de dano.
const SIPHON_MAX_ACTIVE: int = 24

var _siphons: Array[Node2D] = []
var _cogblade_fill_tween: Tween

func add_cogblade_power(amount: float, source_pos = null) -> void:
	if GlobalEvents.is_maycow_normal or not player.cogblade_hud or player.is_using_ultimate: return
	if amount <= 0.0: return

	var vivos: Array[Node2D] = []
	for s in _siphons:
		if is_instance_valid(s): vivos.append(s)
	_siphons = vivos

	var start = _siphon_screen_start(source_pos)
	if start == null or _siphons.size() >= SIPHON_MAX_ACTIVE:
		# Sem posição de origem visível na tela (ou FX demais): aplica direto.
		_apply_cogblade_power(amount)
		return

	_spawn_blood_siphon(start, amount, source_pos)

# Converte a posição 3D do golpe em coordenadas de tela. Retorna null quando
# não dá pra desenhar o trajeto (sem câmera, ou o alvo está atrás dela).
func _siphon_screen_start(source_pos):
	if not (source_pos is Vector3): return null
	if not is_inside_tree(): return null
	var vp := player.get_viewport()
	if not vp: return null
	var cam := vp.get_camera_3d()
	if not is_instance_valid(cam) or cam.is_position_behind(source_pos): return null

	var screen: Vector2 = cam.unproject_position(source_pos)
	var size: Vector2 = vp.get_visible_rect().size
	# Inimigo fora do enquadramento: puxa a gota pra borda mais próxima.
	screen.x = clamp(screen.x, 8.0, size.x - 8.0)
	screen.y = clamp(screen.y, 8.0, size.y - 8.0)
	return screen

func _spawn_blood_siphon(start: Vector2, amount: float, source_pos = null) -> void:
	if not is_instance_valid(player.hud_layer) or not is_instance_valid(player.cogblade_hud):
		_apply_cogblade_power(amount)
		return

	# O sangue sai do inimigo em várias gotas, não em uma só: elas partem de
	# pontos ligeiramente diferentes e escalonadas no tempo, então chegam no
	# medidor em sequência (várias respingadas em vez de uma).
	var total := SIPHON_DROPS_PER_HIT
	var share := amount / float(total)
	for i in total:
		var jitter := Vector2(randf_range(-26.0, 26.0), randf_range(-22.0, 22.0))
		_spawn_blood_drop(start + jitter, share, float(i) * SIPHON_DROP_STAGGER, source_pos)

# --- Ancoragem no mundo -----------------------------------------------------
# As gotas são nós 2D (HUD), mas ficam presas a pontos do MUNDO: a cada frame a
# posição na tela é recalculada projetando o ponto 3D pela câmera atual. Assim,
# girar a câmera faz o sangue deslizar pela tela como qualquer coisa parada no
# cenário, em vez de ficar colado no visor.

## Profundidade (em metros) do ponto à frente do jogador onde a gota espirra.
const SIPHON_SPLASH_DEPTH: Vector2 = Vector2(2.5, 4.5)

func _cam() -> Camera3D:
	var vp := player.get_viewport() if is_instance_valid(player) else null
	if not vp: return null
	return vp.get_camera_3d()

## Ponto do mundo que hoje aparece em `screen`, à distância `dist` da câmera.
func _screen_to_world(screen: Vector2, dist: float) -> Vector3:
	var cam := _cam()
	if not is_instance_valid(cam): return Vector3.ZERO
	return cam.project_position(screen, dist)

## Onde um ponto do mundo cai na tela agora. Se ficou atrás da câmera, devolve
## `fallback` (a última posição válida), pra gota não pular pro outro lado.
func _world_to_screen(world: Vector3, fallback: Vector2) -> Vector2:
	var cam := _cam()
	if not is_instance_valid(cam) or cam.is_position_behind(world): return fallback
	return cam.unproject_position(world)

## Altura do chão logo abaixo de `world`. Sem colisão embaixo (ou sem cena),
## assume a altura dos pés do player.
func _ground_height(world: Vector3) -> float:
	var piso: float = player.global_position.y
	if not player.is_inside_tree(): return piso

	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(world + Vector3.UP * 0.2, world + Vector3.DOWN * 25.0)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.has("position"): return hit["position"].y
	return piso

func _spawn_blood_drop(start: Vector2, amount: float, delay: float, source_pos = null) -> void:
	var vp_size: Vector2 = player.get_viewport().get_visible_rect().size
	var center: Vector2 = vp_size * 0.5
	var hud_target: Vector2 = _cogblade_hud_center()

	# Profundidade desta gota: quanto mais perto da câmera, mais ela desliza
	# quando o jogador vira - é o mesmo paralaxe de qualquer objeto do cenário.
	var depth := randf_range(SIPHON_SPLASH_DEPTH.x, SIPHON_SPLASH_DEPTH.y)
	var cam := _cam()
	# A origem fica presa ao ponto exato do golpe no inimigo (quando temos ele).
	var start_depth: float = depth
	if source_pos is Vector3 and is_instance_valid(cam):
		start_depth = maxf(cam.global_position.distance_to(source_pos), 0.5)
	var start_world: Vector3 = _screen_to_world(start, start_depth)

	# Cada gota tem tamanho e velocidade um pouco diferentes.
	var raio := randf_range(4.5, 7.5)
	var vel := randf_range(0.88, 1.15)

	var container := Node2D.new()
	container.name = "CogbladeBloodSiphon"
	container.position = start
	container.visible = delay <= 0.0
	player.hud_layer.add_child(container)
	_siphons.append(container)

	# Halo suave por trás da gota (dá o "brilho" molhado)
	var halo := Polygon2D.new()
	halo.polygon = _circle_points(raio * 2.0)
	halo.color = Color(0.55, 0.0, 0.0, 0.35)
	container.add_child(halo)

	var drop := Polygon2D.new()
	drop.polygon = _circle_points(raio)
	drop.color = Color(0.72, 0.02, 0.02, 1.0)
	container.add_child(drop)

	# Rastro: as partículas ficam no espaço da tela (local_coords = false),
	# então elas "sobram" no caminho enquanto a gota avança.
	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 40
	trail.lifetime = 0.5
	trail.speed_scale = 1.0
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 5.0
	trail.direction = Vector2(0, 1)
	trail.spread = 45.0
	trail.gravity = Vector2(0, 160)
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 55.0
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 4.5
	trail.color = Color(0.65, 0.0, 0.0, 0.85)
	var trail_ramp := Gradient.new()
	trail_ramp.offsets = [0.0, 1.0]
	trail_ramp.colors = [Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)]
	trail.color_ramp = trail_ramp
	trail.emitting = delay <= 0.0
	container.add_child(trail)

	# Curvas: a gota faz um arco em vez de linha reta. O lado e a altura do
	# arco variam, então gotas do mesmo golpe não viajam empilhadas.
	var arco := randf_range(35.0, 95.0) * (1.0 if randf() < 0.5 else -1.0)

	# Depois de chegar ao centro, a gota vagueia por pontos aleatórios ali por
	# perto antes de decidir subir - cada gota faz um caminho diferente.
	# O ponto de chegada à frente do jogador é do MUNDO, não da tela.
	var center_world: Vector3 = _screen_to_world(center, depth)

	# Espirro: velocidade inicial pra cima com uma abertura lateral aleatória.
	var vel_inicial := Vector3(
		randf_range(-SIPHON_SPLASH_SIDE, SIPHON_SPLASH_SIDE),
		randf_range(SIPHON_SPLASH_UP.x, SIPHON_SPLASH_UP.y),
		randf_range(-SIPHON_SPLASH_SIDE, SIPHON_SPLASH_SIDE)
	)

	# Onde é o chão embaixo desse ponto (raycast), e quanto tempo o voo dura.
	var chao_y: float = _ground_height(center_world)
	var queda: float = maxf(center_world.y - chao_y, 0.05)
	var voo: float = (vel_inicial.y + sqrt(vel_inicial.y * vel_inicial.y + 2.0 * SIPHON_GRAVITY * queda)) / SIPHON_GRAVITY
	voo = clampf(voo, 0.3, 1.6)

	# Ponto exato onde a gota vai bater no chão - é de lá que ela sobe pro medidor.
	# A altura sai da MESMA fórmula do voo (e não de chao_y direto), senão um
	# tempo de voo no limite do clamp faria a gota "pular" no fim da queda.
	var pouso_y: float = center_world.y + vel_inicial.y * voo - 0.5 * SIPHON_GRAVITY * voo * voo
	var last_world: Vector3 = Vector3(
		center_world.x + vel_inicial.x * voo,
		maxf(pouso_y, chao_y + 0.03), # Um dedo acima do chão, pra não sumir dentro dele
		center_world.z + vel_inicial.z * voo
	)
	# Curvatura da subida, guardada como número: o traçado em si é recalculado
	# a cada frame com a projeção atualizada dos pontos.
	var hud_arco := randf_range(-70.0, 70.0)

	# Tween do próprio container: se ele for liberado (poder consumiu o medidor),
	# o trajeto morre junto e o preenchimento não acontece.
	var tw := container.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			if is_instance_valid(container):
				container.visible = true
				trail.emitting = true
		)

	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		# Reprojeta origem e destino todo frame: se o jogador girar a câmera no
		# meio do trajeto, a gota acompanha o cenário em vez da tela.
		var a := _world_to_screen(start_world, container.position)
		var b := _world_to_screen(center_world, container.position)
		var ctrl: Vector2 = a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * arco
		container.position = _bezier2(a, ctrl, b, t)
	, 0.0, 1.0, SIPHON_TO_PLAYER_TIME * vel).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Chegou ao centro: pequena "absorvida" (a gota infla e comprime). A posição
	# continua sendo reprojetada aqui também, senão a gota "congelaria" na tela
	# por um instante justo enquanto o jogador gira a câmera.
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		container.position = _world_to_screen(center_world, container.position)
		container.scale = Vector2.ONE.lerp(Vector2(1.5, 1.5), t)
	, 0.0, 1.0, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		container.position = _world_to_screen(center_world, container.position)
		container.scale = Vector2(1.5, 1.5).lerp(Vector2(0.85, 0.85), t)
	, 0.0, 1.0, 0.06).set_trans(Tween.TRANS_SINE)

	# Espirra pra cima e cai: posição por física de projétil, no espaço do mundo.
	# Sem easing (TRANS_LINEAR) porque a curva já vem da própria gravidade.
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		var tempo := t * voo
		var mundo := center_world + vel_inicial * tempo + Vector3.DOWN * (0.5 * SIPHON_GRAVITY * tempo * tempo)
		container.position = _world_to_screen(mundo, container.position)
		# A gota estica no sentido do voo: alonga subindo/caindo rápido.
		var vel_y: float = vel_inicial.y - SIPHON_GRAVITY * tempo
		var estica: float = clampf(absf(vel_y) / 6.0, 0.0, 0.6)
		container.scale = Vector2(1.0 - estica * 0.35, 1.0 + estica * 0.5)
	, 0.0, 1.0, voo).set_trans(Tween.TRANS_LINEAR)

	# Bateu no chão: achata e descansa ali um instante, ainda preso ao mundo.
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		container.position = _world_to_screen(last_world, container.position)
		# Esparrama no impacto e volta - o "splat" da gota batendo.
		var splat: float = sin(clampf(t, 0.0, 1.0) * PI)
		container.scale = Vector2(1.0 + splat * 0.7, 1.0 - splat * 0.45)
	, 0.0, 1.0, SIPHON_GROUND_REST).set_trans(Tween.TRANS_SINE)

	# Do chão, sobe para o medidor. Aqui a gota "descola" do mundo e passa a ser
	# HUD: a origem ainda acompanha a câmera, o destino é o canto da tela.
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(container): return
		var a := _world_to_screen(last_world, container.position)
		var ctrl: Vector2 = a.lerp(hud_target, 0.5) + (hud_target - a).orthogonal().normalized() * hud_arco
		container.position = _bezier2(a, ctrl, hud_target, t)
	, 0.0, 1.0, SIPHON_TO_HUD_TIME * vel).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.tween_callback(func() -> void:
		_siphons.erase(container)
		if is_instance_valid(container):
			trail.emitting = false
			halo.visible = false
			drop.visible = false
			# Deixa o rastro terminar de cair antes de sumir com o nó.
			container.create_tween().tween_callback(container.queue_free).set_delay(0.6)
		_cogblade_blood_splash()
		_apply_cogblade_power(amount)
	)

# Respingo rápido de sangue no medidor, no momento em que a gota chega.
func _cogblade_blood_splash() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.cogblade_hud): return
	if not is_instance_valid(player.hud_layer): return

	var splash := CPUParticles2D.new()
	splash.position = _cogblade_hud_center()
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 34
	splash.lifetime = 0.5
	splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	splash.emission_sphere_radius = 10.0
	splash.direction = Vector2(0, -1)
	splash.spread = 180.0
	splash.gravity = Vector2(0, 520)
	splash.initial_velocity_min = 70.0
	splash.initial_velocity_max = 230.0
	splash.scale_amount_min = 2.0
	splash.scale_amount_max = 5.5
	splash.color = Color(0.8, 0.0, 0.0, 0.9)
	var ramp := Gradient.new()
	ramp.offsets = [0.0, 0.7, 1.0]
	ramp.colors = [Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)]
	splash.color_ramp = ramp
	splash.emitting = true
	player.hud_layer.add_child(splash)
	splash.create_tween().tween_callback(splash.queue_free).set_delay(1.2)

	# Flash vermelho + "soco" de escala no próprio medidor. Usa modulate/scale
	# porque o pulso de medidor cheio já ocupa o tint_progress.
	var hud: TextureProgressBar = player.cogblade_hud
	var base_scale := Vector2(0.4, 0.4)
	var punch := create_tween()
	punch.tween_property(hud, "modulate", Color(1.8, 0.35, 0.35, 1.0), 0.05)
	punch.parallel().tween_property(hud, "scale", base_scale * 1.12, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(hud, "modulate", Color(1, 1, 1, 1), 0.22)
	punch.parallel().tween_property(hud, "scale", base_scale, 0.22).set_trans(Tween.TRANS_SINE)

# Preenchimento propriamente dito (só depois do sangue chegar no medidor).
func _apply_cogblade_power(amount: float) -> void:
	if not is_instance_valid(player) or not player.cogblade_hud: return
	if GlobalEvents.is_maycow_normal or player.is_using_ultimate: return

	player.cogblade_power_value = clamp(player.cogblade_power_value + amount, 0.0, 100.0)

	if _cogblade_fill_tween and _cogblade_fill_tween.is_valid(): _cogblade_fill_tween.kill()
	_cogblade_fill_tween = create_tween()
	_cogblade_fill_tween.tween_property(player.cogblade_hud, "value", player.cogblade_power_value, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if player.cogblade_power_value >= 100.0 and not player.cogblade_pulsing:
		player.cogblade_pulsing = true
		_start_cogblade_pulse()

# Cancela gotas em trânsito e o tween de preenchimento (usado quando um poder
# consome o medidor: o sangue que ainda estava vindo não pode encher de novo).
func cancel_cogblade_siphons() -> void:
	if _cogblade_fill_tween and _cogblade_fill_tween.is_valid(): _cogblade_fill_tween.kill()
	_cogblade_fill_tween = null
	for s in _siphons:
		if is_instance_valid(s): s.queue_free()
	_siphons.clear()

# Centro do medidor da cogblade em coordenadas da HUD.
func _cogblade_hud_center() -> Vector2:
	var hud: TextureProgressBar = player.cogblade_hud
	if not is_instance_valid(hud): return Vector2(60, 60)
	var tam: Vector2 = hud.size
	if tam == Vector2.ZERO and hud.texture_progress:
		tam = hud.texture_progress.get_size()
	return hud.position + (tam * hud.scale) * 0.5

func _bezier2(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

func _circle_points(radius: float, segments: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

func _start_cogblade_pulse() -> void:
	if not player.cogblade_hud: return
	
	if player.cogblade_pulse_tween: player.cogblade_pulse_tween.kill()
	player.cogblade_pulse_tween = create_tween().set_loops()
	
	player.cogblade_pulse_tween.tween_property(player.cogblade_hud, "tint_progress", Color(1.0, 0.2, 0.2, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	player.cogblade_pulse_tween.tween_property(player.cogblade_hud, "tint_progress", Color(1.0, 1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	if not player.cogblade_particles:
		player.cogblade_particles = CPUParticles2D.new()
		player.cogblade_particles.emitting = true
		player.cogblade_particles.amount = 50
		player.cogblade_particles.lifetime = 1.0
		player.cogblade_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		
		var w = player.cogblade_hud.texture_progress.get_width()
		var h = player.cogblade_hud.texture_progress.get_height()
		player.cogblade_particles.emission_rect_extents = Vector2(w / 2.0, h / 2.0)
		
		player.cogblade_particles.gravity = Vector2(0, 300)
		player.cogblade_particles.color = Color(0.8, 0.0, 0.0, 0.8)
		player.cogblade_particles.scale_amount_min = 3.0
		player.cogblade_particles.scale_amount_max = 6.0
		
		player.cogblade_hud.add_child(player.cogblade_particles)
		player.cogblade_particles.position = Vector2(w / 2.0, h / 2.0)
	else:
		player.cogblade_particles.emitting = true

func update_equipment_visuals() -> void:
	if player.is_first_person and not player.is_reloading and player.control_weapons.visible:
		if not player.are_cutscene_inputs_blocked():
			player.hand_with_pistol.visible = SaveManager.arma_de_fogo_equipada()
		else:
			player.hand_with_pistol.visible = false
	# A arma na mão do Maycow normal não precisa de nada aqui: o
	# `player_gun_hold.gd` lê o equipamento todo quadro. O contador de balas,
	# sim — ele é HUD, e só é reescrito quando alguém pede.
	player.update_ammo_ui()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if player.is_magic_attacking:
		player.blade_in.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true)
		if body.has_method("take_damage"): body.take_damage(player.damage_crescent_cogblade)
	
func _on_area_3d_body_exited(body: Node3D) -> void:
	if player.is_magic_attacking:
		player.blade_back.play()
		spawn_blood_effect(body)
		GlobalUtils.ativar_camera_lenta(0.2, 0.5, true)
		if body.has_method("take_damage"): body.take_damage(player.damage_crescent_cogblade)

func _on_bullet_touch_body_entered(body: Node3D) -> void:
	player.bullet.visible = false
	spawn_blood_effect(body)
