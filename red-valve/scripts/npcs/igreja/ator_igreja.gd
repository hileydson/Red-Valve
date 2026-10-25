@tool
extends Node3D
class_name AtorIgreja

## Um personagem da cena da igreja: o modelo rigado (`modelo`, instancia do
## .glb) + um AnimationPlayer (`anim`) que toca os clipes da biblioteca
## `<personagem>_clipes.tres` — a que da' pra abrir e editar no editor.
##
## O .glb tem o proprio AnimationPlayer, com os mesmos clipes IMPORTADOS. Ele
## fica parado: quem anima e' o `anim` daqui (root_node = ../modelo, por isso
## as trilhas "dona_nice_rig/Skeleton3D:hips" do .tres batem).
##
## Os clipes vem do Blender (`tools/blender/igreja_dona_nice/`) e do
## extrator (`tools/igreja/extrair_clipes.tscn`). Depois de extraidos, a
## fonte e' o .tres.
##
## A pele: no jogo, todo material do modelo vira o `carne_igreja.gdshader`,
## que faz o que o material do .glb fazia e mais dissolver/sangue/veias. Os
## tres sao propriedades AQUI, animaveis por trilha no AnimationPlayer do
## diretor da cena. No editor a troca nao acontece (gravaria os materiais na
## cena ao salvar); o que se ve' no editor e' o .glb puro.

const SHADER_CARNE := preload("res://shaders/npcs/carne_igreja.gdshader")

## Clipe que comeca tocando quando a cena abre (vazio = nenhum).
@export var clipe_inicial: StringName = &""

@export_group("Pele")
## 0 = inteira, 1 = sumiu. Anime isto pra transformar uma na outra.
@export_range(0.0, 1.0) var dissolver: float = 0.0:
	set(v):
		dissolver = v
		_parametro("dissolver", v)
## Quanto sangue por cima da textura.
@export_range(0.0, 1.0) var sangue: float = 0.0:
	set(v):
		sangue = v
		_parametro("sangue", v)
## Veias escuras pulsando (a possessao).
@export_range(0.0, 1.0) var veias: float = 0.0:
	set(v):
		veias = v
		_parametro("veias", v)
@export var cor_borda: Color = Color(1.0, 0.28, 0.06):
	set(v):
		cor_borda = v
		_parametro("cor_borda", v)
## Tamanho da mancha do dissolver (maior = manchas menores). Personagem grande
## (a fase 2 tem 5 m) pede numero menor, senao a borda vira chuvisco.
@export var escala_ruido: float = 5.0

@export_group("Deitado no chao")
## Os clipes de deitado (o `deitado` e o `caido_agonia` do Jonny) vem do
## Blender apoiados num ponto so' — a canela — e o resto do corpo flutua uns
## centimetros. Este giro (graus, em X e Z, em volta da origem do ator) e esta
## descida (metros) assentam costas, cabeca e quadril no chao; ver `no_chao`.
## Medidos na pele (o menor vao de cada parte do corpo ate' o chao).
@export var deitado_giro: Vector3 = Vector3.ZERO
@export var deitado_altura: float = 0.0

@export_group("Seguir as maos de outro ator")
## O ator que carrega este (o Jonny no colo do Maycow). Vazio = nao segue.
@export var seguir: NodePath
## 0 = fica onde a cena o pos; 1 = preso entre as maos do outro. Anime isto
## pra o corpo sair do chao e ir pro colo. No meio ele ja' sobe JUNTO com as
## maos (do jeito que estava encostado nelas quando o peso saiu do zero) e
## vai se acomodando no colo — nunca fica parado no ar com as maos subindo.
@export_range(0.0, 1.0) var seguir_peso: float = 0.0:
	set(v):
		if seguir_peso <= 0.0 and v > 0.0:
			_base_seguir = global_transform if is_inside_tree() else transform
			_prender_base = true
		seguir_peso = v
## Deslocamento do ponto entre as maos, no espaco de quem carrega (+Z = frente dele).
@export var seguir_offset: Vector3 = Vector3(0.0, 0.04, 0.06)
## Giro em Y, em graus, em relacao a quem carrega (o Jonny atravessado: 90).
@export var seguir_giro_y: float = 90.0
## Os dois ossos das maos de quem carrega.
@export var osso_mao_direita: String = "RightHand"
@export var osso_mao_esquerda: String = "LeftHand"

var _materiais: Array[ShaderMaterial] = []
var _base_seguir := Transform3D.IDENTITY
## A base vira relativa as maos no primeiro quadro com peso (as maos so' sao
## lidas no `_process`).
var _prender_base := false

