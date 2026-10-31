extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A FLORESTA (Capítulo 3, a primeira vez que o Maycow chega no
## `floresta_local`).
##
## Começa no preto (a tela da cidade já escureceu). Ele aparece lá dentro,
## no meio das árvores, e anda devagar mata adentro enquanto a câmera o
## acompanha de lado, baixa, e vai passando pras costas dele — a cidade fica
## pra trás. No caminho ele se pergunta se aquele é mesmo o caminho do
## cemitério. No fim a tela volta pro jogo ali mesmo: ele está no meio da
## floresta, e a floresta não o deixa mais sair (`capitulo_3_cidade.gd`).
##
## A linha da caminhada é escolhida entre as árvores do scatter (as que agora
## têm tronco com colisão): a reta mais livre perto da direção do cemitério.

const ANDAR := 9.5
const COMPRIMENTO := 14.0
## [segundo da cena, chave, duração]
const FALAS := [
	[1.6, "CAP3_FLORESTA_MAYCOW_1", 3.0],
	[5.0, "CAP3_FLORESTA_MAYCOW_2", 3.4],
	[8.6, "CAP3_FLORESTA_MAYCOW_3", 3.0],
]

var _direcao := Vector3.FORWARD


func rodar(dono: Node3D, jogador: CharacterBody3D, inicio: Vector3, rumo: Vector3, arvores: Array) -> void:
	travar(dono, jogador, 52.0)
	_tela.modulate.a = 1.0
	_direcao = _rumo_livre(inicio, rumo, arvores)
	player.velocity = Vector3.ZERO
	player.global_position = inicio + Vector3.UP * 1.0
	player.global_rotation.y = atan2(-_direcao.x, -_direcao.z)
	if cena.has_method("_pousar_no_chao"):
		cena.call("_pousar_no_chao", player, inicio)
	await esperar(0.8)
	if not vale():
		return
	var lado := _direcao.cross(Vector3.UP).normalized()
	plantar(_cabeca() + lado * 3.0 - _direcao * 0.5 + Vector3.UP * 0.2, _cabeca())
	escurecer(0.0, 2.0)
	player.cutscene_set_auto_walk(true)
	var ditas := {}
	await fase(ANDAR, func(k: float) -> void:
		var t := k * ANDAR
		# a reta: o passo não pode puxar pra lado nenhum
		player.global_rotation.y = atan2(-_direcao.x, -_direcao.z)
		# de lado e na frente, baixa, pras costas dele e mais alta
		var e := suave(k)
		var cab := _cabeca()
		var de_lado := cab + lado * 3.0 + _direcao * 0.6 - Vector3.UP * 0.35
		var de_tras := cab - _direcao * 3.4 + lado * 0.9 + Vector3.UP * 0.55
		plantar(de_lado.lerp(de_tras, e), cab + _direcao * lerpf(0.0, 4.0, e))
		for f in FALAS:
			if t >= float(f[0]) and not ditas.has(f[1]):
				ditas[f[1]] = true
				legenda(String(f[1]), float(f[2])))
	if not vale():
		return
	player.cutscene_set_auto_walk(false)
	player.velocity = Vector3.ZERO
	await escurecer(1.0, 1.0)
	await esperar(0.4)
	encerrar(1.6)


## A cabeça do modelo (ele fica um pouco atrás da origem do player).
func _cabeca() -> Vector3:
	var modelo = player.get("modelo_visual")
	if is_instance_valid(modelo):
		return (modelo as Node3D).global_position + Vector3.UP * 1.55
	return player.global_position + Vector3.UP * 0.7


## Entre ±40° do rumo, a reta de COMPRIMENTO metros que passa mais longe das
## árvores (pra o passo não esbarrar num tronco no meio da cena).
static func _rumo_livre(inicio: Vector3, rumo: Vector3, arvores: Array) -> Vector3:
	var melhor := rumo
	var folga_melhor := -1.0
	for g in range(-8, 9):
		var d := rumo.rotated(Vector3.UP, deg_to_rad(5.0 * g)).normalized()
		var a := Vector2(inicio.x, inicio.z)
		var b := a + Vector2(d.x, d.z) * COMPRIMENTO
		var folga := 99.0
		for arv in arvores:
			var p := Vector2(float(arv[0]), float(arv[2]))
			if p.distance_to(a) > COMPRIMENTO + 4.0:
				continue
			folga = minf(folga, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
		# prefere o rumo certo quando a folga empata
		folga -= absf(g) * 0.05
		if folga > folga_melhor:
			folga_melhor = folga
			melhor = d
	return melhor
