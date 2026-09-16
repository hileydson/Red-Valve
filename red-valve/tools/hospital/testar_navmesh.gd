extends Node

## Confere, sem abrir o jogo, se da' pra ANDAR de um canto do hospital ao outro.
##
##     Godot_v4.6.1 --headless --path red-valve res://tools/hospital/testar_navmesh.tscn
##
## (tem de ser CENA, e nao `-s script`: com `-s` o Godot nao carrega autoload
## nenhum, e o hospital instancia o jogador, que depende de GlobalEvents.)
##
## O navmesh do hospital nao e' assado pelo editor: ele e' escrito direto no
## .tscn por `tools/godot/hospital/navmesh.py`, a partir da planta. Isso e' bom
## (nao depende de ninguem clicar em "Bake") e e' arriscado pelo mesmo motivo —
## um erro de meio metro num vao de porta fecha uma ala inteira e NAO APARECE:
## a cena carrega, a sala existe, o jogador entra nela a pe'. Quem descobre o
## problema e' o inimigo, que simplesmente para de perseguir na soleira.
##
## Entao aqui a pergunta e' feita ao proprio NavigationServer3D, que e' quem
## responde no jogo: existe caminho de A ate' B?

const CENA := "res://scenes/stages/hospital/hospital.tscn"
## Se o fim do caminho ficar a mais que isto do alvo, nao ha' passagem.
const TOLERANCIA := 2.5

## (nome, de, para) — cada par atravessa pelo menos uma porta e um corredor.
const TRAJETOS := [
	["terreo: hall -> quarto 101", Vector3(6, 0, 34), Vector3(5.7, 0, 5)],
	["terreo: hall -> casa de maquinas", Vector3(6, 0, 34), Vector3(50, 0, 63)],
	["terreo: hall -> necroterio", Vector3(6, 0, 34), Vector3(43, 0, 48)],
	["terreo: hall -> laboratorio", Vector3(6, 0, 34), Vector3(50, 0, 5)],
	["terreo: hall -> elevador", Vector3(6, 0, 34), Vector3(53, 0, 31.6)],
	["terreo: cirurgia -> refeitorio", Vector3(30, 0, 20), Vector3(30, 0, 48)],
	["terreo: uti -> quarto 109", Vector3(42, 0, 20), Vector3(16, 0, 63)],
	["2o andar: elevador -> arquivo", Vector3(53, 4.2, 31.6), Vector3(8, 4.2, 6)],
	["2o andar: elevador -> quarto 204", Vector3(53, 4.2, 31.6), Vector3(5.7, 4.2, 59)],
	["2o andar: elevador -> psiquiatria", Vector3(53, 4.2, 31.6), Vector3(8, 4.2, 38)],
	["2o andar: arquivo -> cirurgia 2", Vector3(8, 4.2, 6), Vector3(27, 4.2, 59)],
	["2o andar: quarto 201 -> observacao", Vector3(6, 4.2, 23), Vector3(38, 4.2, 59)],
]


func _ready() -> void:
	var cena: Node = load(CENA).instantiate()
	add_child(cena)
	# O NavigationServer so' costura a malha no fim de um quadro de fisica; sem
	# esperar, toda consulta volta vazia e o teste "reprova" um navmesh bom.
	for i in 8:
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var mapa: RID = get_viewport().world_3d.navigation_map
	var falhas := 0
	for t in TRAJETOS:
		var nome: String = t[0]
		var de: Vector3 = t[1]
		var para: Vector3 = t[2]
		var caminho := NavigationServer3D.map_get_path(mapa, de, para, true, 4)
		var sobra := 999.0
		if caminho.size() > 0:
			sobra = caminho[caminho.size() - 1].distance_to(para)
		var chegou := sobra <= TOLERANCIA
		if not chegou:
			falhas += 1
		print("%s %-38s %3d pontos, para a %.1f m do alvo"
			% ["ok   " if chegou else "FALHA", nome, caminho.size(), sobra])

	print("")
	if falhas == 0:
		print("navegacao: todos os %d trajetos fecham" % TRAJETOS.size())
	else:
		print("navegacao: %d de %d trajetos NAO fecham" % [falhas, TRAJETOS.size()])
	get_tree().quit(falhas)
