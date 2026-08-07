extends Node3D

var player_na_porta: bool = false
var prompt_label: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.set_minimum_nevoa()
	
	# Cria o prompt visual por código
	prompt_label = Label.new()
	prompt_label.text = tr("PROMPT_LEAVE_HOUSE")
	prompt_label.visible = false
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Aumentando o tamanho da fonte para melhor leitura
	prompt_label.add_theme_font_size_override("font_size", 24)
	# Adicionando um contorno na fonte para destacar na cena
	prompt_label.add_theme_constant_override("outline_size", 4)
	add_child(prompt_label)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_na_porta and Input.is_action_just_pressed("ui_accept"):
		# Previne que o jogador aperte o botão várias vezes
		player_na_porta = false
		prompt_label.visible = false
		
		# Chama o efeito de fade out
		$ambient/fade.fade_out()
		
		# Aguarda 2 segundos para o efeito terminar
		await get_tree().create_timer(2.0).timeout
		
		# Transporta para a cena stage_1 seguindo o padrão atual do projeto
		get_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1.tscn")


func _on_area_3d_body_entered(body: Node3D) -> void:
	print(body.name)
	# Verifica se quem entrou na área foi o player
	if body.name == "player" or body.is_in_group("player"):
		player_na_porta = true
		prompt_label.visible = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("player"):
		player_na_porta = false
		prompt_label.visible = false
