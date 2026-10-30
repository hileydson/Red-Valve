extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A PRAÇA DA IGREJA (Capítulo 2): o Maycow vê a Dona Nice entrando na igreja.
##
##  1. o Maycow anda pela praça, na frente da igreja, procurando;
##  2. de repente para e vira a cabeça pra igreja;
##  3. por cima do ombro dele: a Dona Nice atravessando o adro de mão dada com
##     o Jonny, de costas, indo pra porta;
##  4. mais perto, os dois chegando na porta;
##  5. o rosto do Maycow — a porta bate e o sino toca: eles entraram;
##  6. a porta da igreja, sem ninguém.
##
## A câmera corta ANTES de eles encostarem na porta (a porta do scan não
## abre): eles somem enquanto ela está no rosto do Maycow. Conclui
## `CAP2_NICE_ENTRA_IGREJA` no fim. Quem monta os atores e os solta depois é
## o `capitulo_2_cidade.gd`.

const SOM_PORTA := "res://assets/sounds/igreja/tapa_chao.ogg"
const SOM_SINO := "res://assets/sounds/cenarios/sino.ogg"

## Onde o Maycow anda (pela praça, paralelo à fachada, rumo ao -Z) e para.
const MAYCOW_DE := Vector3(566.0, 0.0, -301.5)
const MAYCOW_PARA := Vector3(566.0, 0.0, -311.5)
## A Dona Nice sai daqui e vai até a porta; o Jonny vai do lado esquerdo dela.
const NICE_INICIO := Vector3(573.6, 0.0, -318.0)
const NICE_PORTA := Vector3(581.0, 0.0, -318.0)
const VELOCIDADE := 0.9
## A porta da igreja (a fachada olha pro -X).
const PORTA := Vector3(582.1, 0.0, -317.7)
## A colisão da igreja engole o adro a partir daqui: raio que começa dentro
## dela atravessa e acha o chão, mas além disto o chão é o do adro, que sobe
## uns centímetros até a soleira.
const X_MURO := 579.0

var dona: Node3D
var jonny: Node3D

var _andando := false
var _dir := Vector3.RIGHT
## Luz de rosto pros closes: à noite, na praça, o rosto dele é breu.
var _luz_rosto: OmniLight3D


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 52.0)
	await escurecer(1.0, 0.4)
	_posicionar()
	_luz_da_porta()
	await esperar(0.25)
	if vale():
		await _andando_pela_praca()
	if vale():
		await _olha_pra_igreja()
	if vale():
		await _eles_no_adro()
	if vale():
		await _chegando_na_porta()
	if vale():
		await _a_porta_bate()
	if vale():
		await _a_porta_vazia()
	Eventos.concluir(Eventos.CAP2_NICE_ENTRA_IGREJA)
	encerrar(1.0)


func _posicionar() -> void:
	var y := _chao(MAYCOW_DE)
	player.global_position = Vector3(MAYCOW_DE.x, y + 1.0, MAYCOW_DE.z)
	player.velocity = Vector3.ZERO
	# o corpo olha pro -Z com giro zero: anda rumo ao -Z, paralelo à fachada
	player.rotation.y = 0.0
	_dir = (NICE_PORTA - NICE_INICIO).normalized()
	var giro := atan2(_dir.x, _dir.z)
	var lado_esquerdo := -Vector3(-_dir.z, 0.0, _dir.x)
	dona.global_position = Vector3(NICE_INICIO.x, _chao(NICE_INICIO), NICE_INICIO.z)
	dona.rotation.y = giro
	jonny.global_position = dona.global_position + lado_esquerdo * 0.55
	jonny.rotation.y = giro
	dona.visible = false
	jonny.visible = false


func _process(delta: float) -> void:
	if not _andando or not is_instance_valid(dona):
		return
	if dona.global_position.x >= NICE_PORTA.x:
		_andando = false
		return
	var passo := _dir * VELOCIDADE * delta
	for ator in [dona, jonny]:
		var p: Vector3 = ator.global_position + passo
		p.y = _chao(p)
		ator.global_position = p


# ============================================================ 1) andando

func _andando_pela_praca() -> void:
	await escurecer(0.0, 0.6)
	player.cutscene_set_auto_walk(true)
	# na frente dele, um pouco pro lado da igreja, de olho nele vindo
	await fase(3.2, func(k: float) -> void:
		player.rotation.y = 0.0
		var p := _corpo()
		var de := p + Vector3(1.5, 1.55, -3.4 + k * 0.4)
		plantar(de, p + Vector3(0.0, 1.45, 0.0)))
	player.cutscene_set_auto_walk(false)
	player.velocity = Vector3.ZERO


# ============================================================ 2) o olhar

func _olha_pra_igreja() -> void:
	var cabeca := _cabeca()
	_acender_rosto(cabeca)
	# de perfil (o lado da igreja), e ele vira o rosto pra câmera — pra igreja
	var de := cabeca + Vector3(1.05, 0.04, -0.5)
	plantar(de, cabeca)
	await esperar(0.35)
	if not vale():
		return
	var giro_ini := player.rotation.y
	var giro_fim := -PI * 0.5
	await fase(0.55, func(k: float) -> void:
		player.rotation.y = lerp_angle(giro_ini, giro_fim, suave(k))
		var c := _cabeca()
		plantar(de.lerp(c + Vector3(0.95, 0.02, -0.2), suave(k)), c))
	await esperar(0.7)
	_apagar_rosto()


# ============================================================ 3) no adro

