@tool
extends Node3D

## As cutscenes do evento da Dona Nice, na igreja.
##
## TUDO o que acontece na tela e' o AnimationPlayer `diretor`: camera, atores,
## clipes de cada um (trilhas de "Animation Playback" no `anim` de cada
## ator), luz, som, legenda e a lente. Pra mexer numa cena, abra o diretor,
## escolha a animacao e edite as chaves — nao ha' tempo escrito em codigo.
##
## Animacoes do diretor:
##   chegada         a primeira entrada: o Maycow entra devagar e, ainda
##                   andando, estica a mao pro ritual; a gota cai em camera
##                   lenta (`lento`); ela levanta, gira a cabeca (o pescoco
##                   estala e espirra sangue), a camera entra nos olhos dela,
##                   ele saca a arma, ela vira monstro e joga os bancos da
##                   nave pros lados (com poeira, `bancos_igreja.gd`)
##   vira_fase_2     a fase 1 morre e cresce na gigante que flutua
##   morte_final     a fase 2 morre e cai perto do Jonny
##   pega_jonny      o Maycow pega o Jonny no colo e sai correndo pela igreja
##
## As trilhas que mexem em coisa de fora dos atores passam por propriedades
## DESTE script (plano, barras, flash, vermelho...), animaveis como qualquer
## outra. Ex.: `plano` troca a camera ativa — e' um corte de cena.
##
## `previa_igreja` e' o modelo da igreja so' pra se ver onde as coisas estao
## no editor. No jogo esta cena e' filha da propria igreja e a previa some.
##
## Esta cena foi montada uma vez por `tools/igreja/montar_cena_dona_nice.gd`
## (que posou os atores e mediu a mao, a faca e a cabeca de verdade pra
## enquadrar cada plano). Dali em diante a fonte e' ESTE .tscn.

signal terminou(animacao: StringName)

const BANCOS := preload("res://scripts/stages/igreja/bancos_igreja.gd")
## Os sons que NAO entram na camera lenta (o clima de fundo segue normal).
const SONS_FORA_DO_LENTO := [&"ambiente"]

## Nome da camera ativa (filha de `cameras`). Vazio = nenhuma desta cena.
@export var plano: String = "":
	set(v):
		plano = v
		_ativar_camera()
@export_range(0.0, 1.0) var barras: float = 0.0:
	set(v):
		barras = v
		_lente("barras", v)
@export_range(0.0, 1.0) var flash: float = 0.0:
	set(v):
		flash = v
		_lente("flash", v)
@export_range(0.0, 1.0) var vermelho: float = 0.0:
	set(v):
		vermelho = v
		_lente("vermelho", v)
@export_range(0.0, 1.0) var borrao: float = 0.0:
	set(v):
		borrao = v
		_lente("radial_blur", v)
@export_range(0.0, 8.0) var aberracao: float = 1.0:
	set(v):
		aberracao = v
		_lente("aberration", v)
@export_range(0.0, 2.0) var saturacao: float = 0.85:
	set(v):
		saturacao = v
		_lente("saturation", v)
@export_range(0.0, 1.0) var gosma_na_tela: float = 0.0:
	set(v):
		gosma_na_tela = v
		_lente("gosma", v)
## Cor da gosma que escorre na tela: a baba da fase 1 e' verde; a cusparada
## da fase 2 troca pra cor de bile.
@export var cor_gosma: Color = Color(0.22, 0.55, 0.08):
	set(v):
		cor_gosma = v
		_lente("cor_gosma", Vector3(v.r, v.g, v.b))
@export_range(0.0, 1.0) var sangue_na_tela: float = 0.0:
	set(v):
		sangue_na_tela = v
		_lente("sangue_tela", v)
## Tunel escuro: so' o meio da tela fica nitido, o resto borra e escurece
## (o giro da cabeca dela).
@export_range(0.0, 1.0) var foco: float = 0.0:
	set(v):
		foco = v
		_lente("foco", v)
## Forma do `foco`: 0 = o tunel redondo, 1 = so' uma faixa estreita no meio
## nitida (os olhos dela, com a camera mirando entre eles).
@export_range(0.0, 1.0) var foco_olhos: float = 0.0:
	set(v):
		foco_olhos = v
		_lente("foco_olhos", v)
## Tamanho do que fica nitido no `foco` (cresce junto com o zoom).
@export_range(0.2, 8.0) var foco_tamanho: float = 1.0:
	set(v):
		foco_tamanho = v
		_lente("foco_tamanho", v)
## Fade pro preto (o fim da chegada fecha no preto e o jogo abre clareando).
@export_range(0.0, 1.0) var preto: float = 0.0:
	set(v):
		preto = v
		var r := get_node_or_null("lente/preto") as ColorRect
		if r:
			r.color.a = v
## Camera lenta (a gota de sangue caindo da faca): a escala do tempo do jogo
## inteiro — atores, chamas, particulas e o proprio diretor. O som desta cena
## tambem fica lento (mais grave, `tom_do_lento`), menos o ambiente
## (`SONS_FORA_DO_LENTO`): `Engine.time_scale` sozinho nao mexe no audio.
## Volta a 1 no fim da animacao, ao pular e ao sair da cena.
@export_range(0.05, 1.0) var lento: float = 1.0:
	set(v):
		lento = v
		if not Engine.is_editor_hint() and is_inside_tree():
			Engine.time_scale = v
			_som_lento(v)
## Quanto o som desce de tom na camera lenta: no tempo a 1/6, o som a ~0,4
## (o tempo inteiro arrastaria o som a um ronco sem forma).
@export_range(0.0, 1.0) var tom_do_lento: float = 0.5
## Tremor da camera ativa (0 parado, 1 terremoto).
@export_range(0.0, 1.0) var tremor: float = 0.0
## Energia do pulso vermelho da transformacao (luz `efeitos/luz_pulso`).
@export_range(0.0, 1.0) var pulso: float = 0.0:
	set(v):
		pulso = v
		var luz := get_node_or_null("efeitos/luz_pulso") as OmniLight3D
		if luz:
			luz.light_energy = 5.0 * v
			luz.visible = v > 0.001

@onready var diretor: AnimationPlayer = get_node_or_null("diretor")

