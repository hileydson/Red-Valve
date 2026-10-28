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
## As duas pontas são PORTAIS (`portal_vortice.gd`): o vento entra neles, e
## quem chega perto é sugado e viaja (`viagem_portal.gd`, as linhas roxas) pra
## `cena_saida` / `cena_entrada`, chegando no marcador `ponto_saida` /
## `ponto_entrada` de lá. Quem chega AQUI por um portal sai cuspido do vórtice
## que fica junto do marcador de chegada (`spawn_entrada` é o do começo,
## `spawn_saida` o do fim).
##
## O inferno 2 herda daqui: o que muda de um mapa pro outro (onde nasce o fogo
## ao longe, pra onde a sombra olha) está em `_ponto_erupcao` e `_giro_sombra`.

@export_group("Ligações")
## Cena do portal do FIM. Vazio = o portal só gira (e não suga).
@export_file("*.tscn") var cena_saida: String = ""
## Onde se chega na `cena_saida`: o nome do marcador de lá ("" = onde ela nasce).
@export var ponto_saida: String = "spawn_entrada"
## Cena do portal do COMEÇO. Vazio = o portal só gira.
@export_file("*.tscn") var cena_entrada: String = ""
## Onde se chega na `cena_entrada`.
@export var ponto_entrada: String = "spawn_saida"

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
const PortalVortice := preload("res://scripts/effects/portal_vortice.gd")

var _geiseres: Array[Dictionary] = []
var _modelo_erupcao: GPUParticles3D
var _erupcao_prazo: float = 1.0
var _sombras: Array[Dictionary] = []
var _portal_saida: Node3D
var _portal_entrada: Node3D


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

	_portal_saida = _montar_portal("saida", "spawn_saida", cena_saida, ponto_saida)
	_portal_entrada = _montar_portal("entrada", "spawn_entrada", cena_entrada, ponto_entrada)
	var ponto := ViagemPortal.pegar_chegada(scene_file_path)
	if ponto != "":
		_chegar(ponto)


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
## O portal da área `area_nome`, no vórtice mais perto dela, olhando pro
## marcador `spawn_nome` (é de lá que se chega e é pra lá que se é cuspido).
func _montar_portal(area_nome: String, spawn_nome: String, cena: String, ponto: String) -> Node3D:
	var area := get_node_or_null(area_nome) as Area3D
	if area == null:
		return null
	var vortice: MeshInstance3D = null
	var melhor := INF
	for no in get_children():
		var m := no as MeshInstance3D
		# o poço do inferno 2 é o fundo do funil (PlaneMesh), não um portal
		if m == null or not ("redemoinho" in String(m.name)) or not (m.mesh is QuadMesh):
			continue
		var d := m.global_position.distance_to(area.global_position)
		if d < melhor:
			melhor = d
			vortice = m
	# a área fica no vórtice; um longe é o da outra ponta
	if vortice == null or melhor > 40.0:
		return null
	var tam := (vortice.mesh as QuadMesh).size
	var spawn := get_node_or_null(spawn_nome) as Node3D
	var frente := (spawn.global_position - vortice.global_position) if spawn else vortice.global_basis.z
	var portal := PortalVortice.new()
	portal.name = "portal_" + area_nome
	add_child(portal)
	portal.montar(vortice, maxf(tam.x, tam.y) * 0.5, frente, cena, ponto)
	area.body_entered.connect(func(corpo: Node3D) -> void:
		if _eh_player(corpo):
			portal.tentar_sugar(corpo))
	return portal


## Chegou por portal: põe o jogador no marcador e, se ele for o de um dos dois
## portais daqui, o portal o cospe pra fora.
func _chegar(ponto: String) -> void:
	var marcador := get_node_or_null(ponto) as Node3D
	var player := get_node_or_null("Player") as CharacterBody3D
	if marcador == null or player == null:
		return
	player.global_transform = Transform3D(marcador.global_basis, marcador.global_position + Vector3.UP)
	var portal = null
	if ponto == "spawn_entrada":
		portal = _portal_entrada
	elif ponto == "spawn_saida":
		portal = _portal_saida
	if portal:
		portal.ejetar(player, marcador)


func _eh_player(corpo: Node3D) -> bool:
	return corpo.is_in_group("player") or corpo.name.to_lower() == "player"
