@tool
extends Node3D

## Etapa 10 — a cidade usada: entulho no pe' do muro, cano na fachada,
## barreira na guia e o que enfeita a praca do obelisco.
##
## A etapa 08 espalhou o entulho de quintal e de fachada. Ela nao alcanca tres
## lugares que sao justamente os que o jogador olha:
##
##   * a GUIA da rua, onde fica a barreira de obra;
##   * o pe' do MURO pelo lado de fora, que e' onde encosta escada, galao,
##     engradado e a lata de spray de quem acabou de pichar;
##   * a PRACA DO OBELISCO, que ate' agora e' um circulo de piso vazio.
##
## As malhas sao do Poly Haven, baixadas em 1k (`assets/3d_model/polyhaven/`).
##
## DUAS FORMAS DE EXTRAIR MALHA, e e' por isso que esta etapa nao entrou na 08:
## o `_primeira_malha()` de la' pega o PRIMEIRO MeshInstance do .gltf e ignora o
## resto. Serve pros adereços de peca unica que ela usa, mas aqui:
##
##   * `potted_plant_02` e `wooden_barrels_01` tem de 3 a 19 pecas ja' montadas
##     no lugar certo: precisam de TODAS fundidas, senao entra na cena so' o
##     vaso sem a planta, ou um barril de uma pilha de dezenove;
##   * `modular_metal_gutter` e `modular_airduct_circular_01` sao KITS — as 12
##     e 16 pecas estao enfileiradas lado a lado no arquivo, feito mostruario.
##     Fundir viraria uma fileira de canos soltos; aqui se escolhe UMA peca
##     pelo nome.
##
## Quem decide e' o campo `peca` do catalogo: presente, pega aquela; ausente,
## funde tudo. Nos dois casos o transform dos nos entra nos vertices, entao a
## instancia sai no lugar sem transform extra.
##
## O resto (onde e' chao, onde e' rua, onde e' casa, onde e' muro) sai do
## `CityMapa`, o mesmo das etapas 09 e 11.

const CityMapa := preload("res://tools/godot/citybuild/city_mapa.gd")
const CAMINHO_PH := "res://assets/3d_model/polyhaven/%s/%s_1k.gltf"
## Malhas fundidas/recortadas gravadas aqui. Sem isso cada MultiMesh embute a
## propria copia da geometria e a cena salta de centenas de KB pra dezenas de
## MB — mesmo motivo documentado na etapa 08.
const DIR_MALHAS := "res://assets/3d_model/city/malhas_urbano"

@export_group("Entrada")
@export var houses_json: String = "res://assets/3d_model/city/houses.json"
@export var poles_json: String = "res://assets/3d_model/city/poles.json"
@export var no_ruas: NodePath = ^"../City/Roads"
@export var no_muros: NodePath = ^"../City/Walls"
## O no do terreno se chama "Terrenasso"; procurar por "Terrain3D" nao acha.
@export var no_terreno: NodePath = ^"../NavigationRegion3D/Terrenasso"
@export var no_cidade: NodePath = ^"../City"

@export_group("Espalhamento")
@export var semente: int = 20260915
@export_range(0.0, 3.0, 0.05) var densidade: float = 1.0
## Distancia minima entre dois adereços, em metros. E' o passo da grade de
## ocupacao, entao o afastamento real fica entre este valor e o dobro dele.
@export var espacamento: float = 2.4
## Piso de raio no espacamento. Sem ele, um adereço pequeno (galao, bola, lata
## de spray) reserva so' o proprio tamanho e tres deles acabam encostados —
## foi o que deixou a beira da praca com cara de deposito.
@export var raio_minimo: float = 1.3
## Adereços que JA' existem na cena e tambem ocupam lugar. A etapa 08
## (`PropsExtra`) tem a propria grade de ocupacao, e as duas nao se enxergam:
## sem ler os adereços dela aqui, um engradado dela e um balde daqui podem
## nascer a dez centimetros um do outro. Vazio = nao considera nada.
@export var no_props_existentes: NodePath = ^"../PropsExtra"
## Distancia a respeitar dos adereços da etapa 08. E' bem menor que o
## `espacamento`: da etapa 08 basta NAO ENCOSTAR, enquanto entre os adereços
## desta etapa se quer espalhamento de verdade. Usar o mesmo valor nos dois
## esterilizaria a cidade — sao mil e quatrocentos adereços ja' postos, e cada
## um reservaria mais de cinquenta metros quadrados.
@export var espacamento_herdado: float = 1.2
## Lado do bloco espacial. Igual as outras etapas: sem fatiar, a cidade inteira
## renderiza sempre.
@export var bloco: float = 128.0

@export_group("Praca do obelisco")
## Centro da praca em coordenadas LOCAIS da cidade (layout.json/landmarks).
@export var praca_centro := Vector2(0.0, 0.0)
## A ilha do obelisco vai ate' aqui; o mobiliario comeca depois dela.
@export var praca_raio_ilha: float = 11.0
## E termina aqui, que e' a guia da rotatoria.
@export var praca_raio_externo: float = 19.0

