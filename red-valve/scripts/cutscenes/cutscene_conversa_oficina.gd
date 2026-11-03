extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A CONVERSA NA OFICINA (Capítulo 5), depois do resgate na arena 3.
##
## A red valve da oficina se abre num clarão vermelho e cospe os dois: o Jimmy
## sai primeiro, olhando a oficina dele como quem não acredita; o Maycow (o
## normal, de volta deste lado) vem atrás. Eles param no meio do galpão e o
## Maycow conta TUDO — sem texto nenhum na tela, só os gestos: ele fala com a
## mão aberta, o Jimmy ouve, pergunta, leva a mão à cabeça.
##
## Enquanto ele conta, vêm os FLASHES do que aconteceu, não nos lugares de
## verdade e sim num "universo paralelo": só os protagonistas de cada momento,
## soltos num fundo de nebulosa que gira (`universo_paralelo.gdshader`), um
## redemoinho roxo atrás (`portal_vortice.gdshader`), partículas rodando em
## volta e luzes coloridas voando. Cada flash entra e sai num clarão, e entre
## um e outro a câmera volta pra oficina, noutro ângulo:
##
##   a escola — a Dona Nice levando o Jonny pela mão
##   o Grizzolito rugindo
##   o ritual — a Dona Nice ajoelhada sobre o Jonny
##   a Dona Nice monstro
##   a Drizzi conversando com o Maycow
##   a Drizzi monstro
##   o Maycow queimando com o amuleto (a arena 2)
##   o Jimmy na jaula
##
## No fim a câmera se afasta dos dois e a tela apaga BEM devagar; quem leva à
## cidade é a oficina (`capitulo_5_oficina.gd`).
##
## O Maycow é o próprio jogador, com o corpo na mão da cena
## (`corpo_do_maycow.gd`: os clipes do .glb dele). O palco dos flashes fica bem
## acima do galpão, longe de tudo.

const CorpoDoMaycow := preload("res://scripts/cutscenes/corpo_do_maycow.gd")
const AtorJimmy := preload("res://scripts/npcs/jimmy/ator_jimmy.gd")
const AtorDrizzi := preload("res://scripts/npcs/drizzi/ator_drizzi.gd")
const JaulaDoJimmy := preload("res://scripts/stages/battlefield/jaula_do_jimmy.gd")
const FOGO := preload("res://scenes/effects/parasite_fire.tscn")
const UNIVERSO := preload("res://shaders/cutscenes/universo_paralelo.gdshader")
const VORTICE := preload("res://shaders/environment/portal_vortice.gdshader")
const SOM_FLASH := "res://assets/sounds/capitulo_4/flash_memoria.ogg"
const SOM_PORTAL := "res://assets/sounds/episodios/portal_red_valve.mp3"

const CENA_DONA := "res://scenes/npcs/igreja/dona_nice.tscn"
const CENA_JONNY := "res://scenes/npcs/igreja/jonny.tscn"
const CENA_MONSTRO := "res://scenes/npcs/igreja/dona_nice_monster.tscn"
const CENA_MAYCOW := "res://scenes/npcs/igreja/maycow_cena.tscn"
const CLIPES_NICE_ESCOLA := "res://assets/3d_model/npc/escola/dona_nice_escola_clipes.glb"
const CLIPES_JONNY_ESCOLA := "res://assets/3d_model/npc/escola/jonny_escola_clipes.glb"
const MODELO_MAYCOW_NORMAL := "res://assets/3d_model/player/Maycow Lopes/maycow_normal/maycow_normal_rigged.glb"
const MODELO_GRIZZOLITO := "res://assets/3d_model/enemies/anti_lopes_members/grizzolito/grizzolito.glb"
const MODELO_PARASITA := "res://assets/3d_model/player/Maycow Lopes/maycow_lopes.glb"
const CLIPES_PARASITA_CAP4 := "res://assets/3d_model/npc/capitulo_4/maycow_parasita_clipes.glb"

## Onde os dois conversam: o miolo livre do galpão, entre a red valve e a
## porta da rua (o chão sai de um raio).
const MAYCOW_AQUI := Vector3(-2.6, 0.0, -3.4)
const JIMMY_AQUI := Vector3(-1.9, 0.0, -2.0)
## O palco dos flashes: bem acima do galpão.
const PALCO := Vector3(0.0, 260.0, 0.0)
const FLASHES := ["escola", "grizzolito", "ritual", "monstro", "drizzi", "drizzi_monstro", "fogo", "jaula"]
const DUR_FLASH := 2.7
const DUR_CONVERSA := 2.4
const RAIO_FUNDO := 34.0
const LAYER_CHAO := 2
const PISO := -5.32

var porta: Node3D
var jimmy: Node3D

var _corpo: RefCounted
var _palco: Node3D
var _vortice: MeshInstance3D
var _girando: Array[Node3D] = []
var _luzes: Array[OmniLight3D] = []
var _chave: SpotLight3D
var _set: Node3D
var _proximo: Node3D
var _proximo_cam: Dictionary = {}
var _no_palco := false
var _tempo := 0.0
var _chao_y := PISO


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 52.0)
	await escurecer(1.0, 0.01)
	_chao_y = _chao(MAYCOW_AQUI)
	if is_instance_valid(player) and player.has_method("apagar_lanterna_agora"):
		player.apagar_lanterna_agora()
	_montar_palco()
	jimmy = AtorJimmy.new()
	jimmy.name = "jimmy_conversa"
	cena.add_child(jimmy)
	jimmy.visible = false
	await _chegada()
	if not vale():
		return

	# --- a conversa e os flashes
	_corpo = CorpoDoMaycow.assumir(player)
	_virar_um_pro_outro()
	_corpo.tocar(&"normal/Talk_with_Right_Hand_Open", 0.4)
	jimmy.tocar(&"ouvindo", 0.4)
	_preparar_set(FLASHES[0])
	await _plano_oficina(0, 3.4)
	for i in FLASHES.size():
		if not vale():
			return
		await _flash()
		_reacao_do_jimmy(String(FLASHES[i]))
		if i + 1 < FLASHES.size():
			_preparar_set(FLASHES[i + 1])
		await _plano_oficina((i + 1) % 4, DUR_CONVERSA + (1.6 if FLASHES[i] == "ritual" else 0.0))
	if not vale():
		return
	await _final()


# ==============================================================================
# A CHEGADA PELA RED VALVE
# ==============================================================================

func _chegada() -> void:
	var frente := porta.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var lado := frente.cross(Vector3.UP).normalized()
	var boca := porta.global_position + frente * 0.8
	var j_ate := Vector3(JIMMY_AQUI.x, _chao(JIMMY_AQUI), JIMMY_AQUI.z)
	var m_ate := Vector3(MAYCOW_AQUI.x, _chao_y, MAYCOW_AQUI.z)
	# o Maycow espera na boca, sem aparecer, até a vez dele
	esconder_modelo(true)
	_por_player(boca, m_ate)
	jimmy.global_position = boca
	jimmy.olhar_para(j_ate)
	var cam_de := porta.global_position + frente * 4.6 - lado * 1.8 + Vector3.UP * 1.5
	var cam_ate := (boca + j_ate) * 0.5 + frente * 0.6 - lado * 3.6 + Vector3.UP * 1.6
	plantar(cam_de, porta.global_position + Vector3.UP * 1.2)
	porta.abrir_sem_sugar()
	escurecer(0.0, 1.4)
	await esperar(1.2)
	clarao(0.55, 0.7)
	_som(SOM_PORTAL, -2.0)
	jimmy.visible = true
	jimmy.tocar(&"andar", 0.0)
	var dur := boca.distance_to(j_ate) / 1.35
	var estado := {"maycow": false}
	await fase(dur, func(k: float) -> void:
		jimmy.global_position = boca.lerp(j_ate, k)
		var olhar := (jimmy.global_position + Vector3.UP * 1.25).lerp(porta.global_position + Vector3.UP * 1.0, 0.25)
		plantar(cam_de.lerp(cam_ate, suave(k)), olhar)
		if not estado["maycow"] and k > 0.3:
			estado["maycow"] = true
			_maycow_sai(m_ate))
	if not vale():
		return
	# o Jimmy para e olha a oficina dele, de volta
	jimmy.tocar(&"parado", 0.4)
	var porta_portal = porta.get("_portal")
	if porta_portal:
		porta_portal.ventar(false)
	porta.call("_fechar", 1.2)
	await esperar(1.6)


