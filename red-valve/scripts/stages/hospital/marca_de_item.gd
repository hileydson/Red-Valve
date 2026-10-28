extends Node3D

## O INDICADOR DE ITEM DE CENARIO (estilo RE2 Remake).
##
## De perto o item ja' se anuncia (realce e prompt do `item_de_balcao.gd`), mas
## uma caixa de bala ou uma seringa numa mesa escura some no cenario. Este
## indicador e' um circulo branco com miolo escuro e uma seta pra baixo, logo
## acima do item, que vai aparecendo (fade) conforme o jogador chega perto e
## some conforme ele se afasta.
##
## E' desenhado em 2D, numa CanvasLayer ACIMA do filtro de tela (PS1, chuva,
## calor): passando pelo filtro ele saia serrilhado e tremido. Por ser 2D, quem
## o esconde atras de parede e' um raio — lancado DO indicador PRA camera, de
## proposito: a colisao dos moveis do hospital e' bem mais alta que o balcao, e
## um raio que nasce dentro dela nao a acerta (de fora pra dentro escondia todos).
##
## Quem usa: `item_de_balcao.gd` e `item_selecionavel.gd` — os dois caminhos por
## onde passa todo item que se pega do cenario.
##
##     var marca := MarcaDeItem.new()
##     marca.dono = objeto
##     marca.malhas = malhas_do_realce
##     objeto.add_child(marca)

## Altura (m) do indicador acima do topo do item.
const ACIMA := 0.14
## Distancia (m) em que comeca a aparecer e em que ja' esta' inteiro.
const APARECE_EM := 6.0
const INTEIRO_EM := 3.5
## Velocidade do fade de entrar/sair de tras de parede (1/s).
const FADE := 5.0
## Raio na tela, em fracao da altura (0.0115 ~ 12 px num 1080p).
const RAIO_TELA := 0.0115
## Dois indicadores mais perto que isto (em raios) viram um so': num balcao com
## cinco itens o RE2 mostra um circulo, nao uma fileira deles empilhados.
const JUNTA_EM_RAIOS := 2.4
## Acima do filtro de tela (1), do calor (10) e da chuva (50); abaixo das
## cutscenes (80/90) e do minimapa (100).
const CAMADA := 55

static var _todas: Array = []

## O item: o indicador fica acima das malhas dele e some junto.
var dono: Node3D = null
## As malhas do item (as mesmas do realce), pra achar onde ele esta'.
var malhas: Array = []
## Falso enquanto nao ha' o que pegar (municao esperando reaparecer).
var ativa: bool = true

var _topo_local := Vector3.ZERO
var _alfa := 0.0
var _tapado := false
var _excluir: Array[RID] = []
## Quer aparecer neste quadro (ativo, na frente da camera, no alcance)...
var _candidata := false
## ...e onde cai na tela.
var _na_tela := Vector2.ZERO
var _desenho: Control = null


func _ready() -> void:
	if dono == null:
		dono = get_parent() as Node3D
	# A posicao e' refeita a cada quadro a partir do dono.
	top_level = true
	var camada := CanvasLayer.new()
	camada.layer = CAMADA
	add_child(camada)
	_desenho = Control.new()
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.draw.connect(_desenhar)
	_desenho.visible = false
	camada.add_child(_desenho)
	_medir_o_topo()
	_recolher_colisoes(dono)


func _enter_tree() -> void:
	_todas.append(self)


func _exit_tree() -> void:
	_todas.erase(self)


func _process(delta: float) -> void:
	if not is_instance_valid(dono):
		queue_free()
		return
	global_position = dono.global_transform * _topo_local + Vector3.UP * ACIMA
	var perto := 0.0
	var cam := get_viewport().get_camera_3d()
	_candidata = ativa and cam != null and not cam.is_position_behind(global_position) \
		and not (GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene)
	if _candidata:
		# Perto do MAYCOW, nao da camera (que fica 2 m atras dele).
		var jogador := get_tree().get_first_node_in_group("player") as Node3D
		var de := jogador.global_position if jogador else cam.global_position
		var dist := de.distance_to(global_position)
		perto = 1.0 - smoothstep(INTEIRO_EM, APARECE_EM, dist)
		_candidata = perto > 0.0
		_na_tela = cam.unproject_position(global_position)
	# A distancia manda direto no alfa (o fade de chegar/sair e' o proprio
	# andar); parede e vizinha entram e saem com fade de tempo.
	var escondida := _tapado or (_candidata and _cede_a_vizinha())
	_alfa = move_toward(_alfa, 0.0 if escondida else 1.0, delta * FADE)
	var a := _alfa * perto
	_desenho.visible = a > 0.005
	if _desenho.visible:
		_desenho.position = _na_tela
		_desenho.modulate.a = a
		_desenho.queue_redraw()


func _physics_process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if not _candidata or cam == null:
		return
	var de := global_position
	var ate := cam.global_position
	var dist := de.distance_to(ate)
	if dist < 0.6:
		_tapado = false
		return
	# Para antes da camera: a mola da camera de 3a pessoa encosta em parede.
	var q := PhysicsRayQueryParameters3D.create(de, de.lerp(ate, (dist - 0.3) / dist))
	q.hit_back_faces = false
	q.exclude = _excluir_com_jogador()
	_tapado = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _desenhar() -> void:
	var r := RAIO_TELA * get_viewport().get_visible_rect().size.y
	var branco := Color(1, 1, 1)
	_desenho.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.45))
	_desenho.draw_arc(Vector2.ZERO, r - r * 0.09, 0.0, TAU, 48, branco, r * 0.16, true)
	var seta := PackedVector2Array([Vector2(-0.36, -0.12) * r, Vector2(0.0, 0.22) * r,
		Vector2(0.36, -0.12) * r])
	_desenho.draw_polyline(seta, branco, r * 0.17, true)


## Uma vizinha na tela (a mais antiga do grupo) mostra o indicador por esta.
func _cede_a_vizinha() -> bool:
	var junta := RAIO_TELA * get_viewport().get_visible_rect().size.y * JUNTA_EM_RAIOS
	var meu := get_instance_id()
	for outra in _todas:
		if outra == self or not outra._candidata or outra._tapado \
				or outra.get_instance_id() > meu:
			continue
		if outra._na_tela.distance_to(_na_tela) < junta:
			return true
	return false


## O topo e' o alto da caixa das malhas, no meio dela, no espaco do dono: se o
## item for movido depois (a seringa da igreja desce por raycast), o indicador
## vai junto.
func _medir_o_topo() -> void:
	if not is_instance_valid(dono):
		return
	var inv := dono.global_transform.affine_inverse()
	var caixa := AABB()
	var tem := false
	for m in malhas:
		if not (m is MeshInstance3D) or not is_instance_valid(m) or m.mesh == null:
			continue
		var a: AABB = (inv * m.global_transform) * m.get_aabb()
		caixa = a if not tem else caixa.merge(a)
		tem = true
	if not tem:
		return
	var centro := caixa.get_center()
	_topo_local = Vector3(centro.x, caixa.end.y, centro.z)


## A colisao do proprio item nao conta como obstaculo.
func _recolher_colisoes(no: Node) -> void:
	if no is CollisionObject3D:
		_excluir.append(no.get_rid())
	for f in no.get_children():
		_recolher_colisoes(f)


func _excluir_com_jogador() -> Array[RID]:
	var lista := _excluir.duplicate()
	var p := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if p:
		lista.append(p.get_rid())
	return lista