@export_group("Pontos de parada")
## Grava onde um NPC pode sentar ou encostar. O `city_npc.gd` le este arquivo
## e manda os moradores pra la'. Sem ele, os NPCs so' sabem vagar.
@export var gravar_pontos: bool = true
@export var pontos_json: String = "res://assets/3d_model/city/pontos_de_parada.json"
## Altura do assento do banco, medida no modelo.
@export var altura_do_assento: float = 0.53
## Quantos lugares de encostar no muro.
@export var pontos_de_encostar: int = 160

@export_group("Colisao")
## Barra o jogador so' nos volumes grandes (carro, banco, barreira, carrinho).
@export var colisao_grandes: bool = true
@export var camada_colisao: int = 2

@export_multiline var last_result: String = ""

## Sem `ResourceSaver` durante a construcao, pelo mesmo motivo da etapa 08:
## salvar recurso a recurso devolve o loop principal ao editor no meio deste
## script @tool e o reload que ele dispara e' SIGSEGV. O unico passo que grava
## e' o `extrair_malhas`, que roda sozinho e nao constroi nada.
var _ocupado: bool = false

## Passo unico, ANTES do primeiro `construir`: funde/recorta as malhas e grava
## em DIR_MALHAS. So' precisa rodar de novo se um .gltf mudar.
@export var extrair_malhas: bool = false:
	set(v):
		extrair_malhas = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_extrair_malhas()
			_ocupado = false

@export var construir: bool = false:
	set(v):
		construir = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_construir()
			_ocupado = false

@export var limpar: bool = false:
	set(v):
		limpar = false
		if v and Engine.is_editor_hint() and not _ocupado:
			_ocupado = true
			_limpar()
			_ocupado = false


# --------------------------------------------------------------------------
# catalogo
# --------------------------------------------------------------------------
# papel — onde o adereço pode nascer:
#   guia     na guia da rua, alinhado com a pista (carro, barreira)
#   muro     encostado no muro pelo lado de FORA, no chao
#   parede   preso na parede da casa, acima do muro (cano, duto, camera)
#   quintal  terreno entre casas
#   praca    anel da praca do obelisco
# peca    — nome do no dentro do .gltf. Ausente = funde o arquivo inteiro.
# base_y  — quanto subir pro modelo assentar (e' o -y_min dele).
# raio    — meia-largura usada no espacamento.
# esc     — faixa de escala uniforme.
# alt     — faixa de altura, so' pro papel "parede".
# grande  — ganha caixa de colisao; `col` e' o tamanho dela.
const CATALOGO := [
	# --- na guia ----------------------------------------------------------
	# O `covered_car` SAIU daqui: uma cidade com carro coberto em cada esquina
	# parecia ferro-velho, nao rua de morador. O .gltf continua baixado em
	# `assets/3d_model/polyhaven/covered_car/` — pra trazer de volta basta
	# reinserir a linha e subir o TENTATIVAS["guia"].
	{"n": "concrete_road_barrier_02", "papel": "guia", "peso": 3, "base_y": 0.0, "raio": 0.9,
		"esc": [0.95, 1.05], "grande": true, "col": [1.6, 1.1, 0.5]},

	# --- encostado no muro, pelo lado da rua ------------------------------
	{"n": "ladder_sectioned_01", "papel": "muro", "peso": 3, "base_y": 0.0, "raio": 0.45, "esc": [0.95, 1.05]},
	{"n": "wooden_ladder_02", "papel": "muro", "peso": 3, "base_y": 0.0, "raio": 0.55, "esc": [0.95, 1.05]},
	## lata de spray largada — o rastro de quem pichou o muro na etapa 09
	{"n": "spray_paint_bottles_02", "papel": "muro", "peso": 5, "base_y": 0.0, "raio": 0.15, "esc": [0.9, 1.1]},
	{"n": "plastic_bottle_gallon", "papel": "muro", "peso": 6, "base_y": 0.0, "raio": 0.12, "esc": [0.9, 1.15]},
	{"n": "metal_jerrycan", "papel": "muro", "peso": 4, "base_y": 0.0, "raio": 0.2, "esc": [0.9, 1.1]},
	{"n": "cement_bag", "papel": "muro", "peso": 4, "base_y": 0.0, "raio": 0.4, "esc": [0.9, 1.1]},
	{"n": "plastic_crate_01", "papel": "muro", "peso": 6, "base_y": 0.0, "raio": 0.25, "esc": [0.9, 1.15]},
	{"n": "plastic_crate_03", "papel": "muro", "peso": 5, "base_y": 0.0, "raio": 0.3, "esc": [0.9, 1.15]},
	{"n": "industrial_pastic_container", "papel": "muro", "peso": 4, "base_y": 0.0, "raio": 0.35, "esc": [0.9, 1.1]},
	{"n": "wooden_bucket_01", "papel": "muro", "peso": 4, "base_y": 0.0, "raio": 0.22, "esc": [0.9, 1.15]},
	{"n": "boombox", "papel": "muro", "peso": 1, "base_y": 0.0, "raio": 0.4, "esc": [0.95, 1.05]},
	{"n": "tire_pump", "papel": "muro", "peso": 2, "base_y": 0.0, "raio": 0.15, "esc": [0.95, 1.05]},
	{"n": "rusted_wheel_rim_01", "papel": "muro", "peso": 3, "base_y": 0.2, "raio": 0.25, "esc": [0.9, 1.1]},
	{"n": "dirty_football", "papel": "muro", "peso": 2, "base_y": 0.0, "raio": 0.15, "esc": [0.95, 1.05]},
	{"n": "WetFloorSign_01", "papel": "muro", "peso": 1, "base_y": 0.0, "raio": 0.3, "esc": [0.95, 1.05]},
	{"n": "planter_pot_clay", "papel": "muro", "peso": 6, "base_y": 0.0, "raio": 0.2, "esc": [0.9, 1.3]},
	{"n": "potted_plant_02", "papel": "muro", "peso": 4, "base_y": 0.0, "raio": 0.4, "esc": [0.9, 1.1]},

	# --- preso na parede da casa, ACIMA do muro ---------------------------
	## cano de descida da calha: e' vertical e vai do beiral ao chao
	{"n": "modular_metal_gutter", "peca": "modular_metal_gutter_section", "papel": "parede",
		"peso": 8, "alt": [2.6, 3.4], "esc": [0.95, 1.05], "esc_y": [1.6, 2.6]},
	{"n": "modular_airduct_circular_01", "peca": "modular_airduct_circular_double",
		"papel": "parede", "peso": 3, "alt": [2.8, 3.6], "esc": [0.9, 1.1]},
	{"n": "security_camera_02", "papel": "parede", "peso": 1, "alt": [3.0, 3.8], "esc": [0.95, 1.05]},

	# --- quintal e terreno entre casas ------------------------------------
	{"n": "portable_generator", "papel": "quintal", "peso": 3, "base_y": 0.0, "raio": 0.5, "esc": [0.95, 1.05]},
	{"n": "tool_cart", "papel": "quintal", "peso": 3, "base_y": 0.0, "raio": 0.7, "esc": [0.95, 1.05]},
	{"n": "wooden_barrels_01", "papel": "quintal", "peso": 4, "base_y": 0.04, "raio": 2.2, "esc": [0.9, 1.05]},
	{"n": "barrel_stove", "papel": "quintal", "peso": 3, "base_y": 0.0, "raio": 0.35, "esc": [0.95, 1.05]},
	{"n": "garden_gnome", "papel": "quintal", "peso": 2, "base_y": 0.0, "raio": 0.2, "esc": [0.9, 1.1]},
	{"n": "watering_can_metal_01", "papel": "quintal", "peso": 3, "base_y": 0.0, "raio": 0.25, "esc": [0.9, 1.1]},
	{"n": "garden_sprinkler_01", "papel": "quintal", "peso": 2, "base_y": 0.0, "raio": 0.2, "esc": [0.9, 1.1]},
	{"n": "planter_pot_clay", "papel": "quintal", "peso": 7, "base_y": 0.0, "raio": 0.2, "esc": [0.9, 1.35]},
	{"n": "wooden_bucket_01", "papel": "quintal", "peso": 5, "base_y": 0.0, "raio": 0.22, "esc": [0.9, 1.15]},
	{"n": "cement_bag", "papel": "quintal", "peso": 3, "base_y": 0.0, "raio": 0.4, "esc": [0.9, 1.1]},
	{"n": "dry_branches_medium_01", "papel": "quintal", "peso": 6, "base_y": 0.02, "raio": 0.8, "esc": [0.85, 1.2]},
	{"n": "shrub_04", "papel": "quintal", "peso": 9, "base_y": 0.01, "raio": 0.45, "esc": [0.85, 1.3]},
	{"n": "nettle_plant", "papel": "quintal", "peso": 7, "base_y": 0.01, "raio": 0.6, "esc": [0.85, 1.25]},
	{"n": "potted_plant_02", "papel": "quintal", "peso": 4, "base_y": 0.0, "raio": 0.4, "esc": [0.9, 1.1]},

	# --- praca do obelisco -------------------------------------------------
	# SAIRAM daqui o `painted_wooden_bench` e o `CoffeeCart_01`: o banco nao
	# combinava com a praca e o carrinho de cafe' ficava com cara de quiosque
	# largado no meio da rua. Os .gltf continuam baixados em
	# `assets/3d_model/polyhaven/`, e as malhas ja' extraidas em DIR_MALHAS —
	# pra trazer qualquer um de volta basta reinserir a linha.
	#
	# Com o banco fora, o `_gravar_pontos` deixa de produzir lugar de SENTAR:
	# sobra so' o de encostar no muro. Ver o comentario la' embaixo.
	{"n": "korean_public_payphone_01", "papel": "praca", "peso": 2, "base_y": 0.0, "raio": 0.35, "esc": [1.0, 1.0]},
	{"n": "planter_pot_clay", "papel": "praca", "peso": 8, "base_y": 0.0, "raio": 0.22, "esc": [1.0, 1.5]},
	{"n": "potted_plant_02", "papel": "praca", "peso": 6, "base_y": 0.0, "raio": 0.4, "esc": [0.95, 1.15]},
	{"n": "dirty_football", "papel": "praca", "peso": 2, "base_y": 0.0, "raio": 0.15, "esc": [0.95, 1.05]},
	{"n": "shrub_04", "papel": "praca", "peso": 5, "base_y": 0.01, "raio": 0.45, "esc": [0.85, 1.2]},
]