## O jogador anda sozinho da boca da red valve até o lugar dele.
func _maycow_sai(alvo: Vector3) -> void:
	esconder_modelo(false)
	clarao(0.3, 0.4)
	player.cutscene_set_auto_walk(true)
	var limite := 9.0
	while limite > 0.0 and vale():
		await get_tree().process_frame
		limite -= get_process_delta_time()
		var m := _modelo_pos()
		var d := Vector3(alvo.x - m.x, 0.0, alvo.z - m.z)
		if d.length() < 0.35:
			break
		player.global_rotation.y = atan2(-d.x, -d.z)
	if is_instance_valid(player):
		player.cutscene_set_auto_walk(false)
		player.velocity = Vector3.ZERO


## Gira os dois de frente um pro outro.
func _virar_um_pro_outro() -> void:
	var m := _modelo_pos()
	var d := jimmy.global_position - m
	player.global_rotation.y = atan2(-d.x, -d.z)
	jimmy.olhar_para(m)


# ==============================================================================
# OS PLANOS NA OFICINA
# ==============================================================================

func _plano_oficina(angulo: int, dur: float) -> void:
	var m := _modelo_pos()
	var j := jimmy.global_position
	var u := Vector3(j.x - m.x, 0.0, j.z - m.z).normalized()
	var p := Vector3(u.z, 0.0, -u.x)
	var cab_m := m + Vector3.UP * 1.6
	var cab_j: Vector3 = jimmy.cabeca()
	var meio := (cab_m + cab_j) * 0.5
	var de: Vector3
	var ate: Vector3
	var olhar_de: Vector3
	var olhar_ate: Vector3
	match angulo:
		0:
			# os dois de lado, a câmera chegando devagar
			de = meio - p * 3.0 + Vector3.DOWN * 0.1
			ate = meio - p * 2.5 + u * 0.2
			olhar_de = meio
			olhar_ate = meio
		1:
			# por cima do ombro do Jimmy: o Maycow contando
			de = cab_j + u * 0.7 - p * 0.4 + Vector3.UP * 0.05
			ate = cab_j + u * 0.55 - p * 0.32
			olhar_de = cab_m - Vector3.UP * 0.1
			olhar_ate = cab_m
		2:
			# por cima do ombro do Maycow: o Jimmy ouvindo
			de = cab_m - u * 0.7 + p * 0.4 + Vector3.UP * 0.05
			ate = cab_m - u * 0.55 + p * 0.32
			olhar_de = cab_j - Vector3.UP * 0.1
			olhar_ate = cab_j
		_:
			# o rosto do Jimmy, de perto
			de = cab_j - u * 1.0 - p * 0.35
			ate = cab_j - u * 0.8 - p * 0.25
			olhar_de = cab_j
			olhar_ate = cab_j - Vector3.UP * 0.03
	await plano(de, olhar_de, ate, olhar_ate, dur)


func _reacao_do_jimmy(flash: String) -> void:
	match flash:
		"ritual":
			jimmy.tocar(&"mao_na_cabeca", 0.4)
		"drizzi", "fogo":
			jimmy.tocar(&"falando", 0.4)
		_:
			jimmy.tocar(&"ouvindo", 0.4)


