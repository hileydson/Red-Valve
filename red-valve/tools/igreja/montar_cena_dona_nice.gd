extends Node

## MONTA a cena das cutscenes da Dona Nice (scenes/stages/igreja/cena_dona_nice.tscn).
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/igreja/montar_cena_dona_nice.tscn
##
## Roda UMA vez. Depois disso a fonte e' o .tscn — abra no editor e mexa no
## AnimationPlayer `diretor`. Rodar de novo SOBRESCREVE a cena inteira (e tudo
## o que tiver sido ajustado a mao nela).
##
## Por que um gerador e nao a cena feita a mao: varios planos dependem de onde
## a mao, a faca e a cabeca estao DE VERDADE num instante de um clipe (a gota
## cai da ponta da faca em cima do peito do Jonny; a camera gira junto com a
## cabeca dela). Aqui os atores sao posados no proprio motor e medidos, e a
## camera e' posta em cima do que foi medido.
##
## Coordenadas: as da igreja (scenes/stages/igreja/igreja_interior.tscn). A
## porta fica em z ~ 0, a nave sobe pro +Z ate' o altar (z ~ 42), o feixe do
## rombo do teto cai em (0, 0, 15,5).

const SAIDA := "res://scenes/stages/igreja/cena_dona_nice.tscn"
const ATORES := "res://scenes/npcs/igreja/"
const SONS := "res://assets/sounds/igreja/"
const TEX := "res://assets/images/textures/igreja/"

## Onde o Jonny esta' deitado: no corredor central, atravessado, ainda dentro
## do facho de lua do rombo (que cai em z 15,5 com ~7 m de raio no chao).
const JONNY_POS := Vector3(0.0, 0.0, 19.6)
const JONNY_GIRO := 90.0
## Onde o Maycow fica na chegada (e onde o jogador volta a ter controle).
const MAYCOW_FIM := Vector3(0.0, 0.0, 4.2)
## Na entrada as pernas sao as do `correr_carregando` (a passada do colo), que
## casa com o chao a PASSO_DO_COLO m/s; ele entra no ritmo do andar do colo no
## jogo (`VELOCIDADE_NO_COLO`) — o no' anda junto com o pe', senao o pe' patina.
const PASSO_DO_COLO := 1.3
const MAYCOW_VELOCIDADE := 1.15
## No `andar_esticando` ele comeca a frear em x e para em y (segundos depois
## de a mao comecar a subir); o braco sobe do 0 ao 2,6.
const ANDA_ESTICANDO_FREIA := Vector2(1.7, 2.7)
## O instante do `correr_carregando` em que um pe' passa pelo outro (os dois
## debaixo do corpo): a passada e' acertada pra ele parar exatamente ai'.
const PES_JUNTOS := 0.53
## Os bracos (do `andar_lento`, que tem outro ritmo) vao presos a fase das
## pernas, com o braco esquerdo a frente quando o pe' direito esta' a frente:
## esta e' a diferenca de fase (fracao do ciclo) entre os dois clipes.
const BRACOS_NA_PASSADA := -0.051
## No `andar_lento` a palma esquerda vem virada pra FRENTE (medido na malha da
## mao: faltam 47-75 graus pra ela olhar pra coxa); o antebraco e a mao giram
## isto no eixo do antebraco, metade cada, pra o pulso nao torcer. A direita
## ja' vem virada pro corpo.
const GIRO_PALMA_ESQUERDA := 60.0
## Os dois olhos dela (as pupilas) no espaco do osso `head`, medidos em duas
## fotos do plano (zoom aberto e fechado, que batem na mesma conta). A camera
## mira entre eles e a lente deixa nitido so' em volta de cada um.
const OLHOS_NO_OSSO := [Vector3(-0.0356, 0.1382, 0.1172), Vector3(0.0207, 0.1395, 0.1211)]
## O girar_cabeca dela toca mais devagar na chegada (3,5 s viram ~6,4 s).
const VEL_CABECA := 0.55
## Os trechos do girar_cabeca (em tempo do CLIPE) em que o pescoco torce de
## verdade — e e' ai' que ele espirra sangue.
const TORCE_PESCOCO := [[0.8, 1.35], [1.8, 2.7]]

var raiz: Node3D
var lib: AnimationLibrary
var a: Animation
var atores := {}


func _ready() -> void:
	SaveManager.current_slot = 9
	raiz = Node3D.new()
	raiz.name = "cena_dona_nice"
	raiz.set_script(load("res://scripts/stages/igreja/cena_dona_nice.gd"))
	add_child(raiz)
	_montar_estrutura()
	await get_tree().process_frame
	await get_tree().process_frame
	_montar_chegada()
	_montar_vira_fase_2()
	_montar_morte_final()
	_montar_pega_jonny()
	_gravar()
	get_tree().quit()


# ==============================================================================
# ESTRUTURA
# ==============================================================================
func _no(tipo, nome: String, pai: Node) -> Node:
	var n: Node = tipo.new()
	n.name = nome
	pai.add_child(n)
	n.owner = raiz
	return n


func _instancia(caminho: String, nome: String, pai: Node) -> Node:
	var n: Node = load(caminho).instantiate()
	n.name = nome
	pai.add_child(n)
	n.owner = raiz
	return n


func _montar_estrutura() -> void:
	var previa := _instancia("res://assets/3d_model/stages/igreja/igreja_interior.glb",
		"previa_igreja", raiz)
	previa.editor_description = "So' pra ver a igreja no editor. Some no jogo."

	var at := _no(Node3D, "atores", raiz)
	for d in [["Maycow", "maycow_cena"], ["Jonny", "jonny"], ["DonaNice", "dona_nice"],
			["Monstro", "dona_nice_monster"]]:
		var n := _instancia(ATORES + d[1] + ".tscn", d[0], at)
		atores[d[0]] = n
		var ap := n.get_node("anim") as AnimationPlayer
		ap.playback_default_blend_time = 0.35
	# deitado ele assenta no chao (costas, cabeca e quadril): `AtorIgreja.no_chao`
	atores["Jonny"].transform = atores["Jonny"].no_chao(
		Transform3D(Basis(Vector3.UP, deg_to_rad(JONNY_GIRO)), JONNY_POS))
	atores["Jonny"].sangue = 0.45
	atores["Jonny"].clipe_inicial = &"caido_agonia"
	atores["DonaNice"].sangue = 0.55
	atores["DonaNice"].clipe_inicial = &"ajoelhada_sussurro"
	atores["Maycow"].position = MAYCOW_FIM
	atores["Maycow"].clipe_inicial = &""
	atores["Monstro"].visible = false
	atores["Monstro"].dissolver = 1.0
	atores["Monstro"].sangue = 0.3
	atores["Monstro"].clipe_inicial = &""

	_posicionar_dona_nice()
	_faca()
	_sangue_pescoco()
	_pistola()
	_cameras_base()
	_efeitos()
	_palcos()
	_sons()
	_lente()

	var diretor := _no(AnimationPlayer, "diretor", raiz) as AnimationPlayer
	lib = AnimationLibrary.new()
	diretor.add_animation_library("", lib)


## Ela fica ajoelhada do lado da porta, de costas pro Maycow, e a ponta da
## faca tem de ficar em cima do PEITO do Jonny (de la' cai a gota). A posicao
## sai disso: mede-se a mao no clipe e anda-se o corpo ate' a mao caber.
func _posicionar_dona_nice() -> void:
	var dn: Node3D = atores["DonaNice"]
	dn.position = Vector3(0.0, 0.0, JONNY_POS.z - 1.0)
	_posar(dn, "ajoelhada_sussurro", 0.0)
	_posar(atores["Jonny"], "caido_agonia", 0.0)
	var mao: Vector3 = dn.posicao_do_osso("hand.R")
	var peito: Vector3 = atores["Jonny"].posicao_do_osso("chest")
	# a ponta da faca fica ~0,18 m alem da mao na direcao do braco
	var alvo := Vector3(peito.x, 0.0, peito.z - 0.10)
	dn.position += Vector3(alvo.x - mao.x, 0.0, alvo.z - mao.z - 0.12)
	print("DonaNice em ", dn.position, " (mao ", mao, " peito ", peito, ")")


## Filho novo dentro de cena instanciada (a faca no esqueleto, que mora no
## .glb, que mora na cena do ator) so' e' gravado se as DUAS instancias
## estiverem como "Editable Children" — senao o pack ignora em silencio.
func _editavel(ator: Node3D) -> void:
	raiz.set_editable_instance(ator, true)
	raiz.set_editable_instance(ator.get_node("modelo"), true)


func _posar(ator: Node3D, clipe: String, t: float) -> void:
	var ap := ator.get_node("anim") as AnimationPlayer
	ap.play(clipe)
	ap.seek(t, true)
	(ator.esqueleto() as Skeleton3D).force_update_all_bone_transforms()


## Posa SEM misturar com o clipe anterior (o `_posar` mistura: sem o tempo
## andar, a pose fica a de antes).
func _posar_seco(ator: Node3D, clipe: String, t: float) -> void:
	var ap := ator.get_node("anim") as AnimationPlayer
	ap.play(clipe, 0.0)
	ap.seek(t, true)
	(ator.esqueleto() as Skeleton3D).force_update_all_bone_transforms()


## A altura do ponto mais baixo da PELE do ator, na pose atual: a malha
## deformada na CPU (o osso fica dentro da carne e nao diz onde o corpo
## encosta no chao).
func _pele_mais_baixa(ator: Node3D, passo := 4) -> float:
	var sk := ator.esqueleto() as Skeleton3D
	var menor := INF
	for mi_ in ator.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_ as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var poses := []
		for i in mi.skin.get_bind_count():
			var b := mi.skin.get_bind_bone(i)
			if b < 0:
				b = sk.find_bone(mi.skin.get_bind_name(i))
			poses.append(sk.get_bone_global_pose(b) * mi.skin.get_bind_pose(i))
		var g := mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ossos = arr[Mesh.ARRAY_BONES]
			var pesos = arr[Mesh.ARRAY_WEIGHTS]
			var k: int = pesos.size() / vs.size()
			for i in range(0, vs.size(), passo):
				var p := Vector3.ZERO
				for j in k:
					var w: float = pesos[i * k + j]
					if w > 0.0:
						var o: int = ossos[i * k + j]
						p += w * ((poses[o] as Transform3D) * vs[i])
				menor = minf(menor, (g * p).y)
	return menor


