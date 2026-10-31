extends Node

## O CAPÍTULO 3 NA CIDADE — a FLORESTA a leste, entre o `floresta_local` e o
## `cemiterio_local` (dois Marker3D de `locais_importantes` na stage_1).
##
## Quem cria é a `stage_1` (no `_ready`), em todo capítulo: antes do Capítulo 3
## isto não faz nada. A floresta é a própria mata da cidade, na mesma cena —
## não há mapa novo. O que muda é uma ÁREA (um corredor largo do F ao C, de
## contorno irregular) que vira lugar fechado:
##
##  - muros invisíveis no contorno, com uma fileira a mais de árvores por fora
##    pra a beira ler como mata fechada, e não como parede;
##  - colisão nos troncos das árvores de dentro (a mata da cidade é só
##    MultiMesh: sem isto o Maycow atravessava as árvores);
##  - a névoa engrossa enquanto ele está lá dentro;
##  - o minimapa (e a aba MAPA) troca pra prancha da floresta, que a cidade não
##    cobre (`mapa_da_floresta.gd`).
##
## As passagens (sempre com a tela indo ao preto):
##
##   cidade --(chega no F)--> floresta: na primeira vez, a cena dele andando no
##       meio das árvores (`cutscene_floresta.gd`); daí em diante a
##       interrogação vai pro C e o objetivo vira "atravesse a floresta";
##   floresta --(chega no C)--> o cemitério, que abre devagar;
##   floresta --(volta ao F)--> a cidade, na beira da mata, no fim da rua. Na
##       primeira travessia NÃO: até chegar no cemitério ele está preso
##       (`Eventos.floresta_presa`);
##   cemitério --(portão)--> floresta, no C (`GlobalEvents.voltando_do_cemiterio`,
##       ver `posicionar_na_volta_do_cemiterio`).
##
## Estar "na floresta" é estar dentro do contorno — não há estado gravado: um
## save feito lá dentro carrega lá dentro.
##
## Do Capítulo 4 em diante (`Eventos.floresta_com_nomes`) a interrogação sai da
## beira da mata e os dois pontos ganham NOME no mapa: o F se chama "Floresta"
## visto da cidade e "Cidade" visto de dentro da mata (é a saída pra ela); o C
## é sempre "Cemitério".

const CutsceneFloresta := preload("res://scripts/stages/stage_1/cutscene_floresta.gd")
const PontoNoMapa := preload("res://scripts/ui/ponto_no_mapa.gd")
const MapaDaFloresta := preload("res://scripts/stages/stage_1/mapa_da_floresta.gd")

const NO_FLORESTA := "locais_importantes/floresta_local"
const NO_CEMITERIO := "locais_importantes/cemiterio_local"
const NO_ESCOLA := "locais_importantes/escola_exterior"
const CENA_CEMITERIO := "res://scenes/stages/cemiterio/cemiterio.tscn"
const SCATTER := "res://assets/3d_model/city/scatter.json"
const MALHAS_ARVORE := ["res://assets/3d_model/city/multimesh/mesh_TREE_forest.tres",
	"res://assets/3d_model/city/multimesh/mesh_TREE_forest_broad.tres"]
const ESPECIES := ["TREE_forest", "TREE_forest_broad"]
## O nó `City` entra na stage_1 deslocado disto: o scatter.json é local a ele.
const NO_CIDADE := "City"
const NO_MINIMAPA := "Minimap"

## Onde ele volta pra cidade: na beira da mata, no fim da rua secundária que
## vem do oeste (ela acaba em x 902, z -87 do mundo; a mata começa em x 930).
const SAIDA_PRA_CIDADE := Vector3(918.0, 4.0, -87.0)
## De costas pra mata, olhando a rua (o corpo olha pro -Z; PI/2 vira pro -X).
const OLHAR_PRA_CIDADE := PI * 0.5

