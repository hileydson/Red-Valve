extends Node3D

## O DIÁRIO DO JIMMY, largado na mesa da sala (Capítulo 1).
##
## É a pista que manda o Maycow para a escola: o Jimmy conta a confusão em que
## se meteu (a seita, o amuleto que ele roubou e deu ao Maycow) e que saiu às
## pressas para buscar o Jonny. Pegar o diário:
##
##  1. abre a tela de leitura (`leitura_diario.gd`): o caderno atrás, a letra
##     do Jimmy na frente, página por página;
##  2. libera o arquivo "diario_do_jimmy" na aba ARQUIVOS do menu;
##  3. conclui o evento `CAP1_DIARIO_JIMMY` — é ele que destranca a escola —,
##     e o objetivo passa a ser ir à escola.
##
## Quem cria é a cena da casa (`casa_jimmy_interior.gd`), e só enquanto o
## evento não aconteceu: depois de lido, o diário é do Maycow (está no menu).

const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")
const LeituraDiario := preload("res://scripts/ui/leitura_diario.gd")
const MODELO := "res://assets/3d_model/polyhaven/binder_notebook/binder_notebook_1k.gltf"
const ARQUIVO := "diario_do_jimmy"
## O caderno de verdade tem uns 30 cm; o da Poly Haven é um fichário grande.
const LARGURA := 0.30

var _modelo: Node3D


## Põe o diário em cima de `mesa` (o nó da mobília): no meio do tampo, que é o
## topo da caixa das malhas dela.
func pousar_em(mesa: Node3D) -> void:
	var caixa := _caixa_global(mesa)
	global_position = Vector3(caixa.get_center().x, caixa.end.y + 0.005, caixa.get_center().z)
	rotation.y = deg_to_rad(-24.0)


func _ready() -> void:
	_modelo = (load(MODELO) as PackedScene).instantiate() as Node3D
	add_child(_modelo)
	var caixa := _caixa_global(_modelo)
	var maior := maxf(caixa.size.x, caixa.size.z)
	if maior > 0.0:
		_modelo.scale = Vector3.ONE * (LARGURA / maior)
	caixa = _caixa_global(_modelo)
	# apoiado pela base, centrado na origem deste nó
	_modelo.global_position += Vector3(global_position.x - caixa.get_center().x,
		global_position.y - caixa.position.y, global_position.z - caixa.get_center().z)

	# Área generosa: a mesa tem 1,4 m e a cápsula do jogador, 1,35 m — ele
	# nunca chega a menos de um metro do meio do tampo.
	var area := Area3D.new()
	area.collision_layer = 0
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.4, 3.2)
	forma.shape = box
	area.add_child(forma)
	add_child(area)

	var selecao := ItemSelecionavel.new()
	add_child(selecao)
	selecao.configurar(self, area, "PROMPT_LER_DIARIO")
	selecao.pegar.connect(_ler)


func _ler() -> void:
	# o prompt some antes da tela (tween nao anda com o jogo pausado)
	await get_tree().create_timer(0.55).timeout
	var tela = LeituraDiario.new()
	tela.arquivo = ARQUIVO
	tela.model_path = MODELO
	get_tree().root.add_child(tela)
	visible = false
	await tela.fechado

	if SaveManager.desbloquear_arquivo(ARQUIVO):
		GlobalUtils.show_new_file_message(ARQUIVO)
	Eventos.concluir(Eventos.CAP1_DIARIO_JIMMY)
	GlobalUtils.mostrar_objetivo(tr(Eventos.objetivo_atual()), 40.0)
	queue_free()


static func _caixa_global(no: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var c: AABB = mi.global_transform * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	if no is MeshInstance3D and primeira:
		caixa = (no as MeshInstance3D).global_transform * (no as MeshInstance3D).get_aabb()
	return caixa