## Quantos candidatos cada papel tenta, antes da densidade e das rejeicoes.
##
## Sao MUITO maiores que o resultado, e de proposito: quem limita o numero
## final e' o espacamento, nao a contagem. Subir tentativa nao adensa a cidade
## — so' faz o espalhamento aproveitar melhor os vaos que sobraram, em vez de
## desistir cedo e deixar quarteirao vazio ao lado de quarteirao cheio.
const TENTATIVAS := {
	"guia": 90, "muro": 2200, "parede": 700, "quintal": 2000, "praca": 900,
}

var _rng := RandomNumberGenerator.new()
var _mapa = null
var _esp = null
var _esp_herdado = null


# --------------------------------------------------------------------------
func _limpar() -> void:
	var n := 0
	for c in get_children():
		remove_child(c)
		c.free()
		n += 1
	last_result = "removidos %d nos" % n


func _construir() -> void:
	var t0 := Time.get_ticks_msec()
	_limpar()
	_rng.seed = semente
	_esp = CityMapa.Espacador.new(espacamento)
	_esp_herdado = CityMapa.Espacador.new(espacamento_herdado)

	var malhas := _colher_malhas()
	if malhas.is_empty():
		last_result = "ERRO: nenhuma malha carregada — rode 'extrair malhas' antes"
		return

	_mapa = CityMapa.new()
	if not _mapa.preparar(self,
			get_node_or_null(no_ruas) as Node3D,
			get_node_or_null(no_terreno) as Node3D,
			get_node_or_null(no_cidade) as Node3D,
			houses_json, poles_json):
		last_result = "ERRO: " + _mapa.erro
		return
	_mapa.preparar_muros(get_node_or_null(no_muros) as Node3D,
		get_node_or_null(no_cidade) as Node3D, self)
	var herdados := _semear_ocupacao(get_node_or_null(no_props_existentes) as Node3D)

	var por_papel := {}
	for item in CATALOGO:
		por_papel.get_or_add(item["papel"], []).append(item)

	var saida := {}
	for item in CATALOGO:
		saida[_chave_saida(item)] = []

	var c := {}
	c["guia"] = _espalhar_guia(por_papel.get("guia", []), saida)
	c["muro"] = _espalhar_muro(por_papel.get("muro", []), saida)
	c["parede"] = _espalhar_parede(por_papel.get("parede", []), saida)
	c["quintal"] = _espalhar_quintal(por_papel.get("quintal", []), saida)
	c["praca"] = _espalhar_praca(por_papel.get("praca", []), saida)

	var total := 0
	for k in c.keys():
		total += int(c[k])
	var nos := _emitir(saida, malhas)
	var grandes := _emitir_colisoes(saida) if colisao_grandes else 0
	var pontos := _gravar_pontos(saida) if gravar_pontos else 0

	last_result = ("%d adereços | guia %d, muro %d, parede %d, quintal %d, praca %d"
		+ " | %d MultiMesh, %d colisoes, %d pontos de parada | desviando de %d"
		+ " adereços da etapa 08 | %s | %d ms") % [
		total, c["guia"], c["muro"], c["parede"], c["quintal"], c["praca"],
		nos, grandes, pontos, herdados, _mapa.resumo(), Time.get_ticks_msec() - t0]
	print("CityUrbano: ", last_result)


## O mesmo modelo pode aparecer em papeis diferentes com escalas diferentes,
## mas a MALHA e' a mesma; a chave da saida junta modelo e peca.
func _chave_saida(item: Dictionary) -> String:
	return "%s|%s" % [item["n"], item.get("peca", "")]


# --------------------------------------------------------------------------
# malhas: fundir o arquivo inteiro, ou recortar uma peca pelo nome
# --------------------------------------------------------------------------
func _extrair_malhas() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_MALHAS))
	var feitas := 0
	var faltou: Array[String] = []
	var vistos := {}
	for item in CATALOGO:
		var chave := _chave_saida(item)
		if vistos.has(chave):
			continue
		vistos[chave] = true
		var destino := "%s/%s.res" % [DIR_MALHAS, _nome_arquivo(item)]
		if ResourceLoader.exists(destino):
			continue
		var caminho := CAMINHO_PH % [item["n"], item["n"]]
		if not ResourceLoader.exists(caminho):
			faltou.append(String(item["n"]))
			continue
		var raiz := (load(caminho) as PackedScene).instantiate()
		var malha := _montar_malha(raiz, item.get("peca", ""))
		raiz.free()
		if malha == null:
			faltou.append(chave)
			continue
		ResourceSaver.save(malha, destino)
		feitas += 1
	last_result = "gravadas %d malhas em %s%s" % [
		feitas, DIR_MALHAS, ("" if faltou.is_empty() else " | faltando: " + ", ".join(faltou))]
	print("CityUrbano: ", last_result)


func _nome_arquivo(item: Dictionary) -> String:
	var peca: String = item.get("peca", "")
	return String(item["n"]) if peca.is_empty() else peca


