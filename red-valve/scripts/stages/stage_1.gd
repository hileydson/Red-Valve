extends Node3D

# O fim do prologo (cutscene_fight_with_power) vira arquivo de leitura assim que
# o Capitulo 1 comeca.
const ARQUIVO_CADERNO := "caderno_do_jimmy"

@onready var navigation_region_3d: NavigationRegion3D = $NavigationRegion3D
@onready var real_time_label: Label = $real_time_label
@onready var sky_3d: Sky3D = $WorldEnvironment/Sky3D

var player_na_oficina: bool = false
var player_na_casa_jimmy: bool = false
var player_na_casa_maycow: bool = false
var prompt_label: Label
var intro_label: Label
var ui_layer: CanvasLayer

var rain_scene = preload("res://scenes/effects/rain_effect.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	GlobalEvents.in_cutscene = false
	if is_instance_valid(real_time_label):
		real_time_label.queue_free()
	SaveManager.save_game()
	GlobalEvents.set_low_nevoa()
	GlobalEvents.is_maycow_normal = true
	#$cameras/camera_1.make_current()
	
	# --- INICIA A CHUVA E ATMOSFERA PESADA ---
	var rain = rain_scene.instantiate()
	add_child(rain)
	
	# Escurecer o ambiente e aumentar a névoa para o clima de tempestade
	var env_node = get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var env = env_node.environment
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.015
		env.volumetric_fog_albedo = Color(0.3, 0.35, 0.4)
		
		env.fog_enabled = true
		env.fog_density = 0.005
		env.fog_light_color = Color(0.2, 0.25, 0.3)
		
		# Reduz levemente a luz ambiente
		env.ambient_light_energy = 0.6
	
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 128
	add_child(ui_layer)
	_setup_areas_casas()
	setup_player_spawn()

func setup_player_spawn() -> void:
	var is_chapter_1 = GlobalEvents.entering_chapter_1 or SaveManager.prolog_finished
	# Consome a flag aqui em cima pra ela nunca sobrar ligada quando o jogador
	# chegar ao mapa por outro caminho (voltando de uma casa, por exemplo).
	var usa_posicao_salva = SaveManager.spawn_from_saved_position and SaveManager.has_saved_position()
	SaveManager.spawn_from_saved_position = false

	# Voltando do interior da casa do Jimmy: o jogador tem de reaparecer na
	# soleira, e não no ponto de entrada normal do mapa.
	if GlobalEvents.voltando_da_casa_jimmy:
		GlobalEvents.voltando_da_casa_jimmy = false
		var saida = get_node_or_null("itens_caminho_jimmy/casa_jimmy/ponto_de_saida")
		if not saida:
			saida = find_child("ponto_de_saida", true, false)
		var jogador = get_node_or_null("Player")
		if not jogador:
			jogador = find_child("Player", true, false)
		if not jogador:
			jogador = find_child("player", true, false)
		if jogador and saida:
			jogador.global_position = saida.global_position
			jogador.global_rotation.y = saida.global_rotation.y
	elif GlobalEvents.voltando_da_casa_maycow:
		GlobalEvents.voltando_da_casa_maycow = false
		var jogador = get_node_or_null("Player")
		if not jogador:
			jogador = find_child("Player", true, false)
		if not jogador:
			jogador = find_child("player", true, false)
		if jogador:
			jogador.global_position = Vector3(638.568, 6.75, -148.692)
			jogador.global_rotation.y = -PI * 0.5
	elif is_chapter_1:
		var spawn_point = get_node_or_null("itens_caminho_jimmy/auto_pecas_jimmy/maykow_capitulo_1_inicio")
		var player = get_node_or_null("Player")
		if not player:
			player = find_child("Player", true, false)
		if not player:
			player = find_child("player", true, false)
		# Se o save veio da opcao "Salvar" do menu de pause, o jogador volta na
		# posicao exata em que gravou; senao, no ponto de entrada do capitulo 1.
		if player and usa_posicao_salva:
			player.global_position = SaveManager.get_saved_position()
			player.global_rotation.y = SaveManager.get_saved_rotation_y()
		elif player and spawn_point:
			player.global_position = spawn_point.global_position
			player.global_rotation.y = spawn_point.global_rotation.y + PI

	var bloqueio = get_node_or_null("bloqueio_prologo_oficina_jimmy")
	if not bloqueio:
		bloqueio = find_child("bloqueio_prologo_oficina_jimmy", true, false)
	if bloqueio:
		bloqueio.queue_free()
		
	# Remove os inimigos imediatamente se ainda estiver no prólogo
	if not is_chapter_1:
		var enemies_node = get_node_or_null("enemies")
		if not enemies_node:
			enemies_node = find_child("enemies", true, false)
		if enemies_node:
			enemies_node.queue_free()
	else:
		_ligar_spawner_de_inimigos()

	if not is_instance_valid(prompt_label):
		var center_container = CenterContainer.new()
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		prompt_label = Label.new()
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt_label.add_theme_font_size_override("font_size", 24)
		prompt_label.add_theme_constant_override("outline_size", 4)
		
		center_container.add_child(prompt_label)
		ui_layer.add_child(center_container)
		center_container.visible = false
		
		# Guardamos a referência ao container para poder ligar/desligar a visibilidade
		# Como o prompt_label é var, vamos sobrescrever o funcionamento usando a variável do prompt
		prompt_label.set_meta("container", center_container)
	
	# Inicia a exibição do texto introdutório
	_play_intro_text()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#real_time_label.text = "Time: "+str(sky_3d.game_time)
	
	if not Input.is_action_just_pressed("ui_accept"):
		return

	if player_na_oficina:
		player_na_oficina = false
		_esconder_prompt()
		$fade.fade_out()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/stages/prolog/oficina_jimmy.tscn")
	elif player_na_casa_jimmy:
		player_na_casa_jimmy = false
		_esconder_prompt()
		$fade.fade_out()
		await get_tree().create_timer(2.0).timeout
		LoadingScreen.load_scene("res://scenes/stages/jimmy_house/casa_jimmy_interior.tscn")
	elif player_na_casa_maycow:
		player_na_casa_maycow = false
		GlobalEvents.entrando_na_casa_maycow = true
		_esconder_prompt()
		$fade.fade_out()
		await get_tree().create_timer(2.0).timeout
		LoadingScreen.load_scene("res://scenes/stages/prolog/the_house.tscn")


func _mostrar_prompt(texto: String) -> void:
	if not is_instance_valid(prompt_label):
		return
	prompt_label.text = texto
	if prompt_label.has_meta("container"):
		prompt_label.get_meta("container").visible = true
	prompt_label.visible = true


func _esconder_prompt() -> void:
	if not is_instance_valid(prompt_label):
		return
	if prompt_label.has_meta("container"):
		prompt_label.get_meta("container").visible = false
	prompt_label.visible = false


func _eh_o_player(body: Node3D) -> bool:
	return body.name.to_lower() == "player" or body.is_in_group("player")


## Casa do Jimmy: mesma mecânica de prompt da oficina, mas sem a trava do
## prólogo — a casa continua acessível depois que ele termina.
func _ao_entrar_area_casa_jimmy(body: Node3D) -> void:
	if not _eh_o_player(body):
		return
	player_na_casa_jimmy = true
	_mostrar_prompt(tr("PROMPT_ENTER_JIMMY_HOUSE"))


func _ao_sair_area_casa_jimmy(body: Node3D) -> void:
	if not _eh_o_player(body):
		return
	player_na_casa_jimmy = false
	_esconder_prompt()


func _setup_areas_casas() -> void:
	var casa_jimmy_area = get_node_or_null("itens_caminho_jimmy/casa_jimmy/area_entrada")
	if not casa_jimmy_area:
		casa_jimmy_area = find_child("area_entrada", true, false)
	if casa_jimmy_area:
		if not casa_jimmy_area.body_entered.is_connected(_ao_entrar_area_casa_jimmy):
			casa_jimmy_area.body_entered.connect(_ao_entrar_area_casa_jimmy)
		if not casa_jimmy_area.body_exited.is_connected(_ao_sair_area_casa_jimmy):
			casa_jimmy_area.body_exited.connect(_ao_sair_area_casa_jimmy)

	if get_node_or_null("area_entrada_casa_maycow") == null:
		var area_maycow = Area3D.new()
		area_maycow.name = "area_entrada_casa_maycow"
		area_maycow.collision_layer = 0
		area_maycow.collision_mask = 1
		area_maycow.monitorable = false
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(7.0, 5.0, 7.0)
		col_shape.shape = box
		area_maycow.add_child(col_shape)
		add_child(area_maycow)
		area_maycow.global_position = Vector3(639.5, 7.5, -148.7)
		area_maycow.body_entered.connect(_ao_entrar_area_casa_maycow)
		area_maycow.body_exited.connect(_ao_sair_area_casa_maycow)


func _ao_entrar_area_casa_maycow(body: Node3D) -> void:
	if not _eh_o_player(body):
		return
	player_na_casa_maycow = true
	_mostrar_prompt(tr("PROMPT_ENTER_MAYCOW_HOUSE"))


func _ao_sair_area_casa_maycow(body: Node3D) -> void:
	if not _eh_o_player(body):
		return
	player_na_casa_maycow = false
	_esconder_prompt()


func _on_timer_timeout() -> void:
	pass #navigation_region_3d.bake_navigation_mesh(true)


func _on_camera_1_area_shape_entered(area_rid: RID, area: Area3D, area_shape_index: int, local_shape_index: int) -> void:
	print("camera 1")
	#$cameras/camera_1.make_current()


func _on_camera_2_body_entered(body: Node3D) -> void:
	print(body)
	print("camera 2")
	#$cameras/camera_2.make_current()


func _on_area_3d_jimmy_house_body_entered(body: Node3D) -> void:
	if SaveManager.prolog_finished:
		return
	if _eh_o_player(body):
		player_na_oficina = true
		_mostrar_prompt(tr("PROMPT_ENTER_WORKSHOP"))


func _on_area_3d_jimmy_house_body_exited(body: Node3D) -> void:
	if SaveManager.prolog_finished:
		return
	if _eh_o_player(body):
		player_na_oficina = false
		_esconder_prompt()

func _play_intro_text() -> void:
	if GlobalEvents.entering_chapter_1:
		GlobalEvents.entering_chapter_1 = false
		# Exibe o título "CAPÍTULO 1" em vermelho bem grande no centro da tela (tamanho 120 como no splash)
		await get_tree().create_timer(1.0, false).timeout
		
		var chapter_label = Label.new()
		chapter_label.text = tr("TXT_CHAPTER_1").to_upper()
		chapter_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chapter_label.add_theme_font_size_override("font_size", 180)
		chapter_label.add_theme_color_override("font_color", Color(0.705882, 0.0, 0.0))
		
		var custom_font = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
		if custom_font:
			chapter_label.add_theme_font_override("font", custom_font)
			
		ui_layer.add_child(chapter_label)
		
		chapter_label.modulate.a = 0.0
		var tween_in = create_tween()
		tween_in.tween_property(chapter_label, "modulate:a", 1.0, 1.0)
		await tween_in.finished
		
		await get_tree().create_timer(3.5, false).timeout
		
		if is_instance_valid(chapter_label):
			var tween_out = create_tween()
			tween_out.tween_property(chapter_label, "modulate:a", 0.0, 1.0)
			await tween_out.finished
			chapter_label.queue_free()

		# So depois que o "CAPITULO 1" saiu da tela: dois avisos grandes ao mesmo
		# tempo no centro se atropelariam, e o respiro deixa claro que sao coisas
		# diferentes.
		await get_tree().create_timer(2.0, false).timeout
		_novo_arquivo(ARQUIVO_CADERNO)
		return

	if SaveManager.prolog_finished:
		return

	if SaveManager.stage_1_intro_played:
		return
	SaveManager.stage_1_intro_played = true
	SaveManager.save_game()
	
	# Pequena pausa antes de começar para não ser tão brusco
	await get_tree().create_timer(1.5, false).timeout
	
	var intro_keys = [
		"NO_POWER_1_WALK_1", "NO_POWER_1_WALK_2", "NO_POWER_1_WALK_3", 
		"NO_POWER_1_WALK_4", "NO_POWER_1_WALK_5", "NO_POWER_1_WALK_6"
	]
	
	for key in intro_keys:
		GlobalUtils.show_center_message("intro_stage_1", tr(key), 18)
		await get_tree().create_timer(4.5, false).timeout
		GlobalUtils.hide_center_message("intro_stage_1")
		await get_tree().create_timer(0.5, false).timeout


## A cidade do Capitulo 1 tem de ter inimigo aparecendo enquanto o Maycow anda.
## O spawner nasce por codigo (e nao no .tscn) justamente porque ele NAO pode
## existir no prologo: la a cidade e so travessia, e a stage_1 e a mesma cena.
## Se a volta da casa do Jimmy ou da arena recarregar a cena, este _ready roda
## de novo e o spawner e recriado — dai o cuidado de nao duplicar.
func _ligar_spawner_de_inimigos() -> void:
	if get_node_or_null("enemy_spawner") != null:
		return
	var spawner = load("res://scripts/enemies/enemy_spawner.gd").new()
	spawner.name = "enemy_spawner"
	add_child(spawner)


## Libera o arquivo do menu, grava e avisa na tela. O aviso so sai na primeira vez.
func _novo_arquivo(id: String) -> void:
	if not SaveManager.desbloquear_arquivo(id):
		return
	# O aviso espera a cutscene acabar (ver GlobalUtils.show_new_file_message).
	GlobalUtils.show_new_file_message(id)