func _eles_no_adro() -> void:
	dona.visible = true
	jonny.visible = true
	dona.tocar(&"escola/andar_de_mao", 0.0)
	jonny.tocar(&"escola/andar_de_mao", 0.0)
	_andando = true
	legenda("CAP2_CENA_IGREJA_MAYCOW_1", 3.2)
	# por cima do ombro direito dele: os dois lá na frente, de costas, indo pra
	# porta
	var de := _cabeca() + Vector3(-1.9, 0.15, 0.7)
	await fase(4.0, func(k: float) -> void:
		var alvo := (dona.global_position + jonny.global_position) * 0.5 + Vector3.UP * 0.9
		plantar(de + Vector3(suave(k) * 0.9, 0.0, 0.0), alvo))


# ============================================================ 4) na porta

func _chegando_na_porta() -> void:
	# baixo, no canto do adro: eles de costas subindo pra porta
	var de := Vector3(575.6, _chao(Vector3(575.6, 0, -321.6)) + 0.9, -321.6)
	await fase(3.9, func(k: float) -> void:
		var alvo := (dona.global_position + jonny.global_position) * 0.5 + Vector3.UP * 1.0
		plantar(de + Vector3(suave(k) * 0.8, 0.0, 0.0), alvo.lerp(_porta_em(1.6), 0.35)))


# ============================================================ 5) a porta bate

func _a_porta_bate() -> void:
	# no rosto dele: os dois entraram; a porta bate lá longe e o sino toca
	_andando = false
	dona.visible = false
	jonny.visible = false
	var cabeca := _cabeca()
	_acender_rosto(cabeca)
	var de := cabeca + Vector3(0.95, 0.0, -0.3)
	plantar(de, cabeca)
	_tocar_som(SOM_PORTA, 2.0, 0.55)
	await esperar(0.45)
	_tocar_som(SOM_SINO, -4.0, 0.9)
	GlobalUtils.vibrate_controller(null, 0.4, 0.3, 0.3)
	await plano(de, cabeca, de + Vector3(-0.25, 0.0, 0.05), cabeca, 2.2)
	_apagar_rosto()


# ============================================================ 6) a porta vazia

func _a_porta_vazia() -> void:
	legenda("CAP2_CENA_IGREJA_MAYCOW_2", 3.6)
	var de := Vector3(568.5, _chao(Vector3(568.5, 0, -316.0)) + 1.4, -316.0)
	await plano(de, _porta_em(1.6), de + Vector3(2.2, 0.2, -0.4), _porta_em(1.9), 3.6)


# ============================================================ peças

## Onde o Maycow APARECE. O modelo não fica na origem do corpo: o pivô de
## virar (estilo RDR2) o deixa uns 70 cm atrás dela, e mirar a origem
## enquadrava o ar na frente dele.
func _corpo() -> Vector3:
	var m = player.get("modelo_visual")
	return (m as Node3D).global_position if m is Node3D else player.global_position + Vector3.DOWN


## A cabeça que se VÊ. A malha `char1` não está no espaço dos ossos (girada
## 180° e descida 1 m): a pose do osso converte pela global da MALHA.
func _cabeca() -> Vector3:
	var sk := player.get_node_or_null("maycow_lopes_normal/Armature/Skeleton3D") as Skeleton3D
	var malha := player.get_node_or_null("maycow_lopes_normal/Armature/Skeleton3D/char1") as Node3D
	if sk and malha:
		for nome in ["Head", "head", "mixamorig_Head"]:
			var i := sk.find_bone(nome)
			if i >= 0:
				return malha.global_transform * sk.get_bone_global_pose(i).origin + Vector3.UP * 0.07
	return _corpo() + Vector3.UP * 1.62


func _acender_rosto(cabeca: Vector3) -> void:
	if not is_instance_valid(_luz_rosto):
		_luz_rosto = OmniLight3D.new()
		_luz_rosto.light_color = Color(0.78, 0.82, 1.0)
		_luz_rosto.omni_range = 2.6
		_luz_rosto.shadow_enabled = false
		cena.add_child(_luz_rosto)
	_luz_rosto.light_energy = 0.9
	_luz_rosto.global_position = cabeca + Vector3(1.1, 0.35, -0.6)


## Uma luz quente em cima da porta, só durante a cena: de noite, com roupa
## escura, a Dona Nice sumia contra o adro.
func _luz_da_porta() -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.66, 0.38)
	luz.light_energy = 1.4
	luz.omni_range = 10.0
	luz.shadow_enabled = true
	add_child(luz)
	luz.global_position = Vector3(PORTA.x - 1.2, _chao(Vector3(X_MURO, 0, PORTA.z)) + 3.2, PORTA.z)


func _apagar_rosto() -> void:
	if is_instance_valid(_luz_rosto):
		_luz_rosto.queue_free()


func _porta_em(altura: float) -> Vector3:
	return Vector3(PORTA.x, _chao(Vector3(X_MURO, 0, PORTA.z)) + altura, PORTA.z)


## O chão em (x, z). Do muro do adro em diante a colisão da igreja cobre tudo
## até 36 m de altura: o raio sai de 14 m — dentro dela, onde ela não pega —
## e acha o terreno embaixo.
func _chao(p: Vector3) -> float:
	var espaco := cena.get_world_3d().direct_space_state
	var c := PhysicsRayQueryParameters3D.create(Vector3(p.x, 14.0, p.z), Vector3(p.x, 0.0, p.z), 2)
	if is_instance_valid(player):
		c.exclude = [player.get_rid()]
	var r := espaco.intersect_ray(c)
	var y: float = r.position.y if r else 11.0
	# a soleira fica um pouco acima do adro
	if p.x > X_MURO:
		y += minf(p.x - X_MURO, 2.0) * 0.06
	return y


func _tocar_som(caminho: String, volume: float, tom: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var s := AudioStreamPlayer.new()
	s.stream = load(caminho)
	s.volume_db = volume
	s.pitch_scale = tom
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