## Junta as superficies que interessam num unico ArrayMesh, com o transform de
## cada no ja' aplicado nos vertices. Uma superficie por malha de origem, pra
## cada uma manter o proprio material.
func _montar_malha(raiz: Node, peca: String) -> ArrayMesh:
	var achados: Array = []
	_colher_mesh_instances(raiz, raiz, peca, Transform3D.IDENTITY, achados)
	if achados.is_empty():
		return null
	var saida := ArrayMesh.new()
	for a in achados:
		var mi: MeshInstance3D = a["mi"]
		var xf: Transform3D = a["xf"]
		var m: Mesh = mi.mesh
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			if arr.is_empty():
				continue
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arr[Mesh.ARRAY_VERTEX] = verts
			# a normal gira, mas nao transladada — dai o basis puro
			if arr[Mesh.ARRAY_NORMAL] != null:
				var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for i in nrm.size():
					nrm[i] = (xf.basis * nrm[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = nrm
			# tangente e' 4 floats por vertice (xyz + sinal); so' o xyz gira
			if arr[Mesh.ARRAY_TANGENT] != null:
				var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
				for i in range(0, tg.size(), 4):
					var v := (xf.basis * Vector3(tg[i], tg[i + 1], tg[i + 2])).normalized()
					tg[i] = v.x
					tg[i + 1] = v.y
					tg[i + 2] = v.z
				arr[Mesh.ARRAY_TANGENT] = tg
			saida.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mat := mi.get_active_material(si)
			if mat != null:
				saida.surface_set_material(saida.get_surface_count() - 1, mat)
	return saida


func _colher_mesh_instances(n: Node, raiz: Node, peca: String, pai: Transform3D, saida: Array) -> void:
	var xf := pai
	var n3 := n as Node3D
	if n3 != null and n != raiz:
		xf = pai * n3.transform
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		if peca.is_empty() or String(mi.name) == peca:
			saida.append({"mi": mi, "xf": xf})
	for c in n.get_children():
		_colher_mesh_instances(c, raiz, peca, xf, saida)


func _colher_malhas() -> Dictionary:
	var out := {}
	for item in CATALOGO:
		var chave := _chave_saida(item)
		if out.has(chave):
			continue
		var destino := "%s/%s.res" % [DIR_MALHAS, _nome_arquivo(item)]
		if ResourceLoader.exists(destino):
			out[chave] = load(destino)
			continue
		# reserva: monta na hora. Funciona, mas EMBUTE a geometria na cena —
		# rode o `extrair malhas` pra gravar os .res antes de valer.
		var caminho := CAMINHO_PH % [item["n"], item["n"]]
		if not ResourceLoader.exists(caminho):
			push_warning("CityUrbano: falta %s" % caminho)
			continue
		var raiz := (load(caminho) as PackedScene).instantiate()
		var m := _montar_malha(raiz, item.get("peca", ""))
		raiz.free()
		if m != null:
			out[chave] = m
	return out


# --------------------------------------------------------------------------
# sorteio
# --------------------------------------------------------------------------
## Raio efetivo no espacamento. O piso e' o que impede tres miudezas de
## nascerem encostadas: sem ele, uma lata de spray de 15 cm reserva 15 cm.
func _vao(raio: float) -> float:
	return maxf(raio, raio_minimo)


## Lugar livre nas DUAS grades: a desta etapa (espalhamento de verdade) e a dos
## adereços herdados da etapa 08 (so' nao encostar).
func _livre(p: Vector3, raio: float) -> bool:
	return _esp.livre(p, _vao(raio)) and _esp_herdado.livre(p, 0.1)


## Marca na grade os adereços que a etapa 08 ja' colocou.
##
## As duas etapas tem grades de ocupacao SEPARADAS e nao se enxergam. O
## resultado aparecia na rua: um engradado da etapa 08 e um balde desta a dez
## centimetros um do outro, porque cada uma achava o lugar vazio. Ler as
## posicoes de la' custa uma varredura de MultiMesh e resolve.
##
## Vai pra uma grade SEPARADA e mais fina (`_esp_herdado`): ver o comentario do
## `espacamento_herdado`.
##
## As posicoes dos MultiMesh estao em MUNDO; a grade daqui vive em coordenadas
## locais da cidade, dai a subtracao do deslocamento.
func _semear_ocupacao(raiz: Node3D) -> int:
	if raiz == null:
		return 0
	var n := 0
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for c in no.get_children():
			pilha.append(c)
		var mmi := no as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var origem: Vector3 = (mmi.global_transform * mm.get_instance_transform(i)).origin
			_esp_herdado.ocupar(origem - _mapa.desloc, 0.1)
			n += 1
	return n


func _sortear(lista: Array) -> Dictionary:
	var soma := 0
	for it in lista:
		soma += int(it["peso"])
	var r := _rng.randi_range(0, maxi(1, soma) - 1)
	for it in lista:
		r -= int(it["peso"])
		if r < 0:
			return it
	return lista[-1]


func _escala(item: Dictionary) -> Vector3:
	var e: Array = item.get("esc", [1.0, 1.0])
	var s := _rng.randf_range(float(e[0]), float(e[1]))
	var ey: Array = item.get("esc_y", [])
	if ey.is_empty():
		return Vector3.ONE * s
	# o cano de descida estica so' na vertical: a secao e' de 1 m e a parede
	# tem 3, entao repetir a peca seria tres vezes mais malha pelo mesmo desenho
	return Vector3(s, s * _rng.randf_range(float(ey[0]), float(ey[1])), s)


func _transform(item: Dictionary, pos: Vector3, giro: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, giro).scaled(_escala(item)), pos)


# --------------------------------------------------------------------------
# os cinco papeis
# --------------------------------------------------------------------------
func _espalhar_guia(lista: Array, saida: Dictionary) -> int:
	"""Carro coberto e barreira, encostados na guia.

	O braco do poste aponta pra rua, entao a direcao da PISTA e' ele girado 90°.
	O carro fica com o comprimento (o Z local dele) em cima dessa direcao."""
	if lista.is_empty() or _mapa.postes.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["guia"] * densidade)
	for t in tentativas:
		var poste: Dictionary = _mapa.postes[_rng.randi_range(0, _mapa.postes.size() - 1)]
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 1.0))
		var rot := float(poste["rot"])
		var ao_longo := _rng.randf_range(2.5, 11.0) * (1 if _rng.randf() < 0.5 else -1)
		var afasta := _rng.randf_range(1.9, 3.1)   # pra dentro da pista
		var p := Vector3(
			float(poste["x"]) + cos(rot) * afasta - sin(rot) * ao_longo,
			0.0,
			float(poste["z"]) + sin(rot) * afasta + cos(rot) * ao_longo)
		# aqui a rua e' obrigatoria: e' onde se estaciona
		var yr: float = _mapa.altura_rua(p)
		if is_nan(yr) or _mapa.dentro_de_casa(p, raio) or not _livre(p, raio):
			continue
		# as duas pontas do carro tambem tem que estar no asfalto, senao ele
		# estaciona metade em cima do canteiro
		var dir_pista := Vector3(-sin(rot), 0.0, cos(rot))
		if not _mapa.eh_rua(p + dir_pista * raio) or not _mapa.eh_rua(p - dir_pista * raio):
			continue
		p.y = yr + float(item.get("base_y", 0.0))
		var giro := rot + PI * 0.5 + _rng.randf_range(-0.04, 0.04)
		if _rng.randf() < 0.5:
			giro += PI
		saida[_chave_saida(item)].append(_transform(item, p, giro))
		_esp.ocupar(p, _vao(raio))
		n += 1
	return n


