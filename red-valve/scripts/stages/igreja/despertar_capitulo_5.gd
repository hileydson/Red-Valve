extends Node

## O DESPERTAR NA IGREJA — o fim do Capítulo 4 e o começo do 5.
##
## Depois de queimar na arena 2 com o amuleto na mão, o Maycow (o normal,
## agora) aparece deitado no pentagrama da igreja, onde o Jonny estava, com
## sangue pra todo lado. A tela vem do preto bem devagar e BORRADA — é um
## pensamento, não o agora. Ele geme, e no meio disso vêm FLASHES da Dona Nice
## fazendo com ele o que fez com o Jonny (o mesmo ritual, a faca, os olhos
## dela), cada vez mais perto um do outro. Ele balança a cabeça, os flashes
## param, o borrão some (volta a realidade) e ele começa a se levantar, bem
## devagar; no meio disso a tela apaga.
##
## Volta o jogo ali mesmo, perto do pentagrama, com "CAPÍTULO 5 — O Pastor" no
## meio da tela, 10% de sangue, 10% de magia, nenhum iron rusk e a estamina lá
## embaixo — até sair da igreja ele não corre e ela não volta
## (`player._sem_forcas`). Nenhum objetivo até ele sair.
##
## Quem cria: `igreja_interior.gd`, quando `Eventos.despertar_na_igreja()`.
## Usa os atores e a lente da cena da Dona Nice (`cena_dona_nice.tscn`), que o
## `evento_dona_nice.gd` já montou (estado >= 4: o corpo da monstro no chão e
## as velas apagadas). O dublê do Maycow ganha a biblioteca "cap4" com os
## clipes de `maycow_normal_clipes.glb` (`tools/blender/capitulo_4`).

const CLIPES := "res://assets/3d_model/npc/capitulo_4/maycow_normal_clipes.glb"
const LACOS := ["deitado_gemendo", "deitado_ritual"]
const SOM_GEMIDO := "res://assets/sounds/capitulo_4/gemido_maycow.ogg"
const SOM_FLASH := "res://assets/sounds/capitulo_4/flash_memoria.ogg"
const SOM_LEVANTAR := "res://assets/sounds/capitulo_4/levantar_ferido.ogg"
const SOM_BATIMENTO := "res://assets/sounds/igreja/batimento_lento.ogg"
const SOM_SUSSURRO := "res://assets/sounds/igreja/sussurro_culto.ogg"

## O meio do pentagrama (o decalque `efeitos/simbolo` da cena).
const SIMBOLO := Vector3(0.0, 0.0, 19.6)
## O corpo deitado atravessa a nave como o do Jonny: a cabeça pro +X.
const CABECA_PARA := Vector3(1.0, 0.0, 0.0)
## A Dona Nice dos flashes: ajoelhada do lado dele que dá pra porta, a esta
## distância da coluna (os braços dele abertos no ritual não entram nela).
const NICE_DISTANCIA := 0.9
## Quanto dura cada flash (a memória na tela) e o respiro de agora entre um e
## outro: cada vez mais curtos, mais perto um do outro.
const FLASHES := [0.95, 0.8, 0.7, 0.6, 0.5, 0.42]
const RESPIROS := [2.4, 1.7, 1.2, 0.85, 0.6, 0.45]
## O jeito "pensamento" da lente: túnel borrado, aberração, sem cor.
const SONHO := {"foco": 0.85, "borrao": 0.16, "aberracao": 3.2, "saturacao": 0.5}
const REAL := {"foco": 0.0, "borrao": 0.0, "aberracao": 1.0, "saturacao": 0.85}
## Quanto de `levantar_devagar` (9,8 s) passa antes de a tela começar a
## apagar, e quanto o apagar leva: começa com ele agachado (6,4 s) e fecha com
## ele quase de pé (o joelho no chão vai de 7,3 a 7,9 s).
const LEVANTAR_ATE_APAGAR := 6.2
const APAGAR := 2.6

## O estado do Maycow quando o jogo volta.
const SANGUE := 0.10
const MAGIA := 0.10

var igreja: Node3D
var cena: Node3D
var player: CharacterBody3D
var maycow: Node3D
var nice: Node3D
var cam: Camera3D

var _luz: SpotLight3D
var _camada: CanvasLayer
var _preto: ColorRect
var _sons: Dictionary = {}
var _tween_cam: Tween
## Eixo da cabeça (horizontal, mundo) e o lado da porta, medidos no corpo.
var _eixo := CABECA_PARA
var _lado := Vector3(0.0, 0.0, -1.0)


func rodar(dono: Node3D, evento: Node) -> void:
	igreja = dono
	player = igreja.get_node_or_null("Player") as CharacterBody3D
	# preto desde o primeiro quadro: a igreja não aparece antes da cena
	_montar_tela()
	_travar(true)
	# o evento da Dona Nice monta a cena dele dois quadros depois de nascer
	while is_inside_tree() and (evento.get("cena") == null or not is_instance_valid(evento.get("cena"))):
		await get_tree().process_frame
	# e só depois disso esconde o que sobrou (estado >= 4): a cena daqui vem
	# por cima, um quadro depois
	for _i in 3:
		await get_tree().process_frame
	cena = evento.get("cena")
	_preparar_maycow()
	_preparar_nice()
	_montar_camera()
	_sangue_no_chao()
	var lente := cena.get_node_or_null("lente") as CanvasLayer
	if lente:
		lente.visible = true
	cena.set("barras", 1.0)
	cena.set("preto", 1.0)
	_lente(SONHO)
	await get_tree().process_frame
	_preto.modulate.a = 0.0

	# --- 1. do preto, muito devagar: ele deitado no pentagrama, visto de cima
	_som("gemido", SOM_GEMIDO, -3.0, true)
	_som("batimento", SOM_BATIMENTO, -10.0, true)
	var peito := maycow.call("posicao_do_osso", "Spine") as Vector3
	_plano(peito + Vector3.UP * 3.4 - _eixo * 0.5 + _lado * 0.3, peito + Vector3.UP * 2.6 - _eixo * 0.2 + _lado * 0.1,
		peito, peito, 46.0, 40.0, 9.0)
	var abre := create_tween()
	abre.tween_property(cena, "preto", 0.0, 7.5).set_trans(Tween.TRANS_SINE)
	await _esperar(8.5)

	# --- 2. o rosto, gemendo
	_plano_rosto(4.0)
	await _esperar(3.6)

	# --- 3. os flashes da Dona Nice
	for i in FLASHES.size():
		await _flash(i, float(FLASHES[i]))
		if i % 2 == 0:
			_plano_rosto(float(RESPIROS[i]) + 0.4)
		else:
			_plano_dos_pes(float(RESPIROS[i]) + 0.4)
		await _esperar(float(RESPIROS[i]))

	# --- 4. ele balança a cabeça: os flashes acabam e o borrão vai embora
	maycow.call("tocar", &"cap4/balancar_cabeca", 0.25)
	_plano_rosto(2.8)
	await _esperar(0.7)
	var volta := create_tween().set_parallel(true)
	for chave in REAL:
		volta.tween_property(cena, chave, float(REAL[chave]), 1.8).set_trans(Tween.TRANS_SINE)
	_calar("batimento", 2.0)
	await _esperar(1.9)
	maycow.call("tocar", &"cap4/deitado_gemendo", 0.4)
	await _esperar(0.6)

	# --- 5. ele se levanta, bem devagar; no meio a tela apaga
	_calar("gemido", 2.5)
	_som("levantar", SOM_LEVANTAR, -2.0, false)
	maycow.call("tocar", &"cap4/levantar_devagar", 0.5)
	var quadril := maycow.call("posicao_do_osso", "Hips") as Vector3
	# ele levanta virado pros pés (o -eixo) e anda uns 35 cm pra lá
	_plano(quadril + _lado * 2.5 - _eixo * 1.0 + Vector3.UP * 0.75,
		quadril + _lado * 2.1 - _eixo * 0.9 + Vector3.UP * 1.0,
		quadril + Vector3.UP * 0.35, quadril - _eixo * 0.3 + Vector3.UP * 0.85, 42.0, 40.0,
		LEVANTAR_ATE_APAGAR + APAGAR)
	await _esperar(LEVANTAR_ATE_APAGAR)
	var fecha := create_tween()
	fecha.tween_property(cena, "preto", 1.0, APAGAR).set_trans(Tween.TRANS_SINE)
	_calar("levantar", APAGAR)
	await _esperar(APAGAR + 0.6)

	# --- 6. de volta ao jogo, ali mesmo
	_preto.modulate.a = 1.0
	var em_pe := maycow.call("posicao_do_osso", "Hips") as Vector3
	_soltar(em_pe)
	await _esperar(0.4)
	var clareia := create_tween()
	clareia.tween_property(_preto, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	await _esperar(1.8)
	await _titulo_do_capitulo("TXT_CHAPTER_5", "TXT_CHAPTER_5_SUBTITULO")
	queue_free()


# ==============================================================================
# OS ATORES
# ==============================================================================
## O dublê do Maycow deitado no pentagrama, com a biblioteca "cap4" e o
## corpo ensanguentado. A cabeça vai pro +X, como a do Jonny: o corpo é posto,
## medido (cabeça - quadril) e girado/arrastado até o peito cair no símbolo.
func _preparar_maycow() -> void:
	maycow = cena.get_node_or_null("atores/Maycow") as Node3D
	if maycow == null:
		return
	var anim := maycow.get("anim") as AnimationPlayer
	var fonte := (load(CLIPES) as PackedScene).instantiate()
	var origem := fonte.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and origem and not anim.has_animation_library(&"cap4"):
		var lib := AnimationLibrary.new()
		for nome in origem.get_animation_list():
			var a := (origem.get_animation(nome) as Animation).duplicate() as Animation
			if String(nome) in LACOS:
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(nome, a)
		anim.add_animation_library(&"cap4", lib)
	fonte.free()
	# a pistola da cena da chegada não vai na mão de quem acorda
	var arma := maycow.find_child("mao_arma", true, false) as Node3D
	if arma:
		arma.visible = false
	maycow.global_transform = Transform3D(Basis.IDENTITY, SIMBOLO)
	maycow.visible = true
	maycow.set("sangue", 0.5)
	maycow.call("tocar", &"cap4/deitado_gemendo", 0.0)
	if anim:
		anim.advance(0.0)
	_acertar_no_simbolo()


func _acertar_no_simbolo() -> void:
	var cabeca := maycow.call("posicao_do_osso", "Head") as Vector3
	var quadril := maycow.call("posicao_do_osso", "Hips") as Vector3
	var eixo := Vector3(cabeca.x - quadril.x, 0.0, cabeca.z - quadril.z)
	if eixo.length() > 0.05:
		var giro := atan2(eixo.x, eixo.z) - atan2(CABECA_PARA.x, CABECA_PARA.z)
		maycow.rotate_y(-giro)
	cabeca = maycow.call("posicao_do_osso", "Head") as Vector3
	quadril = maycow.call("posicao_do_osso", "Hips") as Vector3
	var meio := (cabeca + quadril) * 0.5
	maycow.global_position += Vector3(SIMBOLO.x - meio.x, 0.0, SIMBOLO.z - meio.z)
	_eixo = CABECA_PARA.normalized()
	_lado = Vector3.UP.cross(_eixo).normalized()


## A Dona Nice dos flashes, ajoelhada ao lado dele, de frente pro corpo. O
## .glb dela olha pro +Z.
func _preparar_nice() -> void:
	nice = cena.get_node_or_null("atores/DonaNice") as Node3D
	if nice == null or maycow == null:
		return
	var peito := maycow.call("posicao_do_osso", "Spine") as Vector3
	var onde := Vector3(peito.x, 0.0, peito.z) + _lado * NICE_DISTANCIA
	var para := -_lado
	nice.global_transform = Transform3D(Basis(Vector3.UP, atan2(para.x, para.z)), onde)
	nice.visible = false


## Sangue pra todo lado: mais respingos em volta dele e a poça maior.
func _sangue_no_chao() -> void:
	var poca := cena.get_node_or_null("efeitos/poca_jonny") as Decal
	if poca:
		poca.size = Vector3(3.2, 0.6, 2.6)
		poca.global_position = Vector3(SIMBOLO.x, 0.0, SIMBOLO.z)
	var molde := cena.get_node_or_null("efeitos/respingo_1") as Decal
	if molde == null:
		return
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 5005
	for i in 7:
		var r := molde.duplicate() as Decal
		r.name = "respingo_despertar_%d" % i
		molde.get_parent().add_child(r)
		var a := sorte.randf() * TAU
		var d := sorte.randf_range(0.9, 2.3)
		r.global_position = SIMBOLO + Vector3(cos(a) * d, 0.0, sin(a) * d)
		r.rotation.y = sorte.randf() * TAU
		var s := sorte.randf_range(0.7, 1.6)
		r.size = Vector3(1.4 * s, 0.6, 1.4 * s)


# ==============================================================================
# OS FLASHES
# ==============================================================================
## Um flash: o clarão, e a MEMÓRIA na tela — a Dona Nice ajoelhada sobre ele,
## as velas acesas, sem cor —, e outro clarão de volta ao agora.
func _flash(i: int, dur: float) -> void:
	_som("flash_%d" % i, SOM_FLASH, -1.0, false)
	_clarao(1.0, 0.3)
	_memoria(true, i)
	_plano_da_memoria(i, dur)
	await _esperar(dur)
	_clarao(0.85, 0.25)
	_memoria(false, i)


func _memoria(sim: bool, i: int) -> void:
	if is_instance_valid(nice):
		nice.visible = sim
		if sim:
			nice.call("tocar", &"ajoelhada_sussurro", 0.0)
	var monstro := cena.get_node_or_null("atores/Monstro") as Node3D
	if monstro:
		monstro.visible = not sim
	_velas(sim)
	if is_instance_valid(maycow):
		maycow.call("tocar", &"cap4/deitado_ritual" if sim else &"cap4/deitado_gemendo", 0.0 if sim else 0.3)
	if sim:
		cena.set("saturacao", 0.18)
		cena.set("vermelho", 0.55 if i == FLASHES.size() - 1 else 0.3)
		cena.set("foco", 0.35)
		cena.set("sangue_na_tela", 0.7 if i == 3 else 0.0)
		_som("sussurro", SOM_SUSSURRO, -6.0, false, 1.0, randf_range(0.0, 12.0))
	else:
		cena.set("vermelho", 0.0)
		cena.set("sangue_na_tela", 0.0)
		_lente(SONHO)
		_calar("sussurro", 0.15)


## As velas do ritual acesas só na memória (no agora elas já queimaram).
func _velas(acesas: bool) -> void:
	var velas := cena.get_node_or_null("efeitos/velas")
	if velas:
		for v in velas.get_children():
			var chama := v.get_node_or_null("chama") as Node3D
			if chama:
				chama.visible = acesas
	var luz := cena.get_node_or_null("efeitos/luz_velas") as Light3D
	if luz:
		luz.visible = acesas


func _plano_da_memoria(i: int, dur: float) -> void:
	var peito := maycow.call("posicao_do_osso", "Spine") as Vector3
	var cabeca := maycow.call("posicao_do_osso", "Head") as Vector3
	var dela: Vector3 = peito
	if is_instance_valid(nice):
		dela = nice.call("posicao_do_osso", "head") as Vector3
	var faca := cena.get_node_or_null("atores/DonaNice/modelo/dona_nice_rig/Skeleton3D/mao_faca") as Node3D
	var ponta := faca.global_position if faca else (peito + dela) * 0.5
	match i % 5:
		0:
			# os dois, de longe: ela ajoelhada sobre ele
			var meio := (peito + dela) * 0.5
			_plano(meio + _lado * 2.6 - _eixo * 1.6 + Vector3.UP * 1.5,
				meio + _lado * 2.3 - _eixo * 1.3 + Vector3.UP * 1.4, meio, meio, 42.0, 40.0, dur)
		1:
			# a faca na mão dela, e ele embaixo
			_plano(ponta - _lado * 0.5 + _eixo * 0.25 + Vector3.UP * 0.2,
				ponta - _lado * 0.42 + _eixo * 0.2 + Vector3.UP * 0.16, ponta, ponta, 30.0, 26.0, dur)
		2:
			# o rosto dela olhando pra baixo, pra ele
			_plano(dela - _lado * 0.65 + Vector3.UP * -0.12 + _eixo * 0.12,
				dela - _lado * 0.5 + Vector3.UP * -0.1 + _eixo * 0.08, dela, dela, 32.0, 28.0, dur)
		3:
			# ele, de cima, se debatendo
			_plano(cabeca + Vector3.UP * 0.95 + _lado * 0.15, cabeca + Vector3.UP * 0.8 + _lado * 0.1,
				cabeca, cabeca, 40.0, 36.0, dur)
		_:
			# a faca descendo: baixo, do outro lado dele
			_plano(peito - _lado * 1.1 + Vector3.UP * 0.3, peito - _lado * 0.9 + Vector3.UP * 0.25,
				peito + _lado * 0.3 + Vector3.UP * 0.4, ponta, 38.0, 34.0, dur)


func _clarao(forca: float, dur: float) -> void:
	cena.set("flash", forca)
	var t := create_tween()
	t.tween_property(cena, "flash", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	GlobalUtils.vibrate_controller(null, 0.4, 0.6, 0.2)


# ==============================================================================
# CÂMERA E LENTE
# ==============================================================================
func _montar_camera() -> void:
	cam = Camera3D.new()
	cam.name = "camera_despertar"
	cam.near = 0.02
	cam.far = 120.0
	igreja.add_child(cam)
	cam.make_current()
	# uma luz fria de cima, pra ele não sumir no escuro da nave (spot: a fatia
	# do meio da nave já está no teto de 8 omni)
	_luz = SpotLight3D.new()
	_luz.name = "luz_despertar"
	_luz.light_color = Color(0.62, 0.7, 0.9)
	_luz.light_energy = 2.4
	# sem brilho especular: a pele com sangue é lisa e virava plástico
	_luz.light_specular = 0.15
	_luz.spot_range = 10.0
	_luz.spot_angle = 34.0
	_luz.spot_attenuation = 0.6
	_luz.shadow_enabled = false
	igreja.add_child(_luz)
	_luz.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), SIMBOLO + Vector3.UP * 6.0)


## A câmera andando de `de` a `ate` e virando de `olhar_de` pra `olhar_ate`.
func _plano(de: Vector3, ate: Vector3, olhar_de: Vector3, olhar_ate: Vector3, fov_de: float,
		fov_ate: float, dur: float) -> void:
	if _tween_cam and _tween_cam.is_valid():
		_tween_cam.kill()
	var passo := func(k: float) -> void:
		if not is_instance_valid(cam):
			return
		var s := k * k * (3.0 - 2.0 * k)
		cam.global_position = de.lerp(ate, s)
		var olhar := olhar_de.lerp(olhar_ate, s)
		if not cam.global_position.is_equal_approx(olhar):
			cam.look_at(olhar, Vector3.UP)
		cam.fov = lerpf(fov_de, fov_ate, s)
	passo.call(0.0)
	_tween_cam = create_tween()
	_tween_cam.tween_method(passo, 0.0, 1.0, maxf(dur, 0.05))


## O rosto dele de perfil, rente ao chão, do lado da porta. A origem do osso
## Head é a nuca: o rosto fica uns 9 cm adiante e 6 cm acima (deitado de
## costas, o rosto olha pra cima).
func _plano_rosto(dur: float) -> void:
	var cabeca := maycow.call("posicao_do_osso", "Head") as Vector3
	var rosto := cabeca + _eixo * 0.09 + Vector3.UP * 0.06
	_plano(rosto + _lado * 0.72 + Vector3.UP * 0.16 + _eixo * 0.14,
		rosto + _lado * 0.58 + Vector3.UP * 0.13 + _eixo * 0.1,
		rosto, rosto, 36.0, 33.0, dur)


## Dos pés dele, baixo, o corpo inteiro no chão até o rosto.
func _plano_dos_pes(dur: float) -> void:
	var quadril := maycow.call("posicao_do_osso", "Hips") as Vector3
	var peito := maycow.call("posicao_do_osso", "Spine") as Vector3
	_plano(quadril - _eixo * 2.3 + _lado * 0.4 + Vector3.UP * 0.9,
		quadril - _eixo * 2.0 + _lado * 0.35 + Vector3.UP * 0.85, peito, peito, 40.0, 38.0, dur)


func _lente(valores: Dictionary) -> void:
	for chave in valores:
		cena.set(chave, valores[chave])


func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 96
	add_child(_camada)
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.modulate.a = 1.0
	_camada.add_child(_preto)


func _esperar(seg: float) -> void:
	if seg > 0.0 and is_inside_tree():
		await get_tree().create_timer(seg, false).timeout


# ==============================================================================
# O JOGADOR
# ==============================================================================
func _travar(sim: bool) -> void:
	GlobalEvents.in_cutscene = sim
	if not is_instance_valid(player):
		return
	player.cutscene_set_hud_enabled(not sim)
	player.cutscene_set_player_control(not sim)
	player.cutscene_set_camera_current(not sim)
	player.cutscene_set_model_hidden(sim)
	if sim:
		player.velocity = Vector3.ZERO


## O jogo volta onde o dublê ficou de pé, de frente pra porta, sem forças.
func _soltar(onde: Vector3) -> void:
	if is_instance_valid(maycow):
		maycow.visible = false
	if is_instance_valid(nice):
		nice.visible = false
	var monstro := cena.get_node_or_null("atores/Monstro") as Node3D
	if monstro:
		monstro.visible = true
	_velas(false)
	if is_instance_valid(_luz):
		_luz.queue_free()
	if is_instance_valid(cam):
		cam.queue_free()
	if cena.has_method("esconder_lente"):
		cena.call("esconder_lente")
	cena.set("barras", 0.0)
	cena.set("preto", 0.0)
	_lente(REAL)
	for chave in _sons.keys():
		_calar(chave, 0.3)
	if is_instance_valid(player):
		player.global_position = Vector3(onde.x, 1.05, onde.z)
		# a porta fica pro -Z, e o corpo dele olha pro -Z com giro zero
		player.rotation.y = 0.0
		player.velocity = Vector3.ZERO
		_ficar_sem_forcas()
	_travar(false)
	# o capítulo fecha aqui, já com o estado novo (grava)
	Eventos.concluir(Eventos.CAP4_CONCLUIDO)


## A estamina não precisa de nada aqui: o player a segura lá embaixo sozinho
## enquanto `Eventos.sem_forcas_na_igreja()` (depois do `concluir` abaixo).
func _ficar_sem_forcas() -> void:
	var cheio := int(player.get("max_health"))
	player.set("current_health", maxi(1, int(round(cheio * SANGUE))))
	SaveManager.current_mp = SaveManager.max_mp * MAGIA
	SaveManager.iron_rusks = 0
	SaveManager.iron_rusks_display = 0
	SaveManager.iron_rusks_pending = 0