func _global_do_osso(ator: Node3D, osso: String) -> Transform3D:
	var sk := ator.esqueleto() as Skeleton3D
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(osso))


## A faca: presa no osso da mao direita (BoneAttachment3D) por um pivo. O
## giro do pivo e' calculado pra que, ajoelhada, a lamina aponte pra baixo e
## pra frente — pro Jonny. Daí em diante ela segue a mao.
func _faca() -> void:
	var dn: Node3D = atores["DonaNice"]
	var sk := dn.esqueleto() as Skeleton3D
	_editavel(dn)
	var at := _no(BoneAttachment3D, "mao_faca", sk) as BoneAttachment3D
	at.bone_name = "hand.R"
	var pivo := _no(Node3D, "pivo_faca", at) as Node3D
	pivo.editor_description = "Gire/mova este pivo pra acertar a faca na mao."
	var faca := _instancia("res://assets/3d_model/npc/igreja/faca_ritual.glb", "faca", pivo)
	_posar(dn, "ajoelhada_sussurro", 0.0)
	var mao := _global_do_osso(dn, "hand.R")
	var desejo := Basis.looking_at(Vector3(0.0, -0.85, 0.45).normalized(), Vector3(0, 0, 1))
	# looking_at aponta o -Z; a lamina e' o +Y da faca
	var b := desejo * Basis(Vector3(1, 0, 0), deg_to_rad(-90.0))
	var global := Transform3D(b, mao.origin + mao.basis.y.normalized() * 0.05)
	pivo.transform = mao.affine_inverse() * global
	# o sangue da lamina com borda escorrida
	var sangue := faca.find_child("sangue", true, false) as MeshInstance3D
	if sangue:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/npcs/sangue_lamina.gdshader")
		sangue.material_override = m
	# o sangue que pinga da ponta, sem parar, enquanto ela esta' ajoelhada
	var gotas := _no(GPUParticles3D, "pingos", pivo) as GPUParticles3D
	gotas.position = Vector3(0.0, 0.236, -0.004)
	gotas.amount = 4
	gotas.lifetime = 1.4
	gotas.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.05
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	gotas.process_material = pm
	var malha := SphereMesh.new()
	malha.radius = 0.0028
	malha.height = 0.009
	malha.radial_segments = 8
	malha.rings = 4
	malha.material = _material_sangue()
	gotas.draw_pass_1 = malha
	gotas.visibility_aabb = AABB(Vector3(-0.3, -1.5, -0.3), Vector3(0.6, 1.6, 0.6))


## O pescoco que espirra quando ela torce a cabeca pra tras: jatos em roda,
## em volta do osso, que caem pelo peso. Ligado pelo diretor nos trechos
## `TORCE_PESCOCO` do giro.
func _sangue_pescoco() -> void:
	var dn: Node3D = atores["DonaNice"]
	var sk := dn.esqueleto() as Skeleton3D
	var at := _no(BoneAttachment3D, "pescoco", sk) as BoneAttachment3D
	at.bone_name = "neck"
	var jorro := _no(GPUParticles3D, "jorro", at) as GPUParticles3D
	jorro.position = Vector3(0.0, 0.05, 0.0)
	jorro.emitting = false
	jorro.amount = 260
	jorro.lifetime = 1.1
	jorro.local_coords = false
	var pm := ParticleProcessMaterial.new()
	# em roda, perpendicular ao pescoco (o Y do osso), puxando um pouco pra cima
	pm.direction = Vector3(1, 0.35, 0)
	pm.spread = 180.0
	pm.flatness = 0.75
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.045
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	# cada gota estica na direcao em que voa: le-se como jato, nao como poeira
	pm.particle_flag_align_y = true
	jorro.process_material = pm
	var gota := SphereMesh.new()
	gota.radius = 0.0065
	gota.height = 0.055
	gota.radial_segments = 6
	gota.rings = 3
	# mais vivo que o sangue parado: na igreja escura o vermelho-escuro some
	var m := _material_sangue()
	m.albedo_color = Color(0.42, 0.01, 0.02)
	m.emission_enabled = true
	m.emission = Color(0.3, 0.0, 0.01)
	gota.material = m
	jorro.draw_pass_1 = gota
	jorro.visibility_aabb = AABB(Vector3(-2, -2.5, -2), Vector3(4, 4, 4))


func _material_sangue() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.0, 0.004)
	m.roughness = 0.05
	m.metallic_specular = 0.8
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.02
	return m


## A pistola do duble do Maycow: mesma arma do jogo, na mao direita, com o
## cano pra frente e o cabo na palma no instante em que ele ja' mira.
func _pistola() -> void:
	var mc: Node3D = atores["Maycow"]
	var sk := mc.esqueleto() as Skeleton3D
	_editavel(mc)
	var at := _no(BoneAttachment3D, "mao_arma", sk) as BoneAttachment3D
	at.bone_name = "RightHand"
	var pivo := _no(Node3D, "pivo_arma", at) as Node3D
	pivo.editor_description = "Gire/mova este pivo pra acertar a pistola na mao."
	var arma := _instancia("res://assets/3d_model/player/the_negotiator_V1/the_negotiator_v1.glb",
		"pistola", pivo) as Node3D
	pivo.visible = false
	_posar(mc, "mirando", 0.0)
	var mao := _global_do_osso(mc, "RightHand")
	# o modelo tem o cano no -X, o alto no +Y e 1,92 unidade (22 cm)
	var frente := Vector3(0, 0, 1)
	var b := Basis(Vector3(0, 1, 0), deg_to_rad(90.0))       # -X do modelo -> +Z
	b = b.scaled(Vector3.ONE * 0.115)
	var cabo := b * Vector3(0.61, -0.33, 0.0)
	var global := Transform3D(b, mao.origin + Vector3(0, 0.02, 0.04) - cabo)
	pivo.transform = mao.affine_inverse() * global
	arma.name = "pistola"


func _cameras_base() -> void:
	_no(Node3D, "cameras", raiz)


## `nome` pode ser so' o nome (vai pra `cameras/`) ou um caminho a partir da
## raiz (camera filha de um palco, que se move com ele).
func _camera(nome: String) -> Camera3D:
	var caminho := nome if "/" in nome else "cameras/" + nome
	var c := raiz.get_node_or_null(caminho) as Camera3D
	if c == null:
		var pai := raiz.get_node(caminho.get_base_dir())
		c = _no(Camera3D, caminho.get_file(), pai) as Camera3D
		c.near = 0.02
		c.far = 120.0
	return c


func _efeitos() -> void:
	var ef := _no(Node3D, "efeitos", raiz)
	# --- o chao do ritual: poca embaixo dele, respingos, o simbolo, o rastro
	_decal(ef, "poca_jonny", "sangue_poca", JONNY_POS + Vector3(0, 0, 0.05), Vector3(2.2, 0.6, 1.8), 0.0)
	_decal(ef, "simbolo", "simbolo_culto", JONNY_POS, Vector3(4.2, 0.6, 4.2), 12.0, 0.85)
	_decal(ef, "respingo_1", "sangue_respingo", JONNY_POS + Vector3(-1.4, 0, -0.7), Vector3(1.4, 0.6, 1.4), 40.0)
	_decal(ef, "respingo_2", "sangue_respingo", JONNY_POS + Vector3(1.6, 0, 0.9), Vector3(1.1, 0.6, 1.1), 200.0)
	_decal(ef, "rastro", "sangue_rastro", JONNY_POS + Vector3(0.0, 0, -2.6), Vector3(1.2, 0.6, 3.4), 0.0, 0.7)
	var gota_decal := _decal(ef, "respingo_gota", "sangue_respingo",
		Vector3.ZERO, Vector3(0.35, 0.4, 0.35), 0.0)
	gota_decal.scale = Vector3(0.01, 1, 0.01)
	# --- as velas em volta do Jonny (luz quente que treme: uma omni so')
	var velas := _no(Node3D, "velas", ef)
	for i in 7:
		var ang := TAU * i / 7.0 + 0.2
		var p := JONNY_POS + Vector3(cos(ang) * 1.75, 0.0, sin(ang) * 1.75)
		_vela(velas, "vela_%d" % i, p, 0.10 + 0.08 * fmod(i * 0.37, 1.0))
	var luz := _no(OmniLight3D, "luz_velas", ef) as OmniLight3D
	luz.position = JONNY_POS + Vector3(0, 0.45, 0)
	luz.light_color = Color(1.0, 0.62, 0.32)
	luz.light_energy = 2.2
	luz.omni_range = 4.5
	luz.shadow_enabled = true
	luz.set_meta("piscar", "nervoso")
	# --- o pulso vermelho da transformacao (ocupa o lugar da rebote_rombo)
	var pulso := _no(OmniLight3D, "luz_pulso", ef) as OmniLight3D
	pulso.position = JONNY_POS + Vector3(0, 1.6, -1.2)
	pulso.light_color = Color(1.0, 0.08, 0.04)
	pulso.light_energy = 0.0
	pulso.omni_range = 8.0
	pulso.visible = false
	# --- contraluz da porta (a lua de fora atras do Maycow)
	var porta := _no(SpotLight3D, "luz_porta", ef) as SpotLight3D
	porta.position = Vector3(0.0, 3.4, -2.6)
	porta.look_at_from_position(porta.position, Vector3(0.0, 0.8, 4.0))
	porta.light_color = Color(0.62, 0.72, 1.0)
	porta.light_energy = 6.0
	porta.spot_range = 12.0
	porta.spot_angle = 28.0
	porta.shadow_enabled = true
	# --- luz de chave no Maycow: a porta e' o lugar mais escuro da igreja, e
	# os planos de rosto, da mao e da arma acontecem todos ali
	var chave := _no(SpotLight3D, "luz_chave_maycow", ef) as SpotLight3D
	chave.position = Vector3(1.1, 3.2, MAYCOW_FIM.z + 4.6)
	chave.look_at_from_position(chave.position, MAYCOW_FIM + Vector3(0, 1.3, -1.2))
	chave.light_color = Color(0.85, 0.82, 0.95)
	chave.light_energy = 11.0
	chave.spot_range = 12.0
	chave.spot_angle = 30.0
	chave.spot_angle_attenuation = 1.6
	chave.shadow_enabled = true
	# --- a gota que cai em camera lenta
	var gota := _no(MeshInstance3D, "gota", ef) as MeshInstance3D
	var esf := SphereMesh.new()
	esf.radius = 0.0045
	esf.height = 0.013
	esf.material = _material_sangue()
	gota.mesh = esf
	gota.visible = false
	var resp := _no(GPUParticles3D, "respingo", ef) as GPUParticles3D
	resp.emitting = false
	resp.one_shot = true
	resp.explosiveness = 0.95
	resp.amount = 28
	resp.lifetime = 1.2
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.9
	resp.process_material = pm
	var mm := SphereMesh.new()
	mm.radius = 0.004
	mm.height = 0.008
	mm.radial_segments = 6
	mm.rings = 3
	mm.material = _material_sangue()
	resp.draw_pass_1 = mm
	# --- a nevoa de sangue e os pedacos da transformacao
	var nevoa := _no(GPUParticles3D, "nevoa_sangue", ef) as GPUParticles3D
	nevoa.emitting = false
	nevoa.amount = 220
	nevoa.lifetime = 2.2
	nevoa.explosiveness = 0.0
	var pn := ParticleProcessMaterial.new()
	pn.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pn.emission_sphere_radius = 0.45
	pn.direction = Vector3(0, 1, 0)
	pn.spread = 180.0
	pn.initial_velocity_min = 0.6
	pn.initial_velocity_max = 2.4
	pn.gravity = Vector3(0, -3.5, 0)
	pn.damping_min = 0.4
	pn.damping_max = 1.2
	pn.scale_min = 0.4
	pn.scale_max = 1.6
	nevoa.process_material = pn
	var pedaco := SphereMesh.new()
	pedaco.radius = 0.012
	pedaco.height = 0.02
	pedaco.radial_segments = 6
	pedaco.rings = 3
	pedaco.material = _material_sangue()
	nevoa.draw_pass_1 = pedaco
	nevoa.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 5, 8))


func _decal(pai: Node, nome: String, tex: String, pos: Vector3, tam: Vector3,
		giro: float, opac: float = 1.0) -> Decal:
	var d := _no(Decal, nome, pai) as Decal
	d.position = pos
	d.rotation_degrees.y = giro
	d.size = tam
	d.texture_albedo = load(TEX + tex + ".png")
	d.texture_orm = load(TEX + tex + "_orm.png")
	d.albedo_mix = opac
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 1
	return d


func _vela(pai: Node, nome: String, pos: Vector3, altura: float) -> void:
	var v := _no(MeshInstance3D, nome, pai) as MeshInstance3D
	var cil := CylinderMesh.new()
	cil.top_radius = 0.022
	cil.bottom_radius = 0.025
	cil.height = altura
	cil.radial_segments = 10
	var cera := StandardMaterial3D.new()
	cera.albedo_color = Color(0.78, 0.74, 0.66)
	cera.roughness = 0.6
	cil.material = cera
	v.mesh = cil
	v.position = pos + Vector3(0, altura * 0.5, 0)
	var chama := _no(MeshInstance3D, "chama", v) as MeshInstance3D
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.05)
	var fogo := StandardMaterial3D.new()
	fogo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fogo.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fogo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fogo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fogo.albedo_color = Color(1.0, 0.6, 0.2, 0.9)
	fogo.emission_enabled = true
	fogo.emission = Color(1.0, 0.55, 0.18)
	fogo.emission_energy_multiplier = 4.0
	q.material = fogo
	chama.mesh = q
	chama.position = Vector3(0, altura * 0.5 + 0.03, 0)


func _sons() -> void:
	var s := _no(Node3D, "sons", raiz)
	for d in [["sussurro", "sussurro_culto.ogg", -6.0], ["batimento", "batimento_lento.ogg", -4.0],
			["batimento_rapido", "batimento_rapido.ogg", -3.0], ["gota", "gota_sangue.ogg", -2.0],
			["gota_impacto", "gota_impacto.ogg", -4.0], ["ossos", "transformacao_ossos.ogg", 0.0],
			["grito", "grito_transformacao.ogg", -3.0], ["rugido", "rugido_monstro.ogg", 1.0],
			["grito_monstro", "grito_monstro.ogg", 0.0],
			["ambiente", "ambiente_ritual.ogg", -10.0], ["gemido", "gemido_jonny.ogg", -6.0],
			["pescoco", "pescoco_torcendo.ogg", 0.0]]:
		var p := _no(AudioStreamPlayer, d[0], s) as AudioStreamPlayer
		p.stream = load(SONS + d[1])
		p.volume_db = d[2]
	var arma := _no(AudioStreamPlayer, "arma", s) as AudioStreamPlayer
	arma.stream = load("res://assets/sounds/player/load_gun.mp3")


func _lente() -> void:
	var cl := _no(CanvasLayer, "lente", raiz) as CanvasLayer
	cl.layer = 80
	var tela := _no(ColorRect, "tela", cl) as ColorRect
	# com os offsets: so' a ancora deixava a tela com tamanho zero (sem lente)
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/cutscenes/igreja_lente.gdshader")
	# a vinheta e a cor da lente escurecem ~18%: a exposicao devolve o brilho
	# que a cena tinha sem ela
	m.set_shader_parameter("exposure", 1.18)
	tela.material = m
	# o fade pro preto do fim de uma cena (o diretor anima `preto`)
	var preto := _no(ColorRect, "preto", cl) as ColorRect
	preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preto.color = Color(0, 0, 0, 0)
	var leg := _no(Label, "legenda", cl) as Label
	leg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	leg.offset_top = -150
	leg.offset_bottom = -100
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leg.add_theme_font_size_override("font_size", 34)
	leg.add_theme_color_override("font_color", Color(0.86, 0.80, 0.78))
	leg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	leg.add_theme_constant_override("outline_size", 6)
	var fonte := load("res://assets/fonts/SpecialElite-Regular.ttf") as Font
	if fonte:
		leg.add_theme_font_override("font", fonte)
	leg.modulate.a = 0.0


# ==============================================================================
# TRILHAS
# ==============================================================================
func _trilha(tipo: int, caminho: String) -> int:
	var i := a.add_track(tipo)
	a.track_set_path(i, NodePath(caminho))
	return i


func _valor(caminho: String, chaves: Array, discreto := false) -> void:
	var i := _trilha(Animation.TYPE_VALUE, caminho)
	a.value_track_set_update_mode(i, Animation.UPDATE_DISCRETE if discreto
		else Animation.UPDATE_CONTINUOUS)
	for k in chaves:
		a.track_insert_key(i, k[0], k[1], k[2] if k.size() > 2 else 1.0)


func _pos(caminho: String, chaves: Array) -> void:
	var i := _trilha(Animation.TYPE_POSITION_3D, caminho)
	for k in chaves:
		a.position_track_insert_key(i, k[0], k[1])


func _rot(caminho: String, chaves: Array) -> void:
	var i := _trilha(Animation.TYPE_ROTATION_3D, caminho)
	for k in chaves:
		a.rotation_track_insert_key(i, k[0], k[1])


func _clipe(ator: String, chaves: Array) -> void:
	var caminho := (ator if "/" in ator else "atores/" + ator) + "/anim"
	var i := _trilha(Animation.TYPE_ANIMATION, caminho)
	for k in chaves:
		a.animation_track_insert_key(i, k[0], k[1])


func _metodo(chaves: Array) -> void:
	var i := _trilha(Animation.TYPE_METHOD, ".")
	for k in chaves:
		a.track_insert_key(i, k[0], {"method": k[1], "args": k[2]})


func _som(nome: String, chaves: Array) -> void:
	var i := _trilha(Animation.TYPE_AUDIO, "sons/" + nome)
	var p := raiz.get_node("sons/" + nome) as AudioStreamPlayer
	for k in chaves:
		a.audio_track_insert_key(i, k[0], p.stream, k[1] if k.size() > 1 else 0.0)


## Uma camera com chaves de (tempo, posicao, alvo, fov). Entre as chaves a
## camera anda e gira (posicao linear, giro slerp). A primeira chave tambem
## vira a pose de descanso do no', pra a camera aparecer no lugar no editor.
func _cam(nome: String, chaves: Array) -> void:
	var c := _camera(nome)
	var ps := []
	var rs := []
	var fs := []
	for k in chaves:
		var t: float = k[0]
		var p: Vector3 = k[1]
		var alvo: Vector3 = k[2]
		var b := Basis.looking_at(alvo - p, Vector3.UP)
		ps.append([t, p])
		rs.append([t, b.get_rotation_quaternion()])
		fs.append([t, float(k[3])])
	c.position = chaves[0][1]
	c.basis = Basis(rs[0][1])
	c.fov = chaves[0][3]
	var caminho := nome if "/" in nome else "cameras/" + nome
	_pos(caminho, ps)
	_rot(caminho, rs)
	_valor("%s:fov" % caminho, fs)


# ==============================================================================
# A CHEGADA
# ==============================================================================
func _montar_chegada() -> void:
	a = Animation.new()
	lib.add_animation("chegada", a)
	var dn: Node3D = atores["DonaNice"]
	var DN: Vector3 = dn.position
	var J := JONNY_POS

	# ---------------------------------------------------------------- tempos
	# Abre com ele entrando devagar pela porta; ANDANDO ele estica a mao pro
	# ritual (`andar_esticando`) e so' para um pouco depois, com a mao ja'
	# erguida. O giro da cabeca dela e' lento e escuro; quando o olhar chega
	# nele, a camera dispara ate' o Maycow e gira de volta pra ela.
	const T_MAO := 2.2          # a mao sobe aqui no `andar_esticando`, que comeca no 0
	const T_ROSTO := 5.6        # o plano aberto segura ate' ele parar
	# tudo dali em diante e' o que era, 3 s depois (a entrada andando)
	const E := 3.0
	const T_OMBRO := E + 4.2
	const T_FACA := E + 8.6
	const T_GOTA := E + 12.6
	const T_GOTA_CAI := E + 14.0
	# a queda da gota e' em camera lenta: o jogo inteiro a LENTO (e o som da
	# cena mais grave, menos o ambiente), entao 0,8 s de animacao duram 5 s
	const T_GOTA_BATE := E + 14.8
	const LENTO := 0.16
	const T_LONGE := E + 16.0
	const T_LEVANTA := E + 23.0     # levantar (4,6 s)
	const T_CABECA := E + 27.6      # girar_cabeca (3,5 s / VEL_CABECA)
	var dur_cabeca := 3.5 / VEL_CABECA
	# o olhar dela trava no Maycow aos 2,9 s do clipe; dai' a camera dispara
	var t_dispara := T_CABECA + 2.9 / VEL_CABECA
	var t_chega := t_dispara + 0.45
	var t_volta := t_chega + 0.4
	var T_SACA := t_volta + 0.55       # sacar_arma (1,5 s)
	var T_OLHOS := T_SACA + 1.6
	# no rosto dela a camera nao corta: entra nos olhos (so' eles nitidos) e
	# fica ali OLHAR segundos a mais
	var T_ZOOM := T_SACA + 4.1
	const OLHAR := 2.6
	var T_MIRA := T_ZOOM + OLHAR
	var T_VIRA := T_MIRA + 2.5         # virar_corpo (1,6 s)
	var T_CONVULSAO := T_MIRA + 4.1    # convulsao (5,1 s)
	var T_RUGIDO := T_MIRA + 9.2       # rugido (2,9 s)
	# depois do rugido a camera se afasta e os bancos da nave voam pros lados;
	# fecha no preto, e o jogo abre no Maycow
	var T_BANCOS := T_RUGIDO + 2.6
	var T_FIM := T_BANCOS + 4.6
	# o grito de monstro, no meio da transformacao (o pico vem ~1 s depois)
	var t_grito := T_CONVULSAO + 1.4
	a.length = T_FIM

	# ---------------------------------------------------------------- lente
	_valor(".:barras", [[0.0, 0.0], [1.2, 1.0], [T_FIM, 1.0]])
	_valor(".:preto", [[0.0, 0.0], [T_FIM - 0.7, 0.0], [T_FIM, 1.0]])
	# o giro da cabeca: tunel escuro, so' o meio nitido, ate' a camera
	# terminar de voltar pra ela
	_valor(".:lento", [[0.0, 1.0], [T_GOTA_CAI - 0.12, 1.0], [T_GOTA_CAI, LENTO],
		[T_GOTA_BATE - 0.001, LENTO], [T_GOTA_BATE, 1.0]])
	# na gota tambem: so' ela nitida, o resto borrado (tunel + borrao radial)
	_valor(".:foco", [[0.0, 0.0], [T_GOTA_CAI - 0.1, 0.0], [T_GOTA_CAI + 0.08, 0.9],
		[T_GOTA_BATE, 0.9], [T_GOTA_BATE + 0.25, 0.0], [T_CABECA, 0.0], [T_CABECA + 0.7, 1.0],
		[t_volta, 1.0], [t_volta + 0.35, 0.0], [T_OLHOS, 0.0], [T_OLHOS + 0.6, 0.85],
		[T_MIRA - 0.3, 1.0], [T_MIRA, 0.0]])
	# no rosto dela so' em volta dos olhos fica nitido (`olhos_no_osso`)
	_valor(".:foco_olhos", [[0.0, 0.0], [T_OLHOS - 0.01, 0.0], [T_OLHOS, 1.0],
		[T_MIRA, 1.0], [T_MIRA + 0.01, 0.0]])
	_valor(".:saturacao", [[0.0, 0.85], [T_GOTA, 0.85], [T_GOTA + 0.6, 0.55],
		[T_LONGE, 0.85], [T_CONVULSAO, 0.85], [T_CONVULSAO + 2.0, 0.6], [T_FIM, 0.85]])
	_valor(".:vermelho", [[0.0, 0.0], [T_CONVULSAO, 0.0], [T_CONVULSAO + 2.5, 0.45],
		[T_RUGIDO + 1.0, 0.35], [T_FIM, 0.0]])
	_valor(".:tremor", [[0.0, 0.0], [T_MIRA, 0.0], [T_MIRA + 0.1, 0.05], [T_VIRA, 0.05],
		[T_CONVULSAO, 0.15], [T_CONVULSAO + 3.0, 0.5], [T_RUGIDO, 0.3], [T_RUGIDO + 0.5, 1.0],
		[T_RUGIDO + 2.2, 0.25], [T_BANCOS + 0.5, 0.25], [T_BANCOS + 0.8, 0.7],
		[T_BANCOS + 3.0, 0.15], [T_FIM, 0.0]])
	_valor(".:flash", [[0.0, 0.0], [T_RUGIDO + 0.6, 0.0], [T_RUGIDO + 0.7, 0.55],
		[T_RUGIDO + 1.3, 0.0]])
	_valor(".:borrao", [[0.0, 0.0], [T_GOTA_CAI - 0.1, 0.0], [T_GOTA_CAI + 0.08, 0.3],
		[T_GOTA_BATE, 0.3], [T_GOTA_BATE + 0.2, 0.0], [t_dispara, 0.0], [t_dispara + 0.3, 0.35],
		[t_chega, 0.0], [t_grito + 0.6, 0.0], [t_grito + 0.8, 0.85], [t_grito + 1.7, 0.0],
		[T_RUGIDO + 0.6, 0.0], [T_RUGIDO + 0.7, 0.7], [T_RUGIDO + 1.6, 0.0]])
	_valor(".:pulso", [[0.0, 0.0], [T_CONVULSAO, 0.0], [T_CONVULSAO + 0.4, 0.8],
		[T_CONVULSAO + 0.8, 0.2], [T_CONVULSAO + 1.3, 1.0], [T_CONVULSAO + 1.7, 0.3],
		[T_CONVULSAO + 2.2, 1.0], [T_CONVULSAO + 3.0, 0.6], [T_RUGIDO + 0.7, 1.0],
		[T_FIM, 0.15]])

	# ---------------------------------------------------------------- planos
	_valor(".:plano", [[0.0, "cam_entrada"], [T_ROSTO, "cam_rosto"],
		[T_OMBRO, "cam_ombro"], [T_FACA, "cam_faca"], [T_GOTA, "cam_gota"],
		[T_LONGE, "cam_longe"], [T_LEVANTA, "cam_levanta"], [T_CABECA, "cam_cabeca"],
		[T_SACA, "cam_sacar"], [T_OLHOS, "cam_olhos"], [T_MIRA, "cam_mira"],
		[T_VIRA, "cam_lateral"], [T_CONVULSAO, "cam_transforma"],
		[T_RUGIDO, "cam_rugido"], [T_BANCOS, "cam_bancos"], [T_FIM - 0.05, ""]], true)

	# ---------------------------------------------------------------- Maycow
	# o no' anda no ritmo do pe' (o clipe e' no lugar) e freia junto com as
	# pernas do `andar_esticando`
	var entrada := []
	var t_para := T_MAO + ANDA_ESTICANDO_FREIA.y
	var z0 := MAYCOW_FIM.z - _andou(t_para, T_MAO)
	for i in 61:
		var t := t_para * i / 60.0
		entrada.append([t, Vector3(MAYCOW_FIM.x, 0.0, z0 + _andou(t, T_MAO))])
	_pos("atores/Maycow", entrada)
	_rot("atores/Maycow", [[0.0, Quaternion()]])
	_andar_esticando(T_MAO)
	_clipe("Maycow", [[0.0, "cena/andar_esticando"],
		[T_MAO + 3.2, "mao_esticada"], [T_SACA, "sacar_arma"], [T_SACA + 1.5, "mirando"]])
	_valor("atores/Maycow/modelo/Armature/Skeleton3D/mao_arma/pivo_arma:visible",
		[[0.0, false], [T_SACA + 0.45, true]], true)

	var olho := func(z): return Vector3(0.0, 1.62, z)
	# aberto o bastante pra caber o corpo inteiro e a mao (que estica pro -X);
	# acompanha ele vindo da porta e chega no enquadramento de antes quando
	# ele para
	_cam("cam_entrada", [
		[0.0, Vector3(0.8, 1.55, 9.9), Vector3(0.0, 1.25, z0 + 0.3), 42.0],
		[t_para, Vector3(0.75, 1.5, 9.6), Vector3(-0.25, 1.35, MAYCOW_FIM.z), 40.0],
		[T_ROSTO, Vector3(0.65, 1.5, 9.0), Vector3(-0.25, 1.38, MAYCOW_FIM.z), 37.0]])
	_cam("cam_rosto", [
		[T_ROSTO, Vector3(-0.35, 1.66, 5.35), Vector3(0.0, 1.6, 4.25), 34.0],
		[T_OMBRO, Vector3(-0.30, 1.65, 5.05), Vector3(0.0, 1.6, 4.25), 32.0]])
	_cam("cam_ombro", [
		[T_OMBRO, Vector3(-0.42, 1.74, 3.35), Vector3(0.0, 0.75, J.z), 40.0],
		[T_FACA, Vector3(-0.36, 1.71, 3.85), Vector3(0.0, 0.70, J.z), 36.0]])

	# ---------------------------------------------------------------- Jonny
	_clipe("Jonny", [[0.0, "caido_agonia"]])
	_som("gemido", [[T_LONGE + 2.0], [T_LEVANTA + 3.0]])

	# ---------------------------------------------------------------- a faca
	_posar(dn, "ajoelhada_sussurro", 0.0)
	var ponta := _ponta_da_faca()
	_cam("cam_faca", [
		[T_FACA, ponta + Vector3(0.42, 0.20, -0.30), ponta + Vector3(0, 0.04, 0), 30.0],
		[T_GOTA, ponta + Vector3(0.30, 0.12, -0.20), ponta, 24.0]])
	# a gota: nasce na ponta, engorda, desprende e cai DEVAGAR ate' o peito dele
	_posar(atores["Jonny"], "caido_agonia", 0.0)
	var peito: Vector3 = atores["Jonny"].posicao_do_osso("chest")
	var chao_gota := Vector3(ponta.x, peito.y + 0.09, ponta.z)
	_valor("efeitos/gota:visible", [[0.0, false], [T_GOTA, true], [T_GOTA_BATE, false]], true)
	var gp := []
	for i in 13:
		var u := i / 12.0
		gp.append([T_GOTA_CAI + u * (T_GOTA_BATE - T_GOTA_CAI), ponta.lerp(chao_gota, u * u)])
	_pos("efeitos/gota", [[T_GOTA, ponta + Vector3(0, -0.004, 0)]] + gp)
	_valor("efeitos/gota:scale", [[T_GOTA, Vector3(0.3, 0.3, 0.3)],
		[T_GOTA_CAI - 0.2, Vector3(1.0, 1.15, 1.0)], [T_GOTA_CAI, Vector3(0.9, 1.4, 0.9)],
		[T_GOTA_CAI + 0.15, Vector3(1.0, 1.0, 1.0)], [T_GOTA_BATE, Vector3(1.0, 1.25, 1.0)]])
	_pos("efeitos/respingo", [[0.0, chao_gota]])
	_pos("efeitos/respingo_gota", [[0.0, chao_gota]])
	_valor("efeitos/respingo_gota:scale", [[0.0, Vector3(0.01, 1, 0.01)],
		[T_GOTA_BATE, Vector3(0.01, 1, 0.01)], [T_GOTA_BATE + 0.25, Vector3(1, 1, 1)]])
	_metodo([[T_GOTA_BATE, "estourar", [NodePath("efeitos/respingo")]],
		[T_GOTA_BATE, "vibrar", [0.25, 0.15]]])
	# na queda a camera desce JUNTO com a gota, mirando nela: a gota fica no
	# meio da tela (o meio nitido do `foco`) e o resto passa borrado
	var cg := [[T_GOTA, ponta + Vector3(0.24, 0.02, -0.16), ponta + Vector3(0, -0.01, 0), 22.0],
		[T_GOTA_CAI, ponta + Vector3(0.24, 0.0, -0.16), ponta + Vector3(0, -0.03, 0), 22.0]]
	for i in range(1, 12):
		var u := i / 12.0
		var g := ponta.lerp(chao_gota, u * u)
		cg.append([T_GOTA_CAI + u * (T_GOTA_BATE - T_GOTA_CAI),
			g + Vector3(0.24, 0.0, -0.16).lerp(Vector3(0.30, 0.10, -0.24), u), g,
			lerpf(22.0, 26.0, u)])
	cg.append([T_GOTA_BATE, chao_gota + Vector3(0.30, 0.10, -0.24), chao_gota, 26.0])
	cg.append([T_LONGE, chao_gota + Vector3(0.36, 0.16, -0.30), chao_gota, 28.0])
	_cam("cam_gota", cg)
	_som("gota", [[T_GOTA_CAI - 0.1]])
	# um tico depois do fim da camera lenta: o pingo soa no tom certo
	_som("gota_impacto", [[T_GOTA_BATE + 0.01]])
	# o coracao batendo na queda, em primeiro plano, e some depois do pingo
	_som("batimento", [[T_GOTA_CAI - 0.15]])
	_valor("sons/batimento:volume_db", [[0.0, 3.0], [T_GOTA_BATE + 0.4, 3.0],
		[T_LONGE + 1.5, -30.0]])

	# ---------------------------------------------------------------- o sussurro
	_clipe("DonaNice", [[0.0, "ajoelhada_sussurro"], [T_LEVANTA, "levantar"],
		[T_CABECA, "girar_cabeca"], [T_CABECA + dur_cabeca, "olhando_parada"],
		[T_VIRA, "virar_corpo"], [T_CONVULSAO, "convulsao"]])
	_valor("atores/DonaNice/anim:speed_scale", [[0.0, 1.0], [T_CABECA, VEL_CABECA],
		[T_CABECA + dur_cabeca, 1.0]], true)
	# o pescoco torcendo: espirra sangue, e ela fica suja dele
	var jorro_k := [[0.0, false]]
	for tr in TORCE_PESCOCO:
		jorro_k.append([T_CABECA + tr[0] / VEL_CABECA, true])
		jorro_k.append([T_CABECA + tr[1] / VEL_CABECA, false])
	_valor("atores/DonaNice/modelo/dona_nice_rig/Skeleton3D/pescoco/jorro:emitting", jorro_k, true)
	_valor("atores/DonaNice:sangue", [[0.0, 0.55], [T_CABECA + TORCE_PESCOCO[0][0] / VEL_CABECA, 0.55],
		[T_CABECA + TORCE_PESCOCO[1][1] / VEL_CABECA, 0.85]])
	_som("sussurro", [[0.0]])
	_valor("sons/sussurro:volume_db", [[0.0, -20.0], [T_OMBRO, -12.0], [T_FACA, -6.0],
		[T_LONGE, -2.0], [T_LEVANTA + 2.0, -4.0], [T_CABECA, -30.0]])
	_som("ambiente", [[0.0]])
	_metodo([[T_LONGE + 0.6, "legenda", ["IGR_SUSSURRO_1", 3.0]],
		[T_LONGE + 3.6, "legenda", ["IGR_SUSSURRO_2", 3.0]],
		[T_LEVANTA - 0.6, "legenda", ["IGR_SUSSURRO_3", 3.2]],
		[T_LEVANTA + 2.6, "legenda", ["IGR_SUSSURRO_4", 2.8]],
		[T_OLHOS + 0.4, "legenda", ["IGR_SUSSURRO_5", 2.6]]])
	_cam("cam_longe", [
		[T_LONGE, Vector3(1.3, 1.75, J.z + 8.0), Vector3(0.0, 0.5, J.z - 0.3), 30.0],
		[T_LEVANTA, Vector3(1.0, 1.65, J.z + 6.6), Vector3(0.0, 0.5, J.z - 0.3), 30.0]])
	_cam("cam_levanta", [
		[T_LEVANTA, Vector3(0.75, 0.55, J.z + 2.3), Vector3(DN.x, 0.8, DN.z), 40.0],
		[T_LEVANTA + 2.2, Vector3(0.70, 0.58, J.z + 2.1), Vector3(DN.x, 1.0, DN.z), 40.0],
		[T_CABECA, Vector3(0.65, 0.62, J.z + 1.9), Vector3(DN.x, 1.35, DN.z), 42.0]])

	# ---------------------------------------------------------------- a cabeca
	_cam_cabeca(T_CABECA, t_dispara, t_chega, t_volta, T_SACA)
	# o pescoco estalando enquanto torce
	_som("pescoco", [[T_CABECA]])
	_som("batimento_rapido", [[T_OLHOS - 0.3]])

	# ---------------------------------------------------------------- a arma
	_som("arma", [[T_SACA + 0.5]])
	_cam("cam_sacar", [
		[T_SACA, Vector3(0.95, 1.45, MAYCOW_FIM.z + 2.5), Vector3(0.0, 1.35, MAYCOW_FIM.z), 34.0],
		[T_OLHOS, Vector3(0.85, 1.48, MAYCOW_FIM.z + 2.3), Vector3(-0.1, 1.42, MAYCOW_FIM.z), 32.0]])
	_posar(dn, "girar_cabeca", 3.49)
	var cabeca: Vector3 = dn.posicao_do_osso("head") + Vector3(0, 0.08, 0)
	# O rosto dela de perto, na fala, e o zoom nos olhos. O `_posar` troca de
	# clipe MISTURANDO e, sem o tempo andar, a pose ficava a de antes
	# (ajoelhada): o `_cam_olhos` posa sem mistura, com ela de pe'.
	_cam_olhos(T_OLHOS, T_ZOOM, T_MIRA, T_CABECA + dur_cabeca)
	_cam("cam_mira", [
		[T_MIRA, Vector3(-0.32, 1.68, MAYCOW_FIM.z - 0.25), cabeca - Vector3(0, 0.55, 0), 30.0],
		[T_VIRA, Vector3(-0.30, 1.67, MAYCOW_FIM.z - 0.1), cabeca - Vector3(0, 0.50, 0), 26.0]])

	# ---------------------------------------------------------------- vira o corpo
	_cam("cam_lateral", [
		[T_VIRA, Vector3(-4.3, 1.4, DN.z - 4.0), Vector3(DN.x, 1.15, DN.z), 36.0],
		[T_CONVULSAO, Vector3(-4.0, 1.35, DN.z - 3.6), Vector3(DN.x, 1.15, DN.z), 36.0]])
	# no fim do virar_corpo ela olha pra porta; o no' gira 180 graus no mesmo
	# quadro em que o clipe seguinte comeca de frente
	var de_frente := Quaternion(Vector3.UP, PI)
	_rot("atores/DonaNice", [[0.0, Quaternion()], [T_CONVULSAO - 0.001, Quaternion()],
		[T_CONVULSAO, de_frente]])

	# ---------------------------------------------------------------- transformacao
	var mo: Node3D = atores["Monstro"]
	mo.position = DN
	_pos("atores/Monstro", [[0.0, DN]])
	_rot("atores/Monstro", [[0.0, de_frente]])
	_valor("atores/Monstro:visible", [[0.0, false], [T_CONVULSAO, true]], true)
	_clipe("Monstro", [[T_CONVULSAO, "convulsao"], [T_RUGIDO, "rugido"]])
	# ela fica arqueada de bracos erguidos (o meio do rugido, 0,8-2,0 s) ate' o
	# fim, enquanto os bancos voam: o clipe quase para nesse trecho
	_valor("atores/Monstro/anim:speed_scale", [[0.0, 1.0], [T_RUGIDO + 1.3, 0.07],
		[T_FIM, 1.0]], true)
	_valor("atores/DonaNice:veias", [[0.0, 0.0], [T_CONVULSAO, 0.0], [T_CONVULSAO + 1.2, 1.0]])
	_valor("atores/Monstro:veias", [[0.0, 0.0], [T_CONVULSAO, 1.0], [T_RUGIDO + 1.5, 0.35]])
	_valor("atores/DonaNice:dissolver", [[0.0, 0.0], [T_CONVULSAO + 1.2, 0.0],
		[T_CONVULSAO + 4.2, 1.0]])
	_valor("atores/Monstro:dissolver", [[0.0, 1.0], [T_CONVULSAO + 1.5, 1.0],
		[T_CONVULSAO + 4.5, 0.0]])
	_valor("atores/DonaNice:visible", [[0.0, true], [T_CONVULSAO + 4.3, false]], true)
	_pos("efeitos/nevoa_sangue", [[0.0, DN + Vector3(0, 1.0, 0)]])
	_valor("efeitos/nevoa_sangue:emitting", [[0.0, false], [T_CONVULSAO + 1.0, true],
		[T_CONVULSAO + 4.4, false]], true)
	_metodo([[T_CONVULSAO + 0.2, "vibrar", [0.4, 0.5]], [T_CONVULSAO + 2.2, "vibrar", [0.7, 0.8]],
		[T_RUGIDO + 0.7, "vibrar", [1.0, 1.2]]])
	_som("ossos", [[T_CONVULSAO]])
	_som("grito", [[T_CONVULSAO + 0.5]])
	_som("grito_monstro", [[t_grito]])
	_metodo([[t_grito + 0.7, "vibrar", [0.8, 0.9]]])
	_som("rugido", [[T_RUGIDO + 0.4]])
	var cam_t := []
	for i in 11:
		var u := i / 10.0
		var ang := deg_to_rad(-25.0 + 95.0 * u)
		var p := DN + Vector3(sin(ang) * 3.1, 1.25 - 0.25 * u, -cos(ang) * 3.1)
		cam_t.append([T_CONVULSAO + u * (T_RUGIDO - T_CONVULSAO), p, DN + Vector3(0, 1.0, 0),
			36.0 - 6.0 * u])
	_cam("cam_transforma", cam_t)
	_cam("cam_rugido", [
		[T_RUGIDO, DN + Vector3(0.35, 0.85, -2.6), DN + Vector3(0, 1.45, 0), 42.0],
		[T_RUGIDO + 0.7, DN + Vector3(0.30, 0.80, -2.2), DN + Vector3(0, 1.55, 0), 48.0],
		[T_BANCOS, DN + Vector3(0.25, 0.95, -3.4), DN + Vector3(0, 1.4, 0), 40.0]])

	# ---------------------------------------------------------------- os bancos
	# A camera sai de perto dela, sobe e recua pro lado do altar, vendo a
	# nave inteira ate' a porta: os bancos voam pras naves laterais e o meio
	# fica livre pra luta (`bancos_igreja.gd`).
	_metodo([[T_BANCOS + 0.6, "afastar_bancos", []], [T_BANCOS + 0.8, "vibrar", [0.9, 2.0]]])
	_cam("cam_bancos", [
		[T_BANCOS, DN + Vector3(0.6, 1.9, 2.6), DN + Vector3(0, 1.3, 0), 46.0],
		[T_BANCOS + 1.2, DN + Vector3(0.4, 3.6, 5.0), DN + Vector3(0, 0.9, -3.0), 52.0],
		[T_FIM, Vector3(0.3, 7.6, DN.z + 8.5), Vector3(0.0, 0.2, DN.z - 9.0), 58.0]])


## Quanto o Maycow ja' andou na entrada aos `t` s: MAYCOW_VELOCIDADE ate'
## comecar a frear e freando reto ate' parar (ANDA_ESTICANDO_FREIA).
func _andou(t: float, t_mao: float) -> float:
	var t_freia := t_mao + ANDA_ESTICANDO_FREIA.x
	var t_para := t_mao + ANDA_ESTICANDO_FREIA.y
	var s := MAYCOW_VELOCIDADE * minf(t, t_freia)
	if t > t_freia:
		var u := minf((t - t_freia) / (t_para - t_freia), 1.0)
		s += MAYCOW_VELOCIDADE * (t_para - t_freia) * (u - u * u * 0.5)
	return s


## O clipe da entrada: o Maycow ANDANDO enquanto estica a mao. Nao existe no
## Blender — e' montado aqui, osso a osso, de tres capturas:
##   - quadril e pernas do `correr_carregando` (a passada de quem carrega o
##     Jonny, bem melhor que a do `andar_lento`). O clipe anda junto com o
##     chao percorrido (`_andou`), entao a passada desacelera com o corpo, e e'
##     acertado pra ele parar com os pes juntos (PES_JUNTOS) — dai' a pose
##     parada do `esticar_mao` entra sem arrastar pe';
##   - coluna, bracos e cabeca do `andar_lento` (os do colo seguram o Jonny),
##     presos a fase das pernas (BRACOS_NA_PASSADA): braco oposto a perna, e
##     a palma esquerda virada pro corpo (GIRO_PALMA_ESQUERDA). O
##     quadril do colo inclina pra tras e pra frente a cada passo (o peso do
##     Jonny); a base da coluna desfaz isso, senao a cabeca balanca 7 cm por
##     passo — o tronco fica com a postura do `andar_lento`;
##   - o braco direito e a cabeca passam pro `esticar_mao` a partir de
##     `t_mao`; o resto do corpo so' quando ele para.
## Vai numa biblioteca propria do duble ("cena"), gravada nesta cena: a
## `maycow_clipes.tres` nao muda.
func _andar_esticando(t_mao: float) -> void:
	var ap := atores["Maycow"].get_node("anim") as AnimationPlayer
	var passo := ap.get_animation("correr_carregando")
	var bracos := ap.get_animation("andar_lento")
	var estica := ap.get_animation("esticar_mao")
	var novo := Animation.new()
	novo.length = t_mao + 3.2
	var t_para := t_mao + ANDA_ESTICANDO_FREIA.y
	const PERNAS := ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
		"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
	const MAO := ["RightShoulder", "RightArm", "RightForeArm", "RightHand", "neck",
		"Head", "head_end", "headfront"]
	# o tempo do passo em que ele chega parado com os pes juntos
	var fase0 := PES_JUNTOS - _andou(t_para, t_mao) / PASSO_DO_COLO
	var esq := String(estica.track_get_path(0).get_concatenated_names())
	var quadril_passo := passo.find_track(NodePath(esq + ":Hips"), Animation.TYPE_ROTATION_3D)
	var quadril_bracos := bracos.find_track(NodePath(esq + ":Hips"), Animation.TYPE_ROTATION_3D)
	var sk: Skeleton3D = atores["Maycow"].esqueleto()
	var antebraco := sk.get_bone_rest(sk.find_bone("LeftHand")).origin.normalized()
	var meio_giro := Quaternion(antebraco, deg_to_rad(GIRO_PALMA_ESQUERDA) * 0.5)
	for i in estica.get_track_count():
		var caminho := estica.track_get_path(i)
		var tipo := estica.track_get_type(i)
		var osso := String(caminho.get_concatenated_subnames())
		var de := passo if osso in PERNAS else bracos
		var j := de.find_track(caminho, tipo)
		var n := novo.add_track(tipo)
		novo.track_set_path(n, caminho)
		for q in int(novo.length * 30.0) + 1:
			var t := q / 30.0
			var te := clampf(t - t_mao, 0.0, estica.length)
			var tp := fposmod(fase0 + _andou(t, t_mao) / PASSO_DO_COLO, passo.length)
			var td := tp if de == passo \
				else fposmod(tp / passo.length + BRACOS_NA_PASSADA, 1.0) * bracos.length
			# peso do `esticar_mao`: o braco da mao entra de cara, o resto so'
			# no fim, com ele parando
			var w := smoothstep(t_mao, t_mao + 0.5, t) if osso in MAO \
				else smoothstep(t_para - 0.45, t_para + 0.05, t)
			if tipo == Animation.TYPE_POSITION_3D:
				var a0: Vector3 = de.position_track_interpolate(j, td) if j >= 0 \
					else estica.position_track_interpolate(i, te)
				novo.position_track_insert_key(n, t, a0.lerp(estica.position_track_interpolate(i, te), w))
			elif tipo == Animation.TYPE_ROTATION_3D:
				var q0: Quaternion = de.rotation_track_interpolate(j, td) if j >= 0 \
					else estica.rotation_track_interpolate(i, te)
				# (no rig do Meshy a coluna e' invertida: o Spine02 e' o filho do quadril)
				if osso == "Spine02" and j >= 0:
					q0 = passo.rotation_track_interpolate(quadril_passo, tp).inverse() \
						* bracos.rotation_track_interpolate(quadril_bracos, td) * q0
				elif osso == "LeftForeArm" and j >= 0:
					q0 = q0 * meio_giro
				elif osso == "LeftHand" and j >= 0:
					q0 = meio_giro * q0
				novo.rotation_track_insert_key(n, t, q0.slerp(estica.rotation_track_interpolate(i, te), w))
	var cena_lib := AnimationLibrary.new()
	cena_lib.add_animation("andar_esticando", novo)
	ap.add_animation_library("cena", cena_lib)