func _espalhar_muro(lista: Array, saida: Dictionary) -> int:
	"""Entulho encostado no muro, pelo lado de fora.

	O ponto sai da superficie do muro (`CityMapa.sortear_muro`) e desce pro
	chao; o adereço afasta o proprio raio da parede pra nao entrar nela."""
	if lista.is_empty() or not _mapa.tem_muros():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["muro"] * densidade)
	for t in tentativas:
		var s: Dictionary = _mapa.sortear_muro(_rng)
		if s.is_empty():
			break
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 0.4))
		var normal: Vector3 = s["n"]
		var base: Vector3 = s["p"]
		var p := base + normal * (raio + _rng.randf_range(0.05, 0.35))
		p.y = 0.0
		if _mapa.eh_rua(p) or _mapa.dentro_de_casa(p, raio) or not _livre(p, raio):
			continue
		# lado de fora = o que da' pra rua. Sem isto, metade do entulho nasce
		# dentro do lote, invisivel atras do proprio muro.
		if not _mapa.eh_rua(p + normal * 3.5) and not _mapa.eh_rua(p + normal * 6.0):
			continue
		p.y = _mapa.chao(p.x, p.z, float(s["ymin"])) + float(item.get("base_y", 0.0))
		# de costas pro muro, com a torcao de quem largou ali
		var giro := atan2(normal.x, normal.z) + _rng.randf_range(-0.4, 0.4)
		saida[_chave_saida(item)].append(_transform(item, p, giro))
		_esp.ocupar(p, _vao(raio))
		n += 1
	return n


func _espalhar_parede(lista: Array, saida: Dictionary) -> int:
	"""Cano, duto e camera na parede da casa, sempre ACIMA da altura do muro —
	abaixo dela ninguem ve' da rua."""
	if lista.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["parede"] * densidade)
	for t in tentativas:
		var casa: Dictionary = _mapa.casas[_rng.randi_range(0, _mapa.casas.size() - 1)]
		var h := float(casa["h"])
		if h < 3.4:
			continue
		var item := _sortear(lista)
		var alt: Array = item.get("alt", [2.6, 3.4])
		var y := _rng.randf_range(float(alt[0]), float(alt[1]))
		if y > h - 0.3:
			continue
		var lado := _rng.randi_range(0, 3)
		var ponto: Dictionary = _mapa.ponto_de_parede(
			casa, lado, _rng.randf_range(-0.8, 0.8), 0.1)
		var p: Vector3 = ponto["p"]
		if _mapa.dentro_de_casa(p + _normal_da_face(casa, lado) * 1.0, 0.0):
			continue
		p.y = _mapa.chao(p.x, p.z, float(casa["y"])) + y
		if not _esp.livre(p, 1.1):
			continue
		var normal := _normal_da_face(casa, lado)
		saida[_chave_saida(item)].append(
			_transform(item, p, atan2(normal.x, normal.z)))
		_esp.ocupar(p, 1.1)
		n += 1
	return n


const NORMAL_LOCAL := [
	Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0),
	Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0),
]

