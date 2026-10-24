extends Node

## MONTA a corrida pela cidade (scenes/stages/stage_1/corrida_jonny.tscn).
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/igreja/montar_corrida_jonny.tscn
##
## Roda uma vez; depois a fonte e' o .tscn (AnimationPlayer `diretor`,
## animacao `corrida`). Rodar de novo SOBRESCREVE.
##
## Chaves relativas aos palcos (ver corrida_jonny.gd): no palco da igreja o
## Maycow corre pro +Z, saindo da praca; no do hospital o +Z e' a porta e o
## zero e' o pe' da escada.

const SAIDA := "res://scenes/stages/stage_1/corrida_jonny.tscn"
const ATORES := "res://scenes/npcs/igreja/"
const VEL := 4.2

var raiz: Node3D
var a: Animation


func _ready() -> void:
	raiz = Node3D.new()
	raiz.name = "corrida_jonny"
	raiz.set_script(load("res://scripts/stages/stage_1/corrida_jonny.gd"))
	add_child(raiz)
	_montar()
	remove_child(raiz)
	var cena := PackedScene.new()
	cena.pack(raiz)
	print("== gravado ", ResourceSaver.save(cena, SAIDA))
	get_tree().quit()


func _no(tipo, nome: String, pai: Node) -> Node:
	var n: Node = tipo.new()
	n.name = nome
	pai.add_child(n)
	n.owner = raiz
	return n


func _ator(arquivo: String, nome: String, pai: Node) -> Node3D:
	var n: Node3D = load(ATORES + arquivo).instantiate()
	n.name = nome
	pai.add_child(n)
	n.owner = raiz
	(n.get_node("anim") as AnimationPlayer).playback_default_blend_time = 0.25
	return n


func _trilha(tipo: int, caminho: String) -> int:
	var i := a.add_track(tipo)
	a.track_set_path(i, NodePath(caminho))
	return i


func _valor(caminho: String, chaves: Array, discreto := false) -> void:
	var i := _trilha(Animation.TYPE_VALUE, caminho)
	a.value_track_set_update_mode(i, Animation.UPDATE_DISCRETE if discreto else Animation.UPDATE_CONTINUOUS)
	for k in chaves:
		a.track_insert_key(i, k[0], k[1])


func _pos(caminho: String, chaves: Array) -> void:
	var i := _trilha(Animation.TYPE_POSITION_3D, caminho)
	for k in chaves:
		a.position_track_insert_key(i, k[0], k[1])


func _clipe(caminho: String, chaves: Array) -> void:
	var i := _trilha(Animation.TYPE_ANIMATION, caminho + "/anim")
	for k in chaves:
		a.animation_track_insert_key(i, k[0], k[1])


func _som(no: AudioStreamPlayer, chaves: Array) -> void:
	var i := _trilha(Animation.TYPE_AUDIO, String(raiz.get_path_to(no)))
	for t in chaves:
		a.audio_track_insert_key(i, t, no.stream)


func _cam(caminho: String, chaves: Array) -> void:
	var pai := raiz.get_node(caminho.get_base_dir())
	var c := _no(Camera3D, caminho.get_file(), pai) as Camera3D
	c.near = 0.05
	c.far = 400.0
	var ps := []
	var rs := []
	var fs := []
	for k in chaves:
		var b := Basis.looking_at(k[2] - k[1], Vector3.UP)
		ps.append([k[0], k[1]])
		rs.append([k[0], b.get_rotation_quaternion()])
		fs.append([k[0], float(k[3])])
	c.position = chaves[0][1]
	c.basis = Basis(rs[0][1])
	c.fov = chaves[0][3]
	_pos(caminho, ps)
	var i := _trilha(Animation.TYPE_ROTATION_3D, caminho)
	for r in rs:
		a.rotation_track_insert_key(i, r[0], r[1])
	_valor(caminho + ":fov", fs)