var _offset_base := Vector2.ZERO
var _legenda_tween: Tween
var _bancos: Node3D
## Tom original de cada som da cena, guardado na primeira camera lenta.
var _tons := {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# os chefes acham a cena por aqui (a gosma na tela quando ela agarra)
	add_to_group("cena_dona_nice")
	# dentro da igreja a previa nao serve pra nada
	if get_parent() and get_parent().has_node("modelo"):
		var previa := get_node_or_null("previa_igreja")
		if previa:
			previa.queue_free()
		# os bancos da nave, soltos do modelo pra ela poder joga-los
		_bancos = BANCOS.new()
		_bancos.name = "bancos_igreja"
		_bancos.modelo = get_parent().get_node("modelo")
		get_parent().add_child.call_deferred(_bancos)
	if diretor and not diretor.animation_finished.is_connected(_ao_terminar):
		diretor.animation_finished.connect(_ao_terminar)
	var lente := get_node_or_null("lente") as CanvasLayer
	if lente:
		lente.visible = SaveManager.evento_dona_nice < 4


func tocar(animacao: StringName) -> void:
	var lente := get_node_or_null("lente") as CanvasLayer
	if lente:
		lente.visible = true
	diretor.play(animacao)


## Pula pro fim da animacao atual (o jogador segurou o botao de pular).
func pular() -> void:
	if diretor and diretor.is_playing():
		var a := diretor.current_animation
		diretor.seek(diretor.current_animation_length - 0.05, true)
		await get_tree().process_frame
		if diretor.current_animation == a:
			diretor.advance(0.1)


func _ao_terminar(animacao: StringName) -> void:
	if lento != 1.0:
		lento = 1.0
	_jonny_respirando()
	terminou.emit(animacao)


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and lento != 1.0:
		Engine.time_scale = 1.0


## Todo som da cena (os do diretor e os dos atores, como a respiracao do
## Jonny) desce de tom junto com o tempo; o ambiente fica de fora.
func _som_lento(v: float) -> void:
	if _tons.is_empty():
		if v >= 1.0:
			return
		for s in find_children("*", "", true, false):
			if (s is AudioStreamPlayer or s is AudioStreamPlayer3D) \
					and not s.name in SONS_FORA_DO_LENTO:
				_tons[s] = s.pitch_scale
	var fator := pow(v, tom_do_lento)
	for s in _tons:
		if is_instance_valid(s):
			s.pitch_scale = _tons[s] * fator


## O Jonny esta' vivo: o clipe dele (que arfa) nunca fica parado. Quando o
## diretor termina uma animacao ele PARA os clipes que tocou nos atores, e o
## Jonny congelava ate' a proxima cutscene.
func _jonny_respirando() -> void:
	var jonny := get_node_or_null("atores/Jonny") as AtorIgreja
	if jonny == null or jonny.anim == null or jonny.anim.is_playing():
		return
	var clipe := jonny.anim.assigned_animation
	jonny.tocar(clipe if clipe != &"" else &"caido_agonia", 0.3)


## Fim de uma cutscene: devolve a camera ao jogador. A LENTE FICA: durante a
## luta ela e' o clima (grao, vinheta, cor) e e' nela que a gosma da mordida
## escorre na tela. Quem a desliga de vez e' `esconder_lente`.
func encerrar_lente() -> void:
	plano = ""
	barras = 0.0
	borrao = 0.0
	foco = 0.0
	foco_olhos = 0.0
	foco_tamanho = 1.0
	flash = 0.0
	tremor = 0.0


## Volta do preto do fim de uma cena, ja' com a camera do jogador.
func clarear(duracao: float = 0.9) -> void:
	create_tween().tween_property(self, "preto", 0.0, duracao)


## Trilha de metodo do diretor: ela joga os bancos pros lados.
func afastar_bancos() -> void:
	if is_instance_valid(_bancos):
		_bancos.afastar()


## Os bancos ja' nas naves laterais, sem voo (recomeco da luta, cutscene
## pulada, visitas depois do evento).
func bancos_no_canto() -> void:
	if is_instance_valid(_bancos):
		_bancos.no_canto()


func esconder_lente() -> void:
	encerrar_lente()
	var lente := get_node_or_null("lente") as CanvasLayer
	if lente:
		lente.visible = false


## O corpo da monstro caido perto do Jonny (depois da morte final, e nas
## visitas seguintes).
func mostrar_corpo_da_monstro() -> void:
	var mo := get_node_or_null("atores/Monstro") as Node3D
	var marco := get_node_or_null("efeitos/corpo_da_monstro") as Node3D
	if mo == null:
		return
	if marco:
		# o marco e' o lugar no chao; deitada de bruços ela assenta (ver
		# `AtorIgreja.no_chao`), senao fica flutuando em cima do piso
		mo.global_transform = mo.no_chao(marco.global_transform) if mo.has_method("no_chao") \
			else marco.global_transform
	mo.visible = true
	mo.dissolver = 0.0
	mo.veias = 0.0
	if mo.anim:
		mo.anim.play(&"morta")


## As velas queimaram ate' o fim (visitas depois do evento).
func apagar_velas() -> void:
	var velas := get_node_or_null("efeitos/velas")
	if velas:
		for v in velas.get_children():
			var chama := v.get_node_or_null("chama")
			if chama:
				chama.visible = false
	var luz := get_node_or_null("efeitos/luz_velas") as Light3D
	if luz:
		luz.visible = false
	var pulso_luz := get_node_or_null("efeitos/luz_pulso") as Light3D
	if pulso_luz:
		pulso_luz.visible = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var cam := _camera_ativa()
	if cam and tremor > 0.001:
		var t := Time.get_ticks_msec() * 0.001
		cam.h_offset = (sin(t * 41.0) + sin(t * 23.7) * 0.6) * 0.035 * tremor
		cam.v_offset = (sin(t * 37.0) + sin(t * 17.3) * 0.6) * 0.035 * tremor
	elif cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## Legenda do sussurro/fala (trilha de metodo do diretor).
func legenda(chave: String, duracao: float = 3.5) -> void:
	var rotulo := get_node_or_null("lente/legenda") as Label
	if rotulo == null:
		return
	rotulo.text = tr(chave) if not Engine.is_editor_hint() else chave
	if _legenda_tween and _legenda_tween.is_valid():
		_legenda_tween.kill()
	rotulo.modulate.a = 0.0
	_legenda_tween = create_tween()
	_legenda_tween.tween_property(rotulo, "modulate:a", 1.0, 0.5)
	_legenda_tween.tween_interval(maxf(0.1, duracao - 1.1))
	_legenda_tween.tween_property(rotulo, "modulate:a", 0.0, 0.6)


## Dispara um efeito de particulas de uma vez (respingo, nevoa de sangue).
func estourar(caminho: NodePath) -> void:
	var p := get_node_or_null(caminho)
	if p is GPUParticles3D:
		(p as GPUParticles3D).restart()
		(p as GPUParticles3D).emitting = true


func vibrar(forca: float = 0.6, duracao: float = 0.3) -> void:
	if Engine.is_editor_hint():
		return
	GlobalUtils.vibrate_controller(Input, forca, forca, duracao)


func _camera_ativa() -> Camera3D:
	if plano.is_empty():
		return null
	# camera de palco vem com o caminho inteiro ("palco_fase_2/cam_f2_a")
	if "/" in plano:
		return get_node_or_null(plano) as Camera3D
	return get_node_or_null("cameras/" + plano) as Camera3D


func _ativar_camera() -> void:
	if not is_inside_tree():
		return
	var cam := _camera_ativa()
	if cam:
		cam.make_current()
		return
	if Engine.is_editor_hint():
		return
	# sem plano: devolve a camera do jogador (ele mesmo a reativa no
	# _physics_process quando _cutscene_camera_disabled volta a false)
	for c in find_children("*", "Camera3D", true, false):
		(c as Camera3D).current = false


func _lente(param: String, valor) -> void:
	var tela := get_node_or_null("lente/tela") as ColorRect
	if tela and tela.material is ShaderMaterial:
		(tela.material as ShaderMaterial).set_shader_parameter(param, valor)