## Vetor, e nao angulo: o `rot` do houses.json gira ao contrario do Godot.
func _normal_da_face(casa: Dictionary, lado: int) -> Vector3:
	var nl: Vector3 = NORMAL_LOCAL[lado]
	var rot := float(casa["rot"])
	return Vector3(
		nl.x * cos(rot) - nl.z * sin(rot),
		0.0,
		nl.x * sin(rot) + nl.z * cos(rot)).normalized()


func _espalhar_quintal(lista: Array, saida: Dictionary) -> int:
	if lista.is_empty():
		return 0
	var n := 0
	var tentativas := int(TENTATIVAS["quintal"] * densidade)
	for t in tentativas:
		var casa: Dictionary = _mapa.casas[_rng.randi_range(0, _mapa.casas.size() - 1)]
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 0.5))
		var ang := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(
			maxf(float(casa["w"]), float(casa["d"])) * 0.65 + 1.2, 12.0)
		var p := Vector3(float(casa["x"]) + cos(ang) * dist, 0.0,
			float(casa["z"]) + sin(ang) * dist)
		if _mapa.eh_rua(p) or _mapa.dentro_de_casa(p, raio + 0.4) or not _livre(p, raio):
			continue
		p.y = _mapa.chao(p.x, p.z, float(casa["y"])) + float(item.get("base_y", 0.0))
		saida[_chave_saida(item)].append(_transform(item, p, _rng.randf_range(0.0, TAU)))
		_esp.ocupar(p, _vao(raio))
		n += 1
	return n


func _espalhar_praca(lista: Array, saida: Dictionary) -> int:
	"""Anel da praca do obelisco: entre a ilha e a guia da rotatoria.

	O banco fica VIRADO PRA ILHA — praca de interior tem banco olhando pro
	monumento, nao pro transito. Por isso o giro nao e' sorteado: sai do angulo
	do proprio ponto."""
	if lista.is_empty():
		return 0
	# Espacador PROPRIO, com passo mais curto que o da rua: praca e' o unico
	# lugar da cidade onde mobiliario perto de mobiliario faz sentido (banco ao
	# lado de vaso, vaso ao lado de vaso). Mesmo assim o passo de 0,6 m da
	# primeira versao era curto DEMAIS — vaso colado em vaso, que foi o
	# amontoado que apareceu na beira da praca. 1,2 m poe respiro entre as
	# pecas sem devolver a praca vazia — a 1,5 m ela cai pra dezoito pecas no
	# anel inteiro, que ja' e' pouca coisa demais pra uma praca de centro.
	#
	# O geral (`_esp`) tambem e' consultado: e' o que impede o mobiliario da
	# praca de cair em cima do que a etapa 08 ja' deixou na calcada dela.
	var esp := CityMapa.Espacador.new(1.2)
	var n := 0
	var tentativas := int(TENTATIVAS["praca"] * densidade)
	for t in tentativas:
		var item := _sortear(lista)
		var raio: float = float(item.get("raio", 0.5))
		var ang := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(praca_raio_ilha + raio + 0.5, praca_raio_externo - raio - 1.0)
		if r <= praca_raio_ilha:
			continue
		var p := Vector3(praca_centro.x + cos(ang) * r, 0.0, praca_centro.y + sin(ang) * r)
		if not esp.livre(p, raio * 1.15) or not _esp_herdado.livre(p, 0.1):
			continue
		p.y = _mapa.chao(p.x, p.z, 0.0) + float(item.get("base_y", 0.0))
		# Giro solto: o que sobrou na praca e' vaso, moita e orelhao, e nenhum
		# deles tem frente. O caso do movel virado pro obelisco morreu junto
		# com o banco — se ele voltar, o giro dele e' `atan2(cos(ang),
		# sin(ang))`, que poe o +Z local (onde fica o encosto) pra fora da
		# praca e deixa quem senta olhando pro monumento.
		var giro := _rng.randf_range(0.0, TAU)
		saida[_chave_saida(item)].append(_transform(item, p, giro))
		esp.ocupar(p, raio * 1.15)
		n += 1
	return n


