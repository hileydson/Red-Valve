extends Node3D

## SALA DE TESTE — bancada de inimigos. NAO faz parte do jogo.
##
## So' o Maycow normal (o da cidade, que pode ser agarrado) e os inimigos que
## voce chamar, num chao de 60 m com umas caixas pra se esconder. O Maycow ja'
## entra com a pistola equipada, a cacadeira e a MK3 no inventario, municao das
## tres e seringas. A pausa (Start/Esc) e o inventario funcionam como numa fase.
##
## O MENU DE TESTE abre com L3 + R3 juntos no controle, ou F4 no teclado (e
## fecha com B/Esc ou com o mesmo atalho). Nele:
##   - a lista de TODOS os inimigos do jogo: escolheu, ele cai na sala;
##   - a distancia de onde ele cai (perto, pra testar agarrao; longe, pra
##     ver o comportamento de quando ainda nao viu o Maycow);
##   - limpar a sala, curar o Maycow, repor a municao.
##
## A lista nao e' escrita a mao: sai de uma varredura de `scenes/enemies/`
## (ver `_descobrir_inimigos`). Inimigo novo aparece sozinho, desde que more
## la' e seja inimigo de verdade (grupo "enemies", ou montado sobre o
## `enemy.tscn`).
##
## Roda no slot 9 (`SaveManager.current_slot`): a sala nunca grava por cima do
## save de quem esta' testando. Isso continua valendo depois de sair dela pelo
## debug-travel; pra voltar ao save de verdade, carregue pelo menu principal.

const PLAYER := preload("res://scenes/player/player.tscn")

const PASTA_INIMIGOS := "res://scenes/enemies"
## O molde comum dos inimigos antigos: sozinho nao tem corpo nem modelo.
const MOLDES := ["res://scenes/enemies/enemy.tscn"]
const DISTANCIAS := [12.0, 6.0, 3.0]

## Escuta os atalhos mesmo com o jogo pausado (a sala em si pausa junto: o
## sangue, as pecas e os inimigos param enquanto o menu esta' aberto).
class Atalhos extends Node:
	var sala: Node

	func _input(evento: InputEvent) -> void:
		sala._input_do_menu(evento)

var _player: Node3D
var _inimigos: Array[Node] = []
var _rotulo: Label

## [{nome, cena}], em ordem alfabetica.
var _catalogo: Array = []
var _distancia: int = 0

# --- o menu ---
var _menu: CanvasLayer
var _menu_aberto: bool = false
var _lista: GridContainer
var _btn_distancia: Button
var _status: Label
var _fechando: bool = false


func _ready() -> void:
	SaveManager.current_slot = 9
	GlobalEvents.in_cutscene = false
	GlobalEvents.is_maycow_normal = true
	_armar()
	_ambiente()
	_chao()
	_caixas()
	_painel()
	_catalogo = _descobrir_inimigos()
	_monta_menu()
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector3(0, 1.12, 0)
	# comeca com o lekroso, o primeiro da lista nao e' sempre o mais testado
	for i in _catalogo.size():
		if String(_catalogo[i]["cena"]).ends_with("lekroso_1.tscn"):
			_novo_inimigo(i)
			break


func _armar() -> void:
	for item in [["pistol", 1], ["pistol_ammo", 150], ["shotgun", 1], ["shotgun_ammo", 60],
			["mk3", 1], ["mk3_ammo", 120], ["seringa_adrenalina", 5], ["seringa_magia", 3]]:
		if not SaveManager.tem_item(item[0]):
			SaveManager.add_item(item[0], item[1])
	SaveManager.equip_item("pistol")


func _repor_municao() -> void:
	for item in [["pistol_ammo", 150], ["shotgun_ammo", 60], ["mk3_ammo", 120],
			["seringa_adrenalina", 5], ["seringa_magia", 3]]:
		if SaveManager.get_item_amount(item[0]) < item[1]:
			if SaveManager.tem_item(item[0]):
				SaveManager.debug_definir_quantidade(item[0], item[1])
			else:
				SaveManager.add_item(item[0], item[1])


func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.01
	env.fog_light_color = Color(0.08, 0.08, 0.1)
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, 35, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	add_child(sol)


func _chao() -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 2
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(60, 1, 60)
	forma.shape = caixa
	forma.position.y = -0.5
	corpo.add_child(forma)
	var mi := MeshInstance3D.new()
	var plano := BoxMesh.new()
	plano.size = Vector3(60, 1, 60)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.29, 0.27)
	mat.roughness = 0.95
	plano.material = mat
	mi.mesh = plano
	mi.position.y = -0.5
	add_child(mi)


