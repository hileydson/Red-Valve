extends CanvasLayer

## A VIAGEM POR PORTAL: a transição de quem atravessa um portal (os anéis dos
## infernos, as portas red valve) para outra cena.
##
## É o mesmo desenho do amuleto levando um inimigo pra arena (o shader
## `warp_speed`: as LINHAS ROXAS correndo na tela, o túnel, a aberração) —
## só que aqui ele entra devagar com a tela escurecendo, segura o preto enquanto
## a cena nova carrega por baixo (em segundo plano, sem a tela de loading) e sai
## devagar já na cena nova. Fica na `root`, então sobrevive à troca de cena.
##
##     ViagemPortal.viajar(get_tree(), "res://...tscn", "spawn_entrada")
##
## `ponto` é o NOME do lugar de chegada na cena nova; quem decide o que fazer
## com ele (pôr o jogador no marcador, cuspir ele pra fora do portal) é a cena
## de lá, lendo `pegar_chegada()` no `_ready`. Vazio = a cena nasce como nasce.
##
## Sem `class_name` (ver [[project-class-name-travado]]): quem usa faz
## `const ViagemPortal := preload("res://scripts/systems/viagem_portal.gd")`.

const _EU := "res://scripts/systems/viagem_portal.gd"
const WARP := preload("res://shaders/effects/warp_speed.gdshader")
const SOM := "res://assets/sounds/player/espaco_travel.mp3"

## Avisa a cena nova onde o jogador chega: {"cena": caminho, "ponto": nome}.
static var chegada: Dictionary = {}
## Uma viagem por vez (dois portais no mesmo quadro, a sucção e a área).
static var _em_curso: bool = false

## Emitido quando a cena nova já é a `current_scene` (antes da saída do efeito).
signal trocou

var destino: String = ""
var ponto: String = ""
## Quanto as linhas levam pra tomar a tela, e pra largar a tela na cena nova.
var dur_entrada: float = 1.8
var dur_saida: float = 2.0

var _preto: ColorRect
var _rect: ColorRect
var _mat: ShaderMaterial
var _som: AudioStreamPlayer


## Começa a viagem. Devolve o nó (dá pra esperar o `trocou`), ou null se já
## houver outra em curso.
static func viajar(arvore: SceneTree, cena: String, ponto_chegada: String = "",
		entrada: float = 1.8, saida: float = 2.0) -> Node:
	if _em_curso or cena == "":
		return null
	_em_curso = true
	var v = (load(_EU) as GDScript).new()
	v.destino = caminho_real(cena)
	v.ponto = ponto_chegada
	v.dur_entrada = entrada
	v.dur_saida = saida
	arvore.root.add_child(v)
	return v


## O ponto de chegada desta cena (e apaga o aviso), ou "" se ninguém chegou
## por portal. `cena`: o `scene_file_path` da cena que pergunta.
static func pegar_chegada(cena: String) -> String:
	if chegada.is_empty() or chegada.get("cena", "") != caminho_real(cena):
		return ""
	var p: String = chegada.get("ponto", "")
	chegada = {}
	return p


static func caminho_real(caminho: String) -> String:
	if caminho.begins_with("uid://"):
		var id := ResourceUID.text_to_id(caminho)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return caminho


func _ready() -> void:
	layer = 129
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.modulate.a = 0.0
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preto)
	# o shader lê a tela JÁ com o preto por baixo: as linhas correm por cima dele
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = WARP
	for p in ["intensity", "streak", "aberration", "warp", "flash"]:
		_mat.set_shader_parameter(p, 0.0)
	_mat.set_shader_parameter("time_offset", randf() * 10.0)
	_mat.set_shader_parameter("velocidade", 0.9)
	_rect.material = _mat
	add_child(_rect)
	_som = AudioStreamPlayer.new()
	_som.stream = load(SOM)
	_som.pitch_scale = 0.62
	_som.volume_db = 4.0
	_som.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_som)
	_rodar()


func _rodar() -> void:
	GlobalEvents.in_cutscene = true
	ResourceLoader.load_threaded_request(destino)
	_som.play()
	GlobalUtils.vibrate_controller(null, 0.5, 0.6, 0.5)
	var t := create_tween().set_parallel(true).set_ignore_time_scale(true)
	t.tween_property(_mat, "shader_parameter/intensity", 1.0, dur_entrada).set_trans(Tween.TRANS_SINE)
	t.tween_property(_mat, "shader_parameter/streak", 0.85, dur_entrada).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_mat, "shader_parameter/warp", 0.55, dur_entrada).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_mat, "shader_parameter/aberration", 0.014, dur_entrada)
	# a tela escurece por baixo das linhas, e só na segunda metade
	t.tween_property(_preto, "modulate:a", 1.0, dur_entrada * 0.65).set_delay(dur_entrada * 0.35).set_trans(Tween.TRANS_SINE)
	await t.finished

	var cena: PackedScene = null
	while true:
		var estado := ResourceLoader.load_threaded_get_status(destino)
		if estado == ResourceLoader.THREAD_LOAD_LOADED:
			cena = ResourceLoader.load_threaded_get(destino) as PackedScene
			break
		if estado != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_warning("viagem_portal: não carregou %s" % destino)
			break
		await get_tree().process_frame
	if cena == null:
		_em_curso = false
		GlobalEvents.in_cutscene = false
		var volta := create_tween().set_parallel(true)
		volta.tween_property(_mat, "shader_parameter/intensity", 0.0, 0.6)
		volta.tween_property(_preto, "modulate:a", 0.0, 0.6)
		await volta.finished
		queue_free()
		return

	chegada = {"cena": destino, "ponto": ponto}
	get_tree().paused = false
	GlobalUtils.cleanup_gameplay_leftovers()
	get_tree().change_scene_to_packed(cena)
	# a cena nova roda o _ready (e lê a `chegada`) antes destes dois quadros
	await get_tree().process_frame
	await get_tree().process_frame
	_em_curso = false
	trocou.emit()

	# a cena nova pode entrar em câmera lenta (a oficina cai com time_scale 0,12):
	# a saída corre no relógio de parede, senão as linhas ficam rodando na tela
	var s := create_tween().set_parallel(true).set_ignore_time_scale(true)
	s.tween_property(_preto, "modulate:a", 0.0, dur_saida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	s.tween_property(_mat, "shader_parameter/intensity", 0.0, dur_saida).set_trans(Tween.TRANS_SINE)
	s.tween_property(_mat, "shader_parameter/streak", 0.0, dur_saida * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	s.tween_property(_mat, "shader_parameter/warp", 0.0, dur_saida * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	s.tween_property(_mat, "shader_parameter/aberration", 0.0, dur_saida)
	s.tween_property(_som, "volume_db", -30.0, dur_saida)
	await s.finished
	_rect.visible = false
	_preto.visible = false
	queue_free()
