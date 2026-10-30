extends Node

## Acha malhas que FLUTUAM: a caixa delas (folga de 3 cm) não encosta em
## nenhuma outra geometria da cena. Uso:
##   godot --headless --path . res://tools/flutuantes/achar.tscn -- <cena.tscn> [saida.json]

const CAMADA := 1 << 29
const FOLGA := 0.03

func _ready() -> void:
	SaveManager.current_slot = 9
	var args := OS.get_cmdline_user_args()
	var caminho: String = args[0]
	var saida: String = args[1] if args.size() > 1 else ""
	var cena := (load(caminho) as PackedScene).instantiate()
	# só a geometria: nada de script rodando (player, inimigos)
	# (a cena roda normal: cena desligada tira os corpos do espaço de física)
	get_tree().root.add_child.call_deferred(cena)
	await get_tree().process_frame
	await get_tree().process_frame
	var corpos := {}
	var malhas: Array = []
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if _dentro_do_player(mi):
			continue
		# peça pequena = forma convexa (consulta confiável); grande (piso,
		# parede, prédio) = malha triangular, senão o casco engole o vazio
		var tam_local: Vector3 = (mi.global_transform * mi.get_aabb()).size
		var forma: Shape3D = mi.mesh.create_convex_shape(true, false) if maxf(tam_local.x, maxf(tam_local.y, tam_local.z)) < 2.5 else mi.mesh.create_trimesh_shape()
		if forma == null:
			continue
		var corpo := StaticBody3D.new()
		corpo.collision_layer = CAMADA
		corpo.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = forma
		corpo.add_child(cs)
		mi.add_child(corpo)
		corpos[mi] = corpo
		malhas.append(mi)
	print("MALHAS ", malhas.size(), " t=", Time.get_ticks_msec())
	# a colisão de verdade (chão, paredes) também conta como apoio
	for c in cena.find_children("*", "CollisionObject3D", true, false):
		(c as CollisionObject3D).collision_layer |= CAMADA
	for i in 3:
		await get_tree().physics_frame
	var espaco := (cena as Node3D).get_world_3d().direct_space_state
	print("FISICA OK t=", Time.get_ticks_msec())
	var achados: Array = []
	for mi in malhas:
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		if aabb.size.length() > 30.0:
			continue
		var excluir: Array[RID] = [corpos[mi].get_rid()]
		var toques := _encosta(espaco, aabb, excluir)
		if OS.get_cmdline_user_args().has("debug") and str(mi.name).begins_with("macaneta_porta_q1_e"):
			print("DEBUG encosta: ", toques)
		if not toques:
			var r := PhysicsRayQueryParameters3D.create(aabb.get_center(), aabb.get_center() + Vector3.DOWN * 50.0, CAMADA, excluir)
			var hit := espaco.intersect_ray(r)
			var vao: float = (aabb.position.y - hit.position.y) if hit else -1.0
			var corr := _correcao(espaco, aabb, excluir, vao)
			var raiz := _raiz_da_peca(cena, mi)
			achados.append({"raiz": str(cena.get_path_to(raiz)), "pos_raiz": [raiz.position.x, raiz.position.y, raiz.position.z], "delta": [snappedf(corr.x, 0.001), snappedf(corr.y, 0.001), snappedf(corr.z, 0.001)], "no": str(cena.get_path_to(mi)), "centro": [snappedf(aabb.get_center().x, 0.01), snappedf(aabb.position.y, 0.01), snappedf(aabb.get_center().z, 0.01)], "tam": [snappedf(aabb.size.x, 0.01), snappedf(aabb.size.y, 0.01), snappedf(aabb.size.z, 0.01)], "vao": snappedf(vao, 0.01)})
	print("FLUTUANTES ", achados.size())
	for a in achados:
		print("  ", a)
	# Segundo teste: a peça tem algo EMBAIXO? O de cima aceita qualquer toque,
	# e a caixa de colisão que o gerador põe em volta do móvel (colisao_mobilia)
	# envolve a própria peça — a lixeira a 1 m do chão passava por apoiada.
	# Aqui só malha conta (de outra peça), e a peça é medida inteira.
	var sem_chao := _sem_apoio_embaixo(cena, espaco, malhas, corpos)
	print("SEM_APOIO_EMBAIXO ", sem_chao.size())
	for a in sem_chao:
		print("  ", a)
	achados.append_array(sem_chao)
	if saida != "":
		var f := FileAccess.open(saida, FileAccess.WRITE)
		f.store_string(JSON.stringify(achados, "  "))
	get_tree().quit()


## Encosta em alguma coisa? Raios curtos saindo das 6 faces da caixa (5 por
## face), começando 2 cm por dentro. Raio é confiável contra malha triangular
## grande (piso, teto, balcão fundido), coisa que a consulta de forma não é.
func _encosta(espaco: PhysicsDirectSpaceState3D, aabb: AABB, excluir: Array[RID]) -> bool:
	var c := aabb.get_center()
	var meia := aabb.size * 0.5
	for eixo in 3:
		for sinal in [-1.0, 1.0]:
			var d := Vector3.ZERO
			d[eixo] = sinal
			var u := (eixo + 1) % 3
			var v := (eixo + 2) % 3
			for k in [Vector2(0, 0), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)]:
				var p := c
				p[eixo] += sinal * meia[eixo]
				p[u] += k.x * meia[u]
				p[v] += k.y * meia[v]
				var q := PhysicsRayQueryParameters3D.create(p - d * 0.02, p + d * FOLGA, CAMADA, excluir)
				q.hit_from_inside = true
				q.hit_back_faces = true
				if not espaco.intersect_ray(q).is_empty():
					return true
	return false


