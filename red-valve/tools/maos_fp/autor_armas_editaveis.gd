extends SceneTree

## Gerador inicial de autoria, NAO roda no jogo. Depois da primeira geracao,
## edite a cena e os clipes no AnimationPlayer; rodar isto de novo os substitui.
## Godot --headless --path red-valve --script res://tools/maos_fp/autor_armas_editaveis.gd
const BASE := "res://assets/3d_model/player/"
const BIB := BASE + "hands/maos_fp/armas_fp_clipes.tres"
const CENA := "res://scenes/player/first_person_view/mao_armada.tscn"
var cena: Node3D
var rig: Node3D
var lib := AnimationLibrary.new()
var ap: AnimationPlayer
var controle = load("res://scripts/player/mao_fp_controle.gd")
var config = load("res://scripts/player/arma_fp_config.gd")
var base_arma := {}
var armas := {}
var esquerda: Marker3D
var viseira: Camera3D
var antigo: Node3D

func _initialize():
	call_deferred("_gerar")

func no(nome: String, pai: Node, tipo = Node3D) -> Node:
	var n: Node = tipo.new()
	n.name = nome
	if n is Marker3D: n.gizmo_extents = 0.02
	pai.add_child(n)
	n.owner = cena
	return n

func instancia(caminho: String, nome: String, pai: Node) -> Node3D:
	var n: Node3D = load(caminho).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	n.name = nome
	pai.add_child(n)
	n.owner = cena
	return n

