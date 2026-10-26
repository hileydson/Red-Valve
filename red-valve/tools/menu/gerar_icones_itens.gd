extends Node3D

## Os icones do menu de itens: o proprio modelo 3D de cada item, fotografado
## com fundo transparente e recortado — o mesmo jeito dos icones da MK3, da
## Granola e da cacadeira. Substitui os desenhos antigos em preto e branco.
##
##     Godot_v4.6.1 --path red-valve res://tools/menu/gerar_icones_itens.tscn
##     ICONES=relogio,pistola ... (so' alguns)    ICONES_PREVIA=1 (grava no user://)
##
## Precisa de janela (sem --headless): e' um render de verdade.
##
## Cada item diz o modelo, como ele fica virado pra foto (graus, em X/Y/Z) e o
## arquivo. A camera e' ortogonal e se ajusta sozinha a' caixa do modelo; o
## recorte tira a sobra transparente e a largura final e' a dos icones novos.
##
## `tamanho` (opcional, 0 a 1) encolhe o item dentro do icone, com borda
## transparente em volta: o slot do menu estica o icone ate' a largura, e um
## item fino e comprido (a chave) ficava enorme perto dos outros.

const LARGURA := 580
const RENDER := 1024
const MARGEM := 12

const ITENS := [
	{"nome": "relogio", "modelo": "res://assets/3d_model/player/Maycow Lopes/relogio.glb",
		"giro": Vector3(70, 0, 0), "saida": "res://assets/images/menu/itens/relogio.png"},
	{"nome": "amuleto", "modelo": "res://assets/3d_model/player/Maycow Lopes/amuleto_power.glb",
		"giro": Vector3(0, 0, 0), "saida": "res://assets/images/menu/itens/amuleto_2d.png"},
	{"nome": "lanterna", "modelo": "res://assets/3d_model/player/lanterna/lanterna.glb",
		"giro": Vector3(15, 35, 0), "saida": "res://assets/images/menu/itens/lanterna_2d.png"},
	{"nome": "cogblade", "modelo": "res://assets/3d_model/player/Crescent Cogblade/Crescent Cogblade.glb",
		"giro": Vector3(0, 0, 0), "saida": "res://assets/images/menu/itens/red_valve/cogblade.png"},
	{"nome": "pistola", "modelo": "res://assets/3d_model/player/the_negotiator_V1/the_negotiator_v1.glb",
		"giro": Vector3(0, 180, 0), "saida": "res://assets/images/menu/itens/red_valve/pistola.png"},
	{"nome": "pistola_bala", "modelo": "res://assets/3d_model/player/the_negotiator_V1/cartridge/scene.gltf",
		"giro": Vector3(20, 30, 0), "saida": "res://assets/images/menu/itens/red_valve/pistola_bala.png"},
	{"nome": "chave_igreja", "modelo": "res://assets/3d_model/objects/chave_igreja/chave_igreja.glb",
		"giro": Vector3(70, 0, 0), "saida": "res://assets/images/menu/itens/red_valve/chave_igreja.png",
		"tamanho": 0.6},
	{"nome": "seringa_adrenalina", "modelo": "res://assets/3d_model/objects/seringa_adrenalina/seringa_adrenalina.glb",
		"giro": Vector3(20, 0, -20), "saida": "res://assets/images/menu/itens/red_valve/seringa_adrenalina.png"},
]


func _ready() -> void:
	get_viewport().transparent_bg = true
	get_window().size = Vector2i(RENDER, RENDER)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = env
	add_child(ambiente)
	# chave de cima/frente, recorte de tras pra desenhar a silhueta
	for d in [[Vector3(-40, -30, 0), 1.6], [Vector3(-20, 150, 0), 0.7], [Vector3(-70, 60, 0), 0.4]]:
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = d[0]
		luz.light_energy = d[1]
		add_child(luz)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.make_current()

	var so := OS.get_environment("ICONES").split(",", false)
	var previa := not OS.get_environment("ICONES_PREVIA").is_empty()
	for item in ITENS:
		if not so.is_empty() and not so.has(item["nome"]):
			continue
		var cena: PackedScene = load(item["modelo"])
		if cena == null:
			push_warning("icone: sem modelo %s" % item["modelo"])
			continue
		var pivo := Node3D.new()
		add_child(pivo)
		var modelo := cena.instantiate() as Node3D
		pivo.add_child(modelo)
		pivo.rotation_degrees = item["giro"]
		await get_tree().process_frame
		var caixa := _caixa(modelo)
		# o modelo no meio, a camera olhando do +Z e cobrindo a caixa inteira
		modelo.global_position -= caixa.get_center()
		caixa.position -= caixa.get_center()
		camera.position = Vector3(0, 0, caixa.size.length() * 2.0 + 1.0)
		camera.size = maxf(caixa.size.x, caixa.size.y) * 1.15
		camera.near = 0.01
		camera.far = caixa.size.length() * 4.0 + 2.0
		for _i in 3:
			await RenderingServer.frame_post_draw
		var imagem := get_viewport().get_texture().get_image()
		imagem.convert(Image.FORMAT_RGBA8)
		imagem = _recortar(imagem)
		var alto := int(round(float(imagem.get_height()) * LARGURA / imagem.get_width()))
		imagem.resize(LARGURA, alto, Image.INTERPOLATE_LANCZOS)
		imagem = _encolher(imagem, float(item.get("tamanho", 1.0)))
		var destino: String = item["saida"]
		if previa:
			DirAccess.make_dir_recursive_absolute("user://icones_previa")
			destino = "user://icones_previa/%s.png" % item["nome"]
		imagem.save_png(ProjectSettings.globalize_path(destino))
		print("icone ", item["nome"], " -> ", ProjectSettings.globalize_path(destino), " ", imagem.get_size())
		pivo.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## A caixa do que aparece (todas as malhas), em mundo.
func _caixa(raiz: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var c := mi.global_transform * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return caixa


## O item em `tamanho` do icone, centralizado, com o resto transparente.
func _encolher(imagem: Image, tamanho: float) -> Image:
	if tamanho >= 0.999:
		return imagem
	var w := imagem.get_width()
	var h := imagem.get_height()
	var menor := imagem.duplicate() as Image
	menor.resize(int(round(w * tamanho)), int(round(h * tamanho)), Image.INTERPOLATE_LANCZOS)
	# a altura cresce tambem: o icone continua com a proporcao do item, so' que
	# com borda — senao o slot esticaria a chave de novo ate' a largura
	var tela := Image.create(w, int(round(h / tamanho * 0.75 + h * 0.25)), false, Image.FORMAT_RGBA8)
	tela.blit_rect(menor, Rect2i(Vector2i.ZERO, menor.get_size()),
		(tela.get_size() - menor.get_size()) / 2)
	return tela


## Tira a sobra transparente, deixando uma margem.
func _recortar(imagem: Image) -> Image:
	var uso := imagem.get_used_rect()
	if uso.size.x <= 0 or uso.size.y <= 0:
		return imagem
	uso = uso.grow(MARGEM).intersection(Rect2i(Vector2i.ZERO, imagem.get_size()))
	return imagem.get_region(uso)
