extends Node3D

## ITEM LARGADO EM CIMA DO BALCAO.
##
## O caminho e' o mesmo da lanterna no chao da igreja (ver
## `igreja_interior.gd`): o objeto esta' na cena, uma Area3D em volta acende o
## prompt, o `ui_accept` poe o item no inventario, salva, e a tela
## `item_obtido.tscn` mostra o modelo 3D girando no meio da tela.
##
## A diferenca e' que ali aquilo esta' escrito dentro do script da CENA, e aqui
## sao varios objetos no mesmo balcao (a pistola de um lado, duas caixas de bala
## do outro). Entao vira um script de NO', igual ao que a porta e o elevador do
## hospital ja' fazem, e o que muda de um pro outro vem por metadata do gerador:
##
##     id          identidade DESTE objeto no cenario ("hospital_municao_1")
##     item        id no item_db do SaveManager
##     quantidade  quantas unidades (a municao e' empilhavel)
##     prompt      chave de traducao do "Pegar X?"
##     texto       chave de traducao da tela de item obtido
##     repetido    chave de traducao do aviso curto, da segunda vez em diante
##
## O modelo mostrado na tela sai do proprio item_db (`model_path`), e nao de mais
## uma metadata: e' o mesmo modelo que o menu ja' usa pra inspecionar o item.
##
## ==========================================================================
## "JA' PEGUEI" E' POR OBJETO, NAO POR ITEM
##
## A lanterna da igreja podia perguntar "ja' tenho lanterna?", porque lanterna
## so' existe uma. Bala nao: quem tem 25 ainda pode pegar mais 25, e a segunda
## caixa do balcao sumiria assim que a primeira fosse recolhida.
##
## Por isso cada objeto tem `id` proprio e o SaveManager guarda a lista dos que
## ja' foram recolhidos. A checagem por inventario continua valendo SO' pra item
## unico — e' ela que deixa um save antigo, que ja' tenha a arma, chegar aqui com
## o balcao vazio.
##
## E a TELA de item obtido (o modelo 3D girando no meio da tela, com o jogo
## parado) so' aparece na PRIMEIRA vez que aquele item entra no inventario. Da'
## segunda em diante e' so' um aviso curto no meio da tela: parar o jogo inteiro
## pra apresentar a mesma caixa de bala pela quinta vez seria castigo.

## Quanto o prompt some antes da tela abrir.
##
## `hide_center_message` apaga por tween, e tween NAO anda com a arvore pausada
## (a tela de item obtido pausa o jogo). Sem esta espera o "Pegar a pistola?"
## fica congelado atras do modelo 3D ate' o jogador fechar a tela.
const ESPERA_PROMPT_SUMIR := 0.55

const CENA_ITEM_OBTIDO := "res://scenes/ui/item_obtido.tscn"

## Quanto tempo o aviso curto (da segunda vez em diante) fica na tela.
const TEMPO_AVISO_REPETIDO := 2.2

var _player_perto: bool = false
var _pegando: bool = false


func _ready() -> void:
	if _ja_foi_recolhido():
		queue_free()
		return

	var area := get_node_or_null("area") as Area3D
	if area == null:
		push_warning("item_de_balcao: %s sem Area3D 'area' — nao da' pra pegar" % name)
		return
	if not area.body_entered.is_connected(_ao_entrar):
		area.body_entered.connect(_ao_entrar)
	if not area.body_exited.is_connected(_ao_sair):
		area.body_exited.connect(_ao_sair)


func _process(_delta: float) -> void:
	if _pegando or not _player_perto:
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene:
		return
	if Input.is_action_just_pressed("ui_accept"):
		_pegar()


func _id_do_item() -> String:
	return String(get_meta("item", ""))


## Identidade DESTE objeto no cenario. Sem metadata, cai no nome do no' — que no
## hospital ja' e' unico.
func _id_do_pickup() -> String:
	return String(get_meta("id", name))


func _empilhavel() -> bool:
	var info: Dictionary = SaveManager.item_db.get(_id_do_item(), {})
	return bool(info.get("stackable", false))


func _ja_foi_recolhido() -> bool:
	if SaveManager.pickup_ja_pego(_id_do_pickup()):
		return true
	# Item unico: ter e' o bastante. E' o que faz um save antigo, que ja' tenha a
	# pistola, chegar aqui com o balcao vazio.
	return not _empilhavel() and SaveManager.tem_item(_id_do_item())


func _ao_entrar(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_perto = true
	GlobalUtils.show_center_message(_chave_mensagem(),
		tr(String(get_meta("prompt", ""))), 16)


func _ao_sair(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_perto = false
	GlobalUtils.hide_center_message(_chave_mensagem())


## Id da mensagem central. Tem de ser diferente por objeto, senao a municao
## apagaria o prompt da pistola ao sair de perto dela.
func _chave_mensagem() -> String:
	return "pegar_" + name


func _pegar() -> void:
	_pegando = true
	_player_perto = false
	GlobalUtils.hide_center_message(_chave_mensagem())

	var id := _id_do_item()
	var quantidade := int(get_meta("quantidade", 1))
	# A pergunta tem de ser feita ANTES de somar: e' ela que decide se esta e' a
	# primeira vez que este item entra no inventario.
	var primeira_vez := not SaveManager.tem_item(id)

	SaveManager.add_item(id, quantidade)
	SaveManager.marcar_pickup(_id_do_pickup())
	SaveManager.save_game()

	# O contador de balas do canto da tela e' reescrito sob encomenda, nao todo
	# quadro: sem este aviso ele so' mudava no proximo tiro ou recarga, e pegar
	# 25 balas parecia nao ter feito nada.
	get_tree().call_group("player", "update_ammo_ui")

	# O objeto some do balcao ANTES da tela abrir: a tela e' o "voce pegou", e
	# fechar ela com a arma ainda deitada na mesa desmente a propria tela.
	visible = false
	set_process(false)

	if not primeira_vez:
		_avisar_de_novo(id, quantidade)
		queue_free()
		return

	await get_tree().create_timer(ESPERA_PROMPT_SUMIR).timeout
	if not is_inside_tree():
		return

	var info: Dictionary = SaveManager.item_db.get(id, {})
	var tela: CanvasLayer = load(CENA_ITEM_OBTIDO).instantiate()
	tela.model_path = String(info.get("model_path", ""))
	tela.texto = tr(String(get_meta("texto", "")))
	get_tree().root.add_child(tela)
	await tela.fechado

	queue_free()


## Da' segunda vez em diante: so' um aviso curto, sem parar o jogo.
func _avisar_de_novo(id: String, quantidade: int) -> void:
	var chave := String(get_meta("repetido", ""))
	if chave == "":
		return
	var nome := tr(String(SaveManager.item_db.get(id, {}).get("name_key", "")))
	GlobalUtils.show_center_message("pegou_" + id,
		tr(chave) % [quantidade, nome], 18, TEMPO_AVISO_REPETIDO)


func _eh_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player"