## O fim: ele termina de contar, a câmera se afasta e a tela apaga devagar.
func _final() -> void:
	jimmy.tocar(&"ouvindo", 0.5)
	var m := _modelo_pos()
	var j := jimmy.global_position
	var meio := (m + j) * 0.5 + Vector3.UP * 1.3
	var u := Vector3(j.x - m.x, 0.0, j.z - m.z).normalized()
	var p := Vector3(u.z, 0.0, -u.x)
	var de := meio - p * 2.6 + Vector3.UP * 0.2
	var ate := meio - p * 6.5 + u * 1.5 + Vector3.UP * 2.8
	var estado := {"apagando": false, "calou": false}
	await fase(10.0, func(k: float) -> void:
		plantar(de.lerp(ate, suave(k)), meio.lerp(meio + Vector3.DOWN * 0.3, k))
		if not estado["calou"] and k > 0.35:
			estado["calou"] = true
			_corpo.tocar(&"normal/Long_Breathe_and_Look_Around", 0.6)
		if not estado["apagando"] and k > 0.25:
			estado["apagando"] = true
			escurecer(1.0, 7.0))
	await escurecer(1.0, 0.5)
	if _corpo:
		_corpo.soltar()


# ==============================================================================
# OS FLASHES
# ==============================================================================

## Um clarão, o palco com o momento que ele está contando, outro clarão.
func _flash() -> void:
	_relampago()
	await esperar(0.08)
	if is_instance_valid(_set):
		_set.queue_free()
	_set = _proximo
	var cam_p: Dictionary = _proximo_cam
	_proximo = null
	if not is_instance_valid(_set):
		return
	_set.visible = true
	_palco.visible = true
	_no_palco = true
	var raio := float(cam_p.get("raio", 3.4))
	var altura := float(cam_p.get("altura", 1.4))
	var alvo := PALCO + Vector3.UP * float(cam_p.get("alvo", 1.1))
	var g0 := deg_to_rad(float(cam_p.get("g0", 20.0)))
	var giro := deg_to_rad(float(cam_p.get("giro", 32.0)))
	await fase(DUR_FLASH, func(k: float) -> void:
		var g := g0 + giro * k
		var r := raio * (1.0 - 0.12 * k)
		plantar(PALCO + Vector3(sin(g) * r, altura, cos(g) * r), alvo))
	_relampago()
	await esperar(0.08)
	_no_palco = false
	_palco.visible = false
	if is_instance_valid(_set):
		_set.visible = false


func _relampago() -> void:
	clarao(0.92, 0.5)
	_som(SOM_FLASH, -5.0, randf_range(0.9, 1.1))


## Monta o próximo momento (escondido) enquanto a câmera está na oficina.
func _preparar_set(nome: String) -> void:
	_proximo = Node3D.new()
	_proximo.name = "flash_" + nome
	_proximo.visible = false
	_palco.add_child(_proximo)
	_proximo.global_position = PALCO
	var antes := _set
	_set = _proximo
	_proximo_cam = call("_set_" + nome)
	_set = antes


# --- cada momento -------------------------------------------------------------
# Todo ator olha pro +Z do palco; a câmera gira em volta (g = 0 é de frente).

func _set_escola() -> Dictionary:
	var dona := _ator_igreja(CENA_DONA, {"escola": CLIPES_NICE_ESCOLA})
	var jonny := _ator_igreja(CENA_JONNY, {"escola": CLIPES_JONNY_ESCOLA})
	# o Jonny do lado esquerdo dela, de mão dada (como na quadra)
	dona.position = Vector3(-0.28, 0.0, 0.0)
	jonny.position = Vector3(0.27, 0.0, 0.0)
	dona.tocar(&"escola/andar_de_mao", 0.0)
	jonny.tocar(&"escola/andar_de_mao", 0.0)
	return {"raio": 3.3, "altura": 1.25, "alvo": 1.0, "g0": 25.0, "giro": 32.0}


func _set_grizzolito() -> Dictionary:
	var g := _ator_glb(MODELO_GRIZZOLITO)
	_tocar_glb(g, &"rugido")
	return {"raio": 3.6, "altura": 1.5, "alvo": 1.3, "g0": -25.0, "giro": 35.0}


func _set_ritual() -> Dictionary:
	var dona := _ator_igreja(CENA_DONA, {})
	dona.position = Vector3(0.0, 0.0, -0.4)
	dona.tocar(&"ajoelhada_sussurro", 0.0)
	var jonny := _ator_igreja(CENA_JONNY, {})
	jonny.set("sangue", 0.45)
	jonny.global_transform = jonny.no_chao(Transform3D(Basis(Vector3.UP, PI * 0.5), PALCO + Vector3(0.0, 0.0, 0.45)))
	jonny.tocar(&"caido_agonia", 0.0)
	return {"raio": 2.8, "altura": 1.9, "alvo": 0.45, "g0": 40.0, "giro": 30.0}


