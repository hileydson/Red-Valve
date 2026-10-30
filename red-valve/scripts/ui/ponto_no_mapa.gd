extends Node

## Um ponto VIVO no mapa: marca onde o no' pai (um Node3D) esta' — hoje, o
## Jonny deixado no chao do hospital.
##
## Os pontos fixos vem do JSON de cada planta; estes entram por cima, achados
## pelo grupo "ponto_no_mapa" (`MapaDados.pontos_vivos`). Entrar e sair da
## arvore avisa o minimapa, que refaz os marcadores na hora; a aba MAPA do menu
## monta os dela toda vez que abre.

## Chave de traducao do rotulo (a aba MAPA escreve o nome; o minimapa nao).
@export var chave: String = ""
## Tipo do losango (a cor sai do COR_TIPO do minimapa e do painel).
@export var tipo: String = "pessoa"
## Aparece mesmo com a área ainda na névoa (a interrogação do calabouço: o mapa
## zera, mas o lugar pra onde ir tem de estar marcado).
@export var sempre_visivel: bool = false
## O pai ANDA (a enfermeira que leva o Maycow pelo hospital): de tempos em
## tempos o minimapa refaz os marcadores pra o ponto acompanhar. Os marcadores
## guardam a posição de quando nasceram — sem isto o "?" ficaria pra trás.
@export var segue_o_pai: bool = false

var _visto_em := Vector3.INF
var _relogio := 0.0


func _enter_tree() -> void:
	add_to_group("ponto_no_mapa")
	set_process(segue_o_pai)
	_avisar.call_deferred()


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = 0.2
	var p := (get_parent() as Node3D).global_position
	if p.distance_to(_visto_em) > 0.6:
		_visto_em = p
		_avisar()


func _exit_tree() -> void:
	remove_from_group("ponto_no_mapa")
	if is_inside_tree():
		get_tree().call_group("mapa_cidade", "atualizar_pontos_vivos")


func _avisar() -> void:
	if is_inside_tree():
		get_tree().call_group("mapa_cidade", "atualizar_pontos_vivos")


## O ponto no formato dos do JSON (mais a altura, que decide o andar).
func dados() -> Dictionary:
	var p := (get_parent() as Node3D).global_position
	return {"id": "vivo_%d" % get_instance_id(), "chave": chave, "tipo": tipo,
		"x": p.x, "z": p.z, "y": p.y, "sempre_visivel": sempre_visivel}
