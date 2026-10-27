extends "res://scripts/stages/cenario_aberto.gd"

## O INFERNO — mapa de passagem entre duas cenas.
##
## Modelo de `tools/blender/inferno/gerar_inferno.py`, cena de
## `tools/godot/inferno/gerar_cena_inferno.py`: luz, prop e navmesh mexidos no
## editor somem na próxima regeração. Este script é só comportamento.
##
## Caminho linear de ~1 km do PORTÃO (sul) ao PORTAL (norte), passando por oito
## áreas (os marcadores `areas/area_*` dizem onde cada uma fica — é por eles
## que se monta o conteúdo depois). Por conta própria o lugar:
##
##  - GÊISERES no caminho: a boca acende, fumega e cospe uma coluna de fogo;
##    quem estiver em cima queima;
##  - FOGO SUBINDO do mar de lava ao longe, em volta do jogador, o tempo todo;
##  - SOMBRAS gigantes de pé na lava, balançando e andando devagar;
##  - gárgulas cruzando o céu (a base solta), relâmpago vermelho raro.
##
## As duas pontas levam a outras cenas: `cena_saida` (o portal) vai pro inferno
## 2; `cena_entrada` (o portão por onde se chegou) ainda está vazia. Quem volta
## pela entrada da cena seguinte reaparece no `spawn_saida` daqui.
##
## O inferno 2 herda daqui: o que muda de um mapa pro outro (onde nasce o fogo
## ao longe, pra onde a sombra olha) está em `_ponto_erupcao` e `_giro_sombra`.

@export_group("Ligações")
## Cena carregada ao atravessar o portal do norte. Vazio = o portal só gira.
@export_file("*.tscn") var cena_saida: String = ""
## Cena carregada ao voltar pelo portão do sul. Vazio = o portão fica fechado.
@export_file("*.tscn") var cena_entrada: String = ""

@export_group("Gêiseres")
@export var geiser_espera_min: float = 7.0
@export var geiser_espera_max: float = 20.0
@export var geiser_aviso: float = 1.3
@export var geiser_jato: float = 2.2
@export var geiser_raio: float = 2.6
@export var geiser_dano: int = 10

@export_group("Fogo ao longe")
@export var erupcao_espera_min: float = 1.6
@export var erupcao_espera_max: float = 5.0
@export var erupcao_dist_min: float = 70.0
@export var erupcao_dist_max: float = 240.0

const LAVA := -14.0

## Cena que, ao abrir, põe o jogador no `spawn_saida` em vez do começo: quem
## volta pelo portão da cena seguinte tem de aparecer na frente da saída
## daqui. Static: sobrevive à troca de cena.
static var _chegar_pela_saida: String = ""

var _geiseres: Array[Dictionary] = []
var _modelo_erupcao: GPUParticles3D
var _erupcao_prazo: float = 1.0
var _sombras: Array[Dictionary] = []
var _trocando: bool = false


func _preparar() -> void:
	var raiz := get_node_or_null("geiseres")
	if raiz:
		for g in raiz.get_children():
			if not (g is Node3D):
				continue
			var luz := g.get_node_or_null("luz") as OmniLight3D
			if luz:
				luz.visible = false
			_geiseres.append({
				"no": g, "fase": 0, "prazo": randf_range(2.0, geiser_espera_max),
				"aviso": g.get_node_or_null("aviso"), "jato": g.get_node_or_null("jato"),
				"luz": luz, "som": g.get_node_or_null("som"), "tique": 0.0,
			})
	_modelo_erupcao = get_node_or_null("erupcoes/modelo") as GPUParticles3D
	if _modelo_erupcao:
		_modelo_erupcao.emitting = false
		_modelo_erupcao.visible = false

	var modelo := get_node_or_null("modelo")
	if modelo:
		for no in modelo.find_children("SOMBRA_*", "Node3D", true, false):
			var n3 := no as Node3D
			var a := randf() * TAU
			_sombras.append({
				"no": n3, "base": n3.position, "fase": randf() * TAU,
				"dir": Vector3(cos(a), 0.0, sin(a)), "anda": randf() < 0.55,
				"vel": randf_range(0.4, 1.1), "volta": randf_range(40.0, 110.0), "t": 0.0,
			})
			n3.rotation.y = _giro_sombra(n3.position) + randf_range(-0.5, 0.5)

	if _chegar_pela_saida != "" and _chegar_pela_saida == _caminho_real(scene_file_path):
		_chegar_pela_saida = ""
		var spawn := get_node_or_null("spawn_saida") as Node3D
		var player := get_node_or_null("Player") as Node3D
		if spawn and player:
			player.global_transform = Transform3D(spawn.global_basis, spawn.global_position + Vector3.UP)

	var saida := get_node_or_null("saida") as Area3D
	if saida:
		saida.body_entered.connect(_ao_entrar_portal)
	var entrada := get_node_or_null("entrada") as Area3D
	if entrada:
		entrada.body_entered.connect(_ao_voltar_portao)


## Para onde a SOMBRA em `p` olha. Aqui, pro caminho (o centro do mapa é x=0).
func _giro_sombra(p: Vector3) -> float:
	return atan2(-p.x, 0.0)


## Onde nasce o próximo fogo ao longe; Vector3.INF = nenhum desta vez. Aqui,
## no mar de lava em volta da câmera.
func _ponto_erupcao(cam: Camera3D) -> Vector3:
	var a := randf() * TAU
	var r := randf_range(erupcao_dist_min, erupcao_dist_max)
	var p := cam.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	p.y = LAVA
	return p