## A ponta da faca no mundo, pela mao e pelo pivo (o BoneAttachment so' anda
## no proximo quadro, entao a conta e' feita direto).
func _ponta_da_faca() -> Vector3:
	var dn: Node3D = atores["DonaNice"]
	var mao := _global_do_osso(dn, "hand.R")
	var pivo := dn.find_child("pivo_faca", true, false) as Node3D
	return mao * pivo.transform * Vector3(0.0, 0.236, -0.004)


## A camera que gira com a cabeca dela. Fica atras da cabeca, olhando pra
## onde ela olha: comeca vendo o altar por cima do ombro dela, e conforme a
## cabeca gira 180 graus (devagar: VEL_CABECA) a camera gira junto — e
## termina vendo o que ela ve', o Maycow la' na porta, com a mao esticada.
## Ai' ela DISPARA ate' ele (`t_dispara` -> `t_chega`, acelerando), para na
## frente do rosto dele e gira no lugar de volta pra ela (`t_volta`).
func _cam_cabeca(t0: float, t_dispara: float, t_chega: float, t_volta: float,
		t_fim: float) -> void:
	var dn: Node3D = atores["DonaNice"]
	var chaves := []
	var marcos := [[0.0, 0.0], [0.5, 12.0], [0.9, 18.0], [1.25, 95.0], [1.5, 90.0],
		[1.9, 100.0], [2.4, 172.0], [2.6, 188.0], [2.85, 178.0], [3.5, 180.0]]
	var rosto := MAYCOW_FIM + Vector3(0, 1.6, 0)
	for i in 30:
		var t := i * 0.1
		_posar(dn, "girar_cabeca", t)
		var cab: Vector3 = dn.posicao_do_osso("head") + Vector3(0, 0.12, 0)
		var g := deg_to_rad(_interp_marcos(marcos, t))
		var olha := Vector3(sin(g), 0.0, cos(g))
		var p := cab - olha * 0.95 + Vector3(0, 0.32, 0) + olha.cross(Vector3.UP) * 0.30
		var alvo := cab + olha * 8.0 + Vector3(0, -0.2, 0)
		if t > 2.5:
			alvo = alvo.lerp(rosto - Vector3(0, 0.2, 0), (t - 2.5) / 0.4)
		chaves.append([t0 + t / VEL_CABECA, p, alvo, 50.0])
	# o disparo: da cabeca dela ate' ~1,4 m do rosto dele, acelerando (do lado
	# oposto ao da mao esticada, que fica no -X)
	var ini: Vector3 = chaves[-1][1]
	var perto := rosto + Vector3(0.45, 0.04, 1.3)
	for i in range(1, 6):
		var u := i / 5.0
		var p := ini.lerp(perto, u * u)
		chaves.append([lerpf(t_dispara, t_chega, u), p, rosto, lerpf(50.0, 36.0, u)])
	# e o giro de volta, no lugar, ate' olhar pra ela — pelo +X: pelo outro
	# lado a camera atravessava o braco esticado dele
	_posar(dn, "olhando_parada", 0.0)
	var dela: Vector3 = dn.posicao_do_osso("head")
	var giro0 := Basis.looking_at(rosto - perto, Vector3.UP)
	var giro1 := Basis.looking_at(dela - perto, Vector3.UP)
	for i in range(1, 5):
		var u := i / 4.0
		var k := u * u * (3.0 - 2.0 * u)
		var ang := lerpf(0.0, -PI, k)
		var b := giro0.rotated(Vector3.UP, ang)
		var alvo := perto + (-b.z) * 6.0
		if i == 4:
			alvo = dela
		chaves.append([lerpf(t_chega, t_volta, u), perto, alvo, lerpf(36.0, 30.0, u)])
	chaves.append([t_fim, perto + Vector3(0, 0, 0.12), dela, 27.0])
	_cam("cam_cabeca", chaves)