## Quanto mover pra encostar: na parede mais perto (até 1 m, nos 4 lados) ou,
## sem parede, descer até o apoio.
func _correcao(espaco: PhysicsDirectSpaceState3D, aabb: AABB, excluir: Array[RID], vao: float) -> Vector3:
	var c := aabb.get_center()
	var melhor := INF
	var dir := Vector3.ZERO
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
		var r := PhysicsRayQueryParameters3D.create(c, c + d * 1.5, CAMADA, excluir)
		var hit := espaco.intersect_ray(r)
		if hit.is_empty():
			continue
		var meia: float = absf(d.dot(aabb.size)) * 0.5
		var folga: float = c.distance_to(hit.position) - meia
		if folga < melhor:
			melhor = folga
			dir = d
	if melhor < 1.0:
		return dir * (melhor - 0.004)
	if vao > 0.0:
		return Vector3.DOWN * (vao - 0.002)
	return Vector3.ZERO


## Peças (raiz) cuja base não pousa em malha nenhuma de outra peça. Lista o
## vão até o que houver embaixo; peça pendurada na parede (quadro, lousa,
## extintor) aparece aqui também — quem lê separa pelo nome.
func _sem_apoio_embaixo(cena: Node, espaco: PhysicsDirectSpaceState3D, malhas: Array, corpos: Dictionary) -> Array:
	var pecas := {}
	for mi in malhas:
		var raiz := _raiz_da_peca(cena, mi)
		if raiz == null:
			continue
		if not pecas.has(raiz):
			pecas[raiz] = []
		pecas[raiz].append(mi)
	# só malha: a colisão "de verdade" sai da camada (fica só a das malhas)
	for c in cena.find_children("*", "CollisionObject3D", true, false):
		if not corpos.values().has(c):
			(c as CollisionObject3D).collision_layer &= ~CAMADA
	var lista: Array = []
	for raiz in pecas:
		var caixa: AABB
		var excluir: Array[RID] = []
		for i in pecas[raiz].size():
			var mi: MeshInstance3D = pecas[raiz][i]
			var a: AABB = mi.global_transform * mi.get_aabb()
			caixa = a if i == 0 else caixa.merge(a)
			excluir.append(corpos[mi].get_rid())
		if caixa.size.length() > 30.0:
			continue
		var c := caixa.get_center()
		var meia := caixa.size * 0.5
		var apoiada := false
		# o menor vão entre os 5 pontos: descer isso encosta a peça sem enterrar
		var vao_min := INF
		for k in [Vector2(0, 0), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)]:
			var p := Vector3(c.x + k.x * meia.x, caixa.position.y, c.z + k.y * meia.z)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.02, p + Vector3.DOWN * FOLGA, CAMADA, excluir)
			q.hit_from_inside = true
			q.hit_back_faces = true
			if not espaco.intersect_ray(q).is_empty():
				apoiada = true
				break
			var longe := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 50.0, CAMADA, excluir)
			longe.hit_back_faces = true
			var h := espaco.intersect_ray(longe)
			if not h.is_empty():
				vao_min = minf(vao_min, p.y - h.position.y)
		if apoiada:
			continue
		var r := PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * 50.0, CAMADA, excluir)
		r.hit_back_faces = true
		var hit := espaco.intersect_ray(r)
		var vao: float = (caixa.position.y - hit.position.y) if hit else -1.0
		lista.append({"raiz": str(cena.get_path_to(raiz)), "sem_apoio_embaixo": true,
			"pos_raiz": [raiz.position.x, raiz.position.y, raiz.position.z],
			"delta": [0.0, snappedf(-vao + 0.002, 0.001) if vao > 0.0 else 0.0, 0.0],
			"centro": [snappedf(c.x, 0.01), snappedf(caixa.position.y, 0.01), snappedf(c.z, 0.01)],
			"tam": [snappedf(caixa.size.x, 0.01), snappedf(caixa.size.y, 0.01), snappedf(caixa.size.z, 0.01)],
			"vao": snappedf(vao, 0.01), "vao_min": snappedf(vao_min, 0.001) if vao_min < INF else -1.0})
	return lista


## A peça inteira (o nó logo abaixo do contêiner de 1º nível da cena).
func _raiz_da_peca(cena: Node, n: Node) -> Node3D:
	var atual := n
	while atual.get_parent() and atual.get_parent().get_parent() != cena and atual.get_parent() != cena:
		atual = atual.get_parent()
	return atual as Node3D


## Malhas irmãs da mesma peça (filhas do mesmo pai importado) não contam como
## apoio umas das outras... só quando a peça é uma mesa de pernas. Então contam:
## aqui só a própria malha é excluída.
func _corpos_do_mesmo_objeto(_mi: MeshInstance3D, _corpos: Dictionary) -> Array:
	return []


func _dentro_do_player(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p.name == "Player" or p.is_in_group("player"):
			return true
		p = p.get_parent()
	return false


func _desligar(n: Node) -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED
