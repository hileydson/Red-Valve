extends CanvasLayer

## A DRIZZI WISNY (Capítulo 2, logo depois do hospital escurecer).
##
## Fundo preto. Ela no meio da tela, DE COSTAS pra câmera, gesticulando como
## quem conversa (clipe `conversando` do rig dela). A câmera começa colada na
## cabeça e, enquanto as falas passam, vai girando em volta dela — só pelas
## costas — e descendo, sempre mirando a cabeça: o rosto não aparece em
## momento nenhum. Ela é a esposa do Jimmy e a mãe do Jonny, morta; agora está
## do outro lado, quer saber quem é o culpado e chama o Maycow pro cemitério.
##
## Ela vive num mundo 3D PRÓPRIO (SubViewport com `own_world_3d`), num
## CanvasLayer por cima de tudo: a cena de baixo (o hospital) não aparece e não
## precisa ser escondida. A legenda é daqui mesmo, embaixo da tela — no meio
## ela cobriria a cabeça dela.
##
##     var d = preload("res://scripts/cutscenes/cutscene_drizzi.gd").new()
##     add_child(d)
##     await d.terminou      # já de volta ao preto

signal terminou

## O rig dela (`tools/blender/drizzi/`): malha + esqueleto + clipes. Sem ele,
## o scan parado.
const MODELO := "res://assets/3d_model/npc/drizzi/drizzi.glb"
const MODELO_ESCAN := "res://assets/3d_model/enemies/cemiterio/Drizzi_Wisny.glb"
const SOM_FUNDO := "res://assets/sounds/escola/atmosfera_fantasma.ogg"
const FONTE := "res://assets/fonts/Montserrat-ExtraBold.ttf"
const ALTURA := 1.68

## [chave, segundos]
const FALAS := [
	["DRIZZI_1", 3.0],
	["DRIZZI_2", 3.6],
	["DRIZZI_3", 4.6],
	["DRIZZI_4", 4.2],
	["DRIZZI_5", 4.0],
	["DRIZZI_6", 4.8],
	["DRIZZI_7", 5.4],
	["DRIZZI_8", 3.6],
	["DRIZZI_9", 4.6],
]

var _preto: ColorRect
var _cortina: ColorRect
var _legenda: Label
var _cam: Camera3D
var _drizzi: Node3D
var _cabeca := Vector3(0.0, 1.55, 0.0)
var _som: AudioStreamPlayer
var _pular := false


func _ready() -> void:
	layer = 96
	_montar()
	_rodar()


func _montar() -> void:
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preto)

	var vc := SubViewportContainer.new()
	vc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vc.stretch = true
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vc.add_child(vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	we.environment = env
	vp.add_child(we)

	_drizzi = _modelo()
	vp.add_child(_drizzi)
	_por_luzes(vp)

	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.near = 0.03
	vp.add_child(_cam)
	_cam.current = true

	_legenda = Label.new()
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda.anchor_left = 0.15
	_legenda.anchor_right = 0.85
	_legenda.anchor_top = 0.80
	_legenda.anchor_bottom = 0.95
	_legenda.add_theme_font_size_override("font_size", 26)
	_legenda.add_theme_color_override("font_color", Color(0.86, 0.84, 0.92))
	_legenda.add_theme_constant_override("outline_size", 6)
	_legenda.add_theme_color_override("font_outline_color", Color.BLACK)
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda.modulate.a = 0.0
	add_child(_legenda)

	_cortina = ColorRect.new()
	_cortina.color = Color.BLACK
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)


## Ela de pé na origem, olhando pro -Z do mundo (a câmera fica do lado +Z, nas
## costas dela), com a sola no chão e a altura dela.
func _modelo() -> Node3D:
	var raiz := Node3D.new()
	var caminho := MODELO if ResourceLoader.exists(MODELO) else MODELO_ESCAN
	var modelo := (load(caminho) as PackedScene).instantiate() as Node3D
	raiz.add_child(modelo)
	var caixa := _caixa(modelo)
	if caixa.size.y > 0.0:
		var s := ALTURA / caixa.size.y
		modelo.scale = Vector3.ONE * s
		caixa = _caixa(modelo)
		modelo.position -= Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	# o scan e o rig olham pro +Z (frente do glTF): meia volta, de costas pra câmera
	raiz.rotation.y = PI
	_cabeca = Vector3(0.0, ALTURA * 0.92, 0.0)
	var ap := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(&"conversando"):
		ap.get_animation(&"conversando").loop_mode = Animation.LOOP_LINEAR
		ap.play(&"conversando")
	return raiz