## O rosto dela de perto, na fala, e depois o zoom nos olhos. A camera mira o
## meio dos olhos e acompanha a cabeca, que respira no `olhando_parada`: as
## chaves saem da cabeca posada a cada 0,2 s. A lente deixa nitido so' em
## volta de cada olho: a cena projeta `olhos_no_osso` na tela a cada quadro.
func _cam_olhos(t0: float, t_zoom: float, t_fim: float, t_clipe: float) -> void:
	var dn: Node3D = atores["DonaNice"]
	var L := (dn.get_node("anim") as AnimationPlayer).get_animation("olhando_parada").length
	var olho_local: Vector3 = (OLHOS_NO_OSSO[0] + OLHOS_NO_OSSO[1]) * 0.5
	raiz.olhos_no_osso = PackedVector3Array(OLHOS_NO_OSSO)
	# (tempo, deslocamento da camera a partir dos olhos, fov)
	var marcos := [[t0, Vector3(0.10, 0.0, -0.56), 30.0], [t_zoom, Vector3(0.07, 0.0, -0.46), 28.0],
		[t_zoom + 1.4, Vector3(0.03, 0.0, -0.42), 13.0], [t_fim, Vector3(0.025, 0.0, -0.40), 11.0]]
	var chaves := []
	var t := t0
	while true:
		var i := 0
		while i < marcos.size() - 2 and t > marcos[i + 1][0]:
			i += 1
		var u := smoothstep(marcos[i][0], marcos[i + 1][0], t)
		var desloc: Vector3 = (marcos[i][1] as Vector3).lerp(marcos[i + 1][1], u)
		var fov := lerpf(marcos[i][2], marcos[i + 1][2], u)
		_posar_seco(dn, "olhando_parada", fmod(t - t_clipe, L))
		var olhos := _global_do_osso(dn, "head") * olho_local
		chaves.append([t, olhos + desloc, olhos, fov])
		if t >= t_fim:
			break
		t = minf(t + 0.2, t_fim)
	_cam("cam_olhos", chaves)


func _interp_marcos(m: Array, t: float) -> float:
	for i in m.size() - 1:
		if m[i][0] <= t and t <= m[i + 1][0]:
			var u: float = (t - m[i][0]) / (m[i + 1][0] - m[i][0])
			return lerpf(m[i][1], m[i + 1][1], u * u * (3.0 - 2.0 * u))
	return m[-1][1]


# ==============================================================================
# OS PALCOS: as cutscenes que acontecem onde a luta deixou a Dona Nice
# ==============================================================================
## `palco_fase_2` e' posto pela igreja (evento_dona_nice.gd) onde a fase 1
## morreu, de frente pra onde ela estava virada. Tudo dentro dele — a monstro
## morrendo, a gigante nascendo e as cameras — anda junto. No editor ele fica
## no meio da nave, pra dar pra ver.
func _palcos() -> void:
	var p := _no(Node3D, "palco_fase_2", raiz) as Node3D
	p.position = Vector3(0.0, 0.0, 14.0)
	p.rotation.y = PI
	p.editor_description = "Posto no jogo onde a fase 1 morreu. Atores e cameras daqui andam junto."
	var morrendo := _instancia(ATORES + "dona_nice_monster.tscn", "Morrendo", p) as Node3D
	morrendo.visible = false
	morrendo.veias = 1.0
	morrendo.sangue = 0.35
	var gigante := _instancia(ATORES + "dona_nice_monster_fase_2.tscn", "Gigante", p) as Node3D
	gigante.visible = false
	gigante.dissolver = 1.0
	gigante.veias = 0.6
	for n in [morrendo, gigante]:
		(n.get_node("anim") as AnimationPlayer).playback_default_blend_time = 0.3
		n.clipe_inicial = &""
	atores["Morrendo"] = morrendo
	atores["Gigante"] = gigante
	var ef := _no(Node3D, "efeitos_f2", p)
	var nevoa := (raiz.get_node("efeitos/nevoa_sangue") as GPUParticles3D).duplicate()
	nevoa.name = "nevoa"
	ef.add_child(nevoa)
	nevoa.owner = raiz
	# a morte final acontece num lugar fixo, junto do Jonny
	var pm := _no(Node3D, "palco_morte", raiz) as Node3D
	pm.position = JONNY_POS + Vector3(2.6, 0.0, 2.2)
	pm.rotation.y = deg_to_rad(-140.0)
	var gm := _instancia(ATORES + "dona_nice_monster_fase_2.tscn", "GiganteMorre", pm) as Node3D
	gm.visible = false
	gm.position = Vector3(0, 0.55, 0)
	(gm.get_node("anim") as AnimationPlayer).playback_default_blend_time = 0.3
	gm.clipe_inicial = &""
	atores["GiganteMorre"] = gm
	# onde o corpo dela fica caido, de cara pro Jonny
	var corpo := _no(Marker3D, "corpo_da_monstro", raiz.get_node("efeitos")) as Marker3D
	corpo.position = JONNY_POS + Vector3(2.35, 0.0, 0.55)
	corpo.rotation.y = deg_to_rad(-90.0)


# ==============================================================================
# VIRA_FASE_2: a fase 1 morre e cresce na gigante
# ==============================================================================
func _montar_vira_fase_2() -> void:
	a = Animation.new()
	lib.add_animation("vira_fase_2", a)
	a.length = 9.0
	const P := "palco_fase_2/"
	_valor(".:barras", [[0.0, 0.0], [0.6, 1.0], [8.2, 1.0], [9.0, 0.0]])
	_valor(".:plano", [[0.0, P + "cam_f2_a"], [2.0, P + "cam_f2_b"],
		[5.2, P + "cam_f2_c"], [8.95, ""]], true)
	_valor(".:vermelho", [[0.0, 0.2], [2.0, 0.55], [6.0, 0.4], [9.0, 0.0]])
	_valor(".:tremor", [[0.0, 0.2], [1.8, 0.5], [5.3, 1.0], [7.0, 0.3], [9.0, 0.0]])
	_valor(".:flash", [[0.0, 0.0], [5.3, 0.0], [5.4, 0.6], [6.0, 0.0]])
	_valor(".:borrao", [[0.0, 0.0], [2.5, 0.0], [2.7, 0.85], [3.6, 0.0],
		[5.3, 0.0], [5.4, 0.7], [6.4, 0.0]])
	_valor(".:pulso", [[0.0, 0.3], [1.0, 1.0], [1.6, 0.3], [2.4, 1.0], [3.4, 0.4],
		[5.4, 1.0], [9.0, 0.2]])
	# a monstro: de joelhos, convulsiona, e a carne sai em brasa
	_valor(P + "Morrendo:visible", [[0.0, true], [3.9, false]], true)
	_clipe(P + "Morrendo", [[0.0, "morrer"]])
	_valor(P + "Morrendo:dissolver", [[0.0, 0.0], [1.6, 0.0], [3.8, 1.0]])
	_pos(P + "efeitos_f2/nevoa", [[0.0, Vector3(0, 1.0, 0)]])
	# a gigante nasce no lugar dela, pequena, e cresce subindo do chao
	_valor(P + "Gigante:visible", [[0.0, false], [1.8, true]], true)
	_clipe(P + "Gigante", [[1.9, "surgir"], [4.8, "flutuar"]])
	_valor(P + "Gigante:dissolver", [[0.0, 1.0], [1.8, 1.0], [4.4, 0.0]])
	_valor(P + "Gigante:scale", [[0.0, Vector3.ONE * 0.36], [2.0, Vector3.ONE * 0.36],
		[5.2, Vector3.ONE * 1.0]])
	_pos(P + "Gigante", [[0.0, Vector3.ZERO], [2.0, Vector3.ZERO], [5.2, Vector3(0, 0.55, 0)]])
	_metodo([[0.2, "vibrar", [0.5, 0.6]], [2.2, "estourar", [NodePath(P + "efeitos_f2/nevoa")]],
		[2.6, "vibrar", [0.8, 0.9]], [5.4, "vibrar", [1.0, 1.2]]])
	_som("ossos", [[0.0]])
	_som("grito", [[1.6]])
	# o grito de monstro quando a gigante rompe (o pico vem ~1 s depois)
	_som("grito_monstro", [[1.8]])
	_som("rugido", [[5.0]])
	# cameras do palco (coordenadas do palco: +Z e' pra onde ela olhava)
	_cam(P + "cam_f2_a", [[0.0, Vector3(0.6, 0.9, 2.6), Vector3(0, 0.9, 0), 40.0],
		[2.0, Vector3(0.5, 0.85, 2.2), Vector3(0, 0.95, 0), 38.0]])
	_cam(P + "cam_f2_b", [[2.0, Vector3(-1.2, 1.2, 4.2), Vector3(0, 1.2, 0), 40.0],
		[5.2, Vector3(-2.2, 1.0, 8.4), Vector3(0, 3.0, 0), 46.0]])
	_cam(P + "cam_f2_c", [[5.2, Vector3(1.0, 0.45, 6.6), Vector3(0, 3.4, 0), 52.0],
		[9.0, Vector3(1.4, 0.55, 8.0), Vector3(0, 3.2, 0), 50.0]])