func _gerar():
	antigo = load(CENA).instantiate()
	cena = Node3D.new()
	cena.name = "MaoArmada"
	cena.editor_description = "Primeira pessoa: PreviaDaTela e o olho do jogo. Selecione rig para escolher arma, acao e instante; edite os clipes no AnimationPlayer. F6: F1 pistola, F2 shotgun, R recarga, clique tiro. Armas contem os modelos usados no jogo; Malhas e somente o rig importado."
	cena.set_script(load("res://scripts/player/hand_with_pistol.gd"))
	rig = no("rig", cena)
	rig.editor_description = "Previa: escolha arma/acao/instante no inspetor. No AnimationPlayer, edite Movimento (gesto), ControleEsquerdo (mao livre), Articulacao (dobra), e as chaves evento_recarga (som e municao)."
	var malhas := instancia(BASE + "hands/maos_fp/maos_fp.glb", "Malhas", rig)
	malhas.scale = Vector3.ONE * 0.17
	cena.set_editable_instance(malhas, true)
	for p in ["Armature/Skeleton3D/mao_esq", "Armature_dir/Skeleton3D/mao_dir"]:
		var m: MeshInstance3D = malhas.get_node(p)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.set_surface_override_material(0, load(BASE + "hands/maos_fp/maos_fp_pele_magica.tres" if "esq" in p else BASE + "hands/maos_fp/maos_fp_pele.tres"))
	no("Armas", rig)
	var ajuste := no("AjusteEsquerdo", rig)
	esquerda = no("ControleEsquerdo", ajuste, Marker3D)
	esquerda.set_script(controle)
	esquerda.position = Vector3(-0.23, -0.19, -0.32)
	esquerda.basis = orientacao(Vector3(0.15, 0.40, -1), Vector3(1, 0, 0.2))
	for dedo in ["indicador", "medio", "anelar", "mindinho"]:
		esquerda.set(dedo, {"indicador":Vector3(12,22,12), "medio":Vector3(18,30,16), "anelar":Vector3(26,38,22), "mindinho":Vector3(35,45,25)}[dedo])
	esquerda.polegar = Vector3(14,18,10)
	var cartucho := instancia(BASE + "the_negotiator_V3/cartridge/the_negotiator_V3_bullet.glb", "CartuchoNaMao", esquerda)
	cartucho.scale = Vector3.ONE * 0.0366
	cartucho.position = Vector3(0.0, 0.02, -0.12)
	cartucho.rotation_degrees.y = -90.0
	cartucho.visible = false
	# A mesma municao que sai da arma aparece entre o polegar e os dedos.
	var pente := no("CarregadorNaMao", esquerda, MeshInstance3D)
	pente.mesh = carregador_mesh()
	pente.position = Vector3(0, 0.025, -0.07)
	pente.visible = false
	montar_arma("Pistola", "pistol", "pistola", BASE + "the_negotiator_V1/pistola_fp.tscn", 0.145, Vector3(0.60,-0.28,0), Vector3(0.18,-0.17,-0.36), Vector3(8,20,-5))
	montar_arma("Shotgun", "shotgun", "shotgun", BASE + "the_negotiator_V3/the_negotiator_V3_dobravel.glb", 0.30, Vector3(0.50,-0.03,0), Vector3(0.22,-0.22,-0.42), Vector3(9,20,-7))
	ap = no("AnimationPlayer", rig, AnimationPlayer)
	for item in ["pistol", "shotgun"]:
		anim_idle(item)
		anim_tiro(item)
		anim_troca(item, true)
		anim_troca(item, false)
	anim_recarga_shotgun()
	anim_recarga_pistola()
	ap.add_animation_library("", lib)
	ResourceSaver.save(lib, BIB)
	# Recarrega como recurso externo, para o AnimationPlayer salvar clipes editaveis.
	ap.remove_animation_library("")
	ap.add_animation_library("", load(BIB))
	viseira = no("PreviaDaTela", cena, Camera3D)
	viseira.set_script(load("res://scripts/player/previa_da_tela.gd"))
	viseira.fov = 75.0
	viseira.near = 0.05
	viseira.current = true
	for nome in ["faisca", "fire"]:
		var fx = antigo.get_node(nome).duplicate()
		cena.add_child(fx)
		fx.owner = cena
		if nome == "faisca": fx.speed_scale = 1.0
	# A mesma pose de idle ja fica salva na cena para abrir o editor corretamente.
	# O @tool continua atualizando os ossos quando os controles sao movidos.
	rig.set_script(load("res://scripts/player/maos_fp_armas.gd"))
	root.add_child(cena)
	rig.set_process(false)
	await process_frame
	rig._na_mao = "shotgun"
	rig._mostrar_arma("shotgun")
	ap.play("shotgun_idle")
	ap.seek(0, true)
	ap.pause()
	rig._atualizar_pose()
	await process_frame
	var pacote := PackedScene.new()
	var err := pacote.pack(cena)
	if err == OK: err = ResourceSaver.save(pacote, CENA)
	if err == OK: ResourceSaver.set_uid(CENA, ResourceUID.text_to_id("uid://bbaf3oui2vnkx"))
	print("Autoria FP salva: ", err, " / ",lib.get_animation_list())
	antigo.free()
	quit(err)

func orientacao(dedos: Vector3, palma: Vector3) -> Basis:
	var z := -dedos.normalized()
	var x := palma.cross(z).normalized()
	return Basis(x, z.cross(x).normalized(), z)

