extends Node3D

## ITEM LARGADO EM CIMA DO BALCAO.
##
## O caminho e' o mesmo da lanterna no chao da igreja (ver
## `igreja_interior.gd`): o objeto esta' na cena, uma Area3D em volta acende o
## prompt, o `ui_accept` poe o item no inventario, salva, e a tela
## `item_obtido.tscn` mostra o modelo 3D girando no meio da tela.
##
## A diferenca e' que ali aquilo esta' escrito dentro do script da CENA, e aqui
## sao varios objetos no mesmo balcao (a pistola e duas caixas de bala, lado a
## lado). Entao vira um script de NO', igual ao que a porta e o elevador do
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
##
## ==========================================================================
## QUAL DOS ITENS O JOGADOR ESTA' PEGANDO
##
## No balcao ha' mais de um objeto a menos de um metro um do outro, e a area de
## cada um alcanca o vizinho. Sem arbitro, os tres prompts apareciam juntos na
## tela e um unico "aceitar" disparava todos.
##
## Quem decide e' a MIRA: a cada quadro os itens que tem o jogador por perto sao
## projetados na tela, e vence o que estiver mais perto do centro dela. E' o
## criterio que o jogador ja' usa sem pensar — ele OLHA pro que quer pegar.
##
## Quem venceu fica com o prompt e com o realce forte; os outros ficam so' com
## um brilho fraco, que e' o que diz "aqui tem mais coisa". O realce sai do
## MESMO shader que o amuleto usa nos inimigos (`enemy_highlight.gdshader`),
## posto como `material_overlay`: nao troca o material do objeto, so' soma um
## contorno por cima.
##
## A escolha e' UMA SO' pra todos os itens, por isso mora em `static var`: o
## primeiro item que rodar no quadro arbitra por todos, e os demais so' leem o
## resultado.

## Quanto o prompt some antes da tela abrir.
##
## `hide_center_message` apaga por tween, e tween NAO anda com a arvore pausada
## (a tela de item obtido pausa o jogo). Sem esta espera o "Pegar a pistola?"
## fica congelado atras do modelo 3D ate' o jogador fechar a tela.
const ESPERA_PROMPT_SUMIR := 0.55

const CENA_ITEM_OBTIDO := "res://scenes/ui/item_obtido.tscn"

## Quanto tempo o aviso curto (da segunda vez em diante) fica na tela.
const TEMPO_AVISO_REPETIDO := 2.2

## Grupo de todo objeto controlado por este script. E' por ele que a arbitragem
## enxerga os vizinhos — sozinho, cada item so' saberia de si.
const GRUPO := "item_de_balcao"

const SHADER_REALCE := "res://shaders/effects/enemy_highlight.gdshader"

## Vantagem de quem JA' esta' escolhido, na disputa do quadro seguinte. Dois
## itens quase empatados no centro da tela trocavam de dono a cada quadro, e o
## prompt — que entra e sai por tween de meio segundo — piscava sem parar.
const VANTAGEM_DE_QUEM_ESTA := 0.82

## Altura, acima da origem do objeto, do ponto que o representa na tela. O
## modelo pousa NA origem do no' (o `apoio` do gerador e' de milimetros), entao
## meio palmo pra cima ja' cai no corpo da peca.
const ALTURA_DA_MIRA := 0.06

## Item escolhido agora e o quadro em que isso foi decidido. Valem pra todos os
## itens de uma vez.
static var _selecionado: Node = null
static var _quadro_arbitrado: int = -1
static var _mat_realce: ShaderMaterial = null
static var _mat_selecao: ShaderMaterial = null

var _player_perto: bool = false
var _pegando: bool = false
var _malhas: Array = []
var _prompt_ligado: bool = false
var _overlay_atual: ShaderMaterial = null


func _ready() -> void:
	if _ja_foi_recolhido():
		queue_free()
		return

	add_to_group(GRUPO)
	_malhas = _recolher_malhas(self)

	var area := get_node_or_null("area") as Area3D
	if area == null:
		push_warning("item_de_balcao: %s sem Area3D 'area' — nao da' pra pegar" % name)
		return
	if not area.body_entered.is_connected(_ao_entrar):
		area.body_entered.connect(_ao_entrar)
	if not area.body_exited.is_connected(_ao_sair):
		area.body_exited.connect(_ao_sair)


func _exit_tree() -> void:
	if _selecionado == self:
		_selecionado = null


func _process(_delta: float) -> void:
	_arbitrar(get_tree(), get_viewport().get_camera_3d())

	var escolhido: bool = _selecionado == self
	if escolhido:
		_pintar(_material_selecao())
	elif _disputando():
		_pintar(_material_realce())
	else:
		_pintar(null)
	_mostrar_prompt(escolhido)

	if escolhido and Input.is_action_just_pressed("ui_accept"):
		_pegar()


# ==========================================================================
# A DISPUTA
# ==========================================================================