## A caixa das malhas no espaço do PAI de `no` (o modelo ainda está fora da
## árvore: soma os transforms à mão).
static func _caixa(no: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := mi.transform
		var pai := mi.get_parent()
		while pai != null and pai != no:
			if pai is Node3D:
				t = (pai as Node3D).transform * t
			pai = pai.get_parent()
		var c: AABB = (no.transform * t) * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return caixa


## Contraluz: a luz forte vem da FRENTE dela (do lado que a câmera nunca vê)
## e recorta o contorno do cabelo e dos ombros; um preenchimento fraco e frio
## das costas deixa ler a roupa sem estragar o mistério.
func _por_luzes(vp: SubViewport) -> void:
	var recorte := SpotLight3D.new()
	recorte.light_color = Color(0.72, 0.62, 1.0)
	recorte.light_energy = 9.0
	recorte.spot_range = 7.0
	recorte.spot_angle = 34.0
	recorte.shadow_enabled = true
	vp.add_child(recorte)
	recorte.look_at_from_position(Vector3(0.0, 2.9, -1.9), Vector3(0.0, 1.25, 0.0), Vector3.UP)
	var preenche := OmniLight3D.new()
	preenche.light_color = Color(0.55, 0.62, 0.95)
	preenche.light_energy = 0.55
	preenche.omni_range = 5.0
	vp.add_child(preenche)
	preenche.position = Vector3(0.6, 2.1, 2.2)
	var baixo := OmniLight3D.new()
	baixo.light_color = Color(0.6, 0.1, 0.16)
	baixo.light_energy = 0.8
	baixo.omni_range = 2.5
	vp.add_child(baixo)
	baixo.position = Vector3(-0.5, 0.15, 0.6)


func _rodar() -> void:
	_som = AudioStreamPlayer.new()
	if ResourceLoader.exists(SOM_FUNDO):
		_som.stream = load(SOM_FUNDO)
	_som.volume_db = -30.0
	add_child(_som)
	_som.play()
	create_tween().tween_property(_som, "volume_db", -10.0, 2.5)

	var total := 0.0
	for f in FALAS:
		total += float(f[1])
	total += 2.4
	_posicionar_camera(0.0)
	var abre := create_tween()
	abre.tween_property(_cortina, "color:a", 0.0, 1.6)

	var relogio := 0.0
	var i := -1
	var fim_da_fala := 1.2
	while relogio < total:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		relogio += dt
		_posicionar_camera(clampf(relogio / total, 0.0, 1.0))
		if Input.is_action_just_pressed("ui_accept") and i >= 0 and relogio > fim_da_fala - float(FALAS[i][1]) + 0.6:
			_pular = true
		if relogio >= fim_da_fala or _pular:
			_pular = false
			i += 1
			if i >= FALAS.size():
				_mostrar_fala("")
				if relogio < total - 1.2:
					relogio = total - 1.2
				fim_da_fala = INF
				continue
			_mostrar_fala(tr(String(FALAS[i][0])))
			fim_da_fala = relogio + float(FALAS[i][1])
	var fecha := create_tween().set_parallel(true)
	fecha.tween_property(_cortina, "color:a", 1.0, 1.6)
	fecha.tween_property(_som, "volume_db", -40.0, 1.6)
	await fecha.finished
	terminou.emit()
	queue_free()


func _mostrar_fala(texto: String) -> void:
	var t := create_tween()
	t.tween_property(_legenda, "modulate:a", 0.0, 0.25)
	if texto == "":
		return
	t.tween_callback(func() -> void: _legenda.text = texto)
	t.tween_property(_legenda, "modulate:a", 1.0, 0.35)


## A câmera em `k` (0..1): nas costas dela, ela inteira no quadro e a
## cabeça no meio; girando de um ombro pro outro e descendo até a altura da
## cintura — sempre mirando a cabeça. Um leve giro em torno do próprio eixo vai
## entortando o quadro.
func _posicionar_camera(k: float) -> void:
	var e := k * k * (3.0 - 2.0 * k)
	var angulo := deg_to_rad(lerpf(-34.0, 36.0, e))
	var raio := lerpf(2.5, 2.05, e)
	var altura := lerpf(_cabeca.y + 0.12, 0.35, e)
	# ela olha pro -Z: as costas estão no +Z
	var pos := Vector3(sin(angulo) * raio, altura, cos(angulo) * raio)
	_cam.look_at_from_position(pos, _cabeca, Vector3.UP)
	_cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(lerpf(0.0, -12.0, e)))