## Chegando a isto (no chão) do F, de fora, ele entra; do C, de dentro, vai pro
## cemitério.
const RAIO_DO_PONTO := 6.0
## De dentro, a volta pelo F vale a esta distância dele (o contorno começa
## COMECO metros depois do F, então quem encosta na beira de lá já está perto).
const RAIO_DA_SAIDA := 13.0
## O contorno começa COMECO m depois do F (o F fica do LADO DE FORA, onde a
## cidade alcança) e termina ALEM_DO_C m depois do C.
const COMECO := 8.0
const ALEM_DO_C := 18.0
## [fração do comprimento do contorno, meia-largura em metros]: mais estreito
## nas pontas, largo no meio, com dois "bojos" pra não parecer um corredor.
const LARGURAS := [[0.0, 16.0], [0.08, 28.0], [0.26, 42.0], [0.47, 36.0],
	[0.68, 45.0], [0.86, 34.0], [1.0, 20.0]]
## Onde ele aparece ao entrar pelo F (sem a cena), depois do começo do contorno.
const ENTRADA := 24.0
## A fileira de árvores de fora do contorno: de quanto em quanto e a que
## distância do muro.
const PASSO_DA_BEIRA := 3.4
const FILEIRAS_DA_BEIRA := [1.6, 4.4]
## O raio do tronco das árvores do kit (`vegetation.py`) na escala 1.
const RAIO_TRONCO := 0.38

## A névoa lá dentro (a da stage_1 é 0,005).
const NEVOA_DENTRO := 0.024
const NEVOA_COR_DENTRO := Color(0.12, 0.15, 0.14)

var cidade: Node3D
var player: CharacterBody3D

var _f := Vector3.ZERO
var _c := Vector3.ZERO
## F→C no chão (normalizado) e a perpendicular.
var _dir := Vector2.ZERO
var _lado := Vector2.ZERO
var _contorno := PackedVector2Array()
## [x, y, z, escala] das árvores da região (mundo).
var _arvores: Array = []
## As mesmas, por célula de CELULA metros (Vector2i -> Array).
var _grade := {}
const CELULA := 16.0
## [x, y, z, escala] de tudo que vai desenhado no mapa da floresta: as do
## scatter no recorte da prancha e as da beira.
var _arvores_mapa: Array = []
var _textura_mapa: Texture2D
var _marca: Node3D
var _marcado_em := "-"
## Os pontos com nome do Capítulo 4 em diante (o F e o C) e a chave que o F
## está mostrando agora.
var _nome_f: Node3D
var _nome_c: Node3D
var _chave_f := ""
var _ocupado := false
var _dentro := false
var _aviso_preso := 0.0
var _relogio_marca := 0.0
var _ambiente: Environment
var _nevoa_fora := 0.005
var _nevoa_cor_fora := Color(0.2, 0.25, 0.3)
var _tween_nevoa: Tween
var _camada: CanvasLayer
var _preto: ColorRect


func iniciar(dono: Node3D) -> void:
	cidade = dono
	player = cidade.get_node_or_null("Player") as CharacterBody3D
	var f := cidade.get_node_or_null(NO_FLORESTA) as Node3D
	var c := cidade.get_node_or_null(NO_CEMITERIO) as Node3D
	if f == null or c == null or not Eventos.floresta_aberta():
		set_physics_process(false)
		set_process(false)
		return
	_f = f.global_position
	_c = c.global_position
	_dir = Vector2(_c.x - _f.x, _c.z - _f.z).normalized()
	_lado = Vector2(-_dir.y, _dir.x)
	_montar_contorno()
	_ler_arvores()
	_montar_muros()
	_montar_troncos()
	_montar_beira()
	_textura_mapa = MapaDaFloresta.montar(_contorno, _arvores_mapa)
	_montar_tela()
	var we := cidade.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_ambiente = we.environment
		_nevoa_fora = _ambiente.fog_density
		_nevoa_cor_fora = _ambiente.fog_light_color
	if is_instance_valid(player):
		_dentro = dentro(player.global_position)
		_aplicar_nevoa(_dentro, 0.0)
		_trocar_mapa(_dentro)
	Eventos.mudou.connect(_ao_mudar_evento)
	_atualizar_interrogacao()


func _exit_tree() -> void:
	if Eventos.mudou.is_connected(_ao_mudar_evento):
		Eventos.mudou.disconnect(_ao_mudar_evento)


func _ao_mudar_evento(_id: String, _feito: bool) -> void:
	_atualizar_interrogacao()


# ==============================================================================
# O CONTORNO
# ==============================================================================