@onready var anim: AnimationPlayer = get_node_or_null("anim")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_trocar_materiais()
	if clipe_inicial != &"" and anim and anim.has_animation(clipe_inicial):
		anim.play(clipe_inicial)
	visibility_changed.connect(_sons_do_corpo)
	_sons_do_corpo()


## Os sons em laco do proprio ator (a respiracao do Jonny) param quando ele
## some de cena e voltam quando ele aparece.
func _sons_do_corpo() -> void:
	for som in find_children("*", "AudioStreamPlayer3D", false, false):
		(som as AudioStreamPlayer3D).stream_paused = not is_visible_in_tree()


func _process(_delta: float) -> void:
	if seguir_peso <= 0.0 or seguir.is_empty():
		return
	var outro := get_node_or_null(seguir) as Node3D
	if outro == null or not outro.has_method("posicao_do_osso"):
		return
	var alvo := alvo_nas_maos(outro)
	if _prender_base:
		_base_seguir = alvo.affine_inverse() * _base_seguir
		_prender_base = false
	global_transform = (alvo * _base_seguir).interpolate_with(alvo, seguir_peso) \
		if seguir_peso < 1.0 else alvo


## Onde este ator fica no colo de `outro`: entre as maos dele, com o
## deslocamento e o giro de `seguir_*`. Publico porque o colo do jogador
## (`player_carregar_jonny.gd`) chama isto no MESMO quadro em que move as
## maos, em vez de depender da ordem dos `_process`.
func alvo_nas_maos(outro: Node3D) -> Transform3D:
	var md: Vector3 = outro.posicao_do_osso(osso_mao_direita)
	var me: Vector3 = outro.posicao_do_osso(osso_mao_esquerda)
	var base := outro.global_basis.orthonormalized()
	var b := base * Basis(Vector3.UP, deg_to_rad(seguir_giro_y))
	return Transform3D(b, (md + me) * 0.5 + base * seguir_offset)


## Onde o ator fica deitado com a origem em `base` (no chao, de pe'): a base
## com o giro e a descida de `deitado_*`.
func no_chao(base: Transform3D) -> Transform3D:
	var giro := Basis.from_euler(Vector3(deg_to_rad(deitado_giro.x), deg_to_rad(deitado_giro.y),
		deg_to_rad(deitado_giro.z)))
	return base * Transform3D(giro, Vector3(0.0, deitado_altura, 0.0))


## Toca um clipe com mistura (segundos) a partir do que estiver tocando.
func tocar(clipe: StringName, mistura: float = 0.25, velocidade: float = 1.0) -> void:
	if anim == null or not anim.has_animation(clipe):
		push_warning("%s: sem o clipe %s" % [name, clipe])
		return
	anim.play(clipe, mistura, velocidade)


func esqueleto() -> Skeleton3D:
	return find_child("Skeleton3D", true, false) as Skeleton3D


## Posicao de mundo de um osso (a mao com a faca, a cabeca pra mira...).
func posicao_do_osso(osso: String) -> Vector3:
	var sk := esqueleto()
	if sk == null:
		return global_position
	var i := sk.find_bone(osso)
	if i < 0:
		return global_position
	return sk.global_transform * sk.get_bone_global_pose(i).origin


func _trocar_materiais() -> void:
	for malha in find_children("*", "MeshInstance3D", true, false):
		var mi := malha as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var original := mi.get_active_material(s)
			var novo := ShaderMaterial.new()
			novo.shader = SHADER_CARNE
			if original is BaseMaterial3D:
				var b := original as BaseMaterial3D
				novo.set_shader_parameter("albedo_cor", b.albedo_color)
				if b.albedo_texture:
					novo.set_shader_parameter("albedo_tex", b.albedo_texture)
				if b.normal_enabled and b.normal_texture:
					novo.set_shader_parameter("tem_normal", true)
					novo.set_shader_parameter("normal_tex", b.normal_texture)
					novo.set_shader_parameter("normal_forca", b.normal_scale)
				if b.roughness_texture:
					novo.set_shader_parameter("tem_orm", true)
					novo.set_shader_parameter("orm_tex", b.roughness_texture)
				novo.set_shader_parameter("rugosidade", b.roughness)
				novo.set_shader_parameter("metalico", b.metallic)
			novo.set_shader_parameter("escala_ruido", escala_ruido)
			mi.set_surface_override_material(s, novo)
			_materiais.append(novo)
	_parametro("dissolver", dissolver)
	_parametro("sangue", sangue)
	_parametro("veias", veias)
	_parametro("cor_borda", cor_borda)


func _parametro(nome: String, valor) -> void:
	for m in _materiais:
		m.set_shader_parameter(nome, valor)
