extends Node

## Confere a cena unica de autoria/runtime, as pegadas e os eventos de recarga.
## Godot --headless --path red-valve res://tools/maos_fp/conferir_maos_armadas.tscn
## Usa inventario SOMENTE em memoria. Nao carrega fase nem grava saves.
const CENA := "res://scenes/player/first_person_view/mao_armada.tscn"
var falhas := 0
var rig: Node3D
var ap: AnimationPlayer
var jogador: JogadorDeProva
var combate: Node
var eventos: Array[String] = []

class JogadorDeProva extends CharacterBody3D:
	var is_first_person := true
	var is_reloading := false
	var is_magic_attacking := false
	var cogblade_melee_active := false
	var is_using_ultimate := false
	var clip_pistol_ammo := 0
	var max_clip_pistol := 7
	var clip_shotgun_ammo := 0
	var max_clip_shotgun := 2
	var gun_load := AudioStreamPlayer.new()
	var shotgun_break := AudioStreamPlayer.new()
	var shotgun_load_shell := AudioStreamPlayer.new()
	var shotgun_close := AudioStreamPlayer.new()
	var capsula_shotgun_scene := preload("res://scenes/effects/capsula_shotgun.tscn")
	func _maos_fp() -> Node:
		return get_node("Camera3D/hand_with_pistol/rig")
	func update_ammo_ui() -> void:
		pass

func _ok(condicao: bool, mensagem: String) -> void:
	if not condicao: falhas += 1
	print(("ok " if condicao else "FALHA ") + mensagem)

func _ready() -> void:
	GlobalEvents.is_maycow_normal = false
	SaveManager.inventory_normal = [{"id":"pistol","amount":1},{"id":"shotgun","amount":1},{"id":"pistol_ammo","amount":20},{"id":"shotgun_ammo","amount":8}]
	SaveManager.inventory_combat = SaveManager.inventory_normal.duplicate(true)
	SaveManager.equipped_items = ["cogblade","pistol"]
	jogador = JogadorDeProva.new()
	jogador.name = "JogadorDeProva"
	add_child(jogador)
	for audio in [jogador.gun_load, jogador.shotgun_break, jogador.shotgun_load_shell, jogador.shotgun_close]: jogador.add_child(audio)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	jogador.add_child(camera)
	var mao: Node3D = load(CENA).instantiate()
	mao.name = "hand_with_pistol"
	camera.add_child(mao)
	mao.set_process(false)
	rig = mao.get_node("rig")
	rig.set_process(false)
	ap = rig.get_node("AnimationPlayer")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	combate = Node.new()
	combate.set_script(load("res://scripts/player/player_combat.gd"))
	jogador.add_child(combate)
	rig.recarga_evento.connect(func(evento: String): eventos.append(evento))
	await get_tree().process_frame
	var previa: Camera3D = mao.get_node("PreviaDaTela")
	_ok(previa.transform.is_equal_approx(Transform3D.IDENTITY), "PreviaDaTela na origem do olho")
	_ok(is_equal_approx(previa.fov,75.0), "mesmo FOV neutro de primeira pessoa")
	for item in ["pistol","shotgun"]:
		_pose(item, ("pistola" if item == "pistol" else "shotgun") + "_idle",0)
		var modelo: Node3D = rig._armas[item].get_node("Movimento/Modelo")
		var caminho_modelo := modelo.scene_file_path
		_ok(not caminho_modelo.is_empty(), "%s usa modelo persistido na cena" % item)
		var pior := 0.0
		for acao in ["idle","tiro","recarga","guardar","sacar"]:
			var clipe: String = ("pistola" if item == "pistol" else "shotgun") + "_" + acao
			_ok(ap.has_animation(clipe), clipe + " editavel")
			var anim := ap.get_animation(clipe)
			for k in 41:
				_pose(item,clipe,anim.length*float(k)/40.0)
				var alvo: Node3D = rig._armas[item].get_node("Movimento/PegadaDireita")
				var sk: Skeleton3D = rig.get_node("Malhas/Armature_dir/Skeleton3D")
				pior = maxf(pior,(sk.global_transform * sk.get_bone_global_pose(1).origin).distance_to(alvo.global_position))
		_ok(pior < 0.0001, "%s: pulso acompanha pegada em todos os clipes (%.6f m)" % [item,pior])
		# Mover a arma na cena leva a mao junto sem offsets privados de gameplay.
		_pose(item,("pistola" if item == "pistol" else "shotgun")+"_idle",0)
		var arma: Node3D = rig._armas[item]
		var antes: Vector3 = rig.boca_do_cano()
		arma.position.x += 0.04
		rig._atualizar_pose()
		_ok(absf(rig.boca_do_cano().x-antes.x-0.04)<0.0001,"ajuste visual de %s reflete no runtime"%item)
		arma.position.x -= 0.04
	_conferir_encaixes()
	await _recarga("pistol",7)
	await _recarga("shotgun",2)
	# A reserva de um cartucho nao cria um segundo cartucho fantasma.
	SaveManager.inventory_normal = [{"id":"shotgun","amount":1},{"id":"shotgun_ammo","amount":1}]
	SaveManager.inventory_combat = SaveManager.inventory_normal.duplicate(true)
	await _recarga("shotgun",1)
	# As falanges mantem seu comprimento na transicao da cogblade.
	var magica: Node3D = load("res://scenes/player/first_person_view/mao_magica.tscn").instantiate()
	camera.add_child(magica)
	rig._mao_magica = magica
	for peso in [0.0,0.25,0.5,0.75,1.0]:
		rig._peso_magia = peso
		rig._atualizar_pose()
		var sk: Skeleton3D = rig.get_node("Malhas/Armature/Skeleton3D")
		var integro := true
		for i in range(2,17):
			integro = integro and sk.get_bone_pose_position(i).is_equal_approx(sk.get_bone_rest(i).origin)
		_ok(integro,"falanges rigidas durante gesto magico %.2f"%peso)
	print("== FP: %d falhas ==" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)