func montar_arma(nome: String, item: String, prefixo: String, caminho: String, escala: float, cabo: Vector3, pos: Vector3, giro: Vector3):
	var arma := no(nome, rig.get_node("Armas"))
	arma.set_script(config)
	arma.item_id = item
	arma.prefixo = prefixo
	arma.usa_apoio = item == "shotgun"
	arma.position = pos
	arma.rotation_degrees = giro
	arma.visible = item == "shotgun"
	armas[item] = arma
	base_arma[item] = arma.transform
	var movimento := no("Movimento", arma)
	var modelo := instancia(caminho, "Modelo", movimento)
	modelo.rotation_degrees.y = -90.0
	modelo.scale = Vector3.ONE * escala
	modelo.position = -(modelo.basis * cabo)
	var pegada := no("PegadaDireita", movimento, Marker3D)
	pegada.set_script(controle)
	pegada.editor_description = "Pulso direito. Mover ou girar ajusta a pegada no editor e no jogo. -Z segue os dedos; +Y aponta para a palma. As componentes dos dedos sao as tres falanges em graus."
	var d := (Basis(Vector3.UP, -PI/2) * Vector3(-0.92,-0.39,0)).normalized()
	var p := Vector3.LEFT
	pegada.position = -d * 0.072 - p * 0.036 + Vector3(0,0,-0.01)
	pegada.basis = orientacao(d, p)
	pegada.abertura = Vector3(30, 0, -3)
	pegada.indicador = Vector3(12, 55, 35)
	pegada.medio = Vector3(80, 20, 25)
	pegada.anelar = Vector3(82, 18, 25)
	pegada.mindinho = Vector3(85, 15, 20)
	no("Cabo", movimento, Marker3D)
	var boca := no("BocaDoCano", movimento, Marker3D)
	boca.position = modelo.transform * (Vector3(-0.93,-0.01,0) if item == "shotgun" else Vector3(-0.95,0.50,0))
	var ejecao := no("Ejecao", movimento, Marker3D)
	ejecao.position = Vector3(0.018, 0.07, -0.025)
	if item == "shotgun":
		var articulacao := no("Articulacao", movimento)
		var pivot := Vector3(-0.030, 0.057, 0)
		articulacao.position = modelo.transform * pivot
		boca.owner = null
		boca.reparent(articulacao, false)
		boca.owner = cena
		boca.position -= articulacao.position
		var apoio := no("ApoioEsquerdo", articulacao, Marker3D)
		apoio.set_script(controle)
		apoio.editor_description = "Pulso esquerdo apoiado na telha. Acompanha a articulacao. Durante a recarga, apoio_esquerdo=0 entrega a mao ao ControleEsquerdo."
		var apoio_m := Vector3(-0.27, 0.015, 0)
		var apoio_d := Vector3(0.97, 0.2, -0.1).normalized()
		var apoio_p := Vector3(0.15, 0.9, 0.05).normalized()
		apoio.position = (modelo.basis * (apoio_m - pivot)) - apoio_d * 0.072 - apoio_p * 0.036
		apoio.basis = orientacao(apoio_d, apoio_p)
		apoio.indicador = Vector3(48, 35, 20)
		for i in 2:
			var cam := no("Camara%d" % (i+1), articulacao, Marker3D)
			cam.position = modelo.basis * (Vector3(-0.030,0.127,0.06 if i == 0 else -0.06) - pivot)
			var municao := instancia(BASE + "the_negotiator_V3/cartridge/the_negotiator_V3_bullet.glb", "Cartucho", cam)
			municao.scale = Vector3.ONE * 0.0366
			municao.position.z = -0.035
			municao.rotation_degrees.y = -90
			municao.visible = false
	else:
		var mag := no("Carregador", movimento, MeshInstance3D)
		mag.mesh = carregador_mesh()
		mag.position = Vector3(0, -0.075, 0.015)
		var solto := no("CarregadorSolto", movimento, MeshInstance3D)
		solto.mesh = mag.mesh
		solto.position = mag.position
		solto.visible = false

func carregador_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.024, 0.093, 0.034)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.055, 0.06, 0.065)
	mat.metallic = 0.8
	mat.roughness = 0.45
	mesh.material = mat
	return mesh

func tipo_trilha(caminho: String) -> int:
	if caminho.ends_with(":position"): return Animation.TYPE_POSITION_3D
	if caminho.ends_with(":rotation"): return Animation.TYPE_ROTATION_3D
	return Animation.TYPE_VALUE

func caminho_trilha(caminho: String) -> NodePath:
	return NodePath(caminho.get_slice(":",0) if tipo_trilha(caminho) != Animation.TYPE_VALUE else caminho)

