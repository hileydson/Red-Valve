extends CanvasLayer

## OS CRÉDITOS — o fim do jogo (Capítulo 5).
##
## Nasce na `root` no instante do abraço do Jimmy com o Jonny (`comecar`), só
## com a música ("I Want to go Home", Eldritch Grim, CC0) entrando devagar;
## por isso sobrevive a qualquer troca de cena. `apagar` é o fade longo da cena
## final; `rolar`, os créditos subindo bem devagar no preto. No fim, "Obrigado
## por jogar", a música desce e o jogo volta ao menu.
##
## Segurar o botão de aceitar acelera a rolagem.
##
## Os nomes e títulos ficam aqui (não se traduzem); os papéis e as seções saem
## do CSV de textos (chaves CREDITOS_*).

const ESTE := "res://scripts/ui/creditos.gd"
const MUSICA := "res://assets/sounds/capitulo_5/reencontro.ogg"
const MENU := "res://scenes/configs/main_menu_v2.tscn"
const FONTE := "res://assets/fonts/Montserrat-ExtraBold.ttf"
const VERMELHO := Color(0.705882, 0.0, 0.0)
const CINZA := Color(0.62, 0.6, 0.6)
## Quanto a rolagem inteira leva (a música tem 3:14; o abraço e o fade já
## comeram uns 40 s dela).
const DURACAO := 140.0
const VOLUME := -4.0

## [estilo, texto]: "titulo" e "nome" são literais; "secao", "papel" e "nota"
## são chaves do CSV; "espaco" é um respiro.
const LINHAS := [
	["titulo", "RED VALVE"],
	["papel", "CREDITOS_UM_JOGO_DE"],
	["nome", "Hileydson Luiz Cogo"],
	["espaco", ""],
	["secao", "CREDITOS_EQUIPE"],
	["papel", "CREDITOS_CRIACAO"],
	["nome", "Hileydson Luiz Cogo"],
	["papel", "CREDITOS_PARCEIRO"],
	["nome", "Iago Daltio"],
	["papel", "CREDITOS_ROSTOS"],
	["nome", "Diego de Oliveira Rodrigues"],
	["nome", "Marcio Martins Firme"],
	["papel", "CREDITOS_TESTES"],
	["nome", "Wisney Cogo"],
	["papel", "CREDITOS_APOIO"],
	["nome", "Camila Duque Lenzi"],
	["espaco", ""],
	["secao", "CREDITOS_TECNOLOGIA"],
	["papel", "CREDITOS_MOTOR"],
	["nome", "Godot Engine 4.6"],
	["nota", "CREDITOS_MOTOR_NOTA"],
	["papel", "CREDITOS_ADDONS"],
	["nome", "Terrain3D — Cory Petkovsek & Roope Palmroos"],
	["nome", "Sky3D — J. Cuéllar, Cory Petkovsek & Contributors"],
	["nome", "ProtonScatter — HungryProton"],
	["nome", "SunshineClouds 2 — Bonkahe"],
	["nome", "AmbientCG Downloader — Venit Studios & Contributors"],
	["nome", "Godot AI"],
	["papel", "CREDITOS_ARTE_3D"],
	["nome", "Blender 5.2 · Python (bpy)"],
	["nome", "Meshy AI · Adobe Mixamo"],
	["nota", "CREDITOS_ARTE_3D_NOTA"],
	["papel", "CREDITOS_IMAGEM"],
	["nome", "GIMP · Pillow"],
	["nome", "Poly Haven · ambientCG · Kenney (CC0)"],
	["papel", "CREDITOS_AUDIO"],
	["nome", "ffmpeg · NumPy"],
	["nota", "CREDITOS_AUDIO_NOTA"],
	["papel", "CREDITOS_ASSISTENCIA"],
	["nome", "Claude Code (Anthropic)"],
	["espaco", ""],
	["secao", "CREDITOS_MUSICA"],
	["nome", "\"I Want to go Home\" — Eldritch Grim (CC0)"],
	["nota", "CREDITOS_MUSICA_NOTA"],
	["espaco", ""],
	["secao", "CREDITOS_SONS"],
	["nome", "RPG Sound Pack — artisticdude"],
	["nome", "80 CC0 creature SFX"],
	["nome", "75 CC0 breaking / falling / hit sfx"],
	["nome", "40 CC0 water / splash / slime SFX"],
	["nome", "Dialog vocal samples"],
	["nome", "Deep Bone Crack/Break SFX · 7 Eating Crunches"],
	["nome", "CC0 Deep Monster Roar · Horror Scream1 · Evil Screech 1"],
	["nome", "High pitch scream sounds (2) · SkeletonSFXShortPack"],
	["nome", "Heartbeat sounds · breathing tired · Ambient Horror"],
	["nome", "Squish sounds effects"],
	["nome", "Electric Buzz · Dripping Water Loop"],
	["nome", "Mild wind background noise · 4 Atmospheric Ghostly Loops"],
	["nome", "Equipment Clicks II · 10 Clicks and Switches"],
	["espaco", ""],
	["secao", "CREDITOS_MODELOS"],
	["nome", "PSX Style Cars — GGBot (CC0)"],
	["nome", "3D assets created by jhonny"],
	["nome", "\"9x19mm (Luger/Parabellum) cartridge - (DWM) 1913\" — Orpind (CC BY-NC-ND 4.0)"],
	["nome", "\"10mm Ammo Box\" — VladIG_CG (CC BY 4.0)"],
	["espaco", ""],
	["secao", "CREDITOS_FONTES"],
	["nome", "Montserrat · Oswald · Caveat · Nosifer · Tiny5 — SIL OFL"],
	["nome", "Special Elite · Permanent Marker · Rock Salt — Apache 2.0"],
	["espaco", ""],
	["secao", "CREDITOS_AGRADECIMENTOS"],
	["nota", "CREDITOS_AGRADECIMENTOS_TEXTO"],
]

