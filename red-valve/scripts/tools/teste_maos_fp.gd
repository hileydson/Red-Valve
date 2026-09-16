extends Node3D

## Bancada das maos de primeira pessoa — NAO faz parte do jogo.
##
## Monta um chao, um "jogador" de mentira e um inimigo de mentira, e deixa
## rodar tanto as animacoes de mao soltas quanto o AGARRAO inteiro
## (player_grab.gd), sem precisar da cidade, do terreno nem de um inimigo de
## verdade. E' aqui que se olha uma pose nova antes de gerar o .glb de novo.
##
##   1..0   toca uma animacao de mao (na ordem de ANIMS abaixo)
##   M      roda o agarrao de MORDIDA
##   A      roda o agarrao de ARREMESSO
##   R      recomeca (devolve o jogador e o inimigo ao lugar)
##
## Os dubles (`_FalsoPlayer` e `_FalsoInimigo`, no fim do arquivo) implementam
## SO' o que o player_grab.gd le' do jogador e do inimigo. Se um dia ele passar
## a ler mais coisa, e' aqui que falta.

const ANIMS := ["idle", "defesa", "agarrado", "mordida", "arremesso", "queda",
		"chao", "levantar", "guardar", "sacar"]

const CENA_FP := "res://scenes/player/cutscene_fp/player_cutscene_fp.tscn"

var jogador: CharacterBody3D
var inimigo: CharacterBody3D
var rig_solto: Node3D
var etiqueta: Label


func _ready() -> void:
	_montar_cenario()
	_montar_dubles()
	_montar_hud()
	# Sem isto o agarrao recusa na primeira checagem: ele so' vale fora da
	# arena, e "fora da arena" e' exatamente `is_maycow_normal`.
	GlobalEvents.is_maycow_normal = true
	GlobalEvents.in_cutscene = false
	GlobalEvents.agarrao_rodando = false
	_abrir_rig_solto()


func _montar_cenario() -> void:
	var piso := StaticBody3D.new()
	piso.name = "chao"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(120.0, 1.0, 120.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.5, 0.0)
	piso.add_child(forma)
	var visual := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(120.0, 120.0)
	visual.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.17, 0.16)
	visual.material_override = mat
	piso.add_child(visual)
	add_child(piso)

	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(28.0), 0.0)
	sol.light_energy = 1.0
	add_child(sol)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.52)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	ambiente.environment = env
	add_child(ambiente)


func _montar_dubles() -> void:
	jogador = _FalsoPlayer.new()
	jogador.name = "Player"
	add_child(jogador)
	jogador.global_position = Vector3(0.0, 1.0, 0.0)

	inimigo = _FalsoInimigo.new()
	inimigo.name = "Inimigo"
	add_child(inimigo)
	inimigo.global_position = Vector3(0.0, 0.0, -1.4)

	var comp := Node.new()
	comp.set_script(load("res://scripts/player/player_grab.gd"))
	comp.name = "PlayerGrab"
	jogador.add_child(comp)


func _montar_hud() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 5
	etiqueta = Label.new()
	etiqueta.position = Vector2(24.0, 20.0)
	etiqueta.add_theme_font_size_override("font_size", 16)
	camada.add_child(etiqueta)
	add_child(camada)


## Rig avulso, so' para olhar as animacoes uma a uma. O agarrao instancia o
## dele proprio; este sai de cena enquanto a cinematica roda.
func _abrir_rig_solto() -> void:
	if is_instance_valid(rig_solto):
		return
	rig_solto = load(CENA_FP).instantiate()
	add_child(rig_solto)
	rig_solto.plantar(Vector3(0.0, 1.5, 0.0), Vector3(0.0, 1.35, -3.0))
	rig_solto.assumir_camera()
	rig_solto.tocar(&"idle")


func _fechar_rig_solto() -> void:
	if is_instance_valid(rig_solto):
		rig_solto.queue_free()
	rig_solto = null


func _unhandled_key_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return

	var numero := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
			KEY_6, KEY_7, KEY_8, KEY_9, KEY_0].find(tecla.keycode)
	if numero >= 0 and numero < ANIMS.size():
		_abrir_rig_solto()
		rig_solto.tocar(ANIMS[numero])
		return

	match tecla.keycode:
		KEY_M:
			_disparar("mordida")
		KEY_A:
			_disparar("arremesso")
		KEY_R:
			_recomecar()