func trilha(a: Animation, caminho: String, chaves: Array, discreta := false):
	var tipo := tipo_trilha(caminho)
	var t := a.add_track(tipo)
	a.track_set_path(t, caminho_trilha(caminho))
	if tipo == Animation.TYPE_VALUE:
		a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE if discreta else Animation.UPDATE_CONTINUOUS)
	elif chaves.size()>2 and (not "recarga" in a.resource_name or caminho == "AjusteEsquerdo/ControleEsquerdo:position"):
		a.track_set_interpolation_type(t,Animation.INTERPOLATION_CUBIC)
	for k in chaves:
		var valor = Quaternion.from_euler(k[1]) if tipo == Animation.TYPE_ROTATION_3D else k[1]
		a.track_insert_key(t, float(k[0]), valor, -1.8 if "recarga" in a.resource_name and tipo != Animation.TYPE_VALUE and a.track_get_interpolation_type(t) == Animation.INTERPOLATION_LINEAR else 1.0)

func arma_path(item: String) -> String:
	return "Armas/" + ("Shotgun" if item == "shotgun" else "Pistola") + "/Movimento"

func novo(item: String, acao: String, tempo: float, laco := false) -> Animation:
	var a := Animation.new()
	a.resource_name = ("shotgun" if item == "shotgun" else "pistola") + "_" + acao
	a.length = tempo
	a.loop_mode = Animation.LOOP_LINEAR if laco else Animation.LOOP_NONE
	lib.add_animation(a.resource_name, a)
	for key in ["pistol", "shotgun"]:
		trilha(a, "Armas/" + ("Pistola" if key == "pistol" else "Shotgun") + ":visible", [[0,key==item]], true)
		trilha(a, arma_path(key) + ":position", [[0,Vector3.ZERO]])
		trilha(a, arma_path(key) + ":rotation", [[0,Vector3.ZERO]])
	trilha(a, ".:pressao_gatilho", [[0,0.0]])
	trilha(a, ".:apoio_esquerdo", [[0,1.0 if item == "shotgun" else 0.0]])
	trilha(a, "AjusteEsquerdo/ControleEsquerdo:position", [[0,esquerda.position]])
	trilha(a, "AjusteEsquerdo/ControleEsquerdo:rotation", [[0,esquerda.rotation]])
	for dedo in ["indicador", "medio", "anelar", "mindinho", "polegar"]:
		trilha(a, "AjusteEsquerdo/ControleEsquerdo:" + dedo, [[0,esquerda.get(dedo)]])
	for path in ["AjusteEsquerdo/ControleEsquerdo/CartuchoNaMao", "AjusteEsquerdo/ControleEsquerdo/CarregadorNaMao", "Armas/Pistola/Movimento/CarregadorSolto"]:
		trilha(a, path + ":visible", [[0,false]], true)
	trilha(a, "Armas/Pistola:recuo_ferrolho", [[0,0.0]])
	trilha(a, "Armas/Pistola/Movimento/Carregador:visible", [[0,true]], true)
	trilha(a, "Armas/Shotgun/Movimento/Articulacao:rotation", [[0,Vector3.ZERO]])
	for i in 2:
		trilha(a, "Armas/Shotgun/Movimento/Articulacao/Camara%d/Cartucho:visible" % (i+1), [[0,false]], true)
	return a

func substituir(a: Animation, caminho: String, chaves: Array, discreta := false):
	var t := a.find_track(caminho_trilha(caminho), tipo_trilha(caminho))
	if t >= 0: a.remove_track(t)
	trilha(a,caminho,chaves,discreta)

func anim_idle(item: String):
	var a := novo(item,"idle",2.8,true)
	substituir(a,arma_path(item)+":position",[[0,Vector3.ZERO],[0.7,Vector3(0.001,0.002,-0.001)],[1.4,Vector3.ZERO],[2.1,Vector3(-0.001,-0.002,0.001)],[2.8,Vector3.ZERO]])

