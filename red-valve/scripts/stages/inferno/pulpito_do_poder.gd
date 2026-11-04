extends Node3D

## O PÚLPITO DE UM PODER DA COGBLADE.
##
## O mesmo altar de pedra do inferno 4 e do cemitério (as três pedras e as duas
## velas, com os materiais de lá) com uma chama da cor do poder flutuando em
## cima. Tocar a chama é a cena da aura do amuleto (`cutscene_aura_amuleto.gd`)
## com o evento e a cor deste poder; 2 s depois, a tela do poder novo e, de
## volta ao jogo, o objetivo de novo.
##
## Quem monta: o inferno 1 (Fire Cross, chama amarela, Capítulo 5) e o inferno
## 3 (Slain, chama branca, Capítulo 4). O nó desce sozinho até o chão (a
## colisão do cenário só existe depois do primeiro quadro de física):
##
##     var p = PulpitoDoPoder.new()
##     p.evento = Eventos.CAP5_PODER_FIRE_CROSS
##     p.poder = Eventos.PODER_FIRE_CROSS
##     p.cor = AuraDoAmuleto.AMARELO
##     p.cor_miolo = AuraDoAmuleto.DOURADO
##     p.prompt = "PROMPT_TOCAR_CHAMA_AMARELA"
##     add_child(p)
##     p.global_position = onde
##
## Sem `class_name` (ver [[project-class-name-travado]]): preload deste script.

const CutsceneAura := preload("res://scripts/stages/inferno_4/cutscene_aura_amuleto.gd")
const AuraDoAmuleto := preload("res://scripts/systems/aura_do_amuleto.gd")
const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")

const CENA_ITEM_OBTIDO := "res://scenes/ui/item_obtido.tscn"
const MAT_PEDRA := "res://assets/3d_model/stages/inferno_3/materiais/mat_pedra_clara.tres"
const MAT_VELA := "res://assets/3d_model/stages/inferno_3/materiais/mat_vela.tres"
const MAT_CHAMA := "res://assets/3d_model/stages/cemiterio/materiais/mat_chama.tres"
## A chama flutua 45 cm acima do tampo (1,12 m), como no inferno 4.
const ALTURA_DA_CHAMA := 1.57
const TAMANHO_DA_CHAMA := 0.16
const LAYER_CHAO := 2

## O evento que a chama conclui (e que libera o poder).
var evento: String = ""
## O id do poder (o nome dele na tela do poder novo).
var poder: String = ""
var cor: Color = AuraDoAmuleto.ROXO
var cor_miolo: Color = AuraDoAmuleto.LILAS
## A chave do CSV da pergunta de tocar a chama.
var prompt: String = "PROMPT_TAKE_AURA"
## Uma luz fraca de cima, pra achar o púlpito no escuro (o inferno 3).
var iluminado: bool = false
var luz_energia: float = 1.6

var _selecao: Node
var _chama: Node3D


func _ready() -> void:
	_montar()
	# a colisão do cenário só existe depois do primeiro quadro de física
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree():
		global_position.y = _chao(global_position)


