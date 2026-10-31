extends Node

## O PORTAL SELADO — o portal do fim de um inferno que só abre pagando iron
## rusks (Capítulo 4: o do inferno 4 e o do inferno 3, `Eventos.CUSTO_PORTAL`
## cada).
##
## Fica pendurado no portal (`portal_vortice.gd`) e o mantém `bloqueado`
## enquanto o `evento` não aconteceu. Chegando perto, pergunta (ou diz quanto
## falta); com rusks de sobra e o aceitar, cobra, conclui o evento (que grava)
## e o portal ACORDA — clarão roxo, vendaval, a tela treme — e daí em diante
## suga como qualquer outro. Pago uma vez, fica pago (o evento está no save).
##
##     var selo = PortalSelado.new()
##     selo.evento = Eventos.CAP4_PORTAL_INFERNO_4
##     portal.add_child(selo)
##
## Sem `class_name` (ver [[project-class-name-travado]]): preload deste script.

signal aberto

const SOM_ABRIR := "res://assets/sounds/episodios/portal_red_valve.mp3"
## Quanto tempo o portal leva acordando (o jogador fica parado olhando).
const DUR_ABRINDO := 2.2

## O evento que o pagamento conclui.
var evento: String = ""
## Quantos iron rusks custa (0 = `Eventos.CUSTO_PORTAL`).
var custo: int = 0
## A que distância (no chão) do centro do portal a pergunta aparece. 0 = a da
## captura do portal + 3 m: perto o bastante pra ser dele, longe o bastante pra
## não ser sugado no instante em que o selo cai.
var raio: float = 0.0

var _portal: Node3D
var _texto := ""
var _abrindo := false


func _ready() -> void:
	_portal = get_parent() as Node3D
	if custo <= 0:
		custo = Eventos.CUSTO_PORTAL
	if _portal == null or evento == "" or Eventos.feito(evento):
		queue_free()
		return
	_portal.set("bloqueado", true)


func _exit_tree() -> void:
	_perguntar("")


func _physics_process(_delta: float) -> void:
	if _abrindo:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or GlobalEvents.in_cutscene or get_tree().paused:
		_perguntar("")
		return
	var d := Vector2(player.global_position.x - _portal.global_position.x,
		player.global_position.z - _portal.global_position.z).length()
	var alcance := raio if raio > 0.0 else float(_portal.get("raio_captura")) + 3.0
	if d > alcance:
		_perguntar("")
		return
	var pode_pagar := SaveManager.iron_rusks >= custo
	if pode_pagar:
		_perguntar(tr("PROMPT_PORTAL_SELADO") % custo)
		if Input.is_action_just_pressed("ui_accept"):
			_abrir(player)
	else:
		_perguntar(tr("AVISO_PORTAL_SEM_RUSKS") % [custo, SaveManager.iron_rusks])


func _perguntar(texto: String) -> void:
	if texto == _texto:
		return
	_texto = texto
	if texto != "":
		GlobalUtils.show_center_message("portal_selado", texto, 16)
	else:
		GlobalUtils.hide_center_message("portal_selado")


func _abrir(player: CharacterBody3D) -> void:
	_abrindo = true
	_perguntar("")
	if not SaveManager.gastar_iron_rusks(custo):
		_abrindo = false
		return
	Eventos.concluir(evento)
	if player.has_method("cutscene_set_player_control"):
		player.cutscene_set_player_control(false)
	player.velocity = Vector3.ZERO
	_clarao()
	var som := AudioStreamPlayer.new()
	som.stream = load(SOM_ABRIR)
	som.volume_db = 2.0
	add_child(som)
	som.play()
	GlobalUtils.vibrate_controller(null, 0.8, 0.8, 1.2)
	if _portal.has_method("_soprar"):
		_portal.call("_soprar", DUR_ABRINDO + 1.0)
	GlobalUtils.show_center_message("portal_aberto", tr("AVISO_PORTAL_ABERTO"), 18, 3.0)
	await get_tree().create_timer(DUR_ABRINDO, false).timeout
	if not is_instance_valid(_portal):
		return
	if is_instance_valid(player) and player.has_method("cutscene_set_player_control"):
		player.cutscene_set_player_control(true)
	# daqui em diante é um portal como os outros: quem estiver dentro do raio
	# é sugado já, quem estiver na beira entra andando
	_portal.set("bloqueado", false)
	aberto.emit()
	# o som termina sozinho: solta ele no portal antes de sair
	remove_child(som)
	_portal.add_child(som)
	som.finished.connect(som.queue_free)
	queue_free()


## O clarão roxo do selo quebrando (a cor das linhas da viagem).
func _clarao() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 90
	get_tree().current_scene.add_child(camada)
	var tela := ColorRect.new()
	tela.color = Color(0.62, 0.3, 1.0, 0.0)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(tela)
	var t := camada.create_tween()
	t.tween_property(tela, "color:a", 0.55, 0.18)
	t.tween_property(tela, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_callback(camada.queue_free)