func anim_tiro(item: String):
	var sg := item == "shotgun"
	var tempo := 0.65 if sg else 0.35
	var a := novo(item,"tiro",tempo)
	var p := arma_path(item)
	substituir(a,p+":position",[[0,Vector3.ZERO],[0.045,Vector3(0.004,-0.006,0.055 if sg else 0.025)],[0.12,Vector3(0,-0.002,0.025 if sg else 0.012)],[tempo,Vector3.ZERO]])
	substituir(a,p+":rotation",[[0,Vector3.ZERO],[0.045,Vector3(deg_to_rad(13 if sg else 10),0,deg_to_rad(-3))],[0.14,Vector3(deg_to_rad(5),0,0)],[tempo,Vector3.ZERO]])
	substituir(a,".:pressao_gatilho",[[0,0.0],[0.04,1.0],[0.20,0.0]])
	if not sg:
		substituir(a,"Armas/Pistola:recuo_ferrolho",[[0,0.0],[0.025,0.032],[0.075,0.0],[tempo,0.0]])

func anim_troca(item: String, guardar: bool):
	var a := novo(item,"guardar" if guardar else "sacar",0.45)
	var pos := [[0,Vector3.ZERO],[0.12,Vector3(0,0.015,0)],[0.45,Vector3(0.07,-0.60,0.12)]]
	var rot := [[0,Vector3.ZERO],[0.45,Vector3(-0.5,0.05,0.1)]]
	if not guardar:
		pos = [[0,Vector3(0.07,-0.60,0.12)],[0.34,Vector3(0,0.015,0)],[0.45,Vector3.ZERO]]
		rot = [[0,Vector3(-0.5,0.05,0.1)],[0.45,Vector3.ZERO]]
	substituir(a,arma_path(item)+":position",pos)
	substituir(a,arma_path(item)+":rotation",rot)

