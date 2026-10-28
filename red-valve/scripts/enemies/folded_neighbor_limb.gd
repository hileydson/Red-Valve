extends Area3D

## Caixa de acerto de UM membro do Unknown Neighbor.
##
## Mesma ideia do `head.gd` (o "heart" dos outros inimigos): uma Area3D na
## camada 4, que e' onde o raycast da arma do jogador procura, com um
## `take_damage` que repassa pro corpo. A diferenca e' que aqui ela repassa
## TAMBEM de onde veio o tiro — e e isso que permite arrancar aquele membro
## especifico em vez de so tirar vida.
##
## Ela nao existe sozinha: quem cria, posiciona (via BoneAttachment3D no osso
## correspondente) e apaga quando o membro cai e' o `folded_neighbor.gd`.

## Nome do membro ("braco_r", "mao_l", "perna_r", "cabeca"...).
var membro: String = ""
## Multiplicador de dano deste ponto. A cabeca vale mais, como em qualquer
## lugar; os membros valem um pouco menos que o tronco, porque a recompensa
## deles nao e' o dano, e' arrancar a peca.
var multiplicador: float = 1.0

var dono: Node = null


func take_damage(quanto) -> void:
	if not is_instance_valid(dono) or not dono.has_method("dano_no_membro"):
		return
	dono.dano_no_membro(membro, int(round(float(quanto) * multiplicador)))