var _musica: AudioStreamPlayer
var _preto: ColorRect
var _rolo: VBoxContainer
var _dica: Label
var _rolando := false
var _terminando := false
var _y := 0.0
var _velocidade := 30.0
var _fonte: Font


## Cria os créditos na `root` (sobrevivem à troca de cena) e começa a música.
static func comecar(arvore: SceneTree) -> Node:
	var c = (load(ESTE) as GDScript).new()
	c.name = "Creditos"
	arvore.root.add_child(c)
	return c


func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = load(FONTE)
	_preto = ColorRect.new()
	_preto.color = Color(0, 0, 0, 0)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_preto)
	_musica = AudioStreamPlayer.new()
	_musica.stream = load(MUSICA)
	_musica.volume_db = -40.0
	add_child(_musica)
	_musica.play()
	create_tween().tween_property(_musica, "volume_db", VOLUME, 5.0).set_trans(Tween.TRANS_SINE)


## O fade longo da cena final: a tela vai ao preto em `duracao` segundos.
func apagar(duracao: float) -> void:
	var t := create_tween()
	t.tween_property(_preto, "color:a", 1.0, duracao).set_trans(Tween.TRANS_SINE)


## Os créditos sobem no preto.
func rolar() -> void:
	_preto.color.a = 1.0
	GlobalUtils.esconder_objetivo()
	var tela := get_viewport().get_visible_rect().size
	_rolo = VBoxContainer.new()
	_rolo.add_theme_constant_override("separation", 10)
	_rolo.custom_minimum_size = Vector2(minf(1100.0, tela.x * 0.9), 0.0)
	add_child(_rolo)
	for linha in LINHAS:
		_rolo.add_child(_linha(String(linha[0]), String(linha[1])))
	await get_tree().process_frame
	_rolo.position = Vector2((tela.x - _rolo.size.x) * 0.5, tela.y)
	_y = tela.y
	_velocidade = (tela.y + _rolo.size.y) / DURACAO
	_dica = Label.new()
	_dica.text = tr("CREDITOS_ACELERAR")
	_dica.add_theme_font_size_override("font_size", 16)
	_dica.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
	_dica.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dica.position = Vector2(tela.x - 360.0, tela.y - 40.0)
	add_child(_dica)
	_rolando = true


func _linha(estilo: String, texto: String) -> Control:
	if estilo == "espaco":
		var c := Control.new()
		c.custom_minimum_size = Vector2(0.0, 70.0)
		return c
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _fonte)
	match estilo:
		"titulo":
			l.text = texto
			l.add_theme_font_size_override("font_size", 110)
			l.add_theme_color_override("font_color", VERMELHO)
		"secao":
			l.text = tr(texto).to_upper()
			l.add_theme_font_size_override("font_size", 34)
			l.add_theme_color_override("font_color", VERMELHO)
			l.custom_minimum_size = Vector2(0.0, 70.0)
			l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		"papel":
			l.text = tr(texto)
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", CINZA)
			l.custom_minimum_size = Vector2(0.0, 40.0)
			l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		"nota":
			l.text = tr(texto)
			l.add_theme_font_size_override("font_size", 18)
			l.add_theme_color_override("font_color", CINZA)
		_:
			l.text = texto
			l.add_theme_font_size_override("font_size", 28)
			l.add_theme_color_override("font_color", Color(0.95, 0.93, 0.92))
	return l


func _process(delta: float) -> void:
	if not _rolando or _terminando:
		return
	var v := _velocidade * (5.0 if Input.is_action_pressed("ui_accept") else 1.0)
	_y -= v * delta
	_rolo.position.y = _y
	if _y + _rolo.size.y < 0.0:
		_terminar()


## "Obrigado por jogar", a música desce e o menu.
func _terminar() -> void:
	_terminando = true
	if is_instance_valid(_dica):
		_dica.queue_free()
	var obrigado := Label.new()
	obrigado.text = tr("CREDITOS_OBRIGADO")
	obrigado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obrigado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	obrigado.set_anchors_preset(Control.PRESET_FULL_RECT)
	obrigado.add_theme_font_override("font", _fonte)
	obrigado.add_theme_font_size_override("font_size", 56)
	obrigado.add_theme_color_override("font_color", VERMELHO)
	obrigado.modulate.a = 0.0
	add_child(obrigado)
	var t := create_tween()
	t.tween_property(obrigado, "modulate:a", 1.0, 2.5)
	t.tween_interval(5.0)
	t.tween_property(obrigado, "modulate:a", 0.0, 2.0)
	t.parallel().tween_property(_musica, "volume_db", -60.0, 4.0)
	await t.finished
	GlobalEvents.in_cutscene = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU)
	queue_free()
