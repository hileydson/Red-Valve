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
	var giro := {}
	var rola := {}
	## O quanto o braco esquerdo esta' esticado, em cm, e o quanto ele DA'.
	var estica_min := 999.0
	var estica_max := 0.0
	var alcance := 0.0
	var ligado := false

	func zerar() -> void:
		maior.clear()
		menor.clear()
		giro.clear()
		rola.clear()
		estica_min = 999.0
		estica_max = 0.0

	func _process_modification_with_delta(_delta: float) -> void:
		if not ligado:
			return
		var sk := get_skeleton()
		if sk == null:
			return
		# Braco esticado: se isto encostar no alcance, o IK PAROU de resolver e
		# passou a apontar o braco reto pro alvo. Braco travado reto atravessando
		# o peito e' o pior caso possivel pra malha, e nenhum ajuste de ombro
		# conserta — o que conserta e' aproximar a mao.
		var i_b := sk.find_bone("LeftArm")
		var i_m := sk.find_bone("LeftHand")
		if i_b >= 0 and i_m >= 0:
			var d := sk.get_bone_global_pose(i_b).origin.distance_to(
				sk.get_bone_global_pose(i_m).origin)
			estica_min = minf(estica_min, d)
			estica_max = maxf(estica_max, d)
			alcance = sk.get_bone_rest(sk.find_bone("LeftForeArm")).origin.length() \
				+ sk.get_bone_rest(i_m).origin.length()

		for nome in ossos:
			var i := sk.find_bone(nome)
			if i < 0:
				continue
			var agora := sk.get_bone_pose(i).basis.get_rotation_quaternion()
			var descanso := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			var ang := rad_to_deg(descanso.angle_to(agora))
			maior[nome] = maxf(maior.get(nome, 0.0), ang)
			menor[nome] = minf(menor.get(nome, 999.0), ang)
			# O giro do osso separado em DIRECAO e ROLAGEM. Os dois deformam de
			# jeitos diferentes: direcao demais e' braco dentro do tronco;
			# rolagem demais e' o ombro virando pirulito torcido. Sem separar,
			# um numero so' nao diz qual dos dois consertar.
			var delta := (agora * descanso.inverse()).normalized()
			if delta.w < 0.0:
				delta = -delta
			# O eixo tem de estar no MESMO quadro que o delta. O delta esta' no
			# quadro do PAI (multiplicacao pela esquerda) e o eixo sai do
			# descanso do filho, que e' o quadro do proprio osso: sem girar ele
			# pelo descanso, a conta decompoe em volta de uma linha que nao e' o
			# osso, e a "rolagem" que sai nao quer dizer nada.
			var eixo := (descanso * _eixo_do_osso(sk, i)).normalized()
			var proj := delta.x * eixo.x + delta.y * eixo.y + delta.z * eixo.z
			var rolagem := Quaternion(eixo.x * proj, eixo.y * proj,
				eixo.z * proj, delta.w).normalized()
			var direcao := delta * rolagem.inverse()
			giro[nome] = maxf(giro.get(nome, 0.0),
				rad_to_deg(2.0 * acos(clampf(absf(direcao.w), -1.0, 1.0))))
			rola[nome] = maxf(rola.get(nome, 0.0),
				rad_to_deg(2.0 * acos(clampf(absf(rolagem.w), -1.0, 1.0))))

	## O eixo do proprio osso: a direcao em que o filho dele sai.
	func _eixo_do_osso(sk: Skeleton3D, i: int) -> Vector3:
		for f in sk.get_bone_children(i):
			var v: Vector3 = sk.get_bone_rest(f).origin
			if v.length_squared() > 0.0001:
				return v.normalized()
		return Vector3.RIGHT


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

	if OS.get_cmdline_user_args().has("--varrer"):
		await _varrer()
		get_tree().quit()
		return

	await _situacao("parado", "idle", true)
	await _situacao("correndo", "run", true)
	await _situacao("andando", "walk", true)
	SaveManager.unequip_item("shotgun")
	await _situacao("sem_arma", "run", false)

	print("== fotos em %s ==" % ProjectSettings.globalize_path(PASTA))
	get_tree().quit()


## VARREDURA: onde a mao esquerda ainda ALCANCA o cano.
##
## O `APOIO_NO_MODELO.x` decide em que ponto do cano a mao esquerda fecha, e e'
## a unica coisa que muda o vao entre as maos sem mexer na arma — a arma esta'
## presa na mao direita, entao a pose que o jogador afinou nao se move nem um
## milimetro com isto.
##
## Imprime, pra cada valor, o quanto o braco precisa esticar. Passou do alcance,
## o IK desiste e deixa o braco reto: e' isso que deforma a omoplata.
func _varrer() -> void:
	var alvo: Vector3 = _player.global_position + Vector3(0, 1.4, -40.0)
	print("  apoio.x   vao(cm)   estica parado   estica correndo   (braco da' 49)")
	for passo in 9:
		var x := -0.40 + passo * 0.05
		for anim in ["idle", "run"]:
			_hold._apoio.x = x
			_espiao.zerar()
			_espiao.ligado = false
			for i in 60:
				if _player.playback:
					_player.playback.travel(anim)
				_hold._apoio.x = x
				_hold.mirar(false, alvo)
				await RenderingServer.frame_post_draw
				_espiao.ligado = i >= 30
			if anim == "idle":
				var vao: float = (_hold._cabo.x - x) * _hold._escala
				printf_linha(x, vao, _espiao.estica_max)
			else:
				print("      %.1f" % _espiao.estica_max)


func printf_linha(x: float, vao: float, estica: float) -> void:
	printraw("  %6.3f    %5.1f      %5.1f" % [x, vao, estica])


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
			# O harness congela a fisica do jogador, entao o `player.gd` nunca
			# avisa que ele esta' correndo — aqui a gente avisa.
			_hold.correr(anim == "run")
		_enquadrar()
		# A medida sai DEPOIS do desenho, e nao depois do `process_frame`: o
		# SkeletonModifier3D escreve os ossos no fim do quadro, e ler antes
		# disso devolve a pose crua da AnimationTree — o mesmo numero com arma
		# e sem arma, que foi exatamente o que a primeira versao imprimiu.
		await RenderingServer.frame_post_draw
		# So' depois de assentar: os primeiros quadros ainda sao a pose subindo.
		_espiao.ligado = i >= QUADROS_PRA_ASSENTAR

	# A boca do cano no espaco do JOGADOR: X negativo e' pra esquerda dele, que
	# e' o lado pra onde a ponta recolhe na corrida.
	var boca := Vector3.ZERO
	if com_arma:
		boca = _player.global_transform.affine_inverse() * _hold.boca_do_cano()
	print("  -- %s --   braco E esticado %.1f a %.1f cm  (o braco da' %.1f)   boca do cano x=%.2f z=%.2f"
		% [nome, _espiao.estica_min, _espiao.estica_max, _espiao.alcance,
			boca.x, boca.z])
	for osso in OSSOS_DE_OLHO:
		var lo: float = _espiao.menor.get(osso, 0.0)
		var hi: float = _espiao.maior.get(osso, 0.0)
		print("     %-14s %5.1f a %5.1f do descanso   (balanco %5.1f)   direcao %5.1f  rolagem %5.1f"
			% [osso, lo, hi, hi - lo, _espiao.giro.get(osso, 0.0),
				_espiao.rola.get(osso, 0.0)])

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
