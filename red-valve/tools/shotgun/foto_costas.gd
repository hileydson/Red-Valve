extends Node3D

## Fotografa (e MEDE) as costas do Maycow correndo com a cacadeira.
##
##     Godot_v4.6.1 --path red-valve res://tools/shotgun/foto_costas.tscn
##
## Existe por um sintoma especifico: com a arma equipada, a omoplata esquerda
## deforma enquanto ele anda ou corre, e volta ao normal quando ele para. O
## `foto_pose.tscn` nunca pegaria isso — la' o jogador fica parado.
##
## E foto sozinha nao resolve: "deformou" e "nao deformou" numa omoplata sao
## poucos pixels. Entao aqui sai tambem o NUMERO que explica a deformacao — o
## angulo entre o osso do braco e o ombro que o carrega (a "dobra" da junta).
## Pele presa aos dois colapsa quando esse angulo cresce, e e' ele que a
## animacao de corrida faz oscilar.
##
## O retrato sai em tres situacoes, pra separar culpa:
##
##     parado_*    a pose que ja' estava aprovada, como controle
##     correndo_*  o defeito
##     sem_arma_*  a mesma corrida sem a arma: se deformar aqui tambem, o
##                 problema nao e' nosso

const CENA_PLAYER := "res://scenes/player/player.tscn"
const PASTA := "user://fotos_shotgun"

## De onde olhar. O corpo do Maycow olha pro -Z, logo a esquerda dele e' o -X e
## as costas sao o +Z: a omoplata esquerda mora em (-X, +Z).
const CAMERAS := {
	"costas_e": Vector3(-0.95, 0.35, 1.35),
	"tres_quartos": Vector3(1.05, 0.12, -0.95),
}
const ALTURA_DO_PEITO := 0.45
const CAMERA_PRA := Vector3(0.0, -0.04, 0.0)

## Quadros de animacao antes do clique, pra corrida sair do meio do ciclo e nao
## do primeiro quadro (que e' quase o idle).
const QUADROS_PRA_ASSENTAR := 25
## Quantos quadros medir o angulo do ombro em cada situacao.
const QUADROS_PRA_MEDIR := 90

## Um SkeletonModifier3D que nao modifica nada: so' LE'.
##
## Existe porque de fora nao da'. O Skeleton3D guarda as poses antes de rodar a
## pilha de modificadores e as devolve depois de desenhar, entao
## `get_bone_pose()` chamado de qualquer outro no' devolve a pose crua da
## AnimationTree — a primeira versao deste arquivo imprimiu o MESMO angulo com
## arma e sem arma por causa disso. Aqui dentro, e pendurado no fim da pilha, o
## que se le' e' o que foi pra tela.
class Espiao extends SkeletonModifier3D:
	var ossos: PackedStringArray = []
	var maior := {}
	var menor := {}
	var ligado := false

	func zerar() -> void:
		maior.clear()
		menor.clear()

	func _process_modification_with_delta(_delta: float) -> void:
		if not ligado:
			return
		var sk := get_skeleton()
		if sk == null:
			return
		for nome in ossos:
			var i := sk.find_bone(nome)
			if i < 0:
				continue
			var agora := sk.get_bone_pose(i).basis.get_rotation_quaternion()
			var descanso := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			var ang := rad_to_deg(descanso.angle_to(agora))
			maior[nome] = maxf(maior.get(nome, 0.0), ang)
			menor[nome] = minf(menor.get(nome, 999.0), ang)


const OSSOS_DE_OLHO := ["LeftShoulder", "LeftArm", "LeftForeArm",
	"RightShoulder", "RightArm", "Spine2"]