func _set_monstro() -> Dictionary:
	var m := _ator_igreja(CENA_MONSTRO, {})
	m.tocar(&"rugido", 0.0)
	return {"raio": 4.4, "altura": 1.7, "alvo": 1.7, "g0": 15.0, "giro": 30.0}


func _set_drizzi() -> Dictionary:
	var d = AtorDrizzi.criar(_set, Transform3D(Basis(), PALCO + Vector3(0.0, 0.0, -0.8)), false)
	d.tocar(&"conversando", 0.0)
	var maycow := _ator_igreja(CENA_MAYCOW, {})
	_somar_clipes(maycow.get_node_or_null("anim") as AnimationPlayer, &"normal", MODELO_MAYCOW_NORMAL)
	maycow.position = Vector3(0.0, 0.0, 0.8)
	maycow.rotation.y = PI
	maycow.tocar(&"normal/Long_Breathe_and_Look_Around", 0.0)
	return {"raio": 3.4, "altura": 1.5, "alvo": 1.3, "g0": 80.0, "giro": 30.0}


func _set_drizzi_monstro() -> Dictionary:
	var d = AtorDrizzi.criar(_set, Transform3D(Basis(), PALCO + Vector3(0.0, 0.4, 0.0)), true)
	d.tocar(&"gritar", 0.0)
	return {"raio": 4.2, "altura": 2.0, "alvo": 1.9, "g0": 10.0, "giro": 32.0}


func _set_fogo() -> Dictionary:
	var p := _ator_glb(MODELO_PARASITA)
	var ap := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_somar_clipes(ap, &"cap4", CLIPES_PARASITA_CAP4)
	_tocar_glb(p, &"cap4/agonia_fogo")
	var esqueleto := p.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto:
		for m in [["Hips", "Head", 0.34, 1.25, true], ["LeftArm", "LeftHand", 0.09, 0.85, false],
				["RightArm", "RightHand", 0.09, 0.85, false]]:
			var fogo = FOGO.instantiate()
			fogo.mask_skeleton = esqueleto
			fogo.mask_bone_from = String(m[0])
			fogo.mask_bone_to = String(m[1])
			fogo.mask_radius = float(m[2])
			fogo.flame_scale = float(m[3])
			fogo.flame_opacity = 0.26
			fogo.fade_in = 0.2
			p.add_child(fogo)
			fogo.ignite(p)
			if not m[4]:
				var luz = fogo.get("_light")
				if luz is Node:
					(luz as Node).queue_free()
					fogo.set("_light", null)
	return {"raio": 2.6, "altura": 1.2, "alvo": 0.8, "g0": 20.0, "giro": 34.0}


func _set_jaula() -> Dictionary:
	var jaula = JaulaDoJimmy.new()
	jaula.com_capitel = false
	_set.add_child(jaula)
	jaula.agitar()
	return {"raio": 3.4, "altura": 1.6, "alvo": 1.35, "g0": -10.0, "giro": 30.0}


# --- atores -------------------------------------------------------------------

## Um ator da igreja (`ator_igreja.gd`) com bibliotecas de clipes extras
## ({nome: .glb de clipes}).
func _ator_igreja(caminho: String, extras: Dictionary) -> Node3D:
	var ator := (load(caminho) as PackedScene).instantiate() as Node3D
	ator.set("clipe_inicial", &"")
	_set.add_child(ator)
	var anim := ator.get_node_or_null("anim") as AnimationPlayer
	for nome in extras:
		_somar_clipes(anim, StringName(nome), String(extras[nome]))
	return ator


## Um .glb com AnimationPlayer próprio, num nó que olha pro +Z.
func _ator_glb(caminho: String) -> Node3D:
	var ator := Node3D.new()
	_set.add_child(ator)
	ator.add_child((load(caminho) as PackedScene).instantiate())
	return ator


