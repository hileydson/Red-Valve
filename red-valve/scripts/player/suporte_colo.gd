extends Node3D

## Onde o Jonny se apoia no corpo do Maycow do JOGADOR: responde
## `posicao_do_osso` como um AtorIgreja, pra o `seguir` do Jonny funcionar com o
## player igual funciona com o duble das cutscenes.
##
## Fica PENDURADO NA MALHA `char1`, nao no esqueleto: no player.tscn a malha e'
## girada 180 graus e descida ~1 m em relacao aos ossos, e a mao que se ve' na
## tela esta' no espaco da malha (ver memoria "char1 nao esta' no espaco dos
## ossos"). O +Z daqui e' a frente do corpo visivel.

var esqueleto: Skeleton3D


func posicao_do_osso(osso: String) -> Vector3:
	if esqueleto == null:
		return global_position
	var i := esqueleto.find_bone(osso)
	if i < 0:
		return global_position
	var malha := get_parent() as Node3D
	return malha.global_transform * esqueleto.get_bone_global_pose(i).origin
