extends Node3D

## Fotografa o Maycow segurando a cacadeira, sem precisar jogar ate' o hospital.
##
##     Godot_v4.6.1 --path red-valve res://tools/shotgun/foto_pose.tscn
##
## (SEM --headless: sem renderizador nao ha' imagem pra salvar.)
##
## A pose das maos numa arma longa nao da' pra conferir lendo numero: ou a mao
## esquerda esta' EM CIMA do fore-end ou esta' do lado dele, e a diferenca sao
## dois centimetros que so' aparecem na tela. Chegar ate' la' no jogo — pegar a
## arma no balcao do hospital, equipar, mirar, gastar os dois tiros pra ver a
## recarga — sao uns tres minutos por tentativa.
##
## Entao aqui o jogador nasce num fundo vazio, com a arma ja' equipada, e a
## recarga e' CONGELADA em cada instante interessante: em vez de esperar o
## gesto acontecer, o script escreve o relogio dele e tira o retrato.
##
## O que sai em `FOTOS`: a pose de mira, e o gesto de recarga em cinco quadros.
## Ajustou constante no `player_shotgun_hold.gd`? Roda de novo e compara.

const CENA_PLAYER := "res://scenes/player/player.tscn"
const PASTA := "user://fotos_shotgun"

## (nome do arquivo, instante da recarga, de onde olhar).
##
## O instante -1 e' PORTE (equipada, sem mirar) e -2 e' MIRA. Os dois sao pose
## de verdade agora: a cacadeira nunca sai das duas maos, entao "nao mirando"
## nao e' mais "bracos soltos", e' outra pose que tambem precisa de retrato.
##
## A mira e' fotografada de tres-quartos, que e' como o jogo ve' o Maycow.
##
## A recarga NAO, e nem de frente: o Maycow olha pro -Z e a arma aponta pra
## onde ele olha, entao tanto o tres-quartos quanto a frente veem a arma quase
## pela boca do cano — a dobra, que e' justo o que se quer conferir, some em
## perspectiva. So' de LADO ela aparece de perfil.
const FOTOS := [
	["01_porte", -1.0, "tres_quartos"],
	["02_porte_lado", -1.0, "lado"],
	["03_mira", -2.0, "tres_quartos"],
	["04_abrindo", 0.15, "lado"],
	["05_virada", 0.31, "lado"],
	["06_cartucho_1", 0.60, "lado"],
	["07_volta_ao_cinto", 0.68, "lado"],
	["08_cartucho_2", 0.84, "lado"],
	["09_fechando", 0.93, "lado"],
]

## De onde a camera olha, em relacao ao peito do Maycow — e o que ela mira.
##
## O alvo e' o PEITO mais um empurrao pequeno, e nao um ponto a' frente dele:
## o `look_at` poe o alvo no centro exato do quadro, entao qualquer coisa
## somada aqui sai do enquadramento na mesma medida. Foi assim que a primeira
## versao deixou o Maycow no rodape com meia tela de fundo cinza em cima.
## O corpo do Maycow olha pro -Z, entao +X / -Z e' um tres-quartos de FRENTE:
## de tras nao se ve' arma nenhuma.
const CAMERAS := {
	"tres_quartos": Vector3(1.05, 0.12, -0.95),
	"lado": Vector3(1.40, 0.10, 0.05),
}
const CAMERA_PRA := Vector3(0.0, -0.04, 0.0)

var _de := Vector3.ZERO
## Quantos quadros esperar em cada pose antes do clique. A pose entra por
## `SUBIDA` (0,14 s) e as maos fecham por `FECHA_MAO` (0,18 s): menos que isso
## fotografa o braco no meio do caminho.
const QUADROS_PRA_ASSENTAR := 25

var _player: Node3D = null
var _hold: Node = null
var _camera: Camera3D = null


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

	# Sem chao, o jogador cai pra sempre e a foto sai borrada de movimento.
	# Congelar a fisica dele e' mais simples que construir um tablado.
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3.ZERO

	_hold = _player.get_node_or_null(
		"maycow_lopes_normal/Armature/Skeleton3D/PlayerShotgunHold")
	if _hold == null:
		push_error("foto_pose: nao achei o PlayerShotgunHold")
		get_tree().quit(1)
		return

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()

	for foto in FOTOS:
		_de = CAMERAS[String(foto[2])]
		await _retratar(String(foto[0]), float(foto[1]))

	print("== %d fotos em %s ==" % [FOTOS.size(), ProjectSettings.globalize_path(PASTA)])
	get_tree().quit()


func _montar_luz() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, 145.0, 0.0)
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


func _retratar(nome: String, instante: float) -> void:
	var recarregando := instante >= 0.0
	var mirando := instante <= -1.5
	# Um alvo bem longe e' o que faz o cano ficar horizontal; perto, o braco
	# aponta pra baixo e a foto nao mostra a pose de tiro.
	var alvo: Vector3 = _player.global_position + Vector3(0, 1.4, -40.0)

	for i in QUADROS_PRA_ASSENTAR:
		_hold.mirar(mirando, alvo)
		if recarregando:
			# Escrever o relogio da recarga todo quadro CONGELA o gesto: o
			# modificador ate' avanca ele, mas o proximo quadro o traz de volta.
			_hold._recarregando = true
			_hold._recarga_total = 1000.0
			_hold._recarga = instante
		_enquadrar()
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	var caminho := "%s/%s.png" % [PASTA, nome]
	imagem.save_png(caminho)
	# O quanto a arma esta' aberta vai IMPRESSO, e nao so' fotografado: 16
	# graus de dobra numa arma vista meio de lado sao dois pixels, e olhar a
	# foto e achar que "parece fechada" nao distingue "abriu pouco" de "nao
	# abriu". O numero distingue.
	print("  %s   aberta %3.0f%%"
		% [ProjectSettings.globalize_path(caminho), _hold.quanto_aberta() * 100.0])

	_hold._recarregando = false
	_hold._recarga = 0.0


## A camera mira a ALTURA DO PEITO medida da raiz do jogador, e nao o osso do
## peito.
##
## Tentar pelo osso e' a armadilha classica deste rig: `get_bone_global_pose()`
## devolve CENTIMETROS no espaco do esqueleto, e o esqueleto esta' 180 graus
## virado e um metro deslocado do corpo que aparece na tela (quem carrega essa
## transformacao e' a malha `char1`). Multiplicar pela global do ESQUELETO poe o
## ponto um metro fora — e' o mesmo motivo pelo qual a arma nao e' um
## BoneAttachment3D. Um numero fixo acerta mais.
## Medido do ORIGEM do CharacterBody3D, que fica no meio da capsula (mais ou
## menos na cintura) e nao nos pes — dai' um numero pequeno.
const ALTURA_DO_PEITO := 0.45


func _enquadrar() -> void:
	var centro: Vector3 = _player.global_position + Vector3(0, ALTURA_DO_PEITO, 0)
	# `make_current()` todo quadro, e nao uma vez no `_ready`: o proprio
	# `player.gd` chama `camera_third_person.make_current()` dentro do `_ready`
	# dele, que termina DEPOIS deste — sem reivindicar a camera a cada quadro, a
	# foto sai pela camera de jogo, enquadrando o nada.
	_camera.make_current()
	_camera.global_position = centro + _de
	_camera.look_at(centro + CAMERA_PRA, Vector3.UP)