var _espiao: Espiao = null
var _player: Node3D = null
var _hold: Node = null
var _sk: Skeleton3D = null
var _camera: Camera3D = null
var _modelo: Node3D = null
var _de: Vector3 = CAMERAS["costas_e"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	_montar_luz()

	GlobalEvents.is_maycow_normal = true
	SaveManager.add_item("shotgun", 1)
	SaveManager.add_item("shotgun_ammo", 4)
	SaveManager.equip_item("shotgun")

	_player = load(CENA_PLAYER).instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3.ZERO

	_hold = _player.get_node_or_null(
		"maycow_lopes_normal/Armature/Skeleton3D/PlayerShotgunHold")
	_sk = _player.get_node_or_null("maycow_lopes_normal/Armature/Skeleton3D")
	# O quadro se arma pelo MODELO, nao pela raiz do jogador: o
	# `maycow_lopes_normal` anda deslocado da capsula (a secao 8 do player.gd
	# empurra ele pro lado e gira o empurrao junto), e de tras esse deslocamento
	# joga o Maycow pra fora do quadro.
	_modelo = _player.get_node_or_null("maycow_lopes_normal")
	if _hold == null or _sk == null:
		push_error("foto_costas: nao achei o esqueleto ou o PlayerShotgunHold")
		get_tree().quit(1)
		return

	# No FIM da pilha: o `PlayerShotgunHold` ja' escreveu quando este rodar.
	_espiao = Espiao.new()
	_espiao.ossos = OSSOS_DE_OLHO
	_sk.add_child(_espiao)

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()

	await _situacao("parado", "idle", true)
	await _situacao("correndo", "run", true)
	await _situacao("andando", "walk", true)
	SaveManager.unequip_item("shotgun")
	await _situacao("sem_arma", "run", false)

	print("== fotos em %s ==" % ProjectSettings.globalize_path(PASTA))
	get_tree().quit()


## Uma animacao rodando: mede o angulo do ombro por um ciclo e tira dois
## retratos (costas e tres-quartos).
func _situacao(nome: String, anim: String, com_arma: bool) -> void:
	var alvo: Vector3 = _player.global_position + Vector3(0, 1.4, -40.0)
	_espiao.zerar()
	_espiao.ligado = false

	for i in QUADROS_PRA_MEDIR:
		if _player.playback:
			_player.playback.travel(anim)
		if com_arma:
			_hold.mirar(false, alvo)
		_enquadrar()
		# A medida sai DEPOIS do desenho, e nao depois do `process_frame`: o
		# SkeletonModifier3D escreve os ossos no fim do quadro, e ler antes
		# disso devolve a pose crua da AnimationTree — o mesmo numero com arma
		# e sem arma, que foi exatamente o que a primeira versao imprimiu.
		await RenderingServer.frame_post_draw
		# So' depois de assentar: os primeiros quadros ainda sao a pose subindo.
		_espiao.ligado = i >= QUADROS_PRA_ASSENTAR

	print("  -- %s --" % nome)
	for osso in OSSOS_DE_OLHO:
		var lo: float = _espiao.menor.get(osso, 0.0)
		var hi: float = _espiao.maior.get(osso, 0.0)
		print("     %-14s %5.1f a %5.1f graus do descanso   (balanco %5.1f)"
			% [osso, lo, hi, hi - lo])

	for vista in ["costas_e", "tres_quartos"]:
		_de = CAMERAS[vista]
		_enquadrar()
		await RenderingServer.frame_post_draw
		var caminho := "%s/costas_%s_%s.png" % [PASTA, nome, vista]
		get_viewport().get_texture().get_image().save_png(caminho)


func _montar_luz() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	sol.light_energy = 1.5
	add_child(sol)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.31, 0.34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.60)
	env.ambient_light_energy = 1.0
	ambiente.environment = env
	add_child(ambiente)


func _enquadrar() -> void:
	var base: Vector3 = _modelo.global_position if _modelo != null \
		else _player.global_position
	var centro := Vector3(base.x, _player.global_position.y + ALTURA_DO_PEITO, base.z)
	_camera.make_current()
	_camera.global_position = centro + _de
	_camera.look_at(centro + CAMERA_PRA, Vector3.UP)
