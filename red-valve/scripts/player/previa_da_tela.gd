@tool
extends Camera3D

## A CAMERA QUE SO' EXISTE NO EDITOR, PRA ANIMAR VENDO O QUE O JOGADOR VE.
##
## Abrir `mao_armada.tscn` mostra o rig cru: as maos apontam pra origem da
## cena (que em jogo E' o olho), entao de qualquer angulo do editor elas
## aparecem tortas, de lado ou de cabeca pra baixo. Nao ha' nada errado com o
## rig — falta so' olhar do lugar certo.
##
## Este no' e' esse lugar. Aperte "Prever" nele e o quadro e' o do jogo,
## inclusive o `AJUSTE` do F9: como o enquadramento e' um giro e um
## deslocamento aplicados AO CONJUNTO em espaco de camera, ver a mesma coisa
## de fora e' so' pousar a camera na transformacao INVERSA — a pose de
## repouso do rig cancela dos dois lados da conta.
##
## Em jogo ele some: `maos_fp_armas.gd` o apaga no `_ready`, junto com a
## previa da cacadeira.

const ARMAS := preload("res://scripts/player/maos_fp_armas.gd")

## Qual enquadramento mostrar. Troque pra `pistol` pra animar os clipes dela.
@export_enum("shotgun", "pistol") var arma := "shotgun":
	set(v):
		arma = v
		_pousar()

func _ready() -> void:
	_pousar()

func _pousar() -> void:
	if not Engine.is_editor_hint():
		return
	var a: Dictionary = ARMAS.AJUSTE.get(arma, {})
	var giro: Vector3 = a.get("giro", Vector3.ZERO)
	var tela: Vector3 = a.get("tela", Vector3.ZERO)
	var g := Basis.from_euler(Vector3(deg_to_rad(giro.x), deg_to_rad(giro.y),
		deg_to_rad(giro.z)))
	# O +Z da camera aponta pra TRAS; "pra frente" na tela e' o -Z dela.
	var d := Vector3(tela.x, tela.y, -tela.z) * 0.01
	var t := Transform3D(g, d).affine_inverse()
	# O "tamanho" engorda o conjunto em volta da origem — que e' o olho. Olhar
	# um rig 206% maior de onde o olho esta' e' o mesmo que olhar o rig normal
	# de 1/2,06 da distancia; a camera nao usa escala, entao entra aqui.
	var tam: float = maxf(float(a.get("tamanho", 100.0)), 10.0) / 100.0
	t.origin /= tam
	transform = t