func _montar_contorno() -> void:
	var comprimento := Vector2(_c.x - _f.x, _c.z - _f.z).length() + ALEM_DO_C - COMECO
	var base := Vector2(_f.x, _f.z) + _dir * COMECO
	var esquerda := PackedVector2Array()
	var direita := PackedVector2Array()
	for par in LARGURAS:
		var p: Vector2 = base + _dir * comprimento * float(par[0])
		esquerda.append(p + _lado * float(par[1]))
		direita.append(p - _lado * float(par[1]))
	direita.reverse()
	_contorno = esquerda + direita


## Este ponto (mundo) está dentro da floresta?
func dentro(p: Vector3) -> bool:
	return not _contorno.is_empty() and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _contorno)


func _ler_arvores() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(SCATTER))
	if typeof(dados) != TYPE_DICTIONARY:
		return
	var deslocamento := Vector3(640.0, 0.0, -280.0)
	var no_cidade := cidade.get_node_or_null(NO_CIDADE) as Node3D
	if no_cidade:
		deslocamento = no_cidade.global_position
	var caixa := Rect2(_contorno[0], Vector2.ZERO)
	for v in _contorno:
		caixa = caixa.expand(v)
	caixa = caixa.grow(12.0)
	var prancha := MapaDados.new(MapaDaFloresta.JSON_DA_FLORESTA)
	var recorte := Rect2(prancha.x0, prancha.z0, prancha.tam, prancha.tam)
	for especie in ESPECIES:
		for p in dados["especies"].get(especie, []):
			var w := Vector3(float(p[0]), float(p[1]), float(p[2])) + deslocamento
			if recorte.has_point(Vector2(w.x, w.z)):
				_arvores_mapa.append([w.x, w.y, w.z, float(p[4])])
			if caixa.has_point(Vector2(w.x, w.z)):
				var a := [w.x, w.y, w.z, float(p[4])]
				_arvores.append(a)
				var k := Vector2i(floori(w.x / CELULA), floori(w.z / CELULA))
				if not _grade.has(k):
					_grade[k] = []
				_grade[k].append(a)


## A altura do chão perto de (x, z), pela árvore do scatter mais próxima (o
## Terrain3D só tem colisão perto da câmera).
func _altura(x: float, z: float) -> float:
	var melhor := INF
	var y := _f.y
	var k := Vector2i(floori(x / CELULA), floori(z / CELULA))
	for di in range(-1, 2):
		for dj in range(-1, 2):
			for a in _grade.get(k + Vector2i(di, dj), []):
				var d: float = (float(a[0]) - x) * (float(a[0]) - x) + (float(a[2]) - z) * (float(a[2]) - z)
				if d < melhor:
					melhor = d
					y = float(a[1])
	return y


func _montar_muros() -> void:
	var muro := StaticBody3D.new()
	muro.name = "floresta_muros"
	muro.collision_layer = 2
	muro.collision_mask = 0
	cidade.add_child(muro)
	var n := _contorno.size()
	for i in n:
		var a: Vector2 = _contorno[i]
		var b: Vector2 = _contorno[(i + 1) % n]
		var d := b - a
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(d.length() + 0.6, 24.0, 0.6)
		forma.shape = caixa
		muro.add_child(forma)
		var meio := (a + b) * 0.5
		forma.global_position = Vector3(meio.x, 3.0, meio.y)
		forma.rotation.y = atan2(-d.y, d.x)


func _montar_troncos() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "floresta_troncos"
	corpo.collision_layer = 2
	corpo.collision_mask = 0
	cidade.add_child(corpo)
	var formas := {}
	for a in _arvores:
		var p := Vector2(float(a[0]), float(a[2]))
		if not Geometry2D.is_point_in_polygon(p, _contorno):
			continue
		var r := snappedf(RAIO_TRONCO * float(a[3]), 0.05)
		if not formas.has(r):
			var cil := CylinderShape3D.new()
			cil.radius = r
			cil.height = 7.0
			formas[r] = cil
		var forma := CollisionShape3D.new()
		forma.shape = formas[r]
		corpo.add_child(forma)
		forma.global_position = Vector3(p.x, float(a[1]) + 2.0, p.y)


## Duas fileiras de árvores do lado de fora do muro: a beira vira mata fechada.
func _montar_beira() -> void:
	var centro := Vector2.ZERO
	for v in _contorno:
		centro += v
	centro /= float(_contorno.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3313
	var pontos: Array = [[], []]
	var n := _contorno.size()
	for i in n:
		var a: Vector2 = _contorno[i]
		var b: Vector2 = _contorno[(i + 1) % n]
		var d := b - a
		var fora := Vector2(-d.y, d.x).normalized()
		if fora.dot((a + b) * 0.5 - centro) < 0.0:
			fora = -fora
		var passos := int(d.length() / PASSO_DA_BEIRA)
		for k in passos:
			for fila in FILEIRAS_DA_BEIRA:
				var p := a + d * ((k + rng.randf()) / float(maxi(passos, 1))) \
					+ fora * (float(fila) + rng.randf_range(-0.8, 0.8))
				var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(
					Vector3.ONE * rng.randf_range(0.85, 1.35)), Vector3(p.x, _altura(p.x, p.y), p.y))
				pontos[rng.randi() % 2].append(t)
				_arvores_mapa.append([t.origin.x, t.origin.y, t.origin.z, t.basis.get_scale().x])
	for i in 2:
		var malha := load(MALHAS_ARVORE[i]) as Mesh
		if malha == null or (pontos[i] as Array).is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malha
		mm.instance_count = (pontos[i] as Array).size()
		for k in mm.instance_count:
			mm.set_instance_transform(k, pontos[i][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "floresta_beira_%d" % i
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cidade.add_child(mmi)


func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 95
	add_child(_camada)
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.modulate.a = 0.0
	_camada.add_child(_preto)


func _escurecer(alvo: float, duracao: float) -> void:
	var t := create_tween()
	t.tween_property(_preto, "modulate:a", alvo, duracao).set_trans(Tween.TRANS_SINE)
	await t.finished


# ==============================================================================
# AS PASSAGENS
# ==============================================================================

func _physics_process(delta: float) -> void:
	_relogio_marca -= delta
	if _relogio_marca <= 0.0:
		_relogio_marca = 0.5
		_atualizar_interrogacao()
	if _ocupado or not is_instance_valid(player):
		return
	if GlobalEvents.in_cutscene or GlobalUtils.in_cinematic_cutscene or get_tree().paused:
		return
	# a cidade fica escondida (e o parasita é quem joga) enquanto a arena roda
	if not cidade.visible or not GlobalEvents.is_maycow_normal:
		return
	_aviso_preso = maxf(0.0, _aviso_preso - delta)
	var p := player.global_position
	var agora := dentro(p)
	if agora != _dentro:
		_dentro = agora
		_aplicar_nevoa(_dentro, 2.5)
		_trocar_mapa(_dentro)
	if not _dentro:
		if _no_chao(p, _f) < RAIO_DO_PONTO:
			_entrar_na_floresta()
		return
	if _no_chao(p, _c) < RAIO_DO_PONTO:
		_ir_ao_cemiterio()
	elif _no_chao(p, _f) < RAIO_DA_SAIDA:
		if Eventos.floresta_presa():
			if _aviso_preso <= 0.0:
				_aviso_preso = 8.0
				GlobalUtils.show_center_message("floresta_presa", tr("CAP3_FLORESTA_PRESO"), 18, 3.2)
		else:
			_voltar_pra_cidade()


static func _no_chao(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _travar_jogador(sim: bool) -> void:
	if not is_instance_valid(player):
		return
	player.velocity = Vector3.ZERO
	player.cutscene_set_player_control(not sim)


func _entrar_na_floresta() -> void:
	_ocupado = true
	GlobalUtils.esconder_objetivo()
	_travar_jogador(true)
	await _escurecer(1.0, 1.2)
	if not is_inside_tree():
		return
	var inicio := _no_contorno(ENTRADA)
	if Eventos.pode(Eventos.CAP3_FLORESTA):
		var cena = CutsceneFloresta.new()
		cena.name = "cutscene_floresta"
		cidade.add_child(cena)
		cena.rodar(cidade, player, inicio, Vector3(_dir.x, 0.0, _dir.y), _arvores)
		# a cena começa no preto dela: a nossa tela sai por baixo
		await get_tree().process_frame
		_preto.modulate.a = 0.0
		_dentro = true
		_aplicar_nevoa(true, 1.5)
		_trocar_mapa(true)
		await cena.terminou
		Eventos.concluir(Eventos.CAP3_FLORESTA)
	else:
		_por_jogador(inicio, atan2(-_dir.x, -_dir.y))
		_dentro = true
		_aplicar_nevoa(true, 0.0)
		_trocar_mapa(true)
		await get_tree().create_timer(0.6, false).timeout
		_travar_jogador(false)
		await _escurecer(0.0, 1.6)
	_gravar_posicao()
	_ocupado = false
	_mostrar_objetivo()


func _voltar_pra_cidade() -> void:
	_ocupado = true
	GlobalUtils.esconder_objetivo()
	_travar_jogador(true)
	await _escurecer(1.0, 1.2)
	if not is_inside_tree():
		return
	_por_jogador(SAIDA_PRA_CIDADE, OLHAR_PRA_CIDADE)
	_dentro = false
	_aplicar_nevoa(false, 0.0)
	_trocar_mapa(false)
	await get_tree().create_timer(0.6, false).timeout
	_travar_jogador(false)
	await _escurecer(0.0, 1.6)
	_gravar_posicao()
	_ocupado = false
	_mostrar_objetivo()


## O C: a tela vai ao preto e o cemitério carrega; lá ele abre devagar.
func _ir_ao_cemiterio() -> void:
	_ocupado = true
	GlobalUtils.esconder_objetivo()
	_travar_jogador(true)
	GlobalEvents.in_cutscene = true
	await _escurecer(1.0, 2.2)
	if not is_inside_tree():
		return
	GlobalEvents.chegando_ao_cemiterio = true
	LoadingScreen.load_scene(CENA_CEMITERIO)


## Um ponto do eixo F→C a `metros` depois do começo do contorno.
func _no_contorno(metros: float) -> Vector3:
	var p := Vector2(_f.x, _f.z) + _dir * (COMECO + metros)
	return Vector3(p.x, _altura(p.x, p.y) + 1.0, p.y)


func _por_jogador(onde: Vector3, giro: float) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = onde + Vector3.UP * 1.0
	player.global_rotation.y = giro
	if cidade.has_method("_pousar_no_chao"):
		cidade.call("_pousar_no_chao", player, onde)


func _gravar_posicao() -> void:
	if is_instance_valid(player):
		SaveManager.save_player_position(player.global_position, player.global_rotation.y)
		SaveManager.save_game()


func _mostrar_objetivo() -> void:
	var chave := Eventos.objetivo_atual()
	if chave != "":
		GlobalUtils.mostrar_objetivo(tr(chave), 30.0)


## Saindo do cemitério pelo portão: dentro da floresta, no C, de frente pro F.
## (Chamado pela stage_1 no spawn, antes deste nó existir.)
static func posicionar_na_volta_do_cemiterio(dono: Node3D, jogador: Node3D) -> void:
	var f := dono.get_node_or_null(NO_FLORESTA) as Node3D
	var c := dono.get_node_or_null(NO_CEMITERIO) as Node3D
	if f == null or c == null or jogador == null:
		return
	var d := Vector2(f.global_position.x - c.global_position.x,
		f.global_position.z - c.global_position.z).normalized()
	var onde := c.global_position + Vector3(d.x, 0.0, d.y) * (RAIO_DO_PONTO + 3.0)
	jogador.global_position = onde + Vector3.UP * 1.0
	jogador.global_rotation.y = atan2(-d.x, -d.y)
	if dono.has_method("_pousar_no_chao"):
		dono.call_deferred("_pousar_no_chao", jogador, onde)


# ==============================================================================
# A NÉVOA
# ==============================================================================

func _aplicar_nevoa(na_floresta: bool, duracao: float) -> void:
	if _ambiente == null:
		return
	if _tween_nevoa and _tween_nevoa.is_valid():
		_tween_nevoa.kill()
	var densidade := NEVOA_DENTRO if na_floresta else _nevoa_fora
	var cor := NEVOA_COR_DENTRO if na_floresta else _nevoa_cor_fora
	if duracao <= 0.0:
		_ambiente.fog_density = densidade
		_ambiente.fog_light_color = cor
		return
	_tween_nevoa = create_tween().set_parallel(true)
	_tween_nevoa.tween_property(_ambiente, "fog_density", densidade, duracao)
	_tween_nevoa.tween_property(_ambiente, "fog_light_color", cor, duracao)


# ==============================================================================
# O MAPA
# ==============================================================================

## Dentro: a prancha da floresta no minimapa e na aba MAPA; fora, a da cidade.
func _trocar_mapa(na_floresta: bool) -> void:
	var mini := cidade.get_node_or_null(NO_MINIMAPA)
	if mini == null or not mini.has_method("usar_prancha") or _textura_mapa == null:
		return
	mini.usar_prancha(MapaDaFloresta.JSON_DA_FLORESTA if na_floresta else "", _textura_mapa)


# ==============================================================================
# A INTERROGAÇÃO DO MAPA
# ==============================================================================

## Pra onde a história manda agora ("" = nenhum lugar marcado).
func _onde_marcar() -> String:
	if not is_instance_valid(player):
		return ""
	var na_floresta := dentro(player.global_position)
	match Eventos.capitulo_atual():
		Eventos.CAPITULO_3:
			if not Eventos.feito(Eventos.CAP3_FLORESTA):
				return "floresta"
			if not Eventos.feito(Eventos.CAP3_PODER_CUT):
				return "cemiterio" if na_floresta else "floresta"
			return "floresta" if na_floresta else "escola"
		Eventos.CAPITULO_4:
			# na mata a saída já tem nome ("Cidade"): nada de interrogação
			return "" if na_floresta else "escola"
	return ""


func _posicao(onde: String) -> Variant:
	match onde:
		"floresta":
			return _f
		"cemiterio":
			return _c
		"escola":
			var escola := cidade.get_node_or_null(NO_ESCOLA) as Node3D
			if escola:
				var area := escola.get_node_or_null("area_entrada") as Node3D
				return area.global_position if area else escola.global_position
	return null


func _atualizar_interrogacao() -> void:
	_atualizar_nomes()
	var onde := _onde_marcar()
	if onde == _marcado_em:
		return
	_marcado_em = onde
	if is_instance_valid(_marca):
		_marca.queue_free()
	_marca = null
	var pos = _posicao(onde)
	if pos == null:
		return
	_marca = Node3D.new()
	_marca.name = "interrogacao_capitulo_3"
	cidade.add_child(_marca)
	_marca.global_position = pos
	var ponto = PontoNoMapa.new()
	ponto.tipo = "interrogacao"
	ponto.sempre_visivel = true
	_marca.add_child(ponto)


# ==============================================================================
# OS NOMES DO MAPA (Capítulo 4 em diante)
# ==============================================================================

## O F muda de nome conforme o lado em que o Maycow está; o C não muda. No
## Capítulo 3 nenhum dos dois tem nome (a interrogação faz esse papel).
func _atualizar_nomes() -> void:
	if not Eventos.floresta_com_nomes() or not is_instance_valid(player):
		_chave_f = ""
		for no in [_nome_f, _nome_c]:
			if is_instance_valid(no):
				no.queue_free()
		_nome_f = null
		_nome_c = null
		return
	var chave := "MAP_POI_CIDADE" if dentro(player.global_position) else "MAP_POI_FLORESTA"
	if chave != _chave_f or not is_instance_valid(_nome_f):
		_chave_f = chave
		if is_instance_valid(_nome_f):
			_nome_f.queue_free()
		_nome_f = _ponto_com_nome("nome_floresta_local", _f, chave)
	if not is_instance_valid(_nome_c):
		_nome_c = _ponto_com_nome("nome_cemiterio_local", _c, "MAP_POI_CEMITERIO")


func _ponto_com_nome(nome: String, onde: Vector3, chave: String) -> Node3D:
	var no := Node3D.new()
	no.name = nome
	cidade.add_child(no)
	no.global_position = onde
	var ponto = PontoNoMapa.new()
	ponto.tipo = "local"
	ponto.chave = chave
	ponto.sempre_visivel = true
	no.add_child(ponto)
	return no