# ==============================================================================
# MORTE_FINAL: a gigante morre e cai, monstro de novo, perto do Jonny
# ==============================================================================
func _montar_morte_final() -> void:
	a = Animation.new()
	lib.add_animation("morte_final", a)
	a.length = 11.0
	const P := "palco_morte/"
	var corpo := raiz.get_node("efeitos/corpo_da_monstro") as Node3D
	_valor(".:barras", [[0.0, 0.0], [0.6, 1.0], [10.2, 1.0], [11.0, 0.0]])
	_valor(".:plano", [[0.0, P + "cam_m_a"], [3.0, P + "cam_m_b"], [6.0, "cam_m_c"],
		[10.95, ""]], true)
	_valor(".:vermelho", [[0.0, 0.4], [4.0, 0.2], [8.0, 0.0]])
	_valor(".:saturacao", [[0.0, 0.85], [6.0, 0.7], [11.0, 0.8]])
	_valor(".:tremor", [[0.0, 0.6], [2.8, 0.8], [4.6, 0.2], [5.4, 0.7], [6.0, 0.0]])
	_valor(".:pulso", [[0.0, 1.0], [2.0, 0.6], [4.0, 0.0]])
	_valor(P + "GiganteMorre:visible", [[0.0, true], [4.7, false]], true)
	_clipe(P + "GiganteMorre", [[0.0, "morrer"]])
	_valor(P + "GiganteMorre:dissolver", [[0.0, 0.0], [2.6, 0.0], [4.6, 1.0]])
	_valor(P + "GiganteMorre:scale", [[0.0, Vector3.ONE], [2.6, Vector3.ONE],
		[4.6, Vector3.ONE * 0.5]])
	# o corpo de verdade aparece por baixo e desaba de cara no chao
	_corpo_caindo(corpo.transform)
	_valor("atores/Monstro:visible", [[0.0, false], [2.8, true]], true)
	_valor("atores/Monstro:dissolver", [[0.0, 1.0], [2.8, 1.0], [4.5, 0.0]])
	_valor("atores/Monstro:veias", [[0.0, 1.0], [6.0, 0.0]])
	_clipe("Monstro", [[2.8, "morrer"], [4.9, "cair_morta"], [6.5, "morta"]])
	_som("rugido", [[0.0]])
	_som("ossos", [[2.6]])
	_metodo([[0.1, "vibrar", [0.6, 0.6]], [5.4, "vibrar", [0.9, 0.5]]])
	# o Jonny continua ali, vivo
	_clipe("Jonny", [[0.0, "caido_agonia"]])
	_som("gemido", [[8.0]])
	_cam(P + "cam_m_a", [[0.0, Vector3(1.6, 0.6, 6.5), Vector3(0, 3.0, 0), 50.0],
		[3.0, Vector3(1.3, 0.7, 5.8), Vector3(0, 2.6, 0), 46.0]])
	_cam(P + "cam_m_b", [[3.0, Vector3(-2.0, 1.4, 4.8), Vector3(0, 1.2, 0), 42.0],
		[6.0, Vector3(-2.2, 1.3, 4.2), Vector3(0, 0.6, 0), 40.0]])
	var J := JONNY_POS
	_cam("cam_m_c", [[6.0, J + Vector3(-1.2, 0.5, -1.8), J + Vector3(1.0, 0.25, 0.4), 40.0],
		[11.0, J + Vector3(-2.0, 3.6, -3.4), J + Vector3(0.8, 0.0, 0.3), 46.0]])


## A monstro morrendo (`morrer` 2,8 s, `cair_morta` 4,9 s, `morta` 6,5 s) com
## a pele sempre no chao: os clipes vem do Blender afundando os pes (`morrer`)
## e deitam a 18 cm do piso (`morta`). A cada 0,1 s o no' sobe ou desce ate' o
## ponto mais baixo da pele tocar o chao, e na queda ela vai girando ate' o
## assentar de deitada (`AtorIgreja.no_chao`, o mesmo do corpo nas visitas).
func _corpo_caindo(base: Transform3D) -> void:
	var mo: Node3D = atores["Monstro"]
	var deitada: Transform3D = mo.no_chao(base)
	var giro_final := (base.basis.inverse() * deitada.basis).get_rotation_quaternion()
	var ps := []
	var rs := []
	var t := 2.8
	while t < 6.5 - 0.01:
		var queda := smoothstep(4.9, 6.5, t)
		var giro := Basis(Quaternion.IDENTITY.slerp(giro_final, queda))
		mo.transform = base * Transform3D(giro, Vector3.ZERO)
		if t < 4.9:
			_posar_seco(mo, "morrer", t - 2.8)
		else:
			_posar_seco(mo, "cair_morta", t - 4.9)
		var sobe := -_pele_mais_baixa(mo)
		var tr := base * Transform3D(giro, Vector3(0.0, sobe, 0.0))
		if ps.is_empty():
			ps.append([0.0, tr.origin])
			rs.append([0.0, tr.basis.get_rotation_quaternion()])
		ps.append([t, tr.origin])
		rs.append([t, tr.basis.get_rotation_quaternion()])
		t += 0.1
	ps.append([6.5, deitada.origin])
	rs.append([6.5, deitada.basis.get_rotation_quaternion()])
	_pos("atores/Monstro", ps)
	_rot("atores/Monstro", rs)
	mo.transform = base


# ==============================================================================
# PEGA_JONNY: ajoelha, ergue o Jonny e corre com ele pra fora da igreja
# ==============================================================================
func _montar_pega_jonny() -> void:
	a = Animation.new()
	lib.add_animation("pega_jonny", a)
	var J := JONNY_POS
	var mc: Node3D = atores["Maycow"]
	var jo: Node3D = atores["Jonny"]
	# o Maycow ajoelha do lado do Jonny, de frente pra ele (do lado da porta)
	var inicio := Vector3(J.x + 0.05, 0.0, J.z - 0.62)
	mc.position = inicio
	mc.rotation = Vector3.ZERO
	_posar(mc, "pegar_jonny", 3.29)
	var md: Vector3 = mc.posicao_do_osso("RightHand")
	var me: Vector3 = mc.posicao_do_osso("LeftHand")
	var colo: Vector3 = (md + me) * 0.5 + Vector3(0, 0.06, 0.04)           # Maycow ainda olhando pro +Z

	const T_LEVANTA := 3.3
	const T_VIRA := 4.1
	const T_CORRE := 4.4
	var porta := Vector3(0.0, 0.0, -1.6)
	var corrida := inicio.distance_to(Vector3(inicio.x, 0, porta.z))
	const VEL := 4.2                            # m/s do correr_carregando
	var t_porta := T_CORRE + corrida / VEL
	# assim que ele sai correndo pra porta a tela vai pro preto, e fica preta
	# ate' a cidade carregar (o evento troca de cena no fim)
	a.length = T_CORRE + 1.0
	var no_fim := inicio.lerp(Vector3(inicio.x, 0, porta.z),
		(a.length - T_CORRE) / (t_porta - T_CORRE))

	_valor(".:barras", [[0.0, 1.0], [a.length, 1.0]])
	_valor(".:preto", [[0.0, 0.0], [T_CORRE, 0.0], [T_CORRE + 0.7, 1.0]])
	_valor(".:plano", [[0.0, "cam_pj_a"], [T_LEVANTA - 0.4, "cam_pj_b"],
		[a.length - 0.05, ""]], true)
	_valor(".:saturacao", [[0.0, 0.8], [a.length, 0.7]])
	_valor("atores/Maycow:visible", [[0.0, true]], true)
	_valor("atores/Maycow/modelo/Armature/Skeleton3D/mao_arma/pivo_arma:visible",
		[[0.0, false]], true)
	_clipe("Maycow", [[0.0, "pegar_jonny"], [T_LEVANTA, "parado_carregando"],
		[T_CORRE, "correr_carregando"]])
	_clipe("Jonny", [[0.0, "sendo_erguido"], [T_LEVANTA, "no_colo"]])
	# Maycow: parado ajoelhando, vira pra porta, corre
	var de_costas := Quaternion(Vector3.UP, PI)
	_pos("atores/Maycow", [[0.0, inicio], [T_CORRE, inicio], [a.length, no_fim]])
	_rot("atores/Maycow", [[0.0, Quaternion()], [T_LEVANTA + 0.1, Quaternion()],
		[T_VIRA, de_costas]])
	# Jonny: preso as maos do Maycow pelo `seguir` do AtorIgreja. Fica no chao
	# ate' as maos dele chegarem nele (1,7 s, debrucado) e cola nelas ate' 2,3 s;
	# dai' em diante sobe, gira e corre junto, sem chave nenhuma de posicao.
	jo.seguir = NodePath("../Maycow")
	jo.seguir_giro_y = JONNY_GIRO
	_valor("atores/Jonny:seguir_peso", [[0.0, 0.0], [1.7, 0.0], [2.3, 1.0]])
	_som("gemido", [[1.2]])
	_som("batimento_rapido", [[T_CORRE]])
	_cam("cam_pj_a", [[0.0, inicio + Vector3(1.4, 0.9, 1.4), inicio + Vector3(0, 0.6, 0.5), 42.0],
		[T_LEVANTA - 0.4, inicio + Vector3(1.2, 0.95, 1.2), inicio + Vector3(0, 0.8, 0.5), 40.0]])
	_cam("cam_pj_b", [[T_LEVANTA - 0.4, inicio + Vector3(-1.6, 1.3, -0.6), colo, 40.0],
		[a.length, inicio + Vector3(-1.4, 1.5, -1.4), inicio + Vector3(0, 1.2, -1.5), 44.0]])


# ==============================================================================
func _gravar() -> void:
	# os atores voltam pro clipe de abertura antes de gravar (a pose do editor)
	for n in atores.values():
		var ap := n.get_node("anim") as AnimationPlayer
		ap.stop()
		# o AtorIgreja troca os materiais no _ready (aqui o jogo esta' rodando);
		# com as instancias editaveis o pack gravaria essas trocas na cena
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			if mi.owner == raiz:
				continue
			for i in (mi as MeshInstance3D).get_surface_override_material_count():
				(mi as MeshInstance3D).set_surface_override_material(i, null)
	remove_child(raiz)
	var cena := PackedScene.new()
	var erro := cena.pack(raiz)
	if erro != OK:
		push_error("montar_cena: pack falhou (%d)" % erro)
		return
	erro = ResourceSaver.save(cena, SAIDA)
	print("== gravado %s (erro %d)" % [SAIDA, erro])