func _montar() -> void:
	var pi := _no(Node3D, "palco_igreja", raiz) as Node3D
	pi.editor_description = "Posto na praca da igreja no jogo (+Z = pra onde ele corre)."
	var ph := _no(Node3D, "palco_hospital", raiz) as Node3D
	ph.editor_description = "Posto no pe' da escada do hospital no jogo (+Z = a porta)."
	ph.position = Vector3(40, 0, 0)
	var mA := _ator("maycow_cena.tscn", "MaycowA", pi)
	var jA := _ator("jonny.tscn", "JonnyA", pi)
	var mB := _ator("maycow_cena.tscn", "MaycowB", ph)
	var jB := _ator("jonny.tscn", "JonnyB", ph)
	for par in [[mA, jA], [mB, jB]]:
		par[0].clipe_inicial = &"correr_carregando"
		par[1].clipe_inicial = &"no_colo"
		par[1].sangue = 0.45
		par[1].seguir = NodePath("../" + String(par[0].name))
		par[1].seguir_peso = 1.0
	var colados: Array[NodePath] = [NodePath("palco_igreja/MaycowA"), NodePath("palco_hospital/MaycowB")]
	raiz.colados_no_chao = colados

	var s := _no(Node3D, "sons", raiz)
	var bat := _no(AudioStreamPlayer, "batimento", s) as AudioStreamPlayer
	bat.stream = load("res://assets/sounds/igreja/batimento_rapido.ogg")
	bat.volume_db = -3.0
	var trov := _no(AudioStreamPlayer, "trovao", s) as AudioStreamPlayer
	trov.stream = load("res://assets/sounds/episodios/trailer/storms.mp3")
	var gem := _no(AudioStreamPlayer, "gemido", s) as AudioStreamPlayer
	gem.stream = load("res://assets/sounds/igreja/gemido_jonny.ogg")
	gem.volume_db = -6.0

	var cl := _no(CanvasLayer, "lente", raiz) as CanvasLayer
	cl.layer = 80
	var tela := _no(ColorRect, "tela", cl) as ColorRect
	tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/cutscenes/igreja_lente.gdshader")
	tela.material = m
	var preto := _no(ColorRect, "preto", cl) as ColorRect
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preto.color = Color(0, 0, 0, 0)

	var diretor := _no(AnimationPlayer, "diretor", raiz) as AnimationPlayer
	var lib := AnimationLibrary.new()
	diretor.add_animation_library("", lib)
	a = Animation.new()
	lib.add_animation("corrida", a)

	const T_B := 4.2
	const T_C := 9.6
	const T_FIM := 13.8
	a.length = T_FIM
	_valor(".:barras", [[0.0, 1.0], [T_FIM, 1.0]])
	_valor(".:preto", [[0.0, 1.0], [0.6, 0.0], [12.4, 0.0], [13.5, 1.0]])
	_valor(".:plano", [[0.0, "palco_igreja/cam_a"], [T_B, "palco_hospital/cam_b"],
		[T_C, "palco_hospital/cam_c"]], true)
	_valor("palco_igreja:visible", [[0.0, true], [T_B, false]], true)
	_valor("palco_hospital:visible", [[0.0, false], [T_B, true]], true)
	_clipe("palco_igreja/MaycowA", [[0.0, "correr_carregando"]])
	_clipe("palco_igreja/JonnyA", [[0.0, "no_colo"]])
	_clipe("palco_hospital/MaycowB", [[T_B, "correr_carregando"]])
	_clipe("palco_hospital/JonnyB", [[T_B, "no_colo"]])
	_pos("palco_igreja/MaycowA", [[0.0, Vector3(0, 0, 0)], [T_B, Vector3(0, 0, VEL * T_B)]])
	var zb := -1.3 - VEL * (T_C - T_B)
	_pos("palco_hospital/MaycowB", [[T_B, Vector3(0.3, 0, zb)], [T_C, Vector3(0.3, 0, -1.3)],
		[T_FIM, Vector3(0.0, 0, -1.3 + VEL * 0.85 * (T_FIM - T_C))]])
	_som(bat, [0.0])
	_som(trov, [1.2])
	_som(gem, [6.0])
	# relampago: a lente pisca branco-azulado
	var tela_i := _trilha(Animation.TYPE_VALUE, "lente/tela:material:shader_parameter/flash")
	for k in [[0.0, 0.0], [1.3, 0.0], [1.35, 0.55], [1.5, 0.1], [1.6, 0.45], [2.1, 0.0]]:
		a.track_insert_key(tela_i, k[0], k[1])

	# camera A: parada na frente dele, ele vem na direcao dela e passa
	var olho_a := func(t): return Vector3(0, 1.25, VEL * t)
	_cam("palco_igreja/cam_a", [[0.0, Vector3(1.4, 1.0, 19.5), olho_a.call(0.0), 32.0],
		[2.5, Vector3(1.4, 1.0, 19.5), olho_a.call(2.5), 34.0],
		[T_B, Vector3(1.6, 1.05, 19.2), olho_a.call(T_B), 40.0]])
	# camera B: na escada do hospital, teleobjetiva, ele vindo de longe
	_cam("palco_hospital/cam_b", [[T_B, Vector3(2.6, 1.6, 2.6), Vector3(0.3, 1.2, zb), 14.0],
		[T_C, Vector3(2.4, 1.5, 2.2), Vector3(0.3, 1.2, -1.3), 34.0]])
	# camera C: atras dele subindo a escada ate' a porta
	var cc := []
	for i in 6:
		var u := i / 5.0
		var t := lerpf(T_C, T_FIM, u)
		var z := lerpf(-1.3, -1.3 + VEL * 0.85 * (T_FIM - T_C), u)
		cc.append([t, Vector3(-0.9, 1.5 + u * 0.7, z - 3.4), Vector3(0.0, 1.2 + u * 0.6, z + 2.0), 46.0])
	_cam("palco_hospital/cam_c", cc)