func _tocar_glb(ator: Node3D, clipe: StringName) -> void:
	var ap := ator.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(clipe):
		ap.play(clipe, 0.0)


## Soma ao AnimationPlayer os clipes de um .glb, como CÓPIAS e repetindo (o
## flash é curto: nenhum clipe pode acabar no meio dele).
func _somar_clipes(anim: AnimationPlayer, nome: StringName, caminho_glb: String) -> void:
	if anim == null:
		return
	var fonte := (load(caminho_glb) as PackedScene).instantiate()
	var ap := fonte.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var lib := AnimationLibrary.new()
		for n in ap.get_animation_list():
			var a := (ap.get_animation(n) as Animation).duplicate() as Animation
			a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(n, a)
		anim.add_animation_library(nome, lib)
	fonte.free()


# ==============================================================================
# O PALCO DO UNIVERSO PARALELO
# ==============================================================================

func _montar_palco() -> void:
	_palco = Node3D.new()
	_palco.name = "palco_universo"
	_palco.visible = false
	cena.add_child(_palco)
	_palco.global_position = PALCO

	var esfera := SphereMesh.new()
	esfera.radius = RAIO_FUNDO
	esfera.height = RAIO_FUNDO * 2.0
	esfera.radial_segments = 48
	esfera.rings = 24
	var fundo := MeshInstance3D.new()
	fundo.name = "fundo"
	fundo.mesh = esfera
	fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat_fundo := ShaderMaterial.new()
	mat_fundo.shader = UNIVERSO
	fundo.material_override = mat_fundo
	_palco.add_child(fundo)

	# o redemoinho roxo atrás dos atores (vira pra câmera todo quadro)
	var quad := QuadMesh.new()
	quad.size = Vector2(30.0, 30.0)
	_vortice = MeshInstance3D.new()
	_vortice.name = "redemoinho"
	_vortice.mesh = quad
	_vortice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat_v := ShaderMaterial.new()
	mat_v.shader = VORTICE
	var ruido := NoiseTexture2D.new()
	ruido.seamless = true
	ruido.noise = FastNoiseLite.new()
	mat_v.set_shader_parameter("ruido", ruido)
	mat_v.set_shader_parameter("cor_borda", Color(0.62, 0.32, 1.0))
	mat_v.set_shader_parameter("cor_meio", Color(0.16, 0.05, 0.38))
	mat_v.set_shader_parameter("brilho", 1.5)
	mat_v.set_shader_parameter("velocidade", 0.5)
	_vortice.material_override = mat_v
	_palco.add_child(_vortice)

	# os anéis começam depois da órbita da câmera (até 4,4 m): partícula que
	# passa rente à lente vira um borrão do tamanho da tela
	_girando.append(_particulas("poeira_de_estrelas", 800, 6.0, 10.0, 5.2, 6.0, 0.05, 0.16,
		[Color(0.7, 0.4, 1.0), Color(0.35, 0.75, 1.0), Color(1.0, 0.45, 0.6)]))
	_girando.append(_particulas("faiscas", 180, 3.0, 13.0, 6.5, 9.0, 0.03, 0.08,
		[Color(1.0, 0.9, 0.7), Color(0.9, 0.8, 1.0)]))

	for c in [Color(0.65, 0.3, 1.0), Color(1.0, 0.3, 0.55), Color(0.3, 0.7, 1.0), Color(1.0, 0.55, 0.25)]:
		var luz := OmniLight3D.new()
		luz.light_color = c
		luz.light_energy = 3.0
		luz.omni_range = 7.5
		luz.shadow_enabled = false
		_palco.add_child(luz)
		_luzes.append(luz)
	_chave = SpotLight3D.new()
	_chave.light_color = Color(0.92, 0.88, 1.0)
	_chave.light_energy = 4.0
	_chave.spot_range = 14.0
	_chave.spot_angle = 32.0
	_chave.shadow_enabled = true
	_palco.add_child(_chave)