## Roda UMA vez por quadro, no primeiro item que chegar aqui. Os outros caem no
## `return` de cima e leem `_selecionado` pronto.
static func _arbitrar(arvore: SceneTree, camera: Camera3D) -> void:
	if arvore == null:
		return
	var quadro := Engine.get_process_frames()
	if _quadro_arbitrado == quadro:
		return
	_quadro_arbitrado = quadro

	var melhor: Node = null
	var melhor_nota := INF

	for item in arvore.get_nodes_in_group(GRUPO):
		if not is_instance_valid(item) or not item.is_inside_tree():
			continue
		if not item._disputando():
			continue
		var nota: float = item._nota_de_mira(camera)
		# Quem ja' estava escolhido so' perde o lugar por uma margem folgada.
		if item == _selecionado:
			nota *= VANTAGEM_DE_QUEM_ESTA
		if nota < melhor_nota:
			melhor_nota = nota
			melhor = item

	_selecionado = melhor


## Este item esta' na disputa? Fora da area, ja' pego, escondido ou em cutscene,
## nao esta' — e ai' ninguem fica realcado nem com prompt.
func _disputando() -> bool:
	if _pegando or not _player_perto or not visible:
		return false
	return not (GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene)


## Distancia do item ao CENTRO DA TELA, em fracao da altura da janela. Quanto
## menor, mais o jogador esta' olhando pra ele.
##
## E' distancia de TELA, e nao angulo no mundo, porque e' a tela que o jogador
## ve': em terceira pessoa a camera fica atras do ombro e o centro dela e' o
## unico ponto de mira que existe.
func _nota_de_mira(camera: Camera3D) -> float:
	if camera == null:
		return INF
	var ponto := global_position + Vector3.UP * ALTURA_DA_MIRA
	# De costas pro balcao nao se pega nada.
	if camera.is_position_behind(ponto):
		return INF

	var tela := camera.unproject_position(ponto)
	var janela := Vector2(camera.get_viewport().get_visible_rect().size)
	if janela.y <= 0.0:
		return INF
	return tela.distance_to(janela * 0.5) / janela.y


# ==========================================================================
# O REALCE
# ==========================================================================

func _recolher_malhas(no: Node) -> Array:
	var achadas: Array = []
	if no is MeshInstance3D:
		achadas.append(no)
	for filho in no.get_children():
		achadas.append_array(_recolher_malhas(filho))
	return achadas


## Contorno forte, de quem esta' escolhido. Ambar: e' a cor de "objeto", e nao
## briga com o azul que o amuleto usa em inimigo.
static func _material_selecao() -> ShaderMaterial:
	if is_instance_valid(_mat_selecao):
		return _mat_selecao
	_mat_selecao = _novo_material(Color(1.0, 0.78, 0.32), 1.5, 0.22, 0.30)
	return _mat_selecao


## Contorno fraco, de quem so' esta' por perto: diz "tem mais coisa aqui" sem
## disputar a atencao com o item escolhido.
static func _material_realce() -> ShaderMaterial:
	if is_instance_valid(_mat_realce):
		return _mat_realce
	_mat_realce = _novo_material(Color(0.72, 0.76, 0.86), 0.55, 0.04, 0.0)
	return _mat_realce


static func _novo_material(cor: Color, intensidade: float, preenchimento: float,
		pulso: float) -> ShaderMaterial:
	var shader: Shader = load(SHADER_REALCE)
	if shader == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("rim_color", cor)
	mat.set_shader_parameter("rim_power", 2.0)
	mat.set_shader_parameter("rim_intensity", intensidade)
	mat.set_shader_parameter("fill_intensity", preenchimento)
	mat.set_shader_parameter("pulse_speed", 2.6)
	mat.set_shader_parameter("pulse_amount", pulso)
	return mat


## Troca o overlay das malhas deste objeto. `null` limpa.
##
## So' mexe em overlay que seja NOSSO (ou vazio): se a peca ja' tivesse um
## overlay proprio, sobrescrever aqui perderia ele pra sempre.
func _pintar(desejado: ShaderMaterial) -> void:
	if desejado == _overlay_atual:
		return
	_overlay_atual = desejado
	for m in _malhas:
		if not is_instance_valid(m):
			continue
		if not (m.material_overlay == null or m.material_overlay == _mat_realce
				or m.material_overlay == _mat_selecao):
			continue
		m.material_overlay = desejado


## O prompt so' e' mexido na VIRADA. `show_center_message` chamado todo quadro
## reescreve a label toda vez, e `hide_center_message` refaz o tween de saida —
## um prompt que nunca termina de sumir.
func _mostrar_prompt(ligado: bool) -> void:
	if ligado == _prompt_ligado:
		return
	_prompt_ligado = ligado
	if ligado:
		GlobalUtils.show_center_message(_chave_mensagem(),
			tr(String(get_meta("prompt", ""))), 16)
	else:
		GlobalUtils.hide_center_message(_chave_mensagem())


# ==========================================================================
# PEGAR
# ==========================================================================

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


func _ao_sair(body: Node3D) -> void:
	if not _eh_player(body):
		return
	_player_perto = false


## Id da mensagem central. Tem de ser diferente por objeto, senao a municao
## apagaria o prompt da pistola ao sair de perto dela.
func _chave_mensagem() -> String:
	return "pegar_" + name


func _pegar() -> void:
	_pegando = true
	_player_perto = false
	if _selecionado == self:
		_selecionado = null
	_pintar(null)
	_mostrar_prompt(false)

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