## Umas caixas espalhadas: pra ver o inimigo contornar parede e pro sangue
## ter onde respingar.
func _caixas() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.3, 0.24)
	for p in [Vector3(6, 0, -6), Vector3(-7, 0, -3), Vector3(-4, 0, 8), Vector3(9, 0, 5)]:
		var corpo := StaticBody3D.new()
		corpo.collision_layer = 2
		add_child(corpo)
		corpo.position = p + Vector3(0, 0.75, 0)
		var forma := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(1.5, 1.5, 1.5)
		forma.shape = b
		corpo.add_child(forma)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b.size
		bm.material = mat
		mi.mesh = bm
		corpo.add_child(mi)


func _painel() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 90
	add_child(camada)
	_rotulo = Label.new()
	_rotulo.position = Vector2(16, 120)
	_rotulo.add_theme_font_size_override("font_size", 15)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 0.75))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_rotulo.add_theme_constant_override("outline_size", 4)
	camada.add_child(_rotulo)
	_atualiza_painel()


func _atualiza_painel() -> void:
	_inimigos = _inimigos.filter(func(i): return is_instance_valid(i))
	if _rotulo:
		_rotulo.text = tr("SALA_TESTE_AJUDA") + "\n" + tr("SALA_TESTE_NA_SALA") % _inimigos.size()
	if _status:
		_status.text = tr("SALA_TESTE_NA_SALA") % _inimigos.size()


# ============================================================ os inimigos

## Todo .tscn de `scenes/enemies/` (com subpastas) que e' inimigo de verdade:
## esta' no grupo "enemies" na propria cena, o script dela entra no grupo, ou
## ela e' montada sobre o molde `enemy.tscn` (zumbi, Cobalt, Anti-Lopes).
## Pecas soltas que moram la' (sangue, gosma, projetil) ficam de fora.
func _descobrir_inimigos() -> Array:
	var cenas: Array[String] = []
	_varrer(PASTA_INIMIGOS, cenas)
	var achados: Array = []
	for caminho in cenas:
		if caminho in MOLDES or not _e_inimigo(caminho):
			continue
		achados.append({"nome": _nome_bonito(caminho), "cena": caminho})
	achados.sort_custom(func(a, b): return String(a["nome"]).naturalnocasecmp_to(String(b["nome"])) < 0)
	return achados


func _varrer(pasta: String, saida: Array[String]) -> void:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	for sub in dir.get_directories():
		_varrer(pasta.path_join(sub), saida)
	for arquivo in dir.get_files():
		# no jogo exportado a cena vira "x.tscn.remap"
		var nome := arquivo.trim_suffix(".remap")
		if nome.ends_with(".tscn") and not saida.has(pasta.path_join(nome)):
			saida.append(pasta.path_join(nome))


func _e_inimigo(caminho: String) -> bool:
	var texto := FileAccess.get_file_as_string(caminho)
	if texto == "":
		return ResourceLoader.exists(caminho)  # exportado: confia na pasta
	var grupo := RegEx.create_from_string("groups=\\[[^\\]]*\"enemies\"")
	if grupo.search(texto) != null:
		return true
	for molde in MOLDES:
		if texto.contains("path=\"" + molde + "\""):
			return true
	# o script da raiz poe no grupo por codigo
	var raiz := texto.find("\n[node ")
	var script_raiz := RegEx.create_from_string("script = ExtResource\\(\"([^\"]+)\"\\)")
	var m := script_raiz.search(texto, raiz)
	if m != null:
		var id := m.get_string(1)
		var ext := RegEx.create_from_string("\\[ext_resource type=\"Script\"[^\\]]*path=\"([^\"]+)\" id=\"" + id + "\"")
		var e := ext.search(texto)
		if e != null and FileAccess.get_file_as_string(e.get_string(1)).contains("add_to_group(\"enemies\")"):
			return true
	return false


## "res://scenes/enemies/dona_nice/boss_dona_nice_fase_2.tscn" ->
## "Boss Dona Nice Fase 2".
func _nome_bonito(caminho: String) -> String:
	return caminho.get_file().get_basename().replace("_", " ").capitalize()


func _novo_inimigo(indice: int) -> void:
	if indice < 0 or indice >= _catalogo.size():
		return
	var cena := load(_catalogo[indice]["cena"]) as PackedScene
	if cena == null:
		return
	var inimigo := cena.instantiate() as Node3D
	if inimigo == null:
		return
	add_child(inimigo)
	# cai na frente do Maycow (pra onde a camera olha), na distancia escolhida
	var frente := Vector3.FORWARD
	var cam := get_viewport().get_camera_3d()
	if is_instance_valid(cam):
		frente = -cam.global_basis.z
	frente.y = 0.0
	if frente.length() < 0.01:
		frente = Vector3.FORWARD
	frente = frente.normalized().rotated(Vector3.UP, randf_range(-0.35, 0.35))
	var d: float = DISTANCIAS[_distancia]
	inimigo.global_position = _player.global_position * Vector3(1, 0, 1) \
		+ frente * d + Vector3(0, 0.05, 0)
	_inimigos.append(inimigo)
	_atualiza_painel()


