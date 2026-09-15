extends Node3D

## Bancada de teste do "Unknown Neighbor" — NAO faz parte do jogo.
##
## Poe as quatro linhagens lado a lado num chao de teste, com um alvo falso no
## grupo "player" pra eles perseguirem, e um teclado de atalhos pra forcar as
## cinco formas e o desmembramento sem ter de brigar de verdade.
##
##   1..5   forca a forma
##   Q      arranca a cabeca
##   W      arranca o braco direito (com a foice)
##   E      arranca uma perna
##   R      da 25 de dano em todos (deixa as formas abrirem sozinhas)
##   L      liga/desliga o log da marcha lateral (so no primeiro deles)
##   ESPACO pula com o alvo (pra testar se da pra saltar a onda do Coro)
##   J      pulo em laco do alvo, uma vez por segundo
##
## Duas cenas usam este mesmo script, e a diferenca entre elas e' so o NOME do
## arquivo:
##
##   test_vizinho.tscn              -> comportamento de CIDADE
##   test_vizinho_battlefield.tscn  -> comportamento de ARENA
##
## Isso nao e' gambiarra por acaso: o `_na_arena()` do inimigo (como o dos
## outros tres inimigos do jogo) decide pelo caminho da cena conter
## "battlefield". Uma bancada com esse nome entra no mesmo caminho de codigo da
## arena de verdade, e e' assim que da pra testar a dobra, a ceifa cega, a casca
## e a semeadura sem ter de atravessar a cidade e o amuleto toda vez.

const VIZINHO := preload("res://scenes/enemies/folded_neighbor.tscn")

var _corpos: Array[Node] = []


func _ready() -> void:
	_ambiente()
	_chao()
	_alvo()
	print("[teste_vizinho] modo ", "ARENA" if _modo_arena() else "CIDADE")
	for i in 4:
		var raiz := VIZINHO.instantiate()
		add_child(raiz)
		var espalha := 1.6 if _modo_arena() else 2.2
		raiz.global_position = Vector3(-espalha * 1.5 + float(i) * espalha, 0.5,
			-3.0 if _modo_arena() else -5.0)
		var corpo := raiz.get_child(0)
		corpo.set("linhagem_index", i)
		corpo.set("distance_to_aproach", 40.0)
		# O log da marcha comeca DESLIGADO (tecla L liga). Ele fala a cada 0,4 s
		# e so o primeiro deles fala — quatro vozes ao mesmo tempo no console
		# nao dizem nada.
		_corpos.append(corpo)
	print("[teste_vizinho] 4 linhagens no chao. 1..5 = forma, Q/W/E = membro, R = dano.")


## Ambiente escuro, como o da arena: com o chao branco e o ceu padrao do Godot
## tudo que e' aditivo estoura a tela e nao da pra julgar efeito nenhum.
func _ambiente() -> void:
	var we := get_node_or_null("Ambiente") as WorldEnvironment
	if we == null:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.22, 0.26)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.08, 0.08, 0.10)
	we.environment = env


## Chao da bancada.
##
## No modo ARENA ele e' PEQUENO de proposito — uma plataforma de 14 m com
## beirada e vazio em volta, igual a arena de verdade. E o unico jeito de
## testar a dobra: o bug que ela tinha (teletransportar pra fora do mundo e
## encerrar a batalha sozinha) so aparece quando existe beirada pra errar.
## No modo cidade o chao e' grande, porque la ele so vaga.
func _chao() -> void:
	var lado := 14.0 if _modo_arena() else 40.0
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 2
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(lado, 1, lado)
	forma.shape = caixa
	forma.position.y = -0.5
	corpo.add_child(forma)

	var mi := MeshInstance3D.new()
	var plano := BoxMesh.new()
	plano.size = Vector3(lado, 1, lado)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.10)
	mat.roughness = 0.95
	plano.material = mat
	mi.mesh = plano
	mi.position.y = -0.5
	add_child(mi)


func _modo_arena() -> bool:
	return get_tree().current_scene.scene_file_path.contains("battlefield")


func _alvo() -> void:
	var alvo := CharacterBody3D.new()
	alvo.set_script(preload("res://scripts/tools/teste_alvo.gd"))
	alvo.name = "alvo"
	alvo.add_to_group("player")
	alvo.collision_layer = 1
	alvo.collision_mask = 2
	add_child(alvo)
	alvo.global_position = Vector3(0, 1, 3.4 if not _modo_arena() else 2.0)
	var forma := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	forma.shape = cap
	forma.position.y = 0.85
	alvo.add_child(forma)


## Vigia da queda: se algum deles descer abaixo da plataforma, o resgate da
## dobra falhou e o log tem de dizer. Sem isto o bug (cair no vazio e encerrar
## a batalha) passaria batido — ele some de quadro e ninguem ve.
func _physics_process(_delta: float) -> void:
	for c in _corpos:
		if not is_instance_valid(c):
			continue
		var y: float = (c as Node3D).global_position.y
		if y < -2.0:
			push_warning("[teste_vizinho] %s caiu da plataforma (y=%.1f)" % [c.name, y])


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	var tecla := (evento as InputEventKey).keycode
	for c in _corpos:
		if not is_instance_valid(c):
			continue
		match tecla:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				c.call("_aplica_forma", tecla - KEY_1, false)
			KEY_Q:
				c.call("_arranca_membro", "cabeca")
			KEY_W:
				c.call("_arranca_membro", "braco_r")
			KEY_E:
				c.call("_arranca_membro", "perna_l")
			KEY_R:
				c.call("take_damage", 25)
			KEY_L:
				# So o primeiro fala: quatro vozes no console nao dizem nada.
				if c == _corpos[0]:
					c.set("debug_passo_lateral", not bool(c.get("debug_passo_lateral")))
					print("[teste_vizinho] log da marcha: ", c.get("debug_passo_lateral"))