func anim_recarga_shotgun():
	var a := novo("shotgun","recarga",3.6)
	eventos(a, [[0.288,"abre"],[1.116,"ejeta"],[2.16,"cartucho"],[3.024,"cartucho"],[3.24,"fecha"]])
	var p := arma_path("shotgun")
	var pr := Vector3(-0.045,0.045,0.045)
	var rr := Vector3(deg_to_rad(32),deg_to_rad(32),deg_to_rad(-12))
	substituir(a,p+":position",[[0,Vector3.ZERO],[0.25,pr],[0.70,pr+Vector3(0,-0.01,0.01)],[1.2,pr],[3.15,pr],[3.35,Vector3(0,0.01,0)],[3.6,Vector3.ZERO]])
	substituir(a,p+":rotation",[[0,Vector3.ZERO],[0.28,rr],[0.85,rr+Vector3(0,0,-0.14)],[1.15,rr],[3.20,rr],[3.45,Vector3(-0.04,0,0)],[3.6,Vector3.ZERO]])
	substituir(a,p+"/Articulacao:rotation",[[0,Vector3.ZERO],[0.288,Vector3.ZERO],[0.72,Vector3(-0.95,0,0)],[3.24,Vector3(-0.95,0,0)],[3.49,Vector3.ZERO],[3.6,Vector3.ZERO]])
	substituir(a,".:apoio_esquerdo",[[0,1.0],[0.28,1.0],[0.48,0.0],[3.13,0.0],[3.28,1.0],[3.6,1.0]])
	# Calcula as poses de insercao a partir das CAMARAS, nao do olho.
	var arma: Node3D = armas["shotgun"]
	var art: Node3D = arma.get_node("Movimento/Articulacao")
	var aberto: Transform3D = base_arma["shotgun"] * Transform3D(Basis.from_euler(rr),pr) * Transform3D(Basis(Vector3.RIGHT,-0.95),art.position)
	var pe := "AjusteEsquerdo/ControleEsquerdo"
	var ca1: Vector3 = aberto * art.get_node("Camara1").position
	var ca2: Vector3 = aberto * art.get_node("Camara2").position
	var hand_basis := orientacao(Vector3(0.95,0.15,-0.15), Vector3(0.05,0.2,1.0))
	# Cartucho: 8,5 cm a frente do pulso, 2,5 cm para dentro da palma.
	var of := hand_basis * Vector3(0,0.02,-0.12)
	var e1: Vector3 = ca1 - of - aberto.basis.z * 0.035
	var e2: Vector3 = ca2 - of - aberto.basis.z * 0.035
	substituir(a,pe+":position",[[0,esquerda.position],[0.48,Vector3(-0.18,-0.27,-0.34)],[1.15,Vector3(-0.26,-0.56,-0.20)],[1.48,Vector3(-0.26,-0.50,-0.25)],[1.88,e1+aberto.basis.z*0.12],[2.16,e1],[2.28,e1+Vector3(-0.04,-0.05,0.07)],[2.50,Vector3(-0.26,-0.56,-0.20)],[2.68,e2+aberto.basis.z*0.12],[3.024,e2],[3.13,e2+Vector3(-0.03,-0.04,0.05)],[3.32,esquerda.position],[3.6,esquerda.position]])
	substituir(a,pe+":rotation",[[0,esquerda.rotation],[0.80,hand_basis.get_euler()],[3.13,hand_basis.get_euler()],[3.4,esquerda.rotation]])
	for dedo in ["indicador","medio","anelar","mindinho","polegar"]:
		var pin: Vector3 = {"indicador":Vector3(15,35,20), "medio":Vector3(25,45,25), "anelar":Vector3(40,45,25), "mindinho":Vector3(45,50,30), "polegar":Vector3(10,25,20)}[dedo]
		substituir(a,pe+":"+dedo,[[0,esquerda.get(dedo)],[0.75,Vector3(12,15,10)],[1.45,pin],[2.16,pin],[2.23,Vector3(15,20,12)],[2.55,pin],[3.024,pin],[3.11,Vector3(15,20,12)],[3.4,esquerda.get(dedo)]])
	substituir(a,pe+"/CartuchoNaMao:visible",[[0,false],[1.46,true],[2.16,false],[2.55,true],[3.024,false]],true)
	trilha(a,pe+"/CartuchoNaMao:rotation",[[0,(hand_basis.inverse() * aberto.basis * Basis(Vector3.UP,-PI/2)).get_euler()]])
	for i in 2:
		substituir(a,p+"/Articulacao/Camara%d/Cartucho:visible"%(i+1),[[0,true],[1.116,false],[2.16 if i==0 else 3.024,true]],true)
	# Com so um cartucho de reserva, a mao faz uma unica busca e volta ao apoio.
	var uma: Animation = a.duplicate(true)
	uma.resource_name = "shotgun_recarga_uma"
	lib.add_animation(uma.resource_name, uma)
	substituir(uma,pe+"/CartuchoNaMao:visible",[[0,false],[1.46,true],[2.16,false]],true)
	substituir(uma,p+"/Articulacao/Camara2/Cartucho:visible",[[0,true],[1.116,false]],true)
	substituir(uma,".:apoio_esquerdo",[[0,1.0],[0.28,1.0],[0.48,0.0],[2.28,0.0],[2.70,1.0],[3.6,1.0]])
	var pos_track := uma.find_track(NodePath(pe),Animation.TYPE_POSITION_3D)
	for k in range(uma.track_get_key_count(pos_track)-1,-1,-1):
		if uma.track_get_key_time(pos_track,k)>2.28: uma.track_remove_key(pos_track,k)
	uma.track_insert_key(pos_track,2.70,esquerda.position)
	uma.track_insert_key(pos_track,3.6,esquerda.position)
	var met := uma.find_track(NodePath("."),Animation.TYPE_METHOD)
	for k in range(uma.track_get_key_count(met)-1,-1,-1):
		if is_equal_approx(uma.track_get_key_time(met,k),3.024): uma.track_remove_key(met,k)