## Partículas presas ao emissor (`local_coords`): girar o nó faz todas rodarem
## em volta dos atores.
func _particulas(nome: String, quantas: int, vida: float, raio: float, raio_dentro: float,
		altura: float, tam_min: float, tam_max: float, cores: Array) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = quantas
	p.lifetime = vida
	p.preprocess = vida
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = raio
	mat.emission_ring_inner_radius = raio_dentro
	mat.emission_ring_height = altura
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.35
	mat.gravity = Vector3.ZERO
	mat.scale_min = tam_min
	mat.scale_max = tam_max
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var rampa := GradientTexture1D.new()
	rampa.gradient = grad
	mat.color_ramp = rampa
	var sorteio := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cores.size():
		offs.append(float(i) / maxf(1.0, cores.size() - 1.0))
		cs.append(cores[i])
	sorteio.offsets = offs
	sorteio.colors = cs
	var tex_sorteio := GradientTexture1D.new()
	tex_sorteio.gradient = sorteio
	mat.color_initial_ramp = tex_sorteio
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	# um ponto redondo e macio (sem textura o quad é um quadrado)
	var ponto := GradientTexture2D.new()
	ponto.fill = GradientTexture2D.FILL_RADIAL
	ponto.fill_from = Vector2(0.5, 0.5)
	ponto.fill_to = Vector2(0.5, 0.0)
	var macio := Gradient.new()
	macio.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	macio.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	ponto.gradient = macio
	var m := StandardMaterial3D.new()
	m.albedo_texture = ponto
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.disable_fog = true
	quad.material = m
	p.draw_pass_1 = quad
	_palco.add_child(p)
	return p


func _process(delta: float) -> void:
	_tempo += delta
	if not _no_palco or not is_instance_valid(cam) or not is_instance_valid(_palco):
		return
	var olho := cam.global_position
	var para_tras := (PALCO - olho)
	para_tras.y = 0.0
	para_tras = para_tras.normalized() if para_tras.length() > 0.01 else Vector3.FORWARD
	_vortice.global_position = PALCO + para_tras * 15.0 + Vector3.UP * 2.0
	_vortice.look_at(olho, Vector3.UP)
	for i in _girando.size():
		_girando[i].rotation.y += delta * (0.45 if i == 0 else -0.25)
	for i in _luzes.size():
		var g := _tempo * (0.9 + 0.25 * i) + i * TAU / _luzes.size()
		_luzes[i].position = Vector3(cos(g) * 3.0, 1.2 + 1.3 * sin(_tempo * 1.3 + i), sin(g) * 3.0)
	_chave.global_position = olho + Vector3.UP * 0.8
	_chave.look_at(PALCO + Vector3.UP * 1.0, Vector3.UP)


# ==============================================================================
# PEÇAS
# ==============================================================================

## Onde o corpo que se VÊ do Maycow está (ele fica atrás da origem do player).
func _modelo_pos() -> Vector3:
	var modelo := player.get_node_or_null("maycow_lopes_normal") as Node3D
	var p := modelo.global_position if modelo else player.global_position
	return Vector3(p.x, _chao_y, p.z)


## Põe o jogador com o CORPO em `onde`, olhando pra `alvo`.
func _por_player(onde: Vector3, alvo: Vector3) -> void:
	var d := alvo - onde
	player.velocity = Vector3.ZERO
	player.global_rotation.y = atan2(-d.x, -d.z)
	var modelo := player.get_node_or_null("maycow_lopes_normal") as Node3D
	var desvio := Vector3.ZERO
	if modelo:
		desvio = modelo.global_position - player.global_position
		desvio.y = 0.0
	player.global_position = Vector3(onde.x, onde.y + 1.05, onde.z) - desvio


## O piso do galpão (o raio sai rente a ele: de cima bate no mezanino).
func _chao(xz: Vector3) -> float:
	var de := Vector3(xz.x, PISO + 1.2, xz.z)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 4.0, LAYER_CHAO)
	var h := cena.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3).y if not h.is_empty() else PISO


func _som(caminho: String, volume: float, tom: float = 1.0) -> void:
	var stream := load(caminho) as AudioStream
	if stream == null:
		return
	var s := AudioStreamPlayer.new()
	s.stream = stream
	s.volume_db = volume
	s.pitch_scale = tom
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
