extends "res://scripts/stages/jimmy_house/gaveta_pistola.gd"

## A CHAVE RESERVA DA IGREJA, na gaveta do criado-mudo do quarto da Dona Nice
## (Capítulo 2).
##
## A mesma gaveta da pistola do Jimmy — o criado-mudo é o mesmo modelo da Poly
## Haven —, só que com a chave dentro: selecionar abre, a gaveta desliza pra
## fora e a chave fica no fundo, pegável como qualquer item de balcão. O id da
## chave é o mesmo de quando ela ficava em cima da cômoda
## (`casa_nice_chave_igreja`): save que já a pegou não a vê de novo.
##
## Quem cria é a cena da casa (`casa_nice_interior.gd`).

const GAVETA_NICE := "casa_nice_gaveta_aberta"
const CHAVE := "casa_nice_chave_igreja"
const MODELO_CHAVE := "res://assets/3d_model/objects/chave_igreja/chave_igreja.glb"


func _init() -> void:
	id_gaveta = GAVETA_NICE


## A chave deitada no fundo da gaveta, um pouco de lado.
func _por_itens() -> void:
	_item(CHAVE, "chave_igreja", 1, "PROMPT_TAKE_KEY", "PICKUP_CHAVE_IGREJA", "PICKUP_AMMO_AGAIN",
		MODELO_CHAVE, Transform3D(Basis().scaled(Vector3.ONE * 1.4), Vector3.ZERO),
		Vector3(0.02, FUNDO, -0.2), 0.5)