# ==============================================================================
# SOM
# ==============================================================================
func _som(chave: String, caminho: String, volume: float, laco: bool, tom: float = 1.0,
		de: float = 0.0) -> void:
	var stream := load(caminho) as AudioStream
	if stream == null:
		return
	if laco:
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	var s := AudioStreamPlayer.new()
	s.name = "som_" + chave
	s.stream = stream
	s.volume_db = volume
	s.pitch_scale = tom
	add_child(s)
	s.play(de)
	_sons[chave] = s
	if not laco:
		s.finished.connect(func() -> void:
			if _sons.get(chave) == s:
				_sons.erase(chave)
			s.queue_free())


func _calar(chave: String, dur: float) -> void:
	var s = _sons.get(chave)
	if not is_instance_valid(s):
		return
	_sons.erase(chave)
	var t := create_tween()
	t.tween_property(s, "volume_db", -60.0, dur)
	t.tween_callback(s.queue_free)


# ==============================================================================
# O TÍTULO
# ==============================================================================
## O mesmo título de capítulo da cidade (`stage_1._titulo_do_capitulo`): o nome
## bem grande, em vermelho, no meio da tela, e o subtítulo pequeno embaixo.
func _titulo_do_capitulo(chave_titulo: String, chave_subtitulo: String) -> void:
	var fonte = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
	var titulo := Label.new()
	titulo.text = tr(chave_titulo).to_upper()
	titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 180)
	titulo.add_theme_color_override("font_color", Color(0.705882, 0.0, 0.0))
	if fonte:
		titulo.add_theme_font_override("font", fonte)
	_camada.add_child(titulo)
	var sub := Label.new()
	sub.text = tr(chave_subtitulo)
	sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.offset_top = 170
	sub.offset_bottom = 170
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 48)
	sub.add_theme_color_override("font_color", Color(0.705882, 0.0, 0.0))
	if fonte:
		sub.add_theme_font_override("font", fonte)
	titulo.add_child(sub)
	titulo.modulate.a = 0.0
	var entra := create_tween()
	entra.tween_property(titulo, "modulate:a", 1.0, 1.0)
	await entra.finished
	await _esperar(3.5)
	var sai := create_tween()
	sai.tween_property(titulo, "modulate:a", 0.0, 1.0)
	await sai.finished
	titulo.queue_free()
