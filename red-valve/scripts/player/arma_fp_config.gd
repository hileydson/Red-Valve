@tool
extends Node3D

## Uma arma de primeira pessoa: modelo, pegadas e pontos de efeitos editaveis.
## O no inteiro aponta para -Z, com +Y para cima, em metros.
@export var item_id := "pistol"
@export var prefixo := "pistola"
@export var usa_apoio := false
## Curso do ferrolho em metros; animado pelo mesmo AnimationPlayer das maos.
@export_range(0.0, 0.08, 0.001) var recuo_ferrolho := 0.0

func _process(_delta: float) -> void:
	# O modelo importado usa outros eixos. So este adaptador conhece a conversao;
	# a animacao e o usuario trabalham no controle Articulacao, em eixos normais.
	var articulacao := get_node_or_null("Movimento/Articulacao") as Node3D
	var modelo := get_node_or_null("Movimento/Modelo")
	if modelo != null:
		var ferrolho := modelo.get_node_or_null("Ferrolho") as Node3D
		if ferrolho != null:
			ferrolho.position.x = recuo_ferrolho / maxf(modelo.scale.x, 0.001)
	if articulacao != null and modelo != null:
		var dobradica := modelo.find_child("charneira", true, false) as Node3D
		if dobradica != null:
			dobradica.rotation.z = -articulacao.rotation.x

func ponto(nome: String) -> Vector3:
	var marcador := find_child(nome, true, false) as Node3D
	return marcador.global_position if marcador != null else global_position