static func _caminho_real(caminho: String) -> String:
	if caminho.begins_with("uid://"):
		var id := ResourceUID.text_to_id(caminho)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return caminho


func _passo(delta: float) -> void:
	_passo_geiseres(delta)
	_passo_erupcoes(delta)
	_passo_sombras(delta)


# ==============================================================================
# GÊISERES
# ==============================================================================
func _passo_geiseres(delta: float) -> void:
	for g in _geiseres:
		g["prazo"] = float(g["prazo"]) - delta
		match int(g["fase"]):
			0:
				if g["prazo"] <= 0.0:
					g["fase"] = 1
					g["prazo"] = geiser_aviso
					if g["aviso"]:
						g["aviso"].emitting = true
					if g["luz"]:
						g["luz"].visible = true
						g["luz"].light_energy = 1.0
			1:
				if g["luz"]:
					var t := 1.0 - clampf(float(g["prazo"]) / geiser_aviso, 0.0, 1.0)
					g["luz"].light_energy = 1.0 + 3.0 * t * t
				if g["prazo"] <= 0.0:
					g["fase"] = 2
					g["prazo"] = geiser_jato
					g["tique"] = 0.0
					if g["jato"]:
						g["jato"].emitting = true
					if g["som"]:
						g["som"].pitch_scale = randf_range(0.85, 1.1)
						g["som"].play()
			2:
				if g["luz"]:
					g["luz"].light_energy = 7.0 + randf_range(-1.5, 1.5)
				g["tique"] = float(g["tique"]) - delta
				if g["tique"] <= 0.0:
					g["tique"] = 0.5
					_queimar(g["no"] as Node3D)
				if g["prazo"] <= 0.0:
					g["fase"] = 0
					g["prazo"] = randf_range(geiser_espera_min, geiser_espera_max)
					if g["aviso"]:
						g["aviso"].emitting = false
					if g["jato"]:
						g["jato"].emitting = false
					if g["luz"]:
						g["luz"].visible = false


func _queimar(geiser: Node3D) -> void:
	var p := geiser.global_position
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.has_method("take_damage"):
		var d := Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length()
		if d < geiser_raio and player.global_position.y < p.y + 8.0:
			player.take_damage(geiser_dano)
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if inimigo is Node3D and inimigo.has_method("take_damage"):
			var q := (inimigo as Node3D).global_position
			if Vector2(q.x - p.x, q.z - p.z).length() < geiser_raio:
				inimigo.take_damage(geiser_dano)


# ==============================================================================
# FOGO SUBINDO DO MAR DE LAVA
# ==============================================================================
func _passo_erupcoes(delta: float) -> void:
	if _modelo_erupcao == null:
		return
	_erupcao_prazo -= delta
	if _erupcao_prazo > 0.0:
		return
	_erupcao_prazo = randf_range(erupcao_espera_min, erupcao_espera_max)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := _ponto_erupcao(cam)
	if p == Vector3.INF:
		return
	var e := _modelo_erupcao.duplicate() as GPUParticles3D
	add_child(e)
	e.global_position = p
	e.scale = Vector3.ONE * randf_range(0.7, 1.6)
	e.visible = true
	e.restart()
	e.emitting = true
	get_tree().create_timer(e.lifetime + 1.0).timeout.connect(e.queue_free)


# ==============================================================================
# SOMBRAS
# ==============================================================================
func _passo_sombras(delta: float) -> void:
	for s in _sombras:
		var no: Node3D = s["no"]
		if not is_instance_valid(no):
			continue
		var f: float = float(s["fase"]) + _tempo * 0.35
		# balança como coisa que respira (e bem devagar, que é grande)
		no.rotation.z = sin(f) * 0.035
		no.rotation.x = sin(f * 0.7 + 1.3) * 0.02
		if s["anda"]:
			s["t"] = float(s["t"]) + delta
			if s["t"] > s["volta"]:
				s["t"] = 0.0
				s["dir"] = -(s["dir"] as Vector3)
			no.position += (s["dir"] as Vector3) * float(s["vel"]) * delta
			# passo: sobe e desce um pouco a cada passada
			no.position.y = (s["base"] as Vector3).y + absf(sin(_tempo * 0.6 + float(s["fase"]))) * 1.2


# ==============================================================================
# PONTAS
# ==============================================================================
func _ao_entrar_portal(corpo: Node3D) -> void:
	if not _eh_player(corpo):
		return
	if cena_saida == "":
		push_warning("inferno: portal sem `cena_saida` definida")
		return
	_trocar(cena_saida)


func _ao_voltar_portao(corpo: Node3D) -> void:
	if not _eh_player(corpo) or cena_entrada == "":
		return
	# a cena de trás abre com o jogador na frente da saída dela
	_chegar_pela_saida = _caminho_real(cena_entrada)
	_trocar(cena_entrada)


func _trocar(cena: String) -> void:
	if _trocando:
		return
	_trocando = true
	GlobalEvents.in_cutscene = true
	var fade := get_node_or_null("fade")
	if fade and fade.has_method("fade_out"):
		fade.fade_out()
	await get_tree().create_timer(1.6).timeout
	LoadingScreen.load_scene(cena)


func _eh_player(corpo: Node3D) -> bool:
	return corpo.is_in_group("player") or corpo.name.to_lower() == "player"