func _limpar() -> void:
	for i in _inimigos:
		if is_instance_valid(i):
			i.queue_free()
	_inimigos.clear()
	_atualiza_painel()


func _curar() -> void:
	if is_instance_valid(_player):
		_player.current_health = _player.max_health


# ============================================================ o menu

func _monta_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 95
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.visible = false
	add_child(_menu)
	var atalhos := Atalhos.new()
	atalhos.sala = self
	atalhos.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(atalhos)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(centro)

	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(760, 0)
	centro.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	painel.add_child(margem)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margem.add_child(vbox)

	var titulo := Label.new()
	titulo.text = tr("SALA_TESTE_TITULO")
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)

	var sub := Label.new()
	sub.text = tr("SALA_TESTE_TRAZER")
	sub.add_theme_font_size_override("font_size", 17)
	vbox.add_child(sub)

	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(0, 300)
	rolagem.follow_focus = true
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(rolagem)

	_lista = GridContainer.new()
	_lista.columns = 2
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("h_separation", 12)
	_lista.add_theme_constant_override("v_separation", 8)
	rolagem.add_child(_lista)
	for i in _catalogo.size():
		var b := _botao(String(_catalogo[i]["nome"]), _escolheu.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista.add_child(b)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	vbox.add_child(linha)
	_btn_distancia = _botao("", _troca_distancia)
	linha.add_child(_btn_distancia)
	linha.add_child(_botao(tr("SALA_TESTE_LIMPAR"), func(): _limpar()))
	linha.add_child(_botao(tr("SALA_TESTE_CURAR"), func(): _curar()))
	linha.add_child(_botao(tr("SALA_TESTE_MUNICAO"), func(): _repor_municao()))
	for b in linha.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rodape := HBoxContainer.new()
	vbox.add_child(rodape)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rodape.add_child(_status)
	rodape.add_child(_botao(tr("SALA_TESTE_FECHAR"), func(): _fechar_menu()))

	_atualiza_distancia()
	_atualiza_painel()


func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		GlobalUtils.play_ui_sound("res://assets/sounds/menu_itens/selecionar_item.mp3")
		acao.call())
	return b


func _escolheu(indice: int) -> void:
	await _fechar_menu()
	_novo_inimigo(indice)


func _troca_distancia() -> void:
	_distancia = (_distancia + 1) % DISTANCIAS.size()
	_atualiza_distancia()


func _atualiza_distancia() -> void:
	if _btn_distancia:
		_btn_distancia.text = tr("SALA_TESTE_DISTANCIA") % int(DISTANCIAS[_distancia])


func _abrir_menu() -> void:
	if _menu_aberto or _fechando:
		return
	# por cima da pausa, do inventario ou de uma cena nao abre
	if get_tree().paused or GlobalEvents.in_cutscene or GlobalEvents.agarrao_rodando:
		return
	_menu_aberto = true
	_atualiza_painel()
	_menu.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var primeiro := _lista.get_child(0) as Control if _lista.get_child_count() > 0 else _btn_distancia
	primeiro.grab_focus()


## Despausa DOIS quadros depois: o botao que fechou nao pode vazar pro jogo
## (ver o `in_game_menu.close_menu`).
func _fechar_menu() -> void:
	if not _menu_aberto or _fechando:
		return
	_fechando = true
	_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GlobalEvents.bloquear_dash_por()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	_menu_aberto = false
	_fechando = false


func _input_do_menu(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo \
			and (evento as InputEventKey).keycode == KEY_F4:
		_alternar()
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventJoypadButton and evento.pressed:
		# L3 + R3: o segundo a descer, com o outro ainda apertado
		var b := (evento as InputEventJoypadButton).button_index
		var outro := JOY_BUTTON_RIGHT_STICK if b == JOY_BUTTON_LEFT_STICK else JOY_BUTTON_LEFT_STICK
		if (b == JOY_BUTTON_LEFT_STICK or b == JOY_BUTTON_RIGHT_STICK) \
				and Input.is_joy_button_pressed(evento.device, outro):
			_alternar()
			get_viewport().set_input_as_handled()
			return
	if _menu_aberto and (evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("ui_pause") \
			or (evento is InputEventJoypadButton and evento.pressed \
				and (evento as InputEventJoypadButton).button_index == JOY_BUTTON_B)):
		_fechar_menu()
		get_viewport().set_input_as_handled()


func _alternar() -> void:
	if _menu_aberto:
		_fechar_menu()
	else:
		_abrir_menu()