# --------------------------------------------------------------------------
# pontos de parada: onde um NPC pode ficar fazendo alguma coisa
# --------------------------------------------------------------------------
## Grava um JSON com lugares de SENTAR (os bancos que acabaram de ser postos na
## praca) e de ENCOSTAR (pe' de muro virado pra rua).
##
## Vai pra arquivo, e nao pra nos Marker3D na cena, por dois motivos: seriam
## umas trezentas Node3D vazias engordando a stage_1, e o `city_npc.gd`
## precisa da lista UMA vez por jogo, num `static`, e nao uma varredura de
## arvore por NPC.
##
## As coordenadas saem em MUNDO (ja' com o deslocamento da cidade), porque quem
## le' e' o NPC em tempo de jogo e la' nao existe mais "espaco da cidade".
func _gravar_pontos(saida: Dictionary) -> int:
	var pontos: Array = []

	# --- sentar: dois lugares por banco, um pra cada lado do assento -------
	# DORMENTE enquanto nao houver banco no catalogo: sem banco na praca, este
	# laco nao acha nada e a cidade fica so' com o "encostar". O codigo segue
	# aqui porque e' o unico lugar que sabe medir o assento, e reinserir o
	# banco tem que voltar a produzir lugar de sentar sem mais nenhuma edicao.
	var chave_banco := "painted_wooden_bench|"
	for xf in (saida.get(chave_banco, []) as Array):
		var base: Transform3D = xf
		base.origin += _mapa.desloc
		var eixo := base.basis.x.normalized()      # o comprimento do assento
		# quem senta olha pro -Z local: o encosto esta' no +Z (ver _espalhar_praca)
		var frente := -base.basis.z.normalized()
		for lado in [-0.28, 0.28]:
			var p: Vector3 = base.origin + eixo * float(lado)
			pontos.append({
				"t": "sentar",
				"x": snappedf(p.x, 0.001), "y": snappedf(p.y, 0.001), "z": snappedf(p.z, 0.001),
				"g": snappedf(atan2(frente.x, frente.z), 0.001),
				"h": snappedf(altura_do_assento, 0.001),
			})

	# --- encostar: pe' de muro, virado pra rua ----------------------------
	var tentados := 0
	var encostos := 0
	var esp := CityMapa.Espacador.new(2.0)
	while encostos < pontos_de_encostar and tentados < pontos_de_encostar * 30:
		tentados += 1
		var s: Dictionary = _mapa.sortear_muro(_rng)
		if s.is_empty():
			break
		var normal: Vector3 = s["n"]
		var pe: Vector3 = s["p"]
		# 30 cm a' frente do muro: e' onde encostam as costas de quem para ali
		var p: Vector3 = pe + normal * 0.30
		p.y = 0.0
		if _mapa.eh_rua(p) or _mapa.dentro_de_casa(p, 0.5) or not esp.livre(p, 1.4):
			continue
		# de costas pro muro so' vale se do outro lado tiver rua pra olhar
		if not _mapa.eh_rua(p + normal * 3.5) and not _mapa.eh_rua(p + normal * 6.0):
			continue
		p.y = _mapa.chao(p.x, p.z, float(s["ymin"]))
		esp.ocupar(p, 1.4)
		var m: Vector3 = p + _mapa.desloc
		pontos.append({
			"t": "encostar",
			"x": snappedf(m.x, 0.001), "y": snappedf(m.y, 0.001), "z": snappedf(m.z, 0.001),
			"g": snappedf(atan2(normal.x, normal.z), 0.001),
			"h": 0.0,
		})
		encostos += 1

	var f := FileAccess.open(pontos_json, FileAccess.WRITE)
	if f == null:
		push_error("CityUrbano: nao consegui escrever %s" % pontos_json)
		return 0
	f.store_string(JSON.stringify({
		"nota": "gerado por tools/godot/citybuild/city_urbano.gd — coordenadas de MUNDO",
		"pontos": pontos,
	}, " "))
	f.close()
	return pontos.size()


# --------------------------------------------------------------------------
# saida: um MultiMeshInstance3D por especie por bloco
# --------------------------------------------------------------------------
func _emitir(saida: Dictionary, malhas: Dictionary) -> int:
	var nos := 0
	for chave in saida.keys():
		var lista: Array = saida[chave]
		if lista.is_empty() or not malhas.has(chave):
			continue
		var blocos := {}
		for xf in lista:
			# as posicoes vem no espaco da cidade; os nos vivem na raiz da cena
			var mundo: Transform3D = xf
			mundo.origin += _mapa.desloc
			var b := Vector2i(floori(mundo.origin.x / bloco), floori(mundo.origin.z / bloco))
			blocos.get_or_add(b, []).append(mundo)
		var nome := String(chave).replace("|", "_").rstrip("_")
		for b in blocos.keys():
			var trs: Array = blocos[b]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = malhas[chave]
			mm.instance_count = trs.size()
			for i in trs.size():
				mm.set_instance_transform(i, trs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [nome, b.x, b.y]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mmi.lod_bias = 1.0
			add_child(mmi)
			mmi.owner = get_tree().edited_scene_root
			nos += 1
	return nos


func _emitir_colisoes(saida: Dictionary) -> int:
	"""Um StaticBody3D so', com uma caixa por volume grande. Corpo unico porque
	dezenas de corpos separados custam bem mais no broadphase do que dezenas de
	formas no mesmo corpo."""
	var grandes := {}
	for item in CATALOGO:
		if item.get("grande", false):
			grandes[_chave_saida(item)] = item
	var corpo := StaticBody3D.new()
	corpo.name = "colisao_urbano"
	corpo.collision_layer = camada_colisao
	corpo.collision_mask = 0
	add_child(corpo)
	corpo.owner = get_tree().edited_scene_root
	var n := 0
	for chave in saida.keys():
		if not grandes.has(chave):
			continue
		var item: Dictionary = grandes[chave]
		var c: Array = item.get("col", [1.0, 1.0, 1.0])
		var altura := float(c[1])
		for xf in (saida[chave] as Array):
			var forma := CollisionShape3D.new()
			var caixa := BoxShape3D.new()
			caixa.size = Vector3(float(c[0]), altura, float(c[2]))
			forma.shape = caixa
			forma.transform = Transform3D(xf.basis.orthonormalized(),
				xf.origin + _mapa.desloc + Vector3.UP * altura * 0.5)
			corpo.add_child(forma)
			forma.owner = get_tree().edited_scene_root
			n += 1
	if n == 0:
		corpo.queue_free()
	return n