func _montar() -> void:
	var pedra := load(MAT_PEDRA) as Material
	var vela := load(MAT_VELA) as Material
	# base, coluna e tampo (as três pedras do altar do inferno 4)
	for bloco in [[Vector3(2.2, 0.55, 1.4), -0.025], [Vector3(1.6, 0.75, 0.9), 0.625],
			[Vector3(2.0, 0.12, 1.2), 1.06]]:
		var mi := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = bloco[0]
		caixa.material = pedra
		mi.mesh = caixa
		add_child(mi)
		mi.position.y = float(bloco[1])
	for v in [[Vector3(-0.75, 1.12, -0.4), 0.2], [Vector3(0.8, 1.12, 0.35), 0.14]]:
		var mi := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.05
		cil.bottom_radius = 0.05
		cil.height = float(v[1])
		cil.radial_segments = 6
		cil.material = vela
		mi.mesh = cil
		add_child(mi)
		mi.position = v[0] + Vector3.UP * float(v[1]) * 0.5
		var fogo := MeshInstance3D.new()
		var ponta := CylinderMesh.new()
		ponta.top_radius = 0.002
		ponta.bottom_radius = 0.02
		ponta.height = 0.06
		ponta.radial_segments = 4
		ponta.material = load(MAT_CHAMA)
		fogo.mesh = ponta
		fogo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fogo)
		fogo.position = v[0] + Vector3.UP * (float(v[1]) + 0.03)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = LAYER_CHAO
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.2, 1.6, 1.4)
	forma.shape = bx
	corpo.add_child(forma)
	add_child(corpo)
	forma.position.y = 0.6
	# a seleção (o mesmo do altar do inferno 4: área folgada, a cápsula para longe)
	var area := Area3D.new()
	area.name = "area"
	area.collision_layer = 0
	area.monitorable = false
	var fa := CollisionShape3D.new()
	var ca := BoxShape3D.new()
	ca.size = Vector3(4.4, 2.6, 4.4)
	fa.shape = ca
	area.add_child(fa)
	add_child(area)
	area.position = Vector3(0.0, 0.8, 0.0)
	_selecao = ItemSelecionavel.new()
	add_child(_selecao)
	_selecao.configurar(self, area, prompt)
	_selecao.pegar.connect(_pegar_chama)
	# a chama entra DEPOIS do configurar (os quads não são malha pra contorno)
	_chama = AuraDoAmuleto.chama(TAMANHO_DA_CHAMA, cor, cor_miolo)
	add_child(_chama)
	_chama.position = Vector3.UP * ALTURA_DA_CHAMA
	if iluminado:
		# de cima e um pouco de frente: some na névoa a poucos metros, o
		# bastante pra chamar o olho sem virar holofote
		var luz := SpotLight3D.new()
		luz.name = "luz_do_pulpito"
		luz.light_color = Color(1.0, 0.95, 0.86)
		luz.light_energy = luz_energia
		luz.spot_range = 9.0
		luz.spot_angle = 30.0
		luz.spot_angle_attenuation = 0.6
		luz.spot_attenuation = 0.8
		luz.shadow_enabled = false
		add_child(luz)
		luz.position = Vector3(0.0, 5.2, 1.4)
		luz.look_at_from_position(luz.position, Vector3(0.0, 0.6, 0.0), Vector3.FORWARD)


func _pegar_chama() -> void:
	var dono := get_parent() as Node3D
	var player := dono.get_node_or_null("Player") as CharacterBody3D if dono else null
	if player == null or not is_instance_valid(_chama):
		if is_instance_valid(_selecao):
			_selecao.disponivel = true
		return
	var cena = CutsceneAura.new()
	cena.name = "cutscene_chama_" + poder
	cena.evento = evento
	cena.cor_aura = cor
	dono.add_child(cena)
	cena.rodar(dono, player, _chama)
	await cena.terminou
	if not Eventos.feito(evento):
		# a cena caiu no meio: a chama continua no púlpito, pra pegar de novo
		if is_instance_valid(_selecao):
			_selecao.disponivel = true
		return
	if is_instance_valid(_selecao):
		_selecao.queue_free()
	await get_tree().create_timer(2.0, false).timeout
	_mostrar_poder_novo()
	await get_tree().create_timer(1.0, false).timeout
	var chave := Eventos.objetivo_atual()
	if is_inside_tree() and chave != "":
		GlobalUtils.mostrar_objetivo(tr(chave), 30.0)


## A tela do poder novo: o amuleto com a aura da cor da chama e o nome do poder.
func _mostrar_poder_novo() -> void:
	var tela: CanvasLayer = load(CENA_ITEM_OBTIDO).instantiate()
	tela.model_path = AuraDoAmuleto.MODELO_AMULETO
	tela.aura = true
	tela.cor_aura = cor
	tela.texto = tr("PODER_NOVO_COGBLADE")
	tela.destaque = tr(Eventos.rotulo_poder(poder))
	tela.detalhe = tr("PODER_NOVO_USO_PAD" if GlobalEvents.usando_controle else "PODER_NOVO_USO_KEY")
	get_tree().root.add_child(tela)


func _chao(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 20.0, LAYER_CHAO)
	var meu: Array[RID] = []
	for corpo in find_children("*", "CollisionObject3D", true, false):
		meu.append((corpo as CollisionObject3D).get_rid())
	q.exclude = meu
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return float(r["position"].y) if r else p.y