func _disparar(tipo: String) -> void:
	if GlobalEvents.agarrao_rodando:
		return
	_fechar_rig_solto()
	inimigo.tipo_agarrao = tipo
	jogador.grab_from_touch(inimigo)


func _recomecar() -> void:
	GlobalEvents.agarrao_rodando = false
	GlobalEvents.in_cutscene = false
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	jogador.global_position = Vector3(0.0, 1.0, 0.0)
	jogador.current_health = jogador.max_health
	jogador.invulnerable = false
	inimigo.global_position = Vector3(0.0, 0.0, -1.4)
	_abrir_rig_solto()


func _process(_delta: float) -> void:
	if not is_instance_valid(etiqueta):
		return
	if not GlobalEvents.agarrao_rodando and not is_instance_valid(rig_solto):
		_abrir_rig_solto()
	etiqueta.text = "1..0 animacao   M mordida   A arremesso   R recomeca\n" \
			+ "vida %d   agarrao=%s   cutscene=%s" % [
				jogador.current_health, GlobalEvents.agarrao_rodando,
				GlobalEvents.in_cutscene]


# ---------------------------------------------------------------------------
# dubles
# ---------------------------------------------------------------------------

## Copia o que importa do player.tscn de verdade: a capsula com a ORIGEM NO
## MEIO (nao nos pes) e o marcador de camera de 1a pessoa. Sao esses dois
## numeros que o player_grab.gd le' para saber onde estao os olhos e a que
## altura pousar o corpo — um duble com a origem nos pes esconderia justamente
## o erro que enterrava metade do Maycow no chao.
class _FalsoPlayer extends CharacterBody3D:
	const ALTURA_CAPSULA := 2.0
	var max_health: int = 100
	var current_health: int = 100
	var invulnerable: bool = false
	var is_using_ultimate: bool = false
	var is_teleporting_enemies: bool = false
	var is_playing_return_effect: bool = false
	var modelo_visual: Node3D
	var camera_first_person_marker: Marker3D
	var camera_third_person_marker: Marker3D
	var camera_third_person: Camera3D

	func _ready() -> void:
		add_to_group("player")
		var forma := CollisionShape3D.new()
		var capsula := CapsuleShape3D.new()
		capsula.height = ALTURA_CAPSULA
		capsula.radius = 0.5
		forma.shape = capsula
		add_child(forma)

		var corpo := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.5, 1.7, 0.3)
		corpo.mesh = caixa
		corpo.position = Vector3(0.0, -0.1, 0.0)
		add_child(corpo)
		modelo_visual = corpo

		camera_first_person_marker = Marker3D.new()
		camera_first_person_marker.position = Vector3(0.0, 0.495, 0.0)
		add_child(camera_first_person_marker)

		camera_third_person_marker = Marker3D.new()
		camera_third_person_marker.position = Vector3(0.0, 1.0, 3.5)
		add_child(camera_third_person_marker)
		camera_third_person = Camera3D.new()
		add_child(camera_third_person)
		camera_third_person.global_position = camera_third_person_marker.global_position
		camera_third_person.look_at(global_position + Vector3.UP * 0.3)

	func take_damage(quanto: int) -> void:
		current_health = maxi(current_health - quanto, 0)

	func cutscene_set_hud_enabled(_ligado: bool) -> void:
		pass

	func cutscene_set_camera_current(atual: bool) -> void:
		if atual and is_instance_valid(camera_third_person):
			camera_third_person.make_current()

	func grab_from_touch(quem: Node3D) -> bool:
		var comp := get_node_or_null("PlayerGrab")
		return comp.grab_from_touch(quem) if comp else false


class _FalsoInimigo extends CharacterBody3D:
	var tipo_agarrao: String = "mordida"
	var permite_agarrao: bool = true
	var dead: bool = false
	var cutscene_mode: bool = false
	var animation_tree = null

	func _ready() -> void:
		add_to_group("enemies")
		var forma := CollisionShape3D.new()
		forma.name = "CollisionShape3D"
		var capsula := CapsuleShape3D.new()
		capsula.height = 1.9
		capsula.radius = 0.4
		forma.shape = capsula
		forma.position = Vector3(0.0, 0.95, 0.0)
		add_child(forma)

		var corpo := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.6, 1.9, 0.4)
		corpo.mesh = caixa
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.12, 0.12)
		corpo.material_override = mat
		corpo.position = Vector3(0.0, 0.95, 0.0)
		add_child(corpo)