func anim_recarga_pistola():
	var a := novo("pistol","recarga",3.0)
	eventos(a, [[2.04,"pente"]])
	var p := arma_path("pistol")
	var pr := Vector3(-0.045,0.025,-0.015)
	var rr := Vector3(deg_to_rad(27),deg_to_rad(-12),deg_to_rad(-32))
	substituir(a,p+":position",[[0,Vector3.ZERO],[0.35,pr],[2.05,pr],[2.14,pr+Vector3(0,0.012,-0.004)],[2.28,pr],[2.65,pr],[3.0,Vector3.ZERO]])
	substituir(a,p+":rotation",[[0,Vector3.ZERO],[0.35,rr],[2.30,rr],[2.56,rr+Vector3(0.04,0.08,0)],[3,Vector3.ZERO]])
	var w: Transform3D = base_arma["pistol"] * Transform3D(Basis.from_euler(rr),pr)
	var pe := "AjusteEsquerdo/ControleEsquerdo"
	var hb := orientacao(w.basis.y, w.basis.x)
	var entrada: Vector3 = w * Vector3(0,-0.075,0.015) - hb * Vector3(0,0.025,-0.07)
	var slide: Vector3 = w * Vector3(-0.03,0.09,-0.035) - hb * Vector3(0,0.035,-0.075)
	substituir(a,pe+":position",[[0,esquerda.position],[0.35,entrada+Vector3(-0.04,-0.03,0.02)],[0.65,Vector3(-0.27,-0.50,-0.22)],[1.12,Vector3(-0.26,-0.53,-0.26)],[1.65,entrada-w.basis.y*0.10],[2.04,entrada],[2.18,entrada+w.basis.y*0.012],[2.28,entrada-w.basis.y*0.04],[2.45,slide],[2.60,slide+w.basis.z*0.035],[2.69,slide],[3,esquerda.position]])
	substituir(a,pe+":rotation",[[0,esquerda.rotation],[0.35,hb.get_euler()],[2.69,hb.get_euler()],[3,esquerda.rotation]])
	for dedo in ["indicador","medio","anelar","mindinho","polegar"]:
		var grip := Vector3(40,60,38) if dedo != "polegar" else Vector3(35,30,18)
		substituir(a,pe+":"+dedo,[[0,esquerda.get(dedo)],[0.35,grip],[0.68,Vector3(12,20,10)],[1.12,grip],[2.18,grip],[2.3,Vector3(18,20,10)],[2.45,grip],[2.7,Vector3(12,15,8)],[3,esquerda.get(dedo)]])
	substituir(a,p+"/Carregador:visible",[[0,true],[0.42,false],[2.04,true]],true)
	substituir(a,p+"/CarregadorSolto:visible",[[0,false],[0.42,true],[0.90,false]],true)
	trilha(a,p+"/CarregadorSolto:position",[[0,Vector3(0,-0.075,0.015)],[0.42,Vector3(0,-0.04,0.015)],[0.60,Vector3(-0.02,-0.20,0.03)],[0.90,Vector3(-0.09,-0.7,0.10)]])
	trilha(a,p+"/CarregadorSolto:rotation",[[0,Vector3.ZERO],[0.90,Vector3(0.4,0.2,-0.6)]])
	substituir(a,pe+"/CarregadorNaMao:visible",[[0,false],[1.12,true],[2.04,false]],true)
	trilha(a,pe+"/CarregadorNaMao:rotation",[[0,(hb.inverse()*w.basis).get_euler()]])
	substituir(a,"Armas/Pistola:recuo_ferrolho",[[0,0.0],[2.45,0.0],[2.60,0.035],[2.67,0.0],[3.0,0.0]])


func eventos(a: Animation, chaves: Array) -> void:
	var t := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(t, NodePath("."))
	for chave in chaves:
		a.track_insert_key(t, chave[0], {"method": &"evento_recarga", "args": [chave[1]]})