func _pose(item: String, nome: String, tempo: float) -> void:
	rig._na_mao = item
	rig._mostrar_arma(item)
	ap.play(nome)
	ap.seek(tempo,true)
	for arma in rig.get_node("Armas").get_children(): arma._process(0.0)
	rig._atualizar_pose()

func _conferir_encaixes() -> void:
	for par in [[2.16,1],[3.024,2]]:
		_pose("shotgun","shotgun_recarga",par[0]-0.00001)
		var na_mao: Node3D = rig.get_node("AjusteEsquerdo/ControleEsquerdo/CartuchoNaMao")
		var na_camara: Node3D = rig.get_node("Armas/Shotgun/Movimento/Articulacao/Camara%d/Cartucho"%par[1])
		_ok(na_mao.global_position.distance_to(na_camara.global_position)<0.001,"cartucho %d chega a camara sem salto"%par[1])
	_pose("pistol","pistola_recarga",2.04-0.00001)
	var na_mao: Node3D = rig.get_node("AjusteEsquerdo/ControleEsquerdo/CarregadorNaMao")
	var na_arma: Node3D = rig.get_node("Armas/Pistola/Movimento/Carregador")
	_ok(na_mao.global_position.distance_to(na_arma.global_position)<0.001,"carregador encaixa sem salto")
	_ok(na_mao.global_basis.orthonormalized().is_equal_approx(na_arma.global_basis.orthonormalized()),"carregador orientado como o alojamento")

func _recarga(item: String, esperado: int) -> void:
	SaveManager.equipped_items = ["cogblade",item]
	jogador.clip_pistol_ammo = 0
	jogador.clip_shotgun_ammo = 0
	eventos.clear()
	_pose(item,("pistola" if item == "pistol" else "shotgun")+"_idle",0)
	combate.reload()
	for i in 190:
		ap.advance(0.02)
		for arma in rig.get_node("Armas").get_children(): arma._process(0.0)
		rig._atualizar_pose()
		await get_tree().process_frame
	var carga := jogador.clip_pistol_ammo if item == "pistol" else jogador.clip_shotgun_ammo
	_ok(carga == esperado,"%s recebe %d municoes pelos eventos do clipe (%s)" % [item,esperado,str(eventos)])
	_ok(not jogador.is_reloading,"%s libera o controle ao concluir"%item)
	if item == "shotgun":
		_ok(eventos.count("cartucho")==esperado,"somente os cartuchos disponiveis sao inseridos")
