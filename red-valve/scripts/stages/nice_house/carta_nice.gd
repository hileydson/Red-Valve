extends Node3D

## A CARTA DA DONA NICE, em cima da laje do cômodo do ritual (Capítulo 2).
##
## É ela que conta ao Maycow quem a Dona Nice é: a quinta integrante dos
## Anti-Lopes, a única que ainda não atravessou, e o que ela pretende fazer
## (sacrificar um inocente). Pegar a carta:
##
##  1. abre a tela de leitura (`leitura_diario.gd`), página por página;
##  2. libera o arquivo "carta_da_dona_nice" na aba ARQUIVOS do menu;
##  3. conclui `CAP2_CARTA_NICE`, e o objetivo passa a ser confrontá-la na
##     igreja.
##
## Quem cria é a cena da casa (`casa_nice_interior.gd`), e só enquanto o
## evento não aconteceu: depois de lida, a carta é do Maycow (está no menu).

const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")
const LeituraDiario := preload("res://scripts/ui/leitura_diario.gd")
const MODELO := "res://scenes/stages/nice_house/carta_dona_nice.tscn"
const ARQUIVO := "carta_da_dona_nice"


func _ready() -> void:
	add_child((load(MODELO) as PackedScene).instantiate())

	# Área generosa: a laje fica no meio do círculo e a cápsula do jogador
	# (1,35 m) para longe do tampo.
	var area := Area3D.new()
	area.collision_layer = 0
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 2.4, 2.8)
	forma.shape = box
	area.add_child(forma)
	add_child(area)

	var selecao := ItemSelecionavel.new()
	add_child(selecao)
	selecao.configurar(self, area, "PROMPT_LER_CARTA")
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
	Eventos.concluir(Eventos.CAP2_CARTA_NICE)
	if Eventos.objetivo_atual() != "":
		GlobalUtils.mostrar_objetivo(tr(Eventos.objetivo_atual()), 40.0)
	queue_free()
